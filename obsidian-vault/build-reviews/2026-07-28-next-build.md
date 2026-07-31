---
title: "Build Review — Next Build (2026-07-28)"
date: 2026-07-28
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> roadmap [[roadmap|Phases 1–2]]). One question: what work is needed to get
> there?

> [!warning] Amendment 2026-07-28 — **B1 is withdrawn; its diagnosis was wrong.**
> This review's headline finding, that the exported pck "contains no game data",
> is false. The shipped `wildlife-crossing.pck` contains **all 20** `data/*.json`
> files and boots cleanly to the tutorial in 3 lines with no errors. The
> zero-`.json` result came from string-scanning the pack for `res://…` paths;
> Godot 4.6 writes **pack format 3**, which stores paths *without* that prefix,
> so the scan could not see the directory at all — while still matching path
> literals embedded in `.gdc` bytecode, which is where the "236 GUT paths"
> came from. The §2 reproduction (copying `game/` *without* `data/`) proved only
> what a data-less build looks like, not that this build was one.
> **What survived:** V2 was real (244 development-only files were shipping) and
> is fixed; B2 and V1 are done. §"The export defect, in evidence" and the
> §"Exit criteria" row *"the build launches to the main scene"* should be read as
> retracted. See [[../daily-logs/2026-07-28]] for the evidence.

> [!success] Amendment 2026-07-29 — **B5 and B6 are closed.**
> **B5:** scoped, not built. v0.1.0 ships Bow Valley (sub-area 7) only; the
> other 11 sub-areas are authored, data-complete, and locked pending Phase 5.
> The code already matched this (`starts_unlocked` in `sub_areas.json`); the
> decision is now recorded in `docs/roadmap.md` Phase 2. **B6:** Brent
> launched the downloaded macOS `.app` windowed — reaches the tutorial,
> animals moving, B and M both work — and a headless run via a fixed
> `tools/smoke_boot.sh` came back clean (3 lines, `Tutorial loaded`, exit 0).
> Getting the headless half green surfaced a real macOS-only bug: a killed
> process's buffered stdout is silently lost on macOS (neither SIGTERM nor
> SIGINT flushes it), so a healthy, mostly-quiet boot reported as empty
> output — indistinguishable from a hang. Fixed by wrapping the binary in
> `stdbuf`/`gstdbuf -oL -eL`. The artifact tested predates the 2026-07-28
> exclude-filter/version-pin fixes (still unpushed as of this amendment) — its
> banner reads Godot 4.6.0, not 4.6.3, and it still carries the GUT addon
> internally — so B6's acceptance criteria are met, but the artifact itself
> is not the final one; the eventual push will produce a slimmer replacement
> worth a repeat smoke test. See [[../daily-logs/2026-07-29]].

> [!success] Amendment 2026-07-29 (same day) — **B3 is closed: span geometry
> now follows ADR 0016, not the whole-segment reading.**
> `InfrastructureManager.try_complete()` no longer requires every dangerous
> tile of a segment to be covered; it now checks whether the player's placed
> tiles contain a connected "core" whose local safe ring splits into two or
> more sides — the topological span definition ADR 0016 specifies. `build_full()`
> is renamed/re-scoped to `build_span(segment_id, crossing_type, tiles)`,
> taking an explicit span location rather than paving the whole corridor.
> `Simulation.build_crossing()` and both call sites in `main.gd` (the KEY_B
> tutorial build and the confirm-panel hand-off) now pass a `TUTORIAL_SPAN`
> constant — the ADR's own worked minimal example, `{(12,5),(13,5)}` — as an
> explicit interim default until the real placement UI (B4) exists. Pressing
> **B** in the tutorial now builds a 2-tile, 10,000-cost overpass instead of
> paving all 20 tiles of the highway for 100,000, which is the actual defect
> this blocker names. `infrastructure_manager_test.gd` now carries all seven
> rows of the ADR's verified-behaviour table as named cases (Bow Valley
> full-width/half-width/along-the-road/whole-corridor, Snake River single-tile/
> tip/whole-reach), each checked by hand against the algorithm before being
> confirmed by a green run. Full suite: 15 scripts / **122** tests / 2,750
> asserts, all green (was 116/2,740 before B3). See [[../daily-logs/2026-07-29]].
> **Only B4 (span placement UI) remains on this review's blocker list**, and
> it is now unblocked — B3 was its sole dependency.

> [!success] Amendment 2026-07-30 — **B4 is closed: no build-review blockers
> remain open.**
> Player-chosen placement replaces the hardcoded `TUTORIAL_SPAN`. New
> `game/scripts/ui/build_mode.gd` (`class_name BuildMode extends RefCounted`)
> holds an in-progress span selection with no scene-tree or autoload
> dependency — `toggle()`, `is_selectable()`, `running_cost()`, `is_valid()`,
> `rejection_reason()` — and writes nothing to a live `InfrastructureManager`
> until the player confirms. `main.gd` routes both entry points (the `KEY_B`
> tutorial shortcut and the confirm-panel hand-off) into a shared build-mode
> flow: left-click toggles the tile under the cursor, Enter confirms, Escape
> cancels; an invalid confirm attempt is refused in place with a reason shown
> in a status label ("N tile(s) selected, $cost"). `world_renderer.gd` draws
> a ghost preview — chosen tiles blue, the hovered tile green (valid
> candidate) or red (not part of the segment / not coverable by the crossing
> type) — distinct from the gold completed-crossing fill.
>
> Along the way, ADR 0016's two-sided-core predicate
> (`_contains_two_sided_core` and its helpers) moved from a private
> `InfrastructureManager` method to a static, `world`-parameterized one
> (`InfrastructureManager.contains_two_sided_core`). `try_complete()` and
> `BuildMode.is_valid()` now call the identical function, so the live
> placement preview and the real completion check are provably the same
> rule — a "valid" preview can never be refused at confirm time.
>
> New `game/tests/build_mode_test.gd` (12 tests) re-covers the same ADR 0016
> rows `infrastructure_manager_test.gd` already encodes. Full suite: 16
> scripts / **134** tests / 2,779 asserts, all green (was 122/2,750).
> Verified two ways this couldn't verify itself: a clean headless boot from
> source (unchanged, 3 lines, `Tutorial loaded`, no errors), and — since
> headless can't exercise mouse/keyboard input — a windowed run in the Godot
> editor: press B, click tiles across the road at r=5, Enter to confirm,
> confirmed behaving as expected. See [[../daily-logs/2026-07-30]].
>
> Crossing type is hardcoded to `"overpass"` (the only `available_in_v1`
> type in `infrastructure.json`) — no type selector yet, deferred until
> underpass/corridor ship. The build-mode status label is another ad-hoc
> code-instantiated `Control`, same pattern as `ConfirmPanel` and
> `ConnectivityOverlay` — reproduces rather than resolves the `BaseScreen`
> convention debt in this review's deferrable list; C1's HUD is next to face
> that choice.

## 1. Summary

- **Build case:** **FIRST working build** — but for a new reason. As of
  2026-07-27 **binaries exist for the first time in project history**: three
  platforms sitting in `wildlife-crossing-desktop-builds/` at the repo root
  (Linux x86_64, Windows x86_64, macOS zip; 232 MB, downloaded from the CI run
  on `62a4a48`). That closes the question that has decided this field for four
  reviews. It does not close the build case, because a *working* build must also
  launch to the main scene — and this one does not. **The exported `.pck`
  contains no game data.** Verified two independent ways this review, and
  reproduced end to end (see §2, B1).
- **Target milestone & exit criteria:** roadmap
  [Phase 1](../../docs/roadmap.md) (core simulation + overpass validation) and
  [Phase 2](../../docs/roadmap.md) (location selection + sub-areas).
- **Headline:** **6 blockers, 5 core tasks.** Two of last review's five blockers
  closed — B1 (commit and push) and, indirectly, the CI half of B4 — and the
  week's real achievement was diagnostic: a sixteen-day-old CI defect was found
  and fixed, and artifacts finally uploaded. But the artifacts turn out to be
  hollow. `export_filter="all_resources"` with an empty `include_filter` ships
  every `.gd`, `.tscn` and `.ttf` — and **not one of the 20 `.json` files the
  game reads at startup**. The pck happily contains 236 GUT addon paths and 30
  test-script paths; it contains zero bytes of `data/`. The build ships its test
  framework and leaves its content behind. Everything else on the list is
  unchanged from 2026-07-21, because no game logic was touched this week.
- **Change since last review:** [[2026-07-21-next-build]] — **B1 closed**
  (six commits `ea6f4cf`…`9ba62e2`, pushed; `HEAD` = `origin/main` = `62a4a48`).
  **V2 answered**, and the answer was that CI had *never* gone green, not once —
  the 2026-07-11 artifact everyone hoped for never existed. **B4 half-closed:**
  binaries now exist, but none has been observed to boot. **Newly open:** the
  data-exclusion defect (B1 below), the fragile smoke test (B2), and 232 MB of
  un-ignored binaries sitting in the working tree.

## 2. Current state (evidence)

Grounded in this review's own inspection, a fresh headless suite run, a headless
boot, a string-level scan of the shipped `.pck`, and a reproduction of the export
environment.

- **Systems:** 23 scripts / **2,149 LOC** in `game/scripts/`, zero stubs —
  byte-for-byte the same totals as 2026-07-21. The four autoloads
  (`game_state`, `event_bus`, `debug`, `species_registry`) are registered at
  `game/project.godot:22-25`; all Phase 1 simulation systems, three constants
  files, `world/world_renderer.gd` (54 LOC) and four UI scripts are present and
  real. **No game logic changed this week** — confirmed by re-running every
  defect check from the last review (§"Defects still open" below) and by
  [[../daily-logs/2026-07-27]] ("No game-logic code changed").
- **Data (in the repo):** all **8** canonical files in `game/data/` present and
  valid JSON; all **12** world maps `data/world/sub_area_1..12.json` valid;
  `segments.json` holds **19 segments covering all 12 sub-areas**. Verified by
  `json.load` on each file.
- **Data (in the shipped build):** **absent.** See B1.
- **Scenes & wiring:** `game/scenes/Main.tscn` is `run/main_scene`
  (`project.godot:17`); wiring lives in `main.gd:28-58`, which instantiates
  `Simulation`, `WorldRenderer`, `ConnectivityOverlay`, `Camera2D`,
  `AudioStreamPlayer` and lazily instances `scenes/ui/WorldSelectMap.tscn` +
  `ConfirmPanel`. `scenes/world/Animal.tscn` exists. **Headless boot from source
  is clean:** `[I] Tutorial loaded. Press B to build the Bow Valley overpass.
  Press M for the world map.` on output line 3, no errors.
- **Tests:** GUT via the vendored `tools/godot/Godot_v4.6.3-stable_linux.arm64`
  against `game/.gutconfig.json` — **15 scripts / 116 tests / 2,740 asserts, all
  passing (0.972s)**. Identical to last review; no test was added or lost.
  Untested scripts: the four autoloads, `env_config.gd`, `main.gd`, and the three
  constants files. `env_config.gd` (31 LOC, real branching logic) remains the
  meaningful gap.
- **CI:** `.github/workflows/ci.yml`, two jobs. `test` — pinned
  `GODOT_VERSION: 4.6-stable`, `--headless --import`, GUT with JUnit XML, plus
  the V1 zero-tests guard (counts `<testcase>` elements). `export` — installs
  templates, exports the three desktop presets, smoke-tests the Linux binary,
  uploads `builds/` with `if: always()` and 14-day retention. The `if: always()`
  and the ETC2 ASTC fix both landed in `62a4a48` (2026-07-27).
- **Build/export:** **artifacts exist.** `wildlife-crossing-desktop-builds/`
  (repo root, untracked, 232 MB, all files dated 2026-07-27): Linux
  `wildlife-crossing.x86_64` 71,047,224 B + `.pck` 1,640,952 B; Windows `.exe`
  104,437,248 B + the same `.pck`; macOS `wildlife-crossing.zip` 63,924,226 B.
  `builds/` itself is still empty apart from `.gitignore`, `.gitkeep` and the
  stale empty `builds/wildlife-crossing-linux-arm64/`. No git tag
  (`git tag -l` empty), no release note (`docs/release-notes/` holds only
  `.gitkeep`). → **first build.**
- **Git:** `main` == `origin/main` == `62a4a48`. Working tree is nearly clean —
  three untracked paths: `docs/b1-commit-runbook.md` (obsolete, the 2026-07-27
  log says delete it), `obsidian-vault/daily-logs/2026-07-27.md`, and
  `wildlife-crossing-desktop-builds/`. The last is **not gitignored** —
  `git check-ignore` returns nothing for it, while `builds/` *is* ignored. A
  `git add -A` would commit 232 MB of binaries into a repo whose stated policy
  (root `CLAUDE.md`, `.gitignore`) is that binaries go to GitHub Releases.
- **Assets:** `game/assets/audio/crossing_chime.wav` is the only real asset.
  `sprites/`, `tilesets/`, `fonts/` are `.gitkeep` only.

### The export defect, in evidence

Three independent observations, in the order they were made:

1. **String scan of the shipped pck.** Extracting every `res://…` path from
   `wildlife-crossing-desktop-builds/wildlife-crossing-linux-x86_64/wildlife-crossing.pck`
   yields 120 `.gdc`, 16 `.tscn`, 13 `.ctex`, 10 `.ttf`, 8 `.png` … and **zero
   paths ending `.json`, zero paths containing `/data/`**. It also yields **236
   paths under `addons/gut/`** and **30 under `tests/`**.
2. **The cause is a preset setting, not a build accident.** All four presets in
   `game/export_presets.cfg` carry `export_filter="all_resources"` with
   `include_filter=""` (lines 9-10, 40-41, 71-72, 114-115). Godot 4 treats
   `.json` as a plain file, not an imported resource, so `all_resources` excludes
   `game/data/**/*.json` from every preset. `docs/export-setup.md` never mentions
   `include_filter` or non-resource data files.
3. **Reproduced.** Copying `game/` to a scratch directory *without* `data/` and
   booting headless with the vendored 4.6.3 binary produces exactly the
   failure mode the build must be in:

   ```
   ERROR: Data file missing: res://data/tiles.json
      at: push_error (core/variant/variant_utility.cpp:1024)
      GDScript backtrace (most recent call first):
          [0] _load_object (res://scripts/systems/species_registry.gd:40)
          [1] _load_array (res://scripts/systems/species_registry.gd:34)
          [2] load_all (res://scripts/systems/species_registry.gd:23)
          [3] _ready (res://scripts/systems/species_registry.gd:19)
   ```

   …once for each of the 8 data files, then
   `ERROR: World file missing: res://data/world/sub_area_7.json`
   (`simulation.gd:42`), then **4,329 repetitions** of
   `SCRIPT ERROR: Invalid call. Nonexistent function 'coverage' in base 'Nil'.`
   The process never exits; it was killed at 30 s (`exit=124`). The control run
   *with* `data/` present is clean and terminates. So the exported binary does
   not merely miss a log line — it boots into an unbounded per-frame error storm
   with no world, no species and no segments.

**Why the CI smoke test's message is misleading.** `main.gd:58` still runs, so
`Tutorial loaded` *does* appear — at **output line 69**, after 68 lines of error
backtrace. The smoke step is
`OUT="$(timeout 20 ./builds/…/wildlife-crossing.x86_64 --headless 2>&1 | head -20 || true)"`,
so `head -20` truncates it away and the grep fails. The error message
*"exported binary did not boot to the tutorial"* is therefore true but for the
wrong reason, and would fire identically on a healthy-but-noisy boot. Two
defects stacked: the game is broken, and the check that caught it cannot tell
you that.

### Defects still open (re-verified this review, all unchanged)

| Check | Result |
|---|---|
| `infrastructure_manager.gd:52-63` `try_complete()` | Still loops **every** cell of `_dangerous_tiles(seg)` (lines 59-61) and returns false on any uncovered one — whole-segment semantics, not ADR 0016 span semantics |
| `infrastructure_manager.gd:96-102` `build_full()` | Still paves every dangerous tile of the segment in one call |
| `simulation.gd:81-82` `build_crossing()` | Still the bare passthrough `return infrastructure.build_full(segment_id, crossing_type)` |
| `main.gd:76-78` | Still a hardcoded `KEY_B` → `TUTORIAL_SEGMENT` build |
| `load_world` call sites | Still exactly one (`main.gd:33`); `main.gd:126-128` still short-circuits with *"Sub-area %d is not loaded yet"* |
| `grep -rn hover` over `scripts/ scenes/ tests/` | **3 hits, all docstrings** (`segment_picker.gd:2`, `confirm_panel.gd:6,66`). No state, no draw path, no test |
| `grep -rn preferred_crossing_type` over `scripts/` | **0 hits.** `simulation.gd:102` still passes only `{ "covered": … }` |
| On-screen feedback | None. `main.gd:159` `_log("+%d crossed safely")` → `Debug.info()` → `print()`. `debug.gd` has no on-screen channel |

### Exit criteria, criterion by criterion

| Phase | Criterion | State |
|---|---|---|
| 1 | Animals route around impassable / across hazardous at the configured rate | **Met** — `pathfinding_test.gd`, `simulation_test.gd` green |
| 1 | Full span → zero-mortality route; partial span → none | **Met by the wrong behaviour** — see B3 |
| 1 | `animal_crossed` fires once per traversal | **Met** — `simulation_test.gd` |
| 1 | Visual **+ audio** placeholder cue, coalesced in 2s | **Half met** — audio wired (`main.gd:160`); no visual → C1 |
| 1 | Named Phase 1 suites green | **Met** |
| 1 | (P1) Species preference weighting biases crossing use | **Not applied** — deliberate deferral, see §3 |
| 2 | Continuous zoom, ≥16px/12px hysteresis, no loading screens | **Met** — `world_select_controller_test.gd`, 19 tests |
| 2 | Locked sub-areas desaturated + lock indicator, zoom blocked | **Logic met, visual unverified** → C3 |
| 2 | Overlay orange→teal ~40%, pulse worst three, segment-mode only, clears | **Logic met, visual unverified** → C3 |
| 2 | Hover highlight | **Not implemented** → C2 |
| 2 | Confirm passes correct `(segment, sub_area)` into construction | **Not met** — dead-ends outside sub-area 7 → B5 |
| 2 | Named Phase 2 suites green | **Met** |
| — | *(implied)* the build launches to the main scene | **Not met** — → B1 |

## 3. Work needed for the first build

Ordered the way you'd actually do it. Each item is buildable.

### Blockers (nothing ships until these exist)

#### B1. Ship `game/data/` inside the exported build
- **Why it blocks:** this is the difference between "an artifact exists" and "a
  build exists". The shipped pck contains no `.json` at all, so
  `SpeciesRegistry.load_all()` fails on all 8 files, `Simulation.load_world()`
  fails on `sub_area_7.json`, and the binary runs a per-frame error storm with an
  empty world. Reproduced above; the failing preset lines are quoted in §2.
- **Files/areas:** `game/export_presets.cfg` — all four presets need the data
  files included. Simplest correct fix is `include_filter="data/*.json"` (or
  `*.json` if the GUT addon's own JSON is acceptable) on each
  `[preset.N]` block; alternatively switch `export_filter` to a mode that
  carries non-resource files. Fold the reasoning into
  `docs/export-setup.md` afterwards so it is not re-derived.
- **Acceptance:** a string scan of the new pck lists all 8 `data/*.json` and all
  12 `data/world/sub_area_*.json`; the exported Linux binary run with
  `--headless` prints `Tutorial loaded` with **no** `Data file missing` or
  `World file missing` errors, and **exits** rather than looping.
- **Depends on:** none. This is the single highest-leverage item on the list — a
  config change measured in lines, standing between the project and its first
  real build.
- **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md);
  [[../daily-logs/2026-07-27]]; roadmap Phases 1–2.

#### B2. Make the smoke test able to fail honestly
- **Why it blocks:** the current check cannot distinguish "the game is broken"
  from "the log line scrolled past line 20", and it reported the latter for the
  former. Quoted in §2: it pipes through `head -20`, and the success line lands
  at line 69. Left as-is, B1 could be fixed and the gate would still be
  measuring the wrong thing — or worse, pass while the binary is on fire.
- **Files/areas:** `.github/workflows/ci.yml`, the *Smoke-test the Linux binary*
  step.
- **Acceptance:** the step greps the **whole** captured output, not `head -20`;
  it additionally **fails** if the output contains `Data file missing`,
  `World file missing`, or `SCRIPT ERROR`; and it fails if the binary does not
  exit before the timeout. Verified by pointing the step at a deliberately
  broken export and watching it fail with the right message.
- **Depends on:** none (can land alongside B1; ideally *before*, so B1's fix is
  proven by a gate that works).
- **Size:** S
- **Refs:** `ci.yml`; [[../daily-logs/2026-07-27]] "Open questions";
  [testing-setup](../../docs/testing-setup.md).

#### B3. Implement ADR 0016 span geometry
- **Why it blocks:** the Phase 1 exit criterion *"a fully spanned overpass yields
  a zero-mortality route"* is satisfied by the **wrong** behaviour, re-verified
  unchanged this review (`infrastructure_manager.gd:52-63`,
  `:96-102`, `simulation.gd:81-82` — all quoted in §2). Pressing **B** paves all
  20 tiles of `s7_trans_canada_bow_a`: the tutorial highway ceases to exist, at
  100,000 against a 50,000 starting budget.
- **Files/areas:** `game/scripts/systems/infrastructure_manager.gd`
  (`try_complete()` adopts the two-sided-core predicate; `build_full()` renamed
  and re-scoped to a *span*); `game/scripts/systems/simulation.gd`
  (`build_crossing()` takes a span location); and three test files whose
  assertions encode whole-segment semantics —
  `game/tests/infrastructure_manager_test.gd`, `game/tests/pathfinding_test.gd`,
  `game/tests/simulation_test.gd`. **Both `build_crossing()` call sites must
  change:** `main.gd:77` and `main.gd:129`.
- **Acceptance:** `infrastructure_manager_test.gd` green with the seven rows of
  the ADR 0016 verified-behaviour table as cases — especially the two rejections
  (half-width span; tiles laid *along* the corridor). Bow Valley
  full-width-at-r=5 → valid, 2 tiles, 10,000. The core-size search cap must be a
  named constant with a comment, per the ADR's stated trade-off.
- **Depends on:** none (the ADR is now committed — `1eb9a2d`).
- **Size:** M
- **Refs:** [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md);
  [ADR 0003](../../docs/adr/0003-crossing-tile-architecture.md) (amended);
  [[../design/segment-vs-span-defect]]; roadmap Phase 1 exit criteria.

#### B4. Span placement UI (build mode + ghost preview + running cost)
- **Why it blocks:** ADR 0016 and the defect memo both decide **the player picks
  where the span goes**. Once B3 lands, `build_crossing()` needs a span location
  and there is no way for a player to supply one — `main.gd:76-78` is still a
  hardcoded `KEY_B` build. Without this, B3 makes the game *less* playable. The
  ADR also requires running cost be visible during placement.
- **Files/areas:** new `game/scripts/ui/build_mode.gd` (or extend
  `segment_picker.gd`), `game/scripts/main.gd`, a ghost-preview draw path in
  `game/scripts/world/world_renderer.gd`.
- **Acceptance:** a new `build_mode_test.gd` green; in a windowed run the player
  can enter build mode, hover tiles across the Bow Valley corridor, see a ghost
  and a running cost, and confirm a 2-tile / 10,000 span; an invalid
  (half-width) candidate is refused with a legible message.
- **Depends on:** B3.
- **Size:** L
- **Refs:** [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md)
  §"Negative / Trade-offs"; [[../design/segment-vs-span-defect]] open question 4;
  [crossing-location-selection](../prd/crossing-location-selection.md).

#### B5. Sub-area load path — or an explicit Bow-Valley-only scope
- **Why it blocks:** the Phase 2 exit criterion *"confirm passes the correct
  `(segment, sub_area)` into the construction step"* is **not met**, unchanged
  this review. `main.gd:33` calls `sim.load_world(TUTORIAL_SUB_AREA, …)` exactly
  once and nothing else ever calls it; `main.gd:126-128` short-circuits any
  confirmation outside sub-area 7. The 11 other authored maps — all valid, all
  covered by `segments.json` — are dead data in the shipped build.
- **Files/areas:** `game/scripts/main.gd`,
  `game/scripts/systems/simulation.gd` (`load_world` reload path),
  `game/scripts/ui/world_select_controller.gd`.
- **Acceptance:** *either* confirming a segment in any unlocked sub-area loads
  that world and seeds construction (with a `simulation_test.gd` case covering a
  reload), *or* — the cheap resolution — the first build is deliberately scoped
  to Bow Valley, the other 11 sub-areas are presented as locked, and that scope
  is written into the roadmap and the v0.1.0 release note so it reads as a
  decision rather than a bug.
- **Depends on:** none. **Needs an owner call on which resolution.** Carried
  unanswered from 2026-07-21; it changes what B6 and V6 ship, so it is getting
  more expensive to leave open, not less.
- **Size:** S (scoped) / L (full load path)
- **Refs:** roadmap Phase 2 exit criteria; [sub-areas](../prd/sub-areas.md);
  [[../daily-logs/2026-07-10]].

#### B6. Launch a binary and confirm it plays
- **Why it blocks:** this **is** the build, and it is now genuinely close —
  half-closed rather than untouched, which is new. Artifacts exist for three
  platforms. What does not exist is a single observation of one of them running.
  Given B1, the honest expectation is that today's artifacts do not play at all.
- **Files/areas:** `wildlife-crossing-desktop-builds/`, `builds/`,
  `.github/workflows/ci.yml` `export` job, `docs/export-setup.md`.
- **Acceptance:** a windowed launch on Brent's Mac reaching the tutorial scene
  with animals moving, **plus** the `--headless` run printing `Tutorial loaded`
  cleanly. The macOS zip is unsigned, so it needs
  `xattr -dr com.apple.quarantine` before it will open.
- **Depends on:** B1 (a build with data), B2 (a gate that can confirm it). The
  *content* of a build worth keeping additionally depends on B3, B4, B5, C1.
- **Size:** M
- **Refs:** [export-setup](../../docs/export-setup.md);
  [[../daily-logs/2026-07-27]]; [[2026-07-21-next-build]] B4.

### Core build work (the exit-criteria tasks)

#### C1. Visual half of the crossing cue + minimal HUD
- **Why:** roadmap Phase 1 requires a *"visual + audio placeholder cue"*; only
  audio exists (`main.gd:160`). All player feedback routes through `Debug` to
  **stdout** — correct by `game/CLAUDE.md` convention, invisible in a windowed
  export, where there is no Output panel. A binary that launches and shows the
  player nothing is not the "first playable".
- **Files/areas:** `game/scripts/main.gd`, new `game/scenes/ui/Hud.tscn` +
  `game/scripts/ui/hud.gd`, a placeholder sprite under `game/assets/sprites/`
  (currently `.gitkeep` only). Keep `Debug` logging; add an on-screen channel
  beside it.
- **Acceptance:** in an **exported** binary the coalesced "+N crossed" cue is
  visible on screen alongside the chime, and build result + current mode are
  legible without the editor.
- **Depends on:** none for the code; B1 to verify it in an export.
- **Size:** M
- **Refs:** roadmap Phase 1 exit criteria;
  [pre-build-checklist](../../docs/pre-build-checklist.md) B1;
  [[../daily-logs/2026-07-19]].

#### C2. Hover highlight
- **Why:** a named Phase 2 P0 exit criterion and a named P0 test in
  [test-plan](../../docs/test-plan.md) §11
  (`test_hover_highlights_dangerous_only`). Re-verified entirely unimplemented:
  `grep -rn hover` over `scripts/ scenes/ tests/` returns three docstring
  mentions and nothing else.
- **Files/areas:** `game/scripts/ui/world_select_controller.gd`,
  `game/scripts/world/world_renderer.gd`, new
  `game/tests/hover_highlight_test.gd`.
- **Acceptance:** `test_hover_highlights_dangerous_only` green; at segment zoom
  the hovered segment highlights and only dangerous tiles are highlighted.
- **Depends on:** C4 (needs something rendered in-map to hover over).
- **Size:** M
- **Refs:** roadmap Phase 2 exit criteria;
  [test-plan](../../docs/test-plan.md) §11;
  [crossing-location-selection](../prd/crossing-location-selection.md).

#### C3. Non-headless display + audio QA pass
- **Why:** owed since 2026-07-08 and still unpaid — now for a concrete reason:
  **Godot 4.6.3 is not installed on the Mac** ([[../daily-logs/2026-07-27]]).
  Every *visual* Phase 2 criterion is verified only by unit tests asserting
  *state*, never by looking at pixels. Headless cannot QA rendering.
- **Files/areas:** no code change expected; findings feed back into
  `world_renderer.gd`, `connectivity_overlay.gd`, `Animal.tscn`.
- **Acceptance:** a written QA note in `obsidian-vault/daily-logs/` confirming
  each Phase 2 visual criterion observed on screen, plus the audio cue audible
  once per coalesced window.
- **Depends on:** reinstalling Godot 4.6.3 locally (grab
  `Godot_v4.6.3-stable_export_templates.tpz` at the same time); best run after
  C1 and C4 so there is something to look at.
- **Size:** S
- **Refs:** roadmap Phase 2 exit criteria; [[2026-07-07-next-build]] §5;
  [testing-setup](../../docs/testing-setup.md).

#### C4. In-map segment renderer
- **Why:** `segment_picker.gd` is real and tested (7 tests), but segment mode is
  still drawn over by the placeholder card grid, so picking is **not
  observable** — flagged as owed in [[../daily-logs/2026-07-10]]. Prerequisite
  for C2 and for the visual half of C3.
- **Files/areas:** `game/scripts/world/world_renderer.gd`,
  `game/scripts/ui/world_select_controller.gd`,
  `game/scenes/ui/WorldSelectMap.tscn`.
- **Acceptance:** at segment zoom the loaded sub-area's tiles render in-map with
  segments distinguishable; `world_select_controller_test.gd` stays green.
- **Depends on:** none.
- **Size:** M
- **Refs:** roadmap Phase 2 exit criteria;
  [crossing-location-selection](../prd/crossing-location-selection.md).

#### C5. Confirm the tutorial actually demonstrates the mechanic
- **Why:** [[../design/detour-cost-question]] establishes that only **2 of 19**
  segments bisect their sub-area, so on the other 17 an animal can route around
  the corridor's end without entering a hazard. Bow Valley
  (`s7_trans_canada_bow_a`) is one of the two that *does* separate — so the
  tutorial should demo correctly — but the memo says explicitly this is worth
  confirming rather than assuming, because it is the first thing any player sees.
- **Files/areas:** a throwaway measurement script or a temporary GUT case over
  `pathfinding.gd` + `simulation.gd`.
- **Acceptance:** measured baseline mortality on `s7_trans_canada_bow_a` is
  non-zero before a crossing exists, and measurably drops once a valid span is
  built.
- **Depends on:** B3 (a valid span must be buildable to measure the "after").
- **Size:** S
- **Refs:** [[../design/detour-cost-question]] check 3;
  [simulation-design](../../docs/simulation-design.md).

### Verification (tests, CI, export)

#### V1. Guard the export's *contents*, not just its existence
- **Why:** B1 shipped for however long the presets have existed, through a green
  test suite and an export job, because nothing anywhere asserts that the build
  contains the files the game reads. B2 catches it at boot; this catches it at
  pack time, with a clearer message. The pair is what stops this class of defect
  recurring.
- **Files/areas:** `.github/workflows/ci.yml` (a step after *Export desktop
  presets*), or a small script under `tools/`.
- **Acceptance:** CI fails if the exported pck is missing any of the 8
  `data/*.json` or 12 `data/world/*.json` files; verified against a pck built
  with the old presets.
- **Depends on:** B1.
- **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md); §2 above.

#### V2. Exclude GUT and `tests/` from release exports
- **Why:** the shipped pck carries **236 `addons/gut/` paths and 30 `tests/`
  paths**. Not the cause of anything today, but it is dead weight in a release
  build, it ships the test framework to players, and it is the same
  `export_filter` decision B1 is about — cheapest to fix in the same pass.
- **Files/areas:** `game/export_presets.cfg` (`exclude_filter` on all four
  presets).
- **Acceptance:** a string scan of the new pck shows zero `addons/gut/` and zero
  `tests/` paths, and the binary still boots to the tutorial.
- **Depends on:** B1 (same file, same edit session).
- **Size:** S
- **Refs:** [[../daily-logs/2026-07-27]] "Open questions".

#### V3. Gitignore (or relocate) `wildlife-crossing-desktop-builds/`
- **Why:** 232 MB of untracked binaries are sitting in the repo root.
  `git check-ignore` returns nothing for the directory, while `builds/` *is*
  ignored — so a `git add -A` commits them, against the root `CLAUDE.md` policy
  that binaries go to GitHub Releases. It will also be re-flagged by every future
  review until it is resolved.
- **Files/areas:** root `.gitignore`, or move the downloaded artifacts under the
  already-ignored `builds/`.
- **Acceptance:** `git status --short` is clean of it; `git check-ignore -v`
  names the rule.
- **Depends on:** none.
- **Size:** S
- **Refs:** root [CLAUDE.md](../../CLAUDE.md) "Releases"; root `.gitignore`.

#### V4. CI assertion on expected test-script count
- **Why:** the 2026-07-10 guard catches a *zero*-test run, but 2026-07-19 hit a
  **partial** drop — a parse error took one file out, GUT printed
  `---- All tests passed! ----` and exited 0, and the only signal was the script
  count falling 15 → 14. Re-read this review: the guard still counts
  `<testcase>` elements only, so a partial drop still looks healthy.
- **Files/areas:** `.github/workflows/ci.yml`, the *Guard against a
  silently-empty suite* step.
- **Acceptance:** CI fails when the JUnit XML reports fewer than the expected
  number of test scripts (currently 15); verified against a synthetic short XML.
- **Depends on:** none.
- **Size:** S
- **Refs:** [testing-setup](../../docs/testing-setup.md);
  [[../daily-logs/2026-07-19]].

#### V5. Add `env_config.gd` coverage
- **Why:** still the only untested script carrying real branching logic — it owns
  per-terrain mortality lookup and the resolution order (override → OS env →
  `DEFAULT` 0.20, `env_config.gd:21-31`), which is precisely what the Phase 1
  criterion *"deaths at the configured env-var rate"* rests on.
- **Files/areas:** new `game/tests/env_config_test.gd`.
- **Acceptance:** resolution order covered end to end; suite reaches 16 scripts.
  GUT only discovers a new `*_test.gd` after a re-`--import`.
- **Depends on:** none.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md); roadmap Phase 1 exit criteria.

#### V6. Reconcile `docs/test-plan.md` §11 against the real suite
- **Why:** §11 is the P0 coverage table — the acceptance bar for a first playable
  — and 22 of its 31 named P0 tests have no matching function name. Mostly
  renames, but the table can no longer be used as a checklist, and it hides two
  real holes (C2, and the deferred preference weighting).
- **Files/areas:** `docs/test-plan.md` §11.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason.
- **Depends on:** C2.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md) §11.

#### V7. Cut `v0.1.0` — release note + GitHub Release
- **Why:** `docs/release-notes/` holds only `.gitkeep` and `git tag -l` is empty,
  so there is still no anchor for "most recently shipped" and the next review has
  no milestone to diff against. If B5 resolves as "scoped to Bow Valley", the
  release note is where that scope gets stated.
- **Files/areas:** `docs/release-notes/v0.1.0.md`, a `v0.1.0` tag, a GitHub
  Release with the desktop binaries attached.
- **Acceptance:** release note follows the [docs/CLAUDE.md](../../docs/CLAUDE.md)
  format; the Release carries launchable binaries.
- **Depends on:** B6 (and, for a build worth releasing, B3, B4, B5, C1).
- **Size:** S
- **Refs:** [docs/CLAUDE.md](../../docs/CLAUDE.md);
  [export-setup](../../docs/export-setup.md).

### Deferrable / nice-to-have

- **Explicitly deferred: species preference weighting** (roadmap Phase 1, P1).
  `grep -rn preferred_crossing_type scripts/` returns **zero hits**;
  `simulation.gd:102` passes only `{ "covered": … }`. P1, so not a first-build
  blocker — recorded as a deliberate deferral rather than an oversight.
- Delete `docs/b1-commit-runbook.md` — B1 has landed; the 2026-07-27 log already
  calls for it. Still untracked.
- Fold the 2026-07-27 CI diagnosis (ETC2 ASTC gate, `pipefail` discarding good
  binaries) into `docs/testing-setup.md` so it is not re-derived.
- **`BaseScreen` convention debt.** `game/CLAUDE.md` specifies UI scenes inherit
  a `BaseScreen` scene; `ui/base_screen.gd` / `BaseScreen.tscn` don't exist, and
  `ConfirmPanel` / `ConnectivityOverlay` are bare code-instantiated nodes with no
  `.tscn`. C1's HUD will face the same decision — worth a call before adding a
  fourth ad-hoc UI node.
- Retire or rewrite `docs/pre-build-checklist.md` — actively misleading (§4).
- Reconcile `docs/architecture.md` §1 and `game/CLAUDE.md`'s systems table (§4).
- Real art: `game/assets/sprites/`, `tilesets/`, `fonts/` are still `.gitkeep`;
  presets ship the default Godot icon.
- Tidy stale `.gitkeep` files now shadowed by real content
  (`game/scenes/ui/`, `game/scenes/world/`, `game/assets/audio/`) and the empty
  `builds/wildlife-crossing-linux-arm64/` directory.
- Pin the CI `GODOT_VERSION` (`4.6-stable`) and the local `tools/` binary
  (`4.6.3-stable`) to the same patch. ADR 0012 permits any 4.6.x, but
  export-template paths are version-keyed and this has already cost one
  misdiagnosis.
- Triage `obsidian-vault/prd/minigame-ideas.md` — still unassigned to a phase.
- macOS notarization / Windows signing before any public release.
- Phase 5 gates (liaison-NPC decision, cultural-advisor review) remain open and
  still do not block P0.

## 4. Doc drift to fix

Record only — docs not edited during a review.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | "`game/` is still almost entirely `.gitkeep`"; A1 "no `project.godot`"; A2 "GUT not installed"; A3 "no CI"; A4 "zero game code"; A5 "only `sub_areas.json` and `biome_groups.json`"; A6 "only the `bow_valley_slice` fixture"; all B0/B1/B2 boxes unchecked | Every one is false, and unchanged since last review flagged it. 23 scripts / 2,149 LOC, `project.godot` with 4 autoloads, GUT 9.6.0 vendored, a two-job CI, all 8 data files valid, 12 authored world maps, 15 test scripts. B0/B1/B2 are done **except** the cue's placeholder **sprite** (→ C1) and `scenes/world/WorldMap.tscn`, which was never created and is now obsolete. `status: active` makes this file a trap for onboarding — retire or rewrite. |
| [testing-setup.md](../../docs/testing-setup.md):70 | "the suite currently reports **5 scripts / 28 tests** passing" | Measured this review: **15 scripts / 116 tests / 2,740 asserts**. Off by 3× — anyone using this line as a sanity check would accept a suite that had lost two-thirds of itself. |
| [testing-setup.md](../../docs/testing-setup.md) | Documents the zero-tests silent-pass gap as unguarded; says nothing about the export pipeline | The V1 guard landed 2026-07-10 (`8318dc2`). A *partial* script drop still passes green (→ V4). The 2026-07-27 CI diagnosis (ETC2 ASTC gate; `set -euo pipefail` discarding finished binaries for 16 days) is not recorded anywhere but the daily log. |
| [export-setup.md](../../docs/export-setup.md) | Presented as a complete export runbook | It never mentions `include_filter`, `exclude_filter`, or the fact that Godot's `all_resources` filter silently drops non-resource files like `.json`. That omission is B1. |
| [architecture.md](../../docs/architecture.md) §1 | Lists 8 systems (`economy_manager`, `information_manager`, `permissions_manager`, `season_manager`, `time_controller`, `milestone_tracker`, `save_manager`, `narrative_manager`), 8 UI scripts, and 4 scenes | None exist. All Phase 3–6, so not a regression — but the table reads as a description of the codebase and overstates it. Only `Main.tscn`, `ui/WorldSelectMap.tscn`, `world/Animal.tscn` exist; `ConfirmPanel` and `ConnectivityOverlay` are built in code (`main.gd:39`, `main.gd:141`). Split the table into *planned* vs *built*. |
| [architecture.md](../../docs/architecture.md) §1 **and** [game/CLAUDE.md](../../game/CLAUDE.md) | Neither systems table lists `env_config.gd` | It exists (31 LOC) and is referenced by `data-schemas.md` and `simulation-design.md`. `game/CLAUDE.md` states its own rule — *"Add a row here whenever a new system is created"* — so this is a convention miss, not just an omission. |
| [roadmap.md](../../docs/roadmap.md) Phase 1 exit criteria | "A fully spanned overpass yields a zero-mortality route" | Predates [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md). "Fully spanned" now means a valid **span** (two-sided core across the corridor), not full **segment** coverage. As written, the criterion is satisfied by the defective behaviour. |
| [test-plan.md](../../docs/test-plan.md) §11 | P0 coverage table names 31 tests as the first-playable bar | 22 have no matching function name in `game/tests/`. Mostly renames, but the table can no longer be used as a checklist. See V6. |
| [[2026-07-21-next-build]] | B1 open; V2 "could not verify"; B4 "no binary has ever been produced" | B1 closed (`ea6f4cf`…`9ba62e2`). V2 answered: CI had never gone green; the hoped-for 2026-07-11 artifact never existed. B4 half-closed: three binaries now exist, none verified to boot. |
| [[../daily-logs/2026-07-27]] | "First artifacts in project history … Linux, Windows and macOS builds now exist and are downloadable" | True and worth celebrating, but incomplete: the artifacts contain no game data (§2). The log's own open question — *"the smoke test fails"* — has an answer, and it is not a grep problem. |

## 5. Risks & open questions

- **The export defect is a class, not an instance.** The build was green at every
  gate the project has — suite, zero-test guard, export job — while shipping
  nothing the game could read. The lesson worth banking is that *every check so
  far tests the source tree, and none tests the artifact*. B2 and V1 are the
  cheap correction; without them the next artifact-shaped defect gets found the
  same way, by hand, weeks later.
- **B5 still needs an owner call, and it is a scope decision, not a technical
  one.** Ship the first build as Bow Valley only (S, honest, arguably the right
  shape for a tutorial-first release), or build the sub-area load path (L). The
  cheap option is only cheap if it is *stated* — otherwise 11 authored maps
  silently do nothing and the review after next re-discovers it. Carried
  unanswered for two weeks.
- **Will animals actually use a crossing?** ([[../design/detour-cost-question]],
  status `draft`, unresolved.) Hazard tiles are passable-with-risk, not walls,
  and only 2 of 19 segments cut their map in two. If detouring is cheaper than
  the mortality-weighted crossing cost, the player watches a 10,000 structure sit
  unused. Three logged resolutions await a decision. Not a first-build blocker —
  Bow Valley is one of the two that does bisect — but it is the largest open
  design question in the project and it only gets more expensive to answer.
- **ADR 0016's core-size search cap is undecided.** The ADR notes naive
  enumeration of two-sided cores is exponential and says the cap "must be
  documented where it is set". Pick and justify a bound during B3.
- **Godot 4.6.3 is not installed on Brent's Mac.** Blocks C3, local exports, and
  playing the game at all. `Godot_v4.6.3-stable_export_templates.tpz` is worth
  grabbing in the same sitting — it is the one missing piece for local exports,
  and it would make the build reproducible somewhere other than a CI runner.
- **This review could not observe CI directly.** The GitHub connector is
  unauthorized in this session (as it was on 2026-07-21). Every claim about the
  2026-07-27 run's outcome comes from [[../daily-logs/2026-07-27]] and from the
  artifacts on disk, not from reading the run. The artifacts themselves are hard
  evidence; the job-by-job status is second-hand.
- **The Linux artifact could not be executed here.** The sandbox is `aarch64` and
  the binary is `ELF 64-bit … x86-64`. The export defect was therefore proven by
  inspecting the pck and by reproducing the data-less environment from source —
  strong evidence, but a direct run of the shipped x86_64 binary on Brent's
  machine would close the loop.
- **Art remains a hard dependency on the owner.** Sprites, tilesets and fonts are
  empty; the first build will be coloured shapes on a placeholder grid.
  Acceptable for a *first playable* — but it means "playable" rests entirely on
  C1, which needs at least one placeholder sprite.

## 6. Suggested next-week focus

Given dependencies and size, pull these first:

1. **B1 — ship `game/data/` in the export** (S). A config change measured in
   lines, and the single thing standing between three existing artifacts and a
   build that runs. Do it first because everything about "first working build"
   is downstream of it.
2. **B2 — fix the smoke test** (S). Ideally *before* B1, so B1's fix is proven by
   a gate that can tell the truth. Fold V1 and V2 in while the same two files are
   open — the four together are one afternoon.
3. **B6 — launch the resulting binary** (M). Once B1 and B2 land, this becomes
   "download and double-click". Getting a first playable launch observed on the
   Mac is the milestone this project has been circling since 2026-07-06.
4. **B5 — make the sub-area scope call** (S). A decision, not a build. It changes
   what B6 and V7 are shipping, so it wants answering before them, and it has now
   been open two reviews.
5. **B3 — implement ADR 0016** (M). The one genuine correctness defect in Phase
   1; the spec is written and verified against real data. Then **C1** (M), which
   is independent and is the difference between a binary that launches and one
   that can be played.

The shape of the week is unusual and worth naming: items 1–3 are small, and they
convert an existing artifact into a real one. That is a good week's work even
though almost none of it is game code — and it is the first time the first build
has been a config problem rather than a construction problem.

---

## Related

- [[roadmap]]
- [[pre-build-checklist]]
- [[testing-setup]]
- [export-setup](../../docs/export-setup.md)
- [ADR 0016 — crossing span geometry](../../docs/adr/0016-crossing-span-geometry.md)
- [[../design/segment-vs-span-defect]]
- [[../design/detour-cost-question]]
- [[../daily-logs/2026-07-27]]
- Previous review: [[2026-07-21-next-build]]
