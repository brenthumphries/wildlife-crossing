## Placeholder Phase 1 renderer: draws the world grid and live agents from a
## Simulation as simple colored shapes. A stand-in until the real TileSet art and
## Animal sprites land — the simulation is authoritative; this only visualises it.
class_name WorldRenderer
extends Node2D

const TILE_PX := 24.0
## Ghost-preview colors (build-review B4): a chosen-but-uncompleted span tile,
## a hovered tile the player could add, and a hovered tile that is not part
## of the segment / not coverable by the current crossing type. Distinct from
## the gold `coverage()` fill above so an in-progress span never reads as an
## already-completed crossing.
const COLOR_BUILD_CHOSEN := Color(0.35, 0.75, 0.95, 0.85)
const COLOR_BUILD_HOVER_VALID := Color(0.35, 0.95, 0.45, 0.5)
const COLOR_BUILD_HOVER_INVALID := Color(0.95, 0.30, 0.30, 0.4)
## Corridor-study hotspot ring (roadmap Phase 3): an orange outline, so it reads
## apart from the blue chosen ghost, the green/red hover and the gold completed fill.
const COLOR_COMPLETED_CROSSING := Color(0.92, 0.80, 0.25)
const COLOR_HOTSPOT := Color(1.0, 0.55, 0.0, 0.95)
const HOTSPOT_RING_RADIUS_FRACTION := 0.5
const HOTSPOT_RING_POINTS := 24
const HOTSPOT_RING_WIDTH_PX := 2.0

var sim: Simulation
## Set by Main while a BuildMode is active (build-review B4); null otherwise.
var build_mode: BuildMode = null
var build_hover := Vector2i.ZERO
## Set by Main with `build_mode`: where corridor-study hotspots are read from, and
## the loaded sub-area they belong to. Null information draws no markers.
var information: InformationManager = null
var hotspot_area_id := 0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if sim == null or sim.world == null:
		return
	for c in sim.world.all_coords():
		draw_circle(px_at_coord(c), TILE_PX * 0.45, _tile_color(c))
	for c in sim.infrastructure.coverage().keys():
		draw_circle(px_at_coord(c), TILE_PX * 0.45, COLOR_COMPLETED_CROSSING)
	if build_mode != null:
		_draw_build_preview()
	for a in sim.agents:
		if a["alive"]:
			draw_circle(px_at_coord(a["coord"]), TILE_PX * 0.25, Color.WHITE)

## The ghost preview: tiles already added to the in-progress span, plus a
## highlight on the hovered tile — green if clicking it would add a valid
## candidate, red if it's outside the segment or not coverable by this
## crossing type (ADR 0016 rules 1–2).
func _draw_build_preview() -> void:
	for c in hotspot_tiles(information, hotspot_area_id):
		draw_arc(px_at_coord(c), TILE_PX * HOTSPOT_RING_RADIUS_FRACTION, 0.0, TAU,
				HOTSPOT_RING_POINTS, COLOR_HOTSPOT, HOTSPOT_RING_WIDTH_PX)
	for c in build_mode.chosen_tiles():
		draw_circle(px_at_coord(c), TILE_PX * 0.45, COLOR_BUILD_CHOSEN)
	var hover_valid := build_mode.is_selectable(build_hover) or build_mode.is_chosen(build_hover)
	var hover_color := COLOR_BUILD_HOVER_VALID if hover_valid else COLOR_BUILD_HOVER_INVALID
	draw_circle(px_at_coord(build_hover), TILE_PX * 0.5, hover_color)

## The tiles to mark as corridor-study hotspots for `area_id`: the deadliest-first
## `hotspots` of the corridor study layer, read through `InformationManager.layer`.
## Empty when `info` is null or the study is not held for that area.
static func hotspot_tiles(info: InformationManager, area_id: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if info == null:
		return tiles
	var layer: Dictionary = info.layer(InformationManager.CORRIDOR_STUDY, area_id)
	for h: Dictionary in layer.get("hotspots", []):
		tiles.append(h["tile"])
	return tiles

## The centre of tile `c` in this node's local space. **The single source of
## truth for the placeholder axial→pixel projection** — anything positioning
## itself against the world view (the connectivity overlay, the camera) must
## call this rather than reimplementing the transform. The basis is sheared, so
## naive `coord * TILE_PX` lands in the wrong place and drifts further as `c.y`
## grows.
static func px_at_coord(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE_PX + c.y * TILE_PX * 0.5, c.y * TILE_PX * 0.87)

## Inverse of `px_at_coord`: the tile coordinate under a point in this node's
## local space (pass `get_global_mouse_position()` — a Node2D reports it
## camera-aware). Inverts the sheared basis then rounds; exact enough for the
## placeholder projection used for pointer-picking in segment mode.
static func coord_at_px(p: Vector2) -> Vector2i:
	var r := p.y / (TILE_PX * 0.87)
	var q := (p.x - r * TILE_PX * 0.5) / TILE_PX
	return Vector2i(roundi(q), roundi(r))

func _tile_color(c: Vector2i) -> Color:
	if sim.world.is_impassable(c):
		return Color(0.30, 0.30, 0.30)
	if sim.world.is_hazardous(c):
		return Color(0.62, 0.20, 0.20)
	match sim.world.biome_at(c):
		"forest":
			return Color(0.20, 0.50, 0.22)
		"alpine":
			return Color(0.60, 0.70, 0.82)
		_:
			return Color(0.40, 0.40, 0.40)
