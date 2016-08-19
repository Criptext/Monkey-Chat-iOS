
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
    
    //flags for requesting messages
    var isGettingMessages = false
    var shouldRequestMessages = true
    
    //identifier for header of collection view
    var headerViewIdentifier = JSQMessagesActivityIndicatorHeaderView.headerReuseIdentifier()
    
    
    var outgoingBubbleImageData: JSQMessagesBubbleImage!
    var incomingBubbleImageData: JSQMessagesBubbleImage!
    
    let readDove = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "check-blue-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
    let sentDove = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "check-grey-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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

extension ChatViewController {
    //MARK: Monkey Listeners
    func messageReceived(notification:NSNotification){
        //check that the message is for this conversation
        
        guard let userInfo = notification.userInfo, message = userInfo["message"] as? MOKMessage where message.conversationId(Monkey.sharedInstance().monkeyId()) == self.conversation.conversationId else {
            
            let view = UIImageView()
            view.sd_setImageWithURL(conversation?.getAvatarURL())
            
            let announcement = Announcement(title: "notificacion", subtitle: (notification.userInfo!["message"] as! MOKMessage).plainText, image: view.image, duration: 2.0, action: {
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
        
        let message = Monkey.sharedInstance().sendText(textCopy, to: self.conversation.conversationId, params: nil, push: nil)
        
        self.messageArray.append(message)
        self.messageHash[message.messageId] = message
        self.conversation.lastMessage = message
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        self.finishSendingMessageAnimated(true)
        
        let remainingText = wordArray.joinWithSeparator(" ")
        self.send(remainingText, size: size)
        
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
    
    // MARK: JSQMessagesViewController method overrides
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
        
        let photoButton = UIAlertAction(title: "Send photo", style: .Default) { (action) in
            /**
             *  Add fake photo into conversation messages
             */
//            let photoItem = JSQPhotoMediaItem(image: UIImage(named: "goldengate"))
//            let photoMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: photoItem)
//            
//            self.messageArray.append(photoMessage)
//            
//            JSQSystemSoundPlayer.jsq_playMessageSentSound()
//            self.finishSendingMessageAnimated(true)
        }
        
        let locationButton = UIAlertAction(title: "Send location", style: .Default) { (action) in
            /**
             *  Add fake location into conversation messages
             */
            
//            let ferryBuildingInSF = CLLocation(latitude: 37.795313, longitude: -122.393757)
//            
//            let locationItem = JSQLocationMediaItem()
//            locationItem.setLocation(ferryBuildingInSF) {
//                self.collectionView.reloadData()
//            }
//            
//            let locationMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: locationItem)
//            
//            self.messageArray.append(locationMessage)
//            
//            JSQSystemSoundPlayer.jsq_playMessageSentSound()
//            self.finishSendingMessageAnimated(true)
        }
        
        let audioButton = UIAlertAction(title: "Send audio", style: .Default) { (action) in
            /**
             *  Add fake audio into conversation messages
             */
//            let sample = NSBundle.mainBundle().pathForResource("jsq_messages_sample", ofType: "m4a")
//            
//            let audioData = NSData(contentsOfFile: sample!)
//            let audioItem = JSQAudioMediaItem(data: audioData)
//            let audioMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: audioItem)
//            
//            self.messageArray.append(audioMessage)
//            
//            JSQSystemSoundPlayer.jsq_playMessageSentSound()
//            self.finishSendingMessageAnimated(true)
        }
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        
        sheet.addAction(photoButton)
        sheet.addAction(locationButton)
        sheet.addAction(audioButton)
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
        
        let msg = self.messageArray[indexPath.item]
        
        if !msg.isMediaMessage() {
            
            if msg.senderId() == self.senderId {
                cell.textView.textColor = UIColor.whiteColor()
            }
            else {
                cell.textView.textColor = UIColor.blackColor()
            }
            
            let attributes : [String:AnyObject] = [NSForegroundColorAttributeName:cell.textView.textColor!, NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue]
            cell.textView.linkTextAttributes = attributes
        }
        
        return cell;
    }
    
    
    // MARK: UICollectionView Delegate
    
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
            currentMessage
            return NSAttributedString(string: currentMessage.senderDisplayName())
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