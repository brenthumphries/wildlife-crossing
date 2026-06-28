## Tests for WorldData grid building and queries (ADR 0006, data-schemas §12).
extends GutTest

var _tiles := {
	"forest": { "is_impassable": false, "is_hazardous": false, "biome": "forest" },
	"alpine_meadow": { "is_impassable": false, "is_hazardous": false, "biome": "alpine" },
	"road": { "is_impassable": false, "is_hazardous": true, "biome": null },
	"fence": { "is_impassable": true, "is_hazardous": false, "biome": null },
}

func _build(map: Dictionary) -> WorldData:
	var wd := WorldData.new()
	wd.load_from_dict(map, _tiles)
	return wd

func test_region_fill_and_count() -> void:
	var wd := _build({ "sub_area_id": 1, "origin": [0, 0],
		"regions": [ { "tile": "forest", "rect": [0, 0, 2, 2] } ] })
	assert_eq(wd.tile_count(), 9, "a 3x3 region fills nine cells")
	assert_eq(wd.tile_at(Vector2i(1, 1)), "forest", "interior cell is forest")
	assert_true(wd.has_tile(Vector2i(2, 2)), "corner cell exists")
	assert_false(wd.has_tile(Vector2i(3, 3)), "out-of-region cell absent")

func test_cells_override_regions() -> void:
	var wd := _build({ "sub_area_id": 1, "origin": [0, 0],
		"regions": [ { "tile": "forest", "rect": [0, 0, 2, 2] } ],
		"cells": [ { "q": 1, "r": 1, "tile": "road" } ] })
	assert_eq(wd.tile_at(Vector2i(1, 1)), "road", "explicit cell overrides region fill")
	assert_eq(wd.tile_count(), 9, "overriding an existing cell does not add one")

func test_flag_and_biome_queries() -> void:
	var wd := _build({ "sub_area_id": 1, "origin": [0, 0],
		"cells": [ { "q": 0, "r": 0, "tile": "forest" },
			{ "q": 1, "r": 0, "tile": "road" },
			{ "q": 2, "r": 0, "tile": "fence" } ] })
	assert_true(wd.is_hazardous(Vector2i(1, 0)), "road is hazardous")
	assert_false(wd.is_impassable(Vector2i(1, 0)), "road is not impassable")
	assert_true(wd.is_walkable(Vector2i(1, 0)), "a hazard is walkable")
	assert_true(wd.is_impassable(Vector2i(2, 0)), "fence is impassable")
	assert_false(wd.is_walkable(Vector2i(2, 0)), "a barrier is not walkable")
	assert_eq(wd.biome_at(Vector2i(0, 0)), "forest", "forest tile reports its biome")

func test_neighbors_in_bounds() -> void:
	var wd := _build({ "sub_area_id": 1, "origin": [0, 0],
		"regions": [ { "tile": "forest", "rect": [0, 0, 2, 2] } ] })
	assert_eq(wd.neighbors_in_bounds(Vector2i(0, 0)).size(), 2, "corner of an axial block has two in-bounds neighbours")
	assert_eq(wd.neighbors_in_bounds(Vector2i(1, 1)).size(), 6, "interior cell has all six")

func test_loads_real_tutorial_map() -> void:
	var map := WorldData.parse_file("res://data/world/sub_area_7.json")
	assert_false(map.is_empty(), "sub_area_7.json parses")
	var wd := WorldData.new()
	wd.load_from_dict(map, _tiles)
	assert_eq(wd.sub_area_id, 7, "loads sub-area 7")
	assert_gt(wd.tile_count(), 200, "tutorial map has a few hundred tiles")
	# The Bow Valley road band splits the forest; a road cell sits mid-map.
	assert_true(wd.is_hazardous(Vector2i(12, 5)), "the highway is hazardous")
