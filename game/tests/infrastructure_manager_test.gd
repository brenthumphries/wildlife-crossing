## Tests for InfrastructureManager: placement validation, the ADR 0016
## two-sided-core span predicate (the seven-row verified-behaviour table,
## including the two rejections), crossing_completed signal + patch link,
## usage counter, data-driven types (ADR 0003, ADR 0016, simulation-design §3,
## test-plan §2).
extends GutTest

var _world: WorldData
var _graph: ConnectivityGraph
var _infra: InfrastructureManager
var _completed: Array = []
const SEG := "s7_trans_canada_bow_a"
## ADR 0016's own worked minimal example for this segment.
const BOW_VALLEY_SPAN: Array[Vector2i] = [Vector2i(12, 5), Vector2i(13, 5)]

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _segment_tiles(id: String) -> Array:
	for s in _load_json("res://data/segments.json")["segments"]:
		if s["id"] == id:
			return s["tiles"]
	return []

func before_each() -> void:
	var treg: Dictionary = {}
	for t in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var bg: Dictionary = _load_json("res://data/biome_groups.json")
	var ireg: Dictionary = {}
	for c in _load_json("res://data/infrastructure.json")["infrastructure"]:
		ireg[c["crossing_type"]] = c
	var sreg: Dictionary = {}
	for s in _load_json("res://data/segments.json")["segments"]:
		sreg[s["id"]] = s
	_world = WorldData.new()
	_world.load_from_dict(WorldData.parse_file("res://data/world/sub_area_7.json"), treg)
	_graph = ConnectivityGraph.new()
	_graph.build(_world, bg)
	_infra = InfrastructureManager.new()
	_infra.setup(_world, _graph, ireg, sreg)
	_completed = []
	_infra.crossing_completed.connect(func(seg, ct, sa): _completed.append([seg, ct, sa]))

## A fresh InfrastructureManager wired to sub-area `sa`'s own world/graph —
## for the Snake River rows, which live in sub-area 1, not 7 (before_each's
## fixture).
func _infra_for_sub_area(sa: int) -> InfrastructureManager:
	var treg: Dictionary = {}
	for t in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var bg: Dictionary = _load_json("res://data/biome_groups.json")
	var ireg: Dictionary = {}
	for c in _load_json("res://data/infrastructure.json")["infrastructure"]:
		ireg[c["crossing_type"]] = c
	var sreg: Dictionary = {}
	for s in _load_json("res://data/segments.json")["segments"]:
		sreg[s["id"]] = s
	var world := WorldData.new()
	world.load_from_dict(WorldData.parse_file("res://data/world/sub_area_%d.json" % sa), treg)
	var graph := ConnectivityGraph.new()
	graph.build(world, bg)
	var infra := InfrastructureManager.new()
	infra.setup(world, graph, ireg, sreg)
	return infra

func _place_full_span() -> void:
	for t in _segment_tiles(SEG):
		_infra.place(Vector2i(int(t[0]), int(t[1])), "overpass")

func test_placeable_on_dangerous_rejected_on_plain() -> void:
	assert_true(_infra.can_place(Vector2i(12, 5), "overpass"), "overpass placeable on a road (hazard) tile")
	assert_false(_infra.can_place(Vector2i(0, 0), "overpass"), "overpass rejected on plain forest")

func test_lone_corner_tile_is_not_a_two_sided_core() -> void:
	_infra.place(Vector2i(12, 0), "overpass")          # one dangerous cell, at the corridor's end
	assert_false(_infra.try_complete(SEG, "overpass"), "a lone corner tile does not reach across")
	assert_eq(_completed.size(), 0, "no crossing_completed when no valid core exists")
	assert_eq(_infra.coverage().size(), 0, "nothing is covered on rejection")

func test_usage_counter_increments() -> void:
	var cid := _infra.crossing_id_for(SEG)
	_infra.on_animal_crossed(cid)
	_infra.on_animal_crossed(cid)
	assert_eq(_infra.usage_of(cid), 2, "each animal_crossed bumps the usage counter")

func test_crossing_type_is_data_driven() -> void:
	# A corridor (coverable_flags includes is_hazardous) is placeable on a road with
	# no per-type code branch — purely a registry lookup.
	assert_true(_infra.can_place(Vector2i(12, 5), "corridor"), "any registry type resolves by data")

# --- ADR 0016 §"Verified behaviour" — the seven-row table, as cases ---------

func test_adr0016_bow_valley_full_width_span_is_valid() -> void:
	# Row 1: {(12,5),(13,5)} — the ADR's own worked minimal example, 2 tiles
	# (10,000 at overpass's 5,000/tile — Phase 3 economy isn't wired yet, so
	# coverage size stands in for cost here).
	var west := _graph.patch_at(Vector2i(0, 0))
	var east := _graph.patch_at(Vector2i(25, 0))
	assert_false(_graph.same_network(Vector2i(0, 0), Vector2i(25, 0)), "patches start disconnected")
	for c in BOW_VALLEY_SPAN:
		_infra.place(c, "overpass")
	assert_true(_infra.try_complete(SEG, "overpass"), "a full-width span across the road is valid")
	assert_eq(_completed, [[SEG, "overpass", 7]], "crossing_completed emitted once with payload")
	assert_eq(_infra.coverage().size(), 2, "only the 2 placed tiles are covered, not the whole segment")
	assert_true(_graph.same_network(Vector2i(0, 0), Vector2i(25, 0)),
		"the minimal span still links the two patches bordering it")

func test_adr0016_bow_valley_half_width_span_is_invalid() -> void:
	# Row 2: {(12,5)} — reaches only one side of the two-tile-wide road.
	_infra.place(Vector2i(12, 5), "overpass")
	assert_false(_infra.try_complete(SEG, "overpass"), "a half-width span does not reach the far side")
	assert_eq(_infra.coverage().size(), 0, "nothing is covered on rejection")

func test_adr0016_bow_valley_tiles_along_road_is_invalid() -> void:
	# Row 3: three tiles laid along the corridor's length, not across its width.
	_infra.place(Vector2i(12, 3), "overpass")
	_infra.place(Vector2i(12, 4), "overpass")
	_infra.place(Vector2i(12, 5), "overpass")
	assert_false(_infra.try_complete(SEG, "overpass"),
		"tiles laid along a corridor never cross it, however many are placed")

func test_adr0016_bow_valley_whole_corridor_is_valid_via_embedded_core() -> void:
	# Row 4: covering the entire 20-tile segment is valid — it contains the
	# 2-tile core above — even though the covered set as a whole is not
	# two-sided (ADR 0016 §"Why 'contains a two-sided core' rather than 'is
	# two-sided'"). Priced, not policed: an expensive but legal span.
	_place_full_span()
	assert_true(_infra.try_complete(SEG, "overpass"), "the whole corridor is valid — it contains a valid core")
	assert_eq(_infra.coverage().size(), 20, "the whole corridor is covered")

func test_adr0016_snake_river_single_tile_is_valid() -> void:
	# Row 5: {(15,1)} — a single tile is already a valid core on a 1-wide river.
	var infra := _infra_for_sub_area(1)
	infra.place(Vector2i(15, 1), "overpass")
	assert_true(infra.try_complete("s1_snake_river_a", "overpass"), "a single river tile is a valid core")
	assert_eq(infra.coverage().size(), 1, "only the one placed tile is covered")

func test_adr0016_snake_river_tip_tile_is_valid() -> void:
	# Row 6: {(16,0)} — the river's tip, still a valid core.
	var infra := _infra_for_sub_area(1)
	infra.place(Vector2i(16, 0), "overpass")
	assert_true(infra.try_complete("s1_snake_river_a", "overpass"), "the tip tile is also a valid core")

func test_adr0016_snake_river_whole_reach_is_valid() -> void:
	# Row 7: the whole 8-tile braided reach — valid via an embedded 1-tile core.
	var infra := _infra_for_sub_area(1)
	for t in _segment_tiles("s1_snake_river_a"):
		infra.place(Vector2i(int(t[0]), int(t[1])), "overpass")
	assert_true(infra.try_complete("s1_snake_river_a", "overpass"), "the whole 8-tile reach is valid")
	assert_eq(infra.coverage().size(), 8, "the whole reach is covered")

# --- Completion effects, on the minimal span (the intended real usage) -----

func test_completed_minimal_span_route_is_zero_mortality() -> void:
	for c in BOW_VALLEY_SPAN:
		_infra.place(c, "overpass")
	_infra.try_complete(SEG, "overpass")
	var path := Pathfinding.find_path(_world, Vector2i(6, 5), Vector2i(20, 5), { "covered": _infra.coverage() })
	assert_gt(path.size(), 0, "a route exists across the minimal span")
	assert_false(Pathfinding.path_crosses_hazard(_world, path, { "covered": _infra.coverage() }),
		"the route through the minimal 2-tile span is zero-mortality")
