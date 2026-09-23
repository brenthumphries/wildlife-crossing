#!/usr/bin/env python3
"""Tests for tools/check_pck_contents.py.

Two things are covered:

1. ``resolve_pck`` — *finding* the pack for the two platforms whose packs
   were never checked before build-review V2. The contents assertions it
   feeds were, at the time this suite was written, already exercised every
   CI run against a real exported pack, so building a valid Godot pack
   byte-by-byte in a fixture would test this suite's understanding of the
   format rather than the gate. The case that motivates the whole thing: a
   macOS bundle names its pack from the project's ``config/name``, not from
   the export path. This project exports ``wildlife-crossing.zip`` and the
   pack inside is ``Wildlife Crossing.pck`` — different capitalisation, and a
   space. Every assertion in that section uses a pack name that differs from
   its container's, so a reconstructed filename cannot pass.

2. ``main`` — the critical-asset check added for build-review V8. That check
   is genuinely untested by the CI smoke boot: a missing preloaded asset
   fails the smoke boot too, but only reports "the binary did not boot", not
   which asset is gone (see the module docstring of check_pck_contents.py).
   Exercising it needs a minimal but real pack directory, built below with
   ``build_pck`` against the format ``inspect_pck.read_pck_paths`` parses.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import contextlib
import io
import pathlib
import struct
import sys
import tempfile
import unittest
import zipfile
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import check_pck_contents as gate  # noqa: E402

PACK_MAGIC = 0x43504447  # "GDPC" — see tools/inspect_pck.py


def build_pck(paths: list[str]) -> bytes:
    """Build a minimal but real Godot pack directory (format version 1).

    Only the directory is written — ``read_pck_paths`` never dereferences the
    per-file offset/size, so no file payload is needed to exercise the gate.
    """
    blob = bytearray()
    blob += struct.pack("<I", PACK_MAGIC)
    blob += struct.pack("<4I", 1, 4, 0, 0)  # version 1, "Godot 4.0.0"
    blob += b"\x00" * 64  # reserved (format <=2 keeps the directory inline)
    blob += struct.pack("<I", len(paths))
    for path in paths:
        raw = path.encode("utf-8")
        blob += struct.pack("<I", len(raw))
        blob += raw
        blob += struct.pack("<QQ", 0, 0)  # offset, size
        blob += b"\x00" * 16  # md5
    return bytes(blob)

PCK_BYTES = b"GDPC-not-really-but-resolve_pck-never-parses-it"


class ResolveTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = pathlib.Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def make_bundle(self, app: str, pck: str) -> pathlib.Path:
        bundle = self.tmp / app
        resources = bundle / "Contents" / "Resources"
        resources.mkdir(parents=True)
        (resources / pck).write_bytes(PCK_BYTES)
        (bundle / "Contents" / "MacOS").mkdir()
        return bundle

    def make_zip(self, name: str, members: dict[str, bytes]) -> pathlib.Path:
        path = self.tmp / name
        with zipfile.ZipFile(path, "w") as archive:
            for member, payload in members.items():
                archive.writestr(member, payload)
        return path


class TestPlainPck(ResolveTestCase):
    def test_a_pck_resolves_to_itself(self) -> None:
        pck = self.tmp / "wildlife-crossing.pck"
        pck.write_bytes(PCK_BYTES)
        with gate.resolve_pck(pck) as resolved:
            self.assertEqual(resolved, pck)

    def test_a_missing_file_is_a_locate_error(self) -> None:
        with self.assertRaises(gate.LocateError) as caught:
            with gate.resolve_pck(self.tmp / "absent.pck"):
                pass
        self.assertIn("no such file", str(caught.exception))


class TestAppBundle(ResolveTestCase):
    def test_the_pack_is_found_by_glob_not_by_name(self) -> None:
        """The export path is wildlife-crossing; the pack is Wildlife Crossing."""
        bundle = self.make_bundle("Wildlife Crossing.app", "Wildlife Crossing.pck")
        with gate.resolve_pck(bundle) as resolved:
            self.assertEqual(resolved.name, "Wildlife Crossing.pck")
            self.assertEqual(resolved.read_bytes(), PCK_BYTES)

    def test_an_unrelated_pack_name_still_resolves(self) -> None:
        """config/name can be anything; the gate must not care."""
        bundle = self.make_bundle("Something Else.app", "Totally Different.pck")
        with gate.resolve_pck(bundle) as resolved:
            self.assertEqual(resolved.name, "Totally Different.pck")

    def test_a_bundle_without_a_pack_is_a_locate_error(self) -> None:
        bundle = self.tmp / "Empty.app"
        (bundle / "Contents" / "Resources").mkdir(parents=True)
        with self.assertRaises(gate.LocateError) as caught:
            with gate.resolve_pck(bundle):
                pass
        self.assertIn("not a Godot macOS bundle", str(caught.exception))

    def test_two_packs_are_refused_rather_than_guessed(self) -> None:
        bundle = self.make_bundle("Ambiguous.app", "one.pck")
        (bundle / "Contents" / "Resources" / "two.pck").write_bytes(PCK_BYTES)
        with self.assertRaises(gate.LocateError) as caught:
            with gate.resolve_pck(bundle):
                pass
        self.assertIn("expected one", str(caught.exception))


class TestMacosZip(ResolveTestCase):
    def test_the_pack_is_extracted_from_the_zip(self) -> None:
        archive = self.make_zip(
            "wildlife-crossing.zip",
            {
                "Wildlife Crossing.app/Contents/Info.plist": b"<plist/>",
                "Wildlife Crossing.app/Contents/MacOS/Wildlife Crossing": b"\x7fELF",
                "Wildlife Crossing.app/Contents/Resources/Wildlife Crossing.pck": PCK_BYTES,
            },
        )
        with gate.resolve_pck(archive) as resolved:
            self.assertEqual(resolved.name, "Wildlife Crossing.pck")
            self.assertEqual(resolved.read_bytes(), PCK_BYTES)

    def test_the_extraction_directory_is_cleaned_up(self) -> None:
        archive = self.make_zip(
            "wildlife-crossing.zip",
            {"App.app/Contents/Resources/App.pck": PCK_BYTES},
        )
        with gate.resolve_pck(archive) as resolved:
            extracted = resolved
            self.assertTrue(extracted.exists())
        self.assertFalse(extracted.exists())

    def test_a_zip_without_a_pack_is_a_locate_error(self) -> None:
        archive = self.make_zip("empty.zip", {"README.txt": b"nothing here"})
        with self.assertRaises(gate.LocateError) as caught:
            with gate.resolve_pck(archive):
                pass
        self.assertIn("is this the macOS export?", str(caught.exception))

    def test_a_pck_outside_a_bundle_does_not_count(self) -> None:
        """A loose pck in a zip is not a macOS export and should not be gated.

        Matching any ``*.pck`` anywhere in the archive would silently accept a
        differently-shaped artifact and report on something that is not what
        ships.
        """
        archive = self.make_zip("loose.zip", {"wildlife-crossing.pck": PCK_BYTES})
        with self.assertRaises(gate.LocateError):
            with gate.resolve_pck(archive):
                pass

    def test_a_file_that_is_not_a_zip_is_a_locate_error(self) -> None:
        path = self.tmp / "broken.zip"
        path.write_bytes(b"this is not a zip archive")
        with self.assertRaises(gate.LocateError) as caught:
            with gate.resolve_pck(path):
                pass
        self.assertIn("could not open", str(caught.exception))


class TestCriticalAssets(ResolveTestCase):
    """Covers the build-review V8 check in ``main``."""

    DATA_PATH = "res://data/species_stats.json"
    CHIME = "res://assets/audio/crossing_chime.wav"
    CUE = "res://assets/sprites/crossing_cue.png"

    def setUp(self) -> None:
        super().setUp()
        self.data_dir = self.tmp / "data"
        self.data_dir.mkdir()
        (self.data_dir / "species_stats.json").write_text("{}")

    def run_gate(self, pck: pathlib.Path) -> tuple[int, str]:
        argv = [
            "check_pck_contents.py",
            str(pck),
            "--data-dir",
            str(self.data_dir),
        ]
        out = io.StringIO()
        with mock.patch.object(sys, "argv", argv):
            with contextlib.redirect_stdout(out):
                code = gate.main()
        return code, out.getvalue()

    def test_a_pack_missing_exactly_the_chime_is_reported_by_name(self) -> None:
        pck = self.tmp / "wildlife-crossing.pck"
        pck.write_bytes(build_pck([self.DATA_PATH, self.CUE]))
        code, out = self.run_gate(pck)
        self.assertEqual(code, 1)
        self.assertIn(self.CHIME, out)
        self.assertNotIn(self.CUE, out)

    def test_a_pack_missing_exactly_the_cue_is_reported_by_name(self) -> None:
        pck = self.tmp / "wildlife-crossing.pck"
        pck.write_bytes(build_pck([self.DATA_PATH, self.CHIME]))
        code, out = self.run_gate(pck)
        self.assertEqual(code, 1)
        self.assertIn(self.CUE, out)
        self.assertNotIn(self.CHIME, out)

    def test_a_pack_with_both_assets_passes(self) -> None:
        pck = self.tmp / "wildlife-crossing.pck"
        pck.write_bytes(build_pck([self.DATA_PATH, self.CHIME, self.CUE]))
        code, out = self.run_gate(pck)
        self.assertEqual(code, 0)
        self.assertIn("OK", out)
        self.assertNotIn("error:", out)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
