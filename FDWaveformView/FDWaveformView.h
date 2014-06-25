//
//  FDWaveformView
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@protocol FDWaveformViewDelegate;

@interface FDWaveformView : UIView
@property (nonatomic, weak) id<FDWaveformViewDelegate> delegate;
@property (nonatomic, strong) NSURL *audioURL;
@property (nonatomic, assign, readonly) unsigned long int totalSamples;
@property (nonatomic, assign) unsigned long int progressSamples;
@property (nonatomic, assign) unsigned long int zoomStartSamples;
@property (nonatomic, assign) unsigned long int zoomEndSamples;
@property (nonatomic) BOOL doesAllowScrubbing;
@property (nonatomic) BOOL doesAllowStretchAndScroll;
@property (nonatomic, copy) UIColor *wavesColor;
@property (nonatomic, copy) UIColor *progressColor;


- (float)progress;

@end



@protocol FDWaveformViewDelegate <NSObject>
@optional
- (void)waveformViewWillRender:(FDWaveformView *)waveformView;
- (void)waveformViewDidRender:(FDWaveformView *)waveformView;
- (void)waveformView:(FDWaveformView *)waveformView didScrubToProgress:(float)progress;
- (void)waveformDidBeginScrubbing:(FDWaveformView *)waveformView;
- (void)waveformDidEndScrubbing:(FDWaveformView *)waveformView;

@end