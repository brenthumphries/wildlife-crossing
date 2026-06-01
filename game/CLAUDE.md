# Wildlife Crossing — game/ Scoped Instructions

> Extends `../CLAUDE.md`. Never contradicts it. Read the root file first.

## What lives here

Everything Godot touches: the project file, all scenes, scripts, assets, data
files, and tests. When working in this directory, treat it as the Godot project
root.

---

## Directory layout

```
game/
├── project.godot          # Godot project settings
├── assets/
│   ├── audio/             # .ogg, .wav — music and SFX
│   ├── fonts/             # .ttf, .otf, bitmap fonts
│   ├── sprites/           # Individual sprite sheets per entity/character
│   └── tilesets/          # Tileset images and .tres resource files
├── data/                  # Static game data as .json (species, biomes, etc.)
├── scenes/
│   ├── ui/                # HUD, menus, overlays — PascalCase.tscn
│   └── world/             # World tiles, entities, habitat zones — PascalCase.tscn
├── scripts/
│   ├── systems/           # Core simulation systems (one .gd per system)
│   └── ui/                # UI controllers and screen managers
└── tests/                 # GUT test files — <system_name>_test.gd
```

---

## GDScript conventions (extends root)

- Every `.gd` file opens with a `## one-line description` docstring.
- `class_name` declaration on the second line for any reusable class.
- Signal declarations come before `@export` variables, which come before
  regular variables.
- Use `@export` for designer-tunable values; never hardcode them inline.
- Prefer `await` over callbacks for sequenced async logic.
- No `print()` statements in committed code — use a `Debug` autoload with
  configurable verbosity levels instead.

### Signal naming

Signals are named in past tense: `habitat_created`, `animal_spawned`,
`season_changed`. Handlers are named `_on_<emitter>_<signal>`.

### Autoloads (singletons)

Declare in `project.godot`. Keep the list minimal — add a new autoload only
when a system truly needs global access.

| Autoload name     | Purpose                                      |
|-------------------|----------------------------------------------|
| `GameState`       | Current save state, active biome, time       |
| `EventBus`        | Global signal relay for cross-system events  |
| `Debug`           | Configurable logging (verbose, info, warn)   |
| `SpeciesRegistry` | Loaded species data from `data/`             |

---

## Scene conventions

- One root node per scene; use descriptive node names in PascalCase.
- Scenes own their own child nodes — don't reach up the tree with `get_parent()`.
- Connect signals in `_ready()`, not in the editor, so the connection is
  always visible in code.
- UI scenes inherit from a `BaseScreen` scene where possible.
- World entity scenes use a consistent structure:
  `EntityRoot → Sprite2D, CollisionShape2D, [AnimationPlayer]`

---

## Systems

These are the core simulation systems planned or in progress. Each lives in
`scripts/systems/` as a single `.gd` file and gets a matching test in `tests/`.

| System file              | Responsibility                                      |
|--------------------------|-----------------------------------------------------|
| `habitat_manager.gd`     | Zone placement, habitat type assignment, adjacency  |
| `species_manager.gd`     | Animal spawning, needs satisfaction, population     |
| `ecosystem_manager.gd`   | Food web, resource flows, biodiversity score        |
| `season_manager.gd`      | Season cycle, weather, environmental modifiers      |
| `infrastructure_manager.gd` | Roads, corridors, crossings, connectivity graph  |
| `save_manager.gd`        | Serialise/deserialise `GameState` to disk           |

Add a row here whenever a new system is created.

---

## Data files (`data/`)

Static reference data is stored as JSON and loaded by autoloads at startup.
Schema changes require updating the loader in `SpeciesRegistry` (or the
relevant manager) and bumping the data version key in the file.

| File                  | Contents                                       |
|-----------------------|------------------------------------------------|
| `species_stats.json`  | Per-species needs, range, behaviour flags      |
| `biome_definitions.json` | Habitat types, climate params, valid species |
| `infrastructure.json` | Crossing types, costs, connectivity bonuses    |

---

## Testing

- Framework: **GUT** (Godot Unit Testing). Install as a plugin via the Asset
  Library or by placing the `addons/gut/` folder in `game/`.
- Test files live in `game/tests/` and are named `<system>_test.gd`.
- Every new system file needs at least one corresponding test file before it is
  considered "done".
- Tests must not depend on scene tree or autoloads where possible — test logic
  in isolation by instantiating classes directly.
- Run all tests via the GUT panel in the Godot editor, or via `gut_cmdln.gd`
  in CI.

### Test file template

```gdscript
## Tests for <SystemName>.
extends GutTest

var _subject: SystemName

func before_each() -> void:
    _subject = SystemName.new()

func after_each() -> void:
    _subject.free()

func test_example() -> void:
    assert_eq(_subject.some_value, expected_value)
```

---

## Asset pipeline

- **Sprites**: exported from Aseprite as PNG sprite sheets. Keep source
  `.aseprite` files in a sibling `_src/` folder alongside the PNG. Do not
  commit binaries you didn't generate yourself.
- **Tilesets**: one image per biome theme. Tile size is **16×16 px** at 1×;
  the game renders at 2× or 3× scale via a global `CanvasItem` scale.
- **Audio**: all music as `.ogg` (looping), SFX as `.wav`. Keep file sizes
  small — compress in the Godot import settings.

---

## What to do when uncertain

- If a new system would create a new autoload, discuss it first.
- If a scene structure diverges from the conventions above, flag it.
- If a data schema change would break existing save files, design a migration
  path before touching the schema.
