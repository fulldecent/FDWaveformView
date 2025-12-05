//
// Copyright William Entriken and the FDWaveformView contributors.
//

import UIKit

/// A protocol for rendering waveform samples to an image.
///
/// Renderers are configured at initialization time with their specific style options.
/// The view should call `preferredSampleCount` to determine how many samples to provide,
/// then pass that many samples to `render`.
///
/// ## Sample Format Contract
///
/// The `render` method receives samples in the range **-1.0 to 1.0** (signed PCM format),
/// as provided by `FDWaveformDataSource`. The renderer is responsible for:
/// - Converting to absolute amplitude using `vDSP_vabs` if needed
/// - Applying logarithmic (dB) scaling via `FDWaveformType.process` if configured
/// - Drawing the final visualization
///
/// Example:
/// ```swift
/// let renderer = FDCoreGraphicsRenderer(waveColor: .blue, scale: 2.0)
/// let sampleCount = renderer.preferredSampleCount(forWidth: 300)
/// // ... resample audio data to sampleCount samples ...
/// let image = renderer.render(samples: samples, size: CGSize(width: 300, height: 100))
/// ```
public protocol FDWaveformRenderer {

    /// The preferred number of samples for rendering at the given width.
    ///
    /// The view should resample the audio data to approximately this many samples
    /// before calling `render`. Providing more samples is wasteful; providing fewer
    /// may degrade visual quality.
    ///
    /// - Parameter width: The width of the target image in points.
    /// - Returns: The preferred number of samples.
    func preferredSampleCount(forWidth width: CGFloat) -> Int

    /// Render samples to a waveform image.
    ///
    /// - Parameters:
    ///   - samples: Array of sample values in the range -1.0 to 1.0 (signed PCM format).
    ///              Ideally `samples.count` should match `preferredSampleCount(forWidth: size.width)`.
    ///   - size: The target size for the output image in points.
    /// - Returns: The rendered waveform image, or nil if rendering failed.
    func render(samples: [Float], size: CGSize) -> UIImage?
}
