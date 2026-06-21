#!/usr/bin/env bash
# SessionStart hook for Claude Code on the web.
# Prepares the Flutter wallet app (+ Rust bridge): installs the Flutter SDK if
# missing, then resolves Dart/Flutter packages so analyze/test work.
# Idempotent and non-interactive.
set -euo pipefail

# Only run the heavy setup in the remote (web) environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

# Pin to the Flutter version the CI analyze/test workflow uses (.github/workflows/dart.yml).
FLUTTER_VERSION="3.41.6"
FLUTTER_DIR="/opt/flutter"

if ! command -v flutter >/dev/null 2>&1 && [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "[session-start] fomowl-app: installing Flutter ${FLUTTER_VERSION}"
  git clone --depth 1 -b "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

if [ -x "${FLUTTER_DIR}/bin/flutter" ]; then
  export PATH="${FLUTTER_DIR}/bin:${PATH}"
  # Persist Flutter on PATH for the rest of the session.
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export PATH=\"${FLUTTER_DIR}/bin:\$PATH\"" >> "${CLAUDE_ENV_FILE}"
  fi
fi

flutter config --no-analytics >/dev/null 2>&1 || true

echo "[session-start] fomowl-app: resolving Flutter/Dart packages"
flutter pub get

echo "[session-start] fomowl-app: ready (Android SDK/NDK not installed; needed only for device builds)"
