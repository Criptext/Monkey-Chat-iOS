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
    class func getConversations() -> [MOKConversation]{
        return []
    }
    class func store(message:MOKMessage) {
        let messageItem = MessageItem()
        messageItem.messageId = message.messageId
        messageItem.oldMessageId = message.oldMessageId!
        
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(messageItem, update: true)
        }
    }
    class func getMessage(id:String) -> MessageItem? {
        let realm = try! Realm()
        
        return realm.objectForPrimaryKey(MessageItem.self, key: id)
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
    class func getMessages() -> [MOKMessage]{
        return []
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