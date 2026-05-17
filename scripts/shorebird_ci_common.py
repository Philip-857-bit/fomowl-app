from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import subprocess
from typing import Iterable


VERSION_RE = re.compile(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$")
VOLATILE_PATH_PARTS = (
    "android/.kotlin/",
    "android/build/",
    "android/app/build/",
)


def read_pubspec_release(repo_root: pathlib.Path) -> tuple[str, str]:
    pubspec_path = repo_root / "pubspec.yaml"
    for line in pubspec_path.read_text(encoding="utf-8").splitlines():
        match = VERSION_RE.match(line.strip())
        if match:
            return match.group(1), match.group(2)
    raise RuntimeError(f"Unable to parse version from {pubspec_path}")


def git_output(repo_root: pathlib.Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def list_tracked_files(repo_root: pathlib.Path, roots: Iterable[str]) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for root in roots:
        result = subprocess.run(
            ["git", "ls-files", "-z", "--", root],
            cwd=repo_root,
            check=True,
            capture_output=True,
        )
        if not result.stdout:
            continue
        for raw in result.stdout.split(b"\x00"):
            if not raw:
                continue
            files.append(repo_root / os.fsdecode(raw))
    return sorted(set(files))


def sha256_git_blob(repo_root: pathlib.Path, relative_path: str) -> str:
    result = subprocess.run(
        ["git", "show", f"HEAD:{relative_path}"],
        cwd=repo_root,
        check=True,
        capture_output=True,
    )
    return hashlib.sha256(result.stdout).hexdigest()


def digest_files(repo_root: pathlib.Path, files: Iterable[pathlib.Path]) -> tuple[dict[str, str], str]:
    manifest: dict[str, str] = {}
    combined = hashlib.sha256()
    for path in sorted(files):
        relative_path = path.relative_to(repo_root).as_posix()
        if any(relative_path.startswith(part) for part in VOLATILE_PATH_PARTS):
            continue
        if not path.is_file():
            continue
        file_hash = sha256_git_blob(repo_root, relative_path)
        manifest[relative_path] = file_hash
        combined.update(relative_path.encode("utf-8"))
        combined.update(b"\0")
        combined.update(file_hash.encode("ascii"))
        combined.update(b"\n")
    return manifest, combined.hexdigest()


def write_json(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
