//
//  SGSChannel.h
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MOKSGSSession;
@class MOKSGSId;
@class MOKSGSChannel;
@class MOKSGSMessage;

@protocol MOKSGSChannelDelegate <NSObject>

@optional
- (void)channel:(MOKSGSChannel *)channel messageReceived:(MOKSGSMessage *)message;
- (void)channelLeft:(MOKSGSChannel *)channel;

@end


@interface MOKSGSChannel : NSObject {
    __unsafe_unretained id<MOKSGSChannelDelegate> delegate;
    
    __unsafe_unretained MOKSGSSession *session;
    MOKSGSId *sgsId;
    NSString *name;
}
@property (nonatomic, assign) id<MOKSGSChannelDelegate> delegate;

@property (nonatomic, assign) MOKSGSSession *session;
@property (nonatomic, retain) MOKSGSId *sgsId;
@property (nonatomic, retain) NSString *name;

- (id)initWithSession:(MOKSGSSession *)session channelId:(MOKSGSId *)sgsId name:(NSString *)name;
- (void)sendMessage:(MOKSGSMessage *)message;

@end
