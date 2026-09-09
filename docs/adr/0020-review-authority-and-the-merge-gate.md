---
title: "0020 — Review Authority and the Merge Gate"
date: 2026-09-09
status: accepted
---

## Context

The intended way of working is parallel: a daily review of the work queue picks
items that can run independently, agents build them on their own branches, and
at the end of the day the product owner reviews what came back and selects what
goes into `main`. Selected work then merges without further attention. The same
route is meant to carry work by other people, and work by agents not operating
under the product owner's direction.

`allow_auto_merge` was enabled on the repository on 2026-09-08 on the
assumption that it implements this. It does not, and the gap is the subject of
this record.

**Auto-merge answers "when", never "who".** It waits for every required status
check, the up-to-date-branch requirement and any required reviews, then merges.
It cannot bypass ruleset `22403399`. But it is a per-pull-request action
available to anyone with write access, not a policy about whose approval is
needed. Today every enable is the product owner's by construction, because he
is the only account with write access. That is a property of the current
membership, not of the configuration.

**The configuration has no review gate at all.** Ruleset `22403399` sets
`required_approving_review_count: 0`, `require_code_owner_review: false` and
`require_last_push_approval: false`, and the repository has no `CODEOWNERS`
file. [`pipeline-design`](../pipeline-design.md) §S6b describes the product
owner reading the brief, skimming the diff and merging, and
[ADR 0019](0019-dco-sign-off-on-automated-commits.md) states under Follow-on
work that "nothing signed in advance enters the project without the product
owner's merge." Both describe a habit that nothing enforces. The moment a
second writer exists, a contributor can open a pull request, enable auto-merge
on it themselves, and land it green with no product-owner involvement.

**Two narrower holes follow from the same absence.** With
`dismiss_stale_reviews_on_push: false` and `require_last_push_approval: false`,
an approval survives later pushes, so under auto-merge a contributor can be
approved and then push commits that land on the earlier approval. And
`allowed_merge_methods` is `["merge"]` only, which matters below.

**The obvious fix is blocked by ADR 0019.** The control that makes "the product
owner decides what merges" a rule is a required approving review from a code
owner. GitHub does not permit an author to approve their own pull request, and
ADR 0019 decides that pipeline commits are **authored by Brent Humphries**,
with `Co-Authored-By: Claude` recording the machine. So every automated pull
request arrives with the product owner as its author, he cannot approve it, and
a required review can never gate automated work while that authorship decision
stands. `required_approving_review_count` is 0 today for the related reason
recorded on 2026-09-06: on a sole-author repository a 1 makes every pull
request unmergeable.

**A second personal account for reviewing was considered and is not available.**
GitHub's Terms of Service state that "One person or legal entity may maintain no
more than one free Account (if you choose to control a machine account as well,
that's fine, but it can only be used for running a machine)," and that accounts
registered by bots or other automated methods are not permitted. The machine
carve-out is scoped to running a machine and does not cover a person approving
their own work through a second identity. The policy is not the deciding
objection. An approval from an account the author controls certifies nothing
the author's own judgment did not already certify, so it satisfies the rule
while making its guarantee false. That is the failure ADR 0019 already refused
one layer down, when it rejected a bot identity signing the DCO as itself
because a non-human certifies nothing and the check "would pass it while it
means nothing", on [ADR 0017](0017-licensing.md)'s reasoning that a decorative
attestation is worse than none. The same reasoning forbids it here.

## Decision

### D1. The pipeline gets its own machine account, and authors its own commits

Automated pull requests are authored by a machine account controlled by the
product owner, not by the product owner's personal identity. This is the
account type GitHub's terms contemplate for running automation, and it is one
account rather than a second person.

The product owner then stands outside every automated pull request as a genuine
third party, which is what makes a required review meaningful rather than
ceremonial.

Rejected: a second personal account for the product owner, for the reasons in
Context. Rejected: leaving authorship as ADR 0019 has it and enforcing review
by convention, which is the status quo whose only guarantee is memory.

### D2. ADR 0019 migrates to merge-time attestation

D1 removes the human author that ADR 0019's sign-off depends on, so the DCO
attestation moves to the moment of merge, where the product owner makes it
after reading the work. This is the migration path ADR 0019 named for itself in
its rejected alternatives and in its final Follow-on line, and adopting it does
not invalidate commits already signed under ADR 0019.

Three costs come with it, all of them already identified in ADR 0019 or
discovered here:

1. **The `dco` job must stop requiring a trailer on machine-authored branch
   commits**, which weakens the check for exactly the pull requests it matters
   most for, and it needs a replacement check on the `main` push scoped past
   the 33 unsigned legacy commits that `check_dco.py` deliberately does not
   reach.
2. **ADR 0019's stated fallback does not fit the current ruleset.** It puts the
   trailer in the squash-merge message, and `allowed_merge_methods` on
   ruleset `22403399` is `["merge"]` only. Either the trailer goes in the merge
   commit body, or squash becomes an allowed method for pipeline pull requests.
   The first is preferable: allowing squash reopens the question ADR 0019's
   predecessor settled about what a merge commit records.
3. **The attestation stops being machine-checkable at the branch level.** It
   becomes a thing the merging human does, which is more honest and less
   automatic.

### D3. Self-authored pull requests are gated by checks alone, and that is written down

No configuration makes self-review meaningful. Pull requests the product owner
writes by hand are gated by the five required status checks and by nothing
else, and this record says so rather than disguising it with an approval that
certifies nothing.

This is a residue, not a design goal. It shrinks as the intended way of working
takes hold, because under it the product owner authors little and reviews much.
Where a self-authored change is significant enough to want a second read, the
answer is a human or an agent leaving a review as a comment, understood as
advisory, never as a required approval whose independence is fictional.

Rejected: requiring one approval on all pull requests, which under D1 would
still leave the product owner's own work unmergeable without a second person.
Rejected: adding the product owner as a ruleset bypass actor for his own pull
requests, which reintroduces the bypass that the 2026-09-06 decision removed
deliberately and would apply to far more than this case.

## Consequences

### Positive

- "The product owner decides what merges" becomes enforced by GitHub rather
  than remembered. `pipeline-design` §S6b and ADR 0019's Follow-on claim become
  true statements about the configuration.
- Auto-merge becomes the correct executor of the intended way of working:
  contributors and agents open pull requests, the product owner approves the
  ones he wants at the end-of-day review, and each lands when its checks go
  green without further attention.
- Work by other people needs no special handling. They author, he reviews, the
  same gate applies.
- The DCO attestation lands after the work has been read, which answers ADR
  0019's own stated negative that "the trailer is timestamped before the
  product owner has read the work."

### Negative / Trade-offs

- The `dco` gate is weakened for automated branch commits, per D2 cost 1. This
  is the cost ADR 0019 declined to pay in September and it has not become
  cheaper, only better justified.
- More moving parts: an account to hold, credentials to rotate, and a second
  identity in the commit log that a reader has to understand. `CONTRIBUTING.md`
  and ADR 0019 both need pointers so the history stays legible.
- The product owner's own hand-written work gets no review gate at all, by D3.
  Stated plainly rather than solved.

### Neutral / Follow-on work

- **Configuration changes, to land before the first non-product-owner writer
  gets access, not after.** A `CODEOWNERS` file naming the product owner;
  `required_approving_review_count: 1`; `require_code_owner_review: true`; and
  `require_last_push_approval: true`, which is the precise fix for approval
  followed by a further push under auto-merge. `dismiss_stale_reviews_on_push`
  is the blunter version of the same protection and is worth setting too.
  `.github/rulesets/protect_main.json` is the file, and it is applied with
  `gh api --method POST ... --input`.
- `allow_auto_merge` stays `true`. It weakens nothing, and D1 through D3 are
  what make it safe to rely on.
- **Nothing here is verified until a check goes red under it.** Ruleset
  `22403399` has admitted eight pull requests and refused none, and the review
  requirements above will be equally unexercised on the day they are set.
- The machine account's write access should be scoped to what the pipeline
  needs, and it must not be able to approve pull requests, or D1's separation
  collapses from the other direction.
- If the pipeline is never built, D1 and D2 can be deferred, but the
  configuration changes above still apply the moment another person gets write
  access. D3 applies today.

## Related

- [ADR 0019](0019-dco-sign-off-on-automated-commits.md), whose Decision this
  supersedes if D2 is accepted.
- [ADR 0017](0017-licensing.md), for the decorative-attestation reasoning.
- [pipeline-design](../pipeline-design.md) §6.5, §7.1, §S6b.
- [GitHub Terms of Service](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service),
  Account Terms, read 2026-09-09.
