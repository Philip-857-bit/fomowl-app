## 2026-09-03 - [Visibility Toggle for Sensitive Inputs]
**Vulnerability:** Private keys and secret phrases are displayed in plaintext when entered by the user, making them susceptible to shoulder-surfing attacks.
**Learning:** In Flutter, `TextField` does not support multiline obscured text, so `maxLines` must be conditionally set to 1 when `obscureText` is true.
**Prevention:** Always use `obscureText: true` for sensitive inputs and implement a visibility toggle to allow users to reveal the input securely.
