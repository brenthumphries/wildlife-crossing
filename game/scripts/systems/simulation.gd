## Simulation coordinator (architecture §3–4). Owns the Phase 1 system objects,
## wires them, advances a fixed-rate logical tick in a deterministic order, and
## relays the systems' local signals to the EventBus autoload. Rendering (scenes)
## reads agent state from here and interpolates between ticks.
##
## Agents are lightweight Dictionaries — the logical layer — kept separate from the
## visual Animal scene (ADR 0009). All stochastic draws use one seeded RNG (§7).
class_name Simulation
extends Node

# tick cadence (architecture §4): 0.1 s/tick → ~100 ticks/in-game day, 30-day month.
const TICKS_PER_DAY := SimulationConstants.TICKS_PER_DAY
const TICKS_PER_MONTH := TICKS_PER_DAY * 30

# systems
var world: WorldData
var graph: ConnectivityGraph
var habitat: HabitatManager
var population: PopulationModel
var infrastructure: InfrastructureManager
var species: SpeciesManager
var economy: EconomyManager
var information: InformationManager
var milestones: MilestoneTracker
var seasons: SeasonManager = SeasonManager.new()
var env: EnvConfig
var rng: RandomNumberGenerator

var agents: Array = []           # { species_id, coord, patch, path, idx, alive, in_crossing, last_crossing }
var active_sub_area_id: int = 0
## Speed owner (0 = paused; 1 / 2 / 4). `time_scale` reads through to it.
var time: TimeController = TimeController.new()
var time_scale: float:
	get:
		return time.multiplier

var _registries: Dictionary = {}
var _tick_accum: float = 0.0
var _ticks: int = 0
## Next tile offset to place an agent at, per patch+species pool. Placement
## walks the patch's tile list rather than drawing from `rng`, so seeding a
## world is reproducible without consuming the stochastic stream that goal
## selection and mortality share (§7).
var _spawn_cursor: Dictionary = {}
## True only while `restore_state` is replaying a save. Replayed crossings must
## rebuild the graph exactly as the originals did, but must not re-announce
## themselves on the EventBus — the player would get "Overpass complete" toasts
## and a crossing cue for structures they built an hour ago.
var _restoring: bool = false

func _init() -> void:
	time.time_speed_changed.connect(_on_time_speed_changed)

## Build the whole system stack for one sub-area and seed populations + agents.
## `registries` carries tiles / species / infrastructure / segments / biome_groups.
func load_world(sub_area_id: int, registries: Dictionary, seed_value: int) -> void:
	_registries = registries
	active_sub_area_id = sub_area_id
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	world = WorldData.new()
	world.load_from_dict(WorldData.parse_file("res://data/world/sub_area_%d.json" % sub_area_id), registries["tiles"])
	graph = ConnectivityGraph.new()
	graph.build(world, registries["biome_groups"])
	habitat = HabitatManager.new()
	habitat.setup(world, graph, registries["tiles"], registries["biome_groups"]["biomes"])
	population = PopulationModel.new()
	population.setup(graph, habitat, registries["species"])
	population.seed_initial()
	env = EnvConfig.new()
	env.setup(registries["tiles"])
	species = SpeciesManager.new()
	species.setup(world, graph, habitat, registries["species"], env, rng)
	infrastructure = InfrastructureManager.new()
	infrastructure.setup(world, graph, registries["infrastructure"], registries["segments"])
	species.set_coverage(infrastructure.coverage())

	economy = EconomyManager.new()
	economy.setup(registries["species"], registries["infrastructure"])

	# Only playable sub-areas are ever loaded, so the loaded one is unlocked (Phase 5's
	# permissions manager will own unlocking).
	information = InformationManager.new()
	information.setup(economy, habitat, graph, population, sub_area_id, true)

	milestones = MilestoneTracker.new()
	milestones.setup(registries.get("milestones", {}), sub_area_id)

	_wire_signals()
	_spawn_agents()

func _process(delta: float) -> void:
	if time_scale <= 0.0:
		return
	_tick_accum += delta * time_scale
	while _tick_accum >= SimulationConstants.SIM_TICK_SECONDS:
		_tick_accum -= SimulationConstants.SIM_TICK_SECONDS
		tick()

## One deterministic simulation step (architecture §4 per-tick order). Movement +
## mortality + crossing per tick; the heavy monthly demographic step is event-driven
## on the month boundary.
func tick() -> void:
	_ticks += 1
	for a in agents:
		if a["alive"]:
			_step_agent(a)
	if _ticks % TICKS_PER_MONTH == 0:
		population.monthly_step()
		resync_agents()
		economy.run_monthly_income(infrastructure.crossings())
	# Last, so this tick's movement and monthly work all used one season.
	seasons.advance_to(_ticks)

## Current in-game day, derived from the tick counter (architecture §4).
func current_day() -> int:
	return _ticks / TICKS_PER_DAY

## What a span of `tiles` would cost: the registry's `cost_per_tile` times the
## distinct tiles covered. -1 for a crossing type the registry does not know.
func crossing_cost(crossing_type: String, tiles: Array) -> int:
	var record: Dictionary = _registries["infrastructure"].get(crossing_type, {})
	if record.is_empty():
		return -1
	var distinct: Dictionary = {}
	for t in tiles:
		distinct[t] = true
	return int(record["cost_per_tile"]) * distinct.size()

## Construction-step action: build a span of `tiles` over a segment (UI confirm)
## and charge for it. Returns false, covering nothing and leaving the budget
## untouched, when the balance is short or the span is invalid; the charge lands
## only once the span has actually completed.
func build_crossing(segment_id: String, crossing_type: String, tiles: Array) -> bool:
	var cost: int = crossing_cost(crossing_type, tiles)
	if cost < 0 or not economy.can_afford(cost):
		return false
	infrastructure.current_day = current_day()
	if not infrastructure.build_span(segment_id, crossing_type, tiles):
		return false
	economy.spend(cost)
	return true

# --- agents ----------------------------------------------------------------

func _spawn_agents() -> void:
	agents.clear()
	_spawn_cursor.clear()
	for idx in graph.patches.size():
		for sid in population.resident_species(idx):
			var n: int = species.rendered_agents(population.count_of(idx, sid))
			for k in n:
				agents.append(_new_agent(idx, sid))

## Re-derive the rendered agent pool from PopulationModel — the other half of
## ADR 0009's split, and the reason the visible world stops draining to empty.
##
## Rendered deaths are observable, not demographic: `count` is untouched when an
## agent dies, so a patch that still holds animals should still show animals.
## Before this existed, `_spawn_agents()` ran once at load and nothing ever
## re-derived the pool, so every death was permanent on screen no matter what
## the player built or how the population recovered.
##
## Runs on the monthly boundary, immediately after the demographic step, so the
## pool tracks the counts that step just produced. Dead agents are pruned here
## (rather than at the moment of death) to keep a whole month's mortality
## visible as an emptying corridor before it refills.
func resync_agents() -> void:
	var living: Array = []
	var have: Dictionary = {}
	for a in agents:
		if a["alive"]:
			living.append(a)
			var k: String = _pool_key(int(a["patch"]), String(a["species_id"]))
			have[k] = int(have.get(k, 0)) + 1
	agents = living
	for idx in graph.patches.size():
		for sid: String in population.resident_species(idx):
			var key: String = _pool_key(idx, sid)
			var target: int = species.rendered_agents(population.count_of(idx, sid))
			var current: int = int(have.get(key, 0))
			for _k in maxi(0, target - current):
				agents.append(_new_agent(idx, sid))
			if current > target:
				_cull_pool(idx, sid, current - target)

## Build one agent for a patch/species pool, placed on the next tile in the
## patch's list so a pool spreads across the patch instead of stacking on tile 0.
func _new_agent(patch_index: int, species_id: String) -> Dictionary:
	var tiles: Array = graph.patches[patch_index]["tiles"]
	var key: String = _pool_key(patch_index, species_id)
	var cursor: int = int(_spawn_cursor.get(key, 0))
	_spawn_cursor[key] = cursor + 1
	var a: Dictionary = {
		"species_id": species_id, "coord": tiles[cursor % tiles.size()], "patch": patch_index,
		"path": [], "idx": 0, "alive": true, "in_crossing": false, "last_crossing": "",
	}
	_assign_goal(a)
	return a

## Drop `excess` living agents from one pool, newest first — the population fell
## below what the pool renders, so the surplus stops being drawn. Removing the
## most recently added keeps the longest-lived agents (and any journey they are
## part-way through) on screen.
func _cull_pool(patch_index: int, species_id: String, excess: int) -> void:
	var removed: int = 0
	for i in range(agents.size() - 1, -1, -1):
		if removed >= excess:
			return
		var a: Dictionary = agents[i]
		if int(a["patch"]) == patch_index and String(a["species_id"]) == species_id:
			agents.remove_at(i)
			removed += 1

func _pool_key(patch_index: int, species_id: String) -> String:
	return "%d|%s" % [patch_index, species_id]

func _assign_goal(a: Dictionary) -> void:
	var goal: Vector2i = species.select_goal(a["coord"], a["species_id"])
	a["path"] = Pathfinding.find_path(world, a["coord"], goal, { "covered": infrastructure.coverage() })
	a["idx"] = 0

func _step_agent(a: Dictionary) -> void:
	if a["idx"] >= a["path"].size() - 1:
		_assign_goal(a)
	if a["path"].size() < 2:
		return
	a["idx"] += 1
	var coord: Vector2i = a["path"][a["idx"]]
	a["coord"] = coord
	if infrastructure.coverage().has(coord):
		a["in_crossing"] = true
		a["last_crossing"] = infrastructure.crossing_id_at(coord)
		return
	if a["in_crossing"]:
		species.report_crossed(a["last_crossing"], a["species_id"])   # one traversal completed
		a["in_crossing"] = false
	if world.is_hazardous(coord):
		information.record_attempt(coord)
	if world.is_hazardous(coord) and species.rolls_death(coord):
		species.report_died(a["species_id"], coord, world.tile_at(coord))
		a["alive"] = false

# --- save / load (ADR 0014, data-schemas §14) ------------------------------

## This simulation's mutable state in the §14 shape: the `patches[]` population
## records, the `crossings[]` the player has completed, the `economy` ledger, the
## purchased `information` (`areas_revealed[]`, `products_by_area`), plus
## the sub-area they belong to. Everything else the simulation holds — the connectivity
## graph, habitat quality, the agent pool — is derived and deliberately absent,
## because ADR 0014 rebuilds it on load rather than trusting a stored copy that
## a rebalanced constant would silently invalidate.
func save_state() -> Dictionary:
	return {
		"active_sub_area_id": active_sub_area_id,
		"patches": _patches_state(),
		"crossings": _crossings_state(),
		"economy": { "budget": economy.budget, "last_donation": economy.last_donation },
		"information": information.save_state(),
		"milestones": _milestones_state(),
		"time_speed": time.multiplier,
		"clock": seasons.save_state(),
	}

## Rebuild this simulation from a §14 payload: reload the sub-area from static
## data, replay the saved crossings so the graph re-derives its safe links, then
## apply the saved population records and re-render the agent pool from them.
##
## The tick counter resumes from the saved clock (`SeasonManager.restore`), which
## lands on a day boundary, so the monthly step stays on the 30-day boundary. A
## save with no `clock` loads as year 1 spring day 0.
func restore_state(state: Dictionary, registries: Dictionary, seed_value: int) -> void:
	_restoring = true
	load_world(int(state.get("active_sub_area_id", active_sub_area_id)), registries, seed_value)
	_restore_crossings(state.get("crossings", []))
	_restore_patches(state.get("patches", []))
	_restore_economy(state.get("economy", {}))
	information.restore(state.get("information", {}))
	_restore_milestones(state.get("milestones", {}))
	var clock: Dictionary = state.get("clock", {})
	_ticks = seasons.restore(int(clock.get("year", SeasonManager.FIRST_YEAR)),
		String(clock.get("season", SeasonManager.SPRING)), int(clock.get("day_of_season", 0)))
	# An absent or unusable speed loads at 1x (omit-means-default, ADR 0014).
	var saved_speed: float = float(state.get("time_speed", TimeController.SPEED_1X))
	time.set_speed(saved_speed if TimeController.STEPS.has(saved_speed) else TimeController.SPEED_1X)
	_restoring = false
	resync_agents()

func _patches_state() -> Array:
	var out: Array = []
	for idx in graph.patches.size():
		var records: Array = []
		for sid: String in population.resident_species(idx):
			records.append({
				"species_id": sid,
				"count": population.count_of(idx, sid),
				"trend": population.trend_of(idx, sid),
				"connectivity_status": population.connectivity_status_of(idx, sid),
			})
		if records.is_empty():
			continue
		out.append({
			"patch_id": graph.patch_key(idx),
			"sub_area_id": active_sub_area_id,
			"species": records,
		})
	return out

## Crossings in §14 shape. `covered_tiles` becomes `[q, r]` pairs because a
## Vector2i does not survive `JSON.stringify` — it would serialise as the string
## "(3, 1)" and come back as text.
func _crossings_state() -> Array:
	var out: Array = []
	for c: Dictionary in infrastructure.crossings():
		var tiles: Array = []
		for t: Vector2i in c["covered_tiles"]:
			tiles.append([t.x, t.y])
		out.append({
			"crossing_id": String(c["id"]),
			"segment_id": String(c["segment_id"]),
			"sub_area_id": int(c["sub_area_id"]),
			"crossing_type": String(c["crossing_type"]),
			"covered_tiles": tiles,
			"built_on_day": int(c.get("built_on_day", 0)),
			"fragmentation_deficit": float(c.get("fragmentation_deficit", 0.0)),
		})
	return out

## Rebuild each saved crossing through the real placement path, so a loaded
## crossing is validated by the same ADR 0016 rule that let it be built — a save
## can never reintroduce a span the current rules would reject.
func _restore_crossings(saved: Array) -> void:
	for c: Dictionary in saved:
		var tiles: Array = []
		for t: Array in c.get("covered_tiles", []):
			tiles.append(Vector2i(int(t[0]), int(t[1])))
		infrastructure.current_day = int(c.get("built_on_day", 0))
		if not infrastructure.build_span(String(c["segment_id"]), String(c["crossing_type"]), tiles):
			push_warning("Saved crossing %s no longer forms a valid span — skipped" % String(c.get("crossing_id", "?")))
			continue
		# Keep the saved deficit as stored: the replay's own measurement ran against a
		# partly built graph. A save with no key reads as 0.0 (a 1.0x multiplier).
		infrastructure.restore_fragmentation_deficit(infrastructure.crossing_id_for(String(c["segment_id"])),
			float(c.get("fragmentation_deficit", 0.0)))
	infrastructure.current_day = 0
	species.set_coverage(infrastructure.coverage())

## Apply the saved ledger over the fresh EconomyManager `load_world` built, so a
## restored game keeps its balance instead of being refunded to the starting
## budget. An absent `economy` leaves the starting budget (omit-means-default).
func _restore_economy(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	economy.restore(int(saved.get("budget", EconomyConstants.STARTING_BUDGET)),
		int(saved.get("last_donation", 0)))

## The tracker's reached ids and capstone flag, plus the bonus earned but not yet
## paid, so a save between a milestone and the month's income neither loses nor repeats it.
func _milestones_state() -> Dictionary:
	var out: Dictionary = milestones.save_state()
	out["unpaid_bonus"] = economy.milestone_bonus()
	return out

## Apply the saved milestone record silently: nothing re-fires and nothing is re-paid.
func _restore_milestones(saved: Dictionary) -> void:
	milestones.restore(saved)
	economy.restore_milestone_bonus(int(saved.get("unpaid_bonus", 0)))

## Apply saved population records. A `patch_id` that resolves to nothing is
## skipped with a warning rather than dropped silently — ADR 0014's noted risk
## is exactly this: the authored map changed under an existing save.
func _restore_patches(saved: Array) -> void:
	for p: Dictionary in saved:
		var key: String = String(p.get("patch_id", ""))
		var idx: int = graph.index_of_patch_key(key)
		if idx == -1:
			push_warning("Saved patch '%s' does not exist in this world — skipped" % key)
			continue
		for rec: Dictionary in p.get("species", []):
			population.restore(idx, String(rec["species_id"]), int(rec.get("count", 0)),
				String(rec.get("trend", "stable")), String(rec.get("connectivity_status", "")))

# --- signal wiring / EventBus relay ---------------------------------------

func _wire_signals() -> void:
	species.animal_crossed.connect(_on_animal_crossed)
	species.animal_died.connect(_on_animal_died)
	infrastructure.crossing_completed.connect(_on_crossing_completed)
	population.population_recovered.connect(_on_population_recovered)
	economy.budget_changed.connect(_on_budget_changed)
	economy.donation_received.connect(_on_donation_received)
	species.animal_died.connect(_on_animal_died_record)
	information.information_purchased.connect(_on_information_purchased)
	milestones.milestone_reached.connect(_on_milestone_reached)
	if not seasons.season_changed.is_connected(_on_season_changed):
		seasons.season_changed.connect(_on_season_changed)

func _on_animal_crossed(crossing_id: String, species_id: String) -> void:
	infrastructure.on_animal_crossed(crossing_id)
	economy.record_crossing(crossing_id, species_id)
	var bus := _event_bus()
	if bus:
		bus.animal_crossed.emit(crossing_id, species_id)

func _on_animal_died(species_id: String, tile: Vector2i, cause: String) -> void:
	var bus := _event_bus()
	if bus:
		bus.animal_died.emit(species_id, tile, cause)

func _on_crossing_completed(segment_id: String, crossing_type: String, sub_area_id: int) -> void:
	species.set_coverage(infrastructure.coverage())   # covered cells now zero-mortality
	for a in agents:
		if a["alive"]:
			_assign_goal(a)                           # re-path onto the safe route
	if _restoring:
		milestones.count_crossing(sub_area_id)        # replaying a save: count it, announce nothing
		return
	var bus := _event_bus()
	if bus:
		bus.crossing_completed.emit(segment_id, crossing_type, sub_area_id)
	milestones.on_crossing_completed(sub_area_id)

func _on_population_recovered(patch_id: int, species_id: String, event_type: String) -> void:
	var bus := _event_bus()
	if bus:
		bus.population_recovered.emit(patch_id, species_id, event_type)

func _on_milestone_reached(milestone_id: String, is_capstone: bool) -> void:
	economy.add_milestone_bonus(milestones.reward_of(milestone_id))
	var bus := _event_bus()
	if bus:
		bus.milestone_reached.emit(milestone_id, is_capstone)

func _on_season_changed(new_season: String) -> void:
	var bus := _event_bus()
	if bus:
		bus.season_changed.emit(new_season)

func _on_time_speed_changed(multiplier: float) -> void:
	var bus := _event_bus()
	if bus:
		bus.time_speed_changed.emit(multiplier)

func _on_budget_changed(new_balance: int) -> void:
	var bus := _event_bus()
	if bus:
		bus.budget_changed.emit(new_balance)

func _on_animal_died_record(_species_id: String, tile: Vector2i, _cause: String) -> void:
	information.record_death(tile)

func _on_information_purchased(product: String, area_id: String) -> void:
	var bus := _event_bus()
	if bus:
		bus.information_purchased.emit(product, area_id)

func _on_donation_received(amount: int, breakdown: Dictionary) -> void:
	var bus := _event_bus()
	if bus:
		bus.donation_received.emit(amount, breakdown)

## The EventBus autoload if present, else null (so unit instantiation needs no tree).
func _event_bus() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("EventBus")
