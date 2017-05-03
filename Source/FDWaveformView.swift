//
// Copyright 2013 - 2017, William Entriken and the FDWaveformView contributors.
//
import UIKit
import MediaPlayer
import AVFoundation
import Accelerate

// FROM http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader
// DO SEE http://stackoverflow.com/questions/1191868/uiimageview-scaling-interpolation
// see http://stackoverflow.com/questions/3514066/how-to-tint-a-transparent-png-image-in-iphone

/// A view for rendering audio waveforms
/*@IBDesignable*/ // IBDesignable support in XCode is so broken it's sad
open class FDWaveformView: UIView {
    /// A delegate to accept progress reporting
    /*@IBInspectable*/ open weak var delegate: FDWaveformViewDelegate?

    /// The audio file to render
    /*@IBInspectable*/ open var audioURL: URL? {
        didSet {
            guard let audioURL = audioURL else {
                NSLog("FDWaveformView received nil audioURL")
                audioContext = nil
                return
            }

            loadingInProgress = true
            delegate?.waveformViewWillLoad?(self)
            
            FDAudioContext.load(fromAudioURL: audioURL) { audioContext in
                DispatchQueue.main.async {
                    guard self.audioURL == audioContext?.audioURL else { return }
                    
                    if audioContext == nil {
                        NSLog("FDWaveformView failed to load URL: \(audioURL)")
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
    /*@IBInspectable*/ open var progressSamples = 0 {
        didSet {
            if totalSamples > 0 {
                let progress = CGFloat(progressSamples) / CGFloat(totalSamples)
                clipping.frame = CGRect(x: 0, y: 0, width: frame.width * progress, height: frame.height)
                setNeedsLayout()
            }
        }
    }

    //TODO:  MAKE THIS A RANGE, CAN IT BE ANIMATABLE??!
//TODO: use clampRange for safety!
//TODO: disallow start=end
//TODO: allow nil
    /// The first sample to render
    /*@IBInspectable*/ open var zoomStartSamples = 0 {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }

    /// One plus the last sample to render
    /*@IBInspectable*/ open var zoomEndSamples = 0 {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }

    /// Whether to allow tap and pan gestures to change highlighted range
    /// Pan gives priority to `doesAllowScroll` if this and that are both `true`
    /*@IBInspectable*/ open var doesAllowScrubbing = true

    /// Whether to allow pinch gesture to change zoom
    /*@IBInspectable*/ open var doesAllowStretch = true

    /// Whether to allow pan gesture to change zoom
    /*@IBInspectable*/ open var doesAllowScroll = true

    /// Supported waveform types
    //TODO: make this public after reconciling FDWaveformView.WaveformType and FDWaveformType
    enum WaveformType {
        case linear, logarithmic
    }
    
    // Type of waveform to display
    var waveformType: WaveformType = .logarithmic {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }
    
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
            inProgressWaveformRenderOperation = nil
            cachedWaveformRenderOperation = nil
            renderForCurrentAssetFailed = false
            
            setNeedsDisplay()
            setNeedsLayout()
        }
    }
    
    /// Currently running renderer
    private var inProgressWaveformRenderOperation: FDWaveformRenderOperation? {
        willSet {
            if newValue !== inProgressWaveformRenderOperation {
                inProgressWaveformRenderOperation?.cancel()
            }
        }
    }
    
    /// The render operation used to render the current waveform image
    private var cachedWaveformRenderOperation: FDWaveformRenderOperation?
    
    /// Image of waveform
    private var waveformImage: UIImage? {
        get { return imageView.image }
        set {
            // This will allow us to apply a tint color to the image
            imageView.image = newValue?.withRenderingMode(.alwaysTemplate)
            highlightedImage.image = imageView.image
        }
    }
    
    /// Desired scale of image based on window's screen scale
    private var desiredImageScale: CGFloat {
        return window?.screen.scale ?? UIScreen.main.scale
    }
    
    /// Waveform type for rending waveforms
    //TODO: make this public after reconciling FDWaveformView.WaveformType and FDWaveformType
    var waveformRenderType: FDWaveformType {
        get {
            switch waveformType {
            case .linear: return .linear
            case .logarithmic: return .logarithmic(noiseFloor: noiseFloor)
            }
        }
    }
    
    /// Represents the status of the waveform renderings
    fileprivate enum CacheStatus {
        case dirty
        case notDirty(cancelInProgressRenderOperation: Bool)
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
        //TODO: try to do this in the lazy initializers above
        pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture))
        pinchRecognizer.delegate = self
        addGestureRecognizer(pinchRecognizer)
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panRecognizer.delegate = self
        addGestureRecognizer(panRecognizer)
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
//        tapRecognizer.delegate = self
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

    /// If the cached waveform or in progress waveform is insufficient for the current frame
    fileprivate func cacheStatus() -> CacheStatus {
        guard !renderForCurrentAssetFailed else { return .notDirty(cancelInProgressRenderOperation: true) }

        let isInProgressRenderOperationDirty = isWaveformRenderOperationDirty(inProgressWaveformRenderOperation)
        let isCachedRenderOperationDirty = isWaveformRenderOperationDirty(cachedWaveformRenderOperation)
        
        if let isInProgressRenderOperationDirty = isInProgressRenderOperationDirty {
            if let isCachedRenderOperationDirty = isCachedRenderOperationDirty {
                if isInProgressRenderOperationDirty {
                    if isCachedRenderOperationDirty {
                        return .dirty
                    } else {
                        return .notDirty(cancelInProgressRenderOperation: true)
                    }
                } else if !isCachedRenderOperationDirty {
                    return .notDirty(cancelInProgressRenderOperation: true)
                }
            } else if isInProgressRenderOperationDirty {
                return .dirty
            }
        } else if let isLastWaveformRenderOperationDirty = isCachedRenderOperationDirty {
            if isLastWaveformRenderOperationDirty {
                return .dirty
            }
        } else {
            return .dirty
        }
        
        return .notDirty(cancelInProgressRenderOperation: false)
    }
    
    func isWaveformRenderOperationDirty(_ renderOperation: FDWaveformRenderOperation?) -> Bool? {
        guard let renderOperation = renderOperation else { return nil }
        
        let imageSize = renderOperation.imageSize
        let sampleRange = renderOperation.sampleRange

        if renderOperation.format.type != waveformRenderType {
            return true
        }
        if renderOperation.format.scale != desiredImageScale {
            return true
        }
        if sampleRange.lowerBound < minMaxX(zoomStartSamples - Int(CGFloat(sampleRange.count) * horizontalMaximumBleed), min: 0, max: totalSamples) {
            return true
        }
        if sampleRange.lowerBound > minMaxX(zoomStartSamples - Int(CGFloat(sampleRange.count) * horizontalMinimumBleed), min: 0, max: totalSamples) {
            return true
        }
        if sampleRange.upperBound < minMaxX(zoomEndSamples + Int(CGFloat(sampleRange.count) * horizontalMinimumBleed), min: 0, max: totalSamples) {
            return true
        }
        if sampleRange.upperBound > minMaxX(zoomEndSamples + Int(CGFloat(sampleRange.count) * horizontalMaximumBleed), min: 0, max: totalSamples) {
            return true
        }
        if imageSize.width < frame.width * CGFloat(horizontalMinimumOverdraw) {
            return true
        }
        if imageSize.width > frame.width * CGFloat(horizontalMaximumOverdraw) {
            return true
        }
        if imageSize.height < frame.height * CGFloat(verticalMinimumOverdraw) {
            return true
        }
        if imageSize.height > frame.height * CGFloat(verticalMaximumOverdraw) {
            return true
        }
        return false
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        guard audioContext != nil && zoomEndSamples > 0 else {
            return
        }

        switch cacheStatus() {
        case .dirty:
            renderWaveform()
            return
        
        case .notDirty(let cancelInProgressRenderOperation):
            if cancelInProgressRenderOperation {
                inProgressWaveformRenderOperation = nil
            }
        }

        let zoomSamples = zoomStartSamples ..< zoomEndSamples

        // We need to place the images which have samples in `cachedSampleRange`
        // inside our frame which represents `startSamples..<endSamples`
        // all figures are a portion of our frame width
        var scaledX: CGFloat = 0.0
        var scaledProgressWidth: CGFloat = 0.0
        var scaledWidth: CGFloat = 1.0
        if let cachedSampleRange = cachedWaveformRenderOperation?.sampleRange, !cachedSampleRange.isEmpty && !zoomSamples.isEmpty {
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

        let displayRange = zoomEndSamples - zoomStartSamples
        guard displayRange > 0 else { return }

        let renderStartSamples = minMaxX(zoomStartSamples - Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderEndSamples = minMaxX(zoomEndSamples + Int(CGFloat(displayRange) * horizontalTargetBleed), min: 0, max: totalSamples)
        let renderSampleRange = renderStartSamples..<renderEndSamples
        let widthInPixels = floor(frame.width * horizontalTargetOverdraw)
        let heightInPixels = frame.height * horizontalTargetOverdraw
        let imageSize = CGSize(width: widthInPixels, height: heightInPixels)
        let renderFormat = FDWaveformRenderFormat(type: waveformRenderType, wavesColor: .black, scale: desiredImageScale)
        
        let waveformRenderOperation = FDWaveformRenderOperation(audioContext: audioContext, imageSize: imageSize, sampleRange: renderSampleRange, format: renderFormat) { image in
            DispatchQueue.main.async {
                self.renderForCurrentAssetFailed = (image == nil)
                self.waveformImage = image
                self.renderingInProgress = false
                self.cachedWaveformRenderOperation = self.inProgressWaveformRenderOperation
                self.inProgressWaveformRenderOperation = nil
                self.setNeedsLayout()
                self.delegate?.waveformViewDidRender?(self)
            }
        }
        self.inProgressWaveformRenderOperation = waveformRenderOperation
        
        renderingInProgress = true
        delegate?.waveformViewWillRender?(self)

        waveformRenderOperation.start()
    }
}

//TODO: make this public after reconciling FDWaveformView.WaveformType and FDWaveformType
enum FDWaveformType: Equatable {
    /// Waveform is rendered using a linear scale
    case linear
    
    /// Waveform is rendered using a logarithmic scale
    ///   noiseFloor: The "zero" level (in dB)
    case logarithmic(noiseFloor: CGFloat)
    
    // See http://stackoverflow.com/questions/24339807/how-to-test-equality-of-swift-enums-with-associated-values
    public static func ==(lhs: FDWaveformType, rhs: FDWaveformType) -> Bool {
        switch lhs {
        case .linear:
            if case .linear = rhs {
                return true
            }
        case .logarithmic(let lhsNoiseFloor):
            if case .logarithmic(let rhsNoiseFloor) = rhs {
                return lhsNoiseFloor == rhsNoiseFloor
            }
        }
        return false
    }
    
    public var floorValue: CGFloat {
        switch self {
        case .linear: return 0
        case .logarithmic(let noiseFloor): return noiseFloor
        }
    }
    
    func process(normalizedSamples: inout [Float]) {
        switch self {
        case .linear:
            return
            
        case .logarithmic(let noiseFloor):
            // Convert samples to a log scale
            var zero: Float = 32768.0
            vDSP_vdbcon(normalizedSamples, 1, &zero, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count), 1)
            
            //Clip to [noiseFloor, 0]
            var ceil: Float = 0.0
            var noiseFloorFloat = Float(noiseFloor)
            vDSP_vclip(normalizedSamples, 1, &noiseFloorFloat, &ceil, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count))
        }
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
        
        let zoomRangeSamples = CGFloat(zoomEndSamples - zoomStartSamples)
        let pinchCenterSample = zoomStartSamples + Int(zoomRangeSamples * recognizer.location(in: self).x / bounds.width)
        let newZoomRangeSamples = Int(zoomRangeSamples * 1.0 / recognizer.scale)
        let newZoomStart = pinchCenterSample - Int(CGFloat(pinchCenterSample - zoomStartSamples) * 1.0 / recognizer.scale)
        let newZoomEnd = newZoomStart + newZoomRangeSamples
        
        //TODO: This should be done in the setter
        if newZoomStart < 0 {
            zoomStartSamples = 0
        } else {
            zoomStartSamples = newZoomStart
        }
        if newZoomEnd > totalSamples {
            zoomEndSamples = totalSamples
        } else {
            zoomEndSamples = newZoomEnd
        }
        recognizer.scale = 1
    }

    func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.translation(in: self)
        if doesAllowScroll {
            if recognizer.state == .began {
                delegate?.waveformDidBeginPanning?(self)
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
