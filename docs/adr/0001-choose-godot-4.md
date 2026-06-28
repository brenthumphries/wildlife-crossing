---
title: "0001 — Choose Godot 4 + GDScript"
date: 2026-06-17
status: accepted
---

## Context

Wildlife Crossing is a single-player, offline, top-down 2D management simulation
targeting desktop (Mac, Windows, Linux). It needs a tile-based world, a custom
simulation tick, pixel-art rendering in a Stardew-register palette, and a data
layer loaded from JSON. The team is small and the project is open-ended; build
and iteration speed matter more than raw performance headroom. The simulation is
modest in scale (one sub-area's worth of tiles and animals active at a time), so
an engine optimised for AAA 3D is unnecessary.

Candidate engines considered: Godot 4, Unity, and a bespoke engine on a 2D
framework (e.g. MonoGame/libGDX).

## Decision

Use **Godot 4 with GDScript** as the sole engine and language for the game.
GDScript's tight editor integration, scene/node model, signal system, and
first-class 2D tilemap support match the game's needs with the least friction,
and Godot's permissive MIT licence and small export footprint suit a desktop
indie title.

## Consequences

### Positive

- Native 2D tilemap, `TileSet`, and `Camera2D` support cover the world map and
  continuous-zoom selection interface without third-party plugins.
- Built-in signal system directly supports the project's "signals over direct
  references" convention (see [`EventBus`](../architecture.md)).
- GUT (Godot Unit Testing) gives a mature, CI-runnable test framework — the
  project's mandated test tooling.
- Single language (GDScript) keeps the codebase consistent; no C#/GDScript
  interop boundary.

### Negative / Trade-offs

- GDScript is dynamically typed by default; the project mitigates this by
  requiring static type hints in conventions, but type safety is weaker than C#.
- Godot 4's GDScript is less performant than C# for heavy numeric loops. The
  simulation design avoids per-frame heavy work (connectivity recomputes are
  event-driven, not per-frame) specifically to stay within this budget. See
  [`0004-connectivity-patch-adjacency-graph`](0004-connectivity-patch-adjacency-graph.md).

### Neutral / Follow-on work

- If a future system needs heavy computation (e.g. continental-scale pathfinding
  for the capstone milestone), revisit with a targeted GDExtension/C# module
  rather than switching engines.
