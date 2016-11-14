
//  ChatViewController.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import UIKit
import MonkeyKitUI
import MonkeyKit
import SDWebImage
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

class ChatViewController: MOKChatViewController, JSQMessagesComposerTextViewPasteDelegate {
  
  let maxSize = 8500
  
  // DATA - conversation
  var conversation: MOKConversation!
  var memberHash = [String:MOKUser]() // monkeyId: MOKUser
  var nameMembers = [String]()
  var nameMembersDescription: String?
  
  // DATA - conversation - messages
  var messageHash = [String:MOKMessage]()
  var messageArray = [MOKMessage]()
  
  //messageId : AFHTTPRequestOperation
  var downloadOperations = [String:AnyObject]()
  
  //flags for requesting messages
  var isGettingMessages = false
  var shouldRequestMessages = true
  
  let readDove = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "check-blue-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
  let sentDove = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "check-grey-icon.png"), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
  
  //file destination folder
  let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/"
  
  //preview item
  var previewItem:PreviewItem!
  
  //recorder
  var recorder:AVAudioRecorder?
  
  //timer
  var timerRecording:Timer!
  
  // VIEW - navigation bar - title
  var descriptionViewTapRecognizer: UITapGestureRecognizer!
  
  // VIEW - messages - audio bubble
  var audioBubbleOnPlay: RGCircularSlider?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // DATA - user session
    self.senderId = Monkey.sharedInstance().session["monkeyId"] as! String
    self.senderDisplayName = ((Monkey.sharedInstance().session["user"] as! [String:AnyObject])["name"] as? String) ?? "Unknown"
    
    // DATA - conversation
    for user in DBManager.getUsers(self.conversation.members as NSArray as! [String]) {
      self.memberHash[user.monkeyId] = user
      self.nameMembers.append(user.info?["name"] as? String ?? "Unknown")
    }
    if self.conversation.isGroup() {
      self.nameMembersDescription = self.nameMembers.joined(separator: ", ")
    }
    
    // DATA - conversation - messages
    if let lastMessage = self.conversation.lastMessage  { // load messages
      self.messageArray = DBManager.getMessages(self.senderId, recipient: self.conversation.conversationId, from: lastMessage, count: 10)
      if self.messageArray.index(of: lastMessage) == nil { // include last message
        self.messageArray.append(lastMessage)
      }
    }else{
      self.shouldRequestMessages = false
    }
    
    // VIEW - navigation bar - title
    self.nameLabel.text = self.conversation.info["name"] as? String ?? "Unknown"
    self.statusLabel.text = self.nameMembersDescription ?? ""
    
    self.descriptionViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.showInfoConversation(_:)))
    self.descriptionViewTapRecognizer.numberOfTapsRequired = 1
    self.descriptionView.addGestureRecognizer(self.descriptionViewTapRecognizer)
    
    // VIEW - navigation bar - right button
    self.avatarImageView.sd_setImage(with: self.conversation.getAvatarURL(), placeholderImage: UIImage(named: "Profile_imgDefault.png"))
    self.avatarButton.setImage(self.avatarImageView.image, for: UIControlState.normal)
    
    self.mediaDataDelegate = self
    /**
     *	Register monkey listeners
     */
    //register listener for incoming messages
    NotificationCenter.default.addObserver(self, selector: #selector(self.messageReceived), name: NSNotification.Name.MonkeyMessage, object: nil)
    
    //register listener for message acknowledges
    NotificationCenter.default.addObserver(self, selector: #selector(self.acknowledgeReceived), name: NSNotification.Name.MonkeyAcknowledge, object: nil)
    
    //register listener for acknowledges of opens I do
    NotificationCenter.default.addObserver(self, selector: #selector(self.openResponseReceived(_:)), name: NSNotification.Name.MonkeyConversationStatus, object: nil)
    
    //register listener for UIDeviceProximityStateDidChangeNotification
    NotificationCenter.default.addObserver(self, selector: #selector(self.handleProximityChange), name: NSNotification.Name(rawValue: "UIDeviceProximityStateDidChangeNotification"), object: nil)
    
    
    
    
    //Start by opening the conversation in Monkey
    Monkey.sharedInstance().openConversation(self.conversation.conversationId)
    
    // Update conversation counter unread
    DBManager.store(self.conversation)
    
    
    self.inputToolbar.contentView.textView.pasteDelegate = self
    
    /**
     *  You can set custom avatar sizes
     */
    self.collectionView.collectionViewLayout.incomingAvatarViewSize = .zero
    self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: 12, height: 9.5)
    
    self.showLoadEarlierMessagesHeader = true

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
    

    self.collectionView.reloadData()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    if let player = self.audioBubbleOnPlay {
      player.stopAudio()
      try! AVAudioSession.sharedInstance().setActive(false, with: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation)
      self.audioBubbleOnPlay = nil
      UIDevice.current.isProximityMonitoringEnabled = false
    }
  
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
    NotificationCenter.default.post(name: Notification.Name.MonkeyChat.MessageSent, object: self)
    
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

  override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
    if !self.shouldRequestMessages {
      return .zero
    }
    
    return super.collectionView(collectionView, layout: collectionViewLayout, referenceSizeForHeaderInSection: section)
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
    
    cell.dateLabel.text = self.getDate(message.timestampCreated, format: nil)
    
    if !message.isMediaMessage() {
      
      if isOutgoing {
        cell.textView.textColor = UIColor.white
        cell.textView.linkTextAttributes = [NSForegroundColorAttributeName : UIColor.white, NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
      } else {
        cell.textView.textColor = UIColor.black
        cell.textView.linkTextAttributes = [NSForegroundColorAttributeName : UIColor.black, NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
      }
      
      return cell
    }
    
    //media stuff
    message.maskAsOutgoing(isOutgoing)
    
    let media = message.media()
    
    if media!.needsDownload!() {
      print("Download!!!")
      self.downloadFile(message)
    }
    
    if(message.mediaType() == Audio.rawValue){
      var mediaSubviews:[UIView] = (message.media() as! BLAudioMedia).mediaView().subviews
      let player = mediaSubviews[0] as! RGCircularSlider
      player.delegate = self
    }
    
    return cell
  }
  
  func downloadFile(_ message:MOKMessage) {
    Monkey.sharedInstance().downloadFileMessage(message, fileDestination: self.documentsPath, success: { (data) in
      //reload collection
      
      message.reloadMedia(data)
      self.collectionView.reloadData()
      
    }) { (task, error) in
      //if file download is on progress do nothing
      //      if error.code == -60 {
      //        return
      //      }
      
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
     *  Show a timestamp for every DAY
     */
    
    if indexPath.item == 0 {
      return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
    
    let currentDateMessage = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: self.messageArray[indexPath.item].timestampCreated))
    let previousDateMessage = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: self.messageArray[indexPath.item - 1].timestampCreated))
    
    let qtyDay = Calendar.current.dateComponents([.day], from:previousDateMessage , to:currentDateMessage ).day!
    if( qtyDay >= 1){
      return kJSQMessagesCollectionViewCellLabelHeightDefault
    }

    return 0.0
  }
  
  override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every DAY
     */
    let currentMessage = self.messageArray[indexPath.item]
    
    if indexPath.item == 0 {
      return JSQMessagesTimestampFormatter.shared().attributedTimestamp(for: currentMessage.date())
    }
    
    let currentDateMessage = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: self.messageArray[indexPath.item].timestampCreated))
    let previousDateMessage = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: self.messageArray[indexPath.item - 1].timestampCreated))
    
    let qtyDay = Calendar.current.dateComponents([.day], from: previousDateMessage, to: currentDateMessage).day!
    if( qtyDay >= 1){
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
      let user = self.memberHash[currentMessage.sender]
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
  
  public func composerTextView(_ textView: JSQMessagesComposerTextView!, shouldPasteWithSender sender: Any!) -> Bool {
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

// MARK: - Audio Recording delegate
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
      
      let push = self.createPush(File, fileType: Audio)
      let message = Monkey.sharedInstance().sendFile(data, type: Audio, filename: recorder.url.lastPathComponent, encrypted: true, compressed: true, to: self.conversation.conversationId, params: ["length":Int(seconds)], push: push, success: { (message) in
        
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

// MARK: - Audio Recording delegate
extension ChatViewController: RGCircularSliderDelegate {
  func audioDidBeginPlaying(_ audioSlider: Any) {
    try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
    
    if let player = self.audioBubbleOnPlay {
     player.pauseAudio()
    }
    
    self.audioBubbleOnPlay = audioSlider as? RGCircularSlider
    UIDevice.current.isProximityMonitoringEnabled = true
  }
  
  func audioDidFinishPlaying(_ audioSlider: Any) {
    self.audioBubbleOnPlay = nil
    self.handleProximityChange()
    try! AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
  }
  
  func  audioDidBeginPause(_ audioSlider: Any) {
    UIDevice.current.isProximityMonitoringEnabled = false
    self.audioBubbleOnPlay = audioSlider as? RGCircularSlider
    try! AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
  }
  
  func handleProximityChange() {
    if(UIDevice.current.proximityState) {
      try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
    }else{
      if let player = self.audioBubbleOnPlay {
        player.pauseAudio()
      }
      
      try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
      UIDevice.current.isProximityMonitoringEnabled = false
    }
  }
}

// MARK: - Image delegate
extension ChatViewController: MOKMediaDataDelegate {
  func selectedImage(_ data: Data!) {
    let filename = "photo\(UInt64(Date().timeIntervalSince1970)).png"
    let dirpath = self.documentsPath + filename
    
    try? data.write(to: URL(fileURLWithPath: dirpath), options: [.atomic])
    
    let push = self.createPush(File, fileType: Image)
    let message = Monkey.sharedInstance().sendFile(data, type: Image, filename: filename, encrypted: true, compressed: true, to: self.conversation.conversationId, params: nil, push: push, success: { (message) in
      
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
  
  func recordedAudio(_ data: Data!) {
    
  }
}

//MARK: - Monkey Listeners
extension ChatViewController {
  func messageReceived(_ notification:Foundation.Notification){
    //do nothing if there's no valid message
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
      Whisper.show(shout: announcement, to: self.navigationController!)
      
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
  
  func openResponseReceived(_ notification:Foundation.Notification) {
    guard let response = (notification as NSNotification).userInfo else {
      return
    }
    
    let conversationId = response["monkeyId"] as! String
    if conversationId != self.conversation.conversationId { // do nothing if there's no same conversation
      return
    }
    
    if !self.conversation.isGroup() {
      guard let lastSeen = response["lastSeen"] as? String else {
        let online = response["online"] as! String
        if online == "1" {
          self.statusLabel.text = "Online"
        }
        return
      }

      self.conversation.lastSeen = (lastSeen as NSString).doubleValue as TimeInterval
      DBManager.store(self.conversation)
      self.statusLabel.text = "Last Seen " + self.conversation.getLastSeenDate()
      
    }
  }
}

//MARK: - Chat

extension ChatViewController {
  
  // Conversation
  func showInfoConversation(_ gestureRecognizer: UITapGestureRecognizer) {
    print("conversation info")
    
    let vc = InfoConversationViewController()
    
    vc.conversation = self.conversation
    self.navigationController?.pushViewController(vc, animated: true)
  }
  
  // Message
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
  
  func send(_ text:String, size:Int) {
    
    guard !text.isEmpty else {
      return
    }
    
    var wordArray = text.components(separatedBy: " ").filter({ !$0.isEmpty })
    var textCopy = wordArray.removeFirst()
    
    while(!wordArray.isEmpty && textCopy.characters.count < size){
      textCopy += " \(wordArray.removeFirst())"
    }
    
    let push = self.createPush(Text, fileType: nil)
    let message = Monkey.sharedInstance().sendText(textCopy, to: self.conversation.conversationId, params: nil, push: push)
    
    DBManager.store(message)
    self.messageArray.append(message)
    self.messageHash[message.messageId] = message
    self.conversation.lastMessage = message
    JSQSystemSoundPlayer.jsq_playMessageSentSound()
    self.finishSendingMessage(animated: true)
    let remainingText = wordArray.joined(separator: " ")
    self.send(remainingText, size: size)
  }
  
  func createPush(_ messageType:MOKMessageType, fileType:MOKFileType?) -> [String: Any] {
    var locArgs: [String]
    var locKey = "push"
    
    if(self.conversation.isGroup()){
      locArgs = [self.senderDisplayName, self.conversation.info["name"] as! String]
      locKey = "group" + locKey
    }else{
      locArgs = [self.senderDisplayName]
    }
    
    switch messageType {
    case Text:
      locKey = locKey + "textKey"
      break
    case File:
      switch fileType {
      case Audio?:
        locKey = locKey + "audioKey"
        break
      case Image?:
        locKey = locKey + "imageKey"
        break
      case Archive?:
        locKey = locKey + "fileKey"
        break
      default:
        locKey = locKey + "textKey"
        break
      }
      break
    default:
      locKey = locKey + "textKey"
      break
    }
    
    let push = ["iosData":["alert":["loc-key":locKey,
                                    "loc-args":locArgs],
                           "sound":"default"],
                "andData":["loc-key":locKey,
                          "loc-args":locArgs]
                ] as [String : Any]
    return push
  }
}
