//
//  Monkey.m
//  MonkeyKit
//
//  Created by Gianni Carlo on 6/1/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

#import "Monkey.h"
#import "MOKAPIConnector.h"
#import "MOKSecurityManager.h"
#import "MOKComServerConnection.h"
#import "MOKSBJSON.h"
#import "MOKWatchdog.h"
#import "NSData+GZIP.h"
#import "NSData+Base64.h"

NSString * const MonkeyRegistrationDidCompleteNotification = @"com.criptext.networking.register.success";
NSString * const MonkeyRegistrationDidFailNotification = @"com.criptext.networking.register.fail";

NSString * const MonkeySocketStatusChangeNotification = @"com.criptext.networking.socket.status";

NSString * const MonkeyMessageNotification = @"com.criptext.networking.message.received";
NSString * const MonkeyMessageDeleteNotification = @"com.criptext.networking.message.delete";
NSString * const MonkeyNotificationNotification = @"com.criptext.networking.notification";
NSString * const MonkeyAcknowledgeNotification = @"com.criptext.networking.acknowledge";

NSString * const MonkeyGroupCreateNotification = @"com.criptext.networking.group.create";
NSString * const MonkeyGroupRemoveNotification = @"com.criptext.networking.group.remove";
NSString * const MonkeyGroupAddNotification = @"com.criptext.networking.group.add";
NSString * const MonkeyGroupListNotification = @"com.criptext.group.list";

NSString * const MonkeyOpenNotification = @"com.criptext.networking.open.received";
NSString * const MonkeyOpenResponseNotification = @"com.criptext.networking.open.response";
NSString * const MonkeyCloseNotification = @"com.criptext.networking.close";

NSString * const MonkeyMessageStoreNotification = @"com.criptext.db.message.store";

@interface Monkey () <MOKComServerConnectionDelegate>
@property (nonatomic, strong) MOKSBJsonWriter *jsonWriter;
@property (nonatomic, strong) MOKSBJsonParser *jsonParser;
@end

@implementation Monkey
+ (instancetype)sharedInstance
{
    static Monkey *sharedInstance;
    
    if (!sharedInstance) {
        sharedInstance = [[self alloc] initPrivate];
    }
    
    return sharedInstance;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[Monkey sharedInstance]"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        _jsonWriter = [MOKSBJsonWriter new];
        _jsonParser = [MOKSBJsonParser new];
        _appId = nil;
        _appKey = nil;
        _domain = @"monkey.criptext.com";
        _port = @"1139";
        _session = [@{
                     @"monkeyId":@"",
                     @"user": @{},
                     @"lastTimestamp": @"0",
                     } mutableCopy];
    }
    return self;
}

- (void)checkSession{
    NSAssert(![_session[@"monkeyId"] isEqualToString:@""], @"There's no session created, don't forget to call `initWithApp:secret:user:expireSession:debugging:autoSync:lastTimestamp:`");
}

-(void)initWithApp:(NSString *)appId
            secret:(NSString *)appKey
              user:(NSDictionary *)user
     expireSession:(BOOL)shouldExpire
         debugging:(BOOL)isDebugging
          autoSync:(BOOL)autoSync
     lastTimestamp:(NSNumber*)lastTimestamp{
    
    NSAssert(![appId isEqualToString:@""], @"App Id can't be an empty string");
    NSAssert(![appKey isEqualToString:@""], @"App Key can't be an empty string");
    
    _appId = [appId copy];
    _appKey = [appKey copy];
    _session = [@{@"expireSession": @(shouldExpire),
                  @"debuggingMode": @(isDebugging),
                  @"autoSync": @(autoSync)
                  }mutableCopy];
    
    user = user ? [user mutableCopy] : [@{} mutableCopy];
    _session[@"user"] = user;
    
    _session[@"lastTimestamp"] = lastTimestamp ? [lastTimestamp stringValue] : @"0";
    
    NSString *myKeys = nil;
    NSString *providedMonkeyId = user[@"monkeyId"];
    
    if (providedMonkeyId != nil && ![providedMonkeyId isEqualToString:@""]) {
        _session[@"monkeyId"] = providedMonkeyId;
        myKeys = [[MOKSecurityManager sharedInstance]getAESbase64forUser:_session[@"monkeyId"]];
    }
    
    [[MOKAPIConnector sharedInstance].requestSerializer setAuthorizationHeaderFieldWithUsername:appId password:appKey];
    
    if (myKeys != nil) {
        // connect and be done with it
        [self connect];
        return;
    }
    
    // secure handshake
    [[MOKAPIConnector sharedInstance] secureAuthenticationWithAppId:_appId appKey:_appKey user:user andExpiration:shouldExpire success:^(NSDictionary * _Nonnull data) {
        
        _session[@"monkeyId"] = data[@"monkeyId"];
        _session[@"user"][@"monkeyId"] = data[@"monkeyId"];
        
        NSString *storedLastTimeSynced = data[@"last_time_synced"];
        
        if (storedLastTimeSynced == (id)[NSNull null]) {
            storedLastTimeSynced = @"0";
        }
    
        if ([storedLastTimeSynced intValue] > [_session[@"lastTimestamp"] intValue]) {
            _session[@"lastTimestamp"] = storedLastTimeSynced;
        }
        
        //notify whoever's listening
        [[NSNotificationCenter defaultCenter]postNotificationName:MonkeyRegistrationDidCompleteNotification object:self userInfo:[_session copy]];
        
        //start socket connection
        [self connect];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError *error) {
        //notify failure
        [[NSNotificationCenter defaultCenter]postNotificationName:MonkeyRegistrationDidFailNotification object:self userInfo:@{@"error":error}];
    }];

}

-(void)getPendingMessages{
    [self getMessages:@"15" sinceTimestamp:_session[@"lastTimestamp"] andGetGroups:false];
}

-(void)getPendingMessagesWithGroups{
    [self getMessages:@"15" sinceTimestamp:_session[@"lastTimestamp"] andGetGroups:true];
}
#pragma mark - MOKComServerConnection Delegate
-(void)connect {
    if([MOKComServerConnection sharedInstance].networkStatus == AFNetworkReachabilityStatusNotReachable) {
        NSLog(@"Monkey - Connection not available");
        [MOKComServerConnection sharedInstance].connection.state = MOKConnectionStateNoNetwork;
        [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:@{@"status": @(MOKConnectionStateNoNetwork)}];
    }
    else{
        [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:@{@"status": @(MOKConnectionStateConnecting)}];
        
        [[MOKComServerConnection sharedInstance] connect:_session[@"monkeyId"]
                                                   appId:self.appId
                                                  appKey:self.appKey
                                                  domain:self.domain
                                                    port:self.port
                                                delegate:self];
    }
}

-(void)loggedIn{
    NSString *lastMessageId = _session[@"lastTimestamp"];
    
    if (lastMessageId == (id)[NSNull null]) {
        lastMessageId = @"0";
    }

    //if the app is active, set online
    if([UIApplication sharedApplication].applicationState != UIApplicationStateBackground){
        [self sendCommand:MOKProtocolSet WithArgs:@{@"online" : @"1"}];
    }
    
    if ([_session[@"autoSync"] boolValue]) {
        [self getPendingMessages];
    }else{
        [MOKWatchdog sharedInstance].isUpdateFinished = true;
    }
    
    [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:@{@"status": @(MOKConnectionStateConnected)}];
}

- (void) disconnected{
    NSLog(@"Monkey - Disconnect");
    [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:@{@"status": @(MOKConnectionStateDisconnected)}];
    [self connect];
}

#pragma mark - Conversation stuff
-(void)getConversationsSince:(NSInteger)timestamp
                    quantity:(int)qty
                     success:(nullable void (^)(NSData * _Nonnull data))success
                     failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure{
    [self checkSession];
    [[MOKAPIConnector sharedInstance] getConversationsOf:_session[@"monkeyId"] since:timestamp quantity:qty success:^(NSData * _Nonnull data) {
        
        success(data);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        failure(task, error);
    }];
}


#pragma mark - Messaging manager

-(MOKMessage *)sendText:(NSString *)text toUser:(NSString *)monkeyId{
    return [self sendText:text encrypted:true toUser:monkeyId params:nil push:nil];
}

-(nonnull MOKMessage *)sendText:(nonnull NSString *)text encrypted:(BOOL)shouldEncrypt toUser:(nonnull NSString *)monkeyId params:(nullable NSDictionary *)params push:(nullable id)push{
    
    MOKMessage *message = [[MOKMessage alloc] initTextMessage:text sender:_session[@"monkeyId"] recipient:monkeyId];
    if (shouldEncrypt) {
        message.encryptedText = [[MOKSecurityManager sharedInstance] aesEncryptText:message.messageText fromUser:message.userIdFrom];
        [message setEncrypted:true];
    }
    
    if (params != nil) {
        message.params = [params mutableCopy];
    }
    
    if (push != nil) {
//        message.pushMessage = 
    }
    
    [self sendMessageCommandFromMessage:message];
    
    return message;
}

-(nullable MOKMessage *)sendFilePath:(NSString *)filePath
                                type:(MOKFileType)type
                            filename:(NSString *)filename
                           encrypted:(BOOL)shouldEncrypt
                          compressed:(BOOL)shouldCompress
                              toUser:(nonnull NSString *)monkeyId
                              params:(nullable NSDictionary *)params
                                push:(nullable id)push
                             success:(void (^)(MOKMessage * _Nonnull message))success
                             failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure{
    
    NSData *fileData = [[NSFileManager defaultManager] contentsAtPath:filePath];
    
    if (fileData == nil) {
        failure(nil, [NSError errorWithDomain:@"No file found"
                                                code:-57
                                            userInfo:nil]);
        return nil;
    }
    
    MOKMessage *fileMessage = [self sendFile:fileData
                                        type:type
                                    filename:filename
                                   encrypted:shouldEncrypt
                                  compressed:shouldCompress
                                      toUser:monkeyId
                                      params:params
                                        push:push
                                     success:success
                                     failure:failure];
    
    fileMessage.text = filePath;
    fileMessage.encryptedText = filePath;
    
    return fileMessage;
    
}

-(nonnull MOKMessage *)sendFile:(NSData *)data
                           type:(MOKFileType)type
                       filename:(NSString *)filename
                      encrypted:(BOOL)shouldEncrypt
                     compressed:(BOOL)shouldCompress
                         toUser:(nonnull NSString *)monkeyId
                         params:(nullable NSDictionary *)params
                           push:(nullable id)push
                        success:(void (^)(MOKMessage * _Nonnull message))success
                        failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure{
    [self checkSession];
    
    MOKMessage *fileMessage = [[MOKMessage alloc]initFileMessage:filename type:type sender:_session[@"monkeyId"] recipient:monkeyId];
    NSData *finalData = [data copy];
    
    [fileMessage setFileSize:[@(finalData.length) stringValue]];
    
    if (shouldCompress) {
        [fileMessage setCompression:true];
        finalData = [finalData gzippedData];
    }
    
    if (shouldEncrypt) {
        [fileMessage setEncrypted:true];
        finalData = [[MOKSecurityManager sharedInstance] aesEncryptData:finalData fromUser:_session[@"monkeyId"]];
    }
    
    [[MOKAPIConnector sharedInstance] sendFile:finalData message:fileMessage success:^(NSDictionary * _Nonnull data) {
        if([data[@"messageId"] isKindOfClass:[NSString class]]){
            fileMessage.messageId = data[@"messageId"];
        }else{
            fileMessage.messageId = [data[@"messageId"] stringValue];
        }
        success(fileMessage);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failure(task, error);
    }];
    
    return fileMessage;
}

-(MOKMessage *)sendMessage:(MOKMessage *)message{
    
    //check if should encrypt
    if ([message isEncrypted]) {
        message.encryptedText = [[MOKSecurityManager sharedInstance] aesEncryptText:message.text fromUser:message.userIdFrom];
    }
    
    message.protocolCommand = MOKProtocolMessage;
    message.needsResend = false;
    
    [[MOKWatchdog sharedInstance]messageInTransit:message];
    [self sendMessageCommandFromMessage:message];
    
    return message;
}

-(MOKMessage *)sendNotificationToUser:(NSString *)monkeyId withParams:(NSDictionary *)params andPush:(NSString *)push{
    MOKMessage *message = [[MOKMessage alloc] initTextMessage:@"" sender:_session[@"monkeyId"] recipient:monkeyId];
    message.protocolCommand = MOKProtocolMessage;
    message.protocolType = MOKNotif;
    message.pushMessage = push;
    message.params = [params mutableCopy];
    [self sendMessageCommandFromMessage:message];
    
    return message;
}

-(MOKMessage *)sendTemporalNotificationToUser:(NSString *)monkeyId withParams:(NSDictionary *)params andPush:(NSString *)push{
    MOKMessage *message = [[MOKMessage alloc] initTextMessage:@"" sender:_session[@"monkeyId"] recipient:monkeyId];
    message.protocolCommand = MOKProtocolMessage;
    message.protocolType = MOKTempNote;
    message.pushMessage = push;
    message.params = [params mutableCopy];
    [self sendMessageCommandFromMessage:message];
    
    return message;
}

-(MOKMessage *)sendAlertToUser:(NSString *)monkeyId withParams:(NSDictionary *)params andPush:(NSString *)push{
    MOKMessage *message = [[MOKMessage alloc] initTextMessage:@"" sender:_session[@"monkeyId"] recipient:monkeyId];
    message.protocolCommand = MOKProtocolMessage;
    message.protocolType = MOKAlert;
    message.pushMessage = push;
    message.params = [params mutableCopy];
    [self sendMessageCommandFromMessage:message];
    
    return message;
}

- (void)sendCommand:(MOKProtocolCommand)protocolCommand WithArgs:(NSDictionary *)args{
    NSDictionary *messCom = @{@"cmd":[NSNumber numberWithInt:protocolCommand],
                              @"args": args};
    
    [[MOKComServerConnection sharedInstance] sendMessage:[self.jsonWriter stringWithObject:messCom]];
}
-(void)sendCloseCommandToUser:(NSString *)sessionId{
    [self sendCommand:MOKProtocolClose WithArgs:@{@"rid": sessionId}];
}
-(void)sendDeleteCommandForMessage:(NSString *)messageId ToUser:(NSString *)monkeyId{
    
    
    [self sendCommand:MOKProtocolDelete WithArgs:@{@"id": messageId,
                                                   @"rid":monkeyId}];
}

#pragma mark - Incoming stuff

- (void)parseMessage:(NSDictionary *)message {
    int cmd=[message[@"cmd"] intValue];
    NSMutableDictionary *args=[message[@"args"] mutableCopy];
    
    if (args[@"app_id"] == nil) {
        args[@"app_id"] = self.appId;
    }
    
    switch (cmd) {
        case MOKProtocolMessage: case MOKProtocolPublish:{
            if (![MOKWatchdog sharedInstance].isUpdateFinished) {
                return;
            }
            MOKMessage *msg = [[MOKMessage alloc] initWithArgs:args];
            msg.protocolCommand = MOKProtocolMessage;
            
            [self processMOKProtocolMessage:msg];
            break;
        }
        case MOKProtocolACK:{
            MOKMessage *msg = [[MOKMessage alloc] initWithArgs:args];
            msg.protocolCommand = MOKProtocolACK;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self processMOKProtocolACK:msg];
            });
            
            break;
        }
        case MOKProtocolGet:{
            [[MOKWatchdog sharedInstance] updateFinished];
            
            if([args[@"type"] intValue] == MOKGroupsString) {
#ifdef DEBUG
                NSLog(@"MONKEY - ******** GET Command Groups ********");
#endif
                
                [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyGroupListNotification
                                                                    object:self
                                                                  userInfo:@{@"groups": [((NSString *)args[@"messages"]) componentsSeparatedByString:@","]}];
                break;
            }
            
            break;
        }
        case MOKProtocolSync:{
            [[MOKWatchdog sharedInstance] updateFinished];
            
            NSDecimalNumber *type = args[@"type"];
            
            if([type intValue] == MOKMessagesHistory) {
#ifdef DEBUG
                NSLog(@"MONKEY - ******** SYNC Command Message History ********");
#endif
                NSArray *messages = args[@"messages"];
                NSString *remaining = args[@"remaining_messages"];
                [self processSyncMessages:messages withRemaining:remaining];
            }
            
            break;
        }
        case MOKProtocolOpen:{
#ifdef DEBUG
            NSLog(@"MONKEY - ******** OPEN Command ********");
#endif
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyOpenNotification
                                                                object:self
                                                              userInfo:@{@"senderId": args[@"sid"],
                                                                         @"recipientId": args[@"rid"]}];
            
            break;
        }
        case MOKProtocolDelete:{
#ifdef DEBUG
            NSLog(@"MONKEY - ******** DELETE Command ********");
#endif
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyMessageDeleteNotification
                                                                object:self
                                                              userInfo:@{@"id": ((NSDictionary *)args[@"props"])[@"message_id"],
                                                                         @"senderId": args[@"sid"],
                                                                         @"recipientId": args[@"rid"]}];
            
            break;
        }
        case MOKProtocolClose:{
#ifdef DEBUG
            NSLog(@"MONKEY - ******** CLOSE Command ********");
#endif
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyCloseNotification
                                                                object:self
                                                              userInfo:@{@"senderId": args[@"sid"],
                                                                         @"recipientId": args[@"rid"]}];
            
            break;
        }
        default:{
            MOKMessage *msg = [[MOKMessage alloc] initWithArgs:args];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyNotificationNotification
                                                                object:self
                                                              userInfo:@{@"notification": msg}];
            
            break;
        }
    }
}
- (void)processSyncMessages:(NSArray *)messages withRemaining:(NSString *)numberOfRemaining{
    for (NSDictionary *msgdict in messages) {
        MOKMessage *msg = [[MOKMessage alloc] initWithArgs:msgdict];
        msg.protocolCommand = MOKProtocolMessage;
        [self processMOKProtocolMessage:msg];
    }
    //check if there are still pending messages
    if (![numberOfRemaining isEqualToString:@"0"]) {
        [self getPendingMessages];
    }
}
- (void)processMOKProtocolMessage:(MOKMessage *)msg {
#ifdef DEBUG
    NSLog(@"MONKEY - Message in process: %@, %@, %d", msg.messageText,msg.messageId, msg.protocolType);
#endif
    switch (msg.protocolType) {
        case MOKText:{
            //Check if we have the user key
            [self incomingMessage:msg];
            
            break;
        }
        case MOKFile:{
            msg.text = msg.encryptedText;
            [self fileReceivedNotification:msg];
            break;
        }
        case MOKTempNote:{
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyNotificationNotification
                                                                object:self
                                                              userInfo:@{@"senderId": msg.userIdFrom,
                                                                         @"recipientId": msg.userIdTo,
                                                                         @"params": msg.params}];
            break;
        }
        case MOKProtocolDelete:{
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyMessageDeleteNotification
                                                                object:self
                                                              userInfo:@{@"id": msg.props[@"message_id"],
                                                                         @"senderId": msg.userIdFrom,
                                                                         @"recipientId": msg.userIdTo}];
            break;
        }
        default:
            if (![msg.messageId isEqualToString:@"0"] && msg.timestampCreated > [_session[@"lastTimestamp"] longLongValue]) {
                _session[@"lastTimestamp"] = [@(msg.timestampCreated) stringValue];
            }
            if(msg.props.count > 0 && msg.props[@"monkey_action"] != nil){
                [self dispatchGroupNotification:msg];
                return;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyNotificationNotification
                                                                object:self
                                                              userInfo:@{@"senderId": msg.userIdFrom,
                                                                         @"recipientId": msg.userIdTo,
                                                                         @"params": msg.params}];
            break;
            
    }
}

- (void)processMOKProtocolACK:(MOKMessage *)message {
    
    switch (message.protocolType) {
        case MOKProtocolMessage: case MOKText:
            [message updateMessageIdFromACK];
            
            break;
        case MOKProtocolOpen:
            
            break;
        default:
            break;
    }
    
    NSMutableDictionary *ackParams = [@{} mutableCopy];
    
    if (message.protocolType == MOKProtocolOpen) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyOpenResponseNotification
                                                            object:self
                                                          userInfo:@{@"lastOpenMe": message.props[@"last_open_me"],
                                                                     @"lastSeen": message.props[@"last_seen"],
                                                                     @"online": message.props[@"online"]}];
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyAcknowledgeNotification
                                                        object:self
                                                      userInfo:@{@"newId": message.props[@"new_id"],
                                                                 @"oldId": message.props[@"old_id"],
                                                                 @"senderId": message.userIdFrom,
                                                                 @"recipientId": message.userIdTo,
                                                                 @"status": message.props[@"status"]}];
}

- (void)dispatchGroupNotification:(MOKMessage *)msg{
    msg.props[@"group_id"];
    [((NSString *)msg.props[@"members"]) componentsSeparatedByString:@","];
    msg.props[@"info"];
    switch ([msg.props[@"monkey_action"] intValue]) {
        case MOKGroupCreate:
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyGroupCreateNotification
                                                                object:self
                                                              userInfo:@{@"id": msg.props[@"group_id"],
                                                                         @"members": [((NSString *)msg.props[@"members"]) componentsSeparatedByString:@","],
                                                                         @"info": msg.props[@"info"]}];
            break;
        case MOKGroupDelete:
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyGroupRemoveNotification
                                                                object:self
                                                              userInfo:@{@"id": msg.userIdTo,
                                                                         @"member": msg.userIdFrom}];
            break;
        case MOKGroupNewMember:
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyGroupAddNotification
                                                                object:self
                                                              userInfo:@{@"id": msg.userIdTo,
                                                                         @"member": msg.props[@"new_member"]}];
            break;
        default:
            [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyNotificationNotification
                                                                object:self
                                                              userInfo:@{@"notification": msg}];
            break;
    }
}

- (void)incomingMessage:(MOKMessage *)message {
    
    //check if encrypted
    if ([message isEncrypted]) {
        @try {
            message.text = [[MOKSecurityManager sharedInstance] aesDecryptText:message.encryptedText fromUser:message.userIdFrom];
        }
        @catch (NSException *exception) {
            NSLog(@"MONKEY - couldn't decrypt with current key, retrieving new keys");
            [[MOKAPIConnector sharedInstance] keyExchange:_session[@"monkeyId"] with:message.userIdFrom withPendingMessage:message success:^(NSDictionary * _Nonnull data) {
                [self incomingMessage:message];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self incomingMessage:message];
                });
            }];
            return;
        }
        
        if (message.text == nil || [message.text isEqualToString:@""]) {
            NSLog(@"MONKEY - couldn't decrypt with current key, retrieving new keys");
            [[MOKAPIConnector sharedInstance] keyExchange:_session[@"monkeyId"] with:message.userIdFrom withPendingMessage:message success:^(NSDictionary * _Nonnull data) {
                [self incomingMessage:message];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self incomingMessage:message];
                });
            }];
            return;
        }
    }else{
        message.text = message.encryptedText;
        
        if (message.props[@"encoding"] != nil && ![message.props[@"encoding"] isEqualToString:@"utf8"]) {
            message.text = [[MOKSecurityManager sharedInstance] decodeBase64:message.encryptedText];
        }
    }
    
    if (![message.messageId isEqualToString:@"0"] && message.timestampCreated > [_session[@"lastTimestamp"] intValue]) {
        _session[@"lastTimestamp"] = [@(message.timestampCreated) stringValue];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyMessageNotification
                                                        object:self
                                                      userInfo:@{@"message": message}];
}

- (void)fileReceivedNotification:(MOKMessage *)message {
    
    if (message.timestampCreated > [_session[@"lastTimestamp"] intValue]) {
        _session[@"lastTimestamp"] = [@(message.timestampCreated) stringValue];
    }
    
    //NOTE: check if it's necessary
    NSString *filename = [message.props objectForKey:@"filename"];
    if (filename != nil) {
        NSString *extension = filename.pathExtension;
        NSString *extensionless = [filename stringByDeletingPathExtension];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^a-zA-Z0-9_]+" options:0 error:nil];
        extensionless = [regex stringByReplacingMatchesInString:extensionless options:0 range:NSMakeRange(0, extensionless.length) withTemplate:@"-"];
        
        [message.props setObject:[extensionless stringByAppendingPathExtension:extension] forKey:@"filename"];
    }
    
    //    [[MOKAPIConnector sharedInstance]downloadFile:message withDelegate:self];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MonkeyMessageNotification
                                                        object:self
                                                      userInfo:@{@"message": message}];
    
}

-(void)downloadFileMessage:(MOKMessage *)message
           fileDestination:(NSString *)fileDestination
                   success:(void (^)(NSData * _Nonnull data))success
                   failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure{
    [self checkSession];
    NSString *finalDir = [fileDestination stringByAppendingPathComponent:[message.text lastPathComponent]];
    if([[NSFileManager defaultManager] fileExistsAtPath:finalDir]){
        //TODO: check if message was decrypted correctly
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:finalDir];
        success(data);
        return;
    }
    
    [[MOKAPIConnector sharedInstance] downloadFileMessage:message fileDestination:fileDestination success:^(NSURL * _Nonnull filePath) {
        [self decryptFileMessage:message filePath:filePath success:success failure:failure];
    } failure:failure];
    

}

-(void)decryptFileMessage:(MOKMessage *)message
                 filePath:(NSURL *)filePath
                  success:(void (^)(NSData * _Nonnull data))success
                  failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure{
    @autoreleasepool {
        NSData *decryptedData = nil;
        //check if should decrypt
        if([message isEncrypted]){
            
            
            //check if we
#ifdef DEBUG
            NSLog(@"MONKEY - decrypting file");
            NSLog(@"MONKEY - filePath: %@", filePath);
#endif
            @try {
                NSData *data = [[NSFileManager defaultManager] contentsAtPath:[filePath path]];
                
                decryptedData = [[MOKSecurityManager sharedInstance]aesDecryptData:data fromUser:message.userIdFrom];
                
                if ([message.props[@"device"] isEqualToString:@"web"]) {
                    NSString *mediabase64 = [[NSString alloc]initWithData:decryptedData encoding:NSUTF8StringEncoding];
                    NSArray *realmediabase64 = [mediabase64 componentsSeparatedByString:@","];
                    decryptedData = [NSData mok_dataFromBase64String:[realmediabase64 lastObject]];
                }
            }
            @catch (NSException *exception) {
                [[MOKAPIConnector sharedInstance] keyExchange:_session[@"monkeyId"] with:message.userIdFrom withPendingMessage:message success:^(NSDictionary * _Nonnull data) {
                    [self decryptFileMessage:message filePath:filePath success:success failure:failure];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    
                }];
                //                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                return;
            }
            
            if (decryptedData == nil) {
                //                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                [[MOKAPIConnector sharedInstance] keyExchange:_session[@"monkeyId"] with:message.userIdFrom withPendingMessage:message success:^(NSDictionary * _Nonnull data) {
                    [self decryptFileMessage:message filePath:filePath success:success failure:failure];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    
                }];
                
                return;
            }
            
            //check for file compression
            if ([message isCompressed]) {
                decryptedData = [decryptedData gunzippedData];
#ifdef DEBUG
                NSLog(@"MONKEY - compressedData: %lu",(unsigned long)[decryptedData length]);
#endif
            }
            
            if (message.props[@"size"] != nil &&  [message.props[@"size"] longLongValue] != [decryptedData length]) {
                [[NSFileManager defaultManager] removeItemAtPath:[filePath path] error:nil];
                failure(nil, [NSError errorWithDomain:@"File decryption failed"
                                                 code:-57
                                             userInfo:nil]);
                return;
            }
            
            if (decryptedData != nil) {
                [decryptedData writeToFile:[filePath path] atomically:YES];
            }
            
            //success completion block here
        }
        success(decryptedData);
    }
    
    //    message.messageText = [message.messageText lastPathComponent];
    
    
}

-(void)onUploadFileOK:(MOKMessage *)message{
    [[MOKWatchdog sharedInstance] removeMediaInTransitWithId:message.oldMessageId];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:message.encryptedText error:NULL];
}
-(void)onUploadFileFail:(MOKMessage *)message{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:message.encryptedText error:NULL];
    NSLog(@"MONKEY - Upload Fail");
}
- (void)sendMessagesAgain {
//    if (!self.shouldResendAutomatically) {
//        return;
//    }
//    
//    MOKMessage *message= [[MOKDBManager sharedInstance] getOldestMessageNotSent];
//    
//    if (message == nil) {
//        return;
//    }
//    message.timestampCreated = [[NSDate date] timeIntervalSince1970];
//    message.timestampOrder = message.timestampCreated;
//    
//    switch (message.protocolType) {
//        case MOKText:
//            [self sendMessage:message];
//            break;
//        case MOKFile:
//#ifdef DEBUG
//            NSLog(@"MONKEY - file type resend: %@",[message.props objectForKey:@"file_type"]);
//#endif
//            [self sendFile:message ofType:[message.props objectForKey:@"file_type"]];
//            //            [self sendFileWithURL:[NSURL fileURLWithPath:message.encryptedText] ofType:(MOKFileType)[message.params objectForKey:@"file_type"] toUser:message.userIdTo andParams:message.params];
//            break;
//            
//        default:
//            break;
//    }
//    
}

-(void)getMessages:(NSString *)quantity sinceTimestamp:(NSString *)lastTimestamp andGetGroups:(BOOL)flag{
    [self checkSession];
    NSDictionary *args = flag?
    //ask for groups
    @{@"since" : lastTimestamp,
      @"qty" : quantity,
      @"groups" : @"1"} :
    //don't ask for groups
    @{@"since" : lastTimestamp,
      @"qty" : quantity};
    
    [self sendCommand:MOKProtocolSync WithArgs:args];
}

-(void)sendOpenCommandToUser:(NSString *)sessionId{
    
    [self sendCommand:MOKProtocolOpen WithArgs:@{@"rid" : sessionId}];
    
}
-(void)sendSetCommandWithArgs:(NSDictionary *)args{
    
    [self sendCommand:MOKProtocolSet WithArgs:args];
}
- (void) sendMessageCommandFromMessage:(MOKMessage *)message{
    [self checkSession];
    NSDictionary *args;
    
    if ([message.pushMessage isEqualToString:@""] || message.pushMessage == nil) {
        args = @{@"id": message.messageId,
                 @"rid": message.userIdTo,
                 @"msg": message.messageText,
                 @"type": [NSNumber numberWithInt:message.protocolType],
                 @"props": [self.jsonWriter stringWithObject:message.props],
                 @"params": [self.jsonWriter stringWithObject:message.params]
                 };
    }else{
        args = @{@"id": message.messageId,
                 @"rid": message.userIdTo,
                 @"msg": message.messageText,
                 @"type": [NSNumber numberWithInt:message.protocolType],
                 @"props": [self.jsonWriter stringWithObject:message.props],
                 @"params": [self.jsonWriter stringWithObject:message.params],
                 @"push": message.pushMessage? message.pushMessage : @""
                 };
    }
    
    [self sendCommand:message.protocolCommand WithArgs:args];
}

- (void)logout {
    [[MOKWatchdog sharedInstance]logout];
}

@end