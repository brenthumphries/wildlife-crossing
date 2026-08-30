# Wildlife Crossing

A cozy ecosystem simulation game. Build habitats, manage wildlife corridors,
and help species thrive across a living, breathing landscape.

**Engine**: Godot 4 · **Language**: GDScript · **Style**: Pixel art, top-down 2D

## Project structure

| Folder            | Purpose                                         |
|-------------------|-------------------------------------------------|
| `.claude/`        | Claude AI configuration, commands, context      |
| `.github/`        | GitHub Actions workflows (CI, website deploy)   |
| `obsidian-vault/` | Design notes, PRDs, wiki, daily logs            |
| `game/`           | Godot project (code, scenes, assets)            |
| `docs/`           | Technical docs, ADRs, release notes             |
| `website/`        | Static site and user-facing documentation       |
| `builds/`         | Exported binaries (see GitHub Releases)         |
| `tools/`          | Build, test and release scripts, plus tests     |
| `harness/`        | The skill that writes the weekly build reviews  |

## Development

This project is built with Claude as the primary developer.
See [`CLAUDE.md`](CLAUDE.md) for full context and conventions.

## License

Wildlife Crossing is free and open. Code and non-code material are licensed
separately, because the two need different terms.

| What | License | File |
|------|---------|------|
| Source code (`.gd`, `.tscn`, `.cfg`, `.html`, `.css`, `.js`) and released binaries | MIT | [`LICENSE`](LICENSE) |
| Art, audio, game data, design notes, docs, website copy | CC0 1.0 (public domain) | [`LICENSE-ASSETS`](LICENSE-ASSETS) |
| Third-party components | their own terms | [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) |

Copyright © 2026 Brent Humphries.

In short: **do what you like with any of it.** Fork the code, ship the sprites
in your own game, lift the simulation design. The code asks only that you keep
the MIT notice; the assets and writing ask nothing at all.

Two things are not granted:

- **The name and branding.** "Wildlife Crossing" and the project logo are not
  licensed for derivative works — CC0 explicitly does not waive trademark
  (section 4(a)), and MIT is silent on it. Fork freely, but call it something
  else.
- **Third-party material.** Anything under `game/addons/`, and any third-party
  art or fonts added to `game/assets/` later, stays under its original license.
  `LICENSE-ASSETS` covers original work only.

### Attributions in the game

The game ships its own **Credits & Licences** screen — from the title menu, or
`F1` during play. It lists every third-party component and reproduces every
licence in full, generated at runtime from the engine rather than hand-written,
so it can't go stale on a version bump.

### If you redistribute a build

Exported binaries statically include the Godot engine, which is MIT and requires
its notice to travel with every copy. The credits screen carries that notice
inside the binary; `LICENSE` and `THIRD-PARTY-NOTICES.md` ship alongside the
executable as a second copy, and release archives from CI already contain both.

Reasoning behind these choices is recorded in
[ADR 0017](docs/adr/0017-licensing.md).

## Verifying a download

Every release ships a `SHA256SUMS.txt` covering all platforms, with a detached
OpenPGP signature. One signature covers every artifact, so verifying a download
is two commands rather than six.

Releases are signed with this key:

```
Brent Humphries <brent.humphries@gmail.com>
ed25519  7F68 A7E0 6349 DA13 6226 F04E 2D5F 1ED6 EFFC 08FD
```

The public key is in this repository as
[`wildlife-crossing-signing-key.asc`](wildlife-crossing-signing-key.asc) and on
the [keys.openpgp.org](https://keys.openpgp.org/search?q=7F68A7E06349DA136226F04E2D5F1ED6EFFC08FD)
keyserver. Prefer the keyserver: a key delivered over the same channel as the
file it signs proves very little.

```bash
gpg --keyserver keys.openpgp.org --recv-keys 7F68A7E06349DA136226F04E2D5F1ED6EFFC08FD
```

Then, with `SHA256SUMS.txt`, `SHA256SUMS.txt.asc` and the build you downloaded
in the same directory:

```bash
gpg --verify SHA256SUMS.txt.asc SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt
```

The first proves the manifest was signed with the key above; the second proves
the files match the manifest. Both must pass.

## Contributing

Contributions are welcome. Commits must be signed off under the
[Developer Certificate of Origin](https://developercertificate.org/)
(`git commit -s`), and contributions are made under the same licenses as the
files they touch — MIT for code, CC0 for everything else.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, conventions, and the full
terms.
