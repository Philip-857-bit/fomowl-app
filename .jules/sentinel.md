## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-10-01 - [Import Private Key Screen Capture Guard]
**Vulnerability:** The private key input screen lacked screen capture protection, potentially exposing sensitive cryptographic keys to background recording or malicious applications.
**Learning:** Found that some screens dealing with sensitive inputs used `ScreenCaptureGuard` while others did not. The correct pattern involves wrapping async enablement and disablement calls in `unawaited` inside `initState` and `dispose` lifecycle methods respectively.
**Prevention:** Always ensure any new or existing screens accepting sensitive information (private keys, mnemonics) instantiate and properly manage the `ScreenCaptureGuard` lifecycle.
## 2024-05-24 - [Obscure Text in Verify Phrase Screen]
**Vulnerability:** The seed phrase verification screen (`VerifyPhraseScreen`) displayed the input words in plain text by default, which is a shoulder-surfing risk when entering a sensitive recovery phrase. While it set `keyboardType: TextInputType.visiblePassword`, it did not use `obscureText: true`.
**Learning:** `TextInputType.visiblePassword` is a hint for the OS keyboard layout, but it does not tell Flutter to visually hide the characters (i.e. replacing with asterisks or dots). `obscureText` must be used explicitly. Additionally, Flutter requires `maxLines: 1` when `obscureText: true`.
**Prevention:** All text fields accepting sensitive credentials (keys, passcodes, seed phrases) must default to `obscureText: true` with a visibility toggle, ensuring `maxLines` handles the single-line constraint appropriately.
