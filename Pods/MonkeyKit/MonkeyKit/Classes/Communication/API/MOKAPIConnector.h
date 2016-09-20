//
//  APIConnector.h
//  CriptextKit
//
//  Created by Gianni Carlo on 2/2/15.
//  Copyright (c) 2015 Criptext. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFHTTPSessionManager.h>

@class MOKMessage;
@class MOKConversation;
@class MOKSBJsonWriter;

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
                        ignoredParams:(nullable NSArray<NSString *> *)params
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
-(void)getConversationsOf:(nonnull NSString *)monkeyId
                    since:(double)timestamp
                 quantity:(int)qty
                  success:(nullable void (^)(NSArray<MOKConversation *> * _Nonnull conversations))success
                  failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Request my conversation messages since a given timestamp
 *  @param monkeyId1	My Monkey Id
 *  @param monkeyId2	Recipient Monkey Id
 *  @param since		Timestamp from which the next badge of messages will be pulled
 *  @param quantity 	Number of messages to bring
 *  @param success		Completion block when the request was completed successfully
 *  @param failure		Completion block when the request failed
 */
-(void)getMessagesBetween:(nonnull NSString *)monkeyId1
                      and:(nonnull NSString *)monkeyId2
                    since:(NSInteger)timestamp
                 quantity:(int)qty
                  success:(nullable void (^)(NSMutableArray<MOKMessage *> * _Nonnull messages))success
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

/**
 *  Stop ongoing download operation
 *
 *  @param identifier	Id of the message which the file belongs to.
 *	@param resumeData	Data to resume downloading at a later date
 *
 *	@discussion If there's no operation for the given identifier, nothing will happen
 */
-(void)stopDownload:(nonnull NSString *)identifier
         resumeData:(nullable void (^)(NSData * _Nullable resumeData))resumeData;


/**
 *  Resume previous download operation
 *
 *  @param resumeData      Data already downloaded
 *  @param fileDestination NSURL pointing to folder destination
 *  @param success         Completion block when the request was completed successfully
 *  @param failure         Completion block when the request failed
 */
-(void)resumeDownload:(nonnull NSData *)resumeData
      fileDestination:(nonnull NSString *)fileDestination
              success:(nullable void (^)(NSURL * _Nonnull filePath))success
              failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Delete the conversation between two monkey ids or a group
 *  @param monkeyId1	Dictionary containing the group metadata
 *  @param monkeyId2	Dictionary or String containing the push info
 *  @param success		Completion block when the request was completed successfully
 *  @param failure		Completion block when the request failed
 */
-(void)deleteConversationBetween:(nonnull NSString *)monkeyId1
                             and:(nonnull NSString *)monkeyId2
                         success:(nullable void (^)(NSDictionary * _Nonnull data))success
                         failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Create a group or add members to existing group
 *  @param optionalId	Optional group id
 *  @param creator		String monkey id of the group's creator
 *  @param members		Array of monkey ids
 *  @param info			Dictionary containing the group metadata
 *  @param push			Dictionary or String containing the push info
 *  @param success		Completion block when the request was completed successfully
 *  @param failure		Completion block when the request failed
 */
-(void)createGroup:(nullable NSString *)optionalId
           creator:(nonnull NSString *)monkeyId
           members:(nonnull NSArray *)members
              info:(nullable NSDictionary *)params
              push:(nullable id)push
           success:(nullable void (^)(NSDictionary * _Nonnull groupData))success
           failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Add a member to a existing group
 *  @param newMonkeyId		New member's Monkey Id
 *  @param groupId			Group Id
 *  @param monkeyId			Monkey Id of the user who added the new member
 *  @param pushNewMember	Dictionary or String containing the push info for the new member
 *  @param pushAllMembers	Dictionary or String containing the push info for existing members
 *  @param success			Completion block when the request was completed successfully
 *  @param failure			Completion block when the request failed
 */
- (void)addMember:(nonnull NSString *)newMonkeyId
          toGroup:(nonnull NSString *)groupId
           byUser:(nonnull NSString *)monkeyId
withPushToNewMember:(nullable NSString *)pushNewMember
andPushToAllMembers:(nullable NSString *)pushAllMembers
          success:(nullable void (^)(NSDictionary * _Nonnull groupData))success
          failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Remove a member from a existing group
 *  @param groupId		Id of the group
 *  @param monkeyId		Monkey Id of the user to be removed from the group
 *  @param success		Completion block when the request was completed successfully
 *  @param failure		Completion block when the request failed
 */
- (void)removeMember:(nonnull NSString *)monkeyId
           fromGroup:(nonnull NSString *)groupId
             success:(nullable void (^)(NSDictionary * _Nonnull groupData))success
             failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Get the metadata of a group or a user
 *
 *  @param conversationId Monkey Id or a Group Id
 *  @param success        Completion block when the request was completed successfully
 *  @param failure        Completion block when the request failed
 */
- (void)getInfo:(nonnull NSString *)conversationId
        success:(nullable void (^)(NSDictionary * _Nonnull info))success
        failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

/**
 *  Get info of multiple users
 *
 *  @param idList  Array of monkey Ids
 *  @param success Completion block when the request was completed successfully
 *  @param failure Completion block when the request failed
 */
- (void)getInfoByIds:(nonnull NSArray *)idList
             success:(nullable void (^)(NSDictionary * _Nonnull infos))success
             failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;

- (NSString* _Nullable)postBodyForMethod:(NSString* _Nonnull)method data:(id _Nonnull)dataAsJsonComparableObject;

-(void)logout;

@end
