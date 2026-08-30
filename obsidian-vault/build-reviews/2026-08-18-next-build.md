---
title: "Build Review — Next Build (2026-08-18)"
date: 2026-08-18
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> roadmap [[roadmap|Phases 1–2]]). One question: what work is needed to get
> there?

> [!info] Snapshot
> Measured against **`4119915`** (*docs(runbook): correct Steps 1-5 against what
> actually ran*, 2026-08-13 21:56 CDT) on branch
> `feat/save-load-and-agent-respawn`. The tree has not moved since; there are no
> commits between 2026-08-13 and today. Anything not traceable to something read
> or run this session is labelled in [§Verification](#verification).

## 1. Summary

- **Build case:** **FIRST working build**, for the seventh consecutive review, on
  the same three facts the harness names — *"there is a working build only if you
  can point to an actual export in `builds/` or a GitHub Release **and** it
  launches."* Checked this session: `builds/` holds `.gitignore`, `.gitkeep` and
  one empty `wildlife-crossing-linux-arm64/` directory (`du -sh` → 4.0K);
  `git tag -l` → **0 tags**; `docs/release-notes/` → a single 0-byte `.gitkeep`.
- **Target milestone & exit criteria:** roadmap
  [Phase 1](../../docs/roadmap.md) §*Exit criteria* and
  [Phase 2](../../docs/roadmap.md) §*Exit criteria*, as scoped by the logged
  decisions of 2026-07-29 (Bow Valley only) and 2026-08-06 (world map ships
  look-only). Every one of them is still met in code and green in tests.
- **Headline:** **6 blockers, 6 core tasks, 8 verification items.** The best week
  the pipeline has had — though the best parts of it are *reported* rather than
  confirmed. [[../daily-logs/2026-08-13]] records CI executing all five jobs
  green for the first time in project history, and a human launching a windowed
  macOS build of `HEAD`. Neither is checkable from this session (`gh` absent,
  `git fetch` fails), so both are treated throughout this note as that day's
  record, not as fact — see [§Verification](#verification). What *is* confirmed
  here: the Windows smoke gate was fixed by allowlisting rather than loosening
  and now has 11 tests behind it, the push runbook was corrected and then
  mechanised into `tools/fetch_build.py`, and the Python tool suite grew
  **58 → 86 tests**. Three things need naming.
  1. **Every item that stands between a green pipeline and a downloadable
     release is exactly where it was six days ago.** B4 (packaging), B5 (Apple
     enrolment), B6 (cut the release) and C1–C6 from [[2026-08-12-next-build]]
     are all open, unchanged, and verified open this session by reading the same
     files.
  2. **The one item that costs calendar time has now been skipped by two
     consecutive "next session" lists.** [[2026-08-12-next-build]] ranked Apple
     enrolment **third for the week** and said plainly that it is the only gate
     whose duration cannot be influenced afterwards. The 2026-08-13 log's
     next-session list — merge the PR, walk Step 5, then B4 — does not mention
     it, which is the identical omission that review flagged about the 08-10
     log. Nothing in the repo records enrolment or a GPG key having started, and
     the last word on it is [[../daily-logs/2026-08-10]]:146-147 saying so
     explicitly under *Open questions* — *"Signing prerequisites are not
     started"* — eight days ago. `README.md` contains no fingerprint. **That is
     why it is ranked first this week rather than third.**
  3. **`main` has not moved in eight days, and the review record is not in the
     repo.** `origin/main` is still `0c31c85` (pushed 2026-08-10 21:49, per
     `git reflog show origin/main --date=iso`); `origin/main..HEAD` is **10
     commits**. Everything closed since — the save/load system, the CI fixes, the
     runbook work — lives on a feature branch and PR #1. Separately, three vault
     files have been uncommitted since 2026-08-13: the previous build review with
     its two amendments, the `build-reviews/README.md` headline, and the 08-13
     log (untracked). **The document that says what is blocking the build is not
     in the repository**, so PR #1 does not carry it and a fresh clone does not
     have it.
- **Change since last review:** [[2026-08-12-next-build]] — **B1 closed**
  (`13857e0`, verified this session). **B2 and B3 advanced without closing**;
  **V5 half done**. Five commits landed, all on 2026-08-13: `13857e0`
  (retention-days), `aece807` (the 08-12 review), `6db1e3d` (Windows smoke
  allowlist), `10062ad` (`fetch_build.py`), `4119915` (runbook corrections).
  **Newly closed doc drift:** `export-setup.md:97`'s 14-day retention claim is
  true again. **Newly open:** nothing structural — which is itself the finding.
  **Corrected below:** 08-12's B3 acceptance treats the two runtime assets as
  unguarded; they are in fact guarded, just not by the gate it names (§2).

## 2. Current state (evidence)

Measured against `4119915` this session unless labelled otherwise in
[§Verification](#verification).

- **Systems:** **30 scripts / 3,569 LOC** in `game/scripts/`, unchanged from the
  last review — no `.gd` file was added or removed in the five commits. The four
  autoloads are registered at `game/project.godot:28-31`. Fourteen scripts named
  in `docs/architecture.md:52-68` are absent; all are Phase 3–6.
- **Data:** all **8** canonical files in `game/data/` present and valid JSON; all
  **12** `data/world/sub_area_*.json` valid, every cell's `tile` resolving to a
  `tiles.json` id. Every record carries every required field from
  `docs/data-schemas.md`. Unchanged since 2026-08-04.
- **Scenes & wiring:** `run/main_scene` is `res://scenes/TitleScreen.tscn`
  (`project.godot:23`); `Main.tscn` remains the playable root, reached from
  `title_screen.gd` or via `binary -- --skip-menu`.
  `scenes/world/Animal.tscn` is still referenced by nothing.
- **Tests:** GUT 9.6.0 via the vendored
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` —
  **23 scripts / 237 tests / 3,032 asserts, all passing**, exit 0. Identical to
  2026-08-12; no test file was added this week.
  `python3 -m unittest discover -s tools/tests -b` → **86 tests, OK**, up from
  58 (`test_smoke_boot.py` +11, `test_fetch_build.py` +17). **9 of 30 GDScript
  scripts have no named test file** — `main`, `title_screen`, `env_config`, the
  three constants files, and the autoloads `debug`, `event_bus`,
  `species_registry`. `species_registry.gd` remains the one script with **zero**
  test contact of any kind (`grep -rl SpeciesRegistry game/tests/` → nothing),
  and `grep -c Constants game/tests/data_validation_test.gd` → **0**.
- **Headless boot from source:** both boots clean against the pinned 4.6.3
  binary. Bare → `[I] Title screen ready`. `-- --skip-menu` →
  `[I] Tutorial loaded. Press B to build the Bow Valley overpass. Press M for
  the world map. Press F1 for credits. F5 saves, F9 loads.` No `ERROR:` or
  `SCRIPT ERROR` in either.
- **CI:** `.github/workflows/ci.yml`, **279 lines**, five jobs — `tools:24`,
  `dco:57`, `test:74`, `export:122`, `smoke-windows:256`. `GODOT_VERSION:
  4.6.3-stable` pinned at `:15`. `grep -n retention-days` returns exactly one
  line, `:243`, inside the `Upload build artifacts` step's `with:` block —
  **B1 is closed.** (The `smoke-windows` job moved `:255 → :256` as a result;
  that one-line shift is the whole diff of `13857e0` in this file.) The
  structural caveat from last review is unchanged: `if: always()` sits on two
  *steps* (`:225`, `:238`), not on the `export` job, and `smoke-windows` has a
  bare `needs: export` (`:258`) — so a failing export **skips** it rather than
  turning it red. "Green, not skipped" remains the only useful acceptance
  wording. **Whether any CI run has ever passed is Unverifiable this session:**
  `gh` is not installed and `git fetch origin` fails with *Host key verification
  failed*.
- **Build/export:**
  - `builds/` — `.gitignore`, `.gitkeep`, one empty directory. **No binaries.**
  - `wildlife-crossing-desktop-builds/` — **411 MB**, nothing in it newer than
    2026-08-01 (`find … -newermt 2026-08-01` → empty). Still the 2026-07-27/28
    artifacts that fail the repo's own pack gate and were built by Godot 4.6.0.
  - `git tag -l` → empty; `docs/release-notes/` → `.gitkeep` only.
    → **first build.**
  - No local export was attempted: `~/.local/share/godot/export_templates/` is
    empty in this sandbox (4.0K, no version directories).
- **Git:** branch `feat/save-load-and-agent-respawn`, `HEAD` = `4119915`, fully
  pushed (`rev-list --left-right --count origin/feat/…...HEAD` → `0  0`). Local
  `main` = `9d0ec58`; `origin/main` = `0c31c85`; `origin/main...HEAD` → **`0
  10`**. Working tree carries three modified/untracked vault files and nothing
  else. A 0-byte `.git/index.lock` is present, mtime **2026-08-13 22:04** —
  unchanged after a session's worth of git commands from this sandbox, which
  contradicts [[../daily-logs/2026-08-13]]'s explanation that *"the mount forbids
  `unlink`, so every git command leaves its lock behind"*. The repo now carries
  two accounts of this file — that one, and `tools/ship.py:382-384`, which still
  blames the `weekly-build-review` harness — and neither is supported. It is
  harmless either way: `ship.py:83,380-416` clears anything older than 120 s
  automatically. Filed in §4 as drift with an unknown correction rather than a
  known one.

### What the five commits actually changed

Worth recording, because three of them fixed gates rather than game code and
that is the shape of the week:

1. **`13857e0`** moved `retention-days: 14` out of the `smoke-windows` `run:`
   block and back under the upload step's `with:`. Closes 08-12 B1.
2. **`6db1e3d`** added `BENIGN_PATTERNS` to `tools/smoke_boot.sh:76-80` — three
   narrowly-worded at-exit engine diagnostics stripped before `FATAL_PATTERNS`
   are counted, with the stripped count printed on every run
   (`smoke_boot.sh:147-154`). One of the three names the two engine NavMesh
   parser RID types rather than the generic `were leaked at exit.`, so a leak of
   a game type still fails; the other two are the unreferenced-static-string and
   Variant-pool diagnostics. `tools/tests/test_smoke_boot.py` (11 tests, 8 on the failing
   side) is the first coverage `smoke_boot.sh` has ever had.
3. **`10062ad`** added `tools/fetch_build.py` + 17 tests: run-scoped download
   directories, refusal of a non-empty destination, `unzip` rather than Python's
   `zipfile` (which preserves neither the symlinks nor the executable bit an
   `.app` needs), and a glob for the bundle — because Godot names it from
   `config/name`, so it is `Wildlife Crossing.app`, not the export path's
   `wildlife-crossing`.
4. **`4119915`** corrected `docs/push-runbook.md` Steps 1–5 against what actually
   ran, including the missing `-s` the DCO gate would have rejected and the fact
   that a feature-branch push fires no jobs at all.
5. **`aece807`** committed the 08-12 review itself — though not its two
   amendments, which are still uncommitted.

### A correction to last review's B3

[[2026-08-12-next-build]] B3 asks the pack gate to confirm
`assets/audio/crossing_chime.wav` and `assets/sprites/crossing_cue.png` survive
export, on the grounds that `game/.gitignore:3` excludes `*.import` so both are
re-imported every run and *"nothing asserts they survive"*. The first half is
right and the conclusion is not. `tools/check_pck_contents.py` does not mention
assets at all — it asserts every `game/data/**/*.json` is present as `res://data/…`
and that no development-only path ships — but `main.gd:21` and `hud.gd:14`
**`preload()`** those two files, and a failed `preload` is a script-compile
failure, not a runtime one. The script would never reach
`[I] Tutorial loaded`, which is exactly `smoke_boot.sh:81`'s `SUCCESS_LINE`. So
the assets *are* gated, by the boot rather than by the pack check. Worth adding
an explicit assertion anyway (cheap, and it names the failure instead of leaving
an operator to read a boot log), but it is a V-item, not a B3 acceptance
criterion. Filed as V8.

### Exit criteria, criterion by criterion

Unchanged from [[2026-08-12-next-build]], re-run this session: every Phase 1 and
Phase 2 exit criterion is **met in code and green in tests**, and **three of them
have never been rendered to a human** — the crossing cue (visual + audio), the
locked-sub-area desaturation, and the connectivity overlay's orange→teal
treatment. `hud_test.gd` asserts state, not pixels; this project's 237 tests have
never examined one. The implied criterion — *an export of the current code
launches* — advanced this week: [[../daily-logs/2026-08-13]] records a windowed
macOS build of `HEAD` launching and running, the first any human has seen. The
keyed checklist behind it was not walked.

What is missing is still not gameplay logic. It is a release a stranger could
install.

## 3. Work needed for the first build

Ordered the way you'd actually do it. Numbering restarts each review; the
mapping from [[2026-08-12-next-build]] is B5→**B1**, B2→B2, B3→B3, B4→B4,
B6→**B6**, with C and V lists carried at their existing numbers. **B5 and V8 are
new**, both surfaced by this review's completeness audit.

### Blockers (nothing ships until these exist)

#### B1. Start the Apple enrolment and create the GPG key
- **Why it blocks:** carried from [[2026-08-12-next-build]] B5 and **promoted to
  first**. [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
  makes a signed, notarized macOS build part of what `v0.1.0` *is*, and
  [signing-runbook](../../docs/signing-runbook.md) says it plainly: *"Apple
  enrolment takes a few days. It is the only calendar-time gate left. Start it
  first."* It has now been ranked-and-skipped twice — the 08-10 log's next-session
  list omitted it, last review said so, and the 08-13 log's next-session list
  omits it again. Nothing in the repo records either prerequisite starting. Every
  day this sits is a day added to the release date that no amount of later effort
  removes, and C1, C2 and B6 all queue behind it.
- **Files/areas:** none yet; later, the public key committed to the repo and its
  fingerprint in `README.md` (which currently contains no fingerprint —
  `grep -in fingerprint README.md` → nothing).
- **Acceptance:** runbook **A1–A4 and B1–B2**, not just A1–A2 — enrolment
  submitted; a **Developer ID Application** certificate issued (an "Apple
  Development" certificate signs fine and fails notarization); the Xcode licence
  accepted (A3); and the **App Store Connect API key** created and stored (A4,
  `runbook:90-101` — Apple lets you download the `.p8` exactly once, and
  `notarytool` needs it plus the Issuer ID and Key ID). Plus a GPG signing key
  with its revocation certificate stored and the public key published.
- **Do the GPG half first and separately.** `signing-runbook.md` §Suggested order
  lists the key as *"Blocks on: nothing"* — it needs no Apple account, takes
  minutes, and it is what C6's fingerprint copy actually waits on. Bundling the
  two into one item is convenient for scheduling and has the side effect of
  putting a `gpg --full-generate-key` behind a multi-day enrolment. Treat them as
  B1a (GPG, today) and B1b (Apple, today and then wait).
- **Depends on:** none. **Costs $99/year**; the decision is recorded in ADR 0018,
  the spend has not happened.
- **Size:** S effort, **days of calendar**
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A1–A4, B1–B2,
  §Suggested order of work, §Known gotchas; ADR 0018;
  [[2026-08-12-next-build]] B5.

#### B2. Merge PR #1, and commit the vault files first
- **Why it blocks:** carried from [[2026-08-12-next-build]] B2, which asked for
  `git rev-list --count origin/main..HEAD` → 0. The commits are pushed —
  `origin/feat/save-load-and-agent-respawn` is level with `HEAD` — but
  `origin/main` has not moved since 2026-08-10 21:49 and is **10 commits**
  behind. Until it merges, `main` does not contain the save/load system, the CI
  fixes, or the runbook work, and the repo's `main` branch is not in the state
  the root `CLAUDE.md` requires of it. There is a second half: three vault files
  have been uncommitted since 2026-08-13 — `build-reviews/2026-08-12-next-build.md`
  (both amendments), `build-reviews/README.md`, and the untracked
  `daily-logs/2026-08-13.md` — so the project's own record of what blocks the
  build exists on one machine. They must be committed **and pushed to the branch
  before the merge**, or PR #1 will not carry them and they will need a second
  round trip. This note makes four paths — the index line is an edit to
  `README.md`, which is already one of the three.
- **Files/areas:** no code change.
  [push-runbook](../../docs/push-runbook.md); `tools/ship.py`.
- **Acceptance:** the vault files committed with `-s` (the DCO gate added in
  `792b237` rejects an unsigned commit) and pushed; PR #1 observed green with
  all five jobs including `smoke-windows` **green, not skipped**; merged; and
  after a fetch, `git rev-list --count origin/main..HEAD` → 0.
- **Depends on:** none. Run `ship.py --execute` from a real terminal on the Mac,
  not the Cowork sandbox (`ship.py` says so in its `OSError` branch).
- **Size:** S
- **Refs:** [push-runbook](../../docs/push-runbook.md);
  [[../daily-logs/2026-08-13]] §Open questions;
  [[2026-08-12-next-build]] B2.

#### B3. Walk the windowed verification checklist against a build of `HEAD`
- **Why it blocks:** carried from [[2026-08-12-next-build]] B3 and **genuinely
  advanced**. All three packs passed the contents gate in CI, the Linux and
  Windows binaries both boot, and a windowed macOS build of `HEAD` launched and
  ran on 2026-08-13. What remains is the part only a human can do, and it is the
  part with the licence obligation in it: the credits screen is the primary
  compliance mechanism under
  [ADR 0017](../../docs/adr/0017-licensing.md), and if it renders illegibly the
  project is out of compliance and 237 unit tests cannot tell you.
- **Files/areas:** no code change expected. `tools/fetch_build.py` (new, and
  written for exactly this); [push-runbook](../../docs/push-runbook.md) Step 5.
- **Acceptance:** `tools/fetch_build.py <run-id> --check`, then Step 5 walked to
  completion against that build: the menu appears and `Play` works; the credits
  screen opens from the menu **and** from `F1` and is **actually read** for
  legibility and scrolling; the HUD message line is legible; the "+N crossed
  safely" cue is **seen** firing and the chime **heard**; every key `main.gd`
  owns is pressed — **B**, **M**, **F1**, left-click, **Enter**, **Escape**,
  **F5**/**F9** — with an F5 / quit / relaunch / F9 round-trip, since quicksave
  to `user://` (`save_manager.gd`) has never run from an exported binary where
  the sandbox and permissions differ from the editor; and the `codesign -dv`
  output **recorded**, which 08-13 explicitly did not do and which C1 needs.
- **Depends on:** B2 (so the run being fetched is a `main` run), though it can be
  walked against the PR run today if the merge slips. Machine-gated the same way
  B2 is, and for a second reason: `fetch_build.py` shells out to
  `gh run download`, so it needs `gh` installed and authenticated on the Mac.
  Neither B2 nor B3 can run from this sandbox.
- **Size:** M
- **Refs:** [push-runbook](../../docs/push-runbook.md) Step 5;
  [[../daily-logs/2026-08-13]]; ADR 0017; [[2026-08-12-next-build]] B3.

#### B4. Decide how a Release ships something a stranger can run
- **Why it blocks:** unchanged and re-verified this session.
  `export_presets.cfg:26,57,88` set `binary_format/embed_pck=false`, so the Linux
  build is `wildlife-crossing.x86_64` **+** `wildlife-crossing.pck` and the
  Windows build is `.exe` **+** `.pck` **+** a console wrapper
  (`:87` `export_console_wrapper=1`; the flag is on all four presets at
  `:25,56,87,132`). A GitHub Release asset is a single
  file: a downloader who takes `wildlife-crossing.exe` on its own gets a Godot
  runtime with no game and no error that explains why. Compounding it, GitHub
  Actions artifacts do not preserve the Unix executable bit — which is why
  `ci.yml` has to `chmod +x` the Windows binary before booting it — so a Linux
  binary routed through the CI artifact into a Release arrives non-executable.
  `tools/fetch_build.py` now solves this for *the maintainer*, by unpacking with
  `unzip`; it does nothing for a downloader.
- **Choose the archive, not `embed_pck`.** Both routes produce one runnable file;
  only one keeps the project in licence compliance. Root `CLAUDE.md` and
  [ADR 0017](../../docs/adr/0017-licensing.md):119-121 require every exported
  binary to ship `LICENSE` and `THIRD-PARTY-NOTICES.md` — *"a licence
  obligation, not a nicety"* — and `ci.yml:224-232` places both in
  `builds/<platform>/`, which only reaches a downloader if the **archive** is the
  published asset. A bare embedded-pack `.exe` passes the "one file" test and
  quietly breaks ADR 0017.
- **Files/areas:** `game/export_presets.cfg`; `.github/workflows/ci.yml` export
  and upload steps **and the `smoke-windows` job** (`:276-279` hardcodes
  `BIN=builds/wildlife-crossing-windows-x86_64/wildlife-crossing.exe` and
  hard-fails if it is absent, so any change to the artifact's shape must land
  with it); `tools/check_pck_contents.py` (`:51 resolve_pck`) and
  `tools/inspect_pck.py`, where the pack parser actually lives
  (`check_pck_contents.py:35`) and which has no test file of its own.
- **Acceptance:** each published asset is **one file that runs on a clean
  machine**, verified by extracting into an empty directory and launching with no
  reliance on a sibling file; the Linux binary is executable after download;
  `LICENSE` and `THIRD-PARTY-NOTICES.md` are **inside** the published asset; and
  the console wrapper is dealt with — nothing currently says which of
  `wildlife-crossing.exe` and `wildlife-crossing.console.exe` a downloader is
  meant to run.
- **Depends on:** none now that B1 (08-12) is closed; sequence after B2 so the CI
  change lands on a current `main`. **Land it as one commit** with the
  `smoke-windows`, `inspect_pck.py` and `check_pck_contents.py` updates, or the
  PR carrying it is red on its own gates.
- **Size:** M
- **Refs:** `export_presets.cfg:25-26,56-57,87-88`;
  [export-setup](../../docs/export-setup.md); ADR 0018 §Decision;
  [[2026-08-12-next-build]] B4.

#### B5. Confirm the repository is public before the Release is cut
- **Why it blocks:** **new this review, and no previous review has named it.** A
  GitHub Release on a private repository is not downloadable by a stranger, which
  is the entire definition of "first working build" this harness runs on.
  [ADR 0017](../../docs/adr/0017-licensing.md):9-13 opens on the premise that
  *"the repository has been private to date"* and that licensing is what lets it
  *"go public"*; ADR 0018 §Consequences reasons about *"a real security property
  of a public repo"*; `ci.yml:44-53` justifies the DCO gate as something needed
  *"before the repo is announced publicly"*. Three separate decisions are staged
  for a transition that **no document schedules, gates, or records as done** —
  `grep -rn -i 'repo public\|go public'` across `docs/`, `obsidian-vault/`,
  `README.md`, `CONTRIBUTING.md` and `CLAUDE.md` returns only those ADR sentences
  and one daily-log line. Meanwhile `website/index.html:55` already points the
  site's primary call to action at
  `https://github.com/brenthumphries/wildlife-crossing/releases`.
- **Files/areas:** GitHub repository settings; whichever of `README.md`,
  `CONTRIBUTING.md` and `docs/CLAUDE.md` should carry the record.
- **Acceptance:** either the repo is confirmed public and that is written down
  once, or the flip is scheduled as an explicit step of B6 with its own
  pre-flight check (secrets scan, `export_presets.cfg` diffed for the credentials
  the signing runbook warns Godot writes into it, `tools/_to_delete/` gone). The
  answer belongs in a log either way; a release that lands behind a private repo
  is discovered by a stranger, not by us.
- **Depends on:** none, but it must be settled **before** B6 rather than
  discovered during it.
- **Size:** S — assuming it is already done, in which case the work is the
  sentence that records it.
- **Refs:** ADR 0017 §Context; ADR 0018 §Consequences; `ci.yml:44-53`;
  `website/index.html:55`.

#### B6. Cut `v0.1.0` — release note, tag, signed GitHub Release
- **Why it blocks:** this is the item that decides the build case, and seven
  consecutive reviews have answered "first build" on the same three facts —
  empty `builds/`, zero tags, empty `docs/release-notes/`. All three are still
  true, verified this session.
- **Files/areas:** `docs/release-notes/v0.1.0.md`; a `v0.1.0` tag; a GitHub
  Release carrying the macOS image, the Windows and Linux packages from B4,
  `SHA256SUMS.txt` and its detached signature; `README.md` (key fingerprint);
  root `CLAUDE.md`'s "binaries via GitHub Releases, not committed" policy.
- **Acceptance:** the release note follows [docs/CLAUDE.md](../../docs/CLAUDE.md)
  format and states **all four** scope facts — Bow Valley only, the world map is
  look-only, placeholder art and the default Godot window icon
  (`export_presets.cfg:94,133` `application/icon=""`, no `config/icon` in
  `project.godot`), and which artifacts are signed vs not and how to verify; the
  tag exists; `spctl`/`stapler` verify the notarized image per runbook A7; the
  GPG signature verifies per B4 of the runbook; and the binaries report their own
  version (C3). Plus the runbook's own gotcha: **clear `builds/` first.** B3 of
  the runbook sweeps that directory with a `find` to build the manifest, and
  *"stale files in `builds/` get signed too"* — `builds/wildlife-crossing-linux-arm64/`
  is sitting there now, empty today and populated the moment V4 goes the
  "export it" way.
- **Depends on:** B1, B3, B4, B5, C1, C2, C3, C5, C6.
- **Size:** M
- **Refs:** ADR 0018 §Decision, §Follow-on work;
  [signing-runbook](../../docs/signing-runbook.md) A6–A8, B3–B4, C2;
  [[2026-08-12-next-build]] B6.

### Core build work

#### C1. Configure macOS signing in the export preset
- **Why:** unchanged and re-measured this session — all four keys are still at
  their defaults: `export_presets.cfg:145` `codesign/codesign=1` (Built-in
  ad-hoc; Xcode codesign is `3`), `:173` `notarization/notarization=0`
  (Disabled; Xcode notarytool is `2`), `:147` `codesign/apple_team_id=""`,
  `:148` `codesign/identity=""`. B6's acceptance asks `spctl` and `stapler` to
  verify, which is impossible until these change.
- **Files/areas:** `game/export_presets.cfg` preset 3. The runbook's warning
  stands: **the file is tracked and Godot writes secrets into it** — use the
  `GODOT_MACOS_NOTARIZATION_*` environment variables and diff before every
  commit. Leave the `Debugging` entitlement `false`.
- **Acceptance:** a signed test export from Brent's Mac that `spctl -a -vvv`
  accepts and whose ticket `stapler validate` confirms (runbook A7 — *"do not
  trust the export log"*). Also settle whether `export/distribution_type=0`
  ("Testing", `:128`) needs to change; the runbook's A5 table does not mention it
  and the Godot docs were not reachable from this session either. B3's recorded
  `codesign -dv` output is the first input to this.
- **Depends on:** B1 (the certificate and the API key).
- **Size:** M
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A5, A7,
  §Known gotchas; ADR 0018 §Decision.

#### C2. Change the macOS export target from `.zip` to `.dmg`
- **Why:** ADR 0018 requires it for two independent reasons: **you cannot staple
  a notarization ticket to a `.zip`** (runbook §Known gotchas), and the `.zip` is
  why `LICENSE` and `THIRD-PARTY-NOTICES.md` land *beside* the archive rather
  than inside the bundle — the standing macOS notice gap recorded in
  [[../daily-logs/2026-08-09]] and acknowledged in `ci.yml:220`'s own
  *"Known gap"* comment. `export_presets.cfg:117` still ends `.zip`.
- **The interaction is not the one the previous review described.**
  [[2026-08-12-next-build]] C2 warned that changing the container breaks the
  pack gate. It does not: `ci.yml:169-170` passes an **explicit output path** to
  `--export-release`, which overrides the preset's `export_path`, so CI keeps
  producing a `.zip` and the gate keeps passing whatever `:117` says. The real
  consequence is worse and quieter — **the artifact that actually ships is gated
  by nothing.** The release `.dmg` is built locally on the Mac
  (`signing-runbook.md:188`), never in CI, and `check_pck_contents.py`
  (`resolve_pck`, `:53-80`) accepts only a `.pck`, a `.app` directory or a
  `.zip`. It has no `.dmg` path and no item requires running it against the
  release image. ADR 0018 §Follow-on work names exactly this: *"a checksum
  attests to the integrity of contents that nothing has verified."*
- **Files/areas:** `game/export_presets.cfg:117`; `tools/check_pck_contents.py`
  (teach `resolve_pck` to mount or read a `.dmg`, or add an explicit
  "check the mounted `.app`" step to the local release path);
  `tools/tests/test_check_pck_contents.py`; `docs/signing-runbook.md` §B.
- **Acceptance:** the macOS preset exports a `.dmg`; **the pack inside the
  shipped image passes `check_pck_contents.py`**, run against the image or the
  `.app` mounted from it, and that run is recorded in the release log; its tests
  cover the new input; CI's export job stays green; `LICENSE` and
  `THIRD-PARTY-NOTICES.md` are inside the image, added **before** signing
  (modifying a signed bundle silently invalidates it).
- **Depends on:** none technically; do it in the same pass as C1 so the image is
  signed once.
- **Size:** M
- **Refs:** ADR 0018; [signing-runbook](../../docs/signing-runbook.md) A5–A6;
  [[../daily-logs/2026-08-09]].

#### C3. Set the version metadata the export presets never got
- **Why:** re-measured this session — `export_presets.cfg:138-139` still have
  `application/short_version=""` and `application/version=""`, and the Windows
  preset has no `file_version`/`product_version` at all, while `project.godot:17`
  carries `config/version="0.1.0"`. An empty `CFBundleShortVersionString` is a
  notarization risk, and ADR 0018 explicitly promises *"the macOS binary finally
  reports its own version … set in the same pass"*.
- **Files/areas:** `game/export_presets.cfg` presets 2 and 3.
- **Acceptance:** `application/version` and `application/short_version` read
  `0.1.0`; Windows `file_version`/`product_version` set; a built binary's
  reported version matches the `v0.1.0` tag.
- **Depends on:** none. Cheapest item on the list, and on B6's critical path; do
  it while waiting on Apple.
- **Size:** S
- **Refs:** ADR 0018 §Consequences;
  [signing-runbook](../../docs/signing-runbook.md) A5.

#### C4. Decide the tutorial camera focus
- **Why:** `main.gd:18` still sets `CAMERA_FOCUS_COORD := Vector2i(13, 6)` with
  the docstring *"a tile on the tutorial highway, so the first view shows the
  crossing site"*. The 2026-08-10 measurement found row 6 has zero measured
  deaths and about 10 crossing uses, while 70 of 73 baseline deaths happen on
  rows 0–2 and row 1 logs 192 uses. The opening camera points at the one part of
  the tutorial where nothing happens — on the first screen of the first build a
  stranger will ever see. Flagged to the owner on 08-10, still undecided eight
  days later, and it is one line.
- **Files/areas:** `game/scripts/main.gd:18`; optionally a test asserting the
  focus row is one the measurement found active.
- **Acceptance:** a one-line change or an explicit recorded decision to keep it;
  either way the answer is in a log **before** C5's QA pass runs.
- **Depends on:** none. **Needs an owner call.**
- **Size:** S
- **Refs:** [[../daily-logs/2026-08-10]] §Open questions;
  [[../design/detour-cost-question]]; `tools/measure_tutorial.gd`.

#### C5. Visual + audio QA pass, written down
- **Why:** owed since 2026-07-08 and kept in v0.1.0 scope by the 2026-08-06
  decision. The 08-13 windowed launch got as far as *it ran*; none of the Phase 2
  visual criteria were observed. Three of the roadmap's exit criteria are met
  only in code and have never been looked at.
- **One of them cannot be observed at all, and the pass should know that going
  in.** Phase 2's fourth exit criterion — *"Confirm passes the correct
  `(segment, sub_area)` into the construction step; click-outside and Escape
  behave per spec"* — runs through `ConfirmPanel`, and `main.gd:215-221` says
  outright that the panel is **"unreachable from the map screen in v0.1.0"**
  since `WorldSelectMap.tscn:12` sets `mouse_filter = 0` (STOP) and the in-map
  segment renderer was deferred on 2026-08-06. `B` goes straight to build mode
  (`main.gd:141`). The criterion is met in tests (`confirm_panel_test.gd`) and is
  undemonstrable by hand. The 08-06 decision deferred the renderer; it did not
  record that deferring it makes an exit criterion unobservable in the shipping
  build. Worth a line in the log, and worth not sending a QA pass looking for it.
- **Files/areas:** no code change expected; findings feed back into
  `world_renderer.gd`, `connectivity_overlay.gd`, `hud.gd`, `credits_screen.gd`.
- **Acceptance:** a note in `obsidian-vault/daily-logs/` confirming each Phase 2
  visual criterion observed on screen (locked desaturation + lock indicator;
  overlay orange→teal at ~40%, appearing only in segment mode and clearing), the
  crossing cue visible **and** audible once per coalesced window, the HUD message
  line legible, the credits screen legible and scrollable, a quicksave/quickload
  round-trip in the export, and — still never captured by any log — **the Godot
  version installed on Brent's Mac**.
- **Depends on:** B3 (observed in the export, not the editor), C4 (decide the
  camera first, so the pass looks at what ships). Best done in the same session
  as B3.
- **Size:** S
- **Refs:** roadmap Phase 2 exit criteria; the 2026-08-06 decision block;
  [[2026-08-12-next-build]] C5.

#### C6. Add the verification copy to the download section
- **Why:** ADR 0018 §Follow-on work requires *"`README.md` and the website
  download section need the key fingerprint and the unsigned-Windows note"*. The
  section exists — `website/index.html:56` is the site's primary call to action,
  a "Download for Mac, Windows & Linux" button pointing at the Releases page,
  with footer links at `:286` and in `user-guide.html:425`. What is missing is
  the copy: `grep -in 'fingerprint\|gpg\|sha256\|smartscreen\|unsigned'` over
  `README.md` and `website/index.html` returns **nothing**.
- **Files/areas:** `website/index.html`, `README.md`; `website/CLAUDE.md`
  conventions.
- **Acceptance:** the download area names each published asset, states plainly
  that Windows is unsigned and what SmartScreen will say, gives the GPG
  fingerprint and the two verification commands, and does **not** imply the GPG
  signature suppresses any OS warning (runbook C2 is explicit about that
  conflation). **And it says how to run the thing** — nothing anywhere does:
  `user-guide.html` contains no install instructions (`grep -in
  'download\|install\|releases\|\.dmg\|\.exe'` → one footer link at `:425`) and
  `README.md` has no download section at all. Open the image and drag to
  Applications; `chmod +x` the Linux binary; keep the `.pck` beside the binary if
  B4 goes that way. The executable-bit problem B4 identifies is a
  *downloader-facing* problem and this is the only item that writes copy for it.
- **Depends on:** B4 (the asset list), B1a (the GPG fingerprint — not the Apple
  half), and **B2**: `deploy-website.yml:8-11` publishes only on push to `main`
  under `website/**`, so the copy is inert until a merge lands.
- **Size:** S
- **Refs:** ADR 0018 §Follow-on work;
  [signing-runbook](../../docs/signing-runbook.md) C2; `website/CLAUDE.md`.

### Verification (tests, CI, export)

#### V1. Add `env_config.gd` coverage
- **Why:** carried unchanged; confirmed absent again this session
  (`game/tests/` has 23 `*_test.gd` and none is `env_config_test.gd`). Still the
  only untested script carrying real branching logic: it owns per-terrain
  mortality lookup and the resolution order (override → OS env →
  `DEFAULT = 0.20`, `env_config.gd:8,21-31`) — exactly what the Phase 1 criterion
  *"deaths at the configured env-var rate"* rests on.
- **Files/areas:** new `game/tests/env_config_test.gd`.
- **Acceptance:** resolution order covered end to end; suite reaches 24 scripts.
  GUT only discovers a new `*_test.gd` after a re-`--import`.
- **Depends on:** none.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md); roadmap Phase 1 exit criteria.

#### V2. Cover `species_registry.gd` and the constants files
- **Why:** carried unchanged. `species_registry.gd` (53 LOC) is still the one
  script in the tree with **zero** test contact of any kind, and
  `grep -c Constants game/tests/data_validation_test.gd` → **0**, so no test
  asserts the three constants files against the values `data-schemas.md` §10
  specifies normatively. They are not untouched — `confirm_panel_test.gd:116,129`,
  `connectivity_overlay_test.gd:137,144-152` and `world_select_controller_test.gd:7-8`
  read `SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX`/`DEACTIVATE_PX` as *inputs*,
  which is the opposite of asserting them: if the constant drifted from §10 those
  tests would happily keep passing against the drifted value. `HabitatConstants`
  and `EconomyConstants` have no test contact at all. Note `simulation_constants.gd:38`
  also carries `HAZARD_AVOIDANCE_MULT := 4.0`, which the file itself flags as
  absent from §10 — the reconciliation belongs in this item.
- **Files/areas:** new `game/tests/species_registry_test.gd`; constants
  assertions in `game/tests/data_validation_test.gd`.
- **Acceptance:** `species_registry` load-failure path covered; constants values
  asserted against `data-schemas.md` §10, and §10 either gains
  `HAZARD_AVOIDANCE_MULT` or the constant is justified in a comment.
- **Depends on:** none.
- **Size:** S
- **Refs:** [data-schemas](../../docs/data-schemas.md) §10;
  `game/scripts/systems/simulation_constants.gd`.

#### V3. Reconcile `docs/test-plan.md` §11 against the real suite
- **Why:** carried unchanged. Re-measured by script this session: of **43**
  uniquely named tests in §11, **35 have no matching `func test_` in
  `game/tests/` (81%)** — identical to a week ago, which is expected since no
  test file changed. Five of the eight that resolve are the mortality and span
  rows; the other three are `test_impassable_blocks_movement`,
  `test_four_bands_mapping` and `test_partnership_quality_bonus_applied`. Mostly
  renames, but the table can no longer be used as the checklist it presents
  itself as.
- **Files/areas:** `docs/test-plan.md` §11.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason (the 2026-08-06 decision supplies the reasons for the
  hover-highlight row; `economy_manager_test.gd`, `permissions_manager_test.gd`
  and `milestone_tracker_test.gd` are Phase 3–5 and should say so).
- **Depends on:** none.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md) §11.

#### V4. Export the `Linux arm64` preset in CI, or delete it
- **Why:** carried unchanged. `export_presets.cfg:32-62` defines a preset that
  `ci.yml:158-170` never builds — the export step names exactly three presets,
  "Linux x86_64", "Windows x86_64" and "macOS" — and
  `builds/wildlife-crossing-linux-arm64/` sits empty in the tree as its ghost. It
  is also the architecture this sandbox runs on, so having it would let a future
  review boot a real artifact instead of reasoning about one.
- **Files/areas:** `.github/workflows/ci.yml`, `game/export_presets.cfg`,
  `builds/wildlife-crossing-linux-arm64/`.
- **Acceptance:** either the arm64 artifact appears in the CI upload and passes
  `check_pck_contents.py`, or the preset and the empty directory are gone.
- **Depends on:** B2 (land it on a current `main`).
- **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md); `ci.yml:158-171`.

#### V5. Exercise the `dco` job on a deliberately unsigned commit
- **Why:** **half closed.** [[../daily-logs/2026-08-13]] records the `dco` job
  executing for the first time on PR #1 and passing. Its acceptance also requires
  observing it **red**, which has not happened. A gate that has only ever been
  seen green is a gate whose failure path is untested — and this one's failure
  path is the branch that rejects an outside contributor's work.
- **Files/areas:** a throwaway branch and pull request carrying one deliberately
  unsigned commit, then one signed.
- **Acceptance:** the `dco` job observed red on the unsigned commit and green
  once signed off; the PR closed without merging.
- **Depends on:** none — PR #1 already proved the job runs.
- **Size:** S
- **Refs:** `ci.yml:57-72`; `tools/check_dco.py`; `CONTRIBUTING.md`.

#### V6. Make the zero-tests guard report why it failed, and catch partial drops
- **Why:** carried unchanged; re-read this session at `ci.yml:106-120`. Two
  problems. First, `:115` is
  `TESTS="$(grep -oE '<testcase' "$XML" | wc -l | tr -d …)"` under
  `set -euo pipefail` — if GUT records zero test cases, `grep` exits 1, the
  command substitution fails, and `set -e` kills the step **before** the
  `::error::` at `:118` can print. The build still fails; the operator gets an
  unexplained exit from the one guard written to explain itself. Second, the
  guard catches only `TESTS -eq 0`, whereas the failure it was designed for —
  2026-07-19 — was a **partial** drop where a parse error removed one file, GUT
  printed *All tests passed!* and exited 0. At 23 scripts, a run that silently
  lost 22 of them still passes.
- **Files/areas:** `.github/workflows/ci.yml:106-120`.
- **Acceptance:** a zero-test run prints the `::error::` before exiting; CI fails
  when the JUnit XML reports fewer than the expected number of test scripts
  (currently **23**); both verified against synthetic XML.
- **Depends on:** none.
- **Size:** S
- **Refs:** `ci.yml:106-120`; [[../daily-logs/2026-07-19]];
  [testing-setup](../../docs/testing-setup.md):142-147.

#### V7. Teach `build_encyclopedia.py` to delete, and test it
- **Why:** carried unchanged and re-verified: `tools/build_encyclopedia.py` (686
  LOC) contains no `unlink`, `remove(` or `rmtree` — it only ever writes — while
  `deploy-website.yml:47-56` gates on `git diff --quiet -- website/encyclopedia`.
  A **new** wiki entry produces an **untracked** `website/encyclopedia/<slug>.html`
  that `git diff` cannot see, so the gate passes green while the deployed site is
  missing the page; a **deleted** entry leaves an orphan the diff also cannot
  see. At 686 LOC it is still the largest untested tool, though not the only one:
  five of the nine tools in `tools/` have tests (**86 between them**), and
  `inspect_pck.py` (126), `make_hero_svg.py` (188) and `measure_tutorial.gd`
  (372) have none either. `inspect_pck.py` is the one that matters for B4 — it is
  the actual pack parser behind `check_pck_contents.py:35`.
- **Files/areas:** `tools/build_encyclopedia.py`;
  `.github/workflows/deploy-website.yml:47-56`; new
  `tools/tests/test_build_encyclopedia.py`.
- **Acceptance:** the generator removes pages whose wiki source is gone; the CI
  gate detects an untracked generated file (e.g. `git status --porcelain` as well
  as `git diff`); round-trip and external-asset checks covered by tests;
  `python3 -m unittest discover -s tools/tests -b` still OK.
- **Depends on:** none.
- **Size:** M
- **Refs:** `.github/workflows/deploy-website.yml`; `website/CLAUDE.md`.

#### V8. Assert the two runtime assets survive export
- **Why:** **new this review, and a downgrade rather than a discovery** — see
  §2's correction. `main.gd:21` and `hud.gd:14` `preload()`
  `assets/audio/crossing_chime.wav` and `assets/sprites/crossing_cue.png`;
  `game/.gitignore:3` excludes `*.import`, so both are re-imported on every CI
  run. A missing asset would fail the smoke boot (a failed `preload` is a
  compile failure, so `Tutorial loaded` never prints), so this is covered — but
  covered by a gate that reports *the binary did not boot*, not *the chime is
  missing*. `check_pck_contents.py` asserts data files and forbidden paths and
  says nothing about assets.
- **Files/areas:** `tools/check_pck_contents.py`;
  `tools/tests/test_check_pck_contents.py`.
- **Acceptance:** the pack gate asserts both asset paths are present and names
  them when they are not; the test covers a pack missing one.
- **Depends on:** none.
- **Size:** S
- **Refs:** `check_pck_contents.py:51,134-138`; `smoke_boot.sh:81`;
  [[2026-08-12-next-build]] B3.

### Deferrable / nice-to-have

Carried from [[2026-08-12-next-build]] unchanged unless noted:

- **63% of visible animals die in the first in-game day** — about ten real
  seconds at 1×, before the player can build anything (`6.30` of 10 agents at
  t=100, `measure_tutorial.gd`). Inherited from `EnvConfig.DEFAULT = 0.20` rather
  than chosen. A live tension with the *"cozy, not stressful"* north star.
- **The detour-cost measurement covered Bow Valley only.** The other 17
  non-bisecting segments remain unmeasured.
- **Delete the stale `wildlife-crossing-desktop-builds/` artifacts.** 411 MB,
  they fail the repo's own gate, they were built by Godot 4.6.0 against a
  pipeline pinned to 4.6.3, and four reviews running have had to establish that
  they are not the build. `tools/fetch_build.py` now downloads into run-scoped
  directories, so nothing needs this fixed path any more — the reason to keep it
  is gone.
- **`tools/_to_delete/` holds two `wc_patch*.tar.gz` files** (28–29 KB, dated
  2026-08-11). Untracked, since `.gitignore` re-includes only `*.py`, `*.sh`,
  `*.gd` under `tools/`. Harmless; named so the directory does not become
  permanent.
- **`game/scenes/world/Animal.tscn` is dead weight** — referenced by no script or
  scene; agents are drawn as circles by `world_renderer.gd`. Delete or wire.
- **`entities.json` is loaded and read by nothing.** `species_registry.gd:26`
  indexes it; no other script consumes it. Phase 2's Implements list requires the
  controlling-entity mapping "consumed as data".
- **The twelve world maps are template-scale.** `sub_areas.json` declares
  `playable_tile_count: 4000` for each, and each map in `data/world/` resolves to
  238–312 cells — 92–94% below the
  ±15% acceptance criterion in `data-schemas.md` §11 — and
  `data_validation_test.gd:88-89` asserts only the *declared* number, never the
  resolved grid. Not a build blocker (Bow Valley is the only shipping map, and it
  is playable), but the checklist item it discharges is only partly discharged.
- **Phase 2's "toolbar tool" P0 has neither an implementation nor a deferral.**
  `roadmap.md:96` lists it; `main.gd:332` is a *"placeholder trigger"* bound to
  `M`. Same for the P1 group at `:99-100`. Neither is an exit criterion.
- **`BaseScreen` retrofit** of `ConfirmPanel` and `ConnectivityOverlay` —
  deliberately deferred 07-31.
- **Real art.** `game/assets/fonts/` and `tilesets/` are still `.gitkeep` only;
  `crossing_cue.png` is a 341-byte generated placeholder. The eight species
  portraits ship on the public site but are unwired in the game.
- **`website/CLAUDE.md:79`** still specifies user-guide section 2 as *"Placing
  habitats"*, which the shipped guide does not match.
- Windows signing remains deliberately out of scope — revisit only per ADR 0018's
  stated triggers. Phase 5 gates (liaison-NPC decision, cultural-advisor review)
  remain open and still do not block P0.

## 4. Doc drift to fix

Record only — docs are not edited during a review.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | "`game/` is still almost entirely `.gitkeep`"; A1 "no `project.godot`"; A2 "GUT not installed"; A3 "no CI"; A4 "zero game code"; A5 "only `sub_areas.json` and `biome_groups.json`"; A6 "only the `bow_valley_slice` fixture"; A7 "`game/assets/` is all `.gitkeep`"; all B0/B1/B2 boxes unticked | Every claim is false, **flagged in five consecutive reviews and never fixed**. Actual: 30 scripts / 3,569 LOC, 4 autoloads, GUT 9.6.0 vendored, a 279-line five-job CI, all 8 data files valid, 12 world maps, 23 test scripts / 237 tests, two real assets. Its one still-partly-true row is the `scenes/world/WorldMap.tscn` checkbox. `status: active` makes this a trap for onboarding — retire or rewrite. **This is the longest-running item on this table and the cheapest to close.** |
| [testing-setup.md](../../docs/testing-setup.md):70 | "the suite currently reports **16 scripts / 134 tests / 2,779 asserts**" (dated 2026-07-30) | Measured this session: **23 scripts / 237 tests / 3,032 asserts**. Stale at five consecutive reviews and corrected four times — worth generating from the JUnit XML rather than maintaining by hand. |
| [testing-setup.md](../../docs/testing-setup.md):22 | "**Godot 4.6** (stable). Any 4.6.x patch is fine" | Contradicts `ci.yml:15` and ADR 0012, which pin the exact patch deliberately because export-template paths are version-keyed. Carried unfixed. |
| [testing-setup.md](../../docs/testing-setup.md):142-147 | "### Known gap … Consider adding a CI assertion that the run actually collected tests" | Partly implemented at `ci.yml:106-120` — zero case only, and its error message is unreachable under `set -e`. See V6. |
| [testing-setup.md](../../docs/testing-setup.md):36 | "The repo's root `.gitignore` excludes `/tools/`" | It excludes `/tools/*` then re-includes `*.py`, `*.sh`, `*.gd` and `/tools/tests/`; the sentence reads as though nothing in `tools/` is committed, which is now conspicuously wrong — `tools/` gained two scripts and two test files this week. |
| [roadmap.md](../../docs/roadmap.md) Phase 1 exit criteria | "A fully spanned overpass yields a zero-mortality route" | Still predates [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md); "fully spanned" now means a valid **span** (two-sided core), not full segment coverage. The code is correct; the criterion's wording is not. Carried unfixed from three reviews. |
| [roadmap.md](../../docs/roadmap.md):148, :157 | The 2026-08-06 decision block cites Phase 2's exit criteria as `:98-108` and its Implements list as `:80-92` | The same session's insertion moved them. Cite the heading, not the line — which this note does. |
| [test-plan.md](../../docs/test-plan.md) §11 | P0 coverage table presented as the first-playable bar | 35 of 43 named tests have no matching function (81%, re-measured this session). See V3. Carried unfixed. |
| [architecture.md](../../docs/architecture.md):52-68, :69 | Lists 14 systems and UI scripts that do not exist, plus scene files for UI built in code — including `ui/BaseScreen.tscn` | All Phase 3–6, so not a regression, but the table reads as a description of the codebase and overstates it. `BaseScreen.tscn` is absent **deliberately**: every screen here is code-instantiated. §8 also cross-references only ADRs 0001–0005 of the 18 that exist. Split into *planned* vs *built*. Carried unfixed. |
| [game/CLAUDE.md](../../game/CLAUDE.md):86-100 systems table | Names 13 system files, of which **6 are built** (`habitat_manager`, `species_manager`, `infrastructure_manager`, `save_manager`, `connectivity_graph`, `population_model`) | **24 of the 30 built scripts are absent**, including `simulation.gd`, `main.gd`, all four autoloads, all three constants files, `world_renderer.gd` and all ten UI scripts; there is no UI section at all. The file states its own rule at `:102-104` — *"Add a row here whenever a new system is created"*. A convention miss now four weeks old. |
| [push-runbook.md](../../docs/push-runbook.md):134, 266, 301 | Dated "2026-08-14" | The work was 2026-08-13 local. Cosmetic; self-reported in [[../daily-logs/2026-08-13]] and uncorrected. |
| [push-runbook.md](../../docs/push-runbook.md) §Troubleshooting, and `tools/ship.py:382-384` | Both blame the `weekly-build-review` harness for the stale `.git/index.lock`; [[../daily-logs/2026-08-13]] instead blames the Cowork mount forbidding `unlink`, "so every git command leaves its lock behind" | **Neither is supported.** The lock present this session is 0 bytes with mtime 2026-08-13 22:04 — *unchanged* after a session's worth of git commands from this sandbox, which is the opposite of what the 08-13 explanation predicts. The repo now carries two contradictory accounts in three places. Harmless (`ship.py` clears it), but the correction is "cause unknown", not "cause is X". |
| [README.md](../../README.md):22 | Points at `.claude/CLAUDE.md` | `.claude/` is an empty directory; the file is at the repo root. |
| [README.md](../../README.md) and root [CLAUDE.md](../../CLAUDE.md) repo-structure tables | Neither lists `harness/` | Four tracked files live there, including the skill that produces these notes. It becomes visible to strangers the moment B5 resolves. |

**Closed this week:** `export-setup.md:97`'s *"uploads everything as a workflow
artifact (14-day retention)"* is true again as of `13857e0`. It is the first row
ever to leave this table by being fixed rather than rewritten.

## 5. Risks & open questions

- **The calendar-bound item has been ranked and skipped twice.** B1 (Apple
  enrolment) is small, is nobody's favourite task, costs $99, and silently sets
  the release date. It was ranked third for last week and appears in neither the
  08-10 nor the 08-13 next-session list. This is the single highest-leverage
  thing on the page and the easiest to defer again, which is precisely the
  pattern worth naming: **the release date is now being set by an item nobody has
  scheduled.**
- **The project's own review record lives on one machine.** The 08-12 review, its
  amendments and the 08-13 log have been uncommitted for five days. The
  build-review notes are how this project knows what is blocking it; a note that
  is not in the repo is not a record, it is a file. Fold the commit into B2
  rather than treating it as housekeeping.
- **`main` is eight days stale and ten commits behind `HEAD`.** Root `CLAUDE.md`
  requires `main` to be runnable at all times; it currently *is*, but it is
  runnable in a state that predates the entire save/load system. Every day PR #1
  stays open widens the gap between "what the repo says the project is" and what
  it is.
- **Three separate decisions are staged for a repo transition nothing schedules**
  (B5). ADR 0017's premise, ADR 0018's threat model and the DCO gate's stated
  purpose all assume the repository goes public; no document says when, who, or
  what has to be true first. The failure mode is the quiet one: a release lands,
  the website's download button points at it, and the first person to find out
  it is unreachable is a stranger.
- **This review could not observe CI.** `gh` is not installed and `git fetch
  origin` fails with *Host key verification failed*. Nothing here should be read
  as a claim about CI's current status — including the 08-13 log's report of a
  green five-job run, which is a record of what a human saw, not something this
  session verified. Relatedly, `origin/main` is the local remote-tracking ref,
  last updated **by a push** on 2026-08-10 21:49, not by a fetch, so "10 behind"
  is true as of that push and would be wrong if PR #1 has since merged.
- **`smoke-windows` still cannot be read as evidence when the export fails.**
  `needs: export` is bare and `if: always()` is on steps rather than the job, so
  a failing pack gate or Linux boot **skips** it. Any acceptance written against
  it must say *green, not skipped* — B2's does.
- **The first thing a player sees is aimed at a measured dead zone** (C4). One
  line, measured eight days ago, still undecided. It should not survive into a
  release note.
- **The sandbox cannot export.** `~/.local/share/godot/export_templates/` is
  empty, so the build signal here is a source boot plus the pack gate. V4 (an
  arm64 preset) would let a future review boot a real artifact instead of
  reasoning about one — which is now the main reason to prefer "export it" over
  "delete it" in that item.

## 6. Suggested next-week focus

1. **B1 — make the GPG key, then start Apple enrolment** (S effort, days of
   calendar). First, before anything else, on whatever day the next session
   happens. It has been deferred twice; C1, C2 and B6 all queue behind the Apple
   half, and its duration is the one thing later effort cannot compress. The GPG
   half blocks on nothing and unblocks C6 the same morning — do it first so a
   slow enrolment stops holding it hostage.
2. **B2 — commit the vault files, then merge PR #1** (S). The commit must come
   first or the branch push won't carry it. Watch for `smoke-windows` **green,
   not skipped**.
3. **B3 + C4 + C5 — fetch the build, decide the camera, walk Step 5** (M + S +
   S). One session. `tools/fetch_build.py` exists to make the first part
   mechanical; the value is in the second: the credits screen actually read, the
   chime actually heard, the F5/quit/relaunch/F9 round-trip actually done, and
   the `codesign -dv` output recorded for C1.
4. **C3 — set the version fields, and settle B5** (S + S). Ten minutes each, no
   dependencies, both on B6's critical path. Do them while waiting on Apple: the
   version strings are a two-line edit, and B5 is very likely a sentence
   recording something already true — which is exactly why it will otherwise be
   discovered at release time rather than now.
5. **B4 — the packaging decision** (M). The last thing standing between a green
   pipeline and something a stranger can download and run. Land it as one commit
   with its gate updates.

C1 and C2 unlock the moment the Apple certificate lands, and B6 waits on
everything. If B1 starts this week the release waits only on Apple; if it slips
again it slips the release one-for-one — for the second week running.

---

## Verification

Labels per the harness's Step 6 rule. **Confirmed** = traced to something read or
run *this session*, against `4119915`. **Assumed** = the reasoning is sound but
nothing was checked. **Unverifiable** = not checkable from this session;
inferring a state from a daily log is explicitly not evidence.

**Confirmed (run or read this session, at `4119915`):**

- GUT suite **23 scripts / 237 tests / 3,032 asserts, all passing, exit 0**, via
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` after `--headless --import`.
- `python3 -m unittest discover -s tools/tests -b` → **86 tests, OK**. Five test
  files: `test_check_dco.py`, `test_check_pck_contents.py`, `test_fetch_build.py`,
  `test_ship.py`, `test_smoke_boot.py`.
- Both headless boots clean — `[I] Title screen ready`, and `[I] Tutorial
  loaded. Press B … F5 saves, F9 loads.` No `ERROR:` or `SCRIPT ERROR`.
- `git rev-parse HEAD` = `4119915…`; branch `feat/save-load-and-agent-respawn`;
  `origin/feat/…...HEAD` → `0  0`; local `main` = `9d0ec58`; `origin/main` =
  `0c31c85`; `origin/main...HEAD` → **`0  10`**; `git reflog show origin/main
  --date=iso` → last update **by push**, `2026-08-10 21:49:48 -0500`.
- `git status --short` → `M obsidian-vault/build-reviews/2026-08-12-next-build.md`,
  `M obsidian-vault/build-reviews/README.md`, `?? obsidian-vault/daily-logs/2026-08-13.md`.
- The five commits since `7e10b0c` and their dates (`13857e0`, `aece807`
  2026-08-13 20:31; `6db1e3d` 20:53; `10062ad`, `4119915` 21:56).
- `git tag -l` → 0 tags; `builds/` → `.gitignore`, `.gitkeep`, one empty
  directory, `du -sh` 4.0K; `docs/release-notes/` → 0-byte `.gitkeep` only.
- `wildlife-crossing-desktop-builds/` → 411 MB; `find … -newermt 2026-08-01` →
  nothing.
- `ci.yml` is **279 lines**; jobs at `:24, :57, :74, :122, :256`;
  `GODOT_VERSION` at `:15`; `grep -n retention-days` → **`:243` only**, inside
  the `Upload build artifacts` `with:` block; `if: always()` at `:225` and
  `:238`; `smoke-windows` `needs: export` at `:258`; export step names exactly
  three presets at `:165-170`; the zero-tests guard at `:106-120` with
  `grep -oE '<testcase' | wc -l` under `set -euo pipefail`.
- `main.gd:21` and `hud.gd:14` `preload()` the two runtime assets;
  `simulation_constants.gd:38` `HAZARD_AVOIDANCE_MULT := 4.0`;
  `species_registry.gd:26` indexes `entities.json`; `main.gd:331-332`'s
  *"placeholder trigger for the PRD's 'Add crossing' toolbar action"*;
  `main.gd:215-221`'s *"unreachable from the map screen in v0.1.0"* and
  `WorldSelectMap.tscn:12` `mouse_filter = 0`; `env_config.gd:8,21-31`;
  `data_validation_test.gd:88-89`; `ship.py:83,380-416` and `:382-384`;
  `architecture.md:69`'s `ui/BaseScreen.tscn` row.
- ADR 0017:9-13 (*"the repository has been private to date"*) and `:119-121`
  (*"a licence obligation, not a nicety"*); `ci.yml:44-53` (*"before the repo is
  announced publicly"*), `:224-232` (notice copy), `:276-279` (the hardcoded
  Windows `BIN`); `website/index.html:55` pointing at the Releases page;
  `signing-runbook.md:188` (the `.dmg` is built on the Mac) and its §Suggested
  order row putting GPG on *"Blocks on: nothing"*;
  `check_pck_contents.py:35,53-80` (it imports `inspect_pck.read_pck_paths` and
  accepts only `.pck` / `.app` / `.zip`); `deploy-website.yml:8-11` (publishes
  only on push to `main`); `user-guide.html` has no install copy; `README.md:22`
  points at an empty `.claude/`; `harness/` is tracked and in neither structure
  table.
- `export_presets.cfg`: `:26,57,88` `embed_pck=false`; `:25,56,87,132`
  `export_console_wrapper=1`; `:117` macOS `export_path` ends `.zip`; `:128`
  `distribution_type=0`; `:138-139` empty version strings; `:145`
  `codesign/codesign=1`; `:147-148` empty team id and identity; `:173`
  `notarization/notarization=0`; `:94,133` `application/icon=""`; the arm64
  preset is `[preset.1]` at `:32`, `name=` at `:34`, `export_path` at `:43`.
- `main.gd:18` `CAMERA_FOCUS_COORD := Vector2i(13, 6)`.
- `game/tests/` holds 23 `*_test.gd`; no `env_config_test.gd`, no
  `species_registry_test.gd`; `grep -rl SpeciesRegistry game/tests/` → nothing;
  `grep -c Constants game/tests/data_validation_test.gd` → 0.
- `docs/test-plan.md` §11 → **43** uniquely named tests, **35** with no matching
  `func test_` (**81%**), recomputed by script; the eight that resolve listed in
  the script output.
- `tools/smoke_boot.sh:76-80` `BENIGN_PATTERNS` (three entries), `:81`
  `SUCCESS_LINE="Tutorial loaded"`, `:147-154` strip-and-report.
- `tools/check_pck_contents.py:51 resolve_pck`, `:133-138` builds its expected
  set from `game/data/**/*.json`; no reference to `assets`, `.wav` or `.png`.
- `tools/build_encyclopedia.py` → 686 lines, no `unlink`/`remove(`/`rmtree`;
  `deploy-website.yml:47-55` gates on `git diff --quiet`.
- `docs/testing-setup.md:70` "16 scripts / 134 tests / 2,779 asserts", `:22`
  "any 4.6.x patch", `:142` "### Known gap"; `docs/export-setup.md:97` "14-day
  retention".
- `game/CLAUDE.md:88-100` names 13 systems (header at `:86-87`), 6 of them built.
- `grep -in 'fingerprint|gpg|sha256|smartscreen|unsigned'` over `README.md` and
  `website/index.html` → **no matches**.
- `grep -rn -i 'enrol|apple developer|gpg|notariz'` over
  `obsidian-vault/daily-logs/2026-08-1*.md` → only the 08-10 ADR-writing entries
  and 08-13's closing reference; no record of enrolment or a key being created.
- 23 `.gitkeep` files on disk, **22 tracked** (`builds/.gitkeep` is shadowed by
  `builds/.gitignore`).
- Data inventory: all 8 canonical files and all 12 `data/world/sub_area_*.json`
  parse; required fields present; tile ids resolve; the 4000-vs-238–312
  playable-tile discrepancy and `data_validation_test.gd:88-89`.
- `~/.local/share/godot/export_templates/` → empty (4.0K, no version
  directories); no local export possible.
- A 0-byte `.git/index.lock` with mtime 2026-08-13 22:04.

**Assumed:**

- That a missing `crossing_chime.wav` or `crossing_cue.png` would fail the smoke
  boot (§2's correction). The reasoning — `preload()` resolves at script compile
  time, so `Tutorial loaded` would never print — is sound and was not tested by
  deleting an asset and re-exporting, which this sandbox cannot do.
- That merging PR #1 is all that stands between `origin/main` and `HEAD`. Read
  from local refs; the PR's mergeability was not checked.
- That fixing B1 (08-12) restored 14-day retention rather than the repo default.
  Read from `ci.yml:243`, not from GitHub's settings.
- That `export/distribution_type=0` may need to change for notarization (C1).
  The runbook's A5 table does not mention it and the Godot docs were not
  reachable from this session.
- Item sizings (S/M) throughout.

*Moved out of Assumed by the audits:* "no `.gd` file changed this week" was
listed here as inference from the commit subjects; `git diff --name-only
7e10b0c..HEAD` confirms it directly. **Confirmed.**

**Unverifiable this session:**

- **Any statement about CI's actual status**, including whether run
  `31762062722` was green, whether PR #1 is still open, and whether `origin/main`
  has moved since 2026-08-10 21:49. `gh` is not installed; `git fetch origin`
  fails with *Host key verification failed*. No run, badge or log was consulted,
  and none should be inferred. The 08-13 log's account is a human's record of
  what they saw, and this note treats it as reported rather than confirmed.
- Whether Apple enrolment or the GPG key started outside the repo. The absence of
  evidence in the tree is what is confirmed; the absence of the fact is not.
- **Whether the repository is public** (B5). Not checkable without GitHub. B5 is
  written to be cheap if the answer is yes and load-bearing if it is no.
- What actually creates the stale `.git/index.lock`. Three documents give two
  incompatible answers and this session's evidence supports neither.
- Whether the 2026-07-27/28 binaries launch. They are on disk; nothing here ran
  them.
- Whether the windowed macOS build of `HEAD` launched on 2026-08-13 — reported in
  that day's log, not observed here.
- The 08-10 tutorial measurement figures (6.30 → 1.20 at t=100; the row-1 vs
  row-6 death and usage counts) are quoted from [[../daily-logs/2026-08-10]] and
  `tools/measure_tutorial.gd`'s recorded output; the script was **not** re-run
  this session.
- Whether the HUD cue, the chime, the credits screen or the overlay look correct
  on a screen. This project's 237 tests have never examined a pixel.

### What the audits changed

This note was audited twice before delivery — a fact-integrity pass over every
figure, date and `file:line`, and a completeness red-team asking whether anything
needed for the build is missing and whether anything listed is already done. Both
ran against a draft and both found real errors. Recorded rather than quietly
fixed, because the pattern is the point:

- **A whole blocker was missing.** Nothing in the draft — or in any previous
  review — asked whether the repository is public, while three separate documents
  reason from the assumption that it will be. That is now B5, and it is the kind
  of gap that is invisible precisely because everyone assumes someone else
  checked.
- **B4's acceptance permitted breaking ADR 0017.** "One file that runs on a clean
  machine" is satisfied by an embedded-pack `.exe` that carries neither notice
  file. The licence obligation and the packaging fix were being optimised
  independently.
- **C2's stated failure mode was wrong.** The draft repeated last review's claim
  that a `.dmg` breaks the CI pack gate. CI passes an explicit output path that
  overrides the preset, so it does not — and the real problem is the opposite
  shape: the shipped `.dmg` is built on the Mac and gated by nothing at all.
- **A count contradicted itself three lines later.** "7 verification items"
  against a list of eight, in the same paragraph that says "V8 new".
- **CI status leaked from Unverifiable into the body.** §2, §5 and the
  Verification block labelled the 08-13 CI run correctly; the headline, B3 and the
  index line asserted it flatly. The label was right and the prose was not, which
  is the failure mode the labelling rule exists to catch.
- **An explanation adopted from a log without checking.** The `.git/index.lock`
  cause: the 08-13 log's account predicts a fresh lock after every git command,
  and the mtime is unchanged after a session of them.
- **Nine imprecise citations** (`main.gd:20-21`, `game/CLAUDE.md:86-98`,
  `check_pck_contents.py:134-138`, `deploy-website.yml:47-56`,
  `roadmap.md:155-156`, `export_presets.cfg:25,56,87` as Windows, "arm64 preset
  at `:43`", `ci.yml:165-171`, `ship.py:381-416`) and four overstatements
  ("the eight resolving tests are all mortality and span", "the other five
  tools", "asserted nowhere", "this note and its index line make five").
- **A Phase 2 exit criterion is met in tests and unobservable by hand** —
  `ConfirmPanel` is unreachable from the map screen in v0.1.0. C5's QA pass would
  have gone looking for it.

---

## Related

- [roadmap](../../docs/roadmap.md) — Phase 1 and Phase 2 §*Exit criteria*, and
  the logged decisions of 2026-07-29, 2026-07-31, 2026-08-06
- [pre-build-checklist](../../docs/pre-build-checklist.md) — stale in every
  section; see §4
- [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md),
  [ADR 0017](../../docs/adr/0017-licensing.md),
  [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
- [signing-runbook](../../docs/signing-runbook.md),
  [push-runbook](../../docs/push-runbook.md),
  [export-setup](../../docs/export-setup.md)
- Previous review: [[2026-08-12-next-build]]
- [[../daily-logs/2026-08-13]], [[../daily-logs/2026-08-10]],
  [[../daily-logs/2026-08-09]]
- [[../design/detour-cost-question]]
