---
title: "project.godot settings — what each one is for"
date: 2026-10-08
tags: [godot, configuration, process]
status: active
---

# project.godot settings

`game/project.godot` is committed in the form Godot itself writes: no
hand-written comments. Godot rewrites the file on every editor save and on
`--headless --import`/`--export`, and its writer strips every comment (see the
note in [export-setup.md](export-setup.md)). Keeping comments in the file meant
a stray `git diff` after every editor session. The rationale lives here instead.
Do not add comments to `project.godot`; add the reason to this page.

## Header and pins

- **Godot 4.6** is pinned by [ADR 0012](adr/0012-godot-and-gut-version-pin.md).
- The autoload roster (`GameState`, `EventBus`, `Debug`, `SpeciesRegistry`) and
  the node choices follow [architecture.md](architecture.md) §2–3.

## `run/main_scene`

The game boots to the title screen (`TitleScreen.tscn`), not straight into play
([ADR 0017](adr/0017-licensing.md)): the credits screen carries Godot's MIT
notice and needs a reachable home. `Main.tscn` is still the playable root.
`TitleScreen` changes into it on Play, or immediately when passed
`-- --skip-menu`, which is how `tools/smoke_boot.sh` keeps testing the full
data-loading path.

## `[display]`

Added for build item C10. The 2026-09-02 QA walk failed the credits-screen and
HUD-message legibility clauses because this section did not exist, so exports
ran at Godot's 1152x648 default with stretch disabled.

- **1280x720** is the smallest size that clears the failure without inventing a
  resolution no one asked for.
- **`canvas_items`** was the 2026-09-02 decision's chosen stretch mode. It
  scales every Control together instead of patching individual font sizes per
  screen. It also affects the screen-to-world mapping, which
  `game/tests/world_renderer_test.gd` guards (the area commit `cb9f9b8` fixed).

## `[rendering]`

`textures/vram_compression/import_etc2_astc=true` is required for the macOS
"universal" and Linux arm64 export presets. Godot refuses to export either
architecture with ETC2 ASTC disabled. See
[export-setup.md](export-setup.md#engine-settings-the-presets-depend-on).
