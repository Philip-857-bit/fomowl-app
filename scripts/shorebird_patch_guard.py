from __future__ import annotations

import argparse
import fnmatch
import json
import pathlib
import sys

from shorebird_ci_common import digest_files, git_output, list_tracked_files, read_pubspec_release


RESTRICTED_ROOTS = (
    "pubspec.lock",
    "shorebird.yaml",
    "android",
    "ios",
    "rust",
    "rust_builder",
    "assets",
)

ALLOWED_ROOTS = (
    "lib/",
    "test/",
    "integration_test/",
)

FORBIDDEN_PATTERNS = (
    "lib/src/rust/**",
    "lib/screens/onboarding/**",
    "lib/screens/auth/**",
    "lib/services/wallet_service.dart",
    "lib/services/storage_service.dart",
    "lib/services/auth_service.dart",
    "lib/services/biometric_service.dart",
    "lib/services/wallet_backend_auth_service.dart",
    "lib/services/swap_service.dart",
    "lib/services/swap_execution_service.dart",
    "lib/services/token_approval_service.dart",
    "lib/services/rpc_service.dart",
    "lib/features/discover/provider/**",
    "lib/features/discover/browser/**",
    "lib/utils/sensitive_access_guard.dart",
    "lib/screens/profile/backup_seed_phrase_screen.dart",
    "lib/screens/profile/login_profile_screen.dart",
    "lib/screens/profile/password_security_screen.dart",
    "lib/screens/profile/register_profile_screen.dart",
    "lib/screens/profile/two_factor_setup_screen.dart",
)


def is_allowed_root(path: str) -> bool:
    return any(path.startswith(root) for root in ALLOWED_ROOTS)


def matches_forbidden(path: str) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in FORBIDDEN_PATTERNS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--flutter-version", required=True)
    parser.add_argument("--allow-empty-diff", action="store_true")
    args = parser.parse_args()

    repo_root = pathlib.Path(args.repo_root).resolve()
    manifest_path = pathlib.Path(args.manifest).resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    app_version, build_number = read_pubspec_release(repo_root)
    current_release_version = f"{app_version}+{build_number}"
    manifest_release_version = manifest["release_version"]
    if current_release_version != manifest_release_version:
        print(
            "Patch guard failed: current pubspec release "
            f"{current_release_version} does not match manifest "
            f"{manifest_release_version}.",
            file=sys.stderr,
        )
        return 1

    if args.flutter_version != manifest["flutter_version"]:
        print(
            "Patch guard failed: Flutter version "
            f"{args.flutter_version} does not match manifest "
            f"{manifest['flutter_version']}.",
            file=sys.stderr,
        )
        return 1

    current_files = list_tracked_files(repo_root, RESTRICTED_ROOTS)
    _, current_tree_hash = digest_files(repo_root, current_files)
    if current_tree_hash != manifest["restricted_tree_hash"]:
        print(
            "Patch guard failed: restricted tree hash changed. "
            "Use a store release instead of a Shorebird patch.",
            file=sys.stderr,
        )
        return 1

    release_commit = manifest["release_commit_sha"]
    diff_output = git_output(repo_root, "diff", "--name-only", f"{release_commit}...HEAD")
    changed_files = [line.strip() for line in diff_output.splitlines() if line.strip()]

    if not changed_files and not args.allow_empty_diff:
        print(
            "Patch guard failed: no Dart-only maintenance changes detected.",
            file=sys.stderr,
        )
        return 1

    disallowed_roots = [
        path for path in changed_files if not is_allowed_root(path)
    ]
    if disallowed_roots:
        print(
            "Patch guard failed: files outside the approved maintenance surface "
            f"changed: {', '.join(disallowed_roots)}",
            file=sys.stderr,
        )
        return 1

    forbidden_changes = [path for path in changed_files if matches_forbidden(path)]
    if forbidden_changes:
        print(
            "Patch guard failed: trust-boundary files changed: "
            f"{', '.join(forbidden_changes)}",
            file=sys.stderr,
        )
        return 1

    print(
        "Patch guard passed for release "
        f"{manifest_release_version} with {len(changed_files)} changed files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
