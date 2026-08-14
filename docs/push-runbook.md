---
title: "Push Runbook — Committing and Shipping a Day's Changes"
date: 2026-07-30
status: active
---

## Purpose

How to take a working tree full of uncommitted changes (typically accumulated
over one or more daily-log sessions) and get it committed, pushed, built by
CI, and verified — end to end. This supersedes
[docs/b1-commit-runbook.md](.), which covered the same ground as a one-off for
a single commit (B1, 2026-07-27) and has been deleted now that its purpose is
generalized here.

Run every command in this file from the repo root, **on Brent's Mac**. The
Cowork sandbox has no SSH credentials for `origin`
([git@github.com:brenthumphries/wildlife-crossing.git]), so `git push` fails
there with a host-key/auth error — Claude can stage and even commit inside the
sandbox (it writes the real `.git`), but the push step must run in a real
terminal.

> **Run one command per line**, not a pasted multi-line block, unless a block
> is explicitly fenced as a single unit (e.g. the Python heredocs below). zsh
> can mash multiple pasted lines into one invocation and fail confusingly.

---

## The short version (Steps 0–1 automated)

`tools/ship.py` does the mechanical half of Steps 0 and 1: clears a stale
`.git/index.lock`, refuses a working tree that is not safe to commit, stages
each group, and commits it with a DCO sign-off. It stops before the push.

It executes a commit plan; it does not write one. Ask Claude for a
`commit-plan.json` covering the unpushed work — that grouping is judgment, and
the 2026-08-09 session is the case in point: `tools/smoke_boot.sh` belonged
with the game commit rather than the CI commit, because it asserts against the
boot scene that the same commit moves.

```bash
cd ~/wildlife-crossing
```

```bash
tools/ship.py commit-plan.json
```

Read the dry run. It prints each commit and every file it will stage, and
fails if the plan does not account for every changed path.

```bash
tools/ship.py commit-plan.json --execute
```

```bash
git push origin main
```

```bash
tools/ship.py --verify
```

Everything before the push is one `git reset` away from undone, and `ship.py`
prints the exact reset command if it fails partway. If any of it misbehaves,
the manual steps below are the fallback and remain the specification — the
script was written from them, so **if the two ever disagree, this document is
right and the script has a bug**.

Step 4 is automated too, by `tools/fetch_build.py` — see that step. Steps 3
and 5 are still yours: watching CI needs `gh` credentials the sandbox does not
have, and the windowed launch is the one check nothing can stand in for.

---

## Step 0 — Clear the stale lock, confirm the starting point

`harness/weekly-build-review` (and, occasionally, an interrupted editor
session) leaves `.git/index.lock` behind. This has recurred across the
2026-07-19, 07-28, and 07-30 sessions — check for it every time before
staging anything:

```bash
cd ~/wildlife-crossing
```

```bash
rm -f .git/index.lock
```

```bash
git status --short
```

```bash
git log --oneline -3
```

Read the output before continuing — it tells you what's actually changed and
whether `HEAD` is where you expect.

---

## Step 1 — Group the changes into reviewable commits

Don't `git add -A` and make one commit. Group by theme, matching Conventional
Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:` — see root `CLAUDE.md`).
The fastest way to figure out the grouping: read the daily log(s) covering the
unpushed work — each log's **What got done** section names the files it
touched and why, which is exactly the commit-message material you need.

A typical split looks like:

- **Infra/CI/export changes** together (`.github/workflows/ci.yml`,
  `.gitignore`, `game/export_presets.cfg`, `tools/*.py`, `tools/*.sh`,
  relevant ADRs).
- **Game-logic changes** together (`game/scripts/**`, `game/tests/**`).
- **Daily logs and build-review notes**, either folded into the commit they
  document or as their own `docs:` commit — either is fine, but don't scatter
  a single day's log across multiple commits.

For each group:

```bash
git add <file1> <file2> ...
git commit -s -m "<type>(<scope>): <summary>

<body — what changed and why, 2-4 sentences. Include the suite count
(e.g. '15 scripts / 122 tests / 2,750 asserts green') if tests ran.>"
```

**`-s` is not optional.** `792b237` added a CI job that rejects any commit a
pull request adds without a `Signed-off-by` trailer, as CONTRIBUTING.md
requires. This snippet omitted it until 2026-08-14, so the manual fallback
produced commits that gate would refuse — `ship.py` passes `-s` itself, which
is why it went unnoticed. To repair a commit already made without it:
`git commit --amend -s --no-edit`.

Verify the split before moving on:

```bash
git log --oneline -5
git status --short
```

`git status --short` should be empty (or show only files you've deliberately
left uncommitted, e.g. a runbook documenting itself — note that explicitly if
so, as this file's predecessor did).

---

## Step 2 — Push

**Know what this triggers before you run it.** `ci.yml` fires on exactly two
events: `push` to `main`, and `pull_request` targeting `main`. Nothing else
runs CI. Pushing a feature branch uploads the commits and runs **no jobs at
all** — which is a useful property (it is a free off-machine backup you can
take mid-work), but it means a green terminal here is not evidence of
anything.

Working directly on `main`:

```bash
git push origin main
```

Working on a feature branch — the push is silent, and the pull request is what
actually runs CI:

```bash
git push -u origin <branch>
```

```bash
gh pr create --base main --head <branch> --title "<title>" --body "<why>"
```

If the push fails with a host-key or permission error, you are not on Brent's
Mac — the sandbox cannot push. Re-run from a real terminal.

---

## Step 3 — Watch CI

`gh` is installed and authorized on Brent's Mac; the GitHub MCP connector is
**not** authorized in Cowork sessions, so watching CI is a you-run-it step,
not a Claude-run-it step.

```bash
gh run list --limit 5
```

```bash
gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
```

```bash
gh run view $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
```

All five jobs should report success: `Tool tests`, `DCO sign-off` (pull
requests only), `GUT tests`, `Export desktop builds`, and `Smoke-test the
Windows binary`. The engine job names should show the pinned version (currently
`Godot 4.6.3-stable headless` — see
[ADR 0012](adr/0012-godot-and-gut-version-pin.md)). If the job name shows a
different patch version, the pin has drifted; fix `ci.yml` before trusting
the artifact. The `Node.js 20 is deprecated` annotation is a GitHub Actions
platform notice, not a project defect — safe to ignore.

If a job is red, pull the failure log directly rather than opening the web UI:

```bash
gh run view $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --log-failed
```

---

## Step 4 — Download and verify the artifact's contents

`tools/fetch_build.py` does this step. It downloads into a directory named for
the run, unpacks the macOS zip, then **globs** for the bundle and the binaries
rather than reconstructing their names, and prints Step 5's commands with the
real names already quoted:

```bash
tools/fetch_build.py <run-id> --check
```

Both halves of that matter, and both were learned the hard way on 2026-08-13
when these steps were first walked end to end:

- **The directory is named for the run.** The old fixed `~/Downloads/wc-latest-build`
  collided with the previous download and `gh run download` aborted partway,
  leaving a half-extracted tree. The error was the lucky outcome: without the
  collision you verify July's `.pck` and nothing tells you. `--reuse` reports on
  a directory that already exists instead of refusing it.
- **Nothing is addressed by name.** See Step 5.

`--check` runs the contents guard over every pack, the way CI does. To run it
by hand (works cross-platform — pure Python, no Godot needed):

```bash
python3 tools/check_pck_contents.py <path-to-.pck|.app|macos.zip>
```

Expect: all 20 `data/*.json` files present, **zero** `addons/gut` or `tests`
paths, pack format 3, built by the pinned Godot version. If the file count or
size looks off, compare against the last known-good numbers in
[export-setup.md](export-setup.md) before assuming a regression — Godot 4.6
writes pack format 3 (no `res://` prefix, directory at the end), so a naive
string scan for `res://…` paths will misreport an empty pack as containing no
data (this happened once, see
[[../obsidian-vault/daily-logs/2026-07-28]]). Trust the parser, not a grep.

---

## Step 5 — Relaunch and smoke-test the build

### macOS (windowed)

**Do not type the bundle's name.** The macOS preset exports to
`wildlife-crossing.zip`, but Godot names the `.app` inside it from
`config/name` in `project.godot` — currently **`Wildlife Crossing.app`**, with
a space and different capitalisation. Every command below therefore needs
quoting, and an unquoted one addresses `Wildlife` and reports `No such file`.
This runbook hardcoded `wildlife-crossing.app` until 2026-08-14, so its Step 5
had never been able to work as written; `check_pck_contents.py` had already
learned the same lesson and globs (see its module docstring).

`fetch_build.py` prints these three lines with the real path filled in and
quoted. Run what it prints, rather than the illustrative form here:

```bash
xattr -dr com.apple.quarantine "<bundle>.app"
```

```bash
codesign -dv --verbose=2 "<bundle>.app" 2>&1 | head -5
```

```bash
open "<bundle>.app"
```

The `codesign` check is worth reading, not skipping. The preset sets
`codesign/codesign=1` (Godot's built-in ad-hoc signer) but leaves `identity`,
`apple_team_id` and `notarization` at their defaults, and the export runs on a
Linux runner. If it reports `code object is not signed at all`, the binary is
`universal` and macOS will refuse it as *"damaged"* — a signing gap, not a
corrupt download. Ad-hoc sign locally to continue, and record which happened:
it is evidence for ADR 0018.

```bash
codesign --force --deep --sign - "<bundle>.app"
```

Confirm windowed, in this order:

1. **The title screen appears** — not the tutorial. ADR 0017 put a menu in
   front on 2026-08-09; this runbook said "the Bow Valley tutorial loads" until
   2026-08-14.
2. **F1 opens credits.** This is where Godot's MIT notice lives and is the
   reason the title screen exists at all — a licensing obligation, not a
   nicety.
3. **Start → the Bow Valley tutorial loads.**
4. **B builds a small span** — a couple of tiles, not the whole highway.
   Confirms ADR 0016 span geometry is live, not the old whole-segment
   behaviour.
5. **M opens the world map**, only Bow Valley unlocked, the other 11 sub-areas
   locked/desaturated.
6. **F5 then F9 round-trip a save.** Build a span with **B**, press **F5**,
   **quit the app entirely**, relaunch, press **F9**, and confirm the span is
   still there. A quickload inside one session does not prove the thing
   save/load exists to do. Added because `7e10b0c` shipped this system and no
   human had watched it run.

**One thing that looks like a regression and is not.** The old wording asked
you to confirm "animals move along the corridor". Expect not to see crossings
from the opening camera: `main.gd` sets `CAMERA_FOCUS_COORD := Vector2i(13, 6)`,
and the 2026-08-10 measurement found crossings happen on rows 0–2, with row 1
logging 192 uses. That is a known, measured, open defect (C4 in
[[../obsidian-vault/build-reviews/2026-08-12-next-build]]) — record what you see
against it rather than filing it new.

### Headless (optional — confirms the exported binary boots clean with no
### error storm, not just that it looks right on screen)

`fetch_build.py` prints this line too, with the executable located by glob —
it is named from `config/name` as well, so it is `Contents/MacOS/Wildlife
Crossing`, spaces and all.

```bash
tools/smoke_boot.sh "<bundle>.app/Contents/MacOS/<executable>" 20
```

Requires GNU coreutils (`brew install coreutils` if `gtimeout`/`gstdbuf` are
missing — see [testing-setup.md](testing-setup.md) for why `stdbuf` wrapping
is mandatory on macOS: a killed process's buffered stdout is silently
dropped, and a healthy-but-quiet boot can misreport as empty output).

The Linux and Windows binaries **cannot be executed on a Mac** (different
OS/architecture) — the `check_pck_contents.py` scan in Step 4 is the
verification for those platforms unless you have access to a Linux machine
or the CI runner logs.

---

## Troubleshooting / recurring gotchas

- **`.git/index.lock` reappears most sessions.** Traced to the
  `weekly-build-review` harness leaving it behind ([[../obsidian-vault/daily-logs/2026-07-28]]).
  Always clear it in Step 0 rather than assuming last session's fix stuck.
  `ship.py` clears it only if it is more than two minutes old, on the grounds
  that deleting a lock a live git process still holds corrupts the index —
  pass `--force-lock` if you know nothing is running.
- **`git push` failing with a host-key error means you're in the sandbox, not
  a real terminal.** Not a credentials problem to debug — just switch shells.
- **A green branch push is not a green CI run.** `ci.yml` triggers only on
  `push` to `main` and `pull_request` targeting `main`. A feature branch can
  sit on GitHub indefinitely having run no jobs at all. Open the pull request.
- **`gh run download` refuses to overwrite** and aborts partway through, on the
  first colliding file, leaving a tree that looks complete and is not. Never
  reuse a download directory; `tools/fetch_build.py` names it for the run id.
- **Nothing in the macOS artifact is named after the export path.** The zip is
  `wildlife-crossing.zip`; the bundle inside is `Wildlife Crossing.app` and the
  pack inside that is `Wildlife Crossing.pck`, both from `config/name`. Glob,
  quote, and let `fetch_build.py` print the paths — every hand-typed name in
  this file's Step 5 was wrong for two weeks before anyone ran it.
- **A pck that looks empty from a `grep 'res://'` scan may not be.** Godot
  4.6's pack format 3 doesn't prefix paths with `res://`. Use
  `tools/check_pck_contents.py`, which parses the real pack directory.
- **`project.godot`'s hand-written header keeps getting stripped.** Any
  `--import` or `--export-pack` run through the Godot editor rewrites the
  file and drops comments in the body, even ones placed "above Godot's
  block." If this happens again, restore from `git diff` / `git checkout` —
  don't hand-retype it — and consider moving the rationale permanently into
  a docs file instead of a source comment (already done for the ETC2/ASTC
  rationale — see [export-setup.md](export-setup.md)).

---

## Related

- [`tools/ship.py`](../tools/ship.py) — Steps 0–1 automated; `--help` documents
  the plan format. Tests in `tools/tests/test_ship.py`.
- [`tools/fetch_build.py`](../tools/fetch_build.py) — Step 4 automated: run-scoped
  download, and the bundle located by glob rather than by name. Tests in
  `tools/tests/test_fetch_build.py`.
- [testing-setup.md](testing-setup.md) — suite mechanics, `smoke_boot.sh` details
- [export-setup.md](export-setup.md) — how builds get produced, pack format 3 notes
- [ADR 0012](adr/0012-godot-and-gut-version-pin.md) — the Godot/GUT version pin
- [[../obsidian-vault/daily-logs/2026-07-30]] — the session this runbook was
  written during, and its first dry run
- [[../obsidian-vault/build-reviews/README.md]] — how the weekly build review
  (a different, larger process) relates to this day-to-day one
