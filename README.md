FDWaveformView
==============

Reads an audio file and displays the waveform.

Features:

  * You set the URL, I figure it out from there
  * You can show play progress
  * Supports animation
  * If stretch me, I will redraw to avoid pixelation
  * Supports iOS5+ and ARC
  * If allowed, touching me can set progress to that point

<img src="http://i.imgur.com/ZfSpUw3.png">

Status:

  * Used in production code
  * Works good for smaller audio files (<30 seconds)
  * Need to make a Podspec and clean up project to Pod's recommended style

Instructions:

  * Add `pod 'FDWaveformView', '~> 0.1.0'` to your <a href="https://github.com/AFNetworking/AFNetworking/wiki/Getting-Started-with-AFNetworking">Podfile</a>
  * Check out <a href="https://github.com/fulldecent/FDWaveformView/issues?page=1&state=closed">closed issues on this project</a> for problems you have or implementation code samples 
  * Add your project to "I USE THIS" at https://www.cocoacontrols.com/controls/fdwaveformview
