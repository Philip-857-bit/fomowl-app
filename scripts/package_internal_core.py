"""Build a verified proprietary source package without uploading to a registry.

Run --inventory-only after intentionally changing dependency versions. A normal
release requires a clean repository, a current inventory and publish=false.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "rust" / "owllet-core"
MANIFEST = CORE / "Cargo.toml"
INVENTORY = CORE / "DEPENDENCY_LICENSES.json"


def command(*args: str) -> str:
    result = subprocess.run(args, cwd=ROOT, check=True, text=True, encoding="utf-8", stdout=subprocess.PIPE)
    return result.stdout.strip()


def inventory() -> dict:
    metadata = json.loads(command("cargo", "metadata", "--manifest-path", str(MANIFEST), "--locked", "--all-features", "--format-version", "1"))
    packages = {package["id"]: package for package in metadata["packages"]}
    nodes = {node["id"]: node for node in metadata["resolve"]["nodes"]}
    root = metadata["resolve"]["root"]
    visited = {root}
    pending = [root]
    while pending:
        for dependency in nodes[pending.pop()]["deps"]:
            if not any(kind["kind"] != "dev" for kind in dependency["dep_kinds"]):
                continue
            if dependency["pkg"] not in visited:
                visited.add(dependency["pkg"])
                pending.append(dependency["pkg"])
    entries = []
    for identity in visited - {root}:
        package = packages[identity]
        entries.append({"name": package["name"], "version": package["version"], "license": package["license"], "repository": package["repository"], "source": package["source"]})
    entries.sort(key=lambda entry: (entry["name"], entry["version"]))
    return {
        "package": packages[root]["name"],
        "version": packages[root]["version"],
        "scope": "all-feature runtime and build dependency Cargo license metadata; excludes dev-only dependencies",
        "packages": entries,
        "missing_license_metadata": [f"{entry['name']}@{entry['version']}" for entry in entries if not entry["license"]],
    }


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory-only", action="store_true")
    args = parser.parse_args()
    current = inventory()
    if args.inventory_only:
        write_json(INVENTORY, current)
        print(f"Recorded {len(current['packages'])} dependency license metadata entries")
        return
    package = tomllib.loads(MANIFEST.read_text(encoding="utf-8"))["package"]
    if package.get("publish") is not False:
        raise SystemExit("Internal release requires publish=false")
    if package.get("license-file") != "PROPRIETARY.md":
        raise SystemExit("Internal release requires the proprietary notice")
    if command("git", "status", "--porcelain"):
        raise SystemExit("Commit all source changes before creating an internal release")
    if not INVENTORY.exists() or json.loads(INVENTORY.read_text(encoding="utf-8")) != current:
        raise SystemExit("Dependency inventory is stale; regenerate and commit it first")
    print("Building and verifying the internal source package; no upload command is used", flush=True)
    subprocess.run(["cargo", "package", "--manifest-path", str(MANIFEST), "--locked", "--offline", "--all-features", "--target-dir", str(CORE / "target")], cwd=ROOT, check=True)
    filename = f"{package['name']}-{package['version']}.crate"
    artifact = CORE / "target" / "package" / filename
    # A local Cargo configuration may redirect target output; fail rather than
    # silently packaging an older artifact from an unexpected target directory.
    if not artifact.is_file():
        raise SystemExit(f"Expected verified package was not found: {artifact}")
    checksum = hashlib.sha256(artifact.read_bytes()).hexdigest()
    output = CORE / "target" / "internal-release" / package["version"]
    if not output.resolve().is_relative_to((CORE / "target").resolve()):
        raise SystemExit("Release path escaped the crate target directory")
    output.mkdir(parents=True, exist_ok=True)
    destination = output / filename
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() != checksum:
        raise SystemExit("An internal artifact already exists with this version; increment the version instead of overwriting it")
    shutil.copyfile(artifact, destination)
    (output / "SHA256SUMS").write_text(f"{checksum}  {filename}\n", encoding="utf-8")
    write_json(output / "release.json", {
        "name": package["name"], "version": package["version"], "distribution": "proprietary-internal",
        "source_commit": command("git", "rev-parse", "HEAD"), "rustc": command("rustc", "--version"),
        "artifact": filename, "sha256": checksum, "cargo_package_all_features_verified": True,
        "dependency_inventory_entries": len(current["packages"]),
    })
    print(f"Verified internal package: {destination}")
    print(f"SHA-256: {checksum}")


if __name__ == "__main__":
    main()
