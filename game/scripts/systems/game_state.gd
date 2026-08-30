## The live, save-able world state and the serialization target (ADR 0014,
## data-schemas §14). Holds only mutable runtime state; static reference data
## lives in SpeciesRegistry, and derived state (connectivity graph, quality
## scores, agent pool) is rebuilt on `game_loaded` rather than stored.
extends Node

const SAVE_VERSION := 1

# Defaults live in one place so `reset()` and the omit-means-default load path
# (ADR 0014) cannot drift apart into two different notions of "a fresh game".
const DEFAULT_SUB_AREA_ID := 7
const DEFAULT_YEAR := 1
const DEFAULT_SEASON := "spring"
const DEFAULT_TIME_SPEED := 1.0

# clock
var active_sub_area_id: int = DEFAULT_SUB_AREA_ID
var year: int = DEFAULT_YEAR
var season: String = DEFAULT_SEASON
var day_of_season: int = 0
var time_speed: float = DEFAULT_TIME_SPEED

# economy
var budget: int = 0
var last_donation: int = 0

# meta
var playtime_seconds: int = 0
## When the loaded save was written, straight from its `meta.saved_at_unix`.
## Never written by `to_dict()` — that stamps the current time — so this stays
## 0 until a save is actually loaded.
var last_saved_at_unix: int = 0

# runtime collections (shapes per data-schemas §14)
var patches: Array = []
var entities: Array = []
var crossings: Array = []
var information: Dictionary = { "areas_revealed": [], "entities_revealed": [] }
var milestones: Dictionary = { "reached": [], "capstone_reached": false }

## Serialize mutable state to the §14 GameState shape. Derived state is rebuilt
## on load, never stored here.
func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"meta": {
			"active_sub_area_id": active_sub_area_id,
			"saved_at_unix": int(Time.get_unix_time_from_system()),
			"playtime_seconds": playtime_seconds,
		},
		"clock": {
			"year": year,
			"season": season,
			"day_of_season": day_of_season,
			"time_speed": time_speed,
		},
		"economy": { "budget": budget, "last_donation": last_donation },
		"patches": patches,
		"entities": entities,
		"information": information,
		"crossings": crossings,
		"milestones": milestones,
	}

## Replace every mutable field from a §14 payload and announce it with a single
## `game_loaded` (architecture §7) — the one trigger systems rebuild derived
## state on. Absent keys take the defaults above rather than failing, which is
## ADR 0014's "omit-means-default" rule: a save written by an earlier build of
## the same `save_version` still loads.
##
## Refuses a payload whose `save_version` is not this build's. `SaveManager`
## runs the migration chain before calling here, so reaching that branch means a
## hand-edited file or a caller that skipped the migration — either way,
## applying it would silently corrupt the running game.
func from_dict(data: Dictionary) -> bool:
	var version: int = int(data.get("save_version", -1))
	if version != SAVE_VERSION:
		push_error("GameState.from_dict refused save_version %d (this build is %d) — load it through SaveManager, which migrates first"
			% [version, SAVE_VERSION])
		return false

	var meta: Dictionary = data.get("meta", {})
	active_sub_area_id = int(meta.get("active_sub_area_id", DEFAULT_SUB_AREA_ID))
	last_saved_at_unix = int(meta.get("saved_at_unix", 0))
	playtime_seconds = int(meta.get("playtime_seconds", 0))

	var clock: Dictionary = data.get("clock", {})
	year = int(clock.get("year", DEFAULT_YEAR))
	season = String(clock.get("season", DEFAULT_SEASON))
	day_of_season = int(clock.get("day_of_season", 0))
	time_speed = float(clock.get("time_speed", DEFAULT_TIME_SPEED))

	var economy: Dictionary = data.get("economy", {})
	budget = int(economy.get("budget", 0))
	last_donation = int(economy.get("last_donation", 0))

	# Deep copies: the payload belongs to the caller (and may be a parsed file it
	# still holds), so the live state must not alias it.
	patches = _array_of(data, "patches")
	entities = _array_of(data, "entities")
	crossings = _array_of(data, "crossings")
	information = _merged(data.get("information", {}),
		{ "areas_revealed": [], "entities_revealed": [] })
	milestones = _merged(data.get("milestones", {}),
		{ "reached": [], "capstone_reached": false })

	_emit_game_loaded()
	return true

## Return every field to its new-game value. Used before loading a different
## save and by "new game", so no field survives from the previous world.
func reset() -> void:
	active_sub_area_id = DEFAULT_SUB_AREA_ID
	year = DEFAULT_YEAR
	season = DEFAULT_SEASON
	day_of_season = 0
	time_speed = DEFAULT_TIME_SPEED
	budget = 0
	last_donation = 0
	playtime_seconds = 0
	last_saved_at_unix = 0
	patches = []
	entities = []
	crossings = []
	information = { "areas_revealed": [], "entities_revealed": [] }
	milestones = { "reached": [], "capstone_reached": false }

# --- helpers ---------------------------------------------------------------

## A deep copy of `data[key]` when it is an Array, else []. Guards the load path
## against a truncated or hand-edited file putting a non-Array where a §14
## collection belongs.
func _array_of(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key, [])
	if typeof(value) != TYPE_ARRAY:
		push_warning("Save key '%s' is not an array — using an empty one" % key)
		return []
	return (value as Array).duplicate(true)

## `defaults` overlaid with whatever `value` supplies — the omit-means-default
## rule applied one level into the object-shaped §14 keys.
func _merged(value: Variant, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for k in (value as Dictionary):
		out[k] = (value as Dictionary)[k]
	return out

func _emit_game_loaded() -> void:
	var bus := _event_bus()
	if bus:
		bus.game_loaded.emit()

## The EventBus autoload if present, else null — so a test can instantiate this
## script directly without a scene tree.
func _event_bus() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("EventBus")
