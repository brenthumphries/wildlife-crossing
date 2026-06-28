## Tests for Pathfinding: edge eligibility, hazard cost, crossing coverage,
## and full-vs-partial span routing (simulation-design §2, §3).
extends GutTest

var _tiles := {
	"forest": { "is_impassable": false, "is_hazardous": false, "biome": "forest" },
	"road": { "is_impassable": false, "is_hazardous": true, "biome": null },
	"fence": { "is_impassable": true, "is_hazardous": false, "biome": null },
}

# Build a single axial row of tiles (r = 0) from a list of tile ids.
func _row(ids: Array) -> WorldData:
	var cells: Array = []
	for i in ids.size():
		cells.append({ "q": i, "r": 0, "tile": ids[i] })
	var wd := WorldData.new()
	wd.load_from_dict({ "sub_area_id": 1, "origin": [0, 0], "cells": cells }, _tiles)
	return wd

func test_impassable_blocks_movement() -> void:
	# forest - fence - forest, single row: the only route runs through the barrier.
	var wd := _row(["forest", "fence", "forest"])
	var path := Pathfinding.find_path(wd, Vector2i(0, 0), Vector2i(2, 0))
	assert_eq(path.size(), 0, "an uncovered barrier with no detour blocks the route")

func test_hazardous_is_traversable_but_unsafe() -> void:
	var wd := _row(["forest", "road", "forest"])
	var path := Pathfinding.find_path(wd, Vector2i(0, 0), Vector2i(2, 0))
	assert_eq(path.size(), 3, "a hazard is routable")
	assert_true(Pathfinding.path_crosses_hazard(wd, path), "the route is not zero-mortality")

func test_covered_barrier_becomes_traversable() -> void:
	var wd := _row(["forest", "fence", "forest"])
	var opts := { "covered": { Vector2i(1, 0): true } }
	var path := Pathfinding.find_path(wd, Vector2i(0, 0), Vector2i(2, 0), opts)
	assert_eq(path.size(), 3, "a covered barrier gains an edge")
	assert_false(Pathfinding.path_crosses_hazard(wd, path, opts), "covered route is zero-mortality")

func test_full_span_creates_zero_mortality_route() -> void:
	# forest - road - road - forest; cover both road cells.
	var wd := _row(["forest", "road", "road", "forest"])
	var opts := { "covered": { Vector2i(1, 0): true, Vector2i(2, 0): true } }
	var path := Pathfinding.find_path(wd, Vector2i(0, 0), Vector2i(3, 0), opts)
	assert_eq(path.size(), 4, "full span yields a route")
	assert_false(Pathfinding.path_crosses_hazard(wd, path, opts), "full span is zero-mortality")

func test_partial_span_creates_no_safe_route() -> void:
	# Same band, cover only one of the two road cells.
	var wd := _row(["forest", "road", "road", "forest"])
	var opts := { "covered": { Vector2i(1, 0): true } }
	var path := Pathfinding.find_path(wd, Vector2i(0, 0), Vector2i(3, 0), opts)
	assert_eq(path.size(), 4, "a route still exists (through the hazard)")
	assert_true(Pathfinding.path_crosses_hazard(wd, path, opts), "partial span leaves a hazardous step — no safe route")

func test_covered_route_preferred_over_hazard() -> void:
	# Two parallel ways from (0,0) to a shared goal: a hazard step vs a covered step.
	# A covered crossing (cost 1) should beat an uncovered road (cost 4).
	var wd := _row(["forest", "road", "forest"])
	var hazard_path := Pathfinding.find_path(wd, Vector2i(0, 0), Vector2i(2, 0))
	var covered_path := Pathfinding.find_path(wd, Vector2i(0, 0), Vector2i(2, 0),
		{ "covered": { Vector2i(1, 0): true } })
	assert_true(Pathfinding.path_crosses_hazard(wd, hazard_path), "uncovered crosses hazard")
	assert_false(Pathfinding.path_crosses_hazard(wd, covered_path, { "covered": { Vector2i(1, 0): true } }),
		"covering the band removes the hazard from the route")
