//
//  ViewController.m
//  FDWaveformViewExample
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <FDWaveformViewDelegate>
@property (nonatomic, strong) NSDate *startRendering;
@end

@implementation ViewController
@synthesize startRendering = _startRendering;

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSString *filePath = [thisBundle pathForResource:@"Submarine" ofType:@"aiff"];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    
    // We wish to animate the waveformv iew in when it is rendered
    self.waveform.delegate = self;
    self.waveform.alpha = 0.0f;
    
    self.waveform.audioURL = url;
    self.waveform.progressSamples = 10000;
    self.waveform.doesAllowScrubbing = YES;
    self.waveform.doesAllowStretchAndScroll = YES;
}

- (void)doAnimation
{
    [UIView animateWithDuration:0.3 animations:^{
        NSInteger randomNumber = arc4random() % self.waveform.totalSamples;
        self.waveform.progressSamples = randomNumber;
    }];
}

- (void)doZoomIn
{
    self.waveform.zoomStartSamples = 0;
    self.waveform.zoomEndSamples = self.waveform.totalSamples / 4;
}

- (void)doZoomOut
{
    self.waveform.zoomStartSamples = 0;
    self.waveform.zoomEndSamples = self.waveform.totalSamples;
}

#pragma mark -
#pragma mark FDWaveformViewDelegate

- (void)waveformViewWillRender:(FDWaveformView *)waveformView
{
    self.startRendering = [NSDate date];
}

- (void)waveformViewDidRender:(FDWaveformView *)waveformView
{
    NSLog(@"FDWaveformView rendering done, took %f seconds", -[self.startRendering timeIntervalSinceNow]);
    [UIView animateWithDuration:0.25f animations:^{
        waveformView.alpha = 1.0f;
    }];
}

@end
