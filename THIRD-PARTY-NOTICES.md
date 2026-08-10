# Third-Party Notices

Wildlife Crossing incorporates third-party software. This file reproduces the
notices those components require. It is separate from `LICENSE` (which covers
Wildlife Crossing's own source code) and `LICENSE-ASSETS` (which covers this
project's original non-code material).

The MIT License requires its notice to be included "in all copies or
substantial portions of the Software", and the Godot engine is statically
linked into every exported executable.

**That obligation is discharged primarily by the in-game credits screen**
(`game/scripts/ui/credits_screen.gd`, reachable from the title menu or `F1`
in play), which renders every attribution and full licence text from inside the
binary and therefore cannot be separated from it.

This file is the second copy, and is still shipped beside every release by CI.
Keep it accurate: it is what a distributor, packager or reviewer reads without
launching the game.

---

## Components shipped inside released binaries

### Godot Engine 4.6.3-stable

Wildlife Crossing is built with Godot and exported using Godot's official
export templates. Each exported executable statically includes the engine.

Website: <https://godotengine.org>
License: MIT

```
Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

#### Godot's own third-party components

The Godot engine bundles further third-party libraries — among them FreeType,
Brotli, ENet, mbedTLS, miniupnpc, Thorvg and zlib — several of which carry
their own attribution requirements. Godot aggregates all of these in its
`COPYRIGHT.txt`, published with each release at
<https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt>.

Rather than duplicating that file (which changes between engine versions),
every Godot binary exposes it at runtime:

| Call | Returns |
|------|---------|
| `Engine.get_license_text()` | Godot's MIT licence text |
| `Engine.get_copyright_info()` | Per-component copyright and licence entries |
| `Engine.get_license_info()` | Full text of every bundled licence |

**This is what the credits screen does.** `CreditsScreen.build_document()`
generates the attribution and licence-text sections from these calls rather than
from a hand-maintained list, so it cannot drift when the engine is upgraded — on
4.6.3-stable that is 99 components across 19 distinct licences, which no
hand-written list would survive a version bump. `credits_screen_test.gd` asserts
both that the engine data still has the expected shape and that Godot's
copyright actually reaches the rendered output.

---

## Components used in development only

These are present in the repository but are **not** included in released
binaries. `game/export_presets.cfg` sets `exclude_filter="addons/gut/*,tests/*"`
on every preset, which keeps them out of the exported `.pck`.

If that exclude filter is ever removed, these notices move to the section above.

### GUT (Godot Unit Testing) 9.6.0

Vendored at `game/addons/gut/`. Used to run the test suite.

Website: <https://github.com/bitwes/Gut>
License: MIT — full text at `game/addons/gut/LICENSE.md`

```
Copyright (c) 2018 Tom "Butch" Wesley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Fonts bundled with GUT

GUT ships three typefaces used by its test-output panel, all under the SIL Open
Font License 1.1. Full text at `game/addons/gut/fonts/OFL.txt`.

```
Copyright (c) 2009, Mark Simonson (http://www.ms-studio.com, mark@marksimonson.com),
with Reserved Font Name Anonymous Pro.
```

The three families present are **Anonymous Pro**, **Courier Prime** and
**Lobster Two**. Note that GUT's bundled `OFL.txt` carries only the Anonymous
Pro copyright statement above — it does not include copyright lines for Courier
Prime or Lobster Two. If this project ever ships those typefaces (it currently
does not, since `addons/` is excluded from export), their upstream copyright
statements must be sourced and added here first.

OFL Reserved Font Names may not be used for modified versions of these fonts.

---

## Maintenance

Update this file whenever a dependency is added, removed, or upgraded:

- Adding an addon under `game/addons/` — add a notice, and state whether the
  export presets exclude it.
- Upgrading Godot — update the version heading. The MIT text itself is stable.
- Adding third-party art, audio, or fonts to `game/assets/` — add a notice
  here. Those files are **not** covered by `LICENSE-ASSETS`, which applies only
  to original work by Brent Humphries.

See [ADR 0012](docs/adr/0012-godot-and-gut-version-pin.md) for the version pin
these notices track, and [ADR 0017](docs/adr/0017-licensing.md) for the
licensing decision itself.
