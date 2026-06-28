---
title: "Technical Architecture"
date: 2026-06-17
status: active
---

## Purpose

This document defines the technical architecture of Wildlife Crossing: the
Godot 4 scene tree and autoload structure, the simulation tick model, the
boundaries between systems and the signals that connect them, the save/load
design, and the performance budget for the per-event connectivity recompute. It
is the keystone the other design documents reference. It elaborates the systems
described in [`game-design-overview`](../obsidian-vault/prd/game-design-overview.md)
and the consolidated [`fable-wildlife-crossing`](../obsidian-vault/prd/fable-wildlife-crossing.md)
PRD without changing any decision in them.

Conventions are inherited from the root and scoped `CLAUDE.md` files: GDScript
with static type hints, one class per file in snake_case, `class_name` on line
two, signals declared before exports before regular variables, signals named in
past tense, handlers named `_on_<emitter>_<signal>`, named constants only, no
`print()` (use the `Debug` autoload).

> Decision logged: where this document specifies a structural detail the PRD set
> leaves open (autoload roster additions, tick ordering, autosave cadence), the
> choice is stated here and flagged inline with `> Decision logged:`.

---

## 1. System inventory and script map

Every system named in the PRD set maps to exactly one script (and, where it owns
visible nodes, one scene). The scoped `game/CLAUDE.md` already names six core
system files; this document keeps those names and adds the systems the full PRD
set requires. Each new system file is added to the `game/CLAUDE.md` systems
table when implemented.

> Path convention ([ADR 0013](adr/0013-scaffolding-conventions.md)): the script
> and scene paths in the tables below are **shorthand relative to the canonical
> roots** — `systems/foo.gd` means `game/scripts/systems/foo.gd`; `world/Foo.tscn`
> means `game/scenes/world/Foo.tscn`. The directory scheme in `game/CLAUDE.md`
> (`game/scenes/{ui,world}/`, `game/scripts/{systems,ui}/`) is authoritative.

| PRD system / concern | Script (`game/scripts/...`) | Primary scene | Notes |
|---|---|---|---|
| World data: tiles, hex grid, terrain flags, segments, sub-area geometry | `systems/world_data.gd`, `systems/hex_grid.gd` | `world/WorldMap.tscn` | Static world loaded from `data/`; the per-coordinate terrain map is authored as data (`data/world/<sub_area>.json`) and the `WorldMap` `TileMapLayer` set is generated from it at load — the bridge is one-way, `data/` → tilemap ([ADR 0006](adr/0006-world-map-authoring.md)). Owns the hex topology ([ADR 0002](adr/0002-hex-grid-topology.md)) |
| Habitat & zoning: patches, quality score, viability | `systems/habitat_manager.gd` | — | Per-patch 0–100 quality; recompute on graph-changing events only |
| Connectivity: patch-adjacency graph | `systems/connectivity_graph.gd` | — | Single source of truth for overlay, quality bonus, trust metrics ([ADR 0004](adr/0004-connectivity-patch-adjacency-graph.md)) |
| Species & animal simulation: spawning, movement, pathfinding | `systems/species_manager.gd`, `systems/pathfinding.gd` | `world/Animal.tscn` | 6-directional hex pathfinding; mortality checks |
| Population model: per-patch counts, trend, recovery events | `systems/population_model.gd` | — | Monthly step; fires recovery milestone events |
| Crossings & infrastructure: placement, span validation, connectivity edges | `systems/infrastructure_manager.gd` | `world/Crossing.tscn` | Data-driven crossing types ([ADR 0003](adr/0003-crossing-tile-architecture.md)) |
| Economy & budget: spend, donations, monthly income | `systems/economy_manager.gd` | — | Donation formula; community-fundraising deadlock trickle |
| Information & uncertainty: purchases, reveal state | `systems/information_manager.gd` | — | Per-area/per-entity permanent reveals |
| Permissions & progression: trust scores, unlocks | `systems/permissions_manager.gd` | — | Nine entities; trust 0–100; unlock events |
| Seasons & time: clock, season cycle, modifiers | `systems/season_manager.gd`, `systems/time_controller.gd` | — | 1 season = 15 min at 1×; pause/1×/2×/4× |
| Milestones: per-sub-area + capstone | `systems/milestone_tracker.gd` | — | Continental Connection reachability check |
| Save/load | `systems/save_manager.gd` | — | JSON, versioned, atomic ([ADR 0005](adr/0005-save-file-format.md)) |
| Narrative/cultural content surfacing | `systems/narrative_manager.gd` | — | Unlock beats, land acknowledgment, entity briefs (data-driven) |
| UI: world map + selection mode | `ui/world_select_controller.gd` | `ui/WorldSelectMap.tscn` (selection mode) | Continuous zoom; locked-area treatment. Renamed from `WorldMap.tscn` to avoid the collision with the simulated `world/WorldMap.tscn` ([ADR 0013](adr/0013-scaffolding-conventions.md)) |
| UI: connectivity overlay | `ui/connectivity_overlay.gd` | `ui/ConnectivityOverlay.tscn` | Orange→teal heatmap, 40% opacity |
| UI: confirmation panel | `ui/confirm_panel.gd` | `ui/ConfirmPanel.tscn` | Segment label, budget, connectivity note |
| UI: build palette | `ui/build_palette.gd` | `ui/BuildPalette.tscn` | Crossing-type selection (construction step) |
| UI: patch/tile inspect | `ui/inspect_panel.gd` | `ui/InspectPanel.tscn` | Quality band, usage counter |
| UI: entity profile + trust checklist | `ui/entity_profile.gd` | `ui/EntityProfile.tscn` | Stage + top-3 conditions with progress bars |
| UI: seasonal calendar | `ui/season_calendar.gd` | `ui/SeasonCalendar.tscn` | Always visible; planning aid |
| UI: budget HUD | `ui/budget_hud.gd` | `ui/BudgetHUD.tscn` | Current budget, last donation |
| UI: milestone track | `ui/milestone_track.gd` | `ui/MilestoneTrack.tscn` | Corridor Milestones |
| UI: time controls | `ui/time_controls.gd` | `ui/TimeControls.tscn` | Pause/1×/2×/4× |
| UI: base screen | `ui/base_screen.gd` | `ui/BaseScreen.tscn` | Parent of UI scenes; click-outside-closes rule |

The simulation systems above are plain `RefCounted`/`Node` classes instantiated
under the world; they avoid scene-tree and autoload dependencies where possible
so they can be unit-tested in isolation (per `game/CLAUDE.md` testing rule).

> Decision logged: `connectivity_graph.gd`, `population_model.gd`,
> `economy_manager.gd`, `information_manager.gd`, `permissions_manager.gd`,
> `time_controller.gd`, `milestone_tracker.gd`, and `narrative_manager.gd` are
> new system files beyond the six listed in `game/CLAUDE.md`. They are systems,
> not autoloads — they live under the world subtree and are accessed via signals
> and `GameState`, not as global singletons, to keep the autoload roster minimal.

---

## 2. Autoloads (singletons)

The scoped `game/CLAUDE.md` defines four autoloads; this architecture keeps that
roster unchanged. Adding an autoload requires discussion per the conventions, and
nothing here needs one.

| Autoload | Responsibility | Why global |
|---|---|---|
| `GameState` | The live, save-able world state: budget, time/season, per-patch populations, trust scores, reveal flags, built crossings, milestone progress. The serialisation target. | Every system reads/writes it; it *is* the save. |
| `EventBus` | Global signal relay for cross-system events. Systems emit and subscribe here instead of holding direct references to each other. | Decouples systems; realises "signals over direct references". |
| `Debug` | Configurable logging (verbose / info / warn). Replaces `print()`. | Cross-cutting. |
| `SpeciesRegistry` | Loads and serves static species data from `data/`. Extended in practice to also serve sub-area, segment, entity, and infrastructure data via sibling loaders (`WorldDataRegistry` pattern) — see note. | Read-only reference data needed everywhere. |

> Decision logged: rather than add new autoloads for sub-area/entity/segment
> data, `SpeciesRegistry` is the first of a small set of read-only data
> registries loaded at startup; if more than one is needed they are grouped
> under a single `DataRegistry` autoload to keep the roster minimal. The
> distinction (registries = static `data/`; `GameState` = mutable save) is
> firm: nothing static is serialised into saves ([ADR 0005](adr/0005-save-file-format.md)).

---

## 3. Scene tree

```
Main (Node)
├── GameState            ─┐
├── EventBus              │  (autoloads — registered in project.godot,
├── Debug                 │   parented to the root viewport, not Main)
├── SpeciesRegistry      ─┘
│
└── Game (Node2D)                         # root of an active session
    ├── World (Node2D)                    # the simulated world
    │   ├── WorldMap (TileMapLayer set)   # render output; generated at load from data/world/<sub_area>.json (ADR 0006), not read back by the sim
    │   │   ├── TerrainLayer
    │   │   ├── HazardLayer               # is_hazardous / is_impassable tiles
    │   │   └── CrossingLayer             # placed crossing tiles
    │   ├── Patches (Node)                # habitat patch nodes (data-backed)
    │   ├── Animals (Node)                # active Animal instances
    │   └── Simulation (Node)             # owns the system objects below
    │       ├── world_data
    │       ├── connectivity_graph
    │       ├── habitat_manager
    │       ├── species_manager
    │       ├── pathfinding
    │       ├── population_model
    │       ├── infrastructure_manager
    │       ├── economy_manager
    │       ├── information_manager
    │       ├── permissions_manager
    │       ├── season_manager
    │       ├── time_controller
    │       ├── milestone_tracker
    │       └── narrative_manager
    ├── Camera2D                          # continuous zoom; drives segment-zoom threshold
    └── UILayer (CanvasLayer)
        ├── BudgetHUD
        ├── TimeControls
        ├── SeasonCalendar
        ├── MilestoneTrack
        ├── WorldMapController            # selection mode (continuous zoom)
        │   ├── ConnectivityOverlay
        │   └── ConfirmPanel
        ├── BuildPalette
        ├── InspectPanel
        └── EntityProfile
```

Systems under `Simulation` are instantiated and owned by a `simulation.gd`
coordinator that wires their signals in `_ready()` (connections are made in
code, never in the editor, per conventions). UI scenes inherit `BaseScreen`,
which implements the universal **click-outside-closes-panel** and **Escape**
handling described in the UI/UX spec.

---

## 4. Simulation tick model

### Two clocks

The game separates **render frames** (Godot `_process`) from **simulation
steps** (a fixed-rate logical tick). Animal movement and mortality run on the
simulation tick; rendering interpolates between ticks for smooth motion. This
keeps simulation behaviour independent of frame rate and makes it deterministic
and testable.

| Time unit | Real time at 1× | Drives |
|---|---|---|
| Simulation tick | fixed `SIM_TICK_SECONDS` (named constant) | animal step, mortality check, crossing events |
| In-game day | ≈ 10 seconds | day counter |
| Season | 15 minutes (= 90 in-game days) | seasonal modifiers, autosave |
| Year | 60 minutes (4 seasons) | year counter |

Time controls scale the tick rate: pause halts simulation ticks entirely (UI,
build, and information actions still work — they are not on the sim tick); 1×,
2×, 4× multiply ticks-per-second. `time_controller.gd` owns the speed multiplier
and emits `time_speed_changed`; `season_manager.gd` consumes ticks to advance
the day/season and emits `season_changed` at each boundary.

> Decision logged: `SIM_TICK_SECONDS` defaults to 0.1 s of real time at 1×
> (10 ticks/second), giving ~100 ticks per in-game day. Final value is a tuning
> constant in `economy_constants.gd`'s sibling `simulation_constants.gd`; it does
> not affect determinism because all per-step probabilities are per-tick.

### Per-tick order (within `Simulation`)

A single simulation step executes systems in a fixed order so that cause
precedes effect deterministically within the tick:

1. `season_manager` — advance time; if a boundary is crossed, defer
   `season_changed` to end-of-tick (so movement in this tick uses one consistent
   season).
2. `species_manager` / `pathfinding` — advance each active animal one hex along
   its path; on entering an uncovered `is_hazardous` tile, run the mortality
   check; on completing a crossing traversal, emit `animal_crossed`.
3. `population_model` — accumulate per-patch crossing tallies for the month
   (the heavy monthly step runs only at month boundaries, not every tick).
4. End-of-tick deferred events fire (`season_changed`, recovery milestones),
   triggering the **event-driven** recomputes in §6.

Monthly and seasonal work (donation income, population step, connectivity
re-derivation on season change) is **event-driven**, never per-tick or per-frame.

---

## 5. Signal map

All cross-system communication flows through `EventBus` signals (past-tense
names). Every interaction in the PRD's "How systems interact" table maps to a
named signal below.

### Core signal catalogue

| Signal | Emitted by | Consumed by | Payload |
|---|---|---|---|
| `crossing_completed` | `infrastructure_manager` | `connectivity_graph`, `habitat_manager`, `economy_manager`, `milestone_tracker` | `segment_id`, `crossing_type`, `sub_area_id` |
| `animal_crossed` | `species_manager` (animal) | `economy_manager`, UI feedback layer, `infrastructure_manager` (usage counter) | `crossing_id`, `species_id` |
| `animal_died` | `species_manager` (animal) | `population_model`, `Debug` | `species_id`, `tile`, `cause` |
| `connectivity_recomputed` | `connectivity_graph` | `connectivity_overlay`, `habitat_manager`, `permissions_manager` | `sub_area_id` |
| `habitat_quality_changed` | `habitat_manager` | `inspect_panel`, `population_model` | `patch_id`, `quality`, `band` |
| `population_recovered` | `population_model` | `economy_manager`, `permissions_manager`, `milestone_tracker` | `patch_id`, `species_id`, `event_type` |
| `donation_received` | `economy_manager` | `budget_hud`, `GameState` | `amount`, `breakdown` |
| `budget_changed` | `economy_manager` | `budget_hud`, `confirm_panel`, `build_palette` | `new_balance` |
| `season_changed` | `season_manager` | `species_manager`, `world_data` (terrain shifts), `connectivity_graph`, `population_model`, `season_calendar` | `new_season` |
| `time_speed_changed` | `time_controller` | `season_manager`, `time_controls` | `multiplier` |
| `information_purchased` | `information_manager` | `inspect_panel`, `connectivity_overlay`, `entity_profile`, `permissions_manager` | `product`, `area_or_entity_id` |
| `trust_changed` | `permissions_manager` | `entity_profile` | `entity_id`, `score`, `stage` |
| `sub_area_unlocked` | `permissions_manager` | `world_select_controller`, `economy_manager` (bonus), `narrative_manager`, `milestone_tracker` | `sub_area_id`, `entity_id` |
| `partnership_formed` | `permissions_manager` | `information_manager` (free corridor data), `habitat_manager` (quality bonus), `world_select_controller` (placement hints) | `entity_id`, `sub_area_id` |
| `milestone_reached` | `milestone_tracker` | `economy_manager`, `milestone_track`, `narrative_manager` | `milestone_id`, `is_capstone` |
| `segment_selected` | `world_select_controller` | `confirm_panel` | `segment_id`, `sub_area_id` |
| `location_confirmed` | `confirm_panel` | `build_palette` (construction step) | `segment_id`, `sub_area_id` |
| `selection_cancelled` | `world_select_controller` / `confirm_panel` | `world_select_controller` | — |

### "How systems interact" → signal coverage

Each row of the PRD interaction table is realised by a signal chain:

| PRD cause → effect | Signal chain |
|---|---|
| Player builds a crossing → animals pathfind through it; mortality drops | `crossing_completed` → `connectivity_graph` adds zero-mortality edges → `pathfinding` reads updated graph |
| Animals successfully cross → connectivity & quality recompute upward | `animal_crossed` (usage) + `crossing_completed` → `connectivity_recomputed` → `habitat_quality_changed` |
| Populations recover → donations rise; recovery milestones fire | `population_recovered` → `economy_manager` (income up) + `milestone_reached` |
| Recovery milestones fire → trust rises with entities that value them | `population_recovered` / `milestone_reached` → `permissions_manager` → `trust_changed` |
| Season shifts → migration motivation rises; usage spikes; hazards shift | `season_changed` → `species_manager` (motivation), `world_data` (terrain), `connectivity_graph` |
| Player buys information → better placement; higher effectiveness | `information_purchased` → overlay/inspect reveal → better player choices |
| Trust threshold reached → sub-area unlocks; loop expands | `trust_changed` (crosses threshold) → `sub_area_unlocked` |
| First Nations partnership formed → free corridor data; habitat bonus; hints | `partnership_formed` → `information_manager` + `habitat_manager` + `world_select_controller` |

Every interaction maps to a named signal; this satisfies the architecture
document's acceptance criterion.

---

## 6. Connectivity recompute and performance budget

Connectivity is a **patch-adjacency graph** ([ADR 0004](adr/0004-connectivity-patch-adjacency-graph.md)):
nodes are habitat patches, edges are safe links (contiguous habitat or a
completed same-type crossing chain). It is built per sub-area at load and
recomputed **only** on `crossing_completed` and `season_changed` — never per
frame, never on pan/zoom.

**Budget.** Let `P` = patches in a sub-area (tens), `L` = safe links (tens):

- `crossing_completed`: adding one edge and updating reachability is
  `O(P + L)` — a localised graph update plus a bounded re-derivation of affected
  habitat-quality scores. Runs synchronously inside one tick's end-of-tick phase;
  target < 2 ms.
- `season_changed`: the heaviest event, because terrain shifts (frozen rivers,
  spring floods) can split or merge patches. Patch re-derivation for one
  sub-area is `O(tiles_in_sub_area)` once, then `O(P + L)` for the graph; target
  < 16 ms (one frame) for the active sub-area, with inactive sub-areas recomputed
  lazily on first view. Because season changes occur every 15 minutes, this cost
  is amortised to ~0 per frame.

The overlay, habitat-quality `connectivity_bonus`, and permission "stewardship"
metrics all **read cached values** from the graph; they never trigger a
recompute themselves. This is the single mechanism that keeps the design within
the per-event budget the PRD requires.

The capstone **Continental Connection** check is a reachability query over the
union of all sub-area graphs, evaluated only when a `crossing_completed` event
could plausibly close the final link — not continuously.

---

## 7. Save / load

`save_manager.gd` serialises `GameState` to **versioned JSON**
([ADR 0005](adr/0005-save-file-format.md)). Saves store only mutable runtime
state and reference static data by stable `id`; nothing from `data/` is
duplicated into a save.

Saved state includes: `save_version`, budget, current day/season/year, time
speed, per-patch population records (count, trend, connectivity status),
per-entity trust scores and stages, purchased-information flags
(per-area/per-entity), built crossings (segment id, type, covered tiles),
milestone progress, and partnership states.

Writes are atomic (temp file then rename) to the user data directory. `GameState`
emits nothing on save; on load it repopulates and emits a single
`game_loaded` signal that systems use to rebuild derived state (the connectivity
graph is rebuilt from saved crossings, not stored).

> Decision logged: **autosave fires on `season_changed`** (every 15 minutes) and
> on manual save; this aligns save points with the natural simulation rhythm and
> bounds data loss to one season. Save-file format changes bump the **MAJOR**
> version per the versioning rule and add a migration step keyed on
> `save_version`.

---

## 8. Cross-references

- Data shapes for everything saved or loaded: [`data-schemas`](data-schemas.md)
- Pathfinding, mortality, population, seasonal modifier algorithms:
  [`simulation-design`](simulation-design.md)
- Screen/panel behaviour and input maps:
  [`ui-ux-spec`](../obsidian-vault/design/ui-ux-spec.md) *(to be written)*
- Test coverage of every system here: [`test-plan`](test-plan.md)
- Build order and which ADRs each phase needs: [`roadmap`](roadmap.md)
- ADRs: [0001](adr/0001-choose-godot-4.md), [0002](adr/0002-hex-grid-topology.md),
  [0003](adr/0003-crossing-tile-architecture.md),
  [0004](adr/0004-connectivity-patch-adjacency-graph.md),
  [0005](adr/0005-save-file-format.md)
