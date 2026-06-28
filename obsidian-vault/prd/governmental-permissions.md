---
title: "PRD — Governmental Permissions"
date: 2026-06-06
tags: [prd, system, progression, permissions]
status: draft
---

## Problem statement

The player cannot build crossings everywhere in Y2Y from the start. Sub-areas
are locked until the relevant governmental entity grants permission for
construction to proceed. Without a defined system for how permission is sought,
how it is earned, and how it is communicated to the player, the progression
system has no mechanical foundation — the world map simply has locked areas
with no path to opening them. This PRD defines the gameplay mechanics of the
governmental permissions system: which entities control which sub-areas, what
actions earn their consent, and how that consent is reflected in the game.

The cultural and narrative design of how those entities — First Nations in
particular — are represented is a separate concern, covered in
[[cultural-narrative-design]].

---

## Goals

1. **Unlocking new sub-areas feels earned, not arbitrary.** Permission is granted
   in response to demonstrated ecological impact — crossings built, populations
   recovered, habitat connectivity improved. The player understands the
   connection between their actions and the gates opening.
2. **Each governmental entity has a distinct character.** Different entity types
   (government agencies, First Nations, other jurisdictions) have different
   priorities and respond to different kinds of evidence of stewardship. This
   creates strategic variety in how the player pursues unlocks.
3. **Progress toward permission is legible.** The player can see how close they
   are to earning permission from a given entity, so they can make informed
   decisions about where to focus effort.
4. **The system paces the game well.** Early sub-areas are accessible with modest
   effort. Later sub-areas require sustained demonstrated impact. The curve
   should feel like escalating opportunity, not a grind.
5. **Locked sub-areas feel like meaningful geography, not arbitrary gates.**
   The entity controlling a locked sub-area should make geographic and narrative
   sense — a federal agency for a national park, a First Nation for traditional
   territory, a state government for a highway corridor.

---

## Non-goals

- **No cultural or narrative design in this PRD.** How First Nations and other
  entities are portrayed, what dialogue or storytelling accompanies the
  permission process, and how the game handles cultural sensitivity are all
  covered in [[cultural-narrative-design]].
- **No sub-area geography in this PRD.** Which sub-areas exist and where their
  boundaries fall is defined in [[sub-areas]].
- **No crossing construction mechanics in this PRD.** What the player builds to
  demonstrate impact is defined in [[wildlife-overpass-crossing]] and future
  crossing type PRDs.

---

## Proposed solution

Nine entities govern the twelve sub-areas (see the [[sub-areas]] table for the
sub-area → controlling-entity mapping). Each entity has a Trust score (0–100)
fed by weighted, measurable metrics that differ by entity type. Reaching the
trust threshold triggers an unlock event: a short narrative beat, the sub-area
unlocking on the world map, and a one-time donation bonus. Players learn what an
entity values through the sub-area info panel and an entity profile screen, with
exact metric weights available via the "community liaison briefing" information
purchase (defined in [[game-design-overview]]).

---

## Key mechanics / rules

### Entity roster

Nine entities govern the twelve sub-areas:

- **2 federal parks/forests agencies** (US, Canada) — value usage data and
  visitor-safe outcomes: crossing usage counts, reduced road mortality.
- **2 provincial governments / transport authorities** (BC, state DOTs) —
  value infrastructure metrics: crossings completed, road mortality reduction
  on their corridors.
- **2 territorial governments** (Yukon, NWT) — value sustained stewardship:
  total active crossings and population stability over time.
- **3 First Nations partnerships** (fictional, region-specific — see
  [[cultural-narrative-design]]) — value demonstrated ecological outcomes and
  respect: population recovery events, species diversity, stewardship quality in
  adjacent sub-areas the player already works in, and acceptance of joint
  stewardship invitations (in-game events).

### Unlock mechanics

Each entity has a **Trust score (0–100)**, fed by weighted, measurable metrics
(weights differ per entity as above; exact weights revealed via the community
liaison briefing purchase). Reaching the threshold (default 100) triggers the
unlock event: a short narrative beat, the sub-area unlocking on the world map,
and a one-time donation bonus.

Relationship stages are qualitative: **Introduced → Engaged → Trusted →
Partnered** (quartiles of the trust score). The per-entity panel shows the stage
plus a checklist of that entity's top three priority conditions with progress
bars — progress is always legible.

### Starting state

**Central Canadian Rockies (sub-area 7) is unlocked at game start.** The Bow
Valley's real wildlife overpasses are the most famous in the world; starting
where crossings demonstrably work is geographically motivated, educational, and
gives the tutorial a true story to tell. **Crown of the Continent (6)** is the
intended first unlock with a deliberately low threshold, introducing the First
Nations partnership mechanic early. The remaining ten unlock in any order; trust
thresholds scale northward/southward from the start so the pacing curve feels
like escalating opportunity.

### Revocation

**Permission, once earned, is never revoked.** Re-locking would violate the cozy
pillar. Neglect of an unlocked area instead slows trust growth with *other*
entities ("stewardship quality" metrics dip) — a natural consequence, not a
punishment.

---

## Resolved questions

- ~~**Which sub-areas are accessible at game start?**~~
  *Resolved: Central Canadian Rockies (Bow Valley — real famous overpasses) is
  unlocked at start; Crown of the Continent is the designed first unlock with a
  low threshold.*

- ~~**How are governmental permissions earned mechanically?**~~
  *Resolved: a per-entity Trust score (0–100) fed by weighted, measurable metrics
  (weights differ by entity type); reaching the threshold (default 100) triggers
  the unlock.*

- ~~**How does the player learn which entity controls a locked sub-area and what
  they care about?**~~
  *Resolved: the sub-area info panel and an entity profile screen; exact metric
  weights are revealed via the "community liaison briefing" purchase (see
  [[game-design-overview]]).*

- ~~**Can permission be revoked?**~~
  *Resolved: never. Neglect of an unlocked area instead slows trust growth with
  other entities, rather than re-locking — consistent with the cozy pillar.*

- ~~**How many distinct governmental entities exist in the game?**~~
  *Resolved: nine, across the twelve sub-areas — 2 federal, 2 provincial/state,
  2 territorial, and 3 First Nations partnerships.*

- ~~**How is progress toward a permission communicated to the player?**~~
  *Resolved: qualitative relationship stages (Introduced → Engaged → Trusted →
  Partnered) plus a per-entity checklist of the top three priority conditions
  with progress bars.*

---

## Success criteria

**This PRD is complete when:**

- Every sub-area has a named governmental entity whose consent governs access.
- The unlock conditions for each entity type are specified and measurable.
- The player-facing representation of permission progress is defined.
- The starting state of the game (which sub-areas are unlocked) is specified
  and justified.

---

## Related

- [[sub-areas]] — defines the geographic regions whose access this system gates
- [[crossing-location-selection]] — the interface that reflects locked/unlocked
  state
- [[cultural-narrative-design]] — the narrative and cultural layer on top of this
  mechanical system
- [[game-design-overview]]
