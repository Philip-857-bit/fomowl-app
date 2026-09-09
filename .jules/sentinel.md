## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2024-05-18 - [Fix Screen Capture on Import Private Key]
**Vulnerability:** The screen to import private keys allows the OS or background apps to take screenshots or record screens. This can expose user private keys to malicious apps or accidentally saved to their photos.
**Learning:** This repo has a `ScreenCaptureGuard` to manage this globally. By default screens are not protected, the UI must explicitly enable and disable protection using the guard.
**Prevention:** Make sure `ScreenCaptureGuard.enableProtection()` is called during initialization (e.g. `initState`) and `ScreenCaptureGuard.disableProtection()` is called during teardown (e.g. `dispose`) on all screens containing extremely sensitive information.
