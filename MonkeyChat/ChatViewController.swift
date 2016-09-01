
//  ChatViewController.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import MonkeyKit
import Whisper
import RealmSwift
import QuickLook
import Photos

/**
 *  Override point for customization.
 *
 *  Customize your view.
 *  Look at the properties on `JSQMessagesViewController` and `JSQMessagesCollectionView` to see what is possible.
 *
 *  Customize your layout.
 *  Look at the properties on `JSQMessagesCollectionViewFlowLayout` to see what is possible.
 */

class ChatViewController: JSQMessagesViewController, JSQMessagesComposerTextViewPasteDelegate {
    
    let maxSize = 8500
    
    var conversation: MOKConversation!
    var messageHash = [String:MOKMessage]()
    var messageArray = [MOKMessage]()
    
    //messageId : AFHTTPRequestOperation
    var downloadOperations = [String:AnyObject]()
    
    //flags for requesting messages
    var isGettingMessages = false
    var shouldRequestMessages = true
    
    //identifier for header of collection view
    var headerViewIdentifier = JSQMessagesActivityIndicatorHeaderView.headerReuseIdentifier()
    
    var members = [String:MOKUser]()
    
    var outgoingBubbleImageData: JSQMessagesBubbleImage!
    var incomingBubbleImageData: JSQMessagesBubbleImage!
    
    let readDove = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "check-blue-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
    let sentDove = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "check-grey-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
    
    //file destination folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! + "/"
    
    //preview item
    var previewItem:PreviewItem!
    
    //recorder
    var recorder:AVAudioRecorder?
    
    //timer
    let timerLabel = UILabel()
    var timerRecording:NSTimer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //
        self.timerLabel.text = "00:00"
        self.timerLabel.hidden = true
        self.inputToolbar.contentView.addSubview(self.timerLabel)
        self.timerLabel.frame = CGRectMake(30, 0, self.inputToolbar.contentView.frame.size.width, self.inputToolbar.contentView.frame.size.height)
        self.inputToolbar.contentView.bringSubviewToFront(self.timerLabel)
        
        /**
         *	Register monkey listeners
         */
        //register listener for incoming messages
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.messageReceived(_:)), name: MonkeyMessageNotification, object: nil)
        
        //register listener for message acknowledges
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.acknowledgeReceived(_:)), name: MonkeyAcknowledgeNotification, object: nil)
        
        //Start by opening the conversation in Monkey
        Monkey.sharedInstance().openConversation(self.conversation.conversationId)
        
        self.title = self.conversation.info.objectForKey("name") as? String
        
        //set your cell identifiers
        self.outgoingCellIdentifier = JSQMessagesCollectionViewCellOutgoing2.cellReuseIdentifier()
        self.outgoingMediaCellIdentifier = JSQMessagesCollectionViewCellOutgoing2.mediaCellReuseIdentifier()
        
        self.collectionView.registerNib(JSQMessagesCollectionViewCellOutgoing2.nib(), forCellWithReuseIdentifier: self.outgoingCellIdentifier)
        self.collectionView.registerNib(JSQMessagesCollectionViewCellOutgoing2.nib(), forCellWithReuseIdentifier: self.outgoingMediaCellIdentifier)
        
        self.incomingCellIdentifier = JSQMessagesCollectionViewCellIncoming2.cellReuseIdentifier()
        self.incomingMediaCellIdentifier = JSQMessagesCollectionViewCellIncoming2.mediaCellReuseIdentifier()
        
        self.collectionView.registerNib(JSQMessagesCollectionViewCellIncoming2.nib(), forCellWithReuseIdentifier: self.incomingCellIdentifier)
        self.collectionView.registerNib(JSQMessagesCollectionViewCellIncoming2.nib(), forCellWithReuseIdentifier: self.incomingMediaCellIdentifier)
        
        
        /**
         *  You MUST set your senderId and display name
         */
        self.senderId = Monkey.sharedInstance().session["monkeyId"] as! String
        self.senderDisplayName = ((Monkey.sharedInstance().session["user"] as! [String:AnyObject])["name"] as? String) ?? "Unknown"
        
        self.inputToolbar.contentView.textView.pasteDelegate = self
        
        /**
         *  You can set custom avatar sizes
         */
        self.collectionView.collectionViewLayout.incomingAvatarViewSize = .zero
        self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeMake(12, 9.5);
        
        self.showLoadEarlierMessagesHeader = true;
        
        /**
         *  Register custom header view
         */
        self.collectionView.registerNib(JSQMessagesActivityIndicatorHeaderView.nib(), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: JSQMessagesActivityIndicatorHeaderView.headerReuseIdentifier())
        
        /**
         *  Register custom menu actions for cells.
         */
        JSQMessagesCollectionViewCell.registerMenuAction(#selector(customAction))
        
        /**
         *  OPT-IN: allow cells to be deleted
         */
        JSQMessagesCollectionViewCell.registerMenuAction(#selector(delete(_:)))
        
        /**
         *  Customize your toolbar buttons
         *
         *  self.inputToolbar.contentView.leftBarButtonItem = custom button or nil to remove
         *  self.inputToolbar.contentView.rightBarButtonItem = custom button or nil to remove
         */
        
        
        /**
         *  Set a maximum height for the input toolbar
         *
         *  self.inputToolbar.maximumHeight = 150.0
         */
        
        /**
         *  Enable/disable springy bubbles, default is NO.
         *  You must set this from `viewDidAppear:`
         *  Note: this feature is mostly stable, but still experimental
         *
         *  self.collectionView.collectionViewLayout.springinessEnabled = true
         */
        
        /**
         *  Create message bubble images objects.
         *
         *  Be sure to create your bubble images one time and reuse them for good performance.
         *
         */
        
        let bubbleFactory = JSQMessagesBubbleImageFactory(bubbleImage: UIImage.jsq_bubbleCompactTaillessImage(), capInsets: UIEdgeInsetsZero)
        
        self.outgoingBubbleImageData = bubbleFactory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
        self.incomingBubbleImageData = bubbleFactory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
        
        /**
         *	Load messages for this conversation
         */
        
        self.messageArray = DBManager.getMessages()
        guard let lastMessage = self.conversation.lastMessage else {
            return
        }
        
        self.messageArray.append(lastMessage)
        self.collectionView.reloadData()
    }
    
    //MARK: Custom menu actions for cells
    
    override func didReceiveMenuWillShowNotification(notification: NSNotification!) {
        /**
         *  Display custom menu actions for cells.
         */
        let menu = notification.object as! UIMenuController
        
        menu.menuItems = [UIMenuItem(title: "Custom Action", action: #selector(self.customAction(_:)))]
    }
    
}

//MARK: - Monkey Listeners
extension ChatViewController {
    
    func messageReceived(notification:NSNotification){
        
        
        guard let userInfo = notification.userInfo, message = userInfo["message"] as? MOKMessage else{
            return
        }
        //check that the message is for this conversation
        if message.conversationId(Monkey.sharedInstance().monkeyId()) != self.conversation.conversationId {
            
            let view = UIImageView()
            view.sd_setImageWithURL(conversation?.getAvatarURL())
            
            var title = "Notification"
            
            if let user = DBManager.getUser(message.sender) {
                title = (user.info!["name"] ?? "Notification") as! String
                view.sd_setImageWithURL(user.getAvatarURL())
            }
            
            let announcement = Announcement(title: title, subtitle: (notification.userInfo!["message"] as! MOKMessage).plainText, image: view.image, duration: 2.0, action: {
                print("finish presenting!")
            })
            
            show(shout: announcement, to: self.navigationController!)
            
            return
        }
        
        conversation!.lastMessage = message
        
        self.messageHash[message.messageId] = message
        self.messageArray.append(message)
        
        self.finishReceivingMessage()
    }
    
    func acknowledgeReceived(notification:NSNotification){
        
        guard let acknowledge = notification.userInfo else {
            return
        }
        
        //update last message if necessary
        guard let oldId = acknowledge["oldId"] as? String,
            let newId = acknowledge["newId"] as? String,
            let message = self.messageHash[oldId]
            where message.messageId == oldId || message.messageId == newId else {
                //nothing to do
                return
        }
        
        message.messageId = newId
        message.oldMessageId = oldId
        
        self.collectionView.reloadData()
    }
    
    // MARK: Messaging stuff
    func loadMessages(animated:Bool) {
        guard let firstMessage = self.messageArray.first where self.shouldRequestMessages && !self.isGettingMessages else{
            return
        }
        
        self.isGettingMessages = true
        Monkey.sharedInstance().getConversationMessages(self.conversation.conversationId, since: Int(firstMessage.timestampCreated), quantity: 10, success: { (messages) in
            
            if messages.count == 0 {
                self.shouldRequestMessages = false
            }
            
            for message in messages {
                self.messageHash[message.messageId] = message
                DBManager.store(message)
            }
            
            self.messageArray = messages + self.messageArray
            
            
            
            let oldOffset = self.collectionView.contentOffset
            
            self.collectionView.reloadData()
            
            if animated {
                self.scrollToBottomAnimated(true)
                return
            }
            
            let newIndex = self.messageArray.indexOf(firstMessage)!
            self.collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: newIndex, inSection: 0), atScrollPosition: .Top, animated: false)
            
            let newoffset = CGPointMake(0, self.collectionView.contentOffset.y + oldOffset.y)
            
            self.collectionView.setContentOffset(newoffset, animated: false)
            
            self.isGettingMessages = false
            }, failure: { (task, error) in
                print(error.localizedDescription)
                self.isGettingMessages = false
                self.collectionView.reloadData()
        })
    }
}

// MARK: - PreviewController Delegate
extension ChatViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    func numberOfPreviewItemsInPreviewController(controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(controller: QLPreviewController, previewItemAtIndex index: Int) -> QLPreviewItem {
        return self.previewItem
    }
}

// MARK: - Input Delegate
extension ChatViewController {
    override func messagesInputToolbar(toolbar: JSQMessagesInputToolbar!, didOpenOptionButton sender: KSMManyOptionsButton!) {
        if sender.currentManyOptionsButtonState != KSMManyOptionsButtonState.Closed {
            self.inputToolbar.contentView.textView.hidden = true
            self.inputToolbar.contentView.leftBarButtonItem.hidden = true
            self.timerLabel.hidden = false
            self.startRecording()
        }
    }
    
    override func messagesInputToolbar(toolbar: JSQMessagesInputToolbar!, didSelectOptionButton location: KSMManyOptionsButtonLocation) {
        switch location {
        case KSMManyOptionsButtonLocation.Top:
            print("top")
            break
        case KSMManyOptionsButtonLocation.Right:
            print("right")
            break
        case KSMManyOptionsButtonLocation.Bottom:
            print("bottom")
            break
        case KSMManyOptionsButtonLocation.Left:
            print("left")
            self.stopRecording(send:false)
            break
        case KSMManyOptionsButtonLocation.None:
            print("none")
            self.stopRecording(send:true)
            break
        }
    }
    
    override func messagesInputToolbar(toolbar: JSQMessagesInputToolbar!, didBeginClosingOptionButton sender: KSMManyOptionsButton!) {
        self.timerLabel.hidden = true
        self.inputToolbar.contentView.textView.hidden = false
        self.inputToolbar.contentView.leftBarButtonItem.hidden = false
    }
}

// MARK: - Audio delegate
extension ChatViewController {
    func startRecording(){
    
        AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
            dispatch_async(dispatch_get_main_queue(), { 
                if !granted {
                    let alertcontroller = UIAlertController(title: nil, message: "Maduro", preferredStyle: .Alert)
                    alertcontroller.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) in
                        UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
                    }))
                    alertcontroller.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
                    
                    alertcontroller.popoverPresentationController?.sourceView = self.view
                    alertcontroller.popoverPresentationController?.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height-45, 1.0, 1.0)
                    self.presentViewController(alertcontroller, animated: true, completion: nil)
                    return
                }
                
                UIApplication.sharedApplication().statusBarHidden = true
                
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
                
                let filename = "audio\(UInt64(NSDate().timeIntervalSince1970)).aac"
                let dirpath = self.documentsPath + filename

                try! self.recorder = AVAudioRecorder(URL: NSURL(string: dirpath)!,
                    settings: [
                        AVFormatIDKey: NSNumber(unsignedInt: kAudioFormatMPEG4AAC),
                        AVSampleRateKey: NSNumber(float: 1200),
                        AVNumberOfChannelsKey: NSNumber(int: 1),
                        AVEncoderAudioQualityKey: NSNumber(integer: AVAudioQuality.Min.rawValue)
                    ])
                
                self.recorder!.record()
                
                if self.timerRecording != nil {
                    self.timerRecording.invalidate()
                }
                
                if self.timerRecording == nil || (self.timerRecording != nil && !self.timerRecording.valid) {
                    self.timerRecording = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(self.updateTimer), userInfo: nil, repeats: true)
                    NSRunLoop.mainRunLoop().addTimer(self.timerRecording, forMode: NSRunLoopCommonModes)
                }
                
                UIApplication.sharedApplication().statusBarHidden = false
            })
        }
    }
    
    func updateTimer() {
        guard let recorder = self.recorder else {
            return
        }
        let minutes = Int((recorder.currentTime % 3600) / 60)
        let secs = Int((recorder.currentTime % 3600) % 60)
        
        
        self.timerLabel.text = String(format: "%02d:%02d", minutes, secs)
    }
    
    func stopRecording(send flag:Bool) {
        
        guard let recorder = self.recorder where recorder.recording else {
            return
        }

        recorder.stop()
        
        if !flag {
            return
        }
        
        let audioAsset = AVURLAsset(URL: NSURL(fileURLWithPath: recorder.url.path!))
        let duration = audioAsset.duration
        let seconds = CMTimeGetSeconds(duration)
        if seconds > 0.7 {
            guard let data = NSData(contentsOfFile: recorder.url.path!) else {
                return
            }
            
//            let push = Monkey.sharedInstance()
            let message = Monkey.sharedInstance().sendFile(data, type: MOKAudio, filename: recorder.url.lastPathComponent!, encrypted: true, compressed: true, to: self.conversation.conversationId, params: ["length":Int(seconds)], push: "You received an audio", success: { (message) in
                
                //refresh collectionView?
                
            }) { (task, error) in
                //mark message as failed
                
            }
            
            DBManager.store(message)
            self.messageHash[message.messageId] = message
            self.messageArray.append(message)
            self.conversation.lastMessage = message
            self.finishSendingMessage()
        }
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        try! AVAudioSession.sharedInstance().setActive(false, withOptions: AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
    }

}

// MARK: - Image delegate
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        print("image!")
        
        let filename = "photo\(UInt64(NSDate().timeIntervalSince1970)).png"
        let dirpath = self.documentsPath + filename
        
        guard let representation = UIImageJPEGRepresentation(image, 0.6) else {
            return
        }
        
        let data = NSData.init(data: representation)
        data.writeToFile(dirpath, atomically: true)
        
        self.dismissViewControllerAnimated(true, completion: nil)
        
//        let message = MOKMessage(fileMessage: dirpath, type: MOKPhoto, sender: self.senderId, recipient: self.conversation.conversationId)
        
        let message = Monkey.sharedInstance().sendFile(data, type: MOKPhoto, filename: filename, encrypted: true, compressed: true, to: self.conversation.conversationId, params: nil, push: nil, success: { (message) in
            
            //refresh collectionView?
            
            }) { (task, error) in
                //mark message as failed
                
        }
        
        DBManager.store(message)
        self.messageHash[message.messageId] = message
        self.messageArray.append(message)
        self.conversation.lastMessage = message
        self.finishSendingMessage()
        
        
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        print("cancel!")
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension ChatViewController {

    func send(text:String, size:Int) {
        
        guard !text.isEmpty else {
            return
        }
        
        var wordArray = text.componentsSeparatedByString(" ").filter({ !$0.isEmpty })
        var textCopy = wordArray.removeFirst()
        
        while(!wordArray.isEmpty && textCopy.characters.count < size){
            textCopy += " \(wordArray.removeFirst())"
        }
        
        let message = Monkey.sharedInstance().sendText(textCopy, to: self.conversation.conversationId, params: nil, push: "You received a text")
        
        DBManager.store(message)
        self.messageArray.append(message)
        self.messageHash[message.messageId] = message
        self.conversation.lastMessage = message
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        self.finishSendingMessageAnimated(true)
        
        let remainingText = wordArray.joinWithSeparator(" ")
        self.send(remainingText, size: size)
        
    }
    
    // MARK: - JSQMessagesViewController method overrides
    override func didPressSendButton(button: UIButton?, withMessageText text: String?, senderId: String?, senderDisplayName: String?, date: NSDate?) {
        /**
         *  Sending a message. Your implementation of this method should do *at least* the following:
         *
         *  1. Play sound (optional)
         *  2. Add new id<JSQMessageData> object to your data source
         *  3. Call `finishSendingMessage`
         */
        
        self.send(text ?? "", size: self.maxSize)
    }
    
    override func didPressAccessoryButton(sender: UIButton!) {
        self.inputToolbar.contentView.textView.resignFirstResponder()
        
        let sheet = UIAlertController(title: "Media messages", message: nil, preferredStyle: .ActionSheet)
        
        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            sheet.addAction(
                UIAlertAction(title: "Take Picture", style: .Default) { (action) in
                    
                    AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted) in
                        dispatch_async(dispatch_get_main_queue(), {
                            if !granted {
                                let alertcontroller = UIAlertController(title: nil, message: "Maduro", preferredStyle: .Alert)
                                alertcontroller.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) in
                                    UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
                                }))
                                alertcontroller.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
                                
                                alertcontroller.popoverPresentationController?.sourceView = self.view
                                alertcontroller.popoverPresentationController?.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height-45, 1.0, 1.0)
                                self.presentViewController(alertcontroller, animated: true, completion: nil)
                                return
                            }
                            
                            let picker = UIImagePickerController()
                            picker.delegate = self
                            picker.sourceType = .Camera
                            
                            self.presentViewController(picker, animated: true, completion: nil)
                        })
                    })
            })
        }
        
        let photoButton = UIAlertAction(title: "Choose existing picture", style: .Default) { (action) in
            
            PHPhotoLibrary.requestAuthorization({ (status) in
                dispatch_async(dispatch_get_main_queue(), { 
                    switch status {
                    case .Authorized:
                        let picker = UIImagePickerController()
                        picker.delegate = self
                        picker.sourceType = .PhotoLibrary
                        
                        self.presentViewController(picker, animated: true, completion: nil)
                        break
                    case .Denied, .Restricted:
                        fallthrough
                    default:
                        let alertcontroller = UIAlertController(title: nil, message: "Maduro", preferredStyle: .Alert)
                        alertcontroller.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) in
                            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
                        }))
                        alertcontroller.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
                        
                        alertcontroller.popoverPresentationController?.sourceView = self.view
                        alertcontroller.popoverPresentationController?.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height-45, 1.0, 1.0)
                        self.presentViewController(alertcontroller, animated: true, completion: nil)
                        break
                    }
                })
            })
//            let photoItem = JSQPhotoMediaItem(image: UIImage(named: "goldengate"))
//            let photoMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: photoItem)
//            
//            self.messageArray.append(photoMessage)
//            
//            JSQSystemSoundPlayer.jsq_playMessageSentSound()
//            self.finishSendingMessageAnimated(true)
        }
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        
        sheet.addAction(photoButton)
        sheet.addAction(cancelButton)
        
        self.presentViewController(sheet, animated: true, completion: nil)
    }
    
    // MARK: JSQMessages CollectionView DataSource
    override func collectionView(collectionView: JSQMessagesCollectionView?, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData? {
        let message = self.messageArray[indexPath.item]
        return message
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didDeleteMessageAtIndexPath indexPath: NSIndexPath!) {
        self.messageArray.removeAtIndex(indexPath.item)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource? {
        /**
         *  You may return nil here if you do not want bubbles.
         *  In this case, you should set the background color of your collection view cell's textView.
         *
         *  Otherwise, return your previously created bubble image data objects.
         */
        
        let message = self.messageArray[indexPath.item]
        
        
        if message.senderId() == self.senderId {
            return self.outgoingBubbleImageData
        }
        
        return self.incomingBubbleImageData;
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource? {
        /**
         *  Return `nil` here if you do not want avatars.
         *  If you do return `nil`, be sure to do the following in `viewDidLoad`:
         *
         *  self.collectionView.collectionViewLayout.incomingAvatarViewSize = .zero;
         *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize = .zero;
         *
         *  It is possible to have only outgoing avatars or only incoming avatars, too.
         */
        
        /**
         *  Return your previously created avatar image data objects.
         *
         *  Note: these the avatars will be sized according to these values:
         *
         *  self.collectionView.collectionViewLayout.incomingAvatarViewSize
         *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize
         *
         *  Override the defaults in `viewDidLoad`
         */
        
        let message = self.messageArray[indexPath.item]
        
        //don't show if it's an incoming message
        if message.sender != self.senderId {
            return nil
        }
        
        if message.wasSent() {
            return self.sentDove
        }
        
        
        return nil
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        return nil
    }
    
    override func collectionView(collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, atIndexPath indexPath: NSIndexPath) {
            self.loadMessages(false)
    }
    
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: self.headerViewIdentifier, forIndexPath: indexPath)
        
        //only show if it will request messages afterwards
        header.hidden = !self.shouldRequestMessages
        
        return header
    }
    
    // MARK: UICollectionView DataSource
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.messageArray.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        /**
         *  Override point for customizing cells
         */
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath) as! JSQMessagesCollectionViewCell
        
        /**
         *  Configure almost *anything* on the cell
         *
         *  Text colors, label text, label colors, etc.
         *
         *
         *  DO NOT set `cell.textView.font` !
         *  Instead, you need to set `self.collectionView.collectionViewLayout.messageBubbleFont` to the font you want in `viewDidLoad`
         *
         *
         *  DO NOT manipulate cell layout information!
         *  Instead, override the properties you want on `self.collectionView.collectionViewLayout` from `viewDidLoad`
         */
        
        let message = self.messageArray[indexPath.item]
        
        var isOutgoing = true
        
        if message.sender != self.senderId {
            isOutgoing = false
        }
        
        if !message.isMediaMessage() {
            
            if isOutgoing {
                cell.textView.textColor = UIColor.whiteColor()
            } else {
                cell.textView.textColor = UIColor.blackColor()
            }
            
            let attributes : [String:AnyObject] = [NSForegroundColorAttributeName:cell.textView.textColor!, NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue]
            cell.textView.linkTextAttributes = attributes
            
            return cell
        }
        
        //media stuff
        message.maskAsOutgoing(isOutgoing)
        
        let media = message.media()
        
        if media.needsDownload!() {
            print("Download!!!")
            self.downloadFile(message)
        }
        
        return cell
    }
    
    func downloadFile(message:MOKMessage) {
        Monkey.sharedInstance().downloadFileMessage(message, fileDestination: self.documentsPath, success: { (data) in
            //reload collection
            message.reloadMedia(data)
            self.collectionView.reloadData()
            
            }) { (task, error) in
                //if file download is on progress do nothing
                if error.code == -60 {
                    return
                }
                
                //set fail status to message and reload collection
                
        }
    }
    
    
    // MARK: - UICollectionView Delegate
    
    // MARK: Custom menu items
    
    override func collectionView(collectionView: UICollectionView, canPerformAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        if action == #selector(customAction) {
            return true
        }
        
        return super.collectionView(collectionView, canPerformAction: action, forItemAtIndexPath: indexPath, withSender: sender)
    }
    
    override func collectionView(collectionView: UICollectionView, performAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
        if action == Selector() {
            self.customAction(sender!)
            return
        }
        super.collectionView(collectionView, performAction: action, forItemAtIndexPath: indexPath, withSender: sender)
    }
    
    func customAction(sender: AnyObject) {
        print("Custom action received! Sender: \(sender)")
    }
    
    // MARK: JSQMessages collection view flow layout delegate
    // MARK: Adjusting cell label heights
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        /**
         *  Each label in a cell has a `height` delegate method that corresponds to its text dataSource method
         */
        
        /**
         *  This logic should be consistent with what you return from `attributedTextForCellTopLabelAtIndexPath:`
         *  The other label height delegate methods should follow similarly
         *
         *  Show a timestamp for every 3rd message
         */
        
        if indexPath.item == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        
        let currentMessage = self.messageArray[indexPath.item]
        let previousMessage = self.messageArray[indexPath.item - 1]
        
        if (currentMessage.timestampCreated - previousMessage.timestampCreated) > 7200 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        
        return 0.0
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        /**
         *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
         *  The other label text delegate methods should follow a similar pattern.
         *
         *  Show a timestamp for every 3rd message
         */
        let currentMessage = self.messageArray[indexPath.item]
        
        if indexPath.item == 0 {
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(currentMessage.date())
        }
        
        let previousMessage = self.messageArray[indexPath.item - 1]
        
        if (currentMessage.timestampCreated - previousMessage.timestampCreated) > 7200 {
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(currentMessage.date())
        }
        
        return nil;
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout?, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        /**
         *  iOS7-style sender name labels
         */
        
        if !self.conversation.isGroup() {
            return 0.0
        }
        
        let currentMessage = self.messageArray[indexPath.item]
        if currentMessage.senderId() == self.senderId {
            return 0.0
        }
        
        if indexPath.item > 0 {
            let previousMessage = self.messageArray[indexPath.item - 1]
            if previousMessage.senderId() == currentMessage.senderId() {
                return 0.0
            }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        let currentMessage = self.messageArray[indexPath.item]
        
        /**
         *  iOS7-style sender name labels
         */
        if currentMessage.senderId() == self.senderId {
            return nil
        }
        
        if indexPath.item > 0 {
            let previousMessage = self.messageArray[indexPath.item - 1]
            if previousMessage.senderId() == currentMessage.senderId() {
                return nil
            }
        }
        
        if self.conversation.isGroup() {
            let user = self.members[currentMessage.sender]
            return NSAttributedString(string: (user?.info!["name"] ?? "Unknown") as! String)
        }
        
        /**
         *  Don't specify attributes to use the defaults.
         */
        //        return NSAttributedString(string: message.senderDisplayName)
        return nil
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        return 0.0
    }
    
    // MARK: Responding to collection view tap events
    override func collectionView(collectionView: JSQMessagesCollectionView!, header headerView: JSQMessagesLoadEarlierHeaderView!, didTapLoadEarlierMessagesButton sender: UIButton!) {
        print("Load earlier messages!")
        self.loadMessages(false)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapAvatarImageView avatarImageView: UIImageView!, atIndexPath indexPath: NSIndexPath!) {
        print("Tapped avatar!")
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAtIndexPath indexPath: NSIndexPath!) {
        print("Tapped message bubble!")
        
        let message = self.messageArray[indexPath.item]
        
        if !message.isMediaMessage() {
            return
        }
        
        print(message.fileURL())
        self.previewItem = PreviewItem(title: "", url: message.fileURL()!)
        
        let vc = QLPreviewController()
        vc.currentPreviewItemIndex = 0
        vc.dataSource = self
        vc.reloadData()
        
        self.presentViewController(vc, animated: true, completion: nil)
        
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapCellAtIndexPath indexPath: NSIndexPath!, touchLocation: CGPoint) {
        print("Tapped cell at \(touchLocation)")
    }
    
    // MARK: JSQMessagesComposerTextViewPasteDelegate methods
    func composerTextView(textView: JSQMessagesComposerTextView!, shouldPasteWithSender sender: AnyObject!) -> Bool {
        if (UIPasteboard.generalPasteboard().image != nil) {
            // If there's an image in the pasteboard, construct a media item with that image and `send` it.
            
//            let item = JSQPhotoMediaItem(image: UIPasteboard.generalPasteboard().image)
//            
//            let message = JSQMessage(senderId: self.senderId, senderDisplayName: self.senderDisplayName, date: NSDate(), media: item)
//            self.messageArray.append(message)
//            self.finishSendingMessage()
            
            return false
        }
        
        return true
    }
    
}