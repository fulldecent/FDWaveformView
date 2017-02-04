//
//  FDWaveformView
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2016 William Entriken. All rights reserved.
//
import UIKit
import MediaPlayer
import AVFoundation
import Accelerate

// FROM http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader
// DO SEE http://stackoverflow.com/questions/1191868/uiimageview-scaling-interpolation
// see http://stackoverflow.com/questions/3514066/how-to-tint-a-transparent-png-image-in-iphone

/// A view for rendering audio waveforms
// @IBDesignable
open class FDWaveformView: UIView {
    /// A delegate to accept progress reporting
    @IBInspectable open weak var delegate: FDWaveformViewDelegate?

    /// The audio file to render
    @IBInspectable open var audioURL: URL? {
        didSet {
            guard let audioURL = audioURL else {
                NSLog("FDWaveformView received nil audioURL")
                audioContext = nil
                return
            }

            loadingInProgress = true
            delegate?.waveformViewWillLoad?(self)
            
            // TODO: weak self here?
            // TODO: need to cancel previous loads? Can use nsoperation with block to cancel?
            FDAudioContext.load(fromAudioURL: audioURL) { audioContext in
                DispatchQueue.main.async {
                    if audioContext == nil {
                        NSLog("FDWaveformView failed to load URL")
                    }
                    
                    self.audioContext = audioContext // This will reset the view and kick off a layout
                    
                    self.loadingInProgress = false
                    self.delegate?.waveformViewDidLoad?(self)
                }
            }
        }
    }

    /// The total number of audio samples in the file
    open var totalSamples: Int {
        return audioContext?.totalSamples ?? 0
    }

    /// A portion of the waveform rendering to be highlighted
    @IBInspectable open var progressSamples = 0 {
        didSet {
            if totalSamples > 0 {
                let progress = CGFloat(progressSamples) / CGFloat(totalSamples)
                clipping.frame = CGRect(x: 0, y: 0, width: frame.width * progress, height: frame.height)
                setNeedsLayout()
            }
        }
    }

    //TODO:  MAKE THIS A RANGE, CAN IT BE ANIMATABLE??!

    /// The first sample to render
    @IBInspectable open var zoomStartSamples = 0 {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }

    /// One plus the last sample to render
    @IBInspectable open var zoomEndSamples = 0 {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }

    /// Whether to all the scrub gesture
    @IBInspectable open var doesAllowScrubbing = true

    /// Whether to allow the stretch gesture
    @IBInspectable open var doesAllowStretch = true

    /// Whether to allow the scroll gesture
    @IBInspectable open var doesAllowScroll = true

    /// The color of the waveform
    @IBInspectable open var wavesColor = UIColor.black {
        didSet {
            imageView.tintColor = wavesColor
        }
    }

    /// The color of the highlighted waveform (see `progressSamples`
    @IBInspectable open var progressColor = UIColor.blue {
        didSet {
            highlightedImage.tintColor = progressColor
        }
    }


    //TODO MAKE PUBLIC

    // Drawing a larger image than needed to have it available for scrolling
    fileprivate var horizontalMinimumBleed: CGFloat = 0.1
    fileprivate var horizontalMaximumBleed: CGFloat = 3.0
    fileprivate var horizontalTargetBleed: CGFloat = 0.5

    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var horizontalMinimumOverdraw: CGFloat = 2.0

    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var horizontalMaximumOverdraw: CGFloat = 5.0

    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var horizontalTargetOverdraw: CGFloat = 3.0

    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var verticalMinimumOverdraw: CGFloat = 1.0

    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var verticalMaximumOverdraw: CGFloat = 3.0

    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var verticalTargetOverdraw: CGFloat = 2.0

    /// The "zero" level (in dB)
    fileprivate let noiseFloor: CGFloat = -50.0



    // Mark - Private vars

    /// Current audio context to be used for rendering
    private var audioContext: FDAudioContext? {
        didSet {
            waveformImage = nil
            progressSamples = 0
            zoomStartSamples = 0
            zoomEndSamples = totalSamples
            waveformRenderOperation = nil
            
            setNeedsDisplay()
            setNeedsLayout()
        }
    }
    
    /// Currently running renderer
    private var waveformRenderOperation: FDWaveformRenderOperation? {
        willSet {
            if newValue !== waveformRenderOperation {
                print("cancelling")
                waveformRenderOperation?.cancel()
            }
        }
    }
    
    /// Image of waveform
    private var waveformImage: UIImage? {
        get { return imageView.image }
        set {
            // This will allow us to apply a tint color to the image
            imageView.image = newValue?.withRenderingMode(.alwaysTemplate)
            highlightedImage.image = imageView.image
        }
    }
    
    //TODO RENAME
    fileprivate func minMaxX<T: Comparable>(_ x: T, min: T, max: T) -> T {
        return x < min ? min : x > max ? max : x
    }

    fileprivate func decibel(_ amplitude: CGFloat) -> CGFloat {
        return 20.0 * log10(abs(amplitude))
    }

    /// View for rendered waveform
    lazy fileprivate var imageView: UIImageView = {
        let retval = UIImageView(frame: CGRect.zero)
        retval.contentMode = .scaleToFill
        retval.tintColor = self.wavesColor
        return retval
    }()

    /// View for rendered waveform showing progress
    lazy fileprivate var highlightedImage: UIImageView = {
        let retval = UIImageView(frame: CGRect.zero)
        retval.contentMode = .scaleToFill
        retval.tintColor = self.progressColor
        return retval
    }()

    /// A view which hides part of the highlighted image
    fileprivate let clipping: UIView = {
        let retval = UIView(frame: CGRect.zero)
        retval.clipsToBounds = true
        return retval
    }()

    /// The range of samples we rendered
    fileprivate var cachedSampleRange = 0..<0

    /// Gesture recognizer
    fileprivate var pinchRecognizer = UIPinchGestureRecognizer()

    /// Gesture recognizer
    fileprivate var panRecognizer = UIPanGestureRecognizer()

    /// Gesture recognizer
    fileprivate var tapRecognizer = UITapGestureRecognizer()

    /// Whether rendering is happening asynchronously
    fileprivate var renderingInProgress = false

    /// Whether loading is happening asynchronously
    fileprivate var loadingInProgress = false

    func setup() {
        addSubview(imageView)
        clipping.addSubview(highlightedImage)
        addSubview(clipping)
        clipsToBounds = true

        setupGestureRecognizers()
    }

    fileprivate func setupGestureRecognizers() {
        //TODO: try to do this in the lazy initializer above
        pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture))
        pinchRecognizer.delegate = self
        addGestureRecognizer(pinchRecognizer)
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panRecognizer.delegate = self
        addGestureRecognizer(panRecognizer)
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        addGestureRecognizer(tapRecognizer)
    }

    required public init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        setup()
    }

    override init(frame rect: CGRect) {
        super.init(frame: rect)
        setup()
    }

    /// If the cached image is insufficient for the current frame
    fileprivate func cacheIsDirty() -> Bool {
        guard let image = waveformImage else { return true }
        
        if cachedSampleRange.count == 0 {
            return true
        }
        if cachedSampleRange.lowerBound < minMaxX(zoomStartSamples - Int(CGFloat(cachedSampleRange.count) * horizontalMaximumBleed), min: 0, max: totalSamples) {
            return true
        }
        if cachedSampleRange.lowerBound > minMaxX(zoomStartSamples - Int(CGFloat(cachedSampleRange.count) * horizontalMinimumBleed), min: 0, max: totalSamples) {
            return true
        }
        if cachedSampleRange.upperBound < minMaxX(zoomEndSamples + Int(CGFloat(cachedSampleRange.count) * horizontalMinimumBleed), min: 0, max: totalSamples) {
            return true
        }
        if cachedSampleRange.upperBound > minMaxX(zoomEndSamples + Int(CGFloat(cachedSampleRange.count) * horizontalMaximumBleed), min: 0, max: totalSamples) {
            return true
        }
        if image.size.width < frame.width * UIScreen.main.scale * CGFloat(horizontalMinimumOverdraw) {
            return true
        }
        if image.size.width > frame.width * UIScreen.main.scale * CGFloat(horizontalMaximumOverdraw) {
            return true
        }
        if image.size.height < frame.height * UIScreen.main.scale * CGFloat(verticalMinimumOverdraw) {
            return true
        }
        if image.size.height > frame.height * UIScreen.main.scale * CGFloat(verticalMaximumOverdraw) {
            return true
        }
        return false
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        guard audioContext != nil && !renderingInProgress && zoomEndSamples > 0 else {
            return
        }

        guard !cacheIsDirty() else {
            renderWaveform()
            return
        }

        let zoomSamples = zoomStartSamples ..< zoomEndSamples

        // We need to place the images which have samples in `cachedSampleRange`
        // inside our frame which represents `startSamples..<endSamples`
        // all figures are a portion of our frame width
        var scaledX: CGFloat = 0.0
        var scaledProgressWidth: CGFloat = 0.0
        var scaledWidth: CGFloat = 1.0
        if cachedSampleRange.count > 0 && zoomSamples.count > 0 {
            scaledX = CGFloat(cachedSampleRange.lowerBound - zoomSamples.lowerBound) / CGFloat(zoomSamples.count)
            scaledWidth = CGFloat(cachedSampleRange.last! - zoomSamples.lowerBound) / CGFloat(zoomSamples.count)    // forced unwrap is safe
            scaledProgressWidth = CGFloat(progressSamples - zoomSamples.lowerBound) / CGFloat(zoomSamples.count)
        }
        let childFrame = CGRect(x: frame.width * scaledX, y: 0, width: frame.width * scaledWidth, height: frame.height)
        imageView.frame = childFrame
        highlightedImage.frame = childFrame
        clipping.frame = CGRect(x: 0, y: 0, width: frame.width * scaledProgressWidth, height: frame.height)
        clipping.isHidden = progressSamples <= zoomStartSamples
        print("\(frame) -- \(imageView.frame)")
    }

    func renderWaveform() {
        guard
            !renderingInProgress,
            let audioContext = audioContext
            else { return }

        print("rendering")
        
        renderingInProgress = true
        delegate?.waveformViewWillRender?(self)
        
        let displayRange = zoomEndSamples - zoomStartSamples
        guard displayRange > 0 else { return }

        let renderStartSamples = minMaxX(zoomStartSamples - Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderEndSamples = minMaxX(zoomEndSamples + Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderSampleRange = renderStartSamples..<renderEndSamples
        let widthInPixels = floor(frame.width * UIScreen.main.scale * horizontalTargetOverdraw)
        let heightInPixels = frame.height * UIScreen.main.scale * horizontalTargetOverdraw // TODO: Vertical target overdraw?

        let waveformRenderOperation = FDWaveformRenderOperation(audioContext: audioContext) { image in
            DispatchQueue.main.async {
                print("done")
                self.waveformImage = image
                self.cachedSampleRange = renderSampleRange
                self.renderingInProgress = false
                self.setNeedsLayout()
                self.delegate?.waveformViewDidRender?(self)
            }
        }
        self.waveformRenderOperation = waveformRenderOperation
        // TODO: set other values here or require a context to be passed in
        waveformRenderOperation.sampleRange = renderSampleRange
        waveformRenderOperation.imageSize = CGSize(width: widthInPixels, height: heightInPixels)
        waveformRenderOperation.horizontalTargetOverdraw = horizontalTargetOverdraw
        waveformRenderOperation.verticalTargetOverdraw = verticalTargetOverdraw
        waveformRenderOperation.noiseFloor = noiseFloor
        waveformRenderOperation.start()
    }
}

// TODO: needed?
struct FDWaveformRenderContext {
    
    public var imageSize: CGSize = .zero // TODO: better starting value? Require it for init?
    
    /// The color of the waveform
    public var wavesColor = UIColor.black
    
}

final public class FDAudioContext {
    
    public let audioURL: URL
    
    fileprivate let totalSamples: Int
    fileprivate let asset: AVAsset
    fileprivate let assetTrack: AVAssetTrack
    
    private init(audioURL: URL, totalSamples: Int, asset: AVAsset, assetTrack: AVAssetTrack) {
        self.audioURL = audioURL
        self.totalSamples = totalSamples
        self.asset = asset
        self.assetTrack = assetTrack
    }
    
    public static func load(fromAudioURL audioURL: URL, completionHandler: @escaping (_ audioContext: FDAudioContext?) -> ()) {
        let asset = AVURLAsset(url: audioURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true as Bool)])
        
        guard let assetTrack = asset.tracks(withMediaType: AVMediaTypeAudio).first else {
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
                    let audioFormatDesc = assetTrack.formatDescriptions.first,
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc as! CMAudioFormatDescription) // TODO: Can this be safer?
                    else { break }
                
                let totalSamples = Int((asbd.pointee.mSampleRate) * Float64(asset.duration.value) / Float64(asset.duration.timescale))
                let audioContext = FDAudioContext(audioURL: audioURL, totalSamples: totalSamples, asset: asset, assetTrack: assetTrack)
                completionHandler(audioContext)
                return
                
            case .failed, .cancelled, .loading, .unknown:
                print("FDWaveformView could not load asset: \(error?.localizedDescription)")
            }
            
            completionHandler(nil)
        }
    }
}

// TODO: ++++++++++++++ Consider having a separate class to load the audio file? And that's passed in here?
//       Or passed into the render function? Although that will still have the same issue where there is shared
//       state between render calls.
//       What we need is some way to turn these into discrete operations or tasks that are only run once and are cancellable.
//       How long does it take to get the duration? If it's not long it's not a big deal to load the asset every time, right?
final public class FDWaveformRenderOperation: Operation {
    
    // TODO: document and clean up
    public let audioContext: FDAudioContext
    private let completionHandler: (UIImage?) -> ()
    
    public var sampleRange: CountableRange<Int>
    public var imageSize: CGSize = .zero
    public var wavesColor: UIColor = .black

    // TODO: need to set these three below when rendering
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var horizontalTargetOverdraw: CGFloat = 3.0
    
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    fileprivate var verticalTargetOverdraw: CGFloat = 2.0 // TODO: not used??
    
    /// The "zero" level (in dB)
    fileprivate var noiseFloor: CGFloat = -50.0
    
    public override var isAsynchronous: Bool { return true }
    
    private var _isExecuting = false
    public override var isExecuting: Bool { return _isExecuting }
    
    private var _isFinished = false
    public override var isFinished: Bool { return _isFinished }
    
    private var renderedImage: UIImage?
    
    public init(audioContext: FDAudioContext, completionHandler: @escaping (_ image: UIImage?) -> ()) {
        self.audioContext = audioContext
        self.completionHandler = completionHandler
        
        self.sampleRange = 0..<audioContext.totalSamples
        
        super.init()
        
        self.completionBlock = { [weak self] in
            guard let `self` = self else { return }
            self.completionHandler(self.renderedImage)
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
        
        willChangeValue(forKey: "isExecuting")
        willChangeValue(forKey: "isFinished")
        _isExecuting = false
        _isFinished = true
        didChangeValue(forKey: "isExecuting")
        didChangeValue(forKey: "isFinished")
    }
    
    private func render() {
        guard !sampleRange.isEmpty else {
            finish(with: nil)
            return
        }
        
        let image: UIImage? = {
            guard
                let (samples, sampleMax) = sliceAsset(withRange: sampleRange, andDownsampleTo: Int(imageSize.width)),
                let image = plotLogGraph(samples, maximumValue: sampleMax, zeroValue: self.noiseFloor, imageHeight: self.imageSize.height)
            else { return nil }
            
            return image
        }()
        
        finish(with: image)
    }

    /// Read the asset and create create a lower resolution set of samples
    func sliceAsset(withRange slice: CountableRange<Int>, andDownsampleTo targetSamples: Int) -> (samples: [CGFloat], sampleMax: CGFloat)? {
        guard
            !slice.isEmpty,
            let reader = try? AVAssetReader(asset: audioContext.asset)
            else { return nil }
        
        reader.timeRange = CMTimeRange(start: CMTime(value: Int64(slice.lowerBound), timescale: audioContext.asset.duration.timescale),
                                       duration: CMTime(value: Int64(slice.count), timescale: audioContext.asset.duration.timescale))
        let outputSettingsDict: [String : Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: audioContext.assetTrack, outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        var channelCount = 1
        let formatDesc = audioContext.assetTrack.formatDescriptions
        for item in formatDesc {
            // TODO: handle error here
            guard let fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item as! CMAudioFormatDescription) else { return nil }    // TODO: Can the forced downcast in here be safer?
            channelCount = Int(fmtDesc.pointee.mChannelsPerFrame)
        }

        var sampleMax = noiseFloor
        // TODO: bad things happen if target samples is 0
        let samplesPerPixel = max(1, channelCount * slice.count / targetSamples)
        let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)

        var outputSamples = [CGFloat]()
        var sampleBuffer = Data()

        // 16-bit samples
        reader.startReading()

        while reader.status == .reading {
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else {
                    break
            }

            // Append audio sample buffer into our current sample buffer
            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(readBuffer, 0, &readBufferLength, nil, &readBufferPointer)
            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            CMSampleBufferInvalidate(readSampleBuffer)

            let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
            let downSampledLength = totalSamples / samplesPerPixel
            let samplesToProcess = downSampledLength * samplesPerPixel

            guard samplesToProcess > 0 else { continue }
            
            processSamples(fromData: &sampleBuffer,
                           sampleMax: &sampleMax,
                           outputSamples: &outputSamples,
                           samplesToProcess: samplesToProcess,
                           downSampledLength: downSampledLength,
                           samplesPerPixel: samplesPerPixel,
                           filter: filter)
        }
        
        // Process the remaining samples at the end which didn't fit into samplesPerPixel
        let samplesToProcess = sampleBuffer.count / MemoryLayout<Int16>.size
        if samplesToProcess > 0 {
            let downSampledLength = 1
            let samplesPerPixel = samplesToProcess
            let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)
            
            processSamples(fromData: &sampleBuffer,
                           sampleMax: &sampleMax,
                           outputSamples: &outputSamples,
                           samplesToProcess: samplesToProcess,
                           downSampledLength: downSampledLength,
                           samplesPerPixel: samplesPerPixel,
                           filter: filter)
        }
        
        // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
        // Something went wrong. Handle it.
        if reader.status == .completed {
            return (outputSamples, sampleMax)
        } else {
            print(reader.status)
            return nil
        }
    }
    
    func processSamples(fromData sampleBuffer: inout Data, sampleMax: inout CGFloat, outputSamples: inout [CGFloat], samplesToProcess: Int, downSampledLength: Int, samplesPerPixel: Int, filter: [Float]) {
        sampleBuffer.withUnsafeBytes { (samples: UnsafePointer<Int16>) in
            var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)
            
            let sampleCount = vDSP_Length(samplesToProcess)
            
            //Convert 16bit int samples to floats
            vDSP_vflt16(samples, 1, &processingBuffer, 1, sampleCount)
            
            //Take the absolute values to get amplitude
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)
            
            //Convert to dB
            var zero: Float = 32768.0
            vDSP_vdbcon(processingBuffer, 1, &zero, &processingBuffer, 1, sampleCount, 1)
            
            //Clip to [noiseFloor, 0]
            var ceil: Float = 0.0
            var noiseFloorFloat = Float(noiseFloor)
            vDSP_vclip(processingBuffer, 1, &noiseFloorFloat, &ceil, &processingBuffer, 1, sampleCount)
            
            //Downsample and average
            var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
            vDSP_desamp(processingBuffer,
                        vDSP_Stride(samplesPerPixel),
                        filter, &downSampledData,
                        vDSP_Length(downSampledLength),
                        vDSP_Length(samplesPerPixel))
            
            let downSampledDataCG = downSampledData.map { (value: Float) -> CGFloat in
                let element = CGFloat(value)
                if element > sampleMax { sampleMax = element }
                return element
            }
            
            // Remove processed samples
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)
            
            outputSamples += downSampledDataCG
        }
    }

    // TODO: switch to a synchronous function that paints onto a given context? (for issue #2)
    func plotLogGraph(_ samples: [CGFloat], maximumValue max: CGFloat, zeroValue min: CGFloat, imageHeight: CGFloat) -> UIImage? {
        let imageSize = CGSize(width: CGFloat(samples.count), height: imageHeight)
        UIGraphicsBeginImageContext(imageSize)
        guard let context = UIGraphicsGetCurrentContext() else {
            NSLog("FDWaveformView failed to get graphics context")
            return nil
        }
        context.setShouldAntialias(false)
        context.setAlpha(1.0)
        context.setLineWidth(1.0)
        context.setStrokeColor(wavesColor.cgColor)

        let sampleDrawingScale: CGFloat
        if max == min {
            sampleDrawingScale = 0
        } else {
            sampleDrawingScale = imageHeight / 2 / (max - min)
        }
        let verticalMiddle = imageHeight / 2
        for (x, sample) in samples.enumerated() {
            let height = (sample - min) * sampleDrawingScale
            context.move(to: CGPoint(x: CGFloat(x), y: verticalMiddle - height))
            context.addLine(to: CGPoint(x: CGFloat(x), y: verticalMiddle + height))
            context.strokePath();
        }
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            NSLog("FDWaveformView failed to get waveform image from context")
            return nil
        }
        
        UIGraphicsEndImageContext()
        
        return image

        // TODO: handle the progress image differently?
//        let drawRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
//        context.setFillColor(progressColor.cgColor)
//        UIRectFillUsingBlendMode(drawRect, .sourceAtop)
//        guard let tintedImage = UIGraphicsGetImageFromCurrentImageContext() else {
//            NSLog("FDWaveformView failed to get tinted image from context")
//            return
//        }
//        UIGraphicsEndImageContext()
    }
}

extension FDWaveformView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if !doesAllowStretch {
            return
        }
        if recognizer.scale == 1 {
            return
        }
        let middleSamples = CGFloat((zoomStartSamples + zoomEndSamples) / 2)
        let rangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
        if middleSamples - 1.0 / recognizer.scale * CGFloat(rangeSamples) >= 0 {
            zoomStartSamples = Int(CGFloat(middleSamples) - 1.0 / recognizer.scale * CGFloat(rangeSamples) / 2)
        }
        else {
            zoomStartSamples = 0
        }
        if middleSamples + 1 / recognizer.scale * CGFloat(rangeSamples) / 2 <= CGFloat(totalSamples) {
            zoomEndSamples = Int(middleSamples + 1.0 / recognizer.scale * rangeSamples / 2)
        }
        else {
            zoomEndSamples = totalSamples
        }
        setNeedsDisplay()
        setNeedsLayout()
        recognizer.scale = 1
    }

    func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.translation(in: self)
        if doesAllowScroll {
            if recognizer.state == .began {
                delegate?.waveformDidEndPanning?(self)
            }
            var translationSamples = Int(CGFloat(zoomEndSamples - zoomStartSamples) * point.x / bounds.width)
            recognizer.setTranslation(CGPoint.zero, in: self)
            if zoomStartSamples - translationSamples < 0 {
                translationSamples = zoomStartSamples
            }
            if zoomEndSamples - translationSamples > totalSamples {
                translationSamples = zoomEndSamples - totalSamples
            }
            zoomStartSamples -= translationSamples
            zoomEndSamples -= translationSamples
            if recognizer.state == .ended {
                delegate?.waveformDidEndPanning?(self)
                setNeedsDisplay()
                setNeedsLayout()
            }
        }
        else if doesAllowScrubbing {
            let rangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
            progressSamples = Int(CGFloat(zoomStartSamples) + rangeSamples * recognizer.location(in: self).x / bounds.width)
        }
    }

    func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        if doesAllowScrubbing {
            let rangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
            progressSamples = Int(CGFloat(zoomStartSamples) + rangeSamples * recognizer.location(in: self).x / bounds.width)
        }
    }
}

/// To receive progress updates from FDWaveformView
@objc public protocol FDWaveformViewDelegate: NSObjectProtocol {
    /// Rendering will begin
    @objc optional func waveformViewWillRender(_ waveformView: FDWaveformView)

    /// Rendering did complete
    @objc optional func waveformViewDidRender(_ waveformView: FDWaveformView)

    /// An audio file will be loaded
    @objc optional func waveformViewWillLoad(_ waveformView: FDWaveformView)

    /// An audio file was loaded
    @objc optional func waveformViewDidLoad(_ waveformView: FDWaveformView)

    /// The panning gesture did begin
    @objc optional func waveformDidBeginPanning(_ waveformView: FDWaveformView)

    /// The panning gesture did end
    @objc optional func waveformDidEndPanning(_ waveformView: FDWaveformView)
}
