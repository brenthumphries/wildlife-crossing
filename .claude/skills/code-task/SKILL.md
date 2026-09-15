---
name: code-task
description: >-
  Execute one work item from docs/plan/week.json in Claude Code: branch,
  implement to the project's conventions, test, sign off, push, and open a
  pull request whose body is the review brief. Use when tools/warden.py run
  dispatches an item, or when asked to "build item C5" / "do item V3". Not
  for planning, reviews, or vault notes.
model: sonnet
---

# Code task

You are executing **one** item from this week's Wildlife Crossing plan. The
operator dispatched it with `tools/warden.py run`; you are in a worktree on
the item's branch, based on `origin/main`, and the item's JSON is in your
prompt. The result of this session is a **pull request** whose body lets a
human review it in five minutes, or an honest statement of why not.

## Before writing anything

1. Read the root `CLAUDE.md`, then `game/CLAUDE.md` (for `game/`) or the
   scoped `CLAUDE.md` of every directory you will touch. Conventions there
   are not optional: one class per file, `##` docstrings, signals over
   direct references, no magic numbers, a GUT test per system.
2. Read `docs/plan/facts.json`. It is the tree at the SHA you branched from.
   Cite it; do not recount.
3. Read every file in the item's `files` list and every `references` entry.
   If a reference is a build review, read only the item's own section.
4. Check the item's `files` against the forbidden list in
   `docs/plan/routing.md`. If any path is on it, **stop**: report that the
   item is mis-routed and open no pull request.

## Do the work

- Stay on the branch you were given. Never touch `main`. Never rebase.
- Keep the change to the item. If you discover a second problem, note it in
  the brief under *What this does not do*; do not fix it here.
- **Every new `.gd` file has a `.gd.uid` sibling** once Godot has imported
  it. Godot is not installed on the Mac, so you cannot generate one locally;
  CI's import step will. Do not hand-write a `.uid`. Do add an existing one
  to the commit when you move a script.
- **Tests.** A new system gets `game/tests/<system_name>_test.gd`; a changed
  system gets its test extended. Tests use explicit types (GUT loads them
  with warnings-as-errors; `var x := dict.get(...)` is a parse error there).
  If `godot` is on `PATH`, run the suite from `game/` before pushing:
  `godot --headless --import` then
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`,
  and compare the **Scripts** count with `facts.suite.stated.scripts` — a
  script that fails to load is dropped silently and the run still says
  "All tests passed". If `godot` is not on `PATH`, say so in the brief; CI
  is the test signal and the pull request will show it.
- Python tools get a test in `tools/tests/`; run
  `python3 -m unittest discover -s tools/tests -b` before pushing.
- Any figure the docs state and CI checks — `docs/testing-setup.md`'s suite
  size — is updated in the same commit that changes it, or the check goes
  red on arrival.

## Commit

Conventional Commits, one commit per logical change, and every commit is
**signed off** — `check_dco.py` fails a pull request whose commits lack a
`Signed-off-by` trailer matching the author's email:

```
git add <the paths you changed>
git commit -s -m "<type>(<scope>): <subject under 72 chars>" -m "<what and why, 2–4 sentences>" -m "Item <id>. Co-Authored-By: Claude <noreply@anthropic.com>"
```

`git status --porcelain` must be empty before you push. Do not commit
`docs/plan/facts.json`, `docs/plan/github-state.json` or anything under
`docs/plan/queue/` — they are gitignored and local.

## Push and open the pull request

```
git push -u origin <branch>
gh pr create --title "<type>(<scope>): <subject>" --body-file <brief>
```

The title is the first commit's subject, never the branch name. The body is
the brief below, written to a temp file. Do not enable auto-merge, do not
merge, do not request reviewers. Print the pull request URL as the last line
of your report.

## The brief (pull request body)

```
## Item <id> — <title>

**Acceptance criteria**
- [x] <criterion 1> — evidence: <test name / file / command output>
- [ ] <criterion 2> — NOT MET: <why>

**Test delta** — <scripts / tests / asserts before → after>, from a local
run or "CI will report; godot not on PATH".

**What I would want a human to look at** — a non-empty list. A change with
nothing to look at has not been looked at.

**What this does not do** — deferred pieces and anything discovered but out
of scope, with reasons.

**Facts cited** — `docs/plan/facts.json` at `<sha7>`.
```

## When you cannot finish

Stop at the first criterion you cannot meet. Commit what is sound, push,
open the pull request as a **draft** with the unmet criteria marked, and say
in your final message exactly what is missing and why. An honest partial is
useful; a green pull request that quietly narrowed the task is not. If the
question is one the product owner has to answer, say what the question is
and open no pull request.
