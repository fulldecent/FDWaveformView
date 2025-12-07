//
// Copyright (c) William Entriken and the FDWaveformView contributors
//
import XCTest

@testable import FDWaveformView

final class FDWaveformViewTests: XCTestCase {

  func testFDWaveformViewInitialization() throws {
    // Test that FDWaveformView can be initialized
    let waveformView = FDWaveformView()
    XCTAssertNotNil(waveformView)
    XCTAssertEqual(waveformView.totalSamples, 0)
    XCTAssertNil(waveformView.audioURL)
    XCTAssertNil(waveformView.highlightedSamples)
    XCTAssertEqual(waveformView.zoomSamples, 0..<0)
  }

  func testFDWaveformViewProperties() throws {
    // Test that properties can be set and retrieved
    let waveformView = FDWaveformView()

    // Test boolean properties
    waveformView.doesAllowScrubbing = false
    XCTAssertFalse(waveformView.doesAllowScrubbing)

    waveformView.doesAllowStretch = false
    XCTAssertFalse(waveformView.doesAllowStretch)

    waveformView.doesAllowScroll = false
    XCTAssertFalse(waveformView.doesAllowScroll)

    // Test color properties
    waveformView.wavesColor = .red
    XCTAssertEqual(waveformView.wavesColor, .red)

    waveformView.progressColor = .green
    XCTAssertEqual(waveformView.progressColor, .green)
  }

  func testWaveformTypeEquality() throws {
    // Test WaveformType enum equality
    let linear1 = FDWaveformView.WaveformType.linear
    let linear2 = FDWaveformView.WaveformType.linear
    let logarithmic1 = FDWaveformView.WaveformType.logarithmic
    let logarithmic2 = FDWaveformView.WaveformType.logarithmic

    XCTAssertEqual(linear1, linear2)
    XCTAssertEqual(logarithmic1, logarithmic2)
    XCTAssertNotEqual(linear1, logarithmic1)
  }
}
