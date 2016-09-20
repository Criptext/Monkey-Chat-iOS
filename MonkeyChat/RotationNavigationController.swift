//
//  RotationNavigationController.swift
//  MonkeyChat
//
//  Created by Gianni Carlo on 9/12/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

import UIKit

class RotationNavigationController: UINavigationController {
    
    var lockAutorotate = false
    
    override var shouldAutorotate : Bool {
        return !self.lockAutorotate
    }
}
