//
//  ChatViewController.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import MonkeyKit

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
    
    var conversation: Conversation!
    
    var outgoingBubbleImageData: JSQMessagesBubbleImage!
    
    var incomingBubbleImageData: JSQMessagesBubbleImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.conversation.name;
        
        /**
         *  You MUST set your senderId and display name
         */
        self.senderId = AvatarIDCarlo;
        self.senderDisplayName = DisplayNameCarlo;
        
        self.inputToolbar.contentView.textView.pasteDelegate = self;
        
        /**
         *  You can set custom avatar sizes
         */
        //        self.collectionView.collectionViewLayout.incomingAvatarViewSize = .zero;
        //        self.collectionView.collectionViewLayout.outgoingAvatarViewSize = .zero;
        
        self.showLoadEarlierMessagesHeader = true;
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage.jsq_defaultTypingIndicatorImage(), style: .Plain, target: self, action: #selector(receiveMessagePressed))
        
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
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        
        self.outgoingBubbleImageData = bubbleFactory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
        self.incomingBubbleImageData = bubbleFactory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleGreenColor())
    }
    
    /**
     *  Get random user except me
     */
    func getRandomRecipient() -> User {
        let members = self.conversation.members.filter({ $0.id != self.senderId })
        let user = members[Int(arc4random_uniform(UInt32(members.count)))]
        return user
    }
    
    //MARK: Custom menu actions for cells
    
    override func didReceiveMenuWillShowNotification(notification: NSNotification!) {
        /**
         *  Display custom menu actions for cells.
         */
        let menu = notification.object as! UIMenuController
        
        menu.menuItems = [UIMenuItem(title: "Custom Action", action: #selector(self.customAction(_:)))]
    }
    
    //MARK: Actions
    
    func receiveMessagePressed(sender: UIBarButtonItem) {
        /**
         *  DEMO ONLY
         *
         *  The following is simply to simulate received messages for the demo.
         *  Do not actually do this.
         */
        
        
        /**
         *  Show the typing indicator to be shown
         */
        self.showTypingIndicator = !self.showTypingIndicator
        
        /**
         *  Scroll to actually view the indicator
         */
        self.scrollToBottomAnimated(true)
        
        /**
         *  Get random user that isn't me
         */
        let user = self.getRandomRecipient()
        
        /**
         *  Copy last sent message, this will be the new "received" message
         */
        var copyMessage = self.conversation.messages.last?.copy()
        
        if (copyMessage == nil) {
            copyMessage = JSQMessage(senderId: user.id, displayName: user.name, text: "First received!")
        }
        
        /**
         *  Allow typing indicator to show
         */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            
            
            var newMessage:JSQMessage?
            var newMediaData:JSQMessageMediaData?
            var newMediaAttachmentCopy:AnyObject?
            
            if copyMessage!.isMediaMessage() {
                /**
                 *  Last message was a media message
                 */
                let copyMediaData = copyMessage!.media
                
                switch copyMediaData {
                case is JSQPhotoMediaItem:
                    let photoItemCopy = (copyMediaData as! JSQPhotoMediaItem).copy() as! JSQPhotoMediaItem
                    photoItemCopy.appliesMediaViewMaskAsOutgoing = false
                    
                    newMediaAttachmentCopy = UIImage(CGImage: photoItemCopy.image.CGImage!)
                    
                    /**
                     *  Set image to nil to simulate "downloading" the image
                     *  and show the placeholder view
                     */
                    photoItemCopy.image = nil;
                    
                    newMediaData = photoItemCopy
                case is JSQLocationMediaItem:
                    let locationItemCopy = (copyMediaData as! JSQLocationMediaItem).copy() as! JSQLocationMediaItem
                    locationItemCopy.appliesMediaViewMaskAsOutgoing = false
                    newMediaAttachmentCopy = locationItemCopy.location.copy()
                    
                    /**
                     *  Set location to nil to simulate "downloading" the location data
                     */
                    locationItemCopy.location = nil;
                    
                    newMediaData = locationItemCopy;
                case is JSQVideoMediaItem:
                    let videoItemCopy = (copyMediaData as! JSQVideoMediaItem).copy() as! JSQVideoMediaItem
                    videoItemCopy.appliesMediaViewMaskAsOutgoing = false
                    newMediaAttachmentCopy = videoItemCopy.fileURL.copy()
                    
                    /**
                     *  Reset video item to simulate "downloading" the video
                     */
                    videoItemCopy.fileURL = nil;
                    videoItemCopy.isReadyToPlay = false;
                    
                    newMediaData = videoItemCopy;
                case is JSQAudioMediaItem:
                    let audioItemCopy = (copyMediaData as! JSQAudioMediaItem).copy() as! JSQAudioMediaItem
                    audioItemCopy.appliesMediaViewMaskAsOutgoing = false
                    newMediaAttachmentCopy = audioItemCopy.audioData?.copy()
                    
                    /**
                     *  Reset audio item to simulate "downloading" the audio
                     */
                    audioItemCopy.audioData = nil;
                    
                    newMediaData = audioItemCopy;
                default:
                    print("error: unrecognized media item")
                }
                
                newMessage = JSQMessage(senderId: user.id, displayName: user.name, media: newMediaData)
            }
            else {
                /**
                 *  Last message was a text message
                 */
                
                newMessage = JSQMessage(senderId: user.id, displayName: user.name, text: copyMessage!.text)
            }
            
            /**
             *  Upon receiving a message, you should:
             *
             *  1. Play sound (optional)
             *  2. Add new JSQMessageData object to your data source
             *  3. Call `finishReceivingMessage`
             */
            
            JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
            self.conversation.messages.append(newMessage!)
            self.finishReceivingMessageAnimated(true)
            
            if newMessage!.isMediaMessage {
                /**
                 *  Simulate "downloading" media
                 */
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                    /**
                     *  Media is "finished downloading", re-display visible cells
                     *
                     *  If media cell is not visible, the next time it is dequeued the view controller will display its new attachment data
                     *
                     *  Reload the specific item, or simply call `reloadData`
                     */
                    
                    switch newMediaData {
                    case is JSQPhotoMediaItem:
                        (newMediaData as! JSQPhotoMediaItem).image = newMediaAttachmentCopy as! UIImage
                        self.collectionView.reloadData()
                    case is JSQLocationMediaItem:
                        (newMediaData as! JSQLocationMediaItem).setLocation(newMediaAttachmentCopy as! CLLocation, withCompletionHandler: {
                            self.collectionView.reloadData()
                        })
                    case is JSQVideoMediaItem:
                        (newMediaData as! JSQVideoMediaItem).fileURL = newMediaAttachmentCopy as! NSURL
                        (newMediaData as! JSQVideoMediaItem).isReadyToPlay = true
                        self.collectionView.reloadData()
                    case is JSQAudioMediaItem:
                        (newMediaData as! JSQAudioMediaItem).audioData = newMediaAttachmentCopy as? NSData
                        self.collectionView.reloadData()
                    default:
                        print("error: unrecognized media item")
                    }
                }
            }
        }
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
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        let message = JSQMessage(senderId: senderId, senderDisplayName: senderDisplayName, date: date, text: text)
        
        self.conversation.messages.append(message)
        
        self.finishSendingMessageAnimated(true)
    }
    
    override func didPressAccessoryButton(sender: UIButton!) {
        self.inputToolbar.contentView.textView.resignFirstResponder()
        
        let sheet = UIAlertController(title: "Media messages", message: nil, preferredStyle: .ActionSheet)
        
        let photoButton = UIAlertAction(title: "Send photo", style: .Default) { (action) in
            /**
             *  Add fake photo into conversation messages
             */
            let photoItem = JSQPhotoMediaItem(image: UIImage(named: "goldengate"))
            let photoMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: photoItem)
            
            self.conversation.messages.append(photoMessage)
            
            JSQSystemSoundPlayer.jsq_playMessageSentSound()
            self.finishSendingMessageAnimated(true)
        }
        
        let locationButton = UIAlertAction(title: "Send location", style: .Default) { (action) in
            /**
             *  Add fake location into conversation messages
             */
            
            let ferryBuildingInSF = CLLocation(latitude: 37.795313, longitude: -122.393757)
            
            let locationItem = JSQLocationMediaItem()
            locationItem.setLocation(ferryBuildingInSF) {
                self.collectionView.reloadData()
            }
            
            let locationMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: locationItem)
            
            self.conversation.messages.append(locationMessage)
            
            JSQSystemSoundPlayer.jsq_playMessageSentSound()
            self.finishSendingMessageAnimated(true)
        }
        
        let videoButton = UIAlertAction(title: "Send video", style: .Default) { (action) in
            /**
             *  Add fake video into conversation messages
             */
            let videoURL = NSURL(fileURLWithPath: "file://")
            
            let videoItem = JSQVideoMediaItem(fileURL: videoURL, isReadyToPlay: true)
            let videoMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: videoItem)
            
            self.conversation.messages.append(videoMessage)
            
            JSQSystemSoundPlayer.jsq_playMessageSentSound()
            self.finishSendingMessageAnimated(true)
        }
        
        let audioButton = UIAlertAction(title: "Send audio", style: .Default) { (action) in
            /**
             *  Add fake audio into conversation messages
             */
            let sample = NSBundle.mainBundle().pathForResource("jsq_messages_sample", ofType: "m4a")
            
            let audioData = NSData(contentsOfFile: sample!)
            let audioItem = JSQAudioMediaItem(data: audioData)
            let audioMessage = JSQMessage(senderId: self.senderId, displayName: self.senderDisplayName, media: audioItem)
            
            self.conversation.messages.append(audioMessage)
            
            JSQSystemSoundPlayer.jsq_playMessageSentSound()
            self.finishSendingMessageAnimated(true)
        }
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        
        sheet.addAction(photoButton)
        sheet.addAction(locationButton)
        sheet.addAction(videoButton)
        sheet.addAction(audioButton)
        sheet.addAction(cancelButton)
        
        self.presentViewController(sheet, animated: true, completion: nil)
    }
    
    // MARK: JSQMessages CollectionView DataSource
    override func collectionView(collectionView: JSQMessagesCollectionView?, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData? {
        return self.conversation.messages[indexPath.item]
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didDeleteMessageAtIndexPath indexPath: NSIndexPath!) {
        self.conversation.messages.removeAtIndex(indexPath.item)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource? {
        /**
         *  You may return nil here if you do not want bubbles.
         *  In this case, you should set the background color of your collection view cell's textView.
         *
         *  Otherwise, return your previously created bubble image data objects.
         */
        
        let message = self.conversation.messages[indexPath.item]
        
        
        if message.senderId == self.senderId {
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
        let message = self.conversation.messages[indexPath.item]
        
        guard let user = self.conversation.getUser(message.senderId) else{
            return nil
        }
        
        return user.avatar
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        /**
         *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
         *  The other label text delegate methods should follow a similar pattern.
         *
         *  Show a timestamp for every 3rd message
         */
        if (indexPath.item % 3) == 0 {
            let message = self.conversation.messages[indexPath.item]
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(message.date)
        }
        
        return nil;
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        let message = self.conversation.messages[indexPath.item]
        
        /**
         *  iOS7-style sender name labels
         */
        if message.senderId == self.senderId {
            return nil;
        }
        
        if (indexPath.item - 1) > 0 {
            let previousMessage = self.conversation.messages[indexPath.item - 1]
            if previousMessage.senderId == message.senderId {
                return nil;
            }
        }
        
        /**
         *  Don't specify attributes to use the defaults.
         */
        return NSAttributedString(string: message.senderDisplayName)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        return nil
    }
    
    // MARK: UICollectionView DataSource
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.conversation.messages.count
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
        
        let msg = self.conversation.messages[indexPath.item]
        
        if !msg.isMediaMessage {
            
            if msg.senderId == self.senderId {
                cell.textView.textColor = UIColor.blackColor()
            }
            else {
                cell.textView.textColor = UIColor.whiteColor()
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
        if (indexPath.item % 3) == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        
        return 0.0
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView?, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout?, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        /**
         *  iOS7-style sender name labels
         */
        let currentMessage = self.conversation.messages[indexPath.item]
        if currentMessage.senderId == self.senderId {
            return 0.0
        }
        
        if (indexPath.item - 1) > 0 {
            let previousMessage = self.conversation.messages[indexPath.item - 1]
            if previousMessage.senderId == currentMessage.senderId {
                return 0.0
            }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        return 0.0
    }
    
    // MARK: Responding to collection view tap events
    override func collectionView(collectionView: JSQMessagesCollectionView!, header headerView: JSQMessagesLoadEarlierHeaderView!, didTapLoadEarlierMessagesButton sender: UIButton!) {
        print("Load earlier messages!")
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
            
            let item = JSQPhotoMediaItem(image: UIPasteboard.generalPasteboard().image)
            
            let message = JSQMessage(senderId: self.senderId, senderDisplayName: self.senderDisplayName, date: NSDate(), media: item)
            self.conversation.messages.append(message)
            self.finishSendingMessage()
            
            return false
        }
        
        return true
    }
    
}