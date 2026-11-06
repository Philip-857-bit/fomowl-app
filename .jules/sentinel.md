## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2024-05-24 - [Secure Authentication Input Fields]
**Vulnerability:** The login and register profile screens accepted sensitive credentials (passwords, x-secrets) without screen capture protections or explicitly clearing the text field memory upon disposal.
**Learning:** Even standard authentication screens require defense-in-depth measures against malware or shoulder-surfing. The `ScreenCaptureGuard` should be utilized. Additionally, sensitive `TextEditingController` text values must be explicitly cleared to drop references early in the disposal cycle, limiting the time material remains in memory.
**Prevention:** All authentication screens accepting credentials must implement the `ScreenCaptureGuard` lifecycle properly in `initState` and `dispose`, and explicitly clear contents of controllers associated with sensitive inputs (e.g., `controller.text = ''`) before disposing them.
