# Wildlife Crossing — docs/ Scoped Instructions

> Extends `../CLAUDE.md`. Never contradicts it. Read the root file first.

## What lives here

Human-facing and machine-readable technical documentation: Architecture
Decision Records, release notes, and reusable prompt templates. Nothing in
this directory is game code or Obsidian-style ideation — those live in `game/`
and `obsidian-vault/` respectively.

---

## Directory layout

```
docs/
├── adr/                   # Architecture Decision Records
│   └── NNNN-kebab-title.md
├── release-notes/         # Per-release changelogs
│   └── vMAJOR.MINOR.PATCH.md
└── prompt-templates/      # Reusable Claude prompt starters
    └── kebab-name.md
```

---

## Architecture Decision Records (ADRs)

ADRs capture significant technical decisions so future contributors (and
future Claude sessions) understand *why* the project is built the way it is.

### When to write an ADR

Write one whenever you make a decision that:
- Is hard to reverse (language, engine, data format, core architecture).
- Would reasonably surprise a new contributor.
- Involves meaningful trade-offs between multiple valid options.

### File naming

`docs/adr/NNNN-short-description.md` — four-digit zero-padded sequence number,
then a kebab-case description. Example: `0001-choose-godot-4.md`.

### ADR template

```markdown
---
title: "NNNN — Short Description"
date: YYYY-MM-DD
status: proposed | accepted | deprecated | superseded-by-NNNN
---

## Context

What situation or question prompted this decision? What constraints apply?
Keep this factual and brief.

## Decision

What did we decide to do, and in one sentence, why?

## Consequences

### Positive
- ...

### Negative / Trade-offs
- ...

### Neutral / Follow-on work
- ...
```

### Status values

| Status            | Meaning                                              |
|-------------------|------------------------------------------------------|
| `proposed`        | Under discussion; not yet in effect                  |
| `accepted`        | In effect; followed by the project                   |
| `deprecated`      | No longer recommended but not replaced               |
| `superseded-by-NNNN` | Replaced by a later ADR                           |

---

## Release notes

One file per release, named by semantic version: `docs/release-notes/v0.1.0.md`.

### Release note template

```markdown
---
title: "Wildlife Crossing vX.Y.Z"
date: YYYY-MM-DD
status: active
---

## Highlights

One-paragraph summary of the most exciting changes.

## What's new

- Feature or improvement description.

## Bug fixes

- Fix description.

## Breaking changes

- If any. Otherwise omit this section.

## Known issues

- If any. Otherwise omit this section.
```

### Versioning scheme

Wildlife Crossing uses semantic versioning (`MAJOR.MINOR.PATCH`):
- **MAJOR**: incompatible save-file format changes.
- **MINOR**: new gameplay features or systems.
- **PATCH**: bug fixes, balance tweaks, content additions.

Pre-release versions use `0.x.y` until the game reaches a playable,
feature-complete vertical slice.

---

## Prompt templates

Reusable prompts in `docs/prompt-templates/` help bootstrap common Claude
tasks consistently across sessions. Use kebab-case filenames.

### Template format

Each file is plain Markdown. Include:
1. A short description of when to use this prompt.
2. The prompt text itself (in a fenced code block or clearly delineated).
3. Any known limitations or required context the caller must supply.

### Suggested templates to create

| File                          | Purpose                                        |
|-------------------------------|------------------------------------------------|
| `new-system.md`               | Scaffold a new simulation system + test file   |
| `write-adr.md`                | Draft an ADR for a decision                    |
| `write-release-notes.md`      | Generate release notes from a commit range     |
| `design-species.md`           | Design a new species entry for species_stats.json |
| `design-biome.md`             | Design a new biome for biome_definitions.json  |

---

## What to do when uncertain

- If a decision is significant enough for an ADR but you're not sure of the
  sequence number, check the highest-numbered existing ADR and increment by one.
- If a release touches save-file format, flag it — that is a MAJOR version bump
  even in pre-1.0 if it would break existing saves.
- Don't store ideation or in-progress design thinking here — that belongs in
  `obsidian-vault/`. Docs are for settled, shareable artifacts.
