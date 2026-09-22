## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-18 - [Missing UI Shield on Key Import]
**Vulnerability:** The private key import screen (`import_private_key_screen.dart`) did not implement the `ScreenCaptureGuard` protection, allowing potential screenshotting or screen recording while highly sensitive raw private keys were being typed or pasted.
**Learning:** Even though text was being obscured natively by Flutter, iOS and Android OS-level screen recordings can still capture sensitive data in transit (clipboard overlays or before obscuring mechanisms fully take over). It is easy to forget to add `ScreenCaptureGuard` on every new authentication/import screen.
**Prevention:** Every screen handling raw secret recovery phrases or private keys must instantiate and properly await the initialization and teardown of `ScreenCaptureGuard` in `initState` and `dispose`.
