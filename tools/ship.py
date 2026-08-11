#!/usr/bin/env python3
"""Stage and commit a working tree according to a reviewed commit plan.

Rationale (2026-08-09): ``docs/push-runbook.md`` splits cleanly into two kinds
of step. Clearing the recurring ``.git/index.lock``, staging each group,
committing with a DCO sign-off, and checking the result afterwards are all
mechanical — and doing them by hand every session is how a ``.uid`` file gets
left behind in an untracked state that only surfaces when CI cannot import the
project.

Grouping the changed paths into themed commits is *not* mechanical. On
2026-08-09 ``tools/smoke_boot.sh`` belonged with the game commit rather than
the CI commit, because it asserts against the boot scene that the same commit
moves; the runbook's own generic advice ("``tools/*.sh`` with infra") would
have produced an intermediate commit whose smoke gate fails. No parser reading
the daily log gets that right, because the log records what happened, not which
commit each file belongs in.

So this script executes a plan. It never infers one. The plan is a small JSON
file, written and reviewed before it runs, and the script's real job is to
refuse:

* refuse a plan that does not account for every path git reports as changed
* refuse to stage anything the plan did not name (verified after staging, not
  merely intended before it)
* refuse to commit unsigned, when ``CONTRIBUTING.md`` requires a sign-off
* refuse to start when something is already staged, which would otherwise be
  swept into the first commit
* refuse to touch the working tree at all unless asked twice (``--execute``)

It deliberately stops before ``git push``. Everything it does is one
``git reset`` away from undone, and it prints that exact reset command if it
fails partway through. The push is yours, from a real terminal — the Cowork
sandbox has no credentials for ``origin`` (see docs/push-runbook.md).

Usage:
    ship.py plan.json                 # dry run: validate and print, change nothing
    ship.py plan.json --execute       # clear stale lock, stage, commit
    ship.py --verify                  # after you push: confirm it landed

Plan format:
    {
      "branch": "main",
      "commits": [
        {
          "type": "docs",
          "scope": "licensing",
          "subject": "dual-license the repo MIT + CC0 1.0",
          "body": "What changed and why, 2-4 sentences.",
          "paths": ["LICENSE", "LICENSE-ASSETS", "docs/adr/0017-licensing.md"]
        }
      ]
    }

``scope`` and ``body`` are optional; ``type``, ``subject`` and ``paths`` are
not. A ``paths`` entry is either an exact path or a directory prefix such as
``game/scripts/ui/``. Every changed path must be claimed by exactly one commit,
and every plan entry must match at least one changed path.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import time
from dataclasses import dataclass, field

# Conventional Commit types, from the root CLAUDE.md "Git workflow" section.
# Kept deliberately narrow: the tool enforcing the project's own convention is
# a feature, and a type outside this set is more likely a typo than a decision.
ALLOWED_TYPES = ("feat", "fix", "docs", "chore", "test")

# Advisory only. Warned about, never fatal — a long subject is a style problem,
# not a correctness one, and failing on it would tempt a --no-verify habit.
MAX_SUBJECT_LEN = 72

# A lock younger than this may belong to a git process that is still running,
# and deleting it under a live process corrupts the index. The runbook's
# `rm -f .git/index.lock` is unconditional; this is the same fix with a guard.
STALE_LOCK_SECONDS = 120

# Written into .git/ (untracked by construction, so no .gitignore entry needed)
# so that --verify can check exactly the commits this run created rather than
# guessing at a count.
STATE_FILENAME = "ship-last-run.json"


class ShipError(Exception):
    """A refusal. The repo or the plan is not in a state it is safe to act on."""


# --------------------------------------------------------------------------
# git plumbing
# --------------------------------------------------------------------------


def run_git(root: pathlib.Path, *args: str, stdin: str | None = None,
            check: bool = True) -> str:
    """Run a git command in ``root`` and return its stdout."""
    proc = subprocess.run(
        ["git", "-C", str(root), *args],
        input=stdin,
        capture_output=True,
        text=True,
    )
    if check and proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise ShipError(f"git {' '.join(args)} failed ({proc.returncode}): {detail}")
    return proc.stdout


def repo_root(start: pathlib.Path | None = None) -> pathlib.Path:
    """Return the top level of the git repo containing ``start``."""
    where = start or pathlib.Path.cwd()
    proc = subprocess.run(
        ["git", "-C", str(where), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise ShipError(f"{where} is not inside a git repository")
    return pathlib.Path(proc.stdout.strip())


@dataclass(frozen=True)
class Change:
    """One entry from ``git status --porcelain``."""

    index_status: str
    worktree_status: str
    path: str
    original: str | None = None  # populated for renames and copies

    @property
    def is_staged(self) -> bool:
        return self.index_status not in (" ", "?")

    @property
    def all_paths(self) -> tuple[str, ...]:
        """Every path this entry touches — a rename touches two."""
        if self.original:
            return (self.path, self.original)
        return (self.path,)


def changed_entries(root: pathlib.Path) -> list[Change]:
    """Parse ``git status`` into Change records.

    ``-uall`` matters: without it git collapses a wholly-untracked directory
    into a single ``dir/`` entry, and the coverage check below would then pass
    while individual new files inside it went unexamined.

    ``-z`` matters: paths with spaces are routine here (macOS ``.app`` bundles,
    Obsidian note titles) and the non-NUL format quotes them inconsistently.
    """
    raw = run_git(root, "status", "--porcelain=v1", "-uall", "-z")
    fields = raw.split("\0")
    entries: list[Change] = []
    i = 0
    while i < len(fields):
        field_value = fields[i]
        if not field_value:
            i += 1
            continue
        index_status, worktree_status = field_value[0], field_value[1]
        path = field_value[3:]
        original = None
        if index_status in ("R", "C"):
            # Rename and copy entries are followed by a second NUL-separated
            # field holding the original path.
            i += 1
            original = fields[i] if i < len(fields) else None
        entries.append(Change(index_status, worktree_status, path, original))
        i += 1
    return entries


def staged_paths(root: pathlib.Path) -> set[str]:
    """Paths currently staged relative to HEAD."""
    raw = run_git(root, "diff", "--cached", "--name-only", "-z")
    return {p for p in raw.split("\0") if p}


def current_branch(root: pathlib.Path) -> str:
    return run_git(root, "rev-parse", "--abbrev-ref", "HEAD").strip()


def head_sha(root: pathlib.Path) -> str:
    return run_git(root, "rev-parse", "HEAD").strip()


def committer_identity(root: pathlib.Path) -> tuple[str, str]:
    """Return (name, email), raising if either is unset.

    Checked before the first commit rather than after the third: an unsigned
    or misattributed commit is far cheaper to prevent than to rewrite, and
    CONTRIBUTING.md makes the sign-off mandatory.
    """
    name = run_git(root, "config", "--get", "user.name", check=False).strip()
    email = run_git(root, "config", "--get", "user.email", check=False).strip()
    missing = [k for k, v in (("user.name", name), ("user.email", email)) if not v]
    if missing:
        raise ShipError(
            "git identity incomplete: "
            + ", ".join(missing)
            + " unset. CONTRIBUTING.md requires a Signed-off-by trailer, and "
            "the trailer is built from these. Set them with `git config --global "
            "user.name \"...\"` before shipping."
        )
    return name, email


# --------------------------------------------------------------------------
# plan
# --------------------------------------------------------------------------


@dataclass
class PlannedCommit:
    type: str
    subject: str
    paths: list[str]
    scope: str | None = None
    body: str | None = None
    matched: set[str] = field(default_factory=set)

    @property
    def header(self) -> str:
        prefix = f"{self.type}({self.scope})" if self.scope else self.type
        return f"{prefix}: {self.subject}"

    def message(self) -> str:
        if self.body:
            return f"{self.header}\n\n{self.body.strip()}\n"
        return f"{self.header}\n"


@dataclass
class Plan:
    branch: str
    commits: list[PlannedCommit]


def load_plan(path: pathlib.Path) -> Plan:
    """Read and structurally validate a plan file."""
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise ShipError(f"plan file not found: {path}")
    except json.JSONDecodeError as exc:
        raise ShipError(f"plan file is not valid JSON: {exc}")

    if not isinstance(raw, dict):
        raise ShipError("plan must be a JSON object")

    branch = raw.get("branch", "main")
    if not isinstance(branch, str) or not branch:
        raise ShipError("plan 'branch' must be a non-empty string")

    commits_raw = raw.get("commits")
    if not isinstance(commits_raw, list) or not commits_raw:
        raise ShipError("plan must contain a non-empty 'commits' list")

    commits: list[PlannedCommit] = []
    for position, item in enumerate(commits_raw, start=1):
        if not isinstance(item, dict):
            raise ShipError(f"commit #{position} is not an object")

        commit_type = item.get("type")
        if commit_type not in ALLOWED_TYPES:
            raise ShipError(
                f"commit #{position} has type {commit_type!r}; allowed types are "
                + ", ".join(ALLOWED_TYPES)
                + " (root CLAUDE.md, Git workflow)"
            )

        subject = item.get("subject")
        if not isinstance(subject, str) or not subject.strip():
            raise ShipError(f"commit #{position} needs a non-empty 'subject'")

        paths = item.get("paths")
        if not isinstance(paths, list) or not paths:
            raise ShipError(f"commit #{position} needs a non-empty 'paths' list")
        if not all(isinstance(p, str) and p.strip() for p in paths):
            raise ShipError(f"commit #{position} has a non-string or empty path")

        scope = item.get("scope")
        if scope is not None and (not isinstance(scope, str) or not scope.strip()):
            raise ShipError(f"commit #{position} has an empty 'scope'")

        body = item.get("body")
        if body is not None and not isinstance(body, str):
            raise ShipError(f"commit #{position} has a non-string 'body'")

        commits.append(
            PlannedCommit(
                type=commit_type,
                subject=subject.strip(),
                paths=[p.strip() for p in paths],
                scope=scope.strip() if isinstance(scope, str) else None,
                body=body,
            )
        )

    return Plan(branch=branch, commits=commits)


def style_warnings(plan: Plan) -> list[str]:
    """Non-fatal notes about commit message style."""
    notes: list[str] = []
    for position, commit in enumerate(plan.commits, start=1):
        if len(commit.header) > MAX_SUBJECT_LEN:
            notes.append(
                f"commit #{position} header is {len(commit.header)} chars "
                f"(over {MAX_SUBJECT_LEN}): {commit.header}"
            )
        if commit.subject.endswith("."):
            notes.append(f"commit #{position} subject ends with a period")
        if commit.subject[:1].isupper():
            notes.append(f"commit #{position} subject starts with a capital")
        if not commit.body or not commit.body.strip():
            notes.append(
                f"commit #{position} has no body; the runbook asks for what "
                "changed and why, plus the suite count if tests ran"
            )
    return notes


def match_paths(plan: Plan, entries: list[Change]) -> None:
    """Assign every changed path to exactly one planned commit.

    This is the check that earns the tool its keep. Three failure modes, all
    of which have bitten this project or are one distracted session away from
    doing so: a new file left unclaimed (the ``.uid`` case), a path claimed by
    two commits, and a plan entry describing something that did not actually
    change (usually a typo, occasionally a file already committed).
    """
    changed: set[str] = set()
    for entry in entries:
        changed.update(entry.all_paths)

    owner: dict[str, int] = {}
    for position, commit in enumerate(plan.commits, start=1):
        for pattern in commit.paths:
            prefix = pattern.rstrip("/") + "/"
            hits = {c for c in changed if c == pattern or c.startswith(prefix)}
            if not hits:
                raise ShipError(
                    f"commit #{position} lists {pattern!r}, but git reports no "
                    "change there. Stale plan, or a typo."
                )
            for hit in hits:
                if hit in owner and owner[hit] != position:
                    raise ShipError(
                        f"{hit!r} is claimed by both commit #{owner[hit]} and "
                        f"commit #{position}. Each path belongs to exactly one."
                    )
                owner[hit] = position
            commit.matched.update(hits)

    unclaimed = sorted(changed - set(owner))
    if unclaimed:
        listing = "\n".join(f"  {p}" for p in unclaimed)
        raise ShipError(
            "the plan does not account for every change. Unclaimed:\n"
            + listing
            + "\n\nAdd them to a commit, or stash them, but do not leave them "
            "behind — an unstaged .uid file is how the import breaks in CI."
        )


# --------------------------------------------------------------------------
# preflight
# --------------------------------------------------------------------------


def check_lock(root: pathlib.Path, execute: bool, force: bool) -> list[str]:
    """Clear a stale ``.git/index.lock``, or explain why it was left alone.

    ``harness/weekly-build-review`` leaves this behind most sessions (see the
    2026-07-19, 07-28 and 07-30 logs), which is why the runbook opens with an
    unconditional ``rm -f``. Unconditional is not quite right: deleting a lock
    that a live git process still holds corrupts the index. Age is a crude
    proxy for liveness, but a much better one than nothing.
    """
    lock = root / ".git" / "index.lock"
    if not lock.exists():
        return []

    age = time.time() - lock.stat().st_mtime
    if age < STALE_LOCK_SECONDS and not force:
        raise ShipError(
            f".git/index.lock exists and is only {age:.0f}s old, so a git "
            "process may still be holding it. Wait, close any open editor git "
            "integration, then re-run — or pass --force-lock if you are sure "
            "nothing is running."
        )

    if not execute:
        return [f"would remove stale .git/index.lock ({age:.0f}s old)"]

    try:
        lock.unlink()
    except OSError as exc:
        # Seen from the Cowork sandbox, where the repo is a mount and .git is
        # not writable by the sandbox user. It is also what a genuinely
        # permission-broken .git looks like, and both want the same answer.
        raise ShipError(
            f"could not remove .git/index.lock: {exc}. If you are in the Cowork "
            "sandbox, that is expected — ship.py --execute has to run in a real "
            "terminal on the machine that owns the repo."
        )
    return [f"removed stale .git/index.lock ({age:.0f}s old)"]


def preflight(root: pathlib.Path, plan: Plan, allow_branch_mismatch: bool) -> None:
    """Refuse anything about the repo that makes committing unsafe."""
    if not run_git(root, "rev-parse", "--verify", "HEAD", check=False).strip():
        raise ShipError(
            "this repo has no commits yet; ship.py assumes an existing HEAD to "
            "diff against"
        )

    branch = current_branch(root)
    if branch != plan.branch and not allow_branch_mismatch:
        raise ShipError(
            f"on branch {branch!r} but the plan targets {plan.branch!r}. "
            "Switch branches, fix the plan, or pass --allow-branch-mismatch."
        )

    already = staged_paths(root)
    if already:
        listing = "\n".join(f"  {p}" for p in sorted(already))
        raise ShipError(
            "something is already staged, and it would be swept into the first "
            "commit:\n"
            + listing
            + "\n\nRun `git reset` to unstage, then re-run."
        )

    unmerged = [
        e for e in changed_entries(root)
        if "U" in (e.index_status, e.worktree_status)
    ]
    if unmerged:
        listing = "\n".join(f"  {e.path}" for e in unmerged)
        raise ShipError("unmerged paths present; resolve the conflict first:\n" + listing)

    committer_identity(root)


# --------------------------------------------------------------------------
# execution
# --------------------------------------------------------------------------


def commit_group(root: pathlib.Path, commit: PlannedCommit, position: int) -> str:
    """Stage exactly ``commit.matched`` and commit it signed off.

    The staged set is verified *after* staging rather than trusted beforehand.
    A pathspec that expands differently than expected — a directory prefix that
    picks up a sibling, a rename that drags its original along — is precisely
    the kind of surprise worth catching before it is written into history.
    """
    expected = set(commit.matched)
    run_git(root, "add", "--", *sorted(expected))

    actual = staged_paths(root)
    if actual != expected:
        extra = sorted(actual - expected)
        missing = sorted(expected - actual)
        run_git(root, "reset", check=False)
        detail = []
        if extra:
            detail.append("unexpectedly staged:\n" + "\n".join(f"  {p}" for p in extra))
        if missing:
            detail.append("failed to stage:\n" + "\n".join(f"  {p}" for p in missing))
        raise ShipError(
            f"commit #{position} staged a different set than planned. "
            + "\n".join(detail)
            + "\n\nThe index has been reset; nothing was committed."
        )

    run_git(root, "commit", "-s", "-F", "-", stdin=commit.message())

    sha = head_sha(root)
    message = run_git(root, "log", "-1", "--format=%B", sha)
    if "Signed-off-by:" not in message:
        raise ShipError(
            f"commit {sha[:7]} landed without a Signed-off-by trailer, which "
            "CONTRIBUTING.md requires. Undo with `git reset --soft HEAD~1`, fix "
            "your git identity, and re-run."
        )
    return sha


def write_state(root: pathlib.Path, start: str, commits: list[str], branch: str) -> None:
    payload = {
        "branch": branch,
        "start": start,
        "end": commits[-1] if commits else start,
        "commits": commits,
        "written": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    (root / ".git" / STATE_FILENAME).write_text(
        json.dumps(payload, indent=2) + "\n", encoding="utf-8"
    )


def execute(root: pathlib.Path, plan: Plan) -> list[str]:
    """Run the plan, unwinding cleanly if a group fails partway."""
    start = head_sha(root)
    made: list[str] = []
    try:
        for position, commit in enumerate(plan.commits, start=1):
            sha = commit_group(root, commit, position)
            made.append(sha)
            print(f"  [{position}/{len(plan.commits)}] {sha[:7]} {commit.header}")
    except ShipError:
        if made:
            print(
                f"\n{len(made)} commit(s) were made before this failed. "
                f"Undo them with:\n    git reset --soft {start}",
                file=sys.stderr,
            )
        raise

    write_state(root, start, made, plan.branch)
    return made


# --------------------------------------------------------------------------
# verify
# --------------------------------------------------------------------------


def verify(root: pathlib.Path, fetch: bool) -> int:
    """Confirm a push actually landed. Read-only.

    Checks the three things worth checking after the fact: the tree is clean,
    the remote-tracking ref matches what was built, and every commit this tool
    created carries its sign-off.
    """
    state_path = root / ".git" / STATE_FILENAME
    if not state_path.exists():
        raise ShipError(
            "no record of a previous ship.py run in this repo. --verify checks "
            "the commits ship.py created; there are none to check."
        )
    state = json.loads(state_path.read_text(encoding="utf-8"))
    branch = state["branch"]
    expected_head = state["end"]

    if fetch:
        run_git(root, "fetch", "origin", branch)

    failures: list[str] = []

    leftover = changed_entries(root)
    if leftover:
        listing = "\n".join(f"  {e.index_status}{e.worktree_status} {e.path}" for e in leftover)
        failures.append("working tree is not clean:\n" + listing)
    else:
        print("  clean working tree")

    head = head_sha(root)
    if head != expected_head:
        failures.append(
            f"HEAD is {head[:7]}, but the last ship.py run ended at "
            f"{expected_head[:7]}. Something has been committed since."
        )
    else:
        print(f"  HEAD at {head[:7]}, as built")

    remote_ref = f"origin/{branch}"
    remote = run_git(root, "rev-parse", "--verify", remote_ref, check=False).strip()
    if not remote:
        failures.append(f"{remote_ref} does not exist locally; has it ever been pushed?")
    elif remote != expected_head:
        failures.append(
            f"{remote_ref} is at {remote[:7]}, not {expected_head[:7]}. The push "
            "did not land, or landed somewhere else. Note this compares the "
            "local remote-tracking ref; pass --fetch to refresh it first."
        )
    else:
        print(f"  {remote_ref} matches HEAD")

    for sha in state["commits"]:
        message = run_git(root, "log", "-1", "--format=%B", sha, check=False)
        if "Signed-off-by:" not in message:
            failures.append(f"{sha[:7]} has no Signed-off-by trailer")
    if not failures:
        print(f"  {len(state['commits'])} commit(s) signed off")

    if failures:
        print("\nverification failed:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    print("\nAll checks passed. Runbook Steps 3-5 are still open: watch CI, run")
    print("check_pck_contents.py against the artifact, then a windowed launch.")
    return 0


# --------------------------------------------------------------------------
# reporting
# --------------------------------------------------------------------------


def describe(plan: Plan, notes: list[str], execute_mode: bool) -> None:
    heading = "Executing plan" if execute_mode else "Dry run — nothing will change"
    print(f"{heading}: {len(plan.commits)} commit(s) on {plan.branch}\n")
    for position, commit in enumerate(plan.commits, start=1):
        print(f"[{position}] {commit.header}")
        if commit.body:
            for line in commit.body.strip().splitlines():
                print(f"    | {line}")
        for path in sorted(commit.matched):
            print(f"    + {path}")
        print()
    if notes:
        print("Style notes (not fatal):")
        for note in notes:
            print(f"  - {note}")
        print()


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="ship.py stops before `git push`. See docs/push-runbook.md.",
    )
    parser.add_argument(
        "plan",
        nargs="?",
        type=pathlib.Path,
        help="path to the commit plan JSON (omit when using --verify)",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="actually stage and commit; without this the run is a dry run",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="check that the last ship.py run's commits were pushed",
    )
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="with --verify, refresh the remote-tracking ref first",
    )
    parser.add_argument(
        "--force-lock",
        action="store_true",
        help="remove .git/index.lock even if it is recent (no git running)",
    )
    parser.add_argument(
        "--allow-branch-mismatch",
        action="store_true",
        help="proceed even if the current branch is not the plan's branch",
    )
    parser.add_argument(
        "--repo",
        type=pathlib.Path,
        default=None,
        help="repo to operate on (default: the one containing the cwd)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        root = repo_root(args.repo)

        if args.verify:
            return verify(root, fetch=args.fetch)

        if args.plan is None:
            raise ShipError("a plan file is required (or use --verify)")

        plan = load_plan(args.plan)
        for message in check_lock(root, args.execute, args.force_lock):
            print(message)

        preflight(root, plan, args.allow_branch_mismatch)
        match_paths(plan, changed_entries(root))
        describe(plan, style_warnings(plan), args.execute)

        if not args.execute:
            print("Re-run with --execute to stage and commit.")
            return 0

        made = execute(root, plan)
        print(f"\n{len(made)} commit(s) made. Working tree:")
        remaining = changed_entries(root)
        print("  clean" if not remaining else
              "\n".join(f"  {e.index_status}{e.worktree_status} {e.path}" for e in remaining))
        print(f"\nNothing has been pushed. When ready:\n    git push origin {plan.branch}")
        print("Then confirm it landed:\n    tools/ship.py --verify")
        return 0

    except ShipError as exc:
        print(f"ship.py: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
