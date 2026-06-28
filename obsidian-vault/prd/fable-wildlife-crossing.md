---
title: "PRD — Fable Wildlife Crossing (Consolidated Master PRD)"
date: 2026-06-10
tags: [prd, design, system, decision]
status: draft
---

> **Migration note (2026-06-14):** the content of this consolidated PRD has been
> migrated back out into the individual source PRDs (and a new
> `docs/design-documentation-plan.md`). Migrated sections below are marked with a
> ~~struck-through heading~~ and a pointer to their new home; their bodies are
> retained as historical record. The Decision log and Success criteria sections
> remain here as the migration ledger. See [[fable-migration-plan]] for the full
> mapping.

## Purpose of this document

This is the consolidated master PRD for Wildlife Crossing. It merges and
supersedes-by-consolidation the content of [[game-design-overview]],
[[crossing-location-selection]], [[sub-areas]], [[governmental-permissions]],
[[cultural-narrative-design]], and [[wildlife-overpass-crossing]] — without
modifying those documents. Every open question raised in those PRDs is answered
here (see the Decision log), and new requirements are added so that this
document can be fed back into Claude as a single prompt sufficient to generate
all design documentation needed to build the game.

Where this document conflicts with an earlier PRD, this document wins. The
earlier PRDs remain in the vault unchanged as historical record.

**How to use this document as a generation prompt:** see
"Design documentation generation requirements" near the end. That section
enumerates every design document to be produced, its required contents, its
repo location, and its acceptance criteria.

---

## ~~Vision~~

> **Migrated** to [[game-design-overview#Vision]] (2026-06-14). Content retained below as historical record.

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

## ~~Design pillars~~

> **Migrated** to [[game-design-overview#Design pillars]] (2026-06-14). Content retained below as historical record.

These four principles govern every design and implementation decision. When
options conflict, these are the tiebreakers.

1. **Ecological accuracy matters.** Species behaviour, habitat connectivity,
   and the effects of infrastructure on wildlife are modelled on real science.
   The game is not a nature documentary, but it should not contradict one.
2. **Cozy, not stressful.** No punishing fail states. Setbacks feel like
   interesting challenges to solve. The player is always making progress.
3. **Emergent complexity.** Simple rules produce rich, surprising outcomes.
   Prefer systems that interact over features that are isolated.
4. **The world feels alive.** Animals behave. Seasons change. Populations
   respond to what the player builds. The landscape is the subject, not a
   backdrop.

---

## ~~Core gameplay loop~~

> **Migrated** to [[game-design-overview#Core gameplay loop]] (2026-06-14). Content retained below as historical record.

1. **Survey.** Examine the map; optionally purchase habitat, population, or
   corridor data to clarify where fragmentation is worst.
2. **Select.** Choose a crossing location via the location selection interface:
   zoom from the Y2Y world map into an unlocked sub-area, down to an individual
   road or barrier segment.
3. **Build.** Construct a crossing at the selected segment, spending budget.
4. **Observe.** Animals begin using the crossing; population connectivity
   improves; the simulation visibly responds.
5. **Earn.** Effective crossings inspire donations, replenishing and growing
   the budget.
6. **Unlock.** Demonstrated ecological impact earns the trust of governmental
   entities and First Nations partners, opening new sub-areas.

The loop is open-ended. There is no forced endpoint; optional corridor
milestones (see Progression) provide long-term goals without closing the
sandbox.

---

## ~~World and geography~~

> **Migrated** (2026-06-14) across multiple PRDs — see per-subsection pointers below. Content retained as historical record.

### ~~The Y2Y world map~~

> **Migrated** to [[game-design-overview#Systems]] and [[sub-areas]] (2026-06-14).

The game world is the full Yukon to Yellowstone corridor: ~1.3 million km² of
connected mountain landscape spanning five U.S. states (Wyoming, Montana,
Idaho, Washington*, Oregon*), two Canadian provinces (British Columbia,
Alberta), two territories (Yukon, Northwest Territories), and the traditional
territories of more than 75 Indigenous peoples. (*Fringe extents only; not
playable sub-areas.) Y2Y is the entire extent of the game map — there is no
larger world.

### ~~Sub-areas: definitive list~~

> **Migrated** to [[sub-areas]] (2026-06-14), including the sizing and naming rules below.

**Decision (resolves [[sub-areas]]):** the world is divided into **12
sub-areas** based on the real priority regions identified by the Yellowstone to
Yukon Conservation Initiative, adjusted for roughly equal playable size.
Boundaries follow watersheds and mountain ranges first, administrative lines
only where they coincide with natural features. South to north:

| # | Sub-area | Anchor geography | Jurisdiction (real) | Controlling entity (in-game) |
|---|----------|------------------|---------------------|------------------------------|
| 1 | Greater Yellowstone | Yellowstone & Grand Teton NPs, Wind River Range | WY/MT/ID | US federal parks agency |
| 2 | High Divide | Centennial Mountains, Big Hole Valley | MT/ID | Multi-stakeholder ranching coalition |
| 3 | Salmon–Selway–Bitterroot | Frank Church Wilderness, Bitterroot Range | ID/MT | US federal forests agency |
| 4 | Cabinet–Purcell | Cabinet Mtns, Purcell Trench, Hwy 95 corridor | MT/ID/BC | State/provincial transport authorities |
| 5 | Inland Temperate Rainforest | Columbia Mountains, Selkirks, Kootenay Lake | BC | Provincial government (BC) |
| 6 | Crown of the Continent | Glacier–Waterton, Flathead Valley | MT/BC/AB | First Nations partnership (fictional: Ksanka Confederacy*) |
| 7 | Central Canadian Rockies | Banff, Jasper, Yoho, Kootenay NPs; Bow Valley | AB/BC | Canadian federal parks agency |
| 8 | Peace River Break | Hart Ranges, Peace River canyon, Hwy 97 | BC | Provincial government (BC) |
| 9 | Muskwa–Kechika | Muskwa Ranges, Kechika Basin | BC | First Nations partnership (fictional: Tāłtsē Dena Council*) |
| 10 | Upper Liard Basin | Liard Plateau, Cassiar Mountains | BC/YT | Territorial government |
| 11 | Stikine–Nass–Skeena Headwaters | Sacred Headwaters, Spatsizi Plateau | BC | First Nations partnership (fictional: Three Rivers Nations*) |
| 12 | Greater Mackenzie Mountains | Mackenzie & Selwyn Mountains | YT/NWT | Territorial government |

\* Fictional, region-specific communities — see Cultural and narrative design.

**Sizing rule:** each sub-area is rendered at a comparable playable map size
(target: equal tile counts within ±15%), while world-map shapes remain
geographically proportional. Real priority regions vary in area; the game
normalizes playable density, not geographic truth. Deviations from equal size
are documented in the world data and justified by geography (e.g.
Peace River Break is geographically narrow; its playable map is denser).

**Naming rule:** sub-area names use established geographic names. Where an
established name derives from Indigenous languages (e.g. Muskwa–Kechika), the
sub-area info panel includes a note acknowledging the origin and the real
traditional territories the region overlaps. Final naming passes through
cultural-advisor review (see Cultural and narrative design).

### ~~Segments~~

> **Migrated** to [[crossing-location-selection]] (segment definition, mechanic #6) (2026-06-14).

A **segment** is the smallest selectable unit of road or barrier: a pre-defined
section large enough to include all tiles where crossing infrastructure will be
placed plus surrounding space for fencing and animal-guidance constructs, and
small enough that the construction workflow operates without scope ambiguity.
Segment boundaries are fixed in world data; the player never adjusts them.

### ~~Terrain and tiles~~

> **Migrated** to [[wildlife-overpass-crossing]] (tile danger model + mortality env vars) (2026-06-14).

The map is composed of tiles with terrain types. Two danger categories exist:

- **Hard barriers** (fences, walls, buildings, urban zones): flagged
  `is_impassable = true`. Animals cannot enter these tiles; they are blocked in
  the pathfinding graph.
- **Hazardous tiles** (roads, rivers): flagged `is_hazardous = true`. Passable,
  but each tile-step triggers a mortality check. `is_impassable` and
  `is_hazardous` are mutually exclusive.

Per-terrain mortality is configured by environment variables read at simulation
start: `ROAD_HAZARD_MORTALITY` and `RIVER_HAZARD_MORTALITY`, each defaulting to
`0.20` if absent, independently settable.

---

## ~~Habitat system~~

> **Migrated** to [[game-design-overview#Habitat and zoning]] (2026-06-14). Content retained below as historical record.

### Habitat quality model (decision — resolves the top open question in [[game-design-overview]])

Habitat quality is computed **per patch** (a contiguous zone of ecologically
compatible terrain) as a 0–100 score from four inputs:

```
quality = clamp(0, 100,
    terrain_base                       # 0–40: mean suitability of the patch's
                                       #        terrain tiles for the patch biome
  + size_factor                        # 0–30: log-scaled patch tile count vs.
                                       #        the biome's minimum viable size
  + connectivity_bonus                 # 0–20: count and quality of safe links
                                       #        (crossings or contiguous habitat)
                                       #        to other patches
  - edge_penalty )                     # 0–25: fraction of patch perimeter
                                       #        adjacent to roads, urban zones,
                                       #        or hard barriers
```

Named constants for all weights live in a single `habitat_constants.gd`; no
magic numbers. Quality recomputes incrementally on graph-changing events
(crossing completed, season change), never per frame.

**Surfacing to the player:** quality renders as a four-band qualitative label —
Poor / Fair / Good / Excellent — in the patch-inspect panel and as the
connectivity overlay's data source. Exact numeric scores are revealed only
after the player purchases a habitat assessment for that area, preserving the
information-uncertainty loop.

**Population viability:** a patch below its biome's minimum viable size cannot
sustain a population regardless of animal presence — populations there decline
slowly until connected to a larger network. This makes connectivity mechanical,
not cosmetic.

---

## ~~Species and animal simulation~~

> **Migrated** to [[game-design-overview#Species and animal simulation]] (2026-06-14); the hex 6-directional pathfinding decision also resolves an open question in [[wildlife-overpass-crossing]]. Content retained below as historical record.

### Launch roster (new requirement)

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

### Movement and mortality

- Pathfinding uses the **hex grid's 6-directional** connectivity — each tile has
  exactly six direct neighbours and no diagonal relationships exist. This
  resolves the diagonal-crossing ambiguity in [[wildlife-overpass-crossing]]:
  because every edge is a direct connection in a hex grid, crossing choice is
  always unambiguous.
- Each step onto an uncovered hazardous tile triggers the per-terrain mortality
  check. Death removes the animal from simulation immediately.
- Crossing via constructed infrastructure carries zero mortality.
- Pathfinding cost for a crossing matching the species' preferred type is lower
  (more attractive) than for non-preferred types; preference affects
  probability, never hard eligibility.

### Population model

Population health is tracked per patch per species: count, trend, and
connectivity status. A crossing that reconnects two patches produces observable
recovery — rising counts, range expansion, animals visibly moving. Recovery
milestones (e.g. "caribou population doubled") fire events consumed by the
donation and permission systems.

---

## ~~Crossings and infrastructure~~

> **Migrated** to [[wildlife-overpass-crossing]] (overpass mechanics, feedback decisions, and the crossing-cost rule superseding its no-economy non-goal); cost cross-referenced in [[game-design-overview#Economy and budget]] (2026-06-14). Content retained below as historical record.

### Overpass (v1 crossing type)

All mechanics from [[wildlife-overpass-crossing]] carry forward:

- Overpass placement is valid only on tiles flagged `is_impassable` or
  `is_hazardous`; invalid placement shows a red preview state.
- An overpass must span **every cell** of dangerous terrain to create a route;
  partial spans connect nothing. When complete, the pathfinding graph gains
  zero-mortality edges through the chain, and covered hard-barrier tiles become
  traversable.
- The data model supports future types (underpass, corridor) by adding tile
  registry entries, not structural changes.

### Crossing feedback (decisions — resolve [[wildlife-overpass-crossing]] open questions)

- The `animal_crossed` signal is **per-animal, per-completed-traversal**. The
  feedback layer coalesces signals per crossing within a 2-second window into a
  single visual/audio cue with a small "+N" counter, so simultaneous crossings
  never stack into noise.
- **Art direction for the overpass tile:** a vegetated pixel-art overpass with
  earthen ramps and native plantings, in the warm Stardew-register palette;
  three visual variants keyed to surrounding biome (forest, grassland, alpine).
  A placeholder sprite is acceptable through prototype; the art direction
  document (see generation requirements) finalizes the spec.

### Crossing costs (supersedes the "no economy" non-goal in [[wildlife-overpass-crossing]])

The no-cost rule in the overpass PRD existed to validate the core mechanic in
isolation. In the full game, crossings cost budget: **5,000 per overpass tile**
(a three-tile road span costs 15,000). Constants live in
`economy_constants.gd` and are tunable without code changes.

---

## ~~Crossing location selection interface~~

> **Migrated** to [[crossing-location-selection]] (the four decisions resolve its open questions) (2026-06-14). Content retained below as historical record.

All mechanics from [[crossing-location-selection]] carry forward: the "Add
crossing" toolbar action opens the Y2Y world map in selection mode; navigation
is a continuous zoom with no level-transition screens; locked sub-areas are
desaturated with a lock indicator and cannot be entered; only `is_impassable`
and `is_hazardous` segments are hoverable/selectable; clicking opens a
confirmation panel (segment label, current budget, connectivity note) with
Confirm and Cancel; Confirm passes the segment + sub-area context directly to
construction; Escape exits selection mode from any state; insufficient budget
disables Confirm with an explanatory note. All P0/P1/P2 requirements in that
PRD remain in force.

### Decisions (resolve [[crossing-location-selection]] open questions)

- **Connectivity overlay appearance:** a soft-edged heatmap using a
  colorblind-safe two-hue gradient — warm orange (fragmented) to teal
  (well-connected) — rendered at ~40% opacity over terrain. The three most
  fragmented segments in view get a subtle slow pulse. No numeric labels on the
  overlay itself; numbers live in the hover tooltip (P1).
- **Confirmation panel interaction:** clicking anywhere outside the panel
  closes it (equivalent to Cancel) and returns to hover-selection mode. The
  panel never blocks map panning via keyboard/edge-scroll.
- **Connectivity computation:** connectivity is computed on a patch-adjacency
  graph (patches as nodes, safe links as edges), pre-computed per sub-area at
  load and incrementally recomputed on graph-changing events (crossing
  completed, season change). Never per-frame. The overlay reads cached values.
- **Segment-zoom threshold:** segment-level resolution activates when the
  on-screen tile size reaches **≥16 px**, with hysteresis (deactivates below
  12 px) to prevent flicker at the boundary. The threshold is a named constant,
  identical across sub-areas.

---

## ~~Economy~~

> **Migrated** to [[game-design-overview#Economy and budget]] (budget, donation formula) and [[game-design-overview#Information and uncertainty]] (information purchases) (2026-06-14). Content retained below as historical record.

### Budget

The player starts with **50,000** funds. Budget is spent on construction and
information purchases and replenished by donations. Budget management should
feel enabling: there should usually be a crossing the player can afford, and
scarcity should produce interesting prioritization decisions, not stalls. If
the player's budget falls below the cheapest possible action, a small
unconditional "community fundraising" trickle (500/month) guarantees the game
never deadlocks — consistent with the cozy pillar.

### Donation formula (decision — resolves [[game-design-overview]] open question)

Donations arrive monthly (in-game). Monthly income:

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
design intent: high usage, endangered species, and badly fragmented locations
pay best — building thoughtfully visibly outperforms building randomly.

### Information purchases

| Product | Cost | Reveals |
|---------|------|---------|
| Habitat assessment | 1,000 / area | Numeric habitat quality + patch sizes |
| Population survey | 2,000 / area | Species present, counts, trends |
| Movement corridor study | 3,000 / area | Attempted routes + mortality hotspots |
| Community liaison briefing | 1,500 / entity | Exact permission-progress weights for one governmental entity |

Information is permanent once purchased and most valuable when it changes what
the player would build.

---

## ~~Seasons and time~~

> **Migrated** to [[game-design-overview#Seasons and time]] (2026-06-14). Content retained below as historical record.

**Decision (resolves [[game-design-overview]] pacing question):**

- One in-game year = four seasons; **one season = 15 minutes at 1× speed**
  (one in-game day ≈ 10 seconds). A full year is one hour of play.
- Time controls: pause, 1×, 2×, 4×. Pausing is always available and never
  penalized; all build and information actions work while paused.

Seasonal effects carry forward from [[game-design-overview]]: migration
seasons raise crossing motivation (usage spikes for migratory species);
hibernating species leave the simulation in winter; terrain shifts (frozen
rivers become temporarily non-hazardous; spring floods widen river hazard
zones by one tile). Building before a migration season maximizes early impact
— the seasonal calendar is always visible so the player can plan.

---

## ~~Information and uncertainty~~

> **Migrated** to [[game-design-overview#Information and uncertainty]] (2026-06-14). Content retained below as historical record.

**Decision — map fog (resolves [[game-design-overview]] open question):
geographic clarity, ecological uncertainty.** The terrain map is fully visible
from the start — it represents real, mapped geography, and hiding it would
fight the educational intent. What is uncertain is the *ecological layer*:
without purchases, habitat quality shows only coarse bands, population data
shows "unknown," and mortality hotspots are invisible. Surveying reveals the
living layer of the map rather than the map itself. Locked sub-areas show
terrain but no ecological data at all until unlocked.

---

## ~~Progression: governmental permissions~~

> **Migrated** to [[governmental-permissions]] (2026-06-14). Content retained below as historical record.

### Entity roster (decision — resolves [[governmental-permissions]] open questions)

Nine entities govern the twelve sub-areas (see the sub-area table):

- **2 federal parks/forests agencies** (US, Canada) — value usage data and
  visitor-safe outcomes: crossing usage counts, reduced road mortality.
- **2 provincial governments / transport authorities** (BC, state DOTs) —
  value infrastructure metrics: crossings completed, road mortality reduction
  on their corridors.
- **2 territorial governments** (Yukon, NWT) — value sustained stewardship:
  total active crossings and population stability over time.
- **3 First Nations partnerships** (fictional, region-specific — see Cultural
  and narrative design) — value demonstrated ecological outcomes and respect:
  population recovery events, species diversity, stewardship quality in
  adjacent sub-areas the player already works in, and acceptance of joint
  stewardship invitations (in-game events).

### Unlock mechanics

Each entity has a **Trust score (0–100)**, fed by weighted, measurable metrics
(weights differ per entity as above; exact weights revealed via the community
liaison briefing purchase). Reaching the threshold (default 100) triggers the
unlock event: a short narrative beat, the sub-area unlocking on the world map,
and a one-time donation bonus.

Relationship stages are qualitative: **Introduced → Engaged → Trusted →
Partnered** (quartiles of the trust score). The per-entity panel shows the
stage plus a checklist of that entity's top three priority conditions with
progress bars — progress is always legible.

### Starting state

**Central Canadian Rockies (sub-area 7) is unlocked at game start.** The Bow
Valley's real wildlife overpasses are the most famous in the world; starting
where crossings demonstrably work is geographically motivated, educational,
and gives the tutorial a true story to tell. **Crown of the Continent (6)** is
the intended first unlock with a deliberately low threshold, introducing the
First Nations partnership mechanic early. The remaining ten unlock in any
order; trust thresholds scale northward/southward from the start so the
pacing curve feels like escalating opportunity.

### Revocation

**Permission, once earned, is never revoked.** Re-locking would violate the
cozy pillar. Neglect of an unlocked area instead slows trust growth with
*other* entities ("stewardship quality" metrics dip) — a natural consequence,
not a punishment.

---

## ~~Cultural and narrative design~~

> **Migrated** to [[cultural-narrative-design]] (the four decisions resolve its open questions) (2026-06-14). Content retained below as historical record.

The principles in [[cultural-narrative-design]] carry forward in full:
Indigenous stewardship is centred, not backgrounded; the game does not speak
for Indigenous peoples; named communities require consent and accuracy;
failure to earn consent feels like a natural consequence; government agencies
are characterised thoughtfully, not as bureaucratic obstacles.

### Decisions (resolve [[cultural-narrative-design]] open questions)

- **Representation approach: fictional, region-specific communities.** The
  three First Nations partnerships are respectfully crafted fictional
  communities grounded in real regional context (language family, ecological
  practices, geography), explicitly framed in-game as fictional. Real Nations'
  territories are acknowledged in sub-area info panels and a land
  acknowledgment in the game's opening. This avoids misrepresenting real
  Nations without their consent while keeping the educational content
  specific rather than generic.
- **Cultural consultation: required.** Formal engagement of Indigenous
  cultural advisors is a hard gate before any First Nations narrative content
  ships. The development pipeline includes a cultural-review step for: the
  three fictional communities' design, sub-area naming, dialogue, and the
  joint-stewardship event content. Budgeted as a project line item.
- **Player framing:** the player is an outsider — a coordinator for a
  fictional conservation non-profit — seeking *partnership*, not permission in
  a bureaucratic sense. The org has an existing reputation that the player's
  actions build on; First Nations interactions are framed as relationship-
  building between organizations and communities.
- **Indigenous knowledge in mechanics, not just text.** Partnership with a
  First Nations entity confers gameplay effects reflecting stewardship
  expertise: movement-corridor data in their territory is revealed free of
  charge; co-stewarded habitat patches receive a baseline habitat-quality
  bonus; and "guided placement" hints highlight high-impact segments in their
  sub-area. Indigenous knowledge is mechanically *better information and
  better outcomes* — matching the real-world record of Indigenous-led
  conservation.

---

## ~~Player progression and win condition~~

> **Migrated** to [[game-design-overview#Player progression]] (2026-06-14). Content retained below as historical record.

**Decision (resolves [[game-design-overview]] open question): open-ended
sandbox with optional milestone goals.** There is no forced end state. A
"Corridor Milestones" track provides long-term structure:

- Per-sub-area milestones: first crossing, all priority segments addressed,
  all resident species stable.
- The capstone **Continental Connection** milestone: a continuous chain of
  connected habitat from Greater Yellowstone to the Greater Mackenzie
  Mountains. Achieving it plays a celebratory sequence and the game continues.

Milestones are celebrations, not gates; nothing is locked behind the capstone.

---

## ~~How systems interact~~

> **Migrated** to [[game-design-overview#How systems interact]] (2026-06-14). Content retained below as historical record.

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

A player who builds thoughtfully — using information, timing crossings before
migration seasons, prioritising fragmented links and endangered species —
earns faster unlocks and higher income than one who builds randomly. Skill is
rewarded without punishing the unskilled.

---

## Decision log — every open question answered

| Source PRD | Open question | Decision |
|---|---|---|
| game-design-overview | How is habitat quality computed and surfaced? | Per-patch 0–100 formula (terrain base + size + connectivity − edge penalty); four qualitative bands shown free, numerics behind habitat assessments. See Habitat system. |
| game-design-overview | Is the map fogged at start? | No terrain fog; ecological data is the uncertain layer. "Geographic clarity, ecological uncertainty." |
| game-design-overview | How are First Nations portrayed and consulted? | Fictional region-specific communities; mandatory cultural-advisor review gate. See Cultural and narrative design. |
| game-design-overview | What drives the donation amount? | Monthly formula: usage × status weight × fragmentation multiplier + milestones + base grant. See Economy. |
| game-design-overview | Win condition? | Open-ended sandbox + optional Corridor Milestones; capstone "Continental Connection." |
| game-design-overview | How is time paced? | 1 season = 15 min at 1×; pause/1×/2×/4×; actions available while paused. |
| crossing-location-selection | Overlay appearance? | Colorblind-safe orange→teal heatmap at ~40% opacity; pulse on worst segments. |
| crossing-location-selection | Does the panel block map interaction? | Click-outside closes the panel (acts as Cancel); panning never blocked. |
| crossing-location-selection | How is connectivity computed? | Patch-adjacency graph; precomputed per sub-area + incremental recompute on events; never per-frame. |
| crossing-location-selection | Zoom threshold for segment mode? | Tile size ≥16 px on screen, hysteresis at 12 px; one global named constant. |
| sub-areas | Boundaries, names, count? | 12 sub-areas from real Y2Y priority regions; watershed/range boundaries; table in World and geography. |
| sub-areas | Follow administrative borders? | Natural features first; administrative lines only where they coincide. Equal *playable* size (±15%), proportional world-map shapes. |
| sub-areas | Indigenous place names? | Established names of Indigenous origin kept with acknowledgment notes; all naming passes cultural-advisor review. |
| governmental-permissions | Which sub-areas start unlocked? | Central Canadian Rockies (Bow Valley — real famous overpasses); Crown of the Continent as the designed first unlock. |
| governmental-permissions | How are permissions earned? | Per-entity Trust score 0–100 from weighted measurable metrics; threshold triggers unlock. |
| governmental-permissions | How does the player learn what entities want? | Sub-area info panel + entity profile screen; exact weights via "community liaison briefing" purchase. |
| governmental-permissions | Can permission be revoked? | Never. Neglect slows future trust growth instead. |
| governmental-permissions | How many entities? | Nine, across twelve sub-areas (2 federal, 2 provincial/state, 2 territorial, 3 First Nations partnerships). |
| governmental-permissions | How is progress communicated? | Relationship stages (Introduced→Engaged→Trusted→Partnered) + per-entity checklist with progress bars. |
| cultural-narrative-design | External cultural consultants? | Yes — mandatory review gate before First Nations content ships; budgeted. |
| cultural-narrative-design | Real vs. fictional communities? | Fictional, region-specific, explicitly framed as fictional; real territories acknowledged. |
| cultural-narrative-design | Player's narrative framing? | Outsider coordinator of a conservation non-profit seeking partnership. |
| cultural-narrative-design | Indigenous knowledge in gameplay? | Mechanical benefits of partnership: free corridor data, habitat-quality bonus, placement hints. |
| wildlife-overpass-crossing | Diagonal crossing attempts? | Hex grid: every tile has 6 direct neighbours, no diagonal relationships. Pathfinding is 6-directional; crossing choice is always unambiguous. |
| wildlife-overpass-crossing | Signal granularity? | Per-animal per-traversal; feedback coalesced per crossing in 2 s windows with a "+N" counter. |
| wildlife-overpass-crossing | Overpass art? | Vegetated pixel-art overpass, three biome variants; placeholder acceptable until the art direction doc. |

(The two questions already marked resolved in source PRDs — segment definition
and per-cell overpass spans / 20% default mortality — carry forward unchanged.)

---

## ~~Design documentation generation requirements (new)~~

> **Moved** to `docs/design-documentation-plan.md` ([[design-documentation-plan]]) on 2026-06-14 — it is a meta-plan for producing design docs, so it now lives with the technical docs rather than in this PRD. Content retained below as historical record.

This section makes the PRD sufficient as a prompt for generating the full
design documentation set. When this PRD is fed to Claude with the instruction
"generate the design documentation," produce the following documents, in this
order (each may reference earlier ones). All documents follow the repo's
conventions: ADRs in `docs/adr/NNNN-kebab-case.md` (Context / Decision /
Consequences), technical docs in `docs/`, design notes in
`obsidian-vault/design/`, wiki articles in `obsidian-vault/wiki/` with front
matter, GDScript snake_case, one class per file, signals over direct
references, named constants only.

1. **Technical architecture document** (`docs/architecture.md`) — Godot 4
   scene tree and autoload structure; the simulation tick model; system
   boundaries (world data, habitat, species/pathfinding, economy, permissions,
   seasons, UI) and the signals connecting them; save/load design;
   performance budget for the per-event connectivity recompute.
   *Acceptance: every system in this PRD maps to a named scene/script; every
   cross-system interaction in "How systems interact" maps to a named signal.*

2. **Data schema specification** (`docs/data-schemas.md`) — JSON schemas for
   species (fields listed in Species section), sub-areas (boundaries, playable
   size, controlling entity, trust threshold), segments, tiles (including
   `is_impassable`/`is_hazardous`), governmental entities (metric weights),
   and milestones. Includes the environment-variable registry
   (`ROAD_HAZARD_MORTALITY`, `RIVER_HAZARD_MORTALITY`) and the constants files
   (`habitat_constants.gd`, `economy_constants.gd`).
   *Acceptance: a sample data file for each schema validates; all eight launch
   species and twelve sub-areas have stub entries.*

3. **Simulation and pathfinding design** (`docs/simulation-design.md`) —
   hex-grid 6-directional pathfinding graph construction; crossing-preference cost
   weighting; mortality checks; population model (per-patch counts, viability,
   recovery events); seasonal modifiers; determinism and tick-rate decisions.
   *Acceptance: pseudocode or GDScript sketches for graph update on crossing
   completion and for the monthly population step.*

4. **UI/UX specification** (`obsidian-vault/design/ui-ux-spec.md`) — every
   screen and panel named in this PRD: world map + selection mode, overlay,
   confirmation panel, build palette, patch/tile inspect, entity profile +
   trust checklist, seasonal calendar, budget HUD, milestone track, time
   controls. Wireframe descriptions, input maps (including Escape semantics),
   and the click-outside-closes-panel rule.
   *Acceptance: every P0 requirement in [[crossing-location-selection]] and
   this PRD has a corresponding UI element; all four relationship stages and
   all four habitat bands have defined visual treatments.*

5. **Art direction document** (`obsidian-vault/design/art-direction.md`) —
   palette, tile dimensions, sprite specs for the eight species and three
   overpass biome variants, overlay/heatmap rendering spec (colorblind-safe
   gradient), locked sub-area desaturation treatment, seasonal terrain
   variants.
   *Acceptance: a per-asset list with dimensions and priority sufficient to
   commission or generate placeholder-replacing art.*

6. **Audio design document** (`obsidian-vault/design/audio-design.md`) —
   crossing-success cue (and its coalescing behaviour), ambient seasonal beds,
   unlock fanfares, UI sounds; mixing rules consistent with the cozy pillar.
   *Acceptance: a complete cue list mapped to the signals that trigger them.*

7. **Narrative and cultural content plan**
   (`obsidian-vault/design/narrative-content-plan.md`) — the three fictional
   First Nations communities (names, regional grounding, what each values),
   the nine entity characterisations, unlock narrative beats, land
   acknowledgment text, and the cultural-review pipeline with its sign-off
   gate.
   *Acceptance: every entity in the roster has a character brief; the review
   gate is positioned before any content-complete milestone.*

8. **Wiki seed articles** (`obsidian-vault/wiki/`, one per subject) — the
   eight species, the twelve sub-areas, and core glossary terms (patch,
   segment, connectivity, trust), encyclopedic tone with `## References` to
   real-world science.
   *Acceptance: front matter valid; each species article states the real
   ecology behind its game parameters.*

9. **Test plan** (`docs/test-plan.md`) — GUT test files per system
   (`game/tests/<system_name>_test.gd`): pathfinding through complete/partial
   spans, per-terrain mortality rates honouring environment variables,
   `animal_crossed` signal exactly-once, habitat quality recompute, donation
   formula, trust accumulation and unlock trigger, season transitions.
   *Acceptance: every P0 acceptance criterion in this PRD and
   [[wildlife-overpass-crossing]] maps to at least one named test.*

10. **Milestone roadmap** (`docs/roadmap.md`) — phased build order:
    (1) core simulation + overpass validation, (2) location selection +
    sub-areas, (3) economy + information, (4) seasons, (5) permissions +
    narrative (post cultural review), (6) milestones + polish. Each phase
    lists its PRD sections, exit criteria, and ADRs likely needed (crossing
    tile architecture, save format, connectivity algorithm).
    *Acceptance: every requirement in this PRD is assigned to exactly one
    phase.*

**Generation constraints:** do not modify any existing PRD; new documents only.
Where a generated document must make a decision this PRD does not cover, state
the decision explicitly in the document and flag it `> Decision logged:` per
vault conventions rather than leaving it open.

---

## Success criteria

**This PRD is complete and working when:**

- Every open question from the six source documents appears in the Decision
  log with a concrete answer.
- The twelve sub-areas, nine entities, and eight species are fully enumerated
  with the data needed to stub their definition files.
- Claude, given this document and the generation-requirements section as a
  prompt, can produce all ten design documents without needing to ask a
  blocking question about game design intent.
- No existing PRD file was modified.

**The game vision is working when** (carried forward): a new player starting
in the Bow Valley can identify a fragmented segment with the overlay, build a
complete overpass, watch the first animal cross with celebratory feedback,
receive their first donation, and understand — without instruction — why all
four of those things happened.

---

## Related

- [[game-design-overview]] — superseded-by-consolidation; retained unchanged
- [[crossing-location-selection]] — superseded-by-consolidation; retained unchanged
- [[sub-areas]] — superseded-by-consolidation; retained unchanged
- [[governmental-permissions]] — superseded-by-consolidation; retained unchanged
- [[cultural-narrative-design]] — superseded-by-consolidation; retained unchanged
- [[wildlife-overpass-crossing]] — superseded-by-consolidation; retained unchanged
- ADR reference: none yet — the roadmap document will identify required ADRs

**Real-world references for the sub-area structure:** Yellowstone to Yukon
Conservation Initiative priority regions (y2y.net); Y2Y region ~1.3M km²,
spanning 5 states, 2 provinces, 2 territories, 75+ Indigenous territories.
