# Repo inspection checklist (subagent brief)

Hand this to the Step 1 inventory subagent. Ask it to return a terse,
evidence-backed report — every yes/no claim paired with a file path or a command
output. Do **not** ask it to fix anything; it only reports.

## 1. Systems (game/scripts/systems/ and game/scripts/world/)

For each, report: exists? non-stub (has real logic, not just a docstring)? has a
matching test?

Expected system scripts (from docs/architecture.md autoload + system roster):

- game_state, event_bus, debug, species_registry (the four autoloads in
  project.godot)
- world_data, hex_grid, pathfinding, connectivity_graph
- habitat_manager, infrastructure_manager, species_manager, population_model,
  simulation
- env_config
- constants: habitat_constants, economy_constants, simulation_constants
- world/: world_renderer

Flag any system named in the roadmap/architecture that is **absent**, and any
script present that is an empty stub.

## 2. Data files (game/data/)

Confirm presence + valid JSON for: tiles, species_stats, entities, segments,
infrastructure, milestones, sub_areas, biome_groups. Note anything the schema in
`docs/data-schemas.md` requires that is missing or malformed. Check
`game/data/world/` contents too.

## 3. Scenes (game/scenes/)

- Does `scenes/Main.tscn` exist and is it the `run/main_scene` in
  `project.godot`?
- Does it instantiate/wire the systems, or is it an empty placeholder?
- What else exists under `scenes/ui/` and `scenes/world/` (e.g. `Animal.tscn`)?
  Which are still `.gitkeep`?

## 4. Tests (game/tests/)

- List every `*_test.gd`.
- Cross-reference against the system list: which systems have **no** test?
- Note fixtures in `game/tests/fixtures/`.

## 5. CI (.github/workflows/)

- Is there a real workflow, or only `.gitkeep`?
- If present, does it run headless Godot 4.6 + GUT per ADR 0012?

## 6. Build / export

- Does `game/export_presets.cfg` exist?
- Any binaries in `builds/` or a GitHub Release?
- Conclusion: is there any path from repo to a runnable binary today? (This
  decides first-build vs next-build.)

## 7. Docs freshness signals

- Compare `docs/pre-build-checklist.md` blocker list against what you actually
  found. List each stale claim (it was written when `game/` was mostly
  `.gitkeep`).
- Note the newest `docs/release-notes/` entry, if any, to anchor "most recently
  shipped".
