#!/usr/bin/env python3
"""Tests for tools/suite_figures.py, the generated suite-size figures.

The cases worth reading are the two that encode findings rather than mechanics.
test_an_empty_result_file_refuses covers the trap CONTRIBUTING.md warns about —
GUT exits 0 when it collects nothing, so a broken discovery config and a passing
suite are indistinguishable by exit code, and a figures tool that reported
"0 scripts / 0 tests" would launder that into a number somebody would paste into
a review. test_stale_document_fails_with_the_line_number is the drift row this
script exists to close: docs/testing-setup.md has carried a stale figure at
eight consecutive build reviews.

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

import suite_figures  # noqa: E402


def xml(suites: list[tuple[str, list[int]]], failures: int = 0) -> str:
    """Build a GUT-shaped JUnit document: (script name, per-test assert counts)."""
    total = sum(len(asserts) for _, asserts in suites)
    out = ['<?xml version="1.0" encoding="UTF-8"?>']
    out.append(f'<testsuites name="GutTests" failures="{failures}" tests="{total}" >')
    for name, asserts in suites:
        out.append(
            f'  <testsuite name="{name}" tests="{len(asserts)}" '
            f'failures="0" skipped="0" time="0.001" >'
        )
        for i, count in enumerate(asserts):
            out.append(
                f'      <testcase name="test_{i}" assertions="{count}" '
                f'status="pass" classname="{name}" time="0.0001" >'
            )
            out.append("      </testcase>")
        out.append("  </testsuite>")
    out.append("</testsuites>")
    return "\n".join(out) + "\n"


class SuiteFiguresTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name)
        self.xml_path = self.root / "gut_results.xml"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_tool(self, *argv: str) -> tuple[int, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = suite_figures.main(["--xml", str(self.xml_path), *argv])
        return code, out.getvalue() + err.getvalue()

    # -- parsing ---------------------------------------------------------

    def test_counts_scripts_tests_and_asserts(self) -> None:
        self.xml_path.write_text(xml([("a.gd", [4, 1]), ("b.gd", [2])]), encoding="utf-8")
        figures = suite_figures.parse(self.xml_path)
        self.assertEqual((figures.scripts, figures.tests, figures.asserts), (2, 3, 7))

    def test_thousands_separator_matches_the_prose_convention(self) -> None:
        self.xml_path.write_text(xml([("a.gd", [3154])]), encoding="utf-8")
        code, output = self.run_tool("--print")
        self.assertEqual(code, 0, output)
        self.assertIn("3,154 asserts", output)

    def test_an_empty_result_file_refuses(self) -> None:
        """GUT exits 0 on 'Nothing was run'. Do not turn that into a figure."""
        self.xml_path.write_text(xml([]), encoding="utf-8")
        code, output = self.run_tool("--print")
        self.assertEqual(code, 2, output)
        self.assertIn("broken discovery config", output)

    def test_missing_file_refuses(self) -> None:
        code, output = self.run_tool("--print")
        self.assertEqual(code, 2, output)

    def test_malformed_xml_refuses(self) -> None:
        self.xml_path.write_text("<testsuites", encoding="utf-8")
        code, output = self.run_tool("--print")
        self.assertEqual(code, 2, output)

    def test_non_numeric_assertions_refuses_rather_than_counting_zero(self) -> None:
        self.xml_path.write_text(
            xml([("a.gd", [1])]).replace('assertions="1"', 'assertions="lots"'),
            encoding="utf-8",
        )
        code, output = self.run_tool("--print")
        self.assertEqual(code, 2, output)

    # -- checking a document ---------------------------------------------

    def test_matching_document_passes(self) -> None:
        self.xml_path.write_text(xml([("a.gd", [4, 1]), ("b.gd", [2])]), encoding="utf-8")
        doc = self.root / "doc.md"
        doc.write_text("the suite reports 2 scripts / 3 tests / 7 asserts today\n",
                       encoding="utf-8")
        code, output = self.run_tool("--check", str(doc))
        self.assertEqual(code, 0, output)

    def test_stale_document_fails_with_the_line_number(self) -> None:
        self.xml_path.write_text(xml([("a.gd", [4, 1]), ("b.gd", [2])]), encoding="utf-8")
        doc = self.root / "doc.md"
        doc.write_text(
            "# Testing\n\nintro\n\nthe suite reports 16 scripts / 134 tests / 2,779 asserts\n",
            encoding="utf-8",
        )
        code, output = self.run_tool("--check", str(doc))
        self.assertEqual(code, 1, output)
        self.assertIn(":5", output)
        self.assertIn("2 scripts / 3 tests / 7 asserts", output)

    def test_commas_are_optional_on_the_way_in(self) -> None:
        self.xml_path.write_text(xml([("a.gd", [1000, 1000, 1154])]), encoding="utf-8")
        doc = self.root / "doc.md"
        doc.write_text("1 scripts / 3 tests / 3154 asserts\n", encoding="utf-8")
        code, output = self.run_tool("--check", str(doc))
        self.assertEqual(code, 0, output)

    def test_a_document_with_no_figures_refuses(self) -> None:
        """Silence is not agreement — say the check had nothing to compare."""
        self.xml_path.write_text(xml([("a.gd", [1])]), encoding="utf-8")
        doc = self.root / "doc.md"
        doc.write_text("no numbers here\n", encoding="utf-8")
        code, output = self.run_tool("--check", str(doc))
        self.assertEqual(code, 2, output)
        self.assertIn("nothing to check", output)

    def test_every_occurrence_is_checked_not_just_the_first(self) -> None:
        self.xml_path.write_text(xml([("a.gd", [1])]), encoding="utf-8")
        doc = self.root / "doc.md"
        doc.write_text("1 scripts / 1 tests / 1 asserts\n\n9 scripts / 9 tests / 9 asserts\n",
                       encoding="utf-8")
        code, output = self.run_tool("--check", str(doc))
        self.assertEqual(code, 1, output)
        self.assertIn(":3", output)


if __name__ == "__main__":
    unittest.main()
