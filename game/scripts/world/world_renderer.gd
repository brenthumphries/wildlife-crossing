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
