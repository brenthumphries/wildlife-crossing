---
title: "0019 — DCO Sign-off on Machine-Written Commits"
date: 2026-09-05
status: accepted
---

## Context

[`pipeline-design`](../pipeline-design.md) moves the write side of development
into GitHub Actions: Claude Code runs on a runner, commits to a branch, and
opens a pull request, with no human at a keyboard at commit time. That design
exists because `origin` is SSH, the Cowork mount has no keys, and
`tools/ship.py --execute` refuses to run over the mount — so today every commit
ends at the product owner's terminal, and nothing unattended is possible.

Moving commits to a runner collides with the DCO gate.
[`CONTRIBUTING.md`](../../CONTRIBUTING.md) requires a `Signed-off-by` trailer on
every commit, and `tools/check_dco.py` fails any pull request commit lacking a
trailer whose email matches the commit author's. A `claude-code-action` run
supplies neither by default, so **every automated pull request would be red on
arrival**, and the pipeline cannot exist until this is settled.

[ADR 0017](0017-licensing.md) makes this more than plumbing. With a DCO and no
CLA, the first merged outside contribution is the point of no return on the
licensing model, and the sign-off is the only record that the contributor had
the right to submit the work. `check_dco.py`'s own docstring puts it plainly: a
trailer naming somebody other than the author "makes the attestation
decorative."

Three facts constrain the answer.

1. **The DCO certifies provenance and the right to submit — not authorship of
   every line, and not review.** Clause (a) asks whether the contribution was
   created in whole or in part by the signer and whether the signer has the
   right to submit it under the project's licence. It asks nothing about
   whether the signer has read the diff or believes the code is good.

2. **Machine-generated output carries no third-party rights to infringe.**
   [ADR 0017](0017-licensing.md) §"The AI-authorship consideration" records that
   US law requires human authorship for copyright, that the Copyright Office's
   January 2025 report held purely machine-generated output uncopyrightable, and
   that only the human contribution in a mixed work is protectable. The
   consequence there was that an unknown fraction of this codebase carries thin
   or no copyright. The consequence *here* is the useful mirror image: there is
   no other rights-holder whose permission is needed to submit it. The "right to
   submit" half of clause (a) is cleaner for this material than for a human
   contribution, not murkier.

3. **`check_dco.py` compares the trailer's email only to the author's.** It
   therefore *passes* a bot that authors and signs as itself — mechanically
   green, certifying nothing, which is exactly the failure the script was
   written to prevent. The check cannot distinguish this case; only a decision
   can.

## Decision

**Commits written by the pipeline are authored by and signed off by Brent
Humphries `<brent.humphries@gmail.com>`, with a `Co-Authored-By: Claude`
trailer recording that the work was machine-written.**

The sign-off is truthful at the moment it is written because provenance is a
fact about *how the work is produced*, which the product owner controls by
construction: the pipeline may only touch this repository, and the material
that could break the claim — a vendored dependency, asset, font or addon — is
on the `auto:forbidden` list in [`pipeline-design`](../pipeline-design.md) §7.2
and already forbidden without a `THIRD-PARTY-NOTICES.md` entry by the root
[`CLAUDE.md`](../../CLAUDE.md). An attestation of provenance can be made in
advance. An attestation of quality could not, and the DCO does not ask for one.

Two alternatives were considered and rejected:

- **A distinct bot identity signing as itself.** Honest in the log, but a
  non-human certifies nothing under the DCO, and the check would pass it while
  it means nothing. Rejected on ADR 0017's own reasoning: a decorative
  attestation is worse than none.
- **No sign-off on the branch; the trailer added by the product owner in the
  squash-merge message.** The most honest record — the attestation lands at the
  moment of actual approval — and it remains the fallback if the reasoning above
  is ever doubted. Rejected for now on cost: it requires exempting `feat/**`
  pull-request commits from the `dco` job, which weakens the check for exactly
  the pull requests it now matters most for, and it needs a replacement
  main-push check scoped past the 33 unsigned legacy commits that
  `check_dco.py` deliberately does not reach.

## Consequences

### Positive

- `check_dco.py` and the `dco` job are unchanged. No exemption, no second check,
  no path where the gate is weakened for automated work.
- The record names a human who can certify, which is what the DCO is for.
- `Co-Authored-By: Claude` keeps the log honest about what wrote the code, so
  the attestation and the provenance are both legible and do not have to be
  carried by the same line.
- The reasoning is written down before the first automated commit rather than
  reconstructed after one, which is the position ADR 0017 was written to avoid.

### Negative / Trade-offs

- **The trailer is timestamped before the product owner has read the work.**
  This is the honest objection to the decision and it is not dissolved by the
  reasoning above — only narrowed to the claim the DCO actually makes. Anyone
  auditing the history will see an attestation predating the review.
- The decision leans on ADR 0017's lay reading of US copyright law, which that
  ADR itself flags as warranting a lawyer if the project acquires commercial
  stakes. If that reading is wrong, this ADR is wrong with it.
- It depends on a guardrail holding. If the `auto:forbidden` list is ever
  relaxed to let the pipeline vendor third-party material, the advance
  attestation stops being truthful and this ADR must be revisited in the same
  change.

### Neutral / Follow-on work

- Branch protection on `main` ([`pipeline-design`](../pipeline-design.md) §6.5)
  is load-bearing here: nothing signed in advance enters the project without
  the product owner's merge. Removing branch protection would change what this
  decision means.
- The workflow must set `user.name`, `user.email` and the trailers explicitly;
  a runner's default identity satisfies none of this.
- `CONTRIBUTING.md` is unchanged and still correct for outside contributors —
  its requirement that the name and email be real and match the git author is
  exactly what this decision honours. A pointer to this ADR from its DCO
  section would help a contributor who notices machine-written commits in the
  log and wonders how they were certified.
- If the timestamp objection ever outweighs the cost, the rejected merge-time
  alternative above is the migration path, and it does not invalidate commits
  already signed under this ADR.
