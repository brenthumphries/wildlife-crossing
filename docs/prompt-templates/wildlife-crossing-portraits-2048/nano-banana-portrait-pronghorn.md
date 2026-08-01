---
title: "Nano Banana — Pronghorn Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

Species instance of [nano-banana-species-portrait.md](nano-banana-species-portrait.md).
That file holds the workflow, downscaling steps, and rationale.

**Attach:** `palette-pronghorn.png` (this folder). Nothing else.
**New chat** in the Gemini app, then paste everything between the rules.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **pronghorn buck**
(*Antilocapra americana*) in the style of 16-bit era pixel art — the warm,
naturalistic register of Stardew Valley.

**Subject**

- Head and upper neck in three-quarter view, facing slightly left.
- **Black pronged horns** `#2A2521` — each horn has a forward-facing prong partway
  up, then hooks backward. This forked shape is the primary identifying feature and
  distinguishes pronghorn from any deer or antelope.
- **Very large dark eyes** set high and wide on the skull — pronghorn have
  exceptional vision and the eyes should read as oversized.
- Coat: tan `#C29A5E` upper, with **crisp white throat bands** `#F0E9DC` — two
  horizontal white bars across the throat — and a white muzzle patch.
- Dark brown cheek patch `#4A3A2A` below the eye.
- Calm and alert, mouth closed.

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: 12–16 colors, drawn from the attached reference.
- Flat cel shading, two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft blur, no glow.
- Warm and slightly desaturated. Sunlit, never fluorescent.
- Clean 1px outline around the silhouette in dark brown `#3A2E22`, not pure black.

**Composition**

- Perfectly square, 1:1 aspect ratio.
- Subject centered, filling roughly 80% of the frame with even margins.
- Both horns fully inside the frame — unlike antlered species, the pronghorn rack is
  compact enough to fit.
- Flat solid background in warm parchment `#F3EAD8`. No scenery, no ground, no drop
  shadow, no vignette, no border or frame.

**Do not include**

- Text, labels, watermarks, or signatures.
- Multiple animals, multiple panels, sprite sheets, turnarounds, or grids.
- Photorealistic rendering, 3D shading, painterly brushwork, or cartoon/anime styling.
- Any bright red or saturated orange — those hues are reserved for UI states and
  data visualization and must not appear on the animal.

---

## Species-specific gotcha

Image models reliably default to "generic antelope" and drop the forward prong,
which is the whole point of the name. If the first pass comes back with plain curved
horns, add:

> Each black horn is flat and blade-like, with a distinct forward-pointing prong
> about halfway up, and the tip hooks backward.

The white throat bands are the second-most-likely omission. They're worth insisting
on — at 64×64 they carry more identifying weight than the horns do.

## Acceptance check

- [ ] Forward prong visible on at least the near horn
- [ ] Two white throat bands survive the downscale
- [ ] Eyes read as oversized and dark
- [ ] Distinguishable from a deer at a glance
- [ ] Background is flat `#F3EAD8`, keyable in one pass

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5
- [obsidian-vault/wiki/pronghorn.md](../../obsidian-vault/wiki/pronghorn.md)
