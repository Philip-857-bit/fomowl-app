## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2026-10-25 - [Profile Screen Capture Protection]
**Vulnerability:** LoginProfileScreen and RegisterProfileScreen accepted sensitive credentials like passwords and X-Secrets without screen capture and recording protection enabled.
**Learning:** In Flutter mobile applications handling sensitive identity features, `ScreenCaptureGuard` must be universally applied across all screens processing credentials to defend against background screen recording or malicious accessibility services. The guard must be enabled on `initState` and properly disabled on `dispose` to avoid unintentionally blocking screenshots on harmless screens later in the navigation stack.
**Prevention:** Any new onboarding or profile screens requesting sensitive secrets must implement `ScreenCaptureGuard` lifecycle methods using `unawaited()`.
