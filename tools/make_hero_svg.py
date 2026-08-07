#!/usr/bin/env python3
"""Generate the homepage hero illustration for website/.

Draws a pointy-top hex valley in the Wildlife Crossing palette
(obsidian-vault/design/art-direction.md §2) with a highway cutting through it
and a vegetated overpass spanning the hazardous tile.

The output is a static, self-contained SVG with no external references, in
keeping with website/CLAUDE.md ("no external CDN dependencies").

Usage:
    python3 tools/make_hero_svg.py [output_path]
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

# --- Geometry ---------------------------------------------------------------

HEX_SIZE = 26.0                       # centre-to-vertex radius
HEX_WIDTH = math.sqrt(3) * HEX_SIZE   # flat-to-flat width of a pointy-top hex
ROW_STEP = 1.5 * HEX_SIZE             # vertical distance between row centres

COLS, ROWS = 22, 11
VIEW_W, VIEW_H = 880, 440
MARGIN_X, MARGIN_Y = 6.0, 26.0

# The highway zigzags down one column; the overpass spans it in a single row.
ROAD_COLUMN = 11
OVERPASS_ROW = 6

# --- Palette (art-direction.md §2) -----------------------------------------

PALETTE = {
    "parchment": "#F3EAD8",
    "snow": "#E8EEF2",
    "ice": "#C9DBE6",
    "rock": "#8A8E97",
    "rock_light": "#9DA1A9",
    "forest_deep": "#2E4A36",
    "forest_mid": "#4C7A4A",
    "grassland": "#A8B560",
    "wetland": "#9CA84E",
    "water_deep": "#2B5A72",
    "water_shallow": "#6FB3B8",
    "earth": "#7A5A3A",
    "road": "#57544D",
    "road_alt": "#65625B",
    "span": "#3F6B41",
    "outline": "#23301F",
}


def hex_centre(col: int, row: int) -> tuple[float, float]:
    """Centre of the hex at (col, row); odd rows are offset by half a width."""
    cx = HEX_WIDTH * (col + 0.5 * (row & 1)) + MARGIN_X
    cy = ROW_STEP * row + MARGIN_Y
    return cx, cy


def hex_points(cx: float, cy: float) -> str:
    corners = []
    for i in range(6):
        angle = math.radians(60 * i - 30)
        corners.append((cx + HEX_SIZE * math.cos(angle),
                        cy + HEX_SIZE * math.sin(angle)))
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in corners)


def road_column_for_row(row: int) -> int:
    """The highway drifts one column left every other row, so it reads as a
    road bending through the valley rather than a ruled line."""
    return ROAD_COLUMN - (row // 3)


def terrain_for(col: int, row: int) -> str:
    """Deterministic banded terrain: peaks at the top, valley floor below."""
    n = math.sin(col * 0.55 + row * 0.4) + math.cos(col * 0.31 - row * 0.77) * 0.7
    if row <= 1:
        return "snow" if n > 0.1 else "ice"
    if row == 2:
        return "rock" if n > -0.2 else "rock_light"
    if row in (3, 4, 5):
        return "forest_deep" if n > 0 else "forest_mid"
    if row == 6:
        return "forest_mid" if n > -0.3 else "grassland"
    if row == 7:
        return "grassland" if n > -0.4 else "wetland"
    if row == 9 and 3 <= col <= 9:
        return "water_deep"
    if row == 9 and col in (2, 10):
        return "water_shallow"
    return "grassland" if n > -0.5 else "wetland"


def animal_mark(cx: float, cy: float, colour: str) -> str:
    """A small four-legged silhouette, readable at hero size."""
    return (
        f'<g fill="{colour}">'
        f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="6" ry="3.8"/>'
        f'<circle cx="{cx + 5.6:.1f}" cy="{cy - 3.4:.1f}" r="2.8"/>'
        f'<rect x="{cx - 4.4:.1f}" y="{cy + 2.4:.1f}" width="1.7" height="3.4"/>'
        f'<rect x="{cx + 2.6:.1f}" y="{cy + 2.4:.1f}" width="1.7" height="3.4"/>'
        f"</g>"
    )


def build() -> str:
    parts: list[str] = []

    for row in range(ROWS):
        road_col = road_column_for_row(row)
        for col in range(COLS):
            cx, cy = hex_centre(col, row)
            if cx > VIEW_W + HEX_SIZE or cy > VIEW_H + HEX_SIZE:
                continue
            if col == road_col:
                fill = PALETTE["road"] if row % 2 == 0 else PALETTE["road_alt"]
            else:
                fill = PALETTE[terrain_for(col, row)]
            parts.append(f'<polygon points="{hex_points(cx, cy)}" fill="{fill}"/>')

    # Overpass: earth ramps either side of the road, with a vegetated deck
    # bridging over the road tile — the road stays visible beneath it.
    span_col = road_column_for_row(OVERPASS_ROW)
    for offset in (-1, 1):
        cx, cy = hex_centre(span_col + offset, OVERPASS_ROW)
        parts.append(
            f'<polygon points="{hex_points(cx, cy)}" fill="{PALETTE["earth"]}" '
            f'stroke="{PALETTE["outline"]}" stroke-opacity="0.4" stroke-width="1.6"/>'
        )

    span_cx, span_cy = hex_centre(span_col, OVERPASS_ROW)
    deck_w = HEX_WIDTH * 2.05
    deck_h = HEX_SIZE * 1.02
    deck_x = span_cx - deck_w / 2
    deck_y = span_cy - deck_h / 2
    # Shadow cast onto the roadway, then the deck itself.
    parts.append(
        f'<rect x="{deck_x:.1f}" y="{deck_y + 7:.1f}" width="{deck_w:.1f}" '
        f'height="{deck_h:.1f}" rx="9" fill="{PALETTE["outline"]}" fill-opacity="0.28"/>'
    )
    parts.append(
        f'<rect x="{deck_x:.1f}" y="{deck_y:.1f}" width="{deck_w:.1f}" '
        f'height="{deck_h:.1f}" rx="9" fill="{PALETTE["span"]}" '
        f'stroke="{PALETTE["outline"]}" stroke-opacity="0.45" stroke-width="1.8"/>'
    )
    for i, (dx, dy) in enumerate(
        ((-32, -5), (-20, 6), (-8, -7), (4, 5), (16, -6), (28, 6), (36, -4))
    ):
        r = 3.2 if i % 2 else 2.4
        parts.append(
            f'<circle cx="{span_cx + dx:.1f}" cy="{span_cy + dy:.1f}" r="{r}" '
            f'fill="{PALETTE["grassland"]}" fill-opacity="0.95"/>'
        )

    # Animals: one mid-crossing on the deck, two approaching from either side.
    parts.append(animal_mark(span_cx - 2, span_cy - 1, "#33241A"))
    parts.append(animal_mark(span_cx - HEX_WIDTH * 1.9, span_cy - ROW_STEP, "#4A3524"))
    parts.append(animal_mark(span_cx + HEX_WIDTH * 1.7, span_cy + ROW_STEP + 2, "#5A4630"))

    label = (
        "Pixel-style hex map of a mountain valley: snowy peaks, forest, and "
        "grassland split by a highway, with a vegetated wildlife overpass "
        "carrying animals safely across it"
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {VIEW_W} {VIEW_H}" '
        f'role="img" aria-label="{label}">'
        f'<rect width="{VIEW_W}" height="{VIEW_H}" fill="{PALETTE["parchment"]}"/>'
        + "".join(parts)
        + "</svg>"
    )


def main() -> None:
    default = Path(__file__).resolve().parents[1] / "website/assets/img/hero-corridor.svg"
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else default
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build(), encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
