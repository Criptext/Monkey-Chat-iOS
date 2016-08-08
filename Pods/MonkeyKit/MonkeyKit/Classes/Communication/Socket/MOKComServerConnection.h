//
//  ComServerConnection.h
//  Blip
//
//  Created by Mac on 01/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
//@required

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import "MOKSGSConnection.h"
@class MOKSGSContext;
@class MOKSGSChannel;

@class MOKMessage;


@protocol MOKComServerConnectionDelegate
- (void) parseMessage:(NSDictionary *)dictionary;
- (void) incomingMessage:(MOKMessage *)message;
- (void) fileReceivedNotification:(MOKMessage *)message;
- (void) notify:(MOKMessage *)message withCommand:(int)command;
- (void) acknowledgeNotification:(MOKMessage *)message;
- (void) getPendingMessages;

@optional
- (void) errorConnection:(NSString *)errorMessage;
- (void) disconnected;
- (void) loggedIn;
- (void) onLoadPendingMessages;
- (void) reachabilityDidChange:(AFNetworkReachabilityStatus)reachabilityStatus;
- (void) sendMessagesAgain;


@end

@interface MOKComServerConnection : NSObject {
	
	NSString * userId;
    
	MOKSGSConnection *connection;
	BOOL connected;
    
    NSTimeInterval timeSentPack;
    NSTimeInterval timeRecievePack;
    int id_package_test;
}


@property (nonatomic, weak) id<MOKComServerConnectionDelegate, NSObject> connectionDelegate;
@property (nonatomic, strong) MOKSGSConnection *connection;
@property AFNetworkReachabilityStatus networkStatus;

@property  (nonatomic, strong) NSString *userId;


+ (MOKComServerConnection*) sharedInstance;

-(void) deliverDisconnectionState;
- (void)connect:(NSString *)monkeyId
          appId:(NSString *)appId
         appKey:(NSString *)appKey
         domain:(NSString *)domain
           port:(NSString *)port
       delegate:(id<MOKComServerConnectionDelegate, NSObject>)delegate;

-(BOOL)sendMessage:(NSString *)jsonMessage;
-(void)parseMessage:(NSDictionary *)message;

-(void)logOut;

-(void)resetConnection;
-(void)resetByWatchdog;

-(BOOL)isConnected;
-(BOOL)isReachable;

@end
