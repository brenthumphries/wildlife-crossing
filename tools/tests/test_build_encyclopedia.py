#!/usr/bin/env python3
"""Tests for tools/build_encyclopedia.py, the wiki-to-website generator.

The generator used to only ever write: a wiki note deleted or renamed left its
generated page behind as an orphan on the public site. These tests exercise
the three things that matter now that it can also delete:

* a full run round-trips a small fixture wiki into HTML and is idempotent —
  running it twice with no wiki change produces byte-identical output, which
  is also what `deploy-website.yml`'s "Regenerate and diff" step relies on;
* removing a wiki note removes its generated page on the next run, and
  nothing else;
* the generated HTML never references an external host outside the allowlist
  in `deploy-website.yml`'s "Check for external asset requests" step. That
  step is a `grep` over `website/`, not code this generator runs, so it can't
  be exercised directly; this reimplements its pattern against fixture output
  to catch a regression before CI does, using notes that stick to the
  allowlist and one that doesn't.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import build_encyclopedia as be  # noqa: E402

# Mirrors the allowlist in .github/workflows/deploy-website.yml's "Check for
# external asset requests" step. Keep the two in sync by hand; there is no
# shared source because one lives in a forbidden-path workflow file.
ALLOWED_EXTERNAL_HOSTS = (
    r"github\.com|y2y\.net|wikipedia\.org|unesco\.org|pc\.gc\.ca|usgs\.gov|"
    r"nps\.gov|fws\.gov|fs\.usda\.gov|gov\.bc\.ca|si\.edu|wcs\.org|"
    r"wyofile\.com|arc-solutions\.org|highdivide\.org|wildsheepfoundation\.org"
)
EXTERNAL_REF = re.compile(r'(?:src|href)="(https?://[^"]+)"', re.IGNORECASE)
ALLOWED_HOST = re.compile(ALLOWED_EXTERNAL_HOSTS, re.IGNORECASE)


def disallowed_external_refs(html_dir: pathlib.Path) -> list[str]:
    """URLs in *.html under html_dir whose host isn't on the allowlist."""
    found: list[str] = []
    for path in sorted(html_dir.glob("*.html")):
        for match in EXTERNAL_REF.finditer(path.read_text(encoding="utf-8")):
            url = match.group(1)
            if not ALLOWED_HOST.search(url):
                found.append(url)
    return found


SPECIES_NOTE = """---
title: "Test Species"
date: 2026-01-01
tags: [wiki, species]
status: active
---

The test species (*Testus specius*) is a fixture used to exercise **bold**,
*italic*, `code`, a [Wikipedia link](https://en.wikipedia.org/wiki/Test), and
a [[test-region]] wikilink.

## In-game

- **Habitat:** forest · **Range:** small · **Status weight:** ×1

## Notes

Some prose that mentions [[test-region|the test region]] again.

## References

- [Wikipedia — Test](https://en.wikipedia.org/wiki/Test)

## Related

- [[test-region]]
"""

REGION_NOTE = """---
title: "Test Region"
date: 2026-01-01
tags: [wiki, sub-area]
status: active
---

Sub-area 1 is a fixture region used only by these tests.

## Overview

A short paragraph about the region.
"""

DISALLOWED_NOTE = """---
title: "Suspicious Species"
date: 2026-01-01
tags: [wiki, species]
status: active
---

A fixture note whose only job is to carry a link the allowlist rejects.

## References

- [Off-list tracker](https://tracker.example.com/pixel)
"""


class BuildEncyclopediaTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = pathlib.Path(self._tmp.name)
        self.wiki_dir = root / "wiki"
        self.out_dir = root / "encyclopedia"
        self.portrait_dir = root / "portraits"
        self.wiki_dir.mkdir()

        self._orig_wiki, self._orig_out, self._orig_portrait = (
            be.WIKI_DIR,
            be.OUT_DIR,
            be.PORTRAIT_DIR,
        )
        be.WIKI_DIR = self.wiki_dir
        be.OUT_DIR = self.out_dir
        be.PORTRAIT_DIR = self.portrait_dir

    def tearDown(self) -> None:
        be.WIKI_DIR, be.OUT_DIR, be.PORTRAIT_DIR = (
            self._orig_wiki,
            self._orig_out,
            self._orig_portrait,
        )
        self._tmp.cleanup()

    def write_note(self, name: str, text: str) -> None:
        (self.wiki_dir / name).write_text(text, encoding="utf-8")

    # -- round-trip generation ---------------------------------------------

    def test_round_trip_generation(self) -> None:
        self.write_note("test-species.md", SPECIES_NOTE)
        self.write_note("test-region.md", REGION_NOTE)

        self.assertEqual(be.main(), 0)

        species_html = (self.out_dir / "test-species.html").read_text(encoding="utf-8")
        region_html = (self.out_dir / "test-region.html").read_text(encoding="utf-8")
        index_html = (self.out_dir / "index.html").read_text(encoding="utf-8")

        self.assertIn("<strong>bold</strong>", species_html)
        self.assertIn("<em>italic</em>", species_html)
        self.assertIn("<code>code</code>", species_html)
        self.assertIn('<a href="test-region.html">the test region</a>', species_html)
        self.assertIn('<dt>Habitat</dt><dd>forest</dd>', species_html)
        self.assertIn('<a href="test-region.html">Test Region</a>', species_html)
        self.assertIn(
            '<a href="https://en.wikipedia.org/wiki/Test">Wikipedia — Test</a>',
            species_html,
        )
        self.assertIn("Test Species", index_html)
        self.assertIn("Test Region", index_html)
        self.assertNotIn("[[", species_html)
        self.assertNotIn("[[", region_html)

        before = {
            p.name: p.read_bytes() for p in sorted(self.out_dir.glob("*.html"))
        }
        self.assertEqual(be.main(), 0)
        after = {
            p.name: p.read_bytes() for p in sorted(self.out_dir.glob("*.html"))
        }
        self.assertEqual(before, after)

    # -- deletion of an orphan -----------------------------------------------

    def test_deletes_page_whose_wiki_source_is_gone(self) -> None:
        self.write_note("test-species.md", SPECIES_NOTE)
        self.write_note("test-region.md", REGION_NOTE)
        self.assertEqual(be.main(), 0)
        self.assertTrue((self.out_dir / "test-region.html").exists())
        self.assertTrue((self.out_dir / "test-species.html").exists())

        (self.wiki_dir / "test-region.md").unlink()
        self.assertEqual(be.main(), 0)

        self.assertFalse((self.out_dir / "test-region.html").exists())
        self.assertTrue((self.out_dir / "test-species.html").exists())
        self.assertTrue((self.out_dir / "index.html").exists())

        # The dangling related-link is dropped, not left pointing at a 404.
        species_html = (self.out_dir / "test-species.html").read_text(encoding="utf-8")
        self.assertNotIn("test-region.html", species_html)

        index_html = (self.out_dir / "index.html").read_text(encoding="utf-8")
        self.assertNotIn("Test Region", index_html)

    def test_deletion_leaves_unrelated_files_alone(self) -> None:
        self.write_note("test-species.md", SPECIES_NOTE)
        self.assertEqual(be.main(), 0)
        keepsake = self.out_dir / "not-a-generated-page.txt"
        keepsake.write_text("not html, not ours to delete", encoding="utf-8")

        self.assertEqual(be.main(), 0)

        self.assertTrue(keepsake.exists())

    def test_deletion_leaves_a_hand_written_page_alone(self) -> None:
        self.write_note("test-species.md", SPECIES_NOTE)
        self.assertEqual(be.main(), 0)
        hand_written = self.out_dir / "about.html"
        hand_written.write_text("<p>written by hand</p>", encoding="utf-8")

        self.assertEqual(be.main(), 0)

        self.assertTrue(hand_written.exists())

    def test_empty_wiki_is_an_error_and_deletes_nothing(self) -> None:
        self.write_note("test-species.md", SPECIES_NOTE)
        self.assertEqual(be.main(), 0)
        before = {p.name: p.read_bytes() for p in self.out_dir.glob("*.html")}
        (self.wiki_dir / "test-species.md").unlink()

        self.assertEqual(be.main(), 1)

        after = {p.name: p.read_bytes() for p in self.out_dir.glob("*.html")}
        self.assertEqual(before, after)

    # -- external-asset check -------------------------------------------------

    def test_no_disallowed_external_references_for_allowlisted_content(self) -> None:
        self.write_note("test-species.md", SPECIES_NOTE)
        self.write_note("test-region.md", REGION_NOTE)
        self.assertEqual(be.main(), 0)

        self.assertEqual(disallowed_external_refs(self.out_dir), [])

    def test_disallowed_external_reference_is_caught(self) -> None:
        self.write_note("suspicious-species.md", DISALLOWED_NOTE)
        self.assertEqual(be.main(), 0)

        found = disallowed_external_refs(self.out_dir)
        self.assertEqual(found, ["https://tracker.example.com/pixel"])


if __name__ == "__main__":
    unittest.main()
