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

/// A view for rendering audio waveforms
@interface FDWaveformView : UIView

/// A delegate to accept progress reporting
@property (nonatomic, weak) id<FDWaveformViewDelegate> delegate;

/// The audio file to render
@property (nonatomic, strong) NSURL *audioURL;

/// The total number of audio samples in the file
@property (nonatomic, assign, readonly) long int totalSamples;

/// A portion of the waveform rendering to be highlighted
@property (nonatomic, assign) long int progressSamples;

/// The first sample to render
@property (nonatomic, assign) long int zoomStartSamples;

/// The last sample to render
@property (nonatomic, assign) long int zoomEndSamples;

/// Whether to all the scrub gesture
@property (nonatomic) BOOL doesAllowScrubbing;

/// Whether to allow the stretch gesture
@property (nonatomic) BOOL doesAllowStretch;

/// Whether to allow the scroll gesture
@property (nonatomic) BOOL doesAllowScroll;

/// The color of the waveform
@property (nonatomic, copy) UIColor *wavesColor;

/// The corol of the highlighted waveform (see `progressSamples`
@property (nonatomic, copy) UIColor *progressColor;
@end

/// To receive progress updates from FDWaveformView
@protocol FDWaveformViewDelegate <NSObject>
@optional

/// Rendering will begin
- (void)waveformViewWillRender:(FDWaveformView *)waveformView;

/// Rendering did complete
- (void)waveformViewDidRender:(FDWaveformView *)waveformView;

/// An audio file will be loaded
- (void)waveformViewWillLoad:(FDWaveformView *)waveformView;

/// An audio file was loaded
- (void)waveformViewDidLoad:(FDWaveformView *)waveformView;

/// The panning gesture did begin
- (void)waveformDidBeginPanning:(FDWaveformView *)waveformView;

/// The panning gesture did end
- (void)waveformDidEndPanning:(FDWaveformView *)waveformView;
@end