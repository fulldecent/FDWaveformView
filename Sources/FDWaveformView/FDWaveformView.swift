//
// Copyright (c) William Entriken and the FDWaveformView contributors
//
import Accelerate
import UIKit

// FROM http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader
// DO SEE http://stackoverflow.com/questions/1191868/uiimageview-scaling-interpolation
// see http://stackoverflow.com/questions/3514066/how-to-tint-a-transparent-png-image-in-iphone

/// A view for rendering audio waveforms
open class FDWaveformView: UIView {
  /// A delegate to accept progress reporting
  open weak var delegate: FDWaveformViewDelegate?

  /// The audio file to render
  open var audioURL: URL? {
    didSet {
      guard let audioURL = audioURL else {
        NSLog("FDWaveformView received nil audioURL")
        dataSource = nil
        return
      }

      loadingInProgress = true
      delegate?.waveformViewWillLoad?(self)

      let dataSource = FDWaveformAudioDataSource(audioURL: audioURL)
      self.dataSource = dataSource
      // Note: waveformViewDidLoad is called after loadTotalSamples completes
    }
  }

  /// The total number of audio samples in the file
  /// This value is calculated from the asset's duration and sample rate.
  /// Note: This is a cached value that is loaded asynchronously.
  private var cachedTotalSamples: Int = 0

  open var totalSamples: Int {
    return cachedTotalSamples
  }

  /// Loads the total sample count asynchronously and triggers a layout update when ready.
  private func loadTotalSamples() {
    guard let dataSource = dataSource else {
      cachedTotalSamples = 0
      return
    }

    Task {
      let count = await dataSource.numberOfSamples()
      await MainActor.run {
        self.cachedTotalSamples = count
        self.zoomSamples = (0..<count).clamped(to: 0..<max(1, count))
        self.loadingInProgress = false
        self.delegate?.waveformViewDidLoad?(self)
        self.setNeedsDisplay()
        self.setNeedsLayout()
      }
    }
  }

  /// The samples to be highlighted in a different color
  open var highlightedSamples: CountableRange<Int>? = nil {
    didSet {
      guard totalSamples > 0 else {
        return
      }
      let highlightStartPortion =
        CGFloat(highlightedSamples?.startIndex ?? 0) / CGFloat(totalSamples)
      let highlightLastPortion =
        CGFloat(highlightedSamples?.last ?? 0) / CGFloat(totalSamples)
      let highlightWidthPortion = highlightLastPortion - highlightStartPortion
      self.clipping.frame = CGRect(
        x: self.frame.width * highlightStartPortion, y: 0,
        width: self.frame.width * highlightWidthPortion, height: self.frame.height)
      setNeedsLayout()
    }
  }

  /// The samples to be displayed
  open var zoomSamples: CountableRange<Int> = 0..<0 {
    didSet {
      setNeedsDisplay()
      setNeedsLayout()
    }
  }

  /// Whether to allow tap and pan gestures to change highlighted range
  /// Pan gives priority to `doesAllowScroll` if this and that are both `true`
  open var doesAllowScrubbing = true

  /// Whether to allow pinch gesture to change zoom
  open var doesAllowStretch = true

  /// Whether to allow pan gesture to change zoom
  open var doesAllowScroll = true

  /// Supported waveform types
  public enum WaveformType {
    case linear, logarithmic
  }

  /// Type of waveform to display
  open var waveformType: WaveformType = .logarithmic {
    didSet {
      setNeedsDisplay()
      setNeedsLayout()
    }
  }

  /// The color of the waveform
  open var wavesColor = UIColor.black {
    didSet {
      imageView.tintColor = wavesColor
    }
  }

  /// The color of the highlighted waveform (see `highlightedSamples`
  open var progressColor = UIColor.blue {
    didSet {
      highlightedImage.tintColor = progressColor
    }
  }

  //TODO: MAKE PUBLIC

  /// The portion of extra pixels to render left and right of the viewable region
  private var horizontalBleedTarget = 0.5

  /// The required portion of extra pixels to render left and right of the viewable region
  /// If this portion is not available then a re-render will be performed
  private var horizontalBleedAllowed = 0.1...3.0

  /// The number of horizontal pixels to render per visible pixel on the screen (for anti-aliasing)
  private var horizontalOverdrawTarget = 3.0

  /// The required number of horizontal pixels to render per visible pixel on the screen (for anti-aliasing)
  /// If this number is not available then a re-render will be performed
  private var horizontalOverdrawAllowed = 1.5...5.0

  /// The number of vertical pixels to render per visible pixel on the screen (for anti-aliasing)
  private var verticalOverdrawTarget = 2.0

  /// The required number of vertical pixels to render per visible pixel on the screen (for anti-aliasing)
  /// If this number is not available then a re-render will be performed
  private var verticalOverdrawAllowed = 1.0...3.0

  /// The "zero" level (in dB)
  fileprivate let noiseFloor: CGFloat = -50.0

  /// Minimum number of samples that can be displayed (limits maximum zoom)
  private let minimumZoomSamples = 10

  // Mark - Private vars

  /// Whether rendering for the current asset failed
  private var renderForCurrentAssetFailed = false

  /// Current data source to be used for rendering
  private var dataSource: FDWaveformDataSource? {
    didSet {
      cachedTotalSamples = 0  // Reset cache when new data source is set
      waveformImage = nil
      zoomSamples = 0..<0
      highlightedSamples = nil
      inProgressWaveformRenderOperation = nil
      cachedWaveformRenderOperation = nil
      renderForCurrentAssetFailed = false

      setNeedsDisplay()
      setNeedsLayout()

      // Load sample count asynchronously
      loadTotalSamples()
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
    switch waveformType {
    case .linear: return .linear
    case .logarithmic: return .logarithmic(noiseFloor: noiseFloor)
    }
  }

  /// Represents the status of the waveform renderings
  fileprivate enum CacheStatus {
    case dirty
    case notDirty(cancelInProgressRenderOperation: Bool)
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

  /// Accumulated fractional pan delta (in samples) for smooth slow panning
  fileprivate var accumulatedPanDelta: CGFloat = 0

  /// Gesture recognizer
  fileprivate var pinchRecognizer = UIPinchGestureRecognizer()

  /// Gesture recognizer
  fileprivate var panRecognizer = UIPanGestureRecognizer()

  /// Gesture recognizer
  fileprivate var tapRecognizer = UITapGestureRecognizer()

  /// Whether rendering is happening asynchronously
  fileprivate var renderingInProgress = false

  /// Whether loading is happening asynchronously
  open private(set) var loadingInProgress = false

  func setup() {
    addSubview(imageView)
    clipping.addSubview(highlightedImage)
    addSubview(clipping)
    clipsToBounds = true

    pinchRecognizer = UIPinchGestureRecognizer(
      target: self, action: #selector(handlePinchGesture))
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
    guard !renderForCurrentAssetFailed else {
      return .notDirty(cancelInProgressRenderOperation: true)
    }

    let isInProgressRenderOperationDirty = isWaveformRenderOperationDirty(
      inProgressWaveformRenderOperation)
    let isCachedRenderOperationDirty = isWaveformRenderOperationDirty(
      cachedWaveformRenderOperation)

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

    let requiredSamples = zoomSamples.clamped(to: 0..<max(1, totalSamples))
      .extended(byFactor: horizontalBleedAllowed.lowerBound)
      .clamped(to: 0..<max(1, totalSamples))
    if requiredSamples.clamped(to: renderOperation.sampleRange) != requiredSamples {
      return true
    }

    let allowedSamples = zoomSamples.clamped(to: 0..<max(1, totalSamples))
      .extended(byFactor: horizontalBleedAllowed.upperBound)
      .clamped(to: 0..<max(1, totalSamples))
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
    guard dataSource != nil && !zoomSamples.isEmpty else {
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
    let clampedZoomSamples = zoomSamples.clamped(to: 0..<max(1, totalSamples))
    if let cachedSampleRange = cachedWaveformRenderOperation?.sampleRange,
      !cachedSampleRange.isEmpty
    {
      scaleX =
        CGFloat(clampedZoomSamples.lowerBound - cachedSampleRange.lowerBound)
        / CGFloat(cachedSampleRange.count)
      scaleW = CGFloat(cachedSampleRange.count) / CGFloat(clampedZoomSamples.count)
      if let highlightedSamples = highlightedSamples {
        highlightScaleX =
          CGFloat(highlightedSamples.lowerBound - clampedZoomSamples.lowerBound)
          / CGFloat(cachedSampleRange.count)
        highlightClipScaleL = max(
          0.0,
          CGFloat(
            (highlightedSamples.lowerBound - cachedSampleRange.lowerBound)
              - (clampedZoomSamples.lowerBound - cachedSampleRange.lowerBound))
            / CGFloat(clampedZoomSamples.count))
        highlightClipScaleR = min(
          1.0,
          1.0 - CGFloat((clampedZoomSamples.upperBound - highlightedSamples.upperBound))
            / CGFloat(clampedZoomSamples.count))
      }
    }
    let childFrame = CGRect(
      x: frame.width * scaleW * -scaleX,
      y: 0,
      width: frame.width * scaleW,
      height: frame.height)
    imageView.frame = childFrame
    if let highlightedSamples = highlightedSamples,
      highlightedSamples.overlaps(clampedZoomSamples)
    {
      clipping.frame = CGRect(
        x: frame.width * highlightClipScaleL,
        y: 0,
        width: frame.width * (highlightClipScaleR - highlightClipScaleL),
        height: frame.height)
      if 0 < clipping.frame.minX {
        highlightedImage.frame = childFrame.offsetBy(
          dx: frame.width * scaleW * -highlightScaleX, dy: 0)
      } else {
        highlightedImage.frame = childFrame
      }
      clipping.isHidden = false
    } else {
      clipping.isHidden = true
    }
  }

  func renderWaveform() {
    guard let dataSource = dataSource else { return }
    let clampedZoomSamples = zoomSamples.clamped(to: 0..<max(1, totalSamples))
    guard !clampedZoomSamples.isEmpty else { return }

    let renderSamples = clampedZoomSamples.extended(byFactor: horizontalBleedTarget).clamped(
      to: 0..<max(1, totalSamples))
    let widthInPixels = floor(frame.width * CGFloat(horizontalOverdrawTarget))
    let heightInPixels = frame.height * CGFloat(horizontalOverdrawTarget)
    let imageSize = CGSize(width: widthInPixels, height: heightInPixels)
    let renderFormat = FDWaveformRenderFormat(
      type: waveformRenderType, wavesColor: .black, scale: desiredImageScale)

    let waveformRenderOperation = FDWaveformRenderOperation(
      dataSource: dataSource, totalSamples: totalSamples, imageSize: imageSize,
      sampleRange: renderSamples,
      format: renderFormat
    ) { [weak self] image in
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
  public static func == (lhs: FDWaveformType, rhs: FDWaveformType) -> Bool {
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
      // Convert normalized [0, 1] samples to dB scale
      // Formula: dB = 20 * log10(amplitude)
      // For amplitude in [0, 1]: dB ranges from -infinity to 0
      // We use a small epsilon to avoid log(0) = -infinity
      let epsilon: Float = 1e-10
      for i in 0..<normalizedSamples.count {
        let amplitude = max(normalizedSamples[i], epsilon)
        var dB = 20.0 * log10(amplitude)
        // Clip to [noiseFloor, 0]
        dB = max(dB, Float(noiseFloor))
        dB = min(dB, 0)
        // Normalize to [0, 1] where 0 = noiseFloor and 1 = 0 dB
        normalizedSamples[i] = (dB - Float(noiseFloor)) / (0 - Float(noiseFloor))
      }
    }
  }
}

extension FDWaveformView: UIGestureRecognizerDelegate {
  public func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return true
  }

  @objc func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
    guard doesAllowStretch else { return }

    // Always handle state changes first, before any early returns
    switch recognizer.state {
    case .began:
      if firstGesture == .none {
        firstGesture = .pinch
      }
    case .ended, .cancelled:
      firstGesture = .none
      return  // Nothing more to do on end
    default:
      break
    }

    // Skip if no actual scale change
    guard recognizer.scale != 1 else { return }

    let clampedZoomSamples = zoomSamples.clamped(to: 0..<max(1, totalSamples))
    let zoomRangeSamples = CGFloat(clampedZoomSamples.count)

    // Calculate desired new zoom range using the full accumulated scale (not resetting each frame)
    let desiredZoomRangeSamples = zoomRangeSamples / recognizer.scale
    var newZoomRangeSamples = Int(round(desiredZoomRangeSamples))

    // Enforce minimum and maximum zoom range
    let maxZoomRange = totalSamples
    newZoomRangeSamples = max(minimumZoomSamples, min(maxZoomRange, newZoomRangeSamples))

    // Check if we're at zoom limits
    let isAtMinZoom = clampedZoomSamples.count <= minimumZoomSamples
    let isAtMaxZoom = clampedZoomSamples.count >= totalSamples
    let isZoomingIn = recognizer.scale > 1
    let isZoomingOut = recognizer.scale < 1

    if (isAtMinZoom && isZoomingIn) || (isAtMaxZoom && isZoomingOut) {
      // Reset scale so reversing direction works immediately
      recognizer.scale = 1
      return
    }

    // Only apply if there's an actual change
    if newZoomRangeSamples == clampedZoomSamples.count {
      // Don't reset scale - let it accumulate until we have enough for a change
      return
    }

    // Calculate pinch center for zoom positioning
    let pinchCenterFraction = recognizer.location(in: self).x / bounds.width
    let pinchCenterSample =
      clampedZoomSamples.lowerBound + Int(zoomRangeSamples * pinchCenterFraction)

    // Calculate new start position to keep pinch center stable
    let samplesBeforeCenter = Int(CGFloat(newZoomRangeSamples) * pinchCenterFraction)
    let newZoomStart = pinchCenterSample - samplesBeforeCenter
    let newZoomEnd = newZoomStart + newZoomRangeSamples

    zoomSamples = (newZoomStart..<newZoomEnd).clamped(to: 0..<max(1, totalSamples))

    // Only reset scale after we've applied a change
    recognizer.scale = 1
  }

  @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
    let clampedZoomSamples = zoomSamples.clamped(to: 0..<max(1, totalSamples))
    guard !clampedZoomSamples.isEmpty else { return }

    // Don't allow panning while pinching is active
    if firstGesture == .pinch {
      return
    }

    // Don't process multi-touch as pan
    if recognizer.numberOfTouches > 1 {
      return
    }

    switch recognizer.state {
    case .began:
      firstGesture = .pan
      accumulatedPanDelta = 0
    case .ended, .cancelled:
      firstGesture = .none
      accumulatedPanDelta = 0
    case .changed:
      break
    default:
      return
    }

    if doesAllowScroll {
      if clampedZoomSamples.count == totalSamples {
        return
      }

      if recognizer.state == .began {
        delegate?.waveformDidBeginPanning?(self)
      }

      let point = recognizer.translation(in: self)
      recognizer.setTranslation(CGPoint.zero, in: self)

      let samplesPerPixel = CGFloat(clampedZoomSamples.count) / bounds.width
      let deltaSamples = -point.x * samplesPerPixel

      accumulatedPanDelta += deltaSamples

      let wholeSampleDelta = Int(accumulatedPanDelta)
      if wholeSampleDelta != 0 {
        let maxForwardDelta = totalSamples - clampedZoomSamples.endIndex
        let maxBackwardDelta = -clampedZoomSamples.startIndex
        let clampedDelta = max(maxBackwardDelta, min(maxForwardDelta, wholeSampleDelta))

        if clampedDelta != 0 {
          zoomSamples =
            (clampedZoomSamples.startIndex + clampedDelta)
            ..<(clampedZoomSamples.endIndex + clampedDelta)
        }

        accumulatedPanDelta -= CGFloat(wholeSampleDelta)
      }

      if recognizer.state == .ended {
        delegate?.waveformDidEndPanning?(self)
      }
    } else if doesAllowScrubbing {
      let rangeSamples = CGFloat(clampedZoomSamples.count)
      let scrubLocation = min(max(recognizer.location(in: self).x, 0), frame.width)
      highlightedSamples =
        0..<Int(
          (CGFloat(clampedZoomSamples.startIndex) + rangeSamples * scrubLocation
            / bounds.width))
      delegate?.waveformDidEndScrubbing?(self)
    }
  }

  @objc func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
    if doesAllowScrubbing {
      let clampedZoomSamples = zoomSamples.clamped(to: 0..<max(1, totalSamples))
      let rangeSamples = CGFloat(clampedZoomSamples.count)
      highlightedSamples =
        0..<Int(
          (CGFloat(clampedZoomSamples.startIndex) + rangeSamples
            * recognizer.location(in: self).x / bounds.width))
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
    return lowerBound.advanced(by: -amountToMove)..<upperBound.advanced(by: amountToMove)
  }
}
