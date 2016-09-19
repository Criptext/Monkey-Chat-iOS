//
//  User.swift
//  MonkeyChat
//
//  Created by Gianni Carlo on 5/31/16.
//  Copyright © 2016 Criptext. All rights reserved.
//

import RealmSwift

class User: Object {
    dynamic var monkeyId = ""
    var info = List<SimpleInfo>()
    
    override static func primaryKey() -> String? {
        return "monkeyId"
    }
}

class SimpleInfo: Object {
    dynamic var key = ""
    dynamic var value = ""
}

class StringObject: Object {
    dynamic var value: String?
}