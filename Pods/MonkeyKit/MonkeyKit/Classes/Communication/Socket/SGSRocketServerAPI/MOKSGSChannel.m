//
//  SGSChannel.m
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import "MOKSGSChannel.h"

#import "MOKSGSSession.h"
#import "MOKSGSConnection.h"
#import "MOKSGSMessage.h"
#import "MOKSGSId.h"

@implementation MOKSGSChannel

@synthesize delegate;
@synthesize session;
@synthesize sgsId;
@synthesize name;

- (id)initWithSession:(MOKSGSSession *)aSession channelId:(MOKSGSId *)aSgsId name:(NSString *)aName {
    if(self = [super init]) {
        self.session = aSession;
        self.sgsId = aSgsId;
        self.name = [aName copy];
    }
    return self;
}

- (void)sendMessage:(MOKSGSMessage *)msg {
    // Wrap the passed message with a new message which adds the
    // channel attributes
    MOKSGSMessage *channelMsg = [MOKSGSMessage channelMessage:self];
    [channelMsg appendArbitraryBytes:[msg bytes] length:[msg length]];
    
    [session.connection sendMessage:channelMsg];
}

@end
