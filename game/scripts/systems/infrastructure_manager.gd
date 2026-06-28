## Crossing placement, span validation, and the graph update (ADR 0003,
## simulation-design §3). A crossing is a data-driven tile keyed by `crossing_type`
## into infrastructure.json — placement and completion contain no per-type
## branches. A segment's dangerous cells become a zero-mortality route only when
## EVERY one is covered by a single connected chain of the same type; completion
## then adds the patch-adjacency safe link and emits `crossing_completed`.
##
## Emits a local signal; the simulation coordinator relays it to EventBus.
class_name InfrastructureManager
extends RefCounted

signal crossing_completed(segment_id: String, crossing_type: String, sub_area_id: int)

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

## Attempt to complete the span over `segment_id`. Succeeds only when every
## dangerous cell is covered by one connected chain of `crossing_type`; then it
## links the bordering patches and emits `crossing_completed`. Partial → no-op.
func try_complete(segment_id: String, crossing_type: String) -> bool:
	if not _segments.has(segment_id):
		return false
	var seg: Dictionary = _segments[segment_id]
	var dangerous: Array = _dangerous_tiles(seg)
	if dangerous.is_empty():
		return false
	for c in dangerous:
		if _pending.get(c, "") != crossing_type and _covered.get(c, "") != crossing_type:
			return false               # an uncovered (or wrong-type) cell: partial span
	if not _chain_connected(dangerous):
		return false
	var crossing_id: String = crossing_id_for(segment_id)
	for c in dangerous:
		_covered[c] = crossing_type
		_tile_crossing[c] = crossing_id
		_pending.erase(c)
	_link_bordering_patches(dangerous)
	_crossings.append({
		"id": crossing_id, "segment_id": segment_id, "crossing_type": crossing_type,
		"sub_area_id": int(seg["sub_area_id"]), "covered_tiles": dangerous,
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

## Convenience: place every dangerous cell of a segment and complete the span in
## one call (the construction-step action). Returns true on completion.
func build_full(segment_id: String, crossing_type: String) -> bool:
	if not _segments.has(segment_id):
		return false
	for c in _dangerous_tiles(_segments[segment_id]):
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

func _chain_connected(tiles: Array) -> bool:
	if tiles.size() <= 1:
		return true
	var inset: Dictionary = {}
	for c in tiles:
		inset[c] = true
	var seen: Dictionary = { tiles[0]: true }
	var stack: Array = [tiles[0]]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for nb in HexGrid.neighbors(cur):
			if inset.has(nb) and not seen.has(nb):
				seen[nb] = true
				stack.append(nb)
	return seen.size() == tiles.size()

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
