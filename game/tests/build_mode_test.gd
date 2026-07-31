## Tests for BuildMode: span-placement selectability, running cost, and
## validity against the exact ADR 0016 two-sided-core rule (build-review B4).
## Reuses the same fixture pattern as infrastructure_manager_test.gd — real
## data, no scene tree — and the same seven-row verified-behaviour table,
## since BuildMode now shares InfrastructureManager's static predicate rather
## than re-deriving it.
extends GutTest

var _world: WorldData
var _graph: ConnectivityGraph
var _infra: InfrastructureManager
var _seg: Dictionary
var _build: BuildMode
const SEG_ID := "s7_trans_canada_bow_a"
## ADR 0016's own worked minimal example for this segment.
const BOW_VALLEY_SPAN: Array[Vector2i] = [Vector2i(12, 5), Vector2i(13, 5)]
const COST_PER_TILE := 5000   # overpass, from infrastructure.json

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _fixture_for_sub_area(sa: int) -> Dictionary:
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
	return { "world": world, "graph": graph, "infra": infra, "segments": sreg }

func before_each() -> void:
	var f := _fixture_for_sub_area(7)
	_world = f["world"]
	_graph = f["graph"]
	_infra = f["infra"]
	_seg = f["segments"][SEG_ID]
	_build = BuildMode.new()
	_build.setup(_world, _infra, _seg, "overpass", COST_PER_TILE)

func test_setup_reads_segment_and_type() -> void:
	assert_eq(_build.segment_id, SEG_ID)
	assert_eq(_build.sub_area_id, 7)
	assert_eq(_build.crossing_type, "overpass")
	assert_eq(_build.chosen_count(), 0, "nothing selected yet")

func test_selectable_only_on_the_segments_own_dangerous_tiles() -> void:
	assert_true(_build.is_selectable(Vector2i(12, 5)), "a road tile in this segment")
	assert_false(_build.is_selectable(Vector2i(0, 0)), "plain terrain, not a hazard")

func test_toggle_adds_then_removes() -> void:
	assert_true(_build.toggle(Vector2i(12, 5)), "adds a selectable tile")
	assert_true(_build.is_chosen(Vector2i(12, 5)))
	assert_eq(_build.chosen_count(), 1)
	assert_true(_build.toggle(Vector2i(12, 5)), "toggling again removes it")
	assert_false(_build.is_chosen(Vector2i(12, 5)))
	assert_eq(_build.chosen_count(), 0)

func test_toggle_rejects_a_non_selectable_tile() -> void:
	assert_false(_build.toggle(Vector2i(0, 0)), "plain terrain is never added")
	assert_eq(_build.chosen_count(), 0)

func test_running_cost_scales_with_selection() -> void:
	assert_eq(_build.running_cost(), 0)
	_build.toggle(Vector2i(12, 5))
	assert_eq(_build.running_cost(), COST_PER_TILE)
	_build.toggle(Vector2i(13, 5))
	assert_eq(_build.running_cost(), COST_PER_TILE * 2)

func test_nothing_is_written_to_infrastructure_until_confirmed() -> void:
	for c in BOW_VALLEY_SPAN:
		_build.toggle(c)
	assert_true(_build.is_valid(), "the selection is a valid span")
	assert_eq(_infra.coverage().size(), 0, "BuildMode never touches InfrastructureManager on its own")

# --- validity against ADR 0016's own verified-behaviour table --------------

func test_empty_selection_is_invalid_with_the_empty_reason() -> void:
	assert_false(_build.is_valid())
	assert_eq(_build.rejection_reason(), BuildMode.REJECT_EMPTY)

func test_bow_valley_full_width_span_is_valid() -> void:
	for c in BOW_VALLEY_SPAN:
		_build.toggle(c)
	assert_true(_build.is_valid(), "the ADR's own worked minimal example")

func test_bow_valley_half_width_span_is_invalid() -> void:
	_build.toggle(Vector2i(12, 5))
	assert_false(_build.is_valid(), "reaches only one side of the two-tile-wide road")
	assert_eq(_build.rejection_reason(), BuildMode.REJECT_NO_CORE)

func test_bow_valley_tiles_along_road_is_invalid() -> void:
	_build.toggle(Vector2i(12, 3))
	_build.toggle(Vector2i(12, 4))
	_build.toggle(Vector2i(12, 5))
	assert_false(_build.is_valid(), "laid along the corridor, not across it")

func test_snake_river_single_tile_is_valid() -> void:
	var f := _fixture_for_sub_area(1)
	var build := BuildMode.new()
	build.setup(f["world"], f["infra"], f["segments"]["s1_snake_river_a"], "overpass", COST_PER_TILE)
	build.toggle(Vector2i(15, 1))
	assert_true(build.is_valid(), "a single tile is already a valid core on a 1-wide river")

# --- confirming a valid selection matches the live check exactly -----------

func test_confirmed_valid_selection_completes_via_build_crossing() -> void:
	for c in BOW_VALLEY_SPAN:
		_build.toggle(c)
	assert_true(_build.is_valid())
	assert_true(_infra.build_span(_build.segment_id, _build.crossing_type, _build.chosen_tiles()),
		"a BuildMode-validated selection is never refused at real completion time")
	assert_eq(_infra.coverage().size(), 2)
