---
title: "Crown of the Continent — Ecological Zone Map"
date: 2026-06-15
tags: [design, biome, research]
status: draft
---

## Overview

The Crown of the Continent is the first sub-area of the Wildlife Crossing game
map. It is inspired by the Crown of the Continent Ecosystem — the 16,000-square-
mile intact wilderness centered on Glacier National Park (Montana) and Waterton
Lakes National Park (Alberta). It is one of the most ecologically complete
temperate ecosystems remaining in North America.

The in-game map is **100×100 tiles** at Stardew Valley pixel art scale, with a
Godot 4 tilemap. This document defines the ecological zone layout that serves as
the brief for Phase 2 (Midjourney overview image) and Phase 3 (individual tile
archetype generation).

Geographic accuracy is intentionally approximate — the goal is ecological
inspiration, not topographic replication.

Related: [[ai-map-generation-approach]]

---

## Map Orientation

- **North** = top of map
- **West** = left (Pacific moisture, wetter climate)
- **East** = right (prairie/Arctic climate, drier)
- **Continental Divide** runs roughly north-to-south through columns 40–48,
  with a slight southeast drift. This is the spine of the map.
- Water flows **west** to the Pacific drainage and **east** to the Atlantic/
  Hudson Bay drainage. The Triple Divide Peak concept (where water flows to
  three oceans) is a key ecological story point in this region.

---

## Ecological Zones

Nine zones define the map. Each zone corresponds to a set of tile archetypes.

### 1. Glacier / Alpine Rock
- **Code**: `GLACIER`
- **Position**: Central spine (cols ~36–52, rows 0–55), concentrated in the
  northern half where peaks are tallest
- **Approximate tiles**: ~600–800
- **Ecology**: Permanent snowfields, glacial ice, exposed bedrock, talus slopes,
  fellfield. Virtually no vegetation. Very slow ecological processes. Glaciers
  are a defining visual feature but are in retreat — a subtle narrative hook.
- **Key species**: Mountain goat, golden eagle, ptarmigan (winter), pika
  (talus edges), hoary marmot
- **Tile feel**: Blue-grey ice, bright white snowfields, grey exposed rock,
  scattered boulders. Cold, austere.

### 2. Alpine Meadow
- **Code**: `ALPINE_MEADOW`
- **Position**: Flanking the glacier zone, cols 33–55, rows 0–58 (where
  not covered by glacier)
- **Approximate tiles**: ~500–700
- **Ecology**: Above treeline, below permanent snow. Heather, sedge, willow
  shrubs, wildflower meadows (beargrass, paintbrush, glacier lily). Short
  growing season, deep winter snowpack.
- **Key species**: Bighorn sheep, grizzly bear (summer foraging), wolverine,
  Clark's nutcracker, golden eagle
- **Tile feel**: Bright green in summer with pops of wildflower color (red
  paintbrush, yellow glacier lily). Rocky outcrops. Feels open and airy.

### 3. Subalpine Forest
- **Code**: `SUBALPINE`
- **Position**: Flanking the alpine on both sides, roughly cols 22–60
  (varying with row). The transition zone between peak and forest.
- **Approximate tiles**: ~1,200–1,500
- **Ecology**: Engelmann spruce, subalpine fir, whitebark pine (threatened).
  Dense, dark, and often wind-battered at upper edge (krummholz). Snow stays
  late. Some open subalpine parkland near the alpine boundary.
- **Key species**: Grizzly bear, gray wolf, wolverine, lynx, moose (upper
  subalpine bogs), boreal owl, three-toed woodpecker
- **Tile feel**: Dark dense canopy, some snow patches. Transition tiles near
  alpine show stunted, gnarled trees (krummholz). Most continuous zone
  on the map.

### 4. Western Montane Forest
- **Code**: `WEST_FOREST`
- **Position**: Western third of the map (cols 0–22 roughly), south of the
  subalpine contact
- **Approximate tiles**: ~1,400–1,800
- **Ecology**: Pacific maritime influence produces a much wetter, denser
  forest than the eastern side. Western red cedar, western hemlock, western
  larch (turns gold in autumn — a major visual opportunity), black cottonwood,
  Douglas fir. Dense understory of devil's club, ferns. Cedar-hemlock is the
  westernmost of the forest types, found in the lower valley bottoms.
- **Key species**: Black bear, grizzly bear (salmon season), white-tailed deer,
  moose, great horned owl, pileated woodpecker, harlequin duck (streams)
- **Tile feel**: Deep, rich green canopy. Dense and dark. Some older trees
  with large trunks. Larch turns orange-gold in autumn — consider a seasonal
  variant. Feels like old-growth.

### 5. Eastern Montane Forest
- **Code**: `EAST_FOREST`
- **Position**: Eastern side of divide, cols ~60–88 (where not lake or
  riparian), transitioning to prairie at far east
- **Approximate tiles**: ~1,200–1,400
- **Ecology**: Rain shadow of the divide creates a much drier, more open
  forest. Douglas fir, lodgepole pine, ponderosa pine at lower elevations.
  More fire-adapted. Rocky, gravelly soils. More open canopy than west side —
  more light reaches the ground.
- **Key species**: Elk, white-tailed deer, mule deer, mountain lion, black
  bear, long-billed curlew, ferruginous hawk
- **Tile feel**: Lighter, more open. Individual trees visible rather than
  wall of canopy. Rocky ground. Sunnier and warmer feeling than west forest.

### 6. Riparian Corridor
- **Code**: `RIPARIAN`
- **Position**: Along all rivers and lake shores (see water features below).
  Linear features threading through other zones.
- **Approximate tiles**: ~600–800 (linear)
- **Ecology**: Black cottonwood, Bebb willow, alder, water birch along
  stream banks. Creates a structurally distinct habitat threading through
  the landscape. Critically important as a wildlife movement corridor —
  animals follow water. Bull trout require cold, clear, connected streams.
- **Key species**: Moose, beaver, river otter, osprey, bald eagle, harlequin
  duck, American dipper, bull trout, westslope cutthroat trout
- **Tile feel**: Lush green, willows and cottonwoods with softer, lighter
  color than the forest zones. Water visible alongside. Linear, corridor-like.

### 7. Lake / Open Water
- **Code**: `LAKE`
- **Position**: Western Lake (cols ~6–20, rows 30–62) and Eastern Lake
  (cols ~66–86, rows 22–36), plus scattered alpine lakes in glacier zone
- **Approximate tiles**: ~600–800
- **Ecology**: Glacially-carved lakes, cold and deep. Exceptional water
  clarity (visibility to 30m). Western Lake is lower elevation, longer, fed
  by cedar-hemlock forest runoff. Eastern Lake is higher, more wind-swept,
  flanked by drier slopes. Both drain large watersheds.
- **Key species**: Osprey, bald eagle, common loon, harlequin duck, bull
  trout, westslope cutthroat, lake whitefish, grizzly (shoreline fishing)
- **Tile feel**: Deep blue, clear. Vary depth visually — shallow near shore
  (lighter turquoise), deep water (dark navy). Mountain reflections optional.

### 8. Wetland & Meadow
- **Code**: `WETLAND`
- **Position**: Northwestern lowlands (cols ~1–16, rows 68–84), and
  scattered wet meadows near lake and stream margins throughout
- **Approximate tiles**: ~400–600
- **Ecology**: Beaver ponds, willow carrs, sedge meadows, emergent marsh.
  Beaver are ecosystem engineers — their ponds create wetland for amphibians,
  waterfowl, and moose. High biodiversity relative to area.
- **Key species**: Moose, beaver, Canada goose, sandhill crane, great blue
  heron, wood frog, Pacific chorus frog, water shrew
- **Tile feel**: Yellow-green, soft and wet-looking. Cattails, sedge tufts,
  standing water patches. Slower and lower than riparian — more still water.

### 9. Prairie / Grassland
- **Code**: `PRAIRIE`
- **Position**: Eastern edge, cols ~88–100, expanding southward. Transition
  from eastern forest to open plains.
- **Approximate tiles**: ~800–1,000
- **Ecology**: Rough fescue grassland — one of the most imperiled grassland
  types in North America. Where the Rocky Mountains meet the Great Plains,
  creating dramatic visual contrast. Wind-swept, open, large sky. Bears and
  wolves historically used this transition extensively.
- **Key species**: Pronghorn, elk (winter range), bison (historically),
  swift fox, ferruginous hawk, burrowing owl, short-horned lizard
- **Tile feel**: Golden tan to warm green. Rolling grass, no trees. Feels
  open and exposed relative to other zones. Can show wind movement patterns
  in animation. Dramatic sky implied by low ground cover.

---

## Geographic Features

### Continental Divide
Runs north-to-south through the map, roughly columns 40–48, drifting slightly
east toward the south. This is the structural spine of the map. Everything east
drains one direction, everything west drains another. The divide passes through
the glacier zone — it is not a separate visual feature, but the peaks mark it.

### Water Features

| Feature | Position | Description |
|---|---|---|
| Western Lake | Cols 6–20, rows 30–62 | Large, deep, cold lake. Analog to Lake McDonald. Long and narrow, oriented N–S. Turquoise-blue. |
| North Fork River | Cols 11–13, rows 3–30 | Feeds the western lake from the north. Fast-moving. |
| Lake Outlet River | Cols 0–9, rows 59–70 | Drains western lake to map edge. Slower, wider. |
| Eastern Lake | Cols 66–86, rows 22–36 | Analog to St. Mary Lake. Wind-swept, higher elevation. Flanked by drier slopes. |
| Eastern River | Cols 44–68, rows 18–32 | Flows east from divide to eastern lake. Visible as riparian corridor threading through subalpine/east forest. |
| Eastern Outlet | Cols 85–100, rows 27–30 | Drains eastern lake east off the map. |
| South Fork River | Cols 45–65, rows 55–98 | Emerges from divide, flows southeast through subalpine and east forest. Second major east-side drainage. |
| Alpine Lakes | Cols 43–46, rows 12–16 and cols 49–52, rows 18–22 | Small cirque lakes in glacier zone. Ice-cold, bright blue, fed by snowmelt. |

---

## Wildlife Corridors

Four primary corridors define wildlife movement on this map. These should be
legible in the tile layout — not as separate tile types, but as connections
between habitat zones that make movement routes obvious to the player.

### Corridor 1 — West Riparian (N–S)
Runs north-to-south along the western lake and its river system (cols ~5–20,
rows 0–70). Primary movement route for grizzly, moose, wolf, and beaver.
Connects boreal forest to subalpine zone. Bull trout use the full river
corridor. **Crossing opportunity**: where road/infrastructure might bisect
the lake outlet river.

### Corridor 2 — East Valley (E–W)
Runs east-to-west along the eastern river and lake (rows ~22–36, cols 44–90).
Connects alpine zone to eastern prairie. Elk, wolf, and grizzly use this
valley seasonally. The divide pass at the western end is a natural pinch point
and key crossing opportunity. **Crossing opportunity**: where the east-side
road infrastructure bisects this valley corridor.

### Corridor 3 — Central Pass (N–S)
A high-elevation pass through the divide (around cols 44–46, rows 50–75)
connecting north and south across the mountain spine. Used by wolverine,
lynx, mountain goat. Narrow, high-altitude. **Crossing opportunity**: high-
elevation road crossing, the most dramatic infrastructure challenge.

### Corridor 4 — North Forest (E–W)
Runs through the northern forest belt (rows 0–15, cols 0–40). Connects
western forest to the subalpine zone. Used by grizzly and wolf moving between
drainages. Less dramatic but ecologically important. **Crossing opportunity**:
upper valley road crossing.

---

## Tile Archetypes for Phase 3

The following distinct tile types are needed for Phase 3 (individual Midjourney
generation). Each should be generated as a Stardew Valley-style top-down pixel
art tile, approximately 16×16 or 32×32 pixels before scaling.

| # | Name | Zone | Key Visual Elements |
|---|---|---|---|
| 1 | Dense western forest | WEST_FOREST | Cedar/hemlock dark canopy, moss |
| 2 | Larch forest (autumn) | WEST_FOREST | Orange-gold needles, open below |
| 3 | Open pine forest | EAST_FOREST | Ponderosa/lodgepole, rocky ground |
| 4 | Subalpine dark forest | SUBALPINE | Spruce-fir, some snow patches |
| 5 | Krummholz | SUBALPINE/ALPINE | Wind-stunted gnarled trees at edge |
| 6 | Glacier/snowfield | GLACIER | White ice, grey rock, blue tinge |
| 7 | Alpine rock | GLACIER | Exposed talus, lichen, no ice |
| 8 | Alpine meadow | ALPINE_MEADOW | Wildflowers (red, yellow), heather |
| 9 | Deep lake | LAKE | Dark navy, no features |
| 10 | Shallow lake / shore | LAKE | Lighter turquoise, pebble edge |
| 11 | River (straight) | RIPARIAN | Clear water, rocky bed |
| 12 | River (bend) | RIPARIAN | Curve variant, inner silt bar |
| 13 | River confluence | RIPARIAN | Two streams joining |
| 14 | Riparian bank | RIPARIAN | Willows, cottonwoods alongside water |
| 15 | Wetland / marsh | WETLAND | Cattails, sedge, still water patches |
| 16 | Prairie grass | PRAIRIE | Rolling fescue, golden tan |
| 17 | Forest-to-subalpine | Transition | Mix of tall and stunted trees |
| 18 | Forest-to-prairie | Transition | Scattered trees into open grass |

---

## Phase 2 Midjourney Prompt Brief

Use the following as the base prompt for the Phase 2 overview map generation.
Iterate from here — adjust style descriptors based on initial outputs.

### Primary prompt
```
Top-down pixel art game map, Stardew Valley art style, warm naturalistic 
color palette, bird's eye view. Rocky Mountain wilderness region showing: 
a deep blue-green glacial lake in the left third of the image surrounded 
by dense cedar and western larch forest; towering snow-capped rocky peaks 
with blue-grey glaciers running top-to-bottom through the center; alpine 
wildflower meadows flanking the peaks; dark dense subalpine spruce-fir 
forest on both sides of the mountains; a second elongated lake on the 
right side with drier open pine forest; golden-tan prairie grassland at 
the far right edge; rivers and streams connecting water features; cozy 
and alive feeling, no UI elements, no text, no grid lines, square 
composition. --ar 1:1 --style raw --v 6.1
```

### Style reference suggestions
Collect reference images before prompting:
- Stardew Valley overworld screenshots (for tile density and palette)
- Celeste (Mt. Celeste chapters) for mountain top-down aesthetic
- Actual Glacier NP aerial photography for zone proportions

### Iteration notes
- If the output feels too dark, add: `vibrant colors, warm lighting, sunny day`
- If it doesn't read as top-down: add `strict top-down view, no perspective`
- If glacier zone isn't distinct enough: add `dramatic snow-capped central mountain spine`
- Run 4–8 variants before selecting a reference image to take into Phase 3

---

## Zone Distribution Summary

Approximate tile count per zone for a 100×100 (10,000 tile) map:

| Zone | Approx. Tiles | % of Map |
|---|---|---|
| Western Montane Forest | 1,600 | 16% |
| Subalpine Forest | 1,350 | 13.5% |
| Eastern Montane Forest | 1,300 | 13% |
| Prairie / Grassland | 950 | 9.5% |
| Glacier / Alpine Rock | 750 | 7.5% |
| Lake / Open Water | 700 | 7% |
| Alpine Meadow | 650 | 6.5% |
| Riparian Corridor | 700 | 7% |
| Wetland & Meadow | 500 | 5% |
| Transitions & edges | 1,500 | 15% |
| **Total** | **10,000** | **100%** |

---

## Open Questions

- Should the map include a human footprint layer (road, ranch, fence tiles)
  that creates the crossing problem for the player to solve?
- What is the canonical tile size in pixels (16×16 vs 32×32)?
- Should seasonal tile variants be in scope for Phase 3, or deferred?
- Does the western lake need a named in-game equivalent, or does the real
  name (McDonald-inspired) carry through?

---

## References

- [UNESCO MAB Crown of the Continent](https://www.unesco.org/en/mab/crown-continent)
- [Glacier National Park (Wikipedia)](https://en.wikipedia.org/wiki/Glacier_National_Park_(U.S.))
- [Crown of the Continent Ecosystem — University of Montana](https://www.umt.edu/crown-reporting-project/crown.php)
- [LandScope America — Crown of the Continent](http://www.landscope.org/focus/priority_places/crown_of_the_continent/)
