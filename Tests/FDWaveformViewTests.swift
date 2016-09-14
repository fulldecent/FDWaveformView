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

    var fd: FDWaveformView?

    override func setUp() {
        super.setUp()
        fd = FDWaveformView()
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
        XCTAssert(fd != nil)
    }

    func testZoomSaples() {
        XCTAssert(fd?.zoomStartSamples == 0)
        XCTAssert(fd?.zoomEndSamples == 0)
    }

    func testGesturesPermissions() {
        XCTAssert(fd?.doesAllowScroll == true)
        XCTAssert(fd?.doesAllowStretch == true)
        XCTAssert(fd?.doesAllowScrubbing == true)
    }

    func testColors() {
        XCTAssert(fd?.wavesColor == UIColor.blackColor())
        XCTAssert(fd?.progressColor == UIColor.blueColor())
    }

}
