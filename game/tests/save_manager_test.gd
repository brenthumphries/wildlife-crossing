## Tests for SaveManager — the disk half of save/load (architecture §7, ADR
## 0005): atomic versioned-JSON writes into the user data directory, reads back
## through the migration chain, and refusal of anything this build cannot read.
##
## Every test writes to a throwaway path under `user://` and cleans up after
## itself, so nothing here can touch a real save slot.
extends GutTest

const TEST_DIR := "user://test_saves"

var _path: String

func before_each() -> void:
	_path = "%s/slot_%d.json" % [TEST_DIR, randi()]

func after_each() -> void:
	for p: String in [_path, _path + SaveManager.TEMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func _payload(budget: int = 45000) -> Dictionary:
	return {
		"save_version": 1,
		"meta": { "active_sub_area_id": 7, "saved_at_unix": 1750000000, "playtime_seconds": 60 },
		"clock": { "year": 1, "season": "summer", "day_of_season": 34, "time_speed": 1.0 },
		"economy": { "budget": budget, "last_donation": 1200 },
		"patches": [], "entities": [], "crossings": [],
		"information": { "areas_revealed": [], "entities_revealed": [] },
		"milestones": { "reached": [], "capstone_reached": false },
	}

# --- round trip -------------------------------------------------------------

func test_save_then_load_returns_the_same_payload() -> void:
	assert_eq(SaveManager.save(_payload(), _path), "", "the save reports no error")
	assert_true(FileAccess.file_exists(_path), "the slot exists on disk")
	var loaded: Dictionary = SaveManager.load_save(_path)
	assert_eq(int((loaded["economy"] as Dictionary)["budget"]), 45000, "values survive the round trip")
	assert_eq(int(loaded["save_version"]), 1, "the version key survives")

func test_the_file_is_human_readable_json() -> void:
	assert_eq(SaveManager.save(_payload(), _path), "", "the save succeeds")
	var text: String = FileAccess.get_file_as_string(_path)
	assert_string_contains(text, "\n", "the save is pretty-printed — ADR 0005 chose JSON to be diffable")
	assert_eq(typeof(JSON.parse_string(text)), TYPE_DICTIONARY, "and it parses as a JSON object")

func test_saving_creates_the_save_directory() -> void:
	var nested: String = "%s/nested_%d/slot.json" % [TEST_DIR, randi()]
	assert_eq(SaveManager.save(_payload(), nested), "", "a missing directory is created, not an error")
	assert_true(FileAccess.file_exists(nested), "the slot lands in the new directory")
	DirAccess.remove_absolute(nested)
	DirAccess.remove_absolute(nested.get_base_dir())

func test_overwriting_replaces_the_previous_save() -> void:
	assert_eq(SaveManager.save(_payload(1), _path), "", "the first save succeeds")
	assert_eq(SaveManager.save(_payload(2), _path), "", "the second save succeeds")
	var loaded: Dictionary = SaveManager.load_save(_path)
	assert_eq(int((loaded["economy"] as Dictionary)["budget"]), 2, "the newer save wins")

# --- atomicity (ADR 0005) ---------------------------------------------------

func test_no_temp_file_survives_a_completed_save() -> void:
	assert_eq(SaveManager.save(_payload(), _path), "", "the save succeeds")
	assert_false(FileAccess.file_exists(_path + SaveManager.TEMP_SUFFIX),
		"the temp file is renamed into place, never left behind to be loaded by mistake")

func test_a_stale_temp_file_is_not_mistaken_for_a_save() -> void:
	var tmp: String = _path + SaveManager.TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("{ \"save_version\": 1, \"economy\":")   # a write cut off mid-flight
	f.close()
	assert_false(SaveManager.has_save(_path),
		"an interrupted write leaves no slot — the previous save, if any, is still the one on disk")

# --- reads that must fail safely -------------------------------------------

func test_a_missing_file_loads_as_nothing() -> void:
	assert_eq(SaveManager.load_save(_path), {}, "a missing slot is empty, not an error to recover from")
	assert_false(SaveManager.has_save(_path), "and has_save agrees")

func test_a_corrupt_file_loads_as_nothing() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var f: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	f.store_string("this is not json")
	f.close()
	assert_eq(SaveManager.load_save(_path), {}, "an unparseable slot refuses to load")
	assert_push_error("not valid JSON", "and reports where the parse failed")

func test_a_save_from_a_newer_build_is_refused() -> void:
	var future: Dictionary = _payload()
	future["save_version"] = SaveManager.READABLE_VERSION + 1
	assert_eq(SaveManager.save(future, _path), "", "the file is written")
	assert_eq(SaveManager.load_save(_path), {},
		"a newer save_version is refused rather than read with this build's assumptions")
	assert_push_error("written by a newer build", "and says which version it could not read")

# --- migration chain --------------------------------------------------------

func test_a_payload_with_no_version_is_refused() -> void:
	assert_eq(SaveManager.migrate({ "economy": { "budget": 1 } }), {},
		"save_version is the only migration key — a payload without it cannot be placed in the chain")
	assert_push_error("no save_version", "and reports why")

func test_a_current_version_payload_passes_through_untouched() -> void:
	var out: Dictionary = SaveManager.migrate(_payload())
	assert_eq(int(out["save_version"]), SaveManager.READABLE_VERSION, "the version is unchanged")
	assert_eq(int((out["economy"] as Dictionary)["budget"]), 45000, "the payload is unchanged")

func test_an_older_version_with_no_step_is_refused() -> void:
	# The chain is empty by design (save_version has never been bumped). This
	# guards the contract: a version below READABLE_VERSION with no step must
	# refuse, not silently load a shape the systems will misread. When the first
	# real migration lands, this becomes the test that it runs.
	var ancient: Dictionary = _payload()
	ancient["save_version"] = 0
	assert_eq(SaveManager.migrate(ancient), {}, "an un-migratable old save is refused")
	assert_push_error("No migration step from save_version 0",
		"naming the version that needs a step, so adding one is obvious")

func test_migrate_does_not_mutate_its_input() -> void:
	var payload: Dictionary = _payload()
	SaveManager.migrate(payload)
	assert_eq(int(payload["save_version"]), 1, "the caller's dictionary is left alone")

# --- slot naming ------------------------------------------------------------

func test_slot_path_lives_in_the_user_data_directory() -> void:
	assert_string_starts_with(SaveManager.slot_path(), "user://",
		"saves go to the user data directory, never beside the binary (ADR 0005)")
	assert_string_contains(SaveManager.slot_path("slot_2"), "slot_2", "the slot name is used")
