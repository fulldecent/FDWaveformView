#
# Be sure to run `pod lib lint FDWaveformView.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "FDWaveformView"
  s.version          = "0.3.0"
  s.summary          = "Reads an audio file and displays the waveform"
  s.description      = <<-DESC
                       FDWaveformView is an easy way to display an audio waveform in your app.
                       It is a nice visualization to show a playing audio file or to select a
                       DESC
  s.homepage         = "https://github.com/fulldecent/FDWaveformView"
  s.screenshots     = "https://camo.githubusercontent.com/8c51361597e3c150cce6f60db5055663a7a7f8f1/68747470733a2f2f692e696d6775722e636f6d2f354e376f7a6f672e706e67", "https://camo.githubusercontent.com/3c21c8437f922ba6cb1a44b0701c02c140221d84/68747470733a2f2f692e696d6775722e636f6d2f665272486952502e706e67", "https://camo.githubusercontent.com/771973985f42a25931bfafba291f313ba8e46e32/68747470733a2f2f692e696d6775722e636f6d2f4a514f4b51336f2e706e67", "https://camo.githubusercontent.com/21e361bff1e2351a8f54636881c4290e4818501a/68747470733a2f2f692e696d6775722e636f6d2f386f52376370712e676966", "https://camo.githubusercontent.com/700a0eeb4bfbf5bab688dcb11ef60784b2074eef/68747470733a2f2f692e696d6775722e636f6d2f456778586143592e676966"
  s.license          = 'MIT'
  s.author           = { "William Entriken" => "github.com@phor.net" }
  s.source           = { :git => "https://github.com/fulldecent/FDWaveformView.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/fulldecent'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'FDWaveformView' => ['Pod/Assets/*.png']
  }

  s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'AVFoundation', 'MediaPlayer', 'CoreGraphics'
  # s.dependency 'AFNetworking', '~> 2.3'
end
