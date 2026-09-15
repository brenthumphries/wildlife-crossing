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

**Revised 2026-09-14.** Three things changed, none of them the rule above.

* The reads are REST paths with the reduction done in Python, not ``--jq``
  strings. ``gh api`` and a plain unauthenticated ``curl`` then produce the
  identical file, so a session without ``gh`` — the Cowork device VM has
  network and no ``gh`` — can refresh it with ``--curl``. The paste-ready
  ``--show-commands`` lines still work; they just print whole objects.
* The daily dispatch (``tools/warden.py day``) needs open pull requests with
  their head branches, recently merged ones, branches, tags, releases and the
  last few runs on ``main``. Those reads are added. Twelve REST calls in all,
  well inside the 60-per-hour anonymous budget.
* ``--output`` writes somewhere other than the tracked file. ``warden sync``
  writes the gitignored ``docs/plan/github-state.json`` so a refresh does not
  dirty the tree; ``tools/facts.py`` reads whichever of the two is fresher and
  says which. The tracked copy is refreshed deliberately, when a commit plan
  claims it.

**The drift check is the reason this is a script and not a habit.**
``.github/rulesets/protect_main.json`` is a checked-in *copy* of ruleset
``22403399``, which can be edited in the web interface — as it was on
2026-09-08, when auto-merge was enabled. ``check_required_contexts.py`` proves
``ci.yml`` agrees with that copy; only this script can prove the copy agrees
with the gate. Together they close the loop.

**No secrets are written.** Everything recorded here is readable by anyone who
can see the repository, which is anyone at all: it is public. The file records
*settings and statuses*, never tokens.

Usage:
    tools/github_state.py                 # read with gh, write docs/github-state.json
    tools/github_state.py --output docs/plan/github-state.json
    tools/github_state.py --curl          # read unauthenticated (no gh needed)
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
import urllib.error
import urllib.request

REPO = "brenthumphries/wildlife-crossing"
RULESET_ID = "22403399"
OUT_PATH = pathlib.Path("docs/github-state.json")
COMMITTED_RULESET = pathlib.Path(".github/rulesets/protect_main.json")
API_BASE = "https://api.github.com/"

# Each read is (key, human description, gh argv). Kept as data so --show-commands
# and the real run cannot drift apart: they iterate the same list. The argv is
# always ["api", <path>] — a REST path, no --jq — so the same path works through
# `gh api` and through `curl`. The reduction of each response to what the file
# records is REDUCERS[key], below.
READS: list[tuple[str, str, list[str]]] = [
    ("ruleset", "the applied ruleset, to diff against the committed copy",
     ["api", f"repos/{REPO}/rulesets/{RULESET_ID}"]),
    ("repository", "visibility, auto-merge, and the security_and_analysis block",
     ["api", f"repos/{REPO}"]),
    ("latest_main_run", "the newest CI run on main and its conclusion",
     ["api", f"repos/{REPO}/actions/runs?branch=main&per_page=1"]),
    ("recent_main_runs", "the last five runs on main, for the trend",
     ["api", f"repos/{REPO}/actions/runs?branch=main&per_page=5"]),
    ("artifacts", "artifact names and expiry, for the download window",
     ["api", f"repos/{REPO}/actions/artifacts?per_page=5"]),
    ("open_issues", "open issue count, excluding pull requests",
     ["api", "search/issues?q=repo:" + REPO + "+type:issue+state:open"]),
    ("open_pulls", "open pull request count",
     ["api", "search/issues?q=repo:" + REPO + "+type:pr+state:open"]),
    ("open_pull_requests", "open pull requests with head branch and draft state",
     ["api", f"repos/{REPO}/pulls?state=open&per_page=30"]),
    ("recent_merged_pulls", "recently closed pull requests that were merged",
     ["api", f"repos/{REPO}/pulls?state=closed&sort=updated&direction=desc&per_page=30"]),
    ("branches", "branch names on origin",
     ["api", f"repos/{REPO}/branches?per_page=100"]),
    ("tags", "tag names on origin",
     ["api", f"repos/{REPO}/tags?per_page=20"]),
    ("releases", "GitHub releases, if any",
     ["api", f"repos/{REPO}/releases?per_page=5"]),
]


def _run(doc: object) -> dict | None:
    if not isinstance(doc, dict):
        return None
    return {
        "id": doc.get("id"), "name": doc.get("name"), "status": doc.get("status"),
        "conclusion": doc.get("conclusion"), "created_at": doc.get("created_at"),
        "head_sha": doc.get("head_sha"), "event": doc.get("event"),
    }


def _pull(doc: dict) -> dict:
    return {
        "number": doc.get("number"), "title": doc.get("title"),
        "head": (doc.get("head") or {}).get("ref"),
        "head_sha": (doc.get("head") or {}).get("sha"),
        "draft": doc.get("draft"), "updated_at": doc.get("updated_at"),
        "merged_at": doc.get("merged_at"), "html_url": doc.get("html_url"),
    }


REDUCERS = {
    "ruleset": lambda d: d,
    "repository": lambda d: {k: d.get(k) for k in (
        "visibility", "allow_auto_merge", "allow_squash_merge",
        "allow_rebase_merge", "delete_branch_on_merge", "security_and_analysis",
    )} if isinstance(d, dict) else None,
    "latest_main_run": lambda d: _run((d.get("workflow_runs") or [None])[0])
    if isinstance(d, dict) else None,
    "recent_main_runs": lambda d: [_run(r) for r in d.get("workflow_runs", [])]
    if isinstance(d, dict) else None,
    "artifacts": lambda d: [
        {"name": a.get("name"), "expired": a.get("expired"),
         "expires_at": a.get("expires_at"),
         "workflow_run": (a.get("workflow_run") or {}).get("id")}
        for a in d.get("artifacts", [])
    ] if isinstance(d, dict) else None,
    "open_issues": lambda d: {"total_count": d.get("total_count")} if isinstance(d, dict) else None,
    "open_pulls": lambda d: {"total_count": d.get("total_count")} if isinstance(d, dict) else None,
    "open_pull_requests": lambda d: [_pull(p) for p in d] if isinstance(d, list) else None,
    "recent_merged_pulls": lambda d: [
        _pull(p) for p in d if p.get("merged_at")
    ] if isinstance(d, list) else None,
    "branches": lambda d: [b.get("name") for b in d] if isinstance(d, list) else None,
    "tags": lambda d: [t.get("name") for t in d] if isinstance(d, list) else None,
    "releases": lambda d: [
        {"tag_name": r.get("tag_name"), "name": r.get("name"), "draft": r.get("draft"),
         "prerelease": r.get("prerelease"), "published_at": r.get("published_at")}
        for r in d
    ] if isinstance(d, list) else None,
}


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


def api_path(argv: list[str]) -> str:
    """The REST path from an ``["api", path]`` argv."""
    if len(argv) < 2 or argv[0] != "api":
        raise GithubStateError(f"not an api read: {argv!r}")
    return argv[1]


def read_via_gh(argv: list[str]) -> object:
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


def read_via_curl(argv: list[str]) -> object:
    """Unauthenticated REST read. 60 requests/hour; this script uses twelve."""
    url = API_BASE + api_path(argv)
    request = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "wildlife-crossing-github-state",
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        raise GithubStateError(f"GET {url} answered {exc.code}: {exc.reason}") from exc
    except urllib.error.URLError as exc:
        raise GithubStateError(f"GET {url} failed: {exc.reason}") from exc
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return body


def read_one(argv: list[str], *, via: str = "gh") -> object:
    reader = read_via_curl if via == "curl" else read_via_gh
    return reader(argv)


def reduce_value(key: str, raw: object) -> object:
    reducer = REDUCERS.get(key)
    if reducer is None:
        return raw
    try:
        return reducer(raw)
    except (AttributeError, TypeError, KeyError, IndexError):
        # A response of an unexpected shape is recorded raw, never dropped:
        # the reader downstream can see what came back and say so.
        return raw


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


def collect(root: pathlib.Path, *, via: str = "gh") -> dict:
    now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()
    state: dict = {
        "_comment": (
            "Written by tools/github_state.py. Everything here is a GitHub-side "
            "fact read from api.github.com at read_at, through gh or an "
            "unauthenticated curl (see read_via). Downstream readers must quote "
            "read_at, never imply these are current."
        ),
        "read_at": now,
        "read_via": via,
        "repo": REPO,
        "reads": {},
    }
    for key, description, argv in READS:
        raw = read_one(argv, via=via)
        state["reads"][key] = {
            "description": description,
            "command": command_line(argv),
            "value": reduce_value(key, raw),
        }

    state["ruleset_drift"] = ruleset_drift(
        state["reads"]["ruleset"]["value"], root / COMMITTED_RULESET
    )
    return state


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", type=pathlib.Path, default=None,
                        help=f"where to write (default: {OUT_PATH})")
    parser.add_argument("--curl", action="store_true",
                        help="read api.github.com unauthenticated instead of via gh")
    parser.add_argument("--dry-run", action="store_true",
                        help="read everything, print the result, write nothing")
    parser.add_argument("--show-commands", action="store_true",
                        help="print paste-ready gh lines and exit")
    args = parser.parse_args(argv)

    if args.show_commands:
        return show_commands()

    via = "curl" if args.curl else "gh"
    if via == "gh" and shutil.which("gh") is None:
        print(
            "error: gh is not installed here. Re-run with --curl to read the "
            "public API unauthenticated, or run this on a machine with gh.\n",
            file=sys.stderr,
        )
        show_commands()
        return 2

    root = pathlib.Path(args.repo_root).resolve()
    try:
        state = collect(root, via=via)
    except GithubStateError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    text = json.dumps(state, indent=2, sort_keys=False) + "\n"
    if args.dry_run:
        print(text)
        return 0

    out = args.output or OUT_PATH
    if not out.is_absolute():
        out = root / out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"wrote {out.relative_to(root) if out.is_relative_to(root) else out} "
          f"at {state['read_at']} via {via}")

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
