//
//  CPWatchdog.m
//  Criptext
//
//  Created by Gianni Carlo on 1/13/15.
//  Copyright (c) 2015 Nicolas VERINAUD. All rights reserved.
//

#import "MOKWatchdog.h"
#import "MOKMessage.h"
#import "MOKComServerConnection.h"
#import "MOKSGSConnection.h"

@interface MOKWatchdog ()
@property (nonatomic, strong) NSMutableArray *messagesInTransit;
@property (nonatomic, strong) NSMutableDictionary *mediasInTransit;
@property (nonatomic) BOOL isCheckingConnectivity;
@property (nonatomic) BOOL isLogout;
@end

@implementation MOKWatchdog
#pragma mark initialization
static MOKWatchdog *watchdogInstance = nil;
+ (instancetype)sharedInstance
{
    @synchronized(watchdogInstance) {
        if (watchdogInstance == nil) {
            watchdogInstance = [[self alloc] initPrivate];
        }
        
        return watchdogInstance;
    }
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[MOKWatchdog sharedInstance]"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        _messagesInTransit = [[NSMutableArray alloc] init];
        _mediasInTransit = [[NSMutableDictionary alloc] init];
        _isCheckingConnectivity = false;
        _isUpdateFinished = true;
        _isLogout = false;
    }
    return self;
}
#pragma mark - txt related methods
-(void)checkConnectivity{
    if(self.isCheckingConnectivity){
        return;
    }
    
    self.isCheckingConnectivity = true;
    self.isUpdateFinished = false;
    #ifdef DEBUG
    NSLog(@"MONKEY - check connectivity in 15secs WOOF!");
	#endif
    
    [self performSelector:@selector(resetConnectivity) withObject:nil afterDelay:5.0];
}

-(void)resetConnectivity{
    if (([MOKComServerConnection sharedInstance].connection.state != MOKSGSConnectionStateConnected || !self.isUpdateFinished) && !self.isLogout) {
        #ifdef DEBUG
        NSLog(@"MONKEY - reset conenctivity WOOF!");
		#endif
        
        self.isCheckingConnectivity = false;
        self.isUpdateFinished = false;
        //logout and let Monkey handle reconnect
        [[MOKComServerConnection sharedInstance] resetByWatchdog];
        return;
    }
    
    self.isCheckingConnectivity = false;
    #ifdef DEBUG
    NSLog(@"MONKEY - finish checking connectivity WOOF!");
	#endif
}
-(void)messageInTransit:(MOKMessage *)message{
    @synchronized(self.messagesInTransit){
        [self.messagesInTransit addObject:message];
    }
//    [self.messagesInTransit addObject:message];
    [self performSelector:@selector(checkMessages) withObject:nil afterDelay:5.0];
}

-(void)checkMessages{
    @synchronized(self.messagesInTransit){
        if (self.messagesInTransit.count == 0) {
            return;
        }
        
        MOKMessage *message = [self.messagesInTransit objectAtIndex:0];
//        MOKMessage *msg = [[MOKDBManager sharedInstance]getMessageById:message.messageId];
        
//        if (msg == nil) {
//            [self.messagesInTransit removeObjectAtIndex:0];
//            //            NSLog(@"MONKEY - Todo tuenti en el watchdog!");
//            return;
//        }
        
        [self.messagesInTransit removeAllObjects];
        
        //logout and let Monkey handle reconnect
        [[MOKComServerConnection sharedInstance] resetByWatchdog];
        
    }
}

#pragma mark - media related methods

-(void)mediaInTransit:(MOKMessage *)message{
    @synchronized(self.mediasInTransit){
        [self.mediasInTransit setObject:message forKey:message.messageId];
    }
    
}

-(void)removeMediaInTransitWithId:(NSString *)id_message{
    @synchronized(self.mediasInTransit){
        [self.mediasInTransit removeObjectForKey:id_message];
    }
}

-(MOKMessage *)getMediaInTransitWithId:(NSString *)id_message{
    @synchronized(self.mediasInTransit){
        MOKMessage *msg = [self.mediasInTransit objectForKey:[NSString stringWithFormat:@"%@",id_message]];
        return msg;
    }
}
-(void)updateFinished{
    self.isUpdateFinished = true;
}
-(void)logout{
    self.isLogout = true;
    @synchronized(watchdogInstance) {
        watchdogInstance = nil;
    }
}
-(void)login{
    self.isLogout = false;
}
@end
