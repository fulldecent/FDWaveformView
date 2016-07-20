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

//TODO: find and remove all !

/// A view for rendering audio waveforms
@IBDesignable
public class FDWaveformView: UIView {
    /// A delegate to accept progress reporting
    @IBInspectable public weak var delegate: FDWaveformViewDelegate? = nil
    
    /// The audio file to render
    @IBInspectable public var audioURL: NSURL? = nil {
        didSet {
            guard let audioURL = self.audioURL else {
                NSLog("FDWaveformView failed to load URL")
                return
            }
            let asset = AVURLAsset(URL: audioURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(bool: true)])
            self.asset = asset
            guard let assetTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first else {
                NSLog("FDWaveformView failed to load AVAssetTrack")
                return
            }
            self.assetTrack = assetTrack
            loadingInProgress = true
            self.delegate?.waveformViewWillLoad?(self)
            asset.loadValuesAsynchronouslyForKeys(["duration"]) {
                var error: NSError? = nil
                let status = self.asset!.statusOfValueForKey("duration", error: &error)
                switch status {
                case .Loaded:
                    self.image.image = nil
                    self.highlightedImage.image = nil
                    self.progressSamples = 0
                    self.zoomStartSamples = 0
                    let formatDesc = assetTrack.formatDescriptions
                    let item = formatDesc.first as! CMAudioFormatDescriptionRef
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(item)
                    let samples = asbd.memory.mSampleRate * Float64(self.asset!.duration.value) / Float64(self.asset!.duration.timescale)
                    self.totalSamples = Int(samples)
                    self.zoomEndSamples = Int(samples)
                    self.setNeedsDisplay()
                    self.performSelectorOnMainThread(#selector(self.setNeedsLayout), withObject: nil, waitUntilDone: false)
                case .Failed, .Cancelled, .Loading, .Unknown:
                    print("FDWaveformView could not load asset: \(error?.localizedDescription)")
                }
            }
        }
    }
    
    /// The total number of audio samples in the file
    public private(set) var totalSamples = 0
    
    /// A portion of the waveform rendering to be highlighted
    @IBInspectable public var progressSamples: Int = 0 {
        didSet {
            if self.totalSamples > 0 {
                let progress = CGFloat(self.progressSamples) / CGFloat(self.totalSamples)
                self.clipping.frame = CGRectMake(0, 0, self.frame.size.width * progress, self.frame.size.height)
                self.setNeedsLayout()
            }
        }
    }
    
    //TODO:  MAKE THIS A RANGE, CAN IT BE ANIMATABLE??!
    
    /// The first sample to render
    @IBInspectable public var zoomStartSamples: Int = 0 {
        didSet {
            self.setNeedsDisplay()
            self.setNeedsLayout()
        }
    }
    
    /// One plus the last sample to render
    @IBInspectable public var zoomEndSamples: Int = 0 {
        didSet {
            self.setNeedsDisplay()
            self.setNeedsLayout()
        }
    }
    
    /// Whether to all the scrub gesture
    @IBInspectable public var doesAllowScrubbing = true
    
    /// Whether to allow the stretch gesture
    @IBInspectable public var doesAllowStretch = true
    
    /// Whether to allow the scroll gesture
    @IBInspectable public var doesAllowScroll = true
    
    /// The color of the waveform
    @IBInspectable public var wavesColor = UIColor.blackColor()
    
    /// The corol of the highlighted waveform (see `progressSamples`
    @IBInspectable public var progressColor = UIColor.blueColor()
    
    
    //TODO MAKE PUBLIC
    
    // Drawing a larger image than needed to have it available for scrolling
    private var horizontalMinimumBleed: CGFloat = 0.1
    private var horizontalMaximumBleed: CGFloat = 3.0
    private var horizontalTargetBleed: CGFloat = 0.5
    
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    private var horizontalMinimumOverdraw: CGFloat = 2.0
    
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    private var horizontalMaximumOverdraw: CGFloat = 5.0
    
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    private var horizontalTargetOverdraw: CGFloat = 3.0
    
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    private var verticalMinimumOverdraw: CGFloat = 1.0
    
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    private var verticalMaximumOverdraw: CGFloat = 3.0
    
    /// Drawing more pixels than shown to get antialiasing, 1.0 = no overdraw, 2.0 = twice as many pixels
    private var verticalTargetOverdraw: CGFloat = 2.0
    
    /// The "zero" level (in dB)
    private let noiseFloor: CGFloat = -50.0
    
    
    
    // Mark - Private vars
    
    //TODO RENAME
    private func minMaxX<T: Comparable>(x: T, min: T, max: T) -> T {
        return x < min ? min : x > max ? max : x
    }
    
    
    private func decibel(amplitude: CGFloat) -> CGFloat {
        return 20.0 * log10(abs(amplitude))
    }
    

    /// View for rendered waveform
    private let image: UIImageView = {
        let retval = UIImageView(frame: CGRect.zero)
        retval.contentMode = .ScaleToFill
        return retval
    }()
    
    /// View for rendered waveform showing progress
    private let highlightedImage: UIImageView = {
        let retval = UIImageView(frame: CGRect.zero)
        retval.contentMode = .ScaleToFill
        return retval
    }()
    
    /// A view which hides part of the highlighted image
    private let clipping: UIView = {
        let retval = UIView(frame: CGRect.zero)
        retval.clipsToBounds = true
        return retval
    }()
    
    /// The audio asset we are analyzing
    private var asset: AVAsset?
    
    /// The track (part of the asset) we will render
    private var assetTrack: AVAssetTrack? = nil
    
    /// The range of samples we rendered
    private var cachedSampleRange:Range<Int> = 0..<0
    
    /// Gesture recognizer
    private var pinchRecognizer = UIPinchGestureRecognizer()
    
    /// Gesture recognizer
    private var panRecognizer = UIPanGestureRecognizer()
    
    /// Gesture recognizer
    private var tapRecognizer = UITapGestureRecognizer()
    
    /// Whether rendering is happening asynchronously
    private var renderingInProgress = false
    
    /// Whether loading is happening asynchronously
    private var loadingInProgress = false
    
    func setup() {
        addSubview(image)
        clipping.addSubview(highlightedImage)
        addSubview(clipping)
        clipsToBounds = true
        
        //TODO: try to do this in the lazy initializer above
        self.pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinchGesture))
        self.pinchRecognizer.delegate = self
        self.addGestureRecognizer(self.pinchRecognizer)
        self.panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture))
        self.panRecognizer.delegate = self
        self.addGestureRecognizer(self.panRecognizer)
        self.tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture))
        self.addGestureRecognizer(self.tapRecognizer)
    }
    
    required public init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        self.setup()
    }
    
    override init(frame rect: CGRect) {
        super.init(frame: rect)
        self.setup()
    }
    
    /// If the cached image is insufficient for the current frame
    private func cacheIsDirty() -> Bool {
        if image.image == nil {
            return true
        }
        if cachedSampleRange.count == 0 {
            return true
        }
        if cachedSampleRange.startIndex < minMaxX(zoomStartSamples - Int(CGFloat(cachedSampleRange.count) * horizontalMaximumBleed), min: 0, max: totalSamples) {
            return true
        }
        if cachedSampleRange.startIndex > minMaxX(zoomStartSamples - Int(CGFloat(cachedSampleRange.count) * horizontalMinimumBleed), min: 0, max: totalSamples) {
            return true
        }
        if cachedSampleRange.endIndex < minMaxX(zoomEndSamples + Int(CGFloat(cachedSampleRange.count) * horizontalMinimumBleed), min: 0, max: totalSamples) {
            return true
        }
        if cachedSampleRange.endIndex > minMaxX(zoomEndSamples + Int(CGFloat(cachedSampleRange.count) * horizontalMaximumBleed), min: 0, max: totalSamples) {
            return true
        }
        if image.image?.size.width < frame.size.width * UIScreen.mainScreen().scale * CGFloat(horizontalMinimumOverdraw) {
            return true
        }
        if image.image?.size.width > frame.size.width * UIScreen.mainScreen().scale * CGFloat(horizontalMaximumOverdraw) {
            return true
        }
        if image.image?.size.height < frame.size.height * UIScreen.mainScreen().scale * CGFloat(verticalMinimumOverdraw) {
            return true
        }
        if image.image?.size.height > frame.size.height * UIScreen.mainScreen().scale * CGFloat(verticalMaximumOverdraw) {
            return true
        }
        return false
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        guard self.assetTrack != nil && !self.renderingInProgress && self.zoomEndSamples > 0 else {
            return
        }
        let displayRange = self.zoomEndSamples - self.zoomStartSamples
        if cacheIsDirty() {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
                self.renderAsset()
            }
            return
        }
        
        // We need to place the images which have samples in `cachedSampleRange`
        // inside our frame which represents `startSamples..<endSamples`
        // all figures are a portion of our frame width
        var scaledStart: CGFloat = 0.0
        var scaledProgress: CGFloat = 0.0
        var scaledEnd: CGFloat = 1.0
        var scaledWidth: CGFloat = 1.0
        if cachedSampleRange.count > 0 {
            let zoomRange = CGFloat(zoomEndSamples - zoomStartSamples)
            scaledStart = CGFloat(cachedSampleRange.startIndex - zoomStartSamples) / zoomRange
            scaledEnd = CGFloat(cachedSampleRange.last! - zoomEndSamples) / zoomRange
            scaledWidth = scaledEnd - scaledStart
            scaledProgress = CGFloat(progressSamples - zoomStartSamples) / zoomRange
        }
        let childFrame = CGRectMake(frame.size.width * scaledStart, 0, frame.size.width * scaledWidth, frame.size.height)
        image.frame = childFrame
        highlightedImage.frame = childFrame
        clipping.frame = CGRectMake(0, 0, self.frame.size.width * scaledProgress, self.frame.size.height)
        clipping.hidden = self.progressSamples <= self.zoomStartSamples
        print("\(frame) -- \(image.frame)")
    }
    
    func renderAsset() {
        guard !renderingInProgress else {
            return
        }
        renderingInProgress = true
        delegate?.waveformViewWillRender?(self)
        let displayRange = zoomEndSamples - zoomStartSamples
        guard displayRange > 0 else {
            return
        }
        let renderStartSamples = minMaxX(zoomStartSamples - Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderEndSamples = minMaxX(zoomEndSamples + Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let widthInPixels = Int(frame.size.width * UIScreen.mainScreen().scale * horizontalTargetOverdraw)
        let heightInPixels = frame.size.height * UIScreen.mainScreen().scale * horizontalTargetOverdraw
        
        sliceAsset(withRange: renderStartSamples..<renderEndSamples, andDownsampleTo: widthInPixels) {
            (samples, sampleMax) in
            self.plotLogGraph(samples, maximumValue: sampleMax, zeroValue: self.noiseFloor, imageHeight: heightInPixels) {
                (image, selectedImage) in
                dispatch_async(dispatch_get_main_queue()) {
                    self.image.image = image
                    self.highlightedImage.image = selectedImage
                    self.cachedSampleRange = renderStartSamples ..< renderEndSamples
                    self.renderingInProgress = false
                    self.layoutSubviews()
                    self.delegate?.waveformViewDidRender?(self)
                }
            }
        }
    }
    
    /// Read the asset and create create a lower resolution set of samples
    func sliceAsset(withRange slice: Range<Int>, andDownsampleTo targetSamples: Int, done: (samples: [CGFloat], sampleMax: CGFloat) -> Void) {
        guard slice.count > 0 else {
            return
        }
        guard let asset = asset else {
            return
        }
        guard let assetTrack = assetTrack else {
            return
        }
        var error: NSError? = nil
        guard let reader = try? AVAssetReader(asset: asset) else {
            return
        }
        reader.timeRange = CMTimeRangeMake(CMTimeMake(Int64(slice.startIndex), asset.duration.timescale), CMTimeMake(Int64(slice.count), asset.duration.timescale))
        let outputSettingsDict: [String : AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        reader.addOutput(readerOutput)
        var channelCount = 1
        var formatDesc: [AnyObject] = assetTrack.formatDescriptions
        for item in formatDesc {
            let fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item as! CMAudioFormatDescription)
            guard fmtDesc != nil else {
                return
            }
            channelCount = Int(fmtDesc.memory.mChannelsPerFrame)
        }
        let bytesPerInputSample = sizeof(Int16)
        var sampleMax = noiseFloor
        var tally: CGFloat = 0.0
        var tallyCount = 0
        var samplesPerPixel = slice.count / targetSamples
        if samplesPerPixel < 1 {
            samplesPerPixel = 1
        }
        
        var outputSamples = [CGFloat]()
        
        // 16-bit samples
        reader.startReading()
        
        while reader.status == .Reading {
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer() else {
                break
            }
            guard let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else {
                break
            }
            let readBufferLength = CMBlockBufferGetDataLength(readBuffer)
            
            let data = NSMutableData(length: readBufferLength)
            CMBlockBufferCopyDataBytes(readBuffer, 0, readBufferLength, data!.mutableBytes)
            CMSampleBufferInvalidate(readSampleBuffer)
            let sampleCount = readBufferLength / sizeof(Int16)
            let samples = UnsafeMutablePointer<Int16>(data!.mutableBytes)
            
            for i in 0 ..< sampleCount {
                guard i % Int(channelCount) == 0 else {
                    continue // only use the first channel
                }
                let rawData = samples[i]
                let sample = minMaxX(decibel(CGFloat(rawData)), min: noiseFloor, max: 0.0)
                tally += sample
                tallyCount += 1
                if Int(tallyCount) == samplesPerPixel {
                    let sample = tally / CGFloat(tallyCount)
                    sampleMax = sampleMax > sample ? sampleMax : sample
                    outputSamples.append(sample)
                    tally = 0
                    tallyCount = 0
                }
            }
        }
        // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
        // Something went wrong. Handle it.
        if reader.status == .Completed {
            done(samples: outputSamples, sampleMax: sampleMax)
        }
    }
    
    // TODO: switch to a synchronous function that paints onto a given context? (for issue #2)
    func plotLogGraph(samples: [CGFloat], maximumValue max: CGFloat, zeroValue min: CGFloat, imageHeight: CGFloat, done: (image: UIImage, selectedImage: UIImage)->Void) {
        let imageSize = CGSizeMake(CGFloat(samples.count), imageHeight)
        UIGraphicsBeginImageContext(imageSize)
        let context = UIGraphicsGetCurrentContext()!
        CGContextSetShouldAntialias(context, false)
        CGContextSetAlpha(context, 1.0)
        CGContextSetLineWidth(context, 1.0)
        CGContextSetStrokeColorWithColor(context, self.wavesColor.CGColor)
        
        let verticalMiddle = imageHeight / 2
        let halfGraphHeight = imageHeight / 2
        let centerLeft = halfGraphHeight
        let sampleDrawingScale: CGFloat
        if max == min {
            sampleDrawingScale = 0
        } else {
            sampleDrawingScale = imageHeight / (max - min) / 2
        }
        for sample in samples {
            var height = CGFloat((sample - min) * sampleDrawingScale)
            if height == 0 {
                height = 1
            }
            CGContextMoveToPoint(context, sample, verticalMiddle - height)
            CGContextAddLineToPoint(context, sample, verticalMiddle + height)
            CGContextStrokePath(context);
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        let drawRect = CGRectMake(0, 0, image.size.width, image.size.height)
        progressColor.set()
        UIRectFillUsingBlendMode(drawRect, .SourceAtop)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        done(image: image, selectedImage: tintedImage)
    }
}

extension FDWaveformView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func handlePinchGesture(recognizer: UIPinchGestureRecognizer) {
        if !self.doesAllowStretch {
            return
        }
        if recognizer.scale == 1 {
            return
        }
        let middleSamples = CGFloat((zoomStartSamples + zoomEndSamples) / 2)
        let rangeSamples = CGFloat(self.zoomEndSamples - self.zoomStartSamples)
        if middleSamples - 1.0 / recognizer.scale * CGFloat(rangeSamples) >= 0 {
            self.zoomStartSamples = Int(CGFloat(middleSamples) - 1.0 / recognizer.scale * CGFloat(rangeSamples) / 2)
        }
        else {
            self.zoomStartSamples = 0
        }
        if middleSamples + 1 / recognizer.scale * CGFloat(rangeSamples) / 2 <= CGFloat(totalSamples) {
            self.zoomEndSamples = Int(middleSamples + 1.0 / recognizer.scale * rangeSamples / 2)
        }
        else {
            self.zoomEndSamples = self.totalSamples
        }
        self.setNeedsDisplay()
        self.setNeedsLayout()
        recognizer.scale = 1
    }
    
    func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        var point: CGPoint = recognizer.translationInView(self)
        if self.doesAllowScroll {
            if recognizer.state == .Began {
                delegate?.waveformDidEndPanning?(self)
            }
            var translationSamples = Int(CGFloat(self.zoomEndSamples - self.zoomStartSamples) * point.x / self.bounds.size.width)
            recognizer.setTranslation(CGPointZero, inView: self)
            if self.zoomStartSamples - translationSamples < 0 {
                translationSamples = self.zoomStartSamples
            }
            if self.zoomEndSamples - translationSamples > self.totalSamples {
                translationSamples = self.zoomEndSamples - self.totalSamples
            }
            self.zoomStartSamples -= translationSamples
            self.zoomEndSamples -= translationSamples
            if recognizer.state == .Ended {
                delegate?.waveformDidEndPanning?(self)
                self.setNeedsDisplay()
                self.setNeedsLayout()
            }
            else if self.doesAllowScrubbing {
                let rangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
                progressSamples = Int(CGFloat(zoomStartSamples) + rangeSamples * recognizer.locationInView(self).x / self.bounds.size.width)
            }
        }
    }
    
    func handleTapGesture(recognizer: UITapGestureRecognizer) {
        if self.doesAllowScrubbing {
            let rangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
            progressSamples = Int(CGFloat(zoomStartSamples) + rangeSamples * recognizer.locationInView(self).x / self.bounds.size.width)
        }
    }
}

/// To receive progress updates from FDWaveformView
@objc public protocol FDWaveformViewDelegate: NSObjectProtocol {
    /// Rendering will begin
    optional func waveformViewWillRender(waveformView: FDWaveformView)
    
    /// Rendering did complete
    optional func waveformViewDidRender(waveformView: FDWaveformView)
    
    /// An audio file will be loaded
    optional func waveformViewWillLoad(waveformView: FDWaveformView)
    
    /// An audio file was loaded
    optional func waveformViewDidLoad(waveformView: FDWaveformView)
    
    /// The panning gesture did begin
    optional func waveformDidBeginPanning(waveformView: FDWaveformView)
    
    /// The panning gesture did end
    optional func waveformDidEndPanning(waveformView: FDWaveformView)
}