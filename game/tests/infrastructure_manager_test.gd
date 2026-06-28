## Tests for InfrastructureManager: placement validation, full-vs-partial span,
## crossing_completed signal + patch link, usage counter, data-driven types
## (ADR 0003, simulation-design §3, test-plan §2).
extends GutTest

var _world: WorldData
var _graph: ConnectivityGraph
var _infra: InfrastructureManager
var _completed: Array = []
const SEG := "s7_trans_canada_bow_a"

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

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

func _place_full_span() -> void:
	for t in _load_json("res://data/segments.json")["segments"][0]["tiles"]:
		_infra.place(Vector2i(int(t[0]), int(t[1])), "overpass")

func test_placeable_on_dangerous_rejected_on_plain() -> void:
	assert_true(_infra.can_place(Vector2i(12, 5), "overpass"), "overpass placeable on a road (hazard) tile")
	assert_false(_infra.can_place(Vector2i(0, 0), "overpass"), "overpass rejected on plain forest")

func test_partial_span_emits_nothing() -> void:
	_infra.place(Vector2i(12, 0), "overpass")          # only one of 20 dangerous cells
	assert_false(_infra.try_complete(SEG, "overpass"), "partial span does not complete")
	assert_eq(_completed.size(), 0, "no crossing_completed on a partial span")
	assert_eq(_infra.coverage().size(), 0, "nothing is covered yet")

func test_full_span_completes_links_and_signals() -> void:
	var west := _graph.patch_at(Vector2i(0, 0))
	var east := _graph.patch_at(Vector2i(25, 0))
	assert_false(_graph.same_network(Vector2i(0, 0), Vector2i(25, 0)), "patches start disconnected")
	_place_full_span()
	assert_true(_infra.try_complete(SEG, "overpass"), "full span completes")
	assert_eq(_completed, [[SEG, "overpass", 7]], "crossing_completed emitted once with payload")
	assert_eq(_infra.coverage().size(), 20, "all 20 dangerous cells are covered")
	assert_true(_graph.same_network(Vector2i(0, 0), Vector2i(25, 0)), "the crossing links the two patches")

func test_completed_route_is_zero_mortality() -> void:
	_place_full_span()
	_infra.try_complete(SEG, "overpass")
	var path := Pathfinding.find_path(_world, Vector2i(6, 5), Vector2i(20, 5), { "covered": _infra.coverage() })
	assert_gt(path.size(), 0, "a route exists across the completed overpass")
	assert_false(Pathfinding.path_crosses_hazard(_world, path, { "covered": _infra.coverage() }),
		"the route over the completed span is zero-mortality")

func test_usage_counter_increments() -> void:
	var cid := _infra.crossing_id_for(SEG)
	_infra.on_animal_crossed(cid)
	_infra.on_animal_crossed(cid)
	assert_eq(_infra.usage_of(cid), 2, "each animal_crossed bumps the usage counter")

func test_crossing_type_is_data_driven() -> void:
	# A corridor (coverable_flags includes is_hazardous) is placeable on a road with
	# no per-type code branch — purely a registry lookup.
	assert_true(_infra.can_place(Vector2i(12, 5), "corridor"), "any registry type resolves by data")
