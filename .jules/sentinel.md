## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2026-09-25 - [Screen Capture Guard on Import Private Key]
**Vulnerability:** The private key input screen lacked protection against screen recording or screenshots, making it possible for other apps or features to capture highly sensitive material in transit.
**Learning:** `ScreenCaptureGuard` was implemented on the 'Import Secret Phrase' flow but inconsistently omitted from the 'Import Private Key' flow.
**Prevention:** Always verify that components exposing or managing raw private credentials (private keys, secret phrases) wrap their usage with the `ScreenCaptureGuard` to disable screen capture upon initialization and safely enable upon disposal.
