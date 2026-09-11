## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2026-09-11 - [ScreenCaptureGuard coverage gaps]
**Vulnerability:** Private key views and private key import screens were not protected from screenshots and screen recordings.
**Learning:** ScreenCaptureGuard was applied to seed phrase backup and import but overlooked on the private key import flow and private key export modal. This exposed highly sensitive material to background recording or shoulder surfing (via screenshot).
**Prevention:** Every screen or modal rendering plaintext keys (seed phrase, private key) must wrap its display logic with `ScreenCaptureGuard` lifecycle methods (enable on init/open, disable on dispose/close).
