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

## CI

`.github/workflows/ci.yml` has an `export` job (after `test`): it installs the
pinned Godot + templates, exports the Linux/Windows/macOS presets, smoke-tests
the Linux binary, and uploads everything as a workflow artifact (14-day
retention). Releases are cut manually for now: download the artifact, tag
`vX.Y.Z`, attach the binaries to a GitHub Release (per `docs/CLAUDE.md`
versioning).

## Known limitations (first-build placeholders)

- **No code signing / notarization.** The macOS export is ad-hoc signed at
  best and will trip Gatekeeper; Windows is unsigned. Fine for testing;
  proper signing needs owner-provided identities before public release.
- **No icons** — presets ship the default Godot icon until art lands.
- The Linux arm64 preset exists mainly so the export path can be verified in
  arm64 sandboxes/CI; player-facing builds are the other three presets.
