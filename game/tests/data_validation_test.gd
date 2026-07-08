## Validates every static data file against its schema and the §11 acceptance
## checklist in docs/data-schemas.md. Loads the real files from res://data/ via
## the production path so the data ships exactly as tested.
extends GutTest

const DATA := "res://data/"
const WORLD := "res://data/world/"
const FIXTURES := "res://tests/fixtures/"

const CANONICAL_BIOMES := ["forest", "grassland", "alpine", "wetland",
	"sagebrush", "boreal", "old_growth", "cliff"]

# --- helpers ---------------------------------------------------------------

func _load_obj(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "data file exists: " + path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "parses as JSON object: " + path)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _records(file_name: String, key: String) -> Array:
	var obj := _load_obj(DATA + file_name)
	assert_true(obj.has("data_version"), file_name + " has data_version")
	assert_true(obj.has(key), file_name + " has '" + key + "' array")
	return obj.get(key, [])

func _has_fields(rec: Dictionary, fields: Array, ctx: String) -> void:
	for f in fields:
		assert_true(rec.has(f), ctx + " has field '" + f + "'")

# --- §2 tiles --------------------------------------------------------------

func test_tiles_schema() -> void:
	var tiles := _records("tiles.json", "tiles")
	assert_gt(tiles.size(), 0, "tiles.json is non-empty")
	for t in tiles:
		var ctx := "tile " + str(t.get("id", "?"))
		_has_fields(t, ["id", "display_name", "category", "is_impassable",
			"is_hazardous", "sprite_set"], ctx)
		assert_true(["terrain", "hazard", "barrier", "crossing"].has(t["category"]),
			ctx + " category is valid")
		# Invariant: the two danger flags are never both true.
		assert_false(t["is_impassable"] and t["is_hazardous"],
			ctx + " is not both impassable and hazardous")
		# Terrain biomes must be canonical (or null for non-terrain).
		var biome: Variant = t.get("biome", null)
		if biome != null:
			assert_true(CANONICAL_BIOMES.has(biome), ctx + " biome '" + str(biome) + "' is canonical")

# --- §3 species ------------------------------------------------------------

func test_species_schema_and_count() -> void:
	var species := _records("species_stats.json", "species")
	assert_eq(species.size(), 8, "all eight launch species present")
	var aliases: Dictionary = _load_obj(DATA + "biome_groups.json").get("terrain_aliases", {})
	for s in species:
		var ctx := "species " + str(s.get("id", "?"))
		_has_fields(s, ["id", "display_name", "habitat_terrains", "min_viable_patch_size",
			"range_tiles", "preferred_crossing_type", "seasonal_pattern",
			"status_weight", "sprite_set"], ctx)
		assert_true(["overpass", "underpass", "corridor"].has(s["preferred_crossing_type"]),
			ctx + " preferred_crossing_type valid")
		assert_true(["resident", "seasonal_migration", "elevational_migration", "hibernates"].has(s["seasonal_pattern"]),
			ctx + " seasonal_pattern valid")
		assert_true(int(s["status_weight"]) >= 1 and int(s["status_weight"]) <= 3,
			ctx + " status_weight in 1..3")
		# Every habitat terrain resolves to a canonical biome directly or via alias.
		for terrain in s["habitat_terrains"]:
			var resolves: bool = CANONICAL_BIOMES.has(terrain) or aliases.has(terrain)
			assert_true(resolves, ctx + " habitat terrain '" + str(terrain) + "' resolves to a biome")

# --- §4 sub-areas ----------------------------------------------------------

func test_sub_areas_schema() -> void:
	var subs := _records("sub_areas.json", "sub_areas")
	var entity_ids := _entity_id_set()
	assert_eq(subs.size(), 12, "all twelve sub-areas present")
	var unlocked := 0
	for sa in subs:
		var ctx := "sub_area " + str(sa.get("id", "?"))
		_has_fields(sa, ["id", "name", "controlling_entity_id", "playable_tile_count",
			"trust_threshold", "starts_unlocked"], ctx)
		assert_true(entity_ids.has(sa["controlling_entity_id"]),
			ctx + " controlling_entity_id resolves to an entity")
		# ±15% of the 4000-tile target.
		var count := int(sa["playable_tile_count"])
		assert_true(count >= 3400 and count <= 4600, ctx + " tile count within ±15% of 4000")
		if sa["starts_unlocked"]:
			unlocked += 1
			assert_eq(int(sa["id"]), 7, "only sub-area 7 starts unlocked")
	assert_eq(unlocked, 1, "exactly one sub-area starts unlocked")

# --- §6 entities -----------------------------------------------------------

func _entity_id_set() -> Dictionary:
	var ids := {}
	for e in _records("entities.json", "entities"):
		ids[e["id"]] = true
	return ids

func test_entities_schema() -> void:
	var entities := _records("entities.json", "entities")
	assert_eq(entities.size(), 9, "nine entities enumerated")
	var fn_count := 0
	var governed := {}
	for e in entities:
		var ctx := "entity " + str(e.get("id", "?"))
		_has_fields(e, ["id", "display_name", "type", "governs_sub_areas",
			"trust_threshold", "metric_weights", "top_conditions", "is_first_nations"], ctx)
		assert_eq((e["top_conditions"] as Array).size(), 3, ctx + " has three top_conditions")
		# metric weights sum to 1.0 (within float tolerance).
		var sum := 0.0
		for w in (e["metric_weights"] as Dictionary).values():
			sum += float(w)
		assert_almost_eq(sum, 1.0, 0.001, ctx + " metric_weights sum to 1.0")
		if e["is_first_nations"]:
			fn_count += 1
		for sid in e["governs_sub_areas"]:
			governed[int(sid)] = true
	assert_eq(fn_count, 3, "three First Nations entities")
	# All twelve sub-areas are governed by some entity.
	for i in range(1, 13):
		assert_true(governed.has(i), "sub-area " + str(i) + " is governed by an entity")

# --- §8 infrastructure -----------------------------------------------------

func test_infrastructure_schema() -> void:
	var infra := _records("infrastructure.json", "infrastructure")
	var v1_available := []
	for c in infra:
		var ctx := "crossing " + str(c.get("crossing_type", "?"))
		_has_fields(c, ["crossing_type", "display_name", "cost_per_tile",
			"coverable_flags", "preference_cost_modifier", "biome_sprite_variants",
			"available_in_v1"], ctx)
		if c["available_in_v1"]:
			v1_available.append(c["crossing_type"])
		if c["crossing_type"] == "overpass":
			assert_eq(int(c["cost_per_tile"]), 5000, "overpass costs 5000/tile")
			assert_true(c["available_in_v1"], "overpass available in v1")
	assert_eq(v1_available, ["overpass"], "only overpass is available in v1")

# --- §7 milestones ---------------------------------------------------------

func test_milestones_schema() -> void:
	var ms := _records("milestones.json", "milestones")
	var capstones := 0
	for m in ms:
		var ctx := "milestone " + str(m.get("id", "?"))
		_has_fields(m, ["id", "display_name", "scope", "condition", "reward_bonus", "is_capstone"], ctx)
		assert_true(["sub_area", "capstone"].has(m["scope"]), ctx + " scope valid")
		if m["scope"] == "sub_area":
			assert_ne(m.get("sub_area_id", null), null, ctx + " sub_area milestone has sub_area_id")
		if m["is_capstone"]:
			capstones += 1
	assert_eq(capstones, 1, "exactly one capstone milestone")

# --- §13 biome groups ------------------------------------------------------

func test_biome_groups_schema() -> void:
	var bg := _load_obj(DATA + "biome_groups.json")
	_has_fields(bg, ["data_version", "biomes", "groups"], "biome_groups.json")
	var biomes: Array = bg["biomes"]
	# Every canonical biome appears in exactly one group.
	var seen := {}
	for group_id in (bg["groups"] as Dictionary):
		for b in bg["groups"][group_id]:
			assert_true(biomes.has(b), "group biome '" + str(b) + "' is canonical")
			assert_false(seen.has(b), "biome '" + str(b) + "' appears in exactly one group")
			seen[b] = true
	for b in biomes:
		assert_true(seen.has(b), "canonical biome '" + str(b) + "' belongs to a group")
	# Every alias target is canonical, and alias keys never shadow canonical ids.
	for alias in bg.get("terrain_aliases", {}):
		assert_true(biomes.has(bg["terrain_aliases"][alias]),
			"alias '" + str(alias) + "' resolves to a canonical biome")
		assert_false(biomes.has(alias), "alias key '" + str(alias) + "' does not shadow a canonical biome")

# --- §12 world maps ----------------------------------------------------------

func test_all_sub_area_world_maps_resolve() -> void:
	var registry := {}
	for t in _records("tiles.json", "tiles"):
		registry[t["id"]] = t
	for i in range(1, 13):
		var path := WORLD + "sub_area_%d.json" % i
		var ctx := "sub_area_%d map" % i
		var m := _load_obj(path)
		_has_fields(m, ["data_version", "sub_area_id", "origin", "cells"], ctx)
		assert_eq(int(m.get("sub_area_id", -1)), i, ctx + " sub_area_id matches its filename")
		for region in m.get("regions", []):
			assert_true(registry.has(region["tile"]),
				ctx + " region tile '" + str(region["tile"]) + "' is registered")
		var occupied := {}
		var has_road := false
		for cell in m["cells"]:
			assert_true(registry.has(cell["tile"]),
				ctx + " cell tile '" + str(cell["tile"]) + "' is registered")
			var key := str(int(cell["q"])) + "," + str(int(cell["r"]))
			assert_false(occupied.has(key), ctx + " cell [" + key + "] appears at most once")
			occupied[key] = true
			if cell["tile"] == "road":
				has_road = true
		assert_true(has_road, ctx + " has at least one road (future segment site)")
		# Loads via the production path into a non-empty grid (B4 acceptance).
		var wd := WorldData.new()
		wd.load_from_dict(WorldData.parse_file(path), registry)
		assert_gt(wd.tile_count(), 0, ctx + " loads via WorldData.parse_file")

func test_world_map_fixture_resolves() -> void:
	var path := FIXTURES + "bow_valley_slice.json"
	var m := _load_obj(path)
	_has_fields(m, ["data_version", "sub_area_id", "origin", "cells"], "bow_valley_slice")
	var tile_ids := {}
	for t in _records("tiles.json", "tiles"):
		tile_ids[t["id"]] = true
	for region in m.get("regions", []):
		assert_true(tile_ids.has(region["tile"]), "region tile '" + str(region["tile"]) + "' is registered")
	var occupied := {}
	for cell in m["cells"]:
		assert_true(tile_ids.has(cell["tile"]), "cell tile '" + str(cell["tile"]) + "' is registered")
		var key := str(int(cell["q"])) + "," + str(int(cell["r"]))
		assert_false(occupied.has(key), "cell [" + key + "] appears at most once")
		occupied[key] = true
