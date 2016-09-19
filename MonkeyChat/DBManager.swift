//
//  DBManager.swift
//  MonkeyChat
//
//  Created by Gianni Carlo on 5/31/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

import Foundation
import MonkeyKit
import RealmSwift

class DBManager {
    class func store(message:MOKMessage) {
        
        let messageItem = DBManager.transform(message)
        
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(messageItem, update: true)
        }
    }
    
    class func store(conversation:MOKConversation) {
        let conversationItem = DBManager.transform(conversation)
        
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(conversationItem, update: true)
        }
    }
    
    class func transform(message:MOKMessage) -> MessageItem {
        let messageItem = MessageItem()
        messageItem.messageId = message.messageId
        messageItem.oldMessageId = message.oldMessageId!
        messageItem.sender = message.sender
        messageItem.recipient = message.recipient
        messageItem.timestampOrder = message.timestampOrder
        messageItem.timestampCreated = message.timestampCreated
        messageItem.plainText = message.plainText
        messageItem.encryptedText = message.encryptedText
        
        let bytesParams = try? NSJSONSerialization.dataWithJSONObject(message.params ?? NSMutableDictionary(), options: NSJSONWritingOptions.PrettyPrinted)
        let bytesProps = try? NSJSONSerialization.dataWithJSONObject(message.props ?? NSMutableDictionary(), options: NSJSONWritingOptions.PrettyPrinted)
        
        messageItem.props = bytesProps
        messageItem.params = bytesParams
        
        return messageItem
    }
    
    class func transform(conversation:MOKConversation) -> ConversationItem {
        let conversationItem = ConversationItem()
        conversationItem.conversationId = conversation.conversationId
        conversationItem.info = try? NSJSONSerialization.dataWithJSONObject(conversation.info ?? NSMutableDictionary(), options: NSJSONWritingOptions.PrettyPrinted)
        conversationItem.members = conversation.members.componentsJoinedByString(",")
        
        if let lastMessage = conversation.lastMessage {
            conversationItem.lastMessage = DBManager.transform(lastMessage)
        }
        
        conversationItem.lastModified = conversation.lastModified
        conversationItem.lastSeen = conversation.lastSeen
        conversationItem.unread = conversation.unread
        
        return conversationItem
    }
    
    class func transform(messageItem:MessageItem) -> MOKMessage {
        var props = NSMutableDictionary()
        var params = NSMutableDictionary()
        
        if let bytesParams = messageItem.params {
            params = try! NSJSONSerialization.JSONObjectWithData(bytesParams, options: NSJSONReadingOptions.MutableContainers) as! NSMutableDictionary
        }
        if let bytesProps = messageItem.props {
            props = try! NSJSONSerialization.JSONObjectWithData(bytesProps, options: NSJSONReadingOptions.MutableContainers) as! NSMutableDictionary
        }
        
        let message = MOKMessage(message: messageItem.plainText, sender: messageItem.sender, recipient: messageItem.recipient, params: params as [NSObject:AnyObject], props: props as [NSObject:AnyObject])
        message.messageId = messageItem.messageId
        message.oldMessageId = messageItem.oldMessageId
        message.timestampOrder = messageItem.timestampOrder
        message.timestampCreated = messageItem.timestampCreated
        message.encryptedText = messageItem.encryptedText
        
        return message
    }
    
    class func transform(conversationItem:ConversationItem) -> MOKConversation {
        var info = NSMutableDictionary()
        
        if let bytesInfo = conversationItem.info {
            info = try! NSJSONSerialization.JSONObjectWithData(bytesInfo, options: NSJSONReadingOptions.MutableContainers) as! NSMutableDictionary
        }
        
        let conversation = MOKConversation(id: conversationItem.conversationId)
        conversation.members = NSMutableArray(array: conversationItem.members.componentsSeparatedByString(","))
        conversation.lastSeen = conversationItem.lastSeen
        conversation.lastModified = conversationItem.lastModified
        conversation.unread = conversationItem.unread
        conversation.info = info
        
        if let messageItem = conversationItem.lastMessage {
            conversation.lastMessage = DBManager.transform(messageItem)
        }
        
        return conversation
    }
    
    class func getMessage(id:String) -> MOKMessage? {
        let realm = try! Realm()
        
        if let messageItem = realm.objectForPrimaryKey(MessageItem.self, key: id){
            return DBManager.transform(messageItem)
        }
        
        return nil
    }
    
    class func getConversation(id:String) -> MOKConversation? {
        let realm = try! Realm()
        
        if let conversationItem = realm.objectForPrimaryKey(ConversationItem.self, key: id){
            return DBManager.transform(conversationItem)
        }
        
        return nil
    }
    
    class func exists(message:MOKMessage) -> Bool {
        let realm = try! Realm()
        
        let results = realm.objects(MessageItem.self).filter("messageId = \(message.messageId) OR messageId = \(message.oldMessageId)")
        return results.count > 0
    }
    
    class func existsMessage(id:String, oldId:String) -> Bool {
        let realm = try! Realm()
        
        let results = realm.objects(MessageItem).filter("messageId == %@ OR messageId == %@", id, oldId)
        return results.count > 0
    }
    
    class func updateMessage(id:String, oldId:String) {
        let realm = try! Realm()
        guard let message = realm.objectForPrimaryKey(MessageItem.self, key: oldId) else {
            return
        }
        let newMessage = MessageItem()
        newMessage.messageId = id
        newMessage.oldMessageId = oldId
        
        try! realm.write {
            realm.delete(message)
            realm.add(newMessage, update: true)
        }
    }
    class func getMessages(sender:String, recipient:String, from:MOKMessage?, count:Int) -> [MOKMessage]{
        let realm = try! Realm()
        
        let predicate = NSPredicate(format: "((sender == %@ AND recipient == %@) OR (sender == %@ AND recipient == %@)) AND timestampCreated < %f", sender, recipient, recipient, sender, from?.timestampCreated ?? 0)
        let results = realm.objects(MessageItem).filter(predicate).sorted("timestampCreated", ascending: false)
        
        var messages = [MOKMessage]()
        
        for (index, messageItem) in results.enumerate() {
            if count <= index {
                break
            }

            guard let msg = from where msg.messageId != messageItem.messageId && messageItem.timestampCreated < msg.timestampCreated else {
                continue
            }
            
            let message = DBManager.transform(messageItem)
            
            messages.insert(message, atIndex: 0)
        }
        return messages
    }
    
    class func getConversations(from:MOKConversation?, count:Int) -> [MOKConversation] {
        let realm = try! Realm()
        
        var predicate = NSPredicate(format: "lastModified > 0")
        
        if let conv = from {
            predicate = NSPredicate(format: "lastModified < %f", conv.lastModified ?? 0)
        }
        
        let results = realm.objects(ConversationItem).filter(predicate).sorted("lastModified", ascending: true)
        
        var conversations = [MOKConversation]()
        
        for (index, conversationItem) in results.enumerate() {
            if count <= index {
                break
            }
            
            if let conversation = from {
                
                if conversation.conversationId == conversationItem.conversationId && conversationItem.lastModified <= conversation.lastModified {
                    continue
                }
            }
            
            conversations.insert(DBManager.transform(conversationItem), atIndex: 0)
        }
        return conversations
    }
    
    class func getUser() -> MOKUser?{
        return nil
    }
}


extension DBManager {
    class func getUser(id:String) -> MOKUser? {
        return DBManager.getUsers([id]).first
    }
    
    class func getUsers(ids:[String]) -> [MOKUser]{
        let realm = try! Realm()
        
        let results = realm.objects(User.self).filter("monkeyId IN %@", ids)
        
        var arrayUser = [MOKUser]()
        for userdb in results {
            let user = MOKUser(id: userdb.monkeyId)
            user.info = [:]
            
            for simpleInfo:SimpleInfo in userdb.info {
                user.info![simpleInfo.key] = simpleInfo.value
            }
            
            arrayUser.append(user)
        }
        
        return arrayUser
    }
    
    class func storeUsers(users:[MOKUser]){
        let realm = try! Realm()
        
        try! realm.write {
            for user in users {
                let userDB = User()
                userDB.monkeyId = user.monkeyId
                
                let infoList = List<SimpleInfo>()
                for info in user.info! {
                    let simple = SimpleInfo()
                    simple.key = info.key as! String
                    simple.value = info.value as! String
                    infoList.append(simple)
                }
                
                userDB.info = infoList
                realm.add(userDB, update: true)
            }
            
        }
    }
    
    class func monkeyIdsNotStored(ids:Set<String>) -> [String]{
        let realm = try! Realm()
        
        //search among stored users
        let results = realm.objects(User.self).filter("monkeyId IN %@", ids)
        
        //monkey ids found
        if let monkeyIds = results.valueForKey("monkeyId") as? [String] {
            
//            let realIds = Set(ids.allObjects as! [String])
            
            return Array(ids.subtract(monkeyIds))
        }
        
        return []
    }
}