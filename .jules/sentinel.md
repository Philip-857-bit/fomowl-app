## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-18 - [Missing Screen Capture Protection]
**Vulnerability:** The import private key screen lacked screen capture protection, allowing screenshots and screen recordings to capture sensitive private keys.
**Learning:** ScreenCaptureGuard must be applied consistently across all screens handling sensitive credentials (e.g. private keys, seed phrases) to prevent unauthorized capture.
**Prevention:** Always verify that `ScreenCaptureGuard.enableProtection()` is called in `initState` and `disableProtection()` in `dispose` for any screen that inputs or displays sensitive credentials.
