from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

from shorebird_ci_common import digest_files, git_output, list_tracked_files, read_pubspec_release


RUST_FFI_BRIDGE_ROOTS = (
    "rust/",
    "rust_builder/",
    "lib/src/rust/",
)

NON_RUNTIME_ROOTS = (
    ".github/",
    "docs/",
    "scripts/",
)


def is_non_runtime_root(path: str) -> bool:
    return any(path.startswith(root) for root in NON_RUNTIME_ROOTS)


def is_rust_ffi_bridge_path(path: str) -> bool:
    normalized = path.replace("\\", "/")
    return any(
        normalized == root.rstrip("/") or normalized.startswith(root)
        for root in RUST_FFI_BRIDGE_ROOTS
    )


def rust_ffi_bridge_hashes(file_hashes: dict[str, str]) -> dict[str, str]:
    return {
        path.replace("\\", "/"): digest
        for path, digest in file_hashes.items()
        if is_rust_ffi_bridge_path(path)
    }


def ensure_commit_available(repo_root: pathlib.Path, commit_sha: str) -> None:
    try:
        git_output(repo_root, "cat-file", "-e", f"{commit_sha}^{{commit}}")
        return
    except subprocess.CalledProcessError:
        pass

    subprocess.run(
        ["git", "fetch", "--depth=1", "origin", commit_sha],
        cwd=repo_root,
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--flutter-version", required=True)
    parser.add_argument("--no-tree-shake-icons", action="store_true")
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

    manifest_build_settings = manifest.get("flutter_build_settings", {})
    manifest_no_tree_shake_icons = bool(manifest_build_settings.get("no_tree_shake_icons", False))
    if args.no_tree_shake_icons != manifest_no_tree_shake_icons:
        current_value = str(args.no_tree_shake_icons).lower()
        manifest_value = str(manifest_no_tree_shake_icons).lower()
        print(
            "Patch guard failed: no-tree-shake-icons setting "
            f"{current_value} does not match manifest {manifest_value}. "
            "Use the same Shorebird Flutter build flags as the release line "
            "or create a new store release.",
            file=sys.stderr,
        )
        return 1

    current_files = list_tracked_files(repo_root, RUST_FFI_BRIDGE_ROOTS)
    current_file_hashes, _ = digest_files(repo_root, current_files)
    current_bridge_hashes = rust_ffi_bridge_hashes(current_file_hashes)
    manifest_bridge_hashes = rust_ffi_bridge_hashes(manifest.get("file_hashes", {}))

    changed_bridge_files = sorted(
        path
        for path, digest in manifest_bridge_hashes.items()
        if current_bridge_hashes.get(path) != digest
    )
    added_bridge_files = sorted(set(current_bridge_hashes) - set(manifest_bridge_hashes))

    if changed_bridge_files or added_bridge_files:
        details = ", ".join(changed_bridge_files + added_bridge_files)
        print(
            "Patch guard failed: Rust FFI bridge files changed "
            f"({details}). "
            "Use a store release instead of a Shorebird patch.",
            file=sys.stderr,
        )
        return 1

    release_commit = manifest["release_commit_sha"]
    ensure_commit_available(repo_root, release_commit)
    diff_output = git_output(repo_root, "diff", "--name-only", release_commit, "HEAD")
    changed_files = [
        line.strip()
        for line in diff_output.splitlines()
        if line.strip() and not is_non_runtime_root(line.strip())
    ]

    if not changed_files and not args.allow_empty_diff:
        print(
            "Patch guard failed: no runtime changes detected.",
            file=sys.stderr,
        )
        return 1

    bridge_changes = [path for path in changed_files if is_rust_ffi_bridge_path(path)]
    if bridge_changes:
        print(
            "Patch guard failed: Rust FFI bridge files changed: "
            f"{', '.join(bridge_changes)}",
            file=sys.stderr,
        )
        return 1

    print(
        "Patch guard passed for release "
        f"{manifest_release_version} with {len(changed_files)} changed files. "
        "Runtime changes are allowed; Rust FFI bridge changes require a store release."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
