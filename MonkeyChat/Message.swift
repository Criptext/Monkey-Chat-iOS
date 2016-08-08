//
//  Message.swift
//  MonkeyChat
//
//  Created by Gianni Carlo on 8/3/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

import MonkeyKit
import JSQMessagesViewController



extension MOKMessage: JSQMessageData {
    
    public func senderId() -> String! {
        return self.sender
    }
    
    public func text() -> String! {
        return self.plainText
    }
    
    public func messageHash() -> UInt {
        return UInt(abs(self.plainText.hash))
    }
    
    public func senderDisplayName() -> String! {
        return "meh"
    }
    
    public func media() -> JSQMessageMediaData! {
        //check if media is cached
        if self.cachedMedia != nil {
            return self.cachedMedia as! JSQMessageMediaData
        }
        
        switch self.mediaType() {
        case MOKPhoto.rawValue:
            
            break
        default:
            
            break
        }
        
        return JSQPhotoMediaItem()
    }
    
}