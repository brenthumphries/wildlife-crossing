#!/usr/bin/env python3
"""Record the GitHub-side facts no unattended session can read, into a tracked file.

Rationale (2026-09-09): a cloud session can clone this repository over HTTPS
with no credentials — verified — but ``api.github.com`` answers it **403**:
*"GitHub access to this repository is not enabled for this session."* That is an
egress policy denial, not an authentication failure, so a token would not change
it. Meanwhile ``gh`` is installed and authorised on Brent's Mac and answers all
of it.

So the split is by capability rather than by credential. Everything derivable
from git stays in git and is read by whoever needs it. Everything else is read
**here**, once, during a normal session, and committed as
``docs/github-state.json`` with the moment it was read. Downstream — the daily
queue, the weekly review — then reads a file out of a clone and reports
*"green, as of 2026-09-09 14:02"* instead of *"cannot see"*.

**The drift check is the reason this is a script and not a habit.**
``.github/rulesets/protect_main.json`` is a checked-in *copy* of ruleset
``22403399``, which can be edited in the web interface — as it was on
2026-09-08, when auto-merge was enabled. ``check_required_contexts.py`` proves
``ci.yml`` agrees with that copy; only this script can prove the copy agrees
with the gate. Together they close the loop.

**No secrets are written.** Everything recorded here is readable by anyone who
can see the repository, which is anyone at all: it is public. The file records
*settings and statuses*, never tokens.

If ``gh`` is missing or unauthorised, the script prints the exact commands to
run instead, one per line, ready to paste, and exits without writing.

Usage:
    tools/github_state.py                 # read and write docs/github-state.json
    tools/github_state.py --dry-run       # print the reads, change nothing
    tools/github_state.py --show-commands # print paste-ready gh lines and stop
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import pathlib
import shlex
import shutil
import subprocess
import sys

REPO = "brenthumphries/wildlife-crossing"
RULESET_ID = "22403399"
OUT_PATH = pathlib.Path("docs/github-state.json")
COMMITTED_RULESET = pathlib.Path(".github/rulesets/protect_main.json")

# Each read is (key, human description, gh argv). Kept as data so --show-commands
# and the real run cannot drift apart: they iterate the same list.
READS: list[tuple[str, str, list[str]]] = [
    ("ruleset", "the applied ruleset, to diff against the committed copy",
     ["api", f"repos/{REPO}/rulesets/{RULESET_ID}"]),
    ("repository", "visibility, auto-merge, and the security_and_analysis block",
     ["api", f"repos/{REPO}",
      "--jq", "{visibility, allow_auto_merge, allow_squash_merge, "
              "allow_rebase_merge, delete_branch_on_merge, "
              "security_and_analysis}"]),
    ("latest_main_run", "the newest CI run on main and its conclusion",
     ["api", f"repos/{REPO}/actions/runs?branch=main&per_page=1",
      "--jq", "{id: .workflow_runs[0].id, name: .workflow_runs[0].name, "
              "status: .workflow_runs[0].status, "
              "conclusion: .workflow_runs[0].conclusion, "
              "created_at: .workflow_runs[0].created_at, "
              "head_sha: .workflow_runs[0].head_sha}"]),
    ("artifacts", "artifact names and expiry, for the download window",
     ["api", f"repos/{REPO}/actions/artifacts?per_page=5",
      "--jq", "[.artifacts[] | {name, expired, expires_at, "
              "workflow_run: .workflow_run.id}]"]),
    ("open_issues", "open issue count, excluding pull requests",
     ["api", "search/issues?q=repo:" + REPO + "+type:issue+state:open",
      "--jq", "{total_count}"]),
    ("open_pulls", "open pull request count",
     ["api", "search/issues?q=repo:" + REPO + "+type:pr+state:open",
      "--jq", "{total_count}"]),
]


class GithubStateError(Exception):
    """gh is unavailable, or a read failed in a way that must not be recorded."""


def command_line(argv: list[str]) -> str:
    """Render a gh argv as a single paste-ready shell line.

    Every argument goes through ``shlex.quote``. Hand-rolled quoting missed the
    ``&`` in ``...runs?branch=main&per_page=1``, which the shell would read as a
    job-control separator and background the command — producing a line that is
    worse than no line, because it half works.
    """
    return " ".join(["gh", *(shlex.quote(arg) for arg in argv)])


def show_commands() -> int:
    print("Run each line from the repository root, one at a time:\n")
    for key, description, argv in READS:
        print(f"# {description}")
        print(command_line(argv))
        print()
    print("# then, with those answers to hand:")
    print("tools/github_state.py")
    return 0


def read_one(argv: list[str]) -> object:
    proc = subprocess.run(["gh", *argv], capture_output=True, text=True)
    if proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise GithubStateError(f"gh {' '.join(argv)} failed: {detail}")
    text = proc.stdout.strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return text


def ruleset_drift(applied: object, committed_path: pathlib.Path) -> dict:
    """Compare the applied ruleset to the committed copy. This is A7's check."""
    if not isinstance(applied, dict):
        return {"checked": False, "reason": "the applied ruleset did not parse"}
    if not committed_path.is_file():
        return {"checked": False, "reason": f"{committed_path} does not exist"}

    committed = json.loads(committed_path.read_text(encoding="utf-8"))

    def contexts(doc: dict) -> list[str]:
        out = []
        for rule in doc.get("rules", []):
            if rule.get("type") == "required_status_checks":
                for check in rule.get("parameters", {}).get(
                        "required_status_checks", []):
                    if check.get("context"):
                        out.append(check["context"])
        return sorted(out)

    def pr_rule(doc: dict) -> dict:
        for rule in doc.get("rules", []):
            if rule.get("type") == "pull_request":
                return rule.get("parameters", {})
        return {}

    applied_contexts, committed_contexts = contexts(applied), contexts(committed)
    applied_pr, committed_pr = pr_rule(applied), pr_rule(committed)

    differences = []
    if applied_contexts != committed_contexts:
        differences.append({
            "field": "required_status_checks",
            "applied": applied_contexts,
            "committed": committed_contexts,
        })
    for key in sorted(set(applied_pr) | set(committed_pr)):
        if applied_pr.get(key) != committed_pr.get(key):
            differences.append({
                "field": f"pull_request.{key}",
                "applied": applied_pr.get(key),
                "committed": committed_pr.get(key),
            })
    applied_bypass = applied.get("bypass_actors", [])
    if applied_bypass:
        differences.append({
            "field": "bypass_actors",
            "applied": applied_bypass,
            "committed": committed.get("bypass_actors", []),
            "note": "a bypass actor exists on the applied ruleset",
        })

    return {
        "checked": True,
        "in_sync": not differences,
        "differences": differences,
        "committed_copy": str(committed_path),
    }


def collect(root: pathlib.Path) -> dict:
    now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()
    state: dict = {
        "_comment": (
            "Written by tools/github_state.py from a machine with gh "
            "credentials. Everything here is a GitHub-side fact that a cloud "
            "session cannot read: api.github.com answers those sessions 403 by "
            "egress policy. Downstream readers must quote read_at, never imply "
            "these are current."
        ),
        "read_at": now,
        "repo": REPO,
        "reads": {},
    }
    for key, description, argv in READS:
        state["reads"][key] = {
            "description": description,
            "command": command_line(argv),
            "value": read_one(argv),
        }

    state["ruleset_drift"] = ruleset_drift(
        state["reads"]["ruleset"]["value"], root / COMMITTED_RULESET
    )
    return state


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--dry-run", action="store_true",
                        help="read everything, print the result, write nothing")
    parser.add_argument("--show-commands", action="store_true",
                        help="print paste-ready gh lines and exit")
    args = parser.parse_args(argv)

    if args.show_commands:
        return show_commands()

    if shutil.which("gh") is None:
        print(
            "error: gh is not installed here. This script has to run on a "
            "machine authorised for GitHub — the cloud sessions get 403 from "
            "api.github.com by egress policy.\n",
            file=sys.stderr,
        )
        show_commands()
        return 2

    root = pathlib.Path(args.repo_root).resolve()
    try:
        state = collect(root)
    except GithubStateError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    text = json.dumps(state, indent=2, sort_keys=False) + "\n"
    if args.dry_run:
        print(text)
        return 0

    out = root / OUT_PATH
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"wrote {OUT_PATH} at {state['read_at']}")

    drift = state["ruleset_drift"]
    if drift.get("checked") and not drift.get("in_sync"):
        print("\nThe applied ruleset and the committed copy DISAGREE:")
        for difference in drift["differences"]:
            print(f"  {difference['field']}:")
            print(f"    applied   {difference['applied']!r}")
            print(f"    committed {difference['committed']!r}")
        print("\nUpdate .github/rulesets/protect_main.json to match, or change "
              "the ruleset back. The committed copy is what "
              "check_required_contexts.py measures ci.yml against, so a stale "
              "copy makes that check agree with the wrong thing.")
        return 1
    if drift.get("checked"):
        print("The applied ruleset matches the committed copy.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
