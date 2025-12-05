import AVFoundation
import Accelerate
//
// Copyright William Entriken and the FDWaveformView contributors.
//
import UIKit

/// Holds audio information used for building waveforms
final public class FDAudioContext: FDWaveformDataSource {

    /// The audio asset URL used to load the context
    public let audioURL: URL

    /// Total number of samples in loaded asset
    public let totalSamples: Int

    /// Sample rate in samples per second
    public let sampleRate: Double

    /// Number of audio channels
    public let channelCount: Int

    /// Loaded asset
    public let asset: AVAsset

    // Loaded assetTrack
    public let assetTrack: AVAssetTrack

    // MARK: - FDWaveformDataSource

    public var sampleCount: Int { totalSamples }

    public func readSamples(in range: Range<Int>) throws -> [Float] {
        guard range.lowerBound >= 0 && range.upperBound <= totalSamples else {
            throw FDWaveformDataSourceError.rangeOutOfBounds
        }

        guard !range.isEmpty else { return [] }

        guard let reader = try? AVAssetReader(asset: asset) else {
            throw FDWaveformDataSourceError.readFailed(underlying: nil)
        }

        let timeScale = Int32(sampleRate)
        reader.timeRange = CMTimeRange(
            start: CMTime(value: Int64(range.lowerBound), timescale: timeScale),
            duration: CMTime(value: Int64(range.count), timescale: timeScale)
        )

        let outputSettingsDict: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let readerOutput = AVAssetReaderTrackOutput(
            track: assetTrack, outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        var sampleBuffer = Data()

        reader.startReading()
        defer { reader.cancelReading() }

        while reader.status == .reading {
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer)
            else {
                break
            }

            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil,
                dataPointerOut: &readBufferPointer)
            sampleBuffer.append(
                UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            CMSampleBufferInvalidate(readSampleBuffer)
        }

        // Convert Int16 samples to Float and mix to mono
        let int16Count = sampleBuffer.count / MemoryLayout<Int16>.size
        var floatSamples = [Float](repeating: 0.0, count: int16Count)

        sampleBuffer.withUnsafeBytes { bytes in
            guard let samples = bytes.bindMemory(to: Int16.self).baseAddress else { return }
            vDSP_vflt16(samples, 1, &floatSamples, 1, vDSP_Length(int16Count))
        }

        // Normalize to [-1, 1] range
        var scalar: Float = 1.0 / Float(Int16.max)
        vDSP_vsmul(floatSamples, 1, &scalar, &floatSamples, 1, vDSP_Length(int16Count))

        // Mix channels to mono if stereo
        if channelCount > 1 {
            let monoCount = int16Count / channelCount
            var monoSamples = [Float](repeating: 0.0, count: monoCount)
            for i in 0..<monoCount {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += floatSamples[i * channelCount + ch]
                }
                monoSamples[i] = sum / Float(channelCount)
            }
            return monoSamples
        }

        return floatSamples
    }

    // MARK: - Initialization

    private init(
        audioURL: URL, totalSamples: Int, sampleRate: Double, channelCount: Int, asset: AVAsset,
        assetTrack: AVAssetTrack
    ) {
        self.audioURL = audioURL
        self.totalSamples = totalSamples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.asset = asset
        self.assetTrack = assetTrack
    }

    public static func load(
        fromAudioURL audioURL: URL,
        completionHandler: @escaping (_ audioContext: FDAudioContext?) -> Void
    ) {
        let asset = AVURLAsset(
            url: audioURL,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true as Bool)])

        guard let assetTrack = asset.tracks(withMediaType: AVMediaType.audio).first else {
            NSLog("FDWaveformView failed to load AVAssetTrack")
            completionHandler(nil)
            return
        }

        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            switch status {
            case .loaded:
                guard
                    let formatDescriptions = assetTrack.formatDescriptions
                        as? [CMAudioFormatDescription],
                    let audioFormatDesc = formatDescriptions.first,
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc)
                else { break }

                let sampleRate = Double(asbd.pointee.mSampleRate)
                let channelCount = Int(asbd.pointee.mChannelsPerFrame)
                let totalSamples = Int(
                    sampleRate * Float64(asset.duration.value) / Float64(asset.duration.timescale))
                let audioContext = FDAudioContext(
                    audioURL: audioURL,
                    totalSamples: totalSamples,
                    sampleRate: sampleRate,
                    channelCount: channelCount,
                    asset: asset,
                    assetTrack: assetTrack
                )
                completionHandler(audioContext)
                return

            case .failed, .cancelled, .loading, .unknown:
                print(
                    "FDWaveformView could not load asset: \(error?.localizedDescription ?? "Unknown error")"
                )
            @unknown default:
                print(
                    "FDWaveformView could not load asset: \(error?.localizedDescription ?? "Unknown error")"
                )
            }

            completionHandler(nil)
        }
    }
}
