#!/usr/bin/env python3
"""Download a CI build artifact and find what's actually inside it.

Rationale (2026-08-14): ``docs/push-runbook.md`` Steps 4 and 5 were walked end
to end for the first time on 2026-08-13, and both failed on their first command
for the same reason — they name things instead of finding them.

Two failures, one cause:

* ``gh run download -D ~/Downloads/wc-latest-build`` aborted with ``file
  exists``, because a fixed path accumulates every previous download. Worse
  than the error is the near miss: had the extraction not collided, the
  ``.pck`` verified would have been one from July, and nothing would have said
  so. The 2026-08-04 review's "the artifacts on disk fail the repo's own pck
  gate" is consistent with exactly that.
* ``xattr -dr com.apple.quarantine wildlife-crossing.app`` failed with ``No
  such file``. Godot names the bundle from ``config/name`` in project.godot —
  ``Wildlife Crossing.app``, space and capitals — not from the export path that
  produced ``wildlife-crossing.zip``. ``check_pck_contents.py`` already knew
  this and globs for the pack (see its module docstring); the runbook
  re-introduced the hardcoded name in prose, where nothing could catch it.

So this script does not construct names. It downloads into a directory named
for the run, unpacks whatever came back, globs for the bundle and the binaries,
and prints the next commands with the real names already quoted. Prose can rot
silently. A glob with a test cannot.

Usage:
    fetch_build.py 31762062722                  # download, unpack, report
    fetch_build.py 31762062722 --check          # also run the pack gate
    fetch_build.py --locate ~/Downloads/wc-123  # report on an existing dir
"""

from __future__ import annotations

import argparse
import pathlib
import shlex
import subprocess
import sys
from dataclasses import dataclass, field

# Where a macOS export keeps its executable, inside the .app bundle. Globbed
# for the same reason the bundle itself is: the name comes from config/name.
BUNDLE_EXEC_GLOB = "Contents/MacOS/*"


class FetchError(Exception):
    """A refusal. Something about the destination or the run is not safe."""


@dataclass
class Artifacts:
    """Everything worth knowing about an unpacked artifact directory."""

    root: pathlib.Path
    bundles: list[pathlib.Path] = field(default_factory=list)
    zips: list[pathlib.Path] = field(default_factory=list)
    packs: list[pathlib.Path] = field(default_factory=list)
    windows: list[pathlib.Path] = field(default_factory=list)
    linux: list[pathlib.Path] = field(default_factory=list)

    @property
    def is_empty(self) -> bool:
        return not (self.bundles or self.zips or self.packs or self.windows or self.linux)

    def bundle_executable(self) -> pathlib.Path | None:
        """The binary inside the first .app bundle, or None."""
        for bundle in self.bundles:
            found = sorted(p for p in bundle.glob(BUNDLE_EXEC_GLOB) if p.is_file())
            if found:
                return found[0]
        return None


def dest_for(run_id: str, root: pathlib.Path) -> pathlib.Path:
    """A destination named for the run.

    The run id is the whole point: it makes "which build did I verify?"
    answerable from the directory name, which a fixed `wc-latest-build` never
    could.
    """
    return root.expanduser() / f"wc-{run_id}"


def ensure_usable(dest: pathlib.Path, reuse: bool) -> None:
    """Refuse a destination that already holds something, unless asked twice."""
    if not dest.exists():
        return
    if any(dest.iterdir()):
        if not reuse:
            raise FetchError(
                f"{dest} already exists and is not empty. `gh run download` will "
                "abort partway through on the first colliding file, leaving a "
                "half-extracted tree that looks like a complete one.\n\n"
                "Pass --reuse to report on what is already there, or delete it:\n"
                f"    rm -rf {shlex.quote(str(dest))}"
            )


def download(run_id: str, dest: pathlib.Path) -> None:
    """Shell out to `gh run download`. Thin on purpose — see module docstring."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["gh", "run", "download", run_id, "-D", str(dest)],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise FetchError(f"gh run download failed ({proc.returncode}): {detail}")


def unpack_zips(root: pathlib.Path) -> list[pathlib.Path]:
    """Extract every zip in place, next to itself.

    Uses `unzip` rather than Python's zipfile deliberately: a macOS .app bundle
    carries symlinks and an executable bit, and zipfile preserves neither. An
    app extracted with zipfile looks right in `ls` and will not launch.
    """
    extracted: list[pathlib.Path] = []
    for archive in sorted(root.rglob("*.zip")):
        proc = subprocess.run(
            ["unzip", "-o", "-q", str(archive), "-d", str(archive.parent)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            detail = proc.stderr.strip() or proc.stdout.strip()
            raise FetchError(f"could not unzip {archive}: {detail}")
        extracted.append(archive)
    return extracted


def locate(root: pathlib.Path) -> Artifacts:
    """Find the bundle and the binaries by shape, never by name."""
    root = root.expanduser()
    if not root.is_dir():
        raise FetchError(f"not a directory: {root}")

    found = Artifacts(root=root)
    for path in sorted(root.rglob("*")):
        name = path.name
        if path.is_dir():
            if name.endswith(".app"):
                found.bundles.append(path)
            continue
        if name.endswith(".zip"):
            found.zips.append(path)
        elif name.endswith(".pck"):
            found.packs.append(path)
        elif name.endswith(".exe"):
            found.windows.append(path)
        elif name.endswith((".x86_64", ".arm64")):
            found.linux.append(path)
    return found


def report(found: Artifacts) -> list[str]:
    """Human-readable inventory."""
    lines = [f"Artifact tree: {found.root}", ""]
    if found.is_empty:
        lines.append("  nothing recognisable found — no .app, .pck, .exe or Linux binary.")
        return lines

    for label, paths in (
        ("macOS bundle", found.bundles),
        ("macOS zip", found.zips),
        ("pack", found.packs),
        ("Windows binary", found.windows),
        ("Linux binary", found.linux),
    ):
        for path in paths:
            lines.append(f"  {label:<15} {path.relative_to(found.root)}")
    return lines


def next_steps(found: Artifacts, repo: pathlib.Path | None = None) -> list[str]:
    """The exact commands to run next, with real names already quoted.

    Quoting is not a nicety here. The bundle is `Wildlife Crossing.app`; an
    unquoted command silently addresses `Wildlife` and reports No such file,
    which is precisely how the 2026-08-13 walkthrough stalled.
    """
    if not found.bundles:
        return []

    bundle = found.bundles[0]
    quoted = shlex.quote(str(bundle))
    lines = [
        "",
        "Next (macOS windowed launch):",
        f"    xattr -dr com.apple.quarantine {quoted}",
        f"    codesign -dv --verbose=2 {quoted} 2>&1 | head -5",
        f"    open {quoted}",
    ]

    executable = found.bundle_executable()
    if executable is not None:
        prefix = f"{repo}/" if repo else ""
        lines += [
            "",
            "Optional headless confirmation:",
            f"    {prefix}tools/smoke_boot.sh {shlex.quote(str(executable))} 20",
        ]
    return lines


def check_packs(found: Artifacts, data_dir: pathlib.Path, checker: pathlib.Path) -> int:
    """Run the pack gate over every pack, the way CI does. Returns a exit code.

    Every target is checked even after one fails, for the reason ci.yml gives:
    three platforms diverging three ways is one report worth reading.
    """
    targets = found.packs or found.bundles
    if not targets:
        print("no packs or bundles to check", file=sys.stderr)
        return 1
    failed = 0
    for target in targets:
        print(f"\n--- pack gate: {target.name} ---")
        proc = subprocess.run(
            [sys.executable, str(checker), str(target), "--data-dir", str(data_dir)]
        )
        if proc.returncode != 0:
            failed = 1
    return failed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="See docs/push-runbook.md Steps 4-5.",
    )
    parser.add_argument("run_id", nargs="?", help="the CI run id to download")
    parser.add_argument(
        "--locate",
        type=pathlib.Path,
        default=None,
        help="skip the download and report on an existing directory",
    )
    parser.add_argument(
        "--dest-root",
        type=pathlib.Path,
        default=pathlib.Path("~/Downloads"),
        help="where the run-scoped directory is created (default: ~/Downloads)",
    )
    parser.add_argument(
        "--reuse",
        action="store_true",
        help="report on an existing destination instead of refusing it",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="also run tools/check_pck_contents.py over every pack",
    )
    parser.add_argument(
        "--data-dir",
        type=pathlib.Path,
        default=pathlib.Path("game/data"),
        help="passed through to check_pck_contents.py (default: game/data)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    here = pathlib.Path(__file__).resolve().parent

    try:
        if args.locate is not None:
            dest = args.locate.expanduser()
        else:
            if not args.run_id:
                raise FetchError("a run id is required (or use --locate <dir>)")
            dest = dest_for(args.run_id, args.dest_root)
            ensure_usable(dest, args.reuse)
            if not (dest.exists() and args.reuse):
                download(args.run_id, dest)

        unpack_zips(dest)
        found = locate(dest)
        print("\n".join(report(found)))
        print("\n".join(next_steps(found, repo=here.parent)))

        if args.check:
            return check_packs(found, args.data_dir, here / "check_pck_contents.py")
        return 0

    except FetchError as exc:
        print(f"fetch_build.py: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
