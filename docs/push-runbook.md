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

Steps 3 to 5 are not automated and are still yours.

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
git commit -m "<type>(<scope>): <summary>

<body — what changed and why, 2-4 sentences. Include the suite count
(e.g. '15 scripts / 122 tests / 2,750 asserts green') if tests ran.>"
```

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

```bash
git push origin main
```

If this fails with a host-key or permission error, you are not on Brent's
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

Both jobs (`GUT tests`, `Export desktop builds`) should report success, and
their names should show the pinned engine version (currently
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

```bash
gh run download $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') -D ~/Downloads/wc-latest-build
find ~/Downloads/wc-latest-build -name "*.pck" -o -iname "*.app" -o -iname "*.exe" -o -iname "*.x86_64"
```

Run the contents guard against each `.pck` (works cross-platform since it's
pure Python — no Godot needed):

```bash
python3 tools/check_pck_contents.py <path-to-.pck>
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

The artifact may come through as a `.zip` or as a bare `.app` depending on
how the export step packaged it — check what `find` in Step 4 turned up.

If it's a zip:

```bash
cd ~/Downloads/wc-latest-build/wildlife-crossing-desktop-builds/wildlife-crossing-macos
unzip -o wildlife-crossing.zip -d .
xattr -dr com.apple.quarantine wildlife-crossing.app
```

If it's already a bare `.app`, the `xattr` quarantine step is unnecessary
(downloaded-and-zipped artifacts trigger Gatekeeper's quarantine flag; a
directly-uploaded `.app` from `actions/upload-artifact` does not).

```bash
open wildlife-crossing.app
```

Confirm windowed: the Bow Valley tutorial loads, animals move along the
corridor, **B** builds a small span (a couple of tiles, not the whole
highway — confirms ADR 0016 span geometry is live, not the old whole-segment
behavior), **M** opens the world map with only Bow Valley unlocked and the
other 11 sub-areas locked/desaturated.

### Headless (optional — confirms the exported binary boots clean with no
### error storm, not just that it looks right on screen)

```bash
tools/smoke_boot.sh <path-to-macos-app>/Contents/MacOS/<executable-name> 20
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
- [testing-setup.md](testing-setup.md) — suite mechanics, `smoke_boot.sh` details
- [export-setup.md](export-setup.md) — how builds get produced, pack format 3 notes
- [ADR 0012](adr/0012-godot-and-gut-version-pin.md) — the Godot/GUT version pin
- [[../obsidian-vault/daily-logs/2026-07-30]] — the session this runbook was
  written during, and its first dry run
- [[../obsidian-vault/build-reviews/README.md]] — how the weekly build review
  (a different, larger process) relates to this day-to-day one
