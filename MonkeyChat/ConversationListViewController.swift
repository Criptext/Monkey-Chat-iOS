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
import JSQMessagesViewController
import MonkeyKit
import SDWebImage

/**
 *  ViewController that lists your conversations
 *  
 *  It shows the name of the conversation and its last message
 */

class ConversationsListViewController: UITableViewController {
    
    var conversationHash = [String:Conversation]()
    var conversationArray = [Conversation]()
    
    var filteredConversationArray = [Conversation]()
    
    let searchController = UISearchController(searchResultsController: nil)
    let defaultAvatar = UIImage(named: "Profile_imgDefault.png")
    let readDove = UIImage(named: "check-blue-icon.png")
    let sentDove = UIImage(named: "check-grey-icon.png")
    
    let dateFormatter = NSDateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /**
         *  Hides empty cells
         */
        self.tableView.tableFooterView = UIView()
        
        //fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge.None
        
        self.navigationController?.view.backgroundColor = UIColor.whiteColor()
        
        self.dateFormatter.timeStyle = .ShortStyle
        self.dateFormatter.dateStyle = .NoStyle
        self.dateFormatter.doesRelativeDateFormatting = true
        
        //configure search bar
        self.searchController.searchResultsUpdater = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.searchController.delegate = self
        self.definesPresentationContext = true
        
        self.tableView.tableHeaderView = self.searchController.searchBar
        self.edgesForExtendedLayout = UIRectEdge.All
        self.extendedLayoutIncludesOpaqueBars = true
        
        //configure refresh control
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor(red:0.93, green:0.93, blue:0.93, alpha:1.0)
        self.refreshControl?.addTarget(self, action: #selector(self.handleTableRefresh), forControlEvents: .ValueChanged)
        
        let messageLabel = UILabel(frame: CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height))
        
        messageLabel.text = "No conversations are currently available. Please pull down to refresh."
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .Center
        messageLabel.sizeToFit()
        
        self.tableView.backgroundView = messageLabel
        
        /**
         *  Register event listeners before initializing monkey
         */
        
        //register listener for initial regitration ok
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.monkeyRegisterOK(_:)), name: MonkeyRegistrationDidCompleteNotification, object: nil)
        //register listener for initial registration fail
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.monkeyRegisterFail(_:)), name: MonkeyRegistrationDidFailNotification, object: nil)
        
        //register listener for changes in the socket connection
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.handleConnectionChange(_:)), name: MonkeySocketStatusChangeNotification, object: nil)
        
        //register listener for incoming messages
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.messageReceived(_:)), name: MonkeyMessageNotification, object: nil)
        
        //register listener for message acknowledges
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.acknowledgeReceived(_:)), name: MonkeyAcknowledgeNotification, object: nil)
        
        //register listener for notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.notificationReceived(_:)), name: MonkeyNotificationNotification, object: nil)
        
        //register listener for create group event
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.createGroup(_:)), name: MonkeyGroupCreateNotification, object: nil)
        
        //register listener for add member to group event
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.addMember(_:)), name: MonkeyGroupAddNotification, object: nil)
        
        //register listener for remove member from group event
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.removeMember(_:)), name: MonkeyGroupRemoveNotification, object: nil)
        
        //register listener for list of groups I belong to
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.groupList(_:)), name: MonkeyGroupCreateNotification, object: nil)
        
        //register listener for opens
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.openReceived(_:)), name: MonkeyOpenNotification, object: nil)
        
        //register listener for acknowledges of opens I do
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.openResponseReceived(_:)), name: MonkeyConversationStatusNotification, object: nil)
        
        /**
         *  Initialize Monkey
         */
        
        Monkey.sharedInstance().initWithApp("idkgwf6ghcmyfvvrxqiwwmi",
                                            secret: "9da5bbc32210ed6501de82927056b8d2",
                                            user: ["name":"Gianni",
                                                "monkeyId":"idkh61jqs9ia151u7edhd7vi"],
                                            expireSession: false,
                                            debugging: true,
                                            autoSync: true,
                                            lastTimestamp: nil)
        
        /**
         *  Load conversations
         */
        
        self.conversationArray = DBManager.getConversations()
        
        //
        if self.conversationArray.count == 0 {
            self.getConversations(0)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView?.reloadData()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let conversationController = segue.destinationViewController as? ChatViewController, row = sender as? Int {
            let conversation = conversationArray[row]
            conversationController.conversation = conversation
        }
    }
    
    deinit {
        //for iOS 8
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func handleTableRefresh(){
        self.getConversations(0)
    }
    
    func getConversations(from:Double) {
        Monkey.sharedInstance().getConversationsSince(from, quantity: 5, success: { (conversations) in
            for conversation in conversations as! [[String:AnyObject]] {
                
                let idConv = conversation["id"] as! String
                let info = conversation["info"] as? [String:String] ?? [:]
                let members = conversation["members"] as? [String] ?? [idConv]
                let message = conversation["last_message"] as! MOKMessage
                let lastSeen = Double(conversation["last_seen"]?.integerValue ?? 0)
                let lastModified = Double(conversation["last_modified"]?.integerValue ?? 0)
                let unread = conversation["unread"]?.unsignedLongLongValue ?? 0
                
                var conv = self.conversationHash[idConv]
                
                //do not replace if the conversation already exists
                if let conv = conv {
                    conv.info = info
                    conv.members = members
                }else{
                
                    conv = Conversation(id: idConv,
                        info: info,
                        members: members,
                        lastMessage: message,
                        lastSeen: lastSeen,
                        lastModified:  lastModified,
                        unread: unread)
                    
                    self.conversationHash[conv!.id] = conv!
                    self.conversationArray.append(conv!)
                }
                
                
            }
            
            if conversations.count > 0 {
                self.tableView?.reloadData()
            }
            
            self.refreshControl?.endRefreshing()
            }, failure: { (task, error) in
                self.refreshControl?.endRefreshing()
                print(error)
        })
    }
    
    func sortConversations() {
        self.conversationArray.sortInPlace { (conv1, conv2) -> Bool in
            if let lastMsg1 = conv1.lastMessage, lastMsg2 = conv2.lastMessage {
                return lastMsg1.timestampCreated > lastMsg2.timestampCreated
            }
            return conv1.lastModified > conv2.lastModified
        }
    }
    
    //MARK: TableView DataSource
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.searchController.active {
            return self.filteredConversationArray.count
        }
        return conversationArray.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var conversation:Conversation!
        if self.searchController.active {
            conversation = self.filteredConversationArray[indexPath.row]
        }else{
            conversation = self.conversationArray[indexPath.row]
        }
        let cell = tableView.dequeueReusableCellWithIdentifier("ChatViewCell", forIndexPath: indexPath) as! ChatViewCell
        
        //set highlighted state
        cell.nameLabel.highlightedTextColor = UIColor.blackColor()
        cell.dateLabel.highlightedTextColor = UIColor.grayColor()
        cell.previewLabel.highlightedTextColor = UIColor.grayColor()
        
        //set initial state of cell
        cell.previewLabel.hidden = false
        cell.previewLabel.textColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
        cell.previewLabel.highlightedTextColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
        
        cell.dateLabel.hidden = false
        cell.dateLabel.textColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
        cell.dateLabel.highlightedTextColor = UIColor(red: 142.0/255, green: 142.0/255, blue: 147.0/255, alpha: 1)
        
        cell.moreImageView.hidden = false
        cell.badgeContainerView.hidden = true
        cell.doveImageView.image = nil
        cell.previewOffsetConstraint.constant = 0
        cell.badgeWidthConstraint.constant = 20
        
        //setting current values
        
        cell.nameLabel.text = conversation.info["name"] ?? "Unknown"
        cell.avatarImageView.sd_setImageWithURL(conversation.getAvatarURL(), placeholderImage: self.defaultAvatar)
        
        if conversation.unread > 0 {
            cell.badgeContainerView.hidden = false
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
            cell.moreImageView.hidden = true
            cell.previewLabel.text = conversation.isGroup ? "Write to this Group" : "Write to this Contact"
            
            return cell
        }
        
        cell.dateLabel.text = lastMessage.relativeDate()
        cell.previewLabel.text = lastMessage.plainText
        
        
        //message is outgoing
        if Monkey.sharedInstance().isMessageOutgoing(lastMessage) {
            if lastMessage.wasSent() {
                cell.previewOffsetConstraint.constant = 18
                cell.doveImageView.image = self.sentDove
            } else {
                cell.previewLabel.text = "Sending"
            }
        }
        
        if !lastMessage.wasSent() && Monkey.sharedInstance().isMessageOutgoing(lastMessage) {
            cell.previewLabel.text = "Sending"
        }
        
        if lastMessage.needsResend() {
            cell.previewLabel.text = "Fail to send"
            cell.previewLabel.textColor = UIColor.redColor()
            cell.previewLabel.highlightedTextColor = UIColor.redColor()
        }

        return cell
    }
    
    //MARK: TableView Delegate
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let vc = ChatViewController()
        
        var conversation:Conversation!
        if self.searchController.active {
            conversation = self.filteredConversationArray[indexPath.row]
        }else{
            conversation = self.conversationArray[indexPath.row]
        }
        
        //set all messages to read
        conversation.unread = 0
        
        vc.conversation = conversation
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 75.5
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if self.searchController.active {
            return
        }
        
        guard let lastConv = self.conversationArray.last else {
            return
        }
        
        let conv = self.conversationArray[indexPath.row]
        
        if conv === lastConv {
            guard let lastMessage = lastConv.lastMessage where lastMessage.timestampCreated > 0 else {
                print(lastConv.lastMessage!.timestampCreated)
                self.getConversations(lastConv.lastModified)
                return
            }
            print(lastMessage.timestampCreated)
            self.getConversations(lastMessage.timestampCreated)
        }
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if self.searchController.active {
            return false
        }
        return true
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let conversation = self.conversationArray[indexPath.row]
        
        let title = conversation.isGroup ? "Exit Group" : "Delete"
        
        let deleteAction = UITableViewRowAction(style: .Default, title: title) { (action, indexPath) in
            
            let sheetTitle = conversation.isGroup ? "Delete and exit group \(conversation.info["name"] ?? "Unknown")?" : "Delete conversation with \(conversation.info["name"] ?? "Unknown")?"
            let alert = UIAlertController(title: sheetTitle, message: nil, preferredStyle: .ActionSheet)
            
            alert.addAction(UIAlertAction(title: "Cancelar", style: .Cancel, handler: { action in
                tableView.setEditing(false, animated: true)
            }))
            
            if conversation.isGroup {
                alert.addAction(UIAlertAction(title:"Delete and Exit", style: .Destructive, handler: { action in
                    
                    Monkey.sharedInstance().removeMember(Monkey.sharedInstance().monkeyId()!, group: conversation.id, success: { (data) in
                        self.conversationArray.removeAtIndex(indexPath.row)
                        
                        tableView.beginUpdates()
                        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                        tableView.endUpdates()
                        }, failure: { (task, error) in
                            let errorAlert = UIAlertController(title: "There was an error deleting the conversations, please try again later", message: nil, preferredStyle: .Alert)
                            let okButton = UIAlertAction(title: "Ok", style: .Default, handler: nil)
                            
                            errorAlert.addAction(okButton)
                            
                            self.presentViewController(errorAlert, animated: true, completion: nil)
                    })
                    
                }))
            } else {
                alert.addAction(UIAlertAction(title:"Delete", style: .Destructive, handler: { action in
                    Monkey.sharedInstance().deleteConversation(conversation.id, success: { (data) in
                        self.conversationArray.removeAtIndex(indexPath.row)
                        
                        tableView.beginUpdates()
                        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                        tableView.endUpdates()
                        }, failure: { (data, error) in
                            let errorAlert = UIAlertController(title: "There was an error deleting the conversations, please try again later", message: nil, preferredStyle: .Alert)
                            let okButton = UIAlertAction(title: "Ok", style: .Default, handler: nil)
                            
                            errorAlert.addAction(okButton)
                            
                            self.presentViewController(errorAlert, animated: true, completion: nil)
                    })
                }))
            }
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        deleteAction.backgroundColor = UIColor.redColor()
        
        return [deleteAction]
    }
}

//MARK: SearchController Delegate
extension ConversationsListViewController: UISearchResultsUpdating {
    func filterContentForSearchText(text:String) {
        
        if text == "" {
            self.filteredConversationArray = self.conversationArray
        }else{
            self.filteredConversationArray = self.conversationArray.filter({ (conversation) -> Bool in
                
                let conversationName = conversation.info["name"] ?? "Unknown"
                return conversationName.lowercaseString.containsString(text.lowercaseString)
            })
        }
        
        self.tableView.reloadData()
    }
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        self.filterContentForSearchText(searchController.searchBar.text!)
    }
}

extension ConversationsListViewController: UISearchControllerDelegate {
    func willPresentSearchController(searchController: UISearchController) {
        self.filteredConversationArray = self.conversationArray
        self.tableView.reloadData()
    }
    
    func didPresentSearchController(searchController: UISearchController) {
    }
    
    func willDismissSearchController(searchController: UISearchController) {
        self.filteredConversationArray = []
    }
}

//MARK: Connection delegate
extension ConversationsListViewController {
    func monkeyRegisterOK(notification:NSNotification) {
        //here returns the session
        print(notification.userInfo)
    }
    
    func monkeyRegisterFail(notification:NSNotification) {
        //handle error
        print(notification.userInfo)
    }
    
    func handleConnectionChange(notification:NSNotification){
        //handle connection changes
        switch (notification.userInfo!["status"] as! NSNumber).unsignedIntValue{
        case MOKConnectionStateDisconnected.rawValue:
            print("disconnected")
            break
        case MOKConnectionStateConnected.rawValue:
            print("connected")
            break
        case MOKConnectionStateConnecting.rawValue:
            print("connecting")
            break
        case MOKConnectionStateNoNetwork.rawValue:
            print("no network")
            break
        default:
            break
        }
    }
}

//MARK: Monkey socket messages
extension ConversationsListViewController {
    func messageReceived(notification:NSNotification){
        guard let userInfo = notification.userInfo, message = userInfo["message"] as? MOKMessage else {
            return
        }
        
        var conversation = self.conversationHash[message.conversationId()]
        
        if conversation == nil {
            
            conversation = Conversation(id: message.conversationId(), info: [:], members: [message.sender, message.recipient], lastMessage: message, lastSeen: 0, lastModified: message.timestampCreated, unread: 1)
            self.conversationArray.append(conversation!)
            self.conversationHash[message.conversationId()] = conversation
        }
        
        
        conversation!.lastMessage = message
        
        if !Monkey.sharedInstance().isMessageOutgoing(message) {
            conversation!.unread += 1
        }
        
        self.sortConversations()
        self.tableView.reloadData()
        
        
        print(message)
    }
    
    func acknowledgeReceived(notification:NSNotification){
        
        guard let acknowledge = notification.userInfo else {
            return
        }
        
        print(acknowledge)
    }
    
    func notificationReceived(notification:NSNotification){
        guard let userInfo = notification.userInfo, params = userInfo["notification"] else {
            return
        }
        
        print(params)
    }
    
    func openReceived(notification:NSNotification){
        let message = notification.userInfo!["message"]
        
        print(message)
    }
    
    func openResponseReceived(notification:NSNotification){
        let message = notification.userInfo!["message"]
        
        print(message)
    }
    
    func createGroup(notification:NSNotification){
        let message = notification.userInfo!["message"]
        
        print(message)
    }
    
    func addMember(notification:NSNotification){
        let message = notification.userInfo!["message"]
        
        print(message)
    }
    
    func removeMember(notification:NSNotification){
        let message = notification.userInfo!["message"]
        
        print(message)
    }
    
    func groupList(notification:NSNotification){
        let message = notification.userInfo!["message"]
        
        print(message)
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
    
    override func setHighlighted(highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        self.badgeContainerView.backgroundColor = UIColor(red:0.04, green:0.38, blue:1.00, alpha:1.0)
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.badgeContainerView.backgroundColor = UIColor(red:0.04, green:0.38, blue:1.00, alpha:1.0)
    }
}

extension UIFont {
    
    //This is used for making unread messages bold
    
    func withTraits(traits: UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor().fontDescriptorWithSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor, size: 0)
    }
    
    func bold() -> UIFont {
        return withTraits(.TraitBold)
    }
    
}