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

3. ``resolve_pck`` on a ``.dmg`` — added for C11 (build-review C2, ADR 0018):
   the release image is what actually ships, and before this it was the one
   input shape the gate could not read at all. Mounting needs real
   ``hdiutil``, so most of ``TestMacosDmg`` skips where it is absent (CI's
   Tool-tests job runs on Linux); the "hdiutil is absent" error path itself
   is tested everywhere by mocking ``shutil.which``.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import contextlib
import io
import pathlib
import shutil
import struct
import subprocess
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
        return self.make_bundle_at(self.tmp / app, pck)

    def make_bundle_at(self, bundle: pathlib.Path, pck: str) -> pathlib.Path:
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


HDIUTIL_AVAILABLE = shutil.which("hdiutil") is not None


class TestMacosDmg(ResolveTestCase):
    """Covers C11: the release ``.dmg`` (ADR 0018, build-review C2).

    The tests that actually create and mount a disk image need real
    ``hdiutil`` and skip cleanly where it is absent — CI's Tool-tests job
    runs on Linux, which has none. The absent-``hdiutil`` error path is
    tested separately by mocking ``shutil.which``, so that one test runs on
    any host regardless of whether it actually has hdiutil.
    """

    def make_dmg(self, name: str, src: pathlib.Path) -> pathlib.Path:
        dmg = self.tmp / name
        proc = subprocess.run(
            [
                "hdiutil", "create", "-volname", "TestVolume",
                "-srcfolder", str(src), "-ov", "-format", "UDZO", str(dmg),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return dmg

    def test_hdiutil_absent_is_a_clear_locate_error(self) -> None:
        """Linux, or a Mac with a broken PATH — same failure either way."""
        with mock.patch("shutil.which", return_value=None):
            with self.assertRaises(gate.LocateError) as caught:
                with gate.resolve_pck(self.tmp / "wildlife-crossing.dmg"):
                    pass
        self.assertIn("hdiutil", str(caught.exception))
        self.assertIn("macOS", str(caught.exception))

    @unittest.skipUnless(HDIUTIL_AVAILABLE, "hdiutil not available on this host")
    def test_the_pack_is_found_inside_a_mounted_dmg(self) -> None:
        src = self.tmp / "src"
        self.make_bundle_at(src / "Wildlife Crossing.app", "Wildlife Crossing.pck")
        dmg = self.make_dmg("wildlife-crossing.dmg", src)
        with gate.resolve_pck(dmg) as resolved:
            self.assertEqual(resolved.name, "Wildlife Crossing.pck")
            self.assertEqual(resolved.read_bytes(), PCK_BYTES)
            mount_point = resolved.parent.parent.parent.parent
        self.assertFalse(mount_point.exists(), "the mount must be detached and cleaned up")

    @unittest.skipUnless(HDIUTIL_AVAILABLE, "hdiutil not available on this host")
    def test_a_dmg_without_an_app_is_a_locate_error(self) -> None:
        src = self.tmp / "src-empty"
        src.mkdir()
        (src / "README.txt").write_text("nothing here")
        dmg = self.make_dmg("empty.dmg", src)
        with self.assertRaises(gate.LocateError) as caught:
            with gate.resolve_pck(dmg):
                pass
        self.assertIn("not a Godot macOS disk image", str(caught.exception))

    @unittest.skipUnless(HDIUTIL_AVAILABLE, "hdiutil not available on this host")
    def test_two_apps_in_a_dmg_is_a_locate_error(self) -> None:
        src = self.tmp / "src-ambiguous"
        self.make_bundle_at(src / "One.app", "one.pck")
        self.make_bundle_at(src / "Two.app", "two.pck")
        dmg = self.make_dmg("ambiguous.dmg", src)
        with self.assertRaises(gate.LocateError) as caught:
            with gate.resolve_pck(dmg):
                pass
        self.assertIn("expected one", str(caught.exception))


class TestCriticalAssets(ResolveTestCase):
    """Covers the build-review V8 check in ``main``.

    The imported-form paths are the ones a real 4.6.3 export packs, read with
    inspect_pck.py from CI run 35916017446 on 2026-09-23. The original
    ``.wav`` and ``.png`` paths do not appear in that pack at all.
    """

    DATA_PATH = "res://data/species_stats.json"
    CHIME = "res://assets/audio/crossing_chime.wav"
    CUE = "res://assets/sprites/crossing_cue.png"
    CHIME_PACKED = [
        "res://assets/audio/crossing_chime.wav.import",
        "res://.godot/imported/crossing_chime.wav-d219d4c35414cb82104e0bb87a5155f7.sample",
    ]
    CUE_PACKED = [
        "res://assets/sprites/crossing_cue.png.import",
        "res://.godot/imported/crossing_cue.png-00899eee329faa48c03db87451178be5.ctex",
    ]

    def setUp(self) -> None:
        super().setUp()
        self.data_dir = self.tmp / "data"
        self.data_dir.mkdir()
        (self.data_dir / "species_stats.json").write_text("{}")

    def run_gate(self, paths: list[str]) -> tuple[int, str]:
        pck = self.tmp / "wildlife-crossing.pck"
        pck.write_bytes(build_pck([self.DATA_PATH, *paths]))
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

    def test_a_pack_with_both_assets_in_imported_form_passes(self) -> None:
        code, out = self.run_gate(self.CHIME_PACKED + self.CUE_PACKED)
        self.assertEqual(code, 0)
        self.assertIn("OK", out)
        self.assertNotIn("error:", out)

    def test_a_pack_missing_exactly_the_chime_is_reported_by_name(self) -> None:
        code, out = self.run_gate(self.CUE_PACKED)
        self.assertEqual(code, 1)
        self.assertIn(self.CHIME, out)
        self.assertNotIn(self.CUE, out)

    def test_a_pack_missing_exactly_the_cue_is_reported_by_name(self) -> None:
        code, out = self.run_gate(self.CHIME_PACKED)
        self.assertEqual(code, 1)
        self.assertIn(self.CUE, out)
        self.assertNotIn(self.CHIME, out)

    def test_a_remap_without_its_imported_payload_is_missing(self) -> None:
        code, out = self.run_gate([self.CHIME_PACKED[0]] + self.CUE_PACKED)
        self.assertEqual(code, 1)
        self.assertIn(self.CHIME, out)

    def test_an_asset_packed_under_its_own_name_passes(self) -> None:
        code, _ = self.run_gate([self.CHIME, self.CUE])
        self.assertEqual(code, 0)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
