//
//  ConversationViewController.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

// Cell
class ConversationTableViewCell: UITableViewCell {
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var recentTextLabel: UILabel!
}

import UIKit
import MonkeyKitUI
import MonkeyKit
import SDWebImage
import Whisper
import RealmSwift
import UserNotifications

/**
 *  ViewController that lists your conversations
 *
 *  It shows the name of the conversation and its last message
 */

protocol InAppNotification {
  
}

class ConversationsListViewController: UITableViewController {
  
  var conversationHash = [String:MOKConversation]()
  var conversationArray = [MOKConversation]()
  var filteredConversationArray = [MOKConversation]()
  
  let searchController = UISearchController(searchResultsController: nil)
  let defaultAvatar = UIImage(named: "Profile_imgDefault.png")
  let readDove = UIImage(named: "check-blue-icon.png")
  let sentDove = UIImage(named: "check-grey-icon.png")
  
  let appID = ""
  let appSecret = ""
  
  let dateFormatter = DateFormatter()
  
  //flags for requesting conversations
  var isGettingConversations = false
  var shouldRequestConversations = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    /**
     *  Hides empty cells
     */
    self.tableView.tableFooterView = UIView()
    
    // VIEW - navigation bar
    self.navigationItem.title = "Chat"
    self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: nil, action: nil)
    
    //customize In-app
    ColorList.Shout.background = UIColor.black
    ColorList.Shout.title = UIColor.white
    ColorList.Shout.subtitle = UIColor.white
    
    //stop notifications from modifying tableview inset
    Config.modifyInset = false
    
    //fixed tableview having strange offset
    self.edgesForExtendedLayout = UIRectEdge()
    
    self.navigationController?.view.backgroundColor = UIColor.white
    
    self.dateFormatter.timeStyle = .short
    self.dateFormatter.dateStyle = .none
    self.dateFormatter.doesRelativeDateFormatting = true
    
    //configure search bar
    self.searchController.searchResultsUpdater = self
    self.searchController.dimsBackgroundDuringPresentation = false
    self.searchController.delegate = self
    self.definesPresentationContext = true
    
    self.tableView.tableHeaderView = self.searchController.searchBar
    self.edgesForExtendedLayout = UIRectEdge.all
    self.extendedLayoutIncludesOpaqueBars = true
    
    //register nib for table cell
    self.tableView.register(UINib(nibName: "ChatViewCell", bundle: nil), forCellReuseIdentifier: "ChatViewCell")
    
    //configure refresh control
    self.refreshControl = UIRefreshControl()
    self.refreshControl?.backgroundColor = UIColor(red:0.93, green:0.93, blue:0.93, alpha:1.0)
    self.refreshControl?.addTarget(self, action: #selector(ConversationsListViewController.handleTableRefresh), for: .valueChanged)
    
    // screen info whr conversation list is empty
    let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
    messageLabel.text = "No conversations are currently available. Please pull down to refresh."
    messageLabel.numberOfLines = 0
    messageLabel.textAlignment = .center
    messageLabel.sizeToFit()
    self.tableView.backgroundView = messageLabel
    
    /**
     *  Register event listeners before initializing monkey
     */
    
    //register listener for changes in the socket connection
    NotificationCenter.default.addObserver(self, selector: #selector(self.handleConnectionChange), name: NSNotification.Name.MonkeySocketStatusChange, object: nil)
    
    //register listener for incoming messages
    NotificationCenter.default.addObserver(self, selector: #selector(self.messageReceived(_:)), name: NSNotification.Name.MonkeyMessage, object: nil)
    
    //register listener for message acknowledges
    NotificationCenter.default.addObserver(self, selector: #selector(self.acknowledgeReceived(_:)), name: NSNotification.Name.MonkeyAcknowledge, object: nil)
    
    //register listener for notifications
    NotificationCenter.default.addObserver(self, selector: #selector(self.notificationReceived(_:)), name: NSNotification.Name.MonkeyNotification, object: nil)
    
    //register listener for create group event
    NotificationCenter.default.addObserver(self, selector: #selector(self.createGroup(_:)), name: NSNotification.Name.MonkeyGroupCreate, object: nil)
    
    //register listener for add member to group event
    NotificationCenter.default.addObserver(self, selector: #selector(self.addMember(_:)), name: NSNotification.Name.MonkeyGroupAdd, object: nil)
    
    //register listener for remove member from group event
    NotificationCenter.default.addObserver(self, selector: #selector(self.removeMember(_:)), name: NSNotification.Name.MonkeyGroupRemove, object: nil)
    
    //register listener for list of groups I belong to
    NotificationCenter.default.addObserver(self, selector: #selector(self.groupList(_:)), name: NSNotification.Name.MonkeyGroupCreate, object: nil)
    
    //register listener for opens
    NotificationCenter.default.addObserver(self, selector: #selector(self.openReceived(_:)), name: NSNotification.Name.MonkeyConversationOpen, object: nil)
    
    //register listener for acknowledges of opens I do
    NotificationCenter.default.addObserver(self, selector: #selector(self.openResponseReceived(_:)), name: NSNotification.Name.MonkeyConversationStatus, object: nil)
    
    /**
     *  Load initial conversations
     */
    self.conversationArray = DBManager.getConversations(nil, count: 10)
    if !self.conversationArray.isEmpty {
      for conversation in self.conversationArray{
        self.conversationHash[conversation.conversationId] = conversation
      }
    }
    self.updateConversationList()
    
    /**
     *  Initialize Monkey
     */
    
    let user = ["name":"",
                "monkeyId": ""]
    
    let ignoredParams = ["password"]
    
    Monkey.sharedInstance().initWithApp(self.appID,
                                        secret: self.appSecret,
                                        user: user,
                                        ignoredParams: ignoredParams,
                                        expireSession: false,
                                        debugging: true,
                                        autoSync: true,
                                        lastTimestamp: nil,
                                        success: { (session) in
                                          print(session)
                                          
                                          // push
                                          if #available(iOS 10.0, *) {
                                            //you need to import the UserNotifications framework
                                            UNUserNotificationCenter.current().requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
                                              // Enable or disable features based on authorization.
                                            }
                                          } else {
                                            // Fallback on earlier versions
                                            let settings = UIUserNotificationSettings(types: [UIUserNotificationType.badge, UIUserNotificationType.alert, UIUserNotificationType.sound], categories: nil)
                                            UIApplication.shared.registerUserNotificationSettings(settings)
                                          }
                                          UIApplication.shared.registerForRemoteNotifications()
                                          
                                      
                                          //
                                          if self.conversationArray.count == 0 {
                                            self.getConversations(0)
                                          }
      },
                                        failure: {(task, error) in
                                          print(error.localizedDescription)
    })
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    self.updateConversationList()
    
    guard let index = self.tableView.indexPathsForVisibleRows?.first else {
      //hide search bar on empty list
      self.tableView.setContentOffset(CGPoint(x: 0, y: 44), animated: false)
      return
    }
    
    if ((index as NSIndexPath).row == 0 && !self.searchController.isActive) {
      //hide search bar if the first row is visible
      self.tableView.setContentOffset(CGPoint(x: 0, y: 44), animated: false)
    }
  }
  
  deinit {
    //for iOS 8
    NotificationCenter.default.removeObserver(self)
  }
  
  //MARK: TableView DataSource
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if self.searchController.isActive {
      return self.filteredConversationArray.count
    }
    return conversationArray.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
    var conversation:MOKConversation!
    if self.searchController.isActive {
      conversation = self.filteredConversationArray[indexPath.row]
    }else{
      conversation = self.conversationArray[indexPath.row]
    }
    let cell = tableView.dequeueReusableCell(withIdentifier: "ChatViewCell", for: indexPath) as! ChatViewCell
    
    //set highlighted state
    cell.nameLabel.highlightedTextColor = UIColor.black
    cell.dateLabel.highlightedTextColor = UIColor.gray
    cell.previewLabel.highlightedTextColor = UIColor.gray
    
    //set initial state of cell
    cell.previewLabel.isHidden = false
    cell.previewLabel.textColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
    cell.previewLabel.highlightedTextColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
    
    cell.dateLabel.isHidden = false
    cell.dateLabel.textColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
    cell.dateLabel.highlightedTextColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
    
    cell.moreImageView.isHidden = false
    cell.badgeContainerView.isHidden = true
    cell.doveImageView.image = nil
    cell.previewOffsetConstraint.constant = 0
    cell.badgeWidthConstraint.constant = 20
    
    //setting current values
    
    cell.nameLabel.text = conversation.info.object(forKey: "name") as? String ?? "Unknown"
    cell.avatarImageView.sd_setImage(with: conversation.getAvatarURL(), placeholderImage: self.defaultAvatar)
    
    if conversation.unread > 0 {
      cell.badgeContainerView.isHidden = false
      cell.dateLabel.textColor = UIColor(red: 0.0/255, green: 122.0/255, blue: 255.0/255, alpha: 1)
      cell.dateLabel.highlightedTextColor = UIColor(red: 0.0/255, green: 122.0/255, blue: 255.0/255, alpha: 1)
      cell.badgeLabel.text = String(conversation.unread)
      
      if conversation.unread > 9 {
        cell.badgeWidthConstraint.constant = 25
      }
      
      if conversation.unread > 99 {
        cell.badgeWidthConstraint.constant = 30
      }
    }
    
    guard let lastMessage = conversation.lastMessage else {
      cell.dateLabel.text = ""
      cell.moreImageView.isHidden = true
      cell.previewLabel.text = conversation.isGroup() ? "Write to this Group" : "Write to this Contact"
      
      return cell
    }
    
    cell.dateLabel.text = lastMessage.relativeDate()
    
    var previewText = lastMessage.preview()
    
    //message is outgoing
    if Monkey.sharedInstance().isMessageOutgoing(lastMessage) {
      if lastMessage.wasSent() {
        cell.previewOffsetConstraint.constant = 18
        cell.doveImageView.image = self.sentDove
      } else {
        previewText = "Sending: \(previewText)"
      }
    }
    
    if lastMessage.needsResend() {
      previewText = "Failed to send"
      cell.previewLabel.textColor = UIColor.red
      cell.previewLabel.highlightedTextColor = UIColor.red
    }
    
    cell.previewLabel.text = previewText
    
    return cell
  }
  
  //MARK: TableView Delegate
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
    let vc = ChatViewController()
    
    var conversation:MOKConversation!
    if self.searchController.isActive {
      conversation = self.filteredConversationArray[indexPath.row]
    }else{
      conversation = self.conversationArray[indexPath.row]
    }
    
    //set all messages to read
    conversation.unread = 0
    DBManager.store(conversation)
    
    vc.conversation = conversation
    self.navigationController?.pushViewController(vc, animated: true)
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 75.5
  }
  
  override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    if self.searchController.isActive {
      return
    }
    
    guard let lastConv = self.conversationArray.last else {
      return
    }
    
    let conv = self.conversationArray[indexPath.row]
    
    if conv === lastConv {
      guard let lastMessage = lastConv.lastMessage , lastMessage.timestampCreated > 0 else {
        self.getConversations(lastConv.lastModified)
        return
      }
      self.getConversations(lastMessage.timestampCreated)
    }
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    if self.searchController.isActive {
      return false
    }
    return true
  }
  
  override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
    let conversation = self.conversationArray[indexPath.row]
    
    let title = conversation.isGroup() ? "Exit Group" : "Delete"
    
    let deleteAction = UITableViewRowAction(style: .default, title: title) { (action, indexPath) in
      
      let sheetTitle = conversation.isGroup() ? "Delete and exit group \(conversation.info["name"] ?? "Unknown")?" : "Delete conversation with \(conversation.info["name"] ?? "Unknown")?"
      let alert = UIAlertController(title: sheetTitle, message: nil, preferredStyle: .actionSheet)
      
      alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: { action in
        tableView.setEditing(false, animated: true)
      }))
      
      if conversation.isGroup() {
        alert.addAction(UIAlertAction(title:"Delete and Exit", style: .destructive, handler: { action in
          
          Monkey.sharedInstance().removeMember(Monkey.sharedInstance().monkeyId()!, group: conversation.conversationId, success: { (data) in
            self.conversationHash.removeValue(forKey: conversation.conversationId)
            self.conversationArray.remove(at: indexPath.row)
            DBManager.delete(conversation)
            
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .none)
            tableView.endUpdates()
            }, failure: { (task, error) in
              let errorAlert = UIAlertController(title: "There was an error deleting the conversations, please try again later", message: nil, preferredStyle: .alert)
              let okButton = UIAlertAction(title: "Ok", style: .default, handler: nil)
              
              errorAlert.addAction(okButton)
              
              self.present(errorAlert, animated: true, completion: nil)
          })
          
        }))
      } else {
        alert.addAction(UIAlertAction(title:"Delete", style: .destructive, handler: { action in
          Monkey.sharedInstance().deleteConversation(conversation.conversationId, success: { (data) in
            self.conversationHash.removeValue(forKey: conversation.conversationId)
            self.conversationArray.remove(at: indexPath.row)
            DBManager.delete(conversation)
            
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .none)
            tableView.endUpdates()
            }, failure: { (data, error) in
              let errorAlert = UIAlertController(title: "There was an error deleting the conversations, please try again later", message: nil, preferredStyle: .alert)
              let okButton = UIAlertAction(title: "Ok", style: .default, handler: nil)
              
              errorAlert.addAction(okButton)
              
              self.present(errorAlert, animated: true, completion: nil)
          })
        }))
      }
      self.present(alert, animated: true, completion: nil)
    }
    
    deleteAction.backgroundColor = .red
    
    return [deleteAction]
  }
  
  func updateConversationList() {
    self.sortConversations()
    self.tableView.reloadData()
  }
  
}

//MARK: SearchController Delegate
extension ConversationsListViewController: UISearchResultsUpdating {
  func filterContentForSearchText(_ text:String) {
    
    if text == "" {
      self.filteredConversationArray = self.conversationArray
    }else{
      self.filteredConversationArray = self.conversationArray.filter({ (conversation) -> Bool in
        
        let conversationName = conversation.info["name"] as? String ?? "Unknown"
        return conversationName.lowercased().contains(text.lowercased())
      })
    }
    
    self.tableView.reloadData()
  }
  
  func updateSearchResults(for searchController: UISearchController) {
    self.filterContentForSearchText(searchController.searchBar.text!)
  }
}

extension ConversationsListViewController: UISearchControllerDelegate {
  func willPresentSearchController(_ searchController: UISearchController) {
    self.filteredConversationArray = self.conversationArray
    self.tableView.reloadData()
  }
  
  func didPresentSearchController(_ searchController: UISearchController) {
  }
  
  func willDismissSearchController(_ searchController: UISearchController) {
    self.filteredConversationArray = []
  }
}

//MARK: Connection delegate
extension ConversationsListViewController {
  
  func handleConnectionChange(_ notification:Foundation.Notification){
    
    let text:String
    let color:UIColor
    var action:WhisperAction = .present
    
    //handle connection changes
    switch ((notification as NSNotification).userInfo!["status"] as! NSNumber).uint32Value{
    case MOKConnectionStateDisconnected.rawValue:
      print("disconnected")
      
      text = "Disconnected"
      color = .red
      
      break
    case MOKConnectionStateConnecting.rawValue:
      print("connecting")
      
      text = "Connecting"
      color = UIColor(red:1.00, green:0.60, blue:0.00, alpha:1.0)
      
      break
    case MOKConnectionStateConnected.rawValue:
      print("connected")
      
      text = "Connected"
      color = UIColor(red:0.26, green:0.60, blue:0.22, alpha:1.0)
      
      action = .show
      
      break
    case MOKConnectionStateNoNetwork.rawValue:
      print("no network")
      text = "No Network"
      color = .black
      
      break
    default:
      fatalError()
    }
    
    guard let whisper = self.getWhisper() else {
      let notif = Message(title: text, textColor: UIColor.white, backgroundColor: color, images: nil)
      Whisper.show(whisper: notif, to: self.navigationController!, action: action)
      return
    }
    
    self.update(whisper: whisper, text: text, color: color, action: action)
  }
  
  func update(whisper:WhisperView, text:String, color:UIColor, action:WhisperAction) {
    UIView.animate(withDuration: 0.5, animations: {
      whisper.titleLabel.text = text
      let heightOriginal = whisper.titleLabel.frame.size.height
      whisper.titleLabel.sizeToFit()
      whisper.titleLabel.frame.size.height = heightOriginal
      whisper.backgroundColor = color
    })
    
    if action == .show {
      hide(whisperFrom: self.navigationController!, after: 1.0)
    }
    
  }
  
  func getWhisper() -> WhisperView? {
    var whisperView:WhisperView!
    
    for subview in self.navigationController!.navigationBar.subviews {
      if let whisper = subview as? WhisperView {
        whisperView = whisper
        break
      }
    }
    
    return whisperView
  }
  
  func showInAppNotification(_ title:String?, avatarUrl:URL, description:String) {
    if self.isViewLoaded && (self.view.window != nil) {
      let view = UIImageView()
      view.sd_setImage(with: avatarUrl)
      
      let announcement = Announcement(title: title ?? "Notification", subtitle: description, image: view.image, duration: 2.0, action: {
        print("finish presenting! \(description)")
      })
      
      Whisper.show(shout: announcement, to: self.navigationController!)
    }
  }
}

//MARK: Monkey socket messages
extension ConversationsListViewController {
  func messageReceived(_ notification:Foundation.Notification){
    //do nothing if there's no valid message
    guard let userInfo = (notification as NSNotification).userInfo, let message = userInfo["message"] as? MOKMessage else {
      return
    }
    
    // validate if the message conversation is open
    if let cv = self.navigationController?.topViewController as? ChatViewController {
      if cv.conversation.conversationId == message.conversationId(Monkey.sharedInstance().monkeyId()){
        return
      }
    }
    
    // validate if message exists
    if DBManager.existsMessage(message.messageId, oldId: message.oldMessageId!) {
      return
    }
    
    // save message
    DBManager.store(message)
    
    //check if conversation is already created
    let conversationId = message.conversationId(Monkey.sharedInstance().monkeyId())
    var conversation = self.conversationHash[conversationId]
    if (conversation == nil){
      conversation = DBManager.getConversation(conversationId)
      if(conversation != nil){
        self.conversationHash[conversationId] = conversation
        self.conversationArray.append(conversation!)
      }
    }
    
    guard conversation != nil else { //create conversation if it doesn't exist
      createConversation(conversationId, message: message)
      return
    }
    
    conversation?.lastMessage = message
    if !Monkey.sharedInstance().isMessageOutgoing(message) {
      conversation!.unread += 1
      
      //Show In-app notification
      showInAppNotification(conversation?.info["name"] as! String? , avatarUrl: (conversation?.getAvatarURL())!, description: message.preview())
    }
    
    DBManager.store(conversation!)
    self.updateConversationList()
    
  }
  
  func acknowledgeReceived(_ notification:Foundation.Notification){
    guard let acknowledge = (notification as NSNotification).userInfo else {
      return
    }
    
    // get message to update id
    guard let oldId = acknowledge["oldId"] as? String,
      let newId = acknowledge["newId"] as? String else {
        return
    }
    
    //Multisession - Request pending messages if it's not cached
    guard DBManager.existsMessage(newId, oldId: oldId) else {
      Monkey.sharedInstance().getPendingMessages()
      return
    }

    //update local message
    DBManager.updateMessage(newId, oldId: oldId)

    // get message to update id
    guard let conversation = self.conversationHash[acknowledge["conversationId"] as! String],
      let lastMessage = conversation.lastMessage
      , lastMessage.messageId == oldId else {
        //nothing to do
        return
    }
    
    lastMessage.messageId = newId
    lastMessage.oldMessageId = oldId
    
    // update last message
    DBManager.store(conversation)
    
    self.tableView.reloadData()
  }
  
  func notificationReceived(_ notification:Foundation.Notification){
    guard let userInfo = (notification as NSNotification).userInfo, let params = userInfo["notification"] else {
      return
    }
    
    print(params)
  }
  
  func openReceived(_ notification:Foundation.Notification){
    let message = (notification as NSNotification).userInfo!["message"]
    
    print(message)
  }
  
  func openResponseReceived(_ notification:Foundation.Notification){
    let message = (notification as NSNotification).userInfo!["message"]
    
    print(message)
  }
  
  func createGroup(_ notification:Foundation.Notification){
    let message = (notification as NSNotification).userInfo!["message"]
    
    print(message)
  }
  
  func addMember(_ notification:Foundation.Notification){
    let message = (notification as NSNotification).userInfo!["message"]
    
    print(message)
  }
  
  func removeMember(_ notification:Foundation.Notification){
    let message = (notification as NSNotification).userInfo!["message"]
    
    print(message)
  }
  
  func groupList(_ notification:Foundation.Notification){
    let message = (notification as NSNotification).userInfo!["message"]
    
    print(message)
  }
}

//MARK: MonkeyChat
extension ConversationsListViewController {

  // Conversation
  func getConversations(_ from:Double) {
    
    if self.isGettingConversations && !self.shouldRequestConversations {
      return
    }
    
    self.isGettingConversations = true
    let conversations = DBManager.getConversations(self.conversationArray.last, count: 10)
    
    // Load from local database
    if !conversations.isEmpty {
      let delayTime = DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
      DispatchQueue.main.asyncAfter(deadline: delayTime) {
        for conversation in conversations {
          //do not replace if the conversation already exists
          if let conv = self.conversationHash[conversation.conversationId] {
            conv.info = conversation.info
            conv.members = conversation.members
          }else{
            self.conversationHash[conversation.conversationId] = conversation
            self.conversationArray.append(conversation)
          }
        }
        self.tableView?.reloadData()
        self.isGettingConversations = false
      }
      return
    }
    
    // Load from monkey store
    Monkey.sharedInstance().getConversationsSince(from, quantity: 5, success: { (conversations) in
      var idUsers = Set<String>()
      for conversation in conversations {
        
        // define last message
        if(conversation.lastMessage?.messageId == ""){
          conversation.lastMessage = nil
        }else{
          DBManager.store(conversation.lastMessage!)
        }
        
        //do not replace if the conversation already exists
        if ((self.conversationHash[conversation.conversationId]) == nil) {
          self.conversationArray.append(conversation)
        }
        self.conversationHash[conversation.conversationId] = conversation
        
        idUsers.formUnion(Set(conversation.members as NSArray as! [String]))
        DBManager.store(conversation)
      }
      
      let unknownUsers = DBManager.monkeyIdsNotStored(idUsers)
      if !unknownUsers.isEmpty {
        Monkey.sharedInstance().getInfoByIds(unknownUsers, success: { (users) in
          DBManager.store(users)
          }, failure: { (task, error) in
            print(error)
        })
      }
      
      if !conversations.isEmpty {
        self.tableView?.reloadData()
      }
      
      self.isGettingConversations = false
      
      self.refreshControl?.endRefreshing()
      }, failure: { (task, error) in
        self.isGettingConversations = false
        self.refreshControl?.endRefreshing()
        print(error)
    })
  }
  
  func createConversation(_ conversationId:String ,message:MOKMessage) {
    let conversation = MOKConversation(id: conversationId)
    
    guard let user = DBManager.getUser(conversationId) else {
      //user doesn't exist
      Monkey.sharedInstance().getInfo(conversationId, success: { (info) in
        if ((conversationId.range(of: "G:")) == nil) { // user
          let newUser = MOKUser.init(id: info["monkeyId"] as! String, info: NSMutableDictionary(dictionary: info))
          DBManager.store(newUser)
          conversation.members = [message.sender, message.recipient]
        }else{
          conversation.members = info["members"] as! NSMutableArray
          
          var idUsers = Set<String>()
          idUsers.formUnion(Set(conversation.members as NSArray as! [String]))
          let unknownUsers = DBManager.monkeyIdsNotStored(idUsers)
          if !unknownUsers.isEmpty {
            Monkey.sharedInstance().getInfoByIds(unknownUsers, success: { (users) in
              DBManager.store(users)
              }, failure: { (task, error) in
                print(error)
            })
          }
        }
        
        conversation.info = NSMutableDictionary(dictionary: info)
        conversation.lastMessage = message
        conversation.lastSeen = 0
        conversation.lastModified = message.timestampCreated
        conversation.unread = Monkey.sharedInstance().isMessageOutgoing(message) ? 0 : 1
        
        self.conversationArray.append(conversation)
        self.conversationHash[conversationId] = conversation
        DBManager.store(conversation)
        
        if !Monkey.sharedInstance().isMessageOutgoing(message) {
          
          //Show In-app notification
          self.showInAppNotification(conversation.info["name"] as! String?, avatarUrl: conversation.getAvatarURL(), description: message.preview())
        }
        
        self.updateConversationList()
        
        }, failure: { (task, error) in
          print(error)
      })
      return
    }
    
    conversation.info = (user.info!)
    conversation.members = [message.sender, message.recipient]
    conversation.lastMessage = message
    conversation.lastSeen = 0
    conversation.lastModified = message.timestampCreated
    conversation.unread = Monkey.sharedInstance().isMessageOutgoing(message) ? 0 : 1
    
    self.conversationArray.append(conversation)
    self.conversationHash[conversationId] = conversation
    DBManager.store(conversation)
    
    if !Monkey.sharedInstance().isMessageOutgoing(message) {
      
      //Show In-app notification
      showInAppNotification(conversation.info["name"] as! String?, avatarUrl: conversation.getAvatarURL(), description: message.preview())
    }
    
    self.updateConversationList()
  }
 
  func sortConversations() {
    self.conversationArray.sort { (conv1, conv2) -> Bool in
      
      let time1 = conv1.lastMessage?.timestampCreated ?? conv1.lastModified
      let time2 = conv2.lastMessage?.timestampCreated ?? conv2.lastModified

      return time1 > time2
    }
  }
  
  func handleTableRefresh(){
    self.getConversations(0)
  }
}

class ChatViewCell: UITableViewCell {
  @IBOutlet weak var avatarImageView: UIImageView!
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var dateLabel: UILabel!
  @IBOutlet weak var doveImageView: UIImageView!
  @IBOutlet weak var previewLabel: UILabel!
  @IBOutlet weak var badgeContainerView: UIView!
  @IBOutlet weak var badgeLabel: UILabel!
  @IBOutlet weak var moreImageView: UIImageView!
  @IBOutlet weak var badgeWidthConstraint: NSLayoutConstraint!
  @IBOutlet weak var previewOffsetConstraint: NSLayoutConstraint!
  
  override func setHighlighted(_ highlighted: Bool, animated: Bool) {
    super.setHighlighted(highlighted, animated: animated)
    self.badgeContainerView.backgroundColor = UIColor(red:0.04, green:0.38, blue:1.00, alpha:1.0)
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    self.badgeContainerView.backgroundColor = UIColor(red:0.04, green:0.38, blue:1.00, alpha:1.0)
  }
}

extension UIFont {
  
  //This is used for making unread messages bold
  
  func withTraits(_ traits: UIFontDescriptorSymbolicTraits...) -> UIFont {
    let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
    return UIFont(descriptor: descriptor!, size: 0)
  }
  
  func bold() -> UIFont {
    return withTraits(.traitBold)
  }
  
}
