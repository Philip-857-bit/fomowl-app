## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-06-25 - [Enable ScreenCaptureGuard for Modals]
**Vulnerability:** Private key modal in `WalletsScreen` lacked screenshot protection, and the global `ScreenCaptureGuard` flag was disabled.
**Learning:** When displaying sensitive info (like a private key) via a modal bottom sheet, `ScreenCaptureGuard` must be enabled. Because modals can be dismissed via swipes or taps outside, `disableProtection()` must be guaranteed to run via a `try/finally` block around `showModalBottomSheet`. The global master switch must also be enabled for production.
**Prevention:** Always wrap sensitive `showModalBottomSheet` invocations in `try/finally` using `ScreenCaptureGuard`.
