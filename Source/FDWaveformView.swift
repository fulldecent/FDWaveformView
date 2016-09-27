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
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


// FROM http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader
// DO SEE http://stackoverflow.com/questions/1191868/uiimageview-scaling-interpolation
// see http://stackoverflow.com/questions/3514066/how-to-tint-a-transparent-png-image-in-iphone

//TODO: find and remove all !

/// A view for rendering audio waveforms
//@IBDesignable
open class FDWaveformView: UIView {
    /// A delegate to accept progress reporting
    @IBInspectable open weak var delegate: FDWaveformViewDelegate? = nil

    /// The audio file to render
    @IBInspectable open var audioURL: URL? = nil {
        didSet {
            guard let audioURL = self.audioURL else {
                NSLog("FDWaveformView failed to load URL")
                return
            }

            let asset = AVURLAsset(url: audioURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true as Bool)])
            self.asset = asset

            guard let assetTrack = asset.tracks(withMediaType: AVMediaTypeAudio).first else {
                NSLog("FDWaveformView failed to load AVAssetTrack")
                return
            }

            self.assetTrack = assetTrack
            loadingInProgress = true
            self.delegate?.waveformViewWillLoad?(self)
            asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                var error: NSError? = nil
                let status = self.asset!.statusOfValue(forKey: "duration", error: &error)
                switch status {
                case .loaded:
                    self.image.image = nil
                    self.highlightedImage.image = nil
                    self.progressSamples = 0
                    self.zoomStartSamples = 0
                    let formatDesc = assetTrack.formatDescriptions
                    let item = formatDesc.first as! CMAudioFormatDescription
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(item)
                    let samples = (asbd?.pointee.mSampleRate)! * Float64(self.asset!.duration.value) / Float64(self.asset!.duration.timescale)
                    self.totalSamples = Int(samples)
                    self.zoomEndSamples = Int(samples)
                    self.setNeedsDisplay()
                    self.performSelector(onMainThread: #selector(self.setNeedsLayout), with: nil, waitUntilDone: false)
                case .failed, .cancelled, .loading, .unknown:
                    print("FDWaveformView could not load asset: \(error?.localizedDescription)")
                }
            }
        }
    }

    /// The total number of audio samples in the file
    open fileprivate(set) var totalSamples = 0

    /// A portion of the waveform rendering to be highlighted
    @IBInspectable open var progressSamples: Int = 0 {
        didSet {
            if self.totalSamples > 0 {
                let progress = CGFloat(self.progressSamples) / CGFloat(self.totalSamples)
                self.clipping.frame = CGRect(x: 0, y: 0, width: self.frame.size.width * progress, height: self.frame.size.height)
                self.setNeedsLayout()
            }
        }
    }

    //TODO:  MAKE THIS A RANGE, CAN IT BE ANIMATABLE??!

    /// The first sample to render
    @IBInspectable open var zoomStartSamples: Int = 0 {
        didSet {
            self.setNeedsDisplay()
            self.setNeedsLayout()
        }
    }

    /// One plus the last sample to render
    @IBInspectable open var zoomEndSamples: Int = 0 {
        didSet {
            self.setNeedsDisplay()
            self.setNeedsLayout()
        }
    }

    /// Whether to all the scrub gesture
    @IBInspectable open var doesAllowScrubbing = true

    /// Whether to allow the stretch gesture
    @IBInspectable open var doesAllowStretch = true

    /// Whether to allow the scroll gesture
    @IBInspectable open var doesAllowScroll = true

    /// The color of the waveform
    @IBInspectable open var wavesColor = UIColor.black

    /// The color of the highlighted waveform (see `progressSamples`
    @IBInspectable open var progressColor = UIColor.blue


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

    //TODO RENAME
    fileprivate func minMaxX<T: Comparable>(_ x: T, min: T, max: T) -> T {
        return x < min ? min : x > max ? max : x
    }

    fileprivate func decibel(_ amplitude: CGFloat) -> CGFloat {
        return 20.0 * log10(abs(amplitude))
    }

    /// View for rendered waveform
    fileprivate let image: UIImageView = {
        let retval = UIImageView(frame: CGRect.zero)
        retval.contentMode = .scaleToFill
        return retval
    }()

    /// View for rendered waveform showing progress
    fileprivate let highlightedImage: UIImageView = {
        let retval = UIImageView(frame: CGRect.zero)
        retval.contentMode = .scaleToFill
        return retval
    }()

    /// A view which hides part of the highlighted image
    fileprivate let clipping: UIView = {
        let retval = UIView(frame: CGRect.zero)
        retval.clipsToBounds = true
        return retval
    }()

    /// The audio asset we are analyzing
    fileprivate var asset: AVAsset?

    /// The track (part of the asset) we will render
    fileprivate var assetTrack: AVAssetTrack? = nil

    /// The range of samples we rendered
    fileprivate var cachedSampleRange:CountableRange<Int> = 0..<0

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
        addSubview(image)
        clipping.addSubview(highlightedImage)
        addSubview(clipping)
        clipsToBounds = true

        self.setupGestureRecognizers()
        self.addGestureRecognizer(self.tapRecognizer)
    }

    fileprivate func setupGestureRecognizers() {
        //TODO: try to do this in the lazy initializer above
        self.pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinchGesture))
        self.pinchRecognizer.delegate = self
        self.addGestureRecognizer(self.pinchRecognizer)
        self.panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture))
        self.panRecognizer.delegate = self
        self.addGestureRecognizer(self.panRecognizer)
        self.tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture))
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
    fileprivate func cacheIsDirty() -> Bool {
        if image.image == nil {
            return true
        }
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
        if image.image?.size.width < frame.size.width * UIScreen.main.scale * CGFloat(horizontalMinimumOverdraw) {
            return true
        }
        if image.image?.size.width > frame.size.width * UIScreen.main.scale * CGFloat(horizontalMaximumOverdraw) {
            return true
        }
        if image.image?.size.height < frame.size.height * UIScreen.main.scale * CGFloat(verticalMinimumOverdraw) {
            return true
        }
        if image.image?.size.height > frame.size.height * UIScreen.main.scale * CGFloat(verticalMaximumOverdraw) {
            return true
        }
        return false
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        guard self.assetTrack != nil && !self.renderingInProgress && self.zoomEndSamples > 0 else {
            return
        }

        if cacheIsDirty() {
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async {
                self.renderAsset()
            }
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
            scaledWidth = CGFloat(cachedSampleRange.last! - zoomSamples.lowerBound) / CGFloat(zoomSamples.count)
            scaledProgressWidth = CGFloat(progressSamples - zoomSamples.lowerBound) / CGFloat(zoomSamples.count)
        }
        let childFrame = CGRect(x: frame.size.width * scaledX, y: 0, width: frame.size.width * scaledWidth, height: frame.size.height)
        image.frame = childFrame
        highlightedImage.frame = childFrame
        clipping.frame = CGRect(x: 0, y: 0, width: self.frame.size.width * scaledProgressWidth, height: self.frame.size.height)
        clipping.isHidden = self.progressSamples <= self.zoomStartSamples
        print("\(frame) -- \(image.frame)")
    }

    func renderAsset() {
        guard !renderingInProgress else { return }

        renderingInProgress = true
        delegate?.waveformViewWillRender?(self)
        let displayRange = zoomEndSamples - zoomStartSamples

        guard displayRange > 0 else { return }

        let renderStartSamples = minMaxX(zoomStartSamples - Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderEndSamples = minMaxX(zoomEndSamples + Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let widthInPixels = Int(frame.size.width * UIScreen.main.scale * horizontalTargetOverdraw)
        let heightInPixels = frame.size.height * UIScreen.main.scale * horizontalTargetOverdraw

        sliceAsset(withRange: renderStartSamples..<renderEndSamples, andDownsampleTo: widthInPixels) {
            (samples, sampleMax) in
            self.plotLogGraph(samples, maximumValue: sampleMax, zeroValue: self.noiseFloor, imageHeight: heightInPixels) {
                (image, selectedImage) in
                DispatchQueue.main.async {
                    self.image.image = image
                    self.highlightedImage.image = selectedImage
                    self.cachedSampleRange = renderStartSamples ..< renderEndSamples
                    self.renderingInProgress = false
                    self.setNeedsLayout()
                    self.delegate?.waveformViewDidRender?(self)
                }
            }
        }
    }

    /// Read the asset and create create a lower resolution set of samples
    func sliceAsset(withRange slice: Range<Int>, andDownsampleTo targetSamples: Int, done: (_ samples: [CGFloat], _ sampleMax: CGFloat) -> Void) {
        guard slice.count > 0 else { return }
        guard let asset = asset else { return }
        guard let assetTrack = assetTrack else { return }
        guard let reader = try? AVAssetReader(asset: asset) else { return }

        reader.timeRange = CMTimeRangeMake(CMTimeMake(Int64(slice.lowerBound), asset.duration.timescale), CMTimeMake(Int64(slice.count), asset.duration.timescale))
        let outputSettingsDict: [String : AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM) as AnyObject,
            AVLinearPCMBitDepthKey: 16 as AnyObject,
            AVLinearPCMIsBigEndianKey: false as AnyObject,
            AVLinearPCMIsFloatKey: false as AnyObject,
            AVLinearPCMIsNonInterleaved: false as AnyObject
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        var channelCount = 1
        let formatDesc: [AnyObject] = assetTrack.formatDescriptions as [AnyObject]
        for item in formatDesc {
            let fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item as! CMAudioFormatDescription)
            guard fmtDesc != nil else { return }
            channelCount = Int((fmtDesc?.pointee.mChannelsPerFrame)!)
        }

        var sampleMax = noiseFloor
        var samplesPerPixel = channelCount * slice.count / targetSamples
        if samplesPerPixel < 1 {
            samplesPerPixel = 1
        }

        var outputSamples = [CGFloat]()
        var nextDataOffset = 0

        // 16-bit samples
        reader.startReading()

        while reader.status == .reading {
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else {
                    break
            }

            let readBufferLength = CMBlockBufferGetDataLength(readBuffer)

            var data = Data(capacity: readBufferLength)
            data.withUnsafeMutableBytes {
                (bytes: UnsafeMutablePointer<Int16>) in
                CMBlockBufferCopyDataBytes(readBuffer, 0, readBufferLength, bytes)
                let samples = UnsafeMutablePointer<Int16>(bytes)
                
                CMSampleBufferInvalidate(readSampleBuffer)
                
                let samplesToProcess = readBufferLength / MemoryLayout<Int16>.size
                
                let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)
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
                let downSampledLength = samplesToProcess / samplesPerPixel
                var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
                
                vDSP_desamp(processingBuffer,
                            vDSP_Stride(samplesPerPixel),
                            filter, &downSampledData,
                            vDSP_Length(downSampledLength),
                            vDSP_Length(samplesPerPixel))
                
                let range = nextDataOffset..<(nextDataOffset+downSampledLength)
                var downSampledDataCG = downSampledData.map { (value: Float) -> CGFloat in
                    let element = CGFloat(value)
                    if element > sampleMax { sampleMax = element }
                    return element
                }
                
                outputSamples += downSampledDataCG
                nextDataOffset += downSampledLength
            }
        }
        // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
        // Something went wrong. Handle it.
        if reader.status == .completed {
            done(outputSamples, sampleMax)
        } else {
            print(reader.status)
        }
    }

    // TODO: switch to a synchronous function that paints onto a given context? (for issue #2)
    func plotLogGraph(_ samples: [CGFloat], maximumValue max: CGFloat, zeroValue min: CGFloat, imageHeight: CGFloat, done: (_ image: UIImage, _ selectedImage: UIImage)->Void) {
        let imageSize = CGSize(width: CGFloat(samples.count), height: imageHeight)
        UIGraphicsBeginImageContext(imageSize)
        let context = UIGraphicsGetCurrentContext()!
        context.setShouldAntialias(false)
        context.setAlpha(1.0)
        context.setLineWidth(1.0)
        context.setStrokeColor(self.wavesColor.cgColor)

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
        let image = UIGraphicsGetImageFromCurrentImageContext()
        let drawRect = CGRect(x: 0, y: 0, width: (image?.size.width)!, height: (image?.size.height)!)
        context.setFillColor(progressColor.cgColor)
        UIRectFillUsingBlendMode(drawRect, .sourceAtop)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        done(image!, tintedImage!)
    }
}

extension FDWaveformView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
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

    func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.translation(in: self)
        if self.doesAllowScroll {
            if recognizer.state == .began {
                delegate?.waveformDidEndPanning?(self)
            }
            var translationSamples = Int(CGFloat(self.zoomEndSamples - self.zoomStartSamples) * point.x / self.bounds.size.width)
            recognizer.setTranslation(CGPoint.zero, in: self)
            if self.zoomStartSamples - translationSamples < 0 {
                translationSamples = self.zoomStartSamples
            }
            if self.zoomEndSamples - translationSamples > self.totalSamples {
                translationSamples = self.zoomEndSamples - self.totalSamples
            }
            self.zoomStartSamples -= translationSamples
            self.zoomEndSamples -= translationSamples
            if recognizer.state == .ended {
                delegate?.waveformDidEndPanning?(self)
                self.setNeedsDisplay()
                self.setNeedsLayout()
            }
            else if self.doesAllowScrubbing {
                let rangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
                progressSamples = Int(CGFloat(zoomStartSamples) + rangeSamples * recognizer.location(in: self).x / self.bounds.size.width)
            }
        }
    }

    func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        if self.doesAllowScrubbing {
            let rangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
            progressSamples = Int(CGFloat(zoomStartSamples) + rangeSamples * recognizer.location(in: self).x / self.bounds.size.width)
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
