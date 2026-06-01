# Wildlife Crossing — website/ Scoped Instructions

> Extends `../CLAUDE.md`. Never contradicts it. Read the root file first.

## What lives here

The public-facing static website, hosted via GitHub Pages. It serves as the
game's homepage, user guide, and in-world encyclopedia for players. It is
built with plain HTML, CSS, and vanilla JavaScript — no build step, no
frameworks, no bundlers.

---

## Directory layout

```
website/
├── index.html              # Homepage / landing page
├── user-guide.html         # How to play
├── encyclopedia/           # One .html file per subject (species, biomes, etc.)
│   └── kebab-case.html
└── assets/
    ├── css/
    │   └── style.css       # Single stylesheet (mobile-first, no frameworks)
    ├── img/                # Screenshots, logos, species art
    └── js/
        └── main.js         # Minimal vanilla JS only
```

---

## Tech constraints

- **No frameworks.** No React, Vue, Tailwind, Bootstrap, or similar. The site
  must be self-contained static files that work without a build step.
- **No external CDN dependencies** in production HTML (fonts and icons can be
  self-hosted under `assets/`).
- **JavaScript is for enhancement only.** The site must be fully readable with
  JS disabled. Use JS for things like search, filtering, or ambient animation —
  never for rendering core content.
- **Accessibility first.** Semantic HTML (`<main>`, `<nav>`, `<article>`,
  `<section>`). Every image has `alt` text. Colour contrast meets WCAG AA.
- **Mobile-friendly.** Responsive layout using CSS Grid or Flexbox. Test at
  375 px and 1280 px widths.

---

## Visual style

The website should feel like the game: warm, naturalistic, slightly hand-made.

- **Palette**: earthy greens, warm tans, soft sky blues. Avoid sterile whites
  and harsh blacks.
- **Typography**: a humanist sans-serif for body copy, a pixel or display font
  for headings (self-hosted). Keep the type scale simple — 3 sizes maximum.
- **Pixel art**: use game sprites and screenshots liberally. Render at 2× or
  3× scale using `image-rendering: pixelated` so they stay crisp.
- **Tone**: friendly, curious, educational. Write like a nature documentary
  narrator who is also slightly delighted by everything.

---

## Pages

### Homepage (`index.html`)

- Hero: game title, tagline, one hero screenshot.
- Short "what is this game" paragraph.
- Key feature highlights (3–4 items max).
- Link to itch.io / download (once available).
- Link to the User Guide and Encyclopedia.

### User Guide (`user-guide.html`)

Step-by-step introduction to playing Wildlife Crossing. Written for a player
who has just launched the game for the first time. Structure:

1. First steps / getting oriented
2. Placing habitats
3. Managing species needs
4. Infrastructure and corridors
5. Seasons and the passage of time
6. Tips and advanced play

Each section should be short, clear prose. Prefer screenshots and annotated
images over walls of text.

### Encyclopedia (`encyclopedia/`)

One page per subject. Subjects include species, biomes, and game mechanics.
Filename: `kebab-case-subject.html`.

#### Encyclopedia page structure

```html
<article>
  <header>
    <img src="../assets/img/species-name.png" alt="[Species Name] sprite" class="sprite">
    <h1>Common Name</h1>
    <p class="taxonomy">Scientific name (if real species)</p>
  </header>

  <section class="summary">
    <!-- 1–2 sentence description -->
  </section>

  <section class="habitat">
    <h2>Habitat</h2>
    <!-- Where this species lives in-game and in nature -->
  </section>

  <section class="needs">
    <h2>Needs</h2>
    <!-- What the species requires to thrive -->
  </section>

  <section class="behaviour">
    <h2>Behaviour</h2>
    <!-- How it acts in the simulation -->
  </section>

  <section class="real-world">
    <h2>In the real world</h2>
    <!-- Brief factual note grounding the species in science -->
  </section>
</article>
```

---

## Writing style guide

- **Voice**: second person for instructional content ("You can place a habitat
  by…"), third person for encyclopedia entries.
- **Reading level**: aim for a general audience, roughly grade 8. Avoid jargon;
  if a technical term is used, define it on first use.
- **Ecological accuracy**: encyclopedia entries must be grounded in real science.
  If a species stat diverges from reality for gameplay reasons, note it in the
  real-world section.
- **Length**: pages should be scannable. Use `<h2>` and `<h3>` headings
  generously. Prefer short paragraphs (3–5 sentences).

---

## Deployment

The site deploys automatically to GitHub Pages from the `main` branch via a
GitHub Actions workflow at `.github/workflows/deploy-website.yml` (to be
created). The site root is `website/`.

---

## What to do when uncertain

- If a new page is needed that doesn't fit the current layout, propose the
  addition in the root `CLAUDE.md` conversation before creating files.
- If a design decision would require adding a JS framework or build step,
  discuss it first — this constraint is intentional and should only be relaxed
  with explicit approval.
- Keep encyclopedia content in sync with `obsidian-vault/wiki/` — if the wiki
  says one thing and the website says another, the website is wrong.
