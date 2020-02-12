# Change Log
All notable changes to this project will be documented in this file.
`FDWaveformView` adheres to [Semantic Versioning](http://semver.org/).

---

## [Master](https://github.com/fulldecent/FDWaveformView/compare/4.0.1...master)

#### Changed

---

## [4.0.1](https://github.com/fulldecent/FDWaveformView/releases/tag/4.0.1)
Released on 2020-02-12.

#### Changed
- Switch to new standard library clamp functions
  - Added by [William Entriken](https://github.com/fulldecent)
- Fixed timescale bug for some mp4 files
  - Added by [Doug Earnshaw](https://github.com/pixlwave)

---

## [4.0.0](https://github.com/fulldecent/FDWaveformView/releases/tag/4.0.0)
Released on 2019-04-08.

#### Changed
- Converted to Swift 4.2 and Xcode 10
  - Added by [Doug Earnshaw](https://github.com/pixlwave)
- Prevent to handle panning gesture while pinching
  - Added by [HANAI, Tohru](https://github.com/reedom)
- Improve rendering of zooming and scrolling with highlight
  - Added by [HANAI, Tohru](https://github.com/reedom)
- Updated to Swift 5

---

## [3.0.1](https://github.com/fulldecent/FDWaveformView/releases/tag/3.0.1)
Released on 2017-10-27.

#### Fixed
- Fixed Highlight Samples not aligned to base waveform [#101](https://github.com/fulldecent/FDWaveformView/issues/101).
  - Added by [Jon Andersen](https://github.com/jonandersen)

---

## [3.0.0](https://github.com/fulldecent/FDWaveformView/releases/tag/3.0.0)
Released on 2017-10-27.

#### Changed
- Now supporting Swift 4.0

---

## [2.2.1](https://github.com/fulldecent/FDWaveformView/releases/tag/2.2.1)
Released on 2017-05-31.

#### Changed
- Now using ranges in the API where appropriate
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
  [#76](https://github.com/fulldecent/FDWaveformView/issues/86).

#### Fixed
- Fixed a retain cycle in completion handler of waveform render operation
  - Added by [Philippe Jayet](https://github.com/pjay)
- Cancel waveform render operation when view is released
  - Added by [Philippe Jayet](https://github.com/pjay)

---

## [2.2.0](https://github.com/fulldecent/FDWaveformView/releases/tag/2.2.0)
Released on 2017-05-03.

#### Added
- Improved accuracy of waveform rendering
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for rendering waveform images outside of view (See `FDWaveformRenderOperation`)
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for rendering linear waveforms
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for changing `wavesColor` and `progressColor` after waveform was rendered
  - Added by [Kip Nicol](https://github.com/ospr)
- Added support for updating waveform type and color to iOS Example app.
  - Added by [Kip Nicol](https://github.com/ospr)

#### Fixed
- Fixed waveform rendering for large audio files
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

## [2.1.0](https://github.com/fulldecent/FDWaveformView/releases/tag/2.1.0)
Released on 2017-04-15.

#### Added
- Improved example app to include more options
  - Added by [William Entriken](https://github.com/fulldecent)
- Allowed animation for changes to zoom
  - Added by [William Entriken](https://github.com/fulldecent)

#### Fixed
- Improved accuracy of waveform rendering
  - Added by [Kip Nicol](https://github.com/ospr)
- Fixed waveform rendering for large audio files
  - Added by [Kip Nicol](https://github.com/ospr)
- Fixed crash with quick load time
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
  [#76](https://github.com/fulldecent/FDWaveformView/issues/76).

---

## [2.0.1](https://github.com/fulldecent/FDWaveformView/releases/tag/2.0.1)
Released on 2017-02-16.

#### Added
- Allowed scrubbing independantly of scrolling
  - Added by [Doug Earnshaw](https://github.com/pixlwave)
- Tidied up Swift 3.0 conversion, removed some forced unwraps & generally made more swifty
  - Added by [Doug Earnshaw](https://github.com/pixlwave)

---

## [2.0.0](https://github.com/fulldecent/FDWaveformView/releases/tag/2.0.0)
Released on 2016-09-27.

#### Added
- Automated CocoaPods Quality Indexes testing
  - Added by [Hayden Holligan](https://github.com/haydenholligan)
- Used GPU to process waveforms
  - Added by [Hayden Holligan](https://github.com/haydenholligan)

---

## [1.0.2](https://github.com/fulldecent/FDWaveformView/releases/tag/1.0.2)
Released on 2016-09-02.

#### Fixed
- Corrected rendering, fixed typo
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
  [#62](https://github.com/fulldecent/FDWaveformView/issues/62).

---

## [1.0.1](https://github.com/fulldecent/FDWaveformView/releases/tag/1.0.1)
Released on 2016-08-02.

#### Fixed
- Fixed Podspec for Swift files
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
  [#61](https://github.com/fulldecent/FDWaveformView/issues/61).

---

## [1.0.0](https://github.com/fulldecent/FDWaveformView/releases/tag/1.0.0)
Released on 2016-06-27.

#### Added
- Full API documentation
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
  [#53](https://github.com/fulldecent/FDWaveformView/issues/53).
- Release process documentation
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
  [#57](https://github.com/fulldecent/FDWaveformView/issues/57).
- Changed Log
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
  [#54](https://github.com/fulldecent/FDWaveformView/issues/54).
- Swift Package Manager support
  - Added by [William Entriken](https://github.com/fulldecent) in regards to issue
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
- Separated scrolling and pinching options
  - Added by [Rudy Mutter](https://github.com/rmutter)

#### Updated
- Used recommended CocoPods project format
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
