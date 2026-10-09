# FDWaveformView

[![ci](https://github.com/fulldecent/FDWaveformView/actions/workflows/ci.yml/badge.svg)](https://github.com/fulldecent/FDWaveformView/actions/workflows/ci.yml)

FDWaveformView displays audio waveforms in Swift apps so users can preview audio, scrub, and pick positions with ease.

**:hatching_chick: Virtual tip jar: <https://amazon.com/hz/wishlist/ls/EE78A23EEGQB>**

## Usage

Add an `FDWaveformView` programmatically, then load audio. If your file is missing an extension, see the [Stack Overflow answer on AVURLAsset without extensions](https://stackoverflow.com/questions/9290972/is-it-possible-to-make-avurlasset-work-without-a-file-extension).

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
- Supports iOS 15+, visionOS 1+, and Swift tools version 6.4, as declared in `Package.swift`. Xcode 26 cannot load that tools version.
- Includes unit tests that run on GitHub Actions.

## Installation

Add this package with Swift Package Manager. In Xcode that is File > Add Package Dependencies...

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

GitHub Actions runs the suite on the [Xcode 27 runner image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md). The default Xcode there is 27.0, and that copy provides an iPhone 17 simulator on iOS 27.0. The command is:

```sh
xcodebuild test -scheme FDWaveformView -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0'
```

`xcrun swift test` builds the package for macOS. These sources import UIKit, so that command does not compile this package.

On another Xcode, list the simulators that copy of Xcode can see and pass one of those ids. `xcodebuild` only accepts destinations from the selected Xcode, so an id printed by a different install will fail.

```sh
xcrun simctl list devices available | grep iPhone
xcodebuild test -scheme FDWaveformView -destination 'id=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
```

The Example app target deploys to iOS 18.6, so its simulator has to be iOS 18.6 or newer:

```sh
xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'id=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
```

## Releases

Commit messages use `fix:`, `feat:` or `BREAKING CHANGE:`. [Release Please](https://github.com/googleapis/release-please) opens a release pull request from those messages. Merging that pull request runs [.github/workflows/release.yml](.github/workflows/release.yml), which tests the package and publishes the GitHub Release.

[`.release-please-manifest.json`](.release-please-manifest.json) is the last released version, `5.1.1`. Tags do not use a `v` prefix, because the existing tags do not. Swift Package Manager installs from the git tag. This module imports UIKit, so the release does not attach a Linux static library.

In the repository settings, under Actions, General, Workflow permissions, select read and write permissions and check "Allow GitHub Actions to create and approve pull requests". Under General, Releases, enable release immutability.

## Contributing

- This project's layout is based on <https://github.com/fulldecent/swift6-module-template>
- Ignore rules are inlined from [Swift.gitignore](https://github.com/github/gitignore/blob/main/Swift.gitignore) and [Global/Xcode.gitignore](https://github.com/github/gitignore/blob/main/Global/Xcode.gitignore). The macOS and secret rules above them come from [project-template](https://github.com/fulldecent/project-template).
- Releases follow [swift6-module-template](https://github.com/fulldecent/swift6-module-template/blob/v16.5.0/.github/workflows/release.yml), release 16.5.0. The published result here is the git tag. That template publishes a Linux static library, and this module imports UIKit.
