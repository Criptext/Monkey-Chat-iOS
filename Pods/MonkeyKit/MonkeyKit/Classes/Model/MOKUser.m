//
//  MOKUser.m
//  Pods
//
//  Created by Gianni Carlo on 8/17/16.
//
//

#import "MOKUser.h"

@implementation MOKUser

-(instancetype)initWithId:(NSString *)monkeyId{
    
    if (self = [super init]) {
        _monkeyId = monkeyId;
    }
    
    return self;
}

-(NSURL *)getAvatarURL{
    NSString *path = self.info[@"avatar"] ?: [@"https://monkey.criptext.com/user/icon/default/" stringByAppendingString:self.monkeyId];
    
    return [[NSURL alloc] initWithString:path];
}
@end
