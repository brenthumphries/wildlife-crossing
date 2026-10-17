## Tests for WorldRenderer's coordinate math: coord_at_px must invert the
## placeholder projection so segment-mode pointer-picking lands on the right tile.
extends GutTest

const HOTSPOT_AREA := 7
const HOT_TILE := Vector2i(12, 5)
const OTHER_HOT_TILE := Vector2i(13, 5)

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

## Regression guard for build item C10: project.godot now sets
## `window/stretch/mode = "canvas_items"`, which the 2026-09-02 log flagged as
## also changing screen-to-world mapping — the area `cb9f9b8` fixed for the
## world-select blind-click bug (two code paths disagreeing on which frame a
## click was in). Godot rescales real screen pixels to the configured
## viewport before a script ever sees them, with "keep" aspect (the project
## default) adding a uniform scale plus a letterbox offset on the wider axis.
## Models that rescale-then-descale explicitly so a future descale that drops
## the letterbox offset, or scales the wrong axis, fails a known tile here
## instead of silently mis-picking one on screen.
func test_coord_at_px_round_trips_through_a_stretched_screen() -> void:
	var stretch_mode: Variant = ProjectSettings.get_setting("display/window/stretch/mode")
	assert_eq(stretch_mode, "canvas_items", "this guard only matters while stretch is enabled")

	var width: Variant = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: Variant = ProjectSettings.get_setting("display/window/size/viewport_height")
	var content_size := Vector2(float(width), float(height))
	var window_size := Vector2(1920.0, 1080.0)   # a wider-than-content monitor
	var scale_x := window_size.x / content_size.x
	var scale_y := window_size.y / content_size.y
	var scale := scale_x if scale_x < scale_y else scale_y   # "keep" aspect: the smaller axis wins
	var letterbox := (window_size - content_size * scale) * 0.5

	var c := Vector2i(12, 5)
	var screen := WorldRenderer.px_at_coord(c) * scale + letterbox
	var recovered := (screen - letterbox) / scale
	assert_eq(
			_r.coord_at_px(recovered), c,
			"round-trips through a stretched, letterboxed screen")

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _hotspot_sim() -> Simulation:
	var tiles: Dictionary = {}
	for t: Dictionary in _load_json("res://data/tiles.json")["tiles"]:
		tiles[t["id"]] = t
	var species: Dictionary = {}
	for sp: Dictionary in _load_json("res://data/species_stats.json")["species"]:
		species[sp["id"]] = sp
	var infra: Dictionary = {}
	for c: Dictionary in _load_json("res://data/infrastructure.json")["infrastructure"]:
		infra[c["crossing_type"]] = c
	var segs: Dictionary = {}
	for sg: Dictionary in _load_json("res://data/segments.json")["segments"]:
		segs[sg["id"]] = sg
	var sim := Simulation.new()
	autofree(sim)
	sim.load_world(HOTSPOT_AREA, { "tiles": tiles, "species": species, "infrastructure": infra,
		"segments": segs, "biome_groups": _load_json("res://data/biome_groups.json") }, 42)
	return sim

## Corridor-study hotspot markers: with no information manager, or no study held,
## nothing is marked.
func test_hotspot_tiles_empty_without_a_corridor_study() -> void:
	assert_eq(WorldRenderer.hotspot_tiles(null, HOTSPOT_AREA).size(), 0, "no manager, no markers")
	var sim := _hotspot_sim()
	sim.information.record_death(HOT_TILE)
	assert_eq(WorldRenderer.hotspot_tiles(sim.information, HOTSPOT_AREA).size(), 0,
			"deaths recorded but the study is not held")

func test_hotspot_tiles_marks_tiles_with_deaths_and_updates_as_they_accumulate() -> void:
	var sim := _hotspot_sim()
	sim.economy.budget = 1000000
	sim.information.record_attempt(OTHER_HOT_TILE)
	assert_true(sim.information.purchase(InformationManager.CORRIDOR_STUDY, HOTSPOT_AREA), "study bought")
	assert_eq(WorldRenderer.hotspot_tiles(sim.information, HOTSPOT_AREA).size(), 0,
			"an attempt without a death is a route, not a hotspot")
	sim.information.record_death(HOT_TILE)
	assert_eq(WorldRenderer.hotspot_tiles(sim.information, HOTSPOT_AREA), [HOT_TILE] as Array[Vector2i],
			"the first death marks its tile")
	sim.information.record_death(OTHER_HOT_TILE)
	sim.information.record_death(OTHER_HOT_TILE)
	assert_eq(WorldRenderer.hotspot_tiles(sim.information, HOTSPOT_AREA),
			[OTHER_HOT_TILE, HOT_TILE] as Array[Vector2i], "more deaths add a marker, deadliest first")

func test_hotspot_tiles_empty_for_an_area_that_is_not_loaded() -> void:
	var sim := _hotspot_sim()
	sim.economy.budget = 1000000
	sim.information.purchase(InformationManager.CORRIDOR_STUDY, HOTSPOT_AREA)
	sim.information.record_death(HOT_TILE)
	assert_eq(WorldRenderer.hotspot_tiles(sim.information, HOTSPOT_AREA + 1).size(), 0)

func test_hotspot_colour_is_distinct_from_the_other_build_layers() -> void:
	var others: Array[Color] = [WorldRenderer.COLOR_BUILD_CHOSEN, WorldRenderer.COLOR_BUILD_HOVER_VALID,
			WorldRenderer.COLOR_BUILD_HOVER_INVALID, WorldRenderer.COLOR_COMPLETED_CROSSING]
	for other in others:
		assert_ne(WorldRenderer.COLOR_HOTSPOT, other)

# --- world-select camera framing (ADR 0021) ---

func test_tile_flat_to_flat_is_the_neighbour_spacing() -> void:
	var step := WorldRenderer.px_at_coord(Vector2i(1, 0)) - WorldRenderer.px_at_coord(Vector2i(0, 0))
	assert_almost_eq(step.length(), WorldRenderer.TILE_FLAT_TO_FLAT_PX, 0.001,
			"a hex's width across flats is the distance between neighbouring centres")

func test_centre_px_is_the_projected_bounds_centre() -> void:
	var coords: Array = [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 2)]
	var lo := Vector2(0.0, 0.0)
	var hi := Vector2(4.0 * WorldRenderer.TILE_PX, 2.0 * WorldRenderer.TILE_PX * 0.87)
	assert_almost_eq(WorldRenderer.centre_px(coords), (lo + hi) / 2.0, Vector2(0.001, 0.001))

func test_centre_px_of_nothing_is_the_origin() -> void:
	assert_eq(WorldRenderer.centre_px([]), Vector2.ZERO)
