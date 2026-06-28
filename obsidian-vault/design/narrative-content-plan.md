---
title: "Narrative and Cultural Content Plan"
date: 2026-06-17
tags: [design, narrative, culture, first-nations]
status: draft
---

## Purpose

This document plans the narrative and cultural content of Wildlife Crossing: the
three fictional First Nations communities, character briefs for all nine
governing entities, the unlock narrative beats, the land-acknowledgment text, and
the cultural-review pipeline with its sign-off gate. Its acceptance bar is that
**every entity in the roster has a character brief and the review gate is
positioned before any content-complete milestone.**

It provides the narrative layer over the mechanics in
[[governmental-permissions]] and follows the principles set in
[[cultural-narrative-design]]. Entity ids and metric weights are defined in
[`data-schemas`](../../docs/data-schemas.md) §6.

> **Status: draft pending cultural review.** Per [[cultural-narrative-design]],
> *no First Nations narrative content ships until Indigenous cultural advisors
> sign off.* This plan is deliberately a scaffold: it defines roles, values, and
> structure, and explicitly **defers all culturally specific content**
> (community names' final form, language, worldview, dialogue, ceremonial or
> spiritual detail) to advisor-led development. Nothing here invents that
> content; placeholders are marked `[advisor-developed]`.

---

## 1. Authoring stance (what this document does and does not do)

Following the principles in [[cultural-narrative-design]]:

- It **does** define each entity's institutional role, what it values
  (mechanically already fixed in `entities.json`), the *shape* of its unlock
  beats, and the regional ecological grounding of the fictional communities.
- It **does not** write Indigenous dialogue, worldview, cosmology, ceremony, or
  specific cultural practices. Those are `[advisor-developed]`: the game does not
  speak for Indigenous peoples.
- The three communities are **fictional and explicitly framed as fictional**
  in-game, grounded only in *publicly evident regional context* (geography,
  ecological setting, language family at a high level) — never claiming to depict
  a real Nation. Real Nations' territories are **acknowledged**, not portrayed.
- Government and other entities are characterised thoughtfully — institutional
  cultures and priorities, not bureaucratic-obstacle caricatures.

---

## 2. Land acknowledgment (opening)

Shown at first launch and re-readable from the about screen
([[ui-ux-spec]] §11). Draft copy (to be finalised in review):

> *Wildlife Crossing is set in the Yukon to Yellowstone region — a living
> landscape that is the traditional territory of more than 75 Indigenous peoples,
> whose stewardship of these lands and waters spans thousands of years and
> continues today, long predating the borders this map also shows. The
> communities you partner with in this game are fictional, created to honour —
> not represent — the real Nations of this region. We acknowledge those Nations,
> their enduring relationships with this land, and that conservation here is their
> work first.*

The sub-area info panels additionally carry per-region acknowledgment notes for
names of Indigenous origin (e.g. Muskwa–Kechika, Stikine, Nass, Skeena) — see §5
and [[sub-areas]]. All acknowledgment text is `[advisor-reviewed]`.

---

## 3. The three fictional First Nations communities

Each is a respectfully crafted **fictional** community grounded in its sub-area's
real ecological and geographic context. The briefs below fix only role, regional
grounding, and what each values mechanically; everything cultural is
`[advisor-developed]`.

### Ksanka Confederacy *(fictional)* — Crown of the Continent (sub-area 6)

- **Entity id:** `ksanka_confederacy` · `is_first_nations: true`
- **Regional grounding:** the Crown of the Continent / Flathead region, where
  Pacific-moist and prairie-edge ecosystems meet; one of the most ecologically
  intact temperate landscapes in North America
  ([[crown-of-continent-zone-map]]).
- **Designed role:** the game's **first** First Nations partnership and the
  intended first unlock (deliberately low threshold), introducing the partnership
  mechanic early and warmly.
- **Values (mechanical):** population recovery events, species diversity,
  stewardship in adjacent lands, acceptance of joint-stewardship invitations.
- **Name note:** "Ksanka" and final naming are `[advisor-developed]`; the name
  shown here is a working placeholder pending review and may change.

### Tāłtsē Dena Council *(fictional)* — Muskwa–Kechika (sub-area 9)

- **Entity id:** `taltse_dena_council` · `is_first_nations: true`
- **Regional grounding:** the Muskwa–Kechika, a vast, largely roadless mountain
  wilderness — one of the most intact predator–prey systems in North America.
- **Designed role:** a mid/late partnership emphasising large-landscape
  stewardship and intact connectivity at scale.
- **Values (mechanical):** as the First Nations metric set — recovery, diversity,
  adjacent stewardship, joint-stewardship acceptance.
- **Name note:** working placeholder; final form and any language elements are
  `[advisor-developed]`.

### Three Rivers Nations *(fictional)* — Stikine–Nass–Skeena Headwaters (sub-area 11)

- **Entity id:** `three_rivers_nations` · `is_first_nations: true`
- **Regional grounding:** the Sacred Headwaters, where three major salmon rivers
  (Stikine, Nass, Skeena) rise from a shared plateau — a globally significant
  watershed.
- **Designed role:** a late partnership foregrounding watershed connectivity and
  the link between healthy corridors and salmon-bearing river systems.
- **Values (mechanical):** the First Nations metric set, with the region's
  river-system framing surfaced in `[advisor-developed]` flavour.
- **Name note:** working placeholder; the real names Stikine/Nass/Skeena are of
  Indigenous origin and are **acknowledged**, not claimed — final treatment is
  `[advisor-developed]`.

---

## 4. Entity character briefs (all nine)

Every governing entity has a brief: its institutional character, what it values
(already fixed mechanically in `entities.json`), and how it reads to the player.
Federal/provincial/territorial bodies are characterised with real institutional
texture, never as obstacles.

| Entity | Type | Governs | Character brief |
|---|---|---|---|
| `us_federal_lands` | federal | 1, 3 | A U.S. federal lands agency stewarding flagship parks and wilderness. Mission-driven, data-conscious, accountable to a visiting public. Values **crossing usage** and **reduced road mortality** — visitor-safe, measurable outcomes. Reads as earnest and evidence-led. |
| `ca_federal_parks` | federal | 7 | A Canadian federal parks agency overseeing the Bow Valley, home to the world's most famous wildlife overpasses. Proud of a real track record; the game's **starting (unlocked)** steward and tutorial voice. Values usage data and demonstrated safety. Reads as a confident mentor. |
| `transport_authorities` | provincial/state | 4 | A state/provincial transport authority responsible for highway corridors. Pragmatic, infrastructure-minded, safety- and cost-aware. Values **crossings completed** and **road-mortality reduction** on its corridors. Reads as practical, won over by results. |
| `bc_provincial` | provincial/state | 5, 8 | A provincial government balancing resource economies and conservation. Process-oriented but responsive to clear ecological wins. Values infrastructure metrics and corridor mortality reduction. Reads as deliberate, persuadable by evidence. |
| `ranching_coalition` | ranching coalition | 2 | A multi-stakeholder ranching coalition in the High Divide working land alongside wildlife. Community-rooted, skeptical of outside agendas, loyal once trust is earned. Values stewardship that respects working landscapes. Reads as neighbourly and grounded. |
| `territorial_gov` | territorial | 10, 12 | A northern territorial government stewarding remote, sparsely roaded ranges. Long-horizon, stewardship-first. Values **sustained active crossings** and **population stability over time**. Reads as patient, focused on durability over flash. |
| `ksanka_confederacy` | First Nations *(fictional)* | 6 | See §3. Partnership-seeking, stewardship-expert; values recovery, diversity, adjacent stewardship, and joint-stewardship acceptance. `[advisor-developed]` voice. |
| `taltse_dena_council` | First Nations *(fictional)* | 9 | See §3. Large-landscape stewards of intact wilderness; same First Nations value set. `[advisor-developed]` voice. |
| `three_rivers_nations` | First Nations *(fictional)* | 11 | See §3. Watershed/headwaters stewards; same value set with river-system framing. `[advisor-developed]` voice. |

Every entity in the `entities.json` roster has a brief above — satisfying the
acceptance criterion.

---

## 5. Unlock narrative beats

Each sub-area unlock fires a short narrative beat on `sub_area_unlocked`
([[governmental-permissions]]), paired with the colour-bloom and unlock fanfare
([[art-direction]], [[audio-design]]). Beats follow a consistent, low-key shape
(cozy pillar — earned, not grandiose):

1. **Recognition** — the entity acknowledges the player org's demonstrated
   stewardship (referencing the metrics that crossed the threshold).
2. **Invitation** — access to the sub-area is extended (framed as *partnership*,
   not bureaucratic permission, for all entity types).
3. **What changes** — the sub-area unlocks on the map; a one-time donation bonus
   arrives; for First Nations partnerships, the mechanical benefits activate
   (free corridor data, habitat-quality bonus, guided-placement hints).

Beat *content* differs by entity voice. Government/coalition beats are
`[written]` in this plan's tone; First Nations beats are **`[advisor-developed]`**
and gated (§6). Failure to unlock is never a punishment beat — an unmet
partnership simply hasn't been earned yet, and the entity profile shows exactly
what remains ([[ui-ux-spec]] §9), consistent with "natural consequence, not
punishment."

**Joint-stewardship events** (the in-game events whose acceptance feeds First
Nations trust) are likewise `[advisor-developed]`: the plan reserves the slot and
the mechanic; the content is created in review.

---

## 6. Cultural-review pipeline and sign-off gate

Formal engagement of Indigenous cultural advisors is a **hard gate**, budgeted as
a project line item ([[cultural-narrative-design]]). It precedes any
content-complete milestone — concretely, it sits **before Phase 5 ships** in the
[`roadmap`](../../docs/roadmap.md) (permissions + narrative is the only phase that
introduces First Nations content, and the roadmap already marks the gate at the
top of Phase 5).

### Pipeline

1. **Engage advisors** for the three fictional communities' regions (engagement
   secured before any First Nations content authoring begins).
2. **Co-develop** the `[advisor-developed]` content: community names (final
   form), any language elements, worldview/voice, unlock and joint-stewardship
   beats, and dialogue.
3. **Review** all First Nations–adjacent content, including: the three
   communities' design, **sub-area naming** (acknowledgment notes for
   Indigenous-origin names), the **land acknowledgment** text (§2), and the
   joint-stewardship event content.
4. **Sign-off gate.** A recorded advisor sign-off is required before any of that
   content is enabled in a build. No content-complete milestone may be declared
   while First Nations content is unsigned.
5. **Iterate** on advisor feedback; re-review changed content.

### Review scope checklist

- [ ] Three fictional communities' design and names *(advisor)*
- [ ] Sub-area naming + Indigenous-origin acknowledgment notes *(advisor)*
- [ ] Land acknowledgment opening text *(advisor)*
- [ ] Unlock beats for the three First Nations partnerships *(advisor)*
- [ ] Joint-stewardship event content *(advisor)*
- [ ] Player-framing copy (outsider coordinator seeking partnership) *(advisor-reviewed)*

> Decision logged: government/coalition/territorial entity briefs and their
> unlock beats are **not** gated by cultural review (they involve no Indigenous
> content) and may proceed in Phase 5 independently; only First Nations–adjacent
> content is behind the sign-off gate. This keeps the gate precise without
> stalling unrelated narrative work.

---

## 7. Mechanical-benefit framing (Indigenous knowledge in mechanics)

Per [[cultural-narrative-design]], partnership confers *better information and
better outcomes*, reflecting the real record of Indigenous-led conservation. On
`partnership_formed`, the narrative frames these benefits as the community
sharing stewardship knowledge:

- **Free movement-corridor data** in their territory (no purchase needed).
- **Habitat-quality bonus** on co-stewarded patches (`PARTNERSHIP_QUALITY_BONUS`).
- **Guided-placement hints** highlighting high-impact segments.

The framing copy for these is `[advisor-developed]` so the *why* is told
respectfully rather than as a mechanical perk stripped of meaning.

## Related

- [[cultural-narrative-design]] — principles this plan implements
- [[governmental-permissions]] — the mechanics these beats narrate
- [[sub-areas]] — naming rule and acknowledgment notes
- [[ui-ux-spec]] — entity profile, acknowledgment, unlock UI
- [[audio-design]], [[art-direction]] — unlock fanfare + colour-bloom
- [`roadmap`](../../docs/roadmap.md) — Phase 5 gate placement
