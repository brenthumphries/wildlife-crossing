---
title: "PRD — Game Design Overview"
date: 2026-06-05
tags: [prd, design, system]
status: draft
---

## Purpose of this document

This document describes the full shape of Wildlife Crossing as a game: the
player experience it aims to create, the systems that produce it, and how those
systems interact. It is the anchor reference for all feature PRDs. When a
feature decision is unclear, this document should clarify whether it is
consistent with the game's intent.

---

## Vision

Wildlife Crossing is a cozy management simulation about ecological restoration.
The player is a coordinator for a fictional non-profit conservation initiative
modeled on real corridor-conservation organizations. They identify fragmented
habitat across the Yukon to Yellowstone (Y2Y) corridor, secure funding and
permissions, and build crossing infrastructure that reconnects animal
populations across human-altered landscapes.

The aesthetic is warm and naturalistic: pixel art, top-down 2D, in the visual
register of Stardew Valley, with the systemic depth of Cities: Skylines. The
emotional tone is hopeful. There are no fail states that punish harshly;
setbacks feel like interesting problems, not disasters.

The game is also an educational tool. Species, ecosystems, and environmental
mechanics are grounded in real-world ecology. A player who finishes a session
should know something true about how habitat fragmentation works, why crossings
matter, and who stewards this landscape.

**Platform and stack:** Godot 4, GDScript, desktop (Mac, Windows, Linux),
single-player, offline. Testing via GUT. All conventions in the root CLAUDE.md
apply.

---

## Design pillars

These four principles govern every design and implementation decision. When
options conflict, these are the tiebreakers.

1. **Ecological accuracy matters.** Species behaviour, habitat connectivity, and
   the effects of infrastructure on wildlife are modelled on real science. The
   game is not a nature documentary, but it should not contradict one either.

2. **Cozy, not stressful.** No punishing fail states. Setbacks — a crossing that
   doesn't attract animals, a budget that runs low — should feel like interesting
   challenges to solve, not reasons to quit. The player is always making progress.

3. **Emergent complexity.** Simple rules produce rich, surprising outcomes.
   Seasons shift which species are present; information purchases change which
   locations look attractive; a single well-placed crossing can cascade into
   population recovery. Prefer systems that interact over features that are
   isolated.

4. **The world feels alive.** Animals behave. Seasons change. Populations respond
   to what the player builds. The landscape is not a static backdrop — it is the
   subject.

---

## Core gameplay loop

The player repeats a cycle with increasing scope and complexity as they progress:

1. **Survey.** Examine the map; optionally purchase habitat, population, or
   corridor data to clarify where fragmentation is worst.

2. **Select.** Choose a crossing location via the location selection interface
   (see [[crossing-location-selection]]): zoom from the Y2Y world map into an
   unlocked sub-area, down to an individual road or barrier segment. Locked
   sub-areas are visible but inaccessible until unlocked.

3. **Build.** Construct a crossing at the selected segment, spending budget (see
   [[wildlife-overpass-crossing]] for the current crossing type).

4. **Observe.** Animals begin using the crossing; population connectivity
   improves; the simulation visibly responds.

5. **Earn.** Effective crossings inspire donations, replenishing and growing the
   budget.

6. **Unlock.** Demonstrated ecological impact earns the trust of governmental
   entities and First Nations partners, opening new sub-areas (see
   [[governmental-permissions]]).

The loop is open-ended. There is no forced endpoint; optional corridor
milestones (see Player progression) provide long-term goals without closing the
sandbox.

---

## Systems

The game world is the full Yukon to Yellowstone (Y2Y) corridor: ~1.3 million km²
of connected mountain landscape spanning five U.S. states (Wyoming, Montana,
Idaho, and the fringe extents of Washington and Oregon), two Canadian provinces
(British Columbia, Alberta), two territories (Yukon, Northwest Territories), and
the traditional territories of more than 75 Indigenous peoples. Y2Y is the full
extent of the game's map — there is no larger world. Within it, the world is
divided into **12 sub-areas** of roughly equal *playable* size that serve as the
unit of geographic navigation and governmental permission. Sub-area boundaries,
names, and count are defined in [[sub-areas]].

### Habitat and zoning

The map is composed of tiles with terrain types. Habitats are contiguous zones
of ecologically compatible terrain (forest, wetland, grassland, etc.) that
support specific species. The player does not create habitat directly — natural
habitat already exists on the map. Their role is to restore connectivity between
habitat patches that have been fragmented by roads, fences, buildings, and
urban zones.

Habitat quality and patch size affect which species can survive in a zone. A
small, isolated patch cannot sustain a healthy population even if animals are
physically present. The game models this to make connectivity feel meaningful
rather than cosmetic.

**Habitat quality model.** Habitat quality is computed per patch (a contiguous
zone of ecologically compatible terrain) as a 0–100 score from four inputs:

```
quality = clamp(0, 100,
    terrain_base                       # 0–40: mean suitability of the patch's
                                       #        terrain tiles for the patch biome
  + size_factor                        # 0–30: log-scaled patch tile count vs.
                                       #        tunable size references (ADR 0008)
  + connectivity_bonus                 # 0–20: count and quality of safe links
                                       #        (crossings or contiguous habitat)
                                       #        to other patches
  - edge_penalty )                     # 0–25: fraction of patch perimeter edges
                                       #        adjacent to roads, urban zones, or
                                       #        hard barriers. Each hex tile has 6
                                       #        edges; perimeter is the count of
                                       #        exposed edges on the patch boundary.
```

Named constants for all weights live in a single `habitat_constants.gd`; no
magic numbers, and the exact expression for each of the four terms is specified in
[ADR 0008](../../docs/adr/0008-habitat-quality-subformulae.md). Quality recomputes
incrementally on graph-changing events (crossing completed, season change), never
per frame.

**Surfacing to the player:** quality renders as a four-band qualitative label —
Poor / Fair / Good / Excellent — in the patch-inspect panel and as the
connectivity overlay's data source. Exact numeric scores are revealed only after
the player purchases a habitat assessment for that area, preserving the
information-uncertainty loop.

**Population viability:** a species cannot sustain a population unless the
connected network of habitat it can occupy meets that species'
`min_viable_patch_size` — counted over network tiles whose biome is in the
species' habitat set, not the patch alone. Below that threshold, populations
decline slowly until a crossing (or contiguous habitat) connects them into a
larger network. Patches themselves are biome-based and species-agnostic; viability
is species-relative ([ADR 0007](../../docs/adr/0007-patch-derivation-biome-compatibility.md)).
This makes connectivity mechanical, not cosmetic.

---

### Species and animal simulation

Multiple species are present on the map simultaneously. Each species has:

- **Habitat preferences** — which terrain types it inhabits and what patch size
  it requires to sustain a population.
- **Movement behaviour** — how far individuals range, how they respond to
  barriers, and how readily they cross hazardous terrain without a crossing.
- **Crossing preference** — which crossing type the species is most likely to
  use. Animals are more likely to use their preferred crossing type but are not
  exclusively restricted to it.
- **Seasonal patterns** — whether the species migrates, hibernates, or shifts
  its range with the seasons, and what drives it to do so.

Animals navigate the map in simulation. They pathfind around or across barriers.
Crossing hazardous terrain without a crossing carries a per-step mortality risk.
Crossing via a constructed crossing carries zero mortality risk.

Population health in each habitat patch is tracked. A crossing that successfully
reconnects two patches will, over time, produce observable population recovery —
animals moving freely, counts rising, range expanding. This is the core
emotional payoff of building well.

#### Launch roster

Eight species at launch, chosen for ecological accuracy in Y2Y and for
mechanical variety:

| Species | Habitat | Range | Crossing preference | Seasonal pattern | Status weight |
|---------|---------|-------|--------------------|------------------|---------------|
| Grizzly bear | Forest, alpine meadow | Very large | Overpass | Hibernates (winter absent) | Vulnerable ×2 |
| Elk | Grassland, forest edge | Large | Overpass | Strong seasonal migration | Common ×1 |
| Pronghorn | Grassland, sagebrush | Large | Overpass (will not use underpasses) | Strong seasonal migration | Common ×1 |
| Mountain caribou | Old-growth forest, alpine | Very large | Corridor | Elevational migration | Endangered ×3 |
| Wolverine | Alpine, subalpine | Very large | Corridor | Active all year | Vulnerable ×2 |
| Gray wolf | All forest, grassland | Very large | Underpass | Active all year | Common ×1 |
| Canada lynx | Boreal forest | Medium | Underpass | Active all year | Vulnerable ×2 |
| Bighorn sheep | Cliffs, alpine grassland | Medium | Overpass | Elevational migration | Vulnerable ×2 |

Status weights feed the donation formula. In v1 only overpasses exist, so
species preferring underpasses and corridors cross less frequently — by design,
this makes some species harder to support until later crossing types ship.

All species definitions live in a single `game/data/species_stats.json` array
([ADR 0013](../../docs/adr/0013-scaffolding-conventions.md)); each entry has fields:
`id`, `display_name`, `habitat_terrains[]`, `min_viable_patch_size`,
`range_tiles`, `preferred_crossing_type` (`overpass` | `underpass` |
`corridor`), `seasonal_pattern`, `status_weight`, `sprite_set`.

#### Movement and mortality

- Pathfinding uses the **hex grid's 6-directional** connectivity — each tile has
  exactly six direct neighbours and no diagonal relationships exist. Because every
  inter-tile edge is a direct connection, crossing choice is always unambiguous:
  an animal must pass through one of its six neighbouring tiles, each of which is
  either safe terrain, a hazard, or a crossing (see [[wildlife-overpass-crossing]]).
- Each step onto an uncovered hazardous tile triggers the per-terrain mortality
  check. Death removes the animal from simulation immediately.
- Crossing via constructed infrastructure carries zero mortality.
- Pathfinding cost for a crossing matching the species' preferred type is lower
  (more attractive) than for non-preferred types; preference affects
  probability, never hard eligibility.

#### Population model

Population health is tracked per patch per species: count, trend, and
connectivity status. A crossing that reconnects two patches produces observable
recovery — rising counts, range expansion, animals visibly moving. Recovery
milestones (e.g. "caribou population doubled") fire events consumed by the
donation and permission systems.

---

### Crossings and infrastructure

Crossings are the player's primary build action. They span dangerous terrain
(roads, fences, rivers) and give animals a safe traversal route.

In v1, the only crossing type is the overpass (see [[wildlife-overpass-crossing]]).
Future types — underpass, corridor — will be specced separately. The data model
is designed to support new types without structural changes.

Crossings must physically span every cell of dangerous terrain to be traversable.
A partial crossing does not create a safe route.

Different crossing types attract different species based on preference. As more
crossing types become available, the player must think about which type serves
the species present at a given location, not just whether a crossing exists.

---

### Economy and budget

The player operates with a budget of in-game currency representing funding for
ecological restoration work. Budget is spent to build crossings and buy
information, and replenished through donations.

**Starting budget and deadlock safety.** The player starts with **50,000**
funds. Budget management should feel enabling: there should usually be a crossing
the player can afford, and scarcity should produce interesting prioritization
decisions, not stalls. If the player's budget falls below the cheapest possible
action, a small unconditional "community fundraising" trickle (500/month)
guarantees the game never deadlocks — consistent with the cozy pillar.

**Crossing cost.** Crossings cost budget — **5,000 per overpass tile** (a
three-tile road span costs 15,000). Constants live in `economy_constants.gd` and
are tunable without code changes. See [[wildlife-overpass-crossing]].

**Donations** are the primary income mechanism, arriving monthly (in-game). When
a crossing successfully connects habitat and enables populations to recover,
donors respond; high usage, endangered species, and badly fragmented locations
pay best. Monthly income:

```
income = BASE_GRANT                              # 1,000 — unconditional
       + Σ over crossings:
           crossings_this_month                  # animals safely crossed
         × mean_status_weight                    # ×1 common / ×2 vulnerable / ×3 endangered
         × fragmentation_multiplier              # 1.0–2.0, from the pre-crossing
                                                 # connectivity deficit of the link
       + milestone_bonuses                       # one-time: population recovery
                                                 # events, first-crossing-in-sub-area,
                                                 # species diversity thresholds
```

All constants in `economy_constants.gd`. The formula directly implements the
design intent: building thoughtfully visibly outperforms building randomly.

**Information purchases** are an optional budget expenditure (detailed under
Information and uncertainty, below). They reduce uncertainty in location
selection and are most valuable early in a new area where the player lacks
visibility.

---

### Seasons and time

**Pacing.** One in-game year = four seasons; **one season = 15 minutes at 1×
speed** (one in-game day ≈ 10 seconds). A full year is one hour of play. Time
controls are pause, 1×, 2×, and 4×. Pausing is always available and never
penalized; all build and information actions work while paused.

The four seasons cycle, each affecting the simulation:

- **Animal presence**: Some species migrate seasonally, appearing in some
  habitat patches only at certain times of year.
- **Population motivation**: Migration seasons increase animals' drive to
  cross barriers. A crossing placed before a migration season may see a sharp
  increase in usage as animals actively seek routes.
- **Habitat conditions**: Seasonal changes affect terrain (frozen rivers,
  flooded wetlands) in ways that may open or close certain crossing options.

Seasons create a rhythm that makes the world feel alive and gives the player
temporal strategy decisions — building a crossing before a migration season
maximises its early impact.

---

### Information and uncertainty

**Map fog: geographic clarity, ecological uncertainty.** The terrain map is fully
visible from the start — it represents real, mapped geography, and hiding it
would fight the educational intent. What is uncertain is the *ecological layer*:
without purchases, habitat quality shows only coarse bands, population data shows
"unknown," and mortality hotspots are invisible. Surveying reveals the living
layer of the map rather than the map itself. Locked sub-areas show terrain but no
ecological data at all until unlocked.

The player reduces ecological uncertainty by purchasing information:

| Product | Cost | Reveals |
|---------|------|---------|
| Habitat assessment | 1,000 / area | Numeric habitat quality + patch sizes |
| Population survey | 2,000 / area | Species present, counts, trends |
| Movement corridor study | 3,000 / area | Attempted routes + mortality hotspots |
| Community liaison briefing | 1,500 / entity | Exact permission-progress weights for one governmental entity |

Information is permanent once purchased. It is most valuable when it changes what
the player would build. A
population survey that reveals an unexpected endangered species in an area the
player was considering may redirect their priorities. The information purchase
system creates a light resource decision: spend now to decide better, or save
budget for construction.

---

### Player progression

Progression unlocks access to new sub-areas within the Y2Y world map. The map
contains sub-areas the player cannot initially build in — land controlled by
governmental entities including government agencies, Indigenous communities
(First Nations), and other jurisdictions whose consent is required before any
work proceeds. When consent is granted, the corresponding sub-area unlocks in
the crossing location selection interface and the player can zoom in, evaluate
segments, and begin construction. The mechanics of earning governmental consent
are defined in a separate governmental permissions PRD.

Consent is earned through demonstrated ecological impact. A player who builds
effective crossings, generates population recovery, and shows stewardship of
areas they already control is more persuasive to new landowners. Progression
gates are not arbitrary level-ups; they are earned through the same actions the
player is already taking.

First Nations partnerships in particular should be handled with respect and
ecological grounding. The game should reflect that Indigenous land stewardship
often produces better ecological outcomes than conventional conservation
approaches, and that consent is not a formality to bypass. The cultural and
narrative design of these entities is defined in [[cultural-narrative-design]];
the unlock mechanics are in [[governmental-permissions]].

**Win condition: open-ended sandbox with optional milestone goals.** There is no
forced end state. A "Corridor Milestones" track provides long-term structure:

- Per-sub-area milestones: first crossing, all priority segments addressed, all
  resident species stable.
- The capstone **Continental Connection** milestone: a continuous chain of
  connected habitat from Greater Yellowstone to the Greater Mackenzie Mountains.
  Achieving it plays a celebratory sequence and the game continues.

Milestones are celebrations, not gates; nothing is locked behind the capstone.

---

## How systems interact

The systems are designed to reinforce each other rather than operate in
isolation. Key interactions:

| Cause | Effect |
|---|---|
| Player builds a crossing | Animals pathfind through it; mortality drops on that route |
| Animals successfully cross | Patch connectivity and habitat quality recompute upward |
| Populations recover | Donation income rises; recovery milestones fire |
| Recovery milestones fire | Trust scores rise with entities that value them |
| Season shifts | Migration motivation rises; usage spikes; terrain hazards shift |
| Player buys information | Better placement; higher crossing effectiveness |
| Trust threshold reached | Sub-area unlocks; loop expands in scope |
| First Nations partnership formed | Free corridor data; habitat bonus; placement hints |

The intent is that a player who builds thoughtfully — using information, timing
crossings before migration seasons, prioritising the most fragmented areas —
earns faster access to new land and higher donation income than a player who
builds randomly. Skill is rewarded, but not through punishing the unskilled.

---

## Open questions

- ~~**How is habitat quality computed?**~~
  *Resolved: a per-patch 0–100 formula (terrain base + size + connectivity −
  edge penalty); four qualitative bands (Poor/Fair/Good/Excellent) shown free,
  exact numerics revealed behind a habitat assessment. See Habitat and zoning.*

- ~~**Is the map fogged at game start?**~~
  *Resolved: no terrain fog — "geographic clarity, ecological uncertainty." The
  ecological layer is the uncertain one, revealed by information purchases. See
  Information and uncertainty.*

- ~~**How are First Nations portrayed and consulted?**~~
  *Resolved in [[cultural-narrative-design]]: fictional, region-specific
  communities with a mandatory cultural-advisor review gate.*

- ~~**What drives the donation amount?**~~
  *Resolved: a monthly formula — base grant + Σ(usage × status weight ×
  fragmentation multiplier) + milestone bonuses. See Economy and budget.*

- ~~**What is the win condition, if any?**~~
  *Resolved: open-ended sandbox plus an optional Corridor Milestones track, with
  the capstone "Continental Connection." Milestones celebrate, they don't gate.
  See Player progression.*

- ~~**How is time paced?**~~
  *Resolved: one season = 15 minutes at 1× (a full year is one hour); controls
  are pause/1×/2×/4×; all actions work while paused. See Seasons and time.*

---

## Related

- [[crossing-location-selection]] — the interface for choosing where to build
- [[wildlife-overpass-crossing]] — the first crossing type and its mechanics
- [[sub-areas]] — Y2Y sub-area boundaries, names, and count
- [[governmental-permissions]] — how sub-area locks are earned
- [[cultural-narrative-design]] — cultural and narrative design for First Nations
  and other entity representation
- ADR reference: none yet
