# FDWaveformView

FDWaveformView displays audio waveforms in Swift apps so users can preview audio, scrub, and pick positions with ease.

## Usage

Add an `FDWaveformView` in Interface Builder or programmatically, then load audio. If your file is missing an extension, see the [Stack Overflow answer on AVURLAsset without extensions](https://stackoverflow.com/questions/9290972/is-it-possible-to-make-avurlasset-work-without-a-file-extension).

```swift
let thisBundle = Bundle(for: type(of: self))
let url = thisBundle.url(forResource: "Submarine", withExtension: "aiff")
self.waveform.audioURL = url
```

![Waveform overview showing loaded audio](https://i.imgur.com/5N7ozog.png)

## Features

### Highlight playback

Highlight a portion of the waveform to show progress.

```swift
self.waveform.highlightedSamples = 0..<(self.waveform.totalSamples / 2)
```

![Waveform with highlighted progress](https://i.imgur.com/fRrHiRP.png)

### Zoom for detail

Render only the visible portion while progressively adding detail as you zoom.

```swift
self.waveform.zoomSamples = 0..<(self.waveform.totalSamples / 4)
```

![Zoomed waveform segment](https://i.imgur.com/JQOKQ3o.png)

### Gesture control

Allow scrubbing, stretching, and scrolling with built-in gestures.

```swift
self.waveform.doesAllowScrubbing = true
self.waveform.doesAllowStretch = true
self.waveform.doesAllowScroll = true
```

![Gesture-driven waveform interaction](https://i.imgur.com/8oR7cpq.gif)

### Animated updates

Animate property changes for smoother UI feedback.

```swift
UIView.animate(withDuration: 0.3) {
    let randomNumber = arc4random() % self.waveform.totalSamples
    self.waveform.highlightedSamples = 0 ..< randomNumber
}
```

![Animated waveform highlight change](https://i.imgur.com/EgxXaCY.gif)

### Rendering quality

- Antialiased waveforms draw extra pixels to avoid jagged edges.
- Autolayout-driven size changes trigger re-rendering to prevent pixelation.
- Supports iOS 12+ and Swift 5.
- Includes unit tests running on GitHub Actions.

## Installation

Use Swift Package Manager: in Xcode choose File > Swift Packages > Add Package Dependency and point to this repository. Legacy installation options are available if needed.

## API

Following is the complete API for this module:

- `FDWaveformView` (open class, subclass of `UIView`)
  - `init()` (public init) default initializer
  - `delegate: FDWaveformViewDelegate?` (open var, get/set) delegate for loading and rendering callbacks
  - `audioURL: URL?` (open var, get/set) audio file to render asynchronously
  - `totalSamples: Int` (open var, get) sample count of the loaded asset
  - `highlightedSamples: CountableRange<Int>?` (open var, get/set) range tinted with `progressColor`
  - `zoomSamples: CountableRange<Int>` (open var, get/set) range currently displayed
  - `doesAllowScrubbing: Bool` (open var, get/set) enable tap and pan scrubbing
  - `doesAllowStretch: Bool` (open var, get/set) enable pinch-to-zoom
  - `doesAllowScroll: Bool` (open var, get/set) enable panning across the waveform
  - `wavesColor: UIColor` (open var, get/set) tint for the base waveform image
  - `progressColor: UIColor` (open var, get/set) tint for the highlighted waveform
  - `loadingInProgress: Bool` (open var, get) indicates async load in progress

- `FDWaveformViewDelegate` (@objc public protocol)
  - `waveformViewWillRender(_ waveformView: FDWaveformView)` (optional)
  - `waveformViewDidRender(_ waveformView: FDWaveformView)` (optional)
  - `waveformViewWillLoad(_ waveformView: FDWaveformView)` (optional)
  - `waveformViewDidLoad(_ waveformView: FDWaveformView)` (optional)
  - `waveformDidBeginPanning(_ waveformView: FDWaveformView)` (optional)
  - `waveformDidEndPanning(_ waveformView: FDWaveformView)` (optional)
  - `waveformDidEndScrubbing(_ waveformView: FDWaveformView)` (optional)

A couple other things are exposed that we do not consider public API:

- `FDWaveformView` (implements `UIGestureRecognizerDelegate`)
  - `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:) -> Bool`

## Testing

Find an available simulator:

```sh
xcrun simctl list devices available | grep iPhone
```

Build and test using a simulator ID from the output:

```sh
# Build the library
xcodebuild build -scheme FDWaveformView -destination 'id=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'

# Run unit tests
xcodebuild test -scheme FDWaveformView -destination 'id=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'

# Build the Example app (requires a newer iOS simulator)
cd Example
xcodebuild build -scheme Example -destination 'id=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
```

## Contributing

- This project's layout is based on <https://github.com/fulldecent/swift6-module-template>
