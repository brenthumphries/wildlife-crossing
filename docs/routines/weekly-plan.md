---
title: "Routine — weekly plan (Monday, cloud, Sonnet)"
date: 2026-09-14
tags: [automation, process]
status: active
---

# The weekly-plan routine

A cloud routine — a scheduled Claude Code session at
[claude.ai/code/routines](https://claude.ai/code/routines) — with **this
repository attached**. That attachment is the whole fix for the stale-GitHub
problem: a routine with a repository clones it fresh, reads `api.github.com`
through the GitHub proxy with real credentials (`gh` works), and can push a
`claude/` branch and open a pull request. The earlier scheduled tasks had no
repository attached, so they got `403` from the API and had to guess.

## Create it (once)

1. Open [claude.ai/code/routines](https://claude.ai/code/routines) → **New
   routine**. If GitHub is not yet connected to your Claude account, the
   form prompts you; the repository is public, so the Claude GitHub App does
   not need to be installed on it for cloning and pushing.
2. **Name:** `Wildlife Crossing — weekly plan`.
3. **Model:** Sonnet.
4. **Repository:** `brenthumphries/wildlife-crossing`.
5. **Environment:** Default (Trusted network) is enough; the routine needs
   only GitHub and the Anthropic API.
6. **Trigger:** Schedule → Weekly → Monday, 06:00 America/Chicago. (The
   form takes local time. Runs may start a few minutes late.)
7. **Connectors:** remove all of them. The routine needs none, and every
   connector it keeps is a write it could make without asking.
8. **Prompt:** the block below, verbatim.
9. **Create**, then **Run now** once to see the first pull request arrive.

Or, from a terminal in the repository, `claude` then `/schedule` and describe
the same thing; it checks GitHub access before saving.

## The prompt

```
Run the weekly plan for Wildlife Crossing.

Read .claude/skills/weekly-plan/SKILL.md and follow it exactly. In short:
run python3 tools/facts.py and python3 tools/github_state.py --output
docs/plan/github-state.json, read the previous docs/plan/week.json (or the
newest note in obsidian-vault/build-reviews/ if there is none), the daily
logs since it, and the current phase's exit criteria in docs/roadmap.md.
Then write docs/plan/week.json, a dated note in obsidian-vault/build-reviews/
under 150 lines, and the index line in that folder's README.md.

Verify with python3 tools/warden.py day --no-write before committing.

Land it as a pull request, not a merge: git config user.name "Brent
Humphries" and user.email "brent.humphries@gmail.com" (ADR 0019), branch
claude/plan-<YYYY-MM-DD>, one signed-off commit "docs(plan): week of
<YYYY-MM-DD>" with a Co-Authored-By: Claude trailer, push, gh pr create with
that title and the note's §1 and §3 as the body. Do not merge. Do not enable
auto-merge.

Report in three sentences: the build case and verdict, the item counts by
lane, and the pull request URL. If facts.py or github_state.py fails, say
so and stop rather than writing a plan from memory.
```

## What to expect on Monday

A pull request titled `docs(plan): week of YYYY-MM-DD` with three files: the
plan, the note, the index line. `tools/warden.py sync` shows it; read the
note's §1 (verdict) and *Yours this week*; `tools/warden.py merge <n>`. The
five required checks run on it like any other pull request, so the merge
takes about four minutes.

## If it did not fire

Scheduled workflows and routines both go quiet after long inactivity, and a
routine can hit the daily run cap. `tools/warden.py week` runs the same
skill locally with Sonnet and writes a commit plan for `warden land`.

## Retired the same day

- The daily *project-state dashboard* routine (12:30 UTC, Opus). Its job —
  a page that could not read GitHub, restamped daily — is replaced by
  `warden status` and `warden day`, which read GitHub through `gh` and cost
  no tokens. Disabled, not deleted, so its history stays readable.
- The `weekly-build-review` skill, superseded by `weekly-plan`; a stub
  remains that redirects.
