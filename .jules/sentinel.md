## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-24 - [Fix Missing ScreenCaptureGuard on Private Key Input]
**Vulnerability:** The Private Key Import screen (`lib/screens/onboarding/import_private_key_screen.dart`) accepted a raw private key but was missing the `ScreenCaptureGuard` protection, allowing for potential screenshots or background screen recording.
**Learning:** `ScreenCaptureGuard` application is inconsistent across sensitive onboarding screens. While the Secret Phrase screen had it, the Private Key import screen did not.
**Prevention:** Make sure `ScreenCaptureGuard` is initialized and enabled globally on all screens handling raw private keys or seed phrases, and disabled in `dispose()`.
