---
title: "Milestone Roadmap"
date: 2026-06-17
status: active
---

## Purpose

This roadmap defines the phased build order for Wildlife Crossing. Each phase
lists the PRD sections it implements, its exit criteria, and the ADRs it needs.
Its acceptance bar is that **every requirement in the PRD set is assigned to
exactly one phase** — the assignment table in §8 is the proof.

The phase order follows the design plan: (1) core simulation + overpass
validation, (2) location selection + sub-areas, (3) economy + information,
(4) seasons, (5) permissions + narrative (post cultural review), (6) milestones +
polish. Earlier phases are prerequisites for later ones.

Cross-references: [`architecture`](architecture.md),
[`simulation-design`](simulation-design.md), [`data-schemas`](data-schemas.md),
[`test-plan`](test-plan.md).

---

## Phase 1 — Core simulation + overpass validation

**Goal.** Prove the central mechanic: animals pathfind a hex world, die on
hazards, and cross safely over a completed overpass with legible feedback.

**Implements (PRD sections):**

- `wildlife-overpass-crossing`: all P0 (tile danger flags, overpass tile type,
  placement validation, pathfinding graph update on full/partial span,
  per-terrain mortality env vars, `animal_crossed` signal, crossing feedback);
  P1 species-preference weighting and usage counter.
- `game-design-overview` §Species and animal simulation (movement, mortality,
  hex 6-directional pathfinding), §Habitat and zoning (patch model + quality
  formula + four bands + viability), §Crossings and infrastructure.

**ADRs needed:** [0001 Godot 4](adr/0001-choose-godot-4.md),
[0002 hex-grid topology](adr/0002-hex-grid-topology.md),
[0003 crossing tile architecture](adr/0003-crossing-tile-architecture.md),
[0004 connectivity patch-adjacency graph](adr/0004-connectivity-patch-adjacency-graph.md).

**Exit criteria:**

- On a test map, animals route around `is_impassable` tiles and across
  `is_hazardous` tiles with deaths at the configured env-var rate.
- A fully spanned overpass yields a zero-mortality route; a partial span yields
  none.
- `animal_crossed` fires exactly once per traversal; visual + audio placeholder
  cue plays, coalesced per crossing in a 2s window.
- `pathfinding_test.gd`, `infrastructure_manager_test.gd`,
  `connectivity_graph_test.gd`, `habitat_manager_test.gd`,
  `population_model_test.gd` green.

> **Decision logged (2026-07-31): the visual half of the crossing cue ships as
> an always-on `Hud`, and it pays down the `BaseScreen` convention debt for new
> UI only.** Build review C1 closed: `game/scripts/ui/hud.gd` extends a new
> `game/scripts/ui/base_screen.gd` (`game/CLAUDE.md`'s "UI scenes inherit from
> a BaseScreen scene where possible", implemented as a script base rather than
> a `.tscn` since none of this project's UI is scene-authored — every screen
> is instanced with `.new()`). The `Hud` mirrors `Main._log()` on screen (so
> mode changes and build results, not just the crossing cue, are legible in a
> windowed export) and shows a dedicated icon + "+N crossed safely" flash on
> the coalesced `animal_crossed` window, fading independently of the message
> line. `ConfirmPanel` and `ConnectivityOverlay` predate `BaseScreen` and are
> **not** retrofitted — migrating them is separate, deliberately deferred
> work. Placeholder art: `game/assets/sprites/crossing_cue.png` is a generated
> flat-colour stand-in, not an Aseprite export; real art is still owed.
> Suite: 18 scripts / 144 tests / 2,799 asserts, all green (was 134/2,779).

> **Decision logged (2026-08-06): both Phase 1 P1 items — species-preference
> weighting and the crossing usage counter — are deferred past v0.1.0.** Swept
> into the same scope call as build-review [[2026-08-04-next-build]] B2 because
> only the first of the two had ever been recorded as a deferral, leaving the
> usage counter (`:33`) silently unbuilt across five consecutive reviews.
> Re-verified 2026-08-06: `preferred_crossing_type`, `usage_count` and
> `times_used` all return zero hits in `game/scripts/`. Neither appears in
> Phase 1's exit criteria (`:45-56`), both are marked P1 in the Implements list
> (`:33`), and neither is observable in a build whose only playable crossing is
> the tutorial overpass — a usage counter over one crossing counts to one.
> Revisit when Phase 3's economy gives crossings a cost worth justifying, since
> "how much is this structure being used" is an economic question before it is
> an ecological one.

---

## Phase 2 — Location selection + sub-areas

**Goal.** The player can navigate Y2Y, see fragmentation, and commit a segment
that seeds construction.

**Implements (PRD sections):**

- `crossing-location-selection`: all P0 (toolbar tool, Y2Y world map,
  continuous zoom, locked/unlocked treatment, connectivity overlay at segment
  zoom, hover highlight, confirmation panel, budget gate display, confirm→
  construction, cancel, Escape); P1 hover score, segment label, crossing-count
  note, sub-area summary on hover; the four resolved decisions (overlay
  appearance, click-outside-closes, connectivity computation, zoom threshold).
- `sub-areas`: the 12-sub-area list, sizing rule, naming rule (acknowledgment
  notes), controlling-entity mapping consumed as data.
- `game-design-overview` §Information and uncertainty *map-fog portion* (terrain
  always visible; locked areas show terrain only) — the ecological-reveal
  purchases themselves are Phase 3.

**ADRs needed:** [0004 connectivity](adr/0004-connectivity-patch-adjacency-graph.md)
(overlay reads cached values); [0002 hex](adr/0002-hex-grid-topology.md) (tile-px
zoom threshold measured flat-to-flat).

**Exit criteria:**

- Continuous zoom from world to segment level with ≥16px / 12px hysteresis; no
  loading screens.
- Locked sub-areas desaturated with lock indicator; zoom blocked at boundary.
- Overlay (orange→teal, ~40% opacity, pulse on worst three) appears only in
  segment mode and clears on confirm/cancel/Escape.
- Confirm passes the correct `(segment, sub_area)` into the construction step;
  click-outside and Escape behave per spec.
- `world_select_controller_test.gd`, `connectivity_overlay_test.gd`,
  `confirm_panel_test.gd`, `data_validation_test.gd` green.

> **Decision logged (2026-07-29): v0.1.0 is scoped to Bow Valley only.** The
> first build ships sub-area 7 (Central Canadian Rockies / Bow Valley) as the
> only playable area. The other 11 sub-areas are fully authored and
> data-complete (`game/data/world/sub_area_*.json`, `segments.json`) but ship
> **locked** — desaturated with the lock indicator, per this phase's own exit
> criteria — because their unlock path (trust threshold, `sub_area_unlocked`)
> is Phase 5 and does not exist yet. This is a deliberate scope choice, not a
> bug: Bow Valley is one of only two sub-areas whose corridor bisects the map,
> so the tutorial mechanic is guaranteed to demonstrate correctly (see
> [[../obsidian-vault/design/detour-cost-question]]). Building a general
> sub-area load path ahead of Phase 5's unlock system would let a player reach
> content with no unlock story behind it. Superseded/replaces the sub-area load
> path option previously carried as build-review B5.

> **Decision logged (2026-08-06): the world-map screen ships look-only in
> v0.1.0. The in-map segment renderer and hover highlight are deferred to
> Phase 2 completion.** This resolves build-review [[2026-08-04-next-build]] B2
> — the scope call on C1–C4 — which existed because those four items went quiet
> after the 07-28 review rather than being closed or deferred on the record.
>
> **Deferred, with reasons:**
>
> - **C1, in-map segment renderer → Phase 2 completion (post-v0.1.0).** Not
>   named anywhere in this roadmap — neither in Phase 2's Implements list
>   (`:80-92`) nor its exit criteria (`:98-108`). It entered the build reviews
>   as the fix for the world-map click defect, and that defect is being closed
>   a cheaper way (below), so the renderer is no longer load-bearing for the
>   first build. It remains the prerequisite for C2 and for QA'ing the
>   locked-desaturation and overlay treatments on screen.
> - **C2, hover highlight → Phase 2 completion (post-v0.1.0).** A P0
>   *requirement* in this phase's Implements list (`:85`) and a named P0 test in
>   [test-plan](test-plan.md):172, but **not** one of the five exit criteria at
>   `:98-108`, so Phase 2 can be judged met without it. Deferred on dependency
>   rather than on priority: it needs C1's in-map render to have something to
>   hover over. Note for whoever picks it up — the build-mode tile hover added
>   by B4 (`world_renderer.gd:20,45-47`) is a *different* feature, and mistaking
>   the two is why this looked closed for a fortnight.
>
> **Replacing C1 for v0.1.0: neutralize the blind click (S).**
> `game/scenes/ui/WorldSelectMap.tscn` sets `mouse_filter = 2` (IGNORE), so
> clicks on the world-select screen fall through `main.gd:101` to
> `_try_select_segment()` (`:127`), which resolves the cursor against the
> **world** camera (`:154`) beneath an opaque backdrop
> (`world_select_controller.gd:33,183`). The player sees a placeholder card
> grid and picks a hex they cannot see — usually nothing, sometimes a real Bow
> Valley segment they never aimed at, with the confirm panel opening on it.
> Setting `mouse_filter` to STOP makes world-select consume its own clicks: the
> map screen is look-only, `B` remains the placement path, and the defect
> cannot fire. This is a stopgap with an expiry — it is superseded by C1, and
> C1's acceptance still requires that the drawn map and `_pick_segment_at_mouse()`
> agree on a coordinate space. Needs a regression test asserting that a click
> in world-select mode selects no segment.
>
> **Shipping in v0.1.0:**
>
> - **C3, written visual + audio QA pass (S).** Owed since 2026-07-08. Folded
>   into the B1 windowed launch, since that launch is happening anyway. Records
>   each Phase 2 visual criterion observed on screen, the crossing cue seen
>   *and* heard once per coalesced window, the HUD message line legible, and —
>   new — the Godot version installed locally, which no log has ever captured.
>   Scoped down by this decision: the in-map criteria C1 would have made
>   QA-able are out, so C3 covers the HUD, the cue, and the world view.
> - **C4, tutorial measurement (S).** Independent of everything above and its
>   old dependency (span geometry) closed on 07-29. Measures mortality on
>   `s7_trans_canada_bow_a` before and after a valid span, lands the numbers in
>   [[../obsidian-vault/design/detour-cost-question]] and moves that note off
>   `draft`. Kept in scope because it is the one item that could change what
>   v0.1.0 *is* rather than how it ships: if the tutorial does not demonstrate
>   the mechanic, that is worth knowing before a public release, not after.
>
> **Consequence for the release note (build-review B3):** `v0.1.0` states this
> scope next to the Bow-Valley-only scope above — the world map is a look-only
> screen this release, and crossings are placed from the tutorial via `B`.

---

## Phase 3 — Economy + information

**Goal.** Building and surveying cost budget; effective crossings pay donations.

**Implements (PRD sections):**

- `game-design-overview` §Economy and budget (starting 50,000, overpass cost
  per tile, monthly donation formula, fundraising trickle), §Information and
  uncertainty (the four information products, permanence, reveal layers).
- `wildlife-overpass-crossing` superseded non-goal: crossings now cost budget.
- Budget gate in `crossing-location-selection` becomes functional (was display
  in Phase 2).

**ADRs needed:** none new (economy/info are data + constants over existing
systems).

**Exit criteria:**

- Spends and donations move the budget; `budget_changed` / `donation_received`
  drive the HUD.
- Donation formula matches spec across status weights and fragmentation
  multipliers; trickle prevents deadlock.
- Each information product reveals exactly its layer, permanently and across
  save/load.
- `economy_manager_test.gd`, `information_manager_test.gd` green.

---

## Phase 4 — Seasons

**Goal.** Time and seasons make the world rhythmic and reward timing.

**Implements (PRD sections):**

- `game-design-overview` §Seasons and time (year = 4 seasons, 15 min/season at
  1×, pause/1×/2×/4×, actions while paused), seasonal effects (presence,
  motivation, terrain shifts).
- `simulation-design` seasonal modifiers; `connectivity_graph` re-derivation on
  `season_changed`; autosave on season boundary (architecture §7).

**ADRs needed:** [0005 save-file format](adr/0005-save-file-format.md) (autosave
cadence on `season_changed`).

**Exit criteria:**

- Season cycles at the correct cadence; calendar always visible.
- Hibernators leave in winter; migrators appear seasonally; frozen/flood terrain
  shifts open/close routes.
- Migration seasons spike crossing usage; pause never penalises.
- `season_manager_test.gd` / `time_controller_test.gd`, `save_manager_test.gd`
  green.

---

## Phase 5 — Permissions + narrative (post cultural review)

**Goal.** Sub-areas unlock through earned trust; First Nations partnerships are
represented respectfully and confer mechanical benefits.

> **Gate:** no First Nations narrative content (the three fictional communities'
> design, sub-area naming, dialogue, joint-stewardship events) ships until the
> mandatory cultural-advisor review signs off
> ([`cultural-narrative-design`](../obsidian-vault/prd/cultural-narrative-design.md)).
> This gate precedes any content-complete milestone.

**Implements (PRD sections):**

- `governmental-permissions`: nine-entity roster, trust 0–100 from weighted
  metrics, relationship stages, per-entity checklist, starting state (sub-area 7
  unlocked, Crown of the Continent first), never-revoke / neglect-slows-others.
- `cultural-narrative-design`: fictional region-specific communities, land
  acknowledgment, player-as-outsider framing, Indigenous-knowledge-as-mechanics
  (free corridor data, habitat bonus, placement hints), cultural-review pipeline.
- `game-design-overview` §Player progression (unlock-driven scope expansion);
  community liaison briefing reveal of exact weights.

**ADRs needed:** none new (built on Phases 1–4 systems + data).

**Exit criteria:**

- Trust accrues from each entity's weighted metrics; threshold emits
  `sub_area_unlocked` + one-time bonus; stages and checklist legible.
- Sub-area 7 starts unlocked; Crown of the Continent is the low-threshold first
  unlock; neglect never re-locks.
- `partnership_formed` grants the three mechanical benefits.
- Cultural-advisor sign-off recorded before any First Nations content is enabled.
- `permissions_manager_test.gd` green.

---

## Phase 6 — Milestones + polish

**Goal.** Long-term structure and final feel.

**Implements (PRD sections):**

- `game-design-overview` §Player progression *win-condition portion* (Corridor
  Milestones track: per-sub-area milestones, capstone Continental Connection,
  celebrations not gates).
- Art/audio/UX polish per the creative docs (art direction, audio design,
  UI/UX spec); wiki content surfacing where in-game encyclopedia hooks exist.

**ADRs needed:** none new (capstone reachability reuses
[0004](adr/0004-connectivity-patch-adjacency-graph.md)).

**Exit criteria:**

- Per-sub-area milestones fire on their conditions; capstone fires only on the
  full Yellowstone→Mackenzie chain and gates nothing.
- `milestone_tracker_test.gd` green; full suite green.
- The vision success criterion holds: a new player in the Bow Valley can find a
  fragmented segment via the overlay, build a complete overpass, watch the first
  animal cross with feedback, receive a first donation, and understand why all
  four happened.

---

## 7. ADR summary by phase

| ADR | Introduced/needed in |
|---|---|
| [0001 Godot 4](adr/0001-choose-godot-4.md) | Phase 1 (foundational) |
| [0002 hex-grid topology](adr/0002-hex-grid-topology.md) | Phase 1; reused Phase 2 (zoom px) |
| [0003 crossing tile architecture](adr/0003-crossing-tile-architecture.md) | Phase 1 |
| [0004 connectivity patch-adjacency graph](adr/0004-connectivity-patch-adjacency-graph.md) | Phase 1; reused Phases 2, 6 |
| [0005 save-file format](adr/0005-save-file-format.md) | Phase 4 (autosave); round-trip touched whenever state grows |

---

## 8. Requirement → phase assignment (every requirement, exactly one phase)

| PRD | Requirement group | Phase |
|---|---|---|
| wildlife-overpass-crossing | Tile danger flags; overpass type; placement validation; span graph update; per-terrain mortality env vars; `animal_crossed`; feedback (P0) | 1 |
| wildlife-overpass-crossing | Species preference weighting; usage counter (P1) | 1 |
| wildlife-overpass-crossing | Crossing cost (superseded non-goal) | 3 |
| wildlife-overpass-crossing | Underpass/corridor types; upgrades; seasonal crossing behaviour (P2) | Out of scope (post-v1; data model ready) |
| game-design-overview | Habitat quality formula, bands, viability | 1 |
| game-design-overview | Species roster + movement/mortality/population model | 1 |
| game-design-overview | Crossings & infrastructure | 1 |
| game-design-overview | Economy & budget; donation formula; trickle | 3 |
| game-design-overview | Information & uncertainty — purchases/reveals | 3 |
| game-design-overview | Information & uncertainty — map-fog (terrain visible, locked = terrain only) | 2 |
| game-design-overview | Seasons & time | 4 |
| game-design-overview | Player progression — unlock-driven scope | 5 |
| game-design-overview | Player progression — Corridor Milestones / capstone | 6 |
| crossing-location-selection | All P0 selection/zoom/overlay/panel/Escape | 2 |
| crossing-location-selection | P1 hover score, segment label, crossing-count, sub-area summary | 2 |
| crossing-location-selection | Budget gate (functional) | 3 |
| crossing-location-selection | P2 suggestions, pinning, multi-crossing planning, progress summary | Out of scope (post-v1) |
| sub-areas | 12 sub-areas, sizing rule, naming rule, entity mapping | 2 |
| governmental-permissions | Entity roster, trust, stages, checklist, starting state, never-revoke | 5 |
| cultural-narrative-design | Fictional communities, acknowledgment, framing, mechanics, review gate | 5 |

> Decision logged: P2/"future considerations" items in the source PRDs
> (underpass/corridor crossing types, crossing upgrades, season-aware crossing
> preference, suggested locations, site pinning, multi-crossing planning,
> per-sub-area progress summary) are explicitly **out of v1 scope** — the data
> model and pathfinding hooks are built to accept them without structural change
> ([0003](adr/0003-crossing-tile-architecture.md)), but no phase implements them.
> This keeps "every (in-scope) requirement assigned to exactly one phase" exact
> while honouring the PRDs' own non-goals.
