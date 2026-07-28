## Tests for WorldRenderer's coordinate math: coord_at_px must invert the
## placeholder projection so segment-mode pointer-picking lands on the right tile.
extends GutTest

var _r: WorldRenderer

func before_each() -> void:
	_r = WorldRenderer.new()

func after_each() -> void:
	_r.free()

func test_coord_at_px_round_trips_tile_centres() -> void:
	for c in [Vector2i(0, 0), Vector2i(12, 5), Vector2i(13, 9), Vector2i(25, 11)]:
		assert_eq(_r.coord_at_px(WorldRenderer.px_at_coord(c)), c, "round-trips " + str(c))

func test_coord_at_px_snaps_a_nearby_point_to_its_tile() -> void:
	# A point a few px off a tile centre still resolves to that tile.
	var near := WorldRenderer.px_at_coord(Vector2i(12, 5)) + Vector2(3.0, -2.0)
	assert_eq(_r.coord_at_px(near), Vector2i(12, 5))

## Pins the projection to known values. The round-trip tests above pass for any
## self-consistent pair, so they cannot catch the transform itself drifting —
## which is how the camera came to use a different one (2026-07-19).
func test_px_at_coord_has_the_expected_sheared_basis() -> void:
	var t := WorldRenderer.TILE_PX
	assert_eq(WorldRenderer.px_at_coord(Vector2i(0, 0)), Vector2.ZERO, "origin")
	# One step on x is a pure horizontal move of one tile.
	assert_eq(WorldRenderer.px_at_coord(Vector2i(1, 0)), Vector2(t, 0.0), "x is unsheared")
	# One step on y shifts half a tile right as well as down — the shear.
	var y_step := WorldRenderer.px_at_coord(Vector2i(0, 1))
	assert_almost_eq(y_step.x, t * 0.5, 0.001, "y shears half a tile right")
	assert_almost_eq(y_step.y, t * 0.87, 0.001, "y drops 0.87 of a tile")

## The regression guard for the camera bug: framing the tutorial crossing must
## go through the projection. Naive `coord * TILE_PX` lands 72px off in x and
## ~19px off in y — enough to push the crossing site out of the opening frame.
func test_camera_focus_projection_differs_from_naive_multiplication() -> void:
	var c := Main.CAMERA_FOCUS_COORD
	var projected := WorldRenderer.px_at_coord(c)
	var naive := Vector2(c.x * WorldRenderer.TILE_PX, c.y * WorldRenderer.TILE_PX)
	assert_almost_eq(projected.x, 384.0, 0.01, "projected x of the focus tile")
	assert_almost_eq(projected.y, 125.28, 0.01, "projected y of the focus tile")
	assert_gt(
			projected.distance_to(naive), 1.0,
			"naive multiplication is NOT the projection — do not use it for framing")
