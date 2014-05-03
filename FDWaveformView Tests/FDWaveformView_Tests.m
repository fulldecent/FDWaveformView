//
//  FDWaveformView_Tests.m
//  FDWaveformView Tests
//
//  Created by William Entriken on 5/3/14.
//  Copyright (c) 2014 William Entriken. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FDWaveformView.h"

@interface FDWaveformView_Tests : XCTestCase
@property (nonatomic) FDWaveformView *waveformView;
@end

@implementation FDWaveformView_Tests

- (void)setUp
{
    [super setUp];
    self.waveformView = [[FDWaveformView alloc] init];
}

- (void)tearDown
{
    [super tearDown];
    self.waveformView = nil;
}

- (void)testInheritsFromUIView
{
    XCTAssert([self.waveformView isKindOfClass:[UIView class]], @"Must inherit from UIView");
}

- (void)testDelegateSetGet
{
    id <FDWaveformViewDelegate> class = nil;
    self.waveformView.delegate = class;
    XCTAssertEqual(self.waveformView.delegate, class, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testAudioURLSetGet
{
    NSURL *url = [NSURL URLWithString:@"http://www.google.com/fakesound.mp3"];
    self.waveformView.audioURL = url;
    XCTAssertEqual(self.waveformView.audioURL, url, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testTotalSamplesGet
{
    XCTAssert(self.waveformView.totalSamples == 0, @"Must have correct default value %s", __PRETTY_FUNCTION__);
}

- (void)testProgressSamplesSetGet
{
    unsigned long int samples = 0;
    self.waveformView.progressSamples = samples;
    XCTAssertEqual(self.waveformView.progressSamples, samples, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testZoomSamplesStartSetGet
{
    unsigned long int samples = 0;
    self.waveformView.zoomStartSamples = samples;
    XCTAssertEqual(self.waveformView.zoomStartSamples, samples, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testZoomSamplesEndSetGet
{
    unsigned long int samples = 0;
    self.waveformView.zoomEndSamples = samples;
    XCTAssertEqual(self.waveformView.zoomEndSamples, samples, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testDoesAllowScrubbingSetGet
{
    BOOL b = true;
    self.waveformView.doesAllowScrubbing = b;
    XCTAssertEqual(self.waveformView.doesAllowScrubbing, b, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testDoesAllowStretchAndScrollSetGet
{
    BOOL b = true;
    self.waveformView.doesAllowStretchAndScroll = b;
    XCTAssertEqual(self.waveformView.doesAllowStretchAndScroll, b, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testWavesColorSetGet
{
    UIColor *color = [UIColor purpleColor];
    self.waveformView.wavesColor = color;
    XCTAssertEqual(self.waveformView.wavesColor, color, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

- (void)testProgressColorSetGet
{
    UIColor *color = [UIColor purpleColor];
    self.waveformView.progressColor = color;
    XCTAssertEqual(self.waveformView.progressColor, color, @"Must have same value as set for %s", __PRETTY_FUNCTION__);
}

@end