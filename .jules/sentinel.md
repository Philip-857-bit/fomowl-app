## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2024-05-24 - [Auth Profile Screen Capture Guard]
**Vulnerability:** The login and register screens in the profile tab accepted sensitive credentials (password, x-secret) but lacked screen capture protection and did not clear controller text before disposal, risking exposure to malicious apps and memory scraping.
**Learning:** `ScreenCaptureGuard` was applied inconsistently across the app. Not all screens collecting sensitive inputs were protected. Additionally, text controllers holding secrets weren't consistently cleared before disposal.
**Prevention:** Ensure all screens processing sensitive credentials (passwords, secrets) utilize `ScreenCaptureGuard` (enabled in `initState`, disabled in `dispose`) and explicitly clear `TextEditingController` text before calling `dispose()`.
