## Tests for SpeciesManager: agent-pool sizing, env-var hazard mortality (rate,
## independence, default, coverage), animal_crossed/animal_died emission, and
## deterministic goal selection (ADR 0009/0010, simulation-design §4, §7).
extends GutTest

const TILES := {
	"forest": { "is_impassable": false, "is_hazardous": false, "biome": "forest", "hazard_mortality_env": null },
	"road": { "is_impassable": false, "is_hazardous": true, "biome": null, "hazard_mortality_env": "ROAD_HAZARD_MORTALITY" },
	"river": { "is_impassable": false, "is_hazardous": true, "biome": null, "hazard_mortality_env": "RIVER_HAZARD_MORTALITY" },
}

var _world: WorldData
var _env: EnvConfig
var _rng: RandomNumberGenerator
var _sm: SpeciesManager
var _crossed: Array = []
var _died: Array = []

# A single axial row from tile ids.
func _row(ids: Array) -> WorldData:
	var cells: Array = []
	for i in ids.size():
		cells.append({ "q": i, "r": 0, "tile": ids[i] })
	var wd := WorldData.new()
	wd.load_from_dict({ "sub_area_id": 1, "origin": [0, 0], "cells": cells }, TILES)
	return wd

func before_each() -> void:
	_world = _row(["forest", "road", "river", "forest"])
	_env = EnvConfig.new()
	_env.setup(TILES)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345
	_sm = SpeciesManager.new()
	# graph/habitat/species unused by these tests; pass empties.
	_sm.setup(_world, ConnectivityGraph.new(), HabitatManager.new(), {}, _env, _rng)
	_crossed = []
	_died = []
	_sm.animal_crossed.connect(func(cid, sid): _crossed.append([cid, sid]))
	_sm.animal_died.connect(func(sid, tile, cause): _died.append([sid, tile, cause]))

func _death_rate(coord: Vector2i, n: int) -> float:
	var deaths := 0
	for i in n:
		if _sm.rolls_death(coord):
			deaths += 1
	return float(deaths) / float(n)

func test_rendered_agents_formula() -> void:
	assert_eq(_sm.rendered_agents(0), 0, "empty patch renders none")
	assert_eq(_sm.rendered_agents(25), 1, "ceil(25/25) = 1")
	assert_eq(_sm.rendered_agents(26), 2, "ceil(26/25) = 2")
	assert_eq(_sm.rendered_agents(10000), 8, "capped at MAX_AGENTS_PER_VISIBLE_PATCH")

func test_default_mortality_is_0_20() -> void:
	# No override, no OS env → DEFAULT 0.20 on the road tile.
	assert_almost_eq(_death_rate(Vector2i(1, 0), 4000), 0.20, 0.03, "unset hazard defaults to 0.20")

func test_road_mortality_honours_env_var() -> void:
	_env.set_override("ROAD_HAZARD_MORTALITY", 0.5)
	assert_almost_eq(_death_rate(Vector2i(1, 0), 4000), 0.5, 0.03, "road honours its env var")

func test_river_mortality_independent_of_road() -> void:
	_env.set_override("ROAD_HAZARD_MORTALITY", 0.5)
	# River keeps its own (default) rate; setting road did not move it.
	assert_almost_eq(_death_rate(Vector2i(2, 0), 4000), 0.20, 0.03, "river rate is independent of road")

func test_covered_tile_is_zero_mortality() -> void:
	_sm.set_coverage({ Vector2i(1, 0): "overpass" })
	assert_eq(_sm.mortality_chance(Vector2i(1, 0)), 0.0, "a covered hazard cannot kill")
	assert_false(_sm.rolls_death(Vector2i(1, 0)), "covered tile never rolls a death")

func test_animal_crossed_fires_once_per_traversal() -> void:
	var wd := _row(["forest", "road", "road", "forest"])
	_sm.setup(wd, ConnectivityGraph.new(), HabitatManager.new(), {}, _env, _rng)
	_sm.set_coverage({ Vector2i(1, 0): "overpass", Vector2i(2, 0): "overpass" })
	var path := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var survived := _sm.walk("grizzly_bear", path, "x_test")
	assert_true(survived, "survives the covered crossing")
	assert_eq(_crossed.size(), 1, "animal_crossed fires exactly once per traversal")
	assert_eq(_crossed[0], ["x_test", "grizzly_bear"], "with the crossing id and species")

func test_animal_died_on_uncovered_hazard() -> void:
	_env.set_override("ROAD_HAZARD_MORTALITY", 1.0)            # certain death
	var path := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var survived := _sm.walk("grizzly_bear", path, "x_test")
	assert_false(survived, "dies on the uncovered road")
	assert_eq(_died.size(), 1, "emits animal_died once")
	assert_eq(_died[0][0], "grizzly_bear", "with the species id")
	assert_eq(_crossed.size(), 0, "no crossing was traversed")

func test_select_goal_is_deterministic_for_a_seed() -> void:
	# A small forest world; the assertion is determinism, not the goal's identity.
	var cells: Array = []
	for q in range(0, 6):
		cells.append({ "q": q, "r": 0, "tile": "forest" })
	var wd := WorldData.new()
	wd.load_from_dict({ "sub_area_id": 1, "origin": [0, 0], "cells": cells }, TILES)
	var graph := ConnectivityGraph.new()
	graph.build(wd, { "groups": { "forest_complex": ["forest"] }, "terrain_aliases": {} })
	var habitat := HabitatManager.new()
	habitat.setup(wd, graph, TILES, ["forest"])
	var species := { "grizzly_bear": { "habitat_terrains": ["forest"], "range_tiles": 60 } }
	var rng_a := RandomNumberGenerator.new(); rng_a.seed = 999
	var sm_a := SpeciesManager.new(); sm_a.setup(wd, graph, habitat, species, _env, rng_a)
	var rng_b := RandomNumberGenerator.new(); rng_b.seed = 999
	var sm_b := SpeciesManager.new(); sm_b.setup(wd, graph, habitat, species, _env, rng_b)
	assert_eq(sm_a.select_goal(Vector2i(0, 0), "grizzly_bear"), sm_b.select_goal(Vector2i(0, 0), "grizzly_bear"),
		"same seed yields the same goal (deterministic RNG)")
