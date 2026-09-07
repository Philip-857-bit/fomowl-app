## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-18 - [Screen Capture Protection on Sensitive Inputs]
**Vulnerability:** The private key import screen (`ImportPrivateKeyScreen`) was missing the `ScreenCaptureGuard` which meant the private key could be captured by screenshots or screen recording while it was being entered/pasted or when toggled visible.
**Learning:** In Flutter, sensitive screens should actively disable screenshots. The `ScreenCaptureGuard` was applied to other onboarding screens but missed on this one.
**Prevention:** Make sure all screens that handle sensitive information (like seed phrases, private keys, passwords) instantiate `ScreenCaptureGuard` and call `enableProtection()` in `initState()` and `disableProtection()` in `dispose()`.
