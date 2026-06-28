---
title: "0004 — Connectivity via Patch-Adjacency Graph"
date: 2026-06-17
status: accepted
---

## Context

The connectivity overlay, the habitat-quality `connectivity_bonus`, and several
trust metrics all depend on "how well connected is this habitat?". The map can
contain thousands of tiles per sub-area, and the overlay renders during active,
zoomed selection. Computing connectivity at tile granularity every frame would
blow the performance budget. [`crossing-location-selection`](../../obsidian-vault/prd/crossing-location-selection.md)
resolved that connectivity must be precomputed and incrementally updated, never
per-frame.

Options considered:

1. **Per-tile flood fill on demand** — simple, but recomputes far too much and
   couples cost to zoom/pan.
2. **Patch-adjacency graph** — collapse each contiguous habitat patch into a
   single node; edges are safe links (contiguous habitat or a completed crossing)
   between patches. Connectivity is then a graph query over a few dozen nodes.

## Decision

Model connectivity as a **patch-adjacency graph**: nodes are habitat patches
(maximal contiguous zones of ecologically compatible terrain), edges are safe
links between patches (direct habitat contiguity, or a completed same-type
crossing chain). The graph is built per sub-area at load and **incrementally
recomputed only on graph-changing events** — `crossing_completed` and
`season_changed` — never per frame. The overlay, habitat-quality recompute, and
trust metrics all read cached values from this graph.

## Consequences

### Positive

- Connectivity queries operate over tens of nodes, not thousands of tiles —
  cheap enough to recompute synchronously on the rare graph-changing events.
- A single source of truth feeds the overlay, habitat quality, and permissions,
  so they can never disagree.
- Establishes the performance budget cited in
  [`architecture`](../architecture.md): recompute is O(patches + links) per
  event, bounded per sub-area, and amortised to ~zero per frame.

### Negative / Trade-offs

- Requires maintaining patch identity as terrain/seasonal state changes (e.g. a
  frozen river temporarily merging two patches). Patch re-derivation on
  `season_changed` is the most expensive event and is budgeted explicitly.
- The overlay's per-tile heatmap is a *rendering* interpolation of per-patch
  values, so very fine spatial detail within a patch is not represented — an
  acceptable trade for the cozy, qualitative overlay.

### Neutral / Follow-on work

- The capstone "Continental Connection" check is a reachability query across the
  union of all sub-area graphs; it reuses this structure. See
  [`simulation-design`](../simulation-design.md).
