## Corridor milestones and the Continental Connection capstone: evaluates data-driven conditions, fires each once.
class_name MilestoneTracker
extends RefCounted

## Emitted once per milestone, the first time its condition holds; Simulation relays it to EventBus.
signal milestone_reached(milestone_id: String, is_capstone: bool)

const METRIC_CROSSINGS_IN_SUB_AREA := "crossings_completed_in_sub_area"
const METRIC_CHAIN := "connected_chain_yellowstone_to_mackenzie"
## The chain the capstone asks for runs between these two sub-areas (sub_areas.json ids).
const YELLOWSTONE_SUB_AREA_ID := 1
const MACKENZIE_SUB_AREA_ID := 12

## Ids of the milestones reached so far, in the order they fired (saved).
var reached: Array[String] = []
## Whether the capstone has been reached (saved). Nothing in the game reads it as a gate.
var capstone_reached: bool = false

var _milestones: Array = []
var _sub_area_id: int = 0
var _crossings_completed: int = 0
## Pairs `[a, b]` of sub-area ids joined by a safe crossing; the capstone's connectivity fixture.
var _area_links: Array = []

## Read the milestone records (the registry's id -> record dictionary) and the loaded sub-area.
func setup(milestones_registry: Dictionary, sub_area_id: int) -> void:
	_milestones = milestones_registry.values()
	_sub_area_id = sub_area_id
	_crossings_completed = 0
	_area_links = []
	reached = []
	capstone_reached = false

## Replace the sub-area links the capstone metric reads and re-evaluate.
## Each link is a two-element array of sub-area ids joined by a safe crossing.
func set_area_links(links: Array) -> void:
	_area_links = links
	_evaluate()

## Count a completed crossing without evaluating or announcing anything; a save replay uses this.
func count_crossing(sub_area_id: int) -> void:
	if sub_area_id == _sub_area_id:
		_crossings_completed += 1

## A crossing was completed in `sub_area_id`: count it and fire whatever it satisfies.
func on_crossing_completed(sub_area_id: int) -> void:
	count_crossing(sub_area_id)
	_evaluate()

## The one-time donation bonus of a milestone; 0 for an id the data does not know.
func reward_of(milestone_id: String) -> int:
	for m: Dictionary in _milestones:
		if String(m["id"]) == milestone_id:
			return int(m.get("reward_bonus", 0))
	return 0

## Whether the sub-area links join `from_id` to `to_id`, directly or through other sub-areas.
static func chain_connected(links: Array, from_id: int, to_id: int) -> bool:
	var seen: Dictionary = { from_id: true }
	var frontier: Array = [from_id]
	while not frontier.is_empty():
		var current: int = frontier.pop_back()
		if current == to_id:
			return true
		for link: Array in links:
			var a: int = int(link[0])
			var b: int = int(link[1])
			var other: int = b if a == current else (a if b == current else -1)
			if other != -1 and not seen.has(other):
				seen[other] = true
				frontier.append(other)
	return false

## Save shape for the `milestones` key (data-schemas §14).
func save_state() -> Dictionary:
	return { "reached": reached.duplicate(), "capstone_reached": capstone_reached }

## Apply a saved `milestones` record without announcing anything, so a load never re-fires.
func restore(saved: Dictionary) -> void:
	reached = []
	for id: Variant in saved.get("reached", []):
		reached.append(String(id))
	capstone_reached = bool(saved.get("capstone_reached", false))

func _evaluate() -> void:
	for m: Dictionary in _milestones:
		var id: String = String(m["id"])
		if reached.has(id) or not _applies_here(m):
			continue
		if _condition_met(m["condition"]):
			reached.append(id)
			var is_capstone: bool = bool(m.get("is_capstone", false))
			if is_capstone:
				capstone_reached = true
			milestone_reached.emit(id, is_capstone)

## Only the loaded sub-area's milestones are live; the capstone and other-scope records always are.
func _applies_here(milestone: Dictionary) -> bool:
	if String(milestone.get("scope", "")) != "sub_area":
		return true
	return int(milestone.get("sub_area_id", -1)) == _sub_area_id

func _condition_met(condition: Dictionary) -> bool:
	if condition.has("all_of"):
		for part: Dictionary in condition["all_of"]:
			if not _condition_met(part):
				return false
		return true
	var actual: Variant = _metric(String(condition.get("metric", "")))
	if actual == null:
		return false
	var wanted: Variant = condition.get("value")
	match String(condition.get("comparator", "")):
		">=": return actual >= wanted
		">": return actual > wanted
		"<=": return actual <= wanted
		"<": return actual < wanted
		"==": return actual == wanted
	return false

## Current value of a named metric, or null for one this build does not know.
func _metric(name: String) -> Variant:
	match name:
		METRIC_CROSSINGS_IN_SUB_AREA:
			return _crossings_completed
		METRIC_CHAIN:
			return chain_connected(_area_links, YELLOWSTONE_SUB_AREA_ID, MACKENZIE_SUB_AREA_ID)
	return null
