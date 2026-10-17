---
title: "Test Plan"
date: 2026-06-17
status: active
---

## Purpose

This document defines the GUT (Godot Unit Testing) test suite for Wildlife
Crossing, organised one test file per system
(`game/tests/<system_name>_test.gd`, per `game/CLAUDE.md`). Its acceptance bar is
that **every P0 acceptance criterion in the PRD set maps to at least one named
test that exists in `game/tests/`, or carries an explicit deferral with a
reason**. The mapping table in §11 is the record of that coverage.

For how to *run* the suite (setup, commands, gutconfig, pitfalls), see
[testing-setup.md](testing-setup.md).

Tests follow the `game/CLAUDE.md` template (`extends GutTest`, `before_each` /
`after_each`, classes instantiated directly without scene-tree or autoload
dependencies where possible). All stochastic tests inject a fixed RNG seed and,
where relevant, set the mortality environment variables per case
([simulation-design §7](simulation-design.md)).

---

## 1. `pathfinding_test.gd` — movement graph, crossings, mortality

| Test | Asserts |
|---|---|
| `test_impassable_blocks_movement` | An `is_impassable` tile with no crossing has no in-edge; A* routes around it or fails to reach a walled-off goal. |
| `test_hazardous_is_traversable` | An `is_hazardous` tile is routable (edge exists) but flagged to trigger a mortality check on entry. |
| `test_impassable_and_hazardous_mutually_exclusive` | No tile in the registry has both flags true. |
| `test_full_span_creates_zero_mortality_route` | When every dangerous cell of a segment is covered, animals route through the chain and survive (0 deaths over N runs). |
| `test_partial_span_creates_no_route` | With one cell uncovered, no safe route exists; animals must use the hazardous path or reroute. |
| `test_covered_barrier_becomes_traversable` | A covered `is_impassable` tile gains an in-edge. |
| `test_road_mortality_honours_env_var` | With `ROAD_HAZARD_MORTALITY=0.5`, road deaths ≈ 50%/step over N runs (within tolerance). |
| `test_river_mortality_independent_of_road` | Setting road to 0.5 leaves river deaths at the river var's rate; each var settable/unsettable independently. |
| `test_default_mortality_is_0_20` | Unset env vars fall back to 0.20. |
| `test_preference_weighting_biases_use` (P1) | Given two crossing types, a species preferring overpass uses it at a measurably higher rate. |
| `test_hex_six_neighbours` | Every interior tile has exactly six neighbours; no diagonal edges exist. |

## 2. `infrastructure_manager_test.gd` — placement, span, signal

| Test | Asserts |
|---|---|
| `test_overpass_placeable_on_dangerous_tile` | Placement on `is_hazardous`/`is_impassable` succeeds. |
| `test_overpass_rejected_on_plain_terrain` | Placement on plain terrain is rejected and reports the error/red-preview state. |
| `test_animal_crossed_signal_fires_exactly_once` | One successful traversal emits `animal_crossed` exactly once (no double-count, no miss). |
| `test_crossing_completed_emitted_on_full_span` | Completing the final cell emits `crossing_completed` once; partial spans emit nothing. |
| `test_usage_counter_increments` (P1) | Each `animal_crossed` increments the crossing's usage count shown in tile-inspect. |
| `test_crossing_type_is_data_driven` | Adding an `infrastructure.json` type needs no code branch (registry lookup only). |

## 3. `connectivity_graph_test.gd` — patch-adjacency graph

| Test | Asserts |
|---|---|
| `test_graph_built_per_sub_area_at_load` | A sub-area load produces patches-as-nodes, safe-links-as-edges. |
| `test_recompute_only_on_graph_events` | Pan/zoom/frame ticks trigger no recompute; only `crossing_completed` / `season_changed` do. |
| `test_crossing_adds_safe_link` | `crossing_completed` adds exactly one patch edge between the two bridged patches. |
| `test_recompute_is_incremental` | A single crossing recompute touches only affected patches (O(P+L)), not a full rebuild. |
| `test_overlay_reads_cached_values` | The overlay queries cached connectivity; it never initiates a recompute. |
| `test_continental_connection_reachability` | Capstone check returns true only when a connected chain links Greater Yellowstone → Greater Mackenzie Mountains. |

## 4. `habitat_manager_test.gd` — quality and viability

| Test | Asserts |
|---|---|
| `test_quality_formula_clamped_0_100` | `terrain_base + size + connectivity − edge_penalty` clamps to [0,100]. |
| `test_quality_recompute_on_crossing` | A new safe link raises `connectivity_bonus` and can raise the band. |
| `test_quality_recompute_not_per_frame` | Quality recomputes on events only, never per `_process`. |
| `test_four_bands_mapping` | Scores map to Poor/Fair/Good/Excellent at the band constants. |
| `test_below_min_viable_declines` | A patch below `min_viable_patch_size` and unconnected declines slowly. |
| `test_network_size_used_when_connected` | Once linked into a larger network, combined size restores viability. |
| `test_partnership_quality_bonus_applied` | Co-stewarded patches receive `PARTNERSHIP_QUALITY_BONUS` after `partnership_formed`. |

## 5. `population_model_test.gd` — counts, recovery, seasons

| Test | Asserts |
|---|---|
| `test_monthly_step_runs_on_month_boundary` | The heavy step runs monthly, not per tick. |
| `test_reconnection_produces_recovery` | Connecting two patches raises counts toward capacity and sets trend RISING. |
| `test_population_recovered_event_fires` | Count-doubled / species-return thresholds emit `population_recovered` once. |
| `test_seasonal_absence_not_decline` | Hibernation/migration removes animals without registering decline. |
| `test_decline_is_gentle` | Unconnected sub-viable patches lose at most `DECLINE_STEP`/month (cozy). |

## 6. `economy_manager_test.gd` — budget and donations

| Test | Asserts |
|---|---|
| `test_starting_budget` | New game starts at 50,000. |
| `test_overpass_cost_per_tile` | A three-tile span costs 15,000; budget decremented correctly. |
| `test_donation_formula` | `BASE_GRANT + Σ(usage × mean_status_weight × fragmentation_mult) + milestone_bonuses` computes as specified. |
| `test_status_weight_scaling` | Endangered (×3) crossings pay more than common (×1) for equal usage. |
| `test_fragmentation_multiplier_range` | Multiplier stays within [1.0, 2.0] from the pre-crossing deficit. |
| `test_fundraising_trickle_prevents_deadlock` | Below the cheapest action, a 500/month trickle is added. |
| `test_budget_changed_emitted` | Spends/incomes emit `budget_changed`. |

## 7. `information_manager_test.gd` — purchases and reveals

| Test | Asserts |
|---|---|
| `test_purchase_reveals_layer` | Each product reveals exactly its layer (habitat numerics / population / corridors / entity weights). |
| `test_information_is_permanent` | A reveal persists for the rest of the session and across save/load. |
| `test_locked_sub_area_no_ecological_data` | Locked sub-areas expose terrain only, no ecological layer, until unlocked. |
| `test_costs_match_constants` | Product costs equal the `economy_constants.gd` values. |

## 8. `permissions_manager_test.gd` — trust and unlocks

| Test | Asserts |
|---|---|
| `test_trust_accumulates_from_weighted_metrics` | Trust rises per each entity's `metric_weights`. |
| `test_unlock_triggers_at_threshold` | Reaching the threshold emits `sub_area_unlocked` and a one-time bonus once. |
| `test_relationship_stages_quartiles` | Introduced/Engaged/Trusted/Partnered map to trust quartiles. |
| `test_central_rockies_starts_unlocked` | Sub-area 7 is unlocked at game start; all others locked. |
| `test_crown_low_threshold_first_unlock` | Crown of the Continent has the lowest non-zero threshold. |
| `test_permission_never_revoked` | Neglect never re-locks an unlocked area; it only slows other-entity trust growth. |
| `test_partnership_formed_grants_benefits` | `partnership_formed` triggers free corridor data, habitat bonus, and placement hints. |

## 9. `season_manager_test.gd` / `time_controller_test.gd` — time and seasons

| Test | Asserts |
|---|---|
| `test_season_length_15_min_at_1x` | A season spans 15 real minutes / 90 in-game days at 1×. |
| `test_season_changed_emitted_on_boundary` | `season_changed` fires once per boundary with the new season. |
| `test_pause_halts_sim_not_ui` | Pause stops sim ticks; build/info actions still succeed. |
| `test_speed_multipliers` | 1×/2×/4× scale ticks-per-second proportionally. |
| `test_frozen_river_clears_hazard` | Winter clears `is_hazardous` on river tiles; spring restores + widens by one tile. |
| `test_migration_motivation_spike` | Migratory species raise crossing attempts in their migration season. |

## 10. Support test files

- `data_validation_test.gd` — every schema sample in
  [`data-schemas`](data-schemas.md) parses and satisfies its field table; all 8
  species, 12 sub-areas, 9 entities present; every `controlling_entity_id`
  resolves; env-var defaults registered.
- `save_manager_test.gd` — round-trip serialise/deserialise of `GameState`;
  `save_version` present; reference-by-id integrity; a migration step upgrades an
  older `save_version`; connectivity graph rebuilds from saved crossings.
- `milestone_tracker_test.gd` — per-sub-area milestones fire on their conditions;
  capstone fires only on the full chain; rewards apply once; nothing is gated
  behind the capstone.

---

## 11. P0 acceptance-criterion → test mapping

Every P0 criterion in `wildlife-overpass-crossing` and
`crossing-location-selection`, plus the resolved decisions in the consolidated
PRD, is either mapped to tests that exist in `game/tests/` or carries a
**Deferred** entry that says what is not covered and why.

How to read a row: the **Test(s)** column names tests as `file_test.gd::function`
(a bare function name after such a pair is in the same file as the pair before it). The
**Deferred** column is `—` when the test(s) cover the whole criterion; otherwise it
names the part no test covers and the reason. A row whose **Test(s)** cell is
"none yet" is deferred in full. A deferred part is not covered and is not a
passing claim: it is the list of what a person still has to check.

Names in this section must stay real. When a test is renamed or removed, change its
row in the same commit; `docs/plan/facts.json` `game.tests` lists the test files
that exist.

### `wildlife-overpass-crossing` (P0)

| P0 criterion | Test(s) | Deferred |
|---|---|---|
| Tile danger properties block / trigger correctly | `pathfinding_test.gd::test_impassable_blocks_movement`, `test_hazardous_is_traversable_but_unsafe`; `species_manager_test.gd::test_animal_died_on_uncovered_hazard`; `data_validation_test.gd::test_tiles_schema` (no shipped tile is both impassable and hazardous) | — |
| Overpass tile type placeable from palette | `data_validation_test.gd::test_infrastructure_schema` (overpass is in the registry and available in v1); `infrastructure_manager_test.gd::test_placeable_on_dangerous_rejected_on_plain`, `test_crossing_type_is_data_driven`; `build_mode_test.gd::test_setup_reads_segment_and_type` | The player's selection control and how a placed overpass is drawn on the map. No test renders either; `world_renderer_test.gd` covers projection, centring and hotspot markers only. |
| Placement validation (red preview on invalid) | `infrastructure_manager_test.gd::test_placeable_on_dangerous_rejected_on_plain`; `build_mode_test.gd::test_toggle_rejects_a_non_selectable_tile`, `test_selectable_only_on_the_segments_own_dangerous_tiles` | The red preview state. The tests assert that an invalid placement is rejected; none asserts that the invalid preview is drawn. |
| Pathfinding graph update on full vs partial span | `pathfinding_test.gd::test_full_span_creates_zero_mortality_route`, `test_partial_span_creates_no_safe_route`, `test_covered_barrier_becomes_traversable`; `infrastructure_manager_test.gd::test_completed_minimal_span_route_is_zero_mortality`, `test_lone_corner_tile_is_not_a_two_sided_core`; `simulation_test.gd::test_crossing_zeroes_the_route` | "Tiles of the same corridor away from the span stay hazardous." No test asserts that building one crossing leaves the rest of the corridor hazardous. |
| Per-terrain mortality via env vars (independent) | `species_manager_test.gd::test_road_mortality_honours_env_var`, `test_river_mortality_independent_of_road`, `test_default_mortality_is_0_20`; `env_config_test.gd::test_terrains_resolve_independently`, `test_os_env_used_when_no_override`, `test_override_used_when_os_env_unset`, `test_default_when_no_override_and_no_os_env` | — |
| `animal_crossed` fires exactly once | `species_manager_test.gd::test_animal_crossed_fires_once_per_traversal` | — |
| Crossing success feedback (visual+audio) | `hud_test.gd::test_show_crossing_cue_displays_count_and_icon`, `test_crossing_cue_fades_out_over_its_window` (the HUD flash appears and fades) | The audio cue, and any effect on the overpass tile itself. No GUT test plays or hears either, and the cue ships as a HUD flash. Owned by the written visual + audio QA pass (roadmap, Phase 1 decision of 2026-07-31, item C3). |

### `crossing-location-selection` (P0)

| P0 criterion | Test(s) | Deferred |
|---|---|---|
| Tool opens Y2Y world map in selection mode | `world_select_controller_test.gd::test_enter_selection_mode_opens_world_view` | The toolbar "Add crossing" button. `main.gd` opens the map from a placeholder trigger (`_open_world_select`), and no test drives it. |
| Y2Y world map shows all sub-areas | `world_select_controller_test.gd::test_world_view_draws_the_cards_fully_opaque`; `species_registry_test.gd::test_all_twelve_sub_areas_load` | That each of the twelve cards is drawn and identifiable. The tests assert that the card layer is fully opaque in world view and that twelve sub-areas load, not the per-card drawing. |
| Continuous zoom, no level transitions | `world_select_controller_test.gd::test_world_mode_does_not_activate_inside_hysteresis_band`, `test_segment_mode_survives_hysteresis_band`, `test_cards_give_way_across_the_hysteresis_band`, `test_crossing_the_band_raises_no_prompt_or_extra_event` | — |
| Locked/unlocked visual treatment; zoom blocked on locked | `world_select_controller_test.gd::test_locked_sub_area_blocks_zoom_at_boundary`, `test_focusing_a_locked_area_at_segment_zoom_exits_segment_mode`, `test_locked_focus_never_reveals_the_world`, `test_setup_derives_lock_state_from_starts_unlocked`, `test_registry_data_unlocks_the_tutorial_sub_area`, `test_registry_data_leaves_the_other_sub_areas_locked` | The desaturated treatment and the lock indicator. The tests assert lock state and the zoom block, not how a locked card is drawn. |
| Connectivity overlay at segment zoom; hidden otherwise | `connectivity_overlay_test.gd::test_overlay_starts_inactive`, `test_overlay_appears_only_in_segment_mode`, `test_overlay_clears_when_zooming_back_out`, `test_overlay_clears_on_selection_mode_exit`, `test_overlay_clears_on_confirm_hand_off`, `test_overlay_clears_on_escape_key`, `test_fragmented_patch_is_warmer_than_connected_patch` | — |
| Segment hover highlight on valid tiles only | `world_select_controller_test.gd::test_hover_highlights_dangerous_only`, `test_hover_does_nothing_in_world_view` | — |
| Confirmation panel (segment, budget, note; buttons) | `confirm_panel_test.gd::test_open_shows_segment_budget_and_note`, `test_confirm_passes_exact_segment_and_sub_area`, `test_cancel_closes_and_emits_cancelled_only`; `world_select_controller_test.gd::test_left_click_in_segment_mode_emits_segment_clicked` | That a click on a valid segment opens the panel. Each end is asserted (the controller emits `segment_clicked`; the panel opens) but the wiring between them lives in `main.gd`, which has no test. |
| Budget gate disables Confirm | `confirm_panel_test.gd::test_insufficient_budget_disables_confirm_with_note`, `test_sufficient_budget_enables_confirm` | — |
| Confirm advances to construction with correct segment | `confirm_panel_test.gd::test_confirm_passes_exact_segment_and_sub_area`; `build_mode_test.gd::test_setup_reads_segment_and_type` | The hand-off itself: that the panel's `confirmed` signal opens construction with the segment pre-selected. The wiring lives in `main.gd`, which has no test. |
| Cancel returns to selection with overlay active | `confirm_panel_test.gd::test_cancel_closes_and_emits_cancelled_only` | That the player is back in hover-selection with the overlay still active. No test cancels the panel with a controller and overlay attached and then asserts they are unchanged. |
| Escape exits selection mode from any state | `world_select_controller_test.gd::test_escape_key_exits_selection_mode`, `test_exit_from_segment_mode_leaves_entirely`, `test_hover_clears_on_escape`; `confirm_panel_test.gd::test_escape_exit_closes_panel_silently`; `connectivity_overlay_test.gd::test_overlay_clears_on_escape_key` | — |
| Click-outside closes panel (= Cancel) | `confirm_panel_test.gd::test_click_outside_the_panel_box_cancels` | — |

### Resolved-decision coverage (consolidated PRD)

| Decision | Test(s) | Deferred |
|---|---|---|
| Habitat quality formula + bands + numerics behind purchase | `habitat_manager_test.gd::test_quality_clamped_0_100`, `test_four_bands_mapping`; `information_manager_test.gd::test_purchase_reveals_layer` | — |
| Donation monthly formula | `economy_manager_test.gd::test_donation_formula`, `test_status_weight_scaling`, `test_fragmentation_multiplier_range` | — |
| Win condition / capstone non-gating | none yet (`data_validation_test.gd::test_milestones_schema` checks the milestone data shape only) | Deferred in full. The milestone tracker is Phase 6 and has no script yet; its suite lands with it (roadmap Phase 6 exit criteria). |
| Time pacing + pause-while-acting | `constants_test.gd::test_simulation_constants_match_schema` (season length and days per season are the schema values) | Pause, speed multipliers and the season-boundary signal. Phase 4 has no time controller or season manager script yet; their suites land with it (roadmap Phase 4 exit criteria). |
| Connectivity precompute + incremental | `connectivity_overlay_test.gd::test_rebuild_after_safe_link_merges_networks`; `connectivity_graph_test.gd::test_grizzly_subviable_then_rescued_by_crossing` | That recompute happens only on graph events and is incremental. The tests show the cached scores follow a new safe link; none counts recomputes or compares an incremental update with a full rebuild. |
| Segment-zoom ≥16px with 12px hysteresis | `world_select_controller_test.gd::test_zoom_to_activate_threshold_enters_segment_mode`, `test_below_activate_threshold_stays_in_world_mode`, `test_world_mode_does_not_activate_inside_hysteresis_band`, `test_segment_mode_survives_hysteresis_band`, `test_below_deactivate_threshold_exits_segment_mode`; `constants_test.gd::test_simulation_constants_match_schema` | — |
| Nine entities / trust / stages / unlock | `data_validation_test.gd::test_entities_schema` (nine entities, three First Nations, every sub-area governed) | Trust, stages and unlock behaviour. Phase 5 (permissions) is held behind the cultural-advisor review and has no script yet; its suite lands with it. |
| Never-revoke | none yet | Deferred in full. A permission, once granted, is never revoked is Phase 5 behaviour; there is no permissions system to test (see the row above). |
| Hex 6-directional unambiguous crossing | `hex_grid_test.gd::test_six_distinct_directions`, `test_every_cell_has_six_neighbours_each_one_edge_away` | — |
| `animal_crossed` per-traversal + 2s coalescing | `species_manager_test.gd::test_animal_crossed_fires_once_per_traversal`; `constants_test.gd::test_simulation_constants_match_schema` (the 2s window value); `hud_test.gd::test_show_crossing_cue_displays_count_and_icon` | That crossings within the 2s window coalesce into one "+N" cue. The timer lives in `main.gd`, which has no test. |
| First Nations partnership mechanical benefits | `habitat_manager_test.gd::test_partnership_quality_bonus_applied` | The `partnership_formed` event granting the benefits. The signal is declared on the event bus but nothing emits it or calls `set_costewarded` yet; that wiring is Phase 5. Only the quality bonus itself is tested. |

## Cross-references

- Systems under test: [`architecture`](architecture.md)
- Algorithms under test: [`simulation-design`](simulation-design.md)
- Data validated by `data_validation_test.gd`: [`data-schemas`](data-schemas.md)
- Phase in which each suite is written: [`roadmap`](roadmap.md)
