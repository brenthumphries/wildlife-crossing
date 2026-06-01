# Wildlife Crossing — obsidian-vault/ Scoped Instructions

> Extends `../CLAUDE.md`. Never contradicts it. Read the root file first.

## What lives here

The Obsidian vault is the thinking space for Wildlife Crossing — a living
repository of design intent, product requirements, research, and daily progress
logs. Content here is meant to be human-readable, searchable, and linkable.
It is *not* the place for finalized technical documentation (that goes in
`docs/`) or game code.

---

## Directory layout

```
obsidian-vault/
├── daily-logs/        # One note per working session — what happened, what changed
├── design/            # Game design documents, system sketches, mechanic explorations
├── prd/               # Product Requirement Documents for features
└── wiki/              # Reference articles: species, biomes, lore, glossary
```

---

## Front matter (required on every note)

All notes must open with YAML front matter:

```yaml
---
title: Human-readable title
date: YYYY-MM-DD
tags: [tag1, tag2]
status: draft | active | archived
---
```

- `title`: Full, readable title. Used by Obsidian graph and search.
- `date`: Creation date (or the date of the log entry).
- `tags`: At least one tag. See the tag taxonomy below.
- `status`: Lifecycle state of the note.

---

## Tag taxonomy

Use consistent tags so notes are filterable in Obsidian.

| Tag              | Use for                                                  |
|------------------|----------------------------------------------------------|
| `design`         | Game design thinking, mechanic exploration               |
| `prd`            | Product requirement documents                            |
| `species`        | Notes about a specific animal species                    |
| `biome`          | Notes about a specific biome or habitat type             |
| `system`         | A specific game system (habitat, ecosystem, etc.)        |
| `log`            | Daily or session logs                                    |
| `wiki`           | Reference/encyclopedia-style articles                    |
| `decision`       | A decision that was made (link to ADR if applicable)     |
| `question`       | An open question that needs resolution                   |
| `research`       | External research, references, or inspiration            |

---

## Daily logs (`daily-logs/`)

One note per working session. Filename: `YYYY-MM-DD.md`.

### Log template

```markdown
---
title: "Log — YYYY-MM-DD"
date: YYYY-MM-DD
tags: [log]
status: active
---

## What I worked on

Brief summary of the session's focus.

## What got done

- Item completed or meaningfully advanced.

## Decisions made

- Decision and brief rationale. Link to ADR if written.

## Open questions / blockers

- Anything unresolved that needs follow-up.

## Next session

- What to pick up next time.
```

---

## Design notes (`design/`)

Explorations of game mechanics, systems, and player experience. These are
allowed to be messy and evolving. Filename: `kebab-case-topic.md`.

Good design notes:
- Start with the *problem* or *question* being explored.
- Enumerate options considered, not just the chosen direction.
- End with a current recommendation and open questions.
- Link to related notes using Obsidian `[[wiki-links]]`.

---

## PRDs (`prd/`)

Product Requirement Documents define what a feature is, why it matters, and
what done looks like. Filename: `kebab-case-feature-name.md`.

### PRD template

```markdown
---
title: "PRD — Feature Name"
date: YYYY-MM-DD
tags: [prd, system]
status: draft
---

## Problem statement

What player need or design goal does this feature address?

## Goals

- Specific, testable outcome.

## Non-goals

- What this feature explicitly does NOT do.

## Proposed solution

High-level description. Include sketches or diagrams inline if useful.

## Key mechanics / rules

- Rule or mechanic 1.
- Rule or mechanic 2.

## Open questions

- Question that must be resolved before or during implementation.

## Success criteria

How will we know this feature is working as intended?

## Related

- [[link-to-design-note]]
- ADR reference if applicable
```

---

## Wiki (`wiki/`)

Reference articles intended to be stable and factual — the in-world and
systems encyclopedia. Think of these as the source of truth for species data,
biome descriptions, and game terminology. Filename: `kebab-case-subject.md`.

Wiki articles should:
- Be written in a neutral, encyclopedic tone.
- Include a `## References` section if based on real-world science.
- Link to related wiki articles and relevant PRDs or design notes.

---

## Linking conventions

- Use Obsidian `[[kebab-case-filename]]` links freely — they are the connective
  tissue of the vault.
- Cross-link between wiki ↔ design ↔ PRD notes liberally.
- When a decision surfaces that warrants an ADR, note it with:
  `> Decision logged: see [docs/adr/NNNN-title.md]`

---

## What to do when uncertain

- If content is exploratory or in-progress, use `status: draft`.
- If a note is superseded or no longer relevant, set `status: archived` —
  don't delete notes, as the history is valuable.
- Don't write finalized technical specs here — once a PRD is accepted and
  implemented, the canonical reference moves to `docs/`.
