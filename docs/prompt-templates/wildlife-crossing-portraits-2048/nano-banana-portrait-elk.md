---
title: "Nano Banana — Elk Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

Species instance of [nano-banana-species-portrait.md](nano-banana-species-portrait.md).
That file holds the workflow, downscaling steps, and rationale — read it once, then
use this file for the paste.

**Attach:** `palette-elk.png` (this folder). Nothing else.
**New chat** in the Gemini app, then paste everything between the rules.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **bull elk** (*Cervus
canadensis*) in the style of 16-bit era pixel art — the warm, naturalistic register
of Stardew Valley.

**Subject**

- Head, neck and upper shoulders in three-quarter view, facing slightly left.
- **Broad sweeping antlers** with multiple tines — the primary identifying feature.
- Long tapering muzzle, dark eyes, large upright ears.
- Coat: tan body `#A87F4E` with a distinctly **darker chocolate-brown shaggy neck
  ruff** `#3D2B1F`. The tan/dark-ruff contrast is the second identifying read.
- Antlers in ivory `#C9B48A` with `#8A7048` shadow.
- Calm and alert. Not bugling, not aggressive, mouth closed.

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: 12–16 colors, drawn from the attached reference.
- Flat cel shading, two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft blur, no glow.
- Warm and slightly desaturated. Sunlit, never fluorescent.
- Clean 1px outline around the silhouette in dark brown `#3A2A1C`, not pure black.

**Composition**

- Perfectly square, 1:1 aspect ratio.
- Subject centered, filling roughly 80% of the frame.
- **The antlers may be cropped by the top and side edges.** Keep the head large and
  readable rather than shrinking it to fit the full rack inside the frame.
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

Antlers are the hard part. The model will usually either shrink the head to fit the
whole rack (killing readability at 64×64) or produce a symmetrical deer-shaped rack
that reads as whitetail rather than elk. If both happen, add to the prompt:

> The antlers sweep backward over the shoulders rather than upward, and are cropped
> by the top edge of the frame.

## Acceptance check

- [ ] Reads as elk, not deer — antlers sweep back, neck ruff is dark
- [ ] Tan body vs. dark neck ruff contrast survives the downscale to 64×64
- [ ] Antler tines still distinguishable at 64×64 (2px minimum thickness)
- [ ] Background is flat `#F3EAD8`, keyable in one pass
- [ ] Calm, not threatening (art-direction §1 cozy pillar)

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5
- [obsidian-vault/wiki/elk.md](../../obsidian-vault/wiki/elk.md)
