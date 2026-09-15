---
title: "Work routing — lane, model, mode"
date: 2026-09-14
status: active
---

# Work routing

Every item in `docs/plan/week.json` carries a **lane** (what kind of work),
a **model** (the cheapest one that can do it), a **mode** (how much
supervision), and, implied by the lane unless overridden, a **surface**
(where it runs). The weekly-plan skill assigns these; `tools/warden.py`
enforces them. This file is the rubric. Change the rubric here, not in the
skill, so the reasoning stays in one place and the plan stays auditable.

The principle behind all of it: **facts come from scripts, judgment comes
from models, and the model is the cheapest one whose judgment is sufficient.**
A fact a script can compute — a count, a file's presence, a line number, a
check's conclusion — is never a model's job. That is what `tools/facts.py`
and `tools/github_state.py` are for.

## Lane → surface

| Lane       | What it is                                                                 | Runs in                  |
|------------|----------------------------------------------------------------------------|--------------------------|
| `code`     | GDScript, scenes, data files, Python tools — anything with a test          | Claude Code (`warden run`) |
| `verify`   | Tests only, CI workflow edits, check scripts, smoke gates                  | Claude Code (`warden run`) |
| `docs`     | Vault notes, ADR drafts, runbooks, README, website copy                    | Cowork (`warden cowork`)   |
| `decision` | Needs the product owner's answer before anything can be built             | Brent                    |
| `mac`      | Needs the Mac: installs, signing, notarization, windowed QA, the release   | Brent                    |

An item may set `surface: code` or `surface: cowork` explicitly to override
the lane's default — a one-line doc correction with the exact text spelled out
is cheaper in Claude Code on Haiku than in a Cowork conversation, and the
planner may say so.

## Model

| Model    | Use it when                                                                                                        |
|----------|--------------------------------------------------------------------------------------------------------------------|
| `haiku`  | The item is mechanical and fully specified: the acceptance criteria name the exact file, the exact change, and a test or check that proves it. Renames, index lines, a stated line correction, a test that mirrors an existing one, a constant, a `.gitignore` rule. Size S. |
| `sonnet` | The item needs implementation within known conventions: a system or UI change with acceptance criteria, a new GUT test file, a runbook section, a tool with tests. Size S or M. The default. |
| `opus`   | The item is an architectural fork, touches more than three systems, needs an ADR, or the previous attempt failed on a design question. Size L, or any size flagged `architectural: true`. Rare; the plan must say why. |
| `human`  | `decision` and `mac` lanes, and anything only a person can do: a release, a signing step, a windowed QA walk. |

The weekly plan itself is written by Sonnet. Facts are pre-computed, so the
plan is routing and readiness judgment, which Sonnet does well; pass
`--model opus` to `warden week` for a large re-plan.

## Mode

| Mode         | Meaning                                                                                     | Claude Code flag            |
|--------------|---------------------------------------------------------------------------------------------|-----------------------------|
| `auto`       | Headless. Claude Code runs unattended with its own permission classifier; the run ends with a pull request or an honest partial. | `--permission-mode auto` (headless `-p`) |
| `supervised` | Interactive. A normal Claude Code session in the terminal that you can answer.              | `--permission-mode acceptEdits` |
| `human`      | Not automated.                                                                              | —                           |

Defaults: `haiku` and `sonnet` items are `auto`; `opus` items are
`supervised`. Any item that touches a forbidden path is `supervised` at most.
The operator can always downgrade to supervised with
`warden run <id> --interactive`.

## Forbidden paths — never automated

From `docs/pipeline-design.md` §7.2, unchanged: `LICENSE`, `LICENSE-ASSETS`,
`THIRD-PARTY-NOTICES.md`, `CONTRIBUTING.md`, `docs/adr/**` (existing ADRs;
drafting a *new* one is `docs` lane), `.github/workflows/**`,
`.github/rulesets/**`, `game/export_presets.cfg`, `tools/ship.py`,
`tools/check_dco.py`, and anything the roadmap assigns to Phase 5's
cultural-narrative gate. A pipeline that can edit its own guardrails has
none; a preset that loses `exclude_filter` changes what must be attributed.

An item whose `files` list includes one of these is never `mode: auto`. The
planner routes it `supervised` — a Claude Code session you watch, started
with `warden run <id> --interactive` — or `human`. `tools/warden.py`
refuses to validate a plan that says otherwise, and refuses to run such an
item headless whatever the plan says.

## Size

`S` — one file or one concern, under an hour of a model's work. `M` — a few
files, a test file, one session. `L` — split it; an L item in the plan is a
planning failure unless it is `human`.

## Priority and dependencies

`priority` is a small integer; the daily dispatch sorts by it and then by id.
`depends_on` lists item ids that must be **done** (a merged pull request on
that item's branch, or `status: done` in the plan) before this one is
eligible. The dispatch also refuses to queue two items whose `files` overlap
on the same day, so two branches never fight over one file. Two code items
run at a time (`warden day --max-code`), per `pipeline-design.md` §7.3.

## Ids

Stable across weeks. The series the build reviews already use: `B` blockers,
`C` core build work, `V` verification, `D` doc drift, `Q` decisions. A new
item takes the next free number in its series; a carried item keeps its id
and its history. Ids are branch segments (`feat/c5-…`), so they are short and
alphanumeric.
