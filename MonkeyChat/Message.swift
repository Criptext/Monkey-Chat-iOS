//
//  Message.swift
//  MonkeyChat
//
//  Created by Gianni Carlo on 8/3/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

import MonkeyKit
import MonkeyKitUI
import RealmSwift

class MessageItem: Object {
    dynamic var messageId = ""
    dynamic var oldMessageId = ""
    dynamic var plainText = ""
    dynamic var encryptedText:String?
    dynamic var timestampCreated = Double()
    dynamic var timestampOrder = Double()
    dynamic var recipient = ""
    dynamic var sender = ""
    dynamic var props:Data?
    dynamic var params:Data?
    
    override static func primaryKey() -> String? {
        return "messageId"
    }
}


extension MOKMessage: JSQMessageData {
    
    public func documentsPath() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/"
    }
    
    public func senderId() -> String! {
        return self.sender
    }
    
    public func text() -> String! {
        return self.plainText
    }
    
    public func maskAsOutgoing(_ flag:Bool) {
        if !self.isMediaMessage() {
            return
        }
        
        let media = self.media()
        
        switch self.mediaType() {
        case MOKPhoto.rawValue:
            (media as! JSQPhotoMediaItem).appliesMediaViewMaskAsOutgoing = flag
            break
        default:
            
            break
        }
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
        
        let media:JSQMessageMediaData!
        switch self.mediaType() {
        case MOKAudio.rawValue:
            if let audio = try? Data(contentsOf: self.fileURL()!){
                media = BLAudioMedia(audio: audio)
                (media as! BLAudioMedia).setFilePath(self.filePath())
                let asset = AVURLAsset(url: self.fileURL()!)
                (media as! BLAudioMedia).setAudioDuration(CMTimeGetSeconds(asset.duration))
            }else{
                media = BLAudioMedia()
            }
            
            break
        case MOKPhoto.rawValue:
            let image = UIImage(contentsOfFile: self.filePath()!)
            media = JSQPhotoMediaItem(image: image)
            break
        default:
            media = JSQPhotoMediaItem()
            break
        }
        
        self.cachedMedia = media
//        photo.appliesMediaViewMaskAsOutgoing = false
        return media
    }
    
    public func reloadMedia(_ data: Data) {
        print("photo!: \(self.documentsPath()+self.plainText)")
        self.cachedMedia = nil
        let media:JSQMessageMediaData!
        switch self.mediaType() {
        case MOKAudio.rawValue:
            print("audio!")
            
            let audio = data
            
            media = BLAudioMedia(audio: audio)
            
            (media as! BLAudioMedia).setFilePath(self.filePath())
            let asset = AVURLAsset(url: self.fileURL()!)
            (media as! BLAudioMedia).setAudioDuration(CMTimeGetSeconds(asset.duration))
            break
        case MOKPhoto.rawValue:
            print("photo!")
            
            media = JSQPhotoMediaItem(image: UIImage(data: data))
            (media.mediaView() as! UIImageView).contentMode = .scaleAspectFill
            
            break
        default:
            media = JSQPhotoMediaItem()
            break
        }
        
        self.cachedMedia = media
    }
    
}
