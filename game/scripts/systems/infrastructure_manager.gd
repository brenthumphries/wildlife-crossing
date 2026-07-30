## Crossing placement, span validation, and the graph update (ADR 0003,
## simulation-design §3). A crossing is a data-driven tile keyed by `crossing_type`
## into infrastructure.json — placement and completion contain no per-type
## branches. A **span** (ADR 0016, superseding the segment-wide reading of ADR
## 0003) becomes a zero-mortality route when the player's placed tiles of one
## type contain a connected "core" whose local safe ring splits into two or
## more sides — i.e. the structure actually crosses the hazard, rather than
## running along it or covering only half its width. Completion then adds the
## patch-adjacency safe link (for the tiles actually built, not the whole
## corridor) and emits `crossing_completed`.
##
## Emits a local signal; the simulation coordinator relays it to EventBus.
class_name InfrastructureManager
extends RefCounted

signal crossing_completed(segment_id: String, crossing_type: String, sub_area_id: int)

## ADR 0016 "Negative / Trade-offs": naive enumeration of connected subsets is
## exponential in general. Authored corridors are ≤ 20 tiles and every verified
## minimal span is 1-2 tiles, so capping the core search here keeps it a
## trivial, bounded cost. Raise this if a future corridor's minimal valid span
## needs more tiles to reach both sides than this allows.
const MAX_CORE_TILES := 4

var _world: WorldData
var _graph: ConnectivityGraph
var _registry: Dictionary       # crossing_type -> infrastructure record
var _segments: Dictionary       # segment_id -> segment record
var _pending: Dictionary = {}   # Vector2i -> crossing_type (placed, not yet completed)
var _covered: Dictionary = {}   # Vector2i -> crossing_type (completed, zero-mortality)
var _usage: Dictionary = {}     # crossing_id -> int
var _tile_crossing: Dictionary = {}   # Vector2i -> crossing_id
var _crossings: Array = []

func setup(world: WorldData, graph: ConnectivityGraph, infrastructure_registry: Dictionary, segments_registry: Dictionary) -> void:
	_world = world
	_graph = graph
	_registry = infrastructure_registry
	_segments = segments_registry

## A crossing of `crossing_type` may be placed on `coord` iff the tile is a danger
## flag the type can cover (registry lookup, no per-type branch).
func can_place(coord: Vector2i, crossing_type: String) -> bool:
	if not _registry.has(crossing_type) or not _world.has_tile(coord):
		return false
	var flags: Array = _registry[crossing_type].get("coverable_flags", [])
	if _world.is_hazardous(coord) and flags.has("is_hazardous"):
		return true
	if _world.is_impassable(coord) and flags.has("is_impassable"):
		return true
	return false

## Place a crossing tile (part of a span in progress). Returns false if invalid.
func place(coord: Vector2i, crossing_type: String) -> bool:
	if not can_place(coord, crossing_type):
		return false
	_pending[coord] = crossing_type
	return true

## Attempt to complete a span over `segment_id`: the tiles of `crossing_type`
## already placed (pending or covered) within the segment's dangerous cells.
## Succeeds only when that placed set contains a valid two-sided core (ADR
## 0016 rule 3); then it covers exactly the placed tiles — not the whole
## segment — links the patches bordering them, and emits `crossing_completed`.
## A set with no valid core (too small, or laid along the corridor rather than
## across it) is a no-op.
func try_complete(segment_id: String, crossing_type: String) -> bool:
	if not _segments.has(segment_id):
		return false
	var seg: Dictionary = _segments[segment_id]
	var dangerous: Array = _dangerous_tiles(seg)
	if dangerous.is_empty():
		return false
	var placed: Array = _placed_of_type(dangerous, crossing_type)
	if placed.is_empty():
		return false
	if not _contains_two_sided_core(placed, dangerous):
		return false               # no chain reaches across yet: too small, or runs along the corridor
	var crossing_id: String = crossing_id_for(segment_id)
	for c in placed:
		_covered[c] = crossing_type
		_tile_crossing[c] = crossing_id
		_pending.erase(c)
	_link_bordering_patches(placed)
	_crossings.append({
		"id": crossing_id, "segment_id": segment_id, "crossing_type": crossing_type,
		"sub_area_id": int(seg["sub_area_id"]), "covered_tiles": placed,
	})
	crossing_completed.emit(segment_id, crossing_type, int(seg["sub_area_id"]))
	return true

# --- queries / helpers -----------------------------------------------------

## Coverage map (coord -> crossing_type) — pass as the `covered` option to
## Pathfinding so covered cells are traversable and zero-mortality.
func coverage() -> Dictionary:
	return _covered.duplicate()

func crossing_id_for(segment_id: String) -> String:
	return "x_" + segment_id

## The crossing id covering `coord`, or "" if uncovered.
func crossing_id_at(coord: Vector2i) -> String:
	return _tile_crossing.get(coord, "")

func segment_ids() -> Array:
	return _segments.keys()

## Place every tile in `tiles` — the player's chosen span location — and
## attempt to complete it in one call (the construction-step action). ADR
## 0016: renamed and re-scoped from `build_full`, which paved every dangerous
## cell of the whole segment; a caller now supplies the exact span. Returns
## true on completion.
func build_span(segment_id: String, crossing_type: String, tiles: Array) -> bool:
	if not _segments.has(segment_id):
		return false
	for c in tiles:
		if not place(c, crossing_type):
			return false
	return try_complete(segment_id, crossing_type)

## Usage counter: bumped once per `animal_crossed` for a crossing.
func on_animal_crossed(crossing_id: String) -> void:
	_usage[crossing_id] = int(_usage.get(crossing_id, 0)) + 1

func usage_of(crossing_id: String) -> int:
	return int(_usage.get(crossing_id, 0))

func _dangerous_tiles(seg: Dictionary) -> Array:
	var out: Array = []
	for t in seg["tiles"]:
		var c := Vector2i(int(t[0]), int(t[1]))
		if _world.is_hazardous(c) or _world.is_impassable(c):
			out.append(c)
	return out

## The placed (pending or already-covered) tiles of `crossing_type` within a
## segment's dangerous cells — the candidate span `S` in ADR 0016's terms.
func _placed_of_type(dangerous: Array, crossing_type: String) -> Array:
	var out: Array = []
	for c in dangerous:
		if _pending.get(c, "") == crossing_type or _covered.get(c, "") == crossing_type:
			out.append(c)
	return out

## ADR 0016 rule 3: true when `placed` contains a connected subset — a "core"
## — whose local safe ring falls into two or more separate pieces. That is
## the topological signature of a structure that actually crosses the hazard.
## Searches connected subsets of `placed` grown outward from every tile, up to
## MAX_CORE_TILES, testing the ring at each size reached (a subset is
## connected by construction: each step only adds a neighbour already in
## `placed`). `seen` dedupes subsets reached by more than one growth order.
func _contains_two_sided_core(placed: Array, dangerous: Array) -> bool:
	var dangerous_set: Dictionary = {}
	for d in dangerous:
		dangerous_set[d] = true
	var placed_set: Dictionary = {}
	for p in placed:
		placed_set[p] = true

	var seen: Dictionary = {}
	for start in placed:
		var frontier: Array = [[start]]
		while not frontier.is_empty():
			var core: Array = frontier.pop_back()
			var key := _core_key(core)
			if seen.has(key):
				continue
			seen[key] = true
			if _safe_ring_is_two_sided(core, dangerous_set):
				return true
			if core.size() >= MAX_CORE_TILES:
				continue
			var core_set: Dictionary = {}
			for c in core:
				core_set[c] = true
			for c in core:
				for nb in HexGrid.neighbors(c):
					if placed_set.has(nb) and not core_set.has(nb):
						var grown: Array = core.duplicate()
						grown.append(nb)
						frontier.append(grown)
	return false

## The safe ring of `core` (ADR 0016 rule 3): every in-world neighbour that is
## neither in `core` nor a dangerous tile of the segment. Two-sided when that
## ring is not one connected piece — flood-filling from any single ring tile
## does not reach the rest of it.
func _safe_ring_is_two_sided(core: Array, dangerous_set: Dictionary) -> bool:
	var core_set: Dictionary = {}
	for c in core:
		core_set[c] = true
	var ring: Dictionary = {}
	for c in core:
		for nb in HexGrid.neighbors(c):
			if _world.has_tile(nb) and not core_set.has(nb) and not dangerous_set.has(nb):
				ring[nb] = true
	if ring.size() < 2:
		return false
	var reached: Dictionary = _flood_fill(ring.keys()[0], ring)
	return reached.size() < ring.size()

## Connected component of `universe` (a Vector2i -> true set, hex-adjacency)
## containing `seed`.
func _flood_fill(seed: Vector2i, universe: Dictionary) -> Dictionary:
	var seen: Dictionary = { seed: true }
	var stack: Array = [seed]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for nb in HexGrid.neighbors(cur):
			if universe.has(nb) and not seen.has(nb):
				seen[nb] = true
				stack.append(nb)
	return seen

## Canonical string key for a tile set, so `_contains_two_sided_core` can
## dedupe subsets reached by more than one growth order.
func _core_key(core: Array) -> String:
	var sorted: Array = core.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	var parts: Array = []
	for c in sorted:
		parts.append("%d,%d" % [c.x, c.y])
	return ",".join(parts)

func _link_bordering_patches(tiles: Array) -> void:
	var borders: Dictionary = {}
	for c in tiles:
		for nb in HexGrid.neighbors(c):
			var p: int = _graph.patch_at(nb)
			if p != -1:
				borders[p] = true
	var idxs: Array = borders.keys()
	for i in idxs.size():
		for j in range(i + 1, idxs.size()):
			_graph.add_safe_link(idxs[i], idxs[j])
