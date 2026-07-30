#!/usr/bin/env python3
"""Assert an exported Godot pack contains the files the game reads at runtime.

Rationale (2026-07-28): every gate this project had tested the *source tree* —
the GUT suite, the zero-tests guard, the export job's exit status. Nothing
asserted anything about the artifact, so a whole class of defect could only be
found by hand, weeks later. This closes that gap at pack time; the CI smoke test
closes it at boot time. The pair is what stops the class recurring.

The expected data-file list is derived from the repo rather than hardcoded, so
adding a new `data/*.json` automatically extends the guard.

Usage:
    check_pck_contents.py <file.pck> --data-dir game/data
"""

from __future__ import annotations

import argparse
import pathlib
import sys

from inspect_pck import PckError, read_pck_paths

# Paths that must never ship in a release build. GUT and the test suite are
# development-only; shipping them bloats the pack and hands players the test
# framework. Enforced by `exclude_filter` in game/export_presets.cfg.
FORBIDDEN_PREFIXES = ("res://addons/gut/", "res://tests/")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("pck")
    ap.add_argument(
        "--data-dir",
        default="game/data",
        help="project data directory to derive the expected file list from",
    )
    ap.add_argument(
        "--github",
        action="store_true",
        help="emit ::error:: annotations for GitHub Actions",
    )
    args = ap.parse_args()

    err = "::error::" if args.github else "error: "

    data_dir = pathlib.Path(args.data_dir)
    if not data_dir.is_dir():
        print(f"{err}data directory not found: {data_dir}", file=sys.stderr)
        return 2

    expected = sorted(
        "res://data/" + p.relative_to(data_dir).as_posix()
        for p in data_dir.rglob("*.json")
    )
    if not expected:
        print(f"{err}no .json files under {data_dir} — nothing to check", file=sys.stderr)
        return 2

    try:
        packed, info = read_pck_paths(args.pck)
    except (PckError, OSError) as exc:
        print(f"{err}{exc}", file=sys.stderr)
        return 2

    present = set(packed)
    failed = False

    missing = [p for p in expected if p not in present]
    if missing:
        failed = True
        print(
            f"{err}exported pack is missing {len(missing)} of {len(expected)} "
            f"data file(s) the game loads at startup:"
        )
        for p in missing:
            print(f"    {p}")

    forbidden = sorted(p for p in packed if p.startswith(FORBIDDEN_PREFIXES))
    if forbidden:
        failed = True
        print(
            f"{err}exported pack ships {len(forbidden)} development-only path(s) "
            f"(expected none):"
        )
        for p in forbidden[:10]:
            print(f"    {p}")
        if len(forbidden) > 10:
            print(f"    … and {len(forbidden) - 10} more")

    print(
        f"{args.pck}: {info['file_count']} file(s), pack format {info['version']}, "
        f"built by Godot {info['godot']}."
    )
    if not failed:
        print(
            f"OK — all {len(expected)} data file(s) present, "
            f"no addons/gut or tests paths shipped."
        )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
