//
//  SGSSession.m
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import "MOKSGSSession.h"
#import "MOKSGSConnection.h"
#import "MOKSGSMessage.h"
#import "MOKSGSProtocol.h"
#import "MOKSGSContext.h"
#import "MOKSGSChannel.h"
#import "MOKSGSId.h"

@implementation MOKSGSSession

@synthesize connection;
@synthesize reconnectKey;
@synthesize channels;
@synthesize login;
@synthesize password;

- (id)initWithConnection:(MOKSGSConnection *)aConnection {
    if(self = [super init]) {
        self.connection = aConnection;
        self.channels = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)receiveMessage:(MOKSGSMessage *)message {
    // Get the opcode from the message
    
    MOKSGSOpcode opcode = [message readOpcode];
    //    NSLog(@"MONKEY - nivel opcode = %d", opcode);
    switch (opcode) {
        case MOKSGSOpcodeLoginSuccess:
        {
            // Login success only contains the key which is a byte
            // array.  We use this should we ever need to reconnect
            self.reconnectKey = [message readRemainingBytes];
            if([connection.context.delegate respondsToSelector:@selector(sgsContext:loggedIn:forConnection:)]) {
                [connection.context.delegate sgsContext:connection.context loggedIn:self forConnection:connection];
            }
            
            break;
        }
        case MOKSGSOpcodeLoginFailure:
        {
            // We need to get the error string then disconnect
            NSString *err = [message readString];
            
            // Disconnect from the servier
            [self.connection disconnect];
            
            if([connection.context.delegate respondsToSelector:@selector(sgsContext:loginFailed:forConnection:withMessage:)]) {
                [connection.context.delegate sgsContext:connection.context loginFailed:self forConnection:connection withMessage:err];
            }
            
            break;
        }
        case MOKSGSOpcodeLoginRedirect:
        {
            // Get our new host and port
            NSString *newHost = [message readString];
            uint32_t newPort;
            [message readBytes:&newPort length:sizeof(uint32_t)];
            
            // Reset the context and prepare for the redirect
            connection.context.hostname = newHost;
            connection.context.port = newPort;
            connection.inRedirect = YES;
            [connection disconnect];
            
            // Try to login again
            [connection loginWithUsername:login password:password];
            break;
        }
        case MOKSGSOpcodeSessionMessage:
        {
            // Pass the message onto the handler
            if([connection.context.delegate respondsToSelector:@selector(sgsContext:messageReceived:forConnection:)]) {
                [connection.context.delegate sgsContext:connection.context messageReceived:message forConnection:connection];
            }
            break;
        }
        case MOKSGSOpcodeReconnectSuccess:
        {
            if([connection.context.delegate respondsToSelector:@selector(sgsContext:reconnected:)]) {
                [connection.context.delegate sgsContext:connection.context reconnected:connection];
            }
            break;
        }
        case MOKSGSOpcodeReconnectFailure:
        {
            [connection disconnect];
            break;
        }
        case MOKSGSOpcodeLogoutSuccess:
        {
            connection.expectingDisconnect = YES;
            [connection disconnect];
            break;
        }
        case MOKSGSOpcodeChannelJoin:
        {
            NSString *name = [message readString];
            NSData *sgsData = [message readRemainingBytes];
            MOKSGSId *sgsId = [MOKSGSId idWithData:sgsData];
            
            
            if([channels objectForKey:name]) {
                
                return;
            }
            
            MOKSGSChannel *channel = [[MOKSGSChannel alloc] initWithSession:self channelId:sgsId name:name];
            
            
            
            [channels setObject:channel forKey:channel.name];
            
            if([connection.context.delegate respondsToSelector:@selector(sgsContext:channelJoined:forConnection:)]) {
                [connection.context.delegate sgsContext:connection.context channelJoined:channel forConnection:connection];
            }
            
            break;
        }
        case MOKSGSOpcodeChannelLeave:
        {
            return;
            /*
             NSData *sgsData = [message readRemainingBytes];
             //SGSId *sgsId = [SGSId idWithData:sgsData];
             
             
             SGSChannel *channel = [channels objectForKey:sgsId];
             if(!channel) {
             NSLog(@"MONKEY - Channel Leave Request Failed. Not member of channel.");
             return;
             }
             
             
             if([channel.delegate respondsToSelector:@selector(channelLeft:)]) {
             [channel.delegate channelLeft:channel];
             }
             
             //[channels removeObjectForKey:sgsId];
             break;
             */
        }
        case MOKSGSOpcodeChannelMessage:
        {
            //NSData *sgsData = [message readBytes];
            //SGSId *sgsId = [SGSId idWithData:sgsData];
            
            //			NSLog(@"MONKEY - Channel comming message ");
            
            //			NSString *name = [message readString];
            
            
            
            //SGSChannel *channel = [channels objectForKey:name];
            
            /*
             
             if(!channel) {
             NSLog(@"MONKEY - Channel message dropped.  Channel not found. %@",channel.name);
             
             
             return;
             }
             
             
             
             
             if([channel.delegate respondsToSelector:@selector(channel:messageReceived:)]) {
             [channel.delegate channel:channel messageReceived:message];
             }
             */
            
            
            if([connection.context.delegate respondsToSelector:@selector(channelMessageReceived:)]) {
                [connection.context.delegate channelMessageReceived:message];
                
                //[connection.context.delegate sgsContext:connection.context messageReceived:message forConnection:connection];
            }
            
            //[channel release];
            
            break;
        }
        default:
            NSLog(@"MONKEY - Unknown opcode received.");
            break;
    }
}

- (void)loginWithLogin:(NSString *)aLogin password:(NSString *)aPassword {
    // Build the message
    MOKSGSMessage *msg = [[MOKSGSMessage alloc] init];
    
    uint8_t opcode = MOKSGSOpcodeLoginRequest;
    [msg appendArbitraryBytes:&opcode length:1];
    
    // Add the protocol version field
    uint8_t protocolVersion = MOKSGS_MSG_VERSION;
    [msg appendArbitraryBytes:&protocolVersion length:1];
    
    // Add the login string field
    [msg appendString:aLogin];
    
    // Add the password field
    [msg appendString:aPassword];
    
    // Save reference to used username and password
    self.login = aLogin;
    self.password = aPassword;
    
    // Add message to connection
    [connection sendMessage:msg];
    
    
    //[msg release];
    
    
}

- (void)logout {
    MOKSGSMessage *message = [MOKSGSMessage message];
    uint8_t opcode = MOKSGSOpcodeLogoutRequest;
    [message appendArbitraryBytes:&opcode length:1];
    [connection sendMessage:message];
}

@end
