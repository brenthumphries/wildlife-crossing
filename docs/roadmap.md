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

> **Decision logged (2026-09-15): the Bow Valley card gets real map art; the
> rest of the 2026-08-06 look-only decision stands.** `sub_areas.json` gains an
> optional `card_image` field ([`data-schemas` §4](data-schemas.md)); sub-area 7
> is the first to set it, to `res://assets/sprites/world_map_bow_valley.png`.
> `world_select_controller.gd`'s `_draw_sub_area_card` draws that texture in
> place of the flat color fill, tinted by lock state exactly as the placeholder
> cards already are, with a label scrim for legibility. The other eleven
> sub-areas keep `card_image: null` and the placeholder fill until art exists
> for them. **This does not reopen C1 (in-map segment renderer) or C2 (hover
> highlight)** — the screen is still `MOUSE_FILTER_STOP`, still non-interactive,
> and still draws a flat card grid, not a zoomable rendered map; only the card
> background changed from a solid color to a texture. Both remain deferred to
> Phase 2 completion, post-v0.1.0, per the block above.

> **Decision logged (2026-09-23): the fourth exit criterion is met in tests
> and not reachable in the v0.1.0 artifact; the three remaining Implements
> items are dispositioned.** Resolves build-review C9, open since
> [[2026-09-01-next-build]]. Brent's call.
>
> **The criterion.** *"Confirm passes the correct `(segment, sub_area)` into
> the construction step; click-outside and Escape behave per spec"* is met by
> `confirm_panel_test.gd` (`test_confirm_passes_exact_segment_and_sub_area`,
> `test_click_outside_the_panel_box_cancels`,
> `test_escape_exit_closes_panel_silently`), and `main.gd`
> `_on_confirm_panel_confirmed` hands the pair to `_enter_build_mode`. It is
> **not reachable in the artifact a stranger runs**: the 2026-08-06 block made
> the world map look-only and `WorldSelectMap.tscn` stops mouse events, so
> `_try_select_segment()` never opens the panel. v0.1.0 reaches the same
> construction step through `B`. The path becomes reachable when C1, the
> in-map segment renderer, lands. Rejected: deferring the criterion outright,
> which is equally honest but disowns logic that is built and covered. What
> this block does not allow is the bare word "met": every build review,
> release note or log that states Phase 2's exit criteria says *met in tests,
> not reachable in the shipped build*.
>
> **The three Implements items no earlier block covered:**
>
> - **Toolbar tool ("Add crossing") → Phase 2 completion, with C1.** A toolbar
>   button needs an interactive map to open into. For v0.1.0, `M`
>   (`_open_world_select`, documented as the placeholder trigger for this
>   action) and `B` stand in.
> - **P1 group: the segment label ships; the rest → Phase 2 completion, with
>   C2.** `ConfirmPanel` shows the human-readable segment label, asserted in
>   `confirm_panel_test.gd` as P1. Hover score, crossing-count note and
>   sub-area summary on hover all need the hover highlight, deferred on
>   2026-08-06.
> - **Controlling-entity mapping → met as data.** Every sub-area in
>   `game/data/sub_areas.json` carries a `controlling_entity_id`, and
>   `data_validation_test.gd` asserts each resolves to an entity in
>   `entities.json`. Nothing reads it at runtime yet; gameplay consumption is
>   Phase 5 (permissions).
>
> **Consequence for the release note (build-review B6):** `v0.1.0` states
> Phase 2 as *exit criteria met in tests; segment selection from the world map
> is not reachable in this build*, next to the look-only and Bow-Valley-only
> scope already recorded above.

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

> **Decision logged (2026-10-15): the build after v0.1.0 is Phase 3. Phase 2
> completion is the build after that.** Brent's call. Resolves Q1 from the
> 2026-10-12 plan. Phase 3 is mostly logic and tests, so most of it can run
> unattended. Phase 2 completion is mostly rendering and needs a person watching
> the screen. Rejected: Phase 2 completion first, which would remove the "met in
> tests, not reachable" caveat on the 2026-09-23 block sooner but gives the
> player nothing new to feel; and both phases as one build, which is too large
> to route as S and M items.
>
> **State of the code when this was decided.** `economy_constants.gd` holds the
> constants and `event_bus.gd` declares `budget_changed`, `donation_received` and
> `information_purchased`. `game_state.gd` stores `budget` and `last_donation`,
> both defaulting to 0, and nothing sets `STARTING_BUDGET`. The save schema
> already has the `economy` and `information` keys. The simulation has a
> 30-day month (`TICKS_PER_MONTH`). `main.gd` passes a minimum crossing cost of
> 0 to the confirm panel, so the budget gate is display-only. Neither test file
> exists.
>
> **In scope:**
>
> - Starting budget set on a new game; spends and credits move the budget and
>   emit `budget_changed`.
> - Crossings cost `OVERPASS_COST_PER_TILE` per covered tile, and the budget gate
>   blocks what the player cannot afford.
> - Monthly income: `BASE_GRANT` plus, per crossing, crossings that month times
>   mean status weight times fragmentation multiplier, with the
>   `FUNDRAISING_TRICKLE` when the budget is below the cheapest action. Emits
>   `donation_received`. The HUD shows the budget and the last donation.
> - Three area information products: habitat assessment, population survey and
>   movement corridor study. Each reveals exactly its layer, permanently, and
>   survives save and load. Emits `information_purchased`.
>
> **Decided with it:**
>
> - **Milestone bonuses pay 0 in this build.** The term stays a named hook so
>   Phase 6 can add amounts without changing the formula. No amounts exist and
>   milestones are a Phase 6 track. Rejected: a first-crossing bonus now.
> - **The community liaison briefing is out; it moves to Phase 5.** It reveals
>   permission weights for a governmental entity and no permission system
>   exists. `INFO_LIAISON_BRIEFING` and the `entities_revealed` save key stay
>   unused. Rejected: a purchasable stub that reveals nothing.
> - **The fragmentation multiplier is stored on the crossing when it is built.**
>   The pre-crossing connectivity deficit is recorded once, as a new field on
>   `crossings[]`. Rejected: recomputing the deficit each month by re-running
>   connectivity without the crossing. This changes the save format, and
>   `data-schemas.md` says a `save_version` bump is MAJOR, so the item that adds
>   the field settles whether the bump is needed (optional field with a
>   default, or a bump with a migration, per
>   [0005](adr/0005-save-file-format.md)) and flags it to Brent before merging.
>
> **Open:**
>
> - **Where a revealed layer shows.** Phase 3 lands before the in-map renderer,
>   so the existing UI (HUD, confirm panel, segment label) is the only place to
>   show habitat numerics, population counts and corridor data. The information
>   item proposes a surface. If none fits, the data layer and its tests ship in
>   this build and the visual reveal moves with Phase 2 completion.
>
> **First work items, for the next weekly plan to route and number:**
>
> 1. Economy manager with starting budget, spend and credit, and
>    `economy_manager_test.gd`.
> 2. Crossing cost and the functional budget gate, replacing the display-only
>    gate in `main.gd`.
> 3. Monthly donation formula, trickle and the stored fragmentation deficit, with
>    the save-format question above, and the HUD budget and donation display.
> 4. Information manager for the three area products, with
>    `information_manager_test.gd` and save and load coverage.
> 5. The visual reveal of each layer, subject to the open question.
>
> Items 1 to 4 are `code` lane and suit `sonnet`. Item 3 touches the save format
> and `crossings[]`, so it runs `supervised`. The Phase 2 completion items
> (in-map segment renderer, hover highlight, toolbar tool, P1 hover extras) stay
> as dispositioned on 2026-09-23.

> **Decision logged (2026-10-15, second block): how the fragmentation deficit is
> measured, that its save field needs no version bump, and how purchased
> information is recorded.** Resolves Q4 from the 2026-10-15 plan. Brent's call,
> accepted as the plan proposed it after one correction. C14, C15 and C17 read
> this block for their acceptance.
>
> **The deficit.** When a crossing completes, and before its safe links are
> added, take the distinct connectivity networks of the patches that border its
> covered tiles. Let `combined` be their total tile count (sum of
> `patch_tile_count`, species-agnostic) and `largest` the tile count of the
> biggest one. `fragmentation_deficit = min(1, (combined - largest) / largest)`.
> The multiplier is `FRAGMENTATION_MULT_MIN + deficit * (FRAGMENTATION_MULT_MAX -
> FRAGMENTATION_MULT_MIN)`, computed from the stored deficit at income time. Two
> equal halves score 1.0 (2.0x), a 10% sliver joined to a large network scores
> 0.1 (1.1x), and patches already in one network score 0 (1.0x). The first
> draft used one minus the largest network's share of the total, which tops out
> at 0.5 for two networks and so never reached the top of the range.
> Rejected: an absolute isolation measure against the sub-area's total, which
> pays more for rescuing a tiny pocket but needs a tuning constant. Revisit it if
> playtest shows small pockets feel under-rewarded.
>
> **The stored field.** `crossings[]` gains an optional float
> `fragmentation_deficit`, default 0.0 on load. A restored crossing keeps its
> saved value and never recomputes it, because a restore replays crossings
> against a partly built graph.
>
> **No `save_version` bump.** The field is optional with a default, which
> ADR 0014's omit-means-default rule covers: a save without it loads and pays at
> 1.0x, and an older build reading a newer save ignores the key. Rejected:
> bumping the version, which `data-schemas.md` calls MAJOR and which suits an
> incompatible change, not an additive one.
>
> **Information records.** The `information` save object gains an optional
> `products_by_area` map, default empty: a sub-area id written as a string maps
> to the list of product ids bought for it (`habitat_assessment`,
> `population_survey`, `corridor_study`). String keys because JSON turns integer
> keys into floats, the fault fixed on 2026-09-05 (`species_registry.gd`
> `_index()`). `areas_revealed[]` stays and lists the areas that hold any
> product. "Area" in the PRD's per-area prices means sub-area; only sub-area 7
> is playable in this build. Rejected: encoding `product:area` strings into
> `areas_revealed[]`, which overloads the key, and renaming it, which is a real
> format change.
>
> **Consequence for the work items.** C14 and C17 document the new keys in
> `data-schemas.md` §14. The next weekly plan marks Q4 done, which unblocks C14,
> C15 and C17.

> **Decision logged (2026-10-16): purchased information is shown in a
> keyboard-opened Info panel in this build; map markers come with Phase 2
> completion.** Resolves Q5 from the 2026-10-15 plan. Brent's call, accepted as
> the plan proposed it. C18 builds it.
>
> **The surface.** Pressing `I` opens a modal overlay, in the style of the F1
> credits and the F2 and F3 minigames, listing the three products for the loaded
> sub-area (Bow Valley) with price and bought state. The arrow keys move the
> selection and Enter buys the selected product; an unaffordable or already held
> product is disabled and charges nothing. Before any purchase it lists each
> patch with its free habitat band, population as "unknown" and no corridor data.
> Each purchase reveals only its own layer: exact quality and tile counts,
> species with counts and trends, or the hotspot list. Rejected: deferring the
> visuals to Phase 2 completion, which would leave the "spend now to decide
> better" loop unplayable; and a single-key purchase, because a mis-press costs
> 1,000 to 3,000. `F4` was rejected as the key because a Mac laptop needs `fn`
> for it, as F2 and F3 already do.
>
> **Patch labels.** Patches read "forest patch, 42 tiles", numbered by size,
> largest first, with ties broken by patch key. The raw patch ids stay out of the
> panel.
>
> **The free band needs an accessor.** `InformationManager` returns a patch's band
> only once the habitat assessment is held. C18 adds a free view that returns the
> label, the tile count and the band, never the numeric quality, so the panel does
> not read `HabitatManager` directly.
>
> **Corridor data is per session.** The tallies are not saved, so after a load the
> corridor section starts empty. The panel says "since this session started or
> loaded".
>
> **Phase 2 completion gains one item.** Hotspot markers on the map while placing
> a span, shown when a corridor study is held, because that is where the data
> changes what the player builds. It needs the in-map renderer, so it follows the
> segment renderer (C1) and hover highlight (C2) from the 2026-09-23 block.

> **Decision logged (2026-10-16, later): the text-size baseline, steps and
> storage, and the fundraising trickle's threshold.** Resolves Q6 and Q7 from the
> plan for the week of 2026-10-19. Brent's call; the Q6 numbers are the plan's
> proposals, confirmed.
>
> **Text.** All text is larger by default, on every screen. Baseline sizes at the
> 1280x720 viewport: body 20, title 36, small 16, against 14, 28 and 12 to 13
> today. The player steps through 100, 125, 150 and 175 percent of that baseline,
> default 100, from a title screen option and in play with Ctrl+= to enlarge,
> Ctrl+- to shrink and Ctrl+0 to reset. The choice is stored in a settings file
> at `user://settings.cfg`, separate from saves, so a save from another machine
> never changes the player's text size. The windowed walk (V15) tunes the
> constants against the real screen. Rejected: a fixed size, and storing the
> choice in the save.
>
> **The trickle.** `FUNDRAISING_TRICKLE` pays when the balance is below the
> cheapest crossing tile that can be bought, meaning the lowest `cost_per_tile`
> among crossing types with `available_in_v1` true (5,000 today), not below the
> cheapest information product. C15 shipped the information-product reading
> (1,000); C32 changes it. Rejected: the information-product reading.

> **Decision logged (2026-10-16, v0.2.0 scope): v0.2.0 goes big, behind a feature
> freeze.** Resolves Q8 from the plan for the week of 2026-10-19. Brent's call:
> include as much as can reasonably fit without risking stability.
>
> **In.** Phase 3 as merged; Phase 2 completion (the in-map renderer, hover
> highlight, toolbar, the P1 extras, and hotspot markers); text size with a player
> setting; Phase 4 (time controls, seasons and the calendar, seasonal presence and
> migration, seasonal terrain, autosave and Continue); and Phase 6 (the milestone
> tracker and track, celebrations, and first-time hints that explain the core loop).
>
> **Out.** Phase 5 (permissions, sub-area unlocks and the First Nations narrative
> content), which the roadmap holds behind the cultural-advisor review. Art and audio
> assets that cannot be generated here, so the milestone celebration reuses the
> crossing chime. The Continental Connection capstone is implemented but stays
> unreachable, because only Bow Valley is playable.
>
> **Stability.** One feature freeze, called by Brent when the features are merged and
> walked (V15 to V18), then one stabilization pass (V19) exercising everything at the
> default text size and at 175 percent. Only fixes merge until the release is cut.
> Rejected: a release candidate per phase, which would have kept a last good build to
> ship if a late phase proved unstable. The accepted risk is that a late problem blocks
> the whole release. To limit it, seasonal terrain (C39) is narrowed to hazard changes
> for pathing and mortality, and its ADR records what full re-derivation would need.
>
> **B7.** The Windows and Linux checks on v0.1.0 remain a blocker for any release.
>
> *Resolved 2026-10-25: both binaries launched in `binary-check.yml` run
> 40204770783, and the title-screen screenshots were checked by hand. B7 no
> longer blocks a release (daily log 2026-10-25).*

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

> **Decision logged (2026-10-16): seasonal presence, migration and terrain
> rules.** Resolves Q9 from the plan for the week of 2026-10-19. Brent's call;
> the rules are the plan's proposals with one change: elk and pronghorn are never
> absent.
>
> **Presence.** Only the grizzly (`hibernates`) is absent in a season, and only in
> winter. Elk and pronghorn (`seasonal_migration`), mountain caribou and bighorn
> sheep (`elevational_migration`), and wolverine, gray wolf and Canada lynx
> (`resident`) are present all year. This replaces "migratory species (elk,
> pronghorn) appear in a patch only in their season" in
> `docs/simulation-design.md` §6 and "migrators appear seasonally" in the exit
> criteria above. Rejected: absence in winter for elk and pronghorn, as proposed.
>
> **Migration.** Both migration patterns (`seasonal_migration` and
> `elevational_migration`) migrate in spring and fall. In those seasons
> goal-distance willingness is multiplied by 1.5, so elk and pronghorn show a
> crossing-usage spike in spring and fall without ever leaving.
>
> **Terrain.** Seasons run spring, summer, fall, winter from year 1 spring. Winter
> clears `is_hazardous` on river tiles. Spring widens river hazard zones by one
> tile. Summer and fall use the base terrain. C39 builds this as hazard changes
> only, per the v0.2.0 scope block in Phase 3.
>
> **Effect on the plan.** C37's absence table holds only the grizzly; the
> `seasonal_migration` pattern has no absence season. C37 follows this
> block, as its text says, and C38's 1.5 stands. `docs/simulation-design.md` §6 is not yet amended.

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
