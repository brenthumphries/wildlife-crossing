#!/usr/bin/env python3
"""The Wildlife Crossing warden: every git, GitHub and dispatch step, one command each.

Rationale (2026-09-14). Every "Next session" block in the daily logs ends the
same way: seven commands — branch, dry-run, execute, push, ``gh pr create``,
``gh pr checks --watch``, ``gh pr merge`` — pasted one at a time, with the
title retyped when ``--fill`` names the pull request after the branch, and a
``github_state.py`` run that nobody remembers. Meanwhile the scheduled
processes that were supposed to plan the week and queue the day kept stalling
on GitHub reads they could not make. The two problems have one shape: the
machine with the credentials was doing the pasting, and the machines without
them were doing the guessing.

This script runs on the machine with the credentials. It does the pasting.

* ``sync``    — fetch, clear lock debris, refresh the GitHub-side state and the
  repository facts. The only place GitHub is read; everything else reads files.
* ``day``     — the daily dispatch. Deterministic: reads ``docs/plan/week.json``
  (the weekly plan) and the synced state, derives each item's status from real
  pull requests, and writes today's queue with a ready-to-run prompt per item.
  No model is involved, so it cannot be stale or wrong about GitHub.
* ``run``     — execute one queued code item in Claude Code, headless, in its
  own worktree, with the model and permission mode the plan assigned.
* ``cowork``  — print (and copy) the prompt for a non-code item, for Cowork.
* ``land``    — the seven-command block, as one command, for work Cowork left
  in the tree with a commit plan.
* ``status``, ``pr``, ``checks``, ``merge``, ``locks``, ``clean``, ``doctor``.

It is the operator's tool, not the model's. Skills read what it writes
(``docs/plan/facts.json``, ``docs/plan/github-state.json``, the queue) and
never call GitHub themselves. Run it bare for a menu.

Nothing here invents a plan, a commit grouping, or a task: the weekly plan is
written by the ``weekly-plan`` skill, commit plans by the session that did the
work. ``ship.py`` keeps every refusal it has; this script calls it.

Usage:
    tools/warden.py                       # menu
    tools/warden.py sync                  # refresh state (run this first, most days)
    tools/warden.py day                   # today's dispatch
    tools/warden.py run C5                # build item C5 in Claude Code
    tools/warden.py cowork C8             # prompt for item C8, copied to the clipboard
    tools/warden.py land commit-plan.json # branch, commit, push, PR, checks, merge
    tools/warden.py --help
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

WEEK_PLAN = pathlib.Path("docs/plan/week.json")
FACTS = pathlib.Path("docs/plan/facts.json")
LIVE_STATE = pathlib.Path("docs/plan/github-state.json")
TRACKED_STATE = pathlib.Path("docs/github-state.json")
QUEUE_DIR = pathlib.Path("docs/plan/queue")
QUEUE_LOG = QUEUE_DIR / "log.jsonl"
CODE_TASK_SKILL = pathlib.Path(".claude/skills/code-task/SKILL.md")
WEEKLY_PLAN_SKILL = pathlib.Path(".claude/skills/weekly-plan/SKILL.md")
ROUTING = pathlib.Path("docs/plan/routing.md")

# pipeline-design.md §7.3: start at two released tasks at a time. The failure
# being guarded is not cost, it is a review queue that turns into stale
# branches. Raise it once the queue is being kept up with.
DEFAULT_MAX_CODE = 2

# Lanes and where they run. `code` and `verify` go to Claude Code; `docs` goes
# to Cowork by Brent's rule (non-code work stays in Cowork); `decision` and
# `mac` are his. A planner may override with an explicit `surface`.
LANES = ("code", "verify", "docs", "decision", "mac")
SURFACE_BY_LANE = {"code": "code", "verify": "code", "docs": "cowork",
                   "decision": "human", "mac": "human"}
TYPE_BY_LANE = {"code": "feat", "verify": "test", "docs": "docs",
                "decision": "chore", "mac": "chore"}
MODELS = ("haiku", "sonnet", "opus", "human")
MODES = ("auto", "supervised", "human")
PERMISSION_FOR_MODE = {"auto": "auto", "supervised": "acceptEdits"}

# docs/pipeline-design.md §7.2 and docs/plan/routing.md: paths no unattended
# run may touch. A pipeline that can edit its own guardrails has none. An item
# whose `files` match one of these is never run headless; `--interactive` is
# allowed because a session you watch is a session you are responsible for.
FORBIDDEN_PATHS = (
    "LICENSE", "LICENSE-ASSETS", "THIRD-PARTY-NOTICES.md", "CONTRIBUTING.md",
    "docs/adr/", ".github/workflows/", ".github/rulesets/",
    "game/export_presets.cfg", "tools/ship.py", "tools/check_dco.py",
)

# ship.py's guard, reused: a lock younger than this may be live.
STALE_LOCK_SECONDS = 120
LOCK_NAMES = ("index.lock", "HEAD.lock")


class WardenError(Exception):
    """A refusal or a failed step. Printed plainly; never a traceback."""


# --------------------------------------------------------------------------
# running things
# --------------------------------------------------------------------------


class Runner:
    """All subprocess calls go through here so tests can replace it.

    ``dry_run`` prints every command instead of running it and returns empty
    output, which is enough to exercise every sequence end to end.
    """

    def __init__(self, dry_run: bool = False, quiet: bool = False) -> None:
        self.dry_run = dry_run
        self.quiet = quiet
        self.calls: list[list[str]] = []

    def run(self, argv: list[str], *, cwd: pathlib.Path | None = None,
            check: bool = True, capture: bool = True, env: dict | None = None,
            stdin: str | None = None) -> str:
        self.calls.append(list(argv))
        shown = " ".join(shlex.quote(a) for a in argv)
        if self.dry_run:
            print(f"  $ {shown}")
            return ""
        if not self.quiet and not capture:
            print(f"  $ {shown}")
        proc = subprocess.run(
            argv, cwd=str(cwd) if cwd else None, input=stdin,
            capture_output=capture, text=True, env=env,
        )
        if check and proc.returncode != 0:
            detail = ((proc.stderr or "") + (proc.stdout or "")).strip() if capture else ""
            raise WardenError(f"{shown}\n  exited {proc.returncode}"
                              + (f": {detail}" if detail else ""))
        return proc.stdout or ""

    def query(self, argv: list[str], *, cwd: pathlib.Path | None = None,
              check: bool = True) -> str:
        """A read-only command. Runs even in --dry-run, because deciding what
        to do next needs real answers (which branch, what is dirty); only the
        commands that change something are withheld."""
        self.calls.append(list(argv))
        proc = subprocess.run(argv, cwd=str(cwd) if cwd else None,
                              capture_output=True, text=True)
        if check and proc.returncode != 0:
            detail = ((proc.stderr or "") + (proc.stdout or "")).strip()
            raise WardenError(f"{' '.join(shlex.quote(a) for a in argv)}\n  exited {proc.returncode}"
                              + (f": {detail}" if detail else ""))
        return proc.stdout or ""

    def ok(self, argv: list[str], *, cwd: pathlib.Path | None = None) -> bool:
        """True if the command exits 0. Never raises."""
        try:
            self.query(argv, cwd=cwd, check=True)
            return True
        except WardenError:
            return False


def repo_root(start: pathlib.Path | None = None) -> pathlib.Path:
    where = start or pathlib.Path.cwd()
    proc = subprocess.run(
        ["git", "-C", str(where), "rev-parse", "--show-toplevel"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise WardenError(f"{where} is not inside a git repository")
    return pathlib.Path(proc.stdout.strip())


def git(runner: Runner, root: pathlib.Path, *args: str, check: bool = True) -> str:
    """A git command that changes something. Withheld under --dry-run."""
    return runner.run(["git", "-C", str(root), *args], check=check)


def git_query(runner: Runner, root: pathlib.Path, *args: str, check: bool = True) -> str:
    """A git command that only reads. Always runs."""
    return runner.query(["git", "-C", str(root), *args], check=check)


def current_branch(runner: Runner, root: pathlib.Path) -> str:
    return git_query(runner, root, "rev-parse", "--abbrev-ref", "HEAD").strip()


def porcelain(runner: Runner, root: pathlib.Path) -> list[str]:
    return [l for l in git_query(runner, root, "status", "--porcelain").splitlines() if l.strip()]


def utc_now() -> _dt.datetime:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0)


def today() -> str:
    return _dt.date.today().isoformat()


def load_json(path: pathlib.Path) -> dict | list | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise WardenError(f"{path} is not valid JSON: {exc}")


def write_json(path: pathlib.Path, doc: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")


def slugify(text: str, limit: int = 40) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:limit].rstrip("-") or "item"


# --------------------------------------------------------------------------
# the weekly plan and the item model
# --------------------------------------------------------------------------


def load_plan(root: pathlib.Path) -> dict:
    doc = load_json(root / WEEK_PLAN)
    if not isinstance(doc, dict):
        raise WardenError(
            f"{WEEK_PLAN} is missing. The weekly-plan skill writes it "
            "(see docs/plan/README.md); until then there is nothing to dispatch."
        )
    validate_plan(doc)
    return doc


def validate_plan(doc: dict) -> None:
    """Refuse a plan the dispatch cannot act on. Shape errors are the planner's
    to fix, and they should be found on Monday, not by a failed run on Tuesday."""
    items = doc.get("items")
    if not isinstance(items, list):
        raise WardenError("week.json: 'items' must be a list")
    seen: set[str] = set()
    for position, item in enumerate(items, start=1):
        if not isinstance(item, dict):
            raise WardenError(f"week.json: item #{position} is not an object")
        item_id = item.get("id")
        if not isinstance(item_id, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9]{0,15}", item_id):
            raise WardenError(f"week.json: item #{position} needs a short alphanumeric 'id'")
        if item_id in seen:
            raise WardenError(f"week.json: duplicate item id {item_id!r}")
        seen.add(item_id)
        if not isinstance(item.get("title"), str) or not item["title"].strip():
            raise WardenError(f"week.json: item {item_id} needs a 'title'")
        if item.get("lane") not in LANES:
            raise WardenError(f"week.json: item {item_id} lane must be one of {LANES}")
        if item.get("model", "sonnet") not in MODELS:
            raise WardenError(f"week.json: item {item_id} model must be one of {MODELS}")
        if item.get("mode", "auto") not in MODES:
            raise WardenError(f"week.json: item {item_id} mode must be one of {MODES}")
        deps = item.get("depends_on", [])
        if not isinstance(deps, list) or not all(isinstance(d, str) for d in deps):
            raise WardenError(f"week.json: item {item_id} depends_on must be a list of ids")
        if not isinstance(item.get("acceptance", []), list):
            raise WardenError(f"week.json: item {item_id} acceptance must be a list")
        if item.get("mode", "auto") == "auto" and forbidden_files(item):
            raise WardenError(
                f"week.json: item {item_id} touches a forbidden path "
                f"({', '.join(forbidden_files(item))}) and cannot be mode 'auto'"
            )
    for item in items:
        for dep in item.get("depends_on", []):
            if dep not in seen:
                raise WardenError(
                    f"week.json: item {item['id']} depends on {dep!r}, which is not in the plan"
                )


def item_type(item: dict) -> str:
    return item.get("type") or TYPE_BY_LANE[item["lane"]]


def item_surface(item: dict) -> str:
    return item.get("surface") or SURFACE_BY_LANE[item["lane"]]


def item_model(item: dict) -> str:
    return item.get("model") or "sonnet"


def item_mode(item: dict) -> str:
    return item.get("mode") or ("auto" if item_model(item) in ("haiku", "sonnet") else "supervised")


def forbidden_files(item: dict) -> list[str]:
    """The item's files that no headless run may touch."""
    hits = []
    for path in item.get("files", []):
        for rule in FORBIDDEN_PATHS:
            if path == rule or (rule.endswith("/") and path.startswith(rule)):
                hits.append(path)
                break
    return hits


def item_branch(item: dict) -> str:
    return f"{item_type(item)}/{item['id'].lower()}-{slugify(item['title'])}"


def branch_matches_item(branch: str | None, item_id: str) -> bool:
    """`feat/c5-add-display` matches item C5. The type prefix is not required to
    match, because a planner may call something docs that landed as chore."""
    if not branch or "/" not in branch:
        return False
    tail = branch.split("/", 1)[1].lower()
    return tail == item_id.lower() or tail.startswith(item_id.lower() + "-")


def freshest_state(root: pathlib.Path) -> tuple[dict | None, str | None]:
    """The github-state file with the newest read_at, and its path."""
    best: tuple[_dt.datetime, str, dict] | None = None
    for rel in (LIVE_STATE, TRACKED_STATE):
        doc = load_json(root / rel)
        if not isinstance(doc, dict):
            continue
        try:
            read_at = _dt.datetime.fromisoformat(str(doc.get("read_at")).replace("Z", "+00:00"))
        except ValueError:
            continue
        if best is None or read_at > best[0]:
            best = (read_at, str(rel), doc)
    if best is None:
        return None, None
    return best[2], best[1]


def state_value(state: dict | None, key: str):
    if not state:
        return None
    entry = (state.get("reads") or {}).get(key)
    return entry.get("value") if isinstance(entry, dict) else None


def derive_statuses(plan: dict, state: dict | None) -> dict[str, dict]:
    """Each item's status as GitHub sees it, never as the plan hoped.

    A merged pull request on the item's branch means done; an open one means
    in review; otherwise the plan's own status stands, and an item whose
    dependencies are not all done is blocked. The plan file is never edited by
    this — it is Monday's document, and its statuses are Monday's."""
    open_prs = state_value(state, "open_pull_requests") or []
    merged = state_value(state, "recent_merged_pulls") or []
    result: dict[str, dict] = {}
    for item in plan["items"]:
        item_id = item["id"]
        planned = item.get("status", "open")
        status = {"status": planned, "pr": None, "source": "plan"}
        for pr in merged:
            if isinstance(pr, dict) and branch_matches_item(pr.get("head"), item_id):
                status = {"status": "done", "pr": pr, "source": "merged pull request"}
                break
        else:
            for pr in open_prs:
                if isinstance(pr, dict) and branch_matches_item(pr.get("head"), item_id):
                    status = {"status": "in-review", "pr": pr, "source": "open pull request"}
                    break
        result[item_id] = status
    for item in plan["items"]:
        entry = result[item["id"]]
        if entry["status"] == "open":
            waiting = [d for d in item.get("depends_on", [])
                       if result.get(d, {}).get("status") != "done"]
            if waiting:
                entry["status"] = "blocked"
                entry["waiting_on"] = waiting
    return result


def dispatch(plan: dict, statuses: dict[str, dict], *,
             max_code: int = DEFAULT_MAX_CODE) -> dict[str, list[dict]]:
    """Today's queue. Open items only, in plan order, capped for the code lane,
    and file-disjoint: an item whose files overlap something already in review
    or already picked today waits, so two branches never fight over one file."""
    picked_code: list[dict] = []
    buckets: dict[str, list[dict]] = {
        "code": [], "supervised": [], "cowork": [], "yours": [], "in_review": [],
        "blocked": [], "waiting": [], "done": [], "dropped": [],
    }
    busy_files: set[str] = set()
    for item in plan["items"]:
        if statuses[item["id"]]["status"] == "in-review":
            busy_files.update(item.get("files", []))

    ordered = sorted(plan["items"], key=lambda i: (i.get("priority", 999), i["id"]))
    for item in ordered:
        entry = statuses[item["id"]]
        st = entry["status"]
        if st == "done":
            buckets["done"].append(item)
        elif st == "dropped":
            buckets["dropped"].append(item)
        elif st == "in-review":
            buckets["in_review"].append(item)
        elif st == "blocked":
            buckets["blocked"].append(item)
        elif st == "open":
            surface = item_surface(item)
            files = set(item.get("files", []))
            if surface == "human":
                buckets["yours"].append(item)
            elif files & busy_files:
                item = dict(item, _waiting_reason="shares a file with an item in flight")
                buckets["waiting"].append(item)
            elif surface == "code" and item_mode(item) == "supervised":
                # Needs you at the keyboard, so it takes no unattended slot;
                # it still claims its files so nothing else edits them today.
                buckets["supervised"].append(item)
                busy_files |= files
            elif surface == "code":
                if len(picked_code) >= max_code:
                    item = dict(item, _waiting_reason=f"code lane is full ({max_code} at a time)")
                    buckets["waiting"].append(item)
                else:
                    picked_code.append(item)
                    buckets["code"].append(item)
                    busy_files |= files
            else:
                buckets["cowork"].append(item)
                busy_files |= files
        else:
            buckets["waiting"].append(dict(item, _waiting_reason=f"status {st!r}"))
    return buckets


# --------------------------------------------------------------------------
# prompts
# --------------------------------------------------------------------------


def item_block(item: dict, plan: dict) -> str:
    fields = {k: v for k, v in item.items() if not k.startswith("_")}
    fields["branch"] = item_branch(item)
    header = {
        "week_of": plan.get("week_of"),
        "measured_against": (plan.get("measured_against") or {}).get("head_sha"),
        "build_case": plan.get("build_case"),
    }
    return json.dumps({"plan": header, "item": fields}, indent=2)


def code_prompt(item: dict, plan: dict) -> str:
    return (
        f"Build item {item['id']} from this week's plan: {item['title']}.\n\n"
        f"Read {CODE_TASK_SKILL} first and follow it exactly — it is the contract "
        f"for every automated code task on this repository (branch, conventions, "
        f"tests, sign-off, the pull-request brief). Then read the scoped CLAUDE.md "
        f"for every directory you touch.\n\n"
        f"You are already on branch `{item_branch(item)}` in a dedicated worktree "
        f"whose base is origin/main. Do not switch branches. Do not touch main.\n\n"
        f"The item, verbatim from docs/plan/week.json:\n\n```json\n{item_block(item, plan)}\n```\n\n"
        f"Facts about the tree are in docs/plan/facts.json (regenerate with "
        f"`python3 tools/facts.py` if you need them fresh). Cite them; do not "
        f"recount. When the acceptance criteria are met, push the branch and open "
        f"the pull request as the skill describes. If you cannot meet them, stop "
        f"and say exactly which criterion and why — an honest partial with a "
        f"failing suite is more useful than a green PR that quietly narrowed the task."
    )


def cowork_prompt(item: dict, plan: dict) -> str:
    files = "\n".join(f"- `{f}`" for f in item.get("files", [])) or "- (the item names none; say which you touched)"
    acceptance = "\n".join(f"- {a}" for a in item.get("acceptance", [])) or "- (none written; ask before starting)"
    refs = "\n".join(f"- {r}" for r in item.get("references", [])) or "- (none)"
    return (
        f"Work item {item['id']} from this week's Wildlife Crossing plan: **{item['title']}**.\n\n"
        f"Context: {item.get('context', '(none written)')}\n\n"
        f"Files this item is expected to touch:\n{files}\n\n"
        f"Acceptance criteria — all of these, verbatim from docs/plan/week.json:\n{acceptance}\n\n"
        f"References:\n{refs}\n\n"
        f"Ground rules for this session:\n"
        f"- The repository is mounted from my Mac. Read anything; write project files; "
        f"**never run a git command that takes a lock** (add, commit, checkout, stash, "
        f"pull, mv). docs/automation.md explains why.\n"
        f"- Read docs/plan/facts.json before making claims about the tree, and "
        f"docs/plan/github-state.json (or docs/github-state.json) before making claims "
        f"about GitHub. Quote their read time. Do not fetch GitHub yourself.\n"
        f"- Follow the root CLAUDE.md and the scoped CLAUDE.md for every directory you touch; "
        f"the vault conventions are in obsidian-vault/CLAUDE.md.\n"
        f"- When the acceptance criteria are met, write `commit-plan-{today()}-{item['id'].lower()}.json` "
        f"at the repository root for tools/ship.py, with branch `{item_branch(item)}`, "
        f"one commit per logical change, every changed path claimed, and run "
        f"`python3 tools/ship.py <plan> --allow-branch-mismatch` as a dry run. "
        f"Then tell me it is ready and I will run `tools/warden land <plan>`.\n"
        f"- If a criterion cannot be met, say which and why rather than working around it."
    )


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------


def find_locks(root: pathlib.Path) -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    git_dir = root / ".git"
    for name in LOCK_NAMES:
        p = git_dir / name
        if p.exists():
            found.append(p)
    refs = git_dir / "refs" / "heads"
    if refs.is_dir():
        found.extend(sorted(refs.rglob("*.lock")))
    return found


def cmd_locks(runner: Runner, root: pathlib.Path, *, force: bool = False) -> int:
    """Remove the lock debris the Cowork mount leaves behind. On the Mac,
    unlink works, which is the whole reason this lives here and not in a
    session (docs/automation.md, "Why .git/index.lock keeps coming back")."""
    locks = find_locks(root)
    if not locks:
        print("no lock files")
        return 0
    removed = 0
    for lock in locks:
        age = time.time() - lock.stat().st_mtime
        if age < STALE_LOCK_SECONDS and not force:
            print(f"kept   {lock.relative_to(root)} ({int(age)}s old — a git process may be live; --force to remove)")
            continue
        if runner.dry_run:
            print(f"would remove {lock.relative_to(root)} ({int(age)}s old)")
        else:
            lock.unlink()
            print(f"removed {lock.relative_to(root)} ({int(age)}s old)")
        removed += 1
    parked = root / ".git" / "_stale_locks"
    if parked.is_dir():
        print(f"note   {parked.relative_to(root)}/ still exists (earlier sessions parked locks there); "
              f"`rm -rf .git/_stale_locks` when nothing holds it")
    return 0


def python_tool(root: pathlib.Path, name: str) -> list[str]:
    return [sys.executable, str(root / "tools" / name)]


def cmd_sync(runner: Runner, root: pathlib.Path, *, fetch: bool = True,
             curl: bool = False, tracked: bool = False) -> int:
    """Refresh everything the other commands read. Safe to run any time."""
    if fetch:
        print("fetching origin…")
        git(runner, root, "fetch", "origin", "--prune")
    cmd_locks(runner, root)

    argv = python_tool(root, "github_state.py") + ["--repo-root", str(root)]
    if curl or shutil.which("gh") is None:
        argv.append("--curl")
        if not curl:
            print("gh is not installed here; reading api.github.com unauthenticated")
    if not tracked:
        argv += ["--output", str(LIVE_STATE)]
    print("reading GitHub…")
    try:
        out = runner.run(argv, cwd=root, check=False, capture=True)
        print("  " + out.strip().replace("\n", "\n  ") if out.strip() else "  (no output)")
    except WardenError as exc:
        print(f"  github_state.py failed: {exc}")

    print("recording facts…")
    out = runner.run(python_tool(root, "facts.py") + ["--repo", str(root)], cwd=root, check=False)
    print("  " + out.strip().replace("\n", "\n  ") if out.strip() else "  (no output)")
    return 0


def cmd_status(runner: Runner, root: pathlib.Path) -> int:
    """What the synced state says. Reads files only; run `sync` for fresh ones."""
    facts = load_json(root / FACTS)
    state, source = freshest_state(root)
    if not facts:
        print(f"{FACTS} not found — run `warden sync` first")
    else:
        m = facts["measured_against"]
        print(f"facts      as of {facts['written_at']} at {m['head_sha'][:7]} ({m['branch']})"
              + ("" if facts["working_tree"]["clean"] else
                 f"; tree has {len(facts['working_tree']['modified'])} modified, "
                 f"{len(facts['working_tree']['untracked'])} untracked"))
        vs = m.get("vs_origin_main") or {}
        if vs.get("known"):
            print(f"vs origin  ahead {vs['ahead']}, behind {vs['behind']}")
        print(f"build case {facts['build_case']['case']}")
    if not state:
        print("github     no state file — run `warden sync`")
    else:
        print(f"github     {source}, read {state['read_at']} via {state.get('read_via', 'gh')}")
        run = state_value(state, "latest_main_run") or {}
        if run:
            print(f"main CI    {run.get('conclusion') or run.get('status')} on {str(run.get('head_sha'))[:7]} at {run.get('created_at')}")
        drift = state.get("ruleset_drift") or {}
        if drift.get("checked"):
            print(f"ruleset    {'matches committed copy' if drift.get('in_sync') else 'DRIFTED — see github_state.py output'}")
        prs = state_value(state, "open_pull_requests") or []
        print(f"open PRs   {len(prs)}")
        for pr in prs:
            print(f"  #{pr.get('number')}  {pr.get('head')}  {'draft ' if pr.get('draft') else ''}{pr.get('title')}")
        arts = state_value(state, "artifacts") or []
        live = [a for a in arts if isinstance(a, dict) and not a.get("expired")]
        if live:
            print(f"artifacts  {len(live)} live; newest expires {max(a.get('expires_at') or '' for a in live)}")
    try:
        plan = load_plan(root)
    except WardenError as exc:
        print(f"plan       {exc}")
        return 0
    statuses = derive_statuses(plan, state)
    counts: dict[str, int] = {}
    for entry in statuses.values():
        counts[entry["status"]] = counts.get(entry["status"], 0) + 1
    print(f"plan       week of {plan.get('week_of')}: " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))
    return 0


def render_queue_markdown(queue: dict) -> str:
    lines = [f"# Dispatch — {queue['date']}", "",
             f"Plan week of {queue['week_of']}, measured against `{str(queue['measured_against'])[:7]}`. "
             f"GitHub state read {queue['github_state_read_at'] or 'never'}.", ""]

    def section(title: str, key: str, fmt) -> None:
        items = queue["buckets"].get(key, [])
        lines.append(f"## {title} ({len(items)})")
        lines.append("")
        if not items:
            lines.append("- none")
        for item in items:
            lines.append(fmt(item))
        lines.append("")

    section("Claude Code — run these", "code",
            lambda i: f"- **{i['id']}** {i['title']} — {item_model(i)}/{item_mode(i)}, size {i.get('size', '?')}  \n  `tools/warden run {i['id']}`")
    section("Claude Code — supervised, when you can watch", "supervised",
            lambda i: f"- **{i['id']}** {i['title']} — {item_model(i)}, size {i.get('size', '?')}  \n  `tools/warden run {i['id']} --interactive`")
    section("Cowork — paste these", "cowork",
            lambda i: f"- **{i['id']}** {i['title']} — size {i.get('size', '?')}  \n  `tools/warden cowork {i['id']}`")
    section("Yours", "yours", lambda i: f"- **{i['id']}** {i['title']} ({i['lane']})")
    section("In review", "in_review",
            lambda i: f"- **{i['id']}** {i['title']} — PR #{(queue['statuses'][i['id']].get('pr') or {}).get('number')}")
    section("Waiting", "waiting", lambda i: f"- **{i['id']}** {i['title']} — {i.get('_waiting_reason', '')}")
    section("Blocked", "blocked",
            lambda i: f"- **{i['id']}** {i['title']} — waiting on {', '.join(queue['statuses'][i['id']].get('waiting_on', []))}")
    section("Done this week", "done", lambda i: f"- ~~{i['id']}~~ {i['title']}")
    return "\n".join(lines)


def cmd_day(runner: Runner, root: pathlib.Path, *, max_code: int = DEFAULT_MAX_CODE,
            write: bool = True, as_json: bool = False) -> int:
    plan = load_plan(root)
    state, source = freshest_state(root)
    statuses = derive_statuses(plan, state)
    buckets = dispatch(plan, statuses, max_code=max_code)
    queue = {
        "date": today(),
        "written_at": utc_now().isoformat(),
        "week_of": plan.get("week_of"),
        "measured_against": (plan.get("measured_against") or {}).get("head_sha"),
        "github_state_source": source,
        "github_state_read_at": state.get("read_at") if state else None,
        "statuses": statuses,
        "buckets": {k: [dict(i) for i in v] for k, v in buckets.items()},
        "prompts": {
            **{i["id"]: code_prompt(i, plan) for i in buckets["code"] + buckets["supervised"]},
            **{i["id"]: cowork_prompt(i, plan) for i in buckets["cowork"]},
        },
    }
    if as_json:
        print(json.dumps(queue, indent=2))
        return 0
    if write:
        write_json(root / QUEUE_DIR / f"{queue['date']}.json", queue)
        (root / QUEUE_DIR / f"{queue['date']}.md").write_text(
            render_queue_markdown(queue) + "\n", encoding="utf-8")
    print(render_queue_markdown(queue))
    if state:
        age = (utc_now() - _dt.datetime.fromisoformat(state["read_at"].replace("Z", "+00:00")))
        hours = age.total_seconds() / 3600
        if hours > 24:
            print(f"note: GitHub state is {hours:.0f} hours old — run `warden sync` for a current view")
    else:
        print("note: no GitHub state — statuses come from the plan alone; run `warden sync`")
    if write:
        print(f"written to {QUEUE_DIR}/{queue['date']}.md")
    return 0


def find_item(plan: dict, item_id: str) -> dict:
    for item in plan["items"]:
        if item["id"].lower() == item_id.lower():
            return item
    raise WardenError(f"no item {item_id!r} in {WEEK_PLAN} (ids: "
                      + ", ".join(i["id"] for i in plan["items"]) + ")")


def copy_to_clipboard(text: str) -> bool:
    tool = shutil.which("pbcopy") or shutil.which("xclip") or shutil.which("wl-copy")
    if not tool:
        return False
    argv = [tool] if "pbcopy" in tool or "wl-copy" in tool else [tool, "-selection", "clipboard"]
    try:
        subprocess.run(argv, input=text, text=True, check=True)
        return True
    except (subprocess.CalledProcessError, OSError):
        return False


def cmd_cowork(runner: Runner, root: pathlib.Path, item_id: str, *, copy: bool = True) -> int:
    plan = load_plan(root)
    item = find_item(plan, item_id)
    text = cowork_prompt(item, plan)
    print(text)
    if copy and copy_to_clipboard(text):
        print("\n(copied to the clipboard — paste it into a new Cowork session with the repo folder connected)")
    append_log(root, {"at": utc_now().isoformat(), "action": "cowork", "item": item["id"]})
    return 0


def worktree_dir(root: pathlib.Path, branch: str) -> pathlib.Path:
    base = os.environ.get("WARDEN_WORKTREES")
    base_path = pathlib.Path(base) if base else root.parent / f"{root.name}-work"
    return base_path / branch.replace("/", "--")


def claude_supports_auto(runner: Runner) -> bool:
    try:
        text = runner.query(["claude", "--help"], check=False)
    except (WardenError, OSError):
        return False
    return '"auto"' in text or "auto," in text


def claude_argv(prompt: str, *, model: str, permission_mode: str, interactive: bool,
                effort: str | None = None) -> list[str]:
    argv = ["claude", "--model", model, "--permission-mode", permission_mode]
    if effort:
        argv += ["--effort", effort]
    if interactive:
        argv.append(prompt)
    else:
        argv += ["--output-format", "json", "-p", prompt]
    return argv


def parse_claude_result(text: str) -> dict:
    """The last JSON object in the output, or a stub. `-p --output-format json`
    prints one object; anything else is tolerated rather than trusted."""
    text = text.strip()
    if not text:
        return {}
    try:
        doc = json.loads(text)
        return doc if isinstance(doc, dict) else {"result": doc}
    except json.JSONDecodeError:
        pass
    for line in reversed(text.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return {"result": text[-2000:]}


def append_log(root: pathlib.Path, record: dict) -> None:
    path = root / QUEUE_LOG
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")


def cmd_run(runner: Runner, root: pathlib.Path, item_id: str, *, interactive: bool = False,
            model: str | None = None, here: bool = False, effort: str | None = None,
            watch: bool = False) -> int:
    plan = load_plan(root)
    item = find_item(plan, item_id)
    if item_surface(item) == "human":
        raise WardenError(f"item {item['id']} is in the {item['lane']} lane — it is yours, not Claude Code's")
    if item_surface(item) == "cowork" and not model:
        print(f"note: item {item['id']} is a {item['lane']}-lane item the plan routes to Cowork; "
              f"running it in Claude Code because you asked")
    state, _ = freshest_state(root)
    status = derive_statuses(plan, state)[item["id"]]
    if status["status"] == "done":
        raise WardenError(f"item {item['id']} is already done (PR #{(status.get('pr') or {}).get('number')})")
    if status["status"] == "in-review":
        raise WardenError(f"item {item['id']} already has an open pull request "
                          f"#{(status.get('pr') or {}).get('number')} — `warden checks` or `warden merge` instead")
    if status["status"] == "blocked":
        raise WardenError(f"item {item['id']} is blocked on {', '.join(status.get('waiting_on', []))}")

    model = model or item_model(item)
    if model == "human":
        raise WardenError(f"item {item['id']} is assigned to a human in the plan")
    mode = "supervised" if interactive else item_mode(item)
    if mode == "human":
        raise WardenError(f"item {item['id']} has mode 'human' — run it with --interactive to supervise, or do it yourself")
    forbidden = forbidden_files(item)
    if forbidden and not interactive:
        raise WardenError(
            f"item {item['id']} touches {', '.join(forbidden)} — on the forbidden list "
            f"(docs/plan/routing.md); headless runs may not. Use --interactive and watch it."
        )
    permission = PERMISSION_FOR_MODE[mode]
    if permission == "auto" and not interactive and not claude_supports_auto(runner):
        print("note: this Claude Code does not list --permission-mode auto; using acceptEdits")
        permission = "acceptEdits"

    branch = item_branch(item)
    git(runner, root, "fetch", "origin", "--prune")
    if here:
        workdir = root
        if porcelain(runner, root):
            raise WardenError("the working tree is not clean; run in a worktree instead (drop --here)")
        git(runner, root, "checkout", "-B", branch, "origin/main")
    else:
        workdir = worktree_dir(root, branch)
        if workdir.exists():
            print(f"reusing worktree {workdir}")
        else:
            workdir.parent.mkdir(parents=True, exist_ok=True)
            if git_query(runner, root, "rev-parse", "--verify", "-q", f"refs/heads/{branch}", check=False).strip():
                git(runner, root, "worktree", "add", str(workdir), branch)
            else:
                git(runner, root, "worktree", "add", "-b", branch, str(workdir), "origin/main")
    # Facts for the run are read from the worktree, which is a clean origin/main.
    runner.run(python_tool(root, "facts.py") + ["--repo", str(workdir)], cwd=workdir, check=False)

    prompt = code_prompt(item, plan)
    argv = claude_argv(prompt, model=model, permission_mode=permission,
                       interactive=interactive, effort=effort or item.get("effort"))
    started = utc_now()
    print(f"running {item['id']} — {model}, {permission}, {'interactive' if interactive else 'headless'}, "
          f"branch {branch}\n  in {workdir}")
    record = {"at": started.isoformat(), "action": "run", "item": item["id"], "branch": branch,
              "model": model, "permission_mode": permission, "interactive": interactive,
              "worktree": str(workdir)}
    try:
        if interactive:
            runner.run(argv, cwd=workdir, capture=False, check=False)
            result: dict = {}
        else:
            out = runner.run(argv, cwd=workdir, capture=True, check=False)
            result = parse_claude_result(out)
    finally:
        record["seconds"] = int((utc_now() - started).total_seconds())

    if result:
        for key in ("is_error", "num_turns", "total_cost_usd", "session_id", "duration_ms"):
            if key in result:
                record[key] = result[key]
        summary = str(result.get("result", ""))[-1500:]
        if summary:
            print("\n--- Claude's report ---\n" + summary + "\n-----------------------")

    commits = git_query(runner, root, "log", "--oneline", f"origin/main..{branch}", check=False).strip()
    record["commits"] = len(commits.splitlines()) if commits else 0
    pushed = bool(git_query(runner, root, "ls-remote", "--heads", "origin", branch, check=False).strip())
    record["pushed"] = pushed
    leftover = git_query(runner, workdir, "status", "--porcelain", check=False).strip()
    record["uncommitted_paths"] = len(leftover.splitlines()) if leftover else 0
    pr_line = ""
    if shutil.which("gh"):
        pr_json = runner.query(["gh", "pr", "list", "--head", branch, "--state", "open",
                                "--json", "number,url,title"], cwd=root, check=False)
        try:
            prs = json.loads(pr_json) if pr_json.strip() else []
        except json.JSONDecodeError:
            prs = []
        if prs:
            record["pr"] = prs[0].get("number")
            pr_line = f"PR #{prs[0].get('number')} {prs[0].get('url')}"
    append_log(root, record)

    print(f"\n{item['id']}: {record['commits']} commit(s) on {branch}, "
          f"{'pushed' if pushed else 'NOT pushed'}"
          + (f", {record['uncommitted_paths']} uncommitted path(s) left in the worktree" if record["uncommitted_paths"] else "")
          + (f", {pr_line}" if pr_line else ", no pull request"))
    if pr_line and watch:
        return cmd_checks(runner, root, str(record["pr"]))
    if pr_line:
        print(f"next: `tools/warden checks {record['pr']}` then `tools/warden merge {record['pr']}`")
    elif record["commits"]:
        print(f"next: inspect {workdir}; push with `git -C {shlex.quote(str(workdir))} push -u origin {branch}` "
              f"and `gh pr create` from there, or rerun with --interactive")
    else:
        print(f"nothing was committed; read the report above and rerun with --interactive if it asked a question")
    return 0


def cmd_next(runner: Runner, root: pathlib.Path, **kwargs) -> int:
    plan = load_plan(root)
    state, _ = freshest_state(root)
    buckets = dispatch(plan, derive_statuses(plan, state))
    if not buckets["code"]:
        print("no code items are ready; `warden day` shows why")
        return 0
    return cmd_run(runner, root, buckets["code"][0]["id"], **kwargs)


def pr_title_and_body(plan_doc: dict) -> tuple[str, str]:
    commits = plan_doc["commits"]
    if plan_doc.get("title"):
        title = str(plan_doc["title"]).strip()
    else:
        first = commits[0]
        scope = f"({first['scope']})" if first.get("scope") else ""
        title = f"{first['type']}{scope}: {first['subject']}"
        if len(commits) > 1:
            title += f" (+{len(commits) - 1} more)"
    parts = []
    if plan_doc.get("pr_body"):
        parts.append(str(plan_doc["pr_body"]).strip())
    parts.append("## Commits\n")
    for commit in commits:
        scope = f"({commit['scope']})" if commit.get("scope") else ""
        parts.append(f"- **{commit['type']}{scope}: {commit['subject']}**")
        if commit.get("body"):
            parts.append("  " + str(commit["body"]).strip().replace("\n", "\n  "))
    parts.append("\nOpened with `tools/warden.py land`.")
    return title, "\n".join(parts)


def cmd_land(runner: Runner, root: pathlib.Path, plan_path: pathlib.Path, *,
             merge: bool = True, watch: bool = True, title: str | None = None,
             draft: bool = False) -> int:
    """The seven-command block, in order, stopping at the first refusal."""
    plan_doc = load_json(plan_path if plan_path.is_absolute() else root / plan_path)
    if not isinstance(plan_doc, dict) or not plan_doc.get("commits"):
        raise WardenError(f"{plan_path} is not a commit plan")
    branch = plan_doc.get("branch", "main")
    if branch == "main":
        raise WardenError("the plan's branch is main; main is protected (ruleset 22403399) — give the plan a branch")
    if not porcelain(runner, root):
        raise WardenError("the working tree is clean; nothing to land")

    cmd_locks(runner, root)
    current = current_branch(runner, root)
    if current == branch:
        print(f"already on {branch}")
    elif current == "main":
        print("updating main…")
        git(runner, root, "pull", "--ff-only")
        git(runner, root, "checkout", "-b", branch)
    else:
        raise WardenError(f"on branch {current!r}, but the plan wants {branch!r}; "
                          f"`git checkout main` first (stash if it refuses — see docs/push-runbook.md Step 0)")

    print("committing…")
    runner.run(python_tool(root, "ship.py") + [str(plan_path), "--execute"], cwd=root, capture=False)
    print("pushing…")
    git(runner, root, "push", "-u", "origin", branch)

    pr_title, pr_body = pr_title_and_body(plan_doc)
    if title:
        pr_title = title
    print(f"opening pull request: {pr_title}")
    argv = ["gh", "pr", "create", "--title", pr_title, "--body", pr_body]
    if draft:
        argv.append("--draft")
    out = runner.run(argv, cwd=root)
    url = out.strip().splitlines()[-1] if out.strip() else ""
    number = url.rstrip("/").rsplit("/", 1)[-1] if url else ""
    print(f"  {url}")
    append_log(root, {"at": utc_now().isoformat(), "action": "land", "plan": str(plan_path),
                      "branch": branch, "pr": number, "title": pr_title})
    if draft or not watch:
        print(f"next: `tools/warden checks {number}` then `tools/warden merge {number}`")
        return 0
    code = cmd_checks(runner, root, number or branch)
    if code != 0:
        print(f"checks did not pass; fix, push, then `tools/warden checks {number}` and `tools/warden merge {number}`")
        return code
    if merge:
        return cmd_merge(runner, root, number or branch)
    print(f"checks green; `tools/warden merge {number}` when you are ready")
    return 0


def cmd_checks(runner: Runner, root: pathlib.Path, ref: str, *, attempts: int = 4,
               pause: float = 15.0) -> int:
    """gh pr checks --watch, with the race handled: right after creation the
    run has not registered and gh says 'no checks reported'. Wait and retry."""
    argv = ["gh", "pr", "checks", ref, "--watch", "--fail-fast"]
    for attempt in range(1, attempts + 1):
        proc = subprocess.run(argv, cwd=str(root), capture_output=True, text=True) \
            if not runner.dry_run else None
        runner.calls.append(list(argv))
        if runner.dry_run:
            print("  $ " + " ".join(shlex.quote(a) for a in argv))
            return 0
        output = (proc.stdout or "") + (proc.stderr or "")
        if "no checks reported" in output.lower() and attempt < attempts:
            print(f"  checks not registered yet (attempt {attempt}); waiting {int(pause)}s…")
            time.sleep(pause)
            continue
        print(output.rstrip())
        return proc.returncode
    return 1


def cmd_merge(runner: Runner, root: pathlib.Path, ref: str) -> int:
    print(f"merging {ref}…")
    runner.run(["gh", "pr", "merge", ref, "--merge", "--delete-branch"], cwd=root, capture=False)
    if current_branch(runner, root) != "main":
        git(runner, root, "checkout", "main")
    git(runner, root, "pull", "--ff-only")
    append_log(root, {"at": utc_now().isoformat(), "action": "merge", "ref": ref})
    print("merged; refreshing state…")
    return cmd_sync(runner, root, fetch=True)


def cmd_pr(runner: Runner, root: pathlib.Path, ref: str | None) -> int:
    if ref:
        runner.run(["gh", "pr", "view", ref], cwd=root, capture=False)
    else:
        runner.run(["gh", "pr", "list", "--state", "open"], cwd=root, capture=False)
    return 0


def cmd_clean(runner: Runner, root: pathlib.Path) -> int:
    """Remove worktrees whose branch no longer exists on origin (merged and deleted)."""
    git(runner, root, "fetch", "origin", "--prune")
    listing = git_query(runner, root, "worktree", "list", "--porcelain")
    remote = set(git_query(runner, root, "branch", "-r", "--format=%(refname:short)").split())
    path = None
    removed = 0
    for line in listing.splitlines() + [""]:
        if line.startswith("worktree "):
            path = pathlib.Path(line[len("worktree "):])
        elif line.startswith("branch "):
            branch = line[len("branch refs/heads/"):]
            if path and path != root and f"origin/{branch}" not in remote:
                print(f"removing worktree {path} ({branch} is gone from origin)")
                git(runner, root, "worktree", "remove", "--force", str(path), check=False)
                git(runner, root, "branch", "-D", branch, check=False)
                removed += 1
        elif not line:
            path = None
    git(runner, root, "worktree", "prune", check=False)
    print(f"{removed} worktree(s) removed")
    return 0


def cmd_week(runner: Runner, root: pathlib.Path, *, model: str = "sonnet") -> int:
    """Run the weekly plan locally. The cloud routine is the default home for
    this (docs/routines/weekly-plan.md); this is the fallback for a Monday
    when it did not fire or you want it now."""
    cmd_sync(runner, root)
    if not (root / WEEKLY_PLAN_SKILL).is_file():
        raise WardenError(f"{WEEKLY_PLAN_SKILL} is missing")
    prompt = ("Run the weekly-plan skill: read .claude/skills/weekly-plan/SKILL.md and follow it "
              "exactly. Write docs/plan/week.json, the dated build-review note, and a commit plan "
              "at the repository root. Do not run git write commands; the operator lands it with "
              "tools/warden.py land.")
    argv = claude_argv(prompt, model=model, permission_mode="acceptEdits", interactive=False)
    print(f"planning the week with {model}…")
    out = runner.run(argv, cwd=root, capture=True, check=False)
    result = parse_claude_result(out)
    print(str(result.get("result", out))[-3000:])
    plans = sorted(root.glob("commit-plan-*.json"), key=lambda p: p.stat().st_mtime)
    if plans:
        print(f"\nnext: review docs/plan/week.json and the note, then `tools/warden land {plans[-1].name}`")
    return 0


def cmd_doctor(runner: Runner, root: pathlib.Path) -> int:
    ok = True

    def check(label: str, passed: bool, hint: str = "") -> None:
        nonlocal ok
        ok = ok and passed
        print(f"  [{'ok' if passed else '!!'}] {label}" + (f" — {hint}" if hint and not passed else ""))

    print(f"repo: {root}")
    check("git", shutil.which("git") is not None, "install Xcode command line tools")
    check("gh installed", shutil.which("gh") is not None, "brew install gh")
    if shutil.which("gh"):
        check("gh authenticated", runner.ok(["gh", "auth", "status"]), "gh auth login")
    check("claude installed", shutil.which("claude") is not None,
          "npm install -g @anthropic-ai/claude-code, then run `claude` once to sign in")
    if shutil.which("claude"):
        version = runner.query(["claude", "--version"], check=False).strip()
        check(f"claude version {version or '?'}", bool(version))
        check("claude supports --permission-mode auto", claude_supports_auto(runner),
              "update Claude Code; `warden run` falls back to acceptEdits")
    name = git_query(runner, root, "config", "user.name", check=False).strip()
    email = git_query(runner, root, "config", "user.email", check=False).strip()
    check(f"git identity {name} <{email}>", bool(name and email), "git config user.name / user.email")
    check("origin is the GitHub repo",
          "brenthumphries/wildlife-crossing" in git_query(runner, root, "remote", "get-url", "origin", check=False))
    check(f"{WEEK_PLAN} present", (root / WEEK_PLAN).is_file(), "the weekly-plan skill writes it")
    check(f"{CODE_TASK_SKILL} present", (root / CODE_TASK_SKILL).is_file())
    check("python ≥ 3.9", sys.version_info >= (3, 9), f"found {sys.version.split()[0]}")
    locks = find_locks(root)
    check("no lock debris" if not locks else f"{len(locks)} lock file(s) — `warden locks`", not locks)
    check("pbcopy for `warden cowork`", shutil.which("pbcopy") is not None, "prompts print either way")
    print("\nalias (add to ~/.zshrc):  alias warden='python3 " + str(root / "tools" / "warden.py") + "'")
    return 0 if ok else 1


# --------------------------------------------------------------------------
# menu and argument parsing
# --------------------------------------------------------------------------


MENU = [
    ("sync", "refresh GitHub state and repo facts (do this first)"),
    ("day", "today's dispatch — what to run, what to paste, what is yours"),
    ("next", "run the next ready code item in Claude Code"),
    ("status", "what the synced state says"),
    ("pr", "list open pull requests"),
    ("locks", "clear .git lock debris"),
    ("clean", "remove worktrees whose branches were merged"),
    ("doctor", "check this machine can run everything"),
]


def menu(runner: Runner, root: pathlib.Path) -> int:
    while True:
        print("\nwarden — Wildlife Crossing")
        for n, (name, blurb) in enumerate(MENU, 1):
            print(f"  {n}. {name:<8} {blurb}")
        print("  r. run <id>     c. cowork <id>     l. land <plan.json>     m. merge <n>     q. quit")
        try:
            choice = input("> ").strip()
        except EOFError:
            return 0
        if not choice or choice.lower() in ("q", "quit"):
            return 0
        parts = choice.split()
        head = parts[0].lower()
        argv: list[str]
        if head.isdigit() and 1 <= int(head) <= len(MENU):
            argv = [MENU[int(head) - 1][0]]
        elif head in ("r", "run"):
            argv = ["run", *parts[1:]]
        elif head in ("c", "cowork"):
            argv = ["cowork", *parts[1:]]
        elif head in ("l", "land"):
            argv = ["land", *parts[1:]]
        elif head in ("m", "merge"):
            argv = ["merge", *parts[1:]]
        else:
            argv = parts
        try:
            main(argv)
        except SystemExit:
            pass


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="warden", description=__doc__.splitlines()[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Run with no arguments for a menu. Details: docs/warden.md",
    )
    parser.add_argument("--repo", type=pathlib.Path, default=None,
                        help="repository (default: the one containing the cwd)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the commands a subcommand would run, and run none")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("doctor", help="check gh, claude, git identity and the plan files")
    p = sub.add_parser("sync", help="fetch, clear locks, refresh github-state and facts")
    p.add_argument("--no-fetch", action="store_true")
    p.add_argument("--curl", action="store_true", help="read GitHub unauthenticated (no gh)")
    p.add_argument("--tracked", action="store_true",
                   help=f"write {TRACKED_STATE} (the committed copy) instead of {LIVE_STATE}")
    sub.add_parser("status", help="summarise the synced state; reads files only")
    p = sub.add_parser("day", help="today's dispatch from docs/plan/week.json")
    p.add_argument("--max-code", type=int, default=DEFAULT_MAX_CODE,
                   help=f"code items to queue at once (default {DEFAULT_MAX_CODE})")
    p.add_argument("--no-write", action="store_true", help="print only")
    p.add_argument("--json", action="store_true", help="print the queue as JSON")
    p = sub.add_parser("run", help="build one item in Claude Code")
    p.add_argument("item")
    p.add_argument("--interactive", action="store_true", help="a normal Claude Code session you can answer")
    p.add_argument("--model", choices=("haiku", "sonnet", "opus"), help="override the plan's model")
    p.add_argument("--effort", choices=("low", "medium", "high"), help="pass --effort to claude")
    p.add_argument("--here", action="store_true", help="use this checkout instead of a worktree (needs a clean tree)")
    p.add_argument("--watch", action="store_true", help="watch the PR's checks when one is opened")
    p = sub.add_parser("next", help="run the first ready code item")
    p.add_argument("--interactive", action="store_true")
    p.add_argument("--model", choices=("haiku", "sonnet", "opus"))
    p.add_argument("--watch", action="store_true")
    p = sub.add_parser("cowork", help="print and copy the Cowork prompt for an item")
    p.add_argument("item")
    p.add_argument("--no-copy", action="store_true")
    p = sub.add_parser("land", help="branch, ship.py --execute, push, PR, checks, merge")
    p.add_argument("plan", type=pathlib.Path)
    p.add_argument("--no-merge", action="store_true", help="stop after the checks are green")
    p.add_argument("--no-watch", action="store_true", help="stop after opening the PR")
    p.add_argument("--draft", action="store_true")
    p.add_argument("--title", help="pull request title (default: from the plan)")
    p = sub.add_parser("pr", help="show open pull requests, or one")
    p.add_argument("ref", nargs="?")
    p = sub.add_parser("checks", help="watch a pull request's checks")
    p.add_argument("ref")
    p = sub.add_parser("merge", help="merge a pull request, delete its branch, sync")
    p.add_argument("ref")
    p = sub.add_parser("locks", help="remove stale .git lock files")
    p.add_argument("--force", action="store_true")
    sub.add_parser("clean", help="remove worktrees for merged branches")
    p = sub.add_parser("week", help="run the weekly plan locally (fallback for the routine)")
    p.add_argument("--model", default="sonnet", choices=("sonnet", "opus"))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    runner = Runner(dry_run=args.dry_run)
    try:
        root = repo_root(args.repo)
        if args.command is None:
            return menu(runner, root)
        if args.command == "doctor":
            return cmd_doctor(runner, root)
        if args.command == "sync":
            return cmd_sync(runner, root, fetch=not args.no_fetch, curl=args.curl, tracked=args.tracked)
        if args.command == "status":
            return cmd_status(runner, root)
        if args.command == "day":
            return cmd_day(runner, root, max_code=args.max_code, write=not args.no_write, as_json=args.json)
        if args.command == "run":
            return cmd_run(runner, root, args.item, interactive=args.interactive, model=args.model,
                           here=args.here, effort=args.effort, watch=args.watch)
        if args.command == "next":
            return cmd_next(runner, root, interactive=args.interactive, model=args.model, watch=args.watch)
        if args.command == "cowork":
            return cmd_cowork(runner, root, args.item, copy=not args.no_copy)
        if args.command == "land":
            return cmd_land(runner, root, args.plan, merge=not args.no_merge,
                            watch=not args.no_watch, title=args.title, draft=args.draft)
        if args.command == "pr":
            return cmd_pr(runner, root, args.ref)
        if args.command == "checks":
            return cmd_checks(runner, root, args.ref)
        if args.command == "merge":
            return cmd_merge(runner, root, args.ref)
        if args.command == "locks":
            return cmd_locks(runner, root, force=args.force)
        if args.command == "clean":
            return cmd_clean(runner, root)
        if args.command == "week":
            return cmd_week(runner, root, model=args.model)
        raise WardenError(f"unknown command {args.command!r}")
    except WardenError as exc:
        print(f"warden: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\ninterrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
