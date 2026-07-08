## Tests for ConnectivityOverlay: cached patch/segment scores from the
## patch-adjacency graph, orange→teal gradient mapping, worst-three pulse
## selection, cache rebuild on graph change, and segment-mode-only visibility
## (crossing-location-selection PRD resolved decisions; ADR 0004).
extends GutTest

const TILES := {
	"forest": { "is_impassable": false, "is_hazardous": false, "biome": "forest", "hazard_mortality_env": null },
	"road": { "is_impassable": false, "is_hazardous": true, "biome": null, "hazard_mortality_env": "ROAD_HAZARD_MORTALITY" },
}

const BIOME_GROUPS := {
	"groups": { "woodland": ["forest"] },
	"terrain_aliases": {},
}

const SUB_AREAS := {
	7: { "id": 7, "name": "Central Canadian Rockies", "starts_unlocked": true },
}

var _o: ConnectivityOverlay
var _c: WorldSelectController
var _world: WorldData
var _graph: ConnectivityGraph

func after_each() -> void:
	if _o != null:
		_o.free()
		_o = null
	if _c != null:
		_c.free()
		_c = null

# A single axial row from tile ids, with its derived patch graph.
func _make_overlay(ids: Array, segments: Array) -> void:
	var cells: Array = []
	for i: int in ids.size():
		cells.append({ "q": i, "r": 0, "tile": ids[i] })
	_world = WorldData.new()
	_world.load_from_dict({ "sub_area_id": 7, "origin": [0, 0], "cells": cells }, TILES)
	_graph = ConnectivityGraph.new()
	_graph.build(_world, BIOME_GROUPS)
	_o = ConnectivityOverlay.new()
	_o.setup(_world, _graph, segments)

func _seg(id: String, cols: Array) -> Dictionary:
	var tiles: Array = []
	for c: int in cols:
		tiles.append([c, 0])
	return { "id": id, "sub_area_id": 7, "tiles": tiles }

# --- cached patch scores (ADR 0004: overlay reads cached values) -------------

func test_patch_scores_reflect_network_share() -> void:
	# forest,forest | road | forest → networks of 2 and 1 habitat tiles (total 3).
	_make_overlay(["forest", "forest", "road", "forest"], [])
	assert_almost_eq(_o.patch_score(_graph.patch_at(Vector2i(0, 0))), 2.0 / 3.0, 0.001)
	assert_almost_eq(_o.patch_score(_graph.patch_at(Vector2i(3, 0))), 1.0 / 3.0, 0.001)

func test_single_network_scores_one_everywhere() -> void:
	_make_overlay(["forest", "forest", "forest"], [])
	assert_almost_eq(_o.patch_score(_graph.patch_at(Vector2i(1, 0))), 1.0, 0.001)

func test_rebuild_after_safe_link_merges_networks() -> void:
	_make_overlay(["forest", "forest", "road", "forest"], [])
	_graph.add_safe_link(
			_graph.patch_at(Vector2i(0, 0)), _graph.patch_at(Vector2i(3, 0)))
	_o.rebuild_cache()
	assert_almost_eq(_o.patch_score(_graph.patch_at(Vector2i(3, 0))), 1.0, 0.001,
			"a crossing link joins both patches into one full-share network")

# --- gradient mapping ---------------------------------------------------------

func test_tile_color_is_transparent_off_habitat() -> void:
	_make_overlay(["forest", "road", "forest"], [])
	assert_eq(_o.tile_color(Vector2i(1, 0)).a, 0.0, "hazard tiles carry no patch value")

func test_tile_color_uses_overlay_opacity() -> void:
	_make_overlay(["forest", "forest", "forest"], [])
	assert_almost_eq(_o.tile_color(Vector2i(0, 0)).a, ConnectivityOverlay.OVERLAY_OPACITY,
			0.001, "~40% opacity over terrain")

func test_fragmented_patch_is_warmer_than_connected_patch() -> void:
	_make_overlay(["forest", "forest", "road", "forest"], [])
	var connected := _o.tile_color(Vector2i(0, 0))
	var fragmented := _o.tile_color(Vector2i(3, 0))
	assert_gt(fragmented.r, connected.r, "fragmented leans orange")
	assert_lt(fragmented.b, connected.b, "connected leans teal")

# --- worst-three pulse ---------------------------------------------------------

func test_segment_score_is_mean_of_adjacent_patch_scores() -> void:
	_make_overlay(["forest", "forest", "road", "forest"], [_seg("s_a", [2])])
	# adjacent patches score 2/3 and 1/3 → mean 0.5.
	assert_almost_eq(_o.segment_score("s_a"), 0.5, 0.001)

func test_worst_segments_capped_at_three_most_fragmented() -> void:
	# Four road segments; s4 borders the larger patch pair → best connected.
	_make_overlay(
			["forest", "road", "forest", "road", "forest", "road", "forest", "road", "forest", "forest"],
			[_seg("s1", [1]), _seg("s2", [3]), _seg("s3", [5]), _seg("s4", [7])])
	var worst: Array = _o.worst_segments()
	assert_eq(worst.size(), 3, "pulse only the worst three")
	assert_does_not_have(worst, "s4", "the best-connected segment never pulses")
	assert_true(_o.is_pulsing("s1"))
	assert_false(_o.is_pulsing("s4"))

func test_segment_splitting_no_habitat_never_pulses() -> void:
	_make_overlay(["forest", "road", "forest"],
			[_seg("s_real", [1]), _seg("s_elsewhere", [50])])
	assert_false(_o.is_pulsing("s_elsewhere"), "out-of-world segment is excluded")
	assert_true(_o.is_pulsing("s_real"))

func test_pulse_alpha_starts_at_base_opacity() -> void:
	_make_overlay(["forest", "road", "forest"], [_seg("s_a", [1])])
	assert_almost_eq(_o.pulse_alpha(), ConnectivityOverlay.OVERLAY_OPACITY, 0.001)

# --- segment-mode-only visibility (PRD rule 7) ---------------------------------

func _attach_controller() -> void:
	_c = WorldSelectController.new()
	_c.setup(SUB_AREAS)
	_o.attach(_c)

func _zoom_to_px(px: float) -> void:
	_c.set_zoom(px / WorldSelectController.BASE_TILE_FLAT_TO_FLAT_PX)

func test_overlay_starts_inactive() -> void:
	_make_overlay(["forest", "road", "forest"], [])
	assert_false(_o.active)

func test_overlay_appears_only_in_segment_mode() -> void:
	_make_overlay(["forest", "road", "forest"], [])
	_attach_controller()
	_c.enter_selection_mode()
	assert_false(_o.active, "hidden at world zoom")
	_zoom_to_px(float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX))
	assert_true(_o.active, "appears at segment zoom")

func test_overlay_clears_when_zooming_back_out() -> void:
	_make_overlay(["forest", "road", "forest"], [])
	_attach_controller()
	_c.enter_selection_mode()
	_zoom_to_px(float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX))
	_zoom_to_px(float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX) - 0.1)
	assert_false(_o.active)

func test_overlay_clears_on_selection_mode_exit() -> void:
	_make_overlay(["forest", "road", "forest"], [])
	_attach_controller()
	_c.enter_selection_mode()
	_zoom_to_px(float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX))
	_c.exit_selection_mode()   # the Escape path
	assert_false(_o.active, "clears on Escape/exit")

func test_deactivate_hides_the_layer() -> void:
	_make_overlay(["forest", "road", "forest"], [])
	_o.activate()
	assert_true(_o.visible)
	_o.deactivate()
	assert_false(_o.visible)
