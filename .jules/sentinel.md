## 2024-05-18 - [Screen Capture Protection on Private Key Import]
**Vulnerability:** The `ImportPrivateKeyScreen` allowed users to input their sensitive private key without protection against screenshots and screen recordings.
**Learning:** This codebase uses a custom `ScreenCaptureGuard` to protect sensitive UI screens. It must be explicitly initialized and its protection enabled/disabled in the `initState` and `dispose` lifecycle methods of any screen dealing with sensitive data like private keys or seed phrases.
**Prevention:** Always verify if a screen handling sensitive input (passwords, private keys, seed phrases) uses `ScreenCaptureGuard`.
