## Placeholder Phase 1 renderer: draws the world grid and live agents from a
## Simulation as simple colored shapes. A stand-in until the real TileSet art and
## Animal sprites land — the simulation is authoritative; this only visualises it.
class_name WorldRenderer
extends Node2D

const TILE_PX := 24.0

var sim: Simulation

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if sim == null or sim.world == null:
		return
	for c in sim.world.all_coords():
		draw_circle(_to_px(c), TILE_PX * 0.45, _tile_color(c))
	for c in sim.infrastructure.coverage().keys():
		draw_circle(_to_px(c), TILE_PX * 0.45, Color(0.92, 0.80, 0.25))   # completed crossing
	for a in sim.agents:
		if a["alive"]:
			draw_circle(_to_px(a["coord"]), TILE_PX * 0.25, Color.WHITE)

func _to_px(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE_PX + c.y * TILE_PX * 0.5, c.y * TILE_PX * 0.87)

## Inverse of `_to_px`: the tile coordinate under a point in this node's local
## space (pass `get_global_mouse_position()` — a Node2D reports it camera-aware).
## Inverts the sheared basis then rounds; exact enough for the placeholder
## projection used for pointer-picking in segment mode.
func coord_at_px(p: Vector2) -> Vector2i:
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
