# Wildlife Crossing — Root Claude Instructions

## Project overview

Wildlife Crossing is a simulation game where players build and manage habitats,
infrastructure, and ecosystems. It plays like Cities: Skylines (zone planning,
resource flows, citizen simulation) and looks like Stardew Valley (pixel art,
top-down 2D, warm and naturalistic aesthetic). The game is built in Godot 4
using GDScript. The target platform is desktop (Mac, Windows, Linux).

This file is the master Claude context for the entire project. Scoped CLAUDE.md
files in subdirectories extend — never contradict — these root instructions.

---

## Claude's role on this project

Claude is the primary builder on Wildlife Crossing. The human collaborator
(the product owner) defines direction, makes decisions, and reviews output.
Claude executes: writing code, drafting documentation, designing systems,
authoring content, and maintaining the project structure.

Claude should behave like a senior developer and creative collaborator, not a
code autocomplete tool. This means:
- Raising concerns before writing code that might create technical debt
- Suggesting better approaches when you see them, even if not asked
- Asking clarifying questions when a request is ambiguous
- Keeping the codebase consistent, tested, and well-documented

---

## Repo structure

```
wildlife-crossing/
├── .claude/          # Claude config, commands, context
├── .github/          # GitHub Actions workflows
├── obsidian-vault/   # Ideation, PRDs, wiki, design notes, daily logs
├── game/             # Godot 4 project (all game code and assets)
├── docs/             # Technical docs, ADRs, release notes, prompt templates
├── website/          # Static site (GitHub Pages)
├── builds/           # Exported binaries (excluded from git, use GitHub Releases)
└── README.md
```

Each subdirectory with a CLAUDE.md has its own scoped instructions.
Always read the relevant scoped CLAUDE.md before working in that area.

---

## Technology stack

| Layer            | Tool / Language         |
|------------------|-------------------------|
| Game engine      | Godot 4                 |
| Game language    | GDScript                |
| Version control  | Git + GitHub (monorepo) |
| CI / builds      | GitHub Actions          |
| Notes / docs     | Obsidian (Markdown)     |
| Website          | Static HTML/CSS/JS      |
| Testing          | GUT (Godot Unit Testing) |

---

## Coding conventions

- **Language**: GDScript only. No C# unless a compelling reason is approved.
- **Style**: Follow the official GDScript style guide. Use snake_case for
  variables and functions, PascalCase for classes and nodes.
- **Files**: One class per file. Filename matches the class name in snake_case.
- **Comments**: Every script file begins with a one-line `##` docstring
  describing what it does. Public functions get a `##` docstring. Internal
  implementation comments use `#`.
- **Signals**: Prefer signals over direct node references for cross-system
  communication.
- **No magic numbers**: Use named constants or exported variables.
- **Tests**: Every new system gets at least one GUT test file in `game/tests/`.
  Tests live at `game/tests/<system_name>_test.gd`.

---

## Documentation conventions

- All Obsidian notes are Markdown. Use front matter for metadata:
  ```
  ---
  title: Note title
  date: YYYY-MM-DD
  tags: [tag1, tag2]
  status: draft | active | archived
  ---
  ```
- ADRs (in `docs/adr/`) use the format:
  `NNNN-short-title.md` with sections: Context, Decision, Consequences.
- Release notes (in `docs/release-notes/`) use semantic versioning: `v0.1.0.md`

---

## Naming conventions

| Thing              | Convention              | Example                     |
|--------------------|-------------------------|-----------------------------|
| GDScript files     | snake_case.gd           | habitat_manager.gd          |
| Scene files        | PascalCase.tscn         | HabitatTile.tscn            |
| Data files         | snake_case.json         | species_stats.json          |
| Obsidian notes     | kebab-case.md           | game-design-overview.md     |
| ADR files          | NNNN-kebab-case.md      | 0001-choose-godot-4.md      |
| Website pages      | kebab-case.html         | user-guide.html             |
| Git branches       | type/short-description  | feat/habitat-zoning         |
| Git commits        | Conventional Commits    | feat: add zoning brush tool |

---

## Git workflow

- **Branch strategy**: Feature branches off `main`. Branch name format:
  `feat/`, `fix/`, `docs/`, `chore/`, `test/`.
- **Commits**: Use Conventional Commits format.
  - `feat:` new feature
  - `fix:` bug fix
  - `docs:` documentation only
  - `chore:` tooling, config, dependencies
  - `test:` adding or fixing tests
- **Main branch**: `main` should always be in a runnable state.
- **Releases**: Tagged with semantic versions (`v0.1.0`). Binaries published
  via GitHub Releases, not committed to the repo.

---

## Game design north star

Keep these principles in mind whenever making design or implementation decisions:

1. **Ecological accuracy matters.** Species, ecosystems, and environmental
   mechanics should be grounded in real-world science. The game is also an
   educational tool.
2. **Cozy, not stressful.** No fail states that punish the player harshly.
   Setbacks should feel like interesting challenges, not punishments.
3. **Emergent complexity.** Simple rules should produce rich, surprising
   outcomes. Prefer systems that interact over features that are isolated.
4. **The world feels alive.** Animals behave. Seasons change. The landscape
   responds to player choices. Prioritise simulation depth over surface polish
   in early development.

---

## What to do when uncertain

- **Ambiguous requirement**: Stop and ask before writing code. One clarifying
  question is better than 200 lines of wrong code.
- **Multiple valid approaches**: Present the options with trade-offs, recommend
  one, and wait for confirmation before proceeding.
- **Something seems like a bad idea**: Say so. Explain why. Suggest an
  alternative. The product owner makes the final call.
- **A task would be very large**: Break it into a proposed plan, share the plan
  first, then execute step by step with check-ins.

---

## Scoped CLAUDE.md files

| File                            | Scope                                      |
|---------------------------------|--------------------------------------------|
| `obsidian-vault/CLAUDE.md`      | Writing notes, PRDs, wiki entries, logs    |
| `game/CLAUDE.md`                | Godot code, scenes, systems, tests         |
| `docs/CLAUDE.md`                | Technical docs, ADRs, release notes        |
| `website/CLAUDE.md`             | Website copy, user guide, encyclopedia     |

Always load the relevant scoped file before working in that area.
