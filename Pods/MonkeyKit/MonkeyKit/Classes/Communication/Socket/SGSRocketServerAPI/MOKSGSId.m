//
//  SGSId.m
//  LuckyOnline
//
//  Created by Timothy Braun on 3/15/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import "MOKSGSId.h"


@implementation MOKSGSId

@synthesize data;

+ (id)idWithData:(NSData *)theData {
    return [[MOKSGSId alloc] initWithData:theData];
}

- (id)initWithData:(NSData *)theData {
    if(self = [super init]) {
        data = [[NSData alloc] initWithData:theData];
    }
    return self;
}

- (BOOL)isEqual:(id)other {
    if(![other isKindOfClass:[MOKSGSId class]]) {
        return NO;
    }
    
    MOKSGSId *o = other;
    return [self.data isEqualToData:o.data];
}

- (NSUInteger)hash {
    return [data hash];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

@end
