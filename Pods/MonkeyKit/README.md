# MonkeyKit

[![CI Status](http://img.shields.io/travis/Criptext/Monkey-SDK-iOS.svg?style=flat)](https://travis-ci.org/Criptext/Monkey-SDK-iOS)
[![Version](https://img.shields.io/cocoapods/v/MonkeyKit.svg?style=flat)](http://cocoapods.org/pods/MonkeyKit)
[![License](https://img.shields.io/cocoapods/l/MonkeyKit.svg?style=flat)](http://cocoapods.org/pods/MonkeyKit)
[![Platform](https://img.shields.io/cocoapods/p/MonkeyKit.svg?style=flat)](http://cocoapods.org/pods/MonkeyKit)

# Getting Started

## Playground
Monkey comes with a playground if you download the SDK as a `zip` file. It will let you test basic functionality such as sending messages and images between two Monkey Ids.

## Installation (Cocoapods)
MonkeyKit is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'MonkeyKit'
```


### Initializing Monkey

#####Swift
Import Monkey and initialize it
```swift
import MonkeyKit

class MyController {
    let AppId = "<Get your App Id from the Admin console>"
    let AppSecret = "<Get your App secret from the Admin console>"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Define user metadata
        let user = ["name":"Gianni",
        "password": "53CR3TP455W0RD"]
        
        //You can start Monkey with a Monkey Id
        user["monkeyId"] = "<placeholder>"
        
        //Define user metadata ignored params
        let ignoredParams = ["password"]
        
        /**
         *  Register listener to events regarding connection status changes
         */
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.handleConnectionChange(_:)), name: MonkeySocketStatusChangeNotification, object: nil)
        
        /**
         *  Register listener to events regarding incoming messages
         */
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.messageReceived(_:)), name: MonkeyMessageNotification, object: nil)
        
        /**
         *  Initialize Monkey
         */
        
        Monkey.sharedInstance().initWithApp("idkgwf6ghcmyfvvrxqiwwmi",
                                            secret: "9da5bbc32210ed6501de82927056b8d2",
                                            user: user,
                                            ignoredParams: ignoredParams,
                                            expireSession: false,
                                            debugging: true,
                                            autoSync: true,
                                            lastTimestamp: nil,
                                            success: { (session) in
                                              //print Monkey's current session
                                              print(session)
            },
                                            failure: {(task, error) in
                                            print(error.localizedDescription)
        })
    }
}
```

- You can register in our [Admin Panel](https://admin.criptext.com) to get your App key and App secret of your app.
- You can define your own user metadata with whichever parameters you want. If you already have a monkey Id that you want to reuse, just define in your metadata a key `monkeyId` with the value.
- You can prevent Monkey from storing sensitive user information by sending an array of keys to ignore from the user metadata.
- If you're not reusing a monkey id, you can define if the monkey id generated is temporal or not.
- If you want to see all the logs that monkey prints, set debugging to true.
- To request your pending messages automatically every time you connect to our server, set autoSync to true.

### Sending messages when you are connected

```swift
extenstion MyClass {
    func handleConnectionChange(notification:NSNotification){
        //handle connection changes
        switch (notification.userInfo!["status"] as! NSNumber).unsignedIntValue{
        case MOKConnectionStateDisconnected.rawValue:
            print("disconnected")
            
            break
        case MOKConnectionStateConnecting.rawValue:
            print("connecting")
            break
        case MOKConnectionStateConnected.rawValue:
            print("connected")
            //send test message
            let recipientId = "Other Monkey Id"
            Monkey.sharedInstance().sendText("Hello World!", toUser: recipientId)
            break
        case MOKConnectionStateNoNetwork.rawValue:
            print("no network")

            break
        default:
            break
        }
    }
}
```

The other user will receive the message listening to this event `MonkeyMessageNotification`
```swift
extension MyClass {
    func messageReceived(notification:NSNotification){
        guard let userInfo = notification.userInfo, message = userInfo["message"] as? MOKMessage else {
            return
        }
        print(message.sender)
        print(message.recipient)
        print(message.plainText)
    }
}
```

## Author

Criptext Inc, gianni@criptext.com

## License

MonkeyKit is available under the Apache v2.0 license. See the LICENSE file for more info.