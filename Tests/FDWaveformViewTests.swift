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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        XCTAssert(true)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testFD() {
        XCTAssert(waveformView != nil)
    }

    func testZoomSaples() {
        XCTAssert(waveformView.zoomStartSamples == 0)
        XCTAssert(waveformView.zoomEndSamples == 0)
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
