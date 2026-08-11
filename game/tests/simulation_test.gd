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
			"covered_tiles", "built_on_day"]:
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
