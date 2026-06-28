---
title: "UI/UX Specification"
date: 2026-06-17
tags: [design, system, ui]
status: active
---

## Purpose

This document specifies every screen and panel in Wildlife Crossing: their
layout (as wireframe descriptions), the input map for each, the global
interaction rules, and the visual treatments for the four relationship stages
and four habitat-quality bands. Its acceptance bar is that every P0 requirement
in [[crossing-location-selection]] and the wider PRD set has a corresponding UI
element, and that all four relationship stages and all four habitat bands have
defined visual treatments.

It implements the UI scenes named in [`architecture`](../../docs/architecture.md)
§1 and the heatmap/desaturation rendering finalised in
[[art-direction]]. Conventions: UI scenes inherit `BaseScreen`; signals are
connected in `_ready()`; panels obey the global rules in §2.

---

## 1. Screen inventory

| Screen / panel | Scene | Mode | Source requirement |
|---|---|---|---|
| Persistent HUD (budget, time controls, season calendar, milestone track, build toolbar) | `BudgetHUD`, `TimeControls`, `SeasonCalendar`, `MilestoneTrack`, `BuildPalette` toolbar entry | always on during play | game-design-overview (economy, seasons, milestones) |
| World map + selection mode | `WorldMap` (selection) via `WorldMapController` | crossing-location-selection mode | crossing-location-selection P0 |
| Connectivity overlay | `ConnectivityOverlay` | segment zoom, selection mode | crossing-location-selection P0 |
| Confirmation panel | `ConfirmPanel` | on segment click | crossing-location-selection P0 |
| Build palette (construction step) | `BuildPalette` | after location confirmed | wildlife-overpass-crossing |
| Patch / tile inspect | `InspectPanel` | on click of patch/tile/crossing | game-design-overview (habitat), overpass P1 (usage) |
| Entity profile + trust checklist | `EntityProfile` | from sub-area info or HUD | governmental-permissions |
| Sub-area info panel | part of `WorldMapController` | hover/select sub-area | sub-areas, governmental-permissions |
| Information shop | part of `InspectPanel` / sub-area panel | on demand | game-design-overview (information) |
| Land acknowledgment / opening | `BaseScreen` opening sequence | game start | cultural-narrative-design |

---

## 2. Global interaction rules

These apply to every panel via `BaseScreen` unless a panel overrides them:

1. **Escape** exits the current transient mode. In selection mode, Escape from
   *any* state (world map, sub-area zoom, hover, confirmation panel) returns to
   default map interaction and initiates no crossing
   ([[crossing-location-selection]] P0).
2. **Click-outside-closes.** Clicking anywhere outside an open panel closes it.
   For the confirmation panel this is equivalent to Cancel and returns to
   hover-selection mode; the panel never blocks map panning via keyboard or
   edge-scroll (resolved decision in the consolidated PRD).
3. **Pause-safe.** All build, information, and panel actions work while the
   simulation is paused; opening a panel never force-unpauses.
4. **Non-blocking.** Panels are non-modal overlays on a `CanvasLayer`; the map
   continues to pan/zoom beneath them.
5. **Legibility first.** No action that spends budget or commits a location
   occurs without a visible confirmation affordance and the current budget shown.

### Input map (default + selection mode)

| Input | Default mode | Selection mode |
|---|---|---|
| Mouse drag / edge / arrow keys | Pan map | Pan map (never blocked by panel) |
| Scroll wheel / +,− | Zoom map | Continuous zoom (drives segment threshold) |
| Left click | Inspect patch/tile/crossing | Select hovered valid segment → ConfirmPanel |
| Hover | Tooltip on entities | Highlight valid segment; sub-area summary at world zoom |
| `Esc` | Close open panel | Exit selection mode entirely |
| `Space` | Toggle pause | Toggle pause |
| `1` `2` `3` | Set 1× / 2× / 4× | Set 1× / 2× / 4× |
| Toolbar "Add crossing" | Enter selection mode | — |

---

## 3. Persistent HUD

Wireframe (anchored regions; nothing covers the map centre):

```
┌───────────────────────────────────────────────────────────────┐
│ [Budget HUD]                                  [Season Calendar] │  top corners
│  ⛁ 50,000  ▲ +1,200 last donation              ☀ Summer · Y1 D34│
│                                                                 │
│                                                                 │
│                         (MAP / WORLD)                           │
│                                                                 │
│                                                                 │
│ [Build Toolbar]                              [Milestone Track]  │  bottom corners
│  ⛏ Add crossing   🔍 Inspect   🛈 Info        ◇ Corridor: 3/12  │
│                  [⏸ ▶ 1× 2× 4×  Time controls]                 │  bottom centre
└───────────────────────────────────────────────────────────────┘
```

- **Budget HUD** (`BudgetHUD`): current balance, last donation delta (briefly
  highlighted on `donation_received`), and a low-budget hint when below the
  cheapest action. Updates on `budget_changed`.
- **Time controls** (`TimeControls`): pause / 1× / 2× / 4×. Current speed is
  highlighted; pause is always available and never penalised.
- **Season calendar** (`SeasonCalendar`): current season + year/day, and a small
  four-segment ring showing the year's progress so the player can *plan before a
  migration season* (the PRD's core temporal-strategy aid). Always visible.
- **Milestone track** (`MilestoneTrack`): compact "Corridor N/12" with a click to
  open the full track; capstone shown as a distinct gold node.
- **Build toolbar**: "Add crossing" (enters selection mode), "Inspect", "Info".

---

## 4. World map + selection mode

Entered by the toolbar "Add crossing" action. A single continuous-zoom map; no
discrete level screens ([[crossing-location-selection]] P0).

**World zoom (full Y2Y).** All twelve sub-areas visible. Unlocked sub-areas
render in full colour; **locked sub-areas are desaturated with a lock badge**
(treatment specified in [[art-direction]]). Hovering a sub-area shows a summary
card (name, available segments, existing crossings; P1). Locked sub-areas cannot
be zoomed past their boundary.

```
   Y2Y world view (12 sub-areas, S→N)            Sub-area hover card
   ┌──────────────────────────────┐              ┌─────────────────────┐
   │  ⌞12⌝  desaturated 🔒        │              │ Crown of the        │
   │  ⌞11⌝🔒  ⌞10⌝🔒              │              │ Continent  🔒       │
   │     ⌞9⌝🔒                     │              │ Ksanka Confederacy  │
   │  ⌞8⌝🔒  ⌞7⌝ (unlocked)       │   hover →     │ Stage: Engaged      │
   │  ⌞6⌝🔒  ⌞5⌝🔒                │              │ 14 segments · 0 ⛉   │
   │  ⌞4⌝🔒 ⌞3⌝🔒 ⌞2⌝🔒 ⌞1⌝🔒    │              └─────────────────────┘
   └──────────────────────────────┘
```

**Segment zoom.** When the on-screen hex tile reaches **≥16 px flat-to-flat**,
segment-level resolution activates (hysteresis: deactivates below 12 px to
prevent flicker — a single global named constant). The **connectivity overlay**
appears (§5). Hovering a valid road/barrier segment highlights it; hovering plain
terrain shows nothing. Only `is_impassable`/`is_hazardous` segments are
selectable.

---

## 5. Connectivity overlay

Visible only in selection mode at segment zoom; hidden on mode exit (confirm,
cancel, Escape) and below the zoom threshold.

- Soft-edged heatmap, **colorblind-safe two-hue gradient: warm orange
  (fragmented) → teal (well-connected)**, ~40% opacity over terrain.
- The three most fragmented segments in view get a **subtle slow pulse**.
- No numeric labels on the overlay; numbers live in the hover tooltip ("High
  fragmentation"; P1).
- Reads cached values from the patch-adjacency graph; never triggers a recompute
  ([ADR 0004](../../docs/adr/0004-connectivity-patch-adjacency-graph.md)).

Full gradient and accessibility detail are in [[art-direction]].

---

## 6. Confirmation panel

Opens on click of a highlighted segment ([[crossing-location-selection]] P0).

```
        ┌──────────────────────────────────────┐
        │ Trans-Canada Hwy · Bow Valley sector A │  segment label (P1 name, else coords)
        │ ────────────────────────────────────── │
        │ Connects two fragmented forest patches │  one-line connectivity note
        │ Budget: ⛁ 50,000   Cost: ⛁ 15,000      │  current budget + projected cost
        │ Existing crossings near here: 0         │  P1 crossing-count note
        │                                         │
        │            [ Cancel ]   [ Confirm ]     │
        └──────────────────────────────────────┘
```

- Shows segment label, current budget, a one-line connectivity note, and (P1)
  nearby-crossing count.
- **Budget gate:** if budget is below the minimum cost of any crossing, **Confirm
  is disabled** with a short explanatory note; the player can still browse.
- **Confirm** closes selection mode and passes `(segment, sub_area)` to the build
  palette/construction step (`location_confirmed`); construction opens
  immediately with the segment pre-loaded.
- **Cancel** dismisses the panel and restores hover-selection with the overlay
  still active.
- **Click-outside** = Cancel. **Escape** exits selection mode entirely.

---

## 7. Build palette (construction step)

Opens after a location is confirmed. The player tiles crossing tiles across the
segment's dangerous cells.

- Palette lists available crossing types; in v1 only **Overpass** is enabled,
  others shown disabled with a "coming soon" hint (data-driven; [ADR 0003](../../docs/adr/0003-crossing-tile-architecture.md)).
- Placement preview: **green** on a valid `is_hazardous`/`is_impassable` cell,
  **red** on invalid terrain (overpass PRD P0).
- A running cost readout updates as tiles are placed
  (`OVERPASS_COST_PER_TILE` × tiles); the segment highlights cells still needing
  coverage so the player can see when the span is complete.
- On completion of a full span, `crossing_completed` fires and the success
  feedback cue plays (audio in [[audio-design]], visual in [[art-direction]]).

---

## 8. Patch / tile inspect

Opens on click of a patch, tile, or crossing in default mode.

- **Patch:** habitat-quality **band label** (Poor/Fair/Good/Excellent), resident
  species (if a population survey was purchased; else "unknown"), and trend
  arrows. Exact numeric quality shows only after a habitat assessment purchase
  for the area — preserving the information-uncertainty loop.
- **Crossing tile:** usage counter (animals safely crossed; overpass P1), type,
  and biome variant.
- **Hazard tile:** terrain type and, if a movement corridor study was purchased,
  the mortality-hotspot indicator.

### Habitat band visual treatments (all four)

| Band | Score range | Label colour swatch | Inspect treatment |
|---|---|---|---|
| Poor | 0–25 | muted clay/orange | hatched fill, downward trend default |
| Fair | 26–50 | sand/amber | light fill |
| Good | 51–75 | sage green | solid fill |
| Excellent | 76–100 | deep teal-green | solid fill + subtle glow |

Band colours sit on the same orange→teal axis as the connectivity overlay so the
two reinforce each other; exact hex values in [[art-direction]].

---

## 9. Entity profile + trust checklist

Opened from a sub-area info panel or the HUD; one per governing entity
([[governmental-permissions]]).

```
   ┌───────────────────────────────────────────────┐
   │ Ksanka Confederacy (fictional)        🔒 area 6 │
   │ Relationship: ●●●○  Trusted                     │  stage indicator (4 stages)
   │ ───────────────────────────────────────────────│
   │ What they value:                                │  top-3 conditions w/ bars
   │  Population recovery events   ▓▓▓▓▓▓░░░  72%     │
   │  Species diversity            ▓▓▓▓░░░░░  41%     │
   │  Stewardship in adjacent land ▓▓▓▓▓▓▓░░  78%     │
   │ ───────────────────────────────────────────────│
   │ Exact weights: [ Buy liaison briefing ⛁1,500 ]  │  reveals precise weights
   └───────────────────────────────────────────────┘
```

- Shows the **relationship stage**, the entity's **top three priority
  conditions** with progress bars (always legible), and the briefing purchase to
  reveal exact metric weights.
- Before purchase, weights are shown qualitatively; after, as exact percentages.
- First Nations entities display the in-game "fictional, region-specific" framing
  and link to the land acknowledgment (content in [[narrative-content-plan]]).

### Relationship stage visual treatments (all four)

| Stage | Trust quartile | Pip indicator | Accent |
|---|---|---|---|
| Introduced | 0–25 | ●○○○ | neutral grey-green |
| Engaged | 26–50 | ●●○○ | warming amber |
| Trusted | 51–75 | ●●●○ | sage green |
| Partnered | 76–100 | ●●●● | full teal-green + partnership badge |

Updates on `trust_changed`; crossing a quartile plays the stage-advance cue
([[audio-design]]). Reaching Partnered (or the unlock threshold) fires
`sub_area_unlocked` and the unlock beat.

---

## 10. Sub-area info panel

Shown when a sub-area is selected on the world map.

- Name, controlling entity (with link to its Entity Profile), lock state.
- For names of Indigenous origin, an **acknowledgment note** of the origin and
  the real traditional territories the region overlaps (content and review in
  [[narrative-content-plan]]; [[sub-areas]] naming rule).
- Available information products for the area (habitat assessment, population
  survey, corridor study) with prices and purchased/!purchased state.

---

## 11. Opening + land acknowledgment

At first launch the game presents a brief **land acknowledgment** (the Y2Y
corridor passes through 75+ Indigenous peoples' traditional territories) and
frames the player as an outsider coordinator for a fictional conservation
non-profit seeking partnership. Skippable after first view; re-readable from a
credits/about screen. Exact text and its review gate are in
[[narrative-content-plan]].

---

## 12. P0 → UI element coverage

| P0 requirement | UI element |
|---|---|
| "Add crossing" tool opens Y2Y selection mode | Build toolbar (§3) → WorldMapController (§4) |
| Y2Y world map shows all sub-areas | World zoom (§4) |
| Continuous zoom, no transitions | Continuous-zoom map (§4) |
| Locked/unlocked treatment, zoom blocked | Desaturated + lock badge (§4, [[art-direction]]) |
| Connectivity overlay at segment zoom | ConnectivityOverlay (§5) |
| Segment hover highlight (valid only) | Hover highlight (§4) |
| Confirmation panel (segment, budget, note) | ConfirmPanel (§6) |
| Budget gate disables Confirm | Budget gate (§6) |
| Confirm → construction with segment | Confirm action (§6) → BuildPalette (§7) |
| Cancel returns to selection w/ overlay | Cancel (§6) |
| Escape exits selection mode | Global rule (§2), tested any-state |
| Click-outside closes panel | Global rule (§2) |
| Overpass placement validation (red preview) | BuildPalette preview (§7) |
| Crossing usage visible | InspectPanel crossing (§8) |
| Trust progress legible | EntityProfile checklist (§9) |
| Four relationship stages treated | §9 table |
| Four habitat bands treated | §8 table |

## Related

- [[art-direction]] — exact palette, gradient hex values, sprite specs
- [[audio-design]] — cues triggered by the UI events here
- [[narrative-content-plan]] — entity briefs, acknowledgment text
- [[crossing-location-selection]], [[governmental-permissions]], [[sub-areas]]
- [`architecture`](../../docs/architecture.md) — the UI scenes and their signals
