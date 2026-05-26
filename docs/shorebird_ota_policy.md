# Shorebird OTA Policy

## Purpose
This document defines how Owllet uses Shorebird for over-the-air updates.

Owllet uses Shorebird only for the Flutter host app and only for narrow, Dart-only maintenance patches. Cash In and other hosted mini apps remain outside this OTA surface and continue to update through normal web deployment.

## Scope
Shorebird is enabled for:
- Android
- iOS

Shorebird is not used as a replacement for store releases. It is a signed maintenance lane for low-risk Dart fixes that do not change wallet trust boundaries.

## Allowed Patch Scope
The following changes are allowed through Shorebird patches:
- pure Dart UI fixes
- copy changes
- low-risk UX polish
- small non-sensitive state fixes
- maintenance hotfixes that do not alter signing, wallet security, or native behavior

## Forbidden Patch Scope
The following changes must ship as normal store releases:
- seed phrase and recovery flow changes
- signing logic or transaction construction changes
- fee semantics
- auth or security-critical behavior
- DApp browser trust rules
- WebView provider injection rules
- Rust changes
- native Android or iOS changes
- plugin changes
- asset changes
- Firebase native SDK configuration changes
- biometric changes

## CI Enforcement
Patch eligibility is enforced by CI, not by developer convention.

The Shorebird patch workflow hard fails if a patch candidate touches:
- `rust/**`
- `rust_builder/**`
- `android/**`
- `ios/**`
- `assets/**`
- `pubspec.yaml`
- `pubspec.lock`
- `shorebird.yaml`

The patch workflow also hard fails if a patch candidate touches trust-boundary Dart paths such as:
- `lib/src/rust/**`
- `lib/screens/onboarding/**`
- `lib/services/wallet_service.dart`
- `lib/services/storage_service.dart`
- `lib/services/auth_service.dart`
- `lib/services/biometric_service.dart`
- `lib/services/wallet_backend_auth_service.dart`
- `lib/services/swap_service.dart`
- `lib/services/swap_execution_service.dart`
- `lib/services/token_approval_service.dart`
- `lib/services/rpc_service.dart`
- `lib/features/discover/provider/**`
- `lib/features/discover/browser/**`
- `lib/utils/sensitive_access_guard.dart`
- seed phrase, private key reveal, or recovery screens under profile/security flows

CI-only support files under `.github/**`, `docs/**`, and `scripts/**` are ignored by
the patch-diff guard because they are not packaged into the Flutter runtime. They
must still be reviewed and merged separately from the app behavior being patched.

If a change touches anything outside the approved maintenance surface, the patch workflow fails and the change must go through a normal store release.

## Release and Patch Lineage
Each Shorebird release stores a manifest artifact that records:
- app version
- build number
- release version
- Flutter version
- Shorebird Flutter build settings such as `--no-tree-shake-icons`
- release commit SHA
- a restricted tree hash for native, Rust, assets, lockfile, and Shorebird config inputs
- per-file hashes for the restricted tree

Patch creation is only allowed when:
- the current `pubspec.yaml` release version exactly matches the selected Shorebird release
- the current Flutter version matches the release manifest
- the current Shorebird Flutter build settings match the release manifest
- the restricted tree hash matches the release manifest
- the patch diff since the release commit only touches approved Dart maintenance paths

This prevents dependency drift, native drift, asset drift, icon tree-shaking drift, and release-line confusion.

## Icon Tree-Shaking
Material icon tree-shaking changes the generated `MaterialIcons-Regular.otf` asset when the set of referenced `Icons.*` symbols changes. Shorebird patches cannot ship asset diffs, so Owllet always builds Shorebird releases and patches with `--no-tree-shake-icons`.

This build flag is recorded in the release manifest and the patch guard fails early if a selected release line used different Shorebird Flutter build settings. Older release lines that were built without this setting must use a normal store release instead of a Shorebird patch once icon usage changes.

## No-Op Validation
Each Shorebird release workflow also runs a no-op validation against the newly created manifest. If the restricted tree already differs from the released state, that release line is treated as OTA-unsafe and patching must not continue for that version.

## Signing and Integrity
Patch signing is mandatory for Owllet OTA.

Each Shorebird release embeds a public verification key in the app. Each Shorebird patch must be signed with the matching private key. If a patch signature is missing or invalid, the app must stay on the base release or the last known good patch.

This policy follows Shorebird's signed patch model:
- release with `--public-key-path`
- patch with `--public-key-path` and `--private-key-path`

The signing keys must never be committed to source control.

## Update Behavior
Owllet uses silent maintenance updates only.

The app:
- checks for patches after bootstrap
- checks again on app resume with debounce
- downloads available maintenance patches silently
- applies them on the next restart

Silent updates are acceptable for maintenance fixes. Any urgent trust-critical issue still requires a normal store release because a silently downloaded patch does not take effect until restart.

## Runtime Expectations
If a patch cannot be downloaded, verified, or applied:
- the app must continue running the base release or last known good patch
- the updater must not crash the app
- the failure must be logged in the app patch metadata for support/debug visibility

## Required CI Secrets and Variables
Repository secrets:
- `SHOREBIRD_TOKEN`
- `SHOREBIRD_PATCH_PUBLIC_KEY_BASE64`
- `SHOREBIRD_PATCH_PRIVATE_KEY_BASE64`
- Android signing secrets already used by store builds
- iOS signing secrets already used by store builds

Repository variable or secret:
- `SHOREBIRD_APP_ID`

The Shorebird app id is not secret, but the token and signing keys are secrets.

## Patch Signing Key Generation (Windows)
Use the helper script:

```
scripts\generate_shorebird_patch_keys.ps1
```

It creates:
- `shorebird_keys/shorebird_public.pem`
- `shorebird_keys/shorebird_private.pem`
- `shorebird_keys/shorebird_public_key_base64.txt`
- `shorebird_keys/shorebird_private_key_base64.txt`

Use the base64 files for:
- `SHOREBIRD_PATCH_PUBLIC_KEY_BASE64`
- `SHOREBIRD_PATCH_PRIVATE_KEY_BASE64`

## Local Patch Guard
To enforce the same guardrails locally, use:

```
scripts\shorebird_patch_local.ps1
```

Required environment variables:
- `FLUTTER_VERSION`
- `SHOREBIRD_PLATFORM` (`android` or `ios`)
- `SHOREBIRD_RELEASE_VERSION` (e.g. `1.2.8+13`)
- `SHOREBIRD_PATCH_PUBLIC_KEY_PATH`
- `SHOREBIRD_PATCH_PRIVATE_KEY_PATH`

The script expects a release manifest at:
- `shorebird_release_manifest.json`

Download the manifest artifact from the Shorebird release workflow and place it at the repo root before running the script.

## Operational Rules
- Use `mobile_release_bump.yml` for store releases only.
- Do not bump version for Shorebird patches.
- Do not create a patch from a dirty or drifted release line.
- Do not use OTA for trust-critical wallet fixes.
- If patch signing or lineage validation cannot be satisfied, disable OTA for that release and use a store release instead.
