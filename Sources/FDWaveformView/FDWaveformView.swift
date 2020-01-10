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

    /// The samples to be highlighted in a different color
    /*@IBInspectable*/ open var highlightedSamples: CountableRange<Int>? = nil {
        didSet {
            guard totalSamples > 0 else {
                return
            }
            let highlightStartPortion = CGFloat(highlightedSamples?.startIndex ?? 0) / CGFloat(totalSamples)
            let highlightLastPortion = CGFloat(highlightedSamples?.last ?? 0) / CGFloat(totalSamples)
            let highlightWidthPortion = highlightLastPortion - highlightStartPortion
            self.clipping.frame = CGRect(x: self.frame.width * highlightStartPortion, y: 0, width: self.frame.width * highlightWidthPortion , height: self.frame.height)
            setNeedsLayout()
        }
    }

    /// The samples to be displayed
    /*@IBInspectable*/ open var zoomSamples: CountableRange<Int> = 0 ..< 0 {
        didSet {
            if zoomSamples.startIndex < 0{
                print("rip")
            }
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


    //TODO: MAKE PUBLIC

    /// The portion of extra pixels to render left and right of the viewable region
    private var horizontalBleedTarget = 0.5

    /// The required portion of extra pixels to render left and right of the viewable region
    /// If this portion is not available then a re-render will be performed
    private var horizontalBleedAllowed = 0.1 ... 3.0

    /// The number of horizontal pixels to render per visible pixel on the screen (for anti-aliasing)
    private var horizontalOverdrawTarget = 3.0

    /// The required number of horizontal pixels to render per visible pixel on the screen (for anti-aliasing)
    /// If this number is not available then a re-render will be performed
    private var horizontalOverdrawAllowed = 1.5 ... 5.0

    /// The number of vertical pixels to render per visible pixel on the screen (for anti-aliasing)
    private var verticalOverdrawTarget = 2.0

    /// The required number of vertical pixels to render per visible pixel on the screen (for anti-aliasing)
    /// If this number is not available then a re-render will be performed
    private var verticalOverdrawAllowed = 1.0 ... 3.0

    /// The "zero" level (in dB)
    fileprivate let noiseFloor: CGFloat = -50.0



    // Mark - Private vars

    /// Whether rendering for the current asset failed
    private var renderForCurrentAssetFailed = false

    /// Current audio context to be used for rendering
    private var audioContext: FDAudioContext? {
        didSet {
            waveformImage = nil
            zoomSamples = 0 ..< self.totalSamples
            highlightedSamples = nil
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

    /// Waveform type for rendering waveforms
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

    enum PressType {
        case none
        case pinch
        case pan
    }

    /// Indicates the gesture begun lastly.
    /// This helps to determine which of the continuous interactions should be active, pinching or panning.
    /// pinchRecognizer
    fileprivate var firstGesture = PressType.none

    /// Gesture recognizer
    fileprivate var pinchRecognizer = UIPinchGestureRecognizer()

    /// Gesture recognizer
    fileprivate var panRecognizer = UIPanGestureRecognizer()

    /// Gesture recognizer
    fileprivate var tapRecognizer = UITapGestureRecognizer()

    /// Whether rendering is happening asynchronously
    fileprivate var renderingInProgress = false

    /// Whether loading is happening asynchronously
    open var loadingInProgress = false

    func setup() {
        addSubview(imageView)
        clipping.addSubview(highlightedImage)
        addSubview(clipping)
        clipsToBounds = true

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

    deinit {
        inProgressWaveformRenderOperation?.cancel()
    }

    /// If the cached waveform or in-progress waveform is insufficient for the current frame
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

        if renderOperation.format.type != waveformRenderType {
            return true
        }
        if renderOperation.format.scale != desiredImageScale {
            return true
        }

        let requiredSamples = zoomSamples.extended(byFactor: horizontalBleedAllowed.lowerBound).clamped(to: 0 ..< totalSamples)
        if requiredSamples.clamped(to: renderOperation.sampleRange) != requiredSamples {
            return true
        }

        let allowedSamples = zoomSamples.extended(byFactor: horizontalBleedAllowed.upperBound).clamped(to: 0 ..< totalSamples)
        if renderOperation.sampleRange.clamped(to: allowedSamples) != renderOperation.sampleRange {
            return true
        }

        let verticalOverdrawRequested = Double(renderOperation.imageSize.height / frame.height)
        if !verticalOverdrawAllowed.contains(verticalOverdrawRequested) {
            return true
        }
        let horizontalOverdrawRequested = Double(renderOperation.imageSize.height / frame.height)
        if !horizontalOverdrawAllowed.contains(horizontalOverdrawRequested) {
            return true
        }

        return false
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        guard audioContext != nil && !zoomSamples.isEmpty else {
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

        // We need to place the images which have samples in `cachedSampleRange`
        // inside our frame which represents `startSamples..<endSamples`
        // all figures are a portion of our frame width

        var scaleX: CGFloat = 0.0
        var scaleW: CGFloat = 1.0
        var highlightScaleX: CGFloat = 0.0
        var highlightClipScaleL: CGFloat = 0.0
        var highlightClipScaleR: CGFloat = 1.0
        if let cachedSampleRange = cachedWaveformRenderOperation?.sampleRange, !cachedSampleRange.isEmpty {
            scaleX = CGFloat(zoomSamples.lowerBound - cachedSampleRange.lowerBound) / CGFloat(cachedSampleRange.count)
            scaleW = CGFloat(cachedSampleRange.count) / CGFloat(zoomSamples.count)
            if let highlightedSamples = highlightedSamples {
                highlightScaleX = CGFloat(highlightedSamples.lowerBound - zoomSamples.lowerBound) / CGFloat(cachedSampleRange.count)
                highlightClipScaleL = max(0.0, CGFloat((highlightedSamples.lowerBound - cachedSampleRange.lowerBound) - (zoomSamples.lowerBound - cachedSampleRange.lowerBound)) / CGFloat(zoomSamples.count))
                highlightClipScaleR = min(1.0, 1.0 - CGFloat((zoomSamples.upperBound - highlightedSamples.upperBound)) / CGFloat(zoomSamples.count))
            }
        }
        let childFrame = CGRect(x: frame.width * scaleW * -scaleX,
                                y: 0,
                                width: frame.width * scaleW,
                                height: frame.height)
        imageView.frame = childFrame
        if let highlightedSamples = highlightedSamples, highlightedSamples.overlaps(zoomSamples) {
            clipping.frame = CGRect(x: frame.width * highlightClipScaleL,
                                    y: 0,
                                    width: frame.width * (highlightClipScaleR - highlightClipScaleL),
                                    height: frame.height)
            if 0 < clipping.frame.minX {
                highlightedImage.frame = childFrame.offsetBy(dx: frame.width * scaleW * -highlightScaleX, dy: 0)
            } else {
                highlightedImage.frame = childFrame
            }
            clipping.isHidden = false
        } else {
            clipping.isHidden = true
        }
    }

    func renderWaveform() {
        guard let audioContext = audioContext else { return }
        guard !zoomSamples.isEmpty else { return }

        let renderSamples = zoomSamples.extended(byFactor: horizontalBleedTarget).clamped(to: 0 ..< totalSamples)
        let widthInPixels = floor(frame.width * CGFloat(horizontalOverdrawTarget))
        let heightInPixels = frame.height * CGFloat(horizontalOverdrawTarget)
        let imageSize = CGSize(width: widthInPixels, height: heightInPixels)
        let renderFormat = FDWaveformRenderFormat(type: waveformRenderType, wavesColor: .black, scale: desiredImageScale)

        let waveformRenderOperation = FDWaveformRenderOperation(audioContext: audioContext, imageSize: imageSize, sampleRange: renderSamples, format: renderFormat) { [weak self] image in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }

                strongSelf.renderForCurrentAssetFailed = (image == nil)
                strongSelf.waveformImage = image
                strongSelf.renderingInProgress = false
                strongSelf.cachedWaveformRenderOperation = self?.inProgressWaveformRenderOperation
                strongSelf.inProgressWaveformRenderOperation = nil
                strongSelf.setNeedsLayout()
                strongSelf.delegate?.waveformViewDidRender?(strongSelf)
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

    @objc func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        guard doesAllowStretch, recognizer.scale != 1 else { return }

        switch recognizer.state {
        case .began:
            if firstGesture == .none {
                // Set firstGesture to .pinch only if panning gesture is not active.
                // This enables the user to repetitively pan and zoom action.
                // If we set firstGesture to .pinch in any state then the user becomes unable
                // to pan until they release all fingers from the view.
                firstGesture = .pinch
            }
        case .ended, .cancelled:
            // This happens only if panning has not started.
            firstGesture = .none
        default:
            break
        }

        let zoomRangeSamples = CGFloat(zoomSamples.count)
        let pinchCenterSample = zoomSamples.lowerBound + Int(zoomRangeSamples * recognizer.location(in: self).x / bounds.width)
        let newZoomRangeSamples = Int(zoomRangeSamples * 1.0 / recognizer.scale)
        let newZoomStart = pinchCenterSample - Int(CGFloat(pinchCenterSample - zoomSamples.lowerBound) * 1.0 / recognizer.scale)
        let newZoomEnd = newZoomStart + newZoomRangeSamples

        zoomSamples = (newZoomStart ..< newZoomEnd).clamped(to: 0 ..< totalSamples)
        recognizer.scale = 1
    }

    @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        guard !zoomSamples.isEmpty else { return }

        // This method is called even if the user began with pinching.

        switch recognizer.state {
        case .began:
            guard firstGesture != .pinch else { return }
            firstGesture = .pan
        case .ended, .cancelled:
            let isPan = firstGesture == .pan
            firstGesture = .none
            guard isPan else { return }
        default:
            guard firstGesture == .pan, recognizer.numberOfTouches == 1 else { return }
        }

        if doesAllowScroll {
            if zoomSamples.count == totalSamples {
                // No need to handle panning
                return
            }

            if recognizer.state == .began {
                delegate?.waveformDidBeginPanning?(self)
            }

            let point = recognizer.translation(in: self)
            recognizer.setTranslation(CGPoint.zero, in: self)

            let samplesPerPixel = CGFloat(zoomSamples.count) / bounds.width
            let deltaPixels = point.x < 0
                ? min(-point.x * samplesPerPixel, CGFloat(totalSamples - zoomSamples.endIndex))
                : min(point.x * samplesPerPixel, CGFloat(zoomSamples.startIndex)) * -1
            if deltaPixels != 0 {
                zoomSamples = zoomSamples.startIndex + Int(deltaPixels) ..< zoomSamples.endIndex + Int(deltaPixels)
            }
            if recognizer.state == .ended {
                delegate?.waveformDidEndPanning?(self)
            }
        }
        else if doesAllowScrubbing {
            let rangeSamples = CGFloat(zoomSamples.count)
            let scrubLocation = min(max(recognizer.location(in: self).x, 0), frame.width)    // clamp location within the frame
            highlightedSamples = 0 ..< Int((CGFloat(zoomSamples.startIndex) + rangeSamples * scrubLocation / bounds.width))
            delegate?.waveformDidEndScrubbing?(self)
        }
    }

    @objc func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        if doesAllowScrubbing {
            let rangeSamples = CGFloat(zoomSamples.count)
            highlightedSamples = 0 ..< Int((CGFloat(zoomSamples.startIndex) + rangeSamples * recognizer.location(in: self).x / bounds.width))
            delegate?.waveformDidEndScrubbing?(self)
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

    /// The panning gesture began
    @objc optional func waveformDidBeginPanning(_ waveformView: FDWaveformView)

    /// The panning gesture ended
    @objc optional func waveformDidEndPanning(_ waveformView: FDWaveformView)

    /// The scrubbing gesture ended
    @objc optional func waveformDidEndScrubbing(_ waveformView: FDWaveformView)
}

//MARK -

extension CountableRange where Bound: Strideable {

    // Extend each bound away from midpoint by `factor`, a portion of the distance from begin to end
    func extended(byFactor factor: Double) -> CountableRange<Bound> {
        let theCount: Int = numericCast(count)
        let amountToMove: Bound.Stride = numericCast(Int(Double(theCount) * factor))
        return lowerBound.advanced(by: -amountToMove) ..< upperBound.advanced(by: amountToMove)
    }
}
