## Tests for ConnectivityGraph: biome-based patch derivation, contiguity links,
## crossing links, and species-relative viability over the network
## (ADR 0004, ADR 0007). Asserts the grizzly rescue case on the Bow Valley map.
extends GutTest

const BIOME_GROUPS := {
	"biomes": ["forest", "grassland", "alpine", "wetland", "sagebrush", "boreal", "old_growth", "cliff"],
	"groups": {
		"forest_complex": ["forest", "old_growth"],
		"open_range": ["grassland", "sagebrush"],
		"alpine": ["alpine"], "boreal": ["boreal"], "wetland": ["wetland"], "cliff": ["cliff"],
	},
	"terrain_aliases": { "forest_edge": "forest", "alpine_meadow": "alpine",
		"subalpine": "alpine", "alpine_grassland": "alpine" },
}

const TILES := {
	"forest": { "is_impassable": false, "is_hazardous": false, "biome": "forest" },
	"alpine_meadow": { "is_impassable": false, "is_hazardous": false, "biome": "alpine" },
	"road": { "is_impassable": false, "is_hazardous": true, "biome": null },
}

const GRIZZLY := { "habitat_terrains": ["forest", "alpine_meadow"], "min_viable_patch_size": 220 }

func _bow_valley() -> ConnectivityGraph:
	var map := WorldData.parse_file("res://data/world/sub_area_7.json")
	var wd := WorldData.new()
	wd.load_from_dict(map, TILES)
	var cg := ConnectivityGraph.new()
	cg.build(wd, BIOME_GROUPS)
	return cg

func test_patches_derived_split_by_hazard() -> void:
	var cg := _bow_valley()
	# Two 120-tile forest patches + one 8-tile alpine patch.
	assert_eq(cg.patches.size(), 3, "road band splits forest into two patches, plus alpine")
	var west := cg.patch_at(Vector2i(0, 0))
	var east := cg.patch_at(Vector2i(25, 0))
	var alpine := cg.patch_at(Vector2i(0, 10))
	assert_eq(cg.patch_tile_count(west), 120, "west forest patch is 120 tiles")
	assert_eq(cg.patch_tile_count(east), 120, "east forest patch is 120 tiles")
	assert_eq(cg.patch_tile_count(alpine), 8, "alpine patch is 8 tiles")

func test_hazard_separates_forest_patches() -> void:
	var cg := _bow_valley()
	assert_false(cg.same_network(Vector2i(0, 0), Vector2i(25, 0)),
		"the two forest patches are not connected across the highway")
	# West forest is contiguity-linked to the alpine patch (adjacent terrain).
	assert_true(cg.same_network(Vector2i(0, 0), Vector2i(0, 10)),
		"west forest and the touching alpine patch share a network")

func test_grizzly_subviable_then_rescued_by_crossing() -> void:
	var cg := _bow_valley()
	var west := cg.patch_at(Vector2i(0, 0))
	var east := cg.patch_at(Vector2i(25, 0))
	# Before the crossing: west network = forest 120 + alpine 8 = 128; east = 120. Both < 220.
	assert_eq(cg.habitat_tile_count(cg.network_of(west), GRIZZLY), 128, "west network habitat = 128")
	assert_eq(cg.habitat_tile_count(cg.network_of(east), GRIZZLY), 120, "east network habitat = 120")
	assert_false(cg.is_viable(Vector2i(0, 0), GRIZZLY), "grizzly sub-viable while fragmented")
	# A crossing links the two forest patches.
	cg.add_safe_link(west, east)
	assert_true(cg.same_network(Vector2i(0, 0), Vector2i(25, 0)), "crossing joins the patches")
	assert_eq(cg.habitat_tile_count(cg.network_of(west), GRIZZLY), 248, "joined network habitat = 248")
	assert_true(cg.is_viable(Vector2i(0, 0), GRIZZLY), "grizzly viable once the crossing connects them")

func test_alias_resolution_for_habitat_biomes() -> void:
	var cg := _bow_valley()
	var biomes := cg.resolve_habitat_biomes(GRIZZLY)
	assert_true(biomes.has("forest"), "forest resolves directly")
	assert_true(biomes.has("alpine"), "alpine_meadow resolves to alpine via alias")

# --- fragmentation deficit (roadmap Phase 3, Decision logged 2026-10-15) ----

## A graph over forest columns separated by one-tile-wide road columns, so each
## forest block is its own patch. `widths` gives each block's width in columns;
## every block is `height` rows tall.
func _strips(widths: Array, height: int) -> ConnectivityGraph:
	var regions: Array = []
	var q: int = 0
	for i in widths.size():
		regions.append({ "rect": [q, 0, q + int(widths[i]) - 1, height - 1], "tile": "forest" })
		q += int(widths[i])
		if i < widths.size() - 1:
			regions.append({ "rect": [q, 0, q, height - 1], "tile": "road" })
			q += 1
	var wd := WorldData.new()
	wd.load_from_dict({ "sub_area_id": 99, "origin": [0, 0], "regions": regions }, TILES)
	var cg := ConnectivityGraph.new()
	cg.build(wd, BIOME_GROUPS)
	return cg

func _patches_at_strip_starts(cg: ConnectivityGraph, widths: Array) -> Array:
	var out: Array = []
	var q: int = 0
	for w in widths:
		out.append(cg.patch_at(Vector2i(q, 0)))
		q += int(w) + 1
	return out

func test_deficit_of_two_equal_halves_is_one() -> void:
	var cg := _strips([2, 2], 4)
	assert_eq(cg.patches.size(), 2, "the road column splits two equal patches")
	assert_almost_eq(cg.fragmentation_deficit(_patches_at_strip_starts(cg, [2, 2])), 1.0, 0.0001,
		"two equal halves score 1.0 (a 2.0x multiplier)")

func test_deficit_of_a_ten_percent_sliver_is_a_tenth() -> void:
	var cg := _strips([10, 1], 10)     # 100 tiles and 10 tiles
	assert_almost_eq(cg.fragmentation_deficit(_patches_at_strip_starts(cg, [10, 1])), 0.1, 0.0001,
		"a 10% sliver joined to a large network scores 0.1 (a 1.1x multiplier)")

func test_deficit_of_patches_already_in_one_network_is_zero() -> void:
	var cg := _bow_valley()
	var west := cg.patch_at(Vector2i(0, 0))
	var alpine := cg.patch_at(Vector2i(0, 10))
	assert_true(cg.network_of(west).has(alpine), "the fixture patches share a network")
	assert_eq(cg.fragmentation_deficit([west, alpine]), 0.0,
		"patches already in one network cost nothing to join")

func test_deficit_counts_each_network_once() -> void:
	var cg := _strips([2, 2], 4)
	var ids: Array = _patches_at_strip_starts(cg, [2, 2])
	assert_almost_eq(cg.fragmentation_deficit([ids[0], ids[0], ids[1], ids[1]]), 1.0, 0.0001,
		"repeating a patch does not double its network")

func test_deficit_is_capped_at_one() -> void:
	var cg := _strips([2, 2, 2], 4)
	assert_almost_eq(cg.fragmentation_deficit(_patches_at_strip_starts(cg, [2, 2, 2])), 1.0, 0.0001,
		"three equal networks would score 2.0 uncapped; min(1, ...) holds it at 1.0")

func test_deficit_of_nothing_is_zero() -> void:
	assert_eq(_strips([2, 2], 4).fragmentation_deficit([]), 0.0, "no bordering patches, no deficit")
