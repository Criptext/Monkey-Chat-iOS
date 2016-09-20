//
//  BLAudioMedia.h
//  Criptext
//
//  Created by Criptext Mac on 8/4/15.
//  Copyright (c) 2015 Criptext INC. All rights reserved.
//

#import "JSQMediaItem.h"
#import <AVFoundation/AVFoundation.h>
#import "RGCircularSlider.h"

@interface BLAudioMedia : JSQMediaItem <JSQMessageMediaData, NSCoding, NSCopying>

/**
 *  The audio data for the audio media item. The default value is `nil`.
 */
@property (copy, nonatomic) NSData *audio;

/**
 *  Initializes and returns a audio media item object having the given image.
 *
 *  @param image The image for the photo media item. This value may be `nil`.
 *
 *  @return An initialized `JSQPhotoMediaItem` if successful, `nil` otherwise.
 *
 *  @discussion If the image must be dowloaded from the network,
 *  you may initialize a `JSQPhotoMediaItem` object with a `nil` image.
 *  Once the image has been retrieved, you can then set the image property.
 */
- (instancetype)initWithAudio:(NSData *)data;


- (void)setFilePath:(NSString *)path;

- (void)setAudioDuration:(double)duration;
@end