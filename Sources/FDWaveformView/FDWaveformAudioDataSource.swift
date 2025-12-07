//
// Copyright (c) William Entriken and the FDWaveformView contributors
//
import AVFoundation
import Accelerate
import Foundation

/// Implementation of FDWaveformDataSource that reads audio data from an AVAsset.
final class FDWaveformAudioDataSource: FDWaveformDataSource {
    private let audioURL: URL
    private let asset: AVAsset
    private var assetTrack: AVAssetTrack?
    private var sampleRate: Int = 44100
    private var channelCount: Int = 1
    private var cachedTotalSamples: Int = 0
    private var isLoaded: Bool = false

    init(audioURL: URL) {
        self.audioURL = audioURL
        self.asset = AVAsset(url: audioURL)
    }

    /// Loads audio track properties asynchronously. Called automatically on first access.
    private func loadTrackIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true

        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            self.assetTrack = tracks.first

            if let track = assetTrack,
                let formatDescriptions = try? await track.load(.formatDescriptions)
                    as? [CMAudioFormatDescription],
                let formatDesc = formatDescriptions.first,
                let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
            {
                self.sampleRate = Int(streamDesc.pointee.mSampleRate)
                self.channelCount = Int(streamDesc.pointee.mChannelsPerFrame)

                // Calculate total samples from duration
                let duration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)
                self.cachedTotalSamples = Int(durationInSeconds * Double(sampleRate))
            }
        } catch {
            // Keep default values on error
        }
    }

    func numberOfSamples() async -> Int {
        await loadTrackIfNeeded()
        return cachedTotalSamples
    }

    func samples(in range: Range<Int>) async -> [Float] {
        await loadTrackIfNeeded()
        guard !range.isEmpty, let track = assetTrack else { return [] }

        guard let reader = try? AVAssetReader(asset: asset) else { return [] }

        // Set time range to read
        let timeScale = CMTimeScale(sampleRate)
        reader.timeRange = CMTimeRange(
            start: CMTime(value: Int64(range.lowerBound), timescale: timeScale),
            duration: CMTime(value: Int64(range.count), timescale: timeScale))

        // Configure output for 16-bit PCM
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        var sampleBuffer = Data()

        reader.startReading()
        defer { reader.cancelReading() }

        while reader.status == .reading {
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer)
            else { break }

            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil,
                dataPointerOut: &readBufferPointer)
            sampleBuffer.append(
                UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            CMSampleBufferInvalidate(readSampleBuffer)
        }

        // Convert 16-bit samples to normalized floats
        let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
        guard totalSamples > 0 else { return [] }

        return sampleBuffer.withUnsafeBytes { bytes -> [Float] in
            guard let samples = bytes.bindMemory(to: Int16.self).baseAddress else {
                return []
            }

            var floatSamples = [Float](repeating: 0.0, count: totalSamples)
            vDSP_vflt16(samples, 1, &floatSamples, 1, vDSP_Length(totalSamples))

            // Normalize to [-1, 1] range (divide by 32768)
            var divisor: Float = 32768.0
            vDSP_vsdiv(floatSamples, 1, &divisor, &floatSamples, 1, vDSP_Length(totalSamples))

            // If stereo, average the channels
            if channelCount > 1 {
                let monoSamples = totalSamples / channelCount
                var monoBuffer = [Float](repeating: 0.0, count: monoSamples)
                for i in 0..<monoSamples {
                    var sum: Float = 0
                    for ch in 0..<channelCount {
                        sum += floatSamples[i * channelCount + ch]
                    }
                    monoBuffer[i] = sum / Float(channelCount)
                }
                return monoBuffer
            }

            return floatSamples
        }
    }

    func maximums(from range: Range<Int>, numberOfBins: Int) async -> [Float] {
        await loadTrackIfNeeded()
        guard !range.isEmpty, numberOfBins > 0, let track = assetTrack else { return [] }

        guard let reader = try? AVAssetReader(asset: asset) else { return [] }

        // Set time range to read
        let timeScale = CMTimeScale(sampleRate)
        reader.timeRange = CMTimeRange(
            start: CMTime(value: Int64(range.lowerBound), timescale: timeScale),
            duration: CMTime(value: Int64(range.count), timescale: timeScale))

        // Configure output for 16-bit PCM
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        let samplesPerBin = max(1, channelCount * range.count / numberOfBins)
        let filter = [Float](repeating: 1.0 / Float(samplesPerBin), count: samplesPerBin)

        var outputSamples = [Float]()
        var sampleBuffer = Data()

        reader.startReading()
        defer { reader.cancelReading() }

        while reader.status == .reading {
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer)
            else { break }

            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil,
                dataPointerOut: &readBufferPointer)
            sampleBuffer.append(
                UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            CMSampleBufferInvalidate(readSampleBuffer)

            let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
            let downSampledLength = totalSamples / samplesPerBin
            let samplesToProcess = downSampledLength * samplesPerBin

            guard samplesToProcess > 0 else { continue }

            processSamples(
                fromData: &sampleBuffer,
                outputSamples: &outputSamples,
                samplesToProcess: samplesToProcess,
                downSampledLength: downSampledLength,
                samplesPerBin: samplesPerBin,
                filter: filter)
        }

        // Process remaining samples
        let samplesToProcess = sampleBuffer.count / MemoryLayout<Int16>.size
        if samplesToProcess > 0 {
            let downSampledLength = 1
            let samplesPerBin = samplesToProcess
            let filter = [Float](repeating: 1.0 / Float(samplesPerBin), count: samplesPerBin)

            processSamples(
                fromData: &sampleBuffer,
                outputSamples: &outputSamples,
                samplesToProcess: samplesToProcess,
                downSampledLength: downSampledLength,
                samplesPerBin: samplesPerBin,
                filter: filter)
        }

        return outputSamples
    }

    private func processSamples(
        fromData sampleBuffer: inout Data,
        outputSamples: inout [Float],
        samplesToProcess: Int,
        downSampledLength: Int,
        samplesPerBin: Int,
        filter: [Float]
    ) {
        sampleBuffer.withUnsafeBytes { bytes in
            guard let samples = bytes.bindMemory(to: Int16.self).baseAddress else {
                return
            }

            var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)
            let sampleCount = vDSP_Length(samplesToProcess)

            // Convert 16-bit int samples to floats
            vDSP_vflt16(samples, 1, &processingBuffer, 1, sampleCount)

            // Take absolute values to get amplitude
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)

            // Normalize to [0, 1] range (divide by 32768)
            var divisor: Float = 32768.0
            vDSP_vsdiv(processingBuffer, 1, &divisor, &processingBuffer, 1, sampleCount)

            // Downsample by averaging
            var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
            vDSP_desamp(
                processingBuffer,
                vDSP_Stride(samplesPerBin),
                filter, &downSampledData,
                vDSP_Length(downSampledLength),
                vDSP_Length(samplesPerBin))

            // Remove processed samples
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)

            outputSamples += downSampledData
        }
    }
}
