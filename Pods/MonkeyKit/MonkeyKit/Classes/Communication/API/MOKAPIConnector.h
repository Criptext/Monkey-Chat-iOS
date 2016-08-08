//
//  APIConnector.h
//  CriptextKit
//
//  Created by Gianni Carlo on 2/2/15.
//  Copyright (c) 2015 Criptext. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFHTTPSessionManager.h>
#import "MOKutils.h"
@class MOKMessage;
@class MOKSBJsonWriter;

@protocol MOKAPIConnectorDelegate <NSObject>
@optional
/**
 * These callbacks must be
 * @callback
 */

-(void)onDownloadFileOK;
-(void)onDownloadFileDecryptionWrong;
-(void)onDownloadFileFail:( NSString * _Nullable)error;

-(void)onUploadFileOK:(MOKMessage * _Nullable)message;
-(void)onUploadFileFail:(MOKMessage * _Nullable)message;

-(void)onCreateGroupOK:(NSString * _Nullable)groupId;
-(void)onCreateGroupFail:(NSString * _Nullable)descriptionError;

-(void)onAddMemberToGroupOK:(NSString * _Nullable)newMemberId;
-(void)onAddMemberToGroupFail:(NSString * _Nullable)descriptionError;

-(void)onRemoveMemberFromGroupOK:(NSString * _Nullable)ok;
-(void)onRemoveMemberFromGroupFail:(NSString * _Nullable)descriptionError;

-(void)onGetGroupInfoOK:(NSDictionary * _Nullable)groupInfo andMembers:(NSArray * _Nullable)members;
-(void)onGetGroupInfoFail:(NSString * _Nullable)descriptionError;

@end

@interface MOKAPIConnector : AFHTTPSessionManager
@property (nonatomic, strong) MOKSBJsonWriter * _Nullable jsonWriter;
@property (nonatomic, strong) NSString * _Nullable baseurl;
+(MOKAPIConnector * _Nonnull)sharedInstance;
/**
 *  Register device token in push server
 *  @param deviceToken	Token of the device
 *  @param monkeyId		Password provided by Criptext
 *  @param flag		    Boolean that determines if this token is for production or development environment
 *  @param success		Completion block when the request was completed successfully
 *  @param failure		Completion block when the request failed
 */
- (void)pushSubscribeDevice:(nonnull NSData *)deviceToken
                forMonkeyId:(nonnull NSString *)monkeyId
               inProduction:(BOOL)flag
                    success:(nullable void (^)(NSURLSessionDataTask * _Nullable task, id _Nullable responseObject))success
                    failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;;

/**
 *  Authenticate with Monkey Server
 *  @param appId	Identifier of your App
 *  @param appKey	Secret token associated to your App id
 *  @param user		User metadata defined by the developer
 *  @param expires	Boolean that determines if the Monkey Id generated will expire or not
 *  @param success	Completion block when the request was completed successfully
 *  @param failure	Completion block when the request failed
 */
- (void)secureAuthenticationWithAppId:(NSString * _Nonnull)appID
                               appKey:(NSString * _Nonnull)appKey
                                 user:(NSDictionary * _Nullable)user
                        andExpiration:(BOOL)expires
                              success:(nullable void (^)(NSDictionary * _Nonnull data))success
                              failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nullable error))failure;

/**
 *  Request another user's encryption keys
 *  @param me		My Monkey Id
 *  @param monkeyId	Owner of the keys that I want
 *  @param message	Pending message
 *  @param success	Completion block when the request was completed successfully
 *  @param failure	Completion block when the request failed
 */
-(void)keyExchange:(nonnull NSString *)me
              with:(nonnull NSString *)monkeyId
withPendingMessage:(nullable MOKMessage *)message
           success:(nullable void (^)(NSDictionary * _Nonnull data))success
           failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Request my conversations since a given timestamp
 *  @param monkeyId	My Monkey Id
 *  @param since	Timestamp from which the next badge of conversations will be pulled
 *  @param quantity Number of conversations to bring
 *  @param success	Completion block when the request was completed successfully
 *  @param failure	Completion block when the request failed
 */
-(void)getConversationsOf:(NSString *)monkeyId
                    since:(NSInteger)timestamp
                 quantity:(int)qty
                  success:(nullable void (^)(NSData * _Nonnull data))success
                  failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Request message encrypted with the sender latest keys
 *  @param message	Pending message
 *  @param success	Completion block when the request was completed successfully
 *  @param failure	Completion block when the request failed
 */
-(void)getEncryptedTextForMessage:(nonnull MOKMessage *)message
                          success:(nullable void (^)(NSDictionary * _Nonnull data))success
                          failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Upload file to Monkey servers
 *  @param data		File data
 *  @param message	File message
 *  @param success	Completion block when the request was completed successfully
 *  @param failure	Completion block when the request failed
 */
-(void)sendFile:(nonnull NSData *)data
        message:(nonnull MOKMessage *)message
        success:(nullable void (^)(NSDictionary * _Nonnull data))success
        failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Upload file to Monkey servers
 *  @param message			File message
 *  @param fileDestination	NSURL pointing to folder destination
 *  @param success			Completion block when the request was completed successfully
 *  @param failure			Completion block when the request failed
 */
-(void)downloadFileMessage:(nonnull MOKMessage *)message
           fileDestination:(nonnull NSString *)fileDestination
                   success:(nullable void (^)(NSURL * _Nonnull filePath))success
                   failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

-(void)createGroupWithMe:(nonnull NSString *)me
                 members:(nonnull NSArray *)members
                  params:(nullable NSDictionary *)params
                    push:(nullable NSString *)push
                delegate:(nullable id<MOKAPIConnectorDelegate>)delegate;

- (void)addMember:(nonnull NSString *)monkeyId
             byMe:(nonnull NSString *)me
          toGroup:(nonnull NSString *)groupId
withPushToNewMember:(nullable NSString *)pushNewMember
andPushToAllMembers:(nullable NSString *)pushAllMembers
         delegate:(nullable id <MOKAPIConnectorDelegate>)delegate;

- (void)removeMember:(NSString * _Nonnull)sessionId fromGroup:(NSString * _Nonnull)groupId delegate:(id <MOKAPIConnectorDelegate> _Nullable)delegate;

-(void)getGroupInfo:(NSString * _Nonnull)groupId delegate:(id <MOKAPIConnectorDelegate> _Nullable)delegate;

- (NSString* _Nullable)postBodyForMethod:(NSString* _Nonnull)method data:(id _Nonnull)dataAsJsonComparableObject;

-(void)logout;

@end
