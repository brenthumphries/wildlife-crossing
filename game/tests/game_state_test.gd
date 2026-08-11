## Tests for the GameState autoload — the §14 serialization shape (ADR 0014) and
## its reader. `game_state.gd` is normative for what a save file *is*, so these
## assert the contract rather than the implementation: every §14 section present,
## a lossless round-trip, omit-means-default on read, and a refusal to apply a
## payload this build cannot read.
##
## Instantiated from the script rather than used via `/root/GameState`, so a test
## never mutates the live autoload other tests share.
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/systems/game_state.gd")

var _state: Node

func before_each() -> void:
	_state = GameStateScript.new()
	autofree(_state)

## A fully-populated save payload: every §14 key present with a non-default
## value, so a round-trip that drops or defaults any field fails loudly.
func _full_payload() -> Dictionary:
	return {
		"save_version": 1,
		"meta": {
			"active_sub_area_id": 3,
			"saved_at_unix": 1750000000,
			"playtime_seconds": 12840,
		},
		"clock": { "year": 4, "season": "summer", "day_of_season": 34, "time_speed": 2.0 },
		"economy": { "budget": 45000, "last_donation": 1200 },
		"patches": [{
			"patch_id": "7:forest:3,1", "sub_area_id": 7,
			"species": [{
				"species_id": "grizzly_bear", "count": 18,
				"trend": "declining", "connectivity_status": "sub_viable",
			}],
		}],
		"entities": [{
			"entity_id": "parks_canada", "trust": 42,
			"stage": "cooperative", "partnership": false,
		}],
		"information": {
			"areas_revealed": ["7"], "entities_revealed": ["parks_canada"],
		},
		"crossings": [{
			"crossing_id": "c1", "segment_id": "7:seg:14", "sub_area_id": 7,
			"crossing_type": "overpass", "covered_tiles": [[3, 1], [4, 1]],
			"built_on_day": 120,
		}],
		"milestones": { "reached": ["first_crossing"], "capstone_reached": false },
	}

# --- shape (ADR 0014) -------------------------------------------------------

func test_to_dict_carries_every_section_of_the_schema() -> void:
	var out: Dictionary = _state.to_dict()
	for key: String in ["save_version", "meta", "clock", "economy", "patches",
			"entities", "information", "crossings", "milestones"]:
		assert_true(out.has(key), "§14 requires a top-level '%s'" % key)

func test_save_version_is_the_migration_key() -> void:
	var out: Dictionary = _state.to_dict()
	assert_eq(int(out["save_version"]), 1,
		"save_version starts at 1 — bumping it is a MAJOR change and needs a migration step")

func test_meta_and_clock_hold_the_fields_the_schema_names() -> void:
	var out: Dictionary = _state.to_dict()
	var meta: Dictionary = out["meta"]
	for key: String in ["active_sub_area_id", "saved_at_unix", "playtime_seconds"]:
		assert_true(meta.has(key), "§14 meta requires '%s'" % key)
	var clock: Dictionary = out["clock"]
	for key: String in ["year", "season", "day_of_season", "time_speed"]:
		assert_true(clock.has(key), "§14 clock requires '%s'" % key)

func test_saved_at_unix_is_stamped_at_save_time() -> void:
	var stamped: int = int((_state.to_dict()["meta"] as Dictionary)["saved_at_unix"])
	assert_gt(stamped, 1700000000, "the save stamps the current time, not a stored constant")

# --- round trip -------------------------------------------------------------

func test_round_trip_preserves_every_field() -> void:
	assert_true(_state.from_dict(_full_payload()), "a current-version payload loads")
	assert_eq(_state.active_sub_area_id, 3, "active sub-area survives")
	assert_eq(_state.playtime_seconds, 12840, "playtime survives")
	assert_eq(_state.last_saved_at_unix, 1750000000, "the save's timestamp is kept for display")
	assert_eq(_state.year, 4, "year survives")
	assert_eq(_state.season, "summer", "season survives")
	assert_eq(_state.day_of_season, 34, "day of season survives")
	assert_eq(_state.time_speed, 2.0, "time speed survives")
	assert_eq(_state.budget, 45000, "budget survives")
	assert_eq(_state.last_donation, 1200, "last donation survives")
	assert_eq(_state.patches.size(), 1, "patch records survive")
	assert_eq(_state.entities.size(), 1, "entity records survive")
	assert_eq(_state.crossings.size(), 1, "crossing records survive")
	assert_eq(_state.information["areas_revealed"], ["7"], "revealed areas survive")
	assert_eq(_state.milestones["reached"], ["first_crossing"], "milestone progress survives")

func test_to_dict_after_from_dict_reproduces_the_payload() -> void:
	var original: Dictionary = _full_payload()
	assert_true(_state.from_dict(original), "the payload loads")
	var out: Dictionary = _state.to_dict()
	# `saved_at_unix` is deliberately re-stamped on write, so compare everything else.
	assert_eq(out["clock"], original["clock"], "clock round-trips unchanged")
	assert_eq(out["economy"], original["economy"], "economy round-trips unchanged")
	assert_eq(out["patches"], original["patches"], "patches round-trip unchanged")
	assert_eq(out["entities"], original["entities"], "entities round-trip unchanged")
	assert_eq(out["crossings"], original["crossings"], "crossings round-trip unchanged")
	assert_eq(out["information"], original["information"], "information round-trips unchanged")
	assert_eq(out["milestones"], original["milestones"], "milestones round-trip unchanged")

func test_json_survives_a_string_round_trip() -> void:
	assert_true(_state.from_dict(_full_payload()), "the payload loads")
	var text: String = JSON.stringify(_state.to_dict())
	var reparsed: Variant = JSON.parse_string(text)
	assert_eq(typeof(reparsed), TYPE_DICTIONARY, "the save is valid JSON (ADR 0005)")
	var fresh: Node = GameStateScript.new()
	autofree(fresh)
	assert_true(fresh.from_dict(reparsed as Dictionary), "a save read back off disk loads")
	assert_eq(fresh.budget, 45000, "values survive the JSON encoding, not just the dict copy")

func test_loaded_collections_do_not_alias_the_payload() -> void:
	var payload: Dictionary = _full_payload()
	assert_true(_state.from_dict(payload), "the payload loads")
	(payload["patches"] as Array).clear()
	assert_eq(_state.patches.size(), 1,
		"the caller's payload is deep-copied — mutating it must not reach into live state")

# --- omit-means-default (ADR 0014) -----------------------------------------

func test_absent_keys_take_defaults() -> void:
	_state.budget = 999
	_state.year = 7
	assert_true(_state.from_dict({ "save_version": 1 }), "a minimal payload still loads")
	assert_eq(_state.year, 1, "an absent clock takes the default year")
	assert_eq(_state.season, "spring", "an absent clock takes the default season")
	assert_eq(_state.budget, 0, "an absent economy takes the default budget")
	assert_eq(_state.patches, [], "an absent collection loads empty, not stale")

func test_partial_sections_default_only_the_missing_keys() -> void:
	assert_true(_state.from_dict({ "save_version": 1, "clock": { "year": 9 } }),
		"a partially-written clock loads")
	assert_eq(_state.year, 9, "the supplied key is taken")
	assert_eq(_state.day_of_season, 0, "the missing key defaults rather than failing the load")

func test_information_keeps_its_default_subkeys() -> void:
	assert_true(_state.from_dict({ "save_version": 1,
		"information": { "areas_revealed": ["7"] } }), "a partial information block loads")
	assert_eq(_state.information["areas_revealed"], ["7"], "the supplied list is taken")
	assert_eq(_state.information["entities_revealed"], [],
		"the omitted list is present and empty, so readers need no has() guard")

func test_a_non_array_collection_loads_empty_rather_than_corrupting_state() -> void:
	assert_true(_state.from_dict({ "save_version": 1, "patches": "not an array" }),
		"a malformed collection does not abort the whole load")
	assert_eq(_state.patches, [], "the malformed key becomes an empty array")

# --- version refusal --------------------------------------------------------

func test_a_newer_save_version_is_refused() -> void:
	_state.budget = 500
	assert_false(_state.from_dict({ "save_version": 2, "economy": { "budget": 1 } }),
		"a save from a newer build is refused")
	assert_push_error("refused save_version 2",
		"and says so — a silent refusal would look like a save that loaded and did nothing")
	assert_eq(_state.budget, 500, "a refused load leaves the running game untouched")

func test_a_payload_with_no_version_is_refused() -> void:
	assert_false(_state.from_dict({ "economy": { "budget": 1 } }),
		"a payload with no save_version is refused — it is the only migration key")
	assert_push_error("refused save_version -1", "and reports the refusal")

# --- reset ------------------------------------------------------------------

func test_reset_returns_every_field_to_its_new_game_value() -> void:
	assert_true(_state.from_dict(_full_payload()), "the payload loads")
	_state.reset()
	assert_eq(_state.active_sub_area_id, 7, "sub-area returns to the tutorial default")
	assert_eq(_state.year, 1, "clock returns to year 1")
	assert_eq(_state.season, "spring", "clock returns to spring")
	assert_eq(_state.budget, 0, "economy is cleared")
	assert_eq(_state.playtime_seconds, 0, "playtime is cleared")
	assert_eq(_state.patches, [], "patch records are cleared")
	assert_eq(_state.crossings, [], "crossing records are cleared")
	assert_eq(_state.milestones["capstone_reached"], false, "progression is cleared")

# --- the single rebuild trigger (architecture §7) ---------------------------

func test_loading_announces_game_loaded_once() -> void:
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	assert_not_null(bus, "EventBus autoload is available")
	watch_signals(bus)
	assert_true(_state.from_dict(_full_payload()), "the payload loads")
	assert_signal_emit_count(bus, "game_loaded", 1,
		"exactly one game_loaded — it is the single trigger systems rebuild derived state on")

func test_a_refused_load_announces_nothing() -> void:
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	watch_signals(bus)
	assert_false(_state.from_dict({ "save_version": 99 }), "the save is refused")
	assert_push_error("refused save_version 99", "the refusal is reported")
	assert_signal_emit_count(bus, "game_loaded", 0,
		"a refused load must not tell systems to rebuild from state that never arrived")
