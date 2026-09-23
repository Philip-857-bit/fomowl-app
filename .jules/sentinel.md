## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-20 - [Add Screen Capture Protection]
**Vulnerability:** Private key input screens were vulnerable to being recorded or screenshot, compromising sensitive user data.
**Learning:** `ScreenCaptureGuard` was missing on the `ImportPrivateKeyScreen`. This protection is crucial for any screen that handles raw sensitive inputs like private keys or seed phrases.
**Prevention:** Ensure that `ScreenCaptureGuard.enableProtection()` and `disableProtection()` are consistently used in the `initState` and `dispose` methods (wrapped in `unawaited`) of any screen dealing with highly sensitive data.
