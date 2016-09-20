//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQMessagesMediaPlaceholderView.h"

#import "UIColor+JSQMessages.h"
#import "UIImage+JSQMessages.h"
#import "RGCircularSlider.h"

@implementation JSQMessagesMediaPlaceholderView

#pragma mark - Init

+ (id)viewWithAudioLoading
{
    RGCircularSlider *circularSlider = [[RGCircularSlider alloc]initWithFrame:CGRectMake(0, 0, 120, 120) isIncoming:false];
    circularSlider.timeLabel.text =nil;
    circularSlider.userInteractionEnabled = false;
    
    UIView *mediaView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 140, 140)];
    [mediaView addSubview:circularSlider];
    circularSlider.center = CGPointMake(mediaView.bounds.size.width/2, mediaView.bounds.size.height/2);
    
    
    UIColor *lightGrayColor = [UIColor whiteColor];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    spinner.color = [lightGrayColor jsq_colorByDarkeningColorWithValue:0.4f];
    
    UIView *containerSpinner = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 140, 140)];
    containerSpinner.backgroundColor = lightGrayColor;
    containerSpinner.alpha = 0.60;
    
    [mediaView addSubview:containerSpinner];
    containerSpinner.center = mediaView.center;
    
    [mediaView addSubview:spinner];
    spinner.center = mediaView.center;
    
    [spinner startAnimating];
    
    [mediaView bringSubviewToFront:containerSpinner];
    [mediaView bringSubviewToFront:spinner];
    
    return mediaView;
}

+ (instancetype)viewWithActivityIndicator
{
    UIColor *lightGrayColor = [UIColor jsq_messageBubbleLightGrayColor];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    spinner.color = [lightGrayColor jsq_colorByDarkeningColorWithValue:0.4f];
    
    JSQMessagesMediaPlaceholderView *view = [[JSQMessagesMediaPlaceholderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 120.0f)
                                                                                   backgroundColor:lightGrayColor
                                                                             activityIndicatorView:spinner];
    return view;
}

+ (instancetype)viewWithAttachmentIcon
{
    UIColor *lightGrayColor = [UIColor jsq_messageBubbleLightGrayColor];
    UIImage *paperclip = [[UIImage jsq_defaultAccessoryImage] jsq_imageMaskedWithColor:[lightGrayColor jsq_colorByDarkeningColorWithValue:0.4f]];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:paperclip];
    
    JSQMessagesMediaPlaceholderView *view =[[JSQMessagesMediaPlaceholderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 120.0f)
                                                                                  backgroundColor:lightGrayColor
                                                                                        imageView:imageView];
    return view;
}

- (instancetype)initWithFrame:(CGRect)frame
              backgroundColor:(UIColor *)backgroundColor
        activityIndicatorView:(UIActivityIndicatorView *)activityIndicatorView
{
    NSParameterAssert(activityIndicatorView != nil);
    
    self = [self initWithFrame:frame backgroundColor:backgroundColor];
    if (self) {
        [self addSubview:activityIndicatorView];
        _activityIndicatorView = activityIndicatorView;
        _activityIndicatorView.center = self.center;
        [_activityIndicatorView startAnimating];
        _imageView = nil;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
              backgroundColor:(UIColor *)backgroundColor
                    imageView:(UIImageView *)imageView
{
    NSParameterAssert(imageView != nil);
    
    self = [self initWithFrame:frame backgroundColor:backgroundColor];
    if (self) {
        [self addSubview:imageView];
        _imageView = imageView;
        _imageView.center = self.center;
        _activityIndicatorView = nil;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame backgroundColor:(UIColor *)backgroundColor
{
    NSParameterAssert(!CGRectEqualToRect(frame, CGRectNull));
    NSParameterAssert(!CGRectEqualToRect(frame, CGRectZero));
    NSParameterAssert(backgroundColor != nil);
    
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = backgroundColor;
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        self.contentMode = UIViewContentModeScaleAspectFill;
    }
    return self;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.activityIndicatorView) {
        self.activityIndicatorView.center = self.center;
    }
    else if (self.imageView) {
        self.imageView.center = self.center;
    }
}

@end
