---
title: "Build Review — Next Build (2026-08-12)"
date: 2026-08-12
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> roadmap [[roadmap|Phases 1–2]]). One question: what work is needed to get
> there?

> [!note] This note was measured twice.
> The first pass ran against `9d0ec58` early on 2026-08-11. `7e10b0c` (save/load
> + monthly agent respawn) landed at 15:39 that afternoon, mid-review, and
> invalidated a third of the figures — including two items the first draft had
> filed under *Deferrable*. Everything below is re-measured against `7e10b0c` on
> 2026-08-12. Where a claim could not be re-checked, it is labelled in
> [§Verification](#verification).

## 1. Summary

- **Build case:** **FIRST working build**, for the sixth consecutive review, on
  the same three facts the harness's own test names — *"there is a working build
  only if you can point to an actual export in `builds/` or a GitHub Release
  **and** it launches."* Checked this session: `builds/` holds `.gitignore`,
  `.gitkeep` and one empty `wildlife-crossing-linux-arm64/` directory;
  `git tag -l` returns **0 tags**; `docs/release-notes/` holds a single 0-byte
  `.gitkeep`. The only binaries in the tree are dated **2026-07-27/28**, predate
  the title screen entirely, and fail the repo's own gate.
- **Target milestone & exit criteria:** roadmap
  [Phase 1](../../docs/roadmap.md) (`:45-56`) and
  [Phase 2](../../docs/roadmap.md) (`:114-122`), as scoped by the logged
  decisions of 2026-07-29 (Bow Valley only) and 2026-08-06 (world map ships
  look-only).
- **Headline:** **6 blockers, 6 core tasks, 7 verification items.** A strong
  fortnight — V2 and C4 closed on 08-10, licensing landed end to end on 08-09,
  save/load and agent respawn landed on 08-11, and the suite grew 144 → **237
  tests, all green**, re-run this session. Three things need naming.
  1. **CI is broken on `HEAD`, and nothing has noticed because `HEAD` has never
     been pushed.** `.github/workflows/ci.yml:279` — the last line of the file —
     is `retention-days: 14`, sitting inside the `smoke-windows` job's `run:`
     block under `set -euo pipefail`. It is a shell line, not a workflow key.
     Simulated this session: `bash: retention-days:: command not found`,
     **exit 127**. So the job `d7a2a61` added to close V2 fails on its first run
     no matter how cleanly the `.exe` boots. The same misplacement has a quieter
     half: the `Upload build artifacts` step at `:238-242` **lost** the
     `retention-days: 14` it still carries on `origin/main`
     (`origin/main:ci.yml:188`), so artifacts now use the repo default.
  2. **Five commits have never left this machine.**
     `git rev-list --left-right --count origin/main...HEAD` → **`0  5`**.
     `origin/main` is `0c31c85`, pushed 2026-08-10 21:49; the five that follow
     are `792b237` (DCO gate), `d7a2a61` (V2 pack gates + Windows smoke),
     `ed60d1c` (C4 measurement), `9d0ec58` (08-10 log) — all within 51 minutes of
     that push — and `7e10b0c` (save/load + respawn, 2026-08-11 15:39). So this
     is not a long-running divergence; it is one session that ended without a
     push and a second that never started one. The consequence is the same
     either way: **CI has never run the DCO gate, the three-pack gate, the
     Windows smoke job, or a single line of the save/load system**, and B3
     cannot export `HEAD` because GitHub does not have `HEAD`.
  3. **Nothing on any list gets a runnable download into a user's hands.** Two
     independent gaps, both new to this review. *Packaging:*
     `export_presets.cfg:26,57,88` set `binary_format/embed_pck=false`, so the
     Linux and Windows builds are a binary **plus** a separate `.pck` (plus a
     console wrapper on Windows), while a GitHub Release asset is a single file
     — a user who downloads `wildlife-crossing.exe` alone gets an engine with no
     game. *Signing:* [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
     requires a notarized macOS build, and all four preset keys that would
     produce one are still at their defaults (`codesign/codesign=1`,
     `notarization/notarization=0`, `codesign/identity=""`,
     `codesign/apple_team_id=""`). Apple enrolment — the only calendar-time gate
     in the project — has not started.
- **Change since last review:** [[2026-08-04-next-build]] — **B2 closed**
  (2026-08-06 scope call), **V1 closed** in part (`ci.yml:106-120`; see V6),
  **V2 and C4 closed** (2026-08-10). Its **B1, B3, C3 and V3–V6 remain open** and
  are renumbered here. **Newly open:** the `retention-days` regression; the
  release-packaging gap; the macOS signing configuration; five unpushed commits;
  the tutorial camera pointing at a measured dead zone; an unexercised DCO job;
  three further CI latent defects (V6, V7, and the `smoke-windows` skip
  described in B1). **Off the list:** the world-map click defect (`cb9f9b8`),
  the Windows/macOS pack gate (V2), the tutorial measurement (C4), **agent
  respawn** and **save/load** — the last two were on the previous draft's
  *Deferrable* list, one of them described as the largest gameplay gap in the
  tree, and both were implemented by `7e10b0c` while this review was being
  written.

## 2. Current state (evidence)

Measured against `7e10b0c` on 2026-08-12 unless labelled otherwise in
[§Verification](#verification).

- **Systems:** **30 scripts / 3,569 LOC** in `game/scripts/` (was 26 / 2,567 on
  2026-08-04). New since that review: `ui/credits_screen.gd`, `ui/main_menu.gd`,
  `ui/title_screen.gd` (2026-08-09) and `systems/save_manager.gd` (106 lines,
  2026-08-11). The four autoloads are registered at `game/project.godot:28-31`.
  Fourteen scripts named in `docs/architecture.md:52-68` are absent — all
  Phase 3–6.
- **Data:** all **8** canonical files in `game/data/` present and valid JSON;
  all **12** `data/world/sub_area_*.json` valid; `segments.json` holds **19
  segments covering all 12 sub-areas**. Unchanged since 2026-08-04.
- **Scenes & wiring:** `run/main_scene` is now
  `res://scenes/TitleScreen.tscn` (`project.godot:23`) — changed since the last
  review, and the single biggest reason no existing artifact tells you anything
  about `HEAD`. `Main.tscn` remains the playable root, reached from
  `title_screen.gd:23`. `--skip-menu` is matched as a *user* arg
  (`title_screen.gd:22,54-55`), so the invocation is `binary -- --skip-menu`.
  `scenes/world/Animal.tscn` is referenced by nothing.
- **Tests:** GUT 9.6.0 via the vendored
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` —
  **23 scripts / 237 tests / 3,032 asserts, all passing**, exit 0. Up from
  18 / 144 / 2,799 on 2026-08-04. Separately,
  `python3 -m unittest discover -s tools/tests -b` → **58 tests, OK**.
  **9 of 30 scripts have no named test file** — `main`, `title_screen`,
  `env_config`, the three constants files, and the autoloads `debug`,
  `event_bus`, `species_registry`. The only script with **zero** test contact of
  any kind is now `species_registry.gd` (53 LOC); `game_state.gd` gained
  `game_state_test.gd` (202 lines) in `7e10b0c`.
- **Headless boot from source:** both boots clean against the pinned 4.6.3
  binary. Bare → `[I] Title screen ready`. `-- --skip-menu` →
  `[I] Tutorial loaded. Press B to build the Bow Valley overpass. Press M for
  the world map. Press F1 for credits. F5 saves, F9 loads.` No `ERROR:` or
  `SCRIPT ERROR` in either.
- **CI:** `.github/workflows/ci.yml`, **279 lines**, **five jobs** — `tools:24`,
  `dco:57`, `test:74`, `export:122`, `smoke-windows:255` — with
  `GODOT_VERSION: 4.6.3-stable` pinned at `:15`. The pack gate covers **all
  three** packs (`:191-205`, closing V2) and `smoke_boot.sh` covers Linux
  (`:210-213`) and Windows (`:271-278`). **But see §The `retention-days`
  regression, and V6/V7.** Whether any CI run has ever passed is
  **Unverifiable** this session: `gh` is not installed and `git fetch origin`
  fails with *Host key verification failed*.
- **Build/export:**
  - `builds/` — `.gitignore`, `.gitkeep`, one empty directory. No binaries.
  - `wildlife-crossing-desktop-builds/` — **411 MB**, files dated 2026-07-27 and
    2026-07-28, newest **2026-07-28 03:31**. Running the repo's own gate this
    session: `python3 tools/check_pck_contents.py …/wildlife-crossing.pck
    --data-dir game/data` → **exit 1**, *"exported pack ships 244
    development-only path(s)"*, pack *built by Godot 4.6.0* (CI pins 4.6.3).
    These predate the title screen, the credits screen, `config/version` and the
    save system — they cannot be used to judge anything.
  - `git tag -l` → **empty**. `docs/release-notes/` → `.gitkeep` only.
    → **first build.**
  - No local export was attempted: `~/.local/share/godot/export_templates/` is
    empty in this sandbox.
- **Git:** branch `main`, `HEAD` = `7e10b0c` (*feat(sim): save/load
  serialization and monthly agent respawn*, 2026-08-11 15:39 CDT).
  `origin/main` = `0c31c85`. **5 ahead, 0 behind.** Working tree clean apart from
  this review's own files. A 0-byte `.git/index.lock` is present (mtime
  2026-08-11 15:39:54, i.e. left by the `7e10b0c` session, not by this harness).

### The `retention-days` regression

New this review, and the most consequential single line in the repo:

1. `.github/workflows/ci.yml:274-279` — the `smoke-windows` job's step *Boot the
   Windows binary headless* is `shell: bash`, `run: |`, opening with
   `set -euo pipefail`. Its final line, and the file's, is `retention-days: 14`.
2. Simulated this session: `bash -c 'set -euo pipefail; retention-days: 14'` →
   `bash: line 1: retention-days:: command not found`, **exit 127**. Under
   `set -e` the step fails, so the job fails, unconditionally.
3. `ci.yml:238-242` — the `Upload build artifacts` step's `with:` block now ends
   at `path: builds/`. On `origin/main` that same block carries
   `retention-days: 14` (`origin/main:ci.yml:188`).

`git show d7a2a61 -- .github/workflows/ci.yml` renders the new job's lines as
added immediately *above* `retention-days: 14`, which appears as unchanged
context. The insertion point was one line off: the key was orphaned out of the
`with:` block it belonged to and into the `run:` block below it.

The artifact itself still uploads — `if: always()` is on the upload *step*
(`:238`) — so this is a permanent red X and a silently-changed retention window,
not a lost binary. **But note the corollary, which changes what "fix it" means:**
`if: always()` is on two steps, **not on the `export` job**, and `smoke-windows`
has a bare `needs: export` (`:257`). If the pack gate (`:205`) or the Linux
smoke boot (`:210`) fails, `smoke-windows` is **skipped, not red** — so
"observed green `smoke-windows`" is not a criterion a failing export can ever
produce. Any acceptance written against it needs to say *green, not skipped*.

### Exit criteria, criterion by criterion

Phase 2's five exit criteria are `roadmap.md:114-122`. The in-map segment
renderer and hover highlight are **not** among them and were deferred on the
record on 2026-08-06. (Note: `roadmap.md` cites its own criteria as `:98-108` at
`:148` and `:155-156`; those line numbers were correct before the 08-06
insertion and are not now. Cite the heading, not the line.)

| Phase | Criterion | State |
|---|---|---|
| 1 | Animals route around impassable / across hazardous at the configured rate | **Met** — `pathfinding_test.gd`, `simulation_test.gd` green |
| 1 | Full span → zero-mortality route; partial span → none | **Met, and now measured** — `tools/measure_tutorial.gd` (C4, 2026-08-10) reports **6.30** deaths/10 agents with no span vs **1.20** with a one-row span, at t=100 (about one in-game day). The log is explicit that the endpoint totals say almost nothing: deaths are absorbing, so by t=2000 every arm converges (7.30 vs 6.70). A whole-corridor span holds 0.00 at every horizon |
| 1 | `animal_crossed` fires once per traversal | **Met** — `simulation_test.gd` |
| 1 | Visual **+ audio** placeholder cue, coalesced in 2s | **Met in code, never seen on a screen** — `hud.gd` + `crossing_cue.png` + the chime; `hud_test.gd` asserts state, not pixels, and no export has existed since it landed |
| 1 | Named Phase 1 suites green | **Met** — all five exist and pass |
| 1 | (P1) Species preference weighting; usage counter | **Deferred on the record** 2026-08-06 (roadmap Phase 1 decision block) |
| 2 | Continuous zoom, ≥16px/12px hysteresis, no loading screens | **Met** — `world_select_controller_test.gd`, 22 tests |
| 2 | Locked sub-areas desaturated + lock indicator, zoom blocked | **Logic met, never rendered to a human** → C5 |
| 2 | Overlay orange→teal ~40%, pulse worst three, segment-mode only, clears | **Logic met, never rendered to a human** → C5 |
| 2 | Confirm passes correct `(segment, sub_area)`; click-outside and Escape per spec | **Met** — `confirm_panel_test.gd`; the blind-click path closed `cb9f9b8` and is regression-tested |
| 2 | Named Phase 2 suites green | **Met** — all four exist and pass |
| — | *(implied)* an export of the current code launches | **Unverified** — no export of `HEAD` exists → B3 |

The honest read: **every Phase 1 and Phase 2 exit criterion is met in code and
green in tests, and three of them have never been rendered to a human.** What is
missing is not gameplay logic. It is a pipeline that runs, a binary somebody has
looked at, and a release a stranger could actually install.

## 3. Work needed for the first build

Ordered the way you'd actually do it.

### Blockers (nothing ships until these exist)

#### B1. Fix the orphaned `retention-days` in `ci.yml`
- **Why it blocks:** `ci.yml:279` is a shell line inside `set -euo pipefail`, so
  `smoke-windows` exits 127 on every run regardless of whether the `.exe` boots
  — and that job is the whole second half of V2, closed two days ago.
  Meanwhile the artifact upload silently lost its retention window. Fix this
  *before* B2, or the first push turns CI red on arrival and everything after it
  is debugged through a false signal.
- **Files/areas:** `.github/workflows/ci.yml:238-242` (restore
  `retention-days: 14` under `with:`), `:274-279` (the `run:` block must end at
  `bash tools/smoke_boot.sh "$BIN" 30`).
- **Acceptance:** `grep -n 'retention-days' .github/workflows/ci.yml` returns a
  line inside the `Upload build artifacts` `with:` block and nowhere else; and
  after B2, `smoke-windows` observed **green — not skipped** (a bare
  `needs: export` at `:257` skips it whenever the export job fails, so "not red"
  is not the same as "passed"). If it fails on `stdbuf`, that is a **separate**
  finding, not this one: `tools/smoke_boot.sh:83-90` requires `stdbuf` or
  `gstdbuf` on PATH and exits 2 with a macOS-flavoured message if neither is
  there, and whether Git Bash on `windows-latest` ships `stdbuf` has never been
  tested by anything.
- **Depends on:** none.
- **Size:** S
- **Refs:** `d7a2a61`; `origin/main:ci.yml:188`; [[2026-08-04-next-build]] V2;
  [[../daily-logs/2026-08-10]] (which raises the `stdbuf`/`timeout` question
  itself); [export-setup](../../docs/export-setup.md):97, stale as a result —
  see §4.

#### B2. Push the five commits
- **Why it blocks:** `origin/main` is `0c31c85` (pushed 2026-08-10 21:49); `HEAD`
  is `7e10b0c`; 5 ahead, 0 behind. The DCO gate, the three-pack gate, the Windows
  smoke job, the C4 measurement, the 08-10 log and the **entire save/load and
  agent-respawn system** exist only on this machine. CI has run none of it, so
  V2 and C4 are closed *in the repo* and unproven *in the pipeline*, and 1,044
  lines of new simulation code have never met a second opinion. B3 is impossible
  until GitHub has `HEAD`.
- **Files/areas:** no code change.
  [push-runbook](../../docs/push-runbook.md); `tools/ship.py`.
- **Acceptance:** `git rev-list --count origin/main..HEAD` → 0;
  `tools/ship.py --verify` clean; the resulting CI run observed with `tools`,
  `test`, `export` and `smoke-windows` **all green** — the first run in project
  history to exercise five jobs. Note the stale 0-byte `.git/index.lock`: it is
  ~27 h old and `tools/ship.py:381-416 check_lock()` clears anything older than
  `STALE_LOCK_SECONDS = 120` automatically, so it is **not** an obstacle to
  `ship.py` — but it does block plain `git add`/`git commit`, and `ship.py
  --execute` cannot run from the Cowork sandbox at all (`ship.py` says so in the
  `OSError` branch). Run it from a real terminal on the Mac.
- **Depends on:** B1 (push the fix in the same run).
- **Size:** S
- **Refs:** [push-runbook](../../docs/push-runbook.md);
  [[../daily-logs/2026-08-10]] §Open questions.

#### B3. Export and verify a build from current `HEAD`
- **Why it blocks:** carried from [[2026-08-04-next-build]] B1 and **larger
  again**. Since the last artifact anyone looked at (2026-07-28), the project
  gained a title screen, a main menu, a 91 KB runtime-generated credits screen,
  `config/version="0.1.0"`, a boot-scene change, and quicksave/quickload. The
  exported binary now boots somewhere **no human has ever seen**, and the
  credits screen is the primary licence-compliance mechanism under
  [ADR 0017](../../docs/adr/0017-licensing.md): if it renders illegibly, the
  project is out of compliance and 237 unit tests cannot tell you.
- **Files/areas:** no code change expected — run the pipeline.
  `.github/workflows/ci.yml` `export` job; `tools/check_pck_contents.py`;
  `tools/smoke_boot.sh`.
- **Acceptance:**
  - `check_pck_contents.py` **exits 0** on all three packs — zero `addons/gut`,
    zero `tests/`, all 20 data files, banner Godot **4.6.3**;
  - the pack also contains `assets/audio/crossing_chime.wav` and
    `assets/sprites/crossing_cue.png` — `game/.gitignore:3` excludes `*.import`
    so both are re-imported every run and nothing asserts they survive, yet
    `main.gd:21` and `hud.gd:14` `preload()` them;
  - `smoke_boot.sh` green on Linux **and** Windows, both boots each;
  - a **windowed macOS launch** in which: the menu appears and `Play` works; the
    credits screen opens from the menu *and* from `F1` and is **actually read**
    for legibility and scrolling; the HUD message line is legible; the "+N
    crossed safely" cue is seen firing **and** the chime heard; and every key
    `main.gd` owns is pressed — **B**, **M**, **F1**, left-click, **Enter**,
    **Escape**, and **F5**/**F9**. Quicksave is the only path that writes to
    `user://` (`save_manager.gd`) and it has never run from an exported binary,
    where the sandbox and permissions differ from the editor.
- **Depends on:** B1, B2.
- **Size:** M
- **Refs:** [push-runbook](../../docs/push-runbook.md);
  [export-setup](../../docs/export-setup.md); ADR 0017;
  [[2026-08-04-next-build]] B1.

#### B4. Decide how a Release ships something a stranger can run
- **Why it blocks:** this is the gap that most directly defeats the purpose of
  the release, and no previous review has named it.
  `export_presets.cfg:26,57,88` set `binary_format/embed_pck=false`, so the
  Linux build is `wildlife-crossing.x86_64` **+** `wildlife-crossing.pck` and
  the Windows build is `.exe` **+** `.pck` **+** a console wrapper
  (`debug/export_console_wrapper=1`). A GitHub Release asset is a single file: a
  downloader who takes `wildlife-crossing.exe` on its own gets a Godot runtime
  with no game and no error that explains why. Compounding it, GitHub Actions
  artifacts do not preserve the Unix executable bit — which is exactly why
  `ci.yml:277` has to `chmod +x` the Windows binary — so a Linux binary routed
  through the CI artifact into a Release arrives non-executable.
- **Files/areas:** `game/export_presets.cfg` (either set `embed_pck=true` for
  Linux and Windows, or keep it false and add an archiving step);
  `.github/workflows/ci.yml` export/upload steps; possibly
  `tools/check_pck_contents.py`, which locates a pack by path and would need to
  read an embedded one.
- **Acceptance:** each published asset is **one file that runs on a clean
  machine** — a `.tar.gz`/`.zip` per platform, or embedded packs — verified by
  extracting to an empty directory and launching, with no reliance on a
  sibling file; the Linux binary is executable after download.
- **Depends on:** B1 (don't stack CI changes on a broken workflow).
- **Size:** M
- **Refs:** `export_presets.cfg:26,57,88`, `:25,56,87`;
  [export-setup](../../docs/export-setup.md); ADR 0018 §Decision (the manifest
  covers "every published artifact", which presumes you know what those are).

#### B5. Start the Apple enrolment and create the GPG key
- **Why it blocks:** [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
  (2026-08-10) makes a signed, notarized macOS build part of what `v0.1.0`
  *is*. [signing-runbook](../../docs/signing-runbook.md) says it plainly:
  *"Apple enrolment takes a few days. It is the only calendar-time gate left.
  Start it first."* Neither prerequisite exists. This is the one item that
  cannot be compressed by working harder.
- **Files/areas:** later, the public key committed to the repo and its
  fingerprint in `README.md`.
- **Acceptance:** **A1–A4 and B1–B2 of the runbook**, not just A1–A2 — enrolment
  submitted, a **Developer ID Application** certificate issued (an "Apple
  Development" certificate signs fine and fails notarization), the Xcode licence
  accepted (A3), and the **App Store Connect API key** created and stored (A4,
  `runbook:90-101` — Apple lets you download the `.p8` exactly once, and
  `notarytool` needs it plus the Issuer ID and Key ID). Plus a GPG signing key
  with its revocation certificate stored, and the public key published.
- **Depends on:** none. **Costs $99/year** — the decision is recorded in
  ADR 0018; the spend has not happened.
- **Size:** S effort, **days of calendar**
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A1–A4, B1–B2,
  §Suggested order of work, §Known gotchas.

#### B6. Cut `v0.1.0` — release note, tag, signed GitHub Release
- **Why it blocks:** this is the item that decides the build case, and six
  consecutive reviews have answered "first build" on the same three facts —
  empty `builds/`, zero tags, empty `docs/release-notes/`. All three are still
  true. What changed since 08-04 is that the finish line moved: ADR 0018 turned
  this from *tag and upload* into *notarize, checksum, sign the manifest,
  publish, and say honestly what is signed and what is not*.
- **Files/areas:** `docs/release-notes/v0.1.0.md`; a `v0.1.0` tag; a GitHub
  Release with the macOS image, the Windows and Linux packages from B4,
  `SHA256SUMS.txt` and its detached signature; `README.md` (key fingerprint);
  root `CLAUDE.md`'s "binaries via GitHub Releases, not committed" policy.
- **Acceptance:** the release note follows [docs/CLAUDE.md](../../docs/CLAUDE.md)
  format and states **all four** scope facts — Bow Valley only, the world map is
  look-only, placeholder art and the default Godot icon, and which artifacts are
  signed vs not and how to verify; the tag exists; `spctl`/`stapler` verify the
  notarized image per runbook A7; the GPG signature verifies per B4; and the
  binaries report their own version (C3).
- **Depends on:** B3, B4, B5, C1, C2, C3, C5, C6.
- **Size:** M
- **Refs:** ADR 0018 §Decision, §Follow-on work;
  [signing-runbook](../../docs/signing-runbook.md) A6–A8, B3–B4, C2;
  [[2026-08-04-next-build]] B3.

### Core build work

#### C1. Configure macOS signing in the export preset
- **Why:** ADR 0018 requires a notarized macOS build and **nothing in the repo
  is set up to produce one**. All four keys are at their defaults:
  `export_presets.cfg:145` `codesign/codesign=1` (Built-in ad-hoc; Xcode
  codesign is `3`), `:173` `notarization/notarization=0` (Disabled; Xcode
  notarytool is `2`), `:148` `codesign/identity=""`, `:147`
  `codesign/apple_team_id=""`. B6's acceptance asks `spctl` and `stapler` to
  verify, which is impossible until these change. This was invisible in the
  previous draft, which covered version fields and the container format and
  assumed the signing itself was part of "cut the release".
- **Files/areas:** `game/export_presets.cfg` preset 3. Note the runbook's own
  warning: **the file is tracked and Godot writes secrets into it** — use the
  `GODOT_MACOS_NOTARIZATION_*` environment variables and diff before every
  commit. Leave the `Debugging` entitlement `false`.
- **Acceptance:** a signed test export from Brent's Mac that `spctl -a -vvv`
  accepts and whose ticket `stapler validate` confirms (runbook A7 — *"do not
  trust the export log"*). Also check whether `export/distribution_type=0`
  ("Testing", `:128`) needs to change; the runbook's A5 table does not mention
  it and this review could not reach the Godot docs to settle it.
- **Depends on:** B5 (the certificate and the API key).
- **Size:** M
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A5, A7,
  §Known gotchas; ADR 0018 §Decision.

#### C2. Change the macOS export target from `.zip` to `.dmg`
- **Why:** ADR 0018 requires it for two independent reasons: **you cannot staple
  a notarization ticket to a `.zip`** (runbook §Known gotchas), and the `.zip`
  is why `LICENSE` and `THIRD-PARTY-NOTICES.md` land *beside* the archive rather
  than inside the bundle — the standing macOS notice gap recorded in
  [[../daily-logs/2026-08-09]]. Note the interaction with V2/B1: the pack gate
  currently resolves the macOS pack by globbing `Contents/Resources/*.pck`
  **inside the `.zip`**, so changing the container breaks it unless
  `check_pck_contents.py` learns `.dmg` too.
- **Files/areas:** `game/export_presets.cfg:117`;
  `tools/check_pck_contents.py`; `tools/tests/test_check_pck_contents.py`;
  `.github/workflows/ci.yml` export step.
- **Acceptance:** the macOS preset exports a `.dmg`; `check_pck_contents.py`
  accepts it and its tests cover the new input; CI's export job stays green;
  `LICENSE` and `THIRD-PARTY-NOTICES.md` are inside the image, added **before**
  signing (modifying a signed bundle silently invalidates it).
- **Depends on:** B1.
- **Size:** M
- **Refs:** ADR 0018; [signing-runbook](../../docs/signing-runbook.md) A5–A6;
  [[../daily-logs/2026-08-09]].

#### C3. Set the version metadata the export presets never got
- **Why:** [[2026-08-04-next-build]] B3 asked that "the binaries report their own
  version". Half landed — `project.godot:17` now has `config/version="0.1.0"` —
  and the half that reaches a downloaded file did not. Measured this session:
  `export_presets.cfg:138-139` still have `application/short_version=""` and
  `application/version=""`; the Windows preset has no
  `file_version`/`product_version` at all. An empty
  `CFBundleShortVersionString` is also a notarization risk, and ADR 0018
  explicitly promises *"the macOS binary finally reports its own version … set
  in the same pass"*.
- **Files/areas:** `game/export_presets.cfg` presets 2 and 3.
- **Acceptance:** `application/version` and `application/short_version` read
  `0.1.0`; Windows `file_version`/`product_version` set; a built binary's
  reported version matches the `v0.1.0` tag.
- **Depends on:** none.
- **Size:** S
- **Refs:** ADR 0018 §Consequences; [signing-runbook](../../docs/signing-runbook.md) A5.

#### C4. Decide the tutorial camera focus
- **Why:** `main.gd:18` sets `CAMERA_FOCUS_COORD := Vector2i(13, 6)` with the
  docstring *"a tile on the tutorial highway, so the first view shows the
  crossing site"*. C4's measurement on 2026-08-10 found row 6 has **zero**
  measured deaths and about 10 crossing uses, while **70 of 73 baseline deaths
  happen on rows 0–2** and row 1 logs 192 uses. The opening camera points at the
  one part of the tutorial where nothing happens — on the first screen of the
  first build a stranger will ever see. Flagged to the owner on 08-10 and not
  decided.
- **Files/areas:** `game/scripts/main.gd:18`; optionally a test asserting the
  focus row is one the measurement found active.
- **Acceptance:** a one-line change or an explicit recorded decision to keep it;
  either way the answer is in a log before C5's QA pass runs.
- **Depends on:** none. **Needs an owner call**, and it is a one-line change.
- **Size:** S
- **Refs:** [[../daily-logs/2026-08-10]] §Open questions;
  [[../design/detour-cost-question]]; `tools/measure_tutorial.gd`.

#### C5. Visual + audio QA pass, written down
- **Why:** owed since 2026-07-08 and kept in v0.1.0 scope by the 2026-08-06
  decision. Three windowed sessions happened (07-29, 07-30 ×2); none covered the
  overlay treatment or the locked desaturation, all three pre-date the HUD, and
  all three pre-date the entire title/menu/credits front end and the save
  system. `hud_test.gd` asserts state, not pixels; this project's 237 tests have
  never examined one.
- **Files/areas:** no code change expected; findings feed back into
  `world_renderer.gd`, `connectivity_overlay.gd`, `hud.gd`, `credits_screen.gd`.
- **Acceptance:** a note in `obsidian-vault/daily-logs/` confirming each Phase 2
  visual criterion observed on screen (locked desaturation + lock indicator;
  overlay orange→teal at ~40% appearing only in segment mode and clearing), the
  crossing cue visible **and** audible once per coalesced window, the HUD
  message line legible, the credits screen legible and scrollable, a quicksave
  and quickload round-trip in the export, and — still never captured by any log
  — **the Godot version installed on Brent's Mac**.
- **Depends on:** B3 (observed in the export, not the editor), C4 (decide the
  camera first, so the pass looks at what ships).
- **Size:** S
- **Refs:** roadmap Phase 2 exit criteria; the 2026-08-06 decision block;
  [[2026-08-04-next-build]] C3.

#### C6. Add the verification copy to the existing download section
- **Why:** ADR 0018 §Follow-on work requires *"`README.md` and the website
  download section need the key fingerprint and the unsigned-Windows note"*.
  The section exists — `website/index.html:53-57` is a **"Download for Mac,
  Windows & Linux"** button pointing at the Releases page, with a footer link at
  `:286` and another in `user-guide.html:425`, all landed in `01ca505`
  (2026-08-06). What is missing is the copy, not the page. (Recorded because the
  first draft of this review asserted there was no download section at all,
  reaching that conclusion from a case-sensitive `grep -c download` returning 0.)
- **Files/areas:** `website/index.html`, `README.md`; `website/CLAUDE.md`
  conventions.
- **Acceptance:** the download area names each published asset, states plainly
  that Windows is unsigned and what SmartScreen will say, gives the GPG
  fingerprint and the two verification commands, and does not imply the GPG
  signature suppresses any OS warning (runbook C2 is explicit about that
  conflation).
- **Depends on:** B4 (the asset list), B5 (the fingerprint).
- **Size:** S
- **Refs:** ADR 0018 §Follow-on work;
  [signing-runbook](../../docs/signing-runbook.md) C2; `website/CLAUDE.md`.

### Verification (tests, CI, export)

#### V1. Add `env_config.gd` coverage
- **Why:** carried from [[2026-08-04-next-build]] V3. Still the only untested
  script carrying real branching logic: it owns per-terrain mortality lookup and
  the resolution order (override → OS env → `DEFAULT = 0.20`,
  `env_config.gd:8,21-31`) — exactly what the Phase 1 criterion *"deaths at the
  configured env-var rate"* rests on. Confirmed absent this session.
- **Files/areas:** new `game/tests/env_config_test.gd`.
- **Acceptance:** resolution order covered end to end; suite reaches 24 scripts.
  GUT only discovers a new `*_test.gd` after a re-`--import`.
- **Depends on:** none.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md); roadmap Phase 1 exit criteria.

#### V2. Cover `species_registry.gd` and the constants files
- **Why:** carried from [[2026-08-04-next-build]] V6 and **half closed by
  `7e10b0c`** — `game_state_test.gd` now exists (202 lines, covering the
  `to_dict()`/`from_dict()` round-trip, omit-means-default, and version
  refusal), so the ADR 0014 half of this item is done. What remains:
  `species_registry.gd` is the one script in the tree with zero test contact of
  any kind, and `grep -c Constants game/tests/data_validation_test.gd` → **0**,
  so the three constants files `data-schemas.md` §10 specifies normatively are
  asserted nowhere.
- **Files/areas:** new `game/tests/species_registry_test.gd`; constants
  assertions in `game/tests/data_validation_test.gd`.
- **Acceptance:** `species_registry` load-failure path covered; constants values
  asserted against `data-schemas.md` §10.
- **Depends on:** none.
- **Size:** S
- **Refs:** [data-schemas](../../docs/data-schemas.md) §10; `7e10b0c`.

#### V3. Reconcile `docs/test-plan.md` §11 against the real suite
- **Why:** carried from [[2026-08-04-next-build]] V4. §11 is the P0 coverage
  table — the acceptance bar for a first playable. Re-measured by script this
  session: of **43** uniquely named tests, **35 have no matching `func test_` in
  `game/tests/` (81%)** — identical to a week ago despite 93 new tests landing,
  which is itself the finding. Mostly renames, but the table can no longer be
  used as a checklist.
- **Files/areas:** `docs/test-plan.md` §11.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason (the 2026-08-06 decision supplies the reasons for the
  hover-highlight row).
- **Depends on:** none — the deferral list it was blocked on landed 2026-08-06.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md) §11.

#### V4. Export the `Linux arm64` preset in CI, or delete it
- **Why:** carried from [[2026-08-04-next-build]] V5, unchanged.
  `export_presets.cfg:32-62` defines a preset that `ci.yml:165-170` never
  builds, and `builds/wildlife-crossing-linux-arm64/` sits empty in the tree as
  its ghost. It is also the architecture this sandbox runs on, so having it would
  let a future review boot a real artifact instead of reasoning about one.
- **Files/areas:** `.github/workflows/ci.yml`, `game/export_presets.cfg`,
  `builds/wildlife-crossing-linux-arm64/`.
- **Acceptance:** either the arm64 artifact appears in the CI upload and passes
  `check_pck_contents.py`, or the preset and the empty directory are gone.
- **Depends on:** B1.
- **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md); `ci.yml`.

#### V5. Exercise the `dco` job before it has to guard anything
- **Why:** `ci.yml:59` gates the job on `github.event_name == 'pull_request'`, so
  pushing to `main` never runs it. It has therefore never executed, and
  [[../daily-logs/2026-08-10]] names this itself. A DCO gate discovered to be
  broken by the first outside contributor is worse than no gate: it fails on
  someone else's work.
- **Files/areas:** a throwaway branch and pull request carrying one deliberately
  unsigned commit, then one signed.
- **Acceptance:** the `dco` job observed red on the unsigned commit and green
  once signed off; the PR closed without merging.
- **Depends on:** B2.
- **Size:** S
- **Refs:** `ci.yml:43-72`; `tools/check_dco.py`; `CONTRIBUTING.md`.

#### V6. Make the zero-tests guard report why it failed, and catch partial drops
- **Why:** two problems in the step that closed 08-04's V1. First,
  `ci.yml:115` is `TESTS="$(grep -oE '<testcase' "$XML" | wc -l | …)"` under
  `set -euo pipefail` — if GUT records zero test cases, `grep` exits 1, the
  command substitution fails, and `set -e` kills the step **before** the
  `::error::` message at `:118` can print. The build still fails; the operator
  gets an unexplained exit from the one guard written to explain itself. Second,
  the guard still only catches `TESTS -eq 0`, whereas the failure it was
  designed for — 2026-07-19 — was a **partial** drop where a parse error removed
  one file, GUT printed *All tests passed!* and exited 0. At 23 scripts a run
  that silently lost 22 of them still passes. 08-04's V1 asked for the script
  count assertion; what shipped guards the zero case only. Worth confirming
  which was intended before treating V1 as closed.
- **Files/areas:** `.github/workflows/ci.yml:106-120`.
- **Acceptance:** a zero-test run prints the `::error::` before exiting; CI fails
  when the JUnit XML reports fewer than the expected number of test scripts
  (currently **23**); both verified against synthetic XML.
- **Depends on:** none.
- **Size:** S
- **Refs:** `ci.yml:106-120`; [[../daily-logs/2026-07-19]];
  [[2026-08-04-next-build]] V1; [testing-setup](../../docs/testing-setup.md):142-147.

#### V7. Teach `build_encyclopedia.py` to delete, and test it
- **Why:** the sync gate at `deploy-website.yml:49-56` regenerates and runs
  `git diff --quiet -- website/encyclopedia`. `tools/build_encyclopedia.py` only
  ever writes (`:668` `mkdir`, `:671`/`:675` `write_text`) — it never removes.
  So a **new** wiki entry produces an **untracked** `website/encyclopedia/<slug>.html`,
  which `git diff` cannot see, and the gate passes green while the deployed site
  is missing the page; a **deleted** entry leaves an orphan the diff also cannot
  see. At 686 LOC it is also the largest untested tool of the three that have no
  tests (`inspect_pck.py` and `make_hero_svg.py` are the others; `check_dco.py`,
  `check_pck_contents.py` and `ship.py` have 58 tests between them). Regenerating
  today is a clean no-op — 24 entries plus index — so nothing is out of sync
  right now.
- **Files/areas:** `tools/build_encyclopedia.py`;
  `.github/workflows/deploy-website.yml:49-56`; new
  `tools/tests/test_build_encyclopedia.py`.
- **Acceptance:** the generator removes pages whose wiki source is gone; the CI
  gate detects an untracked generated file (e.g. `git status --porcelain` as
  well as `git diff`); round-trip and external-asset checks covered by tests;
  `python3 -m unittest discover -s tools/tests -b` still OK.
- **Depends on:** none.
- **Size:** M
- **Refs:** `.github/workflows/deploy-website.yml`; `website/CLAUDE.md`.

### Deferrable / nice-to-have

- **63% of visible animals die in the first in-game day** — about ten real
  seconds at 1×, before the player can build anything (`6.30` of 10 agents at
  t=100, `measure_tutorial.gd`). Inherited from `EnvConfig.DEFAULT = 0.20`
  (`env_config.gd:8`) rather than chosen. A live tension with the *"cozy, not
  stressful"* north star, worth an explicit decision rather than a default —
  and `7e10b0c`'s monthly respawn changes the shape of it without settling the
  first-day spike.
- **C4's measurement covered Bow Valley only.** The other 17 non-bisecting
  segments, where a safe detour exists, remain unmeasured — the original form of
  the detour-cost question.
- **The game ships the default Godot window icon.** `config/icon` absent from
  `project.godot`; `application/icon=""` at `export_presets.cfg:94,133`. Already
  recorded as a known first-build limitation at `export-setup.md:119`; say it in
  the release note rather than let a downloader find it.
- **Delete the stale `wildlife-crossing-desktop-builds/` artifacts.** 411 MB,
  they fail the repo's own gate, they were built by Godot 4.6.0 against a
  pipeline that pins 4.6.3, and they are the single most misleading thing in the
  tree — three reviews running have had to establish that they are not the build.
- **`game/scenes/world/Animal.tscn` is dead weight** — referenced by no script or
  scene; agents are drawn as circles by `world_renderer.gd`. Delete or wire.
- **`entities.json` is loaded and read by nothing.** `species_registry.gd:26`
  indexes it; no other script consumes it. Phase 2's Implements list requires
  the controlling-entity mapping "consumed as data".
- **Phase 2's "toolbar tool" P0 has neither an implementation nor a deferral.**
  `roadmap.md:96` lists it among Phase 2's P0 Implements; `main.gd:332` is a
  *"placeholder trigger for the PRD's 'Add crossing' toolbar action"* bound to
  `M`. Same for the whole P1 group at `:99-100` (hover score, segment label,
  crossing-count note, sub-area summary). Neither is an exit criterion, so
  neither blocks the build — but `roadmap.md:12` claims every requirement is
  assigned to exactly one phase, and in practice these are not.
- **19 of 22 `.gitkeep` files** now sit in directories with real content. Only
  `game/assets/fonts/`, `game/assets/tilesets/` and `docs/release-notes/` are
  genuinely empty.
- **`BaseScreen` retrofit** of `ConfirmPanel` and `ConnectivityOverlay` —
  deliberately deferred 07-31, noted so it stays visible.
- **Real art.** `fonts/` and `tilesets/` are still `.gitkeep`;
  `crossing_cue.png` is a 341-byte generated placeholder. The eight 2048×2048
  species portraits generated 07-31 are unwired **in the game** — 512×512
  derivatives do ship on the public site (`website/encyclopedia/*.html`, landed
  `01ca505`).
- **`website/CLAUDE.md:79`** still specifies user-guide section 2 as *"Placing
  habitats"*, which the shipped guide does not match. Raised in the 2026-08-04
  log and never homed anywhere.
- macOS notarization is now specified (ADR 0018); Windows signing is
  deliberately out — revisit only per ADR 0018's stated triggers.
- Phase 5 gates (liaison-NPC decision, cultural-advisor review) remain open and
  still do not block P0.

**Closed since the previous draft of this note, by `7e10b0c`:** *"rendered agents
never respawn"* (`simulation.gd:124 resync_agents()`, called from the monthly
boundary at `:89` and from `restore_state()` at `:227`) and *"save/load is
unimplemented"* (`save_manager.gd`, `game_state.from_dict()`,
`simulation.save_state()/restore_state()`, with `save_manager_test.gd`). The
first of those was described in the earlier draft as the largest gameplay gap in
the tree.

## 4. Doc drift to fix

Record only — docs are not edited during a review.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | "`game/` is still almost entirely `.gitkeep`"; A1 "no `project.godot`"; A2 "GUT not installed"; A3 "no CI"; A4 "zero game code"; A5 "only `sub_areas.json` and `biome_groups.json`"; A6 "only the `bow_valley_slice` fixture"; A7 "`game/assets/` is all `.gitkeep`"; all B0/B1/B2 boxes unticked | Every claim is false, **flagged in four consecutive reviews and never fixed**. Actual: 30 scripts / 3,569 LOC, 4 autoloads, GUT 9.6.0 vendored, a 279-line five-job CI, all 8 data files valid, 12 authored world maps, 23 test scripts / 237 tests, two real assets. Its one still-partly-true row is `:72-75`, a single checkbox covering three items of which only `scenes/world/WorldMap.tscn` is genuinely absent. `status: active` makes this a trap for onboarding — retire or rewrite. |
| [export-setup.md](../../docs/export-setup.md):97 | "uploads everything as a workflow artifact (**14-day retention**)" | **Newly false as of `d7a2a61`** — the `retention-days` key was orphaned out of the upload step (see B1), so artifacts use the repo default. Fixing B1 makes this true again; the row is here so the two don't drift apart. |
| [testing-setup.md](../../docs/testing-setup.md):69-71 | "the suite currently reports **16 scripts / 134 tests / 2,779 asserts**" (dated 2026-07-30) | Measured this session: **23 scripts / 237 tests / 3,032 asserts**. Stale at four consecutive reviews and corrected three times — worth generating from the JUnit XML rather than maintaining by hand. |
| [testing-setup.md](../../docs/testing-setup.md):22 | "**Godot 4.6** (stable). Any 4.6.x patch is fine" | Contradicts `ci.yml:9-15` and ADR 0012, which pin the exact patch deliberately because export-template paths are version-keyed. Carried unfixed. |
| [testing-setup.md](../../docs/testing-setup.md):142-147 | "### Known gap … Consider adding a CI assertion that the run actually collected tests" | Partly implemented at `ci.yml:106-120` — but only for the zero case, and its error message is unreachable under `set -e`. See V6. |
| [testing-setup.md](../../docs/testing-setup.md):35-37 | "The repo's root `.gitignore` excludes `/tools/`" | It excludes `/tools/*` then re-includes `*.py`, `*.sh`, `*.gd` and `/tools/tests/` (`.gitignore:17-28`); 11 files under `tools/` are tracked. The sentence reads as though nothing in `tools/` is committed. |
| [roadmap.md](../../docs/roadmap.md):49 | "A fully spanned overpass yields a zero-mortality route" | Still predates [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md); "fully spanned" now means a valid **span** (two-sided core), not full segment coverage. The code is correct; the criterion's wording is not. Carried unfixed from two reviews — and C4's measurement now gives it a number to cite. |
| [roadmap.md](../../docs/roadmap.md):148, :155-156 | The 2026-08-06 decision block cites Phase 2's exit criteria as `:98-108` and its Implements list as `:80-92` | The same session's +74-line insertion moved them: exit criteria are now `:114-122`, Implements `:94-107`. The 08-06 log flags this about its own text; the roadmap itself does not. Cite the heading, not the line. |
| [test-plan.md](../../docs/test-plan.md) §11 | P0 coverage table presented as the first-playable bar | 35 of 43 named tests have no matching function (81%, re-measured). See V3. Carried unfixed. |
| [architecture.md](../../docs/architecture.md):52-68 | Lists 14 systems and UI scripts that do not exist, plus scene files for UI built in code | All Phase 3–6, so not a regression — but the table reads as a description of the codebase and overstates it. Split into *planned* vs *built*. Carried unfixed. |
| [architecture.md](../../docs/architecture.md):69 | Lists `ui/base_screen.gd` with a companion `ui/BaseScreen.tscn` | The script exists; `BaseScreen.tscn` does not, **deliberately** — every screen in this project is code-instantiated. Carried unfixed. |
| [game/CLAUDE.md](../../game/CLAUDE.md):88-100 systems table | Names 13 system files, of which **6 are built** (`habitat_manager`, `species_manager`, `infrastructure_manager`, `save_manager`, `connectivity_graph`, `population_model`) — so **24 of the 30 built scripts are absent**, including `simulation.gd` (the tick loop), `main.gd` (the largest file), all four autoloads, all three constants files, `world_renderer.gd` and **all ten UI scripts** | `game/CLAUDE.md:102-104` states its own rule — *"Add a row here whenever a new system is created"* — so this is a convention miss that has grown for three consecutive weeks. Worst single omission: there is no UI section at all, in the fortnight UI grew by three scripts. |

## 5. Risks & open questions

- **The pipeline broke in the same commit that fixed the pipeline.** `d7a2a61`
  closed V2 — genuinely good work, with the pack gate taught to read three
  container formats and tested end to end against real artifacts — and
  simultaneously orphaned a workflow key into a shell block one line below where
  it belonged. Worth naming as a category: this repo's CI changes are reviewed
  by reading them, and a YAML file that parses is not a workflow that runs.
  `bash -n` and a schema lint would both have caught it in a second. V6 and V7
  are two more of the same shape, found only because this review went looking.
- **Five commits, including 1,044 lines of new simulation code, have never been
  seen by CI.** Not a long divergence — four landed within 51 minutes of the
  last push and the fifth a day later — but the effect is the same: V2 and C4
  are closed in the review record and unproven in the pipeline, and the save
  system has never run anywhere but this machine and Brent's.
- **The review measured a moving repo.** `7e10b0c` landed mid-review and closed
  two items this note's first draft had filed under *Deferrable*, one of them
  described as the largest gameplay gap in the tree. That draft's figures were
  correct when taken and wrong within six hours. A build review is a snapshot;
  it should say which commit it is a snapshot of, and this one does — `7e10b0c`.
- **`v0.1.0` grew a calendar-time dependency and nothing re-planned around it.**
  ADR 0018 landed on 2026-08-10 and its runbook says start Apple enrolment
  first; [[../daily-logs/2026-08-10]]'s own "next session" list does not mention
  it. That is why B5 is a blocker rather than a core item: it is small, it is
  nobody's favourite task, and it silently sets the release date.
- **The first thing a player sees is aimed at the wrong place** (C4). Small,
  measured, one line, undecided since 08-10. It should not survive into a
  release note.
- **`smoke-windows` has two failure modes stacked on each other.** B1 fixes the
  first. The second — whether Git Bash on `windows-latest` provides `stdbuf`,
  which `tools/smoke_boot.sh:83-90` hard-requires — is untested and its failure
  message names macOS. Do not read a green `smoke-windows` as evidence about the
  `.exe` until the job has actually run to completion once.
- **This review could not observe CI.** `gh` is not installed and
  `git fetch origin` fails with *Host key verification failed*. Nothing here
  should be read as a claim about CI's current status. Relatedly, `origin/main`
  is the local remote-tracking ref, last updated **by a push** on 2026-08-10
  21:49 (`git reflog show origin/main --date=iso`), not by a fetch — so "5
  unpushed" is true as of that push and would be wrong if `main` moved
  elsewhere.
- **The sandbox cannot export.** `~/.local/share/godot/export_templates/` is
  empty, so the build signal is a source boot plus the pck gate on stale
  artifacts. V4 (an arm64 preset) would let a future review boot a real one.

## 6. Suggested next-week focus

1. **B1 — fix `ci.yml:279`** (S). Ten minutes, and it must come before the push
   or the next session is debugged through a false red.
2. **B2 — push the five commits** (S). From a real terminal on the Mac, not the
   sandbox. Watch all five jobs; three of them have never run, and one of them
   guards a simulation system nothing external has ever compiled.
3. **B5 — start Apple enrolment and make the GPG key** (S, days of calendar).
   Do it the same morning as B1 and B2, because it is the only thing here whose
   duration you cannot influence afterwards.
4. **B3 — export and verify `HEAD`** (M). The first launch that includes the
   title screen, the menu, the credits screen and quicksave — and the first time
   anyone checks that the project's primary licence-compliance mechanism is
   legible.
5. **C4 then C5 — decide the camera, then do the QA pass** (S + S). In that
   order, so the pass looks at what ships. Same session as B3.

B4 (packaging) and C1–C3 (signing config, `.dmg`, version fields) are the week
after, and B6 waits on all of them. If B5 starts on schedule the release waits
only on Apple; if it slips, it slips the release one-for-one — which is the
entire reason it is ranked third rather than last.

---

## Verification

Labels per the harness's Step 6 rule. **Confirmed** = traced to something read
or run *this session*, against `7e10b0c`. **Assumed** = the reasoning is sound
but nothing was checked. **Unverifiable** = not checkable from this session;
inferring a state from a daily log is explicitly not evidence.

**Confirmed (run or read this session, at `7e10b0c`):**

- Suite **23 scripts / 237 tests / 3,032 asserts, all passing, exit 0**.
  Python tools **58 tests, OK**.
- Both headless boots clean — `Title screen ready`, and
  `Tutorial loaded… Press F1 for credits. F5 saves, F9 loads.`
- **30 scripts / 3,569 LOC** under `game/scripts/`; 23 `*_test.gd`; 9 scripts
  with no named test; `species_registry.gd` the only one with zero test contact.
- `ci.yml` is **279 lines**, five jobs at `:24,:57,:74,:122,:255`; its final line
  is `retention-days: 14` inside a `run:` block;
  `bash -c 'set -euo pipefail; retention-days: 14'` → **exit 127**;
  `origin/main:ci.yml:188` has the key under `with:`; `if: always()` appears at
  `:225` and `:238` (steps) and `smoke-windows` has bare `needs: export` (`:257`).
- `git rev-parse HEAD` = `7e10b0c…`, `origin/main` = `0c31c85…`,
  `rev-list --left-right --count` = `0  5`; `git reflog show origin/main
  --date=iso` → last push `2026-08-10 21:49:48 -0500`; the five unpushed commits
  dated `2026-08-10 21:58:05` through `2026-08-11 20:39:08 +0000`.
- `git tag -l` → 0 tags; `builds/` → `.gitignore`, `.gitkeep`, one empty dir;
  `docs/release-notes/` → 0-byte `.gitkeep` only.
- `check_pck_contents.py` on the 2026-07-28 Linux pack → **exit 1**, 244
  development-only paths, *built by Godot 4.6.0*; `du -sh` → **411M**; files
  dated 2026-07-27 and 2026-07-28.
- `export_presets.cfg`: `:26,57,88` `embed_pck=false`; `:25,56,87,132`
  `export_console_wrapper=1`; `:117` macOS `export_path` ends `.zip`; `:128`
  `distribution_type=0`; `:138-139` empty version strings; `:145`
  `codesign/codesign=1`; `:147-148` empty team id and identity; `:173`
  `notarization/notarization=0`; `:94,133` `application/icon=""`; `:100,140`
  copyright set; four presets, arm64 at `:32-62`; `exclude_filter` on all four.
- `project.godot:17` `config/version="0.1.0"`, `:23` `run/main_scene=…TitleScreen.tscn`,
  `:28-31` the four autoloads, no `config/icon`.
- `roadmap.md`: Phase 1 exit criteria `:45-56`, Phase 2 `:114-122`, "toolbar
  tool" P0 at `:96`, P1 group `:99-100`, the 08-06 decision block's stale
  self-citations at `:148,:155-156`.
- `test-plan.md` §11 → 43 named tests, 35 with no matching `func test_`, 81%
  (recomputed by script).
- `tools/ship.py:83` `STALE_LOCK_SECONDS = 120` and `:381-416 check_lock()`
  clears a stale lock; `.git/index.lock` present, 0 bytes, mtime
  `2026-08-11 15:39:54 -0500`.
- `tools/smoke_boot.sh:83-90` requires `stdbuf`/`gstdbuf`;
  `build_encyclopedia.py:668,671,675` writes and never deletes;
  `deploy-website.yml:49-56` gates on `git diff --quiet`;
  `ci.yml:115` `grep … | wc -l` under `set -euo pipefail`.
- `website/index.html:56` "Download for Mac, Windows & Linux", `:286` footer
  link; `website/CLAUDE.md:79` "2. Placing habitats"; `export-setup.md:110,119`.
- `7e10b0c` touched 13 files, +1,044 −13, adding `save_manager.gd` (106),
  `game_state_test.gd` (202), `save_manager_test.gd` (131);
  `simulation.gd:124 resync_agents()`; `game_state.gd:75 from_dict()`.
- `game/CLAUDE.md:88-100` names 13 systems, 6 of them built.
- 22 `.gitkeep` files, 19 in directories with other content.
- ADR 0017 and ADR 0018 contents, and `signing-runbook.md` A1–A8 / B1–B4 / C2 /
  §Known gotchas / §Suggested order of work, as quoted.

**Assumed:**

- That `smoke-windows` would otherwise pass. The `retention-days` line
  guarantees exit 127; whether the `.exe` boots under Git Bash — and whether
  Git Bash even provides `stdbuf` — is untested by anything, anywhere.
- That fixing B1 restores the 14-day retention rather than the repo default —
  read from `origin/main`'s copy of the file, not from GitHub's settings.
- That `export/distribution_type=0` may need to change for notarization (C1).
  The runbook's A5 table does not mention it and the Godot docs were not
  reachable from this session.
- That `zero stubs` holds across `game/scripts/`. Judged by reading the file
  list and LOC, not by a defined stub test.
- Item sizings (S/M) throughout.

**Unverifiable this session:**

- **Any statement about CI's actual status.** `gh` is not installed;
  `git fetch origin` fails with *Host key verification failed*. No run, badge or
  log was consulted, and none should be inferred.
- Whether `origin/main` has moved since 2026-08-10 21:49 — the ref was last
  updated by a push, not a fetch.
- Whether the 2026-07-27/28 binaries launch. They are on disk; nothing here ran
  them, and this sandbox has no export templates to build new ones.
- Whether Git Bash on `windows-latest` ships `stdbuf` (M4 in the red-team
  report). The MSYS2 package index was not reachable.
- The 08-10 measurement figures (6.30 → 1.20 at t=100; 0 / 218 / 915 crossing
  uses) are quoted from [[../daily-logs/2026-08-10]] and
  `tools/measure_tutorial.gd`'s recorded output; the script was **not** re-run
  this session.
- Whether the HUD cue, the chime, the credits screen or the overlay look correct
  on a screen. This project's 237 tests have never examined a pixel.

### What the audits changed

This note was audited twice before delivery — a fact-integrity pass over every
figure, date and `file:line` citation, and a completeness red-team asking
whether anything needed for the build is missing and whether anything listed is
already done. Both ran against a draft, and both found real errors. Recorded
here rather than quietly fixed, because the pattern is the point:

- **The repo moved mid-review.** `7e10b0c` invalidated the suite counts, the
  script counts, the `game_state` coverage claim, and two *Deferrable* bullets.
- **A fabricated timespan.** The draft claimed "five days of work has never been
  seen by CI" and repeated it in a blocker, a risk and a next-week item. The
  reflog says the last push was the evening before, and four of the five commits
  landed within 51 minutes of it. The figure was invented at the sentence level
  and read as precision.
- **A case-sensitive `grep` that became a conclusion.** `grep -c download
  website/index.html` → 0 produced "the website has no download page at all".
  `grep -in` finds the site's primary call-to-action at `:56`. C6 is rescoped
  from *build one* to *add the copy*.
- **A blocker resting on a defect the tooling already handles.** The draft
  warned that `.git/index.lock` would stop `tools/ship.py`; `ship.py:381-416`
  was written specifically to clear it.
- **Six wrong citations** (`roadmap.md:98-108`, `export-setup.md:104-108`,
  `main.gd:117-138`, `export_presets.cfg:34`, `pre-build-checklist.md:72`,
  `project.godot:26-31`) and four wrong counts (largest tool, untested tool
  count, omitted `CLAUDE.md` rows, shadowed `.gitkeep` files).
- **Misframed measurements.** The draft quoted C4 as "7.30 → 0.00", which is the
  t=2000 endpoint the 08-10 log explicitly says is meaningless, and attached the
  wrong `uses` figure to the no-span arm.
- **Ten missing items**, of which four are now B4, C1, V6 and V7 — including the
  packaging gap that is the single clearest way a first-time downloader ends up
  with something that does not run.

---

## Related

- [[roadmap]] — Phase 1 `:45-56`, Phase 2 `:114-122`, and the logged decisions of
  2026-07-29, 2026-07-31, 2026-08-06
- [[pre-build-checklist]] — stale; see §4
- [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md),
  [ADR 0017](../../docs/adr/0017-licensing.md),
  [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
- [signing-runbook](../../docs/signing-runbook.md),
  [push-runbook](../../docs/push-runbook.md),
  [export-setup](../../docs/export-setup.md)
- Previous review: [[2026-08-04-next-build]]
- [[../daily-logs/2026-08-06]], [[../daily-logs/2026-08-09]],
  [[../daily-logs/2026-08-10]]
- [[../design/detour-cost-question]]
