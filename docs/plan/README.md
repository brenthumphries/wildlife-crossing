---
title: "docs/plan — the weekly plan and the daily queue"
date: 2026-09-14
status: active
---

# docs/plan

The machine-readable half of planning. The human half stays where it always
was, in `obsidian-vault/build-reviews/`; the two are written together by the
`weekly-plan` skill and describe the same week.

| File | Tracked | Written by | Read by |
|------|---------|------------|---------|
| `week.json` | yes | `weekly-plan` skill, Mondays | `tools/warden.py day` / `run` / `cowork`, the next weekly plan |
| `routing.md` | yes | people | the `weekly-plan` skill (the rubric it applies) |
| `facts.json` | no | `tools/facts.py` — deterministic, pinned to a SHA | every skill and prompt that makes a claim about the tree |
| `github-state.json` | no | `tools/github_state.py` via `warden sync` — the live copy | `facts.py`, `warden day`; the tracked `docs/github-state.json` is the committed snapshot |
| `queue/YYYY-MM-DD.json`, `.md` | no | `warden day` | you; `warden run` and `warden cowork` re-derive rather than read them |
| `queue/log.jsonl` | no | `warden run` / `cowork` / `land` / `merge` | the next weekly plan, for what was dispatched and what landed |

The untracked files are local state. They are cheap to regenerate and they
carry a timestamp, so nothing reads one without knowing how old it is. A
cloud session with the repository attached regenerates them itself; a session
without GitHub access reads the tracked snapshot and quotes its `read_at`.

## `week.json`

```json
{
  "schema": 1,
  "week_of": "2026-09-14",
  "written_at": "2026-09-14T14:00:00+00:00",
  "written_by": "weekly-plan skill (sonnet)",
  "measured_against": {"head_sha": "<40 hex>", "head_date": "…", "github_state_read_at": "…"},
  "build_case": "first",
  "readiness": {"verdict": "not-ready", "blockers_open": ["B4", "B6"], "summary": "one paragraph"},
  "note": "obsidian-vault/build-reviews/2026-09-14-next-build.md",
  "items": [
    {
      "id": "C5",
      "title": "Add the [display] section to project.godot",
      "lane": "code",
      "model": "haiku",
      "mode": "auto",
      "size": "S",
      "priority": 3,
      "blocker": false,
      "depends_on": [],
      "files": ["game/project.godot"],
      "acceptance": ["project.godot has a [display] section setting window/size/viewport_width and viewport_height", "…"],
      "context": "Why it matters, in two sentences, with the roadmap criterion it serves.",
      "references": ["docs/roadmap.md §Phase 1 exit criteria", "obsidian-vault/build-reviews/2026-09-08-next-build.md C5"],
      "status": "open"
    }
  ]
}
```

Field rules, enforced by `tools/warden.py` (`validate_plan`):

- `id` — short, alphanumeric, unique, stable across weeks (see `routing.md`).
- `lane` — one of `code`, `verify`, `docs`, `decision`, `mac`.
- `model` — `haiku`, `sonnet`, `opus`, or `human`. `mode` — `auto`,
  `supervised`, or `human`. Optional `surface` — `code` or `cowork` —
  overrides the lane's default. Optional `type` — a Conventional Commit type
  for the branch name (`feat` by default for code, `docs` for docs, `test`
  for verify, `chore` for the rest). Optional `effort` — passed to Claude
  Code. Optional `architectural: true` — forces `opus`/`supervised`.
- `depends_on` — ids in this plan. An item is eligible only when every
  dependency is **done**.
- `files` — the paths the item is expected to touch. Used for the
  file-disjointness rule and to detect forbidden paths.
- `acceptance` — a list; each entry is one checkable statement. The pull
  request brief repeats them with evidence.
- `status` — `open`, `done`, `blocked`, or `dropped` **as of Monday**. The
  daily dispatch derives the live status from GitHub and never edits this
  file: a merged pull request on `<type>/<id>-…` means done, an open one
  means in review.

## The branch an item lands on

`<type>/<id lowercase>-<slug of title>`, for example
`feat/c5-add-the-display-section-to-project-godot`. `warden run` creates it
in a worktree from `origin/main`; a Cowork session writes a commit plan with
the same `branch` and `warden land` creates it. The id in the branch name is
how the dispatch recognises the item's pull request, so keep it.

## Lifecycle

```
Monday      weekly-plan (cloud routine, Sonnet)  → week.json + note + PR
            you: warden merge <n>
Each day    warden sync → warden day             → queue/YYYY-MM-DD.md
            warden run <id>   (Claude Code, code lane)      → PR
            warden cowork <id>  (paste into Cowork, docs lane) → commit plan → warden land
            warden checks <n> / warden merge <n>
Session end /log in Cowork as before; warden land the log's commit plan
```

The plan is Monday's document. It is not edited during the week; what
happened is visible in GitHub (pull requests on item branches) and in
`queue/log.jsonl`, and the next weekly plan reads both.
