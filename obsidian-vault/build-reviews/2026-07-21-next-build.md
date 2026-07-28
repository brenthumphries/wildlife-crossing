---
title: "Build Review — Next Build (2026-07-21)"
date: 2026-07-21
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> roadmap [[roadmap|Phases 1–2]]). One question: what work is needed to get
> there?

## 1. Summary

- **Build case:** **FIRST working build** (none exists yet). `builds/` holds no
  binary — only `.gitignore`, `.gitkeep`, and an empty
  `builds/wildlife-crossing-linux-arm64/` directory; `docs/release-notes/` is
  empty and `git tag -l` returns nothing. A local export was attempted this
  review and failed: *"No export template found at
  `.../4.6.3.stable/linux_release.arm64`"*. There is still no artifact that can
  be pointed at and launched — the criterion that decides first-vs-next build.
- **Target milestone & exit criteria:** roadmap
  [Phase 1](../../docs/roadmap.md) (core simulation + overpass validation) and
  [Phase 2](../../docs/roadmap.md) (location selection + sub-areas).
- **Headline:** **5 blockers, 5 core tasks.** Last review's seven blockers are
  **all closed** — the Phase 2 UI trio, the 11 sub-area maps, the audio cue, and
  the export pipeline all landed between 2026-07-08 and 2026-07-11, and the
  suite doubled to 15 scripts / 116 tests / 2,740 asserts, green on Godot 4.6.3
  headless with a clean boot to `Main.tscn`. But Phases 1–2 are **not** yet
  complete against their exit criteria, and the misses are the kind that unit
  tests do not catch: the first hands-on play session (2026-07-19) found a real
  span-geometry defect; the crossing cue has audio but **no visual**; **hover
  highlight is entirely unimplemented**; and **11 of the 12 authored world maps
  are unreachable in-game** because nothing ever calls `load_world` a second
  time. Meanwhile the export path — now fully built — has still never produced a
  binary. The count of open work went down; the honesty of the list went up.
- **Change since last review:** [[2026-07-07-next-build]] — **B1–B7 and V1 all
  closed.** Twelve commits landed (`6e485ad`…`af85bce`) and `main` was pushed to
  `origin` on 2026-07-11 17:20. Newly open: the **segment/span defect**
  ([[../design/segment-vs-span-defect]]) and its resolving
  [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md), the **detour-cost
  question** ([[../design/detour-cost-question]]), and the fact that **every
  artifact from 2026-07-19 is still uncommitted**.

## 2. Current state (evidence)

Grounded in this week's subagent inventory, a fresh headless test run, a
headless boot, a real export attempt, and an independent red-team pass.

- **Systems:** 23 scripts / 2,149 LOC in `game/scripts/`, **zero stubs**. The
  four autoloads (`game_state`, `event_bus`, `debug`, `species_registry`) are
  registered in `game/project.godot`; all nine Phase 1 simulation systems plus
  `simulation.gd`, three constants files, `world/world_renderer.gd`, and four UI
  scripts (`world_select_controller.gd` 216 LOC, `connectivity_overlay.gd` 197,
  `confirm_panel.gd` 159, `segment_picker.gd` 38) are present and real.
- **Data:** all 8 canonical files in `game/data/` present and valid JSON.
  **World maps 12/12** — `sub_area_1.json` … `sub_area_12.json`, all valid,
  all matching the §12 key shape. `segments.json` holds **19 segments** covering
  all 12 sub-areas. *But see B5: only sub-area 7 is ever loaded at runtime.*
- **Scenes & wiring:** `game/scenes/Main.tscn` is `run/main_scene`; wiring lives
  in `main.gd`, which instantiates `Simulation`, `WorldRenderer`,
  `ConnectivityOverlay`, `Camera2D`, `AudioStreamPlayer` and lazily instances
  `scenes/ui/WorldSelectMap.tscn` + `ConfirmPanel`. `scenes/world/Animal.tscn`
  exists. Headless boot is clean — logs *"Tutorial loaded. Press B to build the
  Bow Valley overpass. Press M for the world map."* with no script errors.
- **Tests:** GUT (vendored `tools/godot/Godot_v4.6.3-stable_linux.arm64`,
  `game/.gutconfig.json`) — **15 scripts / 116 tests / 2,740 asserts, all
  passing (0.983s)**. Script count matches the 2026-07-19 log, so nothing was
  silently dropped. Untested: the four autoloads, `env_config.gd`, `main.gd`,
  and the three constants files. `env_config.gd` is the meaningful gap — it owns
  per-terrain mortality lookup and env-var resolution order.
- **CI:** `.github/workflows/ci.yml` is real, with **two** jobs — `test` (pinned
  Godot 4.6-stable, `--headless --import`, GUT with JUnit XML, plus the V1
  **zero-tests guard**, commit `8318dc2`) and `export` (installs export
  templates, exports Linux x86_64 / Windows x86_64 / macOS, **smoke-boots the
  Linux binary and greps for "Tutorial loaded"**, uploads `builds/` as a 14-day
  artifact).
- **Build/export:** `game/export_presets.cfg` exists with **4 presets** (Linux
  x86_64, Linux arm64, Windows x86_64, macOS), and `docs/export-setup.md` is a
  complete runbook. But **no binary has ever been produced**: `builds/` is
  empty, no tag, no Release, `docs/release-notes/` empty, and no export
  templates on this machine. The blocker is narrow — the sandbox *can* run the
  vendored arm64 binary (the suite and a headless boot both ran here), it simply
  cannot **download** the `.tpz` (network-locked; `wget --spider` on the 4.6.3
  templates URL is blocked). → **first build.**
- **Git:** `main` == `origin/main` == `af85bce`; `git reflog show origin/main`
  records `update by push` at 2026-07-11 17:20, so the "repo unpushed" blocker
  from the last two logs **is resolved**. However **9 files are modified and 11
  paths untracked** — 210 insertions / 70 deletions of uncommitted work,
  including ADR 0016, both design memos, and the 2026-07-19 camera-projection
  fix.
- **Assets:** `game/assets/audio/crossing_chime.wav` is real (61,782 B) and
  wired (`main.gd:16` preload → `main.gd:160` `_cue_player.play()` inside the
  coalesced feedback window). `sprites/`, `tilesets/`, `fonts/` are `.gitkeep`
  only.

### Exit criteria, criterion by criterion

| Phase | Criterion | State |
|---|---|---|
| 1 | Animals route around impassable / across hazardous at the configured rate | **Met** — `pathfinding_test.gd`, `simulation_test.gd` green |
| 1 | Full span → zero-mortality route; partial span → none | **Met by the wrong behaviour** — see B2 |
| 1 | `animal_crossed` fires once per traversal | **Met** — `simulation_test.gd` |
| 1 | Visual **+ audio** placeholder cue, coalesced in 2s | **Half met** — audio wired; **no visual** (`main.gd:153-161` logs via `Debug`) → C1 |
| 1 | Named Phase 1 suites green | **Met** |
| 1 | (P1) Species preference weighting biases crossing use | **Not applied** — `simulation.gd:102` passes only `{"covered": …}`; `preferred_crossing_type` is authored on all 8 species but never reaches the cost function. P1 → explicit deferral, see §3 |
| 2 | Continuous zoom, ≥16px/12px hysteresis, no loading screens | **Met** — `world_select_controller_test.gd`, 19 tests |
| 2 | Locked sub-areas desaturated + lock indicator, zoom blocked | **Logic met, visual unverified** → C3 |
| 2 | Overlay orange→teal ~40%, pulse worst three, segment-mode only, clears | **Logic met, visual unverified** → C3 |
| 2 | **Hover highlight** | **Not implemented** — no state, no draw path, no test → C2 |
| 2 | Confirm passes correct `(segment, sub_area)` into construction | **Not met** — `main.gd:126-128` dead-ends for any sub-area but 7 → B5 |
| 2 | Named Phase 2 suites green | **Met** |

## 3. Work needed for the first build

Ordered the way you'd actually do it. Each item is buildable.

### Blockers (nothing ships until these exist)

#### B1. Commit and push the 2026-07-19 working tree
- **Why it blocks:** the spec for B2
  ([ADR 0016](../../docs/adr/0016-crossing-span-geometry.md)), both design
  memos, and the camera-projection fix exist **only in the working tree**.
  Nothing downstream is safe or reviewable until they are committed, and CI has
  never seen the camera fix. Verified: `git status --short` → 9 modified, 11
  untracked.
- **Files/areas:** modified — `game/scripts/main.gd`,
  `game/scripts/world/world_renderer.gd`,
  `game/scripts/ui/connectivity_overlay.gd`, `game/tests/world_renderer_test.gd`,
  `game/project.godot`, `docs/adr/0003-crossing-tile-architecture.md`,
  `obsidian-vault/prd/wildlife-overpass-crossing.md`,
  `obsidian-vault/daily-logs/2026-06-28.md`, `.obsidian/workspace.json`.
  Untracked — `docs/adr/0016-crossing-span-geometry.md`,
  `obsidian-vault/design/*.md`, `obsidian-vault/daily-logs/2026-07-19.md`,
  `obsidian-vault/build-reviews/`, `obsidian-vault/prd/minigame-ideas.md`,
  `.obsidian/graph.json`.
- **Decide first (do not `git add -A` blind):** `harness/` and
  `fable-game-builder/` are untracked repo-root directories that need a commit-
  or-ignore decision, and two stray root files look misfiled — `2026-07-11.md`
  (0 bytes) and `Untitled.canvas` (2 bytes). Resolve these *before* staging.
- **Acceptance:** `git status` clean for tracked work; `origin/main` ahead of
  `af85bce`; CI green on the new head.
- **Depends on:** none. **Must run on Brent's machine** — the sandbox has no SSH
  credentials, and a live `.git/index.lock` (dated 2026-07-19, not removable
  from the sandbox) needs clearing locally first.
- **Size:** S
- **Refs:** [[../daily-logs/2026-07-19]]; `wildlife-crossing-git-push` memory.

#### B2. Implement ADR 0016 span geometry
- **Why it blocks:** the Phase 1 exit criterion *"a fully spanned overpass
  yields a zero-mortality route"* is currently satisfied by the **wrong**
  behaviour. Verified unfixed this review:
  `infrastructure_manager.gd:59-61` loops every tile of `_dangerous_tiles(seg)`
  and returns false on any uncovered cell; `simulation.gd:81-82` is the bare
  passthrough `return infrastructure.build_full(segment_id, crossing_type)`.
  Pressing **B** paves all 20 tiles of `s7_trans_canada_bow_a` — the tutorial
  highway ceases to exist — at 100,000 against a 50,000 starting budget.
- **Files/areas (five, not three):**
  `game/scripts/systems/infrastructure_manager.gd` (the real change:
  `try_complete()` adopts the two-sided-core predicate; `build_full()` renamed
  and re-scoped to cover a *span*); `game/scripts/systems/simulation.gd`
  (`build_crossing()` takes a span location); and three test files whose
  assertions encode whole-segment semantics —
  `game/tests/infrastructure_manager_test.gd`,
  `game/tests/pathfinding_test.gd:39-53`
  (`test_full_span_creates_zero_mortality_route`,
  `test_partial_span_creates_no_safe_route`), and
  `game/tests/simulation_test.gd:52,61,80`.
  **Both `build_crossing()` call sites must change:** `main.gd:75-77` (the
  `KEY_B` handler) and `main.gd:129` (`_on_confirm_panel_confirmed`).
- **Acceptance:** `infrastructure_manager_test.gd` green with the **seven rows
  of the ADR 0016 verified-behaviour table** as cases — especially the two
  rejections (half-width span; tiles laid *along* the corridor). Bow Valley
  full-width-at-r=5 → valid, 2 tiles, 10,000. The core-size search cap must be a
  named constant with a comment, per the ADR's stated trade-off.
- **Depends on:** B1 (the ADR must be committed first).
- **Size:** M
- **Refs:** [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md);
  [ADR 0003](../../docs/adr/0003-crossing-tile-architecture.md) (amended);
  [[../design/segment-vs-span-defect]]; roadmap Phase 1 exit criteria.

#### B3. Span placement UI (build mode + ghost preview + running cost)
- **Why it blocks:** ADR 0016 and the defect memo both decide **the player picks
  where the span goes**. Once B2 lands, `build_crossing()` needs a span
  location, and there is no way for a player to supply one — `main.gd:75-77` is
  a hardcoded `KEY_B` → `TUTORIAL_SEGMENT` build. Without this, B2 makes the
  game *less* playable. The ADR also requires running cost be visible during
  placement ("priced, not policed" means the bill must never surprise).
- **Files/areas:** new `game/scripts/ui/build_mode.gd` (or extend
  `segment_picker.gd`), `game/scripts/main.gd`, a ghost-preview draw path in
  `game/scripts/world/world_renderer.gd`.
- **Acceptance:** a new `build_mode_test.gd` green; in a non-headless run the
  player can enter build mode, hover tiles across the Bow Valley corridor, see a
  ghost and a running cost, and confirm a 2-tile / 10,000 span; an invalid
  (half-width) candidate is refused with a legible message.
- **Depends on:** B2.
- **Size:** L
- **Refs:** [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md)
  §"Negative / Trade-offs"; [[../design/segment-vs-span-defect]] open question 4;
  [crossing-location-selection](../prd/crossing-location-selection.md).

#### B4. Produce and launch the first actual binary
- **Why it blocks:** this **is** the build. The pipeline is complete but has
  never been executed to a retained artifact. Local export failed this review
  with *"No export template found at
  `~/.local/share/godot/export_templates/4.6.3.stable/linux_release.arm64`"*.
- **Files/areas:** `game/export_presets.cfg` (exists), `builds/`,
  `.github/workflows/ci.yml` `export` job, `docs/export-setup.md`.
- **Acceptance:** a desktop binary exists and, run with `--headless`, logs
  `Tutorial loaded.` — plus a windowed launch on Brent's Mac reaching the
  tutorial scene. Three viable routes: (a) push B1 and download the CI `export`
  job artifact; (b) install `Godot_v4.6.3-stable_export_templates.tpz` into
  `~/Library/Application Support/Godot/export_templates/4.6.3.stable/` on the
  Mac and export locally; (c) vendor the `.tpz` into `tools/` (gitignored) so
  the sandbox can export too — the sandbox runs the arm64 binary fine, it just
  cannot fetch the archive.
- **Depends on:** B1 for route (a). The *content* of a shippable first build
  depends on B2, B3, B5, C1.
- **Size:** M
- **Refs:** [export-setup](../../docs/export-setup.md); `ci.yml` `export` job.

#### B5. Sub-area load path — or an explicit Bow-Valley-only scope
- **Why it blocks:** the Phase 2 exit criterion *"confirm passes the correct
  `(segment, sub_area)` into the construction step"* is **not met**.
  `main.gd:33` calls `sim.load_world(TUTORIAL_SUB_AREA, …)` exactly once and
  nothing else ever calls `load_world`; `main.gd:126-128` short-circuits any
  confirmation outside sub-area 7 with *"Sub-area %d is not loaded yet"*. So the
  11 maps authored as last review's B4 — celebrated as 12/12 in §2 — are **dead
  data in the shipped build**, and segment picking is scoped to the loaded
  sub-area for the same reason.
- **Files/areas:** `game/scripts/main.gd`,
  `game/scripts/systems/simulation.gd` (`load_world` reload path),
  `game/scripts/ui/world_select_controller.gd`.
- **Acceptance:** *either* confirming a segment in any unlocked sub-area loads
  that world and seeds construction (with a `simulation_test.gd` case covering a
  reload), *or* — the cheap resolution — the first build is deliberately scoped
  to Bow Valley, the other 11 sub-areas are presented as locked, and that scope
  is written into the roadmap and the v0.1.0 release note so it reads as a
  decision rather than a bug.
- **Depends on:** none. **Needs an owner call on which resolution.**
- **Size:** S (scoped) / L (full load path)
- **Refs:** roadmap Phase 2 exit criteria;
  [sub-areas](../prd/sub-areas.md); [[../daily-logs/2026-07-10]].

### Core build work (the exit-criteria tasks)

#### C1. Visual half of the crossing cue + minimal HUD
- **Why:** roadmap Phase 1 requires a *"visual + audio placeholder cue"* and
  `docs/pre-build-checklist.md` B1 spells it out as *"placeholder sprite +
  audio"*. Only audio exists. Worse, the 2026-07-19 session found that all
  player feedback routes through the `Debug` autoload to **stdout** — correct by
  `game/CLAUDE.md` convention, but invisible in a windowed export, where there
  is no Output panel. A binary that launches but shows the player nothing is not
  the "first playable".
- **Files/areas:** `game/scripts/main.gd`, new `game/scenes/ui/Hud.tscn` +
  `game/scripts/ui/hud.gd`, a placeholder sprite under `game/assets/sprites/`.
  Keep `Debug` logging; add an on-screen channel beside it rather than
  replacing it.
- **Acceptance:** in an **exported** binary the coalesced "+N crossed" cue is
  visible on screen alongside the chime, and build result + current mode are
  legible without the editor.
- **Depends on:** none (parallel with B2/B3).
- **Size:** M
- **Refs:** roadmap Phase 1 exit criteria;
  [pre-build-checklist](../../docs/pre-build-checklist.md) B1;
  [[../daily-logs/2026-07-19]].

#### C2. Hover highlight
- **Why:** a named Phase 2 P0 exit criterion and a named P0 test in
  [test-plan](../../docs/test-plan.md) §11
  (`test_hover_highlights_dangerous_only`). It is **entirely unimplemented** —
  grepping `hover` across `game/scripts/` and `game/scenes/` returns only three
  docstring mentions (`segment_picker.gd:2`, `confirm_panel.gd:6,66`); no state,
  no draw path, no test. This was missed by previous reviews because
  `segment_picker.gd` reads as though it covers the interaction.
- **Files/areas:** `game/scripts/ui/world_select_controller.gd`,
  `game/scripts/world/world_renderer.gd`, new
  `game/tests/hover_highlight_test.gd`.
- **Acceptance:** `test_hover_highlights_dangerous_only` green; at segment zoom
  the hovered segment highlights and only dangerous tiles are highlighted.
- **Depends on:** C4 (needs something rendered in-map to hover over).
- **Size:** M
- **Refs:** roadmap Phase 2 exit criteria; [test-plan](../../docs/test-plan.md) §11;
  [crossing-location-selection](../prd/crossing-location-selection.md).

#### C3. Non-headless display + audio QA pass
- **Why:** owed since 2026-07-08 and still unpaid. Every *visual* Phase 2
  criterion — desaturated locked sub-areas with lock indicator, the orange→teal
  ~40%-opacity overlay pulsing on the worst three — is verified only by unit
  tests asserting *state*, never by looking at pixels. Headless cannot QA
  rendering.
- **Files/areas:** no code change expected; findings feed back into
  `world_renderer.gd`, `connectivity_overlay.gd`, `Animal.tscn`.
- **Acceptance:** a written QA note in `obsidian-vault/daily-logs/` confirming
  each Phase 2 visual criterion observed on screen, plus the audio cue audible
  once per coalesced window.
- **Depends on:** best run after C1 and C4 so there is something to look at.
- **Size:** S
- **Refs:** roadmap Phase 2 exit criteria; [[2026-07-07-next-build]] §5.

#### C4. In-map segment renderer
- **Why:** `segment_picker.gd` is real and tested, but segment mode is still
  drawn over by the placeholder card grid, so picking is **not observable** —
  flagged as owed in [[../daily-logs/2026-07-10]]. It is also the prerequisite
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
  confirming rather than assuming, because it is the first thing any player
  sees. This is the cheap third check of the three the memo proposes; the full
  question is a risk, not a blocker (see §5).
- **Files/areas:** a throwaway measurement script or a temporary GUT case over
  `pathfinding.gd` + `simulation.gd`.
- **Acceptance:** measured baseline mortality on `s7_trans_canada_bow_a` is
  non-zero before a crossing exists, and measurably drops once a valid span is
  built.
- **Depends on:** B2 (a valid span must be buildable to measure the "after").
- **Size:** S
- **Refs:** [[../design/detour-cost-question]] check 3;
  [simulation-design](../../docs/simulation-design.md).

### Verification (tests, CI, export)

#### V1. CI assertion on expected test-script count
- **Why:** the 2026-07-10 guard catches a *zero*-test run, but 2026-07-19 hit a
  **partial** drop — `class_name Main` broke one test file's parse, GUT printed
  `---- All tests passed! ----` and exited 0, and the only signal was the script
  count falling 15 → 14. The guard counts `<testcase>` elements, so a partial
  drop still looks healthy.
- **Files/areas:** `.github/workflows/ci.yml` (extend the existing
  "Guard against a silently-empty suite" step).
- **Acceptance:** CI fails when the JUnit XML reports fewer than the expected
  number of test scripts; verified against a synthetic short XML.
- **Depends on:** none.
- **Size:** S
- **Refs:** [testing-setup](../../docs/testing-setup.md);
  [[../daily-logs/2026-07-19]]; `wildlife-crossing-test-setup` memory.

#### V2. Confirm the first CI run went green
- **Why:** `origin/main` was pushed 2026-07-11, which should have triggered the
  first-ever run of both jobs — including the export job fetching templates on
  GitHub's runners rather than the blocked sandbox proxy. **This review could
  not verify it**: the GitHub connector is not authorized in this session. If
  that run went green, B4 route (a) is already half-done and an artifact may
  still be within its 14-day retention (expiring ~2026-07-25).
- **Files/areas:** GitHub Actions run history.
- **Acceptance:** the 2026-07-11 run's `test` and `export` jobs both green, or
  their failures triaged into new items.
- **Depends on:** none.
- **Size:** S
- **Refs:** `ci.yml`; [[../daily-logs/2026-07-10]] "Next session".

#### V3. Reconcile `docs/test-plan.md` §11 against the real suite
- **Why:** §11 is the P0 coverage table — the acceptance bar for a first
  playable — and **22 of its 31 named P0 tests have no matching function name**.
  Most are renamed equivalents (e.g. `test_partial_span_creates_no_route` →
  `pathfinding_test.gd:47 test_partial_span_creates_no_safe_route`), which is
  fine but makes the table useless as a checklist. Two are genuine holes:
  `test_hover_highlights_dangerous_only` (→ C2) and
  `test_preference_weighting_biases_use` (→ deferred, below).
- **Files/areas:** `docs/test-plan.md` §11.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason.
- **Depends on:** C2.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md) §11.

#### V4. Add `env_config.gd` coverage
- **Why:** the only untested script carrying real branching logic — it owns
  per-terrain mortality lookup and env-var resolution order, which is precisely
  what the Phase 1 criterion *"deaths at the configured env-var rate"* rests on.
- **Files/areas:** new `game/tests/env_config_test.gd`.
- **Acceptance:** resolution order (env var → data default → hardcoded fallback)
  covered; suite reaches 16 scripts. GUT only discovers a new `*_test.gd` after
  a re-`--import`.
- **Depends on:** none.
- **Size:** S
- **Refs:** [test-plan](../../docs/test-plan.md); roadmap Phase 1 exit criteria.

#### V5. Cut `v0.1.0` — release note + GitHub Release
- **Why:** `docs/release-notes/` is empty and `git tag -l` returns nothing, so
  there is no anchor for "most recently shipped" and the next review has no
  milestone to diff against. `docs/CLAUDE.md` specifies semantic-version release
  notes. If B5 resolves as "scoped to Bow Valley", the release note is where
  that scope gets stated.
- **Files/areas:** `docs/release-notes/v0.1.0.md`, a `v0.1.0` tag, a GitHub
  Release with the desktop binaries attached.
- **Acceptance:** release note follows the `docs/CLAUDE.md` format; the Release
  carries launchable binaries.
- **Depends on:** B4 (and, for a build worth releasing, B2, B3, B5, C1).
- **Size:** S
- **Refs:** [docs/CLAUDE.md](../../docs/CLAUDE.md);
  [export-setup](../../docs/export-setup.md).

### Deferrable / nice-to-have

- **Explicitly deferred: species preference weighting** (roadmap Phase 1, P1).
  `preferred_crossing_type` is authored on all 8 species in
  `species_stats.json` and `pathfinding.gd:10` documents a preference-cost
  option, but `simulation.gd:102` passes only `{"covered": …}`, so the weighting
  never reaches the cost function. P1, so not a first-build blocker — recording
  it as a deliberate deferral rather than an oversight.
- **`BaseScreen` convention debt.** `game/CLAUDE.md` specifies UI scenes inherit
  a `BaseScreen` scene; `ui/base_screen.gd` / `BaseScreen.tscn` don't exist, and
  `ConfirmPanel` / `ConnectivityOverlay` are bare code-instantiated nodes with no
  `.tscn`. Doesn't block a binary, but C1's HUD will face the same decision —
  worth a call before adding a fourth ad-hoc UI node.
- Retire or rewrite `docs/pre-build-checklist.md` — now actively misleading
  (see §4), not merely stale.
- Reconcile `docs/architecture.md` §1 and `game/CLAUDE.md`'s systems table
  (see §4).
- Real art: `game/assets/sprites/`, `tilesets/`, `fonts/` are still `.gitkeep`;
  presets ship the default Godot icon.
- Tidy stale `.gitkeep` files now shadowed by real content (`game/scenes/ui/`,
  `game/scenes/world/`, `game/assets/audio/`) and the empty
  `builds/wildlife-crossing-linux-arm64/` directory (left by commit `2733f3d`,
  2026-07-08).
- Clear the ~16 inert `.git/*.lock.aside.*` / `.lock.stale*` files from the
  host-shell mount workaround (the live `index.lock` is not inert — see B1).
- Pin the CI `GODOT_VERSION` and the local `tools/` binary to the same 4.6.x
  patch (CI `4.6-stable` → template dir `4.6.stable`; local `4.6.3.stable`).
  ADR 0012 permits any 4.6.x, but export-template paths are version-keyed.
- Triage `obsidian-vault/prd/minigame-ideas.md` — still untracked and unassigned
  to a phase.
- macOS notarization / Windows signing before any public release.
- Phase 5 gates (liaison-NPC decision, cultural-advisor review) remain open and
  still do not block P0.

## 4. Doc drift to fix

Record only — docs not edited during a review.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | "`game/` is still almost entirely `.gitkeep`"; A1 "no `project.godot`"; A2 "GUT not installed"; A3 "no CI"; A4 "zero game code"; A5 "only `sub_areas.json` and `biome_groups.json`"; A6 "only the `bow_valley_slice` fixture"; all B0/B1/B2 boxes unchecked | Every one is false. 23 scripts / 2,149 LOC, `project.godot` with 4 autoloads, GUT 9.6.0 vendored, a two-job CI, all 8 data files valid, 12 authored world maps. B0/B1/B2 are done **except** the cue's placeholder **sprite** (→ C1) and `scenes/world/WorldMap.tscn`, which was never created and is now obsolete (rendering goes through `world_renderer.gd`). `status: active` makes this file a trap for onboarding — retire or rewrite. |
| [[../daily-logs/2026-07-19]] | "Repo still unpushed … `main` vs `origin/main`" | Resolved. `main` == `origin/main` == `af85bce`; `git reflog show origin/main` records `update by push` at 2026-07-11 17:20. What is genuinely unpushed is the **working tree** (9 modified + 11 untracked), which is B1. |
| [architecture.md](../../docs/architecture.md) §1 | Lists 8 systems (`economy_manager`, `information_manager`, `permissions_manager`, `season_manager`, `time_controller`, `milestone_tracker`, `save_manager`, `narrative_manager`), 8 UI scripts (`build_palette`, `inspect_panel`, `entity_profile`, `season_calendar`, `budget_hud`, `milestone_track`, `time_controls`, `base_screen`), and **4** scenes (`world/WorldMap.tscn`, `world/Crossing.tscn`, `ui/ConnectivityOverlay.tscn`, `ui/ConfirmPanel.tscn`) | None exist. All Phase 3–6, so not a regression — but the table reads as a description of the codebase and overstates it. Only `Main.tscn`, `ui/WorldSelectMap.tscn`, `world/Animal.tscn` exist; the two UI scenes are built in code (`main.gd:39`, `main.gd:141`). Split the table into *planned* vs *built*. |
| [architecture.md](../../docs/architecture.md) §1 **and** [game/CLAUDE.md](../../game/CLAUDE.md) | Neither systems table lists `env_config.gd` | It exists (31 LOC) and is referenced by `data-schemas.md:395` and `simulation-design.md:169`. `game/CLAUDE.md` states its own rule — *"Add a row here whenever a new system is created"* — so this is a convention miss, not just an omission. |
| [roadmap.md](../../docs/roadmap.md) Phase 1 exit criteria | "A fully spanned overpass yields a zero-mortality route" | Predates ADR 0016. "Fully spanned" now means a valid **span** (two-sided core across the corridor), not full **segment** coverage. As written, the criterion is satisfied by the defective behaviour. Reword to reference ADR 0016. |
| [test-plan.md](../../docs/test-plan.md) §11 | P0 coverage table names 31 tests as the first-playable bar | 22 have no matching function name in `game/tests/`. Mostly renames, but the table can no longer be used as a checklist — and it hides two real holes (→ C2, and the deferred preference weighting). See V3. |
| [testing-setup.md](../../docs/testing-setup.md) | Documents the zero-tests silent-pass gap as unguarded | The V1 guard landed 2026-07-10 (`8318dc2`, JUnit `<testcase>` count). But a *partial* script drop still passes green — document that, and see V1. |
| [[2026-07-07-next-build]] | B1–B7 + V1 listed as open | All eight closed between 2026-07-08 and 2026-07-11. |

## 5. Risks & open questions

- **Will animals actually use a crossing?** ([[../design/detour-cost-question]],
  status `draft`, unresolved.) Hazard tiles are passable-with-risk, not walls,
  and 17 of 19 segments leave a walk-around gap — corroborated independently in
  ADR 0016 ("only 2 of the 19 authored segments actually cut their map in two").
  If detouring is cheaper than the mortality-weighted crossing cost, the player
  watches a 10,000 structure sit unused. **Needs an owner decision** between the
  three logged resolutions — extend corridors to the map edge, raise detour cost
  via terrain, or accept it and surface expected *usage* in the connectivity
  overlay (the most interesting and the most work). Not a first-build blocker,
  because Bow Valley is one of the two segments that does bisect — but it is the
  largest open design question in the project and it only gets more expensive to
  answer.
- **B5 needs an owner call, and it is a scope decision, not a technical one.**
  Ship the first build as Bow Valley only (S, honest, and arguably the right
  shape for a tutorial-first release), or build the sub-area load path (L). The
  cheap option is only cheap if it is *stated* — otherwise 11 authored maps
  silently do nothing and the next review re-discovers it.
- **ADR 0016's core-size search cap is undecided.** The ADR notes naive
  enumeration of two-sided cores is exponential and says the cap "must be
  documented where it is set". Pick and justify a bound during B2.
- **No binary has ever been produced, and the reason is narrow.** Not a broken
  pipeline — just a missing `.tpz`. The sandbox runs the vendored arm64 binary
  fine (suite and headless boot both ran here); it simply cannot download the
  templates. Vendoring the archive into `tools/` would make the build
  reproducible in three places instead of one, and would de-risk V2 being the
  only path.
- **A live `.git/index.lock` dated 2026-07-19 is present** and could not be
  removed from the sandbox (permission denied). Clear it locally before B1 or
  commits will fail with "Another git process seems to be running."
- **GitHub connector unauthorized in this session**, so CI run status, Releases,
  and artifact retention could not be checked directly. Every claim about CI
  above is from reading `ci.yml`, not from observing a run.
- **Art remains a hard dependency on the owner.** Sprites, tilesets, and fonts
  are empty; the first build will be colored circles on a placeholder grid.
  Acceptable for a *first playable* — but it means "playable" rests entirely on
  C1 doing its job, and C1 now needs at least one placeholder sprite.

## 6. Suggested next-week focus

Given dependencies and size, pull these first:

1. **B1 — commit and push the 2026-07-19 tree** (S). Must run on Brent's Mac
   (clear `index.lock`, and decide `harness/` + `fable-game-builder/` first).
   Unblocks B2 and B4; everything else is at risk until it lands.
2. **V2 — confirm the 2026-07-11 CI run** (S). Five minutes, and it may reveal a
   build artifact already exists — retention expires ~2026-07-25.
3. **B5 — make the sub-area scope call** (S if scoped). A decision, not a build.
   It changes what B4 and V5 are shipping, so it wants answering before them.
4. **B2 — implement ADR 0016** (M). The one genuine correctness defect in
   Phase 1; the spec is already written and verified against real data.
5. **C1 — visual cue + minimal HUD** (M). Independent of B2/B3, and the
   difference between a binary that launches and a binary that can be played.

Holding B4 to the *following* week is deliberate: producing a binary is cheap
once B1 lands, but a binary shipped before B2 and C1 would be a build of the
defect, shown silently.

---

## Related

- [[roadmap]]
- [[pre-build-checklist]]
- [[testing-setup]]
- [ADR 0016 — crossing span geometry](../../docs/adr/0016-crossing-span-geometry.md)
- [[../design/segment-vs-span-defect]]
- [[../design/detour-cost-question]]
- Previous review: [[2026-07-07-next-build]]
