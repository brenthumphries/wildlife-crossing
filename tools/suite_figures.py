#!/usr/bin/env python3
"""Report the GUT suite's figures from its JUnit XML, and check documents against them.

Rationale (2026-09-09): ``docs/testing-setup.md:69-70`` has stated a suite size
by hand since 2026-07-30. It has been stale at **eight consecutive build
reviews** and corrected seven times, which is a maintenance loop nobody chose.
The numbers are already computed: ``ci.yml`` runs GUT with
``-gjunit_xml_file=res://gut_results.xml`` and already parses that file to guard
against a silently-empty suite. Reading it twice is cheaper than typing it once.

Two modes, and the second is the one that closes the drift row:

* ``--print`` emits the canonical line — ``24 scripts / 246 tests / 3,154
  asserts`` — in the exact shape the reviews and logs already use, so it can be
  pasted rather than transcribed. Transcription is where the digits change.
* ``--check FILE`` finds that same pattern in a document and compares it to the
  measured figures, failing on a mismatch. Pointed at ``testing-setup.md`` from
  the ``tools`` job, a stale figure becomes a red check instead of a review row.

**Scripts are counted as ``<testsuite>`` elements, not as files on disk.** The
suite size that matters is what the runner collected; a test file that exists
and is never collected is precisely the failure ``ci.yml``'s zero-guard exists
to catch, and counting files would hide it here.

**Asserts are summed from each ``<testcase assertions=...>``.** GUT prints an
assert total to stdout but does not put one on the root element, and parsing
stdout would make this dependent on GUT's console formatting rather than on its
machine-readable output.

Usage:
    suite_figures.py --print
    suite_figures.py --print --xml game/gut_results.xml
    suite_figures.py --check docs/testing-setup.md
    suite_figures.py --json

Exit status is 0 on success or a matching document, 1 on a mismatch, 2 when the
XML is missing, malformed, or reports an empty suite.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass

DEFAULT_XML = pathlib.Path("game/gut_results.xml")

# The shape the reviews, daily logs and testing-setup.md already write. Commas
# are optional on the way in and always present on the way out, because that is
# how the existing prose reads.
FIGURE_PATTERN = re.compile(
    r"(\d[\d,]*)\s*scripts?\s*/\s*(\d[\d,]*)\s*tests?\s*/\s*(\d[\d,]*)\s*asserts?",
    re.IGNORECASE,
)


class SuiteFiguresError(Exception):
    """The XML could not be read, or describes a suite that did not run."""


@dataclass(frozen=True)
class Figures:
    scripts: int
    tests: int
    asserts: int
    failures: int = 0

    def line(self) -> str:
        return (
            f"{self.scripts:,} scripts / {self.tests:,} tests / "
            f"{self.asserts:,} asserts"
        )


def parse(xml_path: pathlib.Path) -> Figures:
    if not xml_path.is_file():
        raise SuiteFiguresError(
            f"{xml_path} does not exist. Run the suite first — see "
            "docs/testing-setup.md — or pass --xml."
        )
    try:
        root = ET.parse(xml_path).getroot()
    except ET.ParseError as exc:
        raise SuiteFiguresError(f"{xml_path} is not valid XML: {exc}") from exc

    suites = root.findall(".//testsuite")
    cases = root.findall(".//testcase")

    asserts = 0
    for case in cases:
        try:
            asserts += int(case.get("assertions", "0"))
        except ValueError:
            # A malformed attribute is worth failing on rather than treating as
            # zero: a silently low assert count is the same class of wrong
            # figure this script exists to prevent.
            raise SuiteFiguresError(
                f"{xml_path}: testcase {case.get('name')!r} has a "
                f"non-numeric assertions attribute {case.get('assertions')!r}"
            ) from None

    try:
        failures = int(root.get("failures", "0"))
    except ValueError:
        failures = 0

    if not suites or not cases:
        raise SuiteFiguresError(
            f"{xml_path} reports {len(suites)} scripts and {len(cases)} tests. "
            "GUT exits 0 when it collects nothing, so an empty result file is "
            "a broken discovery config, not a passing suite."
        )

    return Figures(len(suites), len(cases), asserts, failures)


def check_document(path: pathlib.Path, figures: Figures) -> int:
    if not path.is_file():
        raise SuiteFiguresError(f"{path} does not exist")

    text = path.read_text(encoding="utf-8")
    matches = list(FIGURE_PATTERN.finditer(text))
    if not matches:
        raise SuiteFiguresError(
            f"{path} states no suite figures in the "
            "'N scripts / N tests / N asserts' form, so there is nothing to "
            "check. Remove it from the check list or write the figures in that "
            "shape."
        )

    stale = []
    for match in matches:
        found = tuple(int(g.replace(",", "")) for g in match.groups())
        if found != (figures.scripts, figures.tests, figures.asserts):
            line_no = text.count("\n", 0, match.start()) + 1
            stale.append((line_no, match.group(0)))

    for line_no, found in stale:
        message = (
            f"{path}:{line_no} states {found!r}; the suite measures "
            f"{figures.line()!r}. Update the document, or regenerate it with "
            "suite_figures.py --print."
        )
        if os.environ.get("GITHUB_ACTIONS") == "true":
            print(f"::error file={path},line={line_no}::{message}")
        else:
            print(f"error: {message}", file=sys.stderr)

    if stale:
        return 1

    print(f"{path}: {len(matches)} figure reference(s) match {figures.line()}.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--xml", default=str(DEFAULT_XML), help="GUT JUnit XML path")
    parser.add_argument("--print", dest="do_print", action="store_true",
                        help="print the canonical figures line")
    parser.add_argument("--json", action="store_true", help="print the figures as JSON")
    parser.add_argument("--check", metavar="FILE", action="append", default=[],
                        help="check a document's stated figures (repeatable)")
    args = parser.parse_args(argv)

    try:
        figures = parse(pathlib.Path(args.xml))
    except SuiteFiguresError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(figures.__dict__, indent=2))
    if args.do_print or not (args.json or args.check):
        print(figures.line())

    status = 0
    for target in args.check:
        try:
            status |= check_document(pathlib.Path(target), figures)
        except SuiteFiguresError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
    return status


if __name__ == "__main__":
    raise SystemExit(main())
