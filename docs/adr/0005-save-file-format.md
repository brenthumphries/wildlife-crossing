---
title: "0005 — Save-File Format"
date: 2026-06-17
status: accepted
---

## Context

The game is a single-player, offline sandbox with no forced endpoint, so the
player accumulates a long-lived world state: built crossings, per-patch
population counts and trends, per-entity trust scores, purchased information,
budget, current season/time, and milestone progress. We need a serialisation
format for `GameState`. The project's semantic-versioning rule designates a
**MAJOR** bump for incompatible save-file changes, so the format must be
explicitly versioned and migratable. Static reference data (species, sub-area
geography, segment definitions) is *not* saved — it lives in `data/` and is
re-loaded — so saves store only mutable runtime state plus references into the
static data by stable `id`.

Options considered:

1. **Godot `resource`/binary (`.tres`/`.res`)** — engine-native, but opaque,
   harder to diff/debug, and couples the save to engine class layout.
2. **JSON** — human-readable, diffable, decoupled from engine internals,
   trivially versioned with a top-level key.

## Decision

Serialise `GameState` to **JSON** with a top-level `save_version` integer and a
flat, reference-by-id structure: saved objects store the stable `id` of the
static data they refer to (species id, sub-area id, segment id, entity id) rather
than duplicating that data. `save_manager.gd` owns serialise/deserialise and a
migration chain keyed on `save_version`. Saves are written atomically
(write-temp-then-rename) to the user data directory.

## Consequences

### Positive

- Human-readable saves are easy to inspect, diff, and hand-edit during
  development and bug triage.
- Versioning + migration chain makes the MAJOR-bump rule actionable: a format
  change adds a migration step rather than orphaning existing saves.
- Decoupling runtime state from static data keeps saves small and lets content
  tuning (rebalancing species stats, costs) apply to existing saves on load.

### Negative / Trade-offs

- JSON is larger and slower to parse than binary; negligible at this game's
  state size (one corridor's worth of crossings/patches), and saves are
  infrequent (manual + season boundaries), so this is acceptable.
- Reference-by-id means a save can be broken by *deleting* a static data id
  between versions; the migration chain must handle id renames/removals.

### Neutral / Follow-on work

- Define the exact `GameState` JSON shape alongside the data schemas; see
  [`data-schemas`](../data-schemas.md). Autosave cadence (e.g. on
  `season_changed`) is specified in [`architecture`](../architecture.md).
