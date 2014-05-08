//
//  FDWaveformView
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//


// FROM http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader
// AND http://stackoverflow.com/questions/8298610/waveform-on-ios
// DO SEE http://stackoverflow.com/questions/1191868/uiimageview-scaling-interpolation
// see http://stackoverflow.com/questions/3514066/how-to-tint-a-transparent-png-image-in-iphone

#import "FDWaveFormView.h"
#import <UIKit/UIKit.h>

#define absX(x) (x<0?0-x:x)
#define minMaxX(x,mn,mx) (x<=mn?mn:(x>=mx?mx:x))
#define noiseFloor (-50.0)
#define decibel(amplitude) (20.0 * log10(absX(amplitude)/32767.0))
#define imgExt @"png"
#define imageToData(x) UIImagePNGRepresentation(x)

// Drawing a larger image than needed to have it available for scrolling
#define horizontalMinimumBleed 0.1
#define horizontalMaximumBleed 3
#define horizontalTargetBleed 0.5
// Drawing more pixels than shown to get antialiasing
#define horizontalMinimumOverdraw 2
#define horizontalMaximumOverdraw 5
#define horizontalTargetOverdraw 3
#define verticalMinimumOverdraw 1
#define verticalMaximumOverdraw 3
#define verticalTargetOverdraw 2


@interface FDWaveformView() <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UIImageView *highlightedImage;
@property (nonatomic, strong) UIView *clipping;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, assign) unsigned long int totalSamples;
@property (nonatomic, assign) unsigned long int cachedStartSamples;
@property (nonatomic, assign) unsigned long int cachedEndSamples;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property BOOL renderingInProgress;
@end

@implementation FDWaveformView
@synthesize audioURL = _audioURL;
@synthesize image = _image;
@synthesize highlightedImage = _highlightedImage;
@synthesize clipping = _clipping;
@synthesize pinchRecognizer = _pinchRecognizer;
@synthesize panRecognizer = _panRecognizer;
@synthesize tapRecognizer = _tapRecognizer;

- (void)initialize
{
    self.image = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    self.highlightedImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    self.image.contentMode = UIViewContentModeScaleToFill;
    self.highlightedImage.contentMode = UIViewContentModeScaleToFill;
    [self addSubview:self.image];
    self.clipping = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    [self.clipping addSubview:self.highlightedImage];
    self.clipping.clipsToBounds = YES;
    [self addSubview:self.clipping];
    self.clipsToBounds = YES;
    
    self.wavesColor = [UIColor blackColor];
    self.progressColor = [UIColor blueColor];
    
    self.pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    self.pinchRecognizer.delegate = self;
    [self addGestureRecognizer:self.pinchRecognizer];

    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.panRecognizer.delegate = self;
    [self addGestureRecognizer:self.panRecognizer];
    
    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self addGestureRecognizer:self.tapRecognizer];
}

- (id)initWithCoder:(NSCoder *)aCoder
{
    if (self = [super initWithCoder:aCoder])
        [self initialize];
    return self;
}

- (id)initWithFrame:(CGRect)rect
{
    if (self = [super initWithFrame:rect])
        [self initialize];
    return self;
}

- (void)dealloc
{
    self.delegate = nil;
    self.audioURL = nil;
    self.image = nil;
    self.highlightedImage = nil;
    self.clipping = nil;
    self.asset = nil;
    self.wavesColor = nil;
    self.progressColor = nil;
}

- (void)setAudioURL:(NSURL *)audioURL
{
    _audioURL = audioURL;
    self.asset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
    self.image.image = nil;
    self.highlightedImage.image = nil;
    self.totalSamples = (unsigned long int) self.asset.duration.value;
    _progressSamples = 0; // skip custom setter
    _zoomStartSamples = 0; // skip custom setter
    _zoomEndSamples = (unsigned long int) self.asset.duration.value; // skip custom setter
    [self setNeedsDisplay];
}

- (void)setProgressSamples:(unsigned long)progressSamples
{
    _progressSamples = progressSamples;
    if (self.totalSamples) {
        float progress = (float)self.progressSamples / self.totalSamples;
        self.clipping.frame = CGRectMake(0,0,self.frame.size.width*progress,self.frame.size.height);
        [self setNeedsLayout];
    }
}

- (void)setZoomStartSamples:(unsigned long)startSamples
{
    _zoomStartSamples = startSamples;
    [self setNeedsDisplay];
    [self setNeedsLayout];
}

- (void)setZoomEndSamples:(unsigned long)endSamples
{
    _zoomEndSamples = endSamples;
    [self setNeedsDisplay];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // We need to place the images which have samples from cachedStart..cachedEnd
    // inside our frame which represents startSamples..endSamples
    // all figures are a portion of our frame size
    float scaledStart = 0, scaledProgress = 0, scaledEnd = 1, scaledWidth = 1;
    if (self.cachedEndSamples > self.cachedStartSamples) {
        scaledStart = ((float)self.cachedStartSamples-self.zoomStartSamples)/(self.zoomEndSamples-self.zoomStartSamples);
        scaledEnd = ((float)self.cachedEndSamples-self.zoomStartSamples)/(self.zoomEndSamples-self.zoomStartSamples);
        scaledWidth = scaledEnd - scaledStart;
        scaledProgress = ((float)self.progressSamples-self.zoomStartSamples)/(self.zoomEndSamples-self.zoomStartSamples);
    }
    CGRect frame = CGRectMake(self.frame.size.width*scaledStart, 0, self.frame.size.width*scaledWidth, self.frame.size.height);
    self.image.frame = self.highlightedImage.frame = frame;
    self.clipping.frame = CGRectMake(0,0,self.frame.size.width*scaledProgress,self.frame.size.height);
    self.clipping.hidden = self.progressSamples <= self.zoomStartSamples;

    if (!self.asset || self.renderingInProgress)
        return;
    unsigned long int displayRange = self.zoomEndSamples - self.zoomStartSamples;
    BOOL needToRender = NO;
    if (!self.image.image)
        needToRender = YES;
//    NSLog(@"%d %ul",self.cachedStartSamples,minMaxX((long)self.startSamples - displayRange * horizontalMaximumBleed, 0, self.totalSamples));
    if (self.cachedStartSamples < (unsigned long)minMaxX((float)self.zoomStartSamples - displayRange * horizontalMaximumBleed, 0, self.totalSamples))
        needToRender = YES;
    if (self.cachedStartSamples > (unsigned long)minMaxX((float)self.zoomStartSamples - displayRange * horizontalMinimumBleed, 0, self.totalSamples))
        needToRender = YES;
    if (self.cachedEndSamples < (unsigned long)minMaxX((float)self.zoomEndSamples + displayRange * horizontalMinimumBleed, 0, self.totalSamples))
        needToRender = YES;
    if (self.cachedEndSamples > (unsigned long)minMaxX((float)self.zoomEndSamples + displayRange * horizontalMaximumBleed, 0, self.totalSamples))
        needToRender = YES;
    if (self.image.image.size.width < self.frame.size.width * [UIScreen mainScreen].scale * horizontalMinimumOverdraw)
        needToRender = YES;
    if (self.image.image.size.width > self.frame.size.width * [UIScreen mainScreen].scale * horizontalMaximumOverdraw)
        needToRender = YES;
    if (self.image.image.size.height < self.frame.size.height * [UIScreen mainScreen].scale * verticalMinimumOverdraw)
        needToRender = YES;
    if (self.image.image.size.height > self.frame.size.height * [UIScreen mainScreen].scale * verticalMaximumOverdraw)
        needToRender = YES;
    if (!needToRender)
        return;
    
    self.renderingInProgress = YES;
    if ([self.delegate respondsToSelector:@selector(waveformViewWillRender:)])
        [self.delegate waveformViewWillRender:self];
    unsigned long int renderStartSamples = minMaxX((long)self.zoomStartSamples - displayRange * horizontalTargetBleed, 0, self.totalSamples);
    unsigned long int renderEndSamples = minMaxX((long)self.zoomEndSamples + displayRange * horizontalTargetBleed, 0, self.totalSamples);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self renderPNGAudioPictogramLogForAsset:self.asset
                                    startSamples:renderStartSamples
                                      endSamples:renderEndSamples
                                            done:^(UIImage *image, UIImage *selectedImage) {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    self.image.image = image;
                                                    self.highlightedImage.image = selectedImage;
                                                    self.cachedStartSamples = renderStartSamples;
                                                    self.cachedEndSamples = renderEndSamples;
                                                    [self layoutSubviews]; // warning
                                                    if ([self.delegate respondsToSelector:@selector(waveformViewDidRender:)])
                                                        [self.delegate waveformViewDidRender:self];
                                                    self.renderingInProgress = NO;
                                                });
                                            }];
    });
}

- (void)plotLogGraph:(Float32 *) samples
        maximumValue:(Float32) normalizeMax
        mimimumValue:(Float32) normalizeMin
         sampleCount:(NSInteger) sampleCount
         imageHeight:(float) imageHeight
                done:(void(^)(UIImage *image, UIImage *selectedImage))done
{
    // TODO: switch to a synchronous function that paints onto a given context? (for issue #2)
    CGSize imageSize = CGSizeMake(sampleCount, imageHeight);
    UIGraphicsBeginImageContext(imageSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetAlpha(context,1.0);
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [self.wavesColor CGColor]);
    
    float halfGraphHeight = (imageHeight / 2);
    float centerLeft = halfGraphHeight;
    float sampleAdjustmentFactor = imageHeight / (normalizeMax - noiseFloor) / 2;
    
    for (NSInteger intSample=0; intSample<sampleCount; intSample++) {
        Float32 sample = *samples++;
        float pixels = (sample - noiseFloor) * sampleAdjustmentFactor;
        CGContextMoveToPoint(context, intSample, centerLeft-pixels);
        CGContextAddLineToPoint(context, intSample, centerLeft+pixels);
        CGContextStrokePath(context);
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    CGRect drawRect = CGRectMake(0, 0, image.size.width, image.size.height);
    [self.progressColor set];
    UIRectFillUsingBlendMode(drawRect, kCGBlendModeSourceAtop);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    done(image, tintedImage);
}

- (void)renderPNGAudioPictogramLogForAsset:(AVURLAsset *)songAsset
                              startSamples:(unsigned long int)start
                                endSamples:(unsigned long int)end
                                      done:(void(^)(UIImage *image, UIImage *selectedImage))done

{
    // TODO: break out subsampling code
    CGFloat widthInPixels = self.frame.size.width * [UIScreen mainScreen].scale * horizontalTargetOverdraw;
    CGFloat heightInPixels = self.frame.size.height * [UIScreen mainScreen].scale * verticalTargetOverdraw;

    NSError *error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    AVAssetTrack *songTrack = [songAsset.tracks objectAtIndex:0];
    NSDictionary *outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                        //     [NSNumber numberWithInt:44100.0],AVSampleRateKey, /*Not Supported*/
                                        //     [NSNumber numberWithInt: 2],AVNumberOfChannelsKey,    /*Not Supported*/
                                        [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,
                                        nil];
    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
    [reader addOutput:output];
    UInt32 channelCount;
    NSArray *formatDesc = songTrack.formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        if (!fmtDesc) return; //!
        channelCount = fmtDesc->mChannelsPerFrame;
    }
    
    UInt32 bytesPerInputSample = 2 * channelCount;
    Float32 maximum = noiseFloor;
    Float64 tally = 0;
    Float32 tallyCount = 0;
    Float32 outSamples = 0;
    
    NSInteger downsampleFactor = (end-start) / widthInPixels;
    downsampleFactor = downsampleFactor<1 ? 1 : downsampleFactor;
    NSMutableData *fullSongData = [[NSMutableData alloc] initWithCapacity:self.totalSamples/downsampleFactor*2]; // 16-bit samples
    reader.timeRange = CMTimeRangeMake(CMTimeMake(start, self.asset.duration.timescale), CMTimeMake((end-start), self.asset.duration.timescale));
    [reader startReading];
    
    while (reader.status == AVAssetReaderStatusReading) {
        AVAssetReaderTrackOutput * trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
        if (sampleBufferRef) {
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            size_t bufferLength = CMBlockBufferGetDataLength(blockBufferRef);
            void *data = malloc(bufferLength);
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, bufferLength, data);
            
            SInt16 *samples = (SInt16 *) data;
            int sampleCount = (int) bufferLength / bytesPerInputSample;
            for (int i=0; i<sampleCount; i++) {
                Float32 sample = (Float32) *samples++;
                sample = decibel(sample);
                sample = minMaxX(sample,noiseFloor,0);
                tally += sample; // Should be RMS?
                for (int j=1; j<channelCount; j++)
                    samples++;
                tallyCount++;
                
                if (tallyCount == downsampleFactor) {
                    sample = tally / tallyCount;
                    maximum = maximum > sample ? maximum : sample;
                    [fullSongData appendBytes:&sample length:sizeof(sample)];
                    tally = 0;
                    tallyCount = 0;
                    outSamples++;
                }
            }
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            free(data);
        }
    }
    
    // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
        // Something went wrong. Handle it.
    if (reader.status == AVAssetReaderStatusCompleted){
        [self plotLogGraph:(Float32 *)fullSongData.bytes
              maximumValue:maximum
              mimimumValue:noiseFloor
               sampleCount:outSamples
               imageHeight:heightInPixels
                      done:done];
    }
}

#pragma mark - Interaction

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer
{
    if (!self.doesAllowStretchAndScroll)
        return;
    if (recognizer.scale == 1) return;
    
    unsigned long middleSamples = (self.zoomStartSamples + self.zoomEndSamples) / 2;
    unsigned long rangeSamples = self.zoomEndSamples - self.zoomStartSamples;
    if (middleSamples - 1/recognizer.scale*rangeSamples/2 >= 0)
        _zoomStartSamples = middleSamples - 1/recognizer.scale*rangeSamples/2;
    else
        _zoomStartSamples = 0;
    if (middleSamples + 1/recognizer.scale*rangeSamples/2 <= self.totalSamples)
        _zoomEndSamples = middleSamples + 1/recognizer.scale*rangeSamples/2;
    else
        _zoomEndSamples = self.totalSamples;
    [self setNeedsDisplay];
    [self setNeedsLayout];
    recognizer.scale = 1;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer
{
    CGPoint point = [recognizer translationInView:self];
    NSLog(@"translation: %f", point.x);

    if (self.doesAllowStretchAndScroll) {
        long translationSamples = (float)(self.zoomEndSamples-self.zoomStartSamples) * point.x / self.bounds.size.width;
        [recognizer setTranslation:CGPointZero inView:self];
        if ((float)self.zoomStartSamples - translationSamples < 0)
            translationSamples = (float)self.zoomStartSamples;
        if ((float)self.zoomEndSamples - translationSamples > self.totalSamples)
            translationSamples = self.zoomEndSamples - self.totalSamples;
        _zoomStartSamples -= translationSamples;
        _zoomEndSamples -= translationSamples;
        [self setNeedsDisplay];
        [self setNeedsLayout];
    } else if (self.doesAllowScrubbing) {
        self.progressSamples = self.zoomStartSamples + (float)(self.zoomEndSamples-self.zoomStartSamples) * [recognizer locationInView:self].x / self.bounds.size.width;
    }
    
    return;
}

- (void)handleTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (self.doesAllowScrubbing) {
        self.progressSamples = self.zoomStartSamples + (float)(self.zoomEndSamples-self.zoomStartSamples) * [recognizer locationInView:self].x / self.bounds.size.width;
    }
}

@end
