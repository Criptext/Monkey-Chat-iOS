//
//  MOKMessage.h
//  Blip
//
//  Created by G V on 12.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MOKDictionaryBasedObject.h"

typedef enum{
    MOKProtocolMessage = 200,
    MOKProtocolGet = 201,
    MOKProtocolTransaction = 202,
    MOKProtocolOpen = 203,
    MOKProtocolSet = 204,
    MOKProtocolACK = 205,
    MOKProtocolDelete = 207,
    MOKProtocolClose = 208,
    MOKProtocolSync = 209
} MOKProtocolCommand;

typedef enum{
    MOKText = 1,
    MOKFile = 2,
    MOKTempNote = 3,
    MOKNotif = 4,
    MOKAlert = 5
} MOKMessageType;

typedef enum{
    MOKAudio = 1,
    MOKVideo = 2,
    MOKPhoto = 3,
    MOKArchive = 4
} MOKFileType;

typedef enum{
    MOKMessagesHistory = 1,
    MOKGroupsString = 2
} MOKGetType;

typedef enum{
    MOKGroupCreate = 1,
    MOKGroupDelete = 2,
    MOKGroupNewMember = 3,
    MOKGroupRemoveMember = 4,
    MOKGroupsJoined = 5
}MOKGroupActionType;

@interface MOKMessage : MOKDictionaryBasedObject


/*!
 @property messageId
 @abstract The string identifier that uniquely identifies the current message
 @discussion If the message is still sending, then the message will have a negative id,
 otherwise the message will have a positive id.
 */
@property (nonatomic, copy) NSString *messageId;

/*!
 @property oldMessageId
 @discussion If the message is already sent, this field contains the old message Id, otherwise it's an empty string
 */
@property (nonatomic, copy) NSString *oldMessageId;

/*!
 @property text
 @abstract Returns the decrypted text of the message
 */
@property (nonatomic, copy) NSString *text;

/*!
 @property encryptedText
 @abstract Returns the encrypted text of the message
 */
@property (nonatomic, copy) NSString *encryptedText;

/*!
 @property timestampCreated
 @abstract Timestamp that refers to when the message was created
 @discussion For outgoing messages, 'timestampCreated' will be the same to 'timestampOrder'
 */
@property (nonatomic, assign) NSTimeInterval timestampCreated;

/*!
 @property timestampOrder
 @abstract Timestamp that refers to when the message was sent/received
 @discussion For outgoing messages, 'timestampCreated' will be the same to 'timestampOrder'
 */
@property (nonatomic, assign) NSTimeInterval timestampOrder;

/*!
 @property userIdTo
 @abstract Session id of the recipient
 @discussion This could be a string of session ids separated by commas (Broadcast)
 */
@property (nonatomic, copy) NSString * userIdTo;

/*!
 @property userIdFrom
 @abstract Session id of the sender
 */
@property (nonatomic, copy) NSString * userIdFrom;

/*!
 @property props
 @abstract Monkey-reserved parameters
 */
@property (nonatomic, readonly) NSMutableDictionary *props;

/*!
 @property params
 @abstract Dictionary for the use of developers
 */
@property (nonatomic, strong) NSMutableDictionary * params;

/*!
 @property readByUser
 @abstract Specifies whether the message has been read or not
 */
@property (nonatomic, assign) BOOL readByUser;

/*!
 @property protocolCommand
 @abstract Protocol command of the message
 @see MOKProtocolCommand
 */
@property (nonatomic, assign) MOKProtocolCommand protocolCommand;

/*!
 @property protocolType
 @abstract Protocol type of the message
 */
@property (nonatomic, assign) int protocolType;

/*!
 @property monkeyType
 @abstract Int reserved for some specific monkey actions
 */
@property (nonatomic, assign) int monkeyType;

/*!
 @property pushMessage
 @abstract JSON string
 */
@property (nonatomic, copy) NSString *pushMessage;

/*!
 @property needsResend
 @abstract Specifies whether the message needs to be re-sent
 */
@property (nonatomic, assign) BOOL needsResend;

/*!
 @property readBy
 @abstract List of users that have read the message
 */
@property (nonatomic, strong) NSMutableArray *readBy;

/**
 *  Returns the encrypted text if it's encrypted, and plain text if it's not
 */
- (NSString *)messageText;

/**
 *  Initialize a text message
 */
- (MOKMessage *)initTextMessage:(NSString*)text sender:(NSString *)senderId recipient:(NSString *)recipientId;

/**
 *  Initialize a file message
 */
- (MOKMessage *)initFileMessage:(NSString *)filename type:(MOKFileType)type sender:(NSString *)senderId recipient:(NSString *)recipientId;

/**
 *  Initialize message from the socket
 */
- (id)initWithArgs:(NSDictionary*)dictionary;

/**
 *  Set file size in message props
 */
- (void)setFileSize:(NSString *)size;

/**
 *  Set encrypted parameter in message props
 */
- (void)setEncrypted:(BOOL)encrypted;

/**
 *  Boolean that determines whether or not the message is decrypted
 */
- (BOOL)isEncrypted;

/**
 *  Set encryption method in message props
 */
- (void)setCompression:(BOOL)compressed;

/**
 *  Boolean that determines whether or not the message is compressed
 */
- (BOOL)isCompressed;

/**
 *  Boolean that determines whether or not the message is compressed
 */
- (BOOL)needsDecryption;

/**
 *  Boolean that determines whether or not the message is a file
 */
- (BOOL)isMedia;

/**
 *  Boolean that determines whether or not the message is in transit
 */
- (BOOL)isInTransit;

- (void)updateMessageIdFromACK;

/*
 */
- (BOOL)isGroupMessage;
/*
 */
- (BOOL)isBroadCastMessage;

-(id) mutableCopyWithZone: (NSZone *) zone;

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
               params:(NSMutableDictionary *)params;

+(NSString *)generatePushFrom:(id)thing;

@end

