# Export setup — desktop builds

How Wildlife Crossing goes from repo to runnable desktop binary. Presets live
in `game/export_presets.cfg` (Linux x86_64, Linux arm64, Windows x86_64,
macOS universal); outputs land in `builds/` (gitignored — binaries ship via
GitHub Releases, never the repo).

## Prerequisites

- Godot **4.6.x** editor/headless binary (ADR 0012 pin).
- Matching **export templates**: download
  `Godot_v4.6.x-stable_export_templates.tpz` from the official GitHub release
  and unzip its `templates/` contents into
  `~/.local/share/godot/export_templates/<version>/` (e.g. `4.6.3.stable/`;
  the directory name is the version string `godot --version` reports, without
  the build hash). macOS path: `~/Library/Application Support/Godot/export_templates/`.

## Local export

```sh
cd game
godot --headless --import          # once, or after adding files
mkdir -p ../builds/wildlife-crossing-linux-x86_64
godot --headless --export-release "Linux x86_64" \
  ../builds/wildlife-crossing-linux-x86_64/wildlife-crossing.x86_64
```

Swap the preset name for `"Linux arm64"`, `"Windows x86_64"`, or `"macOS"` as
needed. Each preset writes a binary plus a sidecar `.pck` (macOS produces a
`.zip` containing the `.app`).

Smoke test: the exported binary run with `--headless` must log
`Tutorial loaded.` — that is the "launches to Main.tscn" acceptance check.
Run it through the script rather than by eye, so the noisy-boot case is caught:

```sh
bash tools/smoke_boot.sh ./builds/wildlife-crossing-linux-x86_64/wildlife-crossing.x86_64
```

## Engine settings the presets depend on

`textures/vram_compression/import_etc2_astc=true` in `game/project.godot` is
**required** by the macOS `universal` and Linux `arm64` presets — Godot refuses
to export either architecture with ETC2 ASTC disabled. It defaulted to absent
(off), which failed every macOS export for sixteen days; fixed in `62a4a48`.

> **`project.godot` cannot hold durable comments.** Godot rewrites the file on
> every editor save *and* on `--headless --import`/`--export`, and its writer
> emits only its own boilerplate header — every hand-written comment is stripped,
> wherever it sits. This has now happened twice (2026-07-27, 2026-07-28); the
> 2026-07-27 conclusion that moving comments "above Godot's block" would protect
> them is wrong. Keep the rationale here, in `docs/`, and treat the in-file
> comments as a convenience that will vanish. If a comment goes missing after an
> export run, restore it — the *settings* survive, only the comments are lost.

## What the presets pack, and how to check

`export_filter="all_resources"` on every preset. Godot 4 registers a **JSON
resource loader**, so `data/*.json` counts as a resource and is packed by that
filter — no `include_filter` is needed, and adding one is not what makes the
data ship. `exclude_filter="addons/gut/*,tests/*"` keeps the test framework and
the suite out of release builds; without it the pack carries 244 development-only
files and is 10× larger (1.64 MB → 165 KB).

Inspect a pack's real contents — do **not** trust `strings`/grep for this:

```sh
python3 tools/inspect_pck.py builds/.../wildlife-crossing.pck
python3 tools/check_pck_contents.py builds/.../wildlife-crossing.pck --data-dir game/data
```

> **Why a parser and not a string scan.** Godot 4.6 writes **pack format 3**,
> which stores paths *without* the `res://` prefix and moves the file directory
> to the end of the pack. Grepping a pack for `res://…` therefore finds nothing
> from the directory — but it *does* find path literals embedded in compiled
> `.gdc` bytecode and the global class cache. The result reads as "no data
> files, but plenty of GUT files", which is exactly backwards. This produced a
> false diagnosis on 2026-07-28; `tools/inspect_pck.py` reads the directory
> properly and is the only trustworthy answer.

You can also boot a pack directly, without its binary:

```sh
godot --headless --main-pack builds/.../wildlife-crossing.pck
```

A healthy boot prints the Godot banner and `Tutorial loaded` in **3 lines** and
then keeps running — the game has no auto-quit, so it ends only when the
timeout stops it (exit **124**). A data-less boot also ends at 124, after
~11,600 lines of errors, so exit status alone proves nothing; check the output.

## CI

`.github/workflows/ci.yml` has an `export` job (after `test`): it installs the
pinned Godot + templates, exports the Linux/Windows/macOS presets, runs
`tools/check_pck_contents.py` against **all three** packs, smoke-tests the
Linux binary, and uploads everything as a workflow artifact (14-day retention).
A `smoke-windows` job then boots the exported `.exe` headless on a
`windows-latest` runner (build-review V2). macOS is not booted in CI: it is
launched and watched by hand during every visual QA and signing session
([signing-runbook.md](signing-runbook.md) A8), which is a stronger check than a
headless boot.

The macOS pack sits inside the `.app` inside the zip and is named from
`config/name` (`Wildlife Crossing.pck`), not from the export path — pass the
gate the `.zip` or the `.app` and it finds the pack itself. Releases are cut manually for now: download the artifact, tag
`vX.Y.Z`, attach the binaries to a GitHub Release (per `docs/CLAUDE.md`
versioning).

## Known limitations (first-build placeholders)

- **CI builds are unsigned and always will be.** The macOS export is ad-hoc
  signed at best and will trip Gatekeeper; Windows is unsigned. This is correct
  for CI — signing is a *release* path, not a *CI* path. Release builds are
  signed by hand on Brent's Mac per [signing-runbook.md](signing-runbook.md):
  macOS is signed and notarized, every artifact is covered by a GPG-signed
  SHA-256 manifest, and **Windows ships unsigned by decision**
  ([ADR 0018](adr/0018-code-signing-and-notarization.md)).
- **No icons** — presets ship the default Godot icon until art lands.
- The Linux arm64 preset exists mainly so the export path can be verified in
  arm64 sandboxes/CI; player-facing builds are the other three presets.
