---
title: "Nano Banana — Bighorn Sheep Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

Species instance of [nano-banana-species-portrait.md](nano-banana-species-portrait.md).
That file holds the workflow, downscaling steps, and rationale.

**Attach:** `palette-bighorn-sheep.png` (this folder). Nothing else.
**New chat** in the Gemini app, then paste everything between the rules.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **bighorn sheep ram** (*Ovis
canadensis*) in the style of 16-bit era pixel art — the warm, naturalistic register
of Stardew Valley.

**Subject**

- Head and upper shoulders in three-quarter view, facing slightly left.
- **Massive curled horns** `#9C7C4A` spiraling down, forward and back up in a full
  circle beside the face, thick and heavily ridged with visible growth rings. These
  are the primary identifying feature and should read as genuinely heavy.
- Blunt square muzzle, small ears tucked behind the horn base, dark eyes.
- Coat: brown `#8A6E4E` with a **white muzzle patch and pale rump/neck edge**
  `#E8E0D0`. Short, close-lying fur — not shaggy or woolly.
- Horn shading: `#6A4F2E` in the spiral shadow, `#C4A878` on the ridge highlights.
- Calm and alert, mouth closed.

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: 12–16 colors, drawn from the attached reference.
- Flat cel shading, two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft blur, no glow.
- Warm and slightly desaturated. Sunlit, never fluorescent.
- Clean 1px outline around the silhouette in `#3A2C1E`, not pure black.

**Composition**

- Perfectly square, 1:1 aspect ratio.
- Subject centered, filling roughly 80% of the frame.
- The horn curl may touch or be lightly cropped by the side edges, but **the full
  spiral shape must remain readable** — do not crop so tightly that the curl reads
  as a straight horn.
- Flat solid background in warm parchment `#F3EAD8`. No scenery, no ground, no drop
  shadow, no vignette, no border or frame.

**Do not include**

- Text, labels, watermarks, or signatures.
- Woolly domestic-sheep fleece, or a ram's-head heraldic/logo treatment.
- Cliffs, mountains, or any scenery.
- Multiple animals, multiple panels, sprite sheets, turnarounds, or grids.
- Photorealistic rendering, 3D shading, painterly brushwork, or cartoon/anime styling.
- Any bright red or saturated orange — those hues are reserved for UI states and
  data visualization and must not appear on the animal.

---

## Species-specific gotcha

The horn spiral is the whole portrait, and it's a genuine 3D form being rendered in
flat cel shading at tiny size. Two things go wrong:

1. **The curl flattens into a crescent** — reads as a generic goat. Insist on the
   full circle: *the horn curls down past the jaw, forward, and back up so the tip
   comes level with the eye.*
2. **Ridging disappears.** The growth rings give the horn its mass. At 64×64 you get
   maybe 4–5 ridge pixels; place them by hand in Aseprite if the downscale mushes
   them.

Also watch for domestic-sheep drift — models add fleece. Bighorn coats are short and
smooth, closer to a deer's than a sheep's.

## Acceptance check

- [ ] Horn reads as a full heavy spiral, not a crescent
- [ ] At least some ridging visible at 64×64
- [ ] Coat is short and smooth, no woolly fleece
- [ ] White muzzle patch survives the downscale
- [ ] Background is flat `#F3EAD8`, keyable in one pass

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5
- [obsidian-vault/wiki/bighorn-sheep.md](../../obsidian-vault/wiki/bighorn-sheep.md)
