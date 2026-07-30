#!/usr/bin/env python3
"""Parse a Godot .pck and list the resource paths it actually contains.

Written for the 2026-07-28 export defect: the shipped build contained no
`data/*.json` at all, and a plain `strings`/grep scan could not prove it either
way because script bytecode and the global class cache mention paths that are
not packed. Reading the pack directory is the only reliable answer.

Format reference: `core/io/file_access_pack.cpp` (Godot 4.x).

Usage:
    inspect_pck.py <file.pck> [--prefix res://data/]
"""

from __future__ import annotations

import argparse
import struct
import sys

PACK_MAGIC = 0x43504447  # "GDPC"


class PckError(Exception):
    pass


def read_pck_paths(path: str) -> tuple[list[str], dict]:
    """Return (sorted resource paths, header info) for a Godot .pck file."""
    with open(path, "rb") as fh:
        blob = fh.read()

    if len(blob) < 4:
        raise PckError(f"{path}: too small to be a pck ({len(blob)} bytes)")

    magic = struct.unpack_from("<I", blob, 0)[0]
    if magic != PACK_MAGIC:
        # A self-contained export embeds the pck at the end of the binary and
        # repeats the magic as a footer; we only support standalone .pck here.
        raise PckError(
            f"{path}: not a standalone Godot pack "
            f"(magic {magic:#010x}, expected {PACK_MAGIC:#010x})"
        )

    off = 4
    version, ver_major, ver_minor, ver_patch = struct.unpack_from("<4I", blob, off)
    off += 16

    pack_flags = 0
    if version >= 2:
        pack_flags = struct.unpack_from("<I", blob, off)[0]
        off += 4
        off += 8  # file_base (u64), unused when reading the directory only

    if pack_flags & 1:  # PACK_DIR_ENCRYPTED
        raise PckError(f"{path}: pack directory is encrypted; cannot inspect")

    if version >= 3:
        # Format 3 moved the file directory to the end of the pack (so file
        # data can be written as a stream) and records its offset here. The
        # 16 reserved words follow it, then padding out to `file_base`.
        (dir_offset,) = struct.unpack_from("<Q", blob, off)
        off = dir_offset
    else:
        off += 16 * 4  # reserved; format <=2 keeps the directory inline

    file_count = struct.unpack_from("<I", blob, off)[0]
    off += 4

    if file_count > 1_000_000:
        raise PckError(
            f"{path}: implausible file count {file_count} — unrecognised pack "
            f"format version {version}"
        )

    paths: list[str] = []
    for i in range(file_count):
        (path_len,) = struct.unpack_from("<I", blob, off)
        off += 4
        raw = blob[off : off + path_len]
        off += path_len
        entry = raw.rstrip(b"\x00").decode("utf-8", errors="replace")
        # Format 3 stores paths relative to the project root; earlier formats
        # keep the `res://` prefix. Normalise so callers can match one shape.
        if not entry.startswith("res://"):
            entry = "res://" + entry.lstrip("/")
        paths.append(entry)
        off += 8 + 8 + 16  # offset, size, md5
        if version >= 2:
            off += 4  # per-file flags

    info = {
        "version": version,
        "godot": f"{ver_major}.{ver_minor}.{ver_patch}",
        "file_count": file_count,
    }
    return sorted(paths), info


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("pck")
    ap.add_argument("--prefix", help="only list paths starting with this prefix")
    args = ap.parse_args()

    try:
        paths, info = read_pck_paths(args.pck)
    except (PckError, OSError, struct.error) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.prefix:
        paths = [p for p in paths if p.startswith(args.prefix)]

    for p in paths:
        print(p)
    print(
        f"\n{len(paths)} path(s) listed; pack format {info['version']}, "
        f"built by Godot {info['godot']}, {info['file_count']} file(s) total.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
