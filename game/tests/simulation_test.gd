## Integration tests for the Simulation coordinator: it wires the Phase 1 systems,
## ticks the core loop deterministically, and relays signals to EventBus. Proves
## the vision loop — animals die on a fragmented road, then a completed overpass
## makes the route safe and animals cross it (architecture §3–4).
extends GutTest

var _sim: Simulation
const SEG := "s7_trans_canada_bow_a"
## ADR 0016's worked minimal span for this segment: a 2-tile crossing at r=5,
## not the whole 20-tile corridor (matches game/scripts/main.gd's TUTORIAL_SPAN).
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
