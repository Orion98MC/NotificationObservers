import Foundation

private struct ReferableObserver {
  var notifierID: UInt?
  var notificationName: String
  var observerID: UInt?
  var notificationObserver: NSObjectProtocol

  init(notifier: AnyObject?, notificationName: String, observer: AnyObject?, notificationObserver: NSObjectProtocol) {
    if let notifier = notifier { notifierID = ObjectIdentifier(notifier).uintValue }
    if let observer = observer { observerID = ObjectIdentifier(observer).uintValue }
    self.notificationName = notificationName
    self.notificationObserver = notificationObserver
  }
}

extension ReferableObserver: Equatable {}
private func ==(lhs: ReferableObserver, rhs: ReferableObserver) -> Bool {
  return lhs.notificationObserver === rhs.notificationObserver
}

public struct NotificationObservers {

  private static let syncQueue = dispatch_queue_create("com.notification-observers.serial", DISPATCH_QUEUE_SERIAL)
  private static var observers = [ReferableObserver]()

  public static func storeObserver(notifier notifier: AnyObject?, notificationName: String, observer: AnyObject?, notificationObserver: NSObjectProtocol) {
    let observer = ReferableObserver(notifier: notifier, notificationName: notificationName, observer: observer, notificationObserver: notificationObserver)
    dispatch_async(syncQueue) { () -> Void in
      self.observers.append(observer)
    }
  }

  public static func removeObservers(notifier: AnyObject?, notificationName: String?, observer: AnyObject?) {
    let removables = observers.filter { (referable) -> Bool in

      if let notifier = notifier, referableNotifier = referable.notifierID {
        if ObjectIdentifier(notifier).uintValue != referableNotifier { return false }
      }

      if let notificationName = notificationName {
        if notificationName != referable.notificationName { return false }
      }

      if let observer = observer, referableObserver = referable.observerID {
        if ObjectIdentifier(observer).uintValue != referableObserver { return false }
      }

      return true
    }

    for removable in removables {
      NSNotificationCenter.defaultCenter().removeObserver(removable.notificationObserver)
      dispatch_sync(syncQueue, { () -> Void in
        self.observers.removeAtIndex(observers.indexOf(removable)!)
        // print("remove observer: \(removable)")
      })
    }

  }

  public static var count: Int { return observers.count }
}

protocol Observable {}
extension Observable where Self: AnyObject {
  func addObserverForName(name: String, observer: AnyObject? = nil, queue: NSOperationQueue? = nil, handler: (NSNotification) -> Void) {
    let notificationObserver = NSNotificationCenter.defaultCenter().addObserverForName(name, object: self, queue: queue, usingBlock: handler)
    NotificationObservers.storeObserver(notifier: self, notificationName: name, observer: observer, notificationObserver: notificationObserver)
  }

  func postNotification(notification: NSNotification) {
    NSNotificationCenter.defaultCenter().postNotification(notification)
  }

  func postNotificationName(name: String, userInfo: [NSObject : AnyObject]? = nil) {
    NSNotificationCenter.defaultCenter().postNotificationName(name, object: self, userInfo: userInfo)
  }

  func removeObservers() {
    NotificationObservers.removeObservers(self, notificationName: nil, observer: nil)
  }
}

protocol ObservableObserver {}
extension ObservableObserver where Self: AnyObject {
  func stopObserving(object: AnyObject? = nil, notificationName: String? = nil) {
    NotificationObservers.removeObservers(object, notificationName: notificationName, observer: self)
  }
}

/* 
  
  Example Usage:
  ==============
  
  
  class Foo: Observable {
    func foo() {
      postNotificationName("FOO")
    }

    deinit {
      removeObservers()
    }
  }

  struct Bar {
    init(foo: Foo) {
      foo.addObserverForName("FOO") { (note) -> Void in
        print("Got Fooed!")
      }
    }
  }


do {
  var foo = Foo()
  var bar = Bar(foo: foo)


  foo.foo() // => "Got Fooed!"

  NotificationObservers.count // # => 1
}

NotificationObservers.count   // # => 0

*/