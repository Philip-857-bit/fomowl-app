## 2025-02-28 - Obscure Highly Sensitive Inputs
**Vulnerability:** Private keys and secret seed phrases were displayed in plaintext within text fields during wallet import, creating a shoulder-surfing or screen recording risk.
**Learning:** Flutter's `TextField` throws an assertion error if `obscureText` is true and `maxLines` is > 1. Hiding multiline sensitive strings requires dynamic state linking `obscureText` to `maxLines = 1`.
**Prevention:** Always default highly sensitive inputs (seeds, private keys) to `obscureText: true` and conditionally manage `maxLines` to support standard text entry limitations while keeping data protected from physical proximity threats.
