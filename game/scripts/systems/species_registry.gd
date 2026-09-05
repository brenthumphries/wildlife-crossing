## Read-only registry of static game data loaded from `data/` at startup
## (architecture §2, the WorldDataRegistry pattern). Serves species plus tile,
## sub-area, entity, segment, infrastructure, milestone, and biome-group data.
## Mutable runtime state is GameState's job, never this registry's.
extends Node

const DATA_DIR := "res://data/"

var tiles: Dictionary = {}
var species: Dictionary = {}
var sub_areas: Dictionary = {}
var entities: Dictionary = {}
var segments: Dictionary = {}
var infrastructure: Dictionary = {}
var milestones: Dictionary = {}
var biome_groups: Dictionary = {}

func _ready() -> void:
	load_all()

## (Re)load every static data file into its id-indexed dictionary.
func load_all() -> void:
	tiles = _index(_load_array("tiles.json", "tiles"), "id")
	species = _index(_load_array("species_stats.json", "species"), "id")
	sub_areas = _index(_load_array("sub_areas.json", "sub_areas"), "id")
	entities = _index(_load_array("entities.json", "entities"), "id")
	segments = _index(_load_array("segments.json", "segments"), "id")
	infrastructure = _index(_load_array("infrastructure.json", "infrastructure"), "crossing_type")
	milestones = _index(_load_array("milestones.json", "milestones"), "id")
	biome_groups = _load_object("biome_groups.json")

## Load a `{ data_version, <key>: [...] }` file and return the array under `key`.
func _load_array(file_name: String, key: String) -> Array:
	return _load_object(file_name).get(key, [])

## Parse a JSON object file from `data/`; returns {} and logs on error.
func _load_object(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("Data file missing: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Data file is not a JSON object: " + path)
		return {}
	return parsed

## Build an id -> record dictionary from an array of records.
##
## `JSON.parse_string` returns every JSON number as a float and Godot
## dictionaries treat `7` and `7.0` as distinct keys, so a numeric id would
## index under `7.0` and miss every `int`-typed lookup in the codebase. Numeric
## ids are normalised to `int` here, at the data boundary, and written back into
## the record so the key and the record's own id field agree.
func _index(records: Array, key: String) -> Dictionary:
	var out: Dictionary = {}
	for rec in records:
		var id: Variant = _normalise_id(rec[key])
		rec[key] = id
		out[id] = rec
	return out

## Narrow a whole-number float id to `int`. Any other value — a string id, a
## fractional number — is returned unchanged rather than silently truncated.
func _normalise_id(id: Variant) -> Variant:
	if typeof(id) == TYPE_FLOAT and is_equal_approx(id, floor(id)):
		return int(id)
	return id
