---
title: "0017 — Licensing: MIT for Code, CC0 for Everything Else"
date: 2026-08-09
status: accepted
---

## Context

The repository has been private to date and carries no licence file. Making it
public without one is the worst of both worlds: under the Berne Convention the
work is automatically copyrighted with all rights reserved, so nobody may
legally fork, build, or redistribute it — while the source is nonetheless
readable by everyone. A public repo with no LICENSE is not "open source"; it is
a published work that no one is permitted to use.

The product owner's intent is that Wildlife Crossing be **free forever and
fully open**. There is no plan to charge for the game or to reserve commercial
rights.

Four distinct legal objects need covering, and they do not want the same
treatment:

1. **Source code** — 126 `.gd` files, 24 `.tscn` scenes, project config.
2. **Original non-code material** — `game/assets/` (currently near-empty:
   `crossing_cue.png` and a handful of SVGs), `game/data/` authored JSON,
   `obsidian-vault/`, `docs/`, `website/` copy.
3. **Third-party material** — GUT 9.6.0 vendored at `game/addons/gut/`, plus
   the fonts it bundles.
4. **Exported binaries** — Linux, Windows and macOS builds produced by
   `.github/workflows/ci.yml`. These are a *different* legal object from the
   repo, because Godot's export templates statically link the engine into the
   executable.

Object 4 creates an obligation that exists regardless of what licence this
project picks. Godot is MIT, and MIT requires its notice to appear "in all
copies or substantial portions of the Software". Every binary this project has
ever produced already carries that obligation and has not been satisfying it.

### Options considered for the code

**MIT.** Permissive. Anyone may fork, close-source, or sell. Matches what Godot
and GUT already use, so there is zero compatibility friction and no licence
matrix to reason about. It is also what a reader expects to find in a Godot game
repository.

**Apache-2.0.** MIT plus an explicit patent grant and a requirement that
modifiers state their changes. The patent grant is meaningful for corporate
contributors; this is a solo project with nothing patentable. It is rarer in
game repositories, so it reads as slightly foreign for no gain here.

**GPL-3.0.** Copyleft: derivatives must also be open. Rejected for three
reasons. First, it does not prevent someone selling the game — only closing it
— so it does not buy the thing people assume it buys. Second, console SDKs
(Switch, PlayStation) are under NDA and GPL-incompatible, so choosing it now
forecloses console ports later; and once outside contributions are accepted,
relicensing requires tracking down every contributor. Third and most decisive,
see below.

### The AI-authorship consideration

Per this project's root `CLAUDE.md`, Claude is the primary builder. US law
requires human authorship for copyright: the Copyright Office's January 2025
report on AI-generated material held that purely machine-generated output is not
copyrightable, and the Supreme Court declined to revisit the question in March
2026. Where a work mixes human and AI contribution, only the human contribution
is protectable.

The practical consequence is that an unknown fraction of this codebase may carry
thin or no copyright. That is close to harmless under a permissive licence,
which asks almost nothing of anyone and does not depend on enforcement. It is
actively corrosive under copyleft, whose entire mechanism *is* the copyright
holder's ability to enforce. Choosing GPL here would mean asserting a right that
may not fully exist.

### Options considered for non-code material

**Same licence as the code (MIT everywhere).** One file, no ambiguity. But MIT's
operative language — "the Software", "copies or substantial portions" — is
drafted for software, and the requirement to include the notice "in copies" is
awkward when the copy in question is a PNG or a design note.

**CC BY 4.0.** Drafted for creative works, permissive, requires attribution.
Attribution gives a foothold if someone lifts the work wholesale.

**CC0 1.0.** Public-domain dedication with a licence fallback for jurisdictions
that do not permit outright waiver. No attribution required at all. Chosen: it
is the most complete expression of "free forever, fully open", and matches the
norm for game assets intended for community reuse. The product owner accepts
that reusers owe nothing, not even credit.

## Decision

**Code and binaries: MIT.** Copyright holder `Brent Humphries`, year 2026. The
canonical MIT text goes in `LICENSE` at the repository root, verbatim, so that
GitHub's licence detection recognises it and surfaces the badge.

**All original non-code material: CC0 1.0 Universal**, in `LICENSE-ASSETS`,
with a header naming the covered and excluded paths, followed by the full CC0
legal text.

**Third-party components: `THIRD-PARTY-NOTICES.md`**, split into components that
ship inside binaries (Godot) and components that do not (GUT and its fonts,
excluded by `exclude_filter="addons/gut/*,tests/*"` on every export preset).

### Trademark is carved out explicitly

CC0 section 4(a) does not waive trademark or patent rights, and MIT is silent on
trademark. Both `LICENSE-ASSETS` and the README state that the name "Wildlife
Crossing" and the project branding are not licensed for derivative works.

This is where the real protection lives. The common objection to permissive
licensing — "someone will reskin my build and sell it" — is not answered by the
copyright licence, which deliberately permits exactly that. It is answered by
the fact that a fork may not call itself Wildlife Crossing. Given the game is
free, a paid fork has no advantage to sell anyway.

### Binaries must ship the notices

`THIRD-PARTY-NOTICES.md` and `LICENSE` are copied into each `builds/<platform>/`
directory before the artifact upload step in `ci.yml`, so that every release
archive carries them. This is a licence obligation, not a nicety.

**Amended 2026-08-09 — the credits screen now exists.** `CreditsScreen`
(`game/scripts/ui/credits_screen.gd`) renders every attribution and full licence
text from `Engine.get_copyright_info()` and `Engine.get_license_info()` at
runtime — 91 KB of document, 99 components, 19 licences on 4.6.3-stable. It is
reachable from the title menu and from `F1` during play.

This is now the primary compliance mechanism, because text rendered from inside
the binary cannot be separated from it. The copied loose files remain as a
second copy for distributors and packagers who never launch the game, and
because the macOS export is a `.zip` whose notices land outside the `.app`.

Adding the screen required a front end to hang it on, which moved the boot
scene — see the consequences below.

## Consequences

### Positive

- The repository can go public without leaving users in the legal limbo of an
  unlicensed public repo.
- Licence compatibility is trivial: MIT code depending on MIT engine and MIT
  test framework. No matrix, no analysis needed when adding dependencies.
- CC0 assets are directly reusable by other Godot developers, which suits a
  project whose north star includes being an educational tool.
- The Godot attribution obligation, previously unmet in every build produced so
  far, is now satisfied.

### Negative / Trade-offs

- Anyone may fork the code, close their fork, and sell it. This is the accepted
  cost of MIT and is mitigated only by trademark and by the game being free.
- CC0 assets may be used with no credit whatsoever. Once published, this cannot
  be walked back for any version already released.
- The decision is effectively one-way. Future work can be relicensed, but every
  commit published under MIT/CC0 stays available under those terms forever. If
  commercial intent ever changes, only *new* material can be reserved — and only
  if no outside contributions have been merged under the old terms.
- Because parts of the codebase may lack human authorship and therefore
  copyright, the MIT grant may be partly a formality over material that is
  already unprotectable. This costs nothing given the intent, but it means the
  licence should not be relied on as a control mechanism.

### Neutral / Follow-on work

- `game/export_presets.cfg`: `application/copyright` was empty on the Windows
  and macOS presets and is now populated. Godot writes this into the Windows
  resource block and the macOS `Info.plist`.
- `.github/workflows/ci.yml`: a step copying `LICENSE` and
  `THIRD-PARTY-NOTICES.md` into each build directory runs before
  `Upload build artifacts`.
- **Done 2026-08-09:** the credits screen, plus the minimal `MainMenu` and
  `TitleScreen` it needed as a home. `run/main_scene` is now
  `res://scenes/TitleScreen.tscn`; `Main.tscn` remains the playable root and
  `TitleScreen` changes into it.

  This nearly gutted `tools/smoke_boot.sh`. That gate asserts the exported
  binary logs `Tutorial loaded`, which is what makes it able to catch a build
  whose `data/*.json` never loaded (2026-07-28 build review). A title screen
  needs no data, so booting to a menu would have passed the gate on exactly the
  broken build it was written to catch. The fix is a `--skip-menu` user arg
  (`TitleScreen.SKIP_MENU_ARG`) that boots straight into `Main`: the smoke test
  now boots twice, bare to assert the menu renders and with the flag to assert
  the tutorial loads with real data. `main_menu_test.gd` pins both the flag
  string and the log line, so drift between script and game fails in the suite
  rather than only on a release run.
- **Decided 2026-08-09:** `CONTRIBUTING.md` adopts the
  [Developer Certificate of Origin 1.1](https://developercertificate.org/) on an
  inbound-equals-outbound basis — code contributions under MIT, non-code under
  CC0 — enforced by a `Signed-off-by` trailer on every commit. No CLA and no
  copyright assignment; contributors keep their copyright.

  Two limits worth stating plainly. First, **a DCO is an attestation of origin,
  not a grant of relicensing rights.** It does not give the project owner the
  power to relicense contributed material later; that would need a CLA, which
  raises the barrier to contribution and is not warranted for a free game.
  Combined with the one-way nature of the licence choice noted above, the
  practical effect is that the first merged outside contribution is the point of
  no return for the licensing model. Second, the sign-off is currently enforced
  by review only — no bot checks it. Worth adding a DCO check to `ci.yml` before
  the repo is announced publicly, since a missed sign-off is much cheaper to fix
  before merge than after.
- This ADR records a lay reading of the licences involved, not legal advice. If
  the project ever acquires commercial stakes, the trademark position and the
  AI-authorship question both warrant a lawyer.
