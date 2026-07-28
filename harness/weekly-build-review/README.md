# weekly-build-review — harness

A standalone Claude skill that runs a weekly build review of Wildlife Crossing
and writes a dated Obsidian note listing the work needed for the next working
build (or the first working build, if none exists yet).

## Install

Move this folder into your Claude skills directory so Claude auto-discovers it:

```
mv harness/weekly-build-review .claude/skills/weekly-build-review
```

(It lives under `harness/` only because `.claude/` was write-protected when it
was generated. The skill itself is unchanged by the location.)

## Files

- `SKILL.md` — the harness: model (Opus), procedure, subagent/`/goal`/`/loop`
  usage, and output spec.
- `references/inspection-checklist.md` — brief for the Step 1 inventory subagent.
- `references/note-template.md` — structure of the review note.

## Run

- On demand: "Run the weekly-build-review for Wildlife Crossing" (uses Opus).
- Weekly: create a scheduled task with that same prompt (e.g. Monday 07:00).

Output lands in `obsidian-vault/build-reviews/YYYY-MM-DD-next-build.md` and the
index in that folder's `README.md` is updated.
