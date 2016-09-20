//
//  SGSSession.h
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MOKSGSConnection.h"

@class MOKSGSMessage;

@interface MOKSGSSession : NSObject {
    __unsafe_unretained MOKSGSConnection *connection;
    NSData *reconnectKey;
    NSMutableDictionary *channels;
    NSString *login;
    NSString *password;
}
@property (nonatomic, assign) MOKSGSConnection *connection;
@property (nonatomic, retain) NSData *reconnectKey;
@property (nonatomic, retain) NSMutableDictionary *channels;
@property (nonatomic, retain) NSString *login;
@property (nonatomic, retain) NSString *password;

- (id)initWithConnection:(MOKSGSConnection *)connection;

- (void)receiveMessage:(MOKSGSMessage *)message;

- (void)loginWithLogin:(NSString *)username password:(NSString *)password;
- (void)logout;

@end
