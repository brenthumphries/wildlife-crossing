---
title: "Design Documentation Generation Plan"
date: 2026-06-14
status: active
---

## Purpose

This document enumerates the full set of design documents to be produced for
Wildlife Crossing — each document's required contents, its repo location, and
its acceptance criteria. It is the authoritative checklist for turning the
product requirements (the PRDs in `obsidian-vault/prd/`) into a complete design
documentation set.

Migrated from the "Design documentation generation requirements" section of
`obsidian-vault/prd/fable-wildlife-crossing.md` on 2026-06-14. When the
consolidated PRD set is fed to Claude with the instruction "generate the design
documentation," produce the documents below, in order (each may reference
earlier ones).

All documents follow the repo's conventions: ADRs in
`docs/adr/NNNN-kebab-case.md` (Context / Decision / Consequences), technical
docs in `docs/`, design notes in `obsidian-vault/design/`, wiki articles in
`obsidian-vault/wiki/` with front matter, GDScript snake_case, one class per
file, signals over direct references, named constants only.

---

## Documents to produce

### 1. Technical architecture document — `docs/architecture.md`

Godot 4 scene tree and autoload structure; the simulation tick model; system
boundaries (world data, habitat, species/pathfinding, economy, permissions,
seasons, UI) and the signals connecting them; save/load design; performance
budget for the per-event connectivity recompute.

*Acceptance: every system in the PRD set maps to a named scene/script; every
cross-system interaction in "How systems interact" maps to a named signal.*

### 2. Data schema specification — `docs/data-schemas.md`

JSON schemas for species (fields listed in the species section of
`game-design-overview`), sub-areas (boundaries, playable size, controlling
entity, trust threshold), segments, tiles (including
`is_impassable`/`is_hazardous`), governmental entities (metric weights), and
milestones. Includes the environment-variable registry (`ROAD_HAZARD_MORTALITY`,
`RIVER_HAZARD_MORTALITY`) and the constants files (`habitat_constants.gd`,
`economy_constants.gd`).

*Acceptance: a sample data file for each schema validates; all eight launch
species and twelve sub-areas have stub entries.*

### 3. Simulation and pathfinding design — `docs/simulation-design.md`

4-directional pathfinding graph construction; crossing-preference cost
weighting; mortality checks; population model (per-patch counts, viability,
recovery events); seasonal modifiers; determinism and tick-rate decisions.

*Acceptance: pseudocode or GDScript sketches for graph update on crossing
completion and for the monthly population step.*

### 4. UI/UX specification — `obsidian-vault/design/ui-ux-spec.md`

Every screen and panel named in the PRD set: world map + selection mode,
overlay, confirmation panel, build palette, patch/tile inspect, entity profile +
trust checklist, seasonal calendar, budget HUD, milestone track, time controls.
Wireframe descriptions, input maps (including Escape semantics), and the
click-outside-closes-panel rule.

*Acceptance: every P0 requirement in `crossing-location-selection` and the PRD
set has a corresponding UI element; all four relationship stages and all four
habitat bands have defined visual treatments.*

### 5. Art direction document — `obsidian-vault/design/art-direction.md`

Palette, tile dimensions, sprite specs for the eight species and three overpass
biome variants, overlay/heatmap rendering spec (colorblind-safe gradient),
locked sub-area desaturation treatment, seasonal terrain variants.

*Acceptance: a per-asset list with dimensions and priority sufficient to
commission or generate placeholder-replacing art.*

### 6. Audio design document — `obsidian-vault/design/audio-design.md`

Crossing-success cue (and its coalescing behaviour), ambient seasonal beds,
unlock fanfares, UI sounds; mixing rules consistent with the cozy pillar.

*Acceptance: a complete cue list mapped to the signals that trigger them.*

### 7. Narrative and cultural content plan — `obsidian-vault/design/narrative-content-plan.md`

The three fictional First Nations communities (names, regional grounding, what
each values), the nine entity characterisations, unlock narrative beats, land
acknowledgment text, and the cultural-review pipeline with its sign-off gate.

*Acceptance: every entity in the roster has a character brief; the review gate
is positioned before any content-complete milestone.*

### 8. Wiki seed articles — `obsidian-vault/wiki/` (one per subject)

The eight species, the twelve sub-areas, and core glossary terms (patch,
segment, connectivity, trust), encyclopedic tone with `## References` to
real-world science.

*Acceptance: front matter valid; each species article states the real ecology
behind its game parameters.*

### 9. Test plan — `docs/test-plan.md`

GUT test files per system (`game/tests/<system_name>_test.gd`): pathfinding
through complete/partial spans, per-terrain mortality rates honouring
environment variables, `animal_crossed` signal exactly-once, habitat quality
recompute, donation formula, trust accumulation and unlock trigger, season
transitions.

*Acceptance: every P0 acceptance criterion in the PRD set and
`wildlife-overpass-crossing` maps to at least one named test.*

### 10. Milestone roadmap — `docs/roadmap.md`

Phased build order: (1) core simulation + overpass validation, (2) location
selection + sub-areas, (3) economy + information, (4) seasons, (5) permissions +
narrative (post cultural review), (6) milestones + polish. Each phase lists its
PRD sections, exit criteria, and ADRs likely needed (crossing tile architecture,
save format, connectivity algorithm).

*Acceptance: every requirement in the PRD set is assigned to exactly one phase.*

---

## Generation constraints

Do not modify any existing PRD; new documents only. Where a generated document
must make a decision the PRD set does not cover, state the decision explicitly
in the document and flag it `> Decision logged:` per vault conventions rather
than leaving it open.

---

## Related

- [[fable-wildlife-crossing]] — original source of these requirements
- [[game-design-overview]] — the anchor PRD these design docs elaborate
