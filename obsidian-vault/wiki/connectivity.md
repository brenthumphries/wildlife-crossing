---
title: "Connectivity"
date: 2026-06-17
tags: [wiki, glossary, system]
status: active
---

**Connectivity** is how well habitat [[patch|patches]] are linked into a network
animals can move through safely. Restoring connectivity is the central goal of
Wildlife Crossing.

## In-game

Connectivity is computed on a **patch-adjacency graph** — patches are nodes,
safe links (contiguous habitat or a completed crossing) are edges. It feeds three
things: the **connectivity overlay** (an orange→teal heatmap showing fragmented
vs. well-connected areas), the `connectivity_bonus` term in a patch's habitat
quality, and several governmental [[trust]] metrics. The graph is precomputed per
sub-area and recomputed only when something changes it (a crossing completed, a
season shift), never every frame. A well-placed crossing can raise connectivity
enough to flip a patch into viability and trigger population recovery — the
game's core cascade.

## Real-world basis

**Landscape connectivity** is a central concept in conservation biology: linked
habitat lets animals find food and mates, disperse, and adapt to change, while
fragmentation isolates populations and raises extinction risk. Wildlife crossings
and protected corridors are the primary tools for restoring it — the real mission
of the Yellowstone to Yukon initiative.

## References

- [Wildlife corridor — Wikipedia](https://en.wikipedia.org/wiki/Wildlife_corridor)
- [Landscape connectivity — Wikipedia](https://en.wikipedia.org/wiki/Landscape_connectivity)
- [Yellowstone to Yukon Conservation Initiative](https://y2y.net)

## Related

- [[patch]] · [[segment]] · [[trust]]
