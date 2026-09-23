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

Since 2026-09-23 this also asserts two runtime assets are present:
`res://assets/audio/crossing_chime.wav` and
`res://assets/sprites/crossing_cue.png`, both `preload`ed
(`game/scripts/main.gd:21`, `game/scripts/ui/hud.gd:14`). A missing one fails
the smoke boot too — a failed `preload` is a compile failure — but that gate
only reports "the binary did not boot", never which asset is gone
(build-review V8). Unlike the data-file list, this pair is hardcoded rather
than derived: nothing in the asset tree marks a file as being on the
preload/critical path, so scanning `game/assets/` would either flag harmless
unpacked assets or require a manifest that does not exist.

An imported asset never ships under its own name. Godot packs the
`<path>.import` remap and the converted file under `res://.godot/imported/`
(`crossing_chime.wav-<hash>.sample`, `crossing_cue.png-<hash>.ctex`), and the
original `.wav` or `.png` is not in the pack at all. Both halves are required:
the remap without its payload loads nothing.

Since 2026-09-23 this also accepts a macOS `.dmg` (build-review C2, ADR 0018).
The release `.dmg` — signed and notarized on the product owner's Mac, per
`signing-runbook.md` A5-A6 — is the artifact that actually ships; before this
it was the one shape `resolve_pck` could not read, so the thing players
download was gated by nothing. Reading it means mounting it: `hdiutil attach`
the image, glob for the `.app` inside exactly as an already-mounted bundle,
then `hdiutil detach` on the way out. `hdiutil` only exists on macOS, so this
fails with a clear message rather than a stack trace where it is absent
(Linux — the CI runner this gate also runs on).

Usage:
    check_pck_contents.py <file.pck|bundle.app|macos.zip|macos.dmg> --data-dir game/data
"""

from __future__ import annotations

import argparse
import contextlib
import pathlib
import shutil
import subprocess
import sys
import tempfile
import zipfile
from collections.abc import Iterator

from inspect_pck import PckError, read_pck_paths

# Paths that must never ship in a release build. GUT and the test suite are
# development-only; shipping them bloats the pack and hands players the test
# framework. Enforced by `exclude_filter` in game/export_presets.cfg.
FORBIDDEN_PREFIXES = ("res://addons/gut/", "res://tests/")

# Runtime assets that are `preload`ed and so must survive export, or the game
# fails to boot. See the module docstring for why this list is hardcoded
# rather than derived.
CRITICAL_ASSETS = (
    "res://assets/audio/crossing_chime.wav",
    "res://assets/sprites/crossing_cue.png",
)

# Where Godot packs the converted form of an imported asset.
IMPORTED_PREFIX = "res://.godot/imported/"

# Where a macOS export keeps its pack, inside the .app bundle.
BUNDLE_PCK_GLOB = "Contents/Resources/*.pck"


def asset_packed(path: str, present: set[str]) -> bool:
    """True if ``path`` shipped, either as itself or in its imported form."""
    if path in present:
        return True
    imported = f"{IMPORTED_PREFIX}{path.rsplit('/', 1)[-1]}-"
    return f"{path}.import" in present and any(p.startswith(imported) for p in present)


class LocateError(Exception):
    """The pack could not be found — as distinct from failing its contents."""


def _find_pck_in_bundle(bundle: pathlib.Path) -> pathlib.Path:
    """Return the one ``.pck`` inside an ``.app`` bundle, or raise."""
    found = sorted(bundle.glob(BUNDLE_PCK_GLOB))
    if not found:
        raise LocateError(
            f"no {BUNDLE_PCK_GLOB} inside {bundle} — not a Godot macOS bundle?"
        )
    if len(found) > 1:
        raise LocateError(f"{len(found)} packs inside {bundle}; expected one")
    return found[0]


@contextlib.contextmanager
def _mounted_dmg(target: pathlib.Path) -> Iterator[pathlib.Path]:
    """Mount ``target`` read-only with ``hdiutil`` and yield the mount point.

    ``hdiutil`` exists only on macOS. Checking for it with ``shutil.which``,
    rather than branching on ``sys.platform``, gives the same clear failure on
    Linux (where it is genuinely absent) as on a Mac with a broken ``PATH``,
    and lets a test simulate the absence without needing a Linux runner.
    """
    hdiutil = shutil.which("hdiutil")
    if hdiutil is None:
        raise LocateError(
            f"{target} is a .dmg, but hdiutil is not on PATH — .dmg images can "
            "only be mounted on macOS. Run this on the Mac that built the "
            "release, or mount it there and pass the .app instead."
        )

    mount_point = pathlib.Path(tempfile.mkdtemp(prefix="pck-gate-dmg-"))
    proc = subprocess.run(
        [
            hdiutil, "attach", "-nobrowse", "-readonly",
            "-mountpoint", str(mount_point), str(target),
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        shutil.rmtree(mount_point, ignore_errors=True)
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise LocateError(f"could not mount {target}: {detail}")
    try:
        yield mount_point
    finally:
        subprocess.run(
            [hdiutil, "detach", str(mount_point), "-quiet"],
            capture_output=True,
            text=True,
        )
        shutil.rmtree(mount_point, ignore_errors=True)


@contextlib.contextmanager
def resolve_pck(target: pathlib.Path) -> Iterator[pathlib.Path]:
    """Yield a readable ``.pck`` for a pck, a ``.app`` bundle, a macOS zip or dmg.

    **The pack inside a macOS bundle is named from the project's
    ``config/name``, not from the export path.** This project exports to
    ``wildlife-crossing.zip`` and the pack inside is ``Wildlife Crossing.pck``,
    with a space and different capitalisation. So every lookup here globs for
    ``*.pck`` and refuses an ambiguous result; none of them reconstructs a
    filename. Guessing the name would produce a "pack not found" on a perfectly
    good build, which is the same class of false failure as the ``head -20``
    defect this project already paid for once.

    A zip is extracted to a temporary directory that is removed on exit; a dmg
    is mounted and detached the same way.
    """
    if target.is_dir() and target.suffix == ".app":
        yield _find_pck_in_bundle(target)
        return

    if target.suffix == ".dmg":
        with _mounted_dmg(target) as mount_point:
            apps = sorted(mount_point.glob("*.app"))
            if not apps:
                raise LocateError(
                    f"no *.app inside {target} — not a Godot macOS disk image?"
                )
            if len(apps) > 1:
                raise LocateError(f"{len(apps)} apps inside {target}; expected one")
            yield _find_pck_in_bundle(apps[0])
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
        help="a .pck, a macOS .app bundle, or the macOS export .zip or .dmg",
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

    missing_assets = [p for p in CRITICAL_ASSETS if not asset_packed(p, present)]
    if missing_assets:
        failed = True
        print(
            f"{err}exported pack is missing {len(missing_assets)} of "
            f"{len(CRITICAL_ASSETS)} runtime asset(s) the game preloads at "
            f"startup:"
        )
        for p in missing_assets:
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
            f"OK — all {len(expected)} data file(s) and {len(CRITICAL_ASSETS)} "
            f"runtime asset(s) present, no addons/gut or tests paths shipped."
        )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
