---
title: "0023 — A 3D Presentation Layer with a Player-Controlled Camera"
date: 2026-11-11
status: proposed
---

## Context

[ADR 0001](0001-choose-godot-4.md) chose Godot 4 for a "top-down 2D management
simulation" and counted native 2D tilemap and `Camera2D` support among its
benefits. The 2D framing was carried into the PRD pillar ("pixel art, top-down
2D"), [`art-direction`](../../obsidian-vault/design/art-direction.md), the
scene tree in [`architecture`](../architecture.md) §3, and the root
`CLAUDE.md`. It was an assumption about the engine, not a requirement of the
game: the product owner believed that choosing Godot limited the game to 2D.
Godot 4 is a full 3D engine, and the pinned 4.6.3 ([ADR 0012](0012-godot-and-gut-version-pin.md))
needs no upgrade to render in 3D.

The question is whether the game should move to 3D with a camera the player
controls, in the Cities: Skylines manner the design already names as its play
reference, and what that would cost. A review of the tree at `f33dfa9` found:

- **The simulation holds no 2D state.** Nothing under
  `game/scripts/systems/` uses `Vector2`, a 2D node, or a pixel measure. World
  data, pathfinding, the connectivity graph, populations, economy, information,
  seasons and saves work in axial hex coordinates `[q, r]`
  ([ADR 0002](0002-hex-grid-topology.md)) and never ask where a tile is drawn.
- **The world view is a placeholder.** `WorldRenderer` (146 lines) draws tiles
  and agents as coloured circles in `_draw()`. `game/assets/tilesets/` is
  empty, and `game/assets/sprites/` holds one cue icon and one map card. The
  eight species portraits are UI art and unaffected. No tileset or animal
  sprite work would be thrown away.
- **The scale is small.** A sub-area is about 26 by 12 hexes (Bow Valley is
  26 by 10), and rendered agents are capped at 8 per species per visible patch
  ([ADR 0009](0009-population-seeding-and-agent-rendering.md)).
- **The view layer is where 2D is baked in.** `WorldRenderer.px_at_coord` and
  `coord_at_px` are the single axial-to-pixel projection. `Main` owns a
  `Camera2D`. `WorldSelectController` (643 lines) measures zoom as on-screen
  flat-to-flat tile width in pixels, with segment mode at 16 px and release at
  12 px (ADR 0002, [ADR 0013](0013-scaffolding-conventions.md),
  [ADR 0021](0021-world-select-renders-the-live-world.md)).
  `ConnectivityOverlay` is a world-space `Node2D`.
- **Seven test files touch the view layer**, about 1,670 of 7,290 test lines,
  the largest being `world_select_controller_test.gd` at 778. The remaining 37
  scripts test systems and UI panels that do not depend on the projection.
- **The world data has no height.** `data/world/<sub_area>.json` carries a
  tile id per cell and nothing else, and `tiles.json` has no elevation field.
- **The project renders with `gl_compatibility`** on all four export presets.

This review read the code and documents. Nothing was prototyped or run, so
camera feel, frame time and headless CI behaviour in 3D are unverified.

> **Amendment 2026-11-11.** Added the Blender toolchain (decision 2), split
> the spike into an engine half and an art half, and restated the art risk.
> Anthropic released an official Blender connector for Claude in April 2026,
> which gives the environment art a production path the first draft did not
> assume. The ADR is still `proposed`.

## Decision

Move the world view to **3D as a presentation layer over the unchanged hex
simulation**, with a player-controlled orbit camera. The simulation stays
authoritative and stays flat: it keeps axial coordinates, the tick model, the
signal map and the save format exactly as they are. Only what draws the world
and what turns a mouse position into a tile changes.

- **One view seam.** A small world-view interface owns three things: the world
  position of a tile, the tile under a screen point, and the framing of a
  sub-area. `Main`, `ConnectivityOverlay`, build mode, the segment picker and
  `WorldSelectController` call it and nothing else. It replaces
  `px_at_coord` / `coord_at_px` as the single source of truth, and it is
  introduced in 2D first so the existing suite proves the seam before any 3D
  code lands.
- **A 3D renderer.** `Game` and `World` become `Node3D`. Tiles are hex prisms
  drawn through `MultiMeshInstance3D`, coloured by the existing
  `tile_color` rules until real art exists. A crossing is a real structure
  spanning its tiles. Agents keep ADR 0009's representative pool and
  [ADR 0015](0015-ecosystem-overpass-fallback-animal-scene.md)'s rule of no
  physics, moving by tick with render interpolation.
- **Camera.** A pivot on the ground plane with a `Camera3D` on a boom. The
  player can pan (drag, arrow keys, edge scroll), zoom (wheel, trackpad scroll,
  pinch), rotate about the vertical axis, and tilt within a clamped range that
  never reaches the horizon or goes below the terrain. The pivot is bounded to
  the loaded sub-area. Limits are named constants in
  `simulation_constants.gd`, tuned by a windowed walk.
- **Picking.** A ray from the camera through the cursor, intersected with the
  terrain, resolved to an axial coordinate. No physics bodies are added for
  it.
- **Zoom thresholds.** The segment-mode thresholds stay a measure of how large
  a tile reads on screen, taken at the camera's focus point, so the PRD's
  continuous zoom and hysteresis survive. Their values are re-tuned, since a
  perspective view has no single tile size.
- **Elevation is added as view data.** World files gain an optional
  per-cell `elevation`, defaulting to 0, with a `data_version` bump on the
  world files and no `save_version` change, because static data is never
  saved ([ADR 0005](0005-save-file-format.md), [ADR 0014](0014-gamestate-serialization-shape.md)).
  The simulation does not read it. Whether elevation should ever affect
  movement cost or habitat is a separate decision.
- **UI stays 2D.** The HUD, panels, calendar, world-select cards and both
  minigames are `Control` nodes on a `CanvasLayer` and draw over a 3D world
  unchanged.
- **Sequencing.** v0.2.0 is cut as the last 2D release, so the pending windowed
  walks are not spent on a view about to be replaced. The 3D renderer is built
  behind a launch flag beside the 2D one, and the 2D renderer is removed only
  when 3D reaches parity. The 3D view ships as v0.3.0, a MINOR bump, since no
  save changes.

### Decisions this ADR needs before it can be accepted

These are the product owner's calls. Each has a proposed default.

1. **Art style.** Proposed: low-poly 3D terrain and structures with
   **billboarded pixel-art sprites for animals**. It keeps the Stardew register
   and the current sprite pipeline for the species, and avoids the need for
   eight rigged, animated 3D models. The alternatives for animals are low-poly
   models from permissively licensed packs (subject to the
   `THIRD-PARTY-NOTICES.md` rule), AI-generated meshes that would still need
   rigging and a licence check, or commissioned models.
2. **Art toolchain.** Proposed: **Blender, driven by Claude through the
   official Blender connector**, as the production path for terrain tiles,
   crossings, barriers and props. The connector lets Claude read the scene, run
   Python inside the running Blender and take viewport screenshots to check its
   work. Assets are generated by script, so a tile set stays consistent and can
   be regenerated when the palette or proportions change, and are exported as
   glTF for Godot. Blender is free, so this adds a tool and no subscription.
   It is expected to suit hard-surface and procedural geometry and to be weak
   at organic character work, which is why animals stay sprites under decision
   1. This expectation is untested on this project; the spike in decision 4 is
   the test.
3. **Renderer.** Proposed: run the spike on `gl_compatibility` as configured
   and decide after seeing it. Moving to the Mobile or Forward+ renderer buys
   better lighting and shadows and changes CI and every export preset.
4. **Go or no-go after a spike.** Proposed: a two-part spike, judged together
   before any of the migration is routed. The **engine half** is a throwaway
   branch that renders Bow Valley as hex prisms under the orbit camera with
   the live simulation running, walked windowed on the Mac. The **art half**
   is a Blender session in which Claude builds three terrain tiles, one
   overpass and one animal attempt, exported to glTF and loaded into the
   engine half. The animal attempt is there to confirm or overturn decision 1,
   not because it is expected to ship.

## Consequences

### Positive

- The camera matches the game's stated play reference, and the subject suits
  it: overpasses are three-dimensional structures, the setting is mountain
  terrain, and three launch species are elevational migrants.
- No simulation system, data loader, save or system test changes. Existing
  saves load unchanged.
- The cost lands at the cheapest moment the project will have: before any
  tileset or animal sprite has been produced.
- The seam removes the direct calls into `WorldRenderer`'s projection that ADR
  0021 had to work around, whichever renderer sits behind it.
- Seasonal mood becomes a lighting and environment change with one shader
  instead of per-tile seasonal variants (art-direction §8).

### Negative / Trade-offs

- **Art is still the largest cost, with the risk concentrated in the
  animals.** Every one of the 18 tile types needs a 3D treatment, crossings
  need models, and the art direction's per-asset list (pixel dimensions, 32 by
  32 hex box) is rewritten. If the Blender path in decision 2 holds up in the
  spike, the environment has a production path and its risk is moderate. The
  animals do not: with billboarded sprites the species work stays close to
  what was planned, and without them the project needs rigged, animated
  quadrupeds that no tool it has is expected to produce well.
- **The Blender path has its own costs.** It runs only on the Mac with Blender
  open, so it cannot be dispatched to the cloud or driven from a phone. Each
  viewport screenshot is an image upload, and asset iteration uses many, so it
  draws on the token budget. The Python the connector runs is not sandboxed.
  Whether the result looks warm and cozy is still judged by the product owner,
  one screenshot round at a time.
- `WorldSelectController` and its 778-line test are substantially rewritten,
  with `ConnectivityOverlay`, the build preview, the segment hover and the
  hotspot rings ported to 3D. About 1,670 test lines are rewritten or
  replaced.
- Rotation and tilt add states the 2D view never had: occlusion of tiles
  behind terrain, picking at shallow angles, and legibility of the orange to
  teal overlay under lighting. Each needs a rule and a test.
- A flat board in 3D adds little. The benefit depends on elevation being
  authored for every playable sub-area, which is new content work.
- Rendering tests that need a GPU may not run in headless CI. The view seam
  keeps projection and picking testable as pure functions, but visual
  correctness moves further onto windowed walks, which are already the
  bottleneck.
- Two renderers exist for the length of the migration.

### Neutral / Follow-on work

High-level migration plan, sized as in `docs/plan/week.json`:

| # | Step | Lane | Size |
|---|---|---|---|
| 1 | Cut v0.2.0 as the last 2D release | mac | L (already planned as B9) |
| 2 | Engine spike: Bow Valley in 3D with the orbit camera, on a throwaway branch | code | S |
| 3 | Art spike: install Blender and the connector; Claude builds three tiles, one overpass and one animal attempt; load them into the engine spike | mac | S |
| 4 | Walk both spikes; decide art style, toolchain, renderer, go or no-go; accept or reject this ADR | decision | S |
| 5 | View seam in 2D, suite green | code | M |
| 6 | 3D renderer, camera rig and ray picking behind a flag | code | L |
| 7 | Port build preview, segment hover, hotspots, connectivity overlay and world-select zoom | code | L |
| 8 | Elevation field, schema and loader; author Bow Valley heights | code + content | M |
| 9 | Environment art through the Blender path; animal sprites; lighting and seasonal grade | mac + mixed | L |
| 10 | Amend docs; remove the 2D renderer; release v0.3.0 | mixed | M |

On acceptance, these documents are amended to point here:

- [ADR 0001](0001-choose-godot-4.md): the 2D framing in Context and the
  tilemap and `Camera2D` benefit.
- [ADR 0002](0002-hex-grid-topology.md) and [ADR 0013](0013-scaffolding-conventions.md):
  the flat-to-flat pixel measure and the 32 by 32 tile box.
- [ADR 0006](0006-world-map-authoring.md): the generated `TileMapLayer` set,
  and the new `elevation` field.
- [ADR 0021](0021-world-select-renders-the-live-world.md): the camera hand-off,
  restated for a `Camera3D` rig.
- [`architecture`](../architecture.md) §3 (scene tree) and
  [`data-schemas`](../data-schemas.md) (world files).
- `game/CLAUDE.md` asset pipeline: Blender sources (`.blend` and the
  generating scripts) kept in a sibling `_src/` beside the exported glTF, as
  the Aseprite rule already does for sprites.
- `THIRD-PARTY-NOTICES.md`: no entry is expected for Blender itself, since it
  is a tool and is not shipped, but that is to be confirmed against its
  licence when the toolchain is adopted, per the rule against stating licence
  terms from memory. Any imported asset library or generated mesh needs its
  own entry.
- `art-direction`, `ui-ux-spec` §2 (input map gains rotate and tilt), the PRD
  pillar in `game-design-overview`, the root and `game/` `CLAUDE.md` files,
  and the website copy.

### Rejected alternatives

**Stay 2D and add a free pan and zoom camera.** This is the smallest change and
keeps every document as written. It was not proposed because it does not
answer the question asked: it gives the player no rotation, no tilt and no
terrain relief, which are what a 3D camera is for.

**Rebuild the simulation in 3D** (3D positions, physics or navigation meshes
for animal movement). Rejected because it discards the deterministic tick
model, the hex pathfinding and 688 passing tests to gain nothing the player
would see that a 3D view over the same simulation does not already give.

**Migrate now, before v0.2.0.** Rejected because v0.2.0 is feature-complete
and waiting only on windowed walks. Replacing the view first would void those
walks and leave the project without a release between v0.1.0 and the end of
the migration.
