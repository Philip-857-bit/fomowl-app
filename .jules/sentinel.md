## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2024-05-18 - [Secure Verify Phrase Screen Input]
**Vulnerability:** The seed phrase verification screen (`VerifyPhraseScreen`) displayed the input words in plaintext, relying solely on `TextInputType.visiblePassword` without toggling `obscureText: true`.
**Learning:** `TextInputType.visiblePassword` alone is insufficient to prevent shoulder-surfing. Sensitive inputs need `obscureText` coupled with `maxLines: 1`. Additionally, when using `dart format .` it is easy to accidentally affect third-party code like `rust_builder` making the PR dirty. Be careful when staging and run `git status`/`git diff` to confirm.
**Prevention:** Always ensure `TextField` inputs dealing with mnemonic phrases initialize with `obscureText: true` and only stage the files related to the security fix.
