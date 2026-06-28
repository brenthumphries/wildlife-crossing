## Tests for HexGrid topology (ADR 0002): six neighbours, no diagonals, distance.
extends GutTest

func test_six_distinct_directions() -> void:
	assert_eq(HexGrid.DIRECTIONS.size(), 6, "six directions")
	var seen := {}
	for d in HexGrid.DIRECTIONS:
		seen[d] = true
	assert_eq(seen.size(), 6, "directions are distinct")

func test_every_cell_has_six_neighbours_each_one_edge_away() -> void:
	var c := Vector2i(3, -2)
	var ns := HexGrid.neighbors(c)
	assert_eq(ns.size(), 6, "six neighbours")
	var seen := {}
	for n in ns:
		seen[n] = true
		assert_eq(HexGrid.distance(c, n), 1, "neighbour is exactly one edge away")
	assert_eq(seen.size(), 6, "neighbours are distinct (no diagonals)")

func test_distance_symmetric_and_zero_on_self() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(2, -1)
	assert_eq(HexGrid.distance(a, b), HexGrid.distance(b, a), "distance is symmetric")
	assert_eq(HexGrid.distance(a, a), 0, "distance to self is zero")

func test_known_distances() -> void:
	assert_eq(HexGrid.distance(Vector2i(0, 0), Vector2i(3, 0)), 3, "three steps on one axis")
	assert_eq(HexGrid.distance(Vector2i(0, 0), Vector2i(2, -1)), 2, "cube distance")
	assert_eq(HexGrid.distance(Vector2i(0, 0), Vector2i(-2, 1)), 2, "negative direction")

func test_adjacency() -> void:
	assert_true(HexGrid.are_adjacent(Vector2i(0, 0), Vector2i(1, 0)), "neighbours adjacent")
	assert_false(HexGrid.are_adjacent(Vector2i(0, 0), Vector2i(2, 0)), "two away not adjacent")
	assert_false(HexGrid.are_adjacent(Vector2i(0, 0), Vector2i(0, 0)), "self not adjacent")
