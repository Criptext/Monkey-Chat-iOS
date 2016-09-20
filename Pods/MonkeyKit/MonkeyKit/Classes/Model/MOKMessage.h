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
    MOKProtocolPublish = 206,
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
    MOKGroupList = 5
}MOKActionType;

@interface MOKMessage : MOKDictionaryBasedObject


/**
 *	The string identifier that uniquely identifies the current message.
 *	If the message is still sending, then the message will have the prefix `-`.
 */
@property (nonnull, nonatomic, copy) NSString * messageId;

/**
 *	If the message is already sent, this field contains the old message Id, otherwise it's an empty string
 */
@property (nullable, nonatomic, copy) NSString *oldMessageId;

/**
 *	Returns the encrypted text of the message
 */
@property (nullable, nonatomic, copy) NSString *encryptedText;

/**
 *	Returns the plain text of the message
 */
@property (nonnull, nonatomic, copy) NSString *plainText;

/**
 *	Timestamp that refers to when the message was created.
 *	For outgoing messages, 'timestampCreated' will be the same to 'timestampOrder'
 */
@property (nonatomic, assign) NSTimeInterval timestampCreated;

/**
 *	Timestamp that refers to when the message was sent/received.
 *	For outgoing messages, 'timestampCreated' will be the same to 'timestampOrder'
 */
@property (nonatomic, assign) NSTimeInterval timestampOrder;

/**
 *	Monkey id of the recipient.
 *	This could be a string of monkey ids separated by commas (Broadcast) or a Group Id
 */
@property (nonnull, nonatomic, copy) NSString * recipient;

/**
 *	Monkey id of the sender.
 *	This could be a string of monkey ids separated by commas (Broadcast) or a Group Id
 */
@property (nonnull, nonatomic, copy) NSString * sender;

/**
 *	Monkey-reserved parameters
 */
@property (nonnull, nonatomic, readonly) NSMutableDictionary *props;

/**
 *	Dictionary for the use of developers
 */
@property (nullable, nonatomic, strong) NSMutableDictionary * params;

/**
 *	Specifies whether the message has been read or not
 */
@property (nonatomic, assign) BOOL readByUser;

/**
 *	Protocol command of the message
 *	@see MOKProtocolCommand
 */
@property (nonatomic, assign) MOKProtocolCommand protocolCommand;

/**
 *	Protocol type of the message
 */
@property (nonatomic, assign) uint protocolType;

/**
 *	Int reserved for some specific monkey actions
 *	@see MOKActionType
 */
@property (nonatomic, assign) MOKActionType monkeyType;

/**
 *	Push represented with a JSON string
 */
@property (nullable, nonatomic, copy) NSString *pushMessage;

/**
 *	List of users that have read the message
 */
@property (nullable, nonatomic, strong) NSMutableArray *readBy;

/**
 *	Used to maintain a reference to a media object.
 */
@property (nullable, nonatomic, strong) id cachedMedia;

/**
 *	Returns date of the message
 */
- (nonnull NSDate *)date;

/**
 *	Returns the relative date of the message
 */
- (nonnull NSString *)relativeDate;

/**
 *  Returns the encrypted text if it's encrypted, and plain text if it's not
 */
- (nonnull NSString *)messageText;

/**
 *  Returns the conversation Id of the message
 */
- (nonnull NSString *)conversationId:(nullable NSString *)myMonkeyId;

/**
 *  Initialize a text message
 */
- (nonnull instancetype)initTextMessage:(nonnull NSString*)text sender:(nonnull NSString *)sender recipient:(nonnull NSString *)recipient;

/**
 *  Initialize a file message
 */
- (nonnull instancetype)initFileMessage:(nonnull NSString *)filename type:(MOKFileType)type sender:(nonnull NSString *)sender recipient:(nonnull NSString *)recipient;

/**
 *  Initialize message from the socket
 */
- (nonnull instancetype)initWithArgs:(nonnull NSDictionary*)dictionary;

/**
 *  Set file size in message props
 */
- (void)setFileSize:(nonnull NSString *)size;

/**
 *  Set encrypted parameter in message props
 */
- (void)setEncrypted:(BOOL)encrypted;

/**
 *  @return File path if it's a media, nil if it's not
 */
-(nullable NSString *)filePath;

/**
 *  @return File URL if it's a media, nil if it's not
 */
-(nullable NSURL *)fileURL;

/**
 *  Boolean that determines whether or not the message is decrypted
 */
- (BOOL)isEncrypted;

/**
 *  Set encryption method in message props
 */
- (void)setCompression:(BOOL)compressed;

/**
 *  Boolean that determines whether or not the message needs resending
 */
- (BOOL)needsResend;

/**
 *  Boolean that determines whether or not the message was already sent
 */
- (BOOL)wasSent;

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
- (BOOL)isMediaMessage;

/**
 *  int representing the media type
 */
- (uint)mediaType;

/**
 *  Boolean that determines whether or not the message is in transit
 */
- (BOOL)isInTransit;

- (void)updateMessageIdFromACK;

/**
 *	Boolean that determines if this is a group message
 */
- (BOOL)isGroupMessage;

/**
 *	Boolean that determines if this is a broadcast message
 */
- (BOOL)isBroadCastMessage;


+(nonnull NSString *)generatePushFrom:(nonnull id)thing;

/**
 *  Not a valid initializer.
 */
- (nullable id)init NS_UNAVAILABLE;

@end

