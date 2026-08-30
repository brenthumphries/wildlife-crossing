---
title: "Answered — will animals use a crossing, or walk around it?"
date: 2026-07-19
measured: 2026-08-10
tags: [design, system, simulation, pathfinding, decision]
status: active
---

> **Answered 2026-08-10** by measurement (build-review C4) — see
> [§ Measured](#measured-2026-08-10). Raised 2026-07-19 while defining span
> geometry ([[../../docs/adr/0016-crossing-span-geometry|ADR 0016]]).
>
> **Short answer: in the tutorial, they use it.** No safe detour exists across
> the Bow Valley corridor, baseline mortality is high rather than near-zero, and
> a single well-placed span cuts first-day deaths by ~85% while logging ~200
> traversals. The tutorial demonstrates the mechanic.
>
> **But the measurement found three things nobody was looking for**, one of them
> a defect in the tutorial as shipped: the opening camera points at the stretch
> of highway where no animal ever crosses. See
> [§ What this changes](#what-this-changes).

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

## Measured (2026-08-10)

Measured with `tools/measure_tutorial.gd`, which drives the real `Simulation`,
`Pathfinding` and `InfrastructureManager` headless against the pinned
Godot 4.6.3 binary — no reimplementation of the cost function, so the numbers
are the game's own behaviour rather than a model of it.

**Method.** Paired runs from identical seeds, one with no crossing and one with
a span built before tick 0. Independent runs rather than one run with a
mid-flight build, because death is absorbing here — `Simulation._step_agent`
sets `alive = false` and nothing revives an agent within a run, so measuring
"after" in the same run would compare against a population the baseline had
already thinned. 10 agents per run, mortality 0.20 per hazard step
(`EnvConfig.DEFAULT`), 100 ticks = 1 in-game day.

### Check 1 — is there a safe detour? **No.**

The corridor occupies columns 12–13 across every row of the map. With hazards
priced at infinity there is **no** west→east route at all; at default costs the
route is 35 tiles and crosses the hazard. Bow Valley genuinely bisects, as
`segments.json` claimed. Every single-row span (all 10 rows) satisfies ADR
0016's two-sided-core rule, so the player cannot easily place an *invalid* one.

### Check 2 — is baseline mortality non-zero? **Emphatically.**

Cumulative deaths out of 10 agents, mean of 10 seeds:

| span | t=100 | t=250 | t=500 | t=1000 | t=2000 | crossing uses |
|---|---|---|---|---|---|---|
| none (baseline) | 6.30 | 7.00 | 7.10 | 7.10 | 7.30 | 0 |
| one row (row 2) | 1.20 | 2.90 | 4.10 | 6.00 | 6.70 | 218 |
| whole corridor | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 915 |

**The horizon is the whole story.** At t=100 — one in-game day, about ten real
seconds at 1× — the baseline has killed 6.3 of 10 agents and a single row has
killed 1.2. By t=2000 the two are within noise of each other, because deaths
are absorbing and nothing respawns agents mid-run, so given twenty in-game days
almost every animal eventually crosses somewhere uncovered. A totals-only
measurement would have reported "the crossing achieves nothing" and been
completely wrong about what the player sees.

### Check 3 — does the tutorial demonstrate the mechanic? **Yes, if you build in the right place.**

Deaths in the first in-game day by span position, 5 seeds each:

| span | deaths @ t=100 | reduction | crossing uses |
|---|---|---|---|
| row 0 | 1.00 | 84% | 201 |
| row 1 | 0.80 | 87% | 192 |
| row 2 | 1.40 | 77% | 192 |
| row 3 | 1.40 | 77% | 161 |
| row 4 | 5.00 | 19% | 20 |
| row 5 | 5.60 | 10% | 11 |
| row 6 | 5.20 | 16% | 10 |
| row 7 | 6.80 | — | 0.2 |
| row 8 | 6.80 | — | 0 |
| row 9 | 6.80 | — | 0 |
| rows 3–7 | 0.40 | 94% | 194 |
| whole corridor | 0.00 | 100% | 915 |

Because animals do not cross the corridor evenly. Baseline deaths by row, 10
seeds:

```
row 0  ##########################################  42
row 1  ################                            16
row 2  ############                                12
row 3  ##                                           2
row 4  #                                            1
rows 5-9                                             0
```

**70 of 73 deaths happen on rows 0–2.** A span there is worth ~85%; a span on
rows 7–9 is a valid, fully-priced structure that is used **zero** times and
saves nobody. This is exactly the third resolution below — "a segment where
animals already route around is a *bad* place to build" — occurring not between
segments but *within* one.

Worth noting for anyone reading the geometry docs: **ADR 0016's own worked
minimal example is `[(12,5), (13,5)]` — row 5**, which measures ~10% here. It
is a perfectly correct illustration of the *span rule*, which is what the ADR is
about, and it is also the span a developer reaching for a canonical example
would copy. `simulation_test.gd` and `infrastructure_manager_test.gd` both use
it, correctly, to test geometry rather than efficacy.

## What this changes

Three findings the question did not ask for. None blocks v0.1.0; the first is
close.

1. **The tutorial's opening camera points at the dead zone.**
   `main.gd:18` sets `CAMERA_FOCUS_COORD = Vector2i(13, 6)` — row 6, where
   **no animal has ever died** across 10 seeded runs and a span logs ~10 uses
   against row 1's ~192. The player's first view of the game frames the one
   stretch of highway where building does least. Moving the focus to row 1 or 2
   is a one-line change; it is a *design* call about first impressions, so it is
   flagged rather than made.

2. **Rendered agents never respawn.** `_spawn_agents()` runs once in
   `load_world`; `_step_agent` sets `alive = false` permanently. `PopulationModel`
   keeps demographic counts and its monthly step recovers them, but nothing ever
   re-derives agents from those counts. So the visible world empties out over
   ~20 in-game days no matter what the player builds, and the crossing's benefit
   decays to zero *in the measurement* for a reason that has nothing to do with
   crossings. Phase 1 deliberately separated observable agents from demographic
   counts (ADR 0009); re-seeding agents from recovered counts is the missing
   other half.

3. **Baseline mortality is harsh for a game whose north star is "cozy, not
   stressful".** 63% of the visible animals die in the first in-game day, before
   the player can plausibly have built anything. That is a tone question, not a
   correctness one — the mechanic is *legible* precisely because the toll is
   obvious — but it is worth deciding deliberately rather than inheriting from
   `EnvConfig.DEFAULT = 0.20`.

The measured answer also strengthens the case for the third resolution below:
usage varies enormously *within* a single corridor, so a connectivity overlay
that showed expected usage would be telling the player something real, not
approximating it.

## Possible resolutions, if it turns out to be a problem

Written 2026-07-19, before the measurement. Options 1 and 2 turn out not to be
needed for Bow Valley — it already bisects, and the detour is already
impossible. Option 3 is the one the data supports, and now has evidence behind
it. Left as written, since the option space is still the right one for the
other 17 segments, which do *not* bisect and have never been measured.

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

## Still open

The measurement covered **Bow Valley only** — the tutorial, and one of the two
segments that bisects. The original question was raised about the *other 17*,
where a safe detour does exist and baseline mortality may well be ~0. Nothing
here says anything about them. `tools/measure_tutorial.gd` is written against
one segment id and would need generalising to sweep the rest; that is the
natural follow-on, and it matters at Phase 5 when other sub-areas unlock, not
for v0.1.0 (which ships Bow Valley alone).

## Related

- `tools/measure_tutorial.gd` — the measurement, re-runnable
- [[../../docs/adr/0016-crossing-span-geometry|ADR 0016]] — span geometry (this
  question is its main open follow-on)
- [[segment-vs-span-defect]] — the defect that surfaced it
- [[../../docs/simulation-design|simulation-design]] — the pathfinding cost
  function this hinges on
- [[crossing-location-selection]] — where "is this a good place to build?" would
  surface
