---
title: "Build Review — Next Build (2026-08-04)"
date: 2026-08-04
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> roadmap [[roadmap|Phases 1–2]]). One question: what work is needed to get
> there?

## 1. Summary

- **Build case:** **FIRST working build** — by the harness's own test, which is
  narrow and worth quoting: *"There is a working build only if you can point to
  an actual export in `builds/` or a GitHub Release **and** it launches."*
  `builds/` holds `.gitignore`, `.gitkeep` and one empty directory. `git tag -l`
  is empty. `docs/release-notes/` holds only `.gitkeep`. So: first build.
  [[../daily-logs/2026-07-30]] records a CI artifact built from `6e6efe4` that
  was verified clean and launched windowed on Brent's Mac — but that is a log
  entry, not something this review could check, and the artifact is not on disk
  here. It is labelled **Unverifiable** in §Verification and nothing below
  depends on it being true.
- **Target milestone & exit criteria:** roadmap
  [Phase 1](../../docs/roadmap.md) (core simulation + overpass validation) and
  [Phase 2](../../docs/roadmap.md) (location selection + sub-areas).
- **Headline:** **3 blockers, 4 core tasks, 6 verification items.** Two real
  achievements since the last review: B4 (span placement UI, `65e69dc`) and C1
  (crossing cue + HUD, `25d33b9`) both landed, and the suite grew 116 → **144
  tests, all green**, re-run this session. Three things need naming, none of
  them alarming.
  1. **No build of current `HEAD` has ever been launched or looked at.** Three
     commits have landed since `6e6efe4` — `e24a3f6` (docs), `65e69dc` (span
     placement UI) and `25d33b9` (HUD) — and the two code commits are precisely
     what makes the game playable rather than merely bootable. A CI export of
     `HEAD` most likely *exists*: the `project-state` artifact records a browser
     read on 2026-08-02 showing **CI #8 green on `25d33b9`**, which means the
     export job ran and both gates passed. But nobody has downloaded it, run it,
     or seen the HUD and span UI on a screen. The only artifacts on disk are
     from 2026-07-27/28 and **fail the repo's own gate**
     (`check_pck_contents.py` → exit 1, 244 development-only paths).
  2. **Four core items from the 2026-07-28 review were dropped rather than
     closed.** C2 (hover highlight), C3 (visual QA), C4 (in-map segment
     renderer) and C5 (tutorial demonstrates the mechanic) were never amended
     shut, and [[../daily-logs/2026-07-31]] states that no core tasks remain
     open. All four are re-verified open below. Note the correction the audit
     forced on this review's own first draft: **hover highlight is a Phase 2 P0
     *requirement* (`roadmap.md:85`, the Implements list), not one of the five
     Phase 2 exit criteria (`:98-108`), and an in-map segment renderer appears
     nowhere in the roadmap at all.** That makes them more deferrable than they
     first looked — which is exactly why the decision should be made
     deliberately rather than by silence.
  3. **The world-map click path is blind in an exported build.** Newly found:
     `main.gd:154` resolves a segment click through
     `_renderer.coord_at_px(get_global_mouse_position())` — against the *world*
     camera — while `world_select_controller.gd:183` paints an opaque
     (alpha 0.96) backdrop and card grid over the entire screen, and
     `WorldSelectMap.tscn` sets `mouse_filter = 2` so clicks pass straight
     through. The player sees cards and clicks a hex they cannot see. Not a
     crash, and the code's own docstring (`main.gd:146-148`) acknowledges the
     cause — but the player-facing consequence is recorded nowhere, and it is
     the strongest argument for shipping the segment renderer in v0.1.0.
- **Change since last review:** [[2026-07-28-next-build]] — **all six blockers
  closed** (B1 withdrawn as misdiagnosed; B2, B3, B4, B5, B6 amended shut) and
  **C1 closed**. V1, V2 and V3 closed. **Newly open:** no export of `HEAD`; the
  four dropped core items; the blind world-map click; the `Linux arm64` preset
  that is defined but never exported; Windows and macOS artifacts that no gate
  has ever checked. **Off the drift list:** `docs/export-setup.md`'s
  `include_filter`/`exclude_filter` gap is fixed.

## 2. Current state (evidence)

Grounded in this review's own inspection, a fresh headless GUT run, a headless
boot from source, and the repo's own pck gate run against the artifacts on disk.

- **Systems:** **26 scripts / 2,567 LOC** in `game/scripts/` (was 23 / 2,149 on
  2026-07-21 and 07-28), **zero stubs**. The four autoloads are registered at
  `game/project.godot:22-25`. New since the last review: `ui/base_screen.gd`
  (23), `ui/hud.gd` (69), `ui/build_mode.gd` (86). Absent but named in
  `docs/architecture.md:52-58`: `economy_manager`, `information_manager`,
  `permissions_manager`, `season_manager`, `time_controller`,
  `milestone_tracker`, `narrative_manager`, `save_manager` — all Phase 3–6, so
  not a regression.
- **Data:** all **8** canonical files in `game/data/` present and valid JSON;
  all **12** `data/world/sub_area_*.json` valid; `segments.json` holds **19
  segments covering all 12 sub-areas**. Verified by `json.load` on each.
- **Scenes & wiring:** `game/scenes/Main.tscn` is `run/main_scene`
  (`project.godot:17`). `main.gd:44-73` instantiates `Simulation`,
  `WorldRenderer`, `ConnectivityOverlay`, `Camera2D` and now `Hud`; autoloads
  are resolved by `get_node_or_null` at `:43`, `:80`, `:87`, `:136` and `:139`.
  `scenes/ui/` holds `WorldSelectMap.tscn`, `scenes/world/` holds `Animal.tscn`
  (which nothing references — agents are drawn as circles by
  `world_renderer.gd:34-36`).
- **Tests:** GUT 9.6.0 via the vendored
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` against `game/.gutconfig.json` —
  **18 scripts / 144 tests / 2,799 asserts, all passing (1.049s)**, exit 0. Up
  from 15 / 116 / 2,740 at the last review. Matches the count in
  [[../daily-logs/2026-07-31]] exactly. **9 scripts have no test:** `main.gd`,
  the four autoloads (`game_state`, `event_bus`, `debug`, `species_registry`),
  `env_config.gd`, and the three constants files.
- **Headless boot from source:** clean. `[I] Tutorial loaded. Press B to build
  the Bow Valley overpass. Press M for the world map.` on output line 3, no
  errors. (Exit 124 is correct and expected — the game has no auto-quit; see the
  header comment in `tools/smoke_boot.sh`.)
- **CI:** `.github/workflows/ci.yml`, 144 lines, two jobs, `GODOT_VERSION:
  4.6.3-stable` pinned to the exact patch (`:15`). `test` runs `--headless
  --import` then GUT with JUnit XML, then the zero-tests guard (`:50-64`).
  `export` builds the Linux x86_64 / Windows x86_64 / macOS presets, runs
  `tools/check_pck_contents.py` **on the Linux pck only** (`:123-125`), runs
  `tools/smoke_boot.sh` **on the Linux binary only** (`:130-133`), and uploads
  with `if: always()` and 14-day retention. **The `Linux arm64` preset defined
  at `export_presets.cfg:32-62` is never exported.** *Whether the last CI run
  passed is **Unverifiable** this session — but a prior-session browser read
  preserved in the `project-state` artifact records **CI #8 green on `25d33b9`,
  1 Aug 13:31**. See §Verification.*
- **Build/export:**
  - `builds/` — `.gitignore`, `.gitkeep`, and the empty stale
    `builds/wildlife-crossing-linux-arm64/`. No binaries.
  - `wildlife-crossing-desktop-builds/` — **429,939,403 B (411 MB)** of Linux,
    Windows and macOS artifacts dated **2026-07-27/28**, including an unpacked
    `.app`. All three `.pck` files are 1,640,952 B and pack **format 3, built by
    Godot 4.6.0**; the Linux and macOS packs are byte-identical
    (`md5 934e8b12…`), the Windows pack differs (`md5 a2dbbbee…`). All contain
    the 20 data files **and** 213 `addons/gut` entries and 31 `tests/` entries.
    Running the repo's own gate:
    `python3 tools/check_pck_contents.py … --data-dir game/data` →
    **exit 1**, *"exported pack ships 244 development-only path(s)"*. They
    pre-date `260b5d6` (2026-07-30 14:45:30), the commit that added
    `exclude_filter="addons/gut/*,tests/*"`.
  - **No artifact under `builds/` or `wildlife-crossing-desktop-builds/` was
    built from current `main`** — every file there predates `65e69dc`
    (2026-07-30) and `25d33b9` (2026-08-01).
  - `git tag -l` → empty. `docs/release-notes/` → `.gitkeep` only.
    → **first build.**
- **Git:** branch `main`, `HEAD` == `origin/main` == `25d33b9` (*feat: visual
  crossing-success cue and minimal HUD*, 2026-08-01). Working tree carries one
  pre-existing modification, `harness/weekly-build-review/SKILL.md` (plus this
  review's own edit to `build-reviews/README.md`). A stale `.git/index.lock` is
  present again — the same recurring artifact of this harness noted on
  2026-07-28 and 2026-07-30.
- **Assets:** `audio/crossing_chime.wav` (61,782 B) and
  `sprites/crossing_cue.png` (341 B, generated placeholder) are the only real
  assets. `crossing_cue.png` is genuinely wired — `hud.gd:14` preloads it,
  `hud.gd:55 show_crossing_cue()` uses it, `main.gd:267` calls it inside the
  coalesced window, `hud_test.gd:34,40,48` covers it. `fonts/` and `tilesets/`
  are still `.gitkeep` only. Note that `game/.gitignore:3` excludes `*.import`,
  so both assets are re-imported from scratch on every CI run and nothing
  asserts they survive into the pack.

### The world-map click defect

New this review. Three facts that only bite together, which is why tests are
green:

1. `main.gd:154` — `_pick_segment_at_mouse()` maps the cursor to a hex with
   `_renderer.coord_at_px(_renderer.get_global_mouse_position())`, i.e. against
   the **world** camera.
2. `world_select_controller.gd:33,183` — world-select mode paints
   `COLOR_BACKDROP = Color(0.08, 0.10, 0.09, 0.96)` over the full rect, then
   draws a **placeholder card grid** (`:201` `_draw_sub_area_card`).
3. `game/scenes/ui/WorldSelectMap.tscn` sets `mouse_filter = 2` (IGNORE), so
   clicks fall through to `main.gd:101` `_unhandled_input`.

So in an exported build, pressing **M** shows a card grid, and clicking a card
selects whatever hex happens to sit under the cursor in the hidden world beneath
it. `SegmentPicker` and `ConfirmPanel` then behave correctly on whatever they
were handed — which is why `world_select_controller_test.gd` (19 tests),
`segment_picker_test.gd` and `confirm_panel_test.gd` are all green. The
docstring at `main.gd:146-148` names the cause (*"the placeholder card grid
can't yet render an unloaded map to pick on"*); the player-facing consequence is
recorded nowhere. This is the case for C1.

### The four dropped core items, re-verified

Each was on the 2026-07-28 review's core list and none was amended closed.
Re-checked from scratch this review:

| Item | What the repo says |
|---|---|
| **C2 hover highlight** | **Open.** `grep -n hover game/scripts/ui/world_select_controller.gd` → **zero hits**. `test_hover_highlights_dangerous_only` is named in [test-plan](../../docs/test-plan.md):172 against `world_select_controller_test.gd`; that file's 19 test functions do not include it. The only `hover` state in the codebase is build-mode tile hover (`world_renderer.gd:20,45-47`; `main.gd:270`) — a **different feature**, added by B4, and probably why this looked closed. |
| **C4 in-map segment renderer** | **Open.** `world_select_controller.gd:28` still reads `# --- placeholder world-map card layout (until real map art lands, B4) ---`; `_draw()` at `:179-199` and `_draw_sub_area_card()` at `:201` still draw the card grid. |
| **C3 visual/audio QA pass** | **Partly done, not written down.** Windowed launches are recorded on 07-29 and twice on 07-30. None covers the overlay treatment or the locked-desaturation treatment, and all pre-date the C1 HUD. C3's acceptance was *a written QA note*; there isn't one. |
| **C5 tutorial demonstrates the mechanic** | **Open.** [[../design/detour-cost-question]] is still `status: draft` and headed *"Unresolved"*. No before/after mortality measurement on `s7_trans_canada_bow_a` exists in any log or test. |

### Exit criteria, criterion by criterion

Phase 2's exit criteria are the five bullets at `roadmap.md:98-108` — hover
highlight and the segment renderer are *not* among them (see §1, headline 2).

| Phase | Criterion | State |
|---|---|---|
| 1 | Animals route around impassable / across hazardous at the configured rate | **Met** — `pathfinding_test.gd`, `simulation_test.gd` green |
| 1 | Full span → zero-mortality route; partial span → none | **Met, and now by the right behaviour** — ADR 0016 span geometry landed in `6e6efe4`; `infrastructure_manager_test.gd` and `build_mode_test.gd` share one static predicate |
| 1 | `animal_crossed` fires once per traversal | **Met** — `simulation_test.gd` |
| 1 | Visual **+ audio** placeholder cue, coalesced in 2s | **Met in code, never seen on a screen** — `hud.gd` + `crossing_cue.png` + `main.gd:266-267`; `hud_test.gd` asserts state, not pixels, and no export exists since C1 landed |
| 1 | Named Phase 1 suites green | **Met** — all five exist and pass |
| 1 | (P1) Species preference weighting; usage counter | **Not applied** — `preferred_crossing_type` and `usage_count`/`times_used` all return 0 hits in `game/scripts/`. Deferral; only the first half has ever been recorded as one |
| 2 | Continuous zoom, ≥16px/12px hysteresis, no loading screens | **Met** — `world_select_controller_test.gd`, 19 tests |
| 2 | Locked sub-areas desaturated + lock indicator, zoom blocked | **Logic met**, rendered as placeholder cards → C1/C3 |
| 2 | Overlay orange→teal ~40%, pulse worst three, segment-mode only, clears | **Logic met, visual unverified** → C3 |
| 2 | Confirm passes correct `(segment, sub_area)`; click-outside and Escape per spec | **Met** — `confirm_panel.gd:93-94,116`; `confirm_panel_test.gd` covers click-outside, Escape and zoom-out-closes. Scoped to Bow Valley by design (`main.gd:160-169`, roadmap Phase 2 decision 2026-07-29). **But see the click defect above: what gets confirmed is correct; what gets *picked* is blind.** |
| 2 | Named Phase 2 suites green | **Met** — all four exist and pass |
| — | *(implied)* an export of the current code launches | **Unverified** — no export of `HEAD` exists → B1 |

## 3. Work needed for the first build

Ordered the way you'd actually do it. Each item is buildable.

### Blockers (nothing ships until these exist)

#### B1. Export and verify a build from current `HEAD`
- **Why it blocks:** three commits have landed since the last artifact anyone
  has *looked at*, two of them the code that makes the game playable — span
  placement (`65e69dc`) and the HUD/crossing cue (`25d33b9`). A CI export of
  `HEAD` probably exists (CI #8 green on `25d33b9`, per the browser read
  preserved in the `project-state` artifact), so the machine-checkable half of
  this may already be done — but no human has run it. The features C1 and B4
  added are, by their nature, only verifiable by watching them: a HUD nobody has
  seen and a mouse-driven placement flow headless cannot exercise. The artifacts
  that *are* on disk fail the repo's own gate (exit 1, 244 dev-only paths), are
  411 MB, and are a standing trap for anyone who mistakes them for the build.
- **Files/areas:** no code change expected — run the pipeline.
  [push-runbook](../../docs/push-runbook.md) is the procedure;
  `.github/workflows/ci.yml` `export` job; `tools/check_pck_contents.py`;
  `tools/smoke_boot.sh`.
- **Acceptance:**
  - `check_pck_contents.py` **exits 0** on the new Linux pck (all 20 data files,
    zero `addons/gut`, zero `tests/`, ~166 KB, banner Godot 4.6.3);
  - the pack also contains `assets/audio/crossing_chime.wav` and
    `assets/sprites/crossing_cue.png` — `game/.gitignore:3` excludes `*.import`,
    so these are re-imported from scratch each run and nothing currently asserts
    they made it in, yet `main.gd:21` and `hud.gd:14` `preload()` them;
  - `smoke_boot.sh` green on the Linux binary;
  - a windowed macOS launch in which **the HUD message line is legible** and the
    "+N crossed safely" cue is observed firing with the chime — the part that
    has never been checked and the entire point of C1;
  - a manual pass over the input surface `main.gd:101-119` owns and no test
    covers: **B**, **M**, left-click, **Enter**, **Escape**.
- **Depends on:** none.
- **Size:** S
- **Refs:** [push-runbook](../../docs/push-runbook.md);
  [export-setup](../../docs/export-setup.md); [[../daily-logs/2026-07-30]];
  roadmap Phase 1 exit criteria.

#### B2. Make the v0.1.0 scope call on C1–C4 — and record it
- **Why it blocks:** four items on the 2026-07-28 core list were never closed
  and are now treated as closed by the index line and by
  [[../daily-logs/2026-07-31]]:94-96. The scope call is genuinely open in both
  directions, and the roadmap is more permissive than this review first assumed:
  hover highlight is a P0 *requirement* in Phase 2's Implements list
  (`roadmap.md:85`), not one of the five exit criteria at `:98-108`, and a
  segment renderer is not in the roadmap at all. So deferring them is
  defensible. What is not defensible is leaving it implicit — B5 spent two weeks
  being re-discovered before the Bow-Valley scope was written down. Cuts the
  other way too: the world-map click defect (§2) means deferring C1 ships a
  build where the map screen is decorative and clicking it does something
  invisible.
- **Files/areas:** `docs/roadmap.md` Phase 2 (a logged decision, in the same
  form as the 2026-07-29 Bow-Valley entry);
  `obsidian-vault/build-reviews/README.md` (the 2026-07-28 index line overstates
  what closed).
- **Acceptance:** each of C1, C2, C3, C4 is either scheduled into v0.1.0 or
  recorded as deferred with a reason and a phase; the Phase 1 P1 **usage
  counter** (`roadmap.md:33`, never mentioned in any review) is swept into the
  same decision alongside preference weighting; and the v0.1.0 release note
  states the resulting scope next to the Bow-Valley-only scope.
- **Depends on:** none. **Needs an owner call.** A decision, not a build — the
  cheapest item here and the one that sets the size of everything else.
- **Size:** S
- **Refs:** [[2026-07-28-next-build]] §3 C2–C5; `roadmap.md:85`, `:98-108`,
  `:33`; [test-plan](../../docs/test-plan.md) §11.

#### B3. Cut `v0.1.0` — release note, tag, GitHub Release
- **Why it blocks:** this is the item that literally decides the build case.
  Five consecutive reviews have answered "first build" on the same three facts —
  empty `builds/`, empty `git tag -l`, empty `docs/release-notes/` — and all
  three are still true. Nothing technical stands in the way any more.
- **Files/areas:** `docs/release-notes/v0.1.0.md`, a `v0.1.0` tag, a GitHub
  Release with the desktop binaries attached; root `CLAUDE.md`'s "binaries via
  GitHub Releases, not committed" policy.
- **Acceptance:** the release note follows [docs/CLAUDE.md](../../docs/CLAUDE.md)
  format and states the Bow-Valley-only scope plus B2's deferral list; the tag
  exists; the Release carries binaries produced by B1's run; **and the binaries
  report their own version** — `game/project.godot` has no `config/version` and
  `export_presets.cfg:138-139` has `application/short_version=""` /
  `application/version=""`, so a downloaded build today cannot be traced back to
  a tag. Set them in the same pass.
- **Depends on:** B1 (a verified build to attach), B2 (the scope to describe).
- **Size:** S
- **Refs:** [docs/CLAUDE.md](../../docs/CLAUDE.md);
  [export-setup](../../docs/export-setup.md); [[2026-07-28-next-build]] V7.

### Core build work

The 2026-07-28 review's C2–C5, renumbered and re-verified. B2 decides which of
these ship in v0.1.0; each drops off with a recorded reason if deferred.

#### C1. In-map segment renderer
- **Why:** `world_select_controller.gd:28` and `:179-201` still draw a
  placeholder card grid. Two consequences. The soft one: segment mode is real
  and tested (19 tests) but **not observable**, so the locked-desaturation and
  overlay criteria cannot be QA'd. The hard one: the click path resolves against
  the world camera underneath the opaque backdrop (§2), so on the map screen the
  player is clicking blind. This is also the prerequisite for C2.
- **Files/areas:** `game/scripts/world/world_renderer.gd`,
  `game/scripts/ui/world_select_controller.gd`,
  `game/scenes/ui/WorldSelectMap.tscn`, `game/scripts/main.gd:148-157`.
- **Acceptance:** at segment zoom the loaded sub-area's tiles render in-map with
  segments distinguishable; a click lands on the segment the player can see —
  `_pick_segment_at_mouse()` and the drawn map agree on a coordinate space;
  `world_select_controller_test.gd` stays green at 19.
- **Depends on:** none.
- **Size:** M
- **Refs:** roadmap Phase 2 Implements;
  [crossing-location-selection](../prd/crossing-location-selection.md);
  [[2026-07-28-next-build]] C4.

#### C2. Hover highlight
- **Why:** a Phase 2 P0 requirement (`roadmap.md:85`) and a named P0 test in
  [test-plan](../../docs/test-plan.md):172
  (`world_select_controller_test.gd::test_hover_highlights_dangerous_only`). The
  test does not exist and `world_select_controller.gd` contains no hover state
  at all. Note the easy misread: B4 added a *build-mode* tile hover
  (`world_renderer.gd:20,45-47`), a different feature at a different moment.
- **Files/areas:** `game/scripts/ui/world_select_controller.gd`,
  `game/scripts/world/world_renderer.gd`, and either a new
  `game/tests/hover_highlight_test.gd` or the named function added to
  `world_select_controller_test.gd`.
- **Acceptance:** `test_hover_highlights_dangerous_only` green; at segment zoom
  the hovered segment highlights and only dangerous tiles are highlighted.
- **Depends on:** C1 (something in-map to hover over).
- **Size:** M
- **Refs:** `roadmap.md:85`; [test-plan](../../docs/test-plan.md) §11;
  [[2026-07-28-next-build]] C2.

#### C3. Visual + audio QA pass, written down
- **Why:** owed since 2026-07-08. Three windowed sessions happened (07-29,
  07-30 ×2); none covered the overlay treatment or the locked desaturation, and
  all three pre-date the C1 HUD. The version of Godot on Brent's Mac is not
  recorded anywhere — worth noting alongside the findings this time.
- **Files/areas:** no code change expected; findings feed back into
  `world_renderer.gd`, `connectivity_overlay.gd`, `hud.gd`.
- **Acceptance:** a note in `obsidian-vault/daily-logs/` confirming each Phase 2
  visual criterion observed on screen, the crossing cue visible **and** audible
  once per coalesced window, the HUD message line legible, and the local Godot
  version recorded.
- **Depends on:** C1 (something to look at), B1 (ideally observed in the export,
  not just the editor).
- **Size:** S
- **Refs:** roadmap Phase 2 exit criteria;
  [testing-setup](../../docs/testing-setup.md); [[2026-07-28-next-build]] C3.

#### C4. Confirm the tutorial actually demonstrates the mechanic
- **Why:** [[../design/detour-cost-question]] is still `status: draft` and still
  headed *"Unresolved"*. It establishes that only **2 of 19** segments bisect
  their sub-area, so on the other 17 an animal can walk around the corridor
  without entering a hazard. Bow Valley is one of the two that does bisect — so
  the tutorial *should* demo correctly — but the memo says explicitly this is
  worth measuring rather than assuming, because it is the first thing any player
  sees. Now cheap: ADR 0016 span geometry and build mode both landed, so the
  "after" is measurable.
- **Files/areas:** a throwaway measurement script or a temporary GUT case over
  `pathfinding.gd` + `simulation.gd`.
- **Acceptance:** measured baseline mortality on `s7_trans_canada_bow_a` is
  non-zero before a crossing exists and measurably drops once a valid span is
  built; the numbers land in `detour-cost-question.md` and move it off `draft`.
- **Depends on:** none (its old dependency, B3 span geometry, closed 07-29).
- **Size:** S
- **Refs:** [[../design/detour-cost-question]] check 3;
  [simulation-design](../../docs/simulation-design.md).

### Verification (tests, CI, export)

#### V1. CI assertion on expected test-script count
- **Why:** `ci.yml:59-63` still guards only `TESTS -eq 0`. The failure this is
  meant to catch is the **partial** drop hit on 2026-07-19, where a parse error
  removed one file, GUT printed `---- All tests passed! ----`, exited 0, and the
  only signal was the script count falling 15 → 14. At 18 scripts, a run that
  silently lost 17 of them still passes this gate.
- **Files/areas:** `.github/workflows/ci.yml`, the *Guard against a
  silently-empty suite* step.
- **Acceptance:** CI fails when the JUnit XML reports fewer than the expected
  number of test scripts (currently **18**); verified against a synthetic short
  XML.
- **Depends on:** none.
- **Size:** S
- **Refs:** [testing-setup](../../docs/testing-setup.md);
  [[../daily-logs/2026-07-19]]; [[2026-07-28-next-build]] V4.

#### V2. Gate the Windows and macOS artifacts too
- **Why:** `ci.yml:121-133` runs the pck gate and the smoke boot on the **Linux
  x86_64** binary only. The Windows pack is not even byte-identical to the Linux
  one (verified this review: `md5 a2dbbbee…` vs `934e8b12…`), so "the Linux pack
  is fine" is not evidence about it. Under B3, the Windows binary goes into a
  public Release having never been gated or booted by anything.
- **Files/areas:** `.github/workflows/ci.yml` export job.
- **Acceptance:** `check_pck_contents.py` runs against the Windows and macOS
  packs as well; a boot check covers at least one non-Linux target (Wine on the
  runner, or a recorded manual launch referenced from the release note).
- **Depends on:** none.
- **Size:** S
- **Refs:** `ci.yml:121-133`; [export-setup](../../docs/export-setup.md).

#### V3. Add `env_config.gd` coverage
- **Why:** still the only untested script carrying real branching logic — it
  owns per-terrain mortality lookup and the resolution order (override → OS env
  → `DEFAULT`, `env_config.gd:21-31`), which is exactly what the Phase 1
  criterion *"deaths at the configured env-var rate"* rests on.
- **Files/areas:** new `game/tests/env_config_test.gd`.
- **Acceptance:** resolution order covered end to end; suite reaches 19 scripts.
  Remember GUT only discovers a new `*_test.gd` after a re-`--import`.
- **Depends on:** none.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md); roadmap Phase 1 exit criteria;
  [[2026-07-28-next-build]] V5.

#### V4. Reconcile `docs/test-plan.md` §11 against the real suite
- **Why:** §11 (`:145`) is the P0 coverage table — the acceptance bar for a
  first playable. Measured this review: of **43** uniquely named tests in
  `:151-195`, **35 have no matching `func test_` in `game/tests/` (81%)**.
  Mostly renames, but the table can no longer be used as a checklist, and it
  hides at least one real hole — `:172`'s row is the live evidence for C2.
- **Files/areas:** `docs/test-plan.md` §11.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason.
- **Depends on:** B2 (the deferral list decides which rows get marked rather
  than fixed).
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md) §11;
  [[2026-07-28-next-build]] V6.

#### V5. Export the `Linux arm64` preset in CI, or delete it
- **Why:** `game/export_presets.cfg:32-62` defines a fourth preset that
  `ci.yml`'s export step never builds, and `builds/wildlife-crossing-linux-arm64/`
  sits empty in the tree as its ghost. A preset nobody exports is a preset
  nobody has ever verified — and it is also the target this sandbox runs on
  (aarch64), so having it would let a future review boot a real artifact instead
  of reasoning about one. Either build it or remove it; carrying it unbuilt is
  the worst of the three.
- **Files/areas:** `.github/workflows/ci.yml`, `game/export_presets.cfg`,
  `builds/wildlife-crossing-linux-arm64/`.
- **Acceptance:** either the arm64 artifact appears in the CI upload and passes
  `check_pck_contents.py`, or the preset and the empty directory are gone.
- **Depends on:** none.
- **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md); `ci.yml`.

#### V6. Cover the autoloads and the constants files
- **Why:** 9 of 26 scripts have no test, and the untested set includes all four
  autoloads — `game_state`, `event_bus`, `debug`, `species_registry` — plus the
  three constants files, whose values `docs/data-schemas.md` §10 specifies
  normatively (`grep -c Constants game/tests/data_validation_test.gd` → 0).
  Lowest urgency here, and the one most likely to save a future archaeology
  session.
- **Files/areas:** new `game/tests/species_registry_test.gd`,
  `game_state_test.gd`, and constants assertions in
  `game/tests/data_validation_test.gd`.
- **Acceptance:** `species_registry` load-failure path and `game_state.to_dict()`
  shape covered; constants values asserted against `data-schemas.md` §10.
- **Depends on:** none.
- **Size:** M
- **Refs:** [test-plan](../../docs/test-plan.md);
  [data-schemas](../../docs/data-schemas.md) §10.

### Deferrable / nice-to-have

- **Explicitly deferred: species preference weighting *and* the usage counter**
  (roadmap Phase 1, P1, `:33`). Re-verified: `preferred_crossing_type`,
  `usage_count` and `times_used` all return 0 hits in `game/scripts/`. Only the
  first has ever been recorded as a deferral; B2 should record both.
- **`entities.json` is loaded and read by nothing.** `species_registry.gd:26`
  indexes it; no other script consumes it. Phase 2's Implements list
  (`roadmap.md:90`) requires the controlling-entity mapping "consumed as data",
  and it is not in Phase 2's exit criteria — so this is low priority, but it is
  a requirement with no consumer.
- **Delete the stale `wildlife-crossing-desktop-builds/` artifacts.** 411 MB,
  they fail the repo's own gate, and they are the single most misleading thing
  in the tree — two reviews running have had to establish that they are not the
  build. (They *are* gitignored; that item closed last review.)
- **`BaseScreen` retrofit** of `ConfirmPanel`, `ConnectivityOverlay` and the
  build-mode status label. Deliberately deferred on 07-31 with a reason; noted
  only so it stays visible.
- **Save/load is unimplemented** — ADR 0005, ADR 0014 and `data-schemas.md` §14
  all specify it; `game_state.gd:29` has `to_dict()` and no reader. Phase 4, so
  not a P0 gap, but it is the largest spec-without-code in the repo.
- **Retire or rewrite `docs/pre-build-checklist.md`** — see §4. Flagged in three
  consecutive reviews.
- **Reconcile `docs/architecture.md` §1 and `game/CLAUDE.md`'s systems table** —
  see §4. Flagged in two consecutive reviews.
- **Real art.** `fonts/` and `tilesets/` are still `.gitkeep`;
  `crossing_cue.png` is a 341-byte generated placeholder; `project.godot` has no
  `config/icon` and `export_presets.cfg:94,133` have `application/icon=""`, so
  the build ships the default Godot icon (already recorded as a known
  first-build limitation at `export-setup.md:104-108`). The eight species
  portraits generated 2026-07-31 are 2048×2048, unwired, and ahead of their
  consumer on purpose; the two naming nits the 07-31 log flagged have since been
  fixed (`docs/prompt-templates/wildlife-crossing-portraits-2048/`,
  `gray-wolf-portrait-2048.png`).
- **`Animal.tscn` is dead weight** — zero references anywhere; agents are drawn
  as circles by `world_renderer.gd:34-36`. Delete or wire it.
- **Tidy stale `.gitkeep` files** now shadowed by real content
  (`game/scenes/ui/`, `game/scenes/world/`, `game/assets/audio/`,
  `.github/workflows/`, `game/tests/`).
- **The recurring `.git/index.lock`.** Present again this run, third occurrence,
  and each time it is this harness that leaves it. Worth a one-line cleanup in
  the harness rather than in `push-runbook.md`'s checklist forever.
- **No daily log for 2026-08-01**, the session that produced `25d33b9`. The
  07-31 log describes the work; the push session itself is unlogged.
- macOS notarization / Windows signing before any public release.
- Phase 5 gates (liaison-NPC decision, cultural-advisor review) remain open and
  still do not block P0.

## 4. Doc drift to fix

Record only — docs are not edited during a review.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | "`game/` is still almost entirely `.gitkeep`"; A1 "no `project.godot`"; A2 "GUT not installed"; A3 "no CI"; A4 "zero game code"; A5 "only `sub_areas.json` and `biome_groups.json`"; A6 "only the `bow_valley_slice` fixture"; A7 "`game/assets/` is all `.gitkeep`"; all B0/B1/B2 boxes unticked | Every one is false, and unchanged since two reviews flagged it. 26 scripts / 2,567 LOC, `project.godot` with 4 autoloads, GUT 9.6.0 vendored, a 144-line two-job CI, all 8 data files valid, 12 authored world maps, 18 test scripts, two real assets. `status: active` makes this file a trap for onboarding — retire or rewrite. |
| [testing-setup.md](../../docs/testing-setup.md):69-71 | "the suite currently reports **16 scripts / 134 tests / 2,779 asserts**" (dated 2026-07-30) | Measured this review: **18 scripts / 144 tests / 2,799 asserts**. `hud_test.gd` and `base_screen_test.gd` landed after that line was written. Stale at three consecutive reviews and corrected twice — worth generating from the JUnit XML rather than maintaining by hand. |
| [testing-setup.md](../../docs/testing-setup.md):22 | "**Godot 4.6** (stable). Any 4.6.x patch is fine" | Contradicts `ci.yml:15` (`GODOT_VERSION: 4.6.3-stable`) and the amended ADR 0012, which pin the **exact** patch deliberately, because export-template paths are version-keyed and a floating patch already cost one misdiagnosis. |
| [testing-setup.md](../../docs/testing-setup.md):142-147 | "### Known gap … Consider adding a CI assertion that the run actually collected tests" | Already implemented at `ci.yml:50-64` (landed 2026-07-10). The *remaining* gap is narrower — a **partial** script drop still passes. See V1. |
| [build-reviews/README.md](README.md), 2026-07-28 entry | "**No build-review blockers remain open**; only C1 … stands before v0.1.0 (V7)" | Blockers: correct. Core tasks: **C2, C3, C4 and C5 were never closed**, and V4, V5, V6 of that review remain open. See §2. |
| [[../daily-logs/2026-07-31]]:94-96 | "No build-review blockers **or core tasks** remain open. C1 was the last one." | C1 was the last one *worked on*; it was not the last one open. (For the record, [[../daily-logs/2026-07-30]]:152 says only "no build-review **blockers** remain open" and immediately names C1 as open at `:153` — that log is accurate. The overstatement enters on 07-31.) |
| [architecture.md](../../docs/architecture.md):69 | Lists `ui/base_screen.gd` with a companion `ui/BaseScreen.tscn` | The script exists; **`BaseScreen.tscn` does not, deliberately** — the 2026-07-31 decision is that every screen in this project is code-instantiated, so `BaseScreen` is a script base with no scene. The row should say so, or drop the scene column entry. |
| [architecture.md](../../docs/architecture.md) §1 (`:52-58`, `:62-68`) | Lists 8 systems and 7 UI scripts that do not exist, plus scene files for UI that is built in code | All Phase 3–6, so not a regression — but the table reads as a description of the codebase and overstates it. Of the four scenes prior reviews named (`world/WorldMap.tscn`, `world/Crossing.tscn`, `ui/ConnectivityOverlay.tscn`, `ui/ConfirmPanel.tscn`), **none exists**; `game/scenes/` holds only `Main.tscn`, `ui/WorldSelectMap.tscn` and `world/Animal.tscn`. Split into *planned* vs *built*. Carried unfixed. |
| [game/CLAUDE.md](../../game/CLAUDE.md) systems table | Does not list `env_config.gd`, `base_screen.gd`, `build_mode.gd` or `hud.gd` | All four exist. `game/CLAUDE.md` states its own rule — *"Add a row here whenever a new system is created"* — so this is a convention miss, and it grew by three entries this week. (`architecture.md` does list `base_screen.gd` at `:69`; the other three are missing from both files.) |
| [roadmap.md](../../docs/roadmap.md) Phase 1 exit criteria | "A fully spanned overpass yields a zero-mortality route" | Still predates [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md); "fully spanned" now means a valid **span** (two-sided core), not full segment coverage. The code is correct; the criterion's wording is not. Carried unfixed from the last review. |
| [test-plan.md](../../docs/test-plan.md) §11 | P0 coverage table presented as the first-playable bar | 35 of its 43 named tests have no matching function in `game/tests/`. See V4. Carried unfixed. |
| [export-setup.md](../../docs/export-setup.md) | *(last review: "never mentions `include_filter`/`exclude_filter`")* | **Fixed** — `:58-63` now covers both, states that no `include_filter` is needed, and quantifies the `exclude_filter` saving. Recorded here so the correction is visible, then off the list. |

## 5. Risks & open questions

- **The world-map click defect is the kind that unit tests structurally cannot
  catch.** Every component along the path is correct and covered; the defect
  lives in the fact that two of them disagree about which camera the mouse is
  in. That is a category worth noting, not just an instance: this project's
  suite is strong on logic and has never once looked at a pixel, and this is the
  first defect that fell exactly in that gap.
- **Four core items went quiet rather than closed.** Worth naming as a process
  observation, not a fault: the closing amendments on 07-29/07-30/07-31 were
  careful and specific about the blockers, and the core list fell out of view
  behind them. The correction is B2 — a decision, recorded — and it costs an
  hour. The pattern to watch is that "no blockers remain" becomes "nothing
  remains" three logs later.
- **This review's own first draft got the roadmap wrong** in the same direction
  the logs did — it asserted that hover highlight and the segment renderer were
  named Phase 2 *exit criteria*, and they are not. Caught by the verification
  pass. Recorded here because the correction makes B2 genuinely more open than
  the summary would otherwise have implied, and because it is a reminder that
  "the roadmap says" deserves a line number.
- **`detour-cost-question` is still `draft`, and it is still the largest open
  design question in the project.** Not a first-build blocker — Bow Valley is
  one of the two segments that bisects its sub-area — but C4 would answer it for
  the price of a throwaway script, and every week it stays open is a week the
  answer might be "the player watches a 10,000 structure sit unused".
- **Artifact retention.** `ci.yml:144` sets `retention-days: 14`, so any
  artifact from the 2026-07-30 run would expire around 2026-08-13 (arithmetic,
  not a value read from GitHub). Nothing depends on it — B1 reproduces a build
  from source — but it is a reason not to let B3 drift.
- **Art remains a hard dependency on the owner.** The first build will be
  coloured shapes, a 341-byte cue icon, and the default Godot window icon. A
  legitimate *first playable*, but it should be stated in the v0.1.0 release
  note rather than discovered by whoever downloads it.
- **This review could not observe CI.** No GitHub tooling is available in this
  session and `gh` is not installed in the sandbox. Nothing here should be read
  as a claim that CI is currently green.
- **The sandbox cannot export.** `~/.local/share/godot/export_templates/` is
  empty, so no local export was attempted and the build signal comes from a
  source boot plus the pck gate on old artifacts. V5 (an arm64 preset) would let
  a future review boot a real artifact here.

## 6. Suggested next-week focus

1. **B2 — make the C1–C4 scope call** (S). A decision, not a build, and it sets
   the size of the whole week. Do it first because B3's release note has to
   state the answer either way. The new input is the click defect: it argues C1
   ships rather than defers.
2. **B1 — export and verify `HEAD`** (S). Push-runbook, CI, pck gate, smoke
   test, then a windowed launch that actually *looks at* the HUD and the
   crossing cue and *presses every key*. First time the acceptance criterion has
   been "watch the feature work" rather than "watch it boot".
3. **B3 — cut v0.1.0** (S). Release note, tag, GitHub Release, and a version
   string in the binary. This is the item that changes the answer to "build
   case" for the first time in five reviews.
4. **C4 — measure the tutorial** (S). Cheap now, answers a design question open
   since 2026-07-19, and the one item here that could change what v0.1.0 *is*
   rather than how it ships.
5. **V1 + V3** (S each). The test-script-count guard and `env_config_test.gd` —
   one afternoon between them, and V1 is the gate that would have caught the
   2026-07-19 silent drop.

If B2 says C1 and C2 (segment renderer + hover) ship in v0.1.0, that is an M+M
week on its own and items 3–5 slide. That trade is exactly what B2 is deciding.

---

## Verification

Labels per the harness's Step 6 rule. **Confirmed** = traced to something read
or run *this session*. **Assumed** = the reasoning is sound but nothing was
checked. **Unverifiable** = not checkable from this session; the harness is
explicit that inferring a state from a daily log is not evidence.

This note was audited two ways before delivery: a fact-integrity pass (every
figure, date and `file:line` citation re-traced) and a completeness red-team
("is anything needed for the build missing, and is anything listed already
done?"). Both found real errors, and both sets of corrections are folded in —
including a wrong commit count that had been this note's headline framing, a
"byte-identical" claim that was false for the Windows pack, a 411 MB directory
carried forward as 232 MB, and the roadmap mis-citation described in §5. The
red-team found **nothing listed here that is already done**; it found the
world-map click defect, which is now §2 and C1.

**Confirmed**

- Suite: 18 scripts / 144 tests / 2,799 asserts, 0 failures, 1.049s, exit 0 —
  run this session with `tools/godot/Godot_v4.6.3-stable_linux.arm64` against
  `game/.gutconfig.json`.
- Headless boot from source is clean: `Tutorial loaded` on output line 3, no
  errors; exit 124 is the documented healthy case.
- 26 scripts / 2,567 LOC in `game/scripts/`; 18 `*_test.gd`; 9 scripts untested.
- All 8 `game/data/*.json` and all 12 `data/world/sub_area_*.json` parse;
  19 segments across 12 sub-areas.
- `builds/` holds no binaries; `git tag -l` is empty; `docs/release-notes/`
  holds only `.gitkeep`. → build case = first build.
- `git rev-list 6e6efe4..HEAD --count` → **3** (`e24a3f6`, `65e69dc`,
  `25d33b9`).
- `wildlife-crossing-desktop-builds/` = 429,939,403 B; all files dated
  2026-07-27/28; Linux and macOS packs `md5 934e8b12…`, Windows pack
  `md5 a2dbbbee…`; all three fail `check_pck_contents.py` with **exit 1**, 244
  development-only paths (213 `addons/gut` + 31 `tests/`), pack format 3, built
  by Godot 4.6.0, 20 data files present. `260b5d6` @ 2026-07-30 14:45:30 added
  `exclude_filter` to all four presets.
- `HEAD` = `origin/main` = `25d33b9` (2026-08-01); stale `.git/index.lock`
  present.
- The click defect: `main.gd:154`, `main.gd:101,118-119`,
  `world_select_controller.gd:33,183,201`, `WorldSelectMap.tscn`
  `mouse_filter = 2` — all read this session.
- C2 open: zero `hover` hits in `world_select_controller.gd`; no
  `test_hover_highlights_dangerous_only` among its 19 tests. C1 open:
  `world_select_controller.gd:28`, `:179-201`. C4 open:
  `detour-cost-question.md` front matter is `status: draft`.
- `preferred_crossing_type`, `usage_count`, `times_used`: 0 hits in
  `game/scripts/`.
- `roadmap.md:98-108` is the Phase 2 exit-criteria list and contains neither
  hover highlight nor a segment renderer; `roadmap.md:85` is where hover
  highlight appears; `roadmap.md:33` names the usage counter.
- `ci.yml:59-63` guards `TESTS -eq 0` only; `:121-133` gates and smoke-tests the
  Linux target only; `export_presets.cfg:32-62` defines a `Linux arm64` preset
  the export step never builds; `:138-139` has empty version fields.
- `crossing_cue.png` is 341 B and wired through `hud.gd:14,55` → `main.gd:267` →
  `hud_test.gd:34,40,48`; `game/.gitignore:3` excludes `*.import`.
- `architecture.md:69` does list `base_screen.gd`; `game/CLAUDE.md` lists none of
  the four new scripts.
- `docs/test-plan.md` §11: 43 named tests, 35 with no matching `func test_`.
- `~/.local/share/godot/export_templates/` is empty; sandbox is `aarch64`.
- Every doc-drift row in §4 was re-read at the cited line numbers this session.

**Assumed**

- That `25d33b9` is pushed. `origin/main` points at it, which a successful push
  would produce; the ref cannot be refreshed in this sandbox. Confirming it
  needs a `git fetch` on Brent's machine.
- That no artifact built from current `main` exists anywhere. Verified for
  `builds/` and `wildlife-crossing-desktop-builds/`; a repo-wide search for
  `*.pck` was not run.
- The 2026-08-13 artifact-expiry date: arithmetic on `ci.yml:144`'s
  `retention-days: 14` and the 2026-07-30 run date, not a value read from
  GitHub.

**Unverifiable**

- **CI status.** Not checkable this session — no GitHub tooling, `gh` not
  installed in the sandbox. The `project-state` artifact (read this session)
  records a browser observation made on 2026-08-02: *"CI #8, commit `25d33b9`,
  success, 1 Aug 1:31 PM."* That is good evidence and the review treats it as
  the likely state, but it is a prior session's observation, not this run's, and
  it is not reproducible without GitHub access. Nothing in §3 fails if it is
  wrong — B1 re-establishes it either way.
- **The 2026-07-30 clean artifact and windowed launch.** [[../daily-logs/2026-07-30]]
  records CI run `30576303478` green, a 77-file / 166,232 B pack, and a macOS
  launch reaching the tutorial with animals moving. The log was read this
  session; the claims in it were not checkable — the artifact is not on disk
  here — and the harness is explicit that inferring state from a daily log is
  not evidence. Nothing in §3 depends on it.
- **Which Godot version is installed on Brent's Mac.** The 2026-07-30 editor
  session proves *a* Godot install; no log records the version. C3 should.
- **Whether any exported binary from `HEAD` launches.** None exists to try, and
  the sandbox is `aarch64` while every existing artifact is x86-64 or macOS.
- **Every *visual* Phase 2 criterion.** Headless cannot QA rendering; this is
  C3's whole reason for existing.

---

## Related

- [[roadmap]]
- [[pre-build-checklist]]
- [[testing-setup]]
- [export-setup](../../docs/export-setup.md)
- [push-runbook](../../docs/push-runbook.md)
- [ADR 0016 — crossing span geometry](../../docs/adr/0016-crossing-span-geometry.md)
- [[../design/detour-cost-question]]
- [[../daily-logs/2026-07-30]]
- [[../daily-logs/2026-07-31]]
- Previous review: [[2026-07-28-next-build]]
