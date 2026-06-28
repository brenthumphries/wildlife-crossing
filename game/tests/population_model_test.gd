## Tests for PopulationModel seeding, gentle decline, reconnection recovery, and
## population_recovered events (ADR 0011, simulation-design §5). The grizzly
## trajectory on the Bow Valley map matches the ADR's worked example.
extends GutTest

var _world: WorldData
var _graph: ConnectivityGraph
var _habitat: HabitatManager
var _pop: PopulationModel
var _west: int
var _east: int
var _recovered: Array = []
const GRIZZLY := "grizzly_bear"

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func before_each() -> void:
	var treg: Dictionary = {}
	for t in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var bg: Dictionary = _load_json("res://data/biome_groups.json")
	var sreg: Dictionary = {}
	for s in _load_json("res://data/species_stats.json")["species"]:
		sreg[s["id"]] = s
	_world = WorldData.new()
	_world.load_from_dict(WorldData.parse_file("res://data/world/sub_area_7.json"), treg)
	_graph = ConnectivityGraph.new()
	_graph.build(_world, bg)
	_habitat = HabitatManager.new()
	_habitat.setup(_world, _graph, treg, bg["biomes"])
	_pop = PopulationModel.new()
	_pop.setup(_graph, _habitat, sreg)
	_west = _graph.patch_at(Vector2i(0, 0))
	_east = _graph.patch_at(Vector2i(25, 0))
	_recovered = []
	_pop.population_recovered.connect(func(p, s, e): _recovered.append([p, s, e]))

func test_seed_is_habitat_derived() -> void:
	_pop.seed_initial()
	assert_eq(_pop.count_of(_west, GRIZZLY), 18, "grizzly seeded at 18 on the west forest patch")
	assert_gt(_pop.count_of(_east, GRIZZLY), 0, "east forest also seeded (populated-but-declining)")

func test_decline_is_gentle_while_fragmented() -> void:
	_pop.seed_initial()
	_pop.monthly_step()
	assert_eq(_pop.count_of(_west, GRIZZLY), 16, "sub-viable patch loses exactly DECLINE_STEP per month")
	assert_eq(_pop.trend_of(_west, GRIZZLY), "falling", "trend is falling while fragmented")
	for i in 5:
		_pop.monthly_step()
	assert_eq(_pop.count_of(_west, GRIZZLY), 6, "18 declines to 6 over six months")

func test_reconnection_produces_recovery() -> void:
	_pop.seed_initial()
	for i in 6:
		_pop.monthly_step()
	assert_eq(_pop.count_of(_west, GRIZZLY), 6, "fragmented down to 6")
	_graph.add_safe_link(_west, _east)            # a crossing connects the patches
	_pop.monthly_step()
	assert_eq(_pop.count_of(_west, GRIZZLY), 11, "recovers 6 -> 11 toward capacity 32")
	assert_eq(_pop.trend_of(_west, GRIZZLY), "rising", "trend is rising once reconnected")

func test_recovery_decelerates_toward_capacity() -> void:
	_pop.seed_initial()
	for i in 6:
		_pop.monthly_step()
	_graph.add_safe_link(_west, _east)
	var traj: Array = []
	for i in 4:
		_pop.monthly_step()
		traj.append(_pop.count_of(_west, GRIZZLY))
	assert_eq(traj, [11, 15, 18, 21], "decelerating approach toward the cap")

func test_locally_extinct_patch_re_establishes_and_fires_returned() -> void:
	_pop.seed_initial()
	_graph.add_safe_link(_west, _east)            # network now viable (248 habitat tiles)
	_pop.set_count(_east, GRIZZLY, 0)             # east locally extinct, source present in network
	_pop.monthly_step()
	assert_eq(_pop.count_of(_east, GRIZZLY), 2, "re-establishes at RE_ESTABLISH_SEED via immigration")
	assert_true([_east, GRIZZLY, "returned"] in _recovered, "fires population_recovered 'returned'")
