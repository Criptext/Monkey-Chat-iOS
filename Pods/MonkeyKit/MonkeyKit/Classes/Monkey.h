//
//  Monkey.h
//  MonkeyKit
//
//  Created by Gianni Carlo on 6/1/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MOKMessage.h"

@protocol MOKMessageReceiver <NSObject>
@required
- (void)messageReceived:(nonnull MOKMessage *)message;
- (void)notificationReceived:(nonnull MOKMessage *)notificationMessage;
- (void)acknowledgeReceived:(nonnull MOKMessage *)ackMessage;
@end

@interface Monkey : NSObject

+ (nonnull instancetype)sharedInstance;

/**
 *  @property appId
 *  @abstract String that identifies your App Id.
 */
@property (copy, nonatomic, readonly)  NSString * _Nonnull appId;

/**
 *  @property appKey
 *  @abstract String that identifies your App Key.
 */
@property (copy, nonatomic, readonly) NSString * _Nonnull appKey;

/**
 *  @property domain
 *  @abstract String that identifies the Monkey domain.
 */
@property (copy, nonatomic, readonly) NSString * _Nonnull domain;

/**
 *  @property port
 *  @abstract String that identifies the Monkey port.
 */
@property (copy, nonatomic, readonly) NSString * _Nonnull port;

/**
 *  @property session
 *  @abstract Dictionary which holds session params:
 *  - id -> Monkey Id
 *  - user -> User metadata
 *  - lastTimestamp -> Timestamp of last sync of messages
 *  - expireSession -> Boolean that determines if this monkey id expires with time on server
 *  - debuggingMode -> Boolean that determines development and production environments
 *  - autoSync -> Boolean that determines if the sync of messages should be automatic everytime the socket connects.
 */
@property (copy, nonatomic, readonly) NSMutableDictionary * _Nonnull session;

/**
 *  @param appId          Monkey App's Id
 *  @param appKey         Monkey App's secret
 *  @param user           User metadata
 *  @param shouldExpire   Flag that determines if the newly created Monkey Id should expire
 *  @param isDebugging    Flag that determines if the app is in Development or Production
 *  @param autoSync       Flag that determines if it should request pending messages upon connection
 *  @param lastTimestamp  Optional timestamp value from which pending messages will be fetched
 *
 
 */
-(void)initWithApp:(nonnull NSString *)appId
            secret:(nonnull NSString *)appKey
              user:(nullable NSDictionary *)user
     expireSession:(BOOL)shouldExpire
         debugging:(BOOL)isDebugging
          autoSync:(BOOL)autoSync
     lastTimestamp:(nullable NSNumber*)lastTimestamp;

/**
 *  Request pending messages
 */
-(void)getPendingMessages;

/**
 *  Request pending messages and request groups to which this monkey id belongs
 */
-(void)getPendingMessagesWithGroups;


/**
 *  Send a text to a user
 *  
 *  @param  text           Plain text to send
 *  @param  shouldEncrypt  Flag that determines if the message should be encrypted
 *  @param  monkeyId       Receiver's Monkey Id
 *  @param  params         Optional params determined by the developer
 *  @param  push           Optional push that goes with the message, expected types are NSString or NSDictionary
 */
-(nonnull MOKMessage *)sendText:(nonnull NSString *)text encrypted:(BOOL)shouldEncrypt toUser:(nonnull NSString *)monkeyId params:(nullable NSDictionary *)params push:(nullable id)push;

/**
 *  Send a encrypted text to a user, null params and null push
 */
-(nonnull MOKMessage *)sendText:(nonnull NSString *)text toUser:(nonnull NSString *)monkeyId;

/**
 *  Send a notification to a user
 */
-(nonnull MOKMessage *)sendNotificationToUser:(nonnull NSString *)monkeyId withParams:(nullable NSDictionary *)params andPush:(nullable NSString *)push;

/**
 *  Send a temporal notification to a user
 */
-(nonnull MOKMessage *)sendTemporalNotificationToUser:(nonnull NSString *)monkeyId withParams:(nullable NSDictionary *)params andPush:(nullable NSString *)push;

/**
 *  Send a delete command for a given message
 */
-(void)sendDeleteCommandForMessage:(nonnull NSString *)messageId ToUser:(nonnull NSString *)monkeyId;

/**
 *  Send a file from memory
 */
-(nonnull MOKMessage *)sendFile:(nonnull NSData *)data
                           type:(MOKFileType)type
                       filename:(nonnull NSString *)filename
                      encrypted:(BOOL)shouldEncrypt
                     compressed:(BOOL)shouldCompress
                         toUser:(nonnull NSString *)monkeyId
                         params:(nullable NSDictionary *)params
                           push:(nullable id)push
                        success:(nullable void (^)(MOKMessage * _Nonnull message))success
                        failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Send a file from local path
 */
-(nullable MOKMessage *)sendFilePath:(nonnull NSString *)filePath
                                type:(MOKFileType)type
                            filename:(nonnull NSString *)filename
                           encrypted:(BOOL)shouldEncrypt
                          compressed:(BOOL)shouldCompress
                              toUser:(nonnull NSString *)monkeyId
                              params:(nullable NSDictionary *)params
                                push:(nullable id)push
                             success:(nullable void (^)(MOKMessage * _Nonnull message))success
                             failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Download file to specified folder. If it's not defined, it will use the default.
 */
-(void)downloadFileMessage:(nonnull MOKMessage *)message
           fileDestination:(nonnull NSString *)fileDestination
                   success:(nullable void (^)(NSData * _Nonnull data))success
                   failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Get conversations for my Monkey Id.
 */
-(void)getConversationsSince:(NSInteger)timestamp
                    quantity:(int)qty
                     success:(nullable void (^)(NSData * _Nonnull data))success
                     failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

@end

///--------------------
/// @name Notifications
///--------------------

/**
 Posted when the registration and secure handshake with the server is successful.
 Comes with the session dictionary.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyRegistrationDidCompleteNotification;

/**
 Posted when the registration and secure handshake with the server failed.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyRegistrationDidFailNotification;

/**
 Posted when the socket connection status is changed.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeySocketStatusChangeNotification;

/**
 Posted when a message arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyMessageNotification;

/**
 Posted when a notification arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyNotificationNotification;

/**
 Posted when an acknowledgement to a message I sent, arrives throught the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyAcknowledgeNotification;

/**
 Posted when a group creation notification arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyGroupCreateNotification;

/**
 Posted when a group member removal notification arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyGroupRemoveNotification;

/**
 Posted when a group add member notification arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyGroupAddNotification;

/**
 Posted when the list of group (ids) that I belong to, arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyGroupListNotification;

/**
 Posted when an open notification arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyOpenNotification;

/**
 Posted when a response to an open I did arrives through the socket.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyOpenResponseNotification;

/**
 Posted when someone closes a conversation with me.
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyCloseNotification;

/**
 Posted when the app should store the message
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyMessageStoreNotification;

/**
 Posted when the app should delete the message
 */
FOUNDATION_EXPORT NSString * __nonnull const MonkeyMessageDeleteNotification;