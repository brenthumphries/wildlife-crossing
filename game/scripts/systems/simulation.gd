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
const TICKS_PER_DAY := 100
const TICKS_PER_MONTH := TICKS_PER_DAY * 30

# systems
var world: WorldData
var graph: ConnectivityGraph
var habitat: HabitatManager
var population: PopulationModel
var infrastructure: InfrastructureManager
var species: SpeciesManager
var env: EnvConfig
var rng: RandomNumberGenerator

var agents: Array = []           # { species_id, coord, patch, path, idx, alive, in_crossing, last_crossing }
var active_sub_area_id: int = 0
var time_scale: float = 1.0      # 0 = paused; 1 / 2 / 4

var _registries: Dictionary = {}
var _tick_accum: float = 0.0
var _ticks: int = 0

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

## Construction-step action: build a span of `tiles` over a segment (UI confirm).
func build_crossing(segment_id: String, crossing_type: String, tiles: Array) -> bool:
	return infrastructure.build_span(segment_id, crossing_type, tiles)

# --- agents ----------------------------------------------------------------

func _spawn_agents() -> void:
	agents.clear()
	for idx in graph.patches.size():
		var tiles: Array = graph.patches[idx]["tiles"]
		for sid in population.resident_species(idx):
			var n: int = species.rendered_agents(population.count_of(idx, sid))
			for k in n:
				var a: Dictionary = {
					"species_id": sid, "coord": tiles[k % tiles.size()], "patch": idx,
					"path": [], "idx": 0, "alive": true, "in_crossing": false, "last_crossing": "",
				}
				_assign_goal(a)
				agents.append(a)

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
	if world.is_hazardous(coord) and species.rolls_death(coord):
		species.report_died(a["species_id"], coord, world.tile_at(coord))
		a["alive"] = false

# --- signal wiring / EventBus relay ---------------------------------------

func _wire_signals() -> void:
	species.animal_crossed.connect(_on_animal_crossed)
	species.animal_died.connect(_on_animal_died)
	infrastructure.crossing_completed.connect(_on_crossing_completed)
	population.population_recovered.connect(_on_population_recovered)

func _on_animal_crossed(crossing_id: String, species_id: String) -> void:
	infrastructure.on_animal_crossed(crossing_id)
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
	var bus := _event_bus()
	if bus:
		bus.crossing_completed.emit(segment_id, crossing_type, sub_area_id)

func _on_population_recovered(patch_id: int, species_id: String, event_type: String) -> void:
	var bus := _event_bus()
	if bus:
		bus.population_recovered.emit(patch_id, species_id, event_type)

## The EventBus autoload if present, else null (so unit instantiation needs no tree).
func _event_bus() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("EventBus")
