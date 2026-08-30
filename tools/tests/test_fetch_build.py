#!/usr/bin/env python3
"""Tests for tools/fetch_build.py, the build-artifact fetcher.

Nothing here touches the network or `gh`. The download is a three-line
shell-out and is not the part that rots; the *locating* is, and that is pure.

The fixtures are shaped like the real thing, which is the whole point. Every
bundle in these tests is named ``Wildlife Crossing.app`` — space, capitals,
nothing like the ``wildlife-crossing.zip`` that produced it — because that
mismatch is what broke the runbook's Step 5 on 2026-08-13, and a fixture named
``wildlife-crossing.app`` would pass while proving nothing.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import pathlib
import shlex
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import fetch_build  # noqa: E402

BUNDLE = "Wildlife Crossing.app"
PACK = "Wildlife Crossing.pck"


class FetchBuildTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    # -- helpers ---------------------------------------------------------

    def make_artifact_tree(self, base: pathlib.Path | None = None) -> pathlib.Path:
        """A tree shaped like a real `gh run download` extraction."""
        base = base or (self.root / "wc-31762062722")
        wrapper = base / "wildlife-crossing-desktop-builds"

        macos = wrapper / "wildlife-crossing-macos"
        resources = macos / BUNDLE / "Contents" / "Resources"
        resources.mkdir(parents=True)
        (resources / PACK).write_bytes(b"GDPC")
        macos_bin = macos / BUNDLE / "Contents" / "MacOS"
        macos_bin.mkdir(parents=True)
        (macos_bin / "Wildlife Crossing").write_bytes(b"\x7fELF")
        (macos / "wildlife-crossing.zip").write_bytes(b"PK\x03\x04")

        linux = wrapper / "wildlife-crossing-linux-x86_64"
        linux.mkdir(parents=True)
        (linux / "wildlife-crossing.x86_64").write_bytes(b"\x7fELF")
        (linux / "wildlife-crossing.pck").write_bytes(b"GDPC")

        windows = wrapper / "wildlife-crossing-windows-x86_64"
        windows.mkdir(parents=True)
        (windows / "wildlife-crossing.exe").write_bytes(b"MZ")
        (windows / "wildlife-crossing.pck").write_bytes(b"GDPC")

        return base

    # -- the destination is named for the run ----------------------------

    def test_destination_carries_the_run_id(self) -> None:
        """"Which build did I verify?" must be answerable from the path."""
        dest = fetch_build.dest_for("31762062722", self.root)
        self.assertEqual(dest.name, "wc-31762062722")
        self.assertIn("31762062722", str(dest))

    def test_two_runs_do_not_share_a_directory(self) -> None:
        first = fetch_build.dest_for("111", self.root)
        second = fetch_build.dest_for("222", self.root)
        self.assertNotEqual(first, second)

    def test_refuses_a_destination_that_already_holds_something(self) -> None:
        """The `file exists` abort, caught before it half-extracts."""
        dest = self.root / "wc-1"
        (dest / "wildlife-crossing-desktop-builds").mkdir(parents=True)
        (dest / "wildlife-crossing-desktop-builds" / "stale.pck").write_bytes(b"GDPC")
        with self.assertRaises(fetch_build.FetchError) as caught:
            fetch_build.ensure_usable(dest, reuse=False)
        self.assertIn("not empty", str(caught.exception))

    def test_reuse_allows_an_existing_destination(self) -> None:
        dest = self.root / "wc-1"
        dest.mkdir()
        (dest / "thing.pck").write_bytes(b"GDPC")
        fetch_build.ensure_usable(dest, reuse=True)  # must not raise

    def test_a_fresh_destination_is_fine(self) -> None:
        fetch_build.ensure_usable(self.root / "wc-nonexistent", reuse=False)

    def test_an_empty_destination_is_fine(self) -> None:
        dest = self.root / "wc-empty"
        dest.mkdir()
        fetch_build.ensure_usable(dest, reuse=False)

    # -- locating by shape, not by name ----------------------------------

    def test_finds_a_bundle_whose_name_does_not_match_its_zip(self) -> None:
        """The 2026-08-13 failure. The bundle is named from config/name."""
        found = fetch_build.locate(self.make_artifact_tree())
        self.assertEqual(len(found.bundles), 1)
        self.assertEqual(found.bundles[0].name, BUNDLE)
        self.assertNotEqual(found.bundles[0].name, "wildlife-crossing.app")

    def test_finds_every_pack_including_the_one_inside_the_bundle(self) -> None:
        found = fetch_build.locate(self.make_artifact_tree())
        names = sorted(p.name for p in found.packs)
        self.assertEqual(names, ["Wildlife Crossing.pck", "wildlife-crossing.pck",
                                 "wildlife-crossing.pck"])

    def test_finds_the_windows_and_linux_binaries(self) -> None:
        found = fetch_build.locate(self.make_artifact_tree())
        self.assertEqual([p.name for p in found.windows], ["wildlife-crossing.exe"])
        self.assertEqual([p.name for p in found.linux], ["wildlife-crossing.x86_64"])

    def test_finds_the_executable_inside_the_bundle(self) -> None:
        found = fetch_build.locate(self.make_artifact_tree())
        executable = found.bundle_executable()
        self.assertIsNotNone(executable)
        self.assertEqual(executable.name, "Wildlife Crossing")
        self.assertIn("Contents/MacOS", str(executable))

    def test_a_bundle_is_a_directory_not_a_file(self) -> None:
        """A .app is a directory. Treating it as a file finds nothing."""
        found = fetch_build.locate(self.make_artifact_tree())
        self.assertTrue(found.bundles[0].is_dir())

    def test_an_empty_tree_reports_empty_rather_than_crashing(self) -> None:
        empty = self.root / "wc-empty"
        empty.mkdir()
        found = fetch_build.locate(empty)
        self.assertTrue(found.is_empty)
        self.assertIn("nothing recognisable", "\n".join(fetch_build.report(found)))

    def test_locating_a_missing_directory_refuses(self) -> None:
        with self.assertRaises(fetch_build.FetchError):
            fetch_build.locate(self.root / "nope")

    # -- the emitted commands --------------------------------------------

    def test_every_emitted_path_survives_the_shell_as_one_argument(self) -> None:
        """The property that matters: unquoted, `xattr` addresses `Wildlife`
        and reports No such file, which is how Step 5 stalled on 2026-08-13.
        Re-parsing each command the way a shell would is the real check —
        asserting on quote characters would pass for the wrong reasons."""
        found = fetch_build.locate(self.make_artifact_tree())
        bundle = str(found.bundles[0])
        self.assertIn(" ", bundle, "fixture must have a space or this proves nothing")

        commands = [
            line.strip()
            for line in "\n".join(fetch_build.next_steps(found)).splitlines()
            if line.startswith("    ")
        ]
        self.assertTrue(commands)
        for command in commands:
            tokens = shlex.split(command.split("2>&1")[0])
            self.assertTrue(
                any(token == bundle or token.startswith(bundle + "/") for token in tokens),
                f"bundle path did not survive shell parsing as one token: {command}",
            )

    def test_next_steps_cover_quarantine_signature_and_launch(self) -> None:
        found = fetch_build.locate(self.make_artifact_tree())
        steps = "\n".join(fetch_build.next_steps(found))
        self.assertIn("com.apple.quarantine", steps)
        self.assertIn("codesign", steps)
        self.assertIn("open ", steps)

    def test_next_steps_offer_the_smoke_boot_command_with_the_real_binary(self) -> None:
        found = fetch_build.locate(self.make_artifact_tree())
        steps = "\n".join(fetch_build.next_steps(found))
        self.assertIn("smoke_boot.sh", steps)
        self.assertIn("'", steps)  # the path is quoted

    def test_no_bundle_means_no_macos_steps(self) -> None:
        linux_only = self.root / "wc-linux"
        (linux_only / "builds").mkdir(parents=True)
        (linux_only / "builds" / "wildlife-crossing.x86_64").write_bytes(b"\x7fELF")
        found = fetch_build.locate(linux_only)
        self.assertEqual(fetch_build.next_steps(found), [])


if __name__ == "__main__":
    unittest.main()
