//
//  FDWaveformViewTests.swift
//  FDWaveformViewTests
//
//  Created by FDWaveformView_OWNER on TODAYS_DATE.
//  Copyright  2016 FDWaveformView_OWNER. All rights reserved.
//

import XCTest
@testable import FDWaveformView

class FDWaveformViewTests: XCTestCase {

    var waveformView: FDWaveformView!

    override func setUp() {
        super.setUp()
        waveformView = FDWaveformView()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Tests
    
    func testZoomSaples() {
        XCTAssert(waveformView.zoomSamples.startIndex == 0)
        XCTAssert(waveformView.zoomSamples.endIndex == 0)
    }

    func testGesturesPermissions() {
        XCTAssert(waveformView.doesAllowScroll == true)
        XCTAssert(waveformView.doesAllowStretch == true)
        XCTAssert(waveformView.doesAllowScrubbing == true)
    }

    func testColors() {
        XCTAssert(waveformView.wavesColor == UIColor.black)
        XCTAssert(waveformView.progressColor == UIColor.blue)
    }

}

extension FDWaveformViewTests {
    static var allTests = [
        ("testZoomSaples", testZoomSaples),
        ("testGesturesPermissions", testGesturesPermissions),
        ("testColors", testColors),
    ]
}
