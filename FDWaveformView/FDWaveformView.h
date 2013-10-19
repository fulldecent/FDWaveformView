//
//  FDWaveformView
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface FDWaveformView : UIView
@property (nonatomic, strong) NSURL *audioURL;
@property (nonatomic, assign, readonly) unsigned long int totalSamples;
@property (nonatomic, assign) unsigned long int progressSamples;
@end
