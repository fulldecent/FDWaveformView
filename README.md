FDWaveformView
==============

FDWaveformView is an easy way to display an audio waveform in your app. It is a nice visualization to show a playing audio file.

Usage
-----

To use it, add a `FDWaveformView` using Interface Builder or programmatically and then just load your audio. Warning, if your audio file does not have file extension, see <a href="https://stackoverflow.com/questions/9290972/is-it-possible-to-make-avurlasset-work-without-a-file-extension">this SO question</a>.

An example of creating a waveform:

    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSString *filePath = [thisBundle pathForResource:@"Submarine" ofType:@"aiff"];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    self.waveform.audioURL = url;

<p align="center">
  <img src="http://i.imgur.com/EbEqBEz.png" width=250>
</p>

Features
--------

**Set play progress** to highlight part of the waveform:

    self.waveform.progressSamples = self.waveform.totalSamples / 2;

**Zoom in** to show only part of the waveform, of course, zooming in will smoothly rerender to show progressively more detail:

    self.waveform.zoomStartSamples = 0;
    self.waveform.zoomEndSamples = self.waveform.totalSamples / 4;

**Enable gestures** for zooming in, panning around or scrubbing:

    self.waveform.doesAllowScrubbing = YES;
    self.waveform.doesAllowStretchAndScroll = YES;

**Supports animation** for changing properties:

    [UIView animateWithDuration:0.3 animations:^{
        NSInteger randomNumber = arc4random() % self.waveform.totalSamples;
        self.waveform.progressSamples = randomNumber;
    }];

Creates **antialiased waveforms** by drawing more pixels than are seen on screen. Also, if you resize me (autolayout) I will render more detail if necessary to avoid pixelation.

**Supports ARC** and **iOS5+**.

Installation
------------

  1. Add `pod 'FDWaveformView', '~> 0.2.0'` to your <a href="https://github.com/AFNetworking/AFNetworking/wiki/Getting-Started-with-AFNetworking">Podfile</a>
  2. The the API documentation under "Class Reference" at http://cocoadocs.org/docsets/FDWaveformView/
  3. Add your project to "I USE THIS" at https://www.cocoacontrols.com/controls/fdwaveformview to keep more project updates coming
