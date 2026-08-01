---
title: "Nano Banana — Canada Lynx Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

Species instance of [nano-banana-species-portrait.md](nano-banana-species-portrait.md).
That file holds the workflow, downscaling steps, and rationale.

**Attach:** `palette-canada-lynx.png` (this folder). Nothing else.
**New chat** in the Gemini app, then paste everything between the rules.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **Canada lynx** (*Lynx
canadensis*) in the style of 16-bit era pixel art — the warm, naturalistic register
of Stardew Valley.

**Subject**

- Head and upper shoulders in three-quarter view, facing slightly left.
- **Long black ear tufts** `#2A2621` standing well clear of the ears — the primary
  identifying feature, and the thing that must survive downscaling.
- **Wide flared facial ruff** of longer fur framing the cheeks, cream `#E0D8C4`,
  giving the head a broad diamond silhouette.
- Short face, small nose, pale amber-green eyes `#C9B86E`.
- Coat: grey-buff `#9A927F` with warm buff `#B8A882` across the brow and a faint
  mottling `#7A7264`. Only faint spotting — Canada lynx are much less spotted than
  a bobcat.
- Calm and alert, mouth closed, ears upright.

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: 12–16 colors, drawn from the attached reference.
- Flat cel shading, two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft blur, no glow.
- Warm and slightly desaturated. Sunlit, never fluorescent.
- Clean 1px outline around the silhouette in `#3A342C`, not pure black.

**Composition**

- Perfectly square, 1:1 aspect ratio.
- Subject centered, filling roughly 75% of the frame — **leave headroom at the top
  so the ear tufts are fully inside the frame and not cropped.**
- Flat solid background in warm parchment `#F3EAD8`. No scenery, no ground, no drop
  shadow, no vignette, no border or frame.

**Do not include**

- Text, labels, watermarks, or signatures.
- Heavy leopard-like spotting or rosettes — that reads as bobcat or serval.
- Multiple animals, multiple panels, sprite sheets, turnarounds, or grids.
- Photorealistic rendering, 3D shading, painterly brushwork, or cartoon/anime styling.
- Any bright red or saturated orange — those hues are reserved for UI states and
  data visualization and must not appear on the animal.

---

## Species-specific gotcha

This is the one portrait where composition is inverted from the rest of the set: the
lynx needs **headroom, not cropping**. Ear tufts cropped by the top edge remove the
single feature that separates a lynx from a housecat at 64×64.

The other risk is bobcat drift — models blend the two species freely. If the result
comes back heavily spotted with short ear tufts, add:

> Ear tufts long and prominent, at least a third the height of the ear. Coat almost
> uniform grey with only faint mottling, not spotted.

Expect to redraw the tufts by hand at 64×64 regardless — they're 2–3px wide and
almost never survive a nearest-neighbor downscale intact.

## Acceptance check

- [ ] Ear tufts fully inside the frame and readable at 64×64
- [ ] Facial ruff gives a broad silhouette, distinct from a generic cat
- [ ] Coat is near-uniform grey-buff, not leopard-spotted
- [ ] Distinguishable from a bobcat
- [ ] Background is flat `#F3EAD8`, keyable in one pass

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5
- [obsidian-vault/wiki/canada-lynx.md](../../obsidian-vault/wiki/canada-lynx.md)
