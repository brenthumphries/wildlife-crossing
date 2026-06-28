---
title: "0002 — Hex-Grid Map Topology"
date: 2026-06-17
status: accepted
---

## Context

The world is a tile map across which animals pathfind around and through
barriers. An early open question in
[`wildlife-overpass-crossing`](../../obsidian-vault/prd/wildlife-overpass-crossing.md)
asked how pathfinding should handle *diagonal* crossing attempts: on a square
grid, an animal at a corner can be ambiguously "adjacent" to a barrier tile
across a diagonal, making it unclear whether a crossing structure is required to
pass and which tile the animal actually traverses. This ambiguity complicates
both mortality checks and overpass-span validation.

The consolidated PRD resolved the question by adopting a hex grid. This ADR
records that decision and its structural consequences.

## Decision

Use a **hexagonal tile grid with 6-directional connectivity**. Every tile has
exactly six direct neighbours and no diagonal relationships exist. An animal
moving between two tiles always crosses exactly one shared edge, so crossing
choice is always unambiguous: to leave a tile, an animal must enter one of its
six neighbours, each of which is safe terrain, a hazard, or a crossing.

Hex tile size is measured as **flat-to-flat width** (the shorter axis); this is
the metric used by the segment-zoom threshold constant.

## Consequences

### Positive

- Eliminates diagonal-adjacency ambiguity in pathfinding, mortality checks, and
  overpass-span completeness validation.
- Six-way movement produces more natural-looking animal paths than 4-way square
  movement without the diagonal-cost complications of 8-way movement.
- Edge-based adjacency makes "every cell of dangerous terrain must be spanned" a
  clean graph property: a span is complete iff every hazardous/impassable tile on
  the segment has overpass coverage and the resulting sub-graph is connected.

### Negative / Trade-offs

- Hex math (axial/cube coordinates, neighbour offsets, pixel conversion) is more
  complex than square-grid indexing; this is encapsulated in a `HexGrid` utility.
- Pixel-art tilesets must be authored for hex tiles; tile dimensions and the
  16×16-at-1× asset convention are interpreted as the hex bounding box. The art
  direction document finalises exact hex dimensions.
- Edge penalty in the habitat-quality formula uses 6 edges per tile (not 4);
  `habitat_constants.gd` weights are tuned accordingly.

### Neutral / Follow-on work

- Standardise on axial coordinates internally with cube coordinates for distance
  math; document the convention in the `HexGrid` utility.
