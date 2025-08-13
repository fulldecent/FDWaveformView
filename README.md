# FDWaveformView

FDWaveformView is an easy way to display an audio waveform in your app. It is a nice visualization to show a playing audio file or to select a position in a file.

**:hatching_chick: Virtual tip jar: https://amazon.com/hz/wishlist/ls/EE78A23EEGQB**

Usage
-----

To use it, add an `FDWaveformView` using Interface Builder or programmatically and then just load your audio as per this example. Note: if your audio file does not have file extension, see <a href="https://stackoverflow.com/questions/9290972/is-it-possible-to-make-avurlasset-work-without-a-file-extension">this SO question</a>.

```swift
let thisBundle = Bundle(for: type(of: self))
let url = thisBundle.url(forResource: "Submarine", withExtension: "aiff")
self.waveform.audioURL = url
```

<p align="center">
<img src="https://i.imgur.com/5N7ozog.png" width=250>
</p>

Features
--------

**Set play progress** to highlight part of the waveform:

```swift
self.waveform.highlightedSamples = 0..<(self.waveform.totalSamples / 2)
```

<p align="center">
<img src="https://i.imgur.com/fRrHiRP.png" width=250>
</p>

**Zoom in** to show only part of the waveform, of course, zooming in will smoothly re-render to show progressively more detail:

```swift
self.waveform.zoomSamples = 0..<(self.waveform.totalSamples / 4)
```

<p align="center">
<img src="https://i.imgur.com/JQOKQ3o.png" width=250>
</p>

**Enable gestures** for zooming in, panning around or scrubbing:

```swift
self.waveform.doesAllowScrubbing = true
self.waveform.doesAllowStretch = true
self.waveform.doesAllowScroll = true
```

<p align="center">
<img src="https://i.imgur.com/8oR7cpq.gif" width=250 loop=infinite>
</p>

**Supports animation** for changing properties:

```swift
UIView.animate(withDuration: 0.3) {
    let randomNumber = arc4random() % self.waveform.totalSamples
    self.waveform.highlightedSamples = 0..<randomNumber
}
```

<p align="center">
<img src="https://i.imgur.com/EgxXaCY.gif" width=250 loop=infinite>
</p>


Creates **antialiased waveforms** by drawing more pixels than are seen on screen. Also, if you resize me (autolayout) I will render more detail if necessary to avoid pixelation.

Supports **iOS12+** and Swift 5.

**Includes unit tests**, todo: run these on GitHub Actions

## Installation

Add this to your project using Swift Package Manager. In Xcode that is simply: File > Swift Packages > Add Package Dependency... and you're done. Alternative installations options are shown below for legacy projects.

## Contributing

* This project's layout is based on https://github.com/fulldecent/swift5-module-template
