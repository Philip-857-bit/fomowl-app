## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2024-11-13 - [Enable ScreenCaptureGuard protection globally]
**Vulnerability:** The `ScreenCaptureGuard` master switch `protectionEnabled` was temporarily set to `false`, leaving all otherwise-protected screens vulnerable to screenshots and recording, even when they invoked `enableProtection()`.
**Learning:** Hardcoding a false master toggle for temporary operational needs (like taking tutorial videos) can accidentally be pushed to main, neutralizing screen capture protections application-wide.
**Prevention:** Always verify that `ScreenCaptureGuard.protectionEnabled` is set to `true` in production code. Temporary debug or demo toggles should ideally rely on build flavors or runtime environment flags rather than hardcoded booleans in the service class.
