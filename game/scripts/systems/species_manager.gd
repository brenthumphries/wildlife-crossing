## Rendered animal agents: the bounded, representative pool that enacts the
## journeys the player watches (ADR 0009), with per-step hazard mortality
## (simulation-design §4) and season-independent goal selection (ADR 0010).
## Authoritative demographics live in PopulationModel; rendered deaths are
## observable, not demographic — they never mutate `count`.
##
## Stochastic decisions draw from a single injected seeded RNG (simulation-design
## §7). Emits local signals; the simulation coordinator relays them to EventBus.
class_name SpeciesManager
extends RefCounted

signal animal_crossed(crossing_id: String, species_id: String)
signal animal_died(species_id: String, tile: Vector2i, cause: String)

var _world: WorldData
var _graph: ConnectivityGraph
var _habitat: HabitatManager
var _species: Dictionary
var _env: EnvConfig
var _rng: RandomNumberGenerator
var _coverage: Dictionary = {}

func setup(world: WorldData, graph: ConnectivityGraph, habitat: HabitatManager, species_registry: Dictionary, env_config: EnvConfig, rng: RandomNumberGenerator) -> void:
	_world = world
	_graph = graph
	_habitat = habitat
	_species = species_registry
	_env = env_config
	_rng = rng

## Refresh the covered-tile set after a crossing completes.
func set_coverage(cov: Dictionary) -> void:
	_coverage = cov

## Emit the traversal/death signals (called by the per-tick coordinator, which
## drives single-hex agent steps rather than whole-path walks).
func report_crossed(crossing_id: String, species_id: String) -> void:
	animal_crossed.emit(crossing_id, species_id)

func report_died(species_id: String, tile: Vector2i, cause: String) -> void:
	animal_died.emit(species_id, tile, cause)

## How many agents to render for a patch holding `count` animals (ADR 0009):
## ceil(count / AGENT_REPRESENTATION), capped, zero when empty.
func rendered_agents(count: int) -> int:
	if count <= 0:
		return 0
	var n: int = int(ceil(float(count) / float(SimulationConstants.AGENT_REPRESENTATION)))
	return clampi(n, 0, SimulationConstants.MAX_AGENTS_PER_VISIBLE_PATCH)

# --- mortality (simulation-design §4) --------------------------------------

## Per-step death probability for entering `coord`: 0 if covered or non-hazard.
func mortality_chance(coord: Vector2i) -> float:
	if _coverage.has(coord):
		return 0.0
	if not _world.is_hazardous(coord):
		return 0.0
	return _env.mortality_for(_world.tile_at(coord))

## Roll the seeded RNG against the tile's mortality chance.
func rolls_death(coord: Vector2i) -> bool:
	var p: float = mortality_chance(coord)
	if p <= 0.0:
		return false
	return _rng.randf() < p

## Walk an agent along `path`: emit `animal_crossed` once per covered run it
## completes, and `animal_died` on the first fatal hazard (stopping there).
## Returns true if it reached the end alive.
func walk(species_id: String, path: Array, crossing_id: String) -> bool:
	var in_crossing := false
	for i in range(1, path.size()):
		var coord: Vector2i = path[i]
		if _coverage.has(coord):
			in_crossing = true
			continue
		if in_crossing:
			animal_crossed.emit(crossing_id, species_id)
			in_crossing = false
		if _world.is_hazardous(coord) and rolls_death(coord):
			animal_died.emit(species_id, coord, _world.tile_at(coord))
			return false
	if in_crossing:
		animal_crossed.emit(crossing_id, species_id)
	return true

# --- goal selection (ADR 0010) ---------------------------------------------

## Season-independent forage/wander goal for an idle agent at `from`.
func select_goal(from: Vector2i, species_id: String) -> Vector2i:
	var sp: Dictionary = _species[species_id]
	var reach: int = int(round(float(sp.get("range_tiles", 0)) * SimulationConstants.MOTIVATION_DISTANCE_MULT))
	if _rng.randf() < SimulationConstants.WANDERLUST_PROB:
		var goal: Vector2i = _weighted_patch_goal(from, sp, reach)
		if goal != from:
			return goal
	return _forage_goal(from)

func _weighted_patch_goal(from: Vector2i, sp: Dictionary, reach: int) -> Vector2i:
	var habitat: Dictionary = _graph.resolve_habitat_biomes(sp)
	var from_patch: int = _graph.patch_at(from)
	var candidates: Array = []
	var total: float = 0.0
	for i in _graph.patches.size():
		if i == from_patch:
			continue
		if not habitat.has(_habitat.patch_biome(i)):
			continue
		var rep: Vector2i = _graph.patches[i]["tiles"][0]
		var d: int = HexGrid.distance(from, rep)
		if d > reach:
			continue
		var w: float = (_habitat.quality(i) + SimulationConstants.GOAL_QUALITY_FLOOR) / (1.0 + d)
		candidates.append({ "tile": rep, "weight": w })
		total += w
	if candidates.is_empty() or total <= 0.0:
		return from
	var pick: float = _rng.randf() * total
	var acc: float = 0.0
	for c in candidates:
		acc += c["weight"]
		if pick <= acc:
			return c["tile"]
	return candidates[-1]["tile"]

func _forage_goal(from: Vector2i) -> Vector2i:
	var options: Array = []
	for c in _world.all_coords():
		if _world.is_walkable(c) and HexGrid.distance(from, c) <= SimulationConstants.FORAGE_RADIUS_TILES:
			options.append(c)
	if options.is_empty():
		return from
	return options[_rng.randi() % options.size()]
