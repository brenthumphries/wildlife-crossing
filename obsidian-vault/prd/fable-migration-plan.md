---
title: "Migration Plan — Decompose fable-wildlife-crossing into source PRDs"
date: 2026-06-14
tags: [plan, prd, migration]
status: draft
---

## Goal

`fable-wildlife-crossing.md` is a consolidated master PRD that merged the six
source PRDs and added new content plus decisions that resolve every open
question. This plan migrates each idea in fable back out to the appropriate
source PRD (or a new home), so the source PRDs become current and authoritative
again.

**No content is deleted.** Migrated material is marked in fable with
`~~strikethrough~~` plus a pointer to its new location. Nothing is changed yet —
this is the plan only.

---

## Decisions driving this plan (confirmed)

1. **No new *system* PRDs.** Detailed specs that today live only as conceptual
   paragraphs in `game-design-overview` (habitat quality model, species roster +
   schema, economy/donations, seasons/time) are **folded into
   `game-design-overview`**, expanding its existing sections.
2. **Refinements migrate.** Where fable has an improved version of a section that
   already exists in a source PRD (Vision, Pillars, Loop, How systems interact),
   the refined version is migrated non-destructively into that PRD.
3. **One new file only.** The "Design documentation generation requirements"
   section moves to a new **`docs/` planning doc** (not a PRD), living with the
   technical docs.
4. **Open questions get resolved in place.** When a decision migrates into a
   destination PRD, that PRD's corresponding open question is marked resolved
   with the answer (matching how the source PRDs already mark resolved questions
   with `~~...~~` + a *Resolved:* note).

---

## The only new document required

| New file | Type | Source in fable | Why new |
|---|---|---|---|
| `docs/design-documentation-plan.md` | Planning doc (not a PRD) | "Design documentation generation requirements" (the 10 design docs, their contents, locations, acceptance criteria) + the "Generation constraints" note | This is a meta-plan for producing design docs, not a product requirement. It belongs in `docs/` per repo conventions, not in `obsidian-vault/prd/`. Every existing PRD already has a home for its own content; this is the one fable section with no existing destination. |

Everything else maps to one of the six existing PRDs.

---

## Migration map by destination

### → `game-design-overview.md` (GDO)

GDO is the anchor "full shape of the game" doc, so it absorbs the cross-cutting
refinements and the system specs that have no dedicated PRD.

| Fable section | Action in GDO | Open question resolved |
|---|---|---|
| Vision | Update Vision with the refined framing: player as coordinator for a fictional conservation non-profit; explicit Y2Y org grounding; add the **Platform and stack** paragraph (Godot 4, GDScript, desktop, single-player, GUT). | — |
| Design pillars | Replace with fable's tightened four-pillar wording (substantively identical). | — |
| Core gameplay loop | Adopt fable's 6-step loop (adds explicit **Earn** and **Unlock** steps, First Nations partners, open-ended + milestone note). | — |
| World and geography → *The Y2Y world map* | Expand GDO's "Systems" world intro with the full extent detail (5 states, 2 provinces, 2 territories, 75+ Indigenous peoples; ~1.3M km²; Y2Y is the entire map). | — |
| Habitat system → *Habitat quality model* | Fold the full per-patch 0–100 formula (terrain base + size + connectivity − edge penalty), four qualitative bands, numerics-behind-assessment, population-viability rule into GDO's "Habitat and zoning" section. | **"How is habitat quality computed?"** → resolved |
| Species and animal simulation → *Launch roster* | Fold the 8-species table + the species JSON field list into GDO's "Species and animal simulation" section. | — |
| Species → *Movement and mortality* | Add to GDO species section (hex 6-directional pathfinding, zero-mortality crossings, preference affects probability). *(Note: the hex pathfinding decision is also the resolution for a WOC open question — see WOC.)* | — |
| Species → *Population model* | Fold per-patch population health + recovery-milestone events into GDO species section. | — |
| Economy → *Budget* | Expand GDO "Economy and budget": 50,000 start, deadlock-proof 500/month fundraising trickle. | — |
| Economy → *Donation formula* | Fold the monthly donation formula (base grant + usage × status weight × fragmentation multiplier + milestones). | **"What drives the donation amount?"** → resolved |
| Economy → *Information purchases* | Fold the information-products table (assessment / survey / corridor study / liaison briefing) into GDO's "Information and uncertainty." | — |
| Seasons and time | Fold pacing (1 season = 15 min at 1×; pause/1×/2×/4×; actions while paused) + seasonal effects into GDO "Seasons and time." | **"How is time paced?"** → resolved |
| Information and uncertainty | Fold "geographic clarity, ecological uncertainty" map-fog decision into GDO. | **"Is the map fogged at game start?"** → resolved |
| Player progression and win condition | Fold open-ended sandbox + Corridor Milestones + Continental Connection capstone into GDO. | **"What is the win condition?"** → resolved |
| How systems interact | Replace GDO's interaction table with fable's expanded version (adds animals-cross→quality recompute, milestones→trust, info→placement, First Nations partnership row). | — |

*Note:* GDO's "How are First Nations portrayed and consulted?" open question is
covered by CUL; its resolution is recorded there, with GDO's pointer updated.

---

### → `crossing-location-selection.md` (CLS)

| Fable section | Action in CLS | Open question resolved |
|---|---|---|
| World and geography → *Segments* | Refine CLS mechanic #6 (segment definition) with fable's wording (fixed in world data, never player-adjusted). | — |
| Crossing location selection interface (carry-forward paragraph) | Confirms all P0/P1/P2 remain in force — no change needed beyond resolving the four open questions below. | — |
| Decisions → *Connectivity overlay appearance* | Add as resolution: colorblind-safe orange→teal heatmap, ~40% opacity, pulse on worst 3 segments. | **"What does the connectivity overlay look like?"** → resolved |
| Decisions → *Confirmation panel interaction* | Add as resolution: click-outside closes (= Cancel); panning never blocked. | **"Does the confirmation panel block map interaction?"** → resolved |
| Decisions → *Connectivity computation* | Add as resolution: patch-adjacency graph, precomputed per sub-area, incremental recompute, never per-frame. | **"How is habitat connectivity computed?"** → resolved |
| Decisions → *Segment-zoom threshold* | Add as resolution: ≥16 px tile size, hysteresis at 12 px, one global constant. | **"What zoom threshold triggers segment-level resolution?"** → resolved |

---

### → `sub-areas.md` (SUB)

SUB is currently a stub ("To be defined"). Fable fully resolves it.

| Fable section | Action in SUB | Open question resolved |
|---|---|---|
| World and geography → *Sub-areas: definitive list* | Populate "Proposed solution" + "Key mechanics" with the 12-sub-area table (anchor geography, jurisdiction, controlling entity). The **Controlling entity** column cross-references the GOV entity roster. | **"What are the sub-area boundaries, names, and count?"** → resolved |
| World and geography → *Sizing rule* | Add: equal *playable* size (±15%), proportional world-map shapes; document deviations. | **"How closely should boundaries follow administrative borders?"** → resolved |
| World and geography → *Naming rule* | Add: established geographic names; acknowledgment notes for Indigenous-origin names; all naming passes cultural-advisor review (cross-ref CUL). | **"How are Indigenous place names handled?"** → resolved |

---

### → `governmental-permissions.md` (GOV)

GOV is also a stub. Fable fully resolves it.

| Fable section | Action in GOV | Open question resolved |
|---|---|---|
| Progression → *Entity roster* | Populate with the 9 entities (2 federal, 2 provincial/state, 2 territorial, 3 First Nations partnerships) and what each values. | **"How many distinct governmental entities exist?"** → resolved |
| Progression → *Unlock mechanics* | Add: per-entity Trust score 0–100, weighted measurable metrics, threshold unlock; relationship stages (Introduced→Engaged→Trusted→Partnered) + checklist UI. | **"How are permissions earned mechanically?"** + **"How is progress communicated?"** → resolved |
| Progression → *Starting state* | Add: Central Canadian Rockies unlocked at start (Bow Valley); Crown of the Continent as designed first unlock. | **"Which sub-areas are accessible at game start?"** → resolved |
| Progression → *Revocation* | Add: permission never revoked; neglect slows other entities' trust growth. | **"Can permission be revoked?"** → resolved |
| (controlling-entity mapping) | Cross-reference the SUB table's controlling-entity column so each sub-area maps to an entity. | **"How does the player learn which entity controls a sub-area?"** → resolved (sub-area info panel + entity profile + liaison-briefing purchase) |

---

### → `cultural-narrative-design.md` (CUL)

| Fable section | Action in CUL | Open question resolved |
|---|---|---|
| Cultural and narrative design (carry-forward) | Confirms the five principles carry forward unchanged — no edit needed beyond the resolutions below. | — |
| Decisions → *Representation approach* | Add: fictional, region-specific communities, explicitly framed as fictional; real territories acknowledged. | **"How are specific First Nations communities identified and portrayed?"** → resolved |
| Decisions → *Cultural consultation* | Add: mandatory cultural-advisor review gate before any First Nations content ships; budgeted line item. | **"Should external cultural consultants be engaged?"** → resolved |
| Decisions → *Player framing* | Add: outsider coordinator of a conservation non-profit seeking partnership. | **"What is the narrative framing of the player's role?"** → resolved |
| Decisions → *Indigenous knowledge in mechanics* | Add: free corridor data, habitat-quality bonus, guided-placement hints in partnered territory. | **"How are Indigenous ecological knowledge and practices surfaced in gameplay?"** → resolved |

---

### → `wildlife-overpass-crossing.md` (WOC)

| Fable section | Action in WOC | Open question resolved |
|---|---|---|
| World and geography → *Terrain and tiles* | Confirms hard-barrier / hazardous model + per-terrain mortality env vars (already in WOC); migrate any refined wording (mutual exclusivity restated). | — (already resolved in WOC) |
| Crossings → *Overpass (v1)* | Confirms carry-forward of all overpass mechanics — no change. | — |
| Species → *Movement and mortality* (hex 6-directional rule) | Add as resolution: hex grid gives each tile 6 direct neighbours with no diagonal relationships; pathfinding is 6-directional and crossing choice is always unambiguous. | **"How does pathfinding handle diagonal crossing attempts?"** → resolved |
| Crossings → *Crossing feedback* (signal coalescing) | Add as resolution: `animal_crossed` is per-animal per-traversal; feedback coalesced per crossing in 2 s windows with "+N" counter. | **"Is the `animal_crossed` signal per-animal, per-crossing, or global?"** → resolved |
| Crossings → *Crossing feedback* (art direction) | Add as resolution: vegetated pixel-art overpass, 3 biome variants; placeholder until art-direction doc. | **"What tile does the overpass render as?"** → resolved |
| Crossings → *Crossing costs* | **Supersede** WOC's "No economy or resource cost" non-goal: strike that non-goal and add the 5,000-per-overpass-tile cost rule (cross-ref GDO economy). | — (updates a non-goal) |

---

## What stays in fable (not migrated)

These are meta/record sections about the consolidation itself; they remain in
fable, **not** struck through:

- **Purpose of this document** — describes the consolidation.
- **Decision log** — kept as the migration ledger: a single table recording
  every decision and where its content now lives. (Each row's *content* now
  lives in a destination PRD, but the log itself stays as the index.)
- **Success criteria** — about the consolidation effort.
- **Related** — the link list.

The **Design documentation generation requirements** section is the exception:
it is migrated out to `docs/design-documentation-plan.md` and struck through in
fable with a pointer.

---

## Strikethrough convention (for the execution phase)

For each migrated section in fable, wrap the heading/body in `~~...~~` and append:

```
> Migrated to [[game-design-overview#Habitat and zoning]] on 2026-06-14.
```

This keeps fable readable as a historical record while making it unambiguous
which ideas have found their permanent home. Sections that only *confirm*
carry-forward (no new content) can be struck with a "carried forward; see
[[...]]" note rather than duplicated.

---

## Cross-cutting items (touch more than one PRD)

A few fable elements legitimately land in two places. Proposed handling:

| Element | Primary home | Secondary reference |
|---|---|---|
| Sub-area table's controlling-entity column | SUB (the table) | GOV (entity roster cross-ref) |
| Crossing costs (5,000/tile) | WOC (supersedes its non-goal) | GDO (economy section) |
| Sub-area naming → cultural review | SUB (naming rule) | CUL (review gate) |
| Hex 6-directional pathfinding | WOC (resolves its open Q) | GDO (species/movement) |

In each case the content is written once in the primary home and referenced via
`[[wikilink]]` from the secondary, to avoid divergent duplicates.

---

## Suggested execution sequence

1. **Create** `docs/design-documentation-plan.md` (the only new file).
2. **Stubs first:** populate `sub-areas.md` and `governmental-permissions.md`
   (currently "to be defined") — biggest value, clearest mapping.
3. **Resolutions:** add resolved-question blocks to `crossing-location-selection.md`,
   `wildlife-overpass-crossing.md`, and `cultural-narrative-design.md`.
4. **Anchor doc:** fold the system specs + refinements into `game-design-overview.md`
   and resolve its open questions.
5. **Strike through** migrated sections in `fable-wildlife-crossing.md` with
   pointers; relabel the gen-requirements section as moved.
6. **Verify** (see below).

---

## Verification step

After migration, before considering it done:

- **Coverage check:** every non-meta fable section is either struck-through with
  a pointer, or explicitly listed as "stays in fable." No orphans.
- **Resolved-question check:** every open question in the six source PRDs that
  fable answered is now marked resolved in its own PRD.
- **Link integrity:** all `[[wikilinks]]` and section anchors added during
  migration resolve to real headings.
- **No-duplication check:** cross-cutting items appear once as canonical content,
  referenced (not copied) elsewhere.
- **Non-destructive check:** `git diff` shows only additions and strikethroughs
  in fable — no deletions of original prose.
