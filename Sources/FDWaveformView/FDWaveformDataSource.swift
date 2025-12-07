//
// Copyright (c) William Entriken and the FDWaveformView contributors
//

/// A source of audio sample data for waveform rendering.
///
/// All data returned by this protocol is in **linear amplitude scale**, not logarithmic (dB).
/// The `FDWaveformView` will apply logarithmic transformation internally if needed based on
/// the `waveformType` setting.
internal protocol FDWaveformDataSource {
  /// The total number of samples available from this data source.
  func numberOfSamples() async -> Int

  /// Returns the audio sample values for the specified range.
  /// - Parameter range: The range of sample indices to retrieve.
  /// - Returns: An array of normalized sample values in the range [-1.0, 1.0] (linear amplitude),
  ///   where -1.0 represents maximum negative amplitude, 1.0 represents maximum positive amplitude,
  ///   and 0.0 represents silence. Returns empty array if the samples cannot be read.
  func samples(in range: Range<Int>) async -> [Float]

  /// Returns the maximum absolute sample values across bins in the specified range.
  /// - Parameters:
  ///   - range: The range of sample indices to analyze.
  ///   - numberOfBins: The number of bins to divide the range into.
  /// - Returns: An array of absolute maximum values in the range [0.0, 1.0] (linear amplitude),
  ///   where 0.0 represents silence and 1.0 represents maximum amplitude. Each value represents
  ///   the peak amplitude within that bin. Returns empty array if the samples cannot be processed.
  func maximums(from range: Range<Int>, numberOfBins: Int) async -> [Float]

  /// Returns a fast, low-quality approximation of maximum absolute sample values.
  ///
  /// This method provides a quick preview by sampling a subset of the available data rather than
  /// analyzing all samples. This is useful for:
  /// - Displaying an initial waveform quickly while full-quality data loads
  /// - Progressive/incremental loading where a rough preview appears immediately
  /// - Zoom-out views where perfect accuracy is less important
  ///
  /// - Parameters:
  ///   - range: The range of sample indices to analyze.
  ///   - numberOfBins: The number of bins to divide the range into.
  /// - Returns: An array of approximate absolute maximum values in the range [0.0, 1.0]. The approximation may skip samples or use cached data. Returns empty array if the samples cannot be processed.
  // func quickMaximums(from range: Range<Int>, numberOfBins: Int) async -> [Float]
}
