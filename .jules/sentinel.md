## 2024-05-18 - [Fix Input Visibility]
**Vulnerability:** Private key and secret phrase inputs in the import onboarding flow were visible in plain text.
**Learning:** These text fields lacked the `obscureText: true` property by default, risking shoulder-surfing exposure of critical secrets. Furthermore, when implementing `obscureText: true` in Flutter's `TextField`, `maxLines` must be dynamically changed to 1 because Flutter doesn't support multi-line obscured text.
**Prevention:** Make sure all `TextField`s accepting sensitive information (passwords, keys, phrases) initialize with `obscureText: true` and have a toggle button for visibility, handling `maxLines` constraint accordingly.

## 2024-05-19 - [Missing ScreenCaptureGuard on ImportPrivateKeyScreen]
**Vulnerability:** The `ImportPrivateKeyScreen` was missing screen capture protection, potentially allowing malicious apps or accidental screenshots to capture raw private keys.
**Learning:** While other sensitive screens (like `BackupSeedPhraseScreen`, `ImportSecretPhraseScreen`) used `ScreenCaptureGuard`, this specific import flow lacked the protection layer, representing a gap in the security posture for importing existing wallets.
**Prevention:** Ensure all screens that handle sensitive credentials (private keys, secret phrases) globally instantiate and toggle `ScreenCaptureGuard` correctly in their `initState` and `dispose` lifecycle methods.
