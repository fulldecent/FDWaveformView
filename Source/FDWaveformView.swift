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

    /// Whether rendering for the current asset failed
    private var renderForCurrentAssetFailed = false
    
    /// Current audio context to be used for rendering
    private var audioContext: FDAudioContext? {
        didSet {
            waveformImage = nil
            progressSamples = 0
            zoomStartSamples = 0
            zoomEndSamples = totalSamples
            waveformRenderOperation = nil
            renderForCurrentAssetFailed = false
            
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
    fileprivate var cachedSampleRange: CountableRange<Int>?

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
        guard !renderForCurrentAssetFailed else { return false }
        guard
            let image = waveformImage,
            let cachedSampleRange = cachedSampleRange
            else { return true }
        
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
        guard audioContext != nil && zoomEndSamples > 0 else {
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
        if let cachedSampleRange = cachedSampleRange, !cachedSampleRange.isEmpty && !zoomSamples.isEmpty {
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
        guard let audioContext = audioContext else { return }

        print("rendering")
        
        let displayRange = zoomEndSamples - zoomStartSamples
        guard displayRange > 0 else { return }

        let renderStartSamples = minMaxX(zoomStartSamples - Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderEndSamples = minMaxX(zoomEndSamples + Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderSampleRange = renderStartSamples..<renderEndSamples
        let widthInPixels = floor(frame.width * UIScreen.main.scale * horizontalTargetOverdraw)
        let heightInPixels = frame.height * UIScreen.main.scale * horizontalTargetOverdraw // TODO: Vertical target overdraw?
        let imageSize = CGSize(width: widthInPixels, height: heightInPixels)
        let renderFormat = FDWaveformRenderFormat(wavesColor: .black, noiseFloor: noiseFloor)
        
        let waveformRenderOperation = FDWaveformRenderOperation(audioContext: audioContext, imageSize: imageSize, sampleRange: renderSampleRange) { image in
            DispatchQueue.main.async {
                self.renderForCurrentAssetFailed = (image == nil)
                print("done")
                self.waveformImage = image
                self.cachedSampleRange = (image != nil) ? renderSampleRange : nil
                self.renderingInProgress = false
                self.waveformRenderOperation = nil
                self.setNeedsLayout()
                self.delegate?.waveformViewDidRender?(self)
            }
        }
        self.waveformRenderOperation = waveformRenderOperation
        
        renderingInProgress = true
        delegate?.waveformViewWillRender?(self)

        waveformRenderOperation.start()
    }
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

public struct FDWaveformRenderFormat {
    
    /// The color of the waveform
    public var wavesColor = UIColor.black
    
    fileprivate var noiseFloor: CGFloat = -50.0
}

final public class FDWaveformRenderOperation: Operation {
    
    // TODO: document and clean up
    public let audioContext: FDAudioContext
    private let completionHandler: (UIImage?) -> ()

    public let format: FDWaveformRenderFormat
    public let imageSize: CGSize
    public let sampleRange: CountableRange<Int>
    
    public override var isAsynchronous: Bool { return true }
    
    private var _isExecuting = false
    public override var isExecuting: Bool { return _isExecuting }
    
    private var _isFinished = false
    public override var isFinished: Bool { return _isFinished }
    
    private var renderedImage: UIImage?
    
    public init(audioContext: FDAudioContext, imageSize: CGSize, sampleRange: CountableRange<Int>? = nil, format: FDWaveformRenderFormat = FDWaveformRenderFormat(), completionHandler: @escaping (_ image: UIImage?) -> ()) {
        self.audioContext = audioContext
        self.format = format
        self.imageSize = imageSize
        self.sampleRange = sampleRange ?? 0..<audioContext.totalSamples
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
                let image = plotLogGraph(samples, maximumValue: sampleMax, zeroValue: self.format.noiseFloor, imageHeight: self.imageSize.height)
            else { return nil }
            
            return image
        }()
        
        finish(with: image)
    }

    /// Read the asset and create create a lower resolution set of samples
    func sliceAsset(withRange slice: CountableRange<Int>, andDownsampleTo targetSamples: Int) -> (samples: [CGFloat], sampleMax: CGFloat)? {
        guard !isCancelled else { print("sampling cancelled!"); return nil }
        
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
            guard let fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item as! CMAudioFormatDescription) else { return nil }    // TODO: Can the forced downcast in here be safer?
            channelCount = Int(fmtDesc.pointee.mChannelsPerFrame)
        }

        var sampleMax = format.noiseFloor
        // TODO: bad things happen if target samples is 0
        let samplesPerPixel = max(1, channelCount * slice.count / targetSamples)
        let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)

        var outputSamples = [CGFloat]()
        var sampleBuffer = Data()

        // 16-bit samples
        reader.startReading()
        defer { reader.cancelReading(); print("canceled reading") } // Cancel reading if we exit early if operation is cancelled

        while reader.status == .reading {
            guard !isCancelled else { print("sampling cancelled!"); return nil }
            
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
            guard !isCancelled else { print("sampling cancelled!"); return nil }
            
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
            print("FDWaveformRenderOperation failed to read audio: \(reader.error)")
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
            var noiseFloorFloat = Float(format.noiseFloor)
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
        guard !isCancelled else { return nil }
        
        let imageSize = CGSize(width: CGFloat(samples.count), height: imageHeight)
        UIGraphicsBeginImageContext(imageSize)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else {
            NSLog("FDWaveformView failed to get graphics context")
            return nil
        }
        context.setShouldAntialias(false)
        context.setAlpha(1.0)
        context.setLineWidth(1.0)
        context.setStrokeColor(format.wavesColor.cgColor)

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
        
        return image
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
