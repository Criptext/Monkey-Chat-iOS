//
//  RGCircularSlider.m
//  Block
//
//  Created by ROBERA GELETA on 12/7/14.
//  Copyright (c) 2014 ROBERA GELETA. All rights reserved.
//
#define HANDLE 57
#define RADIUS 20
#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))

#import "RGCircularSlider.h"

@interface RGCircularSlider()

@property NSInteger angle;
@property AVAudioPlayer *audioPlayer;
@property NSArray *dirPaths;
@property NSString *docsDir;
@property NSURL *soundFileURL;
@property NSTimeInterval intervalAudio;
@property NSTimer *updateTimer;
@property float step;
@property float padding;

@property UIColor *colorTime;
@property UIColor *colorBack;
@property UIColor *colorStrokeBack;
@property UIColor *colorRangeAudio;
@property UIColor *colorButton;
@property UIColor *colorIconButton;
@property UIColor *colorStrokeButton;

@end

@implementation RGCircularSlider

@synthesize nameAudio = _nameAudio;

-(instancetype)initWithFrame:(CGRect)frame isIncoming:(BOOL)isIncomming{
    self = [super initWithFrame:frame];
    if (self) {
        
        // set view
        self.viewForBaselineLayout.backgroundColor = [UIColor clearColor];
        
        //inital angle
        self.angle = -150;
        self.padding = 8;
        self.pressed = YES;
        
        //set audio
        self.dirPaths = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES);
        self.docsDir = self.dirPaths[0];
        
        UIColor* colorBlue = [UIColor colorWithHue:210.0f / 360.0f
                                        saturation:0.94f
                                        brightness:1.0f
                                             alpha:1.0f];
        UIColor* colorLightGray = [UIColor colorWithRed:242/255.0f green:242/255.0f blue:242/255.0f alpha:1.0f];
        UIColor* colorGray = [UIColor colorWithHue:240.0f / 360.0f
                                        saturation:0.02f
                                        brightness:0.92f
                                             alpha:1.0f];
        UIColor* colorDarkGray = [UIColor colorWithRed:206/255.0f green:206/255.0f blue:208/255.0f alpha:1.0f];
        
        if (isIncomming) {
            self.colorBack = colorGray;
            self.colorStrokeBack = [UIColor clearColor];
            self.colorRangeAudio = colorBlue;
            self.colorButton = colorLightGray;
            self.colorIconButton = colorBlue;
            self.colorStrokeButton = colorDarkGray;
            self.colorTime = [UIColor grayColor];
        }else{
            self.colorBack = colorGray;
            self.colorStrokeBack = [UIColor clearColor];
            self.colorRangeAudio = colorDarkGray;
            self.colorButton = colorLightGray;
            self.colorIconButton = colorBlue;
            self.colorStrokeButton = colorDarkGray;
            self.colorTime = [UIColor grayColor];
        }
        
        //time label
        self.timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width/4, self.frame.size.height-15, self.frame.size.width/2, 15)];
        
        [self.timeLabel setFont:[UIFont systemFontOfSize:13]];
        self.timeLabel.textAlignment = NSTextAlignmentCenter;
        self.timeLabel.textColor = self.colorTime;
        [self.viewForBaselineLayout addSubview:self.timeLabel];
        
        //adding panning gesture recognizer to figure out the translation
        UIPanGestureRecognizer *panning = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panning:)];
        [self addGestureRecognizer:panning];
        
        //adding tap gesture recognizer to figure
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap:)];
        [self addGestureRecognizer:tap];
    }
    
    return self;
}

-(NSString*)timeFormat:(float)value{
    
    float minutes = floor(lroundf(value)/60);
    float seconds = lroundf(value) - (minutes * 60);
    
    long roundedSeconds = lroundf(seconds);
    long roundedMinutes = lroundf(minutes);
    
    NSString *time = [[NSString alloc]
                      initWithFormat:@"%02ld:%02ld",
                      roundedMinutes, roundedSeconds];
    return time;
}

-(void)drawRect:(CGRect)rect{
    
    [self drawCanvas2WithFrame:rect sizeOfOuterCircle:self.frame.size.width-self.padding angle:self.angle pauseButton:!self.pressed playButton:self.pressed leftPauseBar:21];
}

- (void)drawCanvas2WithFrame: (CGRect)frame sizeOfOuterCircle: (CGFloat)sizeOfOuterCircle angle: (CGFloat)angle pauseButton: (BOOL)pauseButton playButton: (BOOL)playButton leftPauseBar: (CGFloat)leftPauseBar{
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Shadow Declarations
    UIColor *controlButtonShadowColor = [UIColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.5];
    CGSize controlButtonShadowOffset = CGSizeMake(4, 0);
    CGFloat controlButtonShadowBlurRadius = 4;
    
    UIColor *buttonShadowColor = [UIColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.3];
    CGSize buttonShadowOffset = CGSizeMake(0, 6);
    CGFloat buttonShadowBlurRadius = 5;
    
    //// Variable Declarations
    CGFloat sizeOfInnerCircle = sizeOfOuterCircle / 2.0;
    CGPoint rotationOrigin = CGPointMake(sizeOfInnerCircle + self.padding/2, sizeOfInnerCircle+ self.padding/2);
    CGPoint handlerOffset = CGPointMake(0, sizeOfInnerCircle / 2);
    
    CGPoint innerCircleCenter = CGPointMake(sizeOfOuterCircle / 4.0, sizeOfOuterCircle / 4.0);
    CGFloat playPauseButtonScale = sizeOfOuterCircle / 100.0;
    CGPoint expression = CGPointMake(sizeOfOuterCircle / 2.40, sizeOfOuterCircle / 2.90);
    CGFloat sizeOfHandler = (sizeOfOuterCircle - sizeOfInnerCircle) / 2.0;
    CGFloat rightPauseBar = leftPauseBar - 10;
    
    //// Arc background drawing: total range
    //Create the path
    CGContextAddArc(context, sizeOfInnerCircle + self.padding/2, sizeOfInnerCircle+ self.padding/2, sizeOfInnerCircle/2, (30 * M_PI / 180), (150 * M_PI / 180), 1);
    //Set the stroke color to black
    [self.colorRangeAudio setStroke];
    //Define line width and cap
    CGContextSetLineWidth(context, sizeOfHandler*1.8);
    CGContextSetLineCap(context, kCGLineCapButt);
    //draw it!
    CGContextDrawPath(context, kCGPathStroke);
    
    //// Arc active area drawing: range music
    CGRect ovalRect = CGRectMake(self.padding/2, self.padding/2, sizeOfOuterCircle, sizeOfOuterCircle);
    UIBezierPath* ovalPath = UIBezierPath.bezierPath;
    [ovalPath addArcWithCenter: CGPointMake(CGRectGetMidX(ovalRect), CGRectGetMidY(ovalRect)) radius: CGRectGetWidth(ovalRect) / 2 startAngle: -angle * M_PI/180 endAngle: (30 * M_PI / 180) clockwise: YES];
    [ovalPath addLineToPoint: CGPointMake(CGRectGetMidX(ovalRect), CGRectGetMidY(ovalRect))];
    [ovalPath closePath];
    [self.colorBack setFill];
    [ovalPath fill];
    
    //// Rect drawing: control button
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, rotationOrigin.x, rotationOrigin.y);
    CGContextRotateCTM(context, -(angle + 45) * M_PI / 180);
    
    UIBezierPath* rectPath = [UIBezierPath bezierPathWithRect: CGRectMake(handlerOffset.x-2,handlerOffset.y-2, 8, sizeOfHandler+2)];
    [rectPath applyTransform:CGAffineTransformMakeRotation(-1 * (180 / M_PI))];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, controlButtonShadowOffset, controlButtonShadowBlurRadius, [controlButtonShadowColor CGColor]);
    [[UIColor colorWithRed:242/255.0f green:242/255.0f blue:242/255.0f alpha:1.0f] setFill];
    [rectPath fill];
    CGContextRestoreGState(context);
    CGContextRestoreGState(context);
    
    //// Oval drawing: stop and pause button
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(frame), CGRectGetMinY(frame));
    
    UIBezierPath* oval2Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(innerCircleCenter.x + self.padding/2, innerCircleCenter.y + self.padding/2, sizeOfInnerCircle, sizeOfInnerCircle)];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, buttonShadowOffset, buttonShadowBlurRadius, [buttonShadowColor CGColor]);
    [self.colorButton setFill];
    [oval2Path fill];
    
    [self.colorStrokeButton setStroke];
    oval2Path.lineWidth = 0.5;
    [oval2Path stroke];
    
    CGContextRestoreGState(context);
    CGContextRestoreGState(context);
    
    //// Group
    {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, (expression.x + 0.0833333333333), expression.y);
        
        if (playButton){
            //// Bezier Drawing
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, 5.3, 9.5);
            CGContextScaleCTM(context, playPauseButtonScale, playPauseButtonScale);
            
            UIBezierPath* bezierPath = UIBezierPath.bezierPath;
            [bezierPath moveToPoint: CGPointMake(0, 0)];
            [bezierPath addLineToPoint: CGPointMake(0, 20)];
            [bezierPath addLineToPoint: CGPointMake(18, 10)];
            [bezierPath addLineToPoint: CGPointMake(0, 0)];
            [self.colorIconButton setFill];
            [bezierPath fill];
            
            CGContextRestoreGState(context);
        }
        
        if (pauseButton){
            //// Group 2
            {
                //// Rectangle Drawing
                CGContextSaveGState(context);
                CGContextTranslateCTM(context, (leftPauseBar - 16.5), 9);
                CGContextScaleCTM(context, playPauseButtonScale, playPauseButtonScale);
                
                UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(0, 0, 5, 20)];
                [self.colorIconButton setFill];
                [rectanglePath fill];
                
                CGContextRestoreGState(context);
                
                //// Rectangle 2 Drawing
                CGContextSaveGState(context);
                CGContextTranslateCTM(context, (rightPauseBar - 6.5), 9);
                CGContextScaleCTM(context, playPauseButtonScale, playPauseButtonScale);
                
                UIBezierPath* rectangle2Path = [UIBezierPath bezierPathWithRect: CGRectMake(10.38, 0, 5, 20)];
                [self.colorIconButton setFill];
                [rectangle2Path fill];
                
                CGContextRestoreGState(context);
            }
        }
        CGContextRestoreGState(context);
    }
}

- (void)panning:(UIPanGestureRecognizer *)panning{
    
    NSInteger angle_x = 0;
    if(self.angle > 0){
        angle_x = self.angle;
    }else if (self.angle < 0 ){
        angle_x = 360 + self.angle;
    }
    
    CGPoint currentTouch = [panning locationInView:self];
    self.angle =  - RADIANS_TO_DEGREES(pToA(currentTouch, self));
    
    if ( (self.angle <=- 30 && angle_x > 210) || (self.angle >= -150 && self.angle <=-30) ) {
        self.angle = -150;
    }
    
    if (self.audioPlayer.playing) {
        [self.audioPlayer pause];
        [self.updateTimer invalidate];
        self.pressed = true;
    }
    
    [self setNeedsDisplay];
}

- (CGFloat)percentageFromCircularAngle:(NSInteger )angle{
    CGFloat result = 0.0;
    if(angle > 0){
        result = angle ;
    }else if (angle < 0 ){
        NSInteger convertedAngle = 360 + angle;
        result = convertedAngle;
    }
    
    return result;
}

- (void)tap:(UITapGestureRecognizer *)touch{
    
    //compute the box for the inner circle
    
    NSInteger bigBoxSize = self.bounds.size.width;
    CGFloat quarterSize = self.bounds.size.width /4;
    
    CGPoint touchLocation = [touch locationInView:self];
    NSInteger x = touchLocation.x;
    NSInteger y = touchLocation.y;
    BOOL withInXRange = (x > quarterSize && x < (bigBoxSize - quarterSize));
    BOOL withInYRange = (y > quarterSize && y < (bigBoxSize - quarterSize));
    if( withInXRange && withInYRange){
        self.pressed = !self.pressed;
        [self setNeedsDisplay];
    }
    
    NSInteger porc = 0;
    if (self.angle<=-150 && self.angle>=-180 ){
        porc = (labs(self.angle)) - 150;
        
    }else if(self.angle >=0){
        porc = 180 - self.angle + 30;
    }else{
        porc = 210 + self.angle*-1;
    }
    
    NSError *error;
    if (self.pressed == NO) {
        if ([_delegate respondsToSelector:@selector(audioDidBeginPlaying:)]) {
            [_delegate audioDidBeginPlaying:self];
        }
        
        if (self.audioPlayer == nil) {
            
            self.soundFileURL = [[NSURL alloc] initFileURLWithPath: self.soundFilePath];
            
            self.audioPlayer = [[AVAudioPlayer alloc]
                                initWithContentsOfURL:self.soundFileURL
                                error:&error];
            
            self.audioPlayer.delegate = self;
            self.intervalAudio = self.audioPlayer.duration;
            self.step = self.intervalAudio/240;
            NSLog(@"step: %f",self.step);
            if (error){
                NSLog(@"Error: %@",[error localizedDescription]);
                if ([_delegate respondsToSelector:@selector(audioIsEmpty)]) {
                    [_delegate audioIsEmpty];
                }
            }else{
                self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:self.step target:self selector:@selector(updateSlider) userInfo:nil repeats:YES];
                [self.audioPlayer prepareToPlay];
                [self.audioPlayer setCurrentTime:porc*self.intervalAudio/240];
                [self.audioPlayer play];
            }
        }else{
            self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:self.step target:self selector:@selector(updateSlider) userInfo:nil repeats:YES];
            [self.audioPlayer prepareToPlay];
            [self.audioPlayer setCurrentTime:porc*self.intervalAudio/240];
            [self.audioPlayer play];
        }
    }else{
        if (self.audioPlayer.playing) {
            [self.audioPlayer pause];
            [self.updateTimer invalidate];
            if ([_delegate respondsToSelector:@selector(audioDidBeginPause:)]) {
                [_delegate audioDidBeginPause:self];
            }
        }
    }
    if (self.updateTimer != nil) {
        [[NSRunLoop mainRunLoop] addTimer:self.updateTimer forMode:NSRunLoopCommonModes];
    }
}
- (void)didOpenEfimero{
    self.pressed = !self.pressed;
    [self setNeedsDisplay];
    NSError *error;
    if (self.pressed == NO) {
        if ([_delegate respondsToSelector:@selector(audioDidBeginPlaying:)]) {
            [_delegate audioDidBeginPlaying:self];
        }
        
        if (self.audioPlayer == nil) {
            
            self.soundFileURL = [[NSURL alloc] initFileURLWithPath: self.soundFilePath];
            
            self.audioPlayer = [[AVAudioPlayer alloc]
                                initWithContentsOfURL:self.soundFileURL
                                error:&error];
            
            self.audioPlayer.delegate = self;
            self.intervalAudio = self.audioPlayer.duration;
            self.step = self.intervalAudio/240;
            NSLog(@"step: %f",self.step);
            if (error){
                NSLog(@"Error: %@",[error localizedDescription]);
                if ([_delegate respondsToSelector:@selector(audioIsEmpty)]) {
                    [_delegate audioIsEmpty];
                }
            }else{
                self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:self.step target:self selector:@selector(updateSlider) userInfo:nil repeats:YES];
                [self.audioPlayer prepareToPlay];
                [self.audioPlayer setCurrentTime:0];
                [self.audioPlayer play];
            }
        }else{
            self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:self.step target:self selector:@selector(updateSlider) userInfo:nil repeats:YES];
            [self.audioPlayer prepareToPlay];
            [self.audioPlayer setCurrentTime:0];
            [self.audioPlayer play];
        }
    }else{
        if (self.audioPlayer.playing) {
            [self.audioPlayer pause];
            [self.updateTimer invalidate];
            if ([_delegate respondsToSelector:@selector(audioDidBeginPause:)]) {
                [_delegate audioDidBeginPause:self];
            }
        }
    }
    
    if (self.updateTimer != nil) {
        [[NSRunLoop mainRunLoop] addTimer:self.updateTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopAudio{
    if (self.audioPlayer.playing) {
        [self.updateTimer invalidate];
        [self.audioPlayer stop];
        self.pressed = true;
        self.angle = -150;
        self.timeLabel.text = [self timeFormat:self.audioPlayer.duration];
        [self setNeedsDisplay];
    }
}

- (void)pauseAudio{
    if (self.audioPlayer.playing) {
        [self.updateTimer invalidate];
        [self.audioPlayer pause];
        self.pressed = true;
        [self setNeedsDisplay];
    }
}

static CGFloat pToA (CGPoint loc, UIView* self) {
    
    CGPoint c = CGPointMake(CGRectGetMidX(self.bounds),
                            CGRectGetMidY(self.bounds));
    
    return atan2(loc.y - c.y, loc.x - c.x);
}

- (void)updateSlider{
    if (!(self.angle <= -30 && self.angle >-150)) {
        if (self.angle == -179) {
            self.angle = 180;
        }else{
            self.angle = self.angle - 1;
        }
        
        float minutes = floor(lroundf(self.audioPlayer.currentTime)/60);
        float seconds = lroundf(self.audioPlayer.currentTime) - (minutes * 60);
        
        long roundedSeconds = lroundf(seconds);
        long roundedMinutes = lroundf(minutes);
        
        NSString *time = [[NSString alloc]
                          initWithFormat:@"%02ld:%02ld",
                          roundedMinutes, roundedSeconds];
        
        self.timeLabel.text = time;
        
        [self setNeedsDisplay];
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)flag{
    [self.updateTimer invalidate];
    self.angle = -150;
    self.pressed = !self.pressed;
    [self setNeedsDisplay];
    [_delegate audioDidFinishPlaying:self];
}

@end