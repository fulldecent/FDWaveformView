//
//  ViewController.h
//  FDWaveformViewExample
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FDWaveformView.h"

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet FDWaveformView *waveform;
@property (strong, nonatomic) IBOutlet UIView *playButton;
- (IBAction)doAnimation;
@end
