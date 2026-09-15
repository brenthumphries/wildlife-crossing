#!/usr/bin/env python3
"""Record what the repository actually contains, deterministically, pinned to a SHA.

Rationale (2026-09-14): ten consecutive build reviews re-derived the same
inventory by reading the tree with a model — which scripts exist, which have
tests, whether the data files parse, what the export presets say — and the
09-08 review's own audit found sixteen defects, most of them counts and line
numbers that were derived rather than read. Every one of those facts is
computable. Computing them costs no tokens, cannot hallucinate, and pins the
answer to the commit it describes.

So this script writes ``docs/plan/facts.json``: one file, one ``measured_against``
SHA, and every fact a weekly plan or a daily dispatch needs. Skills and prompts
read the file and cite it. They do not re-derive it. Anything a skill cannot
find here is either added here, with a test, or labelled Unverifiable in the
note — never guessed.

**What this file is not.** It is not GitHub-side state. Pull requests, check
runs, the applied ruleset and artifact expiry are read by
``tools/github_state.py`` from a machine with credentials; this script only
reports where that file is, how old it is, and the handful of figures the
dispatch needs from it. A cloud session with the repository attached can run
both; a session that cannot reach GitHub runs this one and quotes the other's
``read_at``.

It needs nothing but ``git`` and the Python standard library, and it works over
the Cowork mount, because it only reads.

Usage:
    tools/facts.py                     # write docs/plan/facts.json, print a summary
    tools/facts.py --print             # print the JSON to stdout, write nothing
    tools/facts.py --output PATH       # write somewhere else
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

try:  # tools/suite_figures.py owns the figure regex; reuse it, never copy it.
    from suite_figures import FIGURE_PATTERN, parse as parse_junit  # noqa: E402
except ImportError:  # pragma: no cover - only when run from an odd cwd
    FIGURE_PATTERN = re.compile(
        r"(\d[\d,]*)\s*scripts?\s*/\s*(\d[\d,]*)\s*tests?\s*/\s*(\d[\d,]*)\s*asserts?",
        re.IGNORECASE,
    )
    parse_junit = None

SCHEMA = 1
DEFAULT_OUTPUT = pathlib.Path("docs/plan/facts.json")
LIVE_GITHUB_STATE = pathlib.Path("docs/plan/github-state.json")
TRACKED_GITHUB_STATE = pathlib.Path("docs/github-state.json")
WEEK_PLAN = pathlib.Path("docs/plan/week.json")

# A script with fewer meaningful lines than this is reported as a stub. The
# constants files sit at 18 lines and are real, so the bar is low on purpose:
# it catches `extends Node` and nothing else, not small files.
STUB_LINE_THRESHOLD = 5

# Scripts that legitimately have no `<name>_test.gd`: scene glue and constant
# tables. Listed here so the "scripts without a named test" figure means
# something rather than restating the same six names every week. Keep in sync
# with docs/test-plan.md when that document changes its mind.
TEST_EXEMPT_SCRIPTS = frozenset({
    "main", "title_screen", "env_config", "debug", "event_bus",
    "economy_constants", "habitat_constants", "simulation_constants",
})


class FactsError(Exception):
    """The repository is not in a state this script can describe."""


# --------------------------------------------------------------------------
# git
# --------------------------------------------------------------------------


def run_git(root: pathlib.Path, *args: str, check: bool = True) -> str:
    proc = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, text=True,
    )
    if check and proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise FactsError(f"git {' '.join(args)} failed ({proc.returncode}): {detail}")
    return proc.stdout


def repo_root(start: pathlib.Path | None = None) -> pathlib.Path:
    where = start or pathlib.Path.cwd()
    proc = subprocess.run(
        ["git", "-C", str(where), "rev-parse", "--show-toplevel"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise FactsError(f"{where} is not inside a git repository")
    return pathlib.Path(proc.stdout.strip())


def git_facts(root: pathlib.Path) -> dict:
    head = run_git(root, "log", "-1", "--format=%H%x00%cI%x00%s").strip()
    sha, date, subject = head.split("\x00", 2)
    branch = run_git(root, "rev-parse", "--abbrev-ref", "HEAD").strip()

    ahead_behind: dict = {"known": False}
    if run_git(root, "rev-parse", "--verify", "-q", "origin/main", check=False).strip():
        counts = run_git(
            root, "rev-list", "--left-right", "--count", "HEAD...origin/main",
        ).split()
        ahead_behind = {"known": True, "ahead": int(counts[0]), "behind": int(counts[1])}

    dirty, untracked = [], []
    for line in run_git(root, "status", "--porcelain").splitlines():
        if not line.strip():
            continue
        path = line[3:]
        if line.startswith("??"):
            untracked.append(path)
        else:
            dirty.append(path)

    commits = []
    for line in run_git(root, "log", "-15", "--format=%h%x00%cI%x00%s").splitlines():
        h, d, s = line.split("\x00", 2)
        commits.append({"sha": h, "date": d, "subject": s})

    tags = [t for t in run_git(root, "tag", "-l").split() if t]

    return {
        "measured_against": {
            "head_sha": sha,
            "head_date": date,
            "head_subject": subject,
            "branch": branch,
            "vs_origin_main": ahead_behind,
        },
        "working_tree": {
            "clean": not dirty and not untracked,
            "modified": dirty,
            "untracked": untracked,
        },
        "recent_commits": commits,
        "tags": tags,
    }


# --------------------------------------------------------------------------
# game/
# --------------------------------------------------------------------------


def meaningful_lines(path: pathlib.Path) -> int:
    count = 0
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            count += 1
    return count


def godot_config(path: pathlib.Path) -> dict:
    """Parse the few project.godot keys the plan needs. Not a full INI parser."""
    out: dict = {"autoloads": {}, "main_scene": None, "version": None, "name": None}
    if not path.is_file():
        return out
    section = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip().strip('"')
        if section == "autoload":
            out["autoloads"][key] = value
        elif section == "application":
            if key == "run/main_scene":
                out["main_scene"] = value
            elif key == "config/version":
                out["version"] = value
            elif key == "config/name":
                out["name"] = value
    return out


def export_presets(path: pathlib.Path) -> list[dict]:
    if not path.is_file():
        return []
    presets: list[dict] = []
    current: dict | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if re.fullmatch(r"\[preset\.\d+\]", line):
            current = {"name": None, "export_path": None, "exclude_filter": None}
            presets.append(current)
        elif re.fullmatch(r"\[preset\.\d+\.options\]", line):
            current = None
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            key, value = key.strip(), value.strip().strip('"')
            if key in current:
                current[key] = value
    for preset in presets:
        preset["exclude_filter_ok"] = preset["exclude_filter"] == "addons/gut/*,tests/*"
    return presets


def game_facts(root: pathlib.Path) -> dict:
    game = root / "game"
    scripts_dir = game / "scripts"
    tests_dir = game / "tests"

    scripts: dict[str, list[str]] = {}
    stubs: list[str] = []
    all_script_names: list[str] = []
    uid_orphans: list[str] = []
    if scripts_dir.is_dir():
        for gd in sorted(scripts_dir.rglob("*.gd")):
            rel = gd.relative_to(scripts_dir)
            group = rel.parts[0] if len(rel.parts) > 1 else "root"
            scripts.setdefault(group, []).append(gd.stem)
            all_script_names.append(gd.stem)
            if meaningful_lines(gd) < STUB_LINE_THRESHOLD:
                stubs.append(str(gd.relative_to(root)))
            if not gd.with_suffix(".gd.uid").is_file():
                uid_orphans.append(str(gd.relative_to(root)))

    tests: list[str] = []
    if tests_dir.is_dir():
        for gd in sorted(tests_dir.rglob("*_test.gd")):
            tests.append(gd.stem)
            if not gd.with_suffix(".gd.uid").is_file():
                uid_orphans.append(str(gd.relative_to(root)))
    tested = {t[: -len("_test")] for t in tests}
    untested = sorted(
        name for name in all_script_names
        if name not in tested and name not in TEST_EXEMPT_SCRIPTS
    )
    untested_exempt = sorted(
        name for name in all_script_names
        if name not in tested and name in TEST_EXEMPT_SCRIPTS
    )

    data: dict[str, dict] = {}
    data_dir = game / "data"
    if data_dir.is_dir():
        for js in sorted(data_dir.rglob("*.json")):
            rel = str(js.relative_to(data_dir))
            try:
                json.loads(js.read_text(encoding="utf-8"))
                data[rel] = {"valid": True, "bytes": js.stat().st_size}
            except (json.JSONDecodeError, UnicodeDecodeError) as exc:
                data[rel] = {"valid": False, "error": str(exc)[:120]}

    scenes = []
    scenes_dir = game / "scenes"
    if scenes_dir.is_dir():
        scenes = sorted(str(p.relative_to(scenes_dir)) for p in scenes_dir.rglob("*.tscn"))

    gutconfig = None
    gut_path = game / ".gutconfig.json"
    if gut_path.is_file():
        try:
            gutconfig = json.loads(gut_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            gutconfig = {"error": "not valid JSON"}

    return {
        "project": godot_config(game / "project.godot"),
        "scripts": scripts,
        "script_count": len(all_script_names),
        "stub_scripts": stubs,
        "uid_orphans": uid_orphans,
        "tests": tests,
        "test_count": len(tests),
        "scripts_without_named_test": untested,
        "scripts_exempt_from_named_test": untested_exempt,
        "data_files": data,
        "data_files_invalid": sorted(k for k, v in data.items() if not v["valid"]),
        "scenes": scenes,
        "export_presets": export_presets(game / "export_presets.cfg"),
        "gutconfig": gutconfig,
        "gut_vendored": (game / "addons" / "gut" / "plugin.cfg").is_file(),
    }


# --------------------------------------------------------------------------
# suite figures, CI, docs, vault
# --------------------------------------------------------------------------


def suite_facts(root: pathlib.Path) -> dict:
    stated = None
    setup = root / "docs" / "testing-setup.md"
    if setup.is_file():
        for number, line in enumerate(setup.read_text(encoding="utf-8").splitlines(), 1):
            match = FIGURE_PATTERN.search(line)
            if match:
                scripts, tests, asserts = (int(g.replace(",", "")) for g in match.groups())
                stated = {
                    "scripts": scripts, "tests": tests, "asserts": asserts,
                    "source": f"docs/testing-setup.md:{number}",
                }
                break

    measured = None
    xml = root / "game" / "gut_results.xml"
    if xml.is_file() and parse_junit is not None:
        try:
            figures = parse_junit(xml)
            measured = {
                "scripts": figures.scripts, "tests": figures.tests,
                "asserts": figures.asserts, "failures": figures.failures,
                "source": "game/gut_results.xml",
                "file_mtime": _dt.datetime.fromtimestamp(
                    xml.stat().st_mtime, _dt.timezone.utc,
                ).replace(microsecond=0).isoformat(),
            }
        except Exception as exc:  # noqa: BLE001 - report, never fail the inventory
            measured = {"error": str(exc)[:160], "source": "game/gut_results.xml"}

    return {
        "stated": stated,
        "measured_locally": measured,
        "note": (
            "stated is what docs/testing-setup.md claims and CI's GUT job checks "
            "against every run (tools/suite_figures.py --check); measured_locally "
            "exists only if the suite was run on this machine."
        ),
    }


def ci_facts(root: pathlib.Path) -> dict:
    workflow = root / ".github" / "workflows" / "ci.yml"
    job_names: list[str] = []
    godot_version = None
    if workflow.is_file():
        for line in workflow.read_text(encoding="utf-8").splitlines():
            match = re.match(r"^\s{4}name:\s*(.+?)\s*$", line)
            if match:
                job_names.append(match.group(1))
            match = re.match(r"^\s*GODOT_VERSION:\s*(\S+)", line)
            if match:
                godot_version = match.group(1)

    required: list[str] = []
    ruleset = root / ".github" / "rulesets" / "protect_main.json"
    if ruleset.is_file():
        try:
            doc = json.loads(ruleset.read_text(encoding="utf-8"))
            for rule in doc.get("rules", []):
                if rule.get("type") == "required_status_checks":
                    for check in rule["parameters"].get("required_status_checks", []):
                        required.append(check["context"])
        except (json.JSONDecodeError, KeyError):
            required = []

    return {
        "workflow": ".github/workflows/ci.yml" if workflow.is_file() else None,
        "job_names": job_names,
        "godot_version": godot_version,
        "required_contexts": required,
        "required_contexts_match_jobs": bool(required) and set(required) <= set(job_names),
        "deploy_website_workflow": (root / ".github" / "workflows" / "deploy-website.yml").is_file(),
    }


def docs_facts(root: pathlib.Path) -> dict:
    adrs = sorted(p.name for p in (root / "docs" / "adr").glob("[0-9][0-9][0-9][0-9]-*.md"))
    release_notes = sorted(p.name for p in (root / "docs" / "release-notes").glob("v*.md"))
    roadmap = root / "docs" / "roadmap.md"
    phases: list[str] = []
    if roadmap.is_file():
        for line in roadmap.read_text(encoding="utf-8").splitlines():
            match = re.match(r"^## (Phase \d+ — .+?)\s*$", line)
            if match:
                phases.append(match.group(1))
    builds = root / "builds"
    build_entries = []
    if builds.is_dir():
        build_entries = sorted(p.name for p in builds.iterdir() if not p.name.startswith("."))
    return {
        "adr_count": len(adrs),
        "latest_adr": adrs[-1] if adrs else None,
        "release_notes": release_notes,
        "roadmap_phases": phases,
        "builds_dir_entries": build_entries,
        "signing_runbook": (root / "docs" / "signing-runbook.md").is_file(),
    }


def vault_facts(root: pathlib.Path) -> dict:
    logs = sorted(p.stem for p in (root / "obsidian-vault" / "daily-logs").glob("????-??-??.md"))
    reviews = sorted(
        p.name for p in (root / "obsidian-vault" / "build-reviews").glob("????-??-??-*.md")
    )
    return {
        "daily_log_count": len(logs),
        "latest_daily_log": logs[-1] if logs else None,
        "latest_build_review": reviews[-1] if reviews else None,
        "build_review_count": len(reviews),
    }


def tools_facts(root: pathlib.Path) -> dict:
    tools = root / "tools"
    return {
        "scripts": sorted(p.name for p in tools.glob("*.py")),
        "tests": sorted(p.name for p in (tools / "tests").glob("test_*.py")),
        "godot_binary_vendored": any((tools / "godot").glob("*")) if (tools / "godot").is_dir() else False,
    }


# --------------------------------------------------------------------------
# the two files this one reads rather than derives
# --------------------------------------------------------------------------


def load_json(path: pathlib.Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def parse_iso(text: str | None) -> _dt.datetime | None:
    if not text:
        return None
    try:
        return _dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None


def github_state_facts(root: pathlib.Path, now: _dt.datetime) -> dict:
    """Pick the freshest github-state file and summarise it. Never fetch."""
    candidates = []
    for rel in (LIVE_GITHUB_STATE, TRACKED_GITHUB_STATE):
        doc = load_json(root / rel)
        read_at = parse_iso(doc.get("read_at")) if doc else None
        if doc and read_at:
            candidates.append((read_at, str(rel), doc))
    if not candidates:
        return {"source": None, "read_at": None, "note": "no github-state file found"}
    read_at, source, doc = max(candidates, key=lambda c: c[0])
    reads = doc.get("reads", {})

    def value(key: str):
        entry = reads.get(key)
        return entry.get("value") if isinstance(entry, dict) else None

    age = (now - read_at).total_seconds() / 3600
    open_issues = value("open_issues") or {}
    open_pulls = value("open_pulls") or {}
    return {
        "source": source,
        "read_at": read_at.replace(microsecond=0).isoformat(),
        "age_hours": round(age, 1),
        "open_issues": open_issues.get("total_count"),
        "open_pulls": open_pulls.get("total_count"),
        "open_pull_requests": value("open_pull_requests"),
        "recent_merged_pulls": value("recent_merged_pulls"),
        "latest_main_run": value("latest_main_run"),
        "ruleset_in_sync": (doc.get("ruleset_drift") or {}).get("in_sync"),
        "visibility": (value("repository") or {}).get("visibility"),
        "releases": value("releases"),
    }


def plan_facts(root: pathlib.Path) -> dict | None:
    doc = load_json(root / WEEK_PLAN)
    if not doc:
        return None
    items = doc.get("items", [])
    return {
        "path": str(WEEK_PLAN),
        "week_of": doc.get("week_of"),
        "measured_against": (doc.get("measured_against") or {}).get("head_sha"),
        "item_count": len(items),
        "item_ids": [item.get("id") for item in items],
    }


# --------------------------------------------------------------------------
# assembly
# --------------------------------------------------------------------------


def collect(root: pathlib.Path, now: _dt.datetime | None = None) -> dict:
    now = now or _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0)
    facts: dict = {
        "schema": SCHEMA,
        "_comment": (
            "Written by tools/facts.py. Every figure here was read from the tree "
            "at measured_against.head_sha, not derived by a model. Cite this file; "
            "do not recount. GitHub-side facts come from github_state.source and "
            "are only as fresh as github_state.read_at."
        ),
        "written_at": now.isoformat(),
    }
    facts.update(git_facts(root))
    facts["game"] = game_facts(root)
    facts["suite"] = suite_facts(root)
    facts["ci"] = ci_facts(root)
    facts["docs"] = docs_facts(root)
    facts["vault"] = vault_facts(root)
    facts["tools"] = tools_facts(root)
    facts["github_state"] = github_state_facts(root, now)
    facts["plan"] = plan_facts(root)
    facts["build_case"] = build_case(facts)
    return facts


def build_case(facts: dict) -> dict:
    """The harness definition: a working build exists only if a release or a
    launched export can be pointed to. Tags and release notes are the proxies
    a script can see; the launch itself is a Mac step and stays Unverifiable."""
    tags = facts.get("tags", [])
    notes = facts["docs"].get("release_notes", [])
    releases = facts["github_state"].get("releases") or []
    exists = bool(tags) or bool(notes) or bool(releases)
    return {
        "case": "next" if exists else "first",
        "evidence": {
            "git_tags": tags,
            "release_notes": notes,
            "github_releases": [r.get("tag_name") for r in releases if isinstance(r, dict)],
        },
        "note": "'first' means no tag, no release note and no GitHub release exist; "
                "whether an export launches is a Mac step and is not measured here.",
    }


def summary_lines(facts: dict) -> list[str]:
    m = facts["measured_against"]
    g = facts["game"]
    s = facts["suite"]["stated"] or {}
    gh = facts["github_state"]
    lines = [
        f"head       {m['head_sha'][:7]}  {m['head_date']}  {m['head_subject']}",
        f"tree       {'clean' if facts['working_tree']['clean'] else str(len(facts['working_tree']['modified'])) + ' modified, ' + str(len(facts['working_tree']['untracked'])) + ' untracked'}",
        f"game       {g['script_count']} scripts / {g['test_count']} test files; "
        f"{len(g['scripts_without_named_test'])} scripts without a named test; "
        f"{len(g['data_files_invalid'])} invalid data files; "
        f"{len(g['stub_scripts'])} stubs",
        f"suite      stated {s.get('scripts', '?')} / {s.get('tests', '?')} / {s.get('asserts', '?')} ({s.get('source', 'not found')})",
        f"ci         {len(facts['ci']['job_names'])} jobs, required contexts "
        f"{'match' if facts['ci']['required_contexts_match_jobs'] else 'DO NOT MATCH'}",
        f"build case {facts['build_case']['case']} (tags: {len(facts['tags'])}, release notes: {len(facts['docs']['release_notes'])})",
        f"github     {gh.get('source') or 'no state file'}"
        + (f", read {gh['age_hours']}h ago, {gh.get('open_pulls')} open PRs" if gh.get('read_at') else ""),
    ]
    if facts.get("plan"):
        lines.append(f"plan       {facts['plan']['path']} week of {facts['plan']['week_of']}, {facts['plan']['item_count']} items")
    else:
        lines.append("plan       none (docs/plan/week.json missing)")
    return lines


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", type=pathlib.Path, default=None,
                        help="repo to describe (default: the one containing the cwd)")
    parser.add_argument("--output", type=pathlib.Path, default=None,
                        help=f"where to write (default: {DEFAULT_OUTPUT})")
    parser.add_argument("--print", action="store_true", dest="print_only",
                        help="print the JSON and write nothing")
    args = parser.parse_args(argv)

    try:
        root = repo_root(args.repo)
        facts = collect(root)
    except FactsError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    text = json.dumps(facts, indent=2, sort_keys=False) + "\n"
    if args.print_only:
        print(text)
        return 0

    out = args.output or (root / DEFAULT_OUTPUT)
    if not out.is_absolute():
        out = root / out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    for line in summary_lines(facts):
        print(line)
    print(f"wrote {out.relative_to(root) if out.is_relative_to(root) else out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
