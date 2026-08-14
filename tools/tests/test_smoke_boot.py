#!/usr/bin/env python3
"""Tests for tools/smoke_boot.sh, the exported-binary boot gate.

Unlike the other tools tests these need no git repo — they drive the script's
``--check-log`` mode, which is the whole analysis path with the launching cut
off the front. That mode exists precisely so the log analysis can be exercised
without an engine, an export, or a runner.

The fixtures are not invented. ``windows_at_exit_log`` reproduces the real
output of CI run 31760975487 (2026-08-13), the first run in which the Windows
smoke job ever actually executed the binary: both boots reached their expected
state and were then killed by ``timeout`` at 30s, and Godot's shutdown path on
Windows emitted 25 and 28 ``ERROR:`` lines on the way out. Every one was an
at-exit report; the Linux boot of the same commit logged none. The gate failed
a healthy build, so BENIGN_PATTERNS was added.

That is a dangerous kind of fix — an allowlist is one careless widening away
from a gate that cannot fail, which is the exact defect this script was written
to replace (the ``head -20`` truncation, 2026-07-28 build review). So most of
what follows is the failing side, and the tightness cases matter most: a leak
of a *game* type must still fail even though a leak of the two engine parser
types is ignored.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "smoke_boot.sh"

TITLE_LINE = "Title screen ready"
SUCCESS_LINE = "Tutorial loaded"

# The two engine parser types actually observed leaking at exit, and the Variant
# pool actually observed with pages in use. Named exactly, so that a game type
# leaking is not swept up with them.
ENGINE_TAIL = [
    "ERROR: 7 RID allocations of type '23NavMeshGeometryParser2D' were leaked at exit.",
    "ERROR: 6 RID allocations of type '23NavMeshGeometryParser3D' were leaked at exit.",
    "ERROR: Pages in use exist at exit in PagedAllocator: N7Variant5Pools11BucketLargeE",
    "   at: ~PagedAllocator (./core/templates/paged_allocator.h:169)",
]

# Abridged from the real run; the names differ between the two boots but the
# shape does not, and the shape is what the allowlist matches on.
UNREFERENCED_STRINGS = [
    "_draw",
    "_shaped_text_get_line_breaks",
    ".",
    "_physics_process",
    "_process",
    "_unhandled_key_input",
    "_enter_tree",
    "Variant",
    "@warning_ignore",
    "@export",
    "@icon",
]


def windows_at_exit_log(reached: str) -> list[str]:
    """A healthy Windows boot: reaches ``reached``, then is killed at 30s."""
    lines = [
        "Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org",
        "",
        f"[I] {reached}",
    ]
    for name in UNREFERENCED_STRINGS:
        lines.append(f"ERROR: BUG: Unreferenced static string to 0: {name}")
        lines.append("   at: unref (core/string/string_name.cpp:116)")
    lines.extend(ENGINE_TAIL)
    return lines


class SmokeBootTestCase(unittest.TestCase):
    def check(self, lines: list[str], expected: str) -> tuple[int, str]:
        """Run the script's --check-log mode over ``lines``."""
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as handle:
            handle.write("\n".join(lines) + "\n")
            path = handle.name
        self.addCleanup(lambda: pathlib.Path(path).unlink(missing_ok=True))
        proc = subprocess.run(
            ["bash", str(SCRIPT), "--check-log", path, expected],
            capture_output=True,
            text=True,
        )
        return proc.returncode, proc.stdout + proc.stderr

    # -- the healthy side ------------------------------------------------

    def test_windows_title_boot_passes_despite_at_exit_noise(self) -> None:
        rc, _ = self.check(windows_at_exit_log(TITLE_LINE), TITLE_LINE)
        self.assertEqual(rc, 0, "a healthy Windows title boot must not fail the gate")

    def test_windows_tutorial_boot_passes_despite_at_exit_noise(self) -> None:
        rc, _ = self.check(windows_at_exit_log(SUCCESS_LINE), SUCCESS_LINE)
        self.assertEqual(rc, 0, "a healthy Windows tutorial boot must not fail the gate")

    def test_clean_log_passes_and_ignores_nothing(self) -> None:
        rc, out = self.check(
            ["Godot Engine v4.6.3.stable.official.7d41c59c4", f"[I] {SUCCESS_LINE}"],
            SUCCESS_LINE,
        )
        self.assertEqual(rc, 0)
        self.assertNotIn("at-exit engine diagnostic", out)

    def test_says_how_many_lines_it_ignored(self) -> None:
        """A silent filter is how a gate stops being one. It must report."""
        log = windows_at_exit_log(SUCCESS_LINE)
        expected_ignored = sum(
            1
            for line in log
            if line.startswith("ERROR: BUG: Unreferenced static string to 0:")
            or "RID allocations of type '23NavMeshGeometryParser" in line
            or line.startswith("ERROR: Pages in use exist at exit in PagedAllocator: N7Variant5Pools")
        )
        rc, out = self.check(log, SUCCESS_LINE)
        self.assertEqual(rc, 0)
        self.assertIn(f"ignored {expected_ignored} at-exit engine diagnostic", out)

    # -- the failing side: the gate must still reject ---------------------

    def test_missing_data_files_still_fails(self) -> None:
        log = windows_at_exit_log(SUCCESS_LINE)
        log.append("ERROR: Data file missing: res://data/animals.json")
        rc, out = self.check(log, SUCCESS_LINE)
        self.assertEqual(rc, 1)
        self.assertIn("Data file missing", out)

    def test_script_error_still_fails(self) -> None:
        log = windows_at_exit_log(SUCCESS_LINE)
        log.append("SCRIPT ERROR: Invalid call to function 'move' on a null instance")
        rc, out = self.check(log, SUCCESS_LINE)
        self.assertEqual(rc, 1)
        self.assertIn("SCRIPT ERROR", out)

    def test_a_game_type_rid_leak_still_fails(self) -> None:
        """Allowlist tightness. The two engine parser types are ignored by name;
        anything else leaking must not be."""
        log = windows_at_exit_log(SUCCESS_LINE)
        log.append("ERROR: 3 RID allocations of type '10GameEntity' were leaked at exit.")
        rc, out = self.check(log, SUCCESS_LINE)
        self.assertEqual(rc, 1, "a leaked game type must not be swept up with the engine ones")
        self.assertIn("ERROR:", out)

    def test_a_non_variant_paged_allocator_still_fails(self) -> None:
        log = windows_at_exit_log(SUCCESS_LINE)
        log.append("ERROR: Pages in use exist at exit in PagedAllocator: N4Game5PoolE")
        rc, _ = self.check(log, SUCCESS_LINE)
        self.assertEqual(rc, 1)

    def test_an_unrecognised_engine_error_still_fails(self) -> None:
        log = windows_at_exit_log(SUCCESS_LINE)
        log.append('ERROR: Condition "!agent" is true. Returning: false')
        rc, _ = self.check(log, SUCCESS_LINE)
        self.assertEqual(rc, 1, "the allowlist must not generalise beyond what it names")

    def test_never_reaching_the_expected_state_fails(self) -> None:
        log = [line for line in windows_at_exit_log(SUCCESS_LINE) if SUCCESS_LINE not in line]
        rc, out = self.check(log, SUCCESS_LINE)
        self.assertEqual(rc, 1)
        self.assertIn("did not reach the expected state", out)

    def test_title_boot_that_never_reached_the_title_fails(self) -> None:
        log = windows_at_exit_log(SUCCESS_LINE)
        rc, _ = self.check(log, TITLE_LINE)
        self.assertEqual(rc, 1, "reaching the tutorial is not evidence the title screen loaded")


if __name__ == "__main__":
    unittest.main()
