---
title: "0012 — Godot Minor Version and GUT Version Pin"
date: 2026-06-28
status: accepted
---

## Context

[ADR 0001](0001-choose-godot-4.md) committed the project to "Godot 4 + GDScript"
but never pinned a **minor** version, and GUT (the project's mandated test
framework) was named but never versioned. This is blocker **A8** in
[`p0-open-questions` §A8](../p0-open-questions.md): the minor version is not a free
choice, because [`architecture` §3](../architecture.md) uses `TileMapLayer`, a node
that exists only in **Godot 4.3+** (it replaced `TileMap`). The exact engine
version drives `project.godot`, the scene-tree node names, and the CI runner, and
the GUT version must match the engine — so both must be fixed before any
scaffolding (`project.godot`, the directory skeleton, the first GUT test file) is
written.

State of the ecosystem at decision time (2026-06-28):

- **Godot 4.7** is the newest stable release (2026-06-18), with **4.6** the prior
  stable (2026-01).
- **GUT 9.6.0** is the latest shipped GUT release, and it **targets Godot 4.6**.
  GUT tracks Godot minor-for-minor (9.5 → 4.5, 9.6 → 4.6); no GUT release targets
  4.7 yet (4.7 is ten days old at decision time, and GUT historically trails each
  Godot minor by a few weeks).

`p0-open-questions` suggested "latest stable Godot 4.x and the matching GUT
release." Taken literally that points at 4.7 — but there is no *matching* GUT
release for 4.7, and the root `CLAUDE.md` mandates GUT for every system's tests
and for CI. The binding constraint is therefore GUT support, not engine recency.

## Decision

Pin **Godot 4.6 (stable)** and **GUT 9.6.0** as the project's engine and test
framework versions.

GUT 9.6.0 explicitly targets Godot 4.6, so the mandated test tooling is guaranteed
to run against the pinned engine from day one; 4.6 comfortably satisfies the
`TileMapLayer` ≥ 4.3 requirement. Engine recency is deliberately traded for a
proven, mutually-compatible engine/test pair, consistent with ADR 0001's stated
priority of build/iteration stability over raw newness. The 4.7 upgrade is left as
a later, deliberate step (see Follow-on work) rather than adopted before its test
framework has shipped.

Concretely:

- **Engine:** Godot **4.6** stable. `project.godot` declares
  `config/features = PackedStringArray("4.6", "GL Compatibility")` (renderer per a
  later ADR if it deviates from the default).
- **Test framework:** GUT **9.6.0**, vendored at `game/addons/gut/` and pinned by
  exact tag (not a floating `main`).
- **CI:** the GitHub Actions runner uses a pinned `godot 4.6.3-stable` headless
  binary; the engine version is recorded once (a `GODOT_VERSION=4.6.3-stable`
  workflow env var) so the editor and CI never drift.

> **Amendment 2026-07-28.** The CI pin is now the exact patch, `4.6.3-stable`,
> where it was originally the series `4.6-stable`. The decision above is
> unchanged — 4.6.x with GUT 9.6.0 — but "4.6-stable" resolved to **4.6.0** on
> the runner while the vendored `tools/` binary was **4.6.3**, so CI and local
> were building against different engines. That is precisely the drift this
> clause exists to prevent, and it had already cost one misdiagnosis
> ([[../../obsidian-vault/daily-logs/2026-07-27]]). Export-template directories
> are version-keyed (`4.6.3.stable/`), which makes a floating patch actively
> hazardous for the export job. Bumping the patch is now a deliberate edit to
> `.github/workflows/ci.yml` — the env var plus both job names, which inline the
> version because the `env` context is unavailable there.

## Consequences

### Positive

- `project.godot`, node choices, and the CI workflow can all be scaffolded against
  a single fixed pair — unblocks A8 and the **B1/B2/B3** scaffolding cluster that
  follows it in the resolution order.
- `TileMapLayer` and the rest of the `architecture` §3 node set are available, so
  the world-map pipeline from [ADR 0006](0006-world-map-authoring.md) needs no
  rework.
- The mandated GUT test suite (`game/tests/`) is runnable locally and in CI
  immediately, with no unverified engine/framework combination.
- Exact-tag pinning of both engine and GUT keeps editor and CI byte-reproducible
  and removes "works on my machine" drift.

### Negative / Trade-offs

- The project is one minor behind the newest engine, so 4.7-only features
  (HDR, area lights, drawable textures) are unavailable until a deliberate upgrade.
  None are required by the current design.
- A future 4.7 (or later) upgrade is a tracked migration cost rather than a free
  follow-the-latest cadence.

### Neutral / Follow-on work

- **Upgrade path:** revisit via a new ADR (superseding this one) once a GUT release
  targets 4.7+; at that point re-run the GUT suite against the new engine before
  flipping `project.godot` and the CI pin.
- `architecture` / `game/CLAUDE.md` should state the pinned versions where they
  reference Godot or GUT, so the scoped docs cite this ADR rather than a bare
  "Godot 4".
- Tile **size** (B3: 16×16 vs 32×32) and the scene/script **directory** scheme
  (B1) are separate scaffolding decisions and are intentionally out of scope here.
