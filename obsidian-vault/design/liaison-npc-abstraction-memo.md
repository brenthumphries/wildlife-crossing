---
title: "Design Memo — Single Liaison NPC Abstraction for Entity Relationships"
date: 2026-06-21
tags: [design, narrative, culture, first-nations, progression, permissions, evaluation]
status: draft
---

## Summary

This memo evaluates a proposed change to how the player earns access to locked
sub-areas. The current design ([[governmental-permissions]]) has the player
build relationships with nine distinct entities — federal, provincial,
territorial, and three First Nations partnerships — each with its own Trust
score, priorities, and character. The proposal would replace those direct
relationships with interactions with a single in-game, non-player-character
liaison (an employee of the player's fictional conservation org) who manages
all nine relationships behind one interface.

The assessment below weights **cultural representation** most heavily, per the
principles in [[cultural-narrative-design]]. The crux of nearly every effect is
that the proposal routes First Nations partnerships through the *same* NPC as
DOTs and federal agencies — collapsing a distinction the current design draws
deliberately.

**Recommendation: do not adopt the single-liaison model as proposed.** A middle
path (see below) captures most of its production and review benefits without
backgrounding the communities the cultural design insists on centring.

---

## Context

The two PRDs in scope:

- [[governmental-permissions]] — the mechanical system. Nine entities gate
  twelve sub-areas via per-entity Trust scores (0–100) and qualitative
  relationship stages (Introduced → Engaged → Trusted → Partnered).
- [[cultural-narrative-design]] — the narrative and representation layer. Its
  binding principles include: Indigenous stewardship is **centred, not
  backgrounded** (P2); the game **does not speak for** Indigenous peoples (P3);
  named communities require consent and accuracy (P1); and the player seeks
  **partnership, not bureaucratic permission**.

The proposed change abstracts all nine entity relationships behind one liaison
NPC.

---

## Top 5 pros (cultural lens primary)

1. **Reduces "speaking for" risk at the dialogue layer.** The player never
   converses with a Nation directly — only with the org's liaison reporting on
   the relationship — so there is far less surface area to put worldview, voice,
   or cultural specifics into Indigenous characters' mouths. This aligns with
   Principle 3 by structure rather than by careful authoring.

2. **Concentrates the cultural-review surface.** All First Nations content
   flows through one character's voice instead of three distinct communities'
   dialogue trees, making the mandated cultural-review gate cheaper, more
   consistent, and far less likely to let an unvetted line ship.

3. **Models real consultation practice honestly.** Conservation non-profits do
   work through community-relations staff. A liaison can portray consent as an
   ongoing professional relationship the outsider player must work through
   proper channels to earn, reinforcing that the player has no direct
   entitlement to the land.

4. **Can soften the "appease the gatekeeper" feel.** A liaison narrating
   relationship-building can frame progress as earned trust rather than a raw
   per-Nation meter ticking up — closer to Principle 4's "natural consequence,
   not punishment."

5. **Lower production and maintenance cost.** One characterized NPC and one
   interface is far less content than nine distinctly-voiced entities, freeing
   consultation budget to go deeper on the fictional communities' design.

---

## Top 5 cons (cultural lens primary)

1. **Backgrounds the Nations — directly violates Principle 2.** The design
   explicitly wants Indigenous stewardship "centred, not backgrounded." A single
   intermediary makes the Nations offstage entities the player never meets,
   reducing them to a status line in someone else's UI. This is the single
   biggest cultural cost and cuts against the stated educational intent.

2. **Revives the "broker / agent" trope.** A non-Indigenous liaison who
   "manages relationships with" First Nations structurally echoes the historical
   go-between who mediated and controlled Indigenous access to settler
   institutions — a loaded, potentially offensive framing in precisely the area
   the design handles with care.

3. **Conflates sovereign Nations with permitting agencies.** Piping First
   Nations through the same NPC and the same "managed relationship" as DOTs and
   federal forests implies equivalence between Indigenous sovereignty and
   bureaucratic permitting. The current PRDs separate these on purpose;
   collapsing them is itself a representational error.

4. **Filters Indigenous agency to a secondhand report.** The Nations' voice is
   always relayed by a settler org's employee. "Respectful distance" tips into
   silencing — the player hears *about* the Nations, never *from* them, even via
   consulted fictional dialogue.

5. **Weakens the partnership-not-permission framing.** Consent becomes a
   deliverable the liaison unlocks rather than a relationship the player builds,
   undercutting the resolved framing that the player is "seeking partnership,
   not permission in a bureaucratic sense" and that Indigenous involvement is
   "not optional or incidental."

---

## Recommendation — a middle path

Keep the liaison NPC for the **government entities** (federal, provincial,
territorial), where a broker figure fits cleanly and is even thematically apt
for bureaucratic permitting. Preserve **direct, distinctly-voiced partnership
interactions for the three First Nations**, consistent with
[[cultural-narrative-design]].

This captures most of the production and review savings (six entities collapse
to one liaison interface) while keeping the communities the cultural design
insists on centring in the foreground. It also reinforces, rather than erodes,
the deliberate mechanical and narrative distinction between sovereign Nations
and permitting bodies.

---

## Related

- [[governmental-permissions]]
- [[cultural-narrative-design]]
- [[sub-areas]]
- [[game-design-overview]]
