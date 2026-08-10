# Contributing to Wildlife Crossing

Thanks for your interest. Wildlife Crossing is a cozy ecosystem simulation
built in Godot 4 with GDScript. It's free and open — see [Licensing](#licensing)
below for what that means for your contribution.

This is a small project. Please open an issue before writing anything
substantial, so you don't spend an evening on something that turns out to
conflict with a design decision recorded in [`docs/adr/`](docs/adr/).

---

## Licensing

**Inbound equals outbound.** Whatever license applies to a file is the license
your contribution to it is made under. There is no CLA and no copyright
assignment — you keep your copyright.

| What you're changing | License your contribution is made under |
|----------------------|------------------------------------------|
| Source code — `.gd`, `.tscn`, `.cfg`, `.html`, `.css`, `.js` | MIT ([`LICENSE`](LICENSE)) |
| Everything else — art, audio, `game/data/`, `obsidian-vault/`, `docs/`, website copy | CC0 1.0 ([`LICENSE-ASSETS`](LICENSE-ASSETS)) |

Please read that second row carefully before contributing art, audio, or
writing. **CC0 is a public-domain dedication, not just a permissive license.**
You are waiving your copyright in that material worldwide, irrevocably, and
anyone may use it for anything — commercially, without credit, without asking.
That is deliberate: the project's assets are meant to be a resource other
developers can take freely. But it is a bigger step than MIT, and it cannot be
undone once merged. If you aren't comfortable with it, contribute code instead.

Contributions of **third-party material** have an extra requirement — see
[Third-party material](#third-party-material) below.

---

## Developer Certificate of Origin

Every commit must be signed off. The sign-off is your statement that you have
the right to submit the work under the licenses above. It is the
[Developer Certificate of Origin 1.1](https://developercertificate.org/), the
same mechanism the Linux kernel and Godot itself use.

### Signing off

Add `-s` to your commit:

```bash
git commit -s -m "feat: add wolf pack territory behaviour"
```

That appends a trailer to the commit message:

```
Signed-off-by: Random J Developer <random@developer.example.org>
```

The name and email must be your real ones and must match your git author
identity. Anonymous and pseudonymous contributions can't be accepted, because
the certificate is meaningless without an identifiable person behind it.

To sign off automatically for this repository:

```bash
git config format.signOff true
```

### If you forgot

For the most recent commit:

```bash
git commit --amend -s --no-edit
```

For several commits on your branch:

```bash
git rebase --signoff main
```

Then force-push your branch. Don't open a second PR — amending is fine and
expected.

### The certificate

By signing off, you certify the following:

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

Where the DCO says "the open source license indicated in the file", read the
table in [Licensing](#licensing) above: MIT for code, CC0 for everything else.

Note clause (d) in particular — your name and email in the sign-off become a
permanent part of the public git history.

---

## AI-assisted contributions

This project is itself built largely with AI assistance, so AI-assisted
contributions are welcome. Two things are asked of you.

**Disclose substantial AI generation** in the pull request description. A
sentence is enough. This isn't a judgement; it's so the reviewer knows what kind
of review the change needs.

**The DCO still applies unchanged.** Clause (a) requires that you have the right
to submit the work. Running a prompt does not by itself give you rights you
didn't have — if a tool reproduced someone else's licensed code, signing off on
it is a false certification regardless of how it reached your editor. Review
what you submit.

Be aware that under current US law, purely machine-generated material may carry
no copyright at all, so parts of what you submit may be unprotectable rather
than licensed. This doesn't block anything under MIT or CC0. It's discussed in
[ADR 0017](docs/adr/0017-licensing.md).

---

## Third-party material

**Never vendor a dependency, addon, font, asset, or audio file without adding an
entry to [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).** The entry must
state the license and whether the export presets exclude the material from
shipped binaries.

Two rules that are not negotiable:

- **Don't reproduce a license or copyright line from memory.** Copy it from the
  vendored file, or fetch it from upstream. An invented copyright holder is
  worse than no notice at all.
- **Flag anything that isn't MIT, BSD, Apache-2.0, CC0, CC BY, or OFL** in your
  PR rather than merging it. Copyleft and non-commercial terms are a decision
  for the project owner, not a default.

Note that `LICENSE-ASSETS` covers original work only. Third-party art dropped
into `game/assets/` is **not** CC0 and must not be presented as such.

---

## Development setup

Versions are pinned by [ADR 0012](docs/adr/0012-godot-and-gut-version-pin.md) —
**Godot 4.6.3-stable** and **GUT 9.6.0**, the latter vendored at
`game/addons/gut/`. Use the pinned patch release, not just the 4.6 series;
export-template directories are version-keyed and drift has caused a
misdiagnosis before.

Full instructions are in [`docs/testing-setup.md`](docs/testing-setup.md). The
short version, from the `game/` directory:

```bash
godot --headless --import          # first run only: builds the .godot resource cache
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Substitute your local binary path for `godot` if it isn't on your `PATH` (for
example `../tools/godot/Godot_v4.6.3-stable_linux.arm64`).

**A warning about green runs.** GUT exits `0` when it collects zero tests and
prints `Nothing was run`. A broken discovery config therefore looks identical to
a passing suite at the exit-code level. CI guards against this, but locally you
should read the summary and confirm your tests actually ran.

---

## Code conventions

The full set lives in [`CLAUDE.md`](CLAUDE.md) and the scoped `CLAUDE.md` files
in each directory. The essentials:

- **GDScript only.** No C# without prior discussion.
- Follow the official GDScript style guide. `snake_case` for variables and
  functions, `PascalCase` for classes and nodes.
- One class per file; the filename is the class name in `snake_case`.
- Every script starts with a one-line `##` docstring. Public functions get a
  `##` docstring. Internal comments use `#`.
- Prefer signals over direct node references for cross-system communication.
- No magic numbers — use named constants or exported variables.
- **Every new system needs at least one GUT test** at
  `game/tests/<system_name>_test.gd`.
- Don't add SPDX headers or copyright banners to `.gd` files. The root
  `LICENSE` covers the tree.

### Naming

| Thing | Convention | Example |
|-------|------------|---------|
| GDScript files | `snake_case.gd` | `habitat_manager.gd` |
| Scene files | `PascalCase.tscn` | `HabitatTile.tscn` |
| Data files | `snake_case.json` | `species_stats.json` |
| Obsidian notes | `kebab-case.md` | `game-design-overview.md` |
| ADR files | `NNNN-kebab-case.md` | `0001-choose-godot-4.md` |
| Branches | `type/short-description` | `feat/habitat-zoning` |

### Commits and branches

Branch off `main` using `feat/`, `fix/`, `docs/`, `chore/` or `test/`.
Commit messages use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add zoning brush tool
fix: correct carrying-capacity decay on winter rollover
docs: clarify span geometry in ADR 0016
```

`main` must always be in a runnable state.

---

## Design decisions need an ADR

If your change makes a decision that future contributors would otherwise have to
reverse-engineer — a data format, a topology, a simulation formula, a trade-off
between two workable approaches — add an ADR in [`docs/adr/`](docs/adr/) as part
of the same PR. Use the next number in sequence and follow the existing format:
front matter, then Context, Decision, Consequences.

[ADR 0016](docs/adr/0016-crossing-span-geometry.md) is a good model. Record the
options you rejected and why, not just the one you chose.

---

## Pull request checklist

- [ ] Every commit is signed off (`git commit -s`)
- [ ] Tests added or updated; the suite passes and actually collected tests
- [ ] New third-party material has a `THIRD-PARTY-NOTICES.md` entry
- [ ] Substantial AI generation disclosed in the description
- [ ] An ADR added if the change makes a design decision
- [ ] Commit messages follow Conventional Commits
- [ ] The change fits the design north star below

---

## Design north star

Changes are evaluated against these. A technically excellent PR that cuts
against them will still be turned down, so it's worth reading before you start:

1. **Ecological accuracy matters.** Species, ecosystems, and environmental
   mechanics should be grounded in real science. The game is also an
   educational tool.
2. **Cozy, not stressful.** No fail states that punish the player harshly.
   Setbacks should be interesting challenges, not punishments.
3. **Emergent complexity.** Simple rules producing rich outcomes. Prefer
   systems that interact over features that stand alone.
4. **The world feels alive.** Simulation depth beats surface polish in early
   development.

---

## Questions

Open an issue. For anything about licensing specifically, start with
[ADR 0017](docs/adr/0017-licensing.md), which records the reasoning behind the
MIT/CC0 split.
