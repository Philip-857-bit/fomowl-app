## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-20 - [Missing ScreenCaptureGuard on Private Key Import]
**Vulnerability:** The `ImportPrivateKeyScreen` did not implement screen capture protection, allowing screenshots and screen recordings to capture sensitive private keys while the user is importing them.
**Learning:** `ScreenCaptureGuard` is essential for any screen that handles raw secrets (seed phrases, private keys). While it was implemented on `import_secret_phrase_screen`, it was missing on `import_private_key_screen`.
**Prevention:** Ensure any new or existing screens accepting sensitive information initialize and enable `ScreenCaptureGuard` during `initState` and disable it during `dispose` using `unawaited`.
