---
title: "Audio Design"
date: 2026-06-17
tags: [design, audio]
status: active
---

## Purpose

This document defines the audio direction for Wildlife Crossing and the complete
cue list, each cue **mapped to the signal that triggers it**. It covers the
crossing-success cue and its coalescing behaviour, ambient seasonal beds, unlock
fanfares, and UI sounds, with mixing rules consistent with the cozy pillar. Its
acceptance bar is a complete cue list mapped to triggering signals.

Signals referenced are the `EventBus` signals defined in
[`architecture`](../../docs/architecture.md) §5. Assets follow the
`game/CLAUDE.md` audio pipeline: music as looping `.ogg`, SFX as `.wav`, sized
small.

---

## 1. Audio pillars

- **Cozy, never alarming.** Warm acoustic palette (soft strings, woodwinds,
  hand percussion, gentle synth pads). No stingers that read as failure; setbacks
  are quiet, not punishing.
- **The world sounds alive.** Layered natural ambience tied to season and biome
  carries most of the soundscape; music is sparse and supportive.
- **Feedback is earned and legible.** The crossing-success cue is the game's
  signature reward sound — small, satisfying, and never noisy even when many
  animals cross at once.
- **Calm under speed.** At 2×/4× the world should not become a wall of sound;
  event cues thin out and ambience compresses (see mixing rules).

---

## 2. Signature cue — crossing success

The emotional payoff sound, triggered when an animal completes a crossing.

- **Trigger signal:** `animal_crossed` (per-animal, per-traversal).
- **Coalescing:** the feedback layer coalesces `animal_crossed` emissions **per
  crossing within a 2-second window** (`CROSSING_FEEDBACK_COALESCE_SECONDS`) into
  a **single** cue with a "+N" visual counter. The first crossing in the window
  plays the full cue; additional crossings within it add a soft, slightly
  pitched-up grace note (a small ascending arpeggio as N rises) rather than
  re-triggering the whole cue — so a migration-season rush sounds like a happy
  swell, never a machine-gun of identical sounds.
- **Character:** a short, warm two-note "lift" (e.g. a soft marimba/harp pluck
  resolving upward) with a faint nature shimmer. ~0.6 s.
- **Spatialisation:** light stereo pan toward the crossing's screen position;
  attenuates if off-screen so the player isn't pulled around by distant events.

---

## 3. Cue list (mapped to signals)

### Gameplay event cues

| Cue | Trigger signal | Character | Notes |
|---|---|---|---|
| Crossing success | `animal_crossed` | warm 2-note lift + shimmer | coalesced per crossing in 2s window (§2) |
| Crossing complete (build) | `crossing_completed` | soft wooden "set" + brief chord | one-shot when a span finishes |
| Animal lost | `animal_died` | very soft low woodwind sigh | quiet, non-punishing; never a harsh stinger (cozy) |
| Donation received | `donation_received` | gentle coin/chime, scaled to amount | monthly; bigger donation = fuller chord, not louder |
| Budget changed (spend) | `budget_changed` (decrease) | subtle paper/whoosh | quiet confirmation of spend |
| Population recovered | `population_recovered` | rising hopeful motif (short) | the "it's working" beat |
| Habitat quality up a band | `habitat_quality_changed` (band increases) | tiny upward sparkle | only on band change, not every recompute |
| Trust stage advanced | `trust_changed` (crosses quartile) | warm ascending pair | Introduced→…→Partnered |
| Sub-area unlocked | `sub_area_unlocked` | **unlock fanfare** (see §5) | paired with colour-bloom |
| Partnership formed | `partnership_formed` | distinct warmer fanfare variant | First Nations partnership beat |
| Milestone reached | `milestone_reached` (non-capstone) | celebratory flourish | per-sub-area milestone |
| Continental Connection | `milestone_reached` (`is_capstone`) | **capstone sequence** (§5) | full celebratory cue, game continues |

### Season + time cues

| Cue | Trigger signal | Character |
|---|---|---|
| Season change transition | `season_changed` | gentle crossfade swell into the new seasonal bed |
| Migration motivation rising | `season_changed` (into a migration season) | subtle low pulse / distant calls hinting movement |
| Speed changed | `time_speed_changed` | very short tick; ambience ducks at higher speeds |
| Pause / resume | `time_speed_changed` (pause) | soft low pad fades in (pause) / out (resume) |

### UI cues (not on EventBus; driven by UI input)

| Cue | Trigger | Character |
|---|---|---|
| Enter selection mode | toolbar "Add crossing" | soft mode-open swell |
| Segment hover | hover valid segment | faint tick |
| Confirm panel open | `segment_selected` | gentle panel-rise |
| Confirm / commit | `location_confirmed` | affirmative soft chord |
| Cancel / click-outside / Escape | `selection_cancelled` | neutral soft close (never a "wrong" buzzer) |
| Invalid placement | red-preview state | single soft thud (the only mildly negative SFX; still gentle) |
| Information purchased | `information_purchased` | light page-turn / reveal shimmer |
| Generic button / toggle | UI input | minimal click |

---

## 4. Ambient seasonal beds

Each season has a looping ambient bed (`.ogg`), layered by the dominant biome in
view, that carries the soundscape. Music sits sparsely on top.

| Season | Ambient character |
|---|---|
| Spring | birdsong, snowmelt trickle, soft wind; meltwater emphasis |
| Summer | full birdsong, insects, warm breeze, distant water |
| Autumn | wind through drying grass, sparser birds, elk bugle accents |
| Winter | hushed wind, muffled snow, occasional raven; sparse and still |

- Biome layers (forest / grassland / alpine / wetland / water) crossfade with the
  camera's dominant on-screen biome.
- `season_changed` crossfades beds over a few seconds rather than cutting.
- Frozen-river / flood seasonal terrain changes have matching ambient detail
  (ice creak in winter, fuller water in spring).

### Music

Sparse, modal, acoustic underscore that swells at reward moments and rests
otherwise — long stretches are ambience-only by design (cozy, contemplative).
One main looping theme with seasonal instrumentation variants; reward cues are
musically in-key with the current bed so they never clash.

---

## 5. Fanfares

- **Sub-area unlock fanfare** (`sub_area_unlocked`): a warm, rising 3–4 note
  motif resolving to a major chord, ~2 s, paired with the colour-bloom visual.
- **Partnership-formed variant** (`partnership_formed`): the same motif in a
  warmer, more communal instrumentation (added hand percussion / voice-like pad)
  to mark the relationship beat — distinct from a bureaucratic "level up."
- **Capstone — Continental Connection** (`milestone_reached`, `is_capstone`): an
  extended celebratory sequence (full theme statement + layered nature swell),
  then a graceful return to ambience as play continues (the game does not end).

---

## 6. Mixing rules (cozy pillar)

- **Headroom and gentleness.** Master target around −16 LUFS; no cue peaks near
  0 dBFS. The loudest sounds are fanfares, and even those are warm, not bright.
- **No alarm semantics.** Negative events (`animal_died`, invalid placement) are
  the *quietest* meaningful sounds, low and soft — never sharp or high. There are
  no failure stingers anywhere.
- **Event ducking under speed.** At 2×/4×, event cues are throttled (coalescing
  windows effectively widen) and ambience is gently compressed so fast-forward is
  calm, not chaotic.
- **Crossing-cue density cap.** Beyond the 2-second coalescing, a global limiter
  caps simultaneous crossing cues per second; overflow rolls into the "+N" grace
  notes rather than new full cues.
- **Pause ambience.** On pause, a soft low pad fades in and gameplay event cues
  are silenced (build/info UI cues still play, since those actions work while
  paused).
- **Bus layout:** `Master → [Music, Ambience, SFX_events, SFX_ui]`. Ambience and
  SFX_events duck slightly under fanfares; UI stays present so controls always
  feel responsive.

---

## 7. Asset list (priority)

- **P0:** crossing-success cue (+ grace-note layer), crossing-complete,
  donation, four seasonal ambient beds, season-change crossfade, core UI cues
  (hover/confirm/cancel/invalid/purchase), unlock fanfare, main theme loop.
- **P1:** population-recovered, trust-stage, habitat-band-up, partnership
  fanfare, capstone sequence, biome ambient layers, pause pad.
- **P2:** per-biome music instrumentation variants, animal-specific vocalisations
  (elk bugle, wolf howl, raven) as ambient accents.

## Related

- [[ui-ux-spec]] — the UI events these cues accompany
- [[art-direction]] — paired visual feedback (particle burst, colour-bloom)
- [`architecture`](../../docs/architecture.md) §5 — the signal catalogue
- [[wildlife-overpass-crossing]] — `animal_crossed` coalescing decision
