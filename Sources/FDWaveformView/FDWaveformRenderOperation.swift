//
// Copyright 2013 - 2017, William Entriken and the FDWaveformView contributors.
//
import UIKit
import AVFoundation
import Accelerate

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
    
    /// Whether the resulting image size should be as close as possible to imageSize (approximate)
    /// or whether it should match it exactly. Right now there is no support for matching exactly.
    // TODO: Support rendering operations that always match the desired imageSize passed in.
    //       Right now the imageSize passed in to the render operation might not match the
    //       resulting image's size. This flag is hard coded here to convey that.
    public let constrainImageSizeToExactlyMatch = false
    
    // To make these public, you must implement them
    // See http://stackoverflow.com/questions/26224693/how-can-i-make-public-by-default-the-member-wise-initialiser-for-structs-in-swif
    public init() {
        self.init(type: .linear,
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
final public class FDWaveformRenderOperation: Operation {
    
    /// Where we get data from
    let dataSource: FDAudioSource
    
    /// Size of waveform image to render
    public let imageSize: CGSize
    
    /// Range of samples within audio asset to build waveform for
    public let sampleRange: CountableRange<Int>
    
    /// Format of waveform image
    let format: FDWaveformRenderFormat
    
    // MARK: - NSOperation Overrides
    
    public override var isAsynchronous: Bool { return true }
    
    private var _isExecuting = false
    public override var isExecuting: Bool { return _isExecuting }
    
    private var _isFinished = false
    public override var isFinished: Bool { return _isFinished }
    
    // MARK: - Private
    
    ///  Handler called when the rendering has completed. nil UIImage indicates that there was an error during processing.
    private let completionHandler: (UIImage?) -> ()
    
    /// Final rendered image. Used to hold image for completionHandler.
    private var renderedImage: UIImage?
    
    init(dataSource: FDAudioSource, imageSize: CGSize, sampleRange: CountableRange<Int>? = nil, format: FDWaveformRenderFormat = FDWaveformRenderFormat(), completionHandler: @escaping (_ image: UIImage?) -> ()) {
        self.dataSource = dataSource
        self.imageSize = imageSize
        self.sampleRange = sampleRange ?? dataSource.startIndex..<dataSource.endIndex
        self.format = format
        self.completionHandler = completionHandler
        
        super.init()
        
        self.completionBlock = { [weak self] in
            guard let `self` = self else { return }
            self.completionHandler(self.renderedImage)
            self.renderedImage = nil
        }
    }
    
    public override func start() {
        guard !isExecuting && !isFinished && !isCancelled else { return }
        
        willChangeValue(forKey: "isExecuting")
        _isExecuting = true
        didChangeValue(forKey: "isExecuting")
        
        if #available(iOS 8.0, *) {
            DispatchQueue.global(qos: .background).async { self.render() }
        } else {
            DispatchQueue.global(priority: .background).async { self.render() }
        }
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
        
        let image: UIImage? = {
            guard
                let (samples, sampleMax) = sliceAsset(withRange: sampleRange, andDownsampleTo: targetSamples),
                let image = plotWaveformGraph(samples, maximumValue: sampleMax, zeroValue: format.type.floorValue)
                else { return nil }
            
            return image
        }()
        
        finish(with: image)
    }
    
    /// Read the asset and create a lower resolution set of samples
    
    /// Get data and downsample to an approximate size
    /// - Parameters:
    ///   - slice: Samples to get
    ///   - targetSamples: Requested minimum outputsize
    /// - Returns: An array of samples at least as large as targetSamples
    func sliceAsset(withRange slice: CountableRange<Int>, andDownsampleTo targetSamples: Int) -> (samples: [Float], sampleMax: Float)? {
        guard !isCancelled,
              !slice.isEmpty,
              targetSamples != 0,
              var inputSampleData = try? dataSource.readSampleData(bounds: slice) else { return nil }
        
        let inputSampleCount = inputSampleData.count / MemoryLayout<Int16>.size
        let downsampleFactor = max(1, inputSampleCount / targetSamples)
        let averagingFilter = [Float](repeating: 1.0 / Float(downsampleFactor), count: downsampleFactor)
        let outputSampleCount = inputSampleCount / downsampleFactor

        var outputSamples = [Float](repeating: 0.0, count: outputSampleCount)
        var outputSampleMax: Float = .nan

        inputSampleData.withUnsafeBytes { bytes in
            guard let inputSampleInt16Data = bytes.bindMemory(to: Int16.self).baseAddress else {
                return
            }
            
            var inputSamples = [Float](repeating: 0.0, count: inputSampleCount)
            
            // Convert 16-bit Int samples to Floats
            vDSP_vflt16(inputSampleInt16Data, 1, &inputSamples, 1, vDSP_Length(inputSampleCount))
            
            // Take the absolute values to get amplitude
            vDSP_vabs(inputSamples, 1, &inputSamples, 1, vDSP_Length(inputSampleCount))
            
            // Let current type further process the samples
            format.type.process(normalizedSamples: &inputSamples)
            
            // Downsample and average
            vDSP_desamp(inputSamples,
                        vDSP_Stride(downsampleFactor),
                        averagingFilter,
                        &outputSamples,
                        vDSP_Length(outputSampleCount),
                        vDSP_Length(downsampleFactor))
            
            // Find maximum value
            vDSP_maxv(outputSamples, 1, &outputSampleMax, vDSP_Length(outputSampleCount))
        }
        
        return (outputSamples, outputSampleMax)
    }
    
    func plotWaveformGraph(_ samples: [Float], maximumValue max: Float, zeroValue min: Float) -> UIImage? {
        guard !isCancelled else { return nil }
        
        let imageSize = CGSize(width: CGFloat(samples.count) / format.scale,
                               height: self.imageSize.height)
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, format.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else {
            NSLog("FDWaveformView failed to get graphics context")
            return nil
        }
        context.scaleBy(x: 1 / format.scale, y: 1 / format.scale) // Scale context to account for scaling applied to image
        context.setShouldAntialias(false)
        context.setAlpha(1.0)
        context.setLineWidth(1.0 / format.scale)
        context.setStrokeColor(format.wavesColor.cgColor)
        
        let sampleDrawingScale: CGFloat
        if max == min {
            sampleDrawingScale = 0
        } else {
            sampleDrawingScale = (imageSize.height * format.scale) / 2 / CGFloat(max - min)
        }
        let verticalMiddle = (imageSize.height * format.scale) / 2
        for (x, sample) in samples.enumerated() {
            let height = CGFloat(sample - min) * sampleDrawingScale
            context.move(to: CGPoint(x: CGFloat(x), y: verticalMiddle - height))
            context.addLine(to: CGPoint(x: CGFloat(x), y: verticalMiddle + height))
            context.strokePath();
        }
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            NSLog("FDWaveformView failed to get waveform image from context")
            return nil
        }
        
        return image
    }
}

extension AVAssetReader.Status : CustomStringConvertible{
    public var description: String{
        switch self{
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

