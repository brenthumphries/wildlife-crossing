## Tests for the seasonal terrain overlay (ADR 0022): rivers freeze in winter and
## flood their banks in spring for pathing, mortality and the renderer, while
## patches, population records and crossings stay as they are all year.
extends GutTest

const RIVER_MORTALITY := 0.5
## Sub-area 1's Snake River segment and ADR 0016's single-tile valid core on it.
const RIVER_AREA := 1
const RIVER_SEG := "s1_snake_river_a"
const RIVER_SPAN: Array[Vector2i] = [Vector2i(15, 1)]
## Forest either side of the Snake River's upper reach in sub-area 1.
const WEST_BANK := Vector2i(12, 1)
const EAST_BANK := Vector2i(19, 1)

var _tiles := {
	"forest": { "is_impassable": false, "is_hazardous": false, "biome": "forest", "hazard_mortality_env": null },
	"river": { "is_impassable": false, "is_hazardous": true, "biome": null, "hazard_mortality_env": "RIVER_HAZARD_MORTALITY" },
	"road": { "is_impassable": false, "is_hazardous": true, "biome": null, "hazard_mortality_env": "ROAD_HAZARD_MORTALITY" },
	"fence": { "is_impassable": true, "is_hazardous": false, "biome": null, "hazard_mortality_env": null },
}

## A 5x3 forest with a river down column q=2: every route from q=0 to q=4 must
## step on it, and in spring on the flooded columns q=1 and q=3 as well.
func _river_world() -> WorldData:
	var wd := WorldData.new()
	wd.load_from_dict({ "sub_area_id": 99, "origin": [0, 0],
		"regions": [ { "tile": "forest", "rect": [0, 0, 4, 2] }, { "tile": "river", "rect": [2, 0, 2, 2] } ] }, _tiles)
	return wd

func _hazard_steps(wd: WorldData, path: Array) -> int:
	var n: int = 0
	for c: Vector2i in path:
		if wd.is_effective_hazard(c):
			n += 1
	return n

# --- the overlay itself ----------------------------------------------------

func test_frozen_river_clears_hazard() -> void:
	var wd := _river_world()
	var river := Vector2i(2, 1)
	wd.apply_season(SeasonManager.WINTER)
	assert_true(wd.is_frozen(river), "winter freezes the river")
	assert_false(wd.is_effective_hazard(river), "a frozen river is not hazardous")
	assert_true(wd.is_hazardous(river), "the base flag the graph reads is unchanged")
	assert_false(wd.is_flooded(Vector2i(1, 1)), "nothing floods in winter")
	wd.apply_season(SeasonManager.SPRING)
	assert_false(wd.is_frozen(river), "the ice is gone in spring")
	assert_true(wd.is_effective_hazard(river), "spring restores the river's hazard")
	for bank: Vector2i in [Vector2i(1, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(3, 0)]:
		assert_true(wd.is_flooded(bank), "spring floods the bank at %s" % bank)
		assert_true(wd.is_effective_hazard(bank), "a flooded bank is hazardous at %s" % bank)
		assert_false(wd.is_hazardous(bank), "flooding never touches the base flag at %s" % bank)
	assert_false(wd.is_effective_hazard(Vector2i(0, 1)), "the flood widens by one tile only")
	assert_false(wd.is_effective_hazard(Vector2i(4, 1)), "the flood widens by one tile only, east too")

func test_summer_and_fall_use_the_base_terrain() -> void:
	var wd := _river_world()
	for season: String in [SeasonManager.SUMMER, SeasonManager.FALL]:
		wd.apply_season(SeasonManager.SPRING)
		wd.apply_season(season)
		assert_true(wd.is_effective_hazard(Vector2i(2, 1)), "%s: the river is a hazard" % season)
		assert_false(wd.is_effective_hazard(Vector2i(1, 1)), "%s: the bank is dry" % season)
		assert_false(wd.is_frozen(Vector2i(2, 1)), "%s: the river is open" % season)

func test_a_flood_skips_barriers_and_other_hazards() -> void:
	var wd := WorldData.new()
	wd.load_from_dict({ "sub_area_id": 99, "origin": [0, 0], "cells": [
		{ "q": 0, "r": 0, "tile": "fence" }, { "q": 1, "r": 0, "tile": "river" },
		{ "q": 2, "r": 0, "tile": "road" }, { "q": 1, "r": 1, "tile": "forest" } ] }, _tiles)
	wd.apply_season(SeasonManager.SPRING)
	assert_false(wd.is_flooded(Vector2i(0, 0)), "a fence stays a barrier, not a flood")
	assert_false(wd.is_flooded(Vector2i(2, 0)), "a road keeps its own hazard")
	assert_eq(wd.hazard_tile_at(Vector2i(2, 0)), "road", "and its own mortality")
	assert_true(wd.is_flooded(Vector2i(1, 1)), "the forest beside the river floods")
	assert_eq(wd.hazard_tile_at(Vector2i(1, 1)), "river", "a flooded bank takes the river's mortality")
	assert_eq(wd.hazard_tile_at(Vector2i(1, 0)), "river", "the river is its own hazard tile")

func test_reloading_a_grid_clears_the_overlay() -> void:
	var wd := _river_world()
	wd.apply_season(SeasonManager.WINTER)
	wd.load_from_dict({ "sub_area_id": 99, "origin": [0, 0],
		"regions": [ { "tile": "river", "rect": [0, 0, 0, 0] } ] }, _tiles)
	assert_false(wd.is_frozen(Vector2i(0, 0)), "a fresh grid starts on the base terrain")

# --- pathing and mortality -------------------------------------------------

func test_pathing_reads_the_effective_hazard() -> void:
	var wd := _river_world()
	wd.apply_season(SeasonManager.SUMMER)
	var summer := Pathfinding.find_path(wd, Vector2i(0, 1), Vector2i(4, 1))
	assert_eq(_hazard_steps(wd, summer), 1, "summer: one river tile to cross")
	wd.apply_season(SeasonManager.WINTER)
	var winter := Pathfinding.find_path(wd, Vector2i(0, 1), Vector2i(4, 1))
	assert_false(Pathfinding.path_crosses_hazard(wd, winter), "winter: the ice is a free crossing")
	wd.apply_season(SeasonManager.SPRING)
	var spring := Pathfinding.find_path(wd, Vector2i(0, 1), Vector2i(4, 1))
	assert_eq(_hazard_steps(wd, spring), 3, "spring: bank, river and bank are all hazards")

func test_mortality_reads_the_effective_hazard() -> void:
	var wd := _river_world()
	var env := EnvConfig.new()
	env.setup(_tiles)
	env.set_override("RIVER_HAZARD_MORTALITY", RIVER_MORTALITY)
	var rng := RandomNumberGenerator.new()
	var sm := SpeciesManager.new()
	sm.setup(wd, null, null, {}, env, rng)
	wd.apply_season(SeasonManager.WINTER)
	assert_eq(sm.mortality_chance(Vector2i(2, 1)), 0.0, "nothing drowns crossing the ice")
	wd.apply_season(SeasonManager.SPRING)
	assert_eq(sm.mortality_chance(Vector2i(2, 1)), RIVER_MORTALITY, "the spring river is deadly again")
	assert_eq(sm.mortality_chance(Vector2i(1, 1)), RIVER_MORTALITY, "a flooded bank is as deadly as the river")
	wd.apply_season(SeasonManager.FALL)
	assert_eq(sm.mortality_chance(Vector2i(1, 1)), 0.0, "the bank is dry again in fall")

func test_rendered_seasonal_colours_are_distinct() -> void:
	var wd := _river_world()
	var base_river: Color = WorldRenderer.tile_color(wd, Vector2i(2, 1))
	var base_bank: Color = WorldRenderer.tile_color(wd, Vector2i(1, 1))
	wd.apply_season(SeasonManager.WINTER)
	var frozen: Color = WorldRenderer.tile_color(wd, Vector2i(2, 1))
	wd.apply_season(SeasonManager.SPRING)
	var flooded: Color = WorldRenderer.tile_color(wd, Vector2i(1, 1))
	assert_eq(base_river, WorldRenderer.COLOR_HAZARD, "an open river draws as the hazard red")
	assert_ne(frozen, base_river, "a frozen river reads apart from the open river")
	assert_ne(flooded, base_river, "a flooded bank reads apart from the river")
	assert_ne(flooded, base_bank, "a flooded bank reads apart from the dry bank")
	assert_ne(frozen, flooded, "ice and floodwater read apart")
	assert_ne(frozen, WorldRenderer.COLOR_ALPINE, "ice reads apart from alpine terrain")

# --- the simulation --------------------------------------------------------

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _registries() -> Dictionary:
	var treg: Dictionary = {}
	for t: Dictionary in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var sreg: Dictionary = {}
	for s: Dictionary in _load_json("res://data/species_stats.json")["species"]:
		sreg[s["id"]] = s
	var ireg: Dictionary = {}
	for c: Dictionary in _load_json("res://data/infrastructure.json")["infrastructure"]:
		ireg[c["crossing_type"]] = c
	var seg: Dictionary = {}
	for s: Dictionary in _load_json("res://data/segments.json")["segments"]:
		seg[s["id"]] = s
	return { "tiles": treg, "species": sreg, "infrastructure": ireg, "segments": seg,
		"biome_groups": _load_json("res://data/biome_groups.json") }

func _river_sim() -> Simulation:
	var sim := Simulation.new()
	autofree(sim)
	sim.load_world(RIVER_AREA, _registries(), 42)
	return sim

## A Simulation on the river sub-area, restored to day 0 of `season`.
func _sim_in(season: String) -> Simulation:
	var state: Dictionary = _river_sim().save_state()
	state["clock"] = { "year": 1, "season": season, "day_of_season": 0 }
	var sim := Simulation.new()
	autofree(sim)
	sim.restore_state(state, _registries(), 42)
	return sim

func _population_snapshot(sim: Simulation) -> Dictionary:
	var out: Dictionary = {}
	for idx in sim.graph.patches.size():
		for sid: String in sim.population.resident_species(idx):
			out[sim.graph.patch_key(idx) + "|" + sid] = sim.population.count_of(idx, sid)
	return out

func _patch_keys(sim: Simulation) -> Array:
	var keys: Array = []
	for idx in sim.graph.patches.size():
		keys.append(sim.graph.patch_key(idx))
	return keys

func test_a_loaded_world_starts_in_the_seasons_terrain() -> void:
	var sim := _river_sim()
	assert_true(sim.world.is_flooded(Vector2i(14, 1)), "year 1 opens in spring, so the bank is flooded")
	var winter := _sim_in(SeasonManager.WINTER)
	assert_true(winter.world.is_frozen(Vector2i(15, 1)), "a save restored in winter loads frozen")

func test_season_change_keeps_patches_and_population_records() -> void:
	var sim := _river_sim()
	var graph: ConnectivityGraph = sim.graph
	var keys: Array = _patch_keys(sim)
	var counts: Dictionary = _population_snapshot(sim)
	for season: String in [SeasonManager.SUMMER, SeasonManager.FALL, SeasonManager.WINTER, SeasonManager.SPRING]:
		sim.seasons.season_changed.emit(season)
		assert_same(sim.graph, graph, "%s: the connectivity graph is not rebuilt" % season)
		assert_eq(_patch_keys(sim), keys, "%s: patch identity is unchanged" % season)
		assert_eq(_population_snapshot(sim), counts, "%s: population records are not remapped" % season)

func test_season_change_invalidates_cached_paths() -> void:
	var sim := _river_sim()
	sim.seasons.season_changed.emit(SeasonManager.SUMMER)
	# A stale cached route: a detour no winter A* would choose, part-walked, but
	# ending at the agent's real goal. Only a re-path can replace it.
	var stale: Array = [Vector2i(13, 1), WEST_BANK, Vector2i(12, 2), Vector2i(13, 2), EAST_BANK]
	sim.agents = [{
		"species_id": "gray_wolf", "coord": WEST_BANK, "patch": sim.graph.patch_at(WEST_BANK),
		"path": stale, "idx": 1, "alive": true, "in_crossing": false, "last_crossing": "",
	}]
	sim.seasons.season_changed.emit(SeasonManager.WINTER)
	var a: Dictionary = sim.agents[0]
	var winter: Array = Pathfinding.find_path(sim.world, WEST_BANK, EAST_BANK, { "covered": sim.infrastructure.coverage() })
	assert_ne(a["path"], stale, "the cached path is dropped on season_changed")
	assert_eq(a["path"], winter, "and replaced by this season's route from where the agent stands")
	assert_eq(a["path"][-1], EAST_BANK, "re-pathing keeps the goal the agent already had")
	assert_eq(int(a["idx"]), 0, "the agent starts the new route from where it stands")
	assert_false(Pathfinding.path_crosses_hazard(sim.world, a["path"], { "covered": sim.infrastructure.coverage() }),
		"the winter route crosses the ice with no hazard")

func test_a_span_completes_in_every_season() -> void:
	for season: String in SeasonManager.SEASONS:
		var sim := _sim_in(season)
		assert_eq(sim.seasons.season, season, "the simulation is in %s" % season)
		assert_true(sim.build_crossing(RIVER_SEG, "overpass", RIVER_SPAN), "%s: the river span completes" % season)
		assert_eq(sim.infrastructure.crossings().size(), 1, "%s: one crossing stands" % season)
		assert_eq(sim.species.mortality_chance(RIVER_SPAN[0]), 0.0, "%s: the covered tile is safe" % season)

func test_a_completed_crossing_keeps_working_through_the_year() -> void:
	var sim := _sim_in(SeasonManager.SUMMER)
	assert_true(sim.build_crossing(RIVER_SEG, "overpass", RIVER_SPAN), "the span is built in summer")
	for season: String in [SeasonManager.FALL, SeasonManager.WINTER, SeasonManager.SPRING, SeasonManager.SUMMER]:
		sim.seasons.season_changed.emit(season)
		assert_true(sim.infrastructure.coverage().has(RIVER_SPAN[0]), "%s: the crossing still covers its tile" % season)
		assert_eq(sim.species.mortality_chance(RIVER_SPAN[0]), 0.0, "%s: the covered tile stays safe" % season)
		assert_true(sim.world.is_hazardous(RIVER_SPAN[0]), "%s: the base river under it is unchanged" % season)
