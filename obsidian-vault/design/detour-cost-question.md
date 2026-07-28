---
title: "Open question — will animals use a crossing, or walk around it?"
date: 2026-07-19
tags: [design, system, simulation, pathfinding]
status: draft
---

> **Unresolved.** Raised 2026-07-19 while defining span geometry
> ([[../../docs/adr/0016-crossing-span-geometry|ADR 0016]]). It does not block
> that definition, but it determines whether a correctly-built span changes
> anything the player can see.

## The question

**If an animal can walk around the end of a road instead of crossing it, will it
ever use the crossing the player built?**

If detouring is cheaper than the mortality-weighted cost of crossing, the answer
is no — and the player watches a 10,000-budget structure sit unused while animals
stream around the end of the highway. That would read as the game being broken,
even though every system is behaving as specified.

## Why it came up

Authored corridors mostly do not reach the edges of their maps. Of the 19
segments in `segments.json`, only **2** cut their sub-area into two regions when
their tiles are removed:

- `s7_trans_canada_bow_a` (Bow Valley — the tutorial)
- `s8_bc97_pine_pass_a`

The other 17 stop short, leaving a gap at one or both ends that an animal can
walk through without ever entering a hazardous tile.

## Why this is not automatically a bug

Hazardous tiles are **passable with risk**, not walls. Every segment in the game
is currently `is_hazardous` (roads and rivers); none are `is_impassable`. So a
road is *designed* to be crossable-but-deadly. A corridor that does not fully
separate the map is not malformed — it is a hazard that animals may choose to
take or avoid.

The question is therefore about **pathfinding costs**, not about map topology:

- If the detour is long and the hazard is short, animals cross, die at the
  configured rate, and a crossing visibly rescues them. The design works.
- If the detour is short, animals rationally avoid the hazard already, mortality
  is near zero before the player does anything, and the crossing adds nothing.

## What needs checking

1. **Measure the actual trade-off.** For each segment, compare the shortest safe
   detour path against the shortest hazard-crossing path under the real
   pathfinding cost function, including the per-species
   `preferred_crossing_type` modifier (0.6 for a matching type).
2. **Measure baseline mortality per segment.** If animals already avoid a road
   because going around is cheap, deaths there will be ~0 in an unmodified run.
   Near-zero baseline mortality is the tell.
3. **Check the tutorial specifically.** Bow Valley is one of the two segments
   that *does* separate its map, so the tutorial should demonstrate the mechanic
   correctly regardless of how this resolves. Worth confirming rather than
   assuming — it is the first thing any player sees.

## Possible resolutions, if it turns out to be a problem

Not yet evaluated; listed so the option space is on record.

- **Extend corridors to the map edge** in the world data, so crossing is
  unavoidable. Simplest, but makes every sub-area a bisected rectangle, which is
  ecologically crude and visually repetitive.
- **Raise detour cost** by making the terrain at corridor ends genuinely
  expensive (steep, unsuitable) rather than blocking it. Keeps maps naturalistic;
  needs per-map authoring care.
- **Accept it and let it vary by segment.** Some real crossings sit on pinch
  points and some do not; a segment where animals already route around is a
  *bad* place to build, and revealing that could be a legitimate part of the
  location-selection skill. This would make it a feature of
  [[crossing-location-selection]] rather than a defect — but only if the game
  tells the player *before* they spend the budget.

The third option is the most interesting and the most work: it implies the
connectivity overlay should show expected *usage*, not just fragmentation.

## Related

- [[../../docs/adr/0016-crossing-span-geometry|ADR 0016]] — span geometry (this
  question is its main open follow-on)
- [[segment-vs-span-defect]] — the defect that surfaced it
- [[../../docs/simulation-design|simulation-design]] — the pathfinding cost
  function this hinges on
- [[crossing-location-selection]] — where "is this a good place to build?" would
  surface
