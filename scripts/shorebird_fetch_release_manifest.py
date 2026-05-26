from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import zipfile


def run(
    args: list[str],
    *,
    cwd: pathlib.Path | None = None,
    stdout=None,
) -> subprocess.CompletedProcess:
    return subprocess.run(args, cwd=cwd, check=True, stdout=stdout, text=False)


def gh_json(args: list[str]) -> dict:
    result = subprocess.run(
        ["gh", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def fetch_artifacts(repo: str, manifest_name: str) -> list[dict]:
    payload = gh_json(
        [
            "api",
            "-X",
            "GET",
            f"/repos/{repo}/actions/artifacts",
            "-F",
            "per_page=100",
            "-f",
            f"name={manifest_name}",
        ]
    )
    matches = [
        artifact
        for artifact in payload.get("artifacts", [])
        if artifact.get("name") == manifest_name
    ]
    return sorted(matches, key=lambda artifact: artifact.get("created_at", ""))


def download_artifact(repo: str, artifact_id: int, output: pathlib.Path) -> None:
    zip_path = output.with_suffix(".zip")
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zip_path.open("wb") as file:
        run(
            ["gh", "api", f"/repos/{repo}/actions/artifacts/{artifact_id}/zip"],
            stdout=file,
        )

    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(output.parent)

    if not output.is_file():
        raise RuntimeError(f"Downloaded artifact did not contain {output.name}")


def regenerate_manifest(
    *,
    release_sha: str,
    platform: str,
    flutter_version: str,
    output: pathlib.Path,
    workdir: pathlib.Path,
) -> None:
    release_tree = workdir / "shorebird-release-tree"
    if release_tree.exists():
        shutil.rmtree(release_tree)

    run(["git", "fetch", "--depth=1", "origin", release_sha])
    run(["git", "worktree", "add", "--detach", str(release_tree), release_sha])

    try:
        manifest_script = pathlib.Path(__file__).resolve().with_name(
            "shorebird_release_manifest.py"
        )
        if not manifest_script.is_file():
            raise RuntimeError(
                "Unable to locate scripts/shorebird_release_manifest.py"
            )
        run(
            [
                sys.executable,
                str(manifest_script),
                "--repo-root",
                str(release_tree),
                "--platform",
                platform,
                "--flutter-version",
                flutter_version,
                "--output",
                str(output),
            ]
        )
    finally:
        subprocess.run(["git", "worktree", "remove", "--force", str(release_tree)])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--manifest-name", required=True)
    parser.add_argument("--platform", required=True, choices=("android", "ios"))
    parser.add_argument("--flutter-version", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--workdir", required=True)
    args = parser.parse_args()

    output = pathlib.Path(args.output).resolve()
    workdir = pathlib.Path(args.workdir).resolve()
    artifacts = fetch_artifacts(args.repo, args.manifest_name)

    active = [artifact for artifact in artifacts if not artifact.get("expired", False)]
    if active:
        artifact = active[-1]
        download_artifact(args.repo, artifact["id"], output)
        print(
            f"Downloaded active release manifest artifact {args.manifest_name} "
            f"(id {artifact['id']})."
        )
        return 0

    if artifacts:
        latest = artifacts[-1]
        release_sha = latest.get("workflow_run", {}).get("head_sha")
        if not release_sha:
            print(
                "::error::Release manifest artifact "
                f"{args.manifest_name} is expired and its release commit SHA is unavailable. "
                "Run a new store release or manually restore the release manifest.",
                file=sys.stderr,
            )
            return 1

        print(
            "::warning::Release manifest artifact "
            f"{args.manifest_name} expired at {latest.get('expires_at')}. "
            f"Regenerating it from release commit {release_sha}."
        )
        regenerate_manifest(
            release_sha=release_sha,
            platform=args.platform,
            flutter_version=args.flutter_version,
            output=output,
            workdir=workdir,
        )
        return 0

    print(
        "::error::Unable to locate release manifest artifact named "
        f"{args.manifest_name}. Run the Shorebird {args.platform} release workflow "
        "for this exact version before patching.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
