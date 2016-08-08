//
//  SGSConnection.h
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MOKSGSContext;
@class MOKSGSSession;
@class MOKSGSMessage;

typedef enum {
    MOKConnectionStateDisconnected,
    MOKConnectionStateConnecting,
    MOKConnectionStateConnected,
    MOKConnectionStateNoNetwork,
} MOKConnectionState;

@interface MOKSGSConnection : NSObject <NSStreamDelegate>{
    CFSocketRef socket;
    MOKConnectionState state;
    MOKSGSContext *context;
    MOKSGSSession *session;
    NSMutableData *inBuf;
    NSMutableData *outBuf;
    
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
}
@property (nonatomic, readonly) CFSocketRef socket;
@property (nonatomic, assign) MOKConnectionState state;
@property (nonatomic, retain) MOKSGSContext *context;
@property (nonatomic, retain) MOKSGSSession *session;
@property (nonatomic, readonly) NSMutableData *inBuf;
@property (nonatomic, readonly) NSMutableData *outBuf;
@property (nonatomic, assign) BOOL expectingDisconnect;
@property (nonatomic, assign) BOOL inRedirect;
@property (nonatomic, assign) BOOL streamChanged;
@property (nonatomic, strong) NSString *delay;
@property (nonatomic, strong) NSString *portions;

- (id)initWithContext:(MOKSGSContext *)context;

- (void)disconnect;

- (void)loginWithUsername:(NSString *)username password:(NSString *)password;
- (void)logout:(BOOL)force;
-(void) readInputProcess;
- (BOOL)sendMessage:(MOKSGSMessage *)message;

- (void)resetBuffers;
- (BOOL)isConnectionAvailable ;
-(void)notifyConnectionClosed;


@end
