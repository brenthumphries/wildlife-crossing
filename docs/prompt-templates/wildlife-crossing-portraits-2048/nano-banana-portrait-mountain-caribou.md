---
title: "Nano Banana — Mountain Caribou Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

Species instance of [nano-banana-species-portrait.md](nano-banana-species-portrait.md).
That file holds the workflow, downscaling steps, and rationale.

**Attach:** `palette-mountain-caribou.png` (this folder). Nothing else.
**New chat** in the Gemini app, then paste everything between the rules.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **mountain caribou**
(*Rangifer tarandus caribou*) in the style of 16-bit era pixel art — the warm,
naturalistic register of Stardew Valley.

**Subject**

- Head, neck and upper shoulders in three-quarter view, facing slightly left.
- **Broad palmate antlers** — flattened, shovel-like blades rather than round tines,
  with one antler sweeping forward over the face as a distinctive brow shovel. This
  is the primary identifying feature.
- **Blunt, broad, rounded muzzle** — noticeably heavier and squarer than a deer's or
  elk's tapering nose. Second identifying read.
- Coat: grey-brown `#7D7266` with a **pale shaggy neck mane** `#DCD6C6` hanging
  below the throat.
- Antlers in `#9C8C6E` with `#6E6250` shadow. Dark eyes and nose `#2A2621`.
- Calm and alert, mouth closed.

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: 12–16 colors, drawn from the attached reference.
- Flat cel shading, two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft blur, no glow.
- Cool-leaning but still naturalistic and desaturated. Sunlit, never fluorescent.
- Clean 1px outline around the silhouette in `#33302B`, not pure black.

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
- Christmas, reindeer harness, sleighs, bells, or any festive framing.
- Any bright red or saturated orange — those hues are reserved for UI states and
  data visualization and must not appear on the animal.

---

## Species-specific gotcha

Two failure modes, both common:

1. **Reindeer drift.** "Caribou" pulls hard toward Christmas imagery in most image
   models — hence the explicit exclusion above. If a harness or red nose appears,
   regenerate rather than editing; the whole composition is usually contaminated.
2. **Elk-shaped antlers.** Palmate (flat, shovel-like) is the distinguishing
   feature and models default to round tines. If needed, add: *the antlers are
   flattened blades like a moose's, not round spikes.*

At 64×64 the palmate antler and the blunt muzzle are what separate this portrait
from [the elk](nano-banana-portrait-elk.md). If both are weak, the two species will
be indistinguishable in the inspect panel — regenerate rather than accepting.

## Acceptance check

- [ ] Antlers read as flat/palmate, not round tines
- [ ] Muzzle reads blunt and broad, clearly distinct from the elk portrait
- [ ] Pale neck mane visible against the grey-brown coat at 64×64
- [ ] No festive contamination
- [ ] Background is flat `#F3EAD8`, keyable in one pass

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5
- [obsidian-vault/wiki/mountain-caribou.md](../../obsidian-vault/wiki/mountain-caribou.md)
