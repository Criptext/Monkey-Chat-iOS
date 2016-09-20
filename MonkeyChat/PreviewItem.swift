//
//  PreviewItem.swift
//  MonkeyChat
//
//  Created by Gianni Carlo on 8/25/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

import Foundation
import QuickLook

class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
    var previewItemTitle: String?
    
    init (title:String?, url:URL){
        self.previewItemURL = url
        self.previewItemTitle = title
    
    }
}
