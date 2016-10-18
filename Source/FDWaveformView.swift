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
            delegate?.waveformViewWillLoad?(self)
            asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                var error: NSError?
                let status = asset.statusOfValue(forKey: "duration", error: &error)
                switch status {
                case .loaded:
                    if let audioFormatDesc = assetTrack.formatDescriptions.first {
                        let item = audioFormatDesc as! CMAudioFormatDescription     // TODO: Can this be safer?
                        if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(item) {
                            let samples = (asbd.pointee.mSampleRate) * Float64(asset.duration.value) / Float64(asset.duration.timescale)
                            
                            self.imageView.image = nil
                            self.highlightedImage.image = nil
                            self.progressSamples = 0
                            self.zoomStartSamples = 0
                            self.totalSamples = Int(samples)
                            self.zoomEndSamples = Int(samples)
                            self.setNeedsDisplay()
                            self.performSelector(onMainThread: #selector(self.setNeedsLayout), with: nil, waitUntilDone: false)
                        }
                    }
                case .failed, .cancelled, .loading, .unknown:
                    print("FDWaveformView could not load asset: \(error?.localizedDescription)")
                }
            }
        }
    }

    /// The total number of audio samples in the file
    open fileprivate(set) var totalSamples = 0

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
    fileprivate let imageView: UIImageView = {
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
    fileprivate var assetTrack: AVAssetTrack?

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
        addGestureRecognizer(tapRecognizer)
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
        guard let image = imageView.image else { return true }
        
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
        guard assetTrack != nil && !renderingInProgress && zoomEndSamples > 0 else {
            return
        }

        if cacheIsDirty() {
            if #available(iOS 8.0, *) {
                DispatchQueue.global(qos: .background).async { self.renderAsset() }
            } else {
                DispatchQueue.global(priority: .background).async { self.renderAsset() }
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

    func renderAsset() {
        guard !renderingInProgress else { return }

        renderingInProgress = true
        delegate?.waveformViewWillRender?(self)
        let displayRange = zoomEndSamples - zoomStartSamples

        guard displayRange > 0 else { return }

        let renderStartSamples = minMaxX(zoomStartSamples - Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderEndSamples = minMaxX(zoomEndSamples + Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let widthInPixels = Int(frame.width * UIScreen.main.scale * horizontalTargetOverdraw)
        let heightInPixels = frame.height * UIScreen.main.scale * horizontalTargetOverdraw

        sliceAsset(withRange: renderStartSamples..<renderEndSamples, andDownsampleTo: widthInPixels) {
            (samples, sampleMax) in
            self.plotLogGraph(samples, maximumValue: sampleMax, zeroValue: self.noiseFloor, imageHeight: heightInPixels) {
                (image, selectedImage) in
                DispatchQueue.main.async {
                    self.imageView.image = image
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

        reader.timeRange = CMTimeRange(start: CMTime(value: Int64(slice.lowerBound), timescale: asset.duration.timescale), duration: CMTime(value: Int64(slice.count), timescale: asset.duration.timescale))
        let outputSettingsDict: [String : Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        var channelCount = 1
        let formatDesc = assetTrack.formatDescriptions
        for item in formatDesc {
            guard let fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item as! CMAudioFormatDescription) else { return }    // TODO: Can the forced downcast in here be safer?
            channelCount = Int(fmtDesc.pointee.mChannelsPerFrame)
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
                
                let downSampledDataCG = downSampledData.map { (value: Float) -> CGFloat in
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
        guard let context = UIGraphicsGetCurrentContext() else {
            NSLog("FDWaveformView failed to get graphics context")
            return
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
            return
        }
        
        let drawRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        context.setFillColor(progressColor.cgColor)
        UIRectFillUsingBlendMode(drawRect, .sourceAtop)
        guard let tintedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            NSLog("FDWaveformView failed to get tinted image from context")
            return
        }
        UIGraphicsEndImageContext()
        done(image, tintedImage)
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
