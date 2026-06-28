---
title: "Segment"
date: 2026-06-17
tags: [wiki, glossary, system]
status: active
---

A **segment** is the smallest selectable unit of road or barrier in Wildlife
Crossing — the thing the player chooses when deciding *where* to build a
crossing.

## In-game

A segment is a pre-defined section of roadway or barrier large enough to include
all the tiles where crossing infrastructure will go, plus surrounding space for
fencing and animal-guidance constructs, and small enough that construction
operates without scope ambiguity. **Segment boundaries are fixed in world data
and the player never adjusts them.** Only segments flagged `is_impassable` or
`is_hazardous` are selectable; clicking one opens the confirmation panel with its
label, the current budget, and a one-line connectivity note. Confirming passes
the segment (and its sub-area) straight into the construction step.

## Real-world basis

Real wildlife-crossing projects target specific **road segments** identified as
mortality hotspots or pinch points in animal movement — the same logic the game
uses to make location selection ecologically meaningful rather than arbitrary.

## References

- [Wildlife crossing — Wikipedia](https://en.wikipedia.org/wiki/Wildlife_crossing)
- [ARC Solutions (wildlife crossing design)](https://arc-solutions.org)

## Related

- [[patch]] · [[connectivity]] · [[crossing-location-selection]]
