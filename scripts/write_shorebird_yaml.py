from __future__ import annotations

import argparse
import pathlib


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-id", required=True)
    parser.add_argument("--output", default="shorebird.yaml")
    parser.add_argument("--auto-update", default="false", choices=("true", "false"))
    args = parser.parse_args()

    output = pathlib.Path(args.output).resolve()
    output.write_text(
        f"app_id: {args.app_id}\nauto_update: {args.auto_update}\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
