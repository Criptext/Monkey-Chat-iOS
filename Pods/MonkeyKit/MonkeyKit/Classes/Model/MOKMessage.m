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
#import <MobileCoreServices/MobileCoreServices.h>

@interface MOKMessage()
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation MOKMessage
@synthesize props = _props;

-(NSString *)messageText {
    if ([self isEncrypted] && self.plainText != nil) {
        return self.plainText;
    }
    
    return self.encryptedText;
}

-(NSString *)filePath {
    if (![self isMediaMessage]) {
        return nil;
    }
    NSString *documentDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documentDirectory = [documentDirectory stringByAppendingPathComponent:self.plainText];
    documentDirectory = [[documentDirectory stringByDeletingPathExtension] stringByAppendingPathExtension:self.props[@"ext"]];
    
    return documentDirectory;
}

-(NSURL *)fileURL {
    if (![self isMediaMessage]) {
        return nil;
    }
    NSString *documentDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    documentDirectory = [documentDirectory stringByAppendingPathComponent:self.plainText];
    documentDirectory = [[documentDirectory stringByDeletingPathExtension] stringByAppendingPathExtension:self.props[@"ext"]];
    
    return [[NSURL alloc] initFileURLWithPath:documentDirectory];
}

- (NSString *)conversationId:(NSString *)myMonkeyId{

    if ([self isGroupMessage] || (myMonkeyId != nil && [myMonkeyId isEqualToString:self.sender])) {
        return self.recipient;
    }
    
    return self.sender;
}

- (id)initWithArgs:(NSDictionary*)dictionary{
	
	if (self = [super init]) {
		self.plainText = @"";
        
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
		
		self.sender = [self stringFromDictionary:dictionary key:@"sid"];
        self.recipient = [self stringFromDictionary:dictionary key:@"rid"];
		
        if ([self stringFromDictionary:dictionary key:@"readBy"] != nil) {
            self.readBy = [[[self stringFromDictionary:dictionary key:@"readBy"] componentsSeparatedByString:@","] mutableCopy];
        }
		
        self.messageId = [self stringFromDictionary:dictionary key:@"id"];
        self.oldMessageId = [self stringFromDictionary:self.props key:@"old_id"];
        
		self.readByUser = NO;
        
        self.pushMessage = @"";

	}
	
	return self;
	
}

- (id)initWithMessage:(NSString*)text
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
        self.plainText = text;
        self.encryptedText = @"";
        self.timestampCreated = timestampCreated;
        self.timestampOrder = timestampOrder;
        self.sender = sessionIdFrom;
        self.recipient = sessionIdTo;
        self.messageId = messageId;
        self.oldMessageId = oldMessageId;
        self.readByUser = NO;
        self.protocolCommand = cmd;
        self.protocolType = protocolType;
        self.monkeyType = monkeyType;
        self.props = mkprops;
        self.params = params;
        self.pushMessage = @"";
        self.readBy = [@[] mutableCopy];
    }
    return self;
}


- (MOKMessage *)initTextMessage:(NSString*)text sender:(NSString *)sender recipient:(NSString *)recipient {
    return [self initMessage:text sender:sender recipient:recipient params:[@{} mutableCopy] props:[@{} mutableCopy]];
}

- (MOKMessage *)initTextMessage:(NSString*)text
                         sender:(NSString *)sender
                      recipient:(NSString *)recipient
                         params:(NSDictionary *)params{
    
    return [self initMessage:text sender:sender recipient:recipient params:params props:[@{} mutableCopy]];
}

- (MOKMessage *)initMessage:(NSString*)text
                     sender:(NSString *)sender
                  recipient:(NSString *)recipient
                     params:(NSDictionary *)params
                      props:(NSDictionary *)props{
    if (self = [super init]) {
        self.plainText = text;
        self.encryptedText = nil;
        self.messageId = [self generateRandomId];
        self.oldMessageId = self.messageId;
        self.timestampCreated = [[NSDate date] timeIntervalSince1970];
        self.timestampOrder = self.timestampCreated;
        self.recipient = recipient;
        self.sender = sender;
        self.readByUser = NO;
        self.protocolCommand = MOKProtocolMessage;
        self.protocolType = MOKText;
        self.monkeyType = 0;
        self.props = props;
        
        if (self.props[@"file_type"] != nil) {
            self.protocolType = MOKFile;
        }
        
        self.params = params;
        self.pushMessage = @"";
        self.readBy = [@[] mutableCopy];
    }
    return self;
}

- (MOKMessage *)initFileMessage:(NSString *)filename type:(MOKFileType)type sender:(NSString *)sender recipient:(NSString *)recipient {
    if (self = [super init]) {
        
        self.messageId = [self generateRandomId];
        self.oldMessageId = self.messageId;
        self.timestampCreated = [[NSDate date] timeIntervalSince1970];
        self.timestampOrder = self.timestampCreated;
        self.recipient = recipient;
        self.sender = sender;
        self.readByUser = NO;
        self.protocolCommand = MOKProtocolMessage;
        self.protocolType = MOKFile;
        self.monkeyType = 0;
        self.props = [@{@"str":@"0",
                        @"old_id": self.messageId,
                        @"device":@"ios"} mutableCopy];
        self.params = [@{} mutableCopy];
        self.pushMessage = @"";
        self.readBy = [@[] mutableCopy];
        
        //file stuff
        self.plainText = filename;
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
    return ([self.recipient rangeOfString:@"G:"].location!=NSNotFound || [self.sender rangeOfString:@"G:"].location!=NSNotFound);
}
- (BOOL)isBroadCastMessage {
    return ([self.recipient rangeOfString:@","].location!=NSNotFound || [self.sender rangeOfString:@","].location!=NSNotFound);
}

-(id) mutableCopyWithZone: (NSZone *) zone
{
    
    MOKMessage *messCopy = [[MOKMessage alloc] initTextMessage:self.plainText sender:self.sender recipient:self.recipient];
    
    messCopy.messageId=self.messageId;
    messCopy.encryptedText = self.encryptedText;
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

- (BOOL)needsResend{
    if ([self wasSent]) {
        return false;
    }
    double seconds = [[NSDate date] timeIntervalSince1970] - self.timestampOrder;
    
    if (seconds > 15) {
        return true;
    }
    
    return false;
}

- (BOOL)wasSent{
    return ![self.messageId hasPrefix:@"-"];
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
    
    if (self.plainText == nil) {
        return true;
    }
    
    return false;
}

-(NSDate *)date{
    return [NSDate dateWithTimeIntervalSince1970:self.timestampCreated];
}

- (NSString *)relativeDate{
    if (self.dateFormatter == nil) {
        self.dateFormatter = [[NSDateFormatter alloc] init];
    }
    double seconds = [[NSDate date] timeIntervalSince1970] - self.timestampCreated;
    
    if (seconds <= 86400) {
        self.dateFormatter.timeStyle = NSDateFormatterShortStyle;
        self.dateFormatter.dateStyle = NSDateFormatterNoStyle;
    }else{
        self.dateFormatter.timeStyle = NSDateFormatterNoStyle;
        self.dateFormatter.dateStyle = NSDateFormatterShortStyle;
    }
    
    if (seconds > 86400 && seconds < 172800) {
        return @"Yesterday";
    }
    return [self.dateFormatter stringFromDate:self.date];
    
}

- (BOOL)isMediaMessage{
    if (self.protocolCommand == MOKProtocolMessage && self.protocolType == MOKFile) {
        return true;
    }
    
    return false;
}

- (uint)mediaType{
    if ([self isMediaMessage]) {
        return self.params[@"file_type"] ? [self.params[@"file_type"] unsignedIntegerValue]: [self.props[@"file_type"] unsignedIntegerValue];
    }
    
    return -1;
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
    if ([self.oldMessageId isEqualToString:@""]) {
        return false;
    }
    if ([self.oldMessageId isEqualToString:otherMsg.oldMessageId]) {
        return true;
    }
    return false;
}

-(NSString *)description{
    return [NSString stringWithFormat:@"MOKMessage:%@\nplainText:%@\ntimestamp creation: %f", self.messageId, self.plainText, self.timestampCreated];
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
    
    NSAssert(err == nil, @"Failed JSON serialization");
    NSString *pushString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return pushString;
}
@end
