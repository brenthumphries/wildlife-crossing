---
title: "Nano Banana — Gray Wolf Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

Species instance of [nano-banana-species-portrait.md](nano-banana-species-portrait.md).
That file holds the workflow, downscaling steps, and rationale.

**Attach:** `palette-gray-wolf.png` (this folder). Nothing else.
**New chat** in the Gemini app, then paste everything between the rules.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **gray wolf** (*Canis lupus*)
in the style of 16-bit era pixel art — the warm, naturalistic register of Stardew
Valley.

**Subject**

- Head and upper shoulders in three-quarter view, facing slightly left.
- **Long narrow muzzle, upright pointed ears, lean angular skull** — the wolf must
  read as leggy and rangy, clearly not a domestic dog or husky.
- Coat: grey `#8A8E97` with darker guard hair `#33363C` along the muzzle bridge and
  back of the neck, a pale underside and cheek ruff `#DCDCD4`, and a subtle warm tan
  wash `#9A8A72` behind the ears and along the ruff. The warm wash keeps it inside
  the game's naturalistic register rather than reading cold and grey-blue.
- **Amber-gold eyes** `#D8A93C` — the single warm accent and the strongest
  identifying detail at small size.
- Calm and alert, ears forward, **mouth closed. Not snarling, no bared teeth.**

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: 12–16 colors, drawn from the attached reference.
- Flat cel shading, two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft blur, no glow.
- Warm and slightly desaturated. Sunlit, never fluorescent.
- Clean 1px outline around the silhouette in `#33363C`, not pure black.

**Composition**

- Perfectly square, 1:1 aspect ratio.
- Subject centered, filling roughly 80% of the frame with even margins.
- Flat solid background in warm parchment `#F3EAD8`. No scenery, no ground, no drop
  shadow, no vignette, no border or frame.

**Do not include**

- Text, labels, watermarks, or signatures.
- Moons, howling poses, forests, mist, or any dramatic wildlife-poster framing.
- Glowing eyes, blue eyes, or any supernatural treatment.
- Multiple animals, multiple panels, sprite sheets, turnarounds, or grids.
- Photorealistic rendering, 3D shading, painterly brushwork, or cartoon/anime styling.
- Any bright red or saturated orange — those hues are reserved for UI states and
  data visualization and must not appear on the animal.

---

## Species-specific gotcha

Wolves attract two strong stylistic priors: **the howling-at-the-moon poster** and
**the glowing-eyed menacing predator**. Both are excluded above; if either shows up,
regenerate rather than editing.

The subtler risk is that a grey wolf on a parchment background is the lowest-chroma
portrait in the set, and can end up looking washed out and flat next to the grizzly.
The warm tan wash and amber eyes exist specifically to counter that — if the result
still reads cold, add:

> Push warm brown tones through the grey coat so it sits alongside earthy brown
> animal portraits without looking blue.

## Acceptance check

- [ ] Reads as wolf, not husky or German shepherd — narrow muzzle, lean skull
- [ ] Amber eyes present and readable at 64×64
- [ ] Warm enough to sit beside the grizzly portrait without looking cold or grey-blue
- [ ] Calm, mouth closed (art-direction §1 cozy pillar applies to predators too)
- [ ] Background is flat `#F3EAD8`, keyable in one pass

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5
- [obsidian-vault/wiki/gray-wolf.md](../../obsidian-vault/wiki/gray-wolf.md)
