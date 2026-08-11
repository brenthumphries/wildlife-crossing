#!/usr/bin/env python3
"""Assert an exported Godot pack contains the files the game reads at runtime.

Rationale (2026-07-28): every gate this project had tested the *source tree* —
the GUT suite, the zero-tests guard, the export job's exit status. Nothing
asserted anything about the artifact, so a whole class of defect could only be
found by hand, weeks later. This closes that gap at pack time; the CI smoke test
closes it at boot time. The pair is what stops the class recurring.

The expected data-file list is derived from the repo rather than hardcoded, so
adding a new `data/*.json` automatically extends the guard.

Since 2026-08-10 this accepts a macOS `.zip` or `.app` as well as a bare
`.pck`, so all three exported platforms can be gated by the same command
(build-review V2). Before that only the Linux pack was checked, and the Windows
pack is not even byte-identical to it — verified in the 2026-08-04 review,
`md5 a2dbbbee…` against `934e8b12…` — so "the Linux pack is fine" was never
evidence about the other two.

Usage:
    check_pck_contents.py <file.pck|bundle.app|macos.zip> --data-dir game/data
"""

from __future__ import annotations

import argparse
import contextlib
import pathlib
import shutil
import sys
import tempfile
import zipfile
from collections.abc import Iterator

from inspect_pck import PckError, read_pck_paths

# Paths that must never ship in a release build. GUT and the test suite are
# development-only; shipping them bloats the pack and hands players the test
# framework. Enforced by `exclude_filter` in game/export_presets.cfg.
FORBIDDEN_PREFIXES = ("res://addons/gut/", "res://tests/")

# Where a macOS export keeps its pack, inside the .app bundle.
BUNDLE_PCK_GLOB = "Contents/Resources/*.pck"


class LocateError(Exception):
    """The pack could not be found — as distinct from failing its contents."""


@contextlib.contextmanager
def resolve_pck(target: pathlib.Path) -> Iterator[pathlib.Path]:
    """Yield a readable ``.pck`` for a pck, a ``.app`` bundle, or a macOS zip.

    **The pack inside a macOS bundle is named from the project's
    ``config/name``, not from the export path.** This project exports to
    ``wildlife-crossing.zip`` and the pack inside is ``Wildlife Crossing.pck``,
    with a space and different capitalisation. So every lookup here globs for
    ``*.pck`` and refuses an ambiguous result; none of them reconstructs a
    filename. Guessing the name would produce a "pack not found" on a perfectly
    good build, which is the same class of false failure as the ``head -20``
    defect this project already paid for once.

    A zip is extracted to a temporary directory that is removed on exit.
    """
    if target.is_dir() and target.suffix == ".app":
        found = sorted(target.glob(BUNDLE_PCK_GLOB))
        if not found:
            raise LocateError(
                f"no {BUNDLE_PCK_GLOB} inside {target} — not a Godot macOS bundle?"
            )
        if len(found) > 1:
            raise LocateError(f"{len(found)} packs inside {target}; expected one")
        yield found[0]
        return

    if target.suffix == ".zip":
        try:
            archive = zipfile.ZipFile(target)
        except (zipfile.BadZipFile, OSError) as exc:
            raise LocateError(f"could not open {target} as a zip: {exc}")
        with archive:
            members = [
                n for n in archive.namelist()
                if n.endswith(".pck") and "/Contents/Resources/" in n
            ]
            if not members:
                raise LocateError(
                    f"no .app/Contents/Resources/*.pck inside {target} — "
                    "is this the macOS export?"
                )
            if len(members) > 1:
                raise LocateError(
                    f"{len(members)} packs inside {target}; expected one"
                )
            tmp = pathlib.Path(tempfile.mkdtemp(prefix="pck-gate-"))
            try:
                extracted = pathlib.Path(archive.extract(members[0], tmp))
                yield extracted
            finally:
                shutil.rmtree(tmp, ignore_errors=True)
        return

    if not target.exists():
        raise LocateError(f"no such file: {target}")
    yield target


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "pck",
        help="a .pck, a macOS .app bundle, or the macOS export .zip",
    )
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
        with resolve_pck(pathlib.Path(args.pck)) as pck_path:
            packed, info = read_pck_paths(str(pck_path))
    except LocateError as exc:
        print(f"{err}{exc}", file=sys.stderr)
        return 2
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
