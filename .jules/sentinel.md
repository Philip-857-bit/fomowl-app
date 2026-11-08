## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2026-10-15 - [Security Theater in Dispose Methods]
**Vulnerability:** Clearing string variables explicitly inside widget `dispose()` methods (like `_passwordController.text = ''` or `_passcode = ''`) is considered "security theater" and introduces side effects like accidentally triggering `ChangeNotifier` listeners during widget unmounting (causing `FlutterError`).
**Learning:** In Dart, strings are immutable so assigning a new empty string does not remove the existing cryptographic secret from heap memory. Therefore, mutating sensitive `ChangeNotifier` variables during `dispose` does not add real security and degrades stability.
**Prevention:** Avoid mutating `TextEditingController`s during `dispose` in an attempt to clear memory. Stick to simply invoking `dispose()` to let the garbage collector reclaim the memory natively.
