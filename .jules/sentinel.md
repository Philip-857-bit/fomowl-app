## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.
## 2024-05-18 - [Fix Missing Screen Capture Guard on Private Key Screens]
**Vulnerability:** Private key displays in the Import Private Key screen and View Private Key modal were not protected by `ScreenCaptureGuard`, allowing users to take screenshots or screen recordings of sensitive keys.
**Learning:** Screens showing critical secrets need consistent use of `ScreenCaptureGuard`. The lack of `try/finally` around modal display in some places may lead to guards left unprotected or failing to disable when the modal is dismissed.
**Prevention:** Ensure all screens and modals that display or allow entry of private keys or seed phrases instantiate `ScreenCaptureGuard` and properly enable/disable it matching the component lifecycle (using `initState`/`dispose` for stateful widgets and `try/finally` for modals).
