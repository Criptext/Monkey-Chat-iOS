//
//  Conversation.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import JSQMessagesViewController


/**
 *  The `Conversation` class is a concrete class for a proposed conversation model that represents a chat between members of the conversation
 *  A conversation can be either a one-to-one conversation, or a conversation between multiple members.
 *  For group conversations you can specify a generated unique id, whereas in one-to-one conversations, you can have the recipient's id to be the conversation id.
 *  The same applies for the name of the conversation. For groups you can have a special name, whereas for one-to-one conversations you can just use the recipient's name.
 */

class Conversation {
    let id: String
    let name: String
    let members: [User]
    var messages: [JSQMessage]
    
    var isGroup: Bool {
        return self.members.count > 2
    }
    
    init(id:String, name:String, members: [User]) {
        
        self.id = id
        self.name = name
        self.members = members
        
        guard let firstUser = members.first else{
            self.messages = []
            return
        }
        
        /**
         *  Load fake messages into conversation
         */
        
        self.messages = [
            JSQMessage(senderId: firstUser.id, senderDisplayName: firstUser.name, date: NSDate.distantPast(), text: "Welcome to JSQMessages: A messaging UI framework for iOS."),
            JSQMessage(senderId: firstUser.id, senderDisplayName: firstUser.name, date: NSDate.distantPast(), text: "It is simple, elegant, and easy to use. There are super sweet default settings, but you can customize like crazy."),
            JSQMessage(senderId: firstUser.id, senderDisplayName: firstUser.name, date: NSDate.distantPast(), text: "It even has data detectors. You can call me tonight. My cell number is 123-456-7890. My website is www.hexedbits.com."),
            JSQMessage(senderId: firstUser.id, senderDisplayName: firstUser.name, date: NSDate.distantPast(), text: "JSQMessagesViewController is nearly an exact replica of the iOS Messages App. And perhaps, better."),
            JSQMessage(senderId: firstUser.id, senderDisplayName: firstUser.name, date: NSDate.distantPast(), text: "It is unit-tested, free, open-source, and documented."),
            JSQMessage(senderId: firstUser.id, senderDisplayName: firstUser.name, date: NSDate.distantPast(), text: "Now with media messages!")
        ]
        
        /**
         *  Have everyone say Hi!
         */
        for user in self.members {
            self.messages.append(JSQMessage(senderId: user.id, senderDisplayName: user.name, date: NSDate.distantPast(), text: "Hi!"))
        }
    }
    
    func getUser(id: String) -> User? {
        return self.members.filter({ $0.id == id }).first
    }
}
