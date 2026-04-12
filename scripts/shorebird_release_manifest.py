from __future__ import annotations

import argparse
import datetime as dt
import pathlib

from shorebird_ci_common import (
    digest_files,
    git_output,
    list_tracked_files,
    read_pubspec_release,
    write_json,
)


RESTRICTED_ROOTS = (
    "pubspec.lock",
    "shorebird.yaml",
    "android",
    "ios",
    "rust",
    "rust_builder",
    "assets",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--platform", required=True, choices=("android", "ios"))
    parser.add_argument("--flutter-version", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    repo_root = pathlib.Path(args.repo_root).resolve()
    app_version, build_number = read_pubspec_release(repo_root)
    files = list_tracked_files(repo_root, RESTRICTED_ROOTS)
    file_hashes, restricted_tree_hash = digest_files(repo_root, files)

    payload = {
        "platform": args.platform,
        "app_version": app_version,
        "build_number": build_number,
        "release_version": f"{app_version}+{build_number}",
        "flutter_version": args.flutter_version,
        "release_commit_sha": git_output(repo_root, "rev-parse", "HEAD"),
        "generated_at_utc": dt.datetime.now(tz=dt.timezone.utc).isoformat(),
        "restricted_roots": list(RESTRICTED_ROOTS),
        "restricted_tree_hash": restricted_tree_hash,
        "file_hashes": file_hashes,
    }
    write_json(pathlib.Path(args.output).resolve(), payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
