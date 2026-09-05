---
title: "Automated Development Pipeline — Design"
date: 2026-09-05
status: draft
---

## Purpose

This document designs the pipeline that carries work from
[`roadmap`](roadmap.md) through design, development, testing and merge, and
back into the build log. Its acceptance bar: **the product owner touches the
pipeline exactly twice per task** — once to release a task for automated
development, once to review the resulting pull request — and both touches are
short because every automated stage before them prepares its input.

Everything else runs unattended in GitHub Actions.

Status is `draft`. Nothing here is built yet. §6 lists what must change in the
repo first, §7 lists the decisions that are the product owner's and not
Claude's.

---

## 1. Why GitHub Actions and not the Mac

The current shape of every commit on this repo is fixed by a constraint
recorded in `push-runbook.md` and in the `wildlife-crossing-git-push` memory:
`origin` is SSH, the Cowork mount has no SSH keys, and `tools/ship.py --execute`
**deliberately refuses to run over the mount** because the mount forbids
`unlink` and git's lock lifecycle is write-then-unlink. So today the write side
of every change ends at a human keyboard.

That is correct for the current workflow and fatal for an unattended one. A
GitHub Actions runner has a checkout with a working credential, a normal
filesystem, and no mount. Moving the write side there is what makes the rest of
this design possible; it is not an incidental hosting choice.

Consequences worth stating plainly:

- **`tools/ship.py` stays.** It guards the *local* commit path and its value is
  the set of things it refuses to do. The pipeline adds a second commit path
  (Actions) with a different guard — the DCO check plus a required PR — rather
  than replacing the first. Two paths, two guards, neither weakened.
- **The vendored Godot binary in `tools/godot/` is not on the runner.** CI
  already downloads a pinned `4.6.3-stable` per `.github/workflows/ci.yml`.
  Every automated stage that needs an engine reuses that download step, and the
  version stays pinned in one place.
- **Anything needing a windowed launch stays on the Mac.** Visual QA and the
  signing runbook are unchanged by this design.

---

## 2. The state machine

The pipeline's state lives in **GitHub Issue labels**. There is no database, no
external orchestrator, and no state file that can drift from reality. Every
stage reads the label, does its work, and writes the next label.

```
docs/roadmap.md
      │
      ▼
 ┌─────────────────────────────────────────────────────────┐
 │ S1  Task generation            (weekly, scheduled)      │
 │     extends weekly-build-review                         │
 └─────────────────────────────────────────────────────────┘
      │ opens Issues → status:proposed
      ▼
 ╔═════════════════════════════════════════════════════════╗
 ║ S2  HUMAN GATE 1 — release tasks                        ║
 ║     one label per task: status:proposed → status:ready  ║
 ╚═════════════════════════════════════════════════════════╝
      │
      ▼
 ┌─────────────────────────────────────────────────────────┐
 │ S3  Prototype fan-out          (3 parallel runs)        │
 │     proto/<issue>/1..3  +  docs/spikes/<issue>-N.md     │
 └─────────────────────────────────────────────────────────┘
      │ status:spiking → status:selected
      ▼
 ┌─────────────────────────────────────────────────────────┐
 │ S4  Selection                  (1 run, fixed rubric)    │
 │     scores 3 spikes, posts comparison, promotes winner  │
 └─────────────────────────────────────────────────────────┘
      │
      ▼
 ┌─────────────────────────────────────────────────────────┐
 │ S5  Build-out                  (1 run)                  │
 │     full implementation + GUT tests + PR with brief     │
 └─────────────────────────────────────────────────────────┘
      │ status:building → status:in-review
      ▼
 ┌─────────────────────────────────────────────────────────┐
 │ S6a Automated pre-review       (code-review skill)      │
 └─────────────────────────────────────────────────────────┘
      │
      ▼
 ╔═════════════════════════════════════════════════════════╗
 ║ S6b HUMAN GATE 2 — code review and merge decision       ║
 ╚═════════════════════════════════════════════════════════╝
      │
      ▼
 ┌─────────────────────────────────────────────────────────┐
 │ S7  Merge + documentation      (on PR merge)            │
 │     release-note fragment, roadmap decision block,      │
 │     daily-log entry, ADR if flagged, close issue        │
 └─────────────────────────────────────────────────────────┘
      │
      ▼
 obsidian-vault/daily-logs/ + build-reviews/  →  back to S1
```

### Label taxonomy

| Label | Set by | Meaning |
|---|---|---|
| `status:proposed` | S1 | Generated, unblocked, awaiting release |
| `status:ready` | **human** | Released for automated development |
| `status:spiking` | S3 | Fan-out in flight |
| `status:selected` | S4 | An option won; build-out queued |
| `status:building` | S5 | Implementation in flight |
| `status:in-review` | S5 | PR open, awaiting human review |
| `status:blocked-human` | any | Needs an owner decision; pipeline stops |
| `size:S` `size:M` `size:L` | S1 | Rough size, from the build-review convention |
| `phase:1`…`phase:6` | S1 | Roadmap phase the task serves |
| `auto:forbidden` | S1 | Never eligible for automation (see §7.2) |

`status:ready` is **the only label a human ever has to set.** Everything else is
written by a workflow.

---

## 3. Stage specifications

Each stage below states: what fires it, what it reads, what it writes, what
stops it, and how it fails.

### S1 — Task generation

- **Trigger.** `schedule` (weekly, Monday) plus `workflow_dispatch`.
- **Runner.** `anthropics/claude-code-action@v1` in automation mode, `prompt`
  invoking the build-review skill.
- **Reads.** `docs/roadmap.md`, the most recent
  `obsidian-vault/build-reviews/` note, `docs/test-plan.md`,
  `docs/pre-build-checklist.md`, actual repo state, and open Issues.
- **Writes.** The dated build-review note exactly as today, **plus** one GitHub
  Issue per work item that is (a) not already an open Issue and (b) has no
  unmet dependency.

This stage is not new work. `harness/weekly-build-review/SKILL.md` already
produces buildable items with Title / Why it blocks / Files touched /
Acceptance criteria / Dependencies / Size / References — which is exactly an
Issue body. The change is that the review stops emitting only prose and also
emits queue entries, and that its dependency field becomes load-bearing:
**an item with an open dependency is not proposed.** That is what "unblocked"
means here, and it is computable from the note's own `Depends on:` field.

The review's Step 6 verification (Confirmed / Assumed / Unverifiable labels) and
its red-team subagent stay. An item resting on an Unverifiable claim is opened
as `status:blocked-human`, not `status:proposed` — the pipeline should never
spend three parallel runs on a task whose premise nobody checked.

- **Guardrails.** Caps at N new Issues per run (start at 5). Never reopens a
  closed Issue. Never proposes anything matching the `auto:forbidden` path list
  in §7.2.
- **Failure mode.** No Issues opened. The note is still written. Nothing
  downstream fires. Safe.

### S2 — Human gate 1: release tasks

- **Where.** The dashboard (see §9.2 — how it gets refreshed is an open
  choice), backed by GitHub.
- **What you see.** For each `status:proposed` Issue: title, size, phase, the
  one-line reason it is unblocked, its acceptance criteria, and the roadmap exit
  criterion it serves. Sorted by the review's own sequencing.
- **What you do.** Add `status:ready` to the ones you want built. One label.
  From a phone if you like.
- **What it costs you.** Reading five short cards. The judgment is *whether this
  is the right work now* — not *is this task well-formed*, which S1 already
  guaranteed.

### S3 — Prototype fan-out

- **Trigger.** `issues.labeled` where the label is `status:ready`.
- **Runner.** One workflow, `strategy.matrix` of three, three independent
  `claude-code-action` runs.
- **Each run.** Branches `proto/<issue>/<n>` from `main`, builds the smallest
  thing that demonstrates its approach, and writes `docs/spikes/<issue>-<n>.md`:
  the approach in a paragraph, what it changes, what it costs, what it forecloses,
  and an honest list of what the spike does *not* do.
- **Deliberately shallow.** A spike is judged on whether the approach is right,
  not on whether it is finished. It may skip tests, polish and edge cases, and
  the memo must say so. Three finished implementations would cost roughly double
  and throw two away.
- **Differentiation.** The three runs get the same task and *different framing*:
  one told to prefer the smallest change consistent with existing systems, one
  told to prefer the structure that best serves the roadmap two phases out, one
  unconstrained. Without that, three runs of the same model on the same prompt
  converge and the selection stage has nothing to choose between. This is the
  part of the design most likely to need tuning after the first few tasks.
- **CI.** `proto/**` pushes run a **light** job set: `tools` + `test` only.
  No export, no artifact upload — spikes need a test signal, not a binary, and
  three export runs per task is runner time spent on nothing. A spike that
  fails the GUT suite is not
  disqualified — it is reported to S4 as a fact.
- **Guardrails.** `concurrency` group keyed on the Issue number, so a
  double-label cannot fan out twice. `--max-turns` cap. Job `timeout-minutes`.
  Branch protection on `main` (§6.5) makes it structurally impossible for a
  spike to reach `main`.
- **Failure mode.** A run that dies leaves a branch and no memo. S4 treats a
  missing memo as a withdrawn option and proceeds with two. Fewer than two
  surviving options → `status:blocked-human`.

### S4 — Selection

- **Trigger.** `workflow_run` completion of S3. (Not `issues.labeled` — see
  §6.4 on why a token-written label cannot chain.)
- **Runner.** One `claude-code-action` run, Opus.
- **Reads.** The three memos, the three diffs, the three light-CI results,
  `docs/roadmap.md`, the relevant ADRs, root and scoped `CLAUDE.md`.
- **Scores against a fixed, published rubric** — the rubric lives in the repo so
  the decision is auditable and so you can change the pipeline's taste by
  editing a file:

  1. **Delivers the assigned task.** Meets the Issue's acceptance criteria.
  2. **Serves the roadmap.** Does not foreclose a later phase; where phases
     disagree, the earlier one wins.
  3. **Consistent with the architecture.** Obeys `docs/architecture.md`, the
     ADRs, and `game/CLAUDE.md` — signals over direct references, no magic
     numbers, one class per file, no `print()`, past-tense signal names.
  4. **Honest about cost.** Prefers the option whose memo names its own
     weaknesses over the one that claims none.
  5. **Reversibility.** Where two options score alike, the one that is cheaper
     to undo wins.

- **Writes.** A comparison comment on the Issue — one table, one paragraph of
  reasoning, one named winner and why the other two lost. Promotes the winning
  branch to `feat/<issue>-<slug>`. Sets `status:selected`.
- **Escalates instead of guessing.** If the three options differ on something
  the roadmap does not settle — a genuine architectural fork — it writes the
  fork as a question, sets `status:blocked-human`, and stops. This is the
  single most important behaviour in the stage. An automatic selector that
  never escalates will quietly make architectural decisions on your behalf, and
  you will find out about them in a build review six weeks later.
- **Failure mode.** No promotion, no build-out. The spike branches remain for
  manual inspection.

### S5 — Build-out

- **Trigger.** `workflow_run` completion of S4, guarded on `status:selected`.
- **Runner.** One `claude-code-action` run on `feat/<issue>-<slug>`.
- **Does.** Full implementation to project conventions; a GUT test file per new
  system at `game/tests/<system_name>_test.gd` (root `CLAUDE.md` requires it);
  runs the suite; stages the `.uid` files Godot generates at import — the
  omission the `wildlife-crossing-git-push` memory records as how the import
  breaks in CI; commits with a `Signed-off-by` trailer (§6.1); opens a PR.
- **The PR body is the review brief**, and its quality is what makes gate 2
  cheap. Required sections:

  - **Task and acceptance criteria**, as a checklist, each item marked met or
    not met with the evidence.
  - **Which option won and why**, one paragraph, linking the S4 comment.
  - **Roadmap exit criteria touched**, quoted from `docs/roadmap.md`.
  - **Test delta** — scripts / tests / asserts before and after, in the format
    the daily logs already use ("18 scripts / 144 tests / 2,799 asserts").
  - **What I would want a human to look at** — an explicit, non-empty list.
    A build-out that claims nothing needs attention has not looked hard enough.
  - **What this does not do** — deferred pieces, with reasons, in the roadmap's
    own decision-block voice.

- **Guardrails.** Cannot modify any `auto:forbidden` path (§7.2); if the task
  turns out to require one, it stops and sets `status:blocked-human` rather than
  routing around the rule. Cannot push to `main`. Cannot merge.
- **Failure mode.** Draft PR with a failing suite and an honest body. Still
  useful; you decide whether to salvage or discard.

### S6a — Automated pre-review

- **Trigger.** `pull_request` opened / synchronized on a `feat/**` branch.
- **Runner.** `claude-code-action` running the `code-review` plugin skill with
  `--comment`, as documented for the action, posting inline comments.
- **Purpose.** You should never be the first reader of a machine-written diff.
  This stage catches the mechanical things — convention violations, missing
  docstrings, an `@export` that should be a constant, a signal connected in the
  editor rather than `_ready()` — so your attention goes to design and fit.

### S6b — Human gate 2: review and merge

- **Where.** The PR, with me alongside in a Cowork session if you want a second
  read.
- **What you do.** Read the brief, skim the diff, merge or request changes.
  Requesting changes re-fires S5 on the same branch with your comments as input.
- **What it costs you.** The brief is written to be read in five minutes. The
  diff is already screened. The decision is *should this be in the game* — which
  is the only part of this pipeline that was ever yours.

### S7 — Merge and documentation

- **Trigger.** `pull_request` closed with `merged == true`.
- **Does.**
  - Appends a fragment to `docs/release-notes/vX.Y.Z.md` for the release in
    flight.
  - Adds a decision block to `docs/roadmap.md` **only when the merge changes
    what a phase means** — a deferral, a scope call, a superseded item — in the
    established voice, dated, with the evidence. Never rewrites exit criteria.
  - Appends to `obsidian-vault/daily-logs/YYYY-MM-DD.md`, creating it if absent,
    matching the existing log convention.
  - Opens an ADR **draft** if S4 flagged the decision as architecturally
    significant. Draft, not final: ADRs are the record of decisions you made.
  - Closes the Issue with a link to the merge commit.
  - Triggers a dashboard refresh — **not** by calling the artifact tools
    itself, which it cannot do; see §9.2.
- **Guardrails.** Documentation-only. Touches no `.gd` file. Its PR — because
  this stage opens its own docs PR rather than pushing to `main` — is small
  enough to approve at a glance, and keeps `main` protected.

---

## 4. What the pipeline does *not* do

Named explicitly, because a pipeline's guarantees are only as good as its
stated limits:

- It never merges to `main`. Only you do.
- It never ships a release, tags a version, or signs a binary.
- It never touches Phase 5 First Nations narrative content. The roadmap's
  cultural-advisor gate precedes any content-complete milestone, and a review
  gate that a workflow can satisfy is not a review gate.
- It never adds a dependency, asset, font or addon. Root `CLAUDE.md` requires a
  `THIRD-PARTY-NOTICES.md` entry and a licence judgement, and that judgement is
  the copyright holder's.
- It never edits `LICENSE`, `LICENSE-ASSETS`, `THIRD-PARTY-NOTICES.md`,
  `CONTRIBUTING.md`, or an existing ADR.
- It never decides what "done" means. Acceptance criteria come from the roadmap
  and the build review, both of which you own.

---

## 5. Cost and blast radius

- **Five Claude runs per task**: three spikes, one selection, one build-out,
  plus the pre-review. With a subscription OAuth token these draw on plan
  capacity rather than metered API billing, which means the practical cap is
  **how many tasks you release at once**, not a dollar figure. Start by
  releasing two tasks per week and watch what it costs before widening.
- **Actions minutes and artifact storage are both free**, because the
  repository is public: GitHub's per-account quotas for minutes, artifact
  storage and cache storage apply to private repositories only. If it ever goes
  private again, `windows-latest` bills at 2×, `smoke-windows` becomes the
  single most expensive job in the pipeline, and §6.2 reverts to a hard
  constraint rather than a robustness note.
- **Wall-clock, not cost, is now the artifact concern.** ~412 MB uploaded per
  pull-request run is minutes of runner time on every push to every open PR.
- **Blast radius of a total pipeline failure**: some abandoned branches, some
  open Issues, and a docs PR nobody merged. `main` is untouched by construction.

---

## 6. Prerequisites — what must change before any of this runs

Ordered. Each is small; none is optional.

### 6.1 Give Actions commits a DCO identity

`tools/check_dco.py` fails any PR commit without a `Signed-off-by` trailer
whose email matches the commit author's, compared case-insensitively. A
`claude-code-action` run supplies neither by default, so **every automated PR
would be red on arrival.**

**Settled by [ADR 0019](adr/0019-dco-sign-off-on-automated-commits.md)
(2026-09-05):** pipeline commits are authored by and signed off by
Brent Humphries `<brent.humphries@gmail.com>`, with a `Co-Authored-By: Claude`
trailer. The DCO certifies provenance and the right to submit, not review, and
provenance is a fact about how the work is produced — which the
`auto:forbidden` list in §7.2 is what keeps true. `check_dco.py` and the `dco`
job need no changes.

What the workflow must do, since a runner's default identity satisfies none of
it:

```yaml
- name: Identify commits per ADR 0019
  run: |
    git config user.name  "Brent Humphries"
    git config user.email "brent.humphries@gmail.com"
    git config format.signOff true
```

`format.signOff` adds the `Signed-off-by` trailer to every commit the run
makes; `Co-Authored-By: Claude` goes in the commit message template the S5
prompt writes. Verify both on the first automated PR by reading the trailers on
the commit itself, not by trusting a green `dco` job — the job would also pass
a bot signing as itself, which is why ADR 0019 exists.

### 6.2 Decouple the artifact upload from the merge gate

**The quota constraint is gone.** The repository went public on 2026-09-05, and
GitHub's per-account free quotas for minutes, artifact storage and cache storage
apply to private repositories only; standard runners are free in public
repositories. The ~412 MB export set (linux 70 MB, macos 240 MB, windows 102 MB)
no longer counts against 500 MB, and concurrent pull requests are no longer
capped at one. The `ci:export` label this document previously proposed is
unnecessary and has been dropped from §2. Pull requests can keep uploading and
keep running `smoke-windows`, which is *better* coverage than before — every PR
now gets a booted Windows binary rather than only `main`.

**The cascade that did the damage is still there.** Re-read what happened on
2026-08-27: the quota was the trigger, not the mechanism. The upload step is
`if: always()`, so its failure fails the `export` job; `smoke-windows` declares
`needs: export`, so it skipped; and a merge with nothing wrong with it was
blocked. Any transient upload failure — a network blip, a GitHub incident, a
future size limit — reproduces that exact chain, and a pipeline running several
PRs at once meets transient failures more often than one running none.

Two small changes make the upload non-load-bearing:

- Let the upload fail without failing the job (`continue-on-error: true` on that
  step). The export itself already succeeded; eleven staged files proved that in
  August. Losing the *copy* of a good build should not be a red check.
- Give `smoke-windows` a guard so a missing artifact reports "no binary to
  smoke" as a skip rather than inheriting a failure from a step that had nothing
  to do with Windows.

This is worth doing on its own merits, independent of the pipeline. It is the
difference between "a good build was discarded" and "a good build was discarded
*and* blocked a merge."

### 6.3 Add a light CI path for spike branches

`ci.yml` triggers on `push: [main]` and `pull_request: [main]`. A `proto/**`
branch pushed without a PR gets **no CI at all**, so S4 would be choosing
between three untested options. Add a `proto/**` push trigger that runs `tools`
and `test` only — seconds of runner time, no export, no upload.

### 6.4 Chain the stages on an event that a token can actually fire

This is the failure most likely to make the pipeline look broken for a week.

GitHub's rule: **events created with the default `GITHUB_TOKEN` do not create
workflow runs**, and the documented exceptions are `workflow_dispatch` and
`repository_dispatch`. So a workflow that finishes S3 and sets
`status:selected` will *not* fire a workflow listening on `issues.labeled`.
Nothing errors. The Issue simply sits there wearing the right label with no run
behind it.

Two mechanisms work:

- **Guaranteed.** Each stage ends by dispatching the next explicitly —
  `repository_dispatch` with the Issue number in the payload, or
  `workflow_dispatch` with it as an input. Both are named exceptions to the
  rule, so `GITHUB_TOKEN` is sufficient and no extra secret is needed.
- **Lighter, verify before relying on it.** `workflow_run` on the upstream
  workflow's completion. This is the conventional way to chain and fires on
  completion rather than on a token-created API event, but I could not confirm
  the `GITHUB_TOKEN` interaction from GitHub's own documentation — the relevant
  section was truncated on every fetch. If you use it, prove it with a
  two-workflow smoke test before building on top of it. Either way the
  `workflow_run` workflow file **must exist on the default branch** or it never
  fires at all, which is its own silent-stall mode.

Keep `issues.labeled` for S2→S3 only, where a human sets the label and the
rule does not apply.

Related, and equally silent: the action rejects a bot actor unless it is listed
in `allowed_bots`, and applies that check to scheduled runs too — attributing
them to whoever last edited the `cron` line. S1 needs `allowed_bots` configured
or it fails on its own schedule.

### 6.5 Protect `main`

Require a PR, require the CI checks, disallow direct pushes. The pipeline's
"never merges to `main`" guarantee should be enforced by GitHub, not by a
prompt. This also protects against the failure mode where a build-out run
misreads its instructions.

### 6.6 Move the skills where the action can find them

`.claude/` is currently empty; `harness/weekly-build-review/` sits outside it.
For `prompt: "/weekly-build-review"` to resolve, the skill must be under
`.claude/skills/` on the runner after checkout. Either relocate `harness/` to
`.claude/skills/` or add a checkout step that copies it. Relocating is cleaner
and makes the harness discoverable to local sessions too; `README.md` lists
`harness/` in the tree and would need updating with it.

### 6.7 Account for what a public repository changes

Going public resolves §6.2 and introduces four things the pipeline has to know
about. None is a blocker; all four are silent if unanticipated.

- **Fork pull requests get no secrets.** GitHub withholds them from runs
  triggered by a fork PR on a public repository, so S6a's pre-review cannot run
  on an outside contribution — the token simply is not there. The `tools`,
  `dco` and `test` jobs still run and still gate the merge. Expect to review
  outside PRs unassisted, or to re-run the review after pulling the branch
  into the repository yourself.
- **Outsiders cannot make Claude run.** The action checks that the triggering
  actor has write access on issue and pull-request events, and rejects bot
  actors unless listed in `allowed_bots`. A stranger commenting `@claude` on
  a public issue gets nothing. Worth knowing before the first drive-by.
- **Scheduled workflows are disabled after 60 days of repository inactivity**
  in public repositories. S1 is the weekly scheduled run; at the current commit
  cadence this never fires, but a two-month gap silently stops the task queue
  rather than erroring.
- **The spikes are public.** Three half-finished prototypes per task, each with
  a memo candidly listing what it does not do, on public branches. Given that
  this repository already publishes its build reviews and daily logs — including
  the ones recording defects that shipped for a fortnight — that is consistent
  rather than new. But it is a choice, and it is worth making deliberately
  rather than discovering. If you would rather not, the alternative is spikes as
  workflow artifacts instead of branches, which costs S4 the ability to read a
  real diff.

### 6.8 Create the labels and the Issue template

Ten labels (§2) and one Issue template whose fields are exactly the build
review's work-item fields, so S1 fills a form rather than inventing a shape.

---

## 7. Decisions that are yours

### 7.1 Who signs off on a machine-written commit — settled

**Decided 2026-09-05 and recorded in
[ADR 0019](adr/0019-dco-sign-off-on-automated-commits.md).** Author and
sign-off both Brent Humphries, `Co-Authored-By: Claude` alongside.

The reasoning, in one paragraph, because it is the load-bearing part: the DCO
certifies provenance and the right to submit, not authorship of every line and
not review. [ADR 0017](adr/0017-licensing.md)'s own finding — that purely
machine-generated output is uncopyrightable, so an unknown fraction of this
codebase carries thin or no copyright — has a useful mirror image here: there is
no other rights-holder whose permission is needed. The "right to submit" is
cleaner for this material than for a human contribution. And provenance can be
certified in advance because it is a fact about how the work is produced, which
§7.2's forbidden-path list is what keeps true.

The honest objection, recorded in the ADR rather than argued away: the trailer
is timestamped before the work has been read. The migration path if that ever
outweighs the convenience is merge-time sign-off in the squash message, and it
does not invalidate anything signed under ADR 0019.

### 7.2 The `auto:forbidden` path list

My proposed starting list, for you to cut or extend:

`LICENSE`, `LICENSE-ASSETS`, `THIRD-PARTY-NOTICES.md`, `CONTRIBUTING.md`,
`docs/adr/**`, `.github/workflows/**`, `game/export_presets.cfg`,
`tools/ship.py`, `tools/check_dco.py`, and everything the roadmap assigns to
Phase 5's cultural-narrative gate.

Two of those deserve their reasons said out loud. `.github/workflows/**` is
forbidden because a pipeline that can edit its own guardrails has none.
`game/export_presets.cfg` is forbidden because root `CLAUDE.md` requires
`exclude_filter="addons/gut/*,tests/*"` on every preset, and losing it pulls
GUT and its OFL fonts into shipped binaries — changing what must be attributed,
silently.

### 7.3 How many tasks you release at once

Start at two. The failure you are guarding against is not cost, it is a review
queue you cannot keep up with, which turns the pipeline into a generator of
stale branches.

### 7.4 Whether S4 may pick, or may only recommend

The design above lets S4 promote a winner automatically and escalate on
architectural forks. The conservative variant has S4 always post the comparison
and wait for you to apply `status:selected`. That converts the pipeline from
two human gates to three. My read is that two is right *because* the escalation
path exists — but if the first half-dozen selections disagree with what you
would have picked, the third gate is the cheap fix.

---

## 8. Build order

Each step is independently useful, and the pipeline does something real from
step 2 onward. Nothing here requires the whole thing to work before any of it
does.

1. **Prerequisites 6.1–6.8.** No Claude in the loop yet. This is CI hygiene and
   it is worth doing even if the rest is never built — 6.1 (DCO identity) is the
   one that blocks everything, and 6.2 removes a merge-blocking cascade that has
   already cost this project once.
2. **S1 alone.** Extend the build review to open Issues. You get a real queue
   and the dashboard's first content. Still zero automated code.
3. **S6a alone.** Automated pre-review on PRs you open by hand. Immediate value,
   no orchestration, and it calibrates how good the review comments are before
   you depend on them.
4. **S5 without S3/S4.** Label a task `status:ready` and have one instance build
   it directly. This is the whole pipeline minus the prototyping, and it will
   tell you whether the Issue bodies S1 writes are good enough to build from —
   which is the assumption everything else rests on.
5. **S3 + S4.** Add prototyping and selection once step 4 works. This is the
   most expensive and most experimental part; it should be last, not first.
6. **S7.** Documentation automation, once there is a merge history to write
   about.

Steps 2 and 4 are where you will learn whether this design is right. If the
Issues from S1 are not buildable without you rewriting them, no amount of
prototyping downstream will fix that.

---

## 9. Machine dependencies — what still needs the Mac

### 9.1 The pipeline proper needs nothing but a runner

S1 through S7 all execute in GitHub Actions. The engine is downloaded per run
(`4.6.3-stable`, pinned in `ci.yml`), the tests are headless, the credential is
a repository secret, and `main` is written by a merge you click. Nothing in the
eight stages touches a local filesystem.

The Mac's current *mandatory* role disappears with it. Today `push-runbook.md`
and the `wildlife-crossing-git-push` memory describe a fixed division of
labour ending in "Brent runs `ship.py --execute`" and "Brent runs `git push`",
because the mount has no SSH keys and forbids `unlink`. A runner has neither
problem. `ship.py` stays as the guard on the local path; it stops being the
only path.

Going public compounds this: a cloud session with no device link can now clone
and read the repository over the network. Design conversations, code review
help and build-review analysis no longer require the Mac to be awake and
unlocked either.

### 9.2 One thing in this design cannot run in Actions at all

**The dashboard refresh, and it was a hole in the design as first written.**
S7 said "refreshes the dashboard artifact" and S1 inherits the same instruction
from `harness/weekly-build-review/SKILL.md` Step 7, which calls `list_artifacts`
and `update_artifact`. Those are Claude application tools. A
`claude-code-action` run has file tools and the GitHub MCP server; it has no
access to an artifact gallery. As specified, the dashboard could not be
refreshed from inside the pipeline at all — not on the Mac, not in the cloud.

> **Decision logged (2026-09-05): the dashboard is refreshed by a scheduled
> cloud session reading the public repository, and it has moved to a hosted
> artifact to make that possible.** The alternatives were a Pages dashboard
> published by `deploy-website.yml`, which would have made the task queue and
> review backlog public alongside the game, and no dashboard at all.
>
> **The migration was forced, not incidental.** The old
> `wildlife-crossing-project-state` artifact lives in the *desktop* artifact
> system, which is reachable only from a session linked to the Mac. A scheduled
> session bound to the Mac would need it awake and unlocked every Monday, which
> is the dependency this whole design exists to remove. So the board moved to a
> hosted artifact, which a device-free cloud session can read and republish over
> the network. It supersedes the desktop artifact the same way `project-state`
> was superseded by its two per-project successors on 2026-08-19.
>
> **The schedule: daily, 07:30 America/Chicago**, revised from weekly the same
> day. The page's inputs change two or three times a week — the daily-log dates
> across August and early September show that plainly — so a weekly page is
> wrong for most of the week it is up. On 2026-09-05 alone the suite moved from
> 23 / 237 / 3,032 to 24 / 246 / 3,154 and a blocker closed; a Monday-written
> page would have shown the old figures until the following Monday. Note that
> the cron is stored in UTC, so the local time shifts by an hour at each DST
> boundary; it fires at 06:30 local through the winter.
>
> **Daily runs are guarded, so most of them are cheap.** The session reads the
> artifact first — it must, to publish to it — and takes the head SHA already
> baked into the "Head of main" figure. One API call compares it against
> `main`. Unchanged, and with issue and pull-request counts also unchanged, the
> run stops without re-deriving anything.
>
> **Which forced a distinction the page now makes explicit: "State as of"
> versus "last verified".** The first is the date the figures describe; the
> second is the date someone last checked. Without the split, a guarded run has
> only bad options — leave the stamp old and the reader cannot tell stale from
> unchanged, or advance it and the page claims freshness it did not earn. With
> the split, a guarded run advances only "last verified", which is exactly what
> it did. A page that is accurate and eight days old is fine; a page that
> silently claims to be current is the failure this project's whole
> Confirmed / Assumed / Unverifiable discipline exists to prevent.
>
> **Consequence for `harness/weekly-build-review/SKILL.md`: Step 7 must be
> deleted.** Two writers on one page means half of it is always stale — the
> exact reasoning that split `project-state` in August. The scheduled session
> now owns the page; the review owns the note. Deleting Step 7 is also what
> unblocks moving S1 into Actions, since Step 7 is currently the only part of
> that skill that cannot run on a runner. This is a prerequisite of build-order
> step 2, not a tidy-up.
>
> **The reading frame is narrower than the Mac's was, and the page says so.**
> A cloud session reads `origin/main`. Uncommitted work in the local tree is
> invisible to it — and this project routinely carries vault files uncommitted
> for days, five consecutive days as recently as 2026-09-05. The page carries a
> "What this page cannot see" block rather than implying a clean tree. In
> practice this makes the dashboard a mild incentive to push, which is probably
> a feature.

### 9.3 Two things genuinely need a Mac, and neither is per-task

- **Visual QA.** A headless smoke test proves the binary boots to `Main.tscn`.
  It cannot tell you the crossing cue reads well, that the HUD is legible in a
  windowed export, or that the overlay's orange-to-teal treatment looks right —
  which is exactly what roadmap item C3 is owed. That judgment needs eyes on a
  screen.
- **macOS signing and notarization.** Apple's tooling requires macOS; see
  `signing-runbook.md`.

Both are release-time work, not per-task work. Neither sits between a roadmap
item and a merged pull request, so neither gates the pipeline.

---

## 10. Open questions

- Does the differentiated framing in S3 actually produce three distinguishable
  options, or three near-identical ones? Unverifiable until run. If the latter,
  S3 collapses into "one spike plus a design memo listing rejected approaches",
  which is cheaper and nearly as useful.
- Should a spike that fails the light CI suite be shown to S4 at all, or
  filtered? Showing it risks the selector rewarding a broken-but-elegant
  option; hiding it risks discarding the best approach over a trivial fix.
  Start by showing, with the failure stated.
- The roadmap is prose with embedded decision blocks, not a machine-readable
  plan. S1 reconciles it by reading, which works and is expensive. Whether it
  is worth adding a structured index is a question for after step 2.
