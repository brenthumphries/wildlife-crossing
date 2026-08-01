---
title: "Nano Banana — Wolverine Portrait (64×64)"
date: 2026-07-31
tags: [prompt-template, art]
status: active
---

Species instance of [nano-banana-species-portrait.md](nano-banana-species-portrait.md).
That file holds the workflow, downscaling steps, and rationale.

**Attach:** `palette-wolverine.png` (this folder). Nothing else.
**New chat** in the Gemini app, then paste everything between the rules.

---

Use the attached image **only as a color palette reference**. Do not reproduce its
layout, swatches, text, or grid in your output.

Generate a **single square character portrait** of a **wolverine** (*Gulo gulo*) —
the animal, a large member of the weasel family — in the style of 16-bit era pixel
art, in the warm naturalistic register of Stardew Valley.

**Subject**

- Head and upper shoulders in three-quarter view, facing slightly left.
- **Low, broad, heavy head** with small rounded ears set low and wide, and a short
  blunt muzzle. Stocky and bear-like in proportion despite being a weasel.
- Coat: dark brown `#4A3628` overall, with the signature **pale blond stripe**
  `#C9A063` running from the shoulder back along the flank, and a **lighter blond
  facial mask** `#A88657` across the forehead and cheeks.
- Optional small cream throat patch `#E8DFCC`.
- Dark eyes. Calm and alert — **not snarling, no bared teeth, no visible claws.**

**Style**

- Chunky, deliberate pixels with hard edges. Every pixel placed on purpose.
- Limited palette: 12–16 colors, drawn from the attached reference.
- Flat cel shading, two shadow steps and one highlight. No gradients, no
  anti-aliasing, no soft blur, no glow.
- Warm and slightly desaturated. Sunlit, never fluorescent.
- Clean 1px outline around the silhouette in `#241A13`, not pure black.
- **Because the coat is dark, keep the shadow steps shallow** — the silhouette must
  not collapse into a single unreadable dark mass at small size.

**Composition**

- Perfectly square, 1:1 aspect ratio.
- Subject centered, filling roughly 80% of the frame with even margins.
- Flat solid background in warm parchment `#F3EAD8`. No scenery, no ground, no drop
  shadow, no vignette, no border or frame.

**Do not include**

- Text, labels, watermarks, or signatures.
- Any reference to comic books, superheroes, claws, masks, or the Marvel character
  of the same name. This is strictly the real animal.
- Multiple animals, multiple panels, sprite sheets, turnarounds, or grids.
- Photorealistic rendering, 3D shading, painterly brushwork, or cartoon/anime styling.
- Any bright red or saturated orange — those hues are reserved for UI states and
  data visualization and must not appear on the animal.

---

## Species-specific gotcha

**The name is the problem.** "Wolverine" is far more strongly associated with the
Marvel character than with *Gulo gulo* in any model's training data, which is why
the prompt says "the animal, a large member of the weasel family" in the first line
and repeats the exclusion at the bottom. If you still get anything anthropomorphic,
regenerate with the species name replaced entirely:

> a glutton (Gulo gulo), the largest land-dwelling member of the weasel family

Second issue: contrast. A dark brown animal on parchment at 64×64 loses all interior
detail if the shading is deep. The blond stripe and facial mask are doing the
identifying work — if they wash out in the downscale, brighten them by hand in
Aseprite rather than regenerating.

## Acceptance check

- [ ] Unambiguously the animal, zero superhero contamination
- [ ] Blond flank stripe and facial mask both visible at 64×64
- [ ] Interior detail survives — silhouette isn't a dark blob
- [ ] Reads calm, not ferocious (art-direction §1 cozy pillar applies to predators too)
- [ ] Background is flat `#F3EAD8`, keyable in one pass

## Related

- [art-direction.md](../../obsidian-vault/design/art-direction.md) §5
- [obsidian-vault/wiki/wolverine.md](../../obsidian-vault/wiki/wolverine.md)
