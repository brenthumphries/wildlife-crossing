## Information purchases: three per-area products, each unlocking exactly one ecological layer, permanently.
class_name InformationManager
extends RefCounted

## Emitted once per accepted purchase with the product id and the sub-area id as a
## string; Simulation relays it to EventBus.
signal information_purchased(product: String, area_id: String)

const HABITAT_ASSESSMENT := "habitat_assessment"
const POPULATION_SURVEY := "population_survey"
const CORRIDOR_STUDY := "corridor_study"

## Product id -> price, straight from EconomyConstants (data-schemas §10).
const PRODUCT_COSTS: Dictionary = {
	HABITAT_ASSESSMENT: EconomyConstants.INFO_HABITAT_ASSESSMENT,
	POPULATION_SURVEY: EconomyConstants.INFO_POPULATION_SURVEY,
	CORRIDOR_STUDY: EconomyConstants.INFO_CORRIDOR_STUDY,
}

## Sub-area id (as a string, because JSON turns integer keys into floats) -> the
## list of product ids bought for it. This is what the save stores.
var products_by_area: Dictionary = {}

var _economy: EconomyManager
var _habitat: HabitatManager
var _graph: ConnectivityGraph
var _population: PopulationModel
var _loaded_area_id: int = 0
var _loaded_area_unlocked: bool = false
## This session's attempts at hazardous tiles and deaths on them, per tile:
## Vector2i -> { "attempts": int, "deaths": int }. Not saved; a load starts the
## record afresh, as the economy's monthly tally does.
var _route_tally: Dictionary = {}

## Bind the systems whose state the layers read, and say which sub-area is loaded and
## whether it is unlocked. Only that sub-area can be bought for or read from.
func setup(economy: EconomyManager, habitat: HabitatManager, graph: ConnectivityGraph,
		population: PopulationModel, area_id: int, unlocked: bool) -> void:
	_economy = economy
	_habitat = habitat
	_graph = graph
	_population = population
	_loaded_area_id = area_id
	_loaded_area_unlocked = unlocked
	_route_tally.clear()

## Price of `product`, or -1 for an id that is not one of the three area products.
func cost_of(product: String) -> int:
	return int(PRODUCT_COSTS.get(product, -1))

## Whether `area_id` is the loaded, unlocked sub-area: the only one with an ecological layer.
func is_readable(area_id: int) -> bool:
	return _loaded_area_unlocked and area_id == _loaded_area_id

## Whether `product` has been bought for `area_id`.
func holds(product: String, area_id: int) -> bool:
	return (products_by_area.get(str(area_id), []) as Array).has(product)

## Buy `product` for `area_id`. Refused, charging nothing and announcing nothing, for an
## unknown product, an area that is not the loaded unlocked one, a product already held,
## or a balance that does not cover it. Returns whether the purchase happened.
func purchase(product: String, area_id: int) -> bool:
	var cost: int = cost_of(product)
	if cost < 0 or not is_readable(area_id) or holds(product, area_id):
		return false
	if not _economy.spend(cost):
		return false
	var owned: Array = products_by_area.get(str(area_id), [])
	owned.append(product)
	products_by_area[str(area_id)] = owned
	information_purchased.emit(product, str(area_id))
	return true

## The layer `product` reveals for `area_id`, or {} when it is not held or the area
## exposes no ecological data. Each product returns only its own keys.
func layer(product: String, area_id: int) -> Dictionary:
	if not is_readable(area_id) or not holds(product, area_id):
		return {}
	match product:
		HABITAT_ASSESSMENT:
			return { "patches": _habitat_patches() }
		POPULATION_SURVEY:
			return { "patches": _population_patches() }
		CORRIDOR_STUDY:
			return _corridor_layer()
	return {}

## What every patch shows for free, largest first (ties by patch key): `number` (1-based
## in that order), `patch_id`, `biome`, `tile_count` and the habitat `band` label. It never
## carries the numeric quality, which only the habitat assessment layer holds. Empty for an
## area that is not the loaded unlocked one.
func patch_overview(area_id: int) -> Array:
	if not is_readable(area_id):
		return []
	var out: Array = []
	for idx in _graph.patches.size():
		out.append({
			"patch_id": _graph.patch_key(idx),
			"biome": _habitat.patch_biome(idx),
			"tile_count": _graph.patch_tile_count(idx),
			"band": _habitat.band(_habitat.quality(idx)),
		})
	out.sort_custom(_by_size_then_key)
	for i in out.size():
		out[i]["number"] = i + 1
	return out

## Every layer held for `area_id`, keyed by product id; empty when none is.
func revealed_layers(area_id: int) -> Dictionary:
	var out: Dictionary = {}
	for product: String in PRODUCT_COSTS:
		var data: Dictionary = layer(product, area_id)
		if not data.is_empty():
			out[product] = data
	return out

## Tally one agent stepping onto a hazardous, uncovered tile.
func record_attempt(tile: Vector2i) -> void:
	_entry(tile)["attempts"] = int(_entry(tile)["attempts"]) + 1

## Tally one death on `tile`.
func record_death(tile: Vector2i) -> void:
	_entry(tile)["deaths"] = int(_entry(tile)["deaths"]) + 1

## The §14 `information` keys this manager owns: `areas_revealed` (areas holding any
## product, as strings) and `products_by_area`.
func save_state() -> Dictionary:
	return {
		"areas_revealed": products_by_area.keys(),
		"products_by_area": products_by_area.duplicate(true),
	}

## Replace the purchases from a saved `information` block without announcing them.
## Unknown product ids and malformed entries are skipped; an absent or empty
## `products_by_area` leaves nothing bought (omit-means-default).
func restore(saved: Dictionary) -> void:
	products_by_area = {}
	var raw: Variant = saved.get("products_by_area", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key: Variant in (raw as Dictionary):
		var bought: Variant = (raw as Dictionary)[key]
		if typeof(bought) != TYPE_ARRAY:
			continue
		var owned: Array = []
		for product: Variant in (bought as Array):
			if PRODUCT_COSTS.has(product) and not owned.has(product):
				owned.append(product)
		if not owned.is_empty():
			products_by_area[str(key)] = owned

func _entry(tile: Vector2i) -> Dictionary:
	if not _route_tally.has(tile):
		_route_tally[tile] = { "attempts": 0, "deaths": 0 }
	return _route_tally[tile]

func _habitat_patches() -> Array:
	var out: Array = []
	for idx in _graph.patches.size():
		var score: float = _habitat.quality(idx)
		out.append({
			"patch_id": _graph.patch_key(idx),
			"quality": score,
			"band": _habitat.band(score),
			"tile_count": _graph.patch_tile_count(idx),
		})
	return out

func _population_patches() -> Array:
	var out: Array = []
	for idx in _graph.patches.size():
		var records: Array = []
		for sid: String in _population.resident_species(idx):
			records.append({
				"species_id": sid,
				"count": _population.count_of(idx, sid),
				"trend": _population.trend_of(idx, sid),
			})
		if not records.is_empty():
			out.append({ "patch_id": _graph.patch_key(idx), "species": records })
	return out

## `routes`: every hazardous tile an agent tried, with attempts and deaths.
## `hotspots`: the tiles with deaths, deadliest first (ties by q then r).
func _corridor_layer() -> Dictionary:
	var routes: Array = []
	for tile: Vector2i in _route_tally:
		var e: Dictionary = _route_tally[tile]
		routes.append({ "tile": tile, "attempts": int(e["attempts"]), "deaths": int(e["deaths"]) })
	routes.sort_custom(_by_tile)
	var hotspots: Array = routes.filter(func(r: Dictionary) -> bool: return int(r["deaths"]) > 0)
	hotspots.sort_custom(_by_deaths)
	return { "routes": routes, "hotspots": hotspots }

func _by_tile(a: Dictionary, b: Dictionary) -> bool:
	var ta: Vector2i = a["tile"]
	var tb: Vector2i = b["tile"]
	return ta.x < tb.x or (ta.x == tb.x and ta.y < tb.y)

func _by_deaths(a: Dictionary, b: Dictionary) -> bool:
	if int(a["deaths"]) != int(b["deaths"]):
		return int(a["deaths"]) > int(b["deaths"])
	return _by_tile(a, b)

func _by_size_then_key(a: Dictionary, b: Dictionary) -> bool:
	if int(a["tile_count"]) != int(b["tile_count"]):
		return int(a["tile_count"]) > int(b["tile_count"])
	return String(a["patch_id"]) < String(b["patch_id"])
