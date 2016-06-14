//
//  SGSMessage.h
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MOKSGSProtocol.h"

@class MOKSGSChannel;

@interface MOKSGSMessage : NSObject {
    NSMutableData *data;
    NSUInteger payloadLength;
    NSInteger position;
}
@property (nonatomic, assign) NSUInteger payloadLength;
@property (nonatomic, assign) NSInteger position;

+ (id)message;
+ (id)messageWithData:(NSData *)messageData;

+ (id)sessionMessage;
+ (id)channelMessage:(MOKSGSChannel *)channel;

- (id)initWithData:(NSData *)messageData;

- (const void *)bytes;
- (NSUInteger)length;

- (MOKSGSOpcode)getOpcode;

- (void)appendFixedBytes:(const void *)bytes length:(NSUInteger)length;
- (void)appendArbitraryBytes:(const void *)bytes length:(NSUInteger)length;
- (void)appendString:(NSString *)string;
- (void)appendUInt16:(uint16_t)val;
- (void)appendUInt32:(uint32_t)val;

- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes;

- (void)rewind;

- (void)readBytes:(void *)bytes length:(NSUInteger)length;
- (NSData *)readBytes;
- (NSData *)readBytesWithLength:(NSUInteger)length;
- (NSData *)readRemainingBytes;

- (uint16_t)readUInt16;
- (uint32_t)readUInt32;

- (NSString *)readString;

- (MOKSGSOpcode)readOpcode;

@end
