#!/usr/bin/env bash
# Repository bootstrap for the Owllet (fomowl_wallet) Cloud Agent environment.
# Runs after the source tree is checked out. Idempotent: safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Writing android/local.properties (Flutter + Android SDK locations)"
cat > android/local.properties <<EOF
flutter.sdk=${FLUTTER_HOME:-/opt/flutter}
sdk.dir=${ANDROID_SDK_ROOT:-/opt/android-sdk}
EOF

echo "==> flutter pub get"
flutter pub get

# Build the native crypto library (flutter_rust_bridge) for the host so that
# `flutter test` can dlopen it. CI does the same in .github/workflows/dart.yml.
echo "==> cargo build (host native crypto library)"
cargo build --manifest-path rust/Cargo.toml --release --locked

# Enable the repo's pre-commit secret/keystore guard.
echo "==> installing git hooks"
sh scripts/install-git-hooks.sh || true

echo "==> Done. Run tests with:"
echo "    LD_LIBRARY_PATH=\"\$PWD/rust/target/release\" flutter test"
