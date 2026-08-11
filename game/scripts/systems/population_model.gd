## Per-patch-per-species population: count, trend, connectivity status, advanced on
## a monthly boundary (simulation-design §5; ADR 0011). Capacity is size × quality,
## ungated for seeding and viability-gated for the monthly ceiling; recovery is a
## decelerating proportional approach; decline is fixed and gentle. Emits
## `population_recovered` (returned / doubled / saturated) for economy and trust.
##
## Emits a local signal rather than touching the EventBus autoload so it unit-tests
## in isolation; the simulation coordinator relays it to EventBus.
class_name PopulationModel
extends RefCounted

signal population_recovered(patch_id: int, species_id: String, event_type: String)

var _graph: ConnectivityGraph
var _habitat: HabitatManager
var _species: Dictionary        # species_id -> record
var _pop: Dictionary = {}       # patch_index -> { species_id -> { count, trend, connectivity_status, baseline } }

func setup(graph: ConnectivityGraph, habitat: HabitatManager, species_registry: Dictionary) -> void:
	_graph = graph
	_habitat = habitat
	_species = species_registry

## Species resident in a patch: those whose habitat set includes the patch biome.
func resident_species(patch_index: int) -> Array:
	var pb: String = _habitat.patch_biome(patch_index)
	var out: Array = []
	for sid in _species:
		if _graph.resolve_habitat_biomes(_species[sid]).has(pb):
			out.append(sid)
	return out

# --- capacity / rates (ADR 0011) ------------------------------------------

func _potential_capacity(patch_index: int, species: Dictionary) -> int:
	var qnorm: float = clampf(_habitat.quality(patch_index) / 100.0,
		SimulationConstants.QUALITY_CAPACITY_FLOOR_FRAC, 1.0)
	var habitat_tiles: int = _graph.patch_habitat_tile_count(patch_index, species)
	return int(round(SimulationConstants.CAPACITY_PER_HABITAT_TILE * habitat_tiles * qnorm))

func _carrying_capacity(patch_index: int, species: Dictionary, viable: bool) -> int:
	return _potential_capacity(patch_index, species) if viable else 0

func _recovery_rate(capacity: int, count: int) -> int:
	return int(max(SimulationConstants.RECOVERY_MIN_STEP,
		round(SimulationConstants.RECOVERY_APPROACH_FRAC * float(capacity - count))))

# --- seeding (ADR 0009, ungated capacity) ----------------------------------

## Habitat-derived initial seeding for every resident species in every patch.
func seed_initial() -> void:
	_pop.clear()
	for idx in _graph.patches.size():
		for sid in resident_species(idx):
			var pot: int = _potential_capacity(idx, _species[sid])
			var c: int = int(max(SimulationConstants.SEED_FLOOR_IF_HABITABLE,
				round(SimulationConstants.INITIAL_SEED_FRACTION * pot)))
			_write(idx, sid, c)

# --- monthly step ----------------------------------------------------------

## Advance every patch/species one month: decline, re-establish, recover, or hold.
func monthly_step() -> void:
	for idx in _graph.patches.size():
		var network: Array = _graph.network_of(idx)
		for sid in resident_species(idx):
			var sp: Dictionary = _species[sid]
			var rec: Dictionary = _ensure(idx, sid)
			var effective: int = _graph.habitat_tile_count(network, sp)
			var viable: bool = effective >= int(sp.get("min_viable_patch_size", 0))
			var capacity: int = _carrying_capacity(idx, sp, viable)
			var before: int = rec.count
			if not viable:
				rec.count = max(0, rec.count - SimulationConstants.DECLINE_STEP)
				rec.trend = "falling"
			elif rec.count == 0 and _has_species_elsewhere(network, idx, sid):
				rec.count = SimulationConstants.RE_ESTABLISH_SEED
				rec.trend = "rising"
				_check_recovery(idx, sid, before, rec.count, capacity)
			elif rec.count < capacity:
				rec.count = min(capacity, rec.count + _recovery_rate(capacity, rec.count))
				rec.trend = "rising"
				_check_recovery(idx, sid, before, rec.count, capacity)
			else:
				rec.trend = "stable"
			rec.connectivity_status = "connected" if network.size() > 1 else "isolated"

func _check_recovery(patch_index: int, species_id: String, before: int, after: int, capacity: int) -> void:
	var rec: Dictionary = _pop[patch_index][species_id]
	if before == 0 and after > 0:
		population_recovered.emit(patch_index, species_id, "returned")
		rec.baseline = after
		return
	if rec.baseline > 0 and after >= 2 * rec.baseline:
		population_recovered.emit(patch_index, species_id, "doubled")
		rec.baseline = after
	if capacity > 0 and after >= capacity and before < capacity:
		population_recovered.emit(patch_index, species_id, "saturated")

# --- state helpers ---------------------------------------------------------

func _write(patch_index: int, species_id: String, count: int) -> void:
	if not _pop.has(patch_index):
		_pop[patch_index] = {}
	_pop[patch_index][species_id] = {
		"count": count, "trend": "stable", "connectivity_status": "", "baseline": count,
	}

func _ensure(patch_index: int, species_id: String) -> Dictionary:
	if not _pop.has(patch_index) or not _pop[patch_index].has(species_id):
		_write(patch_index, species_id, 0)
	return _pop[patch_index][species_id]

func _has_species_elsewhere(network: Array, patch_index: int, species_id: String) -> bool:
	for j in network:
		if j == patch_index:
			continue
		if count_of(j, species_id) > 0:
			return true
	return false

## Set a patch/species count directly (used by tests and re-seeding scenarios).
func set_count(patch_index: int, species_id: String, count: int) -> void:
	_write(patch_index, species_id, count)

func count_of(patch_index: int, species_id: String) -> int:
	if _pop.has(patch_index) and _pop[patch_index].has(species_id):
		return _pop[patch_index][species_id]["count"]
	return 0

## Overwrite one patch/species record wholesale from a saved §14 `patches[]`
## entry. Unlike `set_count`, this keeps the saved `trend` and
## `connectivity_status` instead of resetting them to the seeding defaults — a
## loaded game must show the same trend arrow the player saved with, not
## "stable" for everything until the next monthly step.
func restore(patch_index: int, species_id: String, count: int, trend: String, connectivity_status: String) -> void:
	_write(patch_index, species_id, count)
	var rec: Dictionary = _pop[patch_index][species_id]
	rec.trend = trend
	rec.connectivity_status = connectivity_status

func connectivity_status_of(patch_index: int, species_id: String) -> String:
	if _pop.has(patch_index) and _pop[patch_index].has(species_id):
		return _pop[patch_index][species_id]["connectivity_status"]
	return ""

func trend_of(patch_index: int, species_id: String) -> String:
	if _pop.has(patch_index) and _pop[patch_index].has(species_id):
		return _pop[patch_index][species_id]["trend"]
	return ""
