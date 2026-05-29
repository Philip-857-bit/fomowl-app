#!/bin/sh
# Point this repository's git at the tracked .githooks directory so the
# secret-scanning pre-commit hook actually runs locally.
#
# Usage:  sh scripts/install-git-hooks.sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
git -C "$repo_root" config core.hooksPath .githooks
chmod +x "$repo_root/.githooks/"* 2>/dev/null || true
echo "Configured core.hooksPath -> .githooks"
