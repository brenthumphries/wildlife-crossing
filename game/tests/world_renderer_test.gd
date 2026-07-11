## Tests for WorldRenderer's coordinate math: coord_at_px must invert the
## placeholder projection so segment-mode pointer-picking lands on the right tile.
extends GutTest

var _r: WorldRenderer

func before_each() -> void:
	_r = WorldRenderer.new()

func after_each() -> void:
	_r.free()

# The forward projection, mirrored from WorldRenderer._to_px for the round-trip.
func _to_px(c: Vector2i) -> Vector2:
	var t := WorldRenderer.TILE_PX
	return Vector2(c.x * t + c.y * t * 0.5, c.y * t * 0.87)

func test_coord_at_px_round_trips_tile_centres() -> void:
	for c in [Vector2i(0, 0), Vector2i(12, 5), Vector2i(13, 9), Vector2i(25, 11)]:
		assert_eq(_r.coord_at_px(_to_px(c)), c, "round-trips " + str(c))

func test_coord_at_px_snaps_a_nearby_point_to_its_tile() -> void:
	# A point a few px off a tile centre still resolves to that tile.
	var near := _to_px(Vector2i(12, 5)) + Vector2(3.0, -2.0)
	assert_eq(_r.coord_at_px(near), Vector2i(12, 5))
