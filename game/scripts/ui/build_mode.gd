## Span-placement state for the construction step (build-review B4, ADR 0016).
## Holds the player's in-progress tile selection for one segment and answers
## selectability/cost/validity queries; owns no scene tree or autoload access,
## so it is unit-testable in isolation like SegmentPicker. Nothing is written
## to a live InfrastructureManager until the player explicitly confirms — a
## cancelled build mode simply discards this object, no cleanup required.
class_name BuildMode
extends RefCounted

const REJECT_EMPTY := "Select at least one tile across the corridor."
const REJECT_NO_CORE := "This selection doesn't reach both sides — extend it across the corridor."

var segment_id: String
var sub_area_id: int
var crossing_type: String
var cost_per_tile: int

var _world: WorldData
var _infrastructure: InfrastructureManager
var _dangerous: Array = []
var _dangerous_set: Dictionary = {}
var _chosen: Dictionary = {}   # Vector2i -> true, insertion order not significant

## `infrastructure` is used only for its stateless `can_place()` query (the
## registry/flag check) — no pending or covered state here is read or written.
func setup(world: WorldData, infrastructure: InfrastructureManager, segment: Dictionary,
		type: String, tile_cost: int) -> void:
	_world = world
	_infrastructure = infrastructure
	segment_id = String(segment["id"])
	sub_area_id = int(segment["sub_area_id"])
	crossing_type = type
	cost_per_tile = tile_cost
	_dangerous = InfrastructureManager.dangerous_tiles(world, segment)
	_dangerous_set = {}
	for c in _dangerous:
		_dangerous_set[c] = true
	_chosen = {}

## True when `coord` may be added to the span: it must belong to this
## segment's dangerous tiles (ADR 0016 rule 1) and be coverable by
## `crossing_type` (rule 2, via the registry's `coverable_flags`).
func is_selectable(coord: Vector2i) -> bool:
	return _dangerous_set.has(coord) and _infrastructure.can_place(coord, crossing_type)

## Add `coord` if unselected and selectable, remove it if already chosen.
## Returns false (no-op) for a coord that isn't selectable.
func toggle(coord: Vector2i) -> bool:
	if _chosen.has(coord):
		_chosen.erase(coord)
		return true
	if not is_selectable(coord):
		return false
	_chosen[coord] = true
	return true

func is_chosen(coord: Vector2i) -> bool:
	return _chosen.has(coord)

func chosen_tiles() -> Array:
	return _chosen.keys()

func chosen_count() -> int:
	return _chosen.size()

## The running cost of the current selection — informational only. No budget
## is deducted anywhere yet (Phase 3 economy is unwired; ConfirmPanel's own
## budget gate is display-only for the same reason).
func running_cost() -> int:
	return _chosen.size() * cost_per_tile

## Whether the current selection would complete a valid span if confirmed now
## — the exact ADR 0016 rule `try_complete()` itself enforces, so a "valid"
## preview here can never be rejected at confirm time.
func is_valid() -> bool:
	if _chosen.is_empty():
		return false
	return InfrastructureManager.contains_two_sided_core(_world, chosen_tiles(), _dangerous)

## A legible reason the current selection is not yet valid, for the status
## label on a rejected confirm attempt. Only meaningful when `is_valid()` is
## false.
func rejection_reason() -> String:
	if _chosen.is_empty():
		return REJECT_EMPTY
	return REJECT_NO_CORE
