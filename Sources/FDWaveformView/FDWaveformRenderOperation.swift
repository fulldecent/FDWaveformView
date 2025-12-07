//
// Copyright (c) William Entriken and the FDWaveformView contributors
//
import AVFoundation
import Accelerate
import UIKit

/// Format options for FDWaveformRenderOperation
//MAYBE: Make this public
struct FDWaveformRenderFormat {

  /// The type of waveform to render
  //TODO: make this public after reconciling FDWaveformView.WaveformType and FDWaveformType
  var type: FDWaveformType

  /// The color of the waveform
  internal var wavesColor: UIColor

  /// The scale factor to apply to the rendered image (usually the current screen's scale)
  public var scale: CGFloat

  public init() {
    self.init(
      type: .linear,
      wavesColor: .black,
      scale: UIScreen.main.scale)
  }

  init(type: FDWaveformType, wavesColor: UIColor, scale: CGFloat) {
    self.type = type
    self.wavesColor = wavesColor
    self.scale = scale
  }
}

/// Operation used for rendering waveform images
final class FDWaveformRenderOperation: Operation {

  /// When samples per pixel falls below this threshold, switch from binned maximums to individual samples
  private let samplesPerPixelThreshold = 2

  /// The data source used to build the waveform
  let dataSource: FDWaveformDataSource

  /// Size of waveform image to render
  let imageSize: CGSize

  /// Range of samples within audio asset to build waveform for
  let sampleRange: CountableRange<Int>

  /// Format of waveform image
  let format: FDWaveformRenderFormat

  // MARK: - NSOperation Overrides

  override var isAsynchronous: Bool { return true }

  private var _isExecuting = false
  override var isExecuting: Bool { return _isExecuting }

  private var _isFinished = false
  override var isFinished: Bool { return _isFinished }

  // MARK: - Private

  ///  Handler called when the rendering has completed. nil UIImage indicates that there was an error during processing.
  private let completionHandler: (UIImage?) -> Void

  /// Final rendered image. Used to hold image for completionHandler.
  private var renderedImage: UIImage?

  init(
    dataSource: FDWaveformDataSource, totalSamples: Int, imageSize: CGSize,
    sampleRange: CountableRange<Int>? = nil,
    format: FDWaveformRenderFormat = FDWaveformRenderFormat(),
    completionHandler: @escaping (_ image: UIImage?) -> Void
  ) {
    self.dataSource = dataSource
    self.imageSize = imageSize
    self.sampleRange = sampleRange ?? 0..<totalSamples
    self.format = format
    self.completionHandler = completionHandler

    super.init()

    self.completionBlock = { [weak self] in
      guard let `self` = self else { return }
      self.completionHandler(self.renderedImage)
      self.renderedImage = nil
    }
  }

  override func start() {
    guard !isExecuting && !isFinished && !isCancelled else { return }

    willChangeValue(forKey: "isExecuting")
    _isExecuting = true
    didChangeValue(forKey: "isExecuting")

    DispatchQueue.global(qos: .background).async { self.render() }
  }

  private func finish(with image: UIImage?) {
    guard !isFinished && !isCancelled else { return }

    renderedImage = image

    // completionBlock called automatically by NSOperation after these values change
    willChangeValue(forKey: "isExecuting")
    willChangeValue(forKey: "isFinished")
    _isExecuting = false
    _isFinished = true
    didChangeValue(forKey: "isExecuting")
    didChangeValue(forKey: "isFinished")
  }

  private func render() {
    guard
      !sampleRange.isEmpty,
      imageSize.width > 0, imageSize.height > 0
    else {
      finish(with: nil)
      return
    }

    let targetSamples = Int(imageSize.width * format.scale)

    Task {
      var amplitudes: [Float]
      var isSignedSamples = false

      // If we have fewer than samplesPerPixelThreshold samples per pixel, use individual samples
      // Otherwise, use binned maximums for efficiency
      if sampleRange.count <= targetSamples * samplesPerPixelThreshold {
        // Zoomed in: show individual signed samples (actual waveform)
        amplitudes = await dataSource.samples(in: sampleRange)
        isSignedSamples = true
      } else {
        // Zoomed out: use binned maximums (always positive)
        amplitudes = await dataSource.maximums(from: sampleRange, numberOfBins: targetSamples)
      }

      guard !amplitudes.isEmpty else {
        await MainActor.run { finish(with: nil) }
        return
      }

      // Apply logarithmic transformation only to amplitude data (not signed samples)
      if !isSignedSamples {
        format.type.process(normalizedSamples: &amplitudes)
      }

      let samples = amplitudes.map { CGFloat($0) }
      // Use fixed max of 1.0 to show faithful amplitude (not auto-scaled)
      let sampleMax: CGFloat = 1.0
      let sampleMin: CGFloat = isSignedSamples ? -1.0 : 0.0

      let image = plotWaveformGraph(
        samples, maximumValue: sampleMax, zeroValue: sampleMin, isSignedSamples: isSignedSamples)

      await MainActor.run { finish(with: image) }
    }
  }

  /// Read the asset and create a lower resolution set of samples
  // TODO: Implement sliceAsset if needed for backwards compatibility
  // This method is no longer used as we now use the dataSource protocol

  // TODO: report progress? (for issue #2)
  func plotWaveformGraph(
    _ samples: [CGFloat], maximumValue max: CGFloat, zeroValue min: CGFloat,
    isSignedSamples: Bool = false
  ) -> UIImage? {
    guard !isCancelled else { return nil }

    let imageSize = CGSize(
      width: CGFloat(samples.count) / format.scale,
      height: self.imageSize.height)

    UIGraphicsBeginImageContextWithOptions(imageSize, false, format.scale)
    defer { UIGraphicsEndImageContext() }
    guard let context = UIGraphicsGetCurrentContext() else {
      NSLog("FDWaveformView failed to get graphics context")
      return nil
    }
    context.scaleBy(x: 1 / format.scale, y: 1 / format.scale)
    context.setShouldAntialias(false)
    context.setAlpha(1.0)
    context.setLineWidth(1.0 / format.scale)
    context.setStrokeColor(format.wavesColor.cgColor)

    let verticalMiddle = (imageSize.height * format.scale) / 2

    if isSignedSamples {
      // Signed samples: draw connected waveform line
      // samples are in range [-1, 1], scale to half the image height
      let sampleDrawingScale = (imageSize.height * format.scale) / 2

      // Draw connected line between samples for smooth waveform
      if samples.count > 1 {
        context.beginPath()
        let firstY = verticalMiddle - samples[0] * sampleDrawingScale
        context.move(to: CGPoint(x: 0, y: firstY))
        for (x, sample) in samples.enumerated().dropFirst() {
          let y = verticalMiddle - sample * sampleDrawingScale
          context.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        context.strokePath()
      } else if samples.count == 1 {
        let y = verticalMiddle - samples[0] * sampleDrawingScale
        context.move(to: CGPoint(x: 0, y: verticalMiddle))
        context.addLine(to: CGPoint(x: 0, y: y))
        context.strokePath()
      }
    } else {
      // Amplitude samples: draw symmetric around center
      let sampleDrawingScale: CGFloat
      if max == min {
        sampleDrawingScale = 0
      } else {
        sampleDrawingScale = (imageSize.height * format.scale) / 2 / (max - min)
      }
      for (x, sample) in samples.enumerated() {
        let height = (sample - min) * sampleDrawingScale
        context.move(to: CGPoint(x: CGFloat(x), y: verticalMiddle - height))
        context.addLine(to: CGPoint(x: CGFloat(x), y: verticalMiddle + height))
        context.strokePath()
      }
    }

    guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
      NSLog("FDWaveformView failed to get waveform image from context")
      return nil
    }

    return image
  }
}

extension AVAssetReader.Status: CustomStringConvertible {
  public var description: String {
    switch self {
    case .reading: return "reading"
    case .unknown: return "unknown"
    case .completed: return "completed"
    case .failed: return "failed"
    case .cancelled: return "cancelled"
    @unknown default:
      fatalError()
    }
  }
}
