#!/usr/bin/env python3
"""Generate the website encyclopedia from the Obsidian wiki.

Reads every note in ``obsidian-vault/wiki/`` and writes a static HTML page per
subject into ``website/encyclopedia/``, plus an index page. The generated HTML
is committed to the repo, so GitHub Pages still serves plain static files and
the site keeps its no-build-step guarantee (website/CLAUDE.md).

Re-run this whenever the wiki changes:

    python3 tools/build_encyclopedia.py

website/CLAUDE.md is explicit that the wiki is the source of truth: "if the
wiki says one thing and the website says another, the website is wrong." This
script is how that stays true.

Only a small, deliberate subset of Markdown is supported — enough for the house
style of the wiki notes, and no more:

* YAML front matter (``title``, ``date``, ``tags``, ``status``)
* ``##`` headings, paragraphs, ``-`` bullet lists
* ``**bold**``, ``*italic*``, ``` `code` ```
* ``[label](url)`` links and ``[[wikilink]]`` / ``[[wikilink|label]]``

Wikilinks that resolve to another wiki note become site links. Wikilinks that
point at unpublished design notes (PRDs, design memos) degrade to plain text.
"""

from __future__ import annotations

import html
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIKI_DIR = ROOT / "obsidian-vault" / "wiki"
OUT_DIR = ROOT / "website" / "encyclopedia"
PORTRAIT_DIR = ROOT / "website" / "assets" / "img" / "species"

GITHUB_URL = "https://github.com/brenthumphries/wildlife-crossing"

KIND_LABELS = {
    "species": "Species",
    "sub-area": "Region",
    "glossary": "Mechanic",
}

# Sections that get bespoke rendering rather than plain prose.
REFERENCE_HEADINGS = {"references"}
RELATED_HEADINGS = {"related"}
CALLOUT_HEADINGS = {"acknowledgment", "acknowledgement"}


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------


@dataclass
class Block:
    """One rendered chunk of a note body."""

    kind: str          # heading | paragraph | list | statblock | callout
    text: str = ""
    items: list[str] = field(default_factory=list)
    pairs: list[tuple[str, str]] = field(default_factory=list)


@dataclass
class Entry:
    slug: str
    title: str
    kind: str                      # species | sub-area | glossary
    date: str
    lede: str                      # rendered HTML, no wrapping <p>
    taxonomy: str | None
    blurb: str                     # plain text, for the index
    blocks: list[Block]
    references: list[str]
    related: list[str]             # slugs
    sort_key: tuple

    @property
    def portrait(self) -> str | None:
        if (PORTRAIT_DIR / f"{self.slug}.png").exists():
            return f"../assets/img/species/{self.slug}.png"
        return None


def parse_front_matter(text: str) -> tuple[dict[str, str], str]:
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    raw, body = text[3:end], text[end + 4 :]
    meta: dict[str, str] = {}
    for line in raw.splitlines():
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        meta[key.strip()] = value.strip().strip('"')
    return meta, body.lstrip("\n")


def unwrap(lines: list[str]) -> str:
    """Join hard-wrapped Markdown lines back into one logical line."""
    return " ".join(line.strip() for line in lines).strip()


def split_sections(body: str) -> list[tuple[str | None, list[str]]]:
    """Split a note body into (heading, lines) pairs. Heading is None for the
    lede paragraph that precedes the first ``##``."""
    sections: list[tuple[str | None, list[str]]] = []
    heading: str | None = None
    buffer: list[str] = []
    for line in body.splitlines():
        if line.startswith("## "):
            sections.append((heading, buffer))
            heading = line[3:].strip()
            buffer = []
        else:
            buffer.append(line)
    sections.append((heading, buffer))
    return sections


def group_paragraphs(lines: list[str]) -> list[tuple[str, list[str]]]:
    """Group raw lines into ('para' | 'list', lines) chunks."""
    chunks: list[tuple[str, list[str]]] = []
    current: list[str] = []
    mode = "para"

    def flush() -> None:
        if current:
            chunks.append((mode, list(current)))
            current.clear()

    for line in lines:
        stripped = line.strip()
        if not stripped:
            flush()
            continue
        is_bullet = stripped.startswith("- ")
        if is_bullet and mode != "list":
            flush()
            mode = "list"
        elif not is_bullet and mode == "list" and not line.startswith("  "):
            flush()
            mode = "para"
        current.append(line)
    flush()
    return chunks


def split_bullets(lines: list[str]) -> list[str]:
    items: list[str] = []
    current: list[str] = []
    for line in lines:
        if line.strip().startswith("- "):
            if current:
                items.append(unwrap(current))
            current = [line.strip()[2:]]
        else:
            current.append(line)
    if current:
        items.append(unwrap(current))
    return items


# ---------------------------------------------------------------------------
# Inline rendering
# ---------------------------------------------------------------------------

MD_LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
WIKI_LINK = re.compile(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]")
BOLD = re.compile(r"\*\*([^*]+)\*\*")
ITALIC = re.compile(r"(?<!\*)\*([^*]+)\*(?!\*)")
CODE = re.compile(r"`([^`]+)`")


def render_inline(text: str, known_slugs: set[str]) -> str:
    """Escape, then re-introduce the small set of inline constructs we allow."""
    placeholders: list[str] = []

    def stash(markup: str) -> str:
        placeholders.append(markup)
        return f"\x00{len(placeholders) - 1}\x00"

    # Markdown links first, so their labels aren't touched by other rules.
    def md_link(match: re.Match) -> str:
        label = html.escape(match.group(1), quote=False)
        label = BOLD.sub(r"<strong>\1</strong>", label)
        label = ITALIC.sub(r"<em>\1</em>", label)
        url = html.escape(match.group(2), quote=True)
        return stash(f'<a href="{url}">{label}</a>')

    text = MD_LINK.sub(md_link, text)

    def wiki_link(match: re.Match) -> str:
        target = match.group(1).strip()
        label = html.escape((match.group(2) or target).strip(), quote=False)
        if target in known_slugs:
            return stash(f'<a href="{target}.html">{label}</a>')
        # Points at an unpublished design note (a PRD or design memo that isn't
        # part of the public site). Keep the words, drop the link, and read the
        # slug back out as prose so it doesn't look like a broken reference.
        if match.group(2):
            return stash(label)
        return stash(html.escape(target.replace("-", " "), quote=False))

    text = WIKI_LINK.sub(wiki_link, text)

    text = html.escape(text, quote=False)
    text = CODE.sub(lambda m: stash(f"<code>{m.group(1)}</code>"), text)
    text = BOLD.sub(r"<strong>\1</strong>", text)
    text = ITALIC.sub(r"<em>\1</em>", text)

    for i, markup in enumerate(placeholders):
        text = text.replace(f"\x00{i}\x00", markup)
    return text


def strip_markup(text: str) -> str:
    """Plain-text version of a line, for search haystacks and blurbs."""
    text = MD_LINK.sub(r"\1", text)
    text = WIKI_LINK.sub(lambda m: (m.group(2) or m.group(1)), text)
    text = BOLD.sub(r"\1", text)
    text = ITALIC.sub(r"\1", text)
    text = CODE.sub(r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


STAT_PAIR = re.compile(r"\*\*(?P<label>[^*]+?):\*\*\s*(?P<value>.*)")


def parse_statblock(item: str) -> list[tuple[str, str]] | None:
    """Turn ``**Habitat:** forest · **Range:** large`` into label/value pairs.

    Returns None if the bullet isn't in that shape.
    """
    parts = [p.strip() for p in item.split("·")]
    if len(parts) < 3:
        return None
    pairs: list[tuple[str, str]] = []
    for part in parts:
        match = STAT_PAIR.fullmatch(part)
        if not match:
            return None
        label = match.group("label").strip()
        value = strip_markup(match.group("value")).strip(" .")
        if not value:
            return None
        pairs.append((label, value))
    return pairs


TAXONOMY = re.compile(r"\s*\(\*([^*]+)\*\)")


# ---------------------------------------------------------------------------
# Note -> Entry
# ---------------------------------------------------------------------------


def classify(tags: str) -> str:
    lowered = tags.lower()
    for kind in ("species", "sub-area", "glossary"):
        if kind in lowered:
            return kind
    return "glossary"


SUB_AREA_NUMBER = re.compile(r"Sub-area\s+(\d+)", re.IGNORECASE)


def load_entry(path: Path, known_slugs: set[str]) -> Entry:
    meta, body = parse_front_matter(path.read_text(encoding="utf-8"))
    slug = path.stem
    kind = classify(meta.get("tags", ""))
    sections = split_sections(body)

    lede_raw = ""
    blocks: list[Block] = []
    references: list[str] = []
    related: list[str] = []
    sub_area_number = 99

    for heading, lines in sections:
        chunks = group_paragraphs(lines)
        if heading is None:
            if chunks:
                lede_raw = unwrap(chunks[0][1])
            continue

        key = heading.strip().lower()

        if key in REFERENCE_HEADINGS:
            for chunk_kind, chunk_lines in chunks:
                if chunk_kind == "list":
                    for item in split_bullets(chunk_lines):
                        references.append(render_inline(item, known_slugs))
            continue

        if key in RELATED_HEADINGS:
            for chunk_kind, chunk_lines in chunks:
                text = unwrap(chunk_lines)
                for match in WIKI_LINK.finditer(text):
                    target = match.group(1).strip()
                    if target in known_slugs and target != slug:
                        related.append(target)
            continue

        is_callout = key in CALLOUT_HEADINGS
        if not is_callout:
            blocks.append(Block("heading", render_inline(heading, known_slugs)))

        for chunk_kind, chunk_lines in chunks:
            if chunk_kind == "list":
                items = split_bullets(chunk_lines)
                pairs = parse_statblock(items[0]) if len(items) >= 1 else None
                if pairs and len(items) == 1:
                    blocks.append(Block("statblock", pairs=pairs))
                    continue
                if pairs:
                    blocks.append(Block("statblock", pairs=pairs))
                    items = items[1:]
                if items:
                    blocks.append(
                        Block("list", items=[render_inline(i, known_slugs) for i in items])
                    )
            else:
                text = unwrap(chunk_lines)
                if not text:
                    continue
                if is_callout:
                    blocks.append(
                        Block(
                            "callout",
                            render_inline(text, known_slugs),
                            items=[heading.strip()],
                        )
                    )
                else:
                    blocks.append(Block("paragraph", render_inline(text, known_slugs)))

        if kind == "sub-area":
            match = SUB_AREA_NUMBER.search(" ".join(lines))
            if match:
                sub_area_number = int(match.group(1))

    taxonomy_match = TAXONOMY.search(lede_raw)
    taxonomy = None
    if kind == "species" and taxonomy_match:
        taxonomy = taxonomy_match.group(1)
        lede_raw = TAXONOMY.sub("", lede_raw, count=1)

    title = meta.get("title") or slug.replace("-", " ").title()
    blurb = strip_markup(lede_raw)
    first_sentence = re.split(r"(?<=[.!?])\s+", blurb)[0] if blurb else ""

    sort_key = (
        (0, sub_area_number, title) if kind == "sub-area" else (0, 0, title)
    )

    return Entry(
        slug=slug,
        title=title,
        kind=kind,
        date=meta.get("date", ""),
        lede=render_inline(lede_raw, known_slugs),
        taxonomy=taxonomy,
        blurb=first_sentence,
        blocks=blocks,
        references=references,
        related=related,
        sort_key=sort_key,
    )


# ---------------------------------------------------------------------------
# HTML output
# ---------------------------------------------------------------------------


def page_shell(title: str, description: str, body: str, *, depth: int) -> str:
    up = "../" * depth
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description, quote=True)}">
<meta name="theme-color" content="#f3ead8">
<link rel="icon" href="{up}assets/img/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="{up}assets/css/style.css">
</head>
<body>

<a class="skip-link" href="#main">Skip to content</a>

<header class="site-header">
  <div class="wrap site-header__inner">
    <a class="wordmark" href="{up}index.html">
      <svg width="24" height="24" viewBox="0 0 64 64" aria-hidden="true" focusable="false">
        <polygon points="32,6 51,17 51,39 32,50 13,39 13,17" fill="#4C7A4A"/>
        <rect x="26" y="12" width="12" height="38" fill="#57544D"/>
        <rect x="10" y="26" width="44" height="13" rx="5" fill="#3F6B41"/>
      </svg>
      Wildlife Crossing
    </a>
    <nav class="site-nav" aria-label="Main">
      <ul>
        <li><a href="{up}index.html">Home</a></li>
        <li><a href="{up}user-guide.html">User guide</a></li>
        <li><a href="{up}encyclopedia/index.html" aria-current="page">Encyclopedia</a></li>
        <li><a href="{GITHUB_URL}">Source</a></li>
      </ul>
    </nav>
  </div>
</header>

{body}

<footer class="site-footer">
  <div class="wrap">
    <div class="site-footer__cols">
      <div>
        <h2>Wildlife Crossing</h2>
        <p>A cozy ecosystem simulation built in Godot 4. Desktop, single-player, offline.</p>
      </div>
      <div>
        <h2>Pages</h2>
        <ul>
          <li><a href="{up}index.html">Home</a></li>
          <li><a href="{up}user-guide.html">User guide</a></li>
          <li><a href="{up}encyclopedia/index.html">Encyclopedia</a></li>
        </ul>
      </div>
      <div>
        <h2>Elsewhere</h2>
        <ul>
          <li><a href="{GITHUB_URL}">Source on GitHub</a></li>
          <li><a href="https://y2y.net">Yellowstone to Yukon Conservation Initiative</a></li>
        </ul>
      </div>
    </div>
    <p class="site-footer__fine">
      Wildlife Crossing is an independent game and is not affiliated with, or
      endorsed by, the Yellowstone to Yukon Conservation Initiative or any agency
      depicted. Governing bodies and partnerships in the game are fictional.
    </p>
  </div>
</footer>

<script src="{up}assets/js/main.js" defer></script>
</body>
</html>
"""


def render_blocks(blocks: list[Block]) -> str:
    out: list[str] = []
    for block in blocks:
        if block.kind == "heading":
            out.append(f"    <h2>{block.text}</h2>")
        elif block.kind == "paragraph":
            out.append(f"    <p>{block.text}</p>")
        elif block.kind == "callout":
            label = html.escape(block.items[0] if block.items else "Note")
            out.append(
                '    <div class="callout">\n'
                f'      <span class="callout__title">{label}</span>\n'
                f"      <p>{block.text}</p>\n"
                "    </div>"
            )
        elif block.kind == "list":
            items = "\n".join(f"      <li>{item}</li>" for item in block.items)
            out.append(f"    <ul>\n{items}\n    </ul>")
        elif block.kind == "statblock":
            cells = "\n".join(
                f"      <div><dt>{html.escape(label)}</dt>"
                f"<dd>{html.escape(value)}</dd></div>"
                for label, value in block.pairs
            )
            out.append(f'    <dl class="statblock">\n{cells}\n    </dl>')
    return "\n".join(out)


def render_entry(entry: Entry, by_slug: dict[str, Entry]) -> str:
    portrait = entry.portrait
    header_class = "entry-header entry-header--with-art" if portrait else "entry-header"

    art = ""
    if portrait:
        art = (
            f'      <img class="portrait" src="{portrait}" width="512" height="512"\n'
            f'           alt="Pixel-art portrait of the {html.escape(entry.title)}">\n'
        )

    taxonomy = (
        f'      <p class="taxonomy">{html.escape(entry.taxonomy)}</p>\n'
        if entry.taxonomy
        else ""
    )

    related = ""
    if entry.related:
        chips = "\n".join(
            f'        <li><a href="{slug}.html">{html.escape(by_slug[slug].title)}</a></li>'
            for slug in entry.related
            if slug in by_slug
        )
        related = (
            "    <h2>Related entries</h2>\n"
            f'    <ul class="related-list">\n{chips}\n    </ul>\n'
        )

    references = ""
    if entry.references:
        items = "\n".join(f"        <li>{ref}</li>" for ref in entry.references)
        references = (
            "    <h2>References</h2>\n"
            f'    <ul class="reference-list">\n{items}\n    </ul>\n'
        )

    body = f"""<main id="main" class="wrap wrap--narrow">

  <article>
    <header class="{header_class}">
{art}      <div>
        <p class="kicker">
          <span class="badge badge--{entry.kind}">{KIND_LABELS[entry.kind]}</span>
        </p>
        <h1>{html.escape(entry.title)}</h1>
{taxonomy}        <p class="entry-lede">{entry.lede}</p>
      </div>
    </header>

    <div class="entry-body">
{render_blocks(entry.blocks)}

{related}{references}      <p class="entry-meta">
        This entry is generated from the project wiki
        (<code>obsidian-vault/wiki/{entry.slug}.md</code>), last revised
        {html.escape(entry.date)}.
        <a href="index.html">Back to the encyclopedia</a>.
      </p>
    </div>
  </article>

</main>"""

    description = entry.blurb or f"{entry.title} in Wildlife Crossing."
    return page_shell(
        f"{entry.title} — Wildlife Crossing encyclopedia", description, body, depth=1
    )


def render_index(entries: list[Entry]) -> str:
    groups = [
        ("species", "Species", "The eight animals of the launch roster."),
        (
            "sub-area",
            "Regions",
            "The twelve sub-areas of the corridor, ordered south to north.",
        ),
        (
            "glossary",
            "Mechanics",
            "The concepts the simulation is built on.",
        ),
    ]

    sections: list[str] = []
    for kind, heading, blurb in groups:
        members = [e for e in entries if e.kind == kind]
        if not members:
            continue
        items: list[str] = []
        for entry in members:
            portrait = entry.portrait
            thumb = (
                f'<img src="{portrait}" width="512" height="512" alt="" loading="lazy">'
                if portrait
                else ""
            )
            haystack = html.escape(
                f"{entry.title} {entry.blurb} {KIND_LABELS[kind]}", quote=True
            )
            items.append(
                f'        <li data-kind="{kind}" data-search="{haystack}">\n'
                f'          <a href="{entry.slug}.html">{thumb}\n'
                f'            <span>\n'
                f'              <span class="entry-list__title">{html.escape(entry.title)}</span>\n'
                f'              <span class="entry-list__blurb">{html.escape(entry.blurb)}</span>\n'
                f"            </span>\n"
                f"          </a>\n"
                f"        </li>"
            )
        sections.append(
            f'      <section aria-labelledby="group-{kind}">\n'
            f'        <h2 id="group-{kind}">{heading}</h2>\n'
            f"        <p>{blurb}</p>\n"
            f'        <ul class="entry-list">\n' + "\n".join(items) + "\n"
            f"        </ul>\n"
            f"      </section>"
        )

    body = f"""<main id="main" class="wrap">

  <header class="page-head">
    <p class="kicker">Encyclopedia</p>
    <h1>Everything in the corridor</h1>
    <p class="entry-lede">
      {len(entries)} entries covering the species you're working for, the regions
      you'll unlock, and the mechanics underneath both — each one explaining how
      it behaves in-game and the real science it comes from.
    </p>
  </header>

  <div class="index-tools" data-index-tools hidden>
    <label for="entry-search">Search</label>
    <input type="search" id="entry-search" placeholder="grizzly, wetland, trust…"
           autocomplete="off" spellcheck="false">
    <div class="filter-group" role="group" aria-label="Filter by kind">
      <button type="button" class="filter-btn" data-filter="all" aria-pressed="true">All</button>
      <button type="button" class="filter-btn" data-filter="species" aria-pressed="false">Species</button>
      <button type="button" class="filter-btn" data-filter="sub-area" aria-pressed="false">Regions</button>
      <button type="button" class="filter-btn" data-filter="glossary" aria-pressed="false">Mechanics</button>
    </div>
  </div>
  <p class="no-results" data-index-status role="status" hidden></p>

  <div data-entry-index>
{chr(10).join(sections)}
  </div>

</main>"""

    return page_shell(
        "Encyclopedia — Wildlife Crossing",
        "Every species, region, and mechanic in Wildlife Crossing, with the real "
        "ecology behind each one.",
        body,
        depth=1,
    )


# ---------------------------------------------------------------------------


def main() -> int:
    if not WIKI_DIR.is_dir():
        print(f"error: no wiki at {WIKI_DIR}", file=sys.stderr)
        return 1

    paths = sorted(WIKI_DIR.glob("*.md"))
    known_slugs = {p.stem for p in paths}

    entries = [load_entry(p, known_slugs) for p in paths]
    entries.sort(key=lambda e: e.sort_key)
    by_slug = {e.slug: e for e in entries}

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for entry in entries:
        (OUT_DIR / f"{entry.slug}.html").write_text(
            render_entry(entry, by_slug), encoding="utf-8"
        )

    (OUT_DIR / "index.html").write_text(render_index(entries), encoding="utf-8")

    counts: dict[str, int] = {}
    for entry in entries:
        counts[entry.kind] = counts.get(entry.kind, 0) + 1
    summary = ", ".join(f"{n} {KIND_LABELS[k].lower()}" for k, n in sorted(counts.items()))
    print(f"wrote {len(entries)} entries + index to {OUT_DIR} ({summary})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
