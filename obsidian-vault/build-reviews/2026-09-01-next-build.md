---
title: "Build Review — Next Build (2026-09-01)"
date: 2026-09-01
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> [roadmap](../../docs/roadmap.md) Phases 1–2). One question: what work is
> needed to get there?

> [!info] Snapshot
> Measured against **`00574b8`** (*docs(readme): point the conventions link at
> the root CLAUDE.md*, 2026-08-29 20:12:33 -0500) on branch **`main`**.
> `git rev-list --count origin/main..HEAD` → **0**. Three days since the last
> commit; **zero commits since**. Anything not traceable to something read or
> run this session is labelled in [§Verification](#verification).

> [!success] The deadline that dominated the last review is very likely gone
> 08-25 opened with a two-day artifact expiry. The merge and the
> `retention-days` split between them should have replaced it: the post-merge
> `main` runs of 2026-08-29 fall on the 14-day branch of `ci.yml:261`, which
> puts expiry around **2026-09-12** — roughly eleven days of runway rather than
> two. **That is a derivation, not an observation.** `ci.yml:261` was read this
> session; the run dates come from [[../daily-logs/2026-08-29]], and no GitHub
> state was reachable from here (§Verification). Check it with `gh run list`
> before relying on it. What *is* certain from the repo is that B3's blocker
> cleared: `origin/main..HEAD` is 0.

> [!success] Amendment 2026-09-02 — **B3 is closed, and the walk found two defects the suite cannot see.**
> Run `33285150876` (`00574b8`) fetched and walked windowed on the Mac per
> push-runbook Step 5. See [[../daily-logs/2026-09-02]].
>
> **The artifact question is settled by observation, not derivation.** This
> note's opening callout derived an expiry of around 2026-09-12 and said so.
> The public GitHub API gives `expired: false` and
> `expires_at: 2026-09-13T01:14:54Z` for artifact
> `wildlife-crossing-desktop-builds`, 127,378,084 bytes. The derivation was
> right and is now measured. The API is reachable unauthenticated because the
> repository is public, which §Verification recorded as unreachable.
>
> **What passed.** Pack gate green on all three platforms: 95 files, pack
> format 3, Godot 4.6.3, all 20 data files, no `addons/gut` or `tests`. Title
> screen, Play, B, left-click, Enter, Escape, M, F1, and the F5 / quit /
> relaunch / F9 round-trip, which had never run from an exported binary before
> today. Credits open from the menu and from F1, and scroll. The `+N crossed
> safely` line appears and the chime is heard.
>
> **The `codesign` result contradicts the runbook and shrinks C1.**
> `flags=0x10002(adhoc,runtime)`, `Signature=adhoc`, universal x86_64 arm64,
> `Identifier=com.wildlifecrossing.game`. No local re-sign was needed, and the
> hardened runtime is already on despite `export_presets.cfg` carrying no
> hardened-runtime key, so C1 supplies identity, team id and
> `notarization=1` only.
>
> **Finding 1, and it should be numbered as a blocker in the next review: the
> world map renders every sub-area locked.** All twelve cards desaturated with
> the padlock, Bow Valley included. `JSON.parse_string` returns numbers as
> floats, so `species_registry.gd:52` keys `sub_areas` by `1.0` through `12.0`,
> Godot dictionaries treat `7` and `7.0` as different keys
> (`has(7.0)=true has(7)=false`, reproduced headlessly against the real data
> file), and `world_select_controller.gd:65`'s `for id: int in ids:` narrows the
> key so the lookup misses. `:232` fails the same way for card labels.
> `world_select_controller_test.gd:11` uses int-keyed fixtures, which is why
> 237 green tests say nothing. **This breaks Phase 2's second exit criterion,
> `roadmap.md:116`, in the artifact while it passes in tests**, which is C9's
> defect a second time and in a second place. `sub_areas` is the only
> numeric-keyed registry, so the blast radius is this screen alone.
>
> **Finding 2, which belongs to C5: no `[display]` section exists in
> `game/project.godot`.** The export runs on Godot defaults, a 1152x648
> viewport with stretch disabled, so nothing scales with window size or pixel
> density and all UI text is too small to read, credits included. Brent's call
> on 2026-09-02 was to record it and not fix it here, because the durable fix
> (`stretch/mode = "canvas_items"`) also changes screen-to-world mapping, the
> area `cb9f9b8` fixed.
>
> **Two acceptance clauses of B3 failed rather than passed:** the credits screen
> and the HUD message line were both required to be legible. B3 is recorded
> closed anyway, because its job was the walk and the walk is complete.
>
> **Doc drift found, owed and unfixed:** `push-runbook.md:302` puts F1 at Step
> 5.2, ahead of Start at 5.3, but F1 is bound only in `main.gd` and
> `title_screen.gd` binds no keys, so that step has never been runnable in the
> order written.

## 1. Summary

- **Build case:** **FIRST working build**, for the ninth consecutive review, on
  the three facts the harness names — *"there is a working build only if you can
  point to an actual export in `builds/` or a GitHub Release **and** it
  launches."* Re-checked this session: `du -sh builds/` → **4.0K** (`.gitignore`,
  `.gitkeep`, one empty `wildlife-crossing-linux-arm64/`); `git tag -l` → **0
  tags**; `docs/release-notes/` → a single 0-byte `.gitkeep`.
- **Target milestone & exit criteria:** [roadmap](../../docs/roadmap.md) Phase 1
  §*Exit criteria* (`:47-55`) and Phase 2 §*Exit criteria* (`:112-122`), as
  scoped by the logged decisions of 2026-07-29 (Bow Valley only) and 2026-08-06
  (world map ships look-only). All still met in code and green in tests — with
  the caveat C9 now carries.
- **Headline:** **6 blockers, 9 core tasks, 8 verification items.** **Four items
  closed since the 08-25 note was first written** — B1a, B2, B5 and V9 — all in
  the 08-26 → 08-29 window and all already recorded in that note's amendments;
  **this review closes nothing further, because nothing has happened in the
  three days since.** `git log --since=2026-08-30` returns nothing. The GUT
  suite reports the same totals as the last three reviews — **23 scripts / 237
  tests / 3,032 asserts, all passing**, exit 0 — and the Python tool suite is
  **86 tests, OK**. Both headless boots are clean. Three things are new this
  week, and two of them are consequences of the merge rather than of new work:
  1. **The top of the queue is unblocked.** B3 has carried `Depends on: B2`
     through three reviews (08-12, 08-18, 08-25). B2 closed on 08-29, so B3 —
     fetch the build, walk push-runbook Step 5 windowed, with C4 and C5 riding
     along — is now a session someone can simply sit down and do. The 08-29
     log's own next-session list puts it first. Nothing has been done against it
     in three days.
  2. **The credential path is now the item with a deadline, and it inherited
     that role from B3.** Apple enrolment was submitted 2026-08-27; whenever it
     is approved, runbook A4 delivers an App Store Connect `.p8` that Apple
     permits **exactly one download of**, into a repository whose `.gitignore`
     carries **no credential patterns at all** — re-verified this session,
     `grep -in 'p8\|p12\|cer\|mobileprovision\|\.env' .gitignore` returns
     **nothing at all**, exit 1 — and which per [[../daily-logs/2026-08-29]] is
     public and has neither push protection nor secret scanning configured.
     (Those last three are GitHub-side settings this session could not read;
     the ignore file is the part that is verified here.) The 08-29 log raised
     all of it as open questions. **None is tracked as a work item anywhere, so
     this review adds one — [B8](#b8-harden-the-credential-path-before-a4-lands).**
     The timing is not the project's to choose, which is what makes it a blocker
     rather than a chore.
  3. **Every `ci.yml` line citation in the carried work items is now wrong.**
     `e5687cf` grew the file from 279 to **297 lines**. `retention-days` moved
     `:243` → **`:261`**; the zero-tests guard `:106-120` → **`:113-127`** with
     the fragile `grep -oE '<testcase'` now at **`:122`**; the *"Known gap"*
     comment `:220` → **`:227-230`**; the `smoke-windows` job `:256` →
     **`:274`**, its misleading name at **`:275`**, its bare `needs: export` at
     **`:276`**. All are corrected in the items below — **and this note's first
     draft got eight of those corrections wrong in turn**, which the
     fact-integrity audit caught and §Verification records. Same defect class
     the 08-25 audit caught ten of. The durable fix is to cite headings and step
     names, not lines; the items below still cite lines because that is what the
     runbooks do.
- **Change since last review:** [[2026-08-25-next-build]] — **B1a, B2, B5 and V9
  closed** (all in that note's amendments, 08-26 through 08-29); **nothing
  closed in the three days this review covers**; **B8, C8 and C9 are new**;
  **two doc-drift rows leave the table by being fixed**, where 08-04 and 08-18
  each closed one and the other five reviews closed none. Numbers B1b, B3, B4,
  B6, B7, C1–C7 and V1–V8 are carried unchanged so the diff stays readable.
  **B1 is split for the first time in the item list rather than only in its
  prose:** B1a is closed, so what remains is B1b, the Apple half.

## 2. Current state (evidence)

Re-measured against `00574b8` this session unless labelled otherwise in
[§Verification](#verification).

- **Systems:** **30 scripts / 3,569 LOC** in `game/scripts/`. Four autoloads
  registered in `game/project.godot` (`GameState`, `EventBus`, `Debug`,
  `SpeciesRegistry`); every other system is instantiated at runtime by `main.gd`.
  No empty stubs — the smallest, `ui/base_screen.gd`, is 23 LOC and real. Of the
  27 scripts the roster table at `docs/architecture.md:44-69` names (16 systems +
  11 UI), **13 are present and 14 are absent**; all fourteen are Phase 3–6 work,
  so this is a stale roster, not a regression (§4).
- **Data:** all **8** canonical files in `game/data/` present and valid JSON, and
  all **12** `data/world/sub_area_*.json` valid — twenty files, zero parse
  failures, re-validated with `python3 -m json.tool` this session. Last changed
  2026-07-10.
- **Scenes & wiring:** `run/main_scene` is `res://scenes/TitleScreen.tscn`.
  `Main.tscn` is a script holder; the wiring is `main.gd`, which constructs
  `Simulation`, `WorldRenderer`, `ConnectivityOverlay`, the camera, the audio
  player, `Hud` and `CreditsScreen` at runtime. Four scenes exist.
  `scenes/world/Animal.tscn` is still referenced by nothing (re-verified by grep
  across `game/` this session — zero hits outside the file itself).
- **Tests:** GUT 9.6.0 via the vendored
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` (`--version` →
  `4.6.3.stable.official.7d41c59c4`) — **23 scripts / 237 tests / 3,032 asserts,
  all passing**, exit 0, 1.76s. `python3 -m unittest discover -s tools/tests -b`
  → **86 tests, OK**. Totals identical to 08-12, 08-18 and 08-25 (wall clock
  differs run to run — 1.76s here, 1.711s on 08-25 — so "identical" means the
  counts, not the run). **9 of the 30 GDScript scripts have no named test
  file**: `main`, `title_screen`, `env_config`, the three constants files, and
  the autoloads `debug`, `event_bus`, `species_registry`. **Three have no grep
  contact of any kind** in `game/tests/`: `species_registry.gd`,
  `economy_constants.gd` and `habitat_constants.gd`. (`debug.gd` has exactly
  one, a docstring mention in `hud_test.gd:2`, which is not a use. `EnvConfig`,
  `SimulationConstants` and `TitleScreen` *are* touched — as fixtures and, for
  `TitleScreen`, asserted in `main_menu_test.gd:61-62` — which is why the
  matching V items are about coverage rather than about contact. An earlier
  draft of this note said seven, from a snake_case-only grep that missed every
  PascalCase class reference; 08-25 had it right at three.)
- **Headless boot from source:** both boots clean against the pinned 4.6.3
  binary. Bare → `[I] Title screen ready`. `-- --skip-menu` → `[I] Tutorial
  loaded. Press B to build the Bow Valley overpass. Press M for the world map.
  Press F1 for credits. F5 saves, F9 loads.` No `ERROR:` or `SCRIPT ERROR` in
  either.
- **CI:** `.github/workflows/ci.yml`, **297 lines** (was 279), five jobs —
  `tools:31`, `dco:64`, `test:81`, `export:129`, `smoke-windows:274`.
  `GODOT_VERSION: 4.6.3-stable` pinned at `:22`. **`workflow_dispatch:` is
  present at `:14`** — V9, closed 08-27 in `e5687cf`, re-verified in the file
  this session, and it carries a comment explaining why. `retention-days` is one
  line, `:261`, and now splits by event:
  `${{ github.event_name == 'pull_request' && 1 || 14 }}`. The structural caveat
  is unchanged: `if: always()` sits on two *steps* (`:232`, `:245`), not on the
  `export` job, and `smoke-windows` has a bare `needs: export` (`:276`), so a
  failing export **skips** it rather than turning it red. And per the 08-29 log,
  **four green plus a skipped `dco` is the correct shape on a push** —
  `ci.yml:66` gates `dco` with `if: github.event_name == 'pull_request'`, so
  "five green" is reachable only on a pull request. **Whether any CI run has
  passed is Unverifiable this session:** `which gh` → not found; `git fetch
  origin` → *Host key verification failed*; and the GitHub API is outside this
  session's fetch provenance (§Verification).
- **Build/export:**
  - `builds/` — `.gitignore`, `.gitkeep`, one empty directory, **4.0K. No
    binaries.**
  - `wildlife-crossing-desktop-builds/` — **411 MB**, newest mtime **2026-07-28
    03:31**, now **five weeks stale**. Size and mtime are measured here; the
    claims that they were built by Godot 4.6.0 and fail the repo's own pack gate
    are **carried from earlier reviews and not re-checked this session** — these
    binaries were not executed (this environment is arm64 Linux). Six reviews
    running have had to establish that these are not the build.
  - `git tag -l` → empty; `docs/release-notes/` → `.gitkeep` only. → **first
    build.**
  - A local export was **attempted this session and failed as expected**:
    `--export-release "Linux arm64"` → *Project export for preset "Linux arm64"
    failed*, with `~/.local/share/godot/export_templates/` empty. The sandbox
    cannot produce a binary; the build signal here is a source boot plus the
    suites.
- **Export presets:** all four still at their defaults on every item C1, C2 and
  C3 name — `export_presets.cfg:145` `codesign/codesign=1` (built-in ad-hoc),
  `:147` `apple_team_id=""`, `:148` `identity=""`, `:173` `notarization=0`,
  `:138-139` `short_version=""` / `version=""`, `:94` and `:133`
  `application/icon=""`, `:117` macOS `export_path` still ends `.zip`,
  `embed_pck=false` at `:26,57,88`, console wrapper on at `:25,56,87,132`,
  `exclude_filter="addons/gut/*,tests/*"` present on all four (`:11,42,73,116`).
- **Git:** branch **`main`**, `HEAD` = `00574b8` (2026-08-29 20:12:33 -0500,
  **three days ago**), `origin/main..HEAD` → **0**. `git tag -l` → 0.
  **Three vault files were uncommitted at the start of this session** —
  `2026-08-25-next-build.md` (M), `build-reviews/README.md` (M),
  `daily-logs/2026-08-29.md` (untracked) — exactly the three the 08-29 log
  listed as owed. Nothing else in the tree was dirty. **This note and its index
  edit make four.**
- **`.git/index.lock`:** present, 0 bytes, mtime **2026-09-01 07:22** — i.e.
  **it moved this session**, created by this session's own git commands from the
  Cowork mount. See §4: this settles a question three documents disagree about,
  and it settles it against the 08-25 ruling.
- **Untracked leftovers:** **six** `commit-plan*.json` at the repo root (was
  one), `tools/_to_delete/`, and ten `.DS_Store` files. All ignored —
  `git check-ignore -v` reports `.gitignore:33` (`/commit-plan*.json`) and
  `.gitignore:17` (`/tools/*`) — so none is stranger-visible. Cosmetic.

### Exit criteria, criterion by criterion

Unchanged and re-run this session: every Phase 1 and Phase 2 exit criterion is
**met in code and green in tests**, and **three of them have still never been
rendered to a human** — the crossing cue (visual + audio), the locked-sub-area
desaturation, and the connectivity overlay's orange→teal treatment. The implied
criterion — *an export of the current code launches* — last advanced on
2026-08-13.

What is missing is still not gameplay logic. It is a release a stranger could
install.

## 3. Work needed for the first build

Ordered the way you'd actually do it. Numbers are carried from
[[2026-08-25-next-build]]; **B8 and C8 are new**, appended rather than
renumbered. Where an item is materially unchanged this note gives the
re-verification and the acceptance bar, and points at 08-25 or 08-18 for the
full argument rather than restating it.

### Blockers (nothing ships until these exist)

#### B1b. Finish the Apple enrolment, and the certificate and API key behind it

- **Why it blocks:** [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
  makes a signed, notarized macOS build part of what `v0.1.0` *is*, and C1, C2
  and B6 all queue behind it. **The GPG half (B1a) is closed** — key
  `7F68A7E06349DA136226F04E2D5F1ED6EFFC08FD`, re-verified in `README.md:91` this
  session along with the two verification commands at `:98-99`. What remains is
  Apple, submitted **2026-08-27** (five days ago) and, as far as the repo
  records, still pending.
- **Files/areas:** none yet; later, the certificate and API key on the Mac —
  **not** in the repo (B8).
- **Acceptance:** runbook **A2–A4** — a **Developer ID Application** certificate
  issued (an "Apple Development" certificate signs fine and fails notarization);
  the Xcode licence accepted (A3, which is *not* gated on approval and can be
  done now); the **App Store Connect API key** created and stored (A4,
  `signing-runbook.md:90-101` — Apple permits exactly one download of the `.p8`).
- **Depends on:** Apple. **This is the only item on the page whose duration no
  amount of effort can compress**, and the fifth consecutive review says so.
  A3 is not gated and should just be done.
- **Size:** S effort, **days of calendar**
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A2–A4; ADR 0018;
  [[2026-08-25-next-build]] B1; [[../daily-logs/2026-08-27]].

#### B3. Walk the windowed verification checklist against a build of `HEAD`

- **Why it blocks:** unchanged in substance — the credits screen is the primary
  licence-compliance mechanism under
  [ADR 0017](../../docs/adr/0017-licensing.md), and if it renders illegibly the
  project is out of compliance and 237 unit tests cannot tell you. Three roadmap
  exit criteria are met only in code and have never been looked at.
- **What changed: it is unblocked, and it is no longer urgent.** B2 closed on
  08-29, so `main` carries the save/load system and CI ran against it. Under
  `ci.yml:261`'s new split a `push: [main]` run retains artifacts **14 days**, so
  the 08-29 post-merge artifacts survive until roughly **2026-09-12**. The
  08-25 note's two-day cliff is gone. If an artifact has nonetheless lapsed,
  `workflow_dispatch` now exists at `ci.yml:14` and the Actions UI has a *Run
  workflow* button — the recovery that V9 was written to provide.
- **Files/areas:** no code change expected. `tools/fetch_build.py`;
  [push-runbook](../../docs/push-runbook.md) Step 5.
- **Acceptance:** `gh run list --branch main --limit 1`, then
  `tools/fetch_build.py <run-id> --check`, then Step 5 walked to completion
  against that build: the menu appears and `Play` works; the credits screen opens
  from the menu **and** from `F1` and is **actually read** for legibility and
  scrolling; the HUD message line is legible; the "+N crossed safely" cue is
  **seen** firing and the chime **heard**; every key `main.gd` owns is pressed —
  **B**, **M**, **F1**, left-click, **Enter**, **Escape**, **F5**/**F9** — with
  an F5 / quit / relaunch / F9 round-trip, since quicksave to `user://` has never
  run from an exported binary; and the `codesign -dv` output **recorded**, which
  C1 needs.
- **Depends on:** none — **this is the top of the queue and it is clear.**
  Machine-gated: `fetch_build.py` shells out to `gh run download`, so it needs
  `gh` installed and authenticated on the Mac. Cannot run from this sandbox.
- **Size:** M
- **Refs:** [push-runbook](../../docs/push-runbook.md) Step 5; `ci.yml:261`;
  ADR 0017; [[2026-08-25-next-build]] B3; [[../daily-logs/2026-08-29]] §Next session.

#### B4. Decide how a Release ships something a stranger can run

- **Why it blocks:** unchanged and re-verified this session.
  `export_presets.cfg:26,57,88` still set `binary_format/embed_pck=false`, so the
  Linux build is `wildlife-crossing.x86_64` **+** `.pck` and the Windows build is
  `.exe` **+** `.pck` **+** a console wrapper (`:87`). A GitHub Release asset is a
  single file: a downloader who takes `wildlife-crossing.exe` on its own gets a
  Godot runtime with no game and no error explaining why. GitHub Actions
  artifacts also do not preserve the Unix executable bit.
- **Choose the archive, not `embed_pck`.** Root `CLAUDE.md` and
  [ADR 0017](../../docs/adr/0017-licensing.md):119-121 require every exported
  binary to ship `LICENSE` and `THIRD-PARTY-NOTICES.md`, and `ci.yml:231-239`
  places both in `builds/<platform>/` — which only reaches a downloader if the
  **archive** is the published asset. A bare embedded-pack `.exe` passes the "one
  file" test and quietly breaks ADR 0017.
- **Files/areas:** `game/export_presets.cfg`; `.github/workflows/ci.yml` export
  and upload steps **and the `smoke-windows` job** (`:294-295` hardcodes the
  `.exe` path and hard-fails if it is absent); `tools/check_pck_contents.py`;
  `tools/inspect_pck.py`, which has no test file of its own.
- **Acceptance:** each published asset is **one file that runs on a clean
  machine**, verified by extracting into an empty directory and launching with no
  reliance on a sibling file; the Linux binary is executable after download;
  `LICENSE` and `THIRD-PARTY-NOTICES.md` are **inside** the published asset; the
  console wrapper is dealt with — nothing currently says which of
  `wildlife-crossing.exe` and `wildlife-crossing.console.exe` a downloader runs;
  **and the signed manifest follows the decision.**
  `signing-runbook.md:297` builds `SHA256SUMS.txt` from a `find` matching
  `*.dmg`, `*.exe`, `*.pck` and `wildlife-crossing.x86_64` — **no archive
  extension matches that pattern**, and neither does `wildlife-crossing.arm64`
  the moment V4 goes the "export it" way. Updating that `find` is part of B4.
- **Depends on:** none now that B2 has closed. **Land it as one commit** with the
  `smoke-windows` and pack-gate updates, or the PR carrying it is red on its own
  gates. Carry C6 and C8 in the same PR.
- **Size:** M
- **Refs:** `export_presets.cfg:25-26,56-57,87-88`;
  [export-setup](../../docs/export-setup.md); [[2026-08-25-next-build]] B4.

#### B6. Cut `v0.1.0` — release note, tag, signed GitHub Release

- **Why it blocks:** this is the item that decides the build case, and nine
  consecutive reviews have answered "first build" on the same three facts — empty
  `builds/`, zero tags, empty `docs/release-notes/`. All three re-verified true
  this session.
- **Files/areas:** `docs/release-notes/v0.1.0.md`; a `v0.1.0` tag; a GitHub
  Release carrying the macOS image, the Windows and Linux packages from B4,
  `SHA256SUMS.txt` and its detached signature.
- **Acceptance:** the release note follows [docs/CLAUDE.md](../../docs/CLAUDE.md)
  format and states **all four** scope facts — Bow Valley only, the world map is
  look-only, placeholder art and the default Godot window icon
  (`export_presets.cfg:94,133` `application/icon=""`), and which artifacts are
  signed vs not and how to verify; the tag exists; `spctl`/`stapler` verify the
  notarized image per runbook A7; the GPG signature verifies per runbook B4; and
  the binaries report their own version (C3). Plus the runbook's gotcha: **clear
  `builds/` first** — runbook B3 sweeps that directory with a `find` to build the
  manifest, and `builds/wildlife-crossing-linux-arm64/` is sitting there now,
  empty today and populated the moment V4 goes the "export it" way.
- **Depends on:** B1b, B3, B4, C1, C2, C3, C5, C6, C7, **and V4** — V4 decides
  whether an arm64 binary exists in `builds/` at the moment runbook B3 sweeps it,
  so V4's outcome changes what gets signed. Settle it before the sweep, either
  way.
- **Size:** M
- **Refs:** ADR 0018 §Decision; [signing-runbook](../../docs/signing-runbook.md)
  A6–A8, B3–B4, C2; [[2026-08-25-next-build]] B6.

#### B7. Walk signing-runbook A8 — the real acceptance test

- **Why it blocks:** unchanged from 08-25, where it was new. It is the only item
  that closes the half of the build case this harness's definition turns on —
  *"an actual export in `builds/` or a GitHub Release **and** it launches."* B6
  cuts the Release; nothing verifies that a stranger can open it.
  `signing-runbook.md:227-236` is titled *"A8. The real acceptance test"*:
  download the DMG from the published Release, on a Mac that has never had this
  project on it, and open it. **"No Gatekeeper warning at all" is the pass
  condition.** Anything less — "unidentified developer", a right-click-to-open
  workaround, a quarantine prompt — means it isn't done. B6's acceptance stops at
  local `spctl` and `stapler`, and runbook A7 is titled *"do not trust the export
  log"* for exactly that reason.
- **Files/areas:** none. A second Mac (or at minimum a fresh user account,
  though a clean machine is the real test), the published Release, and a
  daily-log entry.
- **Acceptance:** the DMG downloaded **from the Release URL** on a machine that
  has not had the project, opened with **no Gatekeeper warning of any kind**; the
  same session confirms the Windows and Linux assets extract and launch on a
  clean machine per B4's acceptance; and **the result recorded in
  `obsidian-vault/daily-logs/`** — the runbook says the log entry is part of the
  test.
- **Depends on:** B6. This is the last item, and it is the one that changes the
  build case from *first* to *next* in the following review.
- **Size:** S — assuming it passes. If it does not, it reopens C1 and C2, which
  is precisely why it must be walked rather than assumed.
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A8, A7; ADR 0018
  §Decision; the harness's own definition of "working build".

#### B8. Harden the credential path before A4 lands

- **Why it blocks:** **new this review**, and it is the item that inherited B3's
  deadline. Three facts, each verified this session, that are individually minor
  and jointly a trap:
  1. `.gitignore` carries **no credential patterns at all** — no `*.p8`, `*.p12`,
     `*.cer`, `*.mobileprovision`, no `.env`. `grep -in` for that whole set
     returns **nothing**, exit 1. (This is the one of the three verified from
     the repo this session.)
  2. Per [[../daily-logs/2026-08-29]], the repository has been **public since
     2026-08-29** and secret scanning, push protection and the branch ruleset
     are **not configured** — all GitHub-side state this session could not read,
     so treat it as three days old rather than current. The 08-29 log also
     argues that push protection would not save a `.p8` anyway, since it matches
     known provider token formats and a `.p8` is a generic private key; that
     reasoning is the log's, not independently checked here. Either way the
     ignore rule is the control that does not depend on it.
  3. **`.gitignore:5-6` is a landmine sitting directly on C1.** It says to
     re-ignore `export_presets.cfg` if identities or keys are ever added. The
     file is **tracked**, so adding the ignore rule alone does nothing: it needs
     `git rm --cached` as well. Nothing outside that comment records this, and
     C1's whole job is to write an Apple identity into that file.
  The reason this is a blocker and not housekeeping: **the timing is Apple's, not
  the project's.** A4 delivers a one-download-only `.p8` at a moment nobody
  controls, into whatever state the repo happens to be in. It costs minutes now
  and a key rotation later.
- **Files/areas:** `.gitignore`; GitHub repository settings (secret scanning,
  push protection, a branch ruleset limited per the 08-29 decision to blocking
  force pushes and restricting deletions — *not* linear history, which forbids
  the merge commits B2's strategy depends on, and *not* required approvals, which
  lock out a sole maintainer).
- **Acceptance:** `.gitignore` carries `*.p8`, `*.p12`, `*.cer`, `*.pem`,
  `*.key`, `*.mobileprovision` and `.env`; secret scanning and push protection
  are on and that is written down; the `git rm --cached export_presets.cfg`
  requirement is recorded somewhere an operator doing C1 will read — the
  signing runbook's Part A pre-flight, not only a `.gitignore` comment.
  **Not in scope:** the GPG revocation certificate and off-machine backup that
  `signing-runbook.md:259-268` requires. Those are **done** —
  [[../daily-logs/2026-08-26]]:20 records the certificate generated and stored
  off the machine holding the key — and this note's completeness audit proposed
  adding them, which is exactly the kind of item that gets rebuilt because a
  closure was recorded in a log nobody re-read.
- **Depends on:** none. **Do it before A4 lands, which means do it now.**
- **Size:** S
- **Refs:** [[../daily-logs/2026-08-29]] §Open questions; `.gitignore:5-6`;
  [signing-runbook](../../docs/signing-runbook.md) A4, `:90-101`.

### Core build work

C1–C7 are unchanged from [[2026-08-25-next-build]] and were re-verified open this
session against the file and line numbers given. Full reasoning is in that note.
**C8 is new.**

#### C1. Configure macOS signing in the export preset

- **Re-verified:** `export_presets.cfg:145` `codesign/codesign=1`, `:147`
  `apple_team_id=""`, `:148` `identity=""`, `:173` `notarization=0` — all four
  still at defaults.
- **Files/areas:** `game/export_presets.cfg` preset 3. **The file is tracked and
  Godot writes secrets into it** — use the `GODOT_MACOS_NOTARIZATION_*`
  environment variables and diff before every commit. See B8 for the
  `git rm --cached` requirement that `.gitignore:5-6` does not state. Leave the
  `Debugging` entitlement `false`.
- **Acceptance:** a signed test export from Brent's Mac that `spctl -a -vvv`
  accepts and whose ticket `stapler validate` confirms (runbook A7 — *"do not
  trust the export log"*). Also settle whether `export/distribution_type=0`
  ("Testing", `:128`) needs to change. B3's recorded `codesign -dv` output is the
  first input.
- **Depends on:** B1b (the certificate and the API key), and B8 should land
  first. **Size:** M
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A5, A7; ADR 0018.

#### C2. Change the macOS export target from `.zip` to `.dmg`

- **Re-verified:** `export_presets.cfg:117` still ends `.zip`. You cannot staple
  a notarization ticket to a `.zip`, and the `.zip` is why `LICENSE` and
  `THIRD-PARTY-NOTICES.md` land *beside* the archive rather than inside the
  bundle — the gap `ci.yml:227-230` acknowledges in its own *"Known gap"* comment
  (line numbers corrected from 08-25's `:220-223`).
- **The real interaction:** changing the container does not break the CI pack
  gate — `ci.yml` passes an explicit output path that overrides `export_path`. It
  is worse and quieter: the release `.dmg` is built locally
  (`signing-runbook.md:188`), never in CI, and `check_pck_contents.py`'s
  `resolve_pck` accepts only a `.pck`, a `.app` directory or a `.zip`. **The
  artifact that actually ships is gated by nothing.**
- **Acceptance:** the macOS preset exports a `.dmg`; **the pack inside the
  shipped image passes `check_pck_contents.py`**, run against the image or the
  mounted `.app`, and that run recorded in the release log; its tests cover the
  new input; CI's export job stays green; `LICENSE` and `THIRD-PARTY-NOTICES.md`
  are inside the image, added **before** signing (modifying a signed bundle
  silently invalidates it).
- **Depends on:** the preset edit depends on nothing; the acceptance requires
  teaching `resolve_pck` to accept a `.dmg`, a `tools/` change with its own tests
  that has to land through a PR. Do the preset in the same pass as C1 and land
  the tools half with B4's commit. **Size:** M
- **Refs:** ADR 0018; [signing-runbook](../../docs/signing-runbook.md) A5–A6.

#### C3. Set the version metadata the export presets never got

- **Re-verified:** `export_presets.cfg:138-139` still `short_version=""` and
  `version=""`; the Windows preset has no `file_version`/`product_version` at
  all, while `project.godot` carries `config/version="0.1.0"`. An empty
  `CFBundleShortVersionString` is a notarization risk.
- **Acceptance:** `application/version` and `application/short_version` read
  `0.1.0`; Windows `file_version`/`product_version` set; a built binary's
  reported version matches the `v0.1.0` tag.
- **Depends on:** none. Cheapest item on the list and on B6's critical path — do
  it while waiting on Apple. **Size:** S
- **Refs:** ADR 0018 §Consequences; [signing-runbook](../../docs/signing-runbook.md) A5.

#### C4. Decide the tutorial camera focus

- **Re-verified:** `main.gd:18` still `const CAMERA_FOCUS_COORD := Vector2i(13, 6)`,
  consumed at `:71`. The 2026-08-10 measurement found row 6 has zero measured
  deaths and about 10 crossing uses, while 70 of 73 baseline deaths happen on
  rows 0–2 and row 1 logs 192 uses. The opening camera points at the one part of
  the tutorial where nothing happens, on the first screen of the first build a
  stranger will ever see. Flagged to the owner on 08-10 — **twenty-two days
  ago** — still undecided, and it is one line.
- **Acceptance:** a one-line change or an explicit recorded decision to keep it;
  either way the answer is in a log **before** C5's QA pass runs.
- **Depends on:** none. **Needs an owner call.** **Size:** S
- **Refs:** [[../daily-logs/2026-08-10]] §Open questions;
  [[../design/detour-cost-question]]; `tools/measure_tutorial.gd`.

#### C5. Visual + audio QA pass, written down

- **Re-verified:** owed since 2026-07-08 and kept in v0.1.0 scope by the
  2026-08-06 decision. Three roadmap exit criteria are met only in code and have
  never been looked at. **One of them cannot be observed at all** — Phase 2's
  fourth criterion runs through `ConfirmPanel`, and `main.gd:215` says outright
  *"**Unreachable from the map screen in v0.1.0.**"* It is met in tests
  (`confirm_panel_test.gd`) and undemonstrable by hand; do not send a QA pass
  looking for it. **C9 is what disposes of it in writing.**
- **Acceptance:** a note in `obsidian-vault/daily-logs/` confirming each Phase 2
  visual criterion observed on screen (locked desaturation + lock indicator;
  overlay orange→teal at ~40%, appearing only in segment mode and clearing), the
  crossing cue visible **and** audible once per coalesced window, the HUD message
  line legible, the credits screen legible and scrollable, a quicksave/quickload
  round-trip in the export, and — still never captured by any log — **the Godot
  version installed on Brent's Mac** (which is also C7's input).
- **Depends on:** B3 (observed in the export, not the editor), C4 (decide the
  camera first). Best done in the same session as B3. **Size:** S
- **Refs:** roadmap Phase 2 exit criteria; the 2026-08-06 decision block.

#### C6. Add the verification copy to the download section

- **Re-verified this session:**
  `grep -in "gpg\|sha256\|smartscreen\|unsigned\|fingerprint" website/index.html
  website/user-guide.html` → **zero hits**. The `README.md` half is now done
  (`:91`, `:98-99` carry the fingerprint and both commands); **the website half
  is untouched**, and the site is now publicly reachable with a download button
  (`website/index.html:55`) pointing at an empty Releases page.
- **Acceptance:** the download area names each published asset, states plainly
  that Windows is unsigned and what SmartScreen will say, gives the GPG
  fingerprint and the two verification commands, and does **not** imply the GPG
  signature suppresses any OS warning (runbook C2 is explicit about that
  conflation). **And it says how to run the thing** — nothing anywhere does.
  Open the image and drag to Applications; `chmod +x` the Linux binary; keep the
  `.pck` beside the binary if B4 goes that way. **And settle the eight species
  portraits while you are in this file.** `website/assets/img/species/*.png` are
  eight images on the public site with no entry in `THIRD-PARTY-NOTICES.md`,
  and `LICENSE-ASSETS` covers original work only — see §5. C6 is the one
  scheduled edit to the page they sit on, so it is the cheapest moment to
  either add the line saying they were authored here or add the notice.
- **Depends on:** B4 (the asset list). C6 is a repo change that must be *carried
  by* a merge, not scheduled after one: `deploy-website.yml:7-17` publishes on
  push to `main` touching `website/**`, `obsidian-vault/wiki/**` or
  `tools/build_encyclopedia.py`. Land it in B4's PR. **Size:** S
- **Refs:** ADR 0018 §Follow-on work;
  [signing-runbook](../../docs/signing-runbook.md) C2; `website/CLAUDE.md`.

#### C7. Pin the release machine's engine, and install its export templates

- **Re-verified:** unchanged. The shipping `.dmg` is built **locally on the Mac**
  (`signing-runbook.md:188`), never in CI, so the one artifact a stranger
  downloads is produced by an engine no gate has ever checked. Three things
  depend on it being 4.6.3-stable specifically: **ADR 0012's 2026-07-28
  amendment** pins the exact patch for CI (the Decision line itself says only
  "4.6 stable", which is the nuance `testing-setup.md:22` gets caught on in §4);
  `THIRD-PARTY-NOTICES.md:25` **hard-codes "Godot Engine 4.6.3-stable"**, so a
  `.dmg` built by another patch ships a licence document that is factually wrong,
  which is an ADR 0017 obligation; and the credits screen renders whatever engine
  actually built the binary. The precedent is in the tree —
  `wildlife-crossing-desktop-builds/` was built by 4.6.0 against a pipeline
  pinned to 4.6.3. **This session's failed sandbox export is the same failure in
  miniature**: the engine looked for `4.6.3.stable/` by name and found an empty
  directory.
- **Files/areas:** no repo change necessarily; a line in the daily log, and
  ideally a pre-flight step in `docs/signing-runbook.md` Part A.
- **Acceptance:** the Mac's `Godot --version` recorded in a log and **equal to
  `4.6.3.stable`**; the matching export templates installed at
  `~/Library/Application Support/Godot/export_templates/4.6.3.stable/` and the
  path confirmed; and the release `.dmg` built by that engine.
- **Depends on:** none — do it before C1/C2's first signed test export, since a
  re-export on a different engine invalidates the signature anyway. **It has
  download lead time and nothing interesting in it**, which is the 08-29 log's
  own argument for starting it early. **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md):8-16;
  [signing-runbook](../../docs/signing-runbook.md):188; ADR 0012;
  `THIRD-PARTY-NOTICES.md:25`.

#### C8. Write down that the repository is public

- **Why: new this review**, and it is the residue of B5 rather than a reopening
  of it. B5's acceptance was *"either the repo is confirmed public and that is
  written down once"*. The flip happened on 08-29 and
  [[../daily-logs/2026-08-29]] records it, but that log is **still untracked**,
  so the only record of the project's licensing and threat-model premise
  changing is a file that is not in the repository. Re-verified this session:
  `grep -in "public" README.md` → nothing about repository visibility;
  `CONTRIBUTING.md` mentions "public" only about CC0 and git history.
- **Files/areas:** `README.md` or `CONTRIBUTING.md`; and the 08-29 log itself
  needs committing (§5).
- **Acceptance:** one durable sentence in a tracked file stating the repository
  is public and since when, plus the 08-29 log committed.
- **Depends on:** none. Ride it along with any commit. **Size:** S
- **Refs:** [[2026-08-25-next-build]] B5 acceptance;
  [[../daily-logs/2026-08-29]] §Open questions.

#### C9. Disposition Phase 2's fourth exit criterion in the roadmap

- **Why: new this review**, and it is the only new item that touches the
  definition of the build case rather than the work behind it.
  `roadmap.md:119-120` requires that *"Confirm passes the correct
  `(segment, sub_area)` into the construction step; click-outside and Escape
  behave per spec."* `main.gd:215-221` records that the path to `ConfirmPanel`
  is *"**Unreachable from the map screen in v0.1.0**"* and is *"only reached
  once the in-map segment renderer lands (build-review C1)"*. So the criterion
  is **met in tests and unreachable in the artifact a stranger runs.** Nine
  reviews have asserted "every Phase 1 and Phase 2 exit criterion is met" and
  this note repeats it; C5 handles the consequence operationally (*don't send a
  QA pass looking for it*) and the deferrable bullet about un-deferred Phase 2
  work explicitly scopes itself to the **Implements** list, saying *"None is an
  exit criterion, so none blocks the build."* **Nothing writes the decision that
  lets `v0.1.0` legitimately claim Phases 1–2 met.** The 2026-08-06 decision
  block deferred the world map to look-only; it did not say what that does to
  this criterion.
- **Files/areas:** `docs/roadmap.md` Phase 2 §Exit criteria — a decision block
  in the same style as the 2026-07-29 and 2026-08-06 ones. **Not** a code
  change.
- **Acceptance:** the roadmap states, in writing and dated, either that the
  criterion is met by `confirm_panel_test.gd` with the in-artifact path
  deferred to C1 and why that is acceptable for v0.1.0, or that it is deferred
  outright. Either way the release note (B6) can then state the scope fact
  honestly, and the next review can stop asserting something with a footnote.
  **Fold the three un-deferred Phase 2 Implements items into the same block** —
  the toolbar tool, the P1 group, and the controlling-entity mapping — since it
  is one decision block for all four and cheaper than writing it twice.
- **Depends on:** none. **Needs an owner call**, like C4. **Size:** S
- **Refs:** `docs/roadmap.md:119-120`; `main.gd:215-221`; the 2026-08-06
  decision block; ADR 0015.

### Verification (tests, CI, export)

V1–V8 are unchanged from [[2026-08-25-next-build]] and were re-verified open this
session. **V9 closed on 2026-08-27 in `e5687cf` and is confirmed in the file at
`ci.yml:14`** — it is not carried here.

#### V1. Add `env_config.gd` coverage

- **Re-verified:** `game/tests/` has 23 `*_test.gd` and none is
  `env_config_test.gd`. `EnvConfig` is *instantiated* as a fixture in
  `species_manager_test.gd:13,30` and never asserted, which is coverage of
  nothing. Still the only untested script carrying real branching logic —
  the per-terrain mortality lookup and the resolution order (override → OS env →
  `DEFAULT = 0.20`), which is exactly what the Phase 1 criterion *"deaths at the
  configured env-var rate"* rests on.
- **Acceptance:** resolution order covered end to end; suite reaches 24 scripts.
  GUT only discovers a new `*_test.gd` after a re-`--import`. **Size:** S

#### V2. Cover `species_registry.gd` and the constants files

- **Re-verified:** `species_registry.gd` (53 LOC) still has **zero** test contact
  of any kind, and so do `economy_constants.gd` and `habitat_constants.gd`.
  `SimulationConstants` does have contact — `connectivity_overlay_test.gd:137,144,145,152`,
  `confirm_panel_test.gd:116,129`, `world_select_controller_test.gd:7,8` — but
  every one of those reads it as an *input*, which is the opposite of asserting
  it. No test asserts any of the three constants files against the values
  `data-schemas.md` §10 specifies normatively.
- **Acceptance:** `species_registry` load-failure path covered; constants values
  asserted against `data-schemas.md` §10, and §10 either gains
  `HAZARD_AVOIDANCE_MULT` (which `simulation_constants.gd` itself flags as absent
  from §10) or the constant is justified in a comment. **Size:** S

#### V3. Reconcile `docs/test-plan.md` §11 against the real suite

- **Re-measured by script this session:** of **43** uniquely named tests in
  §11 (`docs/test-plan.md:145`), **35 have no matching `func test_` in
  `game/tests/` — 81%.** Identical to the last three reviews, as expected since
  no test file changed.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason. **Size:** S

#### V4. Export the `Linux arm64` preset in CI, or delete it

- **Re-verified:** `export_presets.cfg:32-62` (`[preset.1]`) defines a preset CI never builds —
  `ci.yml:172,174,176` names exactly three presets — and
  `builds/wildlife-crossing-linux-arm64/` sits empty as its ghost. It is also the
  architecture this sandbox runs on, which is the main reason to prefer "export
  it": it would let a future review boot a real artifact instead of reasoning
  about one, as this session again could not.
- **Acceptance:** either the arm64 artifact appears in the CI upload and passes
  `check_pck_contents.py`, or the preset and the empty directory are gone.
- **Depends on:** none now. **Settle it before B6**, since it changes what
  runbook B3's `find` sweeps into the signed manifest. **Size:** S

#### V5. Exercise the `dco` job on a deliberately unsigned commit

- **Re-verified half closed:** the job has been seen green on PR #1. Its
  acceptance also requires observing it **red**, which has not happened. A gate
  seen only green is a gate whose failure path — the branch that rejects an
  outside contributor's work — is untested. **This matters more than it did last
  week:** the repository is public, so an outside contribution is now possible
  rather than hypothetical.
- **Acceptance:** the `dco` job observed red on an unsigned commit and green once
  signed off; the throwaway PR closed without merging. **Size:** S

#### V6. Make the zero-tests guard report why it failed, and catch partial drops

- **Re-verified at `ci.yml:113-127`** (corrected from 08-25's `:106-120`). Two
  problems. `:122` is
  `TESTS="$(grep -oE '<testcase' "$XML" | wc -l | tr -d '[:space:]')"` under
  `set -euo pipefail` — if GUT records zero test cases, `grep` exits 1, the
  substitution fails, and `set -e` kills the step **before** the `::error::` at
  `:125` can print. And the guard catches only `TESTS -eq 0`, whereas the failure
  it was designed for (2026-07-19) was a **partial** drop where a parse error
  removed one file and GUT still exited 0. At 23 scripts, a run that silently
  lost 22 still passes.
- **Acceptance:** a zero-test run prints the `::error::` before exiting; CI fails
  when the JUnit XML reports fewer than the expected number of test scripts
  (currently **23**); both verified against synthetic XML. **Size:** S

#### V7. Teach `build_encyclopedia.py` to delete, and test it

- **Re-verified:** `tools/build_encyclopedia.py` (686 LOC) contains **zero**
  occurrences of `unlink`, `os.remove` or `rmtree` — it only ever writes — while
  `deploy-website.yml` gates on `git diff --quiet -- website/encyclopedia`. A
  **new** wiki entry produces an **untracked** file `git diff` cannot see, so the
  gate passes green while the deployed site is missing the page; a **deleted**
  entry leaves an orphan. Still the largest untested tool; `inspect_pck.py` is
  the one that matters for B4, since it is the actual pack parser behind
  `check_pck_contents.py`.
- **Acceptance:** the generator removes pages whose wiki source is gone; the CI
  gate detects an untracked generated file (`git status --porcelain` as well as
  `git diff`); round-trip and external-asset checks covered by tests. **Size:** M

#### V8. Assert the two runtime assets survive export

- **Re-verified:** both assets exist —
  `game/assets/audio/crossing_chime.wav` (61,782 bytes) and
  `game/assets/sprites/crossing_cue.png` (341 bytes) — and both are `preload`ed,
  while `game/.gitignore` excludes `*.import`, so both are re-imported every CI
  run. A missing asset fails the smoke boot (a failed `preload` is a compile
  failure, so `Tutorial loaded` never prints) — so this is covered, but by a gate
  that reports *the binary did not boot*, not *the chime is missing*.
- **Acceptance:** the pack gate asserts both asset paths are present and names
  them when they are not; the test covers a pack missing one. **Size:** S

### Deferrable / nice-to-have

Carried from [[2026-08-25-next-build]] unless noted:

- **63% of visible animals die in the first in-game day** — about ten real
  seconds at 1×, before the player can build anything. Inherited from
  `EnvConfig.DEFAULT = 0.20` rather than chosen. A live tension with the
  *"cozy, not stressful"* north star.
- **Delete the stale `wildlife-crossing-desktop-builds/` artifacts.** 411 MB,
  **now five weeks old**, built by Godot 4.6.0 against a pipeline pinned to
  4.6.3, failing the repo's own pack gate. Six reviews running have had to
  establish that they are not the build. `fetch_build.py` downloads into
  run-scoped directories, so nothing needs this fixed path any more.
- **Untracked clutter has grown from one commit plan to six.**
  `commit-plan.json`, `-2026-08-14b`, `-2026-08-27`, `-2026-08-27b`,
  `-2026-08-27c`, `-2026-08-29`, plus `tools/_to_delete/` and ten `.DS_Store`
  files. All confirmed ignored (`.gitignore:33` and `:17`), so **none is
  stranger-visible** and this is genuinely cosmetic — noted only because the
  count is now growing on its own.
- **`game/scenes/world/Animal.tscn` is dead weight** — re-verified this session:
  `grep -rn "Animal.tscn" game/` returns `game/CLAUDE.md:76` and two `.godot`
  cache entries, and **no script or scene**. Agents are drawn as circles by
  `world_renderer.gd`. Delete or wire. ADR 0015's title names it, so the
  deletion should carry a line explaining that.
- **`entities.json` has no production consumer** beyond `species_registry.gd:26`
  indexing it. (`data_validation_test.gd:99,104` also read it, so the file is
  schema-tested — it is the *game* that never uses the contents.) Phase 2's
  Implements list requires the controlling-entity mapping "consumed as data";
  C9's decision block should say so or defer it.
- **The twelve world maps are template-scale.** `sub_areas.json` declares
  `playable_tile_count: 4000` for each; each map in `data/world/` resolves to
  238–312 cells — 92–94% below the ±15% acceptance criterion in
  `data-schemas.md` §11 — and `data_validation_test.gd` asserts only the
  *declared* number, never the resolved grid.
- **`connectivity_overlay_test.gd` and `species_manager_test.gd` build their
  fixtures from hand-copied const dicts** rather than reading `res://data/`, so a
  drift between those constants and the shipped JSON would leave them green.
- **Three Phase 2 Implements items are neither built nor deferred in writing:**
  the "toolbar tool" P0 (`main.gd:332` is a *"Placeholder trigger for the PRD's
  \"Add crossing\" toolbar action"*, reached from `KEY_M` at `:142-144`), the
  entire Phase 2 P1 group (hover score, segment label, crossing-count note,
  sub-area summary on hover), and `sub-areas`' "controlling-entity mapping
  consumed as data". None is an exit criterion, so none blocks the build — but
  §1's claim that Phases 1–2 are met *"as scoped by the logged decisions"* is
  true of the **exit criteria**, not of the Implements lists. **C9's decision
  block should close all three in the same pass.**
- **The detour-cost measurement covered Bow Valley only.** The other 17
  non-bisecting segments remain unmeasured.
- **`website/CLAUDE.md:79`** still specifies user-guide section 2 as *"Placing
  habitats"*, which the shipped guide does not match.
- **`BaseScreen` retrofit** of `ConfirmPanel` and `ConnectivityOverlay` —
  deliberately deferred 07-31.
- **Real art.** `game/assets/fonts/` and `tilesets/` are **empty but for
  `.gitkeep`** (re-verified this session); `crossing_cue.png` is a 341-byte
  generated placeholder. The eight species portraits ship on the public site but
  are unwired in the game.
- **Eight of the ten `.gitkeep` files under `game/` sit in directories that are
  no longer empty** — harmless, and the cheapest possible tidy. The other two,
  in `assets/fonts/` and `assets/tilesets/`, are still doing their job, which is
  itself the "real art" bullet above.
- Windows signing remains deliberately out of scope per ADR 0018's stated
  triggers. Phase 5 gates remain open and still do not block P0.

## 4. Doc drift to fix

Record only — docs are not edited during a review. Every row was re-verified this
session. **Two rows leave the table by being fixed** — the first time more than
one has closed in a single week — and **two rows are new**, one of which is a
correction to the last review's own ruling.

### Closed since 08-25

| Doc | Was | Now |
|-----|-----|-----|
| [README.md](../../README.md):25 | Pointed at `.claude/CLAUDE.md`, which has never existed. (08-25 cited this as `:22`, which is the `## Development` heading; the link is at `:25`.) | Fixed in `00574b8`; the link resolves to the root `CLAUDE.md` |
| [README.md](../../README.md) and root [CLAUDE.md](../../CLAUDE.md) structure blocks | Neither listed `harness/` or `tools/`; `README.md` also omitted `.github/` | Fixed in `8340749`. Re-verified: `README.md:13,19,20` and `CLAUDE.md:37,43,44` all carry them |

### Still open

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | "`game/` is still almost entirely `.gitkeep`" (`:20`); A1 "no `project.godot`"; A2 "GUT … not yet installed"; A3 "no CI"; A4 "zero game code"; A5 "only `sub_areas.json` and `biome_groups.json`"; A7 "`game/assets/` is all `.gitkeep`" | Every claim is false — 30 scripts / 3,569 LOC, 4 autoloads, GUT 9.6.0 vendored, a 297-line five-job CI, all 8 data files plus 12 world maps valid, 23 test scripts / 237 tests, two real assets. **Flagged in seven consecutive reviews and never fixed, and the severity changed on 2026-08-29: the repository is public, so this is now a stranger-facing onboarding document that describes a project that does not exist.** `status: active`, `date: 2026-06-28`. Longest-running item on this table and the cheapest to close. |
| [testing-setup.md](../../docs/testing-setup.md):69-70 | "the suite currently reports **16 scripts / 134 tests / 2,779 asserts**" (dated 2026-07-30) | Measured this session: **23 scripts / 237 tests / 3,032 asserts**. Stale at seven consecutive reviews and corrected six times — worth generating from the JUnit XML rather than maintaining by hand. |
| [testing-setup.md](../../docs/testing-setup.md):22 | "**Godot 4.6** (stable). Any 4.6.x patch is fine" | Contradicts `ci.yml:16-20` and **ADR 0012's 2026-07-28 amendment**, which pin the exact patch deliberately because export-template paths are version-keyed — as this session's failed export demonstrated again. **Refined this review:** ADR 0012's *Decision* line does say "4.6 (stable)", so `testing-setup.md:22` is consistent with the decision and inconsistent with the amendment and with CI. That is a worse kind of stale, not a lesser one — a reader who checks the ADR's decision line comes away reassured. Carried unfixed. |
| [testing-setup.md](../../docs/testing-setup.md):142-147 | "### Known gap … Consider adding a CI assertion that the run actually collected tests" | Partly implemented at `ci.yml:113-127` — zero case only, and its error message is unreachable under `set -e`. See V6. |
| [testing-setup.md](../../docs/testing-setup.md):36 | "`.gitignore` excludes `/tools/`, which is where the binary lives" | It excludes `/tools/*` then re-includes `*.py`, `*.sh`, `*.gd` and `/tools/tests/`; the sentence reads as though nothing in `tools/` is committed, which is wrong — `git ls-files tools/` returns nine scripts and five test files, and they are now publicly visible. (08-25 quoted this line as *"The repo's root `.gitignore`…"*; the file says just *"`.gitignore`"*. Corrected here.) |
| [roadmap.md](../../docs/roadmap.md):49-50 | Phase 1 exit criterion "A fully spanned overpass yields a zero-mortality route" | Still predates [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md); "fully spanned" now means a valid **span** (two-sided core), not full segment coverage. The code is correct; the criterion's wording is not. Carried unfixed from five reviews. |
| [roadmap.md](../../docs/roadmap.md):147, :148, :156 | The 2026-08-06 decision block cites Phase 2's exit criteria as `:98-108` and its Implements list as `:80-92` | The same session's insertion moved them; the exit criteria are now at `:112-122` and the Implements list at `:94-108`. Cite the heading, not the line — which is also the lesson of §1's third finding. |
| [roadmap.md](../../docs/roadmap.md):163, :174 | States in the present tense that `WorldSelectMap.tscn` *"sets `mouse_filter = 2` (IGNORE)"* and that the blind click *"Needs a regression test"* | Both closed by `cb9f9b8`: the scene sets STOP and `world_select_controller_test.gd` carries the regression test (`test_world_select_map_scene_stops_mouse_events` and `test_left_click_in_segment_mode_selects_nothing` both ran green this session). The decision block reads as a live defect report. |
| [test-plan.md](../../docs/test-plan.md) §11 (`:145`) | P0 coverage table presented as the first-playable bar | 35 of 43 named tests have no matching function (81%, re-measured this session). See V3. Carried unfixed. |
| [architecture.md](../../docs/architecture.md):44-69 | Lists systems and UI scripts that do not exist | Seven system scripts absent (`economy_manager`, `information_manager`, `permissions_manager`, `season_manager`, `time_controller`, `milestone_tracker`, `narrative_manager`) plus most of the UI roster; all Phase 3–6, so not a regression, but the table reads as a description of the codebase and overstates it. §8 cross-references only ADRs 0001–0005 of the 18 that exist. Split into *planned* vs *built*. |
| [game/CLAUDE.md](../../game/CLAUDE.md):86-100 | Systems table names 13 files, of which 6 are built | **24 of the 30 built scripts are absent** from it, including `simulation.gd`, `main.gd`, all four autoloads, all three constants files, `world_renderer.gd` and all ten UI scripts; there is no UI section. The file states its own rule at `:102-104` — *"Add a row here whenever a new system is created"*. Now a six-week-old convention miss. |
| [push-runbook.md](../../docs/push-runbook.md):134, 266, 301 | Dated "2026-08-14" | The work was 2026-08-13 local. Cosmetic; self-reported and uncorrected. |
| [signing-runbook.md](../../docs/signing-runbook.md):392 (Part D.3) | *"**Gate the other two platforms' packs.** Build-review V2 is still open: the pck gate and smoke boot run on the Linux binary only."* | **The claim is false and still in the file.** `ci.yml:208` runs `check_pck_contents.py` against all three packs in a loop and `ci.yml:274-297` boots the `.exe` on `windows-latest`. `export-setup.md:92-102` already describes this correctly, so the repo contradicts itself. The warning would send an operator to re-do work that landed 2026-08-10. |
| [adr/0018](../../docs/adr/0018-code-signing-and-notarization.md):165 §Follow-on work | *"Build-review **V2** (gate the Windows and macOS packs, not just Linux) should land before or with this."* | Same falsified claim, in the ADR that governs the release. It is the one §Follow-on item that reads as open and is in fact **closed**. Strike it, or mark it done with the commit that closed it. |
| [ci.yml](../../.github/workflows/ci.yml):227-230 | *"Known gap … The durable fix is an in-game credits screen built from `Engine.get_copyright_info()`"* | Half closed: the credits screen shipped 2026-08-09 (`66cf279`). Only the `.zip`-places-notices-beside-the-bundle half is still live, which is C2. |
| [ci.yml](../../.github/workflows/ci.yml):275 | `smoke-windows` job name: *"Smoke-test the Windows binary (boots to Main.tscn)"* | `run/main_scene` is `TitleScreen.tscn`; the job reaches `Main` only via `smoke_boot.sh`'s `--skip-menu`. Cosmetic, but the job name is what an operator reads first when the gate goes red, and it names the wrong scene. |
| **NEW** — [2026-08-25-next-build.md](2026-08-25-next-build.md) §4, [push-runbook.md](../../docs/push-runbook.md) §Troubleshooting, `tools/ship.py:380-388` | The 08-25 review ruled the `.git/index.lock` cause **"unknown"**, on the evidence that its mtime had not moved across two sandbox sessions, and filed the 08-13 explanation as falsified | **The evidence 08-25 ruled on is gone.** The lock's mtime this session is **2026-09-01 07:22** (0 bytes) — it *does* move, and it moved for this session's own git commands from the Cowork mount. So "the mtime never moves" is no longer a reason to doubt the 08-13 account. The mechanism itself — *the mount forbids `unlink`, so git commands run there leave the lock behind* — rests on the `Operation not permitted` warning observed on 08-29 and **was not reproduced this session**, so it is well-supported rather than proven. Either way it does not describe the Mac, where `ship.py` cleared a 1,552-second-old lock without complaint. Three places in the repo carry three different accounts; write the 08-13 one down once, scoped to the sandbox, and stop revising it. Harmless throughout (`ship.py:83` `STALE_LOCK_SECONDS = 120`). |
| **NEW** — every `ci.yml` line citation in [2026-08-25-next-build.md](2026-08-25-next-build.md) | `:243` retention, `:3-7` triggers, `:106-120` guard, `:220` known gap, `:256`/`:258`/`:276-279` smoke-windows, "279 lines" | All shifted by `e5687cf`, which grew the file to **297 lines**. Corrected in §3 above: `:261`, `:4-14`, `:113-127`, `:227-230`, `:274-276`, `:294-295`. Not a defect in any document that is still authoritative — but the open work items are read from the *latest* review, so stale line numbers in a carried item are a live trap. **This is the second review running where line-number drift is the largest single category of error, and this note's own first draft contributed eight more before its audits caught them** (§Verification). The pattern is now strong enough to act on: cite headings, job names and step names; use lines only where the source document itself does. |
| **NEW** — [export-setup.md](../../docs/export-setup.md):97 | *"uploads everything as a workflow artifact (14-day retention)"* | Made false for pull-request runs by `e5687cf`, the same commit that closed V9: `ci.yml:261` is now `retention-days: ${{ github.event_name == 'pull_request' && 1 || 14 }}`, so PR artifacts live **one day**. This row is the mirror image of the `export-setup.md:97` row 08-18 closed — the doc went stale again, at the same line, from a fix nobody propagated. Worth one sentence in the same edit that fixes it: this file is downstream of `ci.yml` and should say so. |
| **NEW** — [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md):130-135 | Records that GUT's bundled `OFL.txt` *"carries only the Anonymous Pro copyright statement … it does not include copyright lines for Courier Prime or Lobster Two"* and that those *"must be sourced and added here first"* if the project ever ships them | **Not stale — correct, and load-bearing in a way no review has noted.** The obligation is discharged only by `exclude_filter="addons/gut/*,tests/*"` holding on all four presets, which root `CLAUDE.md` already tells Claude never to remove. Recording it here so that if B4 ever changes what ships, the font question surfaces as a consequence rather than a discovery. |

## 5. Risks & open questions

- **The top of the queue is unblocked and nothing has moved in three days.** B3
  has waited on B2 for four reviews; B2 closed on 08-29; the 08-29 log's own
  next-session list opens with B3. Three days is not a slippage — it is a
  weekend — but it is worth naming, because the previous pattern was that items
  slipped while blocked, and this one is not blocked.
- **The deadline moved from B3 to B8.** The 08-25 review's urgent item was an
  artifact expiring in two days; that is solved. The new clock is Apple's: whenever
  enrolment is approved, A4 delivers a `.p8` that can be downloaded exactly once,
  into a public repository with no credential ignore patterns and no push
  protection. Unlike the artifact, **this one cannot be regenerated** — a
  mishandled key is rotated, not recovered. It costs minutes to prevent.
- **`.gitignore:5-6` is a trap laid directly across C1's path.** The comment
  tells an operator to re-ignore `export_presets.cfg` once identities are added.
  The file is tracked; the ignore rule alone will not work; it needs
  `git rm --cached`. Whoever does C1 is the person most likely to read that
  comment and least likely to know it is incomplete. B8's acceptance moves this
  into the signing runbook, where it will actually be read.
- **The project's review record is outside the repository again — the third
  consecutive review to say so.** `2026-08-25-next-build.md` (modified),
  `build-reviews/README.md` (modified) and `daily-logs/2026-08-29.md`
  (untracked) are exactly what the 08-29 log listed as owed; this note makes
  **four paths**, since the index line is `README.md`, already counted. The
  08-29 log is the *only* record that the repository is public and that B2 and
  B5 closed — and it is untracked. **This is a process problem, not a task**:
  reviews and logs get written at the end of a session, after the last commit.
  Committing the vault is the first thing the next session should do, not the
  last.
- **This review could not observe CI.** `which gh` → not found; `git fetch
  origin` → *Host key verification failed*; and `https://api.github.com/repos/...`
  is outside this session's fetch provenance, so the unauthenticated-API route
  the 08-29 log documents was not available here either. **Nothing in this note
  should be read as a claim about CI's current status**, including the artifact
  expiry date in B3, which is computed from `ci.yml:261` and the 08-29 run dates
  rather than read from GitHub. That computation is the one number in this note
  most worth re-checking before relying on it.
- **`smoke-windows` still cannot be read as evidence when the export fails.**
  `needs: export` is bare at `:276` and `if: always()` is on steps rather than
  the job, so a failing pack gate or Linux boot **skips** it. Any acceptance
  written against it must say *green, not skipped* — and on a push the correct
  shape is **four green with `dco` skipped**, per `ci.yml:66`.
- **The website points at an empty Releases page, publicly.** `index.html:55` is
  the primary call to action, with two more download links at `index.html:286`
  and `user-guide.html:425`. It resolves at B6 and is an argument against letting
  B6 drift now that strangers can reach it.
- **A roadmap exit criterion is met in tests and unreachable in the artifact**
  (C9). Phase 2's fourth criterion runs through `ConfirmPanel`, which
  `main.gd:215` says is unreachable from the map screen in v0.1.0. Nine reviews
  have asserted "every Phase 1 and Phase 2 exit criterion is met"; that is true
  of the test suite and not of the thing a player runs, and no document says
  which of those two the criterion meant. It needs an owner's sentence, not
  code.
- **The first thing a player sees is aimed at a measured dead zone** (C4). One
  line, measured twenty-two days ago, still undecided. It should not survive into
  a release note.
- **Nothing verifies that the published release actually opens for a stranger**
  (B7). Nine reviews have measured the repo; the harness's definition of a
  working build ends with *"**and** it launches"*, and runbook A8 is the only
  test of that half.
- **The eight species portraits on the public site have no recorded provenance.**
  `website/assets/img/species/*.png` are not mentioned in
  `THIRD-PARTY-NOTICES.md`, and `LICENSE-ASSETS` covers **original work only**.
  If they were authored for this project, nothing needs doing except a line
  saying so; if they were not, ADR 0017 requires a notice — and the site is now
  public, so the window for settling this quietly has closed. It cannot be
  settled from the repo; it needs the person who made them. Everything else
  vendored is noticed to the extent it needs to be: `game/addons/gut/` (MIT) and
  its three OFL typefaces are named, and `exclude_filter="addons/gut/*,tests/*"`
  is present on all four export presets (`:11,42,73,116`), so none of it ships.
  **`THIRD-PARTY-NOTICES.md:130-135` is candid that this is conditional** — GUT's
  bundled `OFL.txt` carries only the Anonymous Pro copyright line, and the file
  says the Courier Prime and Lobster Two statements *"must be sourced and added
  here first"* if the project ever ships them. The exclude filter is what makes
  that a non-issue, which is why root `CLAUDE.md` tells Claude never to remove
  it, and why B4 is the item most likely to trip it.
- **The sandbox cannot export**, re-confirmed by attempt this session. V4 (an
  arm64 preset in CI) would let a future review boot a real artifact instead of
  reasoning about one.

## 6. Suggested next-week focus

The ordering has changed from 08-25 in two respects: **B3 moves to first**, since
its blocker cleared and its artifact is no longer expiring; and **B8 is second**,
since it inherited the only real deadline on the page.

1. **B3 + C4 + C5 — fetch the build, decide the camera, walk Step 5** (M + S + S).
   One session on the Mac. `gh run list --branch main --limit 1`, then
   `tools/fetch_build.py <run-id> --check`, then push-runbook Step 5. The value
   is in the walking: the credits screen actually read, the chime actually heard,
   the F5/quit/relaunch/F9 round-trip actually done, and the `codesign -dv`
   output recorded for C1. **This is the largest item not waiting on Apple and it
   is waiting on nothing.**
2. **B8 — the credential path** (S). Seven `.gitignore` lines, three repository
   settings, one runbook pre-flight paragraph. Do it before A4 lands, which means
   do it before you know you needed to.
3. **C7 + C3 + C8 + C9 — the ten-minute items** (S × 4). C7 has download lead
   time and nothing interesting in it: Godot 4.6.3 and the macOS export
   templates on the Mac, before anything gets signed. C3 is a two-line
   version-string edit. C8 is one sentence plus committing the 08-29 log. C9 is
   one roadmap decision block and needs Brent, not a session. **And commit the
   vault files first**, with `-s` — they have been owed since 08-29 and they
   include the only record of B2 and B5 closing.
4. **B4 — the packaging decision** (M), **carrying C6 and C8 in the same PR.**
   The last thing standing between a green pipeline and something a stranger can
   download and run. Land it as one commit with the `smoke-windows`,
   `inspect_pck.py` and `check_pck_contents.py` updates, the `SHA256SUMS.txt`
   `find` pattern, and the download-page copy — C6 cannot be scheduled any other
   way.
5. **V4 — settle the arm64 preset** (S), before B6 rather than during it, since
   it changes what runbook B3's `find` sweeps into the signed manifest.

C1 and C2 unlock the moment the Apple certificate lands; B6 waits on everything;
and **B7 — runbook A8, downloading the published DMG on a clean Mac — is what
actually turns "first build" into "next build"** in a following review. Nothing
before it answers the question this note asks.

---

## Verification

Labels per the harness's Step 6 rule. **Confirmed** = traced to something read or
run *this session*, against `00574b8`. **Assumed** = the reasoning is sound but
nothing was checked. **Unverifiable** = not checkable from this session; said
plainly rather than hedged.

### Confirmed

- **Build case is "first build".** `du -sh builds/` → 4.0K, contents
  `.gitignore`, `.gitkeep`, one empty `wildlife-crossing-linux-arm64/`;
  `git tag -l` → 0 tags; `docs/release-notes/` → `.gitkeep` only.
- **HEAD, branch and remote parity.** `git log -1` → `00574b8`, 2026-08-29
  20:12:33 -0500; `git branch --show-current` → `main`;
  `git rev-list --count origin/main..HEAD` → 0. `git log --since=2026-08-30`
  → nothing.
- **Working tree.** `git status --short` at the start of this session → three
  paths: the 08-25 review (M), `build-reviews/README.md` (M),
  `daily-logs/2026-08-29.md` (untracked). It reads four once this note exists.
- **GUT suite.** 23 scripts / 237 tests / 3,032 asserts, all passing, 1.76s,
  exit 0, via `tools/godot/Godot_v4.6.3-stable_linux.arm64`
  (`--version` → `4.6.3.stable.official.7d41c59c4`).
- **Python tool suite.** `python3 -m unittest discover -s tools/tests -b` →
  86 tests, OK.
- **Both headless boots clean**, bare and `-- --skip-menu`, no `ERROR:` or
  `SCRIPT ERROR`.
- **Export from the sandbox fails**, `--export-release "Linux arm64"` →
  *Project export for preset "Linux arm64" failed*;
  `~/.local/share/godot/export_templates/` is empty.
- **Script and data inventory.** 30 `.gd` / 3,569 LOC; 8 canonical data files and
  12 world maps, all valid JSON by `python3 -m json.tool`.
- **Untested scripts.** 9 with no `*_test.gd`; **3** with zero grep contact in
  `game/tests/` (`species_registry`, `economy_constants`, `habitat_constants`).
- **test-plan §11.** 43 uniquely named tests, 35 with no matching `func test_`
  in `game/tests/` — 81%. Measured by script this session; an earlier, sloppier
  version of that script returned 31/23 by mis-slicing the section, and the
  figure above is the one that reproduces 08-25's.
- **Every export-preset default** cited in C1, C2 and C3, read from
  `game/export_presets.cfg` at the line numbers given.
- **`ci.yml` is 297 lines**, `workflow_dispatch:` at `:14`, `retention-days` at
  `:261` with the per-event expression, `dco` gated at `:66`, the fragile
  `grep -oE '<testcase'` at `:122`, the *"Known gap"* comment at `:227`, the
  `smoke-windows` job at `:274-276`, three presets exported at `:172,174,176`.
- **`.gitignore` has no credential patterns** — the grep for the whole set
  returns nothing, exit 1.
- **README carries the GPG fingerprint** (`:91`) and both verification commands
  (`:98-99`); **the website carries none of it** — zero hits across
  `website/index.html` and `website/user-guide.html`.
- **README and CLAUDE structure tables now list `harness/`, `tools/` and
  `.github/`** (`README.md:13,19,20`; `CLAUDE.md:37,43,44`).
- **No statement anywhere in a tracked file that the repository is public** —
  the basis for C8.
- **`.git/index.lock` mtime is 2026-09-01 07:22**, i.e. moved by this session.
- **Clutter is all ignored** — `git check-ignore -v` on `commit-plan-2026-08-29.json`
  → `.gitignore:33`; on `tools/_to_delete` → `.gitignore:17`.
- **Both runtime assets exist** with their `.import` siblings;
  `game/assets/fonts/` and `tilesets/` contain only `.gitkeep`.
- **`Animal.tscn` is referenced by no script or scene** (grep across `game/`
  returns `game/CLAUDE.md:76` and two `.godot` cache entries), and
  `entities.json` has exactly one production consumer
  (`species_registry.gd:26`), plus two reads in `data_validation_test.gd:99,104`.
- **The signing-runbook `:392` and ADR 0018 `:165` "V2 is still open" claims are
  both still in the files**, verbatim.
- **`main.gd:215`** carries the string *"**Unreachable from the map screen in
  v0.1.0.**"* verbatim, and `main.gd:332` the *"Placeholder trigger"* comment
  reached from `KEY_M` at `:142-144`.
- **`deploy-website.yml:7-17`** triggers on push and pull_request for
  `website/**`, `obsidian-vault/wiki/**` and `tools/build_encyclopedia.py`, with
  `workflow_dispatch:` at `:21`. (An earlier draft filed this as Assumed; it is
  readable in-repo and was read.)
- **Eight species portraits** in `website/assets/img/species/`, zero matches in
  `THIRD-PARTY-NOTICES.md`; `LICENSE-ASSETS:13` covers original work only.
- **`docs/export-setup.md:97`** still says "14-day retention" unconditionally.
- **The GPG revocation certificate is done** —
  [[../daily-logs/2026-08-26]]:20 records it generated and stored off the
  machine holding the key, satisfying `signing-runbook.md:259-268`.

### Assumed

- **That B1b is still pending with Apple.** The last repo record is the 08-27
  enrolment submission; nothing since either way. If it has been approved and
  not written down, C1/C2 are unblocked and this note understates progress.
- **That nothing was done off-repo in the last three days.** The evidence is the
  absence of commits and of a daily log, which is good evidence for repo work and
  no evidence at all about, say, installing export templates.
- **That the archive route remains the right answer for B4.** Unchanged
  reasoning from 08-18; no new information this week.
- **That GitHub Actions artifacts do not preserve the Unix executable bit**
  (B4). Asserted by every review since 08-12 and sourced by none of them,
  including this one. It is almost certainly true and it is load-bearing for
  B4's acceptance, so it is worth five minutes with the `upload-artifact` docs
  rather than a fourth restatement.
- **That the `.git/index.lock` mechanism is the mount's `unlink` refusal.** The
  mtime movement is measured here; the `Operation not permitted` warning that
  explains it was observed on 08-29 and not reproduced this session.
- **That `wildlife-crossing-desktop-builds/` was built by Godot 4.6.0 and fails
  the pack gate.** Carried from earlier reviews; not re-checked. Only its size
  and mtime are measured here.
- **That push protection would not catch a `.p8`** (B8). The 08-29 log's
  reasoning, uncorroborated. Confirmable against GitHub's published
  secret-scanning pattern list.

### Unverifiable from this session

- **CI status, on any run, ever.** `which gh` → not found; `git fetch origin` →
  *Host key verification failed*; `https://api.github.com/repos/brenthumphries/wildlife-crossing`
  was **refused as outside this session's fetch provenance**, so the
  unauthenticated public-API route the 08-29 log documents was not available
  here. The 08-29 log's report of four-green-plus-skipped on runs `33284530592`
  and `33285150876` is a record of what a human read, not something verified
  here. **The run IDs and their dates in this note come from that log.**
- **The B3 artifact expiry date (~2026-09-12).** Computed from `ci.yml:261`'s
  14-day branch plus the 08-29 run dates. Artifact retention counts from upload,
  which was not observed. Treat it as an estimate with a few hours of slack, and
  re-check with `gh run list` before relying on it.
- **Whether the repository is still public**, and the state of secret scanning,
  push protection and branch rules. All are GitHub-side settings; the only repo
  evidence is an untracked log three days old. **This note nonetheless reasons
  from "public" throughout** — in B8, C8, C6, V5 and several §4 rows — because
  the alternative is to write a review that assumes nothing and says nothing.
  Read those as *"per the 08-29 log"*, not as measured today.
- **Whether CI ran against the merge**, which B3's framing assumes. The merge
  landing does not by itself establish it.
- **Whether the macOS export templates or a matching Godot are installed on the
  Mac** (C7), and **what Godot version the Mac runs** (C5's last open item).
- **Anything about `wildlife-crossing-desktop-builds/` beyond its mtimes and
  sizes** — those binaries were not executed; this environment is arm64 Linux.

### What the completeness audit changed

A fresh `general-purpose` subagent, with no sight of this run's reasoning, was
asked the two questions the harness specifies: is anything needed for the build
missing, and is anything listed already done. **Three findings accepted, one
rejected.**

- **Accepted — C9.** Phase 2's fourth exit criterion is met in tests and
  unreachable in the artifact, and nothing disposes of it. The best finding of
  the run: it is the only gap that touches the definition of the build case
  rather than the work behind it, and nine reviews walked past it.
- **Accepted — the species portraits belong in C6's acceptance**, not only in
  §5. C6 is the one scheduled edit to the page they sit on.
- **Accepted — the "seven scripts with zero grep contact" figure was wrong**
  (three), from a snake_case-only grep. See below; both audits caught it
  independently.
- **Rejected — "the GPG revocation certificate is unlifted."** It is done;
  [[../daily-logs/2026-08-26]]:20 records it. The audit read
  `signing-runbook.md:259-268` and the item lists and correctly found no work
  item, but the obligation was discharged in a log. Recorded here because it is
  the failure mode the reviews are most exposed to in the other direction —
  closures that live only in logs.
- Also confirmed clean, which is worth knowing: `docs/p0-open-questions.md` has
  no unlifted obligations (every A and B item carries a *Resolved → ADR*
  block), signing-runbook Part D holds nothing outside B6, and
  `deploy-website.yml`'s two gates both pass against the tree today.

### What the fact-integrity audit changed

The `verify` skill's subagent returned **thirty-odd findings against this note's
first draft**, and it called the draft a ship blocker. Almost all were accepted.
The three categories, in descending order of how badly they reflect on the
draft:

1. **Four claims stated as settled fact while this note's own Unverifiable list
   said otherwise** — that the repository is public, that its security settings
   are unconfigured, that CI ran against the merge, and the artifact-expiry date
   in the opening callout. The callout was the worst of them: it reframed the
   week's priority order on a derived date presented as an observation. All four
   are now hedged at the point of use, not only in this section. **This is the
   exact failure the harness's labelling rule exists to catch, and writing the
   labels at the end did not prevent making the claims at the top.**
2. **Six figures presented as this session's grep output that were false as
   stated** — the seven-zero-contact count (three), the `.gitignore` credential
   grep ("one hit at `:6`" — it returns nothing), `env_config` and
   `SimulationConstants` having zero contact (both have some), `Animal.tscn`
   "zero hits" (three, none a script or scene), `entities.json` "one hit"
   (four). In every case the *conclusion* survived and the *evidence* was wrong,
   which is the more insidious shape: a reader who spot-checks the command
   finds it does not reproduce and has no way to tell which half failed.
3. **Eight of the line-number corrections in §1's third finding were themselves
   wrong** — `:113-128` for `:113-127`, `::error::` at `:126` for `:125`,
   `:231-243` for `:231-239`, `:287-297` for `:294-295`, `:17-21` for `:16-20`,
   `:34-57` for `:32-62`, `:52-68` for `:44-69`, Phase 2's criteria `:112-120`
   for `:112-122` — plus two citations attributed to the 08-25 review that do
   not appear in it. They were derived by adding the commit's line delta rather
   than by opening the file. **In a finding whose entire subject is stale line
   numbers.** All corrected against the files.

Also accepted: two superlatives contradicted by [[2026-08-04-next-build]] (that
four closures was "the most any review has closed" — 08-04 closed ten — and that
this was "the first time a review's own blocker list has shrunk"); "four
reviews" of B3-blocked-on-B2 (three); "fifth consecutive review" on B1b's
calendar argument (fourth); "fourth consecutive review" on the uncommitted vault
(third, and the path count double-counted the index line); "the first time in
three reviews the top item is blocked by nothing" (08-25's B1 also depended on
nothing); "byte-for-byte the same run" (the totals match; the wall clock does
not); and B8's "two repository settings" against its own list of three.

One finding was **under-labelled in the safe direction** and is corrected too:
`deploy-website.yml`'s triggers were filed as Assumed when they are readable
in-repo and were read.

**Two new §4 rows came out of the audit rather than out of the review:**
`export-setup.md:97`'s now-false "14-day retention", and the font-attribution
note in `THIRD-PARTY-NOTICES.md:130-135` — which is not stale, but is a
conditional obligation that B4 could trip.

---

## Related

- [[roadmap]]
- [[pre-build-checklist]]
- Previous review: [[2026-08-25-next-build]]
- [[../daily-logs/2026-08-29]], [[../daily-logs/2026-08-27]], [[../daily-logs/2026-08-26]]
- [signing-runbook](../../docs/signing-runbook.md),
  [push-runbook](../../docs/push-runbook.md),
  [export-setup](../../docs/export-setup.md)
- [ADR 0017](../../docs/adr/0017-licensing.md),
  [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
