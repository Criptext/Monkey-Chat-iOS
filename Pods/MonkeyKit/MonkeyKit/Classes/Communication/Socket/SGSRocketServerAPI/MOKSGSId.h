//
//  SGSId.h
//  LuckyOnline
//
//  Created by Timothy Braun on 3/15/09.
//  Copyright 2009 Fellowship Village. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MOKSGSId : NSObject <NSCopying> {
    NSData *data;
}
@property (nonatomic, readonly) NSData *data;

+ (id)idWithData:(NSData *)data;

- (id)initWithData:(NSData *)data;

@end
