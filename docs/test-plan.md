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
test**. The mapping table in §11 is the proof of that coverage.

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
PRD, maps to at least one named test.

### `wildlife-overpass-crossing` (P0)

| P0 criterion | Test(s) |
|---|---|
| Tile danger properties block / trigger correctly | `test_impassable_blocks_movement`, `test_hazardous_is_traversable`, `test_impassable_and_hazardous_mutually_exclusive` |
| Overpass tile type placeable from palette | `test_overpass_placeable_on_dangerous_tile` |
| Placement validation (red preview on invalid) | `test_overpass_rejected_on_plain_terrain` |
| Pathfinding graph update on full vs partial span | `test_full_span_creates_zero_mortality_route`, `test_partial_span_creates_no_route`, `test_covered_barrier_becomes_traversable` |
| Per-terrain mortality via env vars (independent) | `test_road_mortality_honours_env_var`, `test_river_mortality_independent_of_road`, `test_default_mortality_is_0_20` |
| `animal_crossed` fires exactly once | `test_animal_crossed_signal_fires_exactly_once` |
| Crossing success feedback (visual+audio) | `test_animal_crossed_signal_fires_exactly_once` (signal) + UI feedback verified in audio/UI specs |

### `crossing-location-selection` (P0)

| P0 criterion | Test(s) |
|---|---|
| Tool opens Y2Y world map in selection mode | `world_select_controller_test.gd::test_add_crossing_opens_selection` |
| Y2Y world map shows all sub-areas | `world_select_controller_test.gd::test_all_sub_areas_visible` |
| Continuous zoom, no level transitions | `world_select_controller_test.gd::test_continuous_zoom_threshold_hysteresis` |
| Locked/unlocked visual treatment; zoom blocked on locked | `world_select_controller_test.gd::test_locked_zoom_blocked`, `test_central_rockies_starts_unlocked` |
| Connectivity overlay at segment zoom; hidden otherwise | `connectivity_overlay_test.gd::test_overlay_visible_only_in_segment_mode`, `test_overlay_reads_cached_values` |
| Segment hover highlight on valid tiles only | `world_select_controller_test.gd::test_hover_highlights_dangerous_only` |
| Confirmation panel (segment, budget, note; buttons) | `confirm_panel_test.gd::test_panel_shows_segment_budget_note` |
| Budget gate disables Confirm | `confirm_panel_test.gd::test_zero_budget_disables_confirm`, `economy_manager_test.gd::test_starting_budget` |
| Confirm advances to construction with correct segment | `confirm_panel_test.gd::test_confirm_passes_segment_to_construction` |
| Cancel returns to selection with overlay active | `confirm_panel_test.gd::test_cancel_restores_selection` |
| Escape exits selection mode from any state | `world_select_controller_test.gd::test_escape_exits_from_any_state` |
| Click-outside closes panel (= Cancel) | `confirm_panel_test.gd::test_click_outside_closes_panel` |

### Resolved-decision coverage (consolidated PRD)

| Decision | Test(s) |
|---|---|
| Habitat quality formula + bands + numerics behind purchase | `test_quality_formula_clamped_0_100`, `test_four_bands_mapping`, `test_purchase_reveals_layer` |
| Donation monthly formula | `test_donation_formula`, `test_status_weight_scaling`, `test_fragmentation_multiplier_range` |
| Win condition / capstone non-gating | `milestone_tracker_test.gd` (capstone + non-gating), `test_continental_connection_reachability` |
| Time pacing + pause-while-acting | `test_season_length_15_min_at_1x`, `test_pause_halts_sim_not_ui`, `test_speed_multipliers` |
| Connectivity precompute + incremental | `test_recompute_only_on_graph_events`, `test_recompute_is_incremental` |
| Segment-zoom ≥16px with 12px hysteresis | `test_continuous_zoom_threshold_hysteresis` |
| Nine entities / trust / stages / unlock | `permissions_manager_test.gd` (all rows) |
| Never-revoke | `test_permission_never_revoked` |
| Hex 6-directional unambiguous crossing | `test_hex_six_neighbours` |
| `animal_crossed` per-traversal + 2s coalescing | `test_animal_crossed_signal_fires_exactly_once` + audio-spec coalescing cue |
| First Nations partnership mechanical benefits | `test_partnership_formed_grants_benefits`, `test_partnership_quality_bonus_applied` |

## Cross-references

- Systems under test: [`architecture`](architecture.md)
- Algorithms under test: [`simulation-design`](simulation-design.md)
- Data validated by `data_validation_test.gd`: [`data-schemas`](data-schemas.md)
- Phase in which each suite is written: [`roadmap`](roadmap.md)
