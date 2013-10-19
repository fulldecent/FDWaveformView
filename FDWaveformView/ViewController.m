//
//  ViewController.m
//  FDWaveformViewExample
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSString *filePath = [thisBundle pathForResource:@"Submarine" ofType:@"aiff"];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    
    self.waveform.audioURL = url;
    self.waveform.progressSamples = 10000;
}

- (void)doAnimation
{
    [UIView animateWithDuration:0.3 animations:^{
        NSInteger randomNumber = arc4random() % self.waveform.totalSamples;
        self.waveform.progressSamples = randomNumber;
    }];
}

@end
