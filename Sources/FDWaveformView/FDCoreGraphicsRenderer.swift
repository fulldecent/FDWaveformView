//
// Copyright William Entriken and the FDWaveformView contributors.
//

import Accelerate
import UIKit

/// A waveform renderer using Core Graphics that draws vertical lines for each sample.
///
/// This is the traditional FDWaveformView rendering style.
///
/// Example:
/// ```swift
/// let renderer = FDCoreGraphicsRenderer(
///     waveColor: .systemBlue,
///     waveformType: .logarithmic(noiseFloor: -50),
///     scale: UIScreen.main.scale
/// )
/// let image = renderer.render(samples: samples, size: CGSize(width: 300, height: 100))
/// ```
public final class FDCoreGraphicsRenderer: FDWaveformRenderer {

    /// Color of the waveform.
    public let waveColor: UIColor

    /// The type of amplitude processing (linear or logarithmic).
    public let waveformType: FDWaveformType

    /// Scale factor for rendering (usually screen scale).
    public let scale: CGFloat

    /// Creates a Core Graphics waveform renderer.
    ///
    /// - Parameters:
    ///   - waveColor: Color of the waveform. Default is black.
    ///   - waveformType: Amplitude processing type. Default is linear.
    ///   - scale: Scale factor for rendering. Default is main screen scale.
    public init(
        waveColor: UIColor = .black,
        waveformType: FDWaveformType = .linear,
        scale: CGFloat = UIScreen.main.scale
    ) {
        self.waveColor = waveColor
        self.waveformType = waveformType
        self.scale = scale
    }

    public func preferredSampleCount(forWidth width: CGFloat) -> Int {
        // One sample per pixel for crisp rendering
        return Int(width * scale)
    }

    public func render(samples: [Float], size: CGSize) -> UIImage? {
        guard !samples.isEmpty, size.width > 0, size.height > 0 else {
            return nil
        }

        // Process samples through the waveform type (linear/logarithmic)
        var processedSamples = samples
        waveformType.process(normalizedSamples: &processedSamples)

        // Take absolute values for amplitude
        vDSP_vabs(processedSamples, 1, &processedSamples, 1, vDSP_Length(processedSamples.count))

        // Find max value for normalization
        var maxValue: Float = 0
        vDSP_maxv(processedSamples, 1, &maxValue, vDSP_Length(processedSamples.count))
        let minValue = waveformType.floorValue

        let imageSize = CGSize(
            width: CGFloat(processedSamples.count) / scale,
            height: size.height
        )

        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.scaleBy(x: 1 / scale, y: 1 / scale)
        context.setShouldAntialias(false)
        context.setAlpha(1.0)
        context.setLineWidth(1.0 / scale)
        context.setStrokeColor(waveColor.cgColor)

        let sampleDrawingScale: CGFloat
        if CGFloat(maxValue) == minValue {
            sampleDrawingScale = 0
        } else {
            sampleDrawingScale = (imageSize.height * scale) / 2 / (CGFloat(maxValue) - minValue)
        }

        let verticalMiddle = (imageSize.height * scale) / 2

        for (x, sample) in processedSamples.enumerated() {
            let height = (CGFloat(sample) - minValue) * sampleDrawingScale
            context.move(to: CGPoint(x: CGFloat(x), y: verticalMiddle - height))
            context.addLine(to: CGPoint(x: CGFloat(x), y: verticalMiddle + height))
            context.strokePath()
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

/// A bar-style waveform renderer similar to SoundCloud.
///
/// This renderer draws rounded rectangular bars instead of continuous lines.
///
/// Example:
/// ```swift
/// let renderer = FDBarRenderer(
///     waveColor: .systemBlue,
///     barWidth: 3,
///     gap: 2,
///     cornerRadius: 1.5
/// )
/// let image = renderer.render(samples: samples, size: CGSize(width: 300, height: 100))
/// ```
public final class FDBarRenderer: FDWaveformRenderer {

    /// Color of the bars.
    public let waveColor: UIColor

    /// Width of each bar in points.
    public let barWidth: CGFloat

    /// Gap between bars in points.
    public let gap: CGFloat

    /// Corner radius for rounded bar ends.
    public let cornerRadius: CGFloat

    /// The type of amplitude processing (linear or logarithmic).
    public let waveformType: FDWaveformType

    /// Scale factor for rendering (usually screen scale).
    public let scale: CGFloat

    /// Creates a bar-style waveform renderer.
    ///
    /// - Parameters:
    ///   - waveColor: Color of the bars. Default is black.
    ///   - barWidth: Width of each bar in points. Default is 3.
    ///   - gap: Gap between bars in points. Default is 2.
    ///   - cornerRadius: Corner radius for rounded ends. Default is half of barWidth.
    ///   - waveformType: Amplitude processing type. Default is linear.
    ///   - scale: Scale factor for rendering. Default is main screen scale.
    public init(
        waveColor: UIColor = .black,
        barWidth: CGFloat = 3,
        gap: CGFloat = 2,
        cornerRadius: CGFloat? = nil,
        waveformType: FDWaveformType = .linear,
        scale: CGFloat = UIScreen.main.scale
    ) {
        self.waveColor = waveColor
        self.barWidth = barWidth
        self.gap = gap
        self.cornerRadius = cornerRadius ?? (barWidth / 2)
        self.waveformType = waveformType
        self.scale = scale
    }

    public func preferredSampleCount(forWidth width: CGFloat) -> Int {
        // One sample per bar
        let barSpacing = barWidth + gap
        return max(1, Int(width / barSpacing))
    }

    public func render(samples: [Float], size: CGSize) -> UIImage? {
        guard !samples.isEmpty, size.width > 0, size.height > 0 else {
            return nil
        }

        // Process samples through the waveform type (linear/logarithmic)
        var processedSamples = samples
        waveformType.process(normalizedSamples: &processedSamples)

        // Take absolute values for amplitude
        vDSP_vabs(processedSamples, 1, &processedSamples, 1, vDSP_Length(processedSamples.count))

        // Find max value for normalization
        var maxValue: Float = 0
        vDSP_maxv(processedSamples, 1, &maxValue, vDSP_Length(processedSamples.count))
        let minValue = waveformType.floorValue

        // Calculate how many bars we can fit
        let barSpacing = barWidth + gap
        let barCount = Int(size.width / barSpacing)

        guard barCount > 0 else { return nil }

        // Downsample to number of bars
        let samplesPerBar = max(1, processedSamples.count / barCount)
        var barValues = [Float](repeating: 0, count: barCount)

        for i in 0..<barCount {
            let startIndex = i * samplesPerBar
            let endIndex = min(startIndex + samplesPerBar, processedSamples.count)

            if startIndex < processedSamples.count {
                // Use max value in the range for this bar
                var maxInRange: Float = 0
                let rangeCount = vDSP_Length(endIndex - startIndex)
                vDSP_maxv(
                    Array(processedSamples[startIndex..<endIndex]), 1, &maxInRange, rangeCount)
                barValues[i] = maxInRange
            }
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setFillColor(waveColor.cgColor)

        let drawingScale: CGFloat
        if CGFloat(maxValue) == minValue {
            drawingScale = 0
        } else {
            drawingScale = size.height / (CGFloat(maxValue) - minValue)
        }

        let verticalMiddle = size.height / 2

        for (i, value) in barValues.enumerated() {
            let height = (CGFloat(value) - minValue) * drawingScale
            let x = CGFloat(i) * barSpacing

            // Draw bar centered vertically
            let rect = CGRect(
                x: x,
                y: verticalMiddle - height / 2,
                width: barWidth,
                height: max(height, 1 / scale)  // Minimum 1 pixel height
            )

            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            context.fillPath()
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
