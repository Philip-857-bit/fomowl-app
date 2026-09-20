## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-18 - [Add ScreenCaptureGuard to Private Key Screen]
**Vulnerability:** The private key input screen lacked protection against screen captures, exposing secrets to screenshot and recording utilities.
**Learning:** The `ScreenCaptureGuard` was not uniformly applied across all sensitive onboarding views, meaning developers must manually initialize and manage its lifecycle via `initState` and `dispose` per screen instead of it acting globally.
**Prevention:** Apply `ScreenCaptureGuard` and use its enable and disable methods in `unawaited()` to all screens dealing with secret phrases and private keys.
