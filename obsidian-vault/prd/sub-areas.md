---
title: "PRD — Y2Y Sub-Areas"
date: 2026-06-06
tags: [prd, system, geography, map]
status: draft
---

## Problem statement

The crossing location selection interface requires the Y2Y world map to be
divided into discrete sub-areas that the player can navigate to, zoom into, and
work within. Without a defined set of sub-areas — their geographic boundaries,
names, count, and relative sizes — the interface has no regions to render,
lock, or unlock, and the crossing location workflow cannot be built. This PRD
defines the geographic structure of the Y2Y world map.

---

## Goals

1. **Sub-areas reflect real geography.** Boundaries follow recognisable
   real-world features — mountain ranges, river valleys, provincial and state
   lines — so the map feels grounded and the player builds a genuine sense of
   the Y2Y corridor.
2. **Sub-areas are roughly equal in geographic size.** Equal sizing ensures the
   player's sense of scope and effort is consistent across the map, and that no
   single sub-area feels overwhelming or trivial compared to others.
3. **Sub-area count and granularity fit the gameplay loop.** There should be
   enough sub-areas to give the progression system meaningful pacing, but not so
   many that the world feels arbitrarily fragmented.
4. **Sub-areas are named in a way that is informative and respectful.** Names
   should reflect real place names, including Indigenous place names where
   appropriate, and avoid names that flatten or erase the cultural significance
   of an area.

---

## Non-goals

- **No sub-area artwork or rendering detail in this PRD.** Visual treatment of
  sub-areas on the world map (colour, border style, label placement) is a UI
  concern handled in the crossing location selection interface
  (see [[crossing-location-selection]]).
- **No lock/unlock mechanics in this PRD.** Which sub-areas are accessible at
  game start, and how they are unlocked through governmental permissions, is
  defined in [[governmental-permissions]].
- **No road or barrier data in this PRD.** The specific segments within each
  sub-area are defined by the game's world data layer, not by this document.

---

## Proposed solution

The world is divided into **12 sub-areas** based on the real priority regions
identified by the Yellowstone to Yukon Conservation Initiative, adjusted for
roughly equal playable size. Boundaries follow watersheds and mountain ranges
first, and administrative lines only where they coincide with natural features.

The full game world is the Yukon to Yellowstone (Y2Y) corridor: ~1.3 million km²
of connected mountain landscape spanning five U.S. states (Wyoming, Montana,
Idaho, Washington*, Oregon*), two Canadian provinces (British Columbia,
Alberta), two territories (Yukon, Northwest Territories), and the traditional
territories of more than 75 Indigenous peoples. (*Fringe extents only; not
playable sub-areas.) Y2Y is the entire extent of the game map — there is no
larger world.

---

## Key mechanics / rules

### Sub-areas: definitive list

South to north:

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

\* Fictional, region-specific communities — see [[cultural-narrative-design]].

The controlling-entity column maps each sub-area to one of the nine governing
entities defined in [[governmental-permissions]]; that PRD is the canonical home
for the entity roster and unlock mechanics.

### Sizing rule

Each sub-area is rendered at a comparable playable map size (target: equal tile
counts within ±15%), while world-map shapes remain geographically proportional.
Real priority regions vary in area; the game normalizes playable density, not
geographic truth. Deviations from equal size are documented in the world data
and justified by geography (e.g. Peace River Break is geographically narrow; its
playable map is denser).

### Naming rule

Sub-area names use established geographic names. Where an established name
derives from Indigenous languages (e.g. Muskwa–Kechika), the sub-area info panel
includes a note acknowledging the origin and the real traditional territories
the region overlaps. Final naming passes through cultural-advisor review (see
[[cultural-narrative-design]]).

---

## Resolved questions

- ~~**What are the sub-area boundaries, names, and count?**~~
  *Resolved: 12 sub-areas based on the real Y2Y Conservation Initiative priority
  regions, adjusted for roughly equal playable size. See the definitive list
  above. Boundaries follow watersheds and mountain ranges first.*

- ~~**How closely should sub-area boundaries follow real administrative
  borders?**~~
  *Resolved: natural features (watersheds, mountain ranges) first; administrative
  lines only where they coincide with natural features. Equal *playable* size
  (±15% tile count), with proportional world-map shapes; deviations documented
  and justified by geography.*

- ~~**How are Indigenous place names handled?**~~
  *Resolved: established geographic names are kept, including those of Indigenous
  origin, with acknowledgment notes in the sub-area info panel; all naming passes
  cultural-advisor review (see [[cultural-narrative-design]]).*

---

## Success criteria

**This PRD is complete when:**

- A definitive list of sub-areas exists with names, approximate geographic
  boundaries, and a justification for where each boundary was drawn.
- The list has been reviewed against the equal-size constraint and any deviations
  are documented and justified.
- The sub-area data is in a form the crossing location selection interface can
  consume at runtime.

---

## Related

- [[crossing-location-selection]] — the interface that uses sub-area data for
  navigation and selection
- [[governmental-permissions]] — defines which sub-areas start locked and how
  they are unlocked
- [[cultural-narrative-design]] — informs sub-area naming in areas with
  significant Indigenous presence
- [[game-design-overview]]
