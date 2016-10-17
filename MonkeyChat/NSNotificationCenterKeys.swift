//
//  NSNotificationCenterKeys.swift
//  MonkeyChat
//
//  Created by Erika Perugachi on 10/14/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

import Foundation

let prefix = "com.monkeychat."

extension Notification.Name {

  public struct MonkeyChat {

    public static let MessageSent = Notification.Name(rawValue: prefix + "messageSent")
  }
}
