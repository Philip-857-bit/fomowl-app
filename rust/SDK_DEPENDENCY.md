# Shared SDK dependency

The canonical proprietary SDK is https://github.com/Philip-857-bit/owllet-core.
Release v0.1.0 uses commit bd26eb9603c56d3ec012a5e11ad7b8558a2a2e9e.
The adapter and independent consumer pin both this revision and version =0.1.0.
Core source, capability checks, packaging and releases are maintained in that
repository. There is no embedded source copy in this app.

Developers need read access to the private repository and an authenticated Git
credential helper (for example, `gh auth setup-git`). CI uses the repository
secret OWLLET_CORE_SSH_KEY and a read-only SDK deploy key. Rotate that key by
replacing the secret, verifying a native build, and then revoking the old key.
Never include credentials in Cargo manifests, source files, or app binaries.

To upgrade, review an SDK release, change the exact revision and version in both
Cargo manifests, and update both Cargo lockfiles. Run adapter formatting,
Clippy and tests, the independent consumer, rebuild the native library, and run
Flutter signing/vault compatibility tests. Commit the upgrade as a tracked step.
Changes to native dependencies require evaluating a full binary release before
using a Shorebird patch.

The SDK owns shared cryptography, transaction encoding, signing and vault rules.
The host owns RPC transport, user permissions, platform storage, lifecycle and
backend communication. Payment/KYC/swap provider credentials remain server-side.
Other Rust products can consume the same pinned Git dependency or the verified
private release package; other languages need platform adapters.
