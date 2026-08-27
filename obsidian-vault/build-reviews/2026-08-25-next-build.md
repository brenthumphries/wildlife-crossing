---
title: "Build Review — Next Build (2026-08-25)"
date: 2026-08-25
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> [roadmap](../../docs/roadmap.md) Phases 1–2). One question: what work is
> needed to get there?

> [!info] Snapshot
> Measured against **`4119915`** (*docs(runbook): correct Steps 1-5 against what
> actually ran*, 2026-08-13 21:56 CDT) on branch
> `feat/save-load-and-agent-respawn` — **the same commit the last review
> measured.** `git log --since=2026-08-18 --oneline` returns nothing.
> Anything not traceable to something read or run this session is labelled in
> [§Verification](#verification).

> [!warning] Time-critical
> The CI artifact that [B3](#b3-walk-the-windowed-verification-checklist-against-a-build-of-head)
> and the 08-13 log's own next-session plan depend on — run `31762062722` —
> **expires around 2026-08-27** under `ci.yml:243`'s `retention-days: 14`. That
> is roughly two days from today. See [§5](#5-risks--open-questions).

> [!success] Amendment 2026-08-26 — **B1's GPG half is closed. B2's commit half landed; B2 itself did not close.**
> ed25519 signing key created, fingerprint
> `7F68A7E06349DA136226F04E2D5F1ED6EFFC08FD`, expiring 2029-08-26, with its
> revocation certificate generated and stored off the machine that holds it.
> All three publication steps at `signing-runbook.md:278-284` are done, which
> no previous review's acceptance had named individually: the public key is
> committed at the repo root in `e7ebf9a`, it is on keys.openpgp.org with its
> email address confirmed, and the full fingerprint is in `README.md` under a
> new `## Verifying a download` section carrying runbook B4's two commands. The
> website half of step (c) is C6 and stays open.
>
> B2: all eight uncommitted paths were committed at 22:29 local on 2026-08-26
> and pushed, in `c952a2c`, `ec06258` and `e7ebf9a`. Two consecutive build
> reviews are inside the repository for the first time since 08-12. B2 does not
> close on that: PR #1 is unmerged, `origin/main` is still at `0c31c85`, and
> `origin/main..HEAD` is 13. **The merge must be a merge commit or a rebase.** A
> squash rewrites the branch into a commit that is not an ancestor of `HEAD`, so
> B2's own acceptance would still read 10 after a successful merge. That
> consequence was not stated anywhere before now.
>
> On the Time-critical warning above: run `31762062722`'s artifacts were
> confirmed still present on 2026-08-26, one day inside the estimated expiry.
> They were not re-checked after that. See [[../daily-logs/2026-08-26]].

> [!note] Amendment 2026-08-27 — **B1b submitted. V9 written, not landed. A failure mode this note did not anticipate.**
> Apple Developer Program enrolment was submitted on 2026-08-27, Individual /
> Sole Proprietor. It is recorded in [[../daily-logs/2026-08-27]], which is the
> first record of it anywhere in the repository, as B1's acceptance asked. A2
> cannot proceed until Apple approves: a Developer ID Application certificate
> requires the Account Holder role and an active paid membership, so before
> approval Xcode offers only the free Personal Team's "Apple Development". A4 is
> gated the same way. A3 is not.
>
> V9 is written into `.github/workflows/ci.yml` and is uncommitted, so it is not
> closed.
>
> **New, and not in any list here.** On 2026-08-26 the `export` job failed at
> `Upload build artifacts` with *"Failed to CreateArtifact: Artifact storage
> quota has been hit"* against the 500 MB GitHub Free allowance. The export
> itself succeeded; eleven files were staged. Because `upload-artifact` is
> `export`'s last step and `smoke-windows` carries `needs: export`, a full quota
> fails `export` and skips `smoke-windows`, which is on its own enough to fail
> B2's acceptance. Mitigated three ways: `retention-days` now splits by event
> (uncommitted), the account moved to GitHub Pro, and B5 removes the problem
> outright, since Actions is unmetered on public repositories using standard
> runners. **That is a second, independent argument for B5 that this note did
> not have.**

## 1. Summary

- **Build case:** **FIRST working build**, for the eighth consecutive review, on
  the same three facts the harness names — *"there is a working build only if you
  can point to an actual export in `builds/` or a GitHub Release **and** it
  launches."* Re-checked this session: `builds/` holds `.gitignore`, `.gitkeep`
  and one empty `wildlife-crossing-linux-arm64/` directory (`du -sh` → 4.0K);
  `git tag -l` → **0 tags**; `docs/release-notes/` → a single 0-byte `.gitkeep`.
- **Target milestone & exit criteria:** roadmap
  [Phase 1](../../docs/roadmap.md) §*Exit criteria* and
  [Phase 2](../../docs/roadmap.md) §*Exit criteria*, as scoped by the logged
  decisions of 2026-07-29 (Bow Valley only) and 2026-08-06 (world map ships
  look-only). Every one of them is still met in code and green in tests.
- **Headline:** **7 blockers, 7 core tasks, 9 verification items.** **Nothing
  moved.** Zero commits in twelve days; `HEAD` is still `4119915`. Excluding
  `.git/` and the Godot import cache, exactly **three** files in the entire
  repository have been modified since 2026-08-18: the previous review note, its
  index line — both still uncommitted — and `.obsidian/workspace.json`, which is
  the editor recording that someone opened the vault. The GUT suite is byte-for-byte the same
  run: **23 scripts / 237 tests / 3,032 asserts, all passing**, and the Python
  tool suite is **86 tests, OK** — identical to the last two reviews. Every
  blocker, core task and verification item from [[2026-08-18-next-build]] was
  re-verified open this session by reading the same files. **This note is
  deliberately much shorter than the last one.** The arguments have not changed
  and re-making them at length would dress a still week up as a busy one; where
  an item is unchanged it says so and points at 08-18 for the reasoning. Three
  things are new, and all three are consequences of time passing rather than of
  work done.
  1. **The build B3 is supposed to be walked against expires in about two
     days.** `ci.yml:243` sets `retention-days: 14` on the artifact upload;
     [[../daily-logs/2026-08-13]]:48 records the green five-job run as
     `31762062722`; that log's next-session item #2 is, verbatim,
     `tools/fetch_build.py 31762062722 --check` (`:135`). Fourteen days from
     2026-08-13 is
     **2026-08-27**. The first executable step of this project's own plan has a
     deadline that nobody set deliberately and nobody has been watching. It is
     recoverable — `gh run rerun 31762062722` regenerates the artifacts, since
     GitHub keeps *runs* far longer than *artifacts* — but recovering costs a CI
     cycle, and it is worth knowing before rather than after.
  2. **Apple enrolment slipped a clean seven days this week, for nothing.**
     08-12 ranked it third; 08-18 promoted it to first precisely because two
     consecutive next-session lists had omitted it. **The skip count is still
     two, not three** — no session has happened since 08-13, so there is no
     third list to have omitted it. What has grown is the elapsed time, which is
     the part that matters for a calendar-bound task: thirteen days after it was
     first ranked, `grep -in fingerprint README.md` still returns nothing and
     nothing in the repo records enrolment starting. **The one task nobody has
     scheduled is the one that sets when a release is possible** — and an idle
     week costs it a full week with no way to earn the time back.
  3. **Two consecutive build reviews now live outside the repository.** 08-18
     named this about one note; it is now the 08-12 review with its amendments,
     the `build-reviews/README.md` headline, the untracked 08-13 log, the
     untracked 08-18 review, and — once this note lands — this one and a second
     `README.md` edit. `origin/main` has not moved since **2026-08-10 21:49**
     (`git reflog show origin/main --date=iso`), which is fifteen days.
- **Change since last review:** [[2026-08-18-next-build]] — **nothing closed,
  nothing newly broken, nothing newly built.** No commits, no test-file changes,
  no data changes, no CI changes. **Three items are new, all appended rather
  than renumbered: B7** (walk signing-runbook A8 — the real acceptance test, and
  the one item that actually closes the *"and it launches"* half of the build
  case), **C7** (pin the release machine's engine and export templates) and
  **V9** (add `workflow_dispatch` to `ci.yml`). B7 and C7 came out of this
  review's completeness audit; V9 out of chasing the artifact-expiry problem in
  finding 1. **Three claims carried by prior documents are now falsified** — the
  `.git/index.lock` account, and the *"build-review V2 is still open"* claim
  that both `signing-runbook.md:392-395` and ADR 0018 §Follow-on still carry.
  See [§4](#4-doc-drift-to-fix). Numbers B1–B6, C1–C6 and V1–V8 are carried
  unchanged from 08-18 on purpose: renumbering a list that did not change would
  make the diff unreadable for no gain.

## 2. Current state (evidence)

Re-measured against `4119915` this session unless labelled otherwise in
[§Verification](#verification). Everything in this section matched 08-18 exactly;
it is repeated rather than cross-referenced because a review that only says
"unchanged" cannot be checked.

- **Systems:** **30 scripts / 3,569 LOC** in `game/scripts/`. The four autoloads
  are registered at `game/project.godot:28-31` (`GameState`, `EventBus`,
  `Debug`, `SpeciesRegistry`); every other system is instantiated at runtime by
  `main.gd`. No script in the tree is an empty stub — the smallest,
  `ui/base_screen.gd`, is 23 LOC and real. Of the **27** scripts the roster in
  `docs/architecture.md:44-69` names (16 systems + 11 UI), **13 are present and
  14 are absent**: seven systems (`economy_manager`, `information_manager`,
  `permissions_manager`, `season_manager`, `time_controller`,
  `milestone_tracker`, `narrative_manager`) and seven UI scripts
  (`build_palette`, `inspect_panel`, `entity_profile`, `season_calendar`,
  `budget_hud`, `milestone_track`, `time_controls`). All fourteen are Phase 3–6,
  so this is a stale roster rather than a regression — see §4.
- **Data:** all **8** canonical files in `game/data/` present and valid JSON; all
  **12** `data/world/sub_area_*.json` valid. Twenty files, zero parse failures.
  **Unchanged since 2026-07-10** — `git log -1 -- game/data/` → `feat(game):
  author crossing segments for the 11 new sub-area maps`. (Prior reviews wrote
  "unchanged since 2026-08-04", which was the date it was last *measured*, not
  the date it last *changed*.)
- **Scenes & wiring:** `run/main_scene` is `res://scenes/TitleScreen.tscn`
  (`project.godot:23`). `Main.tscn` is a six-line script holder; the wiring is in
  `main.gd:55-97`, which constructs `Simulation`, `WorldRenderer`,
  `ConnectivityOverlay`, the camera, the audio player, `Hud` and `CreditsScreen`
  at runtime. Four scenes exist. `scenes/world/Animal.tscn` is still referenced
  by nothing.
- **Tests:** GUT 9.6.0 via the vendored
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` (`--version` →
  `4.6.3.stable.official.7d41c59c4`) — **23 scripts / 237 tests / 3,032 asserts,
  all passing**, exit 0, 1.711s. `python3 -m unittest discover -s tools/tests -b`
  → **86 tests, OK**. Both identical to 2026-08-18 and 2026-08-12. **9 of 30
  GDScript scripts have no named test file** — `main`, `title_screen`,
  `env_config`, the three constants files, and the autoloads `debug`,
  `event_bus`, `species_registry`. **Three have no grep contact of any kind** in
  `game/tests/`: `species_registry.gd`, `economy_constants.gd` and
  `habitat_constants.gd`. (`debug.gd` has exactly one, a docstring mention in
  `hud_test.gd:2`, which is not a use.) Nine of the 23 test files do
  read the real `res://data/` files, so the data-consuming systems are tested
  against what ships.
- **Headless boot from source:** both boots clean against the pinned 4.6.3
  binary. Bare → `[I] Title screen ready`. `-- --skip-menu` →
  `[I] Tutorial loaded. Press B to build the Bow Valley overpass. Press M for
  the world map. Press F1 for credits. F5 saves, F9 loads.` No `ERROR:` or
  `SCRIPT ERROR` in either.
- **CI:** `.github/workflows/ci.yml`, **279 lines**, five jobs — `tools:24`,
  `dco:57`, `test:74`, `export:122`, `smoke-windows:256`. `GODOT_VERSION:
  4.6.3-stable` pinned at `:15`. `grep -n retention-days` → one line, `:243`,
  inside the upload step's `with:`. **Triggers are `push: [main]` and
  `pull_request: [main]` only (`:3-7`) — there is no `workflow_dispatch`**, so
  CI cannot be re-run from the Actions UI without a commit or a `gh run rerun`.
  That is new information this review, and it is V9. The structural caveat is
  unchanged: `if: always()` sits on two *steps* (`:225`, `:238`), not on the
  `export` job, and `smoke-windows` has a bare `needs: export` (`:258`), so a
  failing export **skips** it rather than turning it red. "Green, not skipped"
  remains the only useful acceptance wording. **Whether any CI run has ever
  passed is Unverifiable this session:** `which gh` → not found, and
  `git fetch origin` fails with *Host key verification failed*.
- **Build/export:**
  - `builds/` — `.gitignore`, `.gitkeep`, one empty directory, 4.0K.
    **No binaries.**
  - `wildlife-crossing-desktop-builds/` — **411 MB**, newest mtime
    **2026-07-28 03:31**. Now four weeks stale, built by Godot 4.6.0 against a
    pipeline pinned to 4.6.3, and failing the repo's own pack gate. Five reviews
    running have had to establish that these are not the build.
  - `git tag -l` → empty; `docs/release-notes/` → `.gitkeep` only.
    → **first build.**
  - A local export was **attempted this session and failed as expected**:
    `--export-release "Linux arm64"` → *No export template found at
    …/export_templates/4.6.3.stable/linux_release.arm64*, and the directory is
    empty. The sandbox cannot produce a binary; the build signal here is a source
    boot plus the test suite.
- **Export presets:** all four still at their defaults on every item C1 and C3
  name — `export_presets.cfg:145` `codesign/codesign=1` (built-in ad-hoc),
  `:147` `apple_team_id=""`, `:148` `identity=""`, `:173` `notarization=0`,
  `:138-139` `short_version=""` / `version=""`, `:94` and `:133`
  `application/icon=""`, `:117` macOS `export_path` still ends `.zip`,
  `embed_pck=false` at `:26,57,88`, console wrapper on at `:25,56,87,132`.
- **Git:** branch `feat/save-load-and-agent-respawn`, `HEAD` = `4119915`
  (2026-08-13 21:56:53 -0500, **12 days ago**), fully pushed. `origin/main` =
  `0c31c85`, last updated **by a push** on 2026-08-10 21:49;
  `origin/main...HEAD` → **`0  10`**; `origin/main...main` → **`0  4`**. Working
  tree carries four modified/untracked vault files. A 0-byte `.git/index.lock`
  is present, mtime **2026-08-13 22:04** — **unchanged after a second full
  session of git commands from this sandbox**, which is now the second
  independent observation contradicting the 08-13 log's explanation. Harmless
  either way (`ship.py:83,380-416` clears anything older than 120 s).
- **Untracked leftovers:** `commit-plan-2026-08-14b.json` at the repo root (3,975
  bytes, mtime 2026-08-13 21:50) is the **spent** `ship.py` plan that produced
  `10062ad` and its siblings — it is not evidence of an unexecuted plan, just of
  a plan nobody deleted. `tools/_to_delete/` also lingers, as do **ten** `.DS_Store`
  files (`find . -name .DS_Store -not -path './.git/*' | wc -l` → 10; six at
  depth ≤ 1, including `harness/`, `docs/` and `game/addons/gut/`).

### Exit criteria, criterion by criterion

Unchanged from [[2026-08-18-next-build]] and re-run this session: every Phase 1
and Phase 2 exit criterion is **met in code and green in tests**, and **three of
them have never been rendered to a human** — the crossing cue (visual + audio),
the locked-sub-area desaturation, and the connectivity overlay's orange→teal
treatment. The implied criterion — *an export of the current code launches* —
advanced on 2026-08-13 and has not moved since.

What is missing is still not gameplay logic. It is a release a stranger could
install.

## 3. Work needed for the first build

Ordered the way you'd actually do it. **Numbers are carried unchanged from
[[2026-08-18-next-build]]** — B1–B6, C1–C6, V1–V8 — because nothing closed and
renumbering would obscure that. **V9 is new.** Where an item is materially
unchanged, this note gives the re-verification and the one-line why, and points
at 08-18 for the full argument rather than restating it.

### Blockers (nothing ships until these exist)

#### B1. Start the Apple enrolment and create the GPG key
- **Why it blocks:** unchanged from [[2026-08-18-next-build]] B1, which is
  itself the point: **it has been open across three reviews and skipped by the
  two next-session lists that could have picked it up** (08-10 and 08-13). There
  is no third skip to report — there has been no third session. [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
  makes a signed, notarized macOS build part of what `v0.1.0` *is*, and
  [signing-runbook](../../docs/signing-runbook.md) says it plainly: *"Apple
  enrolment takes a few days. It is the only calendar-time gate left. Start it
  first."* Re-verified absent this session: `grep -in fingerprint README.md` →
  nothing; no key, no certificate, no enrolment recorded anywhere in the repo.
  C1, C2 and B6 all queue behind the Apple half.
- **Files/areas:** none yet; later, the public key committed and its fingerprint
  in `README.md`.
- **Acceptance:** runbook **A1–A4 and B1–B2** — enrolment submitted; a
  **Developer ID Application** certificate issued (an "Apple Development"
  certificate signs fine and fails notarization); the Xcode licence accepted
  (A3); the **App Store Connect API key** created and stored (A4,
  `runbook:90-101` — Apple lets you download the `.p8` exactly once). Plus a GPG
  signing key with its revocation certificate stored, and **all three of the
  runbook's publication steps** (`signing-runbook.md:278-284`), which no
  previous review's acceptance named individually:
  **(a)** `wildlife-crossing-signing-key.asc` **committed to the repo root** —
  note this is a repo change and must ride a merge, so it belongs with B2 or
  B4's PR rather than after the release; **(b)** the key uploaded to
  <https://keys.openpgp.org/upload>; **(c)** the full fingerprint printed in
  `README.md` *and* the website download section (that half is C6). The runbook's
  reason matters: *"a key delivered over the same channel as the file it signs
  proves very little."*
- **Do the GPG half first and separately**, as B1a. `signing-runbook.md`
  §Suggested order lists the key as *"Blocks on: nothing"* — minutes of work, no
  Apple account, and it is what C6's fingerprint copy actually waits on.
- **Depends on:** none. **Costs $99/year**; the decision is recorded in ADR 0018,
  the spend has not happened.
- **Size:** S effort, **days of calendar**
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A1–A4, B1–B2;
  ADR 0018; [[2026-08-18-next-build]] B1.

#### B2. Merge PR #1, and commit the vault files first
- **Why it blocks:** unchanged, and the second half has grown. `origin/main` is
  **fifteen days** stale at `0c31c85` and **10 commits** behind `HEAD`, so `main`
  still does not contain the save/load system, the CI fixes or the runbook work.
  The vault half is now **five paths, not three**: the 08-12 review with its
  amendments, `build-reviews/README.md`, the untracked `daily-logs/2026-08-13.md`,
  the untracked `build-reviews/2026-08-18-next-build.md`, and this note. Two
  consecutive build reviews — the documents that say what is blocking the build —
  exist on one machine and are not in the repository PR #1 would merge.
- **Files/areas:** no code change.
  [push-runbook](../../docs/push-runbook.md); `tools/ship.py`.
- **Acceptance:** all five vault paths committed with `-s` (the DCO gate added in
  `792b237` rejects an unsigned commit) and pushed **before** the merge; PR #1
  observed green with all five jobs including `smoke-windows` **green, not
  skipped**; merged; and after a fetch, `git rev-list --count origin/main..HEAD`
  → 0.
- **Depends on:** none. Run `ship.py --execute` from a real terminal on the Mac,
  not the Cowork sandbox.
- **Size:** S
- **Refs:** [push-runbook](../../docs/push-runbook.md);
  [[2026-08-18-next-build]] B2.

#### B3. Walk the windowed verification checklist against a build of `HEAD`
- **Why it blocks:** unchanged in substance — the credits screen is the primary
  licence-compliance mechanism under
  [ADR 0017](../../docs/adr/0017-licensing.md), and if it renders illegibly the
  project is out of compliance and 237 unit tests cannot tell you. **What
  changed is the clock.** The artifact this item is meant to be walked against
  is from run `31762062722` (2026-08-13), and `ci.yml:243` retains artifacts for
  **14 days** — so it expires around **2026-08-27**, about two days from today,
  possibly less depending on the upload time. The 08-13 log's next-session item
  #2 names that run ID literally.
- **If the artifact has lapsed**, do not push a throwaway commit to regenerate
  it. `ci.yml:3-7` has no `workflow_dispatch`, so the Actions UI offers no "Run
  workflow" button, but `gh run rerun 31762062722` re-executes the jobs of an
  existing run and produces fresh artifacts — GitHub retains run *records* far
  longer than run *artifacts*. Alternatively, merging B2 fires a `push: [main]`
  run, which is a better artifact to verify anyway. **Sequencing B2 before B3
  makes the expiry moot**, which is the argument for doing them in that order
  this week rather than in parallel.
- **Files/areas:** no code change expected. `tools/fetch_build.py`;
  [push-runbook](../../docs/push-runbook.md) Step 5.
- **Acceptance:** `tools/fetch_build.py <run-id> --check`, then Step 5 walked to
  completion against that build: the menu appears and `Play` works; the credits
  screen opens from the menu **and** from `F1` and is **actually read** for
  legibility and scrolling; the HUD message line is legible; the "+N crossed
  safely" cue is **seen** firing and the chime **heard**; every key `main.gd`
  owns is pressed — **B**, **M**, **F1**, left-click, **Enter**, **Escape**,
  **F5**/**F9** — with an F5 / quit / relaunch / F9 round-trip, since quicksave
  to `user://` has never run from an exported binary; and the `codesign -dv`
  output **recorded**, which C1 needs.
- **Depends on:** B2 (preferred — see above). Machine-gated: `fetch_build.py`
  shells out to `gh run download`, so it needs `gh` installed and authenticated
  on the Mac. Cannot run from this sandbox.
- **Size:** M
- **Refs:** [push-runbook](../../docs/push-runbook.md) Step 5;
  [[../daily-logs/2026-08-13]]:48,135; `ci.yml:243`; ADR 0017;
  [[2026-08-18-next-build]] B3.

#### B4. Decide how a Release ships something a stranger can run
- **Why it blocks:** unchanged and re-verified this session.
  `export_presets.cfg:26,57,88` still set `binary_format/embed_pck=false`, so the
  Linux build is `wildlife-crossing.x86_64` **+** `.pck` and the Windows build is
  `.exe` **+** `.pck` **+** a console wrapper (`:87`). A GitHub Release asset is a
  single file: a downloader who takes `wildlife-crossing.exe` on its own gets a
  Godot runtime with no game and no error explaining why. GitHub Actions
  artifacts also do not preserve the Unix executable bit, so a Linux binary
  routed through an artifact into a Release arrives non-executable.
- **Choose the archive, not `embed_pck`.** Root `CLAUDE.md` and
  [ADR 0017](../../docs/adr/0017-licensing.md):119-121 require every exported
  binary to ship `LICENSE` and `THIRD-PARTY-NOTICES.md`, and `ci.yml:224-232`
  places both in `builds/<platform>/` — which only reaches a downloader if the
  **archive** is the published asset. A bare embedded-pack `.exe` passes the "one
  file" test and quietly breaks ADR 0017.
- **Files/areas:** `game/export_presets.cfg`; `.github/workflows/ci.yml` export
  and upload steps **and the `smoke-windows` job** (`:276-279` hardcodes the
  `.exe` path and hard-fails if it is absent); `tools/check_pck_contents.py`;
  `tools/inspect_pck.py`, which has no test file of its own.
- **Acceptance:** each published asset is **one file that runs on a clean
  machine**, verified by extracting into an empty directory and launching with no
  reliance on a sibling file; the Linux binary is executable after download;
  `LICENSE` and `THIRD-PARTY-NOTICES.md` are **inside** the published asset; and
  the console wrapper is dealt with — nothing currently says which of
  `wildlife-crossing.exe` and `wildlife-crossing.console.exe` a downloader runs.
  **And the signed manifest has to follow the decision.**
  `signing-runbook.md:297` builds `SHA256SUMS.txt` from
  `find . -type f \( -name '*.dmg' -o -name '*.exe' -o -name '*.pck' -o -name
  'wildlife-crossing.x86_64' \)` — **no archive extension matches that
  pattern.** If B4 goes the archive route, as it should, the manifest as written
  would attest to loose intermediates and not to a single published artifact,
  against ADR 0018:111's requirement that it cover *"every published artifact on
  every platform"*. (`wildlife-crossing.arm64` is unmatched too, the moment V4
  goes the "export it" way.) Updating that `find` is part of B4, not a separate
  item — but nothing named it until now.
- **Depends on:** sequence after B2 so the CI change lands on a current `main`.
  **Land it as one commit** with the `smoke-windows` and pack-gate updates, or
  the PR carrying it is red on its own gates.
- **Size:** M
- **Refs:** `export_presets.cfg:25-26,56-57,87-88`;
  [export-setup](../../docs/export-setup.md); [[2026-08-18-next-build]] B4.

#### B5. Confirm the repository is public before the Release is cut
- **Why it blocks:** unchanged from 08-18, where it was new. A GitHub Release on
  a private repository is not downloadable by a stranger, which is the entire
  definition of "first working build" this harness runs on.
  [ADR 0017](../../docs/adr/0017-licensing.md):9-13 opens on the premise that the
  repository *"has been private to date"*; ADR 0018 §Consequences reasons about
  *"a real security property of a public repo"*; and `ci.yml:44-47` grounds the
  DCO gate in the same assumption — *"with a DCO and no CLA, the first merged
  outside contribution is the point of no return on the licensing model, and a
  missing trailer costs a history rewrite on **a public branch** once it has
  landed."* (Both 08-12 and 08-18 attributed to `ci.yml:44-53` the phrase
  *"before the repo is announced publicly"*. **That phrase is not in the file** —
  `grep -n -i public .github/workflows/ci.yml` returns `:47`, `:182` and `:249`
  and none of them says it. A quotation invented two reviews ago and carried
  forward inside quotation marks; the argument survives on the real line, which
  is why it is replaced here rather than dropped.) Three
  decisions are staged for a transition **no document schedules, gates, or
  records as done**, while `website/index.html:55` already points the site's
  primary call to action at the Releases page.
- **Files/areas:** GitHub repository settings; whichever of `README.md`,
  `CONTRIBUTING.md` and `docs/CLAUDE.md` should carry the record.
- **Acceptance:** either the repo is confirmed public and that is written down
  once, or the flip is scheduled as an explicit step of B6 with its own
  pre-flight check (secrets scan, and `export_presets.cfg` diffed for the
  credentials the signing runbook warns Godot writes into it).
  **Correction to the pre-flight this note first drafted:** the untracked
  clutter is *already* invisible —
  `git check-ignore -v` reports `commit-plan-2026-08-14b.json` ignored by
  `.gitignore:33` (`/commit-plan*.json`) and `tools/_to_delete/` by
  `.gitignore:17` (`/tools/*`). Neither can become stranger-visible. **What
  actually goes public and is undocumented is `harness/`** — four tracked files,
  including the skill that produces these notes — **plus the nine tracked
  `tools/*.py|sh|gd` and five tool tests**, none of which appears in the
  `README.md` or root `CLAUDE.md` structure tables (§4). That row is the real
  pre-flight item; the clutter sweep is cosmetic.
- **Depends on:** none, but settle it **before** B6 rather than during it.
- **Size:** S — assuming it is already done, in which case the work is the
  sentence that records it.
- **Refs:** ADR 0017 §Context; ADR 0018 §Consequences; `ci.yml:44-47`;
  `website/index.html:55`; [[2026-08-18-next-build]] B5.

#### B6. Cut `v0.1.0` — release note, tag, signed GitHub Release
- **Why it blocks:** this is the item that decides the build case, and eight
  consecutive reviews have answered "first build" on the same three facts —
  empty `builds/`, zero tags, empty `docs/release-notes/`. All three re-verified
  true this session.
- **Files/areas:** `docs/release-notes/v0.1.0.md`; a `v0.1.0` tag; a GitHub
  Release carrying the macOS image, the Windows and Linux packages from B4,
  `SHA256SUMS.txt` and its detached signature; `README.md` (key fingerprint).
- **Acceptance:** the release note follows [docs/CLAUDE.md](../../docs/CLAUDE.md)
  format and states **all four** scope facts — Bow Valley only, the world map is
  look-only, placeholder art and the default Godot window icon
  (`export_presets.cfg:94,133` `application/icon=""`), and which artifacts are
  signed vs not and how to verify; the tag exists; `spctl`/`stapler` verify the
  notarized image per runbook A7; the GPG signature verifies per runbook B4; and
  the binaries report their own version (C3). Plus the runbook's gotcha:
  **clear `builds/` first** — B3 of the runbook sweeps that directory with a
  `find` to build the manifest, and `builds/wildlife-crossing-linux-arm64/` is
  sitting there now, empty today and populated the moment V4 goes the "export it"
  way.
- **Depends on:** B1, B3, B4, B5, C1, C2, C3, C5, C6, C7, **and V4** — which
  08-18's list omitted while B6's own acceptance text argues for it. V4 decides
  whether an arm64 binary exists in `builds/` at the moment runbook B3 sweeps
  that directory with a `find` to build the signed manifest, so V4's outcome
  changes what gets signed. Settle it before the sweep, either way.
- **Size:** M
- **Refs:** ADR 0018 §Decision; [signing-runbook](../../docs/signing-runbook.md)
  A6–A8, B3–B4, C2; [[2026-08-18-next-build]] B6.

#### B7. Walk signing-runbook A8 — the real acceptance test
- **Why it blocks:** **new as a work item this review.** A8 is not unmentioned
  in the record — 08-12 and 08-18 both cite the runbook's *"A6–A8"* in B6's
  Refs. What no review has done is lift it out of a reference list and give it
  its own acceptance, which matters because it is the only item that closes the
  half of the build case this harness's own definition turns on. The definition is *"an
  actual export in `builds/` or a GitHub Release **and** it launches."* B6 cuts
  the Release; nothing verifies that a stranger can open it. The runbook already
  specifies the test, at `signing-runbook.md:227-236`, and it is titled *"A8. The
  real acceptance test"*: **download the DMG from the published GitHub Release,
  on a Mac that has never had this project on it, and open it. "No Gatekeeper
  warning at all" is the pass condition. Anything less — "unidentified
  developer", a right-click-to-open workaround, a quarantine prompt — means it
  isn't done.** B6's acceptance stops at local `spctl` and `stapler`, and A7 is
  titled *"do not trust the export log"* for exactly the reason that local
  verification is not the same test: a locally-built bundle has never been
  through the download-and-quarantine path that Gatekeeper actually evaluates.
- **Files/areas:** none. A second Mac (or a fresh user account, though a clean
  machine is the real test), the published Release, and a daily-log entry.
- **Acceptance:** the DMG downloaded **from the Release URL** on a machine that
  has not had the project, opened with **no Gatekeeper warning of any kind**;
  the same session confirms the Windows and Linux assets extract and launch on a
  clean machine per B4's acceptance; and **the result recorded in
  `obsidian-vault/daily-logs/`** — the runbook says the log entry is part of the
  test. Until this passes, the answer to *"is there a working build?"* is still
  no, whatever `builds/` contains.
- **Depends on:** B6. This is the last item, and it is the one that changes the
  build case from *first* to *next* in the following review.
- **Size:** S — assuming it passes. If it does not, it reopens C1 and C2, which
  is precisely why it must be walked rather than assumed.
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A8, A7;
  ADR 0018 §Decision; the harness's own definition of "working build".

### Core build work

All six are unchanged from [[2026-08-18-next-build]] and were re-verified open
this session against the file and line numbers given. Full reasoning is in that
note; the summaries here are the re-verification plus the acceptance bar.

#### C1. Configure macOS signing in the export preset
- **Re-verified:** `export_presets.cfg:145` `codesign/codesign=1`, `:147`
  `apple_team_id=""`, `:148` `identity=""`, `:173` `notarization=0` — all four
  still at defaults. B6's acceptance asks `spctl` and `stapler` to verify, which
  is impossible until these change.
- **Files/areas:** `game/export_presets.cfg` preset 3. **The file is tracked and
  Godot writes secrets into it** — use the `GODOT_MACOS_NOTARIZATION_*`
  environment variables and diff before every commit. Leave the `Debugging`
  entitlement `false`.
- **Acceptance:** a signed test export from Brent's Mac that `spctl -a -vvv`
  accepts and whose ticket `stapler validate` confirms (runbook A7 — *"do not
  trust the export log"*). Also settle whether `export/distribution_type=0`
  ("Testing", `:128`) needs to change. B3's recorded `codesign -dv` output is the
  first input.
- **Depends on:** B1 (the certificate and the API key). **Size:** M
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A5, A7; ADR 0018.

#### C2. Change the macOS export target from `.zip` to `.dmg`
- **Re-verified:** `export_presets.cfg:117` still ends `.zip`. You cannot staple
  a notarization ticket to a `.zip`, and the `.zip` is why `LICENSE` and
  `THIRD-PARTY-NOTICES.md` land *beside* the archive rather than inside the
  bundle — the gap `ci.yml:220` acknowledges in its own *"Known gap"* comment.
- **The real interaction**, per 08-18's correction: changing the container does
  not break the CI pack gate (`ci.yml:169-170` passes an explicit output path
  that overrides `export_path`). It is worse and quieter — the release `.dmg` is
  built locally (`signing-runbook.md:188`), never in CI, and
  `check_pck_contents.py` `resolve_pck` accepts only a `.pck`, a `.app` directory
  or a `.zip`. **The artifact that actually ships is gated by nothing.**
- **Acceptance:** the macOS preset exports a `.dmg`; **the pack inside the
  shipped image passes `check_pck_contents.py`**, run against the image or the
  mounted `.app`, and that run recorded in the release log; its tests cover the
  new input; CI's export job stays green; `LICENSE` and `THIRD-PARTY-NOTICES.md`
  are inside the image, added **before** signing (modifying a signed bundle
  silently invalidates it).
- **Depends on:** not "none", as 08-18 had it. The preset edit depends on
  nothing, but the acceptance requires teaching `resolve_pck` to accept a `.dmg`
  — a `tools/` change with its own tests, which has to land through a PR like any
  other. Do the preset in the same pass as C1 and land the tools half with B4's
  commit. **Size:** M
- **Refs:** ADR 0018; [signing-runbook](../../docs/signing-runbook.md) A5–A6.

#### C3. Set the version metadata the export presets never got
- **Re-verified:** `export_presets.cfg:138-139` still `short_version=""` and
  `version=""`; the Windows preset has no `file_version`/`product_version` at
  all, while `project.godot:17` carries `config/version="0.1.0"`. An empty
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
  stranger will ever see. Flagged to the owner on 08-10 — **fifteen days ago**,
  still undecided, and it is one line.
- **Acceptance:** a one-line change or an explicit recorded decision to keep it;
  either way the answer is in a log **before** C5's QA pass runs.
- **Depends on:** none. **Needs an owner call.** **Size:** S
- **Refs:** [[../daily-logs/2026-08-10]] §Open questions;
  [[../design/detour-cost-question]]; `tools/measure_tutorial.gd`.

#### C5. Visual + audio QA pass, written down
- **Re-verified:** owed since 2026-07-08 and kept in v0.1.0 scope by the
  2026-08-06 decision. Three roadmap exit criteria are met only in code and have
  never been looked at. **One of them cannot be observed at all** — Phase 2's
  fourth criterion runs through `ConfirmPanel`, which `main.gd:215-221` says
  outright is *"unreachable from the map screen in v0.1.0"*. It is met in tests
  (`confirm_panel_test.gd`) and undemonstrable by hand; do not send a QA pass
  looking for it.
- **Acceptance:** a note in `obsidian-vault/daily-logs/` confirming each Phase 2
  visual criterion observed on screen (locked desaturation + lock indicator;
  overlay orange→teal at ~40%, appearing only in segment mode and clearing), the
  crossing cue visible **and** audible once per coalesced window, the HUD message
  line legible, the credits screen legible and scrollable, a quicksave/quickload
  round-trip in the export, and — still never captured by any log — **the Godot
  version installed on Brent's Mac**.
- **Depends on:** B3 (observed in the export, not the editor), C4 (decide the
  camera first). Best done in the same session as B3. **Size:** S
- **Refs:** roadmap Phase 2 exit criteria; the 2026-08-06 decision block.

#### C6. Add the verification copy to the download section
- **Re-verified this session:**
  `grep -in "gpg\|sha256\|smartscreen\|unsigned" README.md website/index.html` →
  **nothing**, and `grep -in fingerprint README.md` → nothing. The download
  button exists (`website/index.html:55-56`, footer links at `:286` and
  `user-guide.html:425`); the copy does not.
- **Acceptance:** the download area names each published asset, states plainly
  that Windows is unsigned and what SmartScreen will say, gives the GPG
  fingerprint and the two verification commands, and does **not** imply the GPG
  signature suppresses any OS warning (runbook C2 is explicit about that
  conflation). **And it says how to run the thing** — nothing anywhere does.
  Open the image and drag to Applications; `chmod +x` the Linux binary; keep the
  `.pck` beside the binary if B4 goes that way.
- **Depends on:** B4 (the asset list) and B1a (the GPG fingerprint — not the
  Apple half). **08-18's third dependency was pointed the wrong way and is
  corrected here.** C6 is a repo change; it does not *wait for* a merge, it must
  be *carried by* one. `deploy-website.yml` publishes on push to `main` touching
  `website/**`, `obsidian-vault/wiki/**` or `tools/build_encyclopedia.py`
  (`:7-14`; it also runs on `pull_request` in check-only mode). So as §6 orders
  the week, C6's inputs arrive at step 1 and step 5 while the only planned merge
  is step 2 — **C6 is unschedulable as written.** Either land C6 in B4's PR, or
  plan a second merge after B4. **Size:** S
- **Refs:** ADR 0018 §Follow-on work;
  [signing-runbook](../../docs/signing-runbook.md) C2; `website/CLAUDE.md`.

#### C7. Pin the release machine's engine, and install its export templates
- **Why: new this review.** The shipping `.dmg` is built **locally on the Mac**
  (`signing-runbook.md:188`), never in CI — so the one artifact a stranger
  downloads is produced by an engine no gate has ever checked. Three things
  depend on it being 4.6.3-stable specifically: ADR 0012 pins the exact patch;
  `THIRD-PARTY-NOTICES.md:25` **hard-codes the string "Godot Engine
  4.6.3-stable"**, so a `.dmg` built by another patch ships a licence document
  that is factually wrong, which is an ADR 0017 obligation and not a cosmetic
  one; and the credits screen renders whatever engine actually built the binary.
  **The precedent is already in the tree** — `wildlife-crossing-desktop-builds/`
  was built by Godot 4.6.0 against a pipeline pinned to 4.6.3, and five reviews
  running have had to work out that those are not the build. C5 asks only that the local
  Godot version be *recorded*; nothing asks that it *match*, and nothing owns
  installing the macOS export templates at all. `docs/export-setup.md:8-16`
  documents the template path
  (`~/Library/Application Support/Godot/export_templates/4.6.3.stable/`) and has
  no owner item. **This session's failed sandbox export is the same failure in
  miniature**: the engine looked for `4.6.3.stable/` by name and found nothing.
- **Files/areas:** no repo change necessarily; a line in the daily log, and
  possibly a pre-flight step in `docs/signing-runbook.md` Part A.
- **Acceptance:** the Mac's `Godot --version` recorded in a log and **equal to
  `4.6.3.stable`**; the matching export templates installed and the path
  confirmed; and the release `.dmg` built by that engine. If the Mac is on a
  different patch, that is a decision to record, not a detail to discover after
  notarization.
- **Depends on:** none — do it before C1/C2's first signed test export, since a
  re-export on a different engine invalidates the signature anyway. **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md):8-16;
  [signing-runbook](../../docs/signing-runbook.md):188; ADR 0012;
  `THIRD-PARTY-NOTICES.md:25`.

### Verification (tests, CI, export)

V1–V8 are unchanged from [[2026-08-18-next-build]] and were re-verified open.
**V9 is new.**

#### V9. Add `workflow_dispatch` to `ci.yml`
- **Why:** **new this review.** `ci.yml:3-7` triggers on `push: [main]` and
  `pull_request: [main]` only. There is no manual trigger, so the only ways to
  produce a fresh set of build artifacts are to push a commit or to
  `gh run rerun` an existing run — neither of which is available to someone who
  just wants a binary to look at, and the first of which invites throwaway
  commits on a branch guarded by a DCO gate. This surfaced from B3's artifact
  expiry: the project's own next-session plan depends on an artifact with a
  14-day life and has no supported way to regenerate one on demand.
- **Files/areas:** `.github/workflows/ci.yml:3-7`.
- **There is already a pattern to copy in this repo:**
  `.github/workflows/deploy-website.yml:21` carries a bare `workflow_dispatch:`.
  Match it. No `ref` input is needed — the Actions UI's *Run workflow* button
  offers a branch selector by default, which is the whole feature.
- **Acceptance:** `workflow_dispatch:` present at `ci.yml:3-7`; the workflow
  appears with a *Run workflow* button in the Actions UI; one manual run
  observed producing the `wildlife-crossing-desktop-builds` artifact.
- **Depends on:** none — it is a one-line change and it can ride along with
  B4's CI commit. **Size:** S
- **Refs:** `ci.yml:3-7,243`; `deploy-website.yml:21`;
  [[../daily-logs/2026-08-13]]:135.

#### V1. Add `env_config.gd` coverage
- **Re-verified:** `game/tests/` has 23 `*_test.gd` and none is
  `env_config_test.gd`. Still the only untested script carrying real branching
  logic — per-terrain mortality lookup and the resolution order (override → OS
  env → `DEFAULT = 0.20`, `env_config.gd:8,21-31`), which is exactly what the
  Phase 1 criterion *"deaths at the configured env-var rate"* rests on.
- **Acceptance:** resolution order covered end to end; suite reaches 24 scripts.
  GUT only discovers a new `*_test.gd` after a re-`--import`. **Size:** S

#### V2. Cover `species_registry.gd` and the constants files
- **Re-verified:** `species_registry.gd` (53 LOC) still has **zero** test contact
  of any kind, and so do `economy_constants.gd` and `habitat_constants.gd`.
  `grep -c Constants game/tests/data_validation_test.gd` → **0**, so no test
  asserts the three constants files against the values `data-schemas.md` §10
  specifies normatively. Where tests do touch `SimulationConstants` they read it
  as an *input*, which is the opposite of asserting it.
- **Acceptance:** `species_registry` load-failure path covered; constants values
  asserted against `data-schemas.md` §10, and §10 either gains
  `HAZARD_AVOIDANCE_MULT` (`simulation_constants.gd:38`, which the file itself
  flags as absent from §10) or the constant is justified in a comment. **Size:** S

#### V3. Reconcile `docs/test-plan.md` §11 against the real suite
- **Re-measured by script this session:** of **43** uniquely named tests in §11,
  **35 have no matching `func test_` in `game/tests/` (81%)** — identical to the
  last two reviews, as expected since no test file changed. The eight that
  resolve are the mortality, span and crossing rows plus
  `test_impassable_blocks_movement`, `test_four_bands_mapping` and
  `test_partnership_quality_bonus_applied`.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason. **Size:** S

#### V4. Export the `Linux arm64` preset in CI, or delete it
- **Re-verified:** `export_presets.cfg:32-62` defines a preset `ci.yml:158-170`
  never builds — the export step names exactly three presets — and
  `builds/wildlife-crossing-linux-arm64/` sits empty as its ghost. It is also the
  architecture this sandbox runs on, which is the main reason to prefer "export
  it": it would let a future review boot a real artifact instead of reasoning
  about one, as this session again could not.
- **Acceptance:** either the arm64 artifact appears in the CI upload and passes
  `check_pck_contents.py`, or the preset and the empty directory are gone.
- **Depends on:** B2. **Size:** S

#### V5. Exercise the `dco` job on a deliberately unsigned commit
- **Re-verified half closed:** [[../daily-logs/2026-08-13]] records the job
  running and passing on PR #1. Its acceptance also requires observing it
  **red**, which has not happened. A gate seen only green is a gate whose failure
  path — the branch that rejects an outside contributor's work — is untested.
- **Acceptance:** the `dco` job observed red on an unsigned commit and green once
  signed off; the throwaway PR closed without merging. **Size:** S

#### V6. Make the zero-tests guard report why it failed, and catch partial drops
- **Re-verified at `ci.yml:106-120`.** Two problems. `:115` is
  `TESTS="$(grep -oE '<testcase' "$XML" | wc -l | …)"` under `set -euo pipefail`
  — if GUT records zero test cases, `grep` exits 1, the substitution fails, and
  `set -e` kills the step **before** the `::error::` at `:118` can print. And the
  guard catches only `TESTS -eq 0`, whereas the failure it was designed for
  (2026-07-19) was a **partial** drop where a parse error removed one file and
  GUT still exited 0. At 23 scripts, a run that silently lost 22 still passes.
- **Acceptance:** a zero-test run prints the `::error::` before exiting; CI fails
  when the JUnit XML reports fewer than the expected number of test scripts
  (currently **23**); both verified against synthetic XML. **Size:** S

#### V7. Teach `build_encyclopedia.py` to delete, and test it
- **Re-verified:** `tools/build_encyclopedia.py` (686 LOC) contains no `unlink`,
  `remove(` or `rmtree` — it only ever writes — while `deploy-website.yml:47-56`
  gates on `git diff --quiet -- website/encyclopedia`. A **new** wiki entry
  produces an **untracked** file `git diff` cannot see, so the gate passes green
  while the deployed site is missing the page; a **deleted** entry leaves an
  orphan. Still the largest untested tool; `inspect_pck.py` (126 LOC) is the one
  that matters for B4, since it is the actual pack parser behind
  `check_pck_contents.py:35`.
- **Acceptance:** the generator removes pages whose wiki source is gone; the CI
  gate detects an untracked generated file (`git status --porcelain` as well as
  `git diff`); round-trip and external-asset checks covered by tests. **Size:** M

#### V8. Assert the two runtime assets survive export
- **Re-verified:** `main.gd:21` and `hud.gd:14` `preload()`
  `assets/audio/crossing_chime.wav` and `assets/sprites/crossing_cue.png`;
  `game/.gitignore:3` excludes `*.import`, so both are re-imported every CI run.
  A missing asset fails the smoke boot (a failed `preload` is a compile failure,
  so `Tutorial loaded` never prints) — so this is covered, but by a gate that
  reports *the binary did not boot*, not *the chime is missing*.
- **Acceptance:** the pack gate asserts both asset paths are present and names
  them when they are not; the test covers a pack missing one. **Size:** S

### Deferrable / nice-to-have

Carried from [[2026-08-18-next-build]] unchanged unless noted:

- **63% of visible animals die in the first in-game day** — about ten real
  seconds at 1×, before the player can build anything. Inherited from
  `EnvConfig.DEFAULT = 0.20` rather than chosen. A live tension with the
  *"cozy, not stressful"* north star.
- **Delete the stale `wildlife-crossing-desktop-builds/` artifacts.** 411 MB,
  **now four weeks old**, built by Godot 4.6.0 against a pipeline pinned to
  4.6.3, failing the repo's own pack gate. Five reviews running have had to
  establish that they are not the build. `fetch_build.py` downloads into
  run-scoped directories, so nothing needs this fixed path any more.
- **`tools/_to_delete/`, `commit-plan-2026-08-14b.json` and ten `.DS_Store`
  files** are untracked clutter. The commit plan is
  spent — its commits landed as `10062ad` and siblings. Named here so they get
  swept before B5 rather than during it.
- **`game/scenes/world/Animal.tscn` is dead weight** — referenced by no script or
  scene (re-verified by grep across `game/` this session); agents are drawn as
  circles by `world_renderer.gd`. Delete or wire. Note ADR 0015's title names it,
  so the deletion should carry a line explaining that.
- **`entities.json` is loaded and read by nothing** beyond
  `species_registry.gd:26` indexing it. Phase 2's Implements list requires the
  controlling-entity mapping "consumed as data".
- **The twelve world maps are template-scale.** `sub_areas.json` declares
  `playable_tile_count: 4000` for each; each map in `data/world/` resolves to
  238–312 cells — 92–94% below the ±15% acceptance criterion in
  `data-schemas.md` §11 — and `data_validation_test.gd:88-89` asserts only the
  *declared* number, never the resolved grid.
- **`connectivity_overlay_test.gd` and `species_manager_test.gd` build their
  fixtures from hand-copied const dicts** rather than reading `res://data/`, so a
  drift between those constants and the shipped JSON would leave them green.
  Minor — nine of the 23 test files, including all the data-consuming systems and
  `data_validation_test.gd`, do read the real files — but worth knowing which
  tests would notice a data change and which would not.
- **Three Phase 2 Implements items are neither built nor deferred in writing**,
  and one of them 08-18 dropped. (a) The **"toolbar tool" P0** — `roadmap.md:96`
  lists it; `main.gd:332` is a *"placeholder trigger"* bound to `M`. (b) **The
  entire Phase 2 P1 group** — `roadmap.md:99-100`: hover score, segment label,
  crossing-count note, sub-area summary on hover. A grep across `docs/` and
  `obsidian-vault/` finds no deferral for it anywhere. **08-18 did name it**
  (`2026-08-18-next-build.md:747`, *"Same for the P1 group at `:99-100`"*); it
  is carried here rather than restored. (c) **`sub-areas`' "controlling-entity
  mapping consumed as data"** (`roadmap.md:102`). None is an exit criterion, so none blocks the
  build — but §1's claim that Phases 1–2 are met *"as scoped by the logged
  decisions"* is true of the **exit criteria**, not of the Implements lists.
  **One roadmap decision block closes all three, and it is cheaper than B5.**
- **The detour-cost measurement covered Bow Valley only.** The other 17
  non-bisecting segments remain unmeasured
  ([[../daily-logs/2026-08-10]]:149-150). *(Carried from 08-18; an earlier draft
  of this note dropped it without saying so.)*
- **`website/CLAUDE.md:79`** still specifies user-guide section 2 as *"Placing
  habitats"*, which the shipped guide does not match. *(Also carried from 08-18
  and briefly dropped.)*
- **`BaseScreen` retrofit** of `ConfirmPanel` and `ConnectivityOverlay` —
  deliberately deferred 07-31.
- **Real art.** `game/assets/fonts/` and `tilesets/` are still `.gitkeep` only;
  `crossing_cue.png` is a 341-byte generated placeholder. The eight species
  portraits ship on the public site but are unwired in the game.
- Windows signing remains deliberately out of scope per ADR 0018's stated
  triggers. Phase 5 gates remain open and still do not block P0.

## 4. Doc drift to fix

Record only — docs are not edited during a review. Every row below was
re-verified this session. **No row left this table by being fixed. Five rows are
new** — each labelled below — **and they are new because this review went
looking, not because anything went stale in twelve idle days.** Most carried rows
also gained line references or a corrected count; where a carried row's wording
changed materially, the change is visible in the row itself.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | "`game/` is still almost entirely `.gitkeep`" (`:20`); A1 "no `project.godot`" (`:26`); A2 "GUT … not yet installed" (`:28-29`); A3 "no CI" (`:30`); A4 "zero game code" (`:32-35`); A5 "only `sub_areas.json` and `biome_groups.json`" (`:36`); A7 "`game/assets/` is all `.gitkeep`" (`:45`) | Every claim is false, **flagged in six consecutive reviews and never fixed**. Actual: 30 scripts / 3,569 LOC, 4 autoloads, GUT 9.6.0 vendored and enabled at `project.godot:35`, a 279-line five-job CI, all 8 data files plus 12 world maps valid, 23 test scripts / 237 tests, two real assets. `status: active` and `date: 2026-06-28` make this a trap for onboarding — retire or rewrite. **Longest-running item on this table and the cheapest to close; it becomes a stranger-facing document the moment B5 resolves.** |
| [testing-setup.md](../../docs/testing-setup.md):69-70 | "the suite currently reports **16 scripts / 134 tests / 2,779 asserts**" (dated 2026-07-30) | Measured this session: **23 scripts / 237 tests / 3,032 asserts**. Stale at six consecutive reviews and corrected five times — worth generating from the JUnit XML rather than maintaining by hand. |
| [testing-setup.md](../../docs/testing-setup.md):22 | "**Godot 4.6** (stable). Any 4.6.x patch is fine" | Contradicts `ci.yml:9-15` and ADR 0012, which pin the exact patch deliberately because export-template paths are version-keyed — as this session's failed export demonstrated, the engine looked for `4.6.3.stable/` by name. Carried unfixed. |
| [testing-setup.md](../../docs/testing-setup.md):142-147 | "### Known gap … Consider adding a CI assertion that the run actually collected tests" | Partly implemented at `ci.yml:106-120` — zero case only, and its error message is unreachable under `set -e`. See V6. |
| [testing-setup.md](../../docs/testing-setup.md):36 | "The repo's root `.gitignore` excludes `/tools/`" | It excludes `/tools/*` then re-includes `*.py`, `*.sh`, `*.gd` and `/tools/tests/` (`.gitignore:17-28`); the sentence reads as though nothing in `tools/` is committed, which is wrong — nine tools and five test files are. |
| [roadmap.md](../../docs/roadmap.md):49-50 | Phase 1 exit criterion "A fully spanned overpass yields a zero-mortality route" | Still predates [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md); "fully spanned" now means a valid **span** (two-sided core), not full segment coverage. The code is correct; the criterion's wording is not. Carried unfixed from four reviews. |
| [roadmap.md](../../docs/roadmap.md):148, :156 | The 2026-08-06 decision block cites Phase 2's exit criteria as `:98-108` and its Implements list as `:80-92` | The same session's insertion moved them. Cite the heading, not the line. |
| [test-plan.md](../../docs/test-plan.md) §11 | P0 coverage table presented as the first-playable bar | 35 of 43 named tests have no matching function (81%, re-measured this session). See V3. Carried unfixed. |
| [architecture.md](../../docs/architecture.md):52-68 | Lists systems and UI scripts that do not exist | Seven system scripts absent (`economy_manager`, `information_manager`, `permissions_manager`, `season_manager`, `time_controller`, `milestone_tracker`, `narrative_manager`) plus most of the UI roster; all Phase 3–6, so not a regression, but the table reads as a description of the codebase and overstates it. `ui/BaseScreen.tscn` is absent **deliberately** — every screen here is code-instantiated. §8 cross-references only ADRs 0001–0005 of the 18 that exist. Split into *planned* vs *built*. |
| [game/CLAUDE.md](../../game/CLAUDE.md):86-100 | Systems table names 13 files, of which **6 are built** | **24 of the 30 built scripts are absent** from it, including `simulation.gd`, `main.gd`, all four autoloads, all three constants files, `world_renderer.gd` and all ten UI scripts; there is no UI section. The file states its own rule at `:102-104` — *"Add a row here whenever a new system is created"*. Now a five-week-old convention miss. |
| [push-runbook.md](../../docs/push-runbook.md):134, 266, 301 | Dated "2026-08-14" | The work was 2026-08-13 local. Cosmetic; self-reported in [[../daily-logs/2026-08-13]]:122-124 and uncorrected. |
| [push-runbook.md](../../docs/push-runbook.md) §Troubleshooting, and `tools/ship.py:382-384` | Both blame the `weekly-build-review` harness for the stale `.git/index.lock`; [[../daily-logs/2026-08-13]]:117-121 instead blames the Cowork mount forbidding `unlink`, *"so every git command leaves its lock behind"* | **Updated: the 08-13 explanation is now falsified across two independent sessions.** The lock is 0 bytes with mtime 2026-08-13 22:04 — unchanged after a full session of git commands from this sandbox on 2026-08-18 *and* again today. If every git command left a lock behind, the mtime would move; it has not, twice. Three places in the repo carry two accounts and neither is supported. Harmless (`ship.py:83,380-416` clears anything older than 120 s), but the correction is **"cause unknown"**, and it should be written as that rather than replaced with a third guess. |
| [README.md](../../README.md):22 | Points at `.claude/CLAUDE.md` | `.claude/` is an empty directory; the file is at the repo root. |
| [README.md](../../README.md):10-17 and root [CLAUDE.md](../../CLAUDE.md):32-42 repo-structure blocks | Neither lists `harness/` or `tools/` | `grep -n harness README.md CLAUDE.md` → no matches. Four tracked files live in `harness/`, including the skill that produces these notes, and nine tracked scripts plus five tool tests live in `tools/`. Both become stranger-visible the moment B5 resolves. (`fable-game-builder/` is **not** in this row: `git check-ignore -v` → `.gitignore:57`, so it is ignored and cannot become visible. `CLAUDE.md:197-200` is the *scoped-CLAUDE.md* table, not the structure block — an earlier draft of this note cited it by mistake.) |
| [signing-runbook.md](../../docs/signing-runbook.md):392-395 (Part D.3) | *"**Gate the other two platforms' packs.** Build-review V2 is still open: the pck gate and smoke boot run on the Linux binary only. Publishing a checksum for a Windows `.exe` that no gate has ever checked attests to the integrity of contents nobody verified."* | **New row, and the claim is false.** `ci.yml:191-205` runs `check_pck_contents.py` against **all three** packs in a loop — Linux `.pck`, Windows `.pck`, macOS `.zip` — and `ci.yml:256-279` boots the `.exe` on `windows-latest`. `export-setup.md:92-102` already describes this correctly, so the repo contradicts itself. The runbook's warning would send an operator to re-do work that landed on 2026-08-10. |
| [adr/0018](../../docs/adr/0018-code-signing-and-notarization.md):164-167 §Follow-on work | *"Build-review **V2** (gate the Windows and macOS packs, not just Linux) should land before or with this."* | **New row.** Same falsified claim as the row above, in the ADR that governs the release. It is the one §Follow-on item that reads as open and is in fact **closed**. Strike it, or mark it done with the commit that closed it — otherwise B6's operator reads an ADR that says a gate is missing when it is not. |
| [ci.yml](../../.github/workflows/ci.yml):220-223 | *"Known gap … The durable fix is an in-game credits screen built from `Engine.get_copyright_info()`"* | **New row.** Half closed: the credits screen shipped 2026-08-09 (`66cf279`, ADR 0017 amendment). Only the `.zip`-places-notices-beside-the-bundle half is still live, which is C2. C2 currently cites this comment as though all of it stands. |
| [roadmap.md](../../docs/roadmap.md):163 and :174 | States in the present tense that `WorldSelectMap.tscn` *"sets `mouse_filter = 2` (IGNORE)"* (`:163`) and that the blind click *"Needs a regression test asserting that a click in world-select mode selects no segment"* (`:174`) | **New row.** Both closed by `cb9f9b8`: the scene sets `mouse_filter = 0` (STOP) and `world_select_controller_test.gd:175` is the regression test. The decision block reads as a live defect report. |
| [ci.yml](../../.github/workflows/ci.yml):257 | `smoke-windows` job name: *"Smoke-test the Windows binary (boots to Main.tscn)"* | **New row.** `run/main_scene` is `TitleScreen.tscn` (`project.godot:23`); the job reaches `Main` only via `smoke_boot.sh`'s `--skip-menu`. Cosmetic, but the job name is what an operator reads first when the gate goes red, and it names the wrong scene. |

## 5. Risks & open questions

- **The artifact the next step depends on expires in about two days.**
  `ci.yml:243` retains build artifacts for 14 days; run `31762062722` is from
  2026-08-13; the 08-13 next-session plan's item #2 is
  `tools/fetch_build.py 31762062722 --check`. That is 2026-08-27, and the exact
  upload time is unknown so it could be sooner. **The recovery is cheap and worth
  knowing in advance:** merge B2 first and verify the resulting `main` run, or
  `gh run rerun 31762062722`. What is not available is the Actions UI's *Run
  workflow* button — `ci.yml` has no `workflow_dispatch` (V9). This is the first
  time a review has found a *deadline* rather than a *gap*, and it exists only
  because twelve days passed.
- **A full week produced nothing, and the calendar-bound item took the whole hit.**
  B1 (Apple enrolment) is small, is nobody's favourite task, costs $99, and
  silently sets the release date. It was ranked third on 08-12, first on 08-18,
  and appears in none of the 08-10 or 08-13 next-session lists. Every other item
  on this page can be compressed by working harder; this one cannot. **Thirteen days after it was
  first ranked, it has not started.** Strictly, no release date exists in the
  repo to have slipped — `grep -rn -i 'release date|target date|ship date'`
  across `docs/` and the vault finds only `daily-logs/2026-08-10.md:75` saying a
  slow validation *"would gate the release date"*, conditionally. The honest
  form of the claim is the one the runbook makes: this is the only gate whose
  duration later effort cannot compress, so every idle day is a day added to
  whenever the release happens.
- **The project's own review record now lives on one machine, twice over.** Two
  consecutive build reviews, the index headline and the 08-13 log are
  uncommitted. The build-review notes are how this project knows what is blocking
  it; a note that is not in the repo is not a record, it is a file. Fold the
  commit into B2 rather than treating it as housekeeping.
- **`main` is fifteen days stale and ten commits behind `HEAD`.** Root
  `CLAUDE.md` requires `main` to be runnable at all times; it currently *is*, but
  in a state that predates the entire save/load system. Every day PR #1 stays
  open widens the gap between what the repo says the project is and what it is.
- **Three separate decisions are staged for a repo transition nothing schedules**
  (B5). ADR 0017's premise, ADR 0018's threat model and the DCO gate's stated
  purpose all assume the repository goes public; no document says when, who, or
  what has to be true first. The failure mode is the quiet one: a release lands,
  the website's download button points at it, and the first person to find out it
  is unreachable is a stranger.
- **This review could not observe CI.** `which gh` → not found; `git fetch
  origin` → *Host key verification failed*. Nothing here should be read as a
  claim about CI's current status, including the 08-13 log's report of a green
  five-job run — that is a record of what a human saw, not something this session
  verified. Relatedly, `origin/main` is a remote-tracking ref last updated **by a
  push** on 2026-08-10, not by a fetch, so "10 behind" is true as of that push
  and would be wrong if PR #1 has since merged. Nothing in the working tree
  suggests it has.
- **`smoke-windows` still cannot be read as evidence when the export fails.**
  `needs: export` is bare and `if: always()` is on steps rather than the job, so
  a failing pack gate or Linux boot **skips** it. Any acceptance written against
  it must say *green, not skipped*.
- **The first thing a player sees is aimed at a measured dead zone** (C4). One
  line, measured fifteen days ago, still undecided. It should not survive into a
  release note.
- **Nothing verifies that the published release actually opens for a stranger**
  (B7). Eight reviews have measured the repo; the harness's definition of a
  working build ends with *"**and** it launches"*, and the runbook's A8 is the
  only test of that half. It was sitting in `signing-runbook.md:227-236` the
  whole time and no review had lifted it into a work item. Worth noticing as a
  pattern: the reviews have been thorough about what the repo contains and quiet
  about what a downloader experiences.
- **The eight species portraits on the public site have no recorded
  provenance.** `website/assets/img/species/*.png` are not mentioned in
  `THIRD-PARTY-NOTICES.md`, and `LICENSE-ASSETS` covers **original work only**.
  If they were authored for this project, nothing needs doing except a line
  saying so; if they were not, ADR 0017 requires a notice before the repo goes
  public (B5) and before a release ships. It cannot be settled from the repo —
  it needs the person who made them. Everything else vendored **is** properly
  noticed: `game/addons/gut/` (MIT) and its twelve `.ttf` files in three
  families (OFL) are all named, and
  `exclude_filter="addons/gut/*,tests/*"` is present on **all four** export
  presets (`export_presets.cfg:11,42,73,116`), so none of it ships.
- **The sandbox cannot export**, re-confirmed by attempt this session:
  `--export-release "Linux arm64"` failed on missing templates for
  `4.6.3.stable`, and `~/.local/share/godot/export_templates/` is empty. V4 (an
  arm64 preset in CI) would let a future review boot a real artifact instead of
  reasoning about one.

## 6. Suggested next-week focus

The ordering has changed from 08-18 in exactly one respect: **B2 now comes before
B3**, because merging generates a fresh artifact and makes the expiry moot.

1. **B1a — make the GPG key. Blocks on nothing, unblocks C6.**
   Then **B1b — start Apple enrolment.** First, before anything else, on whatever
   day the next session happens. Deferred three times; C1, C2 and B6 queue behind
   the Apple half; its duration is the one thing later effort cannot compress.
2. **B2 — commit the five vault files, then merge PR #1** (S). The commit must
   come first or the branch push won't carry it; use `-s` or the DCO gate rejects
   it. Watch for `smoke-windows` **green, not skipped**. The merge fires a
   `push: [main]` run, which gives B3 a fresh artifact and a better one — a build
   of `main` rather than of a branch.
3. **B3 + C4 + C5 — fetch the build, decide the camera, walk Step 5** (M + S + S).
   One session, ideally the same day as B2. **If B2 slips past 2026-08-27**, run
   `gh run rerun 31762062722` first rather than assuming `fetch_build.py` will
   still find the artifact. The value is in the walking: the credits screen
   actually read, the chime actually heard, the F5/quit/relaunch/F9 round-trip
   actually done, and the `codesign -dv` output recorded for C1.
4. **C3 + C7 + B5 + V9 — the ten-minute items** (S × 4). Version strings are a
   two-line edit; C7 is checking `Godot --version` on the Mac and installing the
   4.6.3 export templates before anything gets signed; B5 is very likely a
   sentence recording something already true; V9 is one line of YAML copied from
   `deploy-website.yml:21` that removes the whole class of problem finding 1
   describes (copy the one-liner at `deploy-website.yml:21`). None has
   dependencies, all are on or beside B6's critical path,
   and all are things to do while waiting on Apple.
5. **B4 — the packaging decision** (M), **carrying C6 and V9 in the same PR.**
   The last thing standing between a green pipeline and something a stranger can
   download and run. Land it as one commit with the `smoke-windows`,
   `inspect_pck.py` and `check_pck_contents.py` updates, the `SHA256SUMS.txt`
   `find` pattern, and the download-page copy — C6 cannot be scheduled any other
   way, since it is a repo change whose inputs only exist once B4 is decided.

C1 and C2 unlock the moment the Apple certificate lands; B6 waits on everything;
and **B7 — the runbook's A8, downloading the published DMG on a clean Mac — is
what actually turns "first build" into "next build"** in the following review.
Nothing before it answers the question this note asks. **If B1 starts this week
the release waits only on Apple; if it slips again it slips the release
one-for-one — for the third week running.**

---

## Verification

Labels per the harness's Step 6 rule. **Confirmed** = traced to something read or
run *this session*, against `4119915`. **Assumed** = the reasoning is sound but
nothing was checked. **Unverifiable** = not checkable from this session; say so
rather than hedge.

### Confirmed

- **Build case is "first build".** `du -sh builds/` → 4.0K, contents
  `.gitignore`, `.gitkeep`, one empty `wildlife-crossing-linux-arm64/`;
  `git tag -l` → empty; `ls docs/release-notes/` → `.gitkeep` (0 bytes).
- **No commits since the last review.** `git log --since=2026-08-18 --oneline` →
  empty. `git log -1` → `4119915`, 2026-08-13 21:56:53 -0500. `find . -newermt
  "2026-08-18" -type f` (excluding `.git/`, `game/.godot/`,
  `wildlife-crossing-desktop-builds/`, `__pycache__/`) → three files:
  `.obsidian/workspace.json`, `2026-08-18-next-build.md`,
  `build-reviews/README.md`.
- **Test counts.** GUT run this session: 23 scripts / 237 tests / 237 passing /
  3,032 asserts / 1.711s / `---- All tests passed! ----`, exit 0, against
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` reporting
  `4.6.3.stable.official.7d41c59c4`. `python3 -m unittest discover -s tools/tests
  -b` → `Ran 86 tests … OK`.
- **Both headless boots clean**, bare and `-- --skip-menu`, with the quoted `[I]`
  lines and no `ERROR:`/`SCRIPT ERROR`.
- **Export is impossible in this sandbox.** `--export-release "Linux arm64"` →
  *No export template found at …/4.6.3.stable/linux_release.arm64*;
  `ls ~/.local/share/godot/export_templates/` → empty.
- **All `export_presets.cfg` values** cited in C1, C2, C3, B4 and B6 — read at
  the line numbers given.
- **Every "still absent" grep**: `grep -in fingerprint README.md` → nothing;
  `grep -in "gpg\|sha256\|smartscreen\|unsigned" README.md website/index.html` →
  nothing; `grep -n harness README.md CLAUDE.md` → nothing;
  `ls game/tests/env_config_test.gd` → absent; `grep -rl SpeciesRegistry
  game/tests/` → nothing.
- **`ci.yml` structure**: 279 lines; five jobs at `:24,57,74,122,256`;
  `GODOT_VERSION` at `:15`; `retention-days: 14` at `:243` (single occurrence, in
  the upload step's `with:`); triggers `push: [main]` / `pull_request: [main]` at
  `:3-7` with **no** `workflow_dispatch`; `if: always()` at `:225` and `:238`
  (steps); `needs: export` at `:258`.
- **Git state**: branch, `origin/main` = `0c31c85` with reflog
  `2026-08-10 21:49:48 -0500 update by push`, `origin/main...HEAD` → `0 10`,
  `origin/main...main` → `0 4`, four modified/untracked vault paths,
  `.git/index.lock` 0 bytes mtime 2026-08-13 22:04.
- **Test-plan §11 coverage**: 43 uniquely named tests, 8 implemented, 35 missing
  (81%) — recomputed by script this session, not carried from the last note.
- **Data validity**: all 8 `game/data/*.json` and all 12 `data/world/*.json`
  parse; 20 files, 0 failures.
- **Systems inventory**: 30 `.gd` files, 3,569 LOC, autoloads at
  `project.godot:28-31`, seven architecture-named systems absent.
- **Run `31762062722` is named in [[../daily-logs/2026-08-13]]:48** as the green
  five-job run, and at `:134` as the argument to `fetch_build.py` in that log's
  next-session list (`:135`, not `:134` as an earlier draft of this note had
  it). Both read this session.
- **The three-platform pack gate and the Windows boot job exist**
  (`ci.yml:191-205`, `:256-279`), which is what falsifies the "V2 is still open"
  claim in `signing-runbook.md:392-395` and ADR 0018 §Follow-on.
- **`exclude_filter="addons/gut/*,tests/*"` is present on all four export
  presets** (`export_presets.cfg:11,42,73,116`), so GUT and its OFL fonts do not
  ship and `THIRD-PARTY-NOTICES.md:86-87`'s claim holds. The only vendored
  third-party material in the tree is `game/addons/gut/` and its fonts, both
  noticed; the Godot binary at `tools/godot/` is untracked (`.gitignore:17`).
- **`commit-plan-2026-08-14b.json` and `tools/_to_delete/` are gitignored** —
  `git check-ignore -v` → `.gitignore:33` and `.gitignore:17` respectively.
- **`deploy-website.yml:21` already carries `workflow_dispatch:`**, and its
  trigger paths are `website/**`, `obsidian-vault/wiki/**`,
  `tools/build_encyclopedia.py` and itself (`:7-14`).
- **The runbook's `SHA256SUMS.txt` `find` pattern** (`signing-runbook.md:297`)
  matches `*.dmg`, `*.exe`, `*.pck` and `wildlife-crossing.x86_64` — and no
  archive extension.
- **Runbook A8 exists at `signing-runbook.md:227-236`** with the wording quoted
  in B7.

### Assumed

- **The 14-day retention applied to run `31762062722`.** `13857e0` (which
  restored `retention-days: 14`) is an ancestor of `4119915` and therefore in the
  branch PR #1 built, and the run postdates the smoke fix `6db1e3d` since all
  five jobs were green. So the artifact should carry a 14-day life expiring
  ~2026-08-27. **Not checked** — no GitHub access. If the setting did not apply,
  the repository default (typically longer) would, which makes the deadline
  softer but does not make a two-week-old artifact a sound thing to plan around.
- **`gh run rerun` will regenerate the artifacts.** This is how GitHub Actions
  behaves — run records outlive artifacts — but it was not exercised here.
- **PR #1 has not merged since 2026-08-10.** Inferred from `origin/main` not
  moving and the working tree being untouched. `origin/main` is a
  remote-tracking ref updated by a push, not a fetch, so this is inference.
- **The `.git/index.lock` is harmless.** Read from `ship.py:83,380-416`, which
  clears anything older than 120 s; the clearing path was not executed here.

### Unverifiable from this session

- **Whether any CI run has ever passed, including run `31762062722`.** `gh` is
  not installed; `git fetch origin` fails with *Host key verification failed*.
  The 08-13 log's green-run report is that day's record, not this session's
  finding. **A green badge or a daily-log line is not evidence of current CI
  status** and is not treated as such anywhere in this note.
- **Whether the artifact for run `31762062722` still exists today.** The expiry
  arithmetic is sound; the fact is not checkable here.
- **Whether the repository is public** (B5). Not inspectable from this session —
  which is itself the argument for writing the answer down somewhere in the repo.
- **Whether a windowed macOS build of `HEAD` launched on 2026-08-13.** Reported
  in the daily log; no artifact of it exists in the repo.
- **The Godot version installed on Brent's Mac.** Never captured by any log; C5
  asks for it.
- **Anything about the state of PR #1's review, checks, or conversation.**

### What the completeness audit changed

A fresh subagent, which had not seen this session's reasoning, was asked one
question: *given the actual repo state, is anything needed for the first build
missing from this list, and is anything listed actually already done?* It
verified every "still open" claim independently and found none already closed —
C1, C3, C6, V1, V2, V3, V4, V6, V7 and V9 all re-confirmed open by its own
commands. It added the following, all folded in above:

1. **B7** — runbook A8, the download-on-a-clean-Mac test. The largest miss: the
   only item that closes the *"and it launches"* half of the build case, sitting
   unclaimed in the runbook across eight reviews.
2. **C7** — the release machine's engine and export templates, unowned by any
   item, with an ADR 0017 consequence (`THIRD-PARTY-NOTICES.md:25` hard-codes
   the engine version) and a precedent already in the tree.
3. **B1** — the GPG public key's `.asc` commit and keyserver upload had no
   owner; only the fingerprint did.
4. **B4** — `SHA256SUMS.txt`'s `find` pattern matches no archive extension, so
   the manifest would not cover the assets B4 argues for publishing.
5. **B6** — its dependency list omitted V4, which its own acceptance text argues
   for.
6. **C6 and C2** — dependency directions corrected; C6 as 08-18 wrote it is
   unschedulable.
7. **B5** — this note's first draft claimed `commit-plan-2026-08-14b.json` and
   `tools/_to_delete/` would become visible when the repo flips public. **Wrong:
   both are gitignored.** The real exposure is `harness/` and `tools/`, which is
   already a §4 row.
8. **§4** — four drift rows added, two of them falsified claims sitting in the
   signing path itself (`signing-runbook.md` D.3 and ADR 0018 §Follow-on both
   still say build-review V2 is open; it closed on 2026-08-10).
9. **Deferrables** — the Phase 2 P1 group, which this note's first draft had
   left out.
10. **V9** — `deploy-website.yml` already has the pattern; the `ref` input
    suggestion was unnecessary.

The one item it raised that this note could not settle is the provenance of the
eight website species portraits; it is filed in §5 as an open question for the
owner rather than as a work item, because the repo cannot answer it.

### What the fact-integrity audit changed

A second subagent, also with no view of this session's reasoning, audited the
draft against the daily logs, ADRs, roadmap and the previous review, and re-ran
both test suites. It confirmed the load-bearing arithmetic — the 81% test-plan
figure, the 7/7/9 item counts, the 2026-08-27 expiry, every elapsed-time claim,
the test and LOC counts, and the 92–94% world-map figure — and returned **29
defects**, of which **28 were accepted and corrected above**. The pattern is
worth recording, because it is not the pattern the author expected:

- **Wrong line numbers were the largest category (ten of 29)**, and several were
  inherited from 08-18 and copied forward without re-opening the file —
  `roadmap.md:157`, `daily-logs/2026-08-13:134`, `CLAUDE.md:197-200`. A citation
  is not evidence unless the line is re-read; carrying one across reviews is how
  it decays.
- **One fabricated quotation.** Both 08-12 and 08-18 attributed to `ci.yml:44-53`
  the phrase *"before the repo is announced publicly"*. **It is not in the
  file.** It survived two reviews inside quotation marks, next to a line range,
  which is exactly the shape that reads as verified. Corrected in B5 with the
  real sentence, which supports the same point.
- **Four wrong counts**: 18 roster scripts present (13); 8 scripts without a
  named test (9); two `.DS_Store` files (ten); "two rows updated" in §4 (about
  ten). Three of the four appeared in prose that had no §Verification label,
  which is finding 29's point — **the labelling rule was applied to the claims
  the author already doubted and not to the ones stated in passing.** That is
  the failure mode the rule exists to catch, so it is recorded rather than
  quietly fixed.
- **Two claims about the previous review were false**: that 08-18 dropped the
  Phase 2 P1 group (it did not — `2026-08-18:747`), and that no review had
  "named" runbook A8 (both 08-12 and 08-18 cite A6–A8). Both were corrections
  this note claimed credit for.
- **Two internal contradictions** — "four reviews" vs "five reviews" about the
  same stale artifacts, and "the only files modified" vs §Verification's list of
  three.

**One finding was rejected**, and it is worth naming so the next review does not
re-apply it: the audit read `daily-logs/2026-08-10.md:75`'s *"1 to 20 business
days"* as an identity-validation quote for **Apple** enrolment that contradicts
B1's "a few days" sizing. It is not — that passage
(`2026-08-10.md:70-77`) is about **Azure Artifact Signing** for Windows, which
ADR 0018 rejected. Apple's own figure is `signing-runbook.md:42`, *"Apple
enrolment takes a few days"*, and `:408` — *"nothing — a few days"*. B1's sizing
stands.

---

## Related

- [roadmap](../../docs/roadmap.md) — Phase 1 and Phase 2 exit criteria are the
  target. *(The note template writes these two as `[[wikilinks]]`; both files
  live in `docs/`, outside the Obsidian vault root, so a wikilink does not
  resolve. Written as relative links here.)*
- [pre-build-checklist](../../docs/pre-build-checklist.md) — stale, see §4
- Previous review: [[2026-08-18-next-build]]
- [[../daily-logs/2026-08-13]] — the last session of record
- [ADR 0017](../../docs/adr/0017-licensing.md), [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
- [signing-runbook](../../docs/signing-runbook.md), [push-runbook](../../docs/push-runbook.md)
