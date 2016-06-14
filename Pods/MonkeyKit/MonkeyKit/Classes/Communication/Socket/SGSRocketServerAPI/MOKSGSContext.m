//
//  SGSContext.m
//  LuckyOnline
//
//  Created by Timothy Braun on 3/11/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import "MOKSGSContext.h"


@implementation MOKSGSContext

@synthesize hostname;
@synthesize port;
@synthesize delegate;

- (id)initWithHostname:(NSString *)aHostname port:(NSInteger)aPort {
    if(self = [super init]) {
        self.hostname = aHostname;
        self.port = aPort;
    }
    return self;
}

@end
