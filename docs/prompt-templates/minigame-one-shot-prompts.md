---
title: "Minigame One-Shot Prompts"
date: 2026-09-01
tags: [prompts, minigames, design]
status: draft
---

## Purpose

Three of the twenty concepts in [[minigame-ideas]] can plausibly be built by a
single Claude Code session from a single prompt, with no follow-up questions and
no new art or audio. This file names those three, records the reasoning behind
every design decision made on the product owner's behalf, and gives the
copy-paste prompt for each.

Nothing here has been built. This is the shortlist and the prompts only.

> **Roadmap position.** `minigame-ideas.md` has been flagged "unassigned to any
> phase" in five consecutive build reviews (07-06, 07-07, 07-21, 07-28 and by
> implication since). These three remain unassigned. They are deliberately
> scoped as **isolated, opt-in modules that touch no Phase 1 or Phase 2 code
> path**, so building one cannot regress the first-working-build effort — but it
> also does not advance it. B3 (fetch the build, walk push-runbook Step 5) is
> still the top of the queue per [[2026-09-01-next-build]].

---

## 1. How the three were chosen

A concept is "one-shottable" only if a fresh session can finish it without
stopping to ask. The root `CLAUDE.md` requires Claude to stop and ask on an
ambiguous requirement, on a new autoload, on a schema change that breaks saves,
and on any task large enough to need a plan. So the screen is really: **which
concepts contain none of those stop conditions?**

Six gates, all of which must pass:

| # | Gate | Why it disqualifies |
|---|------|---------------------|
| G1 | **No new art or audio assets.** | `game/assets/sprites/` holds exactly one file (`crossing_cue.png`, itself a flat-colour placeholder); `assets/tilesets/`, `assets/fonts/` are empty and `assets/audio/` holds one `.wav`. Animal vocalisations are **P2** in [[audio-design]] §7 and do not exist. A concept needing depictions or sounds cannot be finished in one pass. |
| G2 | **No new autoload.** | `game/CLAUDE.md`: "If a new system would create a new autoload, discuss it first." An explicit stop condition. |
| G3 | **No change to `data/*.json` or the save format.** | Schema changes are normative in `docs/data-schemas.md` and a save-breaking change requires a designed migration — both explicit stop conditions. |
| G4 | **No dependency on an unbuilt system.** | `season_manager`, `economy_manager`, `narrative_manager`, `time_controller` and the rest of the Phase 3–6 table in `game/CLAUDE.md` do not exist. `ecosystem_manager` is deferred post-v1 (ADR 0015). |
| G5 | **Deterministic core logic, headlessly testable.** | Every new system needs a GUT test before it is "done". If the interesting logic only exists inside a rendered, timing-dependent scene, the session cannot verify its own work. |
| G6 | **No external review gate.** | [[cultural-narrative-design]] mandates cultural-advisor review, which no session can satisfy. |

### Result

| Concept | Verdict | Blocking gate |
|---|---|---|
| **Signal Chase** | ✅ **Build** | — pure geometry, code-drawn |
| **Snowpack Survey** | ✅ **Build** | — pure stratigraphy, code-drawn |
| **Trailhead Encounter** | ✅ **Build** | — text + timer, code-drawn |
| The Nutcracker's Memory | 🟡 Near miss | Passes all six; lost on tie-break (see §2) |
| Camera-Trap ID | ❌ | **G1.** Needs species imagery under IR/blur/half-frame treatment. The eight 2048px portraits in `docs/prompt-templates/wildlife-crossing-portraits-2048/` are *portraits*, not camera-trap frames, and live outside `game/assets/`. A shader could fake the treatment; that is a second session's work, not a one-shot. |
| Track & Sign | ❌ | **G1.** 8 species × (track + gait + scat) ≈ 24 new sprites. |
| Naturalist's Sketchbook | ❌ | **G1.** Needs per-species line art plus a stroke-matching system. |
| Call of the Corridor | ❌ | **G1.** Elk bugle, wolf howl, loon call are P2 in [[audio-design]] and unrecorded. |
| Phenology Journal | ❌ | **G4.** The verb *is* the season cycle; `season_manager.gd` is Phase 4 and unbuilt. |
| Knowledge Keepers | ❌ | **G6.** Mandatory cultural-advisor review. |
| Crossing Architect | ❌ | Self-flagged in [[minigame-ideas]] as duplicating the core build loop. |
| Trophic Cascade, Beaver Works, Native Waters, Burn Season | ❌ | **G4.** All are food-web / resource-flow games; `ecosystem_manager` is deferred post-v1 (ADR 0015). |
| Path of the Pronghorn, Hyperphagia | ❌ | **G1 + G5.** Both are real-time character-movement games needing animated sprites and frame-timed feel that cannot be verified headlessly. |
| Bear-Proof | ❌ | **G1**, plus its verb ("place things to secure a site") is the core build loop with different nouns. |
| Field Survey | ❌ | **G1.** Batch 2's Camera-Trap ID is the same game, better specified. |

---

## 2. Decisions made on your behalf

These apply across all three. Each is a call the root `CLAUDE.md` would normally
have Claude stop and ask about; each is made here so the prompts can run
unattended.

**D1 — New directory `game/scripts/minigames/`, and the prompt updates
`game/CLAUDE.md` to declare it.**
Minigame logic is not a core simulation system, so `scripts/systems/` would
misrepresent it in a directory whose table is a contract. `scripts/ui/` is for
screen controllers. A sibling directory keeps the split the codebase already
uses — pure logic apart from its presentation — and `game/CLAUDE.md` explicitly
says to flag structural divergence, so each prompt amends the layout block
rather than quietly adding a folder.

**D2 — Logic and UI split into two files per minigame; only the logic file is
tested.**
`game/CLAUDE.md`: "Tests must not depend on scene tree or autoloads where
possible — test logic in isolation by instantiating classes directly." The
solver / generator / classifier is a plain `RefCounted` with `class_name`,
instantiable with `.new()` in GUT. The `BaseScreen` subclass holds only
drawing and input. This is what makes G5 pass.

**D3 — Every puzzle is generated from an integer seed via a local
`RandomNumberGenerator`, never `randi()`.**
Determinism is the precondition for asserting on generated content. It also
gives you shareable daily-puzzle seeds free, later.

**D4 — Content lives in `const` arrays inside the logic script, not in
`game/data/*.json`.**
Adding a JSON file obliges an update to the normative `docs/data-schemas.md`, a
loader, and a `data_version` key — G3. Minigame content is not simulation data
and has not earned that surface. Promote it to `data/` if a second minigame
needs the same content.

**D5 — Launch from a keyboard shortcut in `main.gd`, not from the HUD.**
The HUD and toolbar are specified in [[ui-ux-spec]] §3 against P0 requirements.
Putting phase-unassigned content into the shipping UI would be a scope decision
you have not made. A key binding is reversible in one line. `main.gd` already
reserves `F1` (credits), `F5` (quicksave) and `F9` (quickload) as named consts,
so the three prompts claim **F2 / F3 / F4** — allocated here rather than left to
each session, so three prompts run independently cannot collide. Each follows
the credits overlay's modal-guard pattern (`main.gd:124-133`), which swallows
input while open so Escape cannot cancel a build behind the visible screen.

**D6 — No new `EventBus` signals.**
`event_bus.gd` is organised by simulation domain and each signal is load-bearing
for a system. A self-contained overlay that reports only to itself does not
belong on the global relay. If minigames later feed the encyclopedia or trust
metrics, that is the moment to add signals — with a decision behind them.

**D7 — Scoring is banded and named, never a failure.**
Root `CLAUDE.md` north star 2: "Cozy, not stressful. No fail states that punish
the player harshly." Every one of the three ends in a graded, explained result
using the [[art-direction]] §2 data axis (`#E08A3C` → `#2E8B8B`), so the colour
means the same thing it means on the connectivity overlay.

**D8 — Species drawn only from the eight in `species_stats.json`.**
Adding a species is a data change (G3) and a sprite obligation (G1). The cost is
recorded honestly in each prompt where it hurts.

**D9 — Each prompt ends with a full verification ritual, including
`--headless --import`.**
Per `docs/testing-setup.md` and the `wildlife-crossing-test-setup` project
memory: GUT discovers tests from the *imported* filesystem, `class_name`
registration only rebuilds on import, GUT loads test scripts
**warnings-as-errors** (so `var x := dict.get(...)` inferring Variant is a parse
error), and a dropped script still prints "All tests passed" — the only signal is
the **Scripts count going down**. A one-shot that skips this ritual will report
success on a suite that silently never ran. The current baseline to compare
against is **23 scripts / 237 tests / 3,032 asserts**.

**D10 — Signal Chase is retargeted from wolverine to a collared gray wolf.**
[[minigame-ideas]] specifies a wolverine for Signal Chase, and Snowpack Survey is
inherently a wolverine game (snow-obligate denning is the whole lesson). Two
wolverine minigames out of three narrows the roster for no gain. Gray wolf is in
`species_stats.json`, and collar-based wolf tracking is as real and as
well-documented in the Y2Y corridor as wolverine work. The wolverine keeps
Snowpack Survey, where it is irreplaceable.

---

## 3. Idea 1 — Signal Chase (radio telemetry)

**Verb:** geometry / triangulation. **Species:** gray wolf (see D10).
**Teaches:** how biologists actually locate collared animals — that a bearing is
a line not a point, that two bearings give a fix and three give an *error
polygon*, and that the tightness of that polygon is the real measure of a fix.

### Why it one-shots

Everything visible is a line, an arc, a dial or a label — `_draw()` primitives,
zero assets (G1). The entire interesting part is trigonometry: antenna gain as a
function of angular offset, bearing lines from fixed stations, pairwise
intersections, polygon centroid and area. That is a pure function of a seed and
three player angles, so the solver tests are exact-value assertions (G5). It
touches no simulation system (G4), needs no data file (G3), no autoload (G2).

### Decisions made

- **Abstract metre-space, not the hex grid.** The puzzle lives in a 4000 × 3000 m
  local field with its own coordinates. Reusing `hex_grid.gd` would couple a
  standalone minigame to axial coordinates it has no use for, and would make the
  solver tests depend on world data. *Cost:* the minigame is not "somewhere" on
  the Bow Valley map. Acceptable — real telemetry is done in UTM, not in
  whatever the map is drawn in.
- **Three fixed stations, generated from the seed, not player-placed.**
  Player-placed stations turn this into a station-siting game as well as a
  triangulation game and roughly doubles the scope. Fixed stations keep exactly
  one verb. Station siting is a good v2 feature.
- **A real antenna gain pattern, not a proximity meter.** A three-element Yagi
  main lobe plus a side-lobe floor, so the player learns that a strong reading
  can be a side lobe and that the *null* is sharper than the peak. This is the
  actual field technique and costs about fifteen lines.
- **Deterministic noise.** Noise is a function of `(seed, station_index,
  quantised_angle)`, not of time. Without this the solver cannot be tested and a
  player cannot compare two attempts at the same seed.
- **Result banded, truth always revealed.** Every attempt ends by drawing the
  true collar position, the error polygon and the offset in metres, with a note
  explaining what a tighter fix would have taken. No score is withheld and
  nothing is lost (D7).

### The prompt

````text
Build the "Signal Chase" radio-telemetry minigame for Wildlife Crossing, in this
repo, in one pass. Do not ask me questions — every decision below is already
made. Where something is genuinely underspecified, pick the option most
consistent with the existing codebase, implement it, and note the choice in your
final summary.

FIRST: read /CLAUDE.md and game/CLAUDE.md in full, plus
obsidian-vault/prd/minigame-ideas.md (Batch 2 item 2),
obsidian-vault/design/art-direction.md §2 (palette),
obsidian-vault/design/ui-ux-spec.md §2 (global interaction rules), and
docs/testing-setup.md. Follow every convention in them. Read
game/scripts/ui/base_screen.gd and game/scripts/ui/hud.gd before writing any UI
— they are the pattern to match.

WHAT IT IS
The player is a field biologist locating a collared gray wolf by radio
telemetry. From each of three fixed listening stations they rotate a directional
Yagi antenna, read a signal-strength meter, and commit a bearing. Three bearings
produce three pairwise intersections — an error polygon. The tighter the
polygon and the closer its centroid to the wolf's true position, the better the
fix. Then the truth is revealed and explained.

SCOPE BOUNDARIES — do not cross these
- No new autoload. No new EventBus signal. No change to any game/data/*.json,
  to docs/data-schemas.md, or to the save format.
- No new art, audio, or .tscn files. Everything is drawn with Control/_draw()
  primitives and Label nodes.
- No third-party dependency, addon, or font. (Root CLAUDE.md licensing rules.)
- Do not modify any file in game/scripts/systems/. The only existing files you
  may touch are game/scripts/main.gd (one key binding) and game/CLAUDE.md (the
  directory-layout block and, if you add one, the systems table).

FILES TO CREATE
1. game/scripts/minigames/telemetry_solver.gd
   `class_name TelemetrySolver extends RefCounted`. All logic, zero rendering,
   zero autoload use. Public surface:
   - `const FIELD_SIZE := Vector2(4000.0, 3000.0)` (metres)
   - `const STATION_COUNT := 3`
   - `func generate(seed_value: int) -> void` — seeds a local
     RandomNumberGenerator (never `randi()`), places three stations well apart
     (enforce a minimum pairwise separation and a minimum station-to-target
     distance so the geometry is never degenerate), and places the collared wolf.
   - `var stations: Array[Vector2]`, `var target: Vector2` (read-only by
     convention)
   - `func true_bearing_from(station_index: int) -> float` — degrees, 0 = north,
     clockwise, normalised to [0, 360).
   - `func signal_strength(station_index: int, antenna_deg: float) -> float` —
     returns 0.0..1.0. Model it as: a Yagi main lobe
     `pow(cos(angular_offset), MAIN_LOBE_SHARPNESS)` clamped at zero, plus a
     `SIDE_LOBE_FLOOR` contribution at roughly ±120°, multiplied by a
     distance attenuation term, plus deterministic noise derived from
     `(seed, station_index, angle quantised to 1°)` — NOT from time and NOT from
     a shared RNG stream, so the same inputs always give the same reading.
     Every one of MAIN_LOBE_SHARPNESS, SIDE_LOBE_FLOOR, the noise amplitude and
     the attenuation exponent is a named const or @export — no magic numbers.
   - `func fix_from_bearings(bearings: Array[float]) -> Dictionary` — returns
     `{"intersections": Array[Vector2], "centroid": Vector2,
       "polygon_area": float, "error_metres": float, "band": String}`.
     Compute the three pairwise bearing-line intersections. Handle near-parallel
     bearings without dividing by zero — if a pair is within
     `MIN_INTERSECT_ANGLE_DEG`, omit that intersection and say so in the return.
     `band` is one of "excellent", "good", "loose", "wide", chosen by
     `error_metres` against named const thresholds.
   Add a `## ` docstring on the file and on every public function, per
   game/CLAUDE.md.

2. game/scripts/ui/telemetry_minigame.gd
   `class_name TelemetryMinigame extends BaseScreen`. Builds its UI in
   `_build_ui()` (BaseScreen calls it from `_init()`), starts hidden, and
   exposes `func start(seed_value: int) -> void`.
   - Plan view drawn in `_draw()`: field border as a parchment rect (#F3EAD8),
     three station markers, the antenna heading as a ray from the active
     station, committed bearing lines, and — only after the third bearing — the
     intersection triangle, its centroid, and the true collar position.
   - A signal-strength meter: a horizontal bar whose fill uses the
     art-direction §2 data axis (#E08A3C fragmented → #2E8B8B connected), so the
     colour ramp means the same thing it means on the connectivity overlay.
   - Input: A/D or Left/Right arrows rotate the antenna (hold to accelerate),
     Shift+direction for fine 0.5° adjustment, Enter/Space commits the bearing
     and advances to the next station, `R` regenerates with a new seed, `Esc`
     closes the overlay. Esc-closes matches ui-ux-spec §2 rule 1.
   - After the third commit, show the banded result, the error in metres, and a
     one-or-two-sentence naturalist note that names what happened — e.g. that a
     bearing taken off a side lobe throws the whole polygon, or that stations
     nearly in line with the target give a long thin polygon however good the
     bearings were.
   - Consume the input you handle (`get_viewport().set_input_as_handled()`)
     while visible so it does not leak into Main's build-mode keys.
   - Use `Debug.info()` for logging. No `print()` anywhere (game/CLAUDE.md).

3. game/tests/telemetry_solver_test.gd
   `extends GutTest`, following the template in game/CLAUDE.md. Use EXPLICIT
   TYPES on every local variable — GUT loads test scripts warnings-as-errors and
   an inferred-Variant warning becomes a parse error that silently drops the
   whole file. Cover at minimum:
   - `generate()` is deterministic: same seed twice gives identical stations and
     target; two different seeds give different layouts.
   - Generated geometry always satisfies the minimum separation and
     minimum-distance constraints, across at least 50 seeds in a loop.
   - `true_bearing_from()` is correct for hand-constructed positions at the four
     cardinal directions, and is normalised to [0, 360).
   - `signal_strength()` peaks at the true bearing, is symmetric about it within
     tolerance, is deterministic for identical inputs, and stays within 0..1
     across a full 360° sweep at every station.
   - `fix_from_bearings()` with three exact true bearings gives an
     `error_metres` at or near zero and the "excellent" band.
   - A deliberately bad bearing (say +25° off at one station) degrades the band
     and increases `error_metres` — assert the direction of the change, not a
     brittle exact figure.
   - Near-parallel bearings do not crash, produce no NaN or INF, and are
     reported as an omitted intersection.

4. game/scripts/main.gd — add a single key binding on **KEY_F2** in
   `_unhandled_input` that instantiates TelemetryMinigame on its own CanvasLayer
   and shows it. Declare it as a named const alongside the existing
   `CREDITS_KEY := KEY_F1` / `QUICKSAVE_KEY := KEY_F5` / `QUICKLOAD_KEY := KEY_F9`
   and follow the credits-screen pattern exactly — including the modal guard at
   the top of `_unhandled_input` that swallows all input while the overlay is
   open, so Escape cannot cancel a build behind a screen the player is looking
   at. F2 is free; F1, F5, F9, B, M, Enter and Escape are taken.

5. game/CLAUDE.md — add `minigames/` to the directory-layout block under
   `scripts/` with a one-line description, so the new directory is declared
   rather than discovered. Do not add minigames to the core Systems table; they
   are not simulation systems.

STYLE REQUIREMENTS (from the two CLAUDE.md files)
- GDScript only. snake_case functions and variables, PascalCase classes.
- `## ` docstring on line 1 of every file; `class_name` on line 2 for reusable
  classes; signals before @export vars before regular vars.
- @export for anything a designer would tune. No magic numbers anywhere.
- Past-tense signal names; `_on_<emitter>_<signal>` handlers; connect in
  `_ready()` in code, never in the editor.
- Cozy pillar: there is no losing. A wide fix is reported as a wide fix with an
  explanation of why, never as a failure.
- Ecological honesty: the technique modelled is real. Do not invent telemetry
  physics that would teach something false.

VERIFY BEFORE YOU REPORT DONE — all of it, in this order, from game/
1. `../tools/godot/Godot_v4.6*-stable_linux.arm64 --headless --import`
   (use whatever 4.6.x binary is actually in tools/). This is MANDATORY: GUT
   discovers tests from the imported filesystem and `class_name` registration is
   only rebuilt on import. Skipping it makes new tests silently invisible and
   new class names unresolvable.
2. `godot --headless --check-only -s res://tests/telemetry_solver_test.gd` and
   the same for each new script — catches the warnings-as-errors trap before GUT
   hides it behind "does not extend GutTest".
3. `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests
   -ginclude_subdirs -gexit`
4. Read the Run Summary and CHECK THE SCRIPTS COUNT. The baseline before your
   change is 23 scripts / 237 tests / 3,032 asserts. After your change the script
   count must be 24 and the test/assert counts must both have gone UP. A count
   that went down means a script failed to load and GUT still printed "All tests
   passed" — grep the run output for `SCRIPT ERROR|Failed to load` if so.
5. `bash tools/smoke_boot.sh` if it exists, to confirm the game still boots.

THEN
- Commit on a branch `feat/minigame-signal-chase` with a Conventional Commit
  message (`feat(game): add Signal Chase telemetry minigame`). Do not push.
- Report: the final Scripts/Tests/Asserts counts against the 23/237/3,032
  baseline, every decision you made that this prompt left open, and
  anything you think is wrong with the design.
````

---

## 4. Idea 2 — Snowpack Survey

**Verb:** measurement. **Species:** wolverine.
**Teaches:** how to read a snow pit, why the wolverine is a snow-obligate
denner, and — the payload — that its denning habitat is defined by a *date* as
much as a depth, which is exactly what a warming corridor takes away.

### Why it one-shots

A snow pit is a stack of coloured rectangles with hatch patterns. That is
`_draw()` and nothing else (G1). Underneath it is a stratigraphy generator and a
classifier: seed in, layer array out, verdict out. Both are pure functions, so
the tests are exact (G5). It has the best educational payload-to-code ratio of
anything on the list, because real snow science is already discrete and
tabulated — hardness is a five-step scale, grain types are a fixed vocabulary —
so fidelity costs constants, not systems.
[[
]]### Decisions made

- **The real ICSSG hand-hardness scale (fist / 4F / 1F / pencil / knife) and a
  six-term grain vocabulary** (new snow, rounded grains, faceted crystals, depth
  hoar, melt-freeze crust, ice lens). Root north star 1 is ecological accuracy
  and the game is an educational tool; a made-up "softness 1–10" scale would
  teach a player a vocabulary no field book uses, for no saving.
- **Three-way verdict — viable / marginal / not viable — not a yes/no.** A binary
  is a coin flip a player can win without learning anything, and it flattens the
  most interesting real case: deep enough but melting too early. Three options
  force the player to read the whole profile.
- **Verdict rests on three named criteria** — total depth at or above a denning
  threshold, a supporting structure (a hard slab or crust over softer faceted
  snow or depth hoar, which is what actually holds a tunnel open), and
  persistence past a mid-May date. Each is a separate named const, each is
  scored separately, and the reveal shows all three so the player learns which
  one they misread.
- **The site carries its own `survey_date` string; no coupling to seasons.**
  `season_manager.gd` is Phase 4 and does not exist (G4). A local date string is
  a one-line change to swap for the real season system later.
- **Tools are progressive reveals, not a resource.** Probe reveals total depth,
  the crystal card reveals grain type for one layer, the hardness test reveals
  hardness for one layer. No budget, no timer, no limit on their use. Cozy
  pillar; and a limited-tool economy is a different game that would need a
  balance pass you have not asked for.
- **Grain type is drawn as a hatch pattern, not a colour.** Snow is white — a
  six-colour snow pit would be a lie and would collide with the connectivity
  overlay's colour meanings. Hatch patterns are also the field-book convention
  and survive colourblind viewing, which [[art-direction]] §1 requires.

### The prompt

````text
Build the "Snowpack Survey" minigame for Wildlife Crossing, in this repo, in one
pass. Do not ask me questions — every decision below is already made. Where
something is genuinely underspecified, pick the option most consistent with the
existing codebase, implement it, and note the choice in your final summary.

FIRST: read /CLAUDE.md and game/CLAUDE.md in full, plus
obsidian-vault/prd/minigame-ideas.md (Batch 2 item 5),
obsidian-vault/design/art-direction.md §1–2 (visual pillars and palette),
obsidian-vault/design/ui-ux-spec.md §2, and docs/testing-setup.md. Read
game/scripts/ui/base_screen.gd and game/scripts/ui/hud.gd before writing any UI
— they are the pattern to match.

WHAT IT IS
The player digs a snow pit at a candidate wolverine denning site, reads the
layers with three tools, and judges whether the site will hold a natal den. Then
the truth is revealed with the reasoning laid out criterion by criterion.

SCOPE BOUNDARIES — do not cross these
- No new autoload. No new EventBus signal. No change to any game/data/*.json,
  to docs/data-schemas.md, or to the save format.
- No new art, audio, or .tscn files. The pit is drawn with Control/_draw().
- No third-party dependency, addon, or font.
- Do NOT reference season_manager, time_controller, or any other system in
  game/CLAUDE.md's table that has no file in game/scripts/systems/ — most of
  that table is unbuilt Phase 3–6 work. The site carries its own date string.
- Do not modify anything in game/scripts/systems/. The only existing files you
  may touch are game/scripts/main.gd (one key binding) and game/CLAUDE.md
  (directory-layout block).

DOMAIN MODEL — use the real vocabulary, it is not more work
- Hand hardness, the international five-step scale, hardest to softest:
  KNIFE, PENCIL, ONE_FINGER, FOUR_FINGER, FIST. Model as an enum.
- Grain types: NEW_SNOW, ROUNDED, FACETED, DEPTH_HOAR, MELT_FREEZE_CRUST,
  ICE_LENS. Model as an enum.
- A layer is thickness in cm, hardness, grain type, and density in kg/m³.
- Denning reality to encode: a wolverine natal den needs deep, structurally
  supportive snow that PERSISTS into spring. Depth hoar or faceted snow under a
  harder slab or crust is what lets a tunnel and cavity stay open. An early
  melt-freeze signature high in the pack means the site will be gone before the
  kits are.

FILES TO CREATE
1. game/scripts/minigames/snowpack_profile.gd
   `class_name SnowpackProfile extends RefCounted`. All logic, zero rendering,
   zero autoload use. Public surface:
   - `enum Hardness { FIST, FOUR_FINGER, ONE_FINGER, PENCIL, KNIFE }`
   - `enum Grain { NEW_SNOW, ROUNDED, FACETED, DEPTH_HOAR, MELT_FREEZE_CRUST,
     ICE_LENS }`
   - `enum Verdict { VIABLE, MARGINAL, NOT_VIABLE }`
   - `func generate(seed_value: int) -> void` — seeds a local
     RandomNumberGenerator (never `randi()`) and builds `layers`, an ordered
     Array[Dictionary] from surface down to ground. Generate across the full
     range of interesting cases, not just easy ones: deep-and-supportive,
     deep-but-melting-early, shallow-but-cold, and a thin ice lens that looks
     supportive but is too thin to matter.
   - `var layers: Array[Dictionary]`, `var survey_date: String` (an ISO date
     string like "2026-05-14" — the site owns its own date; do NOT reach for a
     season system, none exists).
   - `func total_depth_cm() -> float`
   - `func has_supporting_structure() -> bool` — a layer at or above
     `SUPPORT_MIN_HARDNESS` and at or above `SUPPORT_MIN_THICKNESS_CM` sitting
     above a FACETED or DEPTH_HOAR layer of at least
     `CAVITY_MIN_THICKNESS_CM`. Every threshold a named const.
   - `func persists_past_denning_date() -> bool` — true when the survey date is
     on or after `DENNING_DATE_THRESHOLD` and the profile carries no
     early-melt signature (a MELT_FREEZE_CRUST or ICE_LENS above
     `MELT_SIGNATURE_DEPTH_CM` from the surface).
   - `func evaluate() -> Verdict` — VIABLE when all three criteria hold,
     NOT_VIABLE when depth alone fails, MARGINAL otherwise. Named consts for
     every threshold; no magic numbers.
   - `func criteria_report() -> Dictionary` — each of the three criteria as a
     `{passed: bool, detail: String}` entry, so the UI can explain the verdict
     without re-deriving it.
   `## ` docstring on the file and on every public function.

2. game/scripts/ui/snowpack_minigame.gd
   `class_name SnowpackMinigame extends BaseScreen`, building in `_build_ui()`,
   starting hidden, with `func start(seed_value: int) -> void`.
   - The pit drawn in `_draw()` as a vertical stack of rects scaled to
     thickness, on the #F3EAD8 parchment ground, using the art-direction §2
     snow/ice values (#E8EEF2 snow, #C9DBE6 blue tinge, #8A8E97 alpine rock for
     the ground line).
   - GRAIN TYPE IS A HATCH PATTERN, NOT A COLOUR — draw the field-book style
     symbols with line primitives (dots for rounded, squares/angular marks for
     faceted, cups for depth hoar, a solid bar for an ice lens, and so on) and
     draw a legend. Snow is white; a six-colour pit would be dishonest and would
     collide with the connectivity overlay's colour meanings. Hatching also
     survives colourblind viewing, which art-direction §1 requires.
   - A depth ruler in cm down the left edge.
   - Three tools, selected by key and applied by clicking a layer, each an
     unlimited progressive reveal — no budget, no timer:
     probe (reveals total depth), crystal card (reveals one layer's grain type),
     hardness test (reveals one layer's hardness). Unexamined layers render as
     undifferentiated snow.
   - Verdict input: three buttons or keys for viable / marginal / not viable.
   - On submit, reveal the full profile and the three criteria side by side —
     the player's call against the true verdict, each criterion marked pass or
     fail with its `detail` string, plus one or two sentences on why wolverine
     denning depends on snow that is still there in May. Use the
     art-direction §2 data axis (#E08A3C → #2E8B8B) for the result banding, and
     #D8A93C only if you need a highlight.
   - `Esc` closes (ui-ux-spec §2 rule 1), `R` regenerates with a new seed.
     Consume handled input while visible. Use `Debug.info()`; no `print()`.

3. game/tests/snowpack_profile_test.gd
   `extends GutTest`. EXPLICIT TYPES on every local variable — GUT loads test
   scripts warnings-as-errors and an inferred-Variant warning silently drops the
   whole file. Cover at minimum:
   - `generate()` determinism: same seed gives an identical layer array;
     different seeds differ.
   - Across at least 100 seeds: layers are non-empty, every thickness and
     density is positive, and `total_depth_cm()` equals the sum of thicknesses.
   - Across those same seeds, assert ALL THREE verdicts are actually produced —
     a generator that never emits a MARGINAL case is a broken generator and this
     is the test that catches it.
   - `has_supporting_structure()` against hand-built profiles: true for a
     PENCIL slab of sufficient thickness over deep DEPTH_HOAR; false for the
     same slab too thin; false when the hard layer sits BELOW the depth hoar
     rather than above it (ordering matters and is easy to get backwards).
   - `persists_past_denning_date()`: false for a date before the threshold;
     false for an on-threshold date carrying a near-surface melt-freeze crust;
     true for an on-threshold date with a cold profile.
   - `evaluate()` returns each of the three verdicts for three hand-built
     profiles constructed to hit each branch.
   - `criteria_report()` has exactly three entries and its `passed` flags agree
     with the individual criterion functions — they must not be able to drift.

4. game/scripts/main.gd — one key binding on **KEY_F3** in `_unhandled_input`
   instantiating SnowpackMinigame on its own CanvasLayer. Declare it as a named
   const alongside the existing `CREDITS_KEY := KEY_F1` /
   `QUICKSAVE_KEY := KEY_F5` / `QUICKLOAD_KEY := KEY_F9`, and follow the
   credits-screen pattern exactly — including the modal guard at the top of
   `_unhandled_input` that swallows all input while the overlay is open. F3 is
   free; F1, F5, F9, B, M, Enter and Escape are taken.

5. game/CLAUDE.md — add `minigames/` to the directory-layout block under
   `scripts/` with a one-line description, if it is not already there. Do not
   add minigames to the core Systems table.

STYLE REQUIREMENTS
- GDScript only. snake_case functions/variables, PascalCase classes.
- `## ` docstring on line 1 of every file; `class_name` on line 2; signals
  before @export vars before regular vars; @export for tunables; no magic
  numbers; past-tense signals; connect in `_ready()` in code.
- Cozy pillar (root CLAUDE.md north star 2): a wrong verdict is met with an
  explanation, never a penalty or a loss.
- Ecological honesty (north star 1): the hardness scale, grain vocabulary and
  denning requirements are real. Do not invent snow science. If you are unsure
  of a real threshold, pick a defensible value, name the const clearly, and flag
  it in your summary as needing a check against the literature — do not quietly
  guess.

VERIFY BEFORE YOU REPORT DONE — all of it, in this order, from game/
1. `../tools/godot/Godot_v4.6*-stable_linux.arm64 --headless --import`
   (whichever 4.6.x binary is in tools/). MANDATORY — GUT discovers tests from
   the imported filesystem and `class_name` registration only rebuilds on
   import. Skip it and your new test file is silently never collected.
2. `godot --headless --check-only -s res://tests/snowpack_profile_test.gd`, and
   the same for each new script.
3. `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests
   -ginclude_subdirs -gexit`
4. CHECK THE SCRIPTS COUNT in the Run Summary. Baseline before your change is
   23 scripts / 237 tests / 3,032 asserts. After, it must read 24 scripts with
   tests and asserts both higher. If the count went DOWN, a script failed to
   load and GUT still printed "All tests passed" — grep for
   `SCRIPT ERROR|Failed to load`.
5. `bash tools/smoke_boot.sh` if it exists.

THEN
- Commit on `feat/minigame-snowpack-survey` with a Conventional Commit message.
  Do not push.
- Report: final Scripts/Tests/Asserts against the 23/237/3,032 baseline,
  every open decision you resolved, any threshold you
  picked that a domain expert should check, and anything you think is wrong with
  the design.
````

---

## 5. Idea 3 — Trailhead Encounter

**Verb:** decision under gentle time pressure. **Species:** the existing roster.
**Teaches:** that the correct response to wildlife is species-specific — that
what is right for a grizzly is wrong for a cougar and irrelevant for a bighorn —
and that almost all of it comes down to distance, noise and not running.

### Why it one-shots

It is text, a countdown, and four buttons. No assets (G1), no simulation
coupling (G4), and the scoring logic is a pure function over a fixed content
array (G5). The content is the only real work, and content is what a prompt is
good at carrying. It also brings the third distinct register to the set — the
other two are both instrument-reading games, and this one is a judgement game.

### Decisions made

- **Encounter species restricted to the eight in `species_stats.json`.**
  Adding a species is a data change (G3) and eventually a sprite obligation
  (G1). *This one has a real cost and it should be recorded:* black bear and
  moose are the two most common consequential trailhead encounters in the Crown
  of the Continent, and both are absent from the roster, so the minigame teaches
  a corridor that is missing its two likeliest encounters. Grizzly, elk in rut,
  gray wolf, bighorn sheep, wolverine, lynx, caribou and pronghorn give seven or
  eight workable scenarios — enough for v1. Adding black bear and moose is the
  first thing to do to this game after it exists, and it is a roster decision,
  not a minigame decision.
- **Content lives in a `const` array in the script, not `data/`.** Per D4. It
  earns a JSON file when a second feature reads the same content.
- **The timer is generous and defeatable.** Eight seconds by default, `@export`ed,
  with an accessibility toggle that removes it entirely. [[minigame-ideas]] asks
  for "gentle time pressure"; the cozy pillar and basic accessibility both say
  the pressure must be optional. A timeout is not a loss — it resolves as
  "froze", which is a real and often survivable response, and it is coached.
- **Every option is plausible; distractors are real folk advice.** "Play dead",
  "climb a tree", "make yourself big" are all correct *somewhere* and wrong
  elsewhere. That misapplication is the actual lesson, and four obviously-silly
  options would teach nothing.
- **Never graphic.** The worst outcome any scenario reaches is a bluff charge
  that ends with the animal moving off, and the framing is always what would
  have lowered the odds. No injury, no death, no gore — root north star 2, and
  the [[minigame-ideas]] entry says so itself.
- **A standing disclaimer on the title card.** This is a game about real safety
  behaviour, and a player could carry it onto a real trail. The prompt requires
  the advice to track published agency guidance (Parks Canada, NPS, IGBC) rather
  than being invented, and requires a visible line saying the game is not a
  substitute for local agency guidance. This is the one place in the three where
  being wrong has consequences off-screen.

### The prompt

````text
Build the "Trailhead Encounter" minigame for Wildlife Crossing, in this repo, in
one pass. Do not ask me questions — every decision below is already made. Where
something is genuinely underspecified, pick the option most consistent with the
existing codebase, implement it, and note the choice in your final summary.

FIRST: read /CLAUDE.md and game/CLAUDE.md in full, plus
obsidian-vault/prd/minigame-ideas.md (Batch 2 item 4),
obsidian-vault/design/art-direction.md §2 (palette),
obsidian-vault/design/ui-ux-spec.md §2, and docs/testing-setup.md. Read
game/scripts/ui/base_screen.gd and game/scripts/ui/hud.gd first — they are the
UI pattern to match. Read game/data/species_stats.json for the species roster.

WHAT IT IS
A run of five short encounter vignettes. Each describes meeting an animal on a
trail; the player picks one of four responses under a generous, defeatable
countdown; the outcome is shown with an explanation of why that response fits
this species and not another. A run ends with a "coexistence confidence" summary
of what the player has and has not internalised.

SCOPE BOUNDARIES — do not cross these
- No new autoload. No new EventBus signal. No change to any game/data/*.json,
  to docs/data-schemas.md, or to the save format.
- No new art, audio, or .tscn files. Text, Labels, Buttons, and a countdown ring
  drawn with `_draw()`.
- No third-party dependency, addon, or font.
- SPECIES ARE LIMITED TO THE EIGHT ALREADY IN game/data/species_stats.json:
  grizzly bear, elk, pronghorn, mountain caribou, wolverine, gray wolf, Canada
  lynx, bighorn sheep. Do NOT add a species to that file. I know this omits
  black bear and moose — the two most likely real trailhead encounters in this
  corridor — and I am accepting that gap for v1. Note it in your summary as the
  first thing to fix later.
- Do not modify anything in game/scripts/systems/. The only existing files you
  may touch are game/scripts/main.gd (one key binding) and game/CLAUDE.md
  (directory-layout block).

CONTENT REQUIREMENTS — read this part carefully
- Write 8 scenarios, one per roster species. A run draws 5 of the 8 by seed.
- Each scenario: a two-or-three-sentence setup naming the species, the distance,
  what the animal is doing and whether it has seen you; four response options;
  exactly one best response; a per-option outcome paragraph; and a "why" line
  giving the ecological or behavioural reason.
- THE ADVICE MUST BE REAL. Track published agency guidance — Parks Canada, the
  US National Park Service, the Interagency Grizzly Bear Committee. Do not
  invent safety advice, and do not smooth species differences into one generic
  answer; the differences ARE the lesson. If you are unsure of the correct
  guidance for a species, write the scenario around behaviour you are sure of
  and flag the uncertainty in your summary rather than guessing.
- Distractors must be plausible: use real folk advice that is correct for a
  DIFFERENT species or situation (play dead, climb a tree, make yourself big,
  hold eye contact, back away slowly, get a tree between you). Misapplying good
  advice is the mistake the game exists to correct. Four silly options teach
  nothing.
- NEVER GRAPHIC. The worst outcome any scenario may reach is a bluff charge that
  ends with the animal moving off. No injury, no death, no gore, no fail state.
  Every outcome ends with what would have improved the odds. Root CLAUDE.md
  north star 2 and the minigame-ideas entry both require this.
- The title card must carry a visible line stating this is a game and not a
  substitute for local agency guidance, and pointing the player at the land
  manager's current advice.

FILES TO CREATE
1. game/scripts/minigames/encounter_scenarios.gd
   `class_name EncounterScenarios extends RefCounted`. Content and scoring, zero
   rendering, zero autoload use.
   - `const SCENARIOS: Array[Dictionary]` — the 8 scenarios. Keys:
     `id`, `species_id` (must match an id in species_stats.json exactly),
     `setup`, `options` (Array[Dictionary] of `{text, outcome, is_best}`),
     `why`.
   - `const RUN_LENGTH := 5`
   - `func draw_run(seed_value: int) -> Array[Dictionary]` — a deterministic
     seeded selection of RUN_LENGTH distinct scenarios using a local
     RandomNumberGenerator (never `randi()`).
   - `func score_run(choices: Array[int]) -> Dictionary` — returns
     `{correct: int, total: int, band: String, summary: String}` where `band` is
     one of "confident", "capable", "learning" against named consts. A choice
     index of -1 means the timer ran out; count it as not-best, never as an
     error, and reflect it in the summary as "froze".
   - `func validate() -> Array[String]` — returns a list of structural problems:
     any scenario without exactly one `is_best`, any with fewer than four
     options, any `species_id` not in the roster, any empty string field. This
     exists so the test can assert the content is well-formed, which is the only
     kind of content bug a test can catch.
   `## ` docstring on the file and on every public function.

2. game/scripts/ui/trailhead_minigame.gd
   `class_name TrailheadMinigame extends BaseScreen`, building in `_build_ui()`,
   starting hidden, with `func start(seed_value: int) -> void`.
   - Title card first, carrying the disclaimer line, then the five encounters,
     then the run summary.
   - Setup text, four option buttons, and a countdown ring drawn in `_draw()`
     that depletes over `@export var response_seconds := 8.0`.
   - `@export var timer_enabled := true` plus an on-screen toggle that turns the
     countdown off entirely. Accessibility, and the cozy pillar: the pressure is
     optional.
   - On timeout, resolve as "froze" with a coaching note. It is a real response
     and often a survivable one — do not treat it as a loss.
   - After each choice: the outcome paragraph, the `why` line, and which option
     was best if the player missed it — always shown, win or lose.
   - Run summary uses the art-direction §2 data axis (#E08A3C → #2E8B8B) for the
     band. `#C0492F` is reserved for invalid placement in this project — do NOT
     use it for a wrong answer.
   - `Esc` closes (ui-ux-spec §2 rule 1), `R` starts a new run. Consume handled
     input while visible. Use `Debug.info()`; no `print()`.

3. game/tests/encounter_scenarios_test.gd
   `extends GutTest`. EXPLICIT TYPES on every local variable — GUT loads test
   scripts warnings-as-errors and an inferred-Variant warning silently drops the
   whole file. Cover at minimum:
   - `validate()` returns an EMPTY array. This is the content contract and the
     single most valuable test in the file.
   - Every `species_id` in SCENARIOS appears in game/data/species_stats.json —
     load the JSON in the test and assert against it, so a future roster rename
     breaks the test instead of the game.
   - Every scenario has exactly one option with `is_best == true`.
   - `draw_run()` determinism: same seed gives the same five ids in the same
     order; different seeds differ; the result always has RUN_LENGTH entries and
     never repeats a scenario within a run. Loop at least 50 seeds.
   - `score_run()` with all-best choices gives `correct == total` and the top
     band; with all-worst gives `correct == 0` and the bottom band; with a
     mixture gives the count in between.
   - A `-1` (timeout) choice scores as not-best, does not crash, and does not
     count as an error.

4. game/scripts/main.gd — one key binding on **KEY_F4** in `_unhandled_input`
   instantiating TrailheadMinigame on its own CanvasLayer. Declare it as a named
   const alongside the existing `CREDITS_KEY := KEY_F1` /
   `QUICKSAVE_KEY := KEY_F5` / `QUICKLOAD_KEY := KEY_F9`, and follow the
   credits-screen pattern exactly — including the modal guard at the top of
   `_unhandled_input` that swallows all input while the overlay is open. F4 is
   free; F1, F5, F9, B, M, Enter and Escape are taken.

5. game/CLAUDE.md — add `minigames/` to the directory-layout block under
   `scripts/` with a one-line description, if not already there. Do not add
   minigames to the core Systems table.

STYLE REQUIREMENTS
- GDScript only. snake_case functions/variables, PascalCase classes.
- `## ` docstring on line 1 of every file; `class_name` on line 2; signals
  before @export vars before regular vars; @export for tunables; no magic
  numbers; past-tense signals; connect in `_ready()` in code.
- Cozy pillar: no fail state, no penalty, no scolding. The tone is a patient
  ranger, not a quiz master.

VERIFY BEFORE YOU REPORT DONE — all of it, in this order, from game/
1. `../tools/godot/Godot_v4.6*-stable_linux.arm64 --headless --import`
   (whichever 4.6.x binary is in tools/). MANDATORY — GUT discovers tests from
   the imported filesystem and `class_name` registration only rebuilds on
   import.
2. `godot --headless --check-only -s res://tests/encounter_scenarios_test.gd`,
   and the same for each new script.
3. `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests
   -ginclude_subdirs -gexit`
4. CHECK THE SCRIPTS COUNT. Baseline before your change is 23 scripts / 237
   tests / 3,032 asserts; after, 24 scripts with both other counts higher. A
   count that went DOWN means a script failed to load while GUT still printed
   "All tests passed" — grep for `SCRIPT ERROR|Failed to load`.
5. `bash tools/smoke_boot.sh` if it exists.

THEN
- Commit on `feat/minigame-trailhead-encounter` with a Conventional Commit
  message. Do not push.
- Report: final Scripts/Tests/Asserts against the 23/237/3,032 baseline,
  every open decision you resolved, ANY safety guidance
  you were not fully confident of, and anything you think is wrong with the
  design.
````

---

## 6. If you build more than one

Build **Signal Chase first**. It is the least entangled of the three — nothing
in it touches content judgement or safety advice — so it is the cleanest test of
whether the shared decisions in §2 (the `minigames/` directory, the logic/UI
split, the verification ritual) actually hold up. If they do, the other two
prompts run against a proven pattern. If they do not, you have learned it on the
cheapest of the three.

Run each prompt in its own session on its own branch. They all touch
`game/scripts/main.gd` and `game/CLAUDE.md`, so running two in parallel means
resolving conflicts in exactly the two files whose correctness the verification
ritual depends on.

---

## Related

- [[minigame-ideas]] — the twenty concepts these three were drawn from
- [[art-direction]] — palette and the colourblind-safe data axis
- [[ui-ux-spec]] — global interaction rules the overlays follow
- [[audio-design]] — why the audio-dependent concepts were cut
- [`testing-setup.md`](../testing-setup.md) — the verification ritual in full
- [[2026-09-01-next-build]] — current build state; none of this is on it
