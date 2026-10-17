---
title: "0021 — World Select Renders the Live World at Segment Zoom"
date: 2026-10-16
status: proposed
---

## Context

Crossing-location selection (`WorldSelectController`, scene
`scenes/ui/WorldSelectMap.tscn`, [ADR 0013](0013-scaffolding-conventions.md))
zooms continuously from a full-Y2Y view into segment mode, which activates at
`SEGMENT_ZOOM_ACTIVATE_PX` = 16 px and releases below
`SEGMENT_ZOOM_DEACTIVATE_PX` = 12 px. Both are measured as on-screen
flat-to-flat tile width ([ADR 0002](0002-hex-grid-topology.md)).

Until now the controller drew an opaque backdrop and a grid of sub-area cards at
every zoom, segment mode included, over the live world that `WorldRenderer`
draws under the player's `Camera2D`. Segment picking (`Main._pick_segment_at_mouse`)
and the connectivity overlay both work in that world space. Picking resolved a
click against a world the player could not see. The 2026-08-06 decision made
the map look-only and stopped its mouse events. The 2026-09-23 decision
(roadmap §Phase 2) then recorded Phase 2's fourth exit criterion as *met in
tests, not reachable in the artifact* until an in-map segment renderer exists,
and noted that the drawn map and the pick path must share one coordinate space.

The question is what draws the map at segment zoom.

## Decision

At segment zoom the world-select controller **drives the existing world camera
and lets the existing `WorldRenderer` show through**. It does not draw a map of
its own. This puts the drawn map, the connectivity overlay and the pick path in
one coordinate space by construction, because there is only one.

Mechanics:

- **One measure.** The controller's `tile_px()` stays the authority for zoom
  and hysteresis. The camera is set so that
  `WorldRenderer.TILE_FLAT_TO_FLAT_PX × camera.zoom == tile_px()`, which makes
  the on-screen tile the player sees the tile the thresholds measure. The
  controller's own 32 px base (art-direction box) and the renderer's 24 px
  placeholder tile can differ without drift, because only the on-screen size
  crosses between them. Both live in the same stretched viewport
  (`canvas_items`), so the stretch scale applies to both equally.
- **No loading step.** `world_reveal()` runs from 0 at 12 px to 1 at 16 px
  across the hysteresis band and is 1 throughout segment mode. The card layer
  draws at `1 − reveal`, so the cards fade as the world comes up. Segment mode
  draws no backdrop and no cards, only an outlined header. A locked sub-area
  is clamped at 12 px and never reveals.
- **The player's camera comes back.** `attach_world_camera(camera, centre_of)`
  follows the `attach()` pattern the overlay and confirm panel already use. The
  camera's framing is saved when the reveal starts and restored exactly when it
  ends: zoom-out, locked focus, Escape, or the confirm hand-off.
- **Overlay above terrain.** `ConnectivityOverlay` stays a world-space
  `Node2D` and takes `z_index = 1`, so it draws over the renderer whatever
  order the two nodes are added in. Because the controller draws nothing over
  the world in segment mode, it does not cover the overlay either.

Mouse presses are still stopped by the controller. Routing them to the pick
path is C25; this decision is what makes that routing correct.

## Rejected alternative

**A separate map renderer with its own projection**: a second drawing of the
segment-level map inside the world-select screen, with its own axial→pixel
transform and its own pan and zoom state. This is the "in-map segment renderer"
as first scoped (build-review C1). Rejected because:

- It creates a second coordinate space. Picking, the overlay and build mode all
  work through `WorldRenderer.px_at_coord`/`coord_at_px` under the world
  camera. A second projection either duplicates that transform or has to be
  kept in lockstep with it. The project has already shipped one bug from two
  frames disagreeing (the 2026-07-19 camera fix and the 2026-08-04 blind
  click), and the 2026-09-23 note names exactly this risk.
- It doubles the work every rendering change needs. Real TileSet art, seasonal
  terrain and hotspot markers would each have to land twice.
- It shows a copy of the world, not the world itself. The design principle "the
  world feels alive" is better served by zooming into the running simulation,
  with animals moving, than into a static map of it.

## Consequences

### Positive

- Phase 2's fourth exit criterion becomes reachable once C25 routes clicks.
  Nothing here needs to change for that.
- The connectivity overlay, hotspot markers and live agents appear in segment
  mode for free, because they already draw in world space.
- A single source of truth for projection remains `WorldRenderer.px_at_coord`.

### Negative / Trade-offs

- Only the **loaded** sub-area exists as a live world. v0.1.0 loads Bow Valley
  only, which is also the only sub-area that starts unlocked, so every
  reachable segment-mode focus is the loaded one. Once a second sub-area can
  be unlocked, focusing it must load its world (or segment mode must refuse it).
  That follow-on belongs to the multi-sub-area work, not this ADR.
- The controller holds a reference to the world camera. This is a deliberate
  exception to "signals over direct references", matching the existing
  `attach()` bindings: the camera is a passive node the controller must set
  synchronously on every zoom step, and an exact restore needs one owner.
- Zoom centres on the focused sub-area, not on the cursor. That is acceptable
  for one sub-area, but cursor-anchored zoom is a likely polish item.

### Neutral / Follow-on work

- C25: route segment-mode clicks to `Main._try_select_segment()` now that the
  coordinate space is shared.
- When the card grid gets real map art, the band crossfade still applies
  unchanged. It fades whatever the card layer draws.
