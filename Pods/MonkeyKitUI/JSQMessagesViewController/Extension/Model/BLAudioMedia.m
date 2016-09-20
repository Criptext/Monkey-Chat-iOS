//
//  BLAudioMedia.m
//  Criptext
//
//  Created by Criptext Mac on 8/4/15.
//  Copyright (c) 2015 Criptext INC. All rights reserved.
//

#import "BLAudioMedia.h"
#import "JSQMessagesMediaPlaceholderView.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
#import "UIColor+JSQMessages.h"

#define min_time_efimero 15

@interface BLAudioMedia ()

@property (strong, nonatomic) id cachedAudioView;
@property (strong, nonatomic) id cachedPlaceholderView;

@end

@implementation BLAudioMedia

#pragma mark - Initialization

-(instancetype)initWithAudio:(NSData *)data{
    self = [super init];
    if (self) {
        _audio = [data copy];
        _cachedAudioView = nil;
    }
    return self;
}

- (void)clearCachedMediaViews
{
    [super clearCachedMediaViews];
    _cachedAudioView = nil;
}

#pragma mark - Setters

- (void)setAudio:(NSData *)audio
{
    _audio = [audio copy];
    _cachedAudioView = nil;
}

- (void)setAppliesMediaViewMaskAsOutgoing:(BOOL)appliesMediaViewMaskAsOutgoing
{
    [super setAppliesMediaViewMaskAsOutgoing:appliesMediaViewMaskAsOutgoing];
    _cachedAudioView = nil;
}

- (void)setFilePath:(NSString *)path {
    if (self.audio == nil) {
        return;
    }
    
    ((RGCircularSlider *)[self mediaView].subviews.firstObject).soundFilePath = path;
}

- (void)setAudioDuration:(double)duration {
    if (self.audio == nil) {
        return;
    }
    
    ((RGCircularSlider *)[self mediaView].subviews.firstObject).timeLabel.text = [((RGCircularSlider *)[self mediaView].subviews.firstObject) timeFormat:duration];
}

#pragma mark - JSQMessageMediaData protocol

- (CGSize)mediaViewDisplaySize
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return CGSizeMake(140, 120);
    }
    
    return CGSizeMake(140, 120);
}

- (UIView *)mediaView
{
    if (self.audio == nil) {
        return nil;
    }
    
    if (self.cachedAudioView == nil) {
        CGSize size = [self mediaViewDisplaySize];
        RGCircularSlider *circularSlider = [[RGCircularSlider alloc]initWithFrame:CGRectMake(0, 0, size.width - 20, size.height) isIncoming:self.appliesMediaViewMaskAsOutgoing];
        UIView *mediaView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        [mediaView addSubview:circularSlider];
        circularSlider.center = CGPointMake(mediaView.bounds.size.width/2, mediaView.bounds.size.height/2);

        [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:mediaView isOutgoing:self.appliesMediaViewMaskAsOutgoing];
        self.cachedAudioView = mediaView;
    }
    
    return self.cachedAudioView;
}

- (NSUInteger)mediaHash
{
    return self.hash;
}

- (BOOL)needsDownload {
    
    if (self.audio == nil) {
        return true;
    }
    
    return false;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    return super.hash ^ self.audio.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: image=%@, appliesMediaViewMaskAsOutgoing=%@>",
            [self class], self.audio, @(self.appliesMediaViewMaskAsOutgoing)];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _audio = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(audio))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.audio forKey:NSStringFromSelector(@selector(audio))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    
    BLAudioMedia *copy = [[BLAudioMedia allocWithZone:zone] initWithAudio:self.audio];
    copy.appliesMediaViewMaskAsOutgoing = self.appliesMediaViewMaskAsOutgoing;
    return copy;
}

-(UIView *)mediaPlaceholderView{
    if (self.cachedPlaceholderView == nil) {
        CGSize size = [self mediaViewDisplaySize];
        UIView *view = [JSQMessagesMediaPlaceholderView viewWithAudioLoading];
        view.frame = CGRectMake(0.0f, 0.0f, size.width, size.height);
        [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:view isOutgoing:self.appliesMediaViewMaskAsOutgoing];
        self.cachedPlaceholderView = view;
    }
    
    return self.cachedPlaceholderView;
}
///////////////////////

//-(instancetype)initWithMediaName:(NSString *)name asOutgoing:(BOOL)isOutgoing isEfimero:(BOOL)isEfimero readStatus:(BOOL)readByUser{
//    if (self = [super init]) {
//        self.appliesMediaViewMaskAsOutgoing = isOutgoing;
////        self.size = CGSizeMake(140, 120);
//        
////        NSString *mediaPath = [[self documentsDirectory] stringByAppendingPathComponent:_mediaName];
//        
//        if(!isOutgoing){
//            UIView *view = [JSQMessagesMediaPlaceholderView viewWithAudioLoading];
//            view.contentMode = UIViewContentModeScaleAspectFill;
//            view.clipsToBounds = YES;
//            view.autoresizesSubviews = YES;
//            [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:view isOutgoing:self.appliesMediaViewMaskAsOutgoing];
//            self.cachedMediaView = view;
//            return self;
//        }
//        
//    }
//    return self;
//}
@end