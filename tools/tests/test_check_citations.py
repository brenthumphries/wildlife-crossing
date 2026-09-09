#!/usr/bin/env python3
"""Tests for tools/check_citations.py, the line-number citation reporter.

The false-positive cases carry the weight here. A reporter that flags a clock
time or a semantic version produces a list nobody reads, and an advisory check
nobody reads is worse than no check — it looks like coverage. So most of what
follows asserts silence.

test_reports_the_shapes_the_notes_actually_use is the other half: the four
citation forms are taken from real sentences in the 09-08 review and the 09-09
log, not invented.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import io
import pathlib
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import check_citations  # noqa: E402


class CitationTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def note(self, text: str) -> pathlib.Path:
        path = self.root / "note.md"
        path.write_text(text, encoding="utf-8")
        return path

    def run_tool(self, path: pathlib.Path, *argv: str) -> tuple[int, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = check_citations.main([str(path), *argv])
        return code, out.getvalue() + err.getvalue()

    # -- what it must find -----------------------------------------------

    def test_reports_the_shapes_the_notes_actually_use(self) -> None:
        found = check_citations.citations(
            "`ci.yml:294`'s wrong-scene job name\n"
            "[signing-runbook.md](../../docs/signing-runbook.md):392 says\n"
            "the runbook had it at `:392` and sends it to `:452`\n"
            "testing-setup.md:69-70 states the suite size\n"
        )
        snippets = [s for _, s in found]
        self.assertIn("ci.yml:294", snippets)
        self.assertIn("signing-runbook.md:392", snippets)
        self.assertIn("`:392`", snippets)
        self.assertIn("testing-setup.md:69-70", snippets)

    def test_reports_the_line_the_citation_is_on(self) -> None:
        found = check_citations.citations("first\nsecond\nmain.gd:18 here\n")
        self.assertEqual(found, [(3, "main.gd:18")])

    def test_gdscript_and_json_and_scene_paths_count(self) -> None:
        found = check_citations.citations(
            "game/scripts/main.gd:215 and species_stats.json:4 and Main.tscn:9\n"
        )
        self.assertEqual(len(found), 3)

    # -- what it must stay quiet about -----------------------------------

    def test_clock_times_are_not_citations(self) -> None:
        self.assertEqual(check_citations.citations("merged at 22:53 -05:00\n"), [])

    def test_semantic_versions_are_not_citations(self) -> None:
        self.assertEqual(check_citations.citations("tag v0.1.0:3 is not a thing\n"), [])

    def test_urls_with_ports_and_fragments_are_not_citations(self) -> None:
        self.assertEqual(
            check_citations.citations(
                "see https://example.com/a.md:12 and http://localhost:8080/x\n"
            ),
            [],
        )

    def test_a_bare_colon_number_outside_backticks_is_not_a_citation(self) -> None:
        """Prose like 'the score was 3:1' must not be flagged."""
        self.assertEqual(check_citations.citations("the score was 3:1 at half\n"), [])

    def test_a_clean_note_says_so(self) -> None:
        path = self.note("Cite the **Export desktop builds** job, not a line.\n")
        code, output = self.run_tool(path)
        self.assertEqual(code, 0, output)
        self.assertIn("no line-number citations", output)

    # -- severity --------------------------------------------------------

    def test_advisory_by_default(self) -> None:
        path = self.note("ci.yml:294 is wrong\n")
        code, output = self.run_tool(path)
        self.assertEqual(code, 0, output)
        self.assertIn("1 line-number citation", output)

    def test_strict_fails(self) -> None:
        path = self.note("ci.yml:294 is wrong\n")
        code, output = self.run_tool(path, "--strict")
        self.assertEqual(code, 1, output)

    def test_missing_file_is_a_distinct_exit_code(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = check_citations.main([str(self.root / "nope.md")])
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
