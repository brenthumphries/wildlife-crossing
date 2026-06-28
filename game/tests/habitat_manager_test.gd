## Tests for HabitatManager quality formula, bands, and recompute (ADR 0008).
## Worked example: the Bow Valley west forest patch scores Fair in isolation and
## rises to Good when a crossing adds a safe link.
extends GutTest

var _world: WorldData
var _graph: ConnectivityGraph
var _habitat: HabitatManager
var _west: int
var _east: int

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func before_each() -> void:
	var treg: Dictionary = {}
	for t in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var bg: Dictionary = _load_json("res://data/biome_groups.json")
	_world = WorldData.new()
	_world.load_from_dict(WorldData.parse_file("res://data/world/sub_area_7.json"), treg)
	_graph = ConnectivityGraph.new()
	_graph.build(_world, bg)
	_habitat = HabitatManager.new()
	_habitat.setup(_world, _graph, treg, bg["biomes"])
	_west = _graph.patch_at(Vector2i(0, 0))
	_east = _graph.patch_at(Vector2i(25, 0))

func test_quality_clamped_0_100() -> void:
	for i in _graph.patches.size():
		assert_between(_habitat.quality(i), 0.0, 100.0, "patch quality is within [0,100]")

func test_four_bands_mapping() -> void:
	assert_eq(_habitat.band(0.0), "Poor")
	assert_eq(_habitat.band(25.0), "Poor")
	assert_eq(_habitat.band(25.1), "Fair")
	assert_eq(_habitat.band(50.0), "Fair")
	assert_eq(_habitat.band(50.1), "Good")
	assert_eq(_habitat.band(75.0), "Good")
	assert_eq(_habitat.band(75.1), "Excellent")
	assert_eq(_habitat.band(100.0), "Excellent")

func test_west_forest_fair_then_good_after_crossing() -> void:
	var q_iso := _habitat.quality(_west)
	assert_almost_eq(q_iso, 47.88, 0.5, "west forest Fair in isolation")
	assert_eq(_habitat.band(q_iso), "Fair", "isolated band is Fair")
	_graph.add_safe_link(_west, _east)
	var q_con := _habitat.quality(_west)
	assert_almost_eq(q_con, 53.40, 0.5, "west forest rises to Good after the crossing")
	assert_eq(_habitat.band(q_con), "Good", "connected band is Good")
	assert_gt(q_con, q_iso, "a crossing raises quality")

func test_connectivity_bonus_rises_on_new_link() -> void:
	var before := _habitat.connectivity_bonus(_west)
	_graph.add_safe_link(_west, _east)
	assert_gt(_habitat.connectivity_bonus(_west), before, "a new safe link raises connectivity_bonus")

func test_partnership_quality_bonus_applied() -> void:
	var before := _habitat.quality(_west)
	_habitat.set_costewarded(_west)
	assert_almost_eq(_habitat.quality(_west) - before, 8.0, 0.001, "co-stewarded patch gains PARTNERSHIP_QUALITY_BONUS")
