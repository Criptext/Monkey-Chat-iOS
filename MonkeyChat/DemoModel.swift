//
//  DemoConversation.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import JSQMessagesViewController



// Create Names to display
let DisplayNameSquires = "Jesse Squires"
let DisplayNameLeonard = "Dan Leonard"
let DisplayNameCarlo = "Gianni Carlo"
let DisplayNameCook = "Tim Cook"
let DisplayNameJobs = "Steve Jobs"
let DisplayNameWoz = "Steve Wozniak"
let DisplayNamGroup = "Everyone"

// Create Unique IDs for avatars
let AvatarIDSquires = "053496-4509-289"
let AvatarIDLeonard = "053496-4509-288"
let AvatarIDCarlo = "053496-4509-287"
let AvatarIdCook = "468-768355-23123"
let AvatarIdJobs = "707-8956784-57"
let AvatarIdWoz = "309-41802-93823"
let AvatarIDGroup = "G:1"

// INFO: Creating Static Demo Data. This is only for the example project to show the framework at work.

let cookImage = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "demo_avatar_cook"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
let jobsImage = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "demo_avatar_jobs"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
let wozImage = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "demo_avatar_woz"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
let jsqImage = JSQMessagesAvatarImageFactory.avatarImageWithUserInitials("JSQ", backgroundColor: UIColor(white: 0.85, alpha: 1.0), textColor: UIColor(white: 0.60, alpha: 1.0), font: UIFont.systemFontOfSize(14.0), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
let dlImage = JSQMessagesAvatarImageFactory.avatarImageWithUserInitials("DL", backgroundColor: UIColor(white: 0.85, alpha: 1.0), textColor: UIColor(white: 0.60, alpha: 1.0), font: UIFont.systemFontOfSize(14.0), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
let gcImage = JSQMessagesAvatarImageFactory.avatarImageWithUserInitials("GC", backgroundColor: UIColor(white: 0.85, alpha: 1.0), textColor: UIColor(white: 0.60, alpha: 1.0), font: UIFont.systemFontOfSize(14.0), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))

let squiresUser = User(id: AvatarIDSquires, name: DisplayNameSquires, avatar: jsqImage)
let leonardUser = User(id: AvatarIDLeonard, name: DisplayNameLeonard, avatar: dlImage)
let carloUser = User(id: AvatarIDCarlo, name: DisplayNameCarlo, avatar: gcImage)
let cookUser = User(id: AvatarIdCook, name: DisplayNameCook, avatar: cookImage)
let jobsUser = User(id: AvatarIdJobs, name: DisplayNameJobs, avatar: jobsImage)
let wozUser = User(id: AvatarIdWoz, name: DisplayNameWoz, avatar: wozImage)


let conv1 = Conversation(id: AvatarIDGroup, name: DisplayNamGroup, members: [squiresUser, leonardUser, carloUser, cookUser, jobsUser, wozUser])

let conv2 = Conversation(id: AvatarIDCarlo, name: DisplayNameCarlo, members: [squiresUser, carloUser])

func getConversations()->[Conversation]{
    return [conv1, conv2]
}

//Convenience method
extension Array {
    func randomItem() -> Element? {
        let index = Int(arc4random_uniform(UInt32(self.count)))
        return self[index]
    }
}