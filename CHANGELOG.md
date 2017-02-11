# Change Log
All notable changes to this project will be documented in this file.
`FDWaveformView` adheres to [Semantic Versioning](http://semver.org/).

---

## [Master](https://github.com/fulldecent/FDWaveformView/compare/2.0.0...master)
#### Added
- Allow scrubbing independantly of scrolling
  - Added by [Doug Earnshaw](https://github.com/haydenholligan)
- Tidy up Swift 3.0 conversion, remove some forced unwraps & generally make more Swifty
  - Added by [Doug Earnshaw](https://github.com/haydenholligan)
- Improved accuracy of waveform rendering
  - Added by [Kip Nicol](https://github.com/ospr)
- Fixed waveform rendering for large audio files
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for rendering waveform images outside of a view (See `FDWaveformRenderOperation`)
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for rendering linear waveforms
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for changing `wavesColor` and `progressColor` after waveform was rendered
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for updating waveform type and color to iOS Example app.
  - Added by [Kip Nicol](https://github.com/ospr)
- Fixed bug which could prevent waveform from fitting new view size if rendering was in progress during a view resize
  - Added by [Kip Nicol](https://github.com/ospr)
- Fixed bug which caused `waveformViewDidLoad()` to not be called after the audio file was loaded
  - Added by [Kip Nicol](https://github.com/ospr)
- Fixed bug which caused subsequent waveform renderings for new audioURLs to never complete if there was an error with a previous render
  - Added by [Kip Nicol](https://github.com/ospr)
- Fixed bug which could cause a crash (divide by zero error) if the view's width was 0
  - Added by [Kip Nicol](https://github.com/ospr)

---

## [2.0.0](https://github.com/fulldecent/FDWaveformView/releases/tag/2.0.0)
Released on 2016-09-27.

#### Added
- Automated CocoaPods Quality Indexes testing
  - Added by [Hayden Holligan](https://github.com/haydenholligan)
- Use GPU to process waveforms
  - Added by [Hayden Holligan](https://github.com/haydenholligan)

---

## [1.0.2](https://github.com/fulldecent/FDWaveformView/releases/tag/1.0.2)
Released on 2016-09-02.

#### Fixed
- Corrected rendering, fixed typo
  - Added by [William Entriken](https://github.com/fulldecent) in Regards to Issue
  [#62](https://github.com/fulldecent/FDWaveformView/issues/62).

---

## [1.0.1](https://github.com/fulldecent/FDWaveformView/releases/tag/1.0.1)
Released on 2016-08-02.

#### Fixed
- Fixed Podspec for Swift files
  - Added by [William Entriken](https://github.com/fulldecent) in Regards to Issue
  [#61](https://github.com/fulldecent/FDWaveformView/issues/61).

---

## [1.0.0](https://github.com/fulldecent/FDWaveformView/releases/tag/1.0.0)
Released on 2016-06-27.

#### Added
- Full API documentation
  - Added by [William Entriken](https://github.com/fulldecent) in Regards to Issue
  [#53](https://github.com/fulldecent/FDWaveformView/issues/53).
- Release process documentation
  - Added by [William Entriken](https://github.com/fulldecent) in Regards to Issue
  [#57](https://github.com/fulldecent/FDWaveformView/issues/57).
- Change Log
  - Added by [William Entriken](https://github.com/fulldecent) in Regards to Issue
  [#54](https://github.com/fulldecent/FDWaveformView/issues/54).
- Swift Package Manager support
  - Added by [William Entriken](https://github.com/fulldecent) in Regards to Issue
  [#52](https://github.com/fulldecent/FDWaveformView/issues/52).

---

## [0.3.2](https://github.com/fulldecent/FDWaveformView/releases/tag/0.3.2)
Released on 2016-04-10.

#### Added
- Carthage support
  - Added by [William Entriken](https://github.com/fulldecent)

---

## [0.3.0](https://github.com/fulldecent/FDWaveformView/releases/tag/0.3.0)
Released on 2016-03-29.

#### Added
- Separate scrolling and pinching options
  - Added by [Rudy Mutter](https://github.com/rmutter)

#### Updated
- Uses recommended CocoPods project format
  - Added by [William Entriken](https://github.com/fulldecent)

#### Fixed
- That warning everyone was seeing
  - Added by [Yin Cheng](https://github.com/msching)

---

## [0.2.2](https://github.com/fulldecent/FDWaveformView/releases/tag/0.2.2)
Released on 2015-09-14.

#### Added
- Profiling tests
  - Added by [William Entriken](https://github.com/fulldecent)

---

## [0.1.2](https://github.com/fulldecent/FDWaveformView/releases/tag/0.1.2)
Released on 2014-01-06.

#### Added
- First cocoapods release
  - Added by [William Entriken](https://github.com/fulldecent)

---

## [0.1.0](https://github.com/fulldecent/FDWaveformView/releases/tag/0.1.0)
Released on 2013-11-04.

Initial public release.
