## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## $(date +%Y-%m-%d) - [Missing ScreenCaptureGuard on ImportPrivateKeyScreen]
**Vulnerability:** The private key input screen (`ImportPrivateKeyScreen`) was missing the `ScreenCaptureGuard` which meant the private key was vulnerable to screenshots, screen recordings, or background app preview captures by the OS.
**Learning:** All screens handling highly sensitive credentials like private keys must initialize `ScreenCaptureGuard` during their state lifecycle and enable protection on `initState` while disabling it on `dispose`.
**Prevention:** Make sure any new screen created for handling sensitive info automatically implements and triggers the `ScreenCaptureGuard`.
