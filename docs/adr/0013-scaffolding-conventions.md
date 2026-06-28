---
title: "0013 — Scaffolding Conventions: Directory Scheme, Species Data File, Tile Size"
date: 2026-06-28
status: accepted
---

## Context

Three cross-document inconsistencies in
[`p0-open-questions`](../p0-open-questions.md) (**B1**, **B2**, **B3**) each have
two documents specifying conflicting scaffolding facts. They must be reconciled
before the project skeleton (`project.godot`, the directory tree, the first data
files and scenes) is created, so two systems aren't built against contradictory
specs. They are grouped here because all three are one-time scaffolding choices
with no simulation-model content, and follow A8's version pin
([ADR 0012](0012-godot-and-gut-version-pin.md)) in the resolution order.

- **B1 — directory scheme + a scene-name collision.** `game/CLAUDE.md` lays out
  `game/scenes/{ui,world}/` and `game/scripts/{systems,ui}/`. `architecture` §1
  writes paths as `systems/world_data.gd`, `ui/world_map_controller.gd`,
  `world/WorldMap.tscn` — i.e. without the `scenes/`/`scripts/` prefix. Separately,
  **two** `WorldMap.tscn` are listed: `world/WorldMap.tscn` (the simulated tilemap)
  and `ui/WorldMap.tscn` (the sub-area selection screen) — a name collision.
- **B2 — species data file shape.** `game-design-overview` says each species is its
  own JSON file in `game/data/species/`; `data-schemas`, `game/CLAUDE.md`, and the
  `data_validation_test` all assume a single `data/species_stats.json` array.
- **B3 — tile size.** `game/CLAUDE.md` says 16×16; `art-direction` §3 sets a 32×32
  hex bounding box and tunes `SEGMENT_ZOOM_ACTIVATE_PX`/`DEACTIVATE_PX` against
  32×32 (with a logged 24×24 fallback). The zoom thresholds break if this isn't
  settled.

## Decision

### B1 — directory scheme

`game/CLAUDE.md`'s explicit layout is canonical: scenes under
`game/scenes/{ui,world}/`, scripts under `game/scripts/{systems,ui}/`.
`architecture` §1's column entries are **shorthand relative to those roots** —
a script `systems/foo.gd` means `game/scripts/systems/foo.gd`, a scene
`world/Foo.tscn` means `game/scenes/world/Foo.tscn`. `architecture` §1 carries a
one-line note stating this so the shorthand can't be misread as a flat layout.

**WorldMap collision:** the simulated-world scene keeps `scenes/world/WorldMap.tscn`
(it *is* the world tilemap, ADR 0006, and is referenced most often). The
selection-mode UI scene is renamed to **`scenes/ui/WorldSelectMap.tscn`** with
controller **`scripts/ui/world_select_controller.gd`** (was
`ui/world_map_controller.gd`). The two are now unambiguous: `WorldMap` = the
in-session simulated map; `WorldSelectMap` = the front-end sub-area picker.

### B2 — species data file

A **single `game/data/species_stats.json`** array is canonical, matching
`data-schemas`, `game/CLAUDE.md`, the `SpeciesRegistry` loader pattern, and
`data_validation_test` (which targets the single file). The
`game-design-overview` "one JSON file per species in `game/data/species/`" line is
retired; correct it when that PRD is next edited. No `game/data/species/` directory
is created.

### B3 — tile size

**32×32 px** hex bounding box at 1× is canonical, per `art-direction` §3, so the
`SEGMENT_ZOOM_ACTIVATE_PX = 16` / `DEACTIVATE_PX` zoom thresholds land correctly
(the inscribed hex carries ~16px of detail). `game/CLAUDE.md`'s "16×16 px"
asset-pipeline line is corrected to 32×32 in this same change. The 24×24 box
remains the documented fallback if hex authoring proves heavy.

## Consequences

### Positive

- `project.godot`, the directory tree, the species data file, and the tileset
  import settings can be scaffolded against one unambiguous spec — clears the
  **B1/B2/B3** scaffolding cluster, leaving A7/A9/A10/B5–B7 as the remaining P0
  items.
- The `WorldMap` / `WorldSelectMap` split removes a path collision that would
  otherwise produce two scenes resolving to the same name in tooling and docs.
- 32×32 keeps the art-direction zoom-threshold constants valid as authored, so the
  continuous-zoom selection interface needs no retuning.

### Negative / Trade-offs

- `game-design-overview` (a PRD) is left momentarily inconsistent on B2 until next
  edited; the canonical source (`data-schemas` + this ADR) is unambiguous in the
  meantime, mirroring how B4 deferred its `game/CLAUDE.md` cleanup.
- The `architecture` §1 rename touches a few cross-references; done in this change.

### Neutral / Follow-on work

- Edit `architecture` §1: rename the UI WorldMap scene/controller and add the
  path-shorthand note (done alongside this ADR).
- Edit `game/CLAUDE.md`: tile size → 32×32 (done alongside this ADR). The orphaned
  `biome_definitions.json` row (retired by [ADR 0007](0007-patch-derivation-biome-compatibility.md))
  is still pending its own cleanup and is left as previously noted.
- When `game-design-overview` is next touched, delete the per-species-file line.
