## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2024-05-18 - [Fix Missing ScreenCaptureGuard on Private Key Input]
**Vulnerability:** The private key input screen was missing `ScreenCaptureGuard`, exposing user private keys to being screenshotted or recorded while typed or pasted.
**Learning:** `ScreenCaptureGuard` was implemented for `ImportSecretPhraseScreen` but not for `ImportPrivateKeyScreen`. When building sensitive inputs, one must explicitly guard both screenshots and memory captures using this custom platform channel wrapper in the view lifecycle.
**Prevention:** Make sure `ScreenCaptureGuard` is explicitly injected and managed through `initState` and `dispose` on any view containing private key or seed phrase materials.
