import UserNotifications
import FirebaseMessaging

/// Notification Service Extension that lets rich (image) push notifications
/// display on iOS. FCM delivers the image URL from the message's
/// `notification.image` field; FirebaseMessaging downloads it and attaches it
/// to the notification content here.
///
/// Requirements (see ios/NotificationService/SETUP.md):
///   - This file must belong to a "Notification Service Extension" target.
///   - The push payload must include `mutable-content: 1` (FCM sets this
///     automatically when an image is present).
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent =
      request.content.mutableCopy() as? UNMutableNotificationContent

    guard let bestAttemptContent = bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    // FirebaseMessaging fetches the image referenced by the FCM payload and
    // attaches it to the notification, then calls the content handler.
    Messaging.serviceExtension().populateNotificationContent(
      bestAttemptContent,
      withContentHandler: contentHandler
    )
  }

  override func serviceExtensionTimeWillExpire() {
    // The system is about to terminate the extension; deliver whatever we have.
    if let contentHandler = contentHandler,
      let bestAttemptContent = bestAttemptContent
    {
      contentHandler(bestAttemptContent)
    }
  }
}
