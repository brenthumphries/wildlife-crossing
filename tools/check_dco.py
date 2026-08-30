#!/usr/bin/env python3
"""Fail a pull request whose commits are not signed off under the DCO.

Rationale (2026-08-10): ``CONTRIBUTING.md`` makes a ``Signed-off-by`` trailer
mandatory and nothing enforced it. Review-only enforcement works right up until
the review that forgets, and a missing trailer is far cheaper to fix before a
merge than after — afterwards it needs a history rewrite on a public branch, or
it just stays wrong. ADR 0017 makes this more than bookkeeping: with a DCO and
no CLA, the first merged outside contribution is the point of no return on the
licensing model, so the attestation is the only record that the contributor had
the right to submit the work.

**Scope: the commits a pull request adds, never the whole history.** 33 of the
40 commits on ``main`` as of 2026-08-10 predate ``CONTRIBUTING.md`` and carry no
trailer. A check that read history would paint ``main`` permanently red, and a
permanently red check is one everybody learns to scroll past. Those 33 are also
all by the copyright holder, so there is nothing to attest.

**What counts as signed off:** at least one ``Signed-off-by`` trailer whose
email matches the commit author's, compared case-insensitively.
``CONTRIBUTING.md`` already requires this — *"The name and email must be your
real ones and must match your git author"* — and without the comparison,
``Signed-off-by: Somebody Else <someone@example.com>`` passes, which makes the
attestation decorative. The DCO is a statement by the author about their own
right to submit; a trailer naming somebody else certifies nothing.

**Merge commits are skipped.** GitHub generates them, they have no author in
the DCO sense, and requiring a trailer on them would fail every PR that had
``main`` merged into it.

Trailers are found by scanning every line of the commit message rather than by
asking git for the trailer block. That is deliberate: git's trailer parser only
recognises a trailer block at the end of the message, so a sign-off followed by
a stray line goes unseen — and every other DCO checker in circulation scans
lines, so agreeing with them beats agreeing with git here.

Usage:
    check_dco.py <base> <head>    # e.g. check_dco.py origin/main HEAD
    check_dco.py --repo /path/to/repo origin/main HEAD

Exit status is 0 if every non-merge commit in ``base..head`` is signed off,
1 otherwise. In GitHub Actions, failures are emitted as ``::error::``
annotations so they surface on the commit itself.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass

# Record and field separators: a commit message can contain anything printable,
# including newlines and the pipes/semicolons a naive format would split on.
# The ASCII unit and record separators cannot appear in a git commit message.
FIELD_SEP = "\x1f"
RECORD_SEP = "\x1e"

# Deliberately permissive about spacing and case ("signed-off-by:", extra
# spaces) so that a near-miss is reported as an *email mismatch* rather than as
# a missing trailer. The two failures have different fixes and the message
# should not send someone down the wrong one.
SIGNOFF_RE = re.compile(
    r"^\s*signed-off-by\s*:\s*(?P<name>.*?)\s*<(?P<email>[^>]*)>\s*$",
    re.IGNORECASE,
)

REMEDY = (
    "Fix the most recent commit with:\n"
    "    git commit --amend -s --no-edit\n"
    "or a whole branch with:\n"
    "    git rebase --signoff main\n"
    "then force-push. See CONTRIBUTING.md, Developer Certificate of Origin."
)


class DcoError(Exception):
    """A problem running the check itself, as opposed to a failing commit."""


@dataclass(frozen=True)
class Commit:
    sha: str
    author_name: str
    author_email: str
    subject: str
    signoffs: tuple[tuple[str, str], ...]  # (name, email) pairs, in order

    @property
    def short(self) -> str:
        return self.sha[:8]

    def is_signed_off(self) -> bool:
        """True if any trailer's email matches the author's, case-insensitively.

        Email only. Display names drift legitimately — people marry, change how
        they spell their own name, or configure ``user.name`` differently on two
        machines — and rejecting a contribution over that would be officious.
        The email is the identifier git itself keys on.
        """
        author = self.author_email.strip().lower()
        return any(email.strip().lower() == author for _, email in self.signoffs)


def parse_signoffs(message: str) -> tuple[tuple[str, str], ...]:
    """Extract every ``Signed-off-by`` line from a commit message."""
    found = []
    for line in message.splitlines():
        match = SIGNOFF_RE.match(line)
        if match:
            found.append((match.group("name").strip(), match.group("email").strip()))
    return tuple(found)


def commits_in_range(base: str, head: str, repo: pathlib.Path) -> list[Commit]:
    """Return the non-merge commits reachable from ``head`` but not ``base``."""
    fmt = FIELD_SEP.join(["%H", "%an", "%ae", "%s", "%B"]) + RECORD_SEP
    proc = subprocess.run(
        ["git", "-C", str(repo), "log", "--no-merges", f"--format={fmt}",
         f"{base}..{head}"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise DcoError(
            f"could not list commits in {base}..{head}: {detail}\n"
            "On a pull request this usually means the base ref was not fetched "
            "— the checkout step needs fetch-depth: 0."
        )

    commits: list[Commit] = []
    for record in proc.stdout.split(RECORD_SEP):
        if not record.strip():
            continue
        parts = record.lstrip("\n").split(FIELD_SEP)
        if len(parts) < 5:
            raise DcoError(f"unparseable git log record: {record!r}")
        sha, author_name, author_email, subject, message = parts[:5]
        commits.append(
            Commit(
                sha=sha.strip(),
                author_name=author_name,
                author_email=author_email,
                subject=subject,
                signoffs=parse_signoffs(message),
            )
        )
    return commits


def problems(commits: list[Commit]) -> list[tuple[Commit, str]]:
    """Pair each failing commit with an explanation aimed at its author."""
    failures: list[tuple[Commit, str]] = []
    for commit in commits:
        if commit.is_signed_off():
            continue
        if not commit.signoffs:
            reason = "no Signed-off-by trailer"
        else:
            listed = ", ".join(f"<{email}>" for _, email in commit.signoffs)
            reason = (
                f"signed off by {listed}, but authored by "
                f"<{commit.author_email}>. The DCO is a statement about your "
                "own right to submit the work, so the trailer has to match the "
                "author"
            )
        failures.append((commit, reason))
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify DCO sign-off on the commits a pull request adds.",
    )
    parser.add_argument("base", help="base ref, e.g. origin/main")
    parser.add_argument("head", help="head ref, e.g. HEAD")
    parser.add_argument(
        "--repo",
        default=".",
        help="repository to inspect (default: current directory)",
    )
    args = parser.parse_args(argv)

    in_actions = bool(os.environ.get("GITHUB_ACTIONS"))

    try:
        commits = commits_in_range(args.base, args.head, pathlib.Path(args.repo))
    except DcoError as exc:
        print(f"{'::error::' if in_actions else 'error: '}{exc}", file=sys.stderr)
        return 2

    if not commits:
        # Not a pass to celebrate — a PR with no non-merge commits is unusual
        # enough to say out loud rather than to report as a silent green.
        print(f"No non-merge commits in {args.base}..{args.head}; nothing to check.")
        return 0

    failures = problems(commits)
    if not failures:
        print(f"DCO: {len(commits)} commit(s) signed off correctly.")
        return 0

    for commit, reason in failures:
        message = f"{commit.short} ({commit.subject}): {reason}."
        if in_actions:
            print(f"::error::DCO check failed — {message}")
        print(f"  {message}", file=sys.stderr)

    print(
        f"\n{len(failures)} of {len(commits)} commit(s) are not signed off.\n\n"
        f"{REMEDY}",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
