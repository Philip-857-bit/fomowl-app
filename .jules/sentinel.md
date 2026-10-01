## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-10-24 - [Missing Screen Capture Guard on Private Key Screen]
**Vulnerability:** The private key import screen lacked `ScreenCaptureGuard` protection, allowing private keys to be exposed to screenshots and screen recordings.
**Learning:** `ScreenCaptureGuard` must be explicitly implemented on every screen that handles highly sensitive credentials.
**Prevention:** Ensure that all views handling private keys or seed phrases include `ScreenCaptureGuard` lifecycle management in `initState` and `dispose`.
