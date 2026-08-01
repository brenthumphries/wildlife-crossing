---
title: "Nano Banana — Species Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

## Purpose

A reusable Nano Banana (Gemini image model) prompt for the **species inspect-panel
portrait** specified in [art-direction.md §5](../../obsidian-vault/design/art-direction.md).
Instanced below for the **grizzly bear**; §4 lists the swaps for the other seven species.

## Why this asset

Nano Banana is an image model, not a pixel-art tool. It has no concept of a fixed
canvas grid, seamless tile edges, or frame-to-frame consistency. That rules out
the P0 tileset and sprite-sheet work — a 32×32 flat-top hex that must tile on six
edges, or an 8-frame walk cycle with a stable silhouette, will come back as a
pretty illustration that fails the actual constraint.

The 64×64 portrait (§5, P1) is the one asset in the doc with none of those
constraints: a single centered subject, no tiling, no animation, and a target size
small enough that downscaling from a large generation hides the model's inability
to place individual pixels. It is the highest-probability first success.

---

## 1. Setup before pasting

1. Open the Gemini app and start a **new chat** (a clean context — prior turns bias
   style heavily).
2. Attach **`docs/prompt-templates/wildlife-crossing-palette.png`** from this repo.
   That is the only attachment needed.
3. Paste the prompt in §2 as a single message.

Do not attach `art-direction.md` itself. Long design docs dilute an image prompt —
the model reads it as context to summarize rather than constraints to obey. Every
constraint that matters is already inlined below.

---

## 2. The prompt

> Paste everything between the rules, with the palette PNG attached.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **grizzly bear** in the style
of 16-bit era pixel art — the warm, naturalistic register of Stardew Valley.

**Subject**

- Head and upper shoulders only, in three-quarter view, facing slightly left.
- The pronounced **shoulder hump** must be visible and clearly readable — it is the
  species' primary identifying feature.
- Dished facial profile, small rounded ears, brown eyes. Calm and alert, not
  snarling, not aggressive, no bared teeth or visible claws.
- Coat: rich earthy brown with lighter grizzled silver-tipped guard hairs across the
  hump and shoulders.

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: roughly 12–16 colors total, drawn from the attached reference.
  Fur builds from `#7A5A3A` with `#2E4A36` for the deepest shadow and `#8A8E97` for
  the silver guard-hair tips.
- Flat cel shading with two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft airbrushed blur, no glow.
- Warm and slightly desaturated. Sunlit, never fluorescent or neon.
- Clean 1px dark outline around the silhouette in a dark brown, not pure black.

**Composition**

- Perfectly square, 1:1 aspect ratio.
- Subject centered, filling roughly 80% of the frame with even margins.
- Flat solid background in warm parchment `#F3EAD8`. No scenery, no ground, no
  drop shadow, no vignette, no border or frame.

**Do not include**

- Text, labels, watermarks, or signatures.
- Multiple bears, multiple panels, sprite sheets, turnaround views, or grids.
- Photorealistic rendering, 3D shading, painterly brushwork, or cartoon/anime styling.
- Any bright red (`#C0492F` is reserved for a UI error state), or the orange-to-teal
  ramp at the bottom of the reference image — that is data-visualization color and
  must not appear on the animal.

---

## 3. After you get an image

The output will be roughly 1024×1024 with soft, non-grid-aligned pixels — Nano
Banana renders *pixel-art-looking* imagery, not a true pixel grid. Two paths:

**Path A — use it as concept reference (recommended first pass).**
Judge silhouette, palette, and whether the shoulder hump reads. If it does, hand it
to Aseprite as reference and author the real 64×64 by hand. This is the honest use
of the tool and matches the `_src/` Aseprite workflow in §3 of the art direction.

**Path B — downscale to a candidate asset.**
Nearest-neighbor down to 64×64, then quantize to a fixed palette. Never bilinear —
it reintroduces the anti-aliasing the prompt spent effort excluding.

```bash
# from repo root, with ImageMagick
magick input.png -filter point -resize 64x64 -colors 16 -strip \
  game/assets/sprites/portraits/grizzly_bear_portrait.png
```

Expect to hand-fix the eyes and ear edges regardless — 64×64 is small enough that
a handful of misplaced pixels is the difference between "grizzly" and "brown blob."

### Acceptance check

- [ ] Shoulder hump readable at 64×64 with no zoom
- [ ] Distinguishable from a black bear at a glance
- [ ] Palette stays inside the art-direction naturals; no data-axis orange/teal on fur
- [ ] Background is flat `#F3EAD8`, fully transparent-able by a single color key
- [ ] Reads as cozy, not threatening (§1 cozy pillar)

---

## 4. The other seven species

Each has its own file in this folder with a ready-to-paste prompt, a dedicated
palette PNG, and species-specific failure modes. Structure is identical to this one —
only the **Subject** block and the palette differ.

| Species | Prompt file | Palette | Main failure mode |
|---|---|---|---|
| Elk | [nano-banana-portrait-elk.md](nano-banana-portrait-elk.md) | `palette-elk.png` | Head shrinks to fit the antlers |
| Pronghorn | [nano-banana-portrait-pronghorn.md](nano-banana-portrait-pronghorn.md) | `palette-pronghorn.png` | Forward horn prong omitted |
| Mountain caribou | [nano-banana-portrait-mountain-caribou.md](nano-banana-portrait-mountain-caribou.md) | `palette-mountain-caribou.png` | Christmas-reindeer drift |
| Wolverine | [nano-banana-portrait-wolverine.md](nano-banana-portrait-wolverine.md) | `palette-wolverine.png` | Marvel character, not the animal |
| Gray wolf | [nano-banana-portrait-gray-wolf.md](nano-banana-portrait-gray-wolf.md) | `palette-gray-wolf.png` | Howling-poster framing; reads cold |
| Canada lynx | [nano-banana-portrait-canada-lynx.md](nano-banana-portrait-canada-lynx.md) | `palette-canada-lynx.png` | Ear tufts cropped; bobcat spotting |
| Bighorn sheep | [nano-banana-portrait-bighorn-sheep.md](nano-banana-portrait-bighorn-sheep.md) | `palette-bighorn-sheep.png` | Horn curl flattens to a crescent |

Two rules hold across all eight: keep the **"calm and alert, not aggressive"** line
for every predator — the cozy pillar applies to wolves and wolverines too — and keep
the **data-axis orange/teal off the animal**, since that ramp means connectivity
everywhere else in the game.

### Palette derivation — needs sign-off

art-direction.md §5 gives each species a one-line "distinguishing read" but no fur
colors. The per-species ramps in the palette PNGs were derived from those lines plus
the ecology in `obsidian-vault/wiki/`, harmonized to the §2 warm naturalistic
register. They are **a proposal, not a spec.** If they hold up once a few portraits
exist, they should be folded back into art-direction §5 as a logged decision.

Note also that the per-species palettes deliberately **omit** the data-axis and
`#C0492F` swatches that appear in `wildlife-crossing-palette.png`. Image models
don't reliably process negation in a reference image, and for the tan/amber species
(elk, pronghorn, bighorn) the orange stops sit close enough to correct fur tones
that showing them invites contamination. The prohibition lives in prompt text only.

---

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5 — portrait spec
- `wildlife-crossing-palette.png` — the attachment this prompt expects
- `obsidian-vault/wiki/` — per-species ecology, for keeping the read honest
