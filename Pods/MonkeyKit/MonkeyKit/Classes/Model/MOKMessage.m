//
//  MOKMessage.m
//  Blip
//
//  Created by G V on 12.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MOKMessage.h"
#import "MOKJSON.h"
#import "NSString+Random.h"
#import "MOKutils.h"
@interface MOKMessage()

@end

@implementation MOKMessage
@synthesize props = _props;

-(NSString *)messageText {
    if (self.encryptedText == nil) {
        return self.text;
    }
    
    return self.encryptedText;
}

- (id)initWithArgs:(NSDictionary*)dictionary{
	
	if (self = [super init]) {
		self.text = @"";
        
        if ([dictionary objectForKey:@"props"]) {
            self.props = [[NSJSONSerialization JSONObjectWithData:[[self stringFromDictionary:dictionary key:@"props"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] mutableCopy];
        }else{
            self.props = [@{} mutableCopy];
        }
        
        if ([dictionary objectForKey:@"params"]) {
            self.params = [NSJSONSerialization JSONObjectWithData:[[self stringFromDictionary:dictionary key:@"params"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        }else{
            self.params = [@{}mutableCopy];
        }
        
        self.encryptedText = [self stringFromDictionary:dictionary key:@"msg"];
        self.protocolType  = [self integerFromDictionary:dictionary key:@"type"];
        self.monkeyType = [self integerFromDictionary:self.props key:@"monkey_action"];
		
		self.timestampCreated = [self doubleFromDictionary:dictionary key:@"datetime"];
        self.timestampOrder = [[NSDate date] timeIntervalSince1970];
		
		self.userIdFrom = [self stringFromDictionary:dictionary key:@"sid"];
        self.userIdTo = nil;
        
		if([dictionary objectForKey:@"rid"]!=nil){
            self.userIdTo=[self stringFromDictionary:dictionary key:@"rid"];
        }
		
        if ([self stringFromDictionary:dictionary key:@"readBy"] != nil) {
            self.readBy = [[[self stringFromDictionary:dictionary key:@"readBy"] componentsSeparatedByString:@","] mutableCopy];
        }
		
        self.messageId = [self stringFromDictionary:dictionary key:@"id"];
        self.oldMessageId = [self stringFromDictionary:self.props key:@"old_id"];
        
		self.readByUser = NO;
        self.needsResend = NO;
        
        self.pushMessage = @"";

	}
	
	return self;
	
}

- (id)init {
    return [self initWithMessage:nil
                 protocolCommand:MOKProtocolMessage
                    protocolType:MOKText
                      monkeyType:0
                       messageId:[self generateRandomId]
                    oldMessageId:@"0"
                       timestampCreated:[[NSDate date] timeIntervalSince1970]
                  timestampOrder:[[NSDate date] timeIntervalSince1970]
                        fromUser:nil
                          toUser:nil
                    mkProperties:[@{@"encr": @"1"} mutableCopy]
                          params:nil];
}

- (id)initWithMessage:(NSString*)messageText
      protocolCommand:(MOKProtocolCommand)cmd
         protocolType:(int)protocolType
           monkeyType:(int)monkeyType
            messageId:(NSString *)messageId
         oldMessageId:(NSString *)oldMessageId
     timestampCreated:(NSTimeInterval)timestampCreated
            timestampOrder:(NSTimeInterval)timestampOrder
             fromUser:(NSString *)sessionIdFrom
               toUser:(NSString *)sessionIdTo
         mkProperties:(NSMutableDictionary *)mkprops
               params:(NSMutableDictionary *)params
{
    if (self = [super init]) {
        self.text = messageText;
        self.encryptedText = @"";
        self.timestampCreated = timestampCreated;
        self.timestampOrder = timestampOrder;
        self.userIdFrom = sessionIdFrom;
        self.userIdTo = sessionIdTo;
        self.messageId = messageId;
        self.oldMessageId = oldMessageId;
        self.readByUser = NO;
        self.protocolCommand = cmd;
        self.protocolType = protocolType;
        self.monkeyType = monkeyType;
        self.needsResend = NO;
        self.props = mkprops;
        self.params = params;
        self.pushMessage = @"";
        self.readBy = [@[] mutableCopy];
    }
    return self;
}


- (MOKMessage *)initTextMessage:(NSString*)text sender:(NSString *)senderId recipient:(NSString *)recipientId {
    if (self = [super init]) {
        self.text = text;
        self.encryptedText = nil;
        self.messageId = [self generateRandomId];
        self.oldMessageId = self.messageId;
        self.timestampCreated = [[NSDate date] timeIntervalSince1970];
        self.timestampOrder = self.timestampCreated;
        self.userIdTo = recipientId;
        self.userIdFrom = senderId;
        self.readByUser = NO;
        self.protocolCommand = MOKProtocolMessage;
        self.protocolType = MOKText;
        self.monkeyType = 0;
        self.needsResend = NO;
        self.props = [@{@"str":@"0",
                        @"old_id": self.messageId,
                        @"device":@"ios"} mutableCopy];
        self.params = [@{} mutableCopy];
        self.pushMessage = @"";
        self.readBy = [@[] mutableCopy];
    }
    return self;
}

- (MOKMessage *)initFileMessage:(NSString *)filename type:(MOKFileType)type sender:(NSString *)senderId recipient:(NSString *)recipientId {
    if (self = [super init]) {
        
        self.messageId = [self generateRandomId];
        self.oldMessageId = self.messageId;
        self.timestampCreated = [[NSDate date] timeIntervalSince1970];
        self.timestampOrder = self.timestampCreated;
        self.userIdTo = recipientId;
        self.userIdFrom = senderId;
        self.readByUser = NO;
        self.protocolCommand = MOKProtocolMessage;
        self.protocolType = MOKFile;
        self.monkeyType = 0;
        self.needsResend = NO;
        self.props = [@{@"str":@"0",
                        @"old_id": self.messageId,
                        @"device":@"ios"} mutableCopy];
        self.params = [@{} mutableCopy];
        self.pushMessage = @"";
        self.readBy = [@[] mutableCopy];
        
        //file stuff
        self.text = filename;
        self.encryptedText = filename;
        
        self.props[@"filename"] = filename;
        self.props[@"file_type"] = [NSNumber numberWithInt:type];
        
        NSString *extension = [filename pathExtension];
        
        if (extension) {
            self.props[@"ext"] = extension;
        }
        NSString *mimeType = mok_fileMIMEType(extension);
        
        if (mimeType) {
            self.props[@"mime_type"] = mimeType;
        }
    }
    return self;
}

- (void)updateMessageIdFromACK{
    self.messageId = [self.props objectForKey:@"message_id"];
    if([self.props objectForKey:@"new_id"]!=nil){
        self.messageId = [self.props objectForKey:@"new_id"];
    }
    self.oldMessageId = [self.props objectForKey:@"old_id"];
}

- (NSString*)messageTextToShow {
    return @"";
}

- (BOOL)isGroupMessage {
    return ([self.userIdTo rangeOfString:@"G:"].location!=NSNotFound || [self.userIdFrom rangeOfString:@"G:"].location!=NSNotFound);
}
- (BOOL)isBroadCastMessage {
    return ([self.userIdTo rangeOfString:@","].location!=NSNotFound || [self.userIdFrom rangeOfString:@","].location!=NSNotFound);
}

-(id) mutableCopyWithZone: (NSZone *) zone
{
    MOKMessage *messCopy = [[MOKMessage allocWithZone: zone] init];
    
    messCopy.userIdTo=self.userIdTo;
    messCopy.userIdFrom=self.userIdFrom;
    messCopy.messageId=self.messageId;
    messCopy.text=self.messageText;
    messCopy.timestampCreated=self.timestampCreated;
    messCopy.timestampOrder = self.timestampOrder;
    messCopy.protocolType=self.protocolType;
    messCopy.readByUser=self.readByUser;
    messCopy.oldMessageId=self.oldMessageId;
    messCopy.params = self.params;
    messCopy.props = self.props;
    
    return messCopy;
}

NSString* mok_fileMIMEType(NSString * extension) {
#ifdef __UTTYPE__
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
    NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
    if (!contentType) {
        return @"application/octet-stream";
    } else {
        return contentType;
    }
#else
#pragma unused (extension)
    return @"application/octet-stream";
#endif
}

-(NSString *)generateRandomId{
    return [NSString stringWithFormat:@"%lld%@",(long long)([[NSDate date] timeIntervalSince1970]* -1), [NSString mok_randomStringOfLength:3]];
}
-(NSMutableDictionary *)props{
    return _props;
}
-(void)setProps:(NSMutableDictionary *)newProps{
    _props = newProps;
}
- (void)setFileSize:(NSString *)size{
    self.props[@"size"] = size;
}
- (void)setEncrypted:(BOOL)shouldEncrypt{
    self.props[@"encr"] = shouldEncrypt? @"1":@"0";
}
- (BOOL)isEncrypted{
    return [self.props[@"encr"] intValue] ==1;
}

- (void)setCompression:(BOOL)shouldCompress{
    if (shouldCompress) {
        self.props[@"cmpr"] = @"gzip";
        return;
    }
    
    [self.props removeObjectForKey:@"cmpr"];
}
- (BOOL)isCompressed{
    NSString *compressed = self.props[@"cmpr"];
    
    if ([compressed isEqualToString:@"gzip"]) {
        return true;
    }
    
    return false;
}

- (BOOL)needsDecryption{
    if (![self isEncrypted]) {
        return false;
    }
    
    if (self.text == nil) {
        return true;
    }
    
    return false;
}

- (BOOL)isMedia{
    if (self.protocolType == MOKFile) {
        return true;
    }
    
    return false;
}

- (BOOL)isInTransit{
    unichar firstChar = [self.messageId characterAtIndex:0];
    
    if (firstChar == '-') {
        return true;
    }
    
    return false;
}
-(BOOL)isEqual:(id)object{
    
    MOKMessage *otherMsg = object;
    if ([self.messageId isEqualToString:otherMsg.messageId]) {
        return true;
    }
    if ([self.oldMessageId isEqualToString:otherMsg.oldMessageId]) {
        return true;
    }
    return false;
}

+(NSString *)generatePushFrom:(id)thing{
    NSDictionary *object = nil;
    
    if([thing isKindOfClass:[NSDictionary class]] || [thing isKindOfClass:[NSMutableDictionary class]]){
        object = thing;
    }
    
    if (object == nil && [thing isKindOfClass:[NSString class]]) {
        object = @{@"text": thing,
                   @"iosData":@{@"alert": thing,
                                @"sound": @"default"},
                   @"andData":@{@"alert": thing}
                   };
    }
    
    if (object == nil) {
        object = @{};
    }
    
    NSError * err;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&err];
    
    NSAssert(err, @"");
    NSString *pushString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return pushString;
}
@end
