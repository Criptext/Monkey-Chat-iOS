//
//  SGSContext.h
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MOKSGSSession;
@class MOKSGSContext;
@class MOKSGSChannel;
@class MOKSGSConnection;
@class MOKSGSMessage;

@protocol MOKSGSContextDelegate <NSObject>

@optional
- (void)sgsContext:(MOKSGSContext *)context channelJoined:(MOKSGSChannel *)channel forConnection:(MOKSGSConnection *)connection;
- (void)sgsContext:(MOKSGSContext *)context messageReceived:(MOKSGSMessage *)msg forConnection:(MOKSGSConnection *)connection;
- (void)channelMessageReceived:(MOKSGSMessage *)message;

- (void)sgsContext:(MOKSGSContext *)context disconnected:(MOKSGSConnection *)connection;
- (void)sgsContext:(MOKSGSContext *)context reconnected:(MOKSGSConnection *)connection;
- (void)sgsContext:(MOKSGSContext *)context loggedIn:(MOKSGSSession *)session forConnection:(MOKSGSConnection *)connection;
- (void)sgsContext:(MOKSGSContext *)context loginFailed:(MOKSGSSession *)session forConnection:(MOKSGSConnection *)connection withMessage:(NSString *)message;

@end


@interface MOKSGSContext : NSObject {
    NSString *hostname;
    NSInteger port;
    
    __unsafe_unretained id<MOKSGSContextDelegate> delegate;
}
@property (nonatomic, retain) NSString *hostname;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, assign) id<MOKSGSContextDelegate> delegate;

- (id)initWithHostname:(NSString *)hostname port:(NSInteger)port;

@end
