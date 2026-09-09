#!/usr/bin/env python3
"""Flag line-number citations in vault notes, which go stale the next time anyone edits.

Rationale (2026-09-09): stale line numbers have been the largest single category
of error in three consecutive build reviews. The 2026-09-01 note prescribed the
fix in its own §4 — *cite headings, job names and step names* — and then cited
lines anyway. The 09-08 note's §4 row **about** stale line numbers carried two
wrong numbers of its own, derived by arithmetic rather than by opening the file:
``:452`` for a line that only existed after an unlanded change, and a shift of
+57 where the diff was +60.

A rule stated in prose and never checked is a rule that survives being violated
in the sentence that states it. This is the check.

**Advisory by default, and that is deliberate.** It exits 0 unless asked for
``--strict``. A line citation is sometimes the right call — quoting a specific
hunk of a diff, say — and a fatal check on a judgment call is a check people
learn to route around, which costs more than the drift does. Pointed at a note
before it lands, the report is the reminder; ``--strict`` exists for anyone who
later decides the rule should bite.

**Existing notes are history and are not retrofitted.** Pass the paths you want
checked. Nothing here walks the vault by default, because a report listing every
citation in ten committed reviews is noise that hides the one note being written
now.

What counts as a citation: ``ci.yml:294``, ``roadmap.md:148``, ``:392`` when
backtick-anchored, ranges such as ``:69-70``, and the markdown-link form the
reviews use most, ``[runbook.md](../docs/runbook.md):392``. Clock times, port numbers and
URL fragments are excluded — the left-hand side has to look like a filename, or
the reference has to be anchored to a backtick with nothing before the colon.

Usage:
    check_citations.py obsidian-vault/build-reviews/2026-09-15-next-build.md
    check_citations.py --strict path/to/note.md
    check_citations.py $(git diff --name-only --diff-filter=AM main -- '*.md')

Exit status is 0 unless ``--strict`` is given and citations were found; 2 if a
named file does not exist.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

# A filename-looking token followed by :NNN or :NNN-NNN. The extension bound of
# 1-5 letters keeps 'v0.1.0:3' and '12.30:45' out while admitting .md, .gd,
# .yml, .json, .tscn and .cfg.
FILE_CITATION = re.compile(
    r"(?P<file>[\w./-]+\.[A-Za-z]{1,5})"
    r":(?P<line>\d+(?:\s*-\s*\d+)?)\b"
)

# A bare ':392' or ':69-70' immediately inside backticks, which is how the notes
# refer to a file named earlier in the same sentence.
BARE_CITATION = re.compile(r"`:(?P<line>\d+(?:\s*-\s*\d+)?)`")

# The form the build reviews use most: a markdown link followed by a line
# number, as in [signing-runbook.md](../../docs/signing-runbook.md):392. The
# filename-token pattern above cannot see these, because the character before
# the colon is the link's closing parenthesis.
MD_LINK_CITATION = re.compile(
    r"\]\((?P<target>[^)\s]+)\):(?P<line>\d+(?:\s*-\s*\d+)?)\b"
)

# Anything matching FILE_CITATION inside these is a URL or a duration, not a
# citation into the repository.
SKIP_PREFIXES = ("http://", "https://", "mailto:")


def citations(text: str) -> list[tuple[int, str]]:
    """Return (line number, matched text) for every citation in ``text``."""
    found: list[tuple[int, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for match in FILE_CITATION.finditer(line):
            if _in_url(line, match.start()):
                continue
            found.append((lineno, match.group(0)))
        for match in MD_LINK_CITATION.finditer(line):
            if _in_url(line, match.start()):
                continue
            target = match.group("target").rsplit("/", 1)[-1]
            found.append((lineno, f"{target}:{match.group('line')}"))
        for match in BARE_CITATION.finditer(line):
            found.append((lineno, match.group(0)))
    return found


def _in_url(line: str, index: int) -> bool:
    """True when the match at ``index`` sits inside a URL on this line."""
    for prefix in SKIP_PREFIXES:
        pos = line.find(prefix)
        while pos != -1:
            end = pos
            while end < len(line) and not line[end].isspace() and line[end] not in ")>":
                end += 1
            if pos <= index < end:
                return True
            pos = line.find(prefix, pos + 1)
    return False


def report(path: pathlib.Path, strict: bool) -> tuple[int, int]:
    """Print any citations in ``path``. Returns (count, exit contribution)."""
    text = path.read_text(encoding="utf-8")
    found = citations(text)
    if not found:
        print(f"{path}: no line-number citations.")
        return 0, 0

    print(f"{path}: {len(found)} line-number citation(s).")
    for lineno, snippet in found:
        print(f"  {path}:{lineno}  {snippet}")
    return len(found), (1 if strict else 0)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="+", help="notes to check")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit 1 when any citation is found (default: report only)",
    )
    args = parser.parse_args(argv)

    total = 0
    status = 0
    for name in args.paths:
        path = pathlib.Path(name)
        if not path.is_file():
            print(f"error: {path} does not exist", file=sys.stderr)
            return 2
        count, contribution = report(path, args.strict)
        total += count
        status |= contribution

    if total:
        print(
            f"\n{total} citation(s) across {len(args.paths)} file(s). "
            "Prefer a heading, a job name or a step name: those survive an "
            "edit above them, and a line number does not."
        )
    return status


if __name__ == "__main__":
    raise SystemExit(main())
