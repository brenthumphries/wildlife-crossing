## Integration tests for the Simulation coordinator: it wires the Phase 1 systems,
## ticks the core loop deterministically, and relays signals to EventBus. Proves
## the vision loop — animals die on a fragmented road, then a completed overpass
## makes the route safe and animals cross it (architecture §3–4).
extends GutTest

var _sim: Simulation
const SEG := "s7_trans_canada_bow_a"
## ADR 0016's worked minimal span for this segment: a 2-tile crossing at r=5,
## not the whole 20-tile corridor. Build-review B4 replaced main.gd's own
## hardcoded version of this with real player placement (BuildMode); this
## constant stays as the fixture span for these lower-level Simulation tests.
const SPAN: Array[Vector2i] = [Vector2i(12, 5), Vector2i(13, 5)]

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _registries() -> Dictionary:
	var treg: Dictionary = {}
	for t in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var sreg: Dictionary = {}
	for s in _load_json("res://data/species_stats.json")["species"]:
		sreg[s["id"]] = s
	var ireg: Dictionary = {}
	for c in _load_json("res://data/infrastructure.json")["infrastructure"]:
		ireg[c["crossing_type"]] = c
	var seg: Dictionary = {}
	for s in _load_json("res://data/segments.json")["segments"]:
		seg[s["id"]] = s
	return { "tiles": treg, "species": sreg, "infrastructure": ireg, "segments": seg,
		"biome_groups": _load_json("res://data/biome_groups.json") }

func before_each() -> void:
	_sim = Simulation.new()
	autofree(_sim)
	_sim.load_world(7, _registries(), 42)

func test_loads_and_seeds_agents() -> void:
	assert_gt(_sim.agents.size(), 0, "agents are spawned for the active sub-area")
	var west := _sim.graph.patch_at(Vector2i(0, 0))
	assert_eq(_sim.population.count_of(west, "grizzly_bear"), 18, "grizzly seeded at 18 on the west patch")

func test_fragmentation_causes_unassisted_deaths() -> void:
	var deaths: Array = []
	_sim.species.animal_died.connect(func(sid, tile, cause): deaths.append(sid))
	for i in 1500:
		_sim.tick()
	assert_gt(deaths.size(), 0, "with no crossing, animals risking the road die (fragmentation is fatal)")

func test_crossing_zeroes_the_route() -> void:
	var west_pt := Vector2i(6, 5)
	var east_pt := Vector2i(20, 5)
	var risky := Pathfinding.find_path(_sim.world, west_pt, east_pt, { "covered": _sim.infrastructure.coverage() })
	assert_true(Pathfinding.path_crosses_hazard(_sim.world, risky, { "covered": _sim.infrastructure.coverage() }),
		"before the crossing the only route crosses the highway")
	assert_true(_sim.build_crossing(SEG, "overpass", SPAN), "the overpass is built")
	assert_true(_sim.graph.same_network(west_pt, east_pt), "the patches are now one network")
	var opts := { "covered": _sim.infrastructure.coverage() }
	var safe := Pathfinding.find_path(_sim.world, west_pt, east_pt, opts)
	assert_false(Pathfinding.path_crosses_hazard(_sim.world, safe, opts), "the route is now zero-mortality")
	# Coverage propagated into species_manager, so a road tile can no longer kill.
	assert_eq(_sim.species.mortality_chance(Vector2i(12, 5)), 0.0, "the covered highway tile is safe")

func test_agent_crossing_emits_and_counts_usage() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var path := Pathfinding.find_path(_sim.world, Vector2i(6, 5), Vector2i(20, 5), { "covered": _sim.infrastructure.coverage() })
	# Drive a single deterministic agent across the completed span.
	_sim.agents = [{
		"species_id": "grizzly_bear", "coord": Vector2i(6, 5), "patch": _sim.graph.patch_at(Vector2i(0, 0)),
		"path": path, "idx": 0, "alive": true, "in_crossing": false, "last_crossing": "",
	}]
	var crossed: Array = []
	_sim.species.animal_crossed.connect(func(cid, sid): crossed.append([cid, sid]))
	for i in path.size():
		_sim.tick()
	assert_gt(crossed.size(), 0, "the agent traversing the span emits animal_crossed")
	assert_gt(_sim.infrastructure.usage_of(_sim.infrastructure.crossing_id_for(SEG)), 0,
		"the crossing's usage counter is incremented via the wired signal")

func test_event_bus_relay_on_crossing_completed() -> void:
	var bus := get_tree().root.get_node_or_null("EventBus")
	assert_not_null(bus, "EventBus autoload is available")
	watch_signals(bus)
	_sim.build_crossing(SEG, "overpass", SPAN)
	assert_signal_emitted(bus, "crossing_completed", "the coordinator relays crossing_completed to EventBus")

# --- agent respawn (ADR 0009) ----------------------------------------------

## Living agents belonging to one patch/species pool.
func _pool_size(patch_index: int, species_id: String) -> int:
	var n: int = 0
	for a: Dictionary in _sim.agents:
		if a["alive"] and int(a["patch"]) == patch_index and String(a["species_id"]) == species_id:
			n += 1
	return n

func _kill_all_agents() -> void:
	for a: Dictionary in _sim.agents:
		a["alive"] = false

func test_agents_respawn_while_the_population_survives() -> void:
	var before: int = _sim.agents.size()
	assert_gt(before, 0, "the world starts with a rendered pool")
	_kill_all_agents()
	_sim.resync_agents()
	assert_eq(_sim.agents.size(), before,
		"rendered deaths are observable, not demographic — the pool re-renders from the surviving counts")

func test_dead_agents_are_pruned_rather_than_accumulating() -> void:
	_kill_all_agents()
	var dead: int = _sim.agents.size()
	_sim.resync_agents()
	var still_dead: int = 0
	for a: Dictionary in _sim.agents:
		if not a["alive"]:
			still_dead += 1
	assert_eq(still_dead, 0, "corpses are not carried in the agent array forever")
	assert_gt(dead, 0, "the fixture actually had agents to kill")

func test_the_pool_shrinks_when_a_population_falls() -> void:
	var patch: int = _sim.graph.patch_at(Vector2i(0, 0))
	var full: int = _pool_size(patch, "grizzly_bear")
	assert_gt(full, 0, "the west patch renders grizzlies to begin with")
	_sim.population.set_count(patch, "grizzly_bear", 0)
	_sim.resync_agents()
	assert_eq(_pool_size(patch, "grizzly_bear"), 0,
		"a patch emptied of animals stops rendering them")

func test_an_extirpated_patch_repopulates_when_the_count_returns() -> void:
	var patch: int = _sim.graph.patch_at(Vector2i(0, 0))
	_sim.population.set_count(patch, "grizzly_bear", 0)
	_sim.resync_agents()
	assert_eq(_pool_size(patch, "grizzly_bear"), 0, "the patch is empty on screen")
	_sim.population.set_count(patch, "grizzly_bear", 40)
	_sim.resync_agents()
	assert_gt(_pool_size(patch, "grizzly_bear"), 0,
		"recovery is visible — the whole point of separating counts from rendered agents")

func test_respawned_agents_are_given_a_route() -> void:
	_kill_all_agents()
	_sim.resync_agents()
	var routed: int = 0
	for a: Dictionary in _sim.agents:
		if (a["path"] as Array).size() > 0:
			routed += 1
	assert_gt(routed, 0, "a respawned agent has a goal and a path, not a stalled one")

func test_the_monthly_boundary_resyncs_the_pool() -> void:
	_kill_all_agents()
	for i in Simulation.TICKS_PER_MONTH:
		_sim.tick()
	var living: int = 0
	for a: Dictionary in _sim.agents:
		if a["alive"]:
			living += 1
	assert_gt(living, 0, "the monthly step re-renders the pool without anyone calling resync directly")

# --- save / load round trip (ADR 0014) --------------------------------------

func _restored_copy(state: Dictionary) -> Simulation:
	var other: Simulation = Simulation.new()
	autofree(other)
	other.restore_state(state, _registries(), 42)
	return other

func test_save_state_matches_the_schema_shape() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var state: Dictionary = _sim.save_state()
	assert_eq(int(state["active_sub_area_id"]), 7, "the sub-area is recorded")
	var crossings: Array = state["crossings"]
	assert_eq(crossings.size(), 1, "the completed crossing is saved")
	var c: Dictionary = crossings[0]
	for key: String in ["crossing_id", "segment_id", "sub_area_id", "crossing_type",
			"covered_tiles", "built_on_day", "fragmentation_deficit"]:
		assert_true(c.has(key), "§14 crossings[] requires '%s'" % key)
	assert_eq(c["covered_tiles"], [[12, 5], [13, 5]],
		"covered tiles are saved as [q, r] pairs — a Vector2i would stringify into text")
	var patches: Array = state["patches"]
	assert_gt(patches.size(), 0, "population records are saved")
	assert_true((patches[0] as Dictionary).has("patch_id"), "§14 patches[] are keyed by patch_id")

func test_the_saved_state_is_json_serialisable() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var text: String = JSON.stringify(_sim.save_state())
	var back: Variant = JSON.parse_string(text)
	assert_eq(typeof(back), TYPE_DICTIONARY,
		"nothing engine-specific leaks into the payload that JSON cannot represent")

func test_restore_rebuilds_the_crossing_and_its_connectivity() -> void:
	assert_true(_sim.build_crossing(SEG, "overpass", SPAN), "the overpass is built")
	var other: Simulation = _restored_copy(_sim.save_state())
	assert_true(other.graph.same_network(Vector2i(6, 5), Vector2i(20, 5)),
		"the connectivity graph is rebuilt from the saved crossings, not stored (ADR 0014)")
	assert_eq(other.species.mortality_chance(Vector2i(12, 5)), 0.0,
		"coverage is re-derived, so the crossed highway tile is safe again after a load")
	assert_eq(other.infrastructure.crossings().size(), 1, "the crossing is present exactly once")

func test_restore_preserves_population_records() -> void:
	var patch: int = _sim.graph.patch_at(Vector2i(0, 0))
	var key: String = _sim.graph.patch_key(patch)
	_sim.population.restore(patch, "grizzly_bear", 33, "declining", "sub_viable")
	var other: Simulation = _restored_copy(_sim.save_state())
	var there: int = other.graph.index_of_patch_key(key)
	assert_ne(there, -1, "a saved patch_id re-resolves in a freshly derived world")
	assert_eq(other.population.count_of(there, "grizzly_bear"), 33, "the count survives")
	assert_eq(other.population.trend_of(there, "grizzly_bear"), "declining",
		"the trend survives — a loaded game shows the arrow the player saved with")
	assert_eq(other.population.connectivity_status_of(there, "grizzly_bear"), "sub_viable",
		"connectivity status survives")

func test_restore_renders_a_pool_for_the_restored_counts() -> void:
	var other: Simulation = _restored_copy(_sim.save_state())
	assert_gt(other.agents.size(), 0, "a loaded game has animals in it")

func test_built_on_day_records_when_the_crossing_went_up() -> void:
	for i in Simulation.TICKS_PER_DAY * 3:
		_sim.tick()
	_sim.build_crossing(SEG, "overpass", SPAN)
	var crossings: Array = _sim.save_state()["crossings"]
	assert_eq(int((crossings[0] as Dictionary)["built_on_day"]), 3,
		"the crossing is stamped with the in-game day it was completed")

func test_restore_does_not_re_announce_the_crossings_it_replays() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var state: Dictionary = _sim.save_state()
	var bus := get_tree().root.get_node_or_null("EventBus")
	watch_signals(bus)
	var other: Simulation = _restored_copy(state)
	assert_signal_emit_count(bus, "crossing_completed", 0,
		"loading rebuilds crossings silently — the player should not get build toasts for old work")
	assert_eq(other.infrastructure.coverage().size(), SPAN.size(),
		"even though the replay went through the real placement path")

func test_a_patch_id_that_no_longer_exists_is_skipped_not_fatal() -> void:
	var state: Dictionary = _sim.save_state()
	(state["patches"] as Array).append({
		"patch_id": "999:nowhere:0,0", "sub_area_id": 999,
		"species": [{ "species_id": "grizzly_bear", "count": 5,
			"trend": "stable", "connectivity_status": "connected" }],
	})
	var other: Simulation = _restored_copy(state)
	assert_push_warning("999:nowhere:0,0", "the skipped patch is named rather than dropped silently")
	assert_gt(other.agents.size(), 0,
		"a stale patch_id (ADR 0014's noted risk) is skipped and the rest of the save still loads")

func test_a_saved_span_that_no_longer_validates_is_skipped_not_fatal() -> void:
	var state: Dictionary = _sim.save_state()
	(state["crossings"] as Array).append({
		"crossing_id": "x_bogus", "segment_id": SEG, "sub_area_id": 7,
		"crossing_type": "overpass", "covered_tiles": [[0, 0]], "built_on_day": 1,
	})
	var other: Simulation = _restored_copy(state)
	assert_push_warning("x_bogus", "the refused span is named")
	assert_eq(other.infrastructure.crossings().size(), 0,
		"a span the current rules reject is refused on load by the same check that governs building")
	assert_gt(other.agents.size(), 0, "and the rest of the save still loads")

func test_patch_keys_are_stable_across_two_derivations_of_the_same_world() -> void:
	var other: Simulation = Simulation.new()
	autofree(other)
	other.load_world(7, _registries(), 7)   # different seed, same static map
	for idx in _sim.graph.patches.size():
		assert_eq(other.graph.patch_key(idx), _sim.graph.patch_key(idx),
			"patch_id is deterministic from the static map, which is what makes a save re-resolve")

# --- economy (Phase 3) ------------------------------------------------------

func test_simulation_owns_an_economy_at_the_starting_budget() -> void:
	assert_not_null(_sim.economy, "load_world builds the economy manager")
	assert_eq(_sim.economy.budget, EconomyConstants.STARTING_BUDGET, "and it starts at the starting budget")

func test_budget_changes_reach_the_event_bus_once() -> void:
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	assert_not_null(bus, "the EventBus autoload is present under GUT")
	watch_signals(bus)
	_sim.economy.spend(EconomyConstants.OVERPASS_COST_PER_TILE)
	assert_signal_emit_count(bus, "budget_changed", 1, "spend relays once")
	_sim.economy.credit(1000)
	assert_signal_emit_count(bus, "budget_changed", 2, "credit relays once")
	assert_signal_emitted_with_parameters(bus, "budget_changed", [EconomyConstants.STARTING_BUDGET - EconomyConstants.OVERPASS_COST_PER_TILE + 1000])

# --- charging for crossings (C13) -------------------------------------------

## The ADR 0016 span plus one more road tile: valid, and three tiles to pay for.
const THREE_TILE_SPAN: Array[Vector2i] = [Vector2i(12, 5), Vector2i(13, 5), Vector2i(12, 4)]

func _overpass_cost_per_tile() -> int:
	return int(_registries()["infrastructure"]["overpass"]["cost_per_tile"])

func test_overpass_cost_per_tile() -> void:
	var before: int = _sim.economy.budget
	assert_true(_sim.build_crossing(SEG, "overpass", THREE_TILE_SPAN), "the three-tile overpass is built")
	assert_eq(_sim.economy.budget, before - 3 * _overpass_cost_per_tile(),
		"the registry's cost_per_tile times the covered tiles is deducted")

func test_an_unaffordable_build_covers_nothing_and_costs_nothing() -> void:
	_sim.economy.restore(_overpass_cost_per_tile(), 0)   # one tile's worth, span needs two
	assert_false(_sim.build_crossing(SEG, "overpass", SPAN), "refused for want of budget")
	assert_eq(_sim.economy.budget, _overpass_cost_per_tile(), "the budget is unchanged")
	assert_eq(_sim.infrastructure.coverage().size(), 0, "no tile is covered")

func test_an_invalid_span_costs_nothing() -> void:
	var before: int = _sim.economy.budget
	assert_false(_sim.build_crossing(SEG, "overpass", [Vector2i(12, 5)] as Array[Vector2i]),
		"half the corridor width is not a span")
	assert_eq(_sim.economy.budget, before, "a refused span is free")

func test_an_unknown_crossing_type_costs_nothing() -> void:
	var before: int = _sim.economy.budget
	assert_false(_sim.build_crossing(SEG, "moat", SPAN), "no such crossing type")
	assert_eq(_sim.economy.budget, before, "and it is free")

func test_save_state_carries_the_economy() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var economy: Dictionary = _sim.save_state()["economy"]
	assert_eq(int(economy["budget"]), _sim.economy.budget, "the live balance is saved")
	assert_true(economy.has("last_donation"), "§14 economy holds last_donation")

func test_restore_keeps_the_reduced_budget_and_last_donation() -> void:
	assert_true(_sim.build_crossing(SEG, "overpass", SPAN), "the overpass is built")
	_sim.economy.last_donation = 750
	var reduced: int = _sim.economy.budget
	var other: Simulation = _restored_copy(_sim.save_state())
	assert_eq(other.economy.budget, reduced, "a load does not refund the crossing")
	assert_lt(other.economy.budget, EconomyConstants.STARTING_BUDGET, "the balance is below the start")
	assert_eq(other.economy.last_donation, 750, "last_donation round-trips")
	assert_eq(other.infrastructure.crossings().size(), 1, "and replaying the crossing charged nothing extra")

func test_restore_without_an_economy_key_starts_at_the_starting_budget() -> void:
	var state: Dictionary = _sim.save_state()
	state.erase("economy")
	var other: Simulation = _restored_copy(state)
	assert_eq(other.economy.budget, EconomyConstants.STARTING_BUDGET, "omit-means-default")

# --- fragmentation deficit in the save (C14, data-schemas §14) --------------

func _saved_deficit(sim: Simulation) -> float:
	return float((sim.save_state()["crossings"] as Array)[0]["fragmentation_deficit"])

func test_save_writes_the_deficit_measured_at_completion() -> void:
	var west: int = _sim.graph.patch_at(Vector2i(6, 5))
	var east: int = _sim.graph.patch_at(Vector2i(20, 5))
	var expected: float = _sim.graph.fragmentation_deficit([west, east])
	_sim.build_crossing(SEG, "overpass", SPAN)
	assert_gt(expected, 0.0, "the highway splits the map before the crossing")
	assert_almost_eq(_saved_deficit(_sim), expected, 0.0001, "the saved field is the completion-time deficit")

func test_restore_keeps_the_saved_deficit_rather_than_recomputing() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var state: Dictionary = _sim.save_state()
	((state["crossings"] as Array)[0] as Dictionary)["fragmentation_deficit"] = 0.37
	assert_almost_eq(_saved_deficit(_restored_copy(state)), 0.37, 0.0001,
		"the saved value stands; a replay's own measurement would differ")

func test_a_save_written_before_the_field_existed_loads_with_zero() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var state: Dictionary = _sim.save_state()
	((state["crossings"] as Array)[0] as Dictionary).erase("fragmentation_deficit")
	var other: Simulation = _restored_copy(state)
	assert_eq(other.infrastructure.crossings().size(), 1, "the old save still loads its crossing")
	assert_eq(_saved_deficit(other), 0.0, "the missing key reads as 0.0, a 1.0x multiplier")

func test_the_deficit_survives_a_json_round_trip() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var back: Dictionary = JSON.parse_string(JSON.stringify(_sim.save_state()))
	assert_almost_eq(_saved_deficit(_restored_copy(back)), _saved_deficit(_sim), 0.0001,
		"the float survives the disk format")

# --- monthly income (C15) ---------------------------------------------------

func test_the_month_boundary_pays_income_through_the_event_bus() -> void:
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	watch_signals(bus)
	var before: int = _sim.economy.budget
	for i in Simulation.TICKS_PER_MONTH - 1:
		_sim.tick()
	assert_signal_not_emitted(bus, "donation_received", "nothing is paid before the boundary")
	_sim.tick()
	assert_signal_emit_count(bus, "donation_received", 1, "one donation at the month boundary")
	assert_gte(_sim.economy.budget, before + EconomyConstants.BASE_GRANT, "at least the base grant is credited")
	assert_eq(_sim.economy.last_donation, _sim.economy.budget - before, "last_donation is what was paid")

func test_a_traversal_is_tallied_for_the_month() -> void:
	_sim.build_crossing(SEG, "overpass", SPAN)
	var crossing_id: String = _sim.infrastructure.crossing_id_for(SEG)
	var species_id: String = _sim.agents[0]["species_id"]
	_sim.species.report_crossed(crossing_id, species_id)
	var weight: int = int(_registries()["species"][species_id]["status_weight"])
	var deficit: float = float(_sim.infrastructure.crossings()[0]["fragmentation_deficit"])
	var expected_extra: int = roundi(weight * _sim.economy.fragmentation_multiplier(deficit))
	var paid: int = _sim.economy.run_monthly_income(_sim.infrastructure.crossings())
	assert_eq(paid, EconomyConstants.BASE_GRANT + expected_extra, "the traversal pays weight x multiplier on top of the grant")
