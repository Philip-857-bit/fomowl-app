## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2026-10-02 - [Remove Security Theater on String Clearing]
**Vulnerability:** Pseudo-security logic was found where immutable strings were being cleared manually (e.g. `controller.text = ''` or `word[i] = ''`) in `dispose` methods of screens handling secrets.
**Learning:** Dart strings are immutable. Reassigning a variable does not securely wipe the original string from memory; it only updates the reference and waits for garbage collection. This provides a false sense of security (security theater).
**Prevention:** Avoid writing explicit logic to clear strings in Dart. Instead, simply call `dispose()` on controllers and allow the garbage collector to handle memory cleanup. If true memory wiping is required, strings cannot be used and native memory must be accessed via FFI.
