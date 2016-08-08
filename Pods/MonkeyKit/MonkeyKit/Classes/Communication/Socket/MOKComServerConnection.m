//
//  ComServerConnection.m
//  Blip
//
//  Created by Mac on 01/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import "MOKComServerConnection.h"
#import "MOKSGSMessage.h"
#import "MOKSGSChannel.h"
#import "MOKJSON.h"
#import "MOKSGSContext.h"
#import "MOKSGSChannel.h"
#import "MOKMessage.h"

#import "MOKWatchdog.h"

@interface MOKComServerConnection() <MOKSGSContextDelegate, MOKSGSChannelDelegate>

@end


@implementation MOKComServerConnection

@synthesize connection, userId;

static MOKComServerConnection* comServerConnectionInstance = nil;
+ (MOKComServerConnection*) sharedInstance
{
    
	@synchronized(comServerConnectionInstance)
	{
        if (comServerConnectionInstance == nil) {
            comServerConnectionInstance = [[self alloc] initPrivate];
        }
        return comServerConnectionInstance;
	}

    
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[MOKComServerConnection sharedInstance]"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        self.connectionDelegate=nil;
        self.connection=nil;
        self.networkStatus = AFNetworkReachabilityStatusUnknown;
    }
    return self;
}


// Nobody should be able to copy 
// the shared instance.
- (id)copyWithZone:(NSZone *)zone
{
	return self;
}
-(void)setupReachability{
    if (self.networkStatus != AFNetworkReachabilityStatusUnknown) {
        return;
    }
    
    self.networkStatus = AFNetworkReachabilityStatusNotReachable;
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        NSLog(@"MONKEY - Reachability: %@", AFStringFromNetworkReachabilityStatus(status));
        
        switch (status) {
            case AFNetworkReachabilityStatusReachableViaWWAN:
            case AFNetworkReachabilityStatusReachableViaWiFi:
                self.networkStatus = AFNetworkReachabilityStatusReachableViaWiFi;
                if([self.connectionDelegate respondsToSelector:@selector(reachabilityDidChange:)]){
                    [self.connectionDelegate reachabilityDidChange:AFNetworkReachabilityStatusReachableViaWiFi];
                }
                break;
            case AFNetworkReachabilityStatusNotReachable:
            default:
                self.networkStatus = AFNetworkReachabilityStatusNotReachable;
                if([self.connectionDelegate respondsToSelector:@selector(reachabilityDidChange:)]){
                    [self.connectionDelegate reachabilityDidChange:AFNetworkReachabilityStatusNotReachable];
                }
                break;
        }
    }];
    
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
}
-(BOOL)isReachable{
    return [AFNetworkReachabilityManager sharedManager].isReachable;
}
- (void)connect:(NSString *)monkeyId
          appId:(NSString *)appId
         appKey:(NSString *)appKey
         domain:(NSString *)domain
           port:(NSString *)port
       delegate:(id<MOKComServerConnectionDelegate, NSObject>)delegate
{
    //reset watchdog status
    [[MOKWatchdog sharedInstance] login];
    [[MOKWatchdog sharedInstance] checkConnectivity];
    
	if(connection)
	{
        if(connection.state!=MOKConnectionStateDisconnected){
            [self logOut];
        }

	}

    self.connectionDelegate=delegate;
    self.userId=monkeyId;
    
    [self setupReachability];
    
    MOKSGSContext *context = [[MOKSGSContext alloc] initWithHostname:domain port:[port integerValue]];
	context.delegate = self;
	/*
	 * Create a connection.  The connection will not actually connect to
	 * the server until a call to loginWithUsername:password: is made. 
	 * All connection messages are sent to the con5text delegate. */
    connection = [[MOKSGSConnection alloc] initWithContext:context];

    [connection loginWithUsername:userId password:[NSString stringWithFormat:@"%@:%@", appId, appKey]];
}



-(BOOL) isConnected{
	if(connection.state== MOKConnectionStateConnected || connection.state==MOKConnectionStateConnecting)
		return YES;
	else
        return NO;
    
	//return [connection isConnectionAvailable];
}

-(NSTimeInterval)getLastLatency{
    NSTimeInterval time=-1;
    
    if(id_package_test>0){
        if(timeRecievePack>0){
            time= timeRecievePack-timeSentPack;
            id_package_test=0;
            timeRecievePack=0;
        }
        else{// sino ha llegado aun el mesnaje y si es mayor a 6 segundos entonces dale se setea
            time=[[NSDate date] timeIntervalSince1970]-timeSentPack;
            if(time<6)
                time=-1;
        }
        
    }

    return time;
        
}

-(void)resetConnection{
	[connection resetBuffers];
}

-(void)resetByWatchdog{
    [self logOut];
    [self sgsContext:nil disconnected:nil];
}

-(void)logOut{
	//send before logout
	if(connection!=nil ){
		[connection logout:YES];

	}
	[self resetConnection];
    id_package_test=0;
    timeRecievePack=0;
    timeSentPack=0;
}

-(void)destroyInstance{
    @synchronized(comServerConnectionInstance) {
        comServerConnectionInstance = nil;
    }
}
//sending a session message not a group message
-(BOOL)sendMessage:(NSString *)jsonMessage{

	if (connection.state!= MOKConnectionStateConnected) {
        /// si pasa esto debes llamar afuera a funcion desconectado
		return NO;
	}
	@synchronized(connection) {
		MOKSGSMessage *mess=[MOKSGSMessage  sessionMessage];
        
        NSLog(@"MONKEY - msg to  %@",jsonMessage);
        
		[mess appendString:jsonMessage];
		[connection sendMessage:mess];
		return YES;
	}
}

/** notifies that joins a channel. */
- (void)sgsContext:(MOKSGSContext *)context channelJoined:(MOKSGSChannel *)channel forConnection:(MOKSGSConnection *)connection {
	//NSLog(@"MONKEY - -----------------------------channel JOINING---------------------- %@",channel.name);
	
	/* To receive channel messages, we must set the channel delegate upon joining a
	 * channel.  The channel delegate must implement the SGSChannelDelegate protocol
	 * defined in SGSChannel.h. */
	
    NSMutableDictionary * args=[[NSMutableDictionary alloc] init];
    [args setObject:@"-12" forKey:@"id"];
    [args setObject:@"hashchan" forKey:@"c"];
    [args setObject:@"testing"  forKey:@"msg"];
    [args setObject:[NSNumber numberWithShort:0] forKey:@"type"];
//    MOKMessage *messCOM=[MOKMessage createMessageWithCommand:MOKChannelMessage AndArgs:args];
    
//    [self sendMessage:[messCOM json]];
    
}

- (void)channelLeft:(MOKSGSChannel *)channel{
	//	NSLog(@"MONKEY - -----------------------------leave the channel-----------------------");
}

- (void)channelMessageReceived:(MOKSGSMessage *)message{
	NSString *stringMes=[message readString];
    
	 //ARREGLOGRUPO saco 3 caracteres del inicio
	NSRange startRange = [stringMes rangeOfString:@"{"];
	NSString *substring = [stringMes substringFromIndex:startRange.location];
	

	NSDictionary * parsedData = (NSDictionary *) ([substring mok_JSONValue]); //parse to NSDICtionary
    
    [self.connectionDelegate parseMessage:parsedData];
}

- (void)sgsContext:(MOKSGSContext *)context messageReceived:(MOKSGSMessage *)msg forConnection:(MOKSGSConnection *)connection{
	//handle the message in a manager th,at behaves as a proxy to the UI message

	NSString *stringMes=[msg readString];

	NSLog(@"MONKEY - Message received %@",stringMes);

	NSDictionary * parsedData = (NSDictionary *) ([stringMes mok_JSONValue]); //parse to NSDICtionary
	[self.connectionDelegate parseMessage:parsedData];
}


- (void)sgsContext:(MOKSGSContext *)context disconnected:(MOKSGSConnection *)connection{
    
    NSLog(@"MONKEY - --------- socket disconnected ---------");
	
    [self performSelector:@selector(deliverDisconnectionState) withObject:nil afterDelay:0.5];
}

-(void) deliverDisconnectionState{
	
    if([self.connectionDelegate respondsToSelector:@selector(disconnected)]){
        [self.connectionDelegate disconnected];
    }
}

- (void)sgsContext:(MOKSGSContext *)context loggedIn:(MOKSGSSession *)session forConnection:(MOKSGSConnection *)connection{
	NSLog(@"MONKEY - ---------------- socket connected --------------------");
    
    
    //aqui va lo de loading da server release dialog
    if([self.connectionDelegate respondsToSelector:@selector(loggedIn)]){
        [self.connectionDelegate loggedIn];
    }
    
    [self.connectionDelegate sendMessagesAgain];
}

- (void)sgsContext:(MOKSGSContext *)context loginFailed:(MOKSGSSession *)session forConnection:(MOKSGSConnection *)connection withMessage:(NSString *)message{
	NSLog(@"MONKEY - disconnection login Failed: %@", message);
}

#pragma mark -
#pragma mark Memory management

//- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
//    /*
//     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
//     */
//    
////	[self logOut];
//	//[connection release];
//
//}



@end
