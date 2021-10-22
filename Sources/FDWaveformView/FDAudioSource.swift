// Copyright 2013–2020, William Entriken and the FDWaveformView contributors.
// Released under the MIT license as part of the FDWaveformView project.

import Foundation
import AVFoundation

enum FDAudioSourceError: Error {
    case FailedToReadTrackSamples
}

/// Reads samples from an audio file
final class FDAudioSource: FDWaveformViewDataSource {

    public let startIndex: Int = 0

    public let endIndex: Int

    /// Number of samples available
    public let count: Int

    /// The audio asset URL used to load the context
    let audioURL: URL
    
    /// Loaded asset
    let asset: AVAsset
    
    /// Loaded assetTrack
    let assetTrack: AVAssetTrack
    
    // MARK: - Initialization
    
    // This is private beacuse details are not known until audio is asynchronously loaded
    private init(audioURL: URL, totalSamples: Int, asset: AVAsset, assetTrack: AVAssetTrack) {
        self.endIndex = totalSamples
        self.audioURL = audioURL
        self.asset = asset
        self.assetTrack = assetTrack
        count = endIndex - startIndex
    }
    
    /// Attempt to create collection of samples from an auedio track inside `audioURL`. This is a static function rather than a constructor because we run asynchronously.
    /// - Parameters:
    ///   - audioURL: A media file to load
    ///   - completionHandler: The asynchronous callback (can call on any thread) and may possibly be called synchronousle
    /// - Returns: Void
    public static func load(fromAudioURL audioURL: URL, completionHandler: @escaping (_ audioContext: FDAudioSource?) -> ()) {
        let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true as Bool)]
        let asset = AVURLAsset(url: audioURL, options: assetOptions)
        guard let assetTrack = asset.tracks(withMediaType: .audio).first else
        {
            NSLog("FDWaveformView failed to load AVAssetTrack audio track")
            completionHandler(nil)
            return
        }
        
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError?
            if asset.statusOfValue(forKey: "duration", error: &error) == .loaded {
                let totalSamples = Int(Float64(assetTrack.naturalTimeScale) * Float64(asset.duration.value) / Float64(asset.duration.timescale))
                completionHandler(Self.init(audioURL: audioURL, totalSamples: totalSamples, asset: asset, assetTrack: assetTrack))
                return
            }
            print("FDWaveformView could not load asset: \(error?.localizedDescription ?? "Unknown error")")
            completionHandler(nil)
        }
    }
    
    // MARK: - Features
    
    /// Get audio sample data
    /// - Parameter bounds: These are in units of the `assetTrack`'s natural timescale, as is startIndex and endIndex
    /// - Throws:FDAudioSourceError
    /// - Returns: 16-bit data values (2 bytes per sample)
    func readSampleData(bounds: Range<Int>) throws -> Data {
        //TODO: Consider outputting [Float] directly here. Then possible this could conform to RandomAccessCollection
        let assetReader = try AVAssetReader(asset: asset) // AVAssetReader is a one-shot reader so we cannot make it a class property
        assetReader.timeRange = CMTimeRange(start: CMTime(value: Int64(bounds.lowerBound), timescale: assetTrack.naturalTimeScale),
                                       duration: CMTime(value: Int64(bounds.count), timescale: assetTrack.naturalTimeScale))
        let outputSettingsDict: [String : Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false, // TODO: Maybe use float here because we convert using DSP later anyway. Need to profile performance of this change.
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        assetReader.add(readerOutput)

        var sampleBuffer = Data() // 16-bit samples
        assetReader.startReading()
        defer { assetReader.cancelReading() } // Cancel reading if we exit early or if operation is cancelled

        while assetReader.status == .reading {
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                  let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else {
                break
            }
            // Append audio sample buffer into our current sample buffer
            var readBufferLength: Int = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil, dataPointerOut: &readBufferPointer)
            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            CMSampleBufferInvalidate(readSampleBuffer)
        }
        
        // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
        // Something went wrong. Handle it or do not, depending on if you can get above to work
        if assetReader.status == .completed {
            return sampleBuffer
        }
        throw FDAudioSourceError.FailedToReadTrackSamples
    }
}
