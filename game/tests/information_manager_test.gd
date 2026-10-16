## Tests for InformationManager — purchases, per-product layers, permanence across save and load, locked areas.
extends GutTest

const AREA := 7
const OTHER_AREA := 3
const HOT_TILE := Vector2i(12, 5)
const COOL_TILE := Vector2i(13, 5)
const LAYER_KEYS: Dictionary = {
	"habitat_assessment": ["patches"],
	"population_survey": ["patches"],
	"corridor_study": ["hotspots", "routes"],
}

var _sim: Simulation
var _bought: Array

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

func before_each() -> void:
	_sim = Simulation.new()
	autofree(_sim)
	_sim.load_world(AREA, _registries(), 42)
	_bought = []
	_sim.information.information_purchased.connect(
		func(product: String, area_id: String) -> void: _bought.append([product, area_id]))

func test_costs_match_constants() -> void:
	var info: InformationManager = _sim.information
	assert_eq(info.cost_of("habitat_assessment"), EconomyConstants.INFO_HABITAT_ASSESSMENT, "habitat assessment")
	assert_eq(info.cost_of("population_survey"), EconomyConstants.INFO_POPULATION_SURVEY, "population survey")
	assert_eq(info.cost_of("corridor_study"), EconomyConstants.INFO_CORRIDOR_STUDY, "corridor study")
	assert_eq(info.cost_of("liaison_briefing"), -1, "the liaison briefing is not an area product")
	for product: String in LAYER_KEYS:
		var before: int = _sim.economy.budget
		assert_true(info.purchase(product, AREA), "%s is bought" % product)
		assert_eq(before - _sim.economy.budget, info.cost_of(product), "%s charges its constant" % product)
	assert_eq(_bought.size(), 3, "each purchase emits information_purchased once")
	assert_eq(_bought[0], ["habitat_assessment", "7"], "the area id is announced as a string")

func test_purchase_reveals_layer() -> void:
	var info: InformationManager = _sim.information
	assert_true(info.revealed_layers(AREA).is_empty(), "nothing is revealed before a purchase")
	for product: String in LAYER_KEYS:
		var fresh: Simulation = Simulation.new()
		autofree(fresh)
		fresh.load_world(AREA, _registries(), 42)
		assert_true(fresh.information.purchase(product, AREA), "%s is bought" % product)
		var revealed: Dictionary = fresh.information.revealed_layers(AREA)
		assert_eq(revealed.keys(), [product], "%s exposes only its own layer" % product)
		var keys: Array = revealed[product].keys()
		keys.sort()
		assert_eq(keys, LAYER_KEYS[product], "%s carries its own keys" % product)
	var habitat: Array = _buy_and_read("habitat_assessment")["patches"]
	assert_gt(habitat.size(), 0, "the assessment lists patches")
	assert_true(habitat[0].has("quality") and habitat[0].has("tile_count"), "numeric quality and patch size")
	assert_false(habitat[0].has("species"), "and no population data")
	var west: int = _sim.graph.patch_at(Vector2i(0, 0))
	var survey: Array = _buy_and_read("population_survey")["patches"]
	var found: bool = false
	for p: Dictionary in survey:
		if p["patch_id"] == _sim.graph.patch_key(west):
			for rec: Dictionary in p["species"]:
				if rec["species_id"] == "grizzly_bear":
					found = true
					assert_eq(rec["count"], 18, "the survey reports the count")
					assert_true(rec.has("trend"), "and the trend")
	assert_true(found, "the survey lists the grizzly on the west patch")

func test_corridor_study_reports_attempts_and_hotspots() -> void:
	_sim.information.record_attempt(HOT_TILE)
	_sim.information.record_attempt(HOT_TILE)
	_sim.information.record_attempt(COOL_TILE)
	_sim.information.record_death(HOT_TILE)
	var corridor: Dictionary = _buy_and_read("corridor_study")
	assert_eq((corridor["routes"] as Array).size(), 2, "both attempted tiles are listed")
	assert_eq((corridor["hotspots"] as Array).size(), 1, "only the tile with a death is a hotspot")
	assert_eq(corridor["hotspots"][0]["tile"], HOT_TILE, "the hotspot is the deadly tile")
	assert_eq(corridor["hotspots"][0]["attempts"], 2, "with its attempts")

func test_simulation_feeds_the_corridor_record() -> void:
	for i in 1500:
		_sim.tick()
	var corridor: Dictionary = _buy_and_read("corridor_study")
	assert_gt((corridor["routes"] as Array).size(), 0, "animals approaching the road leave a record")
	assert_gt((corridor["hotspots"] as Array).size(), 0, "and so do the deaths on it")

func test_refused_purchases_charge_nothing() -> void:
	var info: InformationManager = _sim.information
	assert_true(info.purchase("population_survey", AREA), "the first purchase succeeds")
	var after_first: int = _sim.economy.budget
	assert_false(info.purchase("population_survey", AREA), "buying it again is refused")
	assert_false(info.purchase("moat", AREA), "an unknown product is refused")
	assert_eq(_sim.economy.budget, after_first, "neither charges anything")
	assert_eq(_bought.size(), 1, "and neither announces anything")
	_sim.economy.spend(_sim.economy.budget - EconomyConstants.INFO_HABITAT_ASSESSMENT + 1)
	var broke: int = _sim.economy.budget
	assert_false(info.purchase("habitat_assessment", AREA), "one short of the price is refused")
	assert_eq(_sim.economy.budget, broke, "and charges nothing")
	assert_false(info.holds("habitat_assessment", AREA), "and records nothing")

func test_information_is_permanent() -> void:
	_sim.information.purchase("habitat_assessment", AREA)
	_sim.information.purchase("corridor_study", AREA)
	for i in 5:
		_sim.tick()
	assert_true(_sim.information.holds("habitat_assessment", AREA), "still held after ticks")
	var state: Dictionary = JSON.parse_string(JSON.stringify(_sim.save_state()))
	assert_eq(state["information"]["products_by_area"], { "7": ["habitat_assessment", "corridor_study"] },
		"stored by string area id, as the product ids")
	assert_eq(state["information"]["areas_revealed"], ["7"], "areas_revealed lists areas holding any product")
	var other: Simulation = Simulation.new()
	autofree(other)
	other.restore_state(state, _registries(), 42)
	assert_true(other.information.holds("habitat_assessment", AREA), "held after a save and load")
	assert_true(other.information.holds("corridor_study", AREA), "both products")
	assert_false(other.information.holds("population_survey", AREA), "and only those")
	var before: int = other.economy.budget
	assert_false(other.information.purchase("habitat_assessment", AREA), "a restored product cannot be bought twice")
	assert_eq(other.economy.budget, before, "and costs nothing")

func test_restore_without_information_buys_nothing() -> void:
	var state: Dictionary = _sim.save_state()
	state.erase("information")
	var other: Simulation = Simulation.new()
	autofree(other)
	other.restore_state(state, _registries(), 42)
	assert_true(other.information.products_by_area.is_empty(), "omit-means-default")
	other.information.restore({ "products_by_area": { "7": ["habitat_assessment", "bogus", "habitat_assessment"], "9": "no" } })
	assert_eq(other.information.products_by_area, { "7": ["habitat_assessment"] }, "bad entries are skipped")

func test_locked_sub_area_no_ecological_data() -> void:
	var info: InformationManager = _sim.information
	var before: int = _sim.economy.budget
	assert_false(info.purchase("habitat_assessment", OTHER_AREA), "another area cannot be bought for")
	assert_eq(_sim.economy.budget, before, "and costs nothing")
	info.restore({ "products_by_area": { "3": ["habitat_assessment", "population_survey", "corridor_study"] } })
	assert_true(info.revealed_layers(OTHER_AREA).is_empty(), "even a stored purchase exposes nothing for it")
	var locked: Simulation = Simulation.new()
	autofree(locked)
	locked.load_world(AREA, _registries(), 42)
	locked.information.setup(locked.economy, locked.habitat, locked.graph, locked.population, AREA, false)
	assert_false(locked.information.purchase("habitat_assessment", AREA), "a locked loaded area cannot be bought for")
	assert_true(locked.information.layer("habitat_assessment", AREA).is_empty(), "and exposes no layer")

func _buy_and_read(product: String) -> Dictionary:
	_sim.information.purchase(product, AREA)
	return _sim.information.layer(product, AREA)

func test_patch_overview_is_free_sorted_and_has_no_numeric_quality() -> void:
	var info: InformationManager = _sim.information
	var overview: Array = info.patch_overview(AREA)
	assert_eq(overview.size(), _sim.graph.patches.size(), "every patch is listed with nothing bought")
	var seen: Dictionary = {}
	for i in overview.size():
		var entry: Dictionary = overview[i]
		assert_eq(entry["number"], i + 1, "numbered in order")
		assert_false(entry.has("quality"), "the numeric quality is absent before the assessment")
		for value: Variant in entry.values():
			assert_ne(typeof(value), TYPE_FLOAT, "no float, so no numeric quality in disguise")
		assert_true(["Poor", "Fair", "Good", "Excellent"].has(entry["band"]), "the band label is free")
		assert_false(String(entry["biome"]).is_empty(), "so is the biome")
		seen[entry["patch_id"]] = true
		if i > 0:
			var prev: Dictionary = overview[i - 1]
			assert_true(int(prev["tile_count"]) > int(entry["tile_count"])
					or (int(prev["tile_count"]) == int(entry["tile_count"])
					and String(prev["patch_id"]) < String(entry["patch_id"])),
					"largest first, ties by patch key")
	assert_eq(seen.size(), overview.size(), "each patch once")
	assert_true(info.patch_overview(OTHER_AREA).is_empty(), "an area that is not loaded has none")
