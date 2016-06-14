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

/**
 *  ViewController that lists your conversations
 *  
 *  It shows the name of the conversation and its last message
 */

class ConversationsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView?
    var conversations = [Conversation]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /**
         *  Hides empty cells
         */
        tableView?.tableFooterView = UIView()
        
        /**
         *  Load conversations from DB
         */
        self.conversations = getConversations()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView?.reloadData()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let conversationController = segue.destinationViewController as? ChatViewController, row = sender as? Int {
            let conversation = conversations[row]
            conversationController.conversation = conversation
        }
    }
    
    //MARK: TableView DataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as? ConversationTableViewCell else {
            return UITableViewCell()
        }
        
        let conversation = self.conversations[indexPath.row]
        
        cell.nameLabel.text = conversation.name
        
        /**
         *  Setup preview of last message
         */
        
        // Don't show preview if there's no last message
        guard let lastMessage = conversation.messages.last else {
            return cell
        }
        
        var previewText:String!
        
        switch lastMessage.media {
        case is JSQPhotoMediaItem:
            previewText = "Image"
        case is JSQLocationMediaItem:
            previewText = "Location"
        case is JSQVideoMediaItem:
            previewText = "Video"
        case is JSQAudioMediaItem:
            previewText = "Audio"
        default:
            previewText = lastMessage.text
            break
        }
        
        /**
         *  Show name of sender if it's a group
         *  You can have a validation to check if the last message is yours to prefix it with `Me:`
         */
        if conversation.isGroup {
            previewText = "\(lastMessage.senderDisplayName): \(previewText)"
        }
        
        cell.recentTextLabel.text = previewText

        return cell
    }
    
    //MARK: TableView Delegate
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        performSegueWithIdentifier("ConversationSegue", sender: indexPath.row)
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 80
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