//
//  Conversation.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import JSQMessagesViewController
import MonkeyKit

/**
 *  The `Conversation` class is a concrete class for a proposed conversation model that represents a chat between members of the conversation
 *  A conversation can be either a one-to-one conversation, or a conversation between multiple members.
 *  For group conversations you can specify a generated unique id, whereas in one-to-one conversations, you can have the recipient's id to be the conversation id.
 *  The same applies for the name of the conversation. For groups you can have a special name, whereas for one-to-one conversations you can just use the recipient's name.
 */

class Conversation: Hashable, Equatable {
    let id: String
    var info: [String:String]
    var members: [String]
    var lastMessage:MOKMessage? {
        didSet {
            if let lastMessage = lastMessage  {
                self.lastModified = lastMessage.timestampCreated
            }
            
        }
    }
    var lastSeen:Double
    var lastModified:Double
    var unread:UInt64
    
    var isGroup: Bool {
        return self.id.containsString("G:")
    }
    
    init(id:String, info:[String:String]?, members: [String], lastMessage:MOKMessage?, lastSeen:Double, lastModified:Double, unread:UInt64) {
        self.id = id
        self.info = info ?? [:]
        self.members = members
        self.lastMessage = lastMessage
        self.lastSeen = lastSeen
        self.lastModified = lastModified
        self.unread = unread
    }
    
    convenience init(id:String, members:[String]){
        self.init(id: id, info:[:],members: members, lastMessage: nil, lastSeen: 0, lastModified: 0, unread: 0)
    }
    
    func getUser(id: String) -> String? {
        return self.members.filter({ $0 == id }).first
    }
    
    func getAvatarURL() -> NSURL {
        let path = self.info["avatar"] ?? "https://monkey.criptext.com/user/icon/default/\(self.id)"
        
        return NSURL(string: path)!
    }
    
    var hashValue: Int {
        get {
            return "\(self.id)".hashValue
        }
    }
}

func ==(lhs: Conversation, rhs: Conversation) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
