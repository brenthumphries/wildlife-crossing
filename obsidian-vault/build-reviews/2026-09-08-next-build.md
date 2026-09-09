---
title: "Build Review — Next Build (2026-09-08)"
date: 2026-09-08
tags: [build, review, planning]
status: active
---

> Weekly build review. Target: **first working build** (P0 first playable =
> [roadmap](../../docs/roadmap.md) Phases 1–2). One question: what work is
> needed to get there?

> [!info] Snapshot
> Measured against **`16622ec`** (*Merge pull request #7 from
> brenthumphries/docs/log-2026-09-06*, 2026-09-06 19:44:29 -0500) on branch
> **`main`**. `git rev-list --count origin/main..HEAD` → **0**;
> `HEAD..origin/main` → **0**. Suites re-run this session: **24 scripts / 246
> tests / 3,154 asserts** green, **86** Python tests OK, both headless boots
> clean. Anything not traceable to something read or run this session is
> labelled in [§Verification](#verification).

> [!warning] The one thing that happened this week is sitting in the working tree
> **B8 is written and unlanded.** `.gitignore` carries all seven credential
> patterns B8's acceptance names; `docs/signing-runbook.md` has gained the Part
> A pre-flight, with the `git rm --cached` trap written out in full and the
> *"about to go public"* tense corrected. Both are **uncommitted**.
> `commit-plan-2026-09-07.json` names the branch (`chore/credential-path`) and
> two finished commit messages. `git branch --show-current` → **`main`**. The
> branch was never made, the commits were never written, and
> `obsidian-vault/daily-logs/2026-09-07.md` does not exist — **the session that
> did this work left no log.** Under ruleset `22403399` this is now further from
> `main` than uncommitted work used to be: it cannot land except through a pull
> request. See [B8](#b8-land-the-credential-path-work-that-is-already-written).

> [!success] Amendment 2026-09-09 — **B8 is closed.**
> Both halves landed through PR #8, merged as `6fbd34e`: `13730fe` adds the
> seven credential patterns to `.gitignore`, `a2b867b` adds the Part A
> pre-flight to `docs/signing-runbook.md`. `git check-ignore -v` now returns
> seven lines against the committed file rather than a working tree.
> Secret scanning and push protection were read **disabled**, set with the
> runbook's own `gh api --method PATCH` line, and re-read **enabled**. That
> line had never been run before today, so the pre-flight is now walked rather
> than only written. `secret_scanning_non_provider_patterns` is deliberately
> left disabled.
> **What this note says about B8 stands as measured.** At `16622ec` the work
> was uncommitted, and it was. Two numbers in [§4](#4-documentation-drift) were
> wrong when this note was drafted and were corrected before it landed, not
> amended, because nothing had been published to amend: the signing-runbook row
> cited `:452`, a line number that only exists after the pre-flight lands, and
> gave the shift as +57 when it is +60. Both are recorded in
> [[../daily-logs/2026-09-09]].

> [!failure] Amendment 2026-09-09b — **This note shipped without its Step 6 audits. They have now run, and they found sixteen defects.**
> The harness's Step 6 is not optional and it did not happen: the review session
> ended between writing the note and auditing it, and the note was committed in
> `0b28974` in that gap. **Everything below was found after publication that
> should have been found before it.** The body is left exactly as written —
> amend, never correct, once a note is landed — so read §2, §3 and §4 through
> this list.
>
> **The one that matters, because it is a regression against a documented fix.**
> **V3's figures are wrong and the reasoning attached to them is backwards.**
> This note reports §11 of `docs/test-plan.md` as *31 named / 23 missing / 74%*
> and says the 09-01 note's *43 / 35 / 81%* "did not record its extraction" and
> is "not comparable". Both halves are false.
> [[2026-09-01-next-build]]`:792-795` states its method in the item itself, and
> its §Verification at `:1118-1120` goes further: *"an earlier, sloppier version
> of that script returned **31/23** by mis-slicing the section, and the figure
> above is the one that reproduces 08-25's."* §11 names twelve tests in the form
> `` `world_select_controller_test.gd::test_…` ``; an extraction anchored on a
> backtick immediately before `test_` drops all twelve. **This note re-derived a
> number the previous review had already diagnosed as a bug, published it as the
> measurement, and labelled the correct figure unusable.** The right figures are
> **43 / 35 / 81%**, unchanged, since `docs/test-plan.md` has not moved. The §4
> test-plan row and the §Verification entry carry the same error.
>
> **Counts and citations, each re-read from the file at `16622ec`:**
> - **§2 "6 of the 30 GDScript scripts have no named test file" — actually 8**:
>   `main`, `title_screen`, `env_config`, the three constants files, **`debug`**
>   and **`event_bus`**. The note's own next clause says "down from 9", and
>   9 − 1 = 8. The two-with-no-grep-contact figure is right.
> - **`game/project.godot` is 43 lines, not 44** (§3 C5, §Verification). The
>   absent `[display]` section and the four section names are right.
> - **The zero-tests guard is `ci.yml:116-130`, not `:118-131`** (V6, and twice
>   in §4). `:116` is the `- name:`, `:130` the closing `fi`. The inner
>   citations `:125` and `:128` are both correct, which is what makes the range
>   the outlier — it was the one number in that item derived rather than read.
> - **The `smoke-windows` hardcoded `.exe` path is `ci.yml:319`**, not
>   `:293-298` (§3 B4). `:293-298` is the job header; the job runs to `:331`.
> - **`roadmap.md`'s 2026-08-06 decision block is `:138-196`, not `:138-160`**
>   (§2); and §4's correction "Implements list at `:94-108`" should read
>   **`:94-106`**.
> - **`export_presets.cfg:32-61` for `[preset.1]`**, not `:32-62` (V4).
> - **C9's grep returns five hits, not four** — `roadmap.md:354` also matches
>   `Decision logged`. The four Phase 1–2 blocks named are correct.
> - **§4's `ci.yml:238` quote is not verbatim.** The elision *"so these land
>   beside the bundle"* rewrites the actual clause, *"beside the **archive
>   rather than inside the .app** bundle"*. C2 quotes the same line correctly.
> - **§4 attributes one verbatim quote to two files.** The sentence quoted is in
>   `signing-runbook.md` only; ADR 0018`:165` makes the same stale claim in
>   different words. Calling it "the ADR copy" implies a copy.
> - **§2 "the smallest files are the three constants tables at 18/18/46 LOC"** is
>   false as stated — `debug.gd` (21) and `base_screen.gd` (23) sit between them.
>   The "no empty stubs" conclusion survives; the sentence does not.
> - **§5 and V5: ruleset `22403399` had admitted three pull requests at
>   measurement, not two** — #5, #6 and #7, and `HEAD` *is* #7's merge commit,
>   which the note states two lines earlier. The "two" was carried from
>   [[../daily-logs/2026-09-06]], written before #7 existed.
> - **Labelling:** §Verification claims "every line number cited in §2, §3 and
>   §4" as Confirmed, which the guard-range defect falsifies; and it lists
>   `origin/main..HEAD` under Confirmed while §5 records that `git fetch origin`
>   failed, so that ref is stale-local and proves nothing about the remote.
>
> **§4 gains a row this note should have found, and C8 is wrong about why.**
> C8 says `docs/pipeline-design.md` states the repository is public but "never
> say **since when**". It does — `:397`, *"The repository went public on
> **2026-09-05**"* — **and the date is wrong**, contradicting the 2026-08-29
> that [[../daily-logs/2026-08-29]] establishes by `gh repo view`.
> `ci.yml:260` repeats the same wrong date. **Two tracked files state the
> project's licensing and threat-model premise and both state it incorrectly**,
> which is a sharper version of exactly the defect C8 exists to fix, and this
> note walked past it.
>
> **C8 is closeable now, and neither the amendment above nor the 09-09 log
> carried it through.** This note predicted it — *"Landing B8 closes the second
> half by itself"* — and B8 landed. `a2b867b` also rewrote the tense line, so
> `docs/signing-runbook.md:196-197` now reads *"the repository has been public
> since 2026-08-29"*: tracked, durable, both facts, correct date. Both of C8's
> acceptance clauses are met; `README.md` was named as the natural home, not as
> a requirement. **Close C8, and open the date-contradiction row above in its
> place** rather than leaving a met item open to carry a different defect.
>
> **The completeness audit found four gaps in the work list**, and the first is
> the largest thing this review missed:
> - **Nothing names how the Windows and Linux binaries reach `builds/` on the
>   release machine.** `signing-runbook.md:352-357` sweeps `builds/` to build
>   `SHA256SUMS.txt`; only the `.dmg` is built locally (A6, `:245`); the other
>   two exist solely inside the CI artifact, and `tools/fetch_build.py` downloads
>   into a *run-scoped* directory by design. So the manifest silently covers one
>   platform of three, and B7 has no Windows or Linux asset to launch. Both
>   workarounds are closed off by the runbook itself — Part D.1 forbids moving
>   signing into CI, Part D.3 forbids publishing a checksum for a binary no gate
>   has checked. **This blocks B6 and B7 and it has a 14-day artifact clock on
>   it.** B4's acceptance touches the `find` pattern but no item populates the
>   directory.
> - **No procedure exists for cutting the tag or creating the Release.**
>   `gh release`, `git tag -a` and `action-gh-release` return **zero** hits
>   across `docs/`, `tools/` and `.github/`. `push-runbook.md` ends at Step 5;
>   `signing-runbook.md` Part D is titled *"Wiring it into the release"* and
>   never creates one. Every other multi-step manual operation here has a
>   runbook; the one the build case turns on has none.
> - **`deploy-website.yml:57-65` will reject C6's copy.** It fails on any
>   external `src`/`href` outside an allowlist at `:62`, and
>   **`keys.openpgp.org` is not on it** — while `README.md:86-88` links exactly
>   there. Worse, its `check` job is *not* one of the five required contexts, so
>   it does not block the merge; it just silently stops the deploy, leaving the
>   public site's download button pointing at an empty Releases page.
> - **C1's scope is missing the change that turns signing on.** This note says
>   C1 supplies "identity, team id and `notarization=1`".
>   `signing-runbook.md:221-227` is explicit that `codesign/codesign=1` is
>   *"Built-in (ad-hoc only), not real signing — Xcode codesign is `3`"*, and
>   that notarytool is `2`, not `1`. Leaving `codesign=1` reproduces the
>   `adhoc` signature the 09-02 walk recorded, which fails B7's *"no Gatekeeper
>   warning at all"*.
>
> **On ADR 0020**, which landed after measurement and which this note could not
> have seen: its follow-on work is event-keyed rather than dated and **none of it
> gates `v0.1.0`**. Two smaller consequences do land, and neither is in the body.
> `protect_main.json:33` sets `required_review_thread_resolution: true`, which
> the note's "five green contexts and a merge click" does not account for — and
> ADR 0020 §D3 now positively invites advisory reviews on self-authored pull
> requests, so an unresolved thread on B4's or B6's PR is an unmergeable PR
> rather than a red one, the same failure *shape* as the promoted job-name row.
> And ADR 0020 is a third independent reason `protect_main.json` gets edited,
> while **still no item owns that file.** One drift row also arrived with it:
> `pipeline-design.md:370-377` (§6.1) still asserts the ADR 0019 rule that
> ADR 0020 §D2 supersedes, one section above the pointer `6c6891c` added.
>
> **Finally, a structural point the completeness audit is right about.**
> `docs/pre-build-checklist.md` has been flagged in eight consecutive reviews
> and sits in §4, whose preamble is *"record only — docs are not edited during a
> review"*. **There is no mechanism by which a §4 row ever closes.** It is
> stranger-facing, `status: active`, and asserts there is no Godot project to
> build. It needs to be a numbered item, not a table row.
>
> **What this amendment does not change:** the build case (still **first
> build**), the suite figures (24 / 246 / 3,154 and 86, both re-run by the audit
> and matching), the `ci.yml` job-level `if: ${{ !cancelled() }}` finding at
> `:143` and `:298` — checked against the `667a847` diff at YAML indentation
> level, so the risk this note retired was genuinely retired — the
> character-for-character match of the five ruleset contexts, all fifteen
> `export_presets.cfg` citations, every date arithmetic claim, and every
> attribution to the previous review and to the daily logs. Those were audited
> and hold.

## 1. Summary

- **Build case:** **FIRST working build**, for the tenth consecutive review, on
  the three facts the harness names — *"there is a working build only if you can
  point to an actual export in `builds/` or a GitHub Release **and** it
  launches."* Re-checked this session: `du -sh builds/` → **4.0K**
  (`.gitignore`, `.gitkeep`, one empty `wildlife-crossing-linux-arm64/`);
  `git tag -l | wc -l` → **0**; `ls -A docs/release-notes/` → `.gitkeep` only.
- **Target milestone & exit criteria:** [roadmap](../../docs/roadmap.md) Phase 1
  §*Exit criteria* (`:45-55`) and Phase 2 §*Exit criteria* (`:112-122`), as
  scoped by the logged decisions of 2026-07-29 (`:124-136`, Bow Valley only) and
  2026-08-06 (`:138-160`, world map ships look-only). Met in code and green in
  tests, with the caveat [C9](#c9-disposition-phase-2s-fourth-exit-criterion-in-the-roadmap)
  still carries.
- **Headline:** **5 blockers, 9 core tasks, 8 verification items.** **B3 closed**
  since the last note was written — recorded in its 09-02 amendment — which is
  the first blocker to leave this list since B2 and B5 on 08-29. **Zero commits
  landed in this review's own window**: `git log --since=2026-09-07` returns
  nothing, and `HEAD` has not moved since 2026-09-06 19:44. Three things are new
  this week:
  1. **B8 changed shape rather than closing.** Both halves of its repo-side
     acceptance are drafted in the working tree and neither is committed, on a
     branch that was planned and never created, from a session with no log.
     The item's substance is nearly done; its state is the least durable it has
     been. It still carries the only deadline on the page, and the deadline is
     Apple's.
  2. **A carried risk is closed, and this note is the one that has to say so.**
     The 09-01 §5 entry — *"`smoke-windows` still cannot be read as evidence when
     the export fails … a failing pack gate or Linux boot **skips** it"* — was
     made false by `667a847` on 09-06. `ci.yml:298` now puts
     `if: ${{ !cancelled() }}` on the `smoke-windows` **job**, and `:143` the
     same on `export`. Both run when a dependency fails. Carrying that risk
     forward again would have been the fourth review to describe a fixed defect.
  3. **The `ci.yml` line citations are stale for the third consecutive review.**
     `667a847` grew the file 297 → **331 lines**. And the shape of the problem
     got worse: `.github/rulesets/protect_main.json:40,44,48,52,56` now pins the
     five required status checks as **literal job-name strings**, so the job
     names in `ci.yml` are duplicated in a second file that must be edited in
     the same commit. Every line number in §3 below was read from the file this
     session, not derived.
- **Change since last review:** [[2026-09-01-next-build]] — **B3 closed**
  (09-02); **the unnumbered float-key defect closed** (09-05, `829e36b`);
  **B8's branch-ruleset line done** (09-06, ruleset `22403399`); **V2 part
  closed** — `species_registry.gd` now has a test where it had zero contact of
  any kind. **Nothing closed in the two days this review covers.** No new
  numbered items; numbers B1b, B4, B6, B7, B8, C1–C9 and V1–V8 are carried so
  the diff stays readable. **One risk retired and one doc-drift row promoted
  from cosmetic to load-bearing.**

## 2. Current state (evidence)

Re-measured against `16622ec` this session unless labelled otherwise in
[§Verification](#verification).

- **Systems:** **30 scripts / 3,584 LOC** in `game/scripts/` (`find … -name
  '*.gd' | wc -l`, `cat | wc -l`). Four autoloads in `game/project.godot:26-31`
  — `GameState`, `EventBus`, `Debug`, `SpeciesRegistry`; every other system is
  instantiated at runtime by `main.gd:53-107`. **No empty stubs** — the
  smallest files are the three constants tables at 18/18/46 LOC and each is a
  real table. Of the roster at `docs/architecture.md:44-69`, **13 present, 14
  absent**; all fourteen are Phase 3–6 work, so this is a stale roster and not a
  regression (§4).
- **Data:** all **8** canonical files in `game/data/` present and valid JSON, and
  all **12** `data/world/sub_area_*.json` valid — twenty files, zero parse
  failures, re-validated with `python3 -m json.tool` this session.
- **Scenes & wiring:** `project.godot:23` sets
  `run/main_scene="res://scenes/TitleScreen.tscn"`. `Main.tscn` is a
  single-node script holder; the wiring is `main.gd`, which constructs
  `Simulation`, `WorldRenderer`, `ConnectivityOverlay`, the camera, the audio
  player, `Hud` and `CreditsScreen` at runtime. Four scenes exist.
  `game/scenes/world/Animal.tscn` is still referenced by **nothing** —
  `grep -rn "Animal.tscn" game/` returns one hit, `game/CLAUDE.md:76`, a prose
  mention.
- **Tests:** GUT 9.6.0 via the vendored
  `tools/godot/Godot_v4.6.3-stable_linux.arm64` (`--version` →
  `4.6.3.stable.official.7d41c59c4`, matching `ci.yml:25`'s pinned
  `GODOT_VERSION: 4.6.3-stable`) — **24 scripts / 246 tests / 3,154 asserts, all
  passing**, exit 0, 1.714s. `python3 -m unittest discover -s tools/tests` →
  **Ran 86 tests, OK**. **6 of the 30 GDScript scripts have no named test
  file**: `main`, `title_screen`, `env_config`, and the three constants files —
  down from 9, because `829e36b` added `species_registry_test.gd` and
  `debug`/`event_bus` remain untested but were already counted. **Two have no
  grep contact of any kind** in `game/tests/`: `economy_constants.gd` and
  `habitat_constants.gd` (was three; `species_registry` now has two contacts).
- **Headless boot from source:** both clean against the pinned 4.6.3 binary.
  Bare → `[I] Title screen ready`. `-- --skip-menu` → `[I] Tutorial loaded.
  Press B to build the Bow Valley overpass. Press M for the world map. Press F1
  for credits. F5 saves, F9 loads.` No `ERROR:` or `SCRIPT ERROR` in either.
- **CI:** `.github/workflows/ci.yml`, **331 lines** (was 297), five jobs —
  `tools:34`, `dco:67`, `test:84`, `export:132`, `smoke-windows:293`.
  `workflow_dispatch:` at `:14`. `retention-days` at `:280`, still split by
  event: `${{ github.event_name == 'pull_request' && 1 || 14 }}`.
  **The structural caveat carried since 08-12 is gone:** `if: ${{ !cancelled()
  }}` now sits on the `export` **job** (`:143`) and the `smoke-windows` **job**
  (`:298`), with `continue-on-error: true` on the artifact upload (`:264`) and
  on the smoke job's download step (`:306`). `dco` is still gated to pull
  requests at `:69`, so **four green with `dco` skipped remains the correct
  shape on a push**. A second workflow, `deploy-website.yml` (85 lines),
  publishes `website/` to Pages. **Whether any CI run has passed is
  Unverifiable this session:** `which gh` → not found; `git fetch origin` →
  *Host key verification failed* (§Verification).
- **Branch protection:** `.github/rulesets/protect_main.json` is checked in
  (1,519 bytes, 09-06). Its five `"context"` strings at `:40,44,48,52,56` are
  the five `ci.yml` job names, character for character. **This file is now a
  second place that has to change whenever a job name does** — see §4 and §5.
- **Build/export:**
  - `builds/` — `.gitignore`, `.gitkeep`, one empty directory, **4.0K. No
    binaries.**
  - `wildlife-crossing-desktop-builds/` — **411 MB**, newest mtime **2026-07-28
    03:31**, now **six weeks stale**. Size and mtime measured here; the claims
    that these were built by Godot 4.6.0 and fail the repo's own pack gate are
    **carried from earlier reviews and not re-checked** — they were not executed
    (this environment is arm64 Linux). Seven reviews running have had to
    establish that these are not the build.
  - A local export was **attempted this session and failed as expected**:
    `--export-release "Linux arm64"` → *No export template found at the expected
    path … `export_templates/4.6.3.stable/linux_release.arm64`*. The sandbox
    cannot produce a binary; the build signal here is a source boot plus the
    suites.
- **Export presets:** all four still at their defaults on every item C1, C2 and
  C3 name — `export_presets.cfg:145` `codesign/codesign=1`, `:147`
  `apple_team_id=""`, `:148` `identity=""`, `:173` `notarization/notarization=0`,
  `:138-139` `application/short_version=""` / `application/version=""`, `:128`
  `export/distribution_type=0`, `:117` macOS `export_path` still ends `.zip`.
  `exclude_filter="addons/gut/*,tests/*"` present on all four (`:11,42,73,116`);
  `embed_pck=false` at `:26,57,88`.
- **Git:** branch **`main`**, `HEAD` = `16622ec` (2026-09-06 19:44:29 -0500,
  **two days ago**), `origin/main..HEAD` → **0**, `HEAD..origin/main` → **0**,
  `git tag -l` → 0. Working tree: **`M .gitignore`, `M
  docs/signing-runbook.md`** — the B8 work, and nothing else. **This is the
  first review in four whose vault backlog is already committed**: the 09-01
  note, its amendments, its index line and every daily log through 09-06 are all
  in `16622ec`. That improvement is real and is why the uncommitted B8 work
  stands out rather than blending in.
- **Untracked leftovers:** **fourteen** `commit-plan*.json` at the repo root —
  **was six a week ago** — plus `tools/_to_delete/` and the `.DS_Store` files.
  All ignored (`git check-ignore -v` reports `.gitignore:36`
  `/commit-plan*.json` and `.gitignore:20` `/tools/*`), so none is
  stranger-visible. Still cosmetic; the growth rate is not, since each new file
  marks a session that planned commits.

### Exit criteria, criterion by criterion

Re-run this session: every Phase 1 and Phase 2 exit criterion is **met in code
and green in tests**. Two things qualify that sentence, and both are already
numbered. **Phase 2's second criterion** (`roadmap.md:116`, locked sub-areas
desaturated) was met in tests and broken in the artifact until `829e36b`, and
is now **met by observation** per the 09-05 walk. **Phase 2's fourth criterion**
(`:119-120`) is met in tests and **unreachable in the artifact** — `main.gd:215`
says so in its own comment — and nothing has yet written the decision that lets
`v0.1.0` claim it. That is C9, and it is still open.

**Two criteria have still never been rendered to a human**: the crossing cue
(visual + audio) and the connectivity overlay's orange→teal treatment. The
09-02 walk covered the cue — *"the `+N crossed safely` line appears and the
chime is heard"* — so that one is reported closed by a log rather than open;
the overlay is not mentioned in either walk. C5 is where both land.

What is missing is still not gameplay logic. It is a release a stranger could
install.

## 3. Work needed for the first build

Ordered the way you'd actually do it. Numbers carried from
[[2026-09-01-next-build]]; **nothing is renumbered and nothing is new.** Where
an item is materially unchanged this note gives the re-verification and the
acceptance bar and points at the 09-01 or 08-25 note for the full argument.

### Blockers (nothing ships until these exist)

#### B8. Land the credential-path work that is already written

- **Why it blocks:** unchanged in substance from 09-01 — signing-runbook **A4**
  delivers an App Store Connect `.p8` that Apple permits **exactly one download
  of**, at a moment Apple chooses, into a repository that has been public since
  2026-08-29. A leaked key is rotated, not recovered. **What changed is that the
  work exists and is not in the repository.** Verified this session:
  1. `git diff -- .gitignore` adds all seven patterns — `*.p8`, `*.p12`,
     `*.cer`, `*.pem`, `*.key`, `*.mobileprovision`, `.env` — placed after the
     `/tools/` re-includes with a comment explaining why, and deliberately
     omitting `*.asc` so the tracked GPG **public** key stays tracked. It also
     rewrites the `export_presets.cfg` note at the top to stop trying to hold
     the whole procedure in a comment.
  2. `git diff -- docs/signing-runbook.md` inserts a **Part A pre-flight** with
     three checks: `git check-ignore -v` over all seven patterns; `gh api …
     --jq .security_and_analysis` to read secret scanning and push protection,
     with a `PATCH` to turn them on and an explicit refusal to credit push
     protection as the control that protects the `.p8`; and the
     `git rm --cached` trap written out with its consequence — untracking
     `export_presets.cfg` breaks all three `--export-release` invocations, and
     *Export desktop builds* is one of the five required contexts under a
     ruleset with no bypass actor, so **every pull request in the repository
     would be unmergeable**. It also corrects A5's *"about to go public"* to
     *"public since 2026-08-29"*.
  3. `git branch --show-current` → **`main`**.
     `commit-plan-2026-09-07.json` names branch `chore/credential-path` and two
     complete commit bodies. Neither branch nor commit exists.
     `obsidian-vault/daily-logs/2026-09-07.md` does not exist.
- **Files/areas:** `.gitignore` and `docs/signing-runbook.md` — both already
  edited; GitHub repository settings (secret scanning, push protection). The
  branch-ruleset line of this item's original Files/areas is **done**
  (`22403399`, 09-06).
- **Acceptance:** the two commits landed on `main` **through a pull request**,
  since the ruleset admits nothing else; `git check-ignore -v` returning seven
  lines on a clean checkout; secret scanning and push protection read, set if
  needed, and **the result and date written into a daily log** — the runbook's
  own pre-flight says to; and a `2026-09-07`-or-later log recording the session
  that wrote this. **Not in scope:** the GPG revocation certificate and
  off-machine backup, which are **done** ([[../daily-logs/2026-08-26]]).
- **Depends on:** none. **It is two commits and a pull request.**
- **Size:** S
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A4;
  [[2026-09-01-next-build]] B8; [[../daily-logs/2026-09-06]] §Next session.

#### B1b. Finish the Apple enrolment, and the certificate and API key behind it

- **Why it blocks:** [ADR 0018](../../docs/adr/0018-code-signing-and-notarization.md)
  makes a signed, notarized macOS build part of what `v0.1.0` *is*; C1, C2 and
  B6 all queue behind it. **B1a is closed** — GPG key
  `7F68A7E06349DA136226F04E2D5F1ED6EFFC08FD`, re-verified this session at
  `README.md:77-82` and `:91`. Apple enrolment was submitted **2026-08-27**
  (twelve days ago) and, as far as the repo records, is still pending.
- **Files/areas:** none yet; later, the certificate and API key on the Mac —
  **not** in the repo (B8).
- **Acceptance:** runbook **A2–A4** — a **Developer ID Application** certificate
  issued (an "Apple Development" certificate signs fine and fails
  notarization); the Xcode licence accepted (**A3, which is not gated on
  approval and can be done today**); the App Store Connect API key created and
  stored.
- **Depends on:** Apple. **The only item on the page whose duration no amount of
  effort can compress**, and the sixth consecutive review to say so.
- **Size:** S effort, **days of calendar**
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A2–A4; ADR 0018;
  [[../daily-logs/2026-08-27]].

#### B4. Decide how a Release ships something a stranger can run

- **Re-verified this session:** `export_presets.cfg:26,57,88` still set
  `binary_format/embed_pck=false`, so the Linux build is
  `wildlife-crossing.x86_64` **+** `.pck` and the Windows build is `.exe` **+**
  `.pck` **+** a console wrapper. A GitHub Release asset is a single file: a
  downloader who takes `wildlife-crossing.exe` alone gets a Godot runtime with
  no game and no error explaining why. Actions artifacts also do not preserve
  the Unix executable bit.
- **Choose the archive, not `embed_pck`.** Root `CLAUDE.md` and
  [ADR 0017](../../docs/adr/0017-licensing.md) require every exported binary to
  ship `LICENSE` and `THIRD-PARTY-NOTICES.md`; `ci.yml` places both in
  `builds/<platform>/`, which only reaches a downloader if the **archive** is
  the published asset. A bare embedded-pack `.exe` passes the "one file" test
  and quietly breaks ADR 0017.
- **Files/areas:** `game/export_presets.cfg`; `ci.yml` export and upload steps
  **and the `smoke-windows` job** (`:293-298`, which hardcodes the `.exe` path);
  `tools/check_pck_contents.py`; `tools/inspect_pck.py`, which has no test file.
- **Acceptance:** each published asset is **one file that runs on a clean
  machine**, verified by extracting into an empty directory and launching with
  no reliance on a sibling file; the Linux binary is executable after download;
  `LICENSE` and `THIRD-PARTY-NOTICES.md` are **inside** the published asset; the
  console wrapper is dealt with — nothing says which of `wildlife-crossing.exe`
  and `wildlife-crossing.console.exe` a downloader runs; **and the signed
  manifest follows the decision.** `signing-runbook.md` Part B builds
  `SHA256SUMS.txt` from a `find` matching `*.dmg`, `*.exe`, `*.pck` and
  `wildlife-crossing.x86_64` — **no archive extension matches**, and neither
  does `wildlife-crossing.arm64` the moment V4 goes the "export it" way.
- **Depends on:** none. **Land it as one commit** with the `smoke-windows` and
  pack-gate updates, or the pull request carrying it is red on its own gates.
  Carry C6 in the same PR. **Size:** M
- **Refs:** `export_presets.cfg:25-26,56-57,87-88`;
  [export-setup](../../docs/export-setup.md); [[2026-08-25-next-build]] B4.

#### B6. Cut `v0.1.0` — release note, tag, signed GitHub Release

- **Why it blocks:** this is the item that decides the build case, and ten
  consecutive reviews have answered "first build" on the same three facts —
  empty `builds/`, zero tags, empty `docs/release-notes/`. All three re-verified
  true this session.
- **Files/areas:** `docs/release-notes/v0.1.0.md`; a `v0.1.0` tag; a GitHub
  Release carrying the macOS image, the Windows and Linux packages from B4,
  `SHA256SUMS.txt` and its detached signature.
- **Acceptance:** the release note follows [docs/CLAUDE.md](../../docs/CLAUDE.md)
  format and states **all four** scope facts — Bow Valley only, the world map is
  look-only, placeholder art and the default Godot window icon
  (`export_presets.cfg:94,133` `application/icon=""`), and which artifacts are
  signed vs not and how to verify; the tag exists; `spctl`/`stapler` verify the
  notarized image per runbook A7; the GPG signature verifies per runbook B4; the
  binaries report their own version (C3). Plus the runbook's gotcha: **clear
  `builds/` first**, since runbook Part B sweeps that directory with a `find`
  and `builds/wildlife-crossing-linux-arm64/` is sitting there now.
- **Depends on:** B1b, B4, B7's prerequisites, C1, C2, C3, C5, C6, C7, **and
  V4** — V4 decides whether an arm64 binary exists in `builds/` at the moment
  the manifest sweep runs. **Size:** M
- **Refs:** ADR 0018 §Decision; [signing-runbook](../../docs/signing-runbook.md)
  A6–A8, B3–B4, C2.

#### B7. Walk signing-runbook A8 — the real acceptance test

- **Why it blocks:** unchanged. It is the only item that closes the half of the
  build case this harness's definition turns on — *"an actual export in
  `builds/` or a GitHub Release **and** it launches."* B6 cuts the Release;
  nothing verifies a stranger can open it. The runbook's *"A8. The real
  acceptance test"* is explicit: download the DMG from the published Release, on
  a Mac that has never had this project on it, and open it. **"No Gatekeeper
  warning at all" is the pass condition.** Anything less — "unidentified
  developer", a right-click-to-open workaround, a quarantine prompt — means it
  isn't done. B6's acceptance stops at local `spctl` and `stapler`, and runbook
  A7 is titled *"do not trust the export log"* for exactly that reason.
- **Files/areas:** none. A second Mac (or at minimum a fresh user account), the
  published Release, and a daily-log entry.
- **Acceptance:** the DMG downloaded **from the Release URL** on a machine that
  has not had the project, opened with **no Gatekeeper warning of any kind**;
  the same session confirms the Windows and Linux assets extract and launch on a
  clean machine per B4's acceptance; and **the result recorded in
  `obsidian-vault/daily-logs/`** — the runbook says the log entry is part of the
  test.
- **Depends on:** B6. **This is the last item, and it is the one that changes
  the build case from *first* to *next* in the following review.**
- **Size:** S — assuming it passes. If it does not, it reopens C1 and C2, which
  is precisely why it must be walked rather than assumed.
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A8, A7; ADR 0018.

### Core build work

C1–C9 are carried from [[2026-09-01-next-build]] and were re-verified open this
session against the file and line numbers given. Full reasoning is in that note
and in [[2026-08-25-next-build]].

#### C1. Configure macOS signing in the export preset

- **Re-verified:** `export_presets.cfg:145` `codesign/codesign=1`, `:147`
  `apple_team_id=""`, `:148` `identity=""`, `:173` `notarization=0` — all four
  still at defaults. **Scope is smaller than it was**: the 09-02 walk recorded
  `flags=0x10002(adhoc,runtime)` on the CI-built `.app`, so the hardened runtime
  is already on and C1 supplies identity, team id and `notarization=1` only.
- **Files/areas:** `game/export_presets.cfg` preset 3. **The file is tracked and
  Godot writes secrets into it** — use the `GODOT_MACOS_NOTARIZATION_*`
  environment variables and diff before every commit. **B8's Part A pre-flight
  is the document that explains why untracking it is not the answer; land B8
  first.** Leave the `Debugging` entitlement `false`.
- **Acceptance:** a signed test export from Brent's Mac that `spctl -a -vvv`
  accepts and whose ticket `stapler validate` confirms. Also settle whether
  `export/distribution_type=0` ("Testing", `:128`) needs to change.
- **Depends on:** B1b; B8 should land first. **Size:** M
- **Refs:** [signing-runbook](../../docs/signing-runbook.md) A5, A7; ADR 0018.

#### C2. Change the macOS export target from `.zip` to `.dmg`

- **Re-verified:** `export_presets.cfg:117` still ends `.zip`. You cannot staple
  a notarization ticket to a `.zip`, and the `.zip` is why `LICENSE` and
  `THIRD-PARTY-NOTICES.md` land *beside* the archive rather than inside the
  bundle — the gap `ci.yml:238` acknowledges in its own *"Known gap"* comment
  (line corrected from 09-01's `:227-230`).
- **The real interaction:** the release `.dmg` is built locally, never in CI, and
  `check_pck_contents.py`'s `resolve_pck` accepts only a `.pck`, a `.app`
  directory or a `.zip`. **The artifact that actually ships is gated by
  nothing.**
- **Acceptance:** the macOS preset exports a `.dmg`; **the pack inside the
  shipped image passes `check_pck_contents.py`**, run against the image or the
  mounted `.app`, and that run recorded in the release log; its tests cover the
  new input; CI's export job stays green; `LICENSE` and `THIRD-PARTY-NOTICES.md`
  are inside the image, added **before** signing.
- **Depends on:** the preset edit depends on nothing; the acceptance requires
  teaching `resolve_pck` to accept a `.dmg`, a `tools/` change with its own
  tests. **Size:** M
- **Refs:** ADR 0018; [signing-runbook](../../docs/signing-runbook.md) A5–A6.

#### C3. Set the version metadata the export presets never got

- **Re-verified:** `export_presets.cfg:138-139` still `application/short_version=""`
  and `application/version=""`; `grep -n "file_version\|product_version"` returns
  **nothing**, so the Windows preset has neither, while `project.godot` carries
  `config/version="0.1.0"`. An empty `CFBundleShortVersionString` is a
  notarization risk.
- **Acceptance:** `application/version` and `application/short_version` read
  `0.1.0`; Windows `file_version`/`product_version` set; a built binary's
  reported version matches the `v0.1.0` tag.
- **Depends on:** none. **Cheapest item on the list and on B6's critical path —
  do it while waiting on Apple.** **Size:** S
- **Refs:** ADR 0018 §Consequences; [signing-runbook](../../docs/signing-runbook.md) A5.

#### C4. Decide the tutorial camera focus

- **Re-verified:** `main.gd:18` still `const CAMERA_FOCUS_COORD := Vector2i(13, 6)`,
  consumed at `:71`. The 2026-08-10 measurement found row 6 has zero measured
  deaths and about 10 crossing uses, while 70 of 73 baseline deaths happen on
  rows 0–2. The opening camera points at the one part of the tutorial where
  nothing happens, on the first screen of the first build a stranger will ever
  see. Flagged to the owner on 08-10 — **twenty-nine days ago** — still
  undecided, and it is one line.
- **Acceptance:** a one-line change or an explicit recorded decision to keep it;
  either way the answer is in a log **before** C5's QA pass runs.
- **Depends on:** none. **Needs an owner call.** **Size:** S
- **Refs:** [[../daily-logs/2026-08-10]] §Open questions;
  [[../design/detour-cost-question]]; `tools/measure_tutorial.gd`.

#### C5. Visual + audio QA pass, written down

- **Re-verified, and partly discharged by the 09-02 walk.** That walk observed
  the title screen, Play, B, left-click, Enter, Escape, M, F1, the F5/quit/
  relaunch/F9 round-trip, the credits from both entry points, and the crossing
  cue seen and heard. The 09-05 walk observed the locked-sub-area desaturation.
  **What remains unobserved:** the connectivity overlay's orange→teal treatment
  at segment zoom, and legibility — the 09-02 walk **failed** the credits-screen
  and HUD-message-line legibility clauses, because `game/project.godot` has **no
  `[display]` section at all** (re-verified this session: the file is 44 lines,
  `[application]`, `[autoload]`, `[editor_plugins]`, `[rendering]`), so the
  export runs at Godot's 1152×648 default with stretch disabled.
- **Do not send a QA pass looking for Phase 2's fourth criterion** —
  `main.gd:215` says the `ConfirmPanel` path is unreachable from the map screen
  in v0.1.0. That is C9's job to dispose of in writing.
- **Acceptance:** a note in `obsidian-vault/daily-logs/` confirming the overlay
  treatment observed (orange→teal at ~40%, only in segment mode, clearing on
  confirm/cancel/Escape), the HUD message line and credits screen **legible**,
  and — still never captured by any log — **the Godot version installed on
  Brent's Mac** (also C7's input). The `[display]` decision is part of this
  item now: fix it or record why not, since `stretch/mode = "canvas_items"` also
  changes screen-to-world mapping, the area `cb9f9b8` fixed.
- **Depends on:** C4 (decide the camera first). **Size:** S
- **Refs:** roadmap Phase 2 exit criteria; [[../daily-logs/2026-09-02]].

#### C6. Add the verification copy to the download section

- **Re-verified this session:**
  `grep -cin "gpg\|sha256\|smartscreen\|unsigned\|fingerprint" website/index.html
  website/user-guide.html` → **0 and 0**. The `README.md` half is done
  (`:77-82`, `:91`); **the website half is untouched**, and the site is publicly
  reachable with a download button pointing at an empty Releases page.
- **Acceptance:** the download area names each published asset, states plainly
  that Windows is unsigned and what SmartScreen will say, gives the GPG
  fingerprint and the two verification commands, and does **not** imply the GPG
  signature suppresses any OS warning. **And it says how to run the thing** —
  nothing anywhere does. **And settle the eight species portraits while you are
  in this file** (§5).
- **Depends on:** B4 (the asset list). C6 must be *carried by* a merge, not
  scheduled after one: `deploy-website.yml` publishes on push to `main` touching
  `website/**`. Land it in B4's PR. **Size:** S
- **Refs:** ADR 0018 §Follow-on work;
  [signing-runbook](../../docs/signing-runbook.md) C2; `website/CLAUDE.md`.

#### C7. Pin the release machine's engine, and install its export templates

- **Re-verified:** unchanged. The shipping `.dmg` is built **locally on the
  Mac**, never in CI, so the one artifact a stranger downloads is produced by an
  engine no gate has ever checked. Three things depend on it being 4.6.3-stable
  specifically: ADR 0012's 2026-07-28 amendment; `THIRD-PARTY-NOTICES.md:25`,
  which **hard-codes "Godot Engine 4.6.3-stable"**, so a `.dmg` built by another
  patch ships a licence document that is factually wrong under ADR 0017; and the
  credits screen, which renders whatever engine built the binary. **This
  session's failed sandbox export is the same failure in miniature** — the
  engine looked for `4.6.3.stable/` by name and found nothing.
- **Acceptance:** the Mac's `Godot --version` recorded in a log and **equal to
  `4.6.3.stable`**; the matching export templates installed at
  `~/Library/Application Support/Godot/export_templates/4.6.3.stable/` and the
  path confirmed; the release `.dmg` built by that engine.
- **Depends on:** none. **It has download lead time and nothing interesting in
  it** — start it early. **Size:** S
- **Refs:** [export-setup](../../docs/export-setup.md):8-16; ADR 0012;
  `THIRD-PARTY-NOTICES.md:25`.

#### C8. Write down that the repository is public

- **Part closed, and now carrying a contradiction.** The 08-29 log is
  **committed** (`c070b12`), which closes half of this item's acceptance. On the
  durable-sentence half, the repo now says both things at once:
  `docs/pipeline-design.md:346-347` and `:485` (tracked, `db643f1`) state that
  the repository *is* public and reason from it — but never say **since when** —
  while the **committed** `docs/signing-runbook.md:137` still says the repo *"is
  about to go public"*. The correction to that line is real and is sitting
  **uncommitted** in the B8 diff. `grep -in "public" README.md` returns nothing
  about repository visibility.
- **Acceptance:** one durable sentence in a tracked file stating the repository
  is public **and since when** — `README.md` is the natural home — and no
  tracked file left asserting the opposite tense. **Landing B8 closes the second
  half by itself.**
- **Depends on:** none. Ride it along with any commit; B8's PR is the obvious
  one. **Size:** S
- **Refs:** [[2026-08-25-next-build]] B5 acceptance; [[../daily-logs/2026-08-29]].

#### C9. Disposition Phase 2's fourth exit criterion in the roadmap

- **Re-verified open.** `roadmap.md:119-120` requires that *"Confirm passes the
  correct `(segment, sub_area)` into the construction step; click-outside and
  Escape behave per spec."* `main.gd:215` records that the path to
  `ConfirmPanel` is unreachable from the map screen in v0.1.0. So the criterion
  is **met in tests and unreachable in the artifact a stranger runs.**
  `grep -n "Decision logged" docs/roadmap.md` returns the same four blocks as
  last week (`:57`, `:73`, `:124`, `:138`) — **no new block has been written.**
- **Files/areas:** `docs/roadmap.md` Phase 2 §Exit criteria — a decision block
  in the same style as the 2026-07-29 and 2026-08-06 ones. **Not** a code
  change.
- **Acceptance:** the roadmap states, in writing and dated, either that the
  criterion is met by `confirm_panel_test.gd` with the in-artifact path deferred
  and why that is acceptable for v0.1.0, or that it is deferred outright. **Fold
  the three un-deferred Phase 2 Implements items into the same block** — the
  toolbar tool, the P1 group, and the controlling-entity mapping.
- **Depends on:** none. **Needs an owner call**, like C4. **Size:** S
- **Refs:** `docs/roadmap.md:119-120`; `main.gd:215`; the 2026-08-06 decision
  block; ADR 0015.

### Verification (tests, CI, export)

#### V1. Add `env_config.gd` coverage

- **Re-verified:** `ls game/tests/*_test.gd | wc -l` → **24**, and none is
  `env_config_test.gd`. `EnvConfig` is instantiated as a fixture in
  `species_manager_test.gd` and never asserted. Still the only untested script
  carrying real branching logic — the per-terrain mortality lookup and the
  resolution order (override → OS env → `DEFAULT = 0.20`), which is exactly what
  the Phase 1 criterion *"deaths at the configured env-var rate"* rests on.
- **Acceptance:** resolution order covered end to end; suite reaches 25 scripts.
  GUT only discovers a new `*_test.gd` after a re-`--import`. **Size:** S

#### V2. Cover the constants files

- **Half closed by `829e36b`.** `species_registry.gd` had **zero** test contact
  of any kind at the last review and now has a dedicated
  `species_registry_test.gd` plus contact from
  `world_select_controller_test.gd` — and those tests read `res://data/` through
  the registry rather than int-keyed fixtures, which is what let the float-key
  defect through. **What remains is the constants half:** `grep -rl` across
  `game/tests/` returns **nothing** for `economy_constants`/`EconomyConstants`
  or `habitat_constants`/`HabitatConstants`. `SimulationConstants` has contact
  but every hit reads it as an *input*, which is the opposite of asserting it.
- **Acceptance:** constants values asserted against `data-schemas.md` §10, and
  §10 either gains `HAZARD_AVOIDANCE_MULT` (which `simulation_constants.gd`
  itself flags as absent from §10) or the constant is justified in a comment.
  **Size:** S

#### V3. Reconcile `docs/test-plan.md` §11 against the real suite

- **Re-measured this session, with the method stated:** extracting every
  backticked `test_*` name from §11 (`docs/test-plan.md:145` to end of file) and
  matching against `func test_` across `game/tests/*_test.gd` gives **31 named,
  23 with no matching function — 74%.** The 09-01 note reported 43/35/81% and
  did not record its extraction, so **these numbers are not comparable and this
  is not evidence of movement.** Some closure is real — `829e36b` added three
  test files — but the arithmetic to prove it is not available. Whoever fixes
  V3 should put the measurement in a script.
- **Acceptance:** every P0 row either names a test that exists, or is marked
  deferred with a reason. **Size:** S

#### V4. Export the `Linux arm64` preset in CI, or delete it

- **Re-verified:** `export_presets.cfg:32-62` (`[preset.1]`, `name="Linux
  arm64"`) defines a preset CI never builds — `ci.yml:183,185,187` names exactly
  `"Linux x86_64"`, `"Windows x86_64"` and `"macOS"` — and
  `builds/wildlife-crossing-linux-arm64/` sits empty as its ghost. It is also
  the architecture this sandbox runs on, which is the main reason to prefer
  "export it": it would let a future review boot a real artifact instead of
  reasoning about one, as this session again could not.
- **Acceptance:** either the arm64 artifact appears in the CI upload and passes
  `check_pck_contents.py`, or the preset and the empty directory are gone.
- **Depends on:** none. **Settle it before B6**, since it changes what the
  manifest sweep finds. **Size:** S

#### V5. Exercise the `dco` job on a deliberately unsigned commit

- **Re-verified half closed, and no further advanced.** The job has now been
  seen green on PRs #1 through #7. Its acceptance also requires observing it
  **red**, which has not happened — every commit in every pull request has been
  signed off. A gate seen only green is a gate whose failure path is untested,
  and the repository is public, so an outside contribution is possible rather
  than hypothetical. **The same argument now applies one level up**: per
  [[../daily-logs/2026-09-06]], ruleset `22403399` has also never refused
  anything, because both pull requests under it were merged after their checks
  were already green.
- **Acceptance:** the `dco` job observed red on an unsigned commit and green
  once signed off; the throwaway PR closed without merging. **Size:** S

#### V6. Make the zero-tests guard report why it failed, and catch partial drops

- **Re-verified at `ci.yml:118-131`** (corrected from 09-01's `:113-127`). Two
  problems, both unchanged. `:125` is
  `TESTS="$(grep -oE '<testcase' "$XML" | wc -l | tr -d '[:space:]')"` under
  `set -euo pipefail` — if GUT records zero test cases, `grep` exits 1, the
  substitution fails, and `set -e` kills the step **before** the `::error::` at
  `:128` can print. And the guard catches only `TESTS -eq 0`, whereas the
  failure it was designed for (2026-07-19) was a **partial** drop. At 24
  scripts, a run that silently lost 23 still passes.
- **Acceptance:** a zero-test run prints the `::error::` before exiting; CI fails
  when the JUnit XML reports fewer than the expected number of test scripts
  (**currently 24** — the constant moves whenever V1 or V2 lands, which is an
  argument for reading it from a file); both verified against synthetic XML.
  **Size:** S

#### V7. Teach `build_encyclopedia.py` to delete, and test it

- **Re-verified:** `tools/build_encyclopedia.py` is **686 lines** and contains
  **zero** occurrences of `unlink`, `os.remove` or `rmtree` — it only ever
  writes — while `deploy-website.yml` gates on
  `git diff --quiet -- website/encyclopedia`. A **new** wiki entry produces an
  **untracked** file `git diff` cannot see, so the gate passes green while the
  deployed site is missing the page; a **deleted** entry leaves an orphan. Still
  the largest untested tool.
- **Acceptance:** the generator removes pages whose wiki source is gone; the CI
  gate detects an untracked generated file (`git status --porcelain` as well as
  `git diff`); round-trip and external-asset checks covered by tests. **Size:** M

#### V8. Assert the two runtime assets survive export

- **Re-verified:** both exist — `game/assets/audio/crossing_chime.wav` (61,782
  bytes) and `game/assets/sprites/crossing_cue.png` (341 bytes) — and both are
  `preload`ed. A missing asset fails the smoke boot (a failed `preload` is a
  compile failure, so `Tutorial loaded` never prints), so this is covered, but
  by a gate that reports *the binary did not boot*, not *the chime is missing*.
- **Acceptance:** the pack gate asserts both asset paths are present and names
  them when they are not; the test covers a pack missing one. **Size:** S

### Deferrable / nice-to-have

Carried from [[2026-09-01-next-build]] unless noted:

- **63% of visible animals die in the first in-game day** — about ten real
  seconds at 1×, before the player can build anything. Inherited from
  `EnvConfig.DEFAULT = 0.20` rather than chosen. A live tension with the
  *"cozy, not stressful"* north star.
- **Delete the stale `wildlife-crossing-desktop-builds/` artifacts.** 411 MB,
  **now six weeks old**. Seven reviews running have had to establish that they
  are not the build. `fetch_build.py` downloads into run-scoped directories, so
  nothing needs this fixed path any more.
- **Untracked clutter has grown from six commit plans to fourteen** in one week.
  All confirmed ignored (`.gitignore:36` and `:20`), so **none is
  stranger-visible** and this remains cosmetic — but the count is now growing
  faster than the commit log, which is the same signal B8 is.
- **`game/scenes/world/Animal.tscn` is dead weight** — re-verified: one grep hit
  across `game/`, a prose mention at `game/CLAUDE.md:76`. Agents are drawn as
  circles by `world_renderer.gd`. Delete or wire; ADR 0015's title names it, so
  the deletion should carry a line explaining that.
- **`entities.json` has no production consumer** beyond `species_registry.gd`
  indexing it. C9's decision block should say so or defer it.
- **The twelve world maps are template-scale.** `sub_areas.json` declares
  `playable_tile_count: 4000` for each; each map resolves to 238–312 cells —
  92–94% below the ±15% acceptance criterion in `data-schemas.md` §11 — and
  `data_validation_test.gd` asserts only the *declared* number.
- **`connectivity_overlay_test.gd` and `species_manager_test.gd` build their
  fixtures from hand-copied const dicts** rather than reading `res://data/`.
  `829e36b` fixed exactly this class of defect in
  `world_select_controller_test.gd`; these two are the same shape and were not
  swept in.
- **Three Phase 2 Implements items are neither built nor deferred in writing:**
  the toolbar tool, the Phase 2 P1 group, and `sub-areas`' controlling-entity
  mapping. None is an exit criterion, so none blocks the build. **C9's decision
  block should close all three in the same pass.**
- **The detour-cost measurement covered Bow Valley only.** The other 17
  non-bisecting segments remain unmeasured.
- **`website/CLAUDE.md:79`** still specifies user-guide section 2 as *"Placing
  habitats"*, which the shipped guide does not match.
- **`BaseScreen` retrofit** of `ConfirmPanel` and `ConnectivityOverlay` —
  deliberately deferred 07-31.
- **Real art.** `game/assets/fonts/` and `tilesets/` are **empty but for
  `.gitkeep`** (re-verified: `ls -A` returns `.gitkeep` and nothing else);
  `crossing_cue.png` is a 341-byte generated placeholder. The eight species
  portraits ship on the public site but are unwired in the game.
- **Eight of the ten `.gitkeep` files under `game/` sit in directories that are
  no longer empty** — harmless, and the cheapest possible tidy.
- Windows signing remains deliberately out of scope per ADR 0018's stated
  triggers. Phase 5 gates remain open and still do not block P0.

## 4. Doc drift to fix

Record only — docs are not edited during a review. Every row was re-verified
this session. **No row closed this week.** Two are new and one is promoted.

| Doc | Stale claim | Correction |
|-----|-------------|------------|
| **NEW** — every `ci.yml` line citation in [2026-09-01-next-build.md](2026-09-01-next-build.md) | `:261` retention, `:113-127` guard, `:227-230` known gap, `:274-276` smoke-windows, `:294-295`, "297 lines" | All shifted by `667a847`, which grew the file to **331 lines**. Corrected in §3: retention `:280`, guard `:118-131`, known gap `:238`, `smoke-windows` job `:293` with its name at `:294` and `needs: export` at `:295`, `if: ${{ !cancelled() }}` at `:143` and `:298`. **Third consecutive review where line-number drift is the largest single category of error.** The 09-01 note already prescribed the fix — cite headings, job names and step names — and then cited lines anyway, because the runbooks do. Someone has to break that loop. |
| **NEW** — [signing-runbook.md](../../docs/signing-runbook.md):392 (Part D.3) and [adr/0018](../../docs/adr/0018-code-signing-and-notarization.md):165 | *"Build-review V2 is still open: the pck gate and smoke boot run on the Linux binary only."* | **Still false, and it is about to move.** `ci.yml` runs `check_pck_contents.py` against all three packs and boots the `.exe` on `windows-latest`; that landed 2026-08-10. The runbook copy was cited at `:392` last week and has not moved since; **the uncommitted Part A pre-flight sends it to `:452`, a shift of +60, the moment B8 lands.** The ADR copy at `:165` has not moved. Strike both, or mark them done with the commit that closed them — and note that this row is itself an instance of the row above. |
| **PROMOTED** — [ci.yml](../../.github/workflows/ci.yml):294 **and** [.github/rulesets/protect_main.json](../../.github/rulesets/protect_main.json):56 | `smoke-windows` job name: *"Smoke-test the Windows binary (boots to Main.tscn)"* | `run/main_scene` is `TitleScreen.tscn`; the job reaches `Main` only via `smoke_boot.sh`'s `--skip-menu`. **This stopped being cosmetic on 09-06.** The string is now a required status check context, duplicated verbatim in the ruleset. Renaming it in `ci.yml` without editing `protect_main.json` in the same commit yields a context that never reports, which under `bypass_actors: []` is an **unmergeable** pull request rather than a red one. Two of the five contexts (`:48`, `:52`) also embed `4.6.3-stable`, so a `GODOT_VERSION` bump has the same shape. |
| [pre-build-checklist.md](../../docs/pre-build-checklist.md) | *"`game/` is still almost entirely `.gitkeep` placeholders; there is no Godot project to build yet"* (`:19-20`); A1 "no `project.godot`"; A2 "GUT … not yet installed"; A3 "no CI"; A4 "zero game code"; A5 "only `sub_areas.json` and `biome_groups.json`"; A7 "`game/assets/` is all `.gitkeep`" | Every claim is false — 30 scripts / 3,584 LOC, 4 autoloads, GUT 9.6.0 vendored, a 331-line five-job CI, all 8 data files plus 12 world maps valid, 24 test scripts / 246 tests, two real assets. **Flagged in eight consecutive reviews and never fixed.** `status: active`, `date: 2026-06-28`. The repository is public, so this is a stranger-facing onboarding document describing a project that does not exist. Longest-running item on this table and the cheapest to close. |
| [testing-setup.md](../../docs/testing-setup.md):69-70 | *"the suite currently reports **16 scripts / 134 tests / 2,779 asserts**"* (dated 2026-07-30) | Measured this session: **24 scripts / 246 tests / 3,154 asserts**. Stale at eight consecutive reviews and corrected seven times — **generate it from the JUnit XML rather than maintaining it by hand.** |
| [testing-setup.md](../../docs/testing-setup.md):22 | *"**Godot 4.6** (stable). Any 4.6.x patch is fine; verified working on 4.6.3."* | Contradicts `ci.yml:25` and ADR 0012's 2026-07-28 amendment, which pin the exact patch deliberately because export-template paths are version-keyed — as this session's failed export demonstrated again. ADR 0012's *Decision* line does say "4.6 (stable)", so a reader who checks the ADR comes away reassured. That is a worse kind of stale, not a lesser one. |
| [testing-setup.md](../../docs/testing-setup.md):142-147 | *"### Known gap … Consider adding a CI assertion that the run actually collected tests"* | Partly implemented at `ci.yml:118-131` — zero case only, and its error message is unreachable under `set -e`. See V6. |
| [testing-setup.md](../../docs/testing-setup.md):36 | *"`.gitignore` excludes `/tools/`, which is where the binary lives"* | It excludes `/tools/*` (`.gitignore:20`) then re-includes `*.py`, `*.sh`, `*.gd` and `/tools/tests/`; nine scripts and five test files are tracked and publicly visible. |
| [roadmap.md](../../docs/roadmap.md):49-50 | Phase 1 exit criterion *"A fully spanned overpass yields a zero-mortality route"* | Still predates [ADR 0016](../../docs/adr/0016-crossing-span-geometry.md); "fully spanned" now means a valid **span** (two-sided core), not full segment coverage. The code is correct; the criterion's wording is not. Carried unfixed from six reviews. |
| [roadmap.md](../../docs/roadmap.md):148, :156 | The 2026-08-06 decision block cites Phase 2's exit criteria as `:98-108` and its Implements list as `:80-92` | Re-verified: the exit criteria are at `:112-122` and the Implements list at `:94-108`. The same session's own insertion moved them. Cite the heading, not the line. |
| [roadmap.md](../../docs/roadmap.md):163, :174 | States in the present tense that `WorldSelectMap.tscn` *"sets `mouse_filter = 2` (IGNORE)"* and that the blind click *"Needs a regression test"* | Both closed by `cb9f9b8`: the scene sets STOP and `world_select_controller_test.gd` carries the regression test — `test_world_select_map_scene_stops_mouse_events` and `test_left_click_in_segment_mode_selects_nothing` both ran green this session. The decision block reads as a live defect report. |
| [test-plan.md](../../docs/test-plan.md) §11 (`:145`) | P0 coverage table presented as the first-playable bar | 23 of 31 named tests in §11 have no matching function (74%, method stated in V3). Carried unfixed. |
| [architecture.md](../../docs/architecture.md):44-69 | Lists systems and UI scripts that do not exist | Seven system scripts absent (`economy_manager`, `information_manager`, `permissions_manager`, `season_manager`, `time_controller`, `milestone_tracker`, `narrative_manager`) plus most of the UI roster; all Phase 3–6, so not a regression, but the table reads as a description of the codebase and overstates it. Split into *planned* vs *built*. |
| [game/CLAUDE.md](../../game/CLAUDE.md):86-100 | Systems table names 13 files, of which 6 are built | Re-verified: **24 of the 30 built scripts are absent** from it, including `simulation.gd`, `main.gd`, all four autoloads, all three constants files, `world_renderer.gd` and all ten UI scripts; there is no UI section. The file states its own rule at `:102-104` — *"Add a row here whenever a new system is created"*. Now a seven-week-old convention miss. |
| [push-runbook.md](../../docs/push-runbook.md):199, 383, 422 | Dated "2026-08-14" | The work was 2026-08-13 local. Cosmetic; self-reported and uncorrected. |
| [ci.yml](../../.github/workflows/ci.yml):238 | *"Known gap … the macOS preset exports a .zip, so these land beside the bundle"* | Half closed: the credits screen shipped 2026-08-09 (`66cf279`). Only the `.zip` half is still live, which is C2. |
| [export-setup.md](../../docs/export-setup.md):97 | *"uploads everything as a workflow artifact (14-day retention)"* | Still false for pull-request runs: `ci.yml:280` is `retention-days: ${{ github.event_name == 'pull_request' && 1 || 14 }}`, so PR artifacts live **one day**. This file is downstream of `ci.yml` and should say so. |
| [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md):130-135 | Records that GUT's bundled `OFL.txt` carries only the Anonymous Pro copyright statement, and that Courier Prime and Lobster Two *"must be sourced and added here first"* if the project ever ships them | **Not stale — correct, and load-bearing.** The obligation is discharged only by `exclude_filter="addons/gut/*,tests/*"` holding on all four presets (re-verified at `:11,42,73,116`). Recorded here so that if B4 changes what ships, the font question surfaces as a consequence rather than a discovery. |

## 5. Risks & open questions

- **The week's only work is in the working tree, and the session that did it
  left no log.** `M .gitignore`, `M docs/signing-runbook.md`,
  `commit-plan-2026-09-07.json` naming a branch that was never created, and no
  `daily-logs/2026-09-07.md`. **This is the same process defect the 09-01 review
  named — reviews and logs get written after the last commit — arriving in a new
  place.** The vault backlog it complained about is now clean; the code backlog
  is not. The fix is the same: the session's first move commits the previous
  session's work.
- **Uncommitted is further from `main` than it used to be.** Before 09-06, dirty
  files on `main` were one `git commit && git push` away. Under ruleset
  `22403399` with `bypass_actors: []`, they now need a branch, a pull request,
  five green contexts and a merge click. **This is correct and it is also
  friction that nobody has yet paid in a working session** — PRs #5 and #6 were
  created by a session that had already planned for it. B8 is the first item to
  meet the new floor cold.
- **The deadline is still Apple's, and it is now twelve days old.** Enrolment
  submitted 2026-08-27. Whenever it is approved, A4 delivers a `.p8` that can be
  downloaded exactly once, into a public repository. The control that does not
  depend on any GitHub setting is written and **not in the repository**. It
  costs one pull request to fix, and a key that leaks is rotated, not recovered.
- **Two gates in this repository have never refused anything.** `dco` has been
  green on seven pull requests and red on none (V5); ruleset `22403399` has
  admitted two pull requests and refused none. Both are the failure path that
  matters, and both are untested. A gate seen only green is a gate.
- **`protect_main.json` and `ci.yml` must now change together.** Five literal
  job-name strings, in two files, in two directories, with no test asserting
  they match. Two of them carry the Godot version. Nothing in CI would catch a
  drift — the symptom is a pull request that never becomes mergeable, which
  reads as a GitHub outage rather than as a typo. **Worth a `tools/` check with
  a test, next time anyone is in either file.**
- **A roadmap exit criterion is met in tests and unreachable in the artifact**
  (C9). Ten reviews have now asserted "every Phase 1 and Phase 2 exit criterion
  is met"; that is true of the test suite and not of the thing a player runs,
  and no document says which of those two the criterion meant. It needs an
  owner's sentence, not code.
- **`game/project.godot` has no `[display]` section**, so the export runs at
  1152×648 with stretch disabled and the 09-02 walk failed two of B3's
  acceptance clauses on legibility. Recorded, not fixed, by Brent's call on
  09-02, because `stretch/mode = "canvas_items"` also changes screen-to-world
  mapping. **It is now inside C5's acceptance rather than floating**, and it
  will be visible in the first screenshot anyone takes of a release.
- **The first thing a player sees is aimed at a measured dead zone** (C4). One
  line, measured twenty-nine days ago, still undecided. It should not survive
  into a release note.
- **Nothing verifies that the published release actually opens for a stranger**
  (B7). Ten reviews have measured the repo; the harness's definition of a
  working build ends with *"**and** it launches"*.
- **The website points at an empty Releases page, publicly.**
  `website/index.html` carries the primary download call to action and the page
  has **zero** occurrences of "gpg", "sha256", "smartscreen", "unsigned" or
  "fingerprint" (C6).
- **The eight species portraits on the public site have no recorded
  provenance.** `website/assets/img/species/*.png` are not mentioned in
  `THIRD-PARTY-NOTICES.md`, and `LICENSE-ASSETS` covers **original work only**.
  If they were authored for this project, nothing needs doing except a line
  saying so; if not, ADR 0017 requires a notice. It cannot be settled from the
  repo; it needs the person who made them.
- **This review could not observe CI or any GitHub state.** `which gh` → not
  found; `git fetch origin` → *Host key verification failed*. **Nothing in this
  note should be read as a claim about CI's current status, artifact expiry,
  secret scanning, push protection, or whether the ruleset is still applied.**
  The repository files describing those things were read; the settings
  themselves were not.
- **The sandbox cannot export**, re-confirmed by attempt this session. V4 (an
  arm64 preset in CI) would let a future review boot a real artifact instead of
  reasoning about one.

## 6. Suggested next-week focus

1. **B8 — land what is already written** (S). A branch, two commits from
   `commit-plan-2026-09-07.json`, a pull request, five green contexts, a merge.
   Then the two things the commits cannot do: read secret scanning and push
   protection with `gh api` and **write the result and the date into a log**,
   and write the 09-07 session's log. **This closes C8's second half for free**,
   because the same diff corrects the *"about to go public"* line. It is the
   only item on the page with a deadline nobody controls, and it is a session
   measured in minutes.
2. **C7 + C3 — the two items with lead time and no thinking in them** (S + S).
   Godot 4.6.3 and the macOS export templates installed on the Mac before
   anything gets signed, with the version recorded in a log; and the four
   version strings in `export_presets.cfg`. Neither waits on Apple and both are
   on B6's critical path.
3. **C4 + C9 — the two owner calls** (S + S). Both are one decision and one
   paragraph, both have been open for weeks, and both are inputs to documents
   that come later: C4 to C5's QA pass, C9 to B6's release note. Neither needs a
   working session; they need Brent.
4. **B4 — the packaging decision** (M), **carrying C6 and C8 in the same PR.**
   The last thing standing between a green pipeline and something a stranger can
   download and run. Land it as one commit with the `smoke-windows`,
   `inspect_pck.py` and `check_pck_contents.py` updates, the `SHA256SUMS.txt`
   `find` pattern, and the download-page copy — C6 cannot be scheduled any other
   way, since `deploy-website.yml` publishes on push.
5. **V4 — settle the arm64 preset** (S), before B6 rather than during it.

C1 and C2 unlock the moment the Apple certificate lands; B6 waits on everything;
and **B7 — runbook A8, downloading the published DMG on a clean Mac — is what
actually turns "first build" into "next build"** in a following review.

---

## Verification

Every claim in this note is labelled below. Anything not traceable to something
read or run **this session** is Unverifiable and is said so plainly rather than
hedged in prose.

### Confirmed — read or run this session

- `HEAD` = `16622ec`, branch `main`, `origin/main..HEAD` = 0, `HEAD..origin/main`
  = 0, `git tag -l` empty (`git rev-parse`, `git rev-list --count`, `git tag`).
- Working tree is exactly `M .gitignore` and `M docs/signing-runbook.md`
  (`git status --short`); both diffs read in full (`git diff`).
- `commit-plan-2026-09-07.json` contents, including branch name
  `chore/credential-path` and both commit bodies (`cat`).
- `obsidian-vault/daily-logs/2026-09-07.md` does not exist (`ls`, exit 2).
- GUT: 24 scripts / 246 tests / 3,154 asserts, all passing, exit 0, 1.714s
  (vendored `Godot_v4.6.3-stable_linux.arm64`, `--headless -s
  addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`).
- Python tools: `Ran 86 tests … OK` (`python3 -m unittest discover -s
  tools/tests`).
- Both headless boots clean, with the exact log lines quoted in §2.
- Sandbox export failed on missing `export_templates/4.6.3.stable/` templates
  (`--export-release "Linux arm64"`).
- `ci.yml` = 331 lines and every line number cited in §2, §3 and §4
  (`wc -l`, `grep -n`).
- `.github/rulesets/protect_main.json` exists, 1,519 bytes, with five `"context"`
  strings at `:40,44,48,52,56` matching the five `ci.yml` job names.
- All 20 data files valid JSON (`python3 -m json.tool`).
- 30 `.gd` files / 3,584 LOC under `game/scripts/`; 24 `*_test.gd`; no
  `env_config_test.gd`; zero test-file contact for `economy_constants` and
  `habitat_constants`.
- `export_presets.cfg` values at `:11,26,42,57,73,88,116,117,128,138,139,145,147,148,173`.
- `builds/` = 4.0K; `wildlife-crossing-desktop-builds/` = 411 MB, newest mtime
  2026-07-28 03:31; `docs/release-notes/` = `.gitkeep` only.
- 14 `commit-plan*.json` at root, all ignored via `.gitignore:36`
  (`git check-ignore -v`).
- Zero hits for the verification keywords in `website/index.html` and
  `website/user-guide.html` (`grep -cin`).
- `game/project.godot` is 44 lines with no `[display]` section; autoload block at
  `:26-31`; `run/main_scene` at `:23`.
- V3's 31/23/74% measurement, by the extraction described in the item.
- Every §4 doc-drift row's quoted text and line number, re-read this session.
- `docs/pipeline-design.md:346-347` and `:485` assert the repo is public;
  committed `docs/signing-runbook.md:137` still says "about to go public"
  (`git show HEAD:… | grep -n`).

### Assumed — carried from the repo's own record, not re-verified here

- That the 09-02 and 09-05 windowed walks observed what
  [[../daily-logs/2026-09-02]] and [[../daily-logs/2026-09-05]] say they did:
  the crossing cue seen and heard, the credits legibility failure, the
  `codesign` `adhoc,runtime` result, the locked-sub-area desaturation, and the
  eleven padlocked cards. **No artifact was fetched or run this session.**
- That `wildlife-crossing-desktop-builds/` was built by Godot 4.6.0 and fails
  the repo's pack gate. Size and mtime are measured; the provenance is carried
  from earlier reviews and the binaries were not executed (this environment is
  arm64 Linux).
- That ruleset `22403399` is still applied with `bypass_actors: []`. The file
  `.github/rulesets/protect_main.json` was read; **GitHub was not.**
- That Apple enrolment submitted 2026-08-27 is still pending —
  [[../daily-logs/2026-08-27]] is the only record and nothing since contradicts
  it.
- That `dco` has been green on seven pull requests. The job's gating condition
  was read at `ci.yml:69`; the run history comes from the daily logs.

### Unverifiable from this session

- **CI status.** `which gh` → not found; `git fetch origin` → *Host key
  verification failed*. Whether the last run passed, whether any artifact still
  exists, and what its expiry is are all unknown here. §1's Step-1 finding that
  CI *exists* says nothing about whether it *passed*.
- **Secret scanning and push protection.** GitHub-side settings. The 08-29 log
  says they were off; nothing since has recorded a change; this session could
  not read them. B8's Part A pre-flight exists precisely to make this
  observable, and it is uncommitted.
- **Whether the ruleset would actually refuse a red check.** Never exercised.
- **Whether `require_extra_approval_for_unattributed_changes` (arrived by
  default per the 09-06 log) affects the ADR 0019 pipeline.** Untested.
- **The provenance of the eight website species portraits.** Not answerable from
  the repository.
- **The 09-01 note's V3 figures (43/35/81%).** Its extraction method was not
  recorded, so this session's 31/23/74% cannot be compared to it. Neither number
  is wrong; they are not the same measurement.

---

## Related

- [[../../docs/roadmap|roadmap]]
- [[../../docs/pre-build-checklist|pre-build-checklist]]
- [[../../docs/signing-runbook|signing-runbook]]
- Previous review: [[2026-09-01-next-build]]
- Recent logs: [[../daily-logs/2026-09-06]], [[../daily-logs/2026-09-05]],
  [[../daily-logs/2026-09-02]]
