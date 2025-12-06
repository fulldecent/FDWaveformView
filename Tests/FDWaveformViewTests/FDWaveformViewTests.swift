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

  func testFDWaveformTypeEquality() throws {
    // Test FDWaveformType enum equality
    let linear1 = FDWaveformType.linear
    let linear2 = FDWaveformType.linear
    let logarithmic1 = FDWaveformType.logarithmic(noiseFloor: -50.0)
    let logarithmic2 = FDWaveformType.logarithmic(noiseFloor: -50.0)
    let logarithmic3 = FDWaveformType.logarithmic(noiseFloor: -60.0)

    XCTAssertEqual(linear1, linear2)
    XCTAssertEqual(logarithmic1, logarithmic2)
    XCTAssertNotEqual(linear1, logarithmic1)
    XCTAssertNotEqual(logarithmic1, logarithmic3)
  }

  func testFDWaveformTypeFloorValue() throws {
    // Test floor value property
    let linear = FDWaveformType.linear
    let logarithmic = FDWaveformType.logarithmic(noiseFloor: -45.0)

    XCTAssertEqual(linear.floorValue, 0)
    XCTAssertEqual(logarithmic.floorValue, -45.0)
  }
}
