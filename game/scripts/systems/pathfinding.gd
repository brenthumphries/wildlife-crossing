## A* routing over the hex movement graph (simulation-design §2). One node per
## tile, edges to the six neighbours; edge eligibility and cost depend on tile
## danger flags and crossing coverage. Stateless and scene-free — operates on a
## WorldData grid so it unit-tests in isolation.
##
## `opts` keys (all optional):
##   covered            Dictionary<Vector2i, bool> — tiles under a completed
##                      crossing chain: traversable and zero-mortality.
##   crossing_pref_mult float  — cost multiplier on covered tiles for a species
##                      that prefers this crossing type (< 1.0). Default 1.0.
##   hazard_mult        float  — cost multiplier on uncovered hazards.
##                      Default SimulationConstants.HAZARD_AVOIDANCE_MULT.
class_name Pathfinding
extends RefCounted

const BASE_COST := 1.0

## Lowest-cost path from `start` to `goal` as an Array[Vector2i] inclusive of
## both ends, or [] if no route exists (e.g. a barrier with no crossing).
static func find_path(world: WorldData, start: Vector2i, goal: Vector2i, opts: Dictionary = {}) -> Array:
	if not world.has_tile(start) or not world.has_tile(goal):
		return []
	var open: Array = [start]
	var open_set: Dictionary = { start: true }
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: float(HexGrid.distance(start, goal)) }
	while not open.is_empty():
		var current: Vector2i = _lowest(open, f_score)
		if current == goal:
			return _reconstruct(came_from, current)
		open.erase(current)
		open_set.erase(current)
		for nb in world.neighbors_in_bounds(current):
			var step := _edge_cost(world, nb, opts)
			if step == INF:
				continue
			var tentative: float = float(g_score[current]) + step
			if not g_score.has(nb) or tentative < float(g_score[nb]):
				came_from[nb] = current
				g_score[nb] = tentative
				f_score[nb] = tentative + float(HexGrid.distance(nb, goal))
				if not open_set.has(nb):
					open.append(nb)
					open_set[nb] = true
	return []

## Cost to enter tile `b`; INF when the edge does not exist (uncovered barrier).
static func _edge_cost(world: WorldData, b: Vector2i, opts: Dictionary) -> float:
	var covered: Dictionary = opts.get("covered", {})
	if covered.has(b):
		return BASE_COST * float(opts.get("crossing_pref_mult", 1.0))
	if world.is_impassable(b):
		return INF
	if world.is_hazardous(b):
		return BASE_COST * float(opts.get("hazard_mult", SimulationConstants.HAZARD_AVOIDANCE_MULT))
	return BASE_COST

## True when the path steps onto any uncovered hazardous tile — i.e. it is not a
## zero-mortality route. Mortality probability itself is rolled by species_manager.
static func path_crosses_hazard(world: WorldData, path: Array, opts: Dictionary = {}) -> bool:
	var covered: Dictionary = opts.get("covered", {})
	for c in path:
		if not covered.has(c) and world.is_hazardous(c):
			return true
	return false

static func _lowest(open: Array, f_score: Dictionary) -> Vector2i:
	var best: Vector2i = open[0]
	var best_f: float = float(f_score[best])
	for n in open:
		var nf := float(f_score[n])
		if nf < best_f:
			best = n
			best_f = nf
	return best

static func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array:
	var path: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path
