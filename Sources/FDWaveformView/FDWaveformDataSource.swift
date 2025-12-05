//
// Copyright William Entriken and the FDWaveformView contributors.
//

import Foundation

/// A protocol that provides audio sample data for waveform rendering.
///
/// Implement this protocol to create custom data sources such as:
/// - File-based audio (see `FDAudioContext`)
/// - Streaming audio
/// - Procedurally generated audio (e.g., sine waves)
/// - Pre-computed sample arrays
///
/// ## Sample Format Contract
///
/// The `readSamples(in:)` method must return samples in the range **-1.0 to 1.0**,
/// representing the raw audio waveform (signed PCM). This matches the output of
/// `AVAudioPCMBuffer.floatChannelData` and Core Audio conventions.
///
/// The **renderer** is responsible for:
/// - Converting to absolute amplitude (`vDSP_vabs`) if needed
/// - Applying logarithmic scaling for dB display
/// - Any other visualization transformations
public protocol FDWaveformDataSource: AnyObject {

    /// Total number of samples available from this data source.
    var sampleCount: Int { get }

    /// Sample rate in samples per second (e.g., 44100 for CD quality).
    var sampleRate: Double { get }

    /// Number of audio channels (1 for mono, 2 for stereo).
    /// Samples returned by `readSamples` should be mixed to mono.
    var channelCount: Int { get }

    /// Read samples for a given range.
    ///
    /// - Parameter range: The range of sample indices to read.
    /// - Returns: An array of Float values in the range **-1.0 to 1.0** representing
    ///            the raw audio waveform. For multi-channel sources, samples should
    ///            be mixed down to mono.
    /// - Throws: `FDWaveformDataSourceError` if samples cannot be read.
    func readSamples(in range: Range<Int>) throws -> [Float]
}

/// Errors that can occur when reading samples from a data source.
public enum FDWaveformDataSourceError: Error {
    /// The requested range is outside the bounds of available samples.
    case rangeOutOfBounds

    /// The data source is not ready to provide samples.
    case notReady

    /// Failed to read samples from the underlying source.
    case readFailed(underlying: Error?)
}
