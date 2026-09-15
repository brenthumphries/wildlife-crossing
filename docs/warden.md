---
title: "Warden — the weekly plan, the daily queue, and one command per GitHub step"
date: 2026-09-14
tags: [automation, process, tooling]
status: active
---

# Warden

`tools/warden.py` is the operator's tool for this repository. It runs on the
Mac — the machine with `gh`, the SSH key and Claude Code — and it does the
things that used to be pasted one line at a time. Skills and prompts read
what it writes and never call GitHub themselves; that split is what stops
the scheduled processes from stalling on GitHub reads they cannot make.

```
alias warden='python3 ~/wildlife-crossing/tools/warden.py'
```

Run `warden` bare for a menu, `warden doctor` to check the machine, and
`warden <command> --help` for flags. `--dry-run` prints what a command would
run and runs none of it.

## The week

| When | You do | What happens |
|------|--------|--------------|
| **Monday, unattended** | nothing | The **weekly-plan** routine (cloud, Sonnet, repository attached — see `docs/routines/weekly-plan.md`) refreshes the facts, writes `docs/plan/week.json` and a short note in `obsidian-vault/build-reviews/`, and opens a pull request. |
| **Monday, five minutes** | `warden sync` · read the note's §1 and *Yours this week* · `warden merge <n>` | The plan is on `main`. |
| **Each working day** | `warden sync` · `warden day` | Today's queue: which items go to Claude Code, which to Cowork, which are yours, what is in review, what is waiting and why. Written to `docs/plan/queue/YYYY-MM-DD.md`. |
| | `warden run C5` | Item C5 builds in Claude Code, headless, in its own worktree, on the model and permission mode the plan assigned, and ends with a pull request. `warden next` runs the first ready one. |
| | `warden cowork C8` | The prompt for a docs-lane item, copied to the clipboard. Paste it into a new Cowork session with the repository folder connected. Cowork writes the files and a commit plan. |
| | `warden land commit-plan-….json` | Branch, `ship.py --execute`, push, pull request with a real title, watch the five checks, merge, delete the branch, sync. The block that used to end every daily log. |
| | `warden checks 17` · `warden merge 17` | For a pull request Claude Code opened. |
| **Session end** | `/log` in Cowork, then `warden land` its commit plan | As before. |

Nothing in the table needs the Mac awake overnight, and nothing in it
needs a model to read GitHub.

## Commands

**`sync`** — `git fetch --prune`; remove `.git` lock debris; refresh
`docs/plan/github-state.json` (twelve REST reads through `gh`, or `--curl`
without it); refresh `docs/plan/facts.json`. Run it first, most days.
`--tracked` writes the committed `docs/github-state.json` instead, for a
commit plan to claim.

**`status`** — what the synced files say: head, tree, build case, latest run
on `main`, ruleset drift, open pull requests, artifact expiry, plan counts.
Reads files only.

**`day`** — the dispatch. Deterministic. Each item's status is derived from
GitHub: a merged pull request on the item's branch (`feat/c5-…`) is *done*,
an open one is *in review*, unmet dependencies are *blocked*. Then, in
priority order: `code`/`verify`-lane items go to the Claude Code bucket
(two at a time, `--max-code`), `docs`-lane items to Cowork, `decision` and
`mac` to you; anything sharing a file with an item in flight waits.
`week.json` is never edited.

**`run <id>`** — creates `../wildlife-crossing-work/<branch>` as a worktree
from `origin/main` (or reuses it), writes the facts there, and runs
`claude -p` with the item's prompt, `--model` from the plan and
`--permission-mode auto` (`acceptEdits` if this Claude Code lacks `auto`).
The prompt tells Claude to follow `.claude/skills/code-task/SKILL.md`. When
it returns, warden reports commits, whether the branch was pushed, and the
pull request. `--interactive` runs a normal session you can answer;
`--model` overrides; `--here` uses your checkout (must be clean); `--watch`
watches the checks afterwards. Refuses items that are done, in review,
blocked, or yours.

**`cowork <id>`** — prints the prompt for a non-code item and copies it with
`pbcopy`. The prompt carries the acceptance criteria, the files, the rule
against git writes over the mount, and the instruction to end with a commit
plan named for the item.

**`land <plan.json>`** — the seven commands, in order, stopping at the first
refusal: checks the tree is dirty and the plan's branch is not `main`; clears
locks; `git pull --ff-only` on `main` and `checkout -b`; `ship.py --execute`
(every refusal ship.py has still applies); `push -u`; `gh pr create` titled
from the plan (`title` field, else the first commit's subject — never the
branch name); `gh pr checks --watch`, retrying while the run registers;
`gh pr merge --merge --delete-branch`; `sync`. `--no-merge` stops after green
checks, `--no-watch` after the pull request, `--draft` opens a draft.

**`checks <n>`**, **`merge <n>`**, **`pr [n]`** — thin wrappers with the race
handled and the sync done afterwards.

**`locks`** — removes `index.lock` / `HEAD.lock` / `refs/heads/*.lock` older
than two minutes (`--force` for younger). This is the fix for the recurring
lock `docs/automation.md` explains: the mount cannot unlink, the Mac can.

**`clean`** — removes worktrees whose branch is gone from origin.

**`week`** — the weekly plan run locally (`claude -p` with the weekly-plan
skill, Sonnet by default). The routine is the normal home for this; use
`week` when it did not fire or you want the plan now, then `land` the commit
plan it writes.

**`doctor`** — `gh` authenticated, `claude` present and its version, whether
it lists `--permission-mode auto`, git identity, origin, the plan files,
lock debris.

## Where things are

| Path | What |
|------|------|
| `docs/plan/week.json` | this week's routed plan (tracked) |
| `docs/plan/routing.md` | the lane / model / mode rubric |
| `docs/plan/README.md` | the plan schema and lifecycle |
| `docs/plan/facts.json` | the tree, pinned to a SHA (local) |
| `docs/plan/github-state.json` | GitHub, pinned to a `read_at` (local) |
| `docs/plan/queue/` | daily dispatches and `log.jsonl` (local) |
| `.claude/skills/weekly-plan/` | the Monday skill |
| `.claude/skills/code-task/` | the contract every `warden run` follows |
| `docs/routines/weekly-plan.md` | the routine's prompt and setup |
| `../wildlife-crossing-work/` | worktrees `run` creates (`WARDEN_WORKTREES` to move them) |

## What it will not do

- Merge without you. `land` merges only after the five required checks are
  green, and only because you ran `land`; `run` never merges.
- Write a plan, a commit grouping, or a task. Those are the weekly-plan
  skill's, the working session's, and yours.
- Touch `main` directly. Ruleset 22403399 would refuse it anyway.
- Run over the Cowork mount for anything that takes a git lock. `sync`,
  `status`, `day` and `cowork` are safe there; `run`, `land`, `merge`,
  `locks` and `clean` are Mac commands.

## Related

- [`automation.md`](automation.md) — every recurring process and what it can see
- [`push-runbook.md`](push-runbook.md) — the manual steps `land` automates; still the specification
- [`pipeline-design.md`](pipeline-design.md) — the Actions-based design this supersedes in part (§9.2 and the daily dashboard are retired; §7.2's forbidden paths and §7.3's two-at-a-time cap are kept)
- [`plan/README.md`](plan/README.md), [`plan/routing.md`](plan/routing.md)
