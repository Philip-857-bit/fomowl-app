## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2026-10-08 - [Verify Phrase Input Visibility]
**Vulnerability:** The seed phrase verification input fields on the verify phrase screen were visible in plain text.
**Learning:** Text fields accepting sensitive information (like verifying the backup of a seed phrase) only used `keyboardType: TextInputType.visiblePassword`. This is insufficient and still allows shoulder-surfing. They must use `obscureText: true`. Setting `obscureText` dynamically requires ensuring `maxLines` is set to `1` as Flutter doesn't support multiline obscured text.
**Prevention:** Always verify that `obscureText: true` is set for all text fields taking sensitive inputs (seed phrases, passwords, keys) and include a toggle if appropriate.
