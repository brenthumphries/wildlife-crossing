## Tests for SpeciesRegistry's data-boundary load: that numeric ids survive JSON
## parsing as `int` dictionary keys, that string ids stay strings, and that the
## record's own id field agrees with the key it is filed under.
##
## Regression for the 2026-09-02 windowed build walk, where the world map drew
## every sub-area locked — including the tutorial one — because
## `JSON.parse_string` returns every JSON number as a float and Godot
## dictionaries treat `7` and `7.0` as different keys. The suite could not see
## it because every fixture was hand-built with `int` keys; these tests read
## `res://data/` through the production path instead.
extends GutTest

## The autoload's script, instantiated directly so these tests exercise the real
## `res://data/` load without depending on the `SpeciesRegistry` singleton.
const REGISTRY_SCRIPT := preload("res://scripts/systems/species_registry.gd")

const TUTORIAL_SUB_AREA := 7
const SUB_AREA_COUNT := 12

# The registry is read-only once loaded and no test mutates it, so one
# instance is built for the whole script rather than per test.
var _reg := REGISTRY_SCRIPT.new()

func before_all() -> void:
	_reg.load_all()

func after_all() -> void:
	_reg.free()

# --- numeric ids -----------------------------------------------------------

func test_all_twelve_sub_areas_load() -> void:
	assert_eq(_reg.sub_areas.size(), SUB_AREA_COUNT,
			"sub_areas.json loads all %d records" % SUB_AREA_COUNT)

func test_sub_area_keys_are_ints_not_floats() -> void:
	for key: Variant in _reg.sub_areas.keys():
		assert_eq(typeof(key), TYPE_INT,
				"sub_areas key %s is an int, not a float" % str(key))

func test_sub_area_lookup_by_int_literal_hits() -> void:
	assert_true(_reg.sub_areas.has(TUTORIAL_SUB_AREA),
			"has(%d) — the int literal every typed caller passes"
			% TUTORIAL_SUB_AREA)
	assert_false(_reg.sub_areas.has(float(TUTORIAL_SUB_AREA)),
			"has(%.1f) — the float key must not exist alongside it"
			% float(TUTORIAL_SUB_AREA))

func test_sub_area_record_id_field_agrees_with_its_key() -> void:
	for key: Variant in _reg.sub_areas.keys():
		var rec: Dictionary = _reg.sub_areas[key]
		assert_eq(typeof(rec["id"]), TYPE_INT,
				"record filed under %s carries an int id field" % str(key))
		assert_eq(rec["id"], key,
				"record id field equals the key it is filed under")

func test_only_the_tutorial_sub_area_starts_unlocked() -> void:
	var unlocked: Array = []
	for key: Variant in _reg.sub_areas.keys():
		if bool(_reg.sub_areas[key].get("starts_unlocked", false)):
			unlocked.append(key)
	unlocked.sort()
	assert_eq(unlocked, [TUTORIAL_SUB_AREA],
			"exactly sub-area %d starts unlocked" % TUTORIAL_SUB_AREA)

# --- string ids are left alone ---------------------------------------------

func test_string_keyed_registries_keep_string_keys() -> void:
	var registries: Dictionary = {
		"tiles": _reg.tiles,
		"species": _reg.species,
		"entities": _reg.entities,
		"segments": _reg.segments,
		"infrastructure": _reg.infrastructure,
		"milestones": _reg.milestones,
	}
	for name: String in registries:
		var reg: Dictionary = registries[name]
		assert_false(reg.is_empty(), "%s loaded at least one record" % name)
		for key: Variant in reg.keys():
			assert_eq(typeof(key), TYPE_STRING,
					"%s key %s stays a string" % [name, str(key)])

func test_a_known_string_id_still_resolves() -> void:
	assert_true(_reg.species.has("grizzly_bear"),
			"species keyed by their string ids")
	assert_true(_reg.infrastructure.has("overpass"),
			"infrastructure keyed by crossing_type, not id")
