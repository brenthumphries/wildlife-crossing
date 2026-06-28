---
title: "PRD — Crossing Location Selection Interface"
date: 2026-06-06
tags: [prd, system, infrastructure, ui]
status: draft
---

## Problem statement

Before a player can build a wildlife crossing, they need to decide *where* one
is needed. The game's map spans the full Yukon to Yellowstone (Y2Y) corridor —
a vast landscape with roads, barriers, and potential crossing sites distributed
across many geographic sub-areas. Without a structured location selection
workflow, the player either places crossings arbitrarily — losing the ecological
reasoning that makes the game meaningful — or is overwhelmed by the complexity
of evaluating a large world. This interface covers the full geographic navigation
workflow: from the Y2Y world map, through sub-area navigation, to commitment of
a specific road or barrier segment — after which the construction step begins.

---

## Goals

1. **Location selection is ecologically informed.** The player can see habitat
   connectivity data overlaid on the map while selecting a crossing site, so
   their choice reflects real fragmentation problems rather than guesswork.
2. **Budget is visible before commitment.** The player can see their remaining
   budget before confirming a location, preventing a commit-then-can't-build
   failure state.
3. **The selection step is fast and non-blocking.** A player should be able to
   navigate to a sub-area, identify a segment, evaluate it, and confirm in a
   few steps. The interface does not gate progress behind complex sub-menus.
4. **The selected location correctly seeds the downstream workflow.** Confirming
   a location passes the right context (which segment in which sub-area) to the
   specific construction step, with no ambiguity about what was chosen.
5. **Locked areas are legible without frustration.** Sub-areas the player cannot
   yet build in are clearly marked as locked, communicating "not yet" rather than
   "never". The player understands which areas are accessible without trial and
   error.

---

## Non-goals

- **No specific tile placement in this interface.** Placing individual overpass
  tiles is handled by the existing crossing construction workflow
  (see [[wildlife-overpass-crossing]]). This interface ends at location
  confirmation.
- **No automated site suggestions in v1.** The game will not highlight
  recommended locations or rank candidate sites. The player browses and decides.
  Smart suggestions are a future enhancement.
- **No multi-site comparison.** The player selects one location at a time. A
  side-by-side comparison view, pinning candidate sites, or planning multiple
  crossings simultaneously is out of scope.
- **No crossing type selection here.** The player chooses *where*, not *what*.
  Crossing type (overpass vs underpass vs corridor) is decided in the
  construction step, not during location selection.
- **No road or barrier creation.** This interface is read-only with respect to
  the terrain. The player selects from existing roads and barriers.
- **No sub-area boundary definition in this PRD.** How Y2Y is divided into
  sub-areas — their boundaries, names, and count — is defined in a separate PRD.
  This interface treats sub-areas as pre-defined.
- **No governmental permission mechanics in this PRD.** The system by which
  governmental entities grant construction permission to unlock sub-areas is
  defined in a separate PRD. This interface reflects locked/unlocked state but
  does not drive it.

---

## Proposed solution

The crossing location workflow begins at the Y2Y world map — the game's
top-level geographic view, opened when the player activates the "Add crossing"
action from the build toolbar. The player scrolls and zooms continuously, as on
a geographic map, to navigate from the broad Y2Y view into a specific sub-area.
Sub-areas the player has not yet unlocked are visible on the map but treated as
locked: they are visually desaturated with a lock indicator, and cannot be
entered.

Once the player has zoomed sufficiently into an unlocked sub-area, the map
transitions to segment-level resolution. A habitat connectivity overlay appears,
visually distinguishing well-connected areas from fragmented ones. Road and
barrier segments are individually identifiable at this zoom level; hovering over
a valid segment highlights it. On click, a confirmation panel appears showing
the selected segment, current budget, and a brief connectivity summary. The
player confirms to commit the location and advance to the construction step, or
cancels to reselect or navigate elsewhere.

---

## Key mechanics / rules

1. **The tool is triggered from the build toolbar.** A dedicated "Add crossing"
   action in the toolbar opens the Y2Y world map view and puts the game into
   crossing-location-selection mode. This is the sole entry point for the
   geographic navigation workflow in v1.

2. **Y2Y is the game's world map.** The Yukon to Yellowstone corridor is the
   full geographic extent of the game. The top-level view in
   crossing-location-selection mode shows this entire area.

3. **Y2Y is subdivided into sub-areas of roughly equal geographic size.** The
   boundaries, names, and count of sub-areas are defined in a separate PRD. This
   interface treats sub-areas as pre-defined regions the player navigates to
   and into.

4. **Navigation is a continuous zoom on a single map.** The player scrolls and
   zooms without discrete level-transition screens. Zooming into a sub-area
   progressively reveals more detail until individual road and barrier segments
   are identifiable. Zooming back out returns to the Y2Y overview.

5. **Sub-areas have locked and unlocked states.** Locked sub-areas are visible
   in the world map but cannot be entered or zoomed into beyond the sub-area
   boundary level. They are rendered with a desaturated visual treatment and a
   lock indicator. Unlocked sub-areas can be zoomed into freely. The lock/unlock
   state is driven by the governmental permissions system (see forthcoming
   governmental permissions PRD).

6. **A "segment" is the smallest selectable unit of road or barrier.** A segment
   is a pre-defined section of roadway or barrier that is: (a) large enough to
   include all tiles where crossing infrastructure will be placed (as defined in
   [[wildlife-overpass-crossing]]) plus surrounding space for fencing or other
   animal-guidance constructs; and (b) small enough that the crossing
   construction workflow can operate on it without scope ambiguity. Segment
   boundaries are fixed in the game's world data and are never adjusted by the
   player — not during location selection nor at any other time.

7. **The connectivity overlay activates at segment-zoom level.** When the player
   has zoomed into an unlocked sub-area to segment-level resolution, the map
   renders a habitat connectivity layer that visually distinguishes fragmented
   areas from well-connected ones. The overlay is off by default and only visible
   during active selection mode at this zoom level.

8. **Only roads and barrier segments are selectable.** At segment zoom level, the
   cursor only registers hits on segments flagged `is_impassable` or
   `is_hazardous` (using the same tile properties defined in
   [[wildlife-overpass-crossing]]). Hovering over plain terrain shows no
   selection highlight.

9. **A hover highlight previews the selection.** When the cursor is over a valid
   segment, the road or barrier tiles under consideration are highlighted. The
   highlight makes clear which segment will be committed on click.

10. **Clicking a valid segment opens a confirmation panel.** The panel shows:
    - Which segment was selected (location label or coordinates)
    - Current budget remaining
    - A one-line connectivity note (e.g. "Connects two fragmented habitat zones")
    The panel has two actions: **Confirm** and **Cancel**.

11. **Confirming passes context to the construction step.** On confirmation, the
    selected segment reference (including its sub-area) is passed to the crossing
    construction workflow. The construction step opens immediately; the player
    does not return to the map between location selection and construction.

12. **Cancelling returns to selection mode.** If the player cancels the
    confirmation panel, they remain in the sub-area with the hover-selection
    state and overlay still active.

13. **Pressing Escape exits selection mode entirely.** Escape from any state
    (world map, sub-area zoom, hover state, or confirmation panel) returns the
    player to the default map interaction mode. No crossing is initiated.

14. **Insufficient budget disables confirmation.** If the player's budget is zero
    or below the minimum cost of any crossing, the Confirm button is disabled and
    a brief note explains why. The player can still browse locations.

---

## User stories

**As a player**, I want to see the full Y2Y map when I activate the crossing
tool, so that I can orient myself geographically before committing to an area.

**As a player**, I want to zoom continuously from the world view into a specific
road or barrier segment, so that navigating to a crossing location feels natural
and spatial rather than menu-driven.

**As a player**, I want locked sub-areas to be clearly marked, so that I
understand which parts of Y2Y I can work in without having to discover
restrictions by trial and error.

**As a player**, I want to see where my habitat is most fragmented while I
choose a crossing location, so that I place crossings where they will have the
most ecological impact.

**As a player**, I want to see my remaining budget before committing to a
location, so that I do not start a construction project I cannot finish.

**As a player**, I want to hover over road segments and get a clear preview of
what I'm about to select, so that I don't accidentally commit to the wrong
location.

**As a player**, I want to cancel out of the confirmation panel without losing
my place, so that I can reconsider my choice without being punished for
hesitating.

**As a player**, I want location selection to lead directly into construction,
so that the workflow feels continuous rather than fragmented across multiple
menus.

---

## Requirements

### Must-have (P0)

- **Crossing location tool in build toolbar.** An "Add crossing" action exists
  in the toolbar and activates crossing-location-selection mode, opening the Y2Y
  world map view.
  *Acceptance: Clicking the toolbar action opens the Y2Y world map in
  crossing-location-selection mode.*

- **Y2Y world map view.** The top-level view shows the full Y2Y corridor. All
  sub-areas — locked and unlocked — are visible at this zoom level.
  *Acceptance: The full Y2Y corridor is visible and sub-areas are identifiable
  when the tool is first activated.*

- **Continuous zoom navigation.** The player can scroll and zoom from the Y2Y
  world view into any unlocked sub-area without discrete level transitions.
  Zooming out from a sub-area returns to the world view.
  *Acceptance: Smooth zoom between world-level and segment-level resolution with
  no loading screens or mode-switch prompts.*

- **Sub-area locked/unlocked visual treatment.** Locked sub-areas are visually
  distinct from unlocked ones (desaturated treatment and lock indicator).
  Zooming into a locked sub-area is blocked at the sub-area boundary.
  *Acceptance: Locked sub-areas are visually identifiable; zoom stops at the
  sub-area boundary for locked areas and shows a locked-state indicator.*

- **Connectivity overlay at segment zoom level.** During selection mode at
  segment-level zoom, the map renders a habitat connectivity layer that visually
  distinguishes fragmented areas from well-connected ones. The overlay is hidden
  outside selection mode and below the segment zoom threshold.
  *Acceptance: Overlay appears when zoomed to segment level in an unlocked
  sub-area, and disappears on mode exit (confirm, cancel, or Escape).*

- **Segment hover highlight.** Hovering the cursor over a valid road or barrier
  segment at segment zoom level highlights it. Non-valid tiles show no highlight.
  *Acceptance: Highlight appears over `is_impassable` and `is_hazardous` tiles
  only; plain terrain produces no response.*

- **Confirmation panel.** Clicking a highlighted segment opens a panel showing
  selected segment, current budget, and a connectivity note. Panel has Confirm
  and Cancel buttons.
  *Acceptance: Panel appears on click of valid segment; displays correct budget
  value; both buttons respond to input.*

- **Budget gate.** If budget is insufficient to build any crossing, the Confirm
  button is disabled with an explanatory note.
  *Acceptance: With zero budget, Confirm is non-interactive and a budget note is
  visible in the panel.*

- **Confirm advances to construction.** Confirming the panel closes selection
  mode, passes the selected segment (and its sub-area) to the construction
  workflow, and opens the construction step.
  *Acceptance: After confirm, the construction workflow opens with the correct
  segment pre-selected.*

- **Cancel returns to selection.** Cancelling the panel dismisses it and
  restores hover-selection mode in the sub-area with the overlay still active.
  *Acceptance: After cancel, cursor is back in hover-selection state with the
  overlay still active.*

- **Escape exits selection mode.** Pressing Escape at any point during selection
  mode returns to default map interaction. No crossing is created.
  *Acceptance: Escape from any state (world map, sub-area zoom, hover state, or
  confirmation panel) exits selection mode entirely.*

### Nice-to-have (P1)

- **Connectivity score on hover.** Hovering over a segment shows a brief numeric
  or qualitative connectivity score (e.g. "High fragmentation") in a tooltip,
  giving the player more precise information before clicking.

- **Segment label.** The confirmation panel identifies the selected segment with
  a human-readable name (e.g. "North Highway, sector 4") rather than raw
  coordinates.

- **Crossing count indicator.** The confirmation panel notes how many crossings
  already exist on or near the selected segment.

- **Sub-area summary on hover.** Hovering over a sub-area in the world map view
  shows its name and a brief summary (e.g. number of available segments, existing
  crossings), helping the player decide where to zoom in.

### Future considerations (P2)

- **Suggested locations.** The game highlights top-N candidate segments ranked by
  connectivity impact, giving players guidance without removing agency.
- **Site pinning.** The player can pin candidate locations to compare before
  committing.
- **Multi-crossing planning mode.** Plan several crossing locations in sequence
  before entering construction on any of them.
- **Sub-area progress summary.** A view showing, per sub-area, crossings built
  vs. high-priority segments remaining.

---

## Open questions

- ~~**How is "segment" defined for selection purposes?**~~
  *Resolved: A segment is a pre-defined section of roadway or barrier large
  enough to include all tiles where crossing infrastructure will be placed (as
  defined in [[wildlife-overpass-crossing]]) plus surrounding space for fencing
  and animal-guidance constructs, and small enough that the construction workflow
  can operate without scope ambiguity.*

- ~~**What does the connectivity overlay look like?**~~
  *Resolved: a soft-edged heatmap using a colorblind-safe two-hue gradient — warm
  orange (fragmented) to teal (well-connected) — rendered at ~40% opacity over
  terrain. The three most fragmented segments in view get a subtle slow pulse. No
  numeric labels on the overlay itself; numbers live in the hover tooltip (P1).*

- ~~**Does the confirmation panel block map interaction?**~~
  *Resolved: clicking anywhere outside the panel closes it (equivalent to Cancel)
  and returns to hover-selection mode. The panel never blocks map panning via
  keyboard/edge-scroll.*

- ~~**How is habitat connectivity computed?**~~
  *Resolved: connectivity is computed on a patch-adjacency graph (patches as
  nodes, safe links as edges), pre-computed per sub-area at load and incrementally
  recomputed on graph-changing events (crossing completed, season change). Never
  per-frame. The overlay reads cached values.*

- ~~**What zoom threshold triggers segment-level resolution?**~~
  *Resolved: segment-level resolution activates when the on-screen tile size
  reaches ≥16 px, with hysteresis (deactivates below 12 px) to prevent flicker at
  the boundary. For hex tiles, tile size is measured as the flat-to-flat width
  (the shorter axis). The threshold is a single global named constant, identical
  across sub-areas.*

- **How are sub-area boundaries, names, and count defined?** Covered by
  [[sub-areas]]. This interface assumes sub-areas are pre-defined and their data
  is available at runtime.

- **How are governmental permissions earned and reflected in sub-area lock
  state?** Covered by [[governmental-permissions]]. This interface reads lock
  state but does not drive it.

---

## Success criteria

**The feature is working when:**

- A player activating the crossing tool sees the full Y2Y map and can zoom
  continuously from world view to segment level within an unlocked sub-area.
- Locked sub-areas are visually distinct and cannot be entered; unlocked
  sub-areas are fully navigable.
- A player can hover, click, review the confirmation panel (including current
  budget), and either confirm or cancel — all without leaving the map or opening
  a separate screen.
- Confirming a location immediately opens the construction workflow with the
  correct segment pre-loaded, requiring no re-selection.
- A player with zero budget sees a clear explanation of why they cannot confirm,
  rather than a silent failure.

**Stretch indicator:**

- A player new to the game, seeing the world map for the first time, can navigate
  to an unlocked sub-area, identify a fragmented segment using the connectivity
  overlay, and place a crossing there without instruction.

---

## Related

- [[wildlife-overpass-crossing]] — the construction step this interface feeds into
- [[game-design-overview]]
- [[sub-areas]] — defines Y2Y sub-area boundaries, names, and count
- [[governmental-permissions]] — defines how sub-area locks are earned
