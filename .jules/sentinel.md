## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2025-02-28 - [Add ScreenCaptureGuard for ImportPrivateKeyScreen]
**Vulnerability:** The screen to import private keys `ImportPrivateKeyScreen` lacked protection against screen captures and screenshots.
**Learning:** Sensitive credential inputs should be protected at the platform level (using iOS secure text / Android secure flag). The codebase has a custom platform channel service `ScreenCaptureGuard` created specifically for this purpose.
**Prevention:** Make sure screens dealing with highly sensitive user data like seed phrases or private keys use the `ScreenCaptureGuard` correctly in their lifecycles.
