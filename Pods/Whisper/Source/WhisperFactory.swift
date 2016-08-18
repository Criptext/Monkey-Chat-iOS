import UIKit

public enum WhisperAction: String {
  case Present = "Whisper.PresentNotification"
  case Show = "Whisper.ShowNotification"
}

let whisperFactory: WhisperFactory = WhisperFactory()

class WhisperFactory: NSObject {

  struct AnimationTiming {
    static let movement: NSTimeInterval = 0.3
    static let switcher: NSTimeInterval = 0.1
    static let popUp: NSTimeInterval = 1.5
    static let loaderDuration: NSTimeInterval = 0.7
    static let totalDelay: NSTimeInterval = popUp + movement * 2
  }

  weak var navigationController: UINavigationController?
  var edgeInsetHeight: CGFloat = 0
  var whisperView: WhisperView!
  var delayTimer = NSTimer()
  var presentTimer = NSTimer()
  var navigationStackCount = 0

  // MARK: - Initializers

  override init() {
    super.init()
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(WhisperFactory.orientationDidChange), name: UIDeviceOrientationDidChangeNotification, object: nil)
  }

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
  }

  func craft(message: Message, navigationController: UINavigationController, action: WhisperAction) {
    self.navigationController = navigationController
    self.navigationController?.delegate = self
    presentTimer.invalidate()

    var containsWhisper = false
    for subview in navigationController.navigationBar.subviews {
      if let whisper = subview as? WhisperView {
        whisperView = whisper
        containsWhisper = true
        break
      }
    }

    if !containsWhisper {
      whisperView = WhisperView(height: navigationController.navigationBar.frame.height, message: message)
      whisperView.frame.size.height = 0
      var maximumY = navigationController.navigationBar.frame.height

      whisperView.transformViews.forEach {
        $0.frame.origin.y = -10
        $0.alpha = 0
      }

      for subview in navigationController.navigationBar.subviews {
        if subview.frame.maxY > maximumY && subview.frame.height > 0 { maximumY = subview.frame.maxY }
      }

      whisperView.frame.origin.y = maximumY
      navigationController.navigationBar.addSubview(whisperView)
    }

    if containsWhisper {
      changeView(message, action: action)
    } else {
      switch action {
      case .Present:
        presentView()
      case .Show:
        showView()
      }
    }
  }

  func silentWhisper(controller: UINavigationController, after: NSTimeInterval) {
    self.navigationController = controller
    guard let navigationController = self.navigationController else { return }
    
    var whisperSubview: WhisperView? = nil
    for subview in navigationController.navigationBar.subviews {
      if let whisper = subview as? WhisperView {
        whisperSubview = whisper
        break
      }
    }

    if whisperSubview == nil {
        return
    }

    whisperView = whisperSubview
    delayTimer.invalidate()
    delayTimer = NSTimer.scheduledTimerWithTimeInterval(after, target: self,
      selector: #selector(WhisperFactory.delayFired(_:)), userInfo: nil, repeats: false)
  }

  // MARK: - Presentation

  func presentView() {
    moveControllerViews(true)

    UIView.animateWithDuration(AnimationTiming.movement, animations: {
      self.whisperView.frame.size.height = WhisperView.Dimensions.height
      for subview in self.whisperView.transformViews {
        subview.frame.origin.y = 0

        if subview == self.whisperView.complementImageView {
          subview.frame.origin.y = (WhisperView.Dimensions.height - WhisperView.Dimensions.imageSize) / 2
        }

        subview.alpha = 1
      }
    })
  }

  func showView() {
    moveControllerViews(true)

    UIView.animateWithDuration(AnimationTiming.movement, animations: {
      self.whisperView.frame.size.height = WhisperView.Dimensions.height
      for subview in self.whisperView.transformViews {
        subview.frame.origin.y = 0

        if subview == self.whisperView.complementImageView {
          subview.frame.origin.y = (WhisperView.Dimensions.height - WhisperView.Dimensions.imageSize) / 2
        }

        subview.alpha = 1
      }
      }, completion: { _ in
        self.delayTimer = NSTimer.scheduledTimerWithTimeInterval(1.5, target: self,
          selector: #selector(WhisperFactory.delayFired(_:)), userInfo: nil, repeats: false)
    })
  }

  func changeView(message: Message, action: WhisperAction) {
    presentTimer.invalidate()
    delayTimer.invalidate()
    hideView()

    let title = message.title
    let textColor = message.textColor
    let backgroundColor = message.backgroundColor
    let action = action.rawValue

    var array = ["title": title, "textColor" : textColor, "backgroundColor": backgroundColor, "action": action]
    if let images = message.images { array["images"] = images }

    presentTimer = NSTimer.scheduledTimerWithTimeInterval(AnimationTiming.movement * 1.1, target: self,
      selector: #selector(WhisperFactory.presentFired(_:)), userInfo: array, repeats: false)
  }

  func hideView() {
    moveControllerViews(false)

    UIView.animateWithDuration(AnimationTiming.movement, animations: {
      self.whisperView.frame.size.height = 0
      for subview in self.whisperView.transformViews {
        subview.frame.origin.y = -10
        subview.alpha = 0
      }
      }, completion: { _ in
        self.whisperView.removeFromSuperview()
    })
  }

  // MARK: - Timer methods

  func delayFired(timer: NSTimer) {
    hideView()
  }

  func presentFired(timer: NSTimer) {
    guard let navigationController = self.navigationController,
      userInfo = timer.userInfo,
      title = userInfo["title"] as? String,
      textColor = userInfo["textColor"] as? UIColor,
      backgroundColor = userInfo["backgroundColor"] as? UIColor,
      actionString = userInfo["action"] as? String else { return }

    var images: [UIImage]? = nil

    if let imageArray = userInfo["images"] as? [UIImage]? { images = imageArray }

    let action = WhisperAction(rawValue: actionString)
    let message = Message(title: title, textColor: textColor, backgroundColor: backgroundColor, images: images)

    whisperView = WhisperView(height: navigationController.navigationBar.frame.height, message: message)
    navigationController.navigationBar.addSubview(whisperView)
    whisperView.frame.size.height = 0

    var maximumY = navigationController.navigationBar.frame.height

    for subview in navigationController.navigationBar.subviews {
      if subview.frame.maxY > maximumY && subview.frame.height > 0 { maximumY = subview.frame.maxY }
    }

    whisperView.frame.origin.y = maximumY

    action == .Present ? presentView() : showView()
  }

  // MARK: - Animations

  func moveControllerViews(down: Bool) {
    guard let navigationController = self.navigationController,
        visibleController = navigationController.visibleViewController
      where Config.modifyInset
      else { return }

    let stackCount = navigationController.viewControllers.count

    if down {
      navigationStackCount = stackCount
    } else if navigationStackCount != stackCount {
      return
    }

    if !(edgeInsetHeight == WhisperView.Dimensions.height && down) {
      edgeInsetHeight = down ? WhisperView.Dimensions.height : -WhisperView.Dimensions.height

      UIView.animateWithDuration(AnimationTiming.movement, animations: {
        self.performControllerMove(visibleController)
      })
    }
  }

  func performControllerMove(viewController: UIViewController) {
    guard Config.modifyInset else { return }

    if let tableView = viewController.view as? UITableView
      where viewController is UITableViewController {
        tableView.contentInset = UIEdgeInsetsMake(tableView.contentInset.top + edgeInsetHeight, tableView.contentInset.left, tableView.contentInset.bottom, tableView.contentInset.right)
    } else if let collectionView = viewController.view as? UICollectionView
      where viewController is UICollectionViewController {
        collectionView.contentInset = UIEdgeInsetsMake(collectionView.contentInset.top + edgeInsetHeight, collectionView.contentInset.left, collectionView.contentInset.bottom, collectionView.contentInset.right)
    } else {
      for view in viewController.view.subviews {
        if let scrollView = view as? UIScrollView {
          scrollView.contentInset = UIEdgeInsetsMake(scrollView.contentInset.top + edgeInsetHeight, scrollView.contentInset.left, scrollView.contentInset.bottom, scrollView.contentInset.right)
        }
      }
    }
  }

  // MARK: - Handling screen orientation

  func orientationDidChange() {
    guard let navigationController = self.navigationController else { return }
    for subview in navigationController.navigationBar.subviews {
      guard let whisper = subview as? WhisperView else { continue }

      var maximumY = navigationController.navigationBar.frame.height
      for subview in navigationController.navigationBar.subviews where subview != whisper {
        if subview.frame.maxY > maximumY && subview.frame.height > 0 { maximumY = subview.frame.maxY }
      }

      whisper.frame = CGRect(
        x: whisper.frame.origin.x,
        y: maximumY,
        width: UIScreen.mainScreen().bounds.width,
        height: whisper.frame.size.height)
      whisper.setupFrames()
    }
  }
}

// MARK: UINavigationControllerDelegate

extension WhisperFactory: UINavigationControllerDelegate {

  func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
    var maximumY = navigationController.navigationBar.frame.maxY - UIApplication.sharedApplication().statusBarFrame.height

    for subview in navigationController.navigationBar.subviews {
      if subview is WhisperView { navigationController.navigationBar.bringSubviewToFront(subview) }

      if subview.frame.maxY > maximumY && !(subview is WhisperView) {
        maximumY = subview.frame.maxY
      }
    }

    whisperView.frame.origin.y = maximumY
  }

  func navigationController(navigationController: UINavigationController, didShowViewController viewController: UIViewController, animated: Bool) {

    for subview in navigationController.navigationBar.subviews where subview is WhisperView {
      moveControllerViews(true)

      if let index = navigationController.viewControllers.indexOf(viewController) where index > 0 {
        edgeInsetHeight = -WhisperView.Dimensions.height
        performControllerMove(navigationController.viewControllers[Int(index) - 1])
        break
      }
    }
  }
}
