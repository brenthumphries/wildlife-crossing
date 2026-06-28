---
title: "Art Direction"
date: 2026-06-17
tags: [design, art]
status: active
---

## Purpose

This document defines the visual direction for Wildlife Crossing and the concrete
asset list needed to produce it: palette, tile dimensions, sprite specs for the
eight launch species and the three overpass biome variants, the connectivity
overlay/heatmap rendering spec (colorblind-safe), the locked sub-area
desaturation treatment, and seasonal terrain variants. Its acceptance bar is a
**per-asset list with dimensions and priority sufficient to commission or
generate placeholder-replacing art**.

Direction follows the PRD pillars: warm, naturalistic, pixel-art, top-down 2D in
the Stardew Valley register, hopeful and cozy. Biome vocabulary draws on
[[crown-of-continent-zone-map]]. The grid is **hexagonal**
([ADR 0002](../../docs/adr/0002-hex-grid-topology.md)); tile dimensions below are
the hex bounding box.

---

## 1. Visual pillars

- **Warm and naturalistic.** Earthy, slightly desaturated naturals; sunlight, not
  fluorescent. The landscape is the subject, never a backdrop.
- **Cozy, not stressful.** Soft edges, gentle contrast, no harsh reds except the
  single invalid-placement state. Even fragmentation reads as "a problem to
  solve," not danger.
- **Legible at a glance.** Habitat bands, lock state, and connectivity must read
  instantly and survive colorblind viewing.
- **Educational honesty.** Species and terrain are recognisable enough that a
  player learns true things about Y2Y ecology.

---

## 2. Palette

A warm naturalistic base with a single perceptually-uniform data axis
(orange→teal) reused across overlay and habitat bands so colour always means the
same thing.

### Base environment

| Role | Hex | Use |
|---|---|---|
| Canvas / sky-neutral | `#F3EAD8` | UI backdrop, parchment |
| Forest deep | `#2E4A36` | dense canopy |
| Forest mid | `#4C7A4A` | montane forest |
| Grassland | `#A8B560` | prairie / meadow |
| Alpine rock | `#8A8E97` | talus, exposed rock |
| Snow / glacier | `#E8EEF2` | snowfield, ice (blue tinge `#C9DBE6`) |
| Water deep | `#2B5A72` | deep lake |
| Water shallow | `#6FB3B8` | shore, river |
| Wetland | `#9CA84E` | marsh, sedge |
| Earth / ramp | `#7A5A3A` | overpass ramps, trails |

### Data axis (orange→teal, colorblind-safe)

Single sequential ramp used by the connectivity overlay and habitat bands.
Chosen to remain distinguishable under deuteranopia/protanopia (diverging
hue + monotonic lightness):

| Stop | Hex | Meaning |
|---|---|---|
| Fragmented | `#E08A3C` (warm orange) | low connectivity / Poor |
| — | `#D9A85C` | Fair |
| — | `#8FB07A` | Good |
| Connected | `#2E8B8B` (teal) | high connectivity / Excellent |

### UI accents

| Role | Hex |
|---|---|
| Confirm / positive | `#2E8B8B` |
| Invalid placement (only hard red) | `#C0492F` |
| Locked overlay tint | `#6B6E73` at reduced saturation |
| Gold (capstone, partnership badge) | `#D8A93C` |

---

## 3. Tile system

- **Grid:** hexagonal, flat-top. Internal coordinates axial `[q,r]`.
- **Tile size:** **32×32 px** bounding box at 1× (flat-to-flat width 32 px is the
  axis the segment-zoom threshold measures). Rendered at 1×/2×/3× via a global
  `CanvasItem` scale. (The scoped `game/CLAUDE.md` lists 16×16 as the square-tile
  default; hex bounding boxes use 32×32 so the hex interior matches the 16px
  detail density — noted below as a logged decision.)
- **Authoring:** Aseprite source in a sibling `_src/`, exported PNG sheets per
  biome theme ([[crown-of-continent-zone-map]] tile archetypes are the content
  brief).

> Decision logged: hex tiles are authored at a **32×32 bounding box** (not the
> 16×16 square default) so the inscribed hex carries roughly the same visual
> detail as a 16px square tile and the ≥16px / 12px zoom thresholds land on a
> readable on-screen size. The global render scale and the
> `SEGMENT_ZOOM_ACTIVATE_PX`/`DEACTIVATE_PX` constants are tuned against this
> box. If hex authoring proves heavy, a 24×24 box is the fallback.

### Terrain tile archetypes (priority)

Reuse the archetype set from [[crown-of-continent-zone-map]]: forest (dense west,
open east, larch-autumn), subalpine, krummholz, glacier/snowfield, alpine rock,
alpine meadow, lake (deep/shallow), river (straight/bend/confluence/bank),
wetland, prairie, and forest↔subalpine / forest↔prairie transitions. Plus the
human-footprint hazard/barrier tiles below (these create the crossing problem).

| Tile | Flags | Dimensions | Priority |
|---|---|---|---|
| Road (highway) | `is_hazardous` | 32×32 | P0 |
| River (as hazard crossing) | `is_hazardous` | 32×32 (+bend/confluence) | P0 |
| Fence line | `is_impassable` | 32×32 | P0 |
| Wall / building / urban | `is_impassable` | 32×32 ×3 variants | P1 |
| Core biomes (forest, grassland, alpine, wetland, water) | terrain | 32×32 each | P0 |
| Secondary biomes/transitions | terrain | 32×32 each | P2 |

---

## 4. Crossing sprites — overpass (three biome variants)

A **vegetated pixel-art overpass with earthen ramps and native plantings** in the
warm Stardew register, with **three variants keyed to surrounding biome**
([[wildlife-overpass-crossing]] resolved decision).

| Asset | Biome context | Plantings/feel | Dimensions | Priority |
|---|---|---|---|---|
| `overpass_forest` | forest | conifer saplings, ferns, mossy deck | 32×32 per spanned cell + ramp end-caps | P0 |
| `overpass_grassland` | grassland/prairie | fescue grass, low shrubs, warm tan | 32×32 per cell + ramp caps | P0 |
| `overpass_alpine` | alpine/subalpine | heather, scree edges, hardy wildflowers | 32×32 per cell + ramp caps | P0 |

Each variant needs: a **mid-span tile** (tileable across cells), two **ramp
end-caps** (entry/exit), and an **under-construction** state. The biome variant
is resolved at placement from the surrounding terrain (data-driven sprite key,
[ADR 0003](../../docs/adr/0003-crossing-tile-architecture.md)). Placeholder
sprites are acceptable through prototype (Phase 1).

**Crossing-success visual:** a brief, soft particle burst (leaves/light motes in
the data-axis teal) on the spanned tile when `animal_crossed` fires, with a small
"+N" counter when crossings coalesce within the 2-second window
([[audio-design]] coalescing). Gentle, never flashy — cozy pillar.

---

## 5. Species sprites (all eight)

Top-down pixel-art animals readable at gameplay zoom, each with an idle, a walk
cycle (the visible "animals behave" payoff), and a crossing animation. Sizes are
sprite footprints (not hitboxes); larger-bodied species read bigger.

| Species | sprite_set | Footprint (px) | Animations | Distinguishing read | Priority |
|---|---|---|---|---|---|
| Grizzly bear | `grizzly_bear` | 28×28 | idle, walk, cross | bulky brown, shoulder hump | P0 |
| Elk | `elk` | 26×30 | idle, walk, cross | tan body, antlers (bull) | P0 |
| Pronghorn | `pronghorn` | 22×24 | idle, walk(fast), cross | tan/white, black horns | P0 |
| Mountain caribou | `mountain_caribou` | 26×30 | idle, walk, cross | grey-brown, broad antlers | P0 |
| Wolverine | `wolverine` | 18×18 | idle, walk, cross | dark, low, pale stripe | P0 |
| Gray wolf | `gray_wolf` | 22×22 | idle, walk(pack), cross | grey, lean, long legs | P0 |
| Canada lynx | `canada_lynx` | 18×18 | idle, walk, cross | grey, ear tufts, big paws | P0 |
| Bighorn sheep | `bighorn_sheep` | 22×22 | idle, walk, cross | brown, curled horns (ram) | P0 |

Each species also needs: a **death frame/fade** (gentle, non-gory — the cozy
pillar; a soft fade-out, not blood) and a small **portrait** (64×64) for the
inspect panel and wiki. Seasonal coat variants for migratory/elevational species
are P2 (e.g. lynx paler in winter).

---

## 6. Connectivity overlay / heatmap rendering

- Soft-edged heatmap over terrain at **~40% opacity**, using the **orange→teal**
  data axis (§2). Rendered as a smooth field interpolating per-patch cached
  connectivity values (per-tile is a rendering interpolation only;
  [ADR 0004](../../docs/adr/0004-connectivity-patch-adjacency-graph.md)).
- The **three most fragmented segments in view** get a subtle slow pulse
  (opacity/limited bloom oscillation, ~1.5s period). No numeric labels on the
  overlay; numbers live in the hover tooltip ([[ui-ux-spec]] §5).
- **Colorblind safety:** the ramp is monotonic in lightness, so fragmentation
  also reads as light→dark independent of hue; verify against deuteranope/
  protanope/tritanope simulation before sign-off. A settings toggle can swap to a
  texture-pattern overlay (hatch density = fragmentation) as a non-colour
  fallback.

---

## 7. Locked sub-area treatment

Locked sub-areas ([[crossing-location-selection]] P0) are rendered:

- **Desaturated** to ~25% chroma and slightly darkened with the locked tint
  (`#6B6E73`), so they read clearly as "not yet" rather than "never."
- A **lock badge** (simple padlock glyph) centred on the sub-area at world zoom.
- **No ecological overlay** at all (locked areas show terrain only until
  unlocked — the map-fog rule). Zoom is blocked at the sub-area boundary with a
  soft edge vignette.
- On unlock (`sub_area_unlocked`), a brief **colour-bloom transition** restores
  full saturation — the visual reward beat paired with the unlock fanfare.

---

## 8. Seasonal terrain variants

Seasons visibly change the world ([[game-design-overview]] seasons). Required
seasonal variants (P1 unless noted):

| Terrain | Spring | Summer | Autumn | Winter |
|---|---|---|---|---|
| Forest (west larch) | green | green | gold (major moment) | bare/snow-dusted |
| Grassland/prairie | green | golden-tan | tan | snow patches |
| River | normal | normal | normal | **frozen (clears `is_hazardous`)** P0 |
| Wetland | flooded (spring melt) | reduced | reduced | frozen |
| Alpine meadow | wildflowers emerging | full bloom | fading | snow |
| River banks (flood) | **+1 tile hazard width (spring flood)** P0 | normal | normal | frozen |

Frozen-river and spring-flood variants are **P0** because they change
traversability and hazard extent (simulation, not just cosmetics). Others are P1
mood variants. A global seasonal colour-grade (warmer in autumn, cooler in
winter) is applied on top via shader to reduce per-tile variant count.

---

## 9. UI art

| Asset | Notes | Priority |
|---|---|---|
| HUD frames (budget, time, season ring, milestone) | parchment + earth palette | P0 |
| Habitat band swatches (4) | clay/sand/sage/teal per [[ui-ux-spec]] §8 | P0 |
| Relationship stage pips + partnership badge | grey-green→teal, gold badge | P0 |
| Placement preview states | green valid / red invalid | P0 |
| Lock badge, info icons, crossing-type icons | simple glyphs | P0 |
| Unlock colour-bloom + capstone celebration sequence | gold motes, Continental Connection | P1 |
| Entity/portrait frames | for nine entities + eight species | P1 |

---

## 10. Asset production summary (priority rollup)

- **P0 (Phase 1–2 playable):** core biome tiles, road/river/fence hazard tiles,
  three overpass biome variants (mid + ramp + construction), eight species
  (idle/walk/cross/death/portrait), connectivity heatmap shader, habitat band +
  stage UI swatches, placement-preview states, frozen-river & spring-flood
  variants, lock badge + desaturation.
- **P1:** seasonal mood variants, unlock colour-bloom + capstone sequence,
  entity/species portraits and frames, urban/building barrier variants.
- **P2:** secondary biome/transition tiles, seasonal species coat variants.

## Related

- [[ui-ux-spec]] — where each asset appears and how it behaves
- [[audio-design]] — cues paired with the visual feedback here
- [[crown-of-continent-zone-map]] — biome/tile archetype content brief
- [[wildlife-overpass-crossing]] — overpass variant requirement
- [ADR 0002](../../docs/adr/0002-hex-grid-topology.md), [ADR 0003](../../docs/adr/0003-crossing-tile-architecture.md)
