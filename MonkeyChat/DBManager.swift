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
    class func store(_ message:MOKMessage) {
        
        let messageItem = DBManager.transform(message)
        
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(messageItem, update: true)
        }
    }
    
    class func store(_ conversation:MOKConversation) {
        let conversationItem = DBManager.transform(conversation)
        
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(conversationItem, update: true)
        }
    }
    
    class func transform(_ message:MOKMessage) -> MessageItem {
        let messageItem = MessageItem()
        messageItem.messageId = message.messageId
        messageItem.oldMessageId = message.oldMessageId!
        messageItem.sender = message.sender
        messageItem.recipient = message.recipient
        messageItem.timestampOrder = message.timestampOrder
        messageItem.timestampCreated = message.timestampCreated
        messageItem.plainText = message.plainText
        messageItem.encryptedText = message.encryptedText
        if let params = message.params {
            messageItem.params = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
        }
        messageItem.props = try? JSONSerialization.data(withJSONObject: message.props, options: .prettyPrinted)
        
        return messageItem
    }
    
    class func transform(_ conversation:MOKConversation) -> ConversationItem {
        let conversationItem = ConversationItem()
        conversationItem.conversationId = conversation.conversationId
      conversationItem.info = try? JSONSerialization.data(withJSONObject: conversation.info, options: .prettyPrinted)
        conversationItem.members = conversation.members.componentsJoined(by: ",")
        
        if let lastMessage = conversation.lastMessage {
            conversationItem.lastMessage = DBManager.transform(lastMessage)
        }
        
        conversationItem.lastModified = conversation.lastModified
        conversationItem.lastSeen = conversation.lastSeen
        conversationItem.unread = Int32(conversation.unread)
        
        return conversationItem
    }
    
    class func transform(_ messageItem:MessageItem) -> MOKMessage {
      var props = [AnyHashable: Any]()
      var params: NSMutableDictionary?
      
        if let bytesParams = messageItem.params {
          params = (try? JSONSerialization.jsonObject(with: bytesParams, options: .mutableContainers)) as? NSMutableDictionary
        }
        if let bytesProps = messageItem.props {
          props = try! JSONSerialization.jsonObject(with: bytesProps, options: .mutableContainers) as! [AnyHashable: Any]
        }
        let message = MOKMessage(textMessage: messageItem.plainText, sender: messageItem.sender, recipient: messageItem.recipient)
        message.params = params
//        message.setPr
//        let message = MOKMessage(message: messageItem.plainText, sender: messageItem.sender, recipient: messageItem.recipient, params: params, props: props)
        message.messageId = messageItem.messageId
        message.oldMessageId = messageItem.oldMessageId
        message.timestampOrder = messageItem.timestampOrder
        message.timestampCreated = messageItem.timestampCreated
        message.encryptedText = messageItem.encryptedText
        
        return message
    }
    
    class func transform(_ conversationItem:ConversationItem) -> MOKConversation {
        var info = NSMutableDictionary()
        
        if let bytesInfo = conversationItem.info {
          info = try! JSONSerialization.jsonObject(with: bytesInfo, options: .mutableContainers) as! NSMutableDictionary
        }
        
        let conversation = MOKConversation(id: conversationItem.conversationId)
        conversation.members = NSMutableArray(array: conversationItem.members.components(separatedBy: ","))
        conversation.lastSeen = conversationItem.lastSeen
        conversation.lastModified = conversationItem.lastModified
        conversation.unread = uint(conversationItem.unread)
        conversation.info = info
        
        if let messageItem = conversationItem.lastMessage {
            conversation.lastMessage = DBManager.transform(messageItem)
        }
        
        return conversation
    }
  
    class func getMessage(_ id:String) -> MOKMessage? {
        let realm = try! Realm()
        
        if let messageItem = realm.object(ofType: MessageItem.self, forPrimaryKey: id) {
            return DBManager.transform(messageItem)
        }
        
        return nil
    }
    
    class func getConversation(_ id:String) -> MOKConversation? {
        let realm = try! Realm()
        
      if let conversationItem = realm.object(ofType: ConversationItem.self, forPrimaryKey: id){
            return DBManager.transform(conversationItem)
        }
        
        return nil
    }
    
    class func exists(_ message:MOKMessage) -> Bool {
        let realm = try! Realm()
        
        let results = realm.objects(MessageItem.self).filter("messageId = \(message.messageId) OR messageId = \(message.oldMessageId)")
        return results.count > 0
    }
    
    class func existsMessage(_ id:String, oldId:String) -> Bool {
        let realm = try! Realm()
        
        let results = realm.objects(MessageItem.self).filter("messageId == %@ OR messageId == %@", id, oldId)
        return results.count > 0
    }
    
    class func updateMessage(_ id:String, oldId:String) {
        let realm = try! Realm()
      guard let message = realm.object(ofType: MessageItem.self, forPrimaryKey: oldId) else {
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
    class func getMessages(_ sender:String, recipient:String, from:MOKMessage?, count:Int) -> [MOKMessage]{
        let realm = try! Realm()
        
        let predicate = NSPredicate(format: "((sender == %@ AND recipient == %@) OR (sender == %@ AND recipient == %@)) AND timestampCreated < %f", sender, recipient, recipient, sender, from?.timestampCreated ?? 0)
        let results = realm.objects(MessageItem.self).filter(predicate).sorted(byProperty: "timestampCreated", ascending: false)
        
        var messages = [MOKMessage]()
        
        for (index, messageItem) in results.enumerated() {
            if count <= index {
                break
            }

            guard let msg = from , msg.messageId != messageItem.messageId && messageItem.timestampCreated < msg.timestampCreated else {
                continue
            }
            
            let message = DBManager.transform(messageItem)
            
            messages.insert(message, at: 0)
        }
        return messages
    }
    
    class func getConversations(_ from:MOKConversation?, count:Int) -> [MOKConversation] {
        let realm = try! Realm()
        
        var predicate = NSPredicate(format: "lastModified > 0")
        
        if let conv = from {
            predicate = NSPredicate(format: "lastModified < %f", conv.lastModified)
        }
        
        let results = realm.objects(ConversationItem.self).filter(predicate).sorted(byProperty: "lastModified", ascending: true)
        
        var conversations = [MOKConversation]()
        
        for (index, conversationItem) in results.enumerated() {
            if count <= index {
                break
            }
            
            if let conversation = from {
                
                if conversation.conversationId == conversationItem.conversationId && conversationItem.lastModified <= conversation.lastModified {
                    continue
                }
            }
            
            conversations.insert(DBManager.transform(conversationItem), at: 0)
        }
        return conversations
    }
    
    class func getUser() -> MOKUser?{
        return nil
    }
}


extension DBManager {
    class func getUser(_ id:String) -> MOKUser? {
        return DBManager.getUsers([id]).first
    }
    
    class func getUsers(_ ids:[String]) -> [MOKUser]{
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
    
    class func storeUsers(_ users:[MOKUser]){
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
    
    class func monkeyIdsNotStored(_ ids:Set<String>) -> [String]{
        let realm = try! Realm()
        
        //search among stored users
        let results = realm.objects(User.self).filter("monkeyId IN %@", ids)
        
        //monkey ids found
        if let monkeyIds = results.value(forKey: "monkeyId") as? [String] {
            
//            let realIds = Set(ids.allObjects as! [String])
            
            return Array(ids.subtracting(monkeyIds))
        }
        
        return []
    }
}
