---
title: "Testing Setup & Runbook"
date: 2026-06-28
status: active
---

## Purpose

How to run the Wildlife Crossing test suite locally and understand the test
tooling. This is the operational companion to two other documents: the *why* of
the version choices lives in [ADR 0012](adr/0012-godot-and-gut-version-pin.md),
and the *what* (per-system test coverage) lives in [test-plan.md](test-plan.md).
Conventions for writing test files are in [`game/CLAUDE.md`](../game/CLAUDE.md).

---

## Pinned versions

Per [ADR 0012](adr/0012-godot-and-gut-version-pin.md), the engine and test
framework are pinned as a matched pair:

- **Godot 4.6** (stable). Any 4.6.x patch is fine; verified working on 4.6.3.
- **GUT 9.6.0**, vendored at `game/addons/gut/` by exact tag (not floating
  `main`). GUT tracks Godot minor-for-minor, and 9.6.0 targets 4.6.

The vendored GUT tree is committed to the repo so both the editor and CI resolve
`res://addons/gut/`. The bundled `*.import` files are intentionally gitignored
(repo-wide `*.import` rule) — Godot regenerates them on first import; the `.uid`
files that ship with GUT are committed.

---

## The local Godot binary

The Godot binary is **not** committed (it is ~120 MB). The repo's root
`.gitignore` excludes `/tools/`, which is where the binary lives for local and
sandbox test runs:

```
tools/godot/Godot_v4.6.x-stable_linux.arm64    # or _linux.x86_64 / macOS app
```

Pick the build that matches the machine running it:

- Developer Mac: the macOS `.app` from the Godot 4.6 download page.
- The Cowork/Claude sandbox: a **Linux ARM64** build
  (`Godot_v4.6.x-stable_linux.arm64`) — the sandbox is aarch64, so neither the
  macOS app nor the Linux x86_64 build will run there.
- CI: a pinned Linux x86_64 headless binary, fetched by the workflow (see below).

The binary at `tools/` is for running tests only; it does not need to match every
contributor's machine because it is gitignored and provided locally.

---

## Running the suite

### From the command line (headless)

This is exactly what CI runs. From the `game/` directory:

```bash
godot --headless --import          # first run only: builds the .godot resource cache
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Substitute the path to your local binary for `godot` (e.g.
`../tools/godot/Godot_v4.6.3-stable_linux.arm64`). A clean run ends with
`---- All tests passed! ----` and a summary; the suite currently reports
**16 scripts / 134 tests / 2,779 asserts** passing (2026-07-30, after
`build_mode_test.gd` landed with build-review B4).

The `ObjectDB instances leaked at exit` warning on shutdown is benign Godot
teardown noise and can be ignored (or filtered with `grep -v`).

### From the editor

Open the `game/` project in Godot 4.6 and use the **GUT** bottom panel (added by
the enabled plugin) to run the suite or individual scripts.

---

## Test discovery: `game/.gutconfig.json`

GUT's default file matching looks for the **`test_` prefix**, but this project's
convention (per `game/CLAUDE.md`) names test files with the **`_test.gd`
suffix** (e.g. `pathfinding_test.gd`). Without an override, GUT collects nothing,
prints `Nothing was run`, and — critically — still exits `0`, so CI passes while
running zero tests.

`game/.gutconfig.json` fixes this for both CI and the editor panel:

```json
{
	"dirs": ["res://tests"],
	"include_subdirs": true,
	"prefix": "",
	"suffix": "_test.gd",
	"should_exit": true,
	"log_level": 1
}
```

`gut_cmdln.gd` auto-loads `res://.gutconfig.json`, so no extra flags are needed on
the command line or in CI. The equivalent flag-only override (not used here, because
it leaves the editor panel broken) would be `-gprefix= -gsuffix=_test.gd`.

---

## Writing tests that GUT will load

GUT loads each test script with **warnings treated as errors**. A GDScript
*warning* in a test file therefore becomes a hard parse error and GUT skips the
whole file with the misleading message `… does not extend GutTest`. The most
common offender is **inferring a type from a `Variant`**:

```gdscript
# Fails to load: ':=' infers Variant from Dictionary.get(...)
var aliases := some_dict.get("terrain_aliases", {})

# Correct: give it an explicit type.
var aliases: Dictionary = some_dict.get("terrain_aliases", {})
```

If a file you expect to run is missing from the summary, run it through the parser
directly to see the real error:

```bash
godot --headless --check-only -s res://tests/<name>_test.gd
```

---

## CI

`.github/workflows/ci.yml` runs the suite headless on every push/PR to `main`. It
pins the engine via a `GODOT_VERSION=4.6.3-stable` env var, downloads the matching
Linux x86_64 headless binary, runs `godot --headless --import`, then the same
`gut_cmdln.gd` command shown above. Because discovery now comes from
`game/.gutconfig.json`, the workflow needs no GUT-specific flags.

### Known gap

GUT exits `0` on `Nothing was run`, so a future discovery regression (renamed
files, moved `tests/` dir, deleted gutconfig) would silently turn CI green again.
Consider adding a CI assertion that the run actually collected tests — e.g. grep
the output for the script/test totals, or fail if `Nothing was run` appears.

---

## Smoke-testing an exported build

`tools/smoke_boot.sh <binary> [timeout_seconds]` boots an **exported** binary
(not the source tree — see [export-setup.md](export-setup.md) for how builds
get produced) headless and checks that it reaches the tutorial cleanly. It
replaced an earlier inline CI check that piped through `head -20` and
misreported healthy-but-noisy boots as failures (2026-07-28 build review).

```bash
tools/smoke_boot.sh path/to/exported/binary 20
tools/smoke_boot.sh --check-log existing-boot-log.txt   # re-check a saved log
```

A healthy run prints 3 lines (engine banner, blank line, `Tutorial loaded`)
and exits `124` — still running when the timeout fired, which is expected
since the game has no auto-quit. The script's own exit code is `0` if the log
passed every check in `FATAL_PATTERNS`, non-zero otherwise.

### Requires GNU coreutils' `timeout` and `stdbuf`

Both ship natively on Linux (CI and the sandbox). **Neither ships on stock
macOS.** Install with:

```bash
brew install coreutils
```

which provides `gtimeout` / `gstdbuf`. The script detects and uses whichever
prefix is present (`timeout`/`gtimeout`, `stdbuf`/`gstdbuf`) and fails with an
explicit message rather than a misleading result if neither exists — a
missing dependency must never be misreported as "the binary didn't boot,"
which is exactly the class of bug this script exists to prevent.

`stdbuf -oL -eL` is not optional. Confirmed by hand on a Mac (2026-07-29): a
killed (non-exiting) process's buffered stdout is **silently lost on macOS**
— neither `SIGTERM` nor `SIGINT` flushes it, whether the kill comes from
`timeout` or a plain `kill`. A healthy boot only logs a handful of short
lines before going idle, so it never fills the buffer on its own — the
result was a report of **zero lines of output** on a build already confirmed
playable in a windowed launch, indistinguishable from a hang or a crash.
Linux does not have this problem (verified: a plain `timeout`-killed boot on
the same project came through cleanly with no wrapper needed), but the
script wraps the binary in `stdbuf`/`gstdbuf` on both platforms unconditionally
so behaviour doesn't silently depend on which OS is running it.
