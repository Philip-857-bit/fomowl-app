## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2024-05-18 - [Fix Screen Capture Guard]
**Vulnerability:** Global screen capture protection (`ScreenCaptureGuard`) was completely disabled, and `ImportPrivateKeyScreen` lacked the protection implementation.
**Learning:** Hardcoded variables for development/recording purposes (`protectionEnabled = false`) left the app critically vulnerable to screenshot/screen-recording attacks on highly sensitive keys.
**Prevention:** Ensure `ScreenCaptureGuard` is enabled in production and systematically integrated into the `initState` and `dispose` lifecycle of any screen exposing seed phrases or private keys.
