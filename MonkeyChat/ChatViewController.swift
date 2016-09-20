
//  ChatViewController.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import UIKit
import MonkeyKitUI
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
  
  let readDove = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "check-blue-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
  let sentDove = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "check-grey-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
  
  //file destination folder
  let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/"
  
  //preview item
  var previewItem:PreviewItem!
  
  //recorder
  var recorder:AVAudioRecorder?
  
  //timer
  let timerLabel = UILabel()
  var timerRecording:Timer!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    //
    self.timerLabel.text = "00:00"
    self.timerLabel.isHidden = true
    self.inputToolbar.contentView.addSubview(self.timerLabel)
    self.timerLabel.frame = CGRect(x: 30, y: 0, width: self.inputToolbar.contentView.frame.size.width, height: self.inputToolbar.contentView.frame.size.height)
    self.inputToolbar.contentView.bringSubview(toFront: self.timerLabel)
    
    /**
     *	Register monkey listeners
     */
    //register listener for incoming messages
    NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.messageReceived), name: NSNotification.Name.MonkeyMessage, object: nil)
    
    //register listener for message acknowledges
    NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.acknowledgeReceived), name: NSNotification.Name.MonkeyAcknowledge, object: nil)
    
    //Start by opening the conversation in Monkey
    Monkey.sharedInstance().openConversation(self.conversation.conversationId)
    
    self.title = self.conversation.info.object(forKey: "name") as? String
    
    //set your cell identifiers
    self.outgoingCellIdentifier = JSQMessagesCollectionViewCellOutgoing2.cellReuseIdentifier()
    self.outgoingMediaCellIdentifier = JSQMessagesCollectionViewCellOutgoing2.mediaCellReuseIdentifier()
    
    self.collectionView.register(JSQMessagesCollectionViewCellOutgoing2.nib(), forCellWithReuseIdentifier: self.outgoingCellIdentifier)
    self.collectionView.register(JSQMessagesCollectionViewCellOutgoing2.nib(), forCellWithReuseIdentifier: self.outgoingMediaCellIdentifier)
    
    self.incomingCellIdentifier = JSQMessagesCollectionViewCellIncoming2.cellReuseIdentifier()
    self.incomingMediaCellIdentifier = JSQMessagesCollectionViewCellIncoming2.mediaCellReuseIdentifier()
    
    self.collectionView.register(JSQMessagesCollectionViewCellIncoming2.nib(), forCellWithReuseIdentifier: self.incomingCellIdentifier)
    self.collectionView.register(JSQMessagesCollectionViewCellIncoming2.nib(), forCellWithReuseIdentifier: self.incomingMediaCellIdentifier)
    
    
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
    self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: 12, height: 9.5)
    
    self.showLoadEarlierMessagesHeader = true
    
    /**
     *  Register custom header view
     */
    self.collectionView.register(JSQMessagesActivityIndicatorHeaderView.nib(), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: JSQMessagesActivityIndicatorHeaderView.headerReuseIdentifier())
    
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
    
    let bubbleFactory = JSQMessagesBubbleImageFactory(bubble: .jsq_bubbleCompactTailless(), capInsets: .zero)
    
    self.outgoingBubbleImageData = bubbleFactory?.outgoingMessagesBubbleImage(with: .jsq_messageBubbleBlue())
    self.incomingBubbleImageData = bubbleFactory?.incomingMessagesBubbleImage(with: .jsq_messageBubbleLightGray())
    
    /**
     *	Load messages for this conversation
     */
    
    guard let lastMessage = self.conversation.lastMessage else {
      return
    }
    
    self.messageArray = DBManager.getMessages(self.senderId, recipient: self.conversation.conversationId, from: lastMessage, count: 10)
    
    if self.messageArray.index(of: lastMessage) == nil {
      self.messageArray.append(lastMessage)
    }
    
    self.collectionView.reloadData()
  }
}

//MARK: - Monkey Listeners
extension ChatViewController {
  
  func messageReceived(_ notification:Foundation.Notification){
    
    
    guard let userInfo = (notification as NSNotification).userInfo, let message = userInfo["message"] as? MOKMessage else{
      return
    }
    //check that the message is for this conversation
    if message.conversationId(Monkey.sharedInstance().monkeyId()) != self.conversation.conversationId {
      
      let view = UIImageView()
      view.sd_setImage(with: conversation?.getAvatarURL())
      
      var title = "Notification"
      
      if let user = DBManager.getUser(message.sender) {
        title = (user.info!["name"] ?? "Notification") as! String
        view.sd_setImage(with: user.getAvatarURL())
      }
      
      let announcement = Announcement(title: title, subtitle: (notification.userInfo!["message"] as! MOKMessage).plainText, image: view.image, duration: 2.0, action: {
        print("finish presenting!")
      })
      show(shout: announcement, to: self.navigationController!, completion: { _ in })
      
      return
    }
    
    conversation!.lastMessage = message
    
    self.messageHash[message.messageId] = message
    self.messageArray.append(message)
    
    self.finishReceivingMessage()
  }
  
  func acknowledgeReceived(_ notification:Foundation.Notification){
    
    guard let acknowledge = (notification as NSNotification).userInfo else {
      return
    }
    
    //update last message if necessary
    guard let oldId = acknowledge["oldId"] as? String,
      let newId = acknowledge["newId"] as? String,
      let message = self.messageHash[oldId]
      , message.messageId == oldId || message.messageId == newId else {
        //nothing to do
        return
    }
    
    message.messageId = newId
    message.oldMessageId = oldId
    
    self.collectionView.reloadData()
  }
  
  // MARK: Messaging stuff
  func loadMessages(_ animated:Bool) {
    guard let firstMessage = self.messageArray.first , self.shouldRequestMessages && !self.isGettingMessages else{
      return
    }
    
    self.isGettingMessages = true
    
    //try loading more from db
    
    let messages = DBManager.getMessages(self.senderId, recipient: self.conversation.conversationId, from: firstMessage, count: 10)
    
    if messages.count > 0 {
      let delayTime = DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
      DispatchQueue.main.asyncAfter(deadline: delayTime) {
        for message in messages {
          self.messageHash[message.messageId] = message
        }
        
        self.messageArray = messages + self.messageArray
        
        let oldOffset = self.collectionView.contentOffset
        
        self.collectionView.reloadData()
        
        if animated {
          self.scrollToBottom(animated: true)
          self.isGettingMessages = false
          return
        }
        
        let newIndex = self.messageArray.index(of: firstMessage)!
        self.collectionView.scrollToItem(at: IndexPath(item: newIndex, section: 0), at: .top, animated: false)
        
        let newoffset = CGPoint(x: 0, y: self.collectionView.contentOffset.y + oldOffset.y)
        
        self.collectionView.setContentOffset(newoffset, animated: false)
        
        self.isGettingMessages = false
      }
      
      return
    }
    
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
        self.scrollToBottom(animated: true)
        self.isGettingMessages = false
        return
      }
      
      let newIndex = self.messageArray.index(of: firstMessage)!
      self.collectionView.scrollToItem(at: IndexPath(item: newIndex, section: 0), at: .top, animated: false)
      
      let newoffset = CGPoint(x: 0, y: self.collectionView.contentOffset.y + oldOffset.y)
      
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
  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    return 1
  }
  
  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    return self.previewItem
  }
}

// MARK: - Input Delegate
extension ChatViewController {
  override func messagesInputToolbar(_ toolbar: JSQMessagesInputToolbar!, didOpenOptionButton sender: KSMManyOptionsButton!) {
    if sender.currentManyOptionsButtonState != .closed {
      self.inputToolbar.contentView.textView.isHidden = true
      self.inputToolbar.contentView.leftBarButtonItem.isHidden = true
      self.timerLabel.isHidden = false
      self.startRecording()
    }
  }
  
  override func messagesInputToolbar(_ toolbar: JSQMessagesInputToolbar!, didSelectOptionButton location: KSMManyOptionsButtonLocation) {
    switch location {
    case .left:
      self.stopRecording(send:false)
    case .none:
      self.stopRecording(send:true)
    default: break
    }
  }
  
  override func messagesInputToolbar(_ toolbar: JSQMessagesInputToolbar!, didBeginClosingOptionButton sender: KSMManyOptionsButton!) {
    self.timerLabel.isHidden = true
    self.inputToolbar.contentView.textView.isHidden = false
    self.inputToolbar.contentView.leftBarButtonItem.isHidden = false
  }
}

// MARK: - Audio delegate
extension ChatViewController {
  func startRecording(){
    
    AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
      DispatchQueue.main.async(execute: {
        if !granted {
          let alertcontroller = UIAlertController(title: nil, message: "Maduro", preferredStyle: .alert)
          alertcontroller.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action) in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
          }))
          alertcontroller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
          
          alertcontroller.popoverPresentationController?.sourceView = self.view
          alertcontroller.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.size.width / 2.0, y: self.view.bounds.size.height-45, width: 1.0, height: 1.0)
          self.present(alertcontroller, animated: true, completion: nil)
          return
        }
        
        (self.navigationController as! RotationNavigationController).lockAutorotate = true
        
        UIApplication.shared.isStatusBarHidden = true
        
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        
        let filename = "audio\(UInt64(Date().timeIntervalSince1970)).aac"
        let dirpath = self.documentsPath + filename
        
        try! self.recorder = AVAudioRecorder(url: URL(string: dirpath)!,
                                             settings: [
                                              AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC as UInt32),
                                              AVSampleRateKey: NSNumber(value: 1200 as Float),
                                              AVNumberOfChannelsKey: NSNumber(value: 1 as Int32),
                                              AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.min.rawValue as Int)
          ])
        
        self.recorder!.record()
        
        if self.timerRecording != nil {
          self.timerRecording.invalidate()
        }
        
        if self.timerRecording == nil || (self.timerRecording != nil && !self.timerRecording.isValid) {
          self.timerRecording = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateTimer), userInfo: nil, repeats: true)
          RunLoop.main.add(self.timerRecording, forMode: RunLoopMode.commonModes)
        }
        
        UIApplication.shared.isStatusBarHidden = false
      })
    }
  }
  
  func updateTimer() {
    guard let recorder = self.recorder else {
      return
    }
    let minutes = Int((recorder.currentTime.truncatingRemainder(dividingBy: 3600)) / 60)
    let secs = Int((recorder.currentTime.truncatingRemainder(dividingBy: 3600)).truncatingRemainder(dividingBy: 60))
    
    
    self.timerLabel.text = String(format: "%02d:%02d", minutes, secs)
  }
  
  func stopRecording(send flag:Bool) {
    
    guard let recorder = self.recorder , recorder.isRecording else {
      return
    }
    (self.navigationController as! RotationNavigationController).lockAutorotate = false
    
    recorder.stop()
    
    if !flag {
      return
    }
    
    let audioAsset = AVURLAsset(url: URL(fileURLWithPath: recorder.url.path))
    let duration = audioAsset.duration
    let seconds = CMTimeGetSeconds(duration)
    if seconds > 0.7 {
      guard let data = try? Data(contentsOf: URL(fileURLWithPath: recorder.url.path)) else {
        return
      }
      
      //            let push = Monkey.sharedInstance()
      let message = Monkey.sharedInstance().sendFile(data, type: MOKAudio, filename: recorder.url.lastPathComponent, encrypted: true, compressed: true, to: self.conversation.conversationId, params: ["length":Int(seconds)], push: "You received an audio", success: { (message) in
        
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
    try! AVAudioSession.sharedInstance().setActive(false, with: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation)
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
  }
  
}

// MARK: - Image delegate
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
    
    let filename = "photo\(UInt64(Date().timeIntervalSince1970)).png"
    let dirpath = self.documentsPath + filename
    
    guard let representation = UIImageJPEGRepresentation(image, 0.6) else {
      return
    }
    
    let data = NSData.init(data: representation) as Data
    try? data.write(to: URL(fileURLWithPath: dirpath), options: [.atomic])
    
    self.dismiss(animated: true, completion: nil)
    
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
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    self.dismiss(animated: true, completion: nil)
  }
}

extension ChatViewController {
  
  func send(_ text:String, size:Int) {
    
    guard !text.isEmpty else {
      return
    }
    
    var wordArray = text.components(separatedBy: " ").filter({ !$0.isEmpty })
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
    
    self.finishSendingMessage(animated: true)
    
    let remainingText = wordArray.joined(separator: " ")
    self.send(remainingText, size: size)
    
  }
  
  // MARK: - JSQMessagesViewController method overrides
  override func didPressSend(_ button: UIButton?, withMessageText text: String?, senderId: String?, senderDisplayName: String?, date: Date?) {
    /**
     *  Sending a message. Your implementation of this method should do *at least* the following:
     *
     *  1. Play sound (optional)
     *  2. Add new id<JSQMessageData> object to your data source
     *  3. Call `finishSendingMessage`
     */
    
    self.send(text ?? "", size: self.maxSize)
  }
  
  override func didPressAccessoryButton(_ sender: UIButton!) {
    self.inputToolbar.contentView.textView.resignFirstResponder()
    
    let sheet = UIAlertController(title: "Media messages", message: nil, preferredStyle: .actionSheet)
    
    if UIImagePickerController.isSourceTypeAvailable(.camera) {
      sheet.addAction(
        UIAlertAction(title: "Take Picture", style: .default) { (action) in
          
          AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted) in
            DispatchQueue.main.async(execute: {
              if !granted {
                let alertcontroller = UIAlertController(title: nil, message: "Maduro", preferredStyle: .alert)
                alertcontroller.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action) in
                  UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
                }))
                alertcontroller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                alertcontroller.popoverPresentationController?.sourceView = self.view
                alertcontroller.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.size.width / 2.0, y: self.view.bounds.size.height-45, width: 1.0, height: 1.0)
                self.present(alertcontroller, animated: true, completion: nil)
                return
              }
              
              let picker = UIImagePickerController()
              picker.delegate = self
              picker.sourceType = .camera
              
              self.present(picker, animated: true, completion: nil)
            })
          })
      })
    }
    
    let photoButton = UIAlertAction(title: "Choose existing picture", style: .default) { (action) in
      
      PHPhotoLibrary.requestAuthorization({ (status) in
        DispatchQueue.main.async(execute: {
          switch status {
          case .authorized:
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            
            self.present(picker, animated: true, completion: nil)
            break
          case .denied, .restricted:
            fallthrough
          default:
            let alertcontroller = UIAlertController(title: nil, message: "Maduro", preferredStyle: .alert)
            alertcontroller.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action) in
              UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
            }))
            alertcontroller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            alertcontroller.popoverPresentationController?.sourceView = self.view
            alertcontroller.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.size.width / 2.0, y: self.view.bounds.size.height-45, width: 1.0, height: 1.0)
            self.present(alertcontroller, animated: true, completion: nil)
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
    
    let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    
    sheet.addAction(photoButton)
    sheet.addAction(cancelButton)
    
    self.present(sheet, animated: true, completion: nil)
  }
  
  // MARK: JSQMessages CollectionView DataSource
  override func collectionView(_ collectionView: JSQMessagesCollectionView?, messageDataForItemAt indexPath: IndexPath) -> JSQMessageData? {
    let message = self.messageArray[indexPath.item]
    return message
  }
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView, didDeleteMessageAt indexPath: IndexPath) {
    self.messageArray.remove(at: indexPath.item)
  }
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView?, messageBubbleImageDataForItemAt indexPath: IndexPath) -> JSQMessageBubbleImageDataSource? {
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
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView, avatarImageDataForItemAt indexPath: IndexPath) -> JSQMessageAvatarImageDataSource? {
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
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView, attributedTextForCellBottomLabelAt indexPath: IndexPath) -> NSAttributedString? {
    return nil
  }
  
  override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
    self.loadMessages(false)
  }
  
  override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: self.headerViewIdentifier!, for: indexPath)
    
    //only show if it will request messages afterwards
    header.isHidden = !self.shouldRequestMessages
    
    return header
  }
  
  // MARK: UICollectionView DataSource
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.messageArray.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    /**
     *  Override point for customizing cells
     */
    let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
    
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
        cell.textView.textColor = .white
      } else {
        cell.textView.textColor = .black
      }
      
      let attributes : [String:Any] = [NSForegroundColorAttributeName:cell.textView.textColor!, NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle]
      cell.textView.linkTextAttributes = attributes
      
      return cell
    }
    
    //media stuff
    message.maskAsOutgoing(isOutgoing)
    
    let media = message.media()
    
    if media!.needsDownload!() {
      print("Download!!!")
      self.downloadFile(message)
    }
    
    return cell
  }
  
  func downloadFile(_ message:MOKMessage) {
    Monkey.sharedInstance().downloadFileMessage(message, fileDestination: self.documentsPath, success: { (data) in
      //reload collection
      message.reloadMedia(data as NSData)
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
  
  // MARK: JSQMessages collection view flow layout delegate
  // MARK: Adjusting cell label heights
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAt indexPath: IndexPath!) -> CGFloat {
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
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every 3rd message
     */
    let currentMessage = self.messageArray[indexPath.item]
    
    if indexPath.item == 0 {
      return JSQMessagesTimestampFormatter.shared().attributedTimestamp(for: currentMessage.date())
    }
    
    let previousMessage = self.messageArray[indexPath.item - 1]
    
    if (currentMessage.timestampCreated - previousMessage.timestampCreated) > 7200 {
      return JSQMessagesTimestampFormatter.shared().attributedTimestamp(for: currentMessage.date())
    }
    
    return nil;
  }
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView?, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout?, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
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
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
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
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAt indexPath: IndexPath!) -> CGFloat {
    return 0.0
  }
  
  // MARK: Responding to collection view tap events
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
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
    
    self.present(vc, animated: true, completion: nil)
    
  }
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapCellAt indexPath: IndexPath!, touchLocation: CGPoint) {
    print("Tapped cell at \(touchLocation)")
  }
  
  // MARK: JSQMessagesComposerTextViewPasteDelegate methods
  func composerTextView(_ textView: JSQMessagesComposerTextView!, shouldPasteWithSender sender: AnyObject!) -> Bool {
    if (UIPasteboard.general.image != nil) {
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
