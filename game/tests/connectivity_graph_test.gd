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
