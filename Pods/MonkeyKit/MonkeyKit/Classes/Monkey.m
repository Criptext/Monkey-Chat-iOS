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
NSString * const MonkeySocketDidConnectNotification = @"com.criptext.networking.socket.resume";
NSString * const MonkeySocketDidDisconnectNotification = @"com.criptext.networking.socket.close";
NSString * const MonkeySocketUnavailableNotification = @"com.criptext.networking.socket.unavailable";
NSString * const MonkeySocketStatusChangeNotification = @"com.criptext.networking.socket.status";
NSString * const MonkeyMessageStoreNotification = @"com.criptext.message.store";
NSString * const MonkeyMessageDeleteNotification = @"com.criptext.message.delete";
NSString * const MonkeyMessageNotification = @"com.criptext.message.delete";

@interface Monkey () <MOKComServerConnectionDelegate>
@property (nonatomic,strong) NSMutableArray *receivers;
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
        _receivers = [[NSMutableArray alloc]init];
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

-(void)initWithApp:(NSString *)appId
            secret:(NSString *)appKey
              user:(NSDictionary *)user
     expireSession:(BOOL)shouldExpire
         debugging:(BOOL)isDebugging
          autoSync:(BOOL)autoSync
     lastTimestamp:(NSNumber*)lastTimestamp{
    
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
    
    if (providedMonkeyId != nil) {
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
        [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:nil];
        [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketUnavailableNotification object:self userInfo:nil];
        [MOKComServerConnection sharedInstance].connection.state = MOKSGSConnectionStateNoNetwork;
    }
    else{
        [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:nil];
        
        [[MOKComServerConnection sharedInstance] connect:_session[@"monkeyId"]
                                                   appId:self.appId
                                                  appKey:self.appKey
                                                  domain:self.domain
                                                    port:self.port
                                                delegate:self];
    }
}

-(void)loggedIn{
    [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:nil];
    
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
    
    [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketDidConnectNotification object:self userInfo:[_session copy]];
}

- (void) disconnected{
    NSLog(@"Monkey - Disconnect");
    [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketStatusChangeNotification object:self userInfo:nil];
    [[NSNotificationCenter defaultCenter]postNotificationName:MonkeySocketDidDisconnectNotification object:self userInfo:nil];
    [self connect];
}



#pragma mark - Messaging manager

- (void)addReceiver:(id <MOKMessageReceiver>)receiver {
    @synchronized (self) {
        if (![self.receivers containsObject:receiver]) {
            [self.receivers addObject:receiver];
        }
    }
}

- (void)removeReceiver:(id <MOKMessageReceiver>)receiver {
    @synchronized (self) {
        [self.receivers removeObject:receiver];
    }
}

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
        if([[data objectForKey:@"messageId"] isKindOfClass:[NSString class]]){
            fileMessage.messageId = [data objectForKey:@"messageId"];
        }else{
            fileMessage.messageId = [[data objectForKey:@"messageId"] stringValue];
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
- (void)notify:(MOKMessage *)message withCommand:(int)command {
    
    //Type of messages: invites, openConversation, isTyping.
    switch (command) {
        case MOKProtocolGet:
            
            [self.receivers makeObjectsPerformSelector:@selector(notificationReceived:) withObject:message];
            return;
            break;
        default: {
            
            break;
        }
    }
    
    
    if (message.timestampCreated > [_session[@"lastTimestamp"] intValue]) {
        _session[@"lastTimestamp"] = [@(message.timestampCreated) stringValue];
    }
    
    if([self.receivers count] > 0){
        
        if([message.userIdTo rangeOfString:@","].location!=NSNotFound){
            message.userIdTo = _session[@"monkeyId"];
        }
        
        [self.receivers makeObjectsPerformSelector:@selector(notificationReceived:) withObject:message];
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
                [self incomingMessage:message];
            }];
            return;
        }
        
        if (message.text == nil) {
            NSLog(@"MONKEY - couldn't decrypt with current key, retrieving new keys");
            [[MOKAPIConnector sharedInstance] keyExchange:_session[@"monkeyId"] with:message.userIdFrom withPendingMessage:message success:^(NSDictionary * _Nonnull data) {
                [self incomingMessage:message];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [self incomingMessage:message];
            }];
            return;
        }
    }else{
        message.text = message.encryptedText;
    }
    
    if (![message.messageId isEqualToString:@"0"] && message.timestampCreated > [_session[@"lastTimestamp"] intValue]) {
        _session[@"lastTimestamp"] = [@(message.timestampCreated) stringValue];
    }
    
    @synchronized (self) {
        
        [self.receivers makeObjectsPerformSelector:@selector(messageReceived:) withObject:message];
        
    }
}

- (void)fileReceivedNotification:(MOKMessage *)message {
    
    if (message.timestampCreated > [_session[@"lastTimestamp"] intValue]) {
        _session[@"lastTimestamp"] = [@(message.timestampCreated) stringValue];
    }
    
    NSString *filename = [message.props objectForKey:@"filename"];
    if (filename != nil) {
        NSString *extension = filename.pathExtension;
        NSString *extensionless = [filename stringByDeletingPathExtension];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^a-zA-Z0-9_]+" options:0 error:nil];
        extensionless = [regex stringByReplacingMatchesInString:extensionless options:0 range:NSMakeRange(0, extensionless.length) withTemplate:@"-"];
        
        [message.props setObject:[extensionless stringByAppendingPathExtension:extension] forKey:@"filename"];
    }
    
    //    [[MOKAPIConnector sharedInstance]downloadFile:message withDelegate:self];
    
    @synchronized (self) {
        
        [self.receivers makeObjectsPerformSelector:@selector(messageReceived:) withObject:message];
        
    }
    
}
-(void)acknowledgeNotification:(MOKMessage *)message{
    
    switch (message.protocolType) {
        case MOKText: case 50: case 51: case 52:
//            [[MOKDBManager sharedInstance]deleteMessageSent:message];
//            [self sendMessagesAgain];
            break;
        case MOKFile:
            message.messageId = [message.props objectForKey:@"new_id"];
            message.oldMessageId = [message.props objectForKey:@"old_id"];
            break;
        default: {
            
            break;
        }
    }
    
    @synchronized (self) {
        [self.receivers makeObjectsPerformSelector:@selector(acknowledgeReceived:) withObject:message];
    }
}

-(void)downloadFileMessage:(MOKMessage *)message
           fileDestination:(NSString *)fileDestination
                   success:(void (^)(NSData * _Nonnull data))success
                   failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure{
    
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
    if (self.receivers != NULL) {
        [self.receivers makeObjectsPerformSelector:@selector(acknowledgeReceived:) withObject:message];
    }
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

-(void)getMessages:(NSString *)quantity sinceId:(NSString *)lastMessageId  andGetGroups:(BOOL)flag{
    NSDictionary *args = flag?
    //ask for groups
    @{@"messages_since" : lastMessageId,
      @"qty" : quantity,
      @"groups" : @"1"} :
    //don't ask for groups
    @{@"messages_since" : lastMessageId,
      @"qty" : quantity};
    
    [self sendCommand:MOKProtocolGet WithArgs:args];
}
-(void)getMessages:(NSString *)quantity sinceTimestamp:(NSString *)lastTimestamp andGetGroups:(BOOL)flag{
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
    NSDictionary *args;
    
    if ([message.pushMessage isEqualToString:@""] || message.pushMessage == nil) {
        args = @{@"id": message.messageId,
                 @"sid": message.userIdFrom,
                 @"rid": message.userIdTo,
                 @"msg": message.messageText,
                 @"type": [NSNumber numberWithInt:message.protocolType],
                 @"props": [self.jsonWriter stringWithObject:message.props],
                 @"params": [self.jsonWriter stringWithObject:message.params]
                 };
    }else{
        args = @{@"id": message.messageId,
                 @"sid": message.userIdFrom,
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