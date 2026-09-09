---
title: "Automation — what runs, where, and what it can see"
date: 2026-09-09
tags: [automation, process, pipeline]
status: active
---

# Automation

Every recurring process that touches this repository, with the one thing each
cannot see. Written 2026-09-09, when an audit found three processes reporting
incongruities largely because none of them declared which copy of the repository
it had read.

**The rule this file exists to enforce:** a process that reports project state
names its source and its read time. "Green" without "as of" is the failure this
table is here to prevent.

---

## What runs

| Process | Where it runs | Reads | Writes | Cannot see |
|---|---|---|---|---|
| `weekly-build-review` skill | On demand, in a session with this repo mounted | The tree, the test suite, the previous review, recent daily logs | `obsidian-vault/build-reviews/YYYY-MM-DD-next-build.md` and its index | GitHub: no `gh` and no API. CI status, run history and repository settings are **Unverifiable** in a review unless read from `github-state.json` |
| `next` skill | On demand | Recent logs and reviews, plus live `git status` | Nothing — read-only by constraint | Anything not yet written down |
| `log` skill | On demand, at the end of a session | The conversation, the vault conventions | The daily log; amendments to reviews; the review index | Whether its own output ever gets committed |
| Daily project-state refresh | Scheduled cloud session, 12:30 UTC | The public repo over git; formerly the GitHub API | The `Wildlife Crossing Project State` artifact | Your working tree, and the GitHub API (see below) |
| Morning brief | Scheduled cloud session, weekdays 13:00 UTC | Calendar, mail, memory | An artifact | This repository |

## What the cloud can and cannot reach

Tested 2026-09-09 from both a scheduled-style cloud container and a
device-linked session:

- **`git` over HTTPS works with no credentials.** `git ls-remote` and a shallow
  clone both return the true head. Every file, the full history, and each pull
  request's merge state via `refs/pull/*` are reachable this way.
- **`api.github.com` answers a cloud session `403`** — *"GitHub access to this
  repository is not enabled for this session"*. That is an egress policy denial,
  not an authentication failure, so a token does not change it. The agent
  proxy's own documentation says such a denial must be reported rather than
  retried or routed around.
- **`api.github.com/rate_limit` answers `5000` requests with `0` used.**
  Anonymous GitHub allows 60, so that reply is not coming from GitHub. Reports
  of "stale cached" API answers are better explained by this interception layer
  than by a CDN cache, and no amount of read-corroboration logic will fix them.

**Therefore:** anything derivable from git is read from git, pinned to a SHA.
Everything else is read on Brent's Mac by `tools/github_state.py` and committed
to `docs/github-state.json` with the moment it was read. Downstream readers
quote that timestamp. They never imply it is current.

## Why `.git/index.lock` keeps coming back

**Largely explained 2026-09-09, after being carried as "cause unknown" since
2026-08-25. One part is proven, one part is inference, and the difference is
recorded here deliberately.**

### Proven

A session working against the mounted copy of this repository can create and
rename files but **cannot unlink them**. Git takes a lock for every write, does
its work, then removes the lock, and that removal fails. Running `git reset`
from a linked session prints it:

```
warning: unable to unlink '.../.git/HEAD.lock': Operation not permitted
warning: unable to unlink '.../.git/refs/heads/main.lock': Operation not permitted
warning: unable to unlink '.../.git/index.lock': Operation not permitted
```

The operation itself succeeds. The lock stays. That accounts for the locks
always being **zero bytes** (nothing ever wrote to them), for no git process
ever running when one is found, and for the mtime not moving between sessions,
which is what the 2026-08-25 review measured when it disproved the theory that
`harness/weekly-build-review` was leaving them behind. That theory was wrong,
and the review was right to record the cause as unknown rather than guess a
third time.

### The workaround that hid it

`.git/_stale_locks/` holds **15 parked `index.lock.<pid>` files**, dated
2026-09-06 through 2026-09-09, one per recent session day. `.git/__probe` dates
from 2026-06-28 and `.git/_stale_lock_2` from 2026-08-11. None of these is a
git file; git creates nothing with those names.

They are earlier sessions working around the same wall: unable to delete a
lock, they moved it aside and carried on. **The evidence of the recurrence was
being filed into a directory nobody looked in**, which is a large part of why
eight weeks of investigation kept coming back empty. Anything on its way out of
a mounted folder should go to a `_to_delete/` directory in the working tree,
never inside `.git/`.

### Observed, not implicated

`lsof +D .git` shows a `com.apple` process holding several hundred **read-only**
descriptors across `.git/`, including the parked locks. That is consistent with
Spotlight or a similar indexer. Read-only descriptors do not create lock files,
so this is recorded as seen rather than as a cause. If locks ever appear with
no session having run a git write, this is the first thing to re-examine.

### The rule that follows

**No session runs git write commands against the mounted folder.** Reads are
fine, and so is writing project files. Anything that takes a git lock (`add`,
`reset`, `commit`, `mv`, `checkout`, `pull`, `stash`) is a real-terminal step.
This is why `tools/ship.py --execute` is a Mac step, and why the
session-closing skill writes a commit plan and hands over the commands rather
than running them.

To clear locks after one appears:

```
rm -f .git/index.lock .git/HEAD.lock .git/refs/heads/main.lock
```

The parked directory can go too, once nothing is holding it:

```
rm -rf .git/_stale_locks .git/__probe .git/_stale_lock_2
```

**None of this constrains autonomous cloud work.** A cloud session clones the
repository into its own container over HTTPS and works there with full
permissions on its own copy. It never touches the mounted folder and never
meets this lock.

Files on their way out of the working tree are moved to a `_to_delete/`
directory (gitignored) and removed by hand, for the same reason.

## The checks, and what each actually proves

| Check | Proves | Does not prove |
|---|---|---|
| `tools/check_required_contexts.py` (CI, `tools` job) | `ci.yml`'s job names and `protect_main.json`'s required contexts agree | That either matches the **applied** ruleset — that is a copy, and it was last edited in the web interface on 2026-09-08 |
| `tools/github_state.py` (Mac, by hand) | The applied ruleset matches the committed copy | Nothing about a moment other than its `read_at` |
| `tools/suite_figures.py --check` (CI, `test` job) | `testing-setup.md`'s stated suite size matches the run | That the suite covers anything in particular |
| `tools/check_citations.py` (by hand, advisory) | Where a note cites a line number | Whether the cited line says what the note claims |
| `tools/check_dco.py` (CI, `dco` job) | Every commit a pull request adds is signed off | Anything about the 33 legacy commits it deliberately does not reach |

## Related

- [`push-runbook.md`](push-runbook.md) — the day-to-day commit and ship process
- [`pipeline-design.md`](pipeline-design.md) §6 prerequisites, §7 open decisions
- [ADR 0019](adr/0019-dco-sign-off-on-automated-commits.md) and
  [ADR 0020](adr/0020-review-authority-and-the-merge-gate.md) — who signs and
  who merges, which is what any autonomous pipeline has to satisfy
