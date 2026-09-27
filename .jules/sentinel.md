## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-18 - [Fix Missing Screen Protection on Private Key Input]
**Vulnerability:** The `ImportPrivateKeyScreen` allowed screenshots and screen recordings while the user was pasting or typing raw private keys.
**Learning:** Raw cryptographic secrets must be protected at the OS level from screenshot or screen recording capture. While other sensitive screens (like `ImportSecretPhraseScreen`) used the app's `ScreenCaptureGuard` utility, this screen omitted it, introducing an inconsistency and an exposure risk.
**Prevention:** All screens that handle raw cryptographic secrets (e.g., importing seed phrases, private keys, revealing secrets) must implement `ScreenCaptureGuard` upon initialization (`enableProtection`) and clean up upon disposal (`disableProtection`).
