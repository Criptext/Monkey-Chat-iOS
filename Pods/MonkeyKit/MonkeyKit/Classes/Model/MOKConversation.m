//
//  MOKConversation.m
//  Pods
//
//  Created by Gianni Carlo on 8/10/16.
//
//

#import "MOKConversation.h"

@implementation MOKConversation

-(instancetype)initWithId:(NSString *)conversationId{
    
    if (self = [super init]) {
        _conversationId = conversationId;
        _info = [@{} mutableCopy];
        _members = [@[] mutableCopy];
    }
    
    return self;
}

-(NSURL *)getAvatarURL{
    NSString *path = self.info[@"avatar"] ?: [@"https://monkey.criptext.com/user/icon/default/" stringByAppendingString:self.conversationId];
    
    return [[NSURL alloc] initWithString:path];
}

-(BOOL)isGroup{
    return [self.conversationId rangeOfString:@"G:"].location != NSNotFound;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"MOKConversation:%@\ninfo:%@\nlast modified: %f", self.conversationId, self.info, self.lastModified];
}

@end
