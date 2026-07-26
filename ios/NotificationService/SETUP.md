# iOS Notification Service Extension - wiring steps

This folder contains the source for an iOS **Notification Service Extension**
that lets rich (image) push notifications display on iOS. The Swift handler and
`Info.plist` are ready; the extension **target** must be created in Xcode
because adding a target + the "Embed App Extensions" build phase cannot be done
safely by hand-editing `project.pbxproj`.

> Android needs nothing extra - images already render via the FCM
> `notification.image` field. This is only required for **iOS**.

## One-time setup (on a Mac with Xcode)

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File ▸ New ▸ Target… ▸ Notification Service Extension.**
   - Product Name: `NotificationService`
   - Language: Swift
   - When prompted to activate the scheme, choose **Cancel** (not required).
   - Xcode creates a `NotificationService` group with its own
     `NotificationService.swift` and `Info.plist`.
3. **Replace** Xcode's generated `NotificationService.swift` and `Info.plist`
   with the two files in this folder (they use FirebaseMessaging to download
   and attach the image). Easiest: delete Xcode's generated two files (move to
   trash) and drag in the files from `ios/NotificationService/`, making sure
   **Target Membership = NotificationService**.
4. Set the extension's **Deployment Target** to match Runner (or lower) and its
   **Bundle Identifier** to `<your.app.bundle.id>.NotificationService`.
5. Add the FirebaseMessaging pod to the extension. In `ios/Podfile`, add a
   target block (outside the `Runner` block):

   ```ruby
   target 'NotificationService' do
     use_frameworks!
     pod 'Firebase/Messaging'
   end
   ```

   Then run `cd ios && pod install`.
6. Build & run on a real device (rich pushes don't show in the simulator).

## Verifying

Send a push with an image (admin endpoint):

```
POST /api/blockchain/{chainId}/admin/broadcast-push
{ "title": "Hello", "message": "Tap to view", "imageUrl": "https://your-cdn/banner.png" }
```

- The backend already sets the FCM `notification.image` field, and FCM adds
  `mutable-content: 1` for iOS automatically when an image is present.
- With the extension installed, the image appears in the expanded notification
  on iOS. Without it, iOS shows a normal (text) notification - no crash.
