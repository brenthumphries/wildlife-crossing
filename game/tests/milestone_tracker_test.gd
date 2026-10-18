## Tests for MilestoneTracker — first-crossing milestones, once-only firing, the save round trip,
## and the Continental Connection capstone (reachability over a fixture; it gates nothing).
extends GutTest

const BOW_VALLEY := 7
const OTHER_SUB_AREA := 3
const FIRST_CROSSING_ID := "first_crossing_sub7"
const CAPSTONE_ID := "continental_connection"
const FIRST_CROSSING_REWARD := 2000

var _tracker: MilestoneTracker
var _fired: Array = []

func _registry() -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/milestones.json"))
	var out: Dictionary = {}
	for m: Dictionary in parsed["milestones"]:
		out[m["id"]] = m
	return out

func before_each() -> void:
	_tracker = MilestoneTracker.new()
	_tracker.setup(_registry(), BOW_VALLEY)
	_fired = []
	_tracker.milestone_reached.connect(func(id: String, is_capstone: bool) -> void: _fired.append([id, is_capstone]))

# --- first-crossing milestones ----------------------------------------------

func test_nothing_fires_before_a_crossing() -> void:
	assert_eq(_fired.size(), 0, "no milestone before any crossing")
	assert_eq(_tracker.reached.size(), 0, "none reached")

func test_first_crossing_fires_once_with_its_id() -> void:
	_tracker.on_crossing_completed(BOW_VALLEY)
	assert_eq(_fired, [[FIRST_CROSSING_ID, false]], "the loaded sub-area's first-crossing milestone fires, not as capstone")
	assert_eq(_tracker.reached, [FIRST_CROSSING_ID] as Array[String], "and is recorded")

func test_a_second_crossing_does_not_fire_it_again() -> void:
	_tracker.on_crossing_completed(BOW_VALLEY)
	_tracker.on_crossing_completed(BOW_VALLEY)
	assert_eq(_fired.size(), 1, "once per milestone")

func test_a_crossing_in_another_sub_area_does_not_count() -> void:
	_tracker.on_crossing_completed(OTHER_SUB_AREA)
	assert_eq(_fired.size(), 0, "only the loaded sub-area is evaluated")

func test_only_the_loaded_sub_areas_milestone_exists_in_play() -> void:
	_tracker.on_crossing_completed(BOW_VALLEY)
	for entry: Array in _fired:
		assert_ne(entry[0], "first_crossing_sub3", "other sub-areas' milestones stay dormant")

func test_reward_of_reads_the_data() -> void:
	assert_eq(_tracker.reward_of(FIRST_CROSSING_ID), FIRST_CROSSING_REWARD, "first crossing pays 2,000")
	assert_eq(_tracker.reward_of(CAPSTONE_ID), 0, "the capstone pays nothing")
	assert_eq(_tracker.reward_of("no_such_milestone"), 0, "an unknown id pays nothing")

func test_an_empty_registry_is_inert() -> void:
	var bare := MilestoneTracker.new()
	bare.setup({}, BOW_VALLEY)
	bare.on_crossing_completed(BOW_VALLEY)
	assert_eq(bare.reached.size(), 0, "no data, no milestones, no crash")

# --- save / restore -----------------------------------------------------------

func test_save_state_has_the_schema_keys() -> void:
	_tracker.on_crossing_completed(BOW_VALLEY)
	var saved: Dictionary = _tracker.save_state()
	assert_eq(saved["reached"], [FIRST_CROSSING_ID], "reached ids")
	assert_false(saved["capstone_reached"], "capstone flag")

func test_restore_does_not_refire() -> void:
	_tracker.on_crossing_completed(BOW_VALLEY)
	var saved: Dictionary = _tracker.save_state()
	var other := MilestoneTracker.new()
	other.setup(_registry(), BOW_VALLEY)
	var refired: Array = []
	other.milestone_reached.connect(func(id: String, _c: bool) -> void: refired.append(id))
	other.restore(saved)
	other.on_crossing_completed(BOW_VALLEY)
	assert_eq(refired.size(), 0, "a restored milestone never fires again")
	assert_eq(other.reached, [FIRST_CROSSING_ID] as Array[String], "and stays reached")

func test_replayed_crossings_count_silently() -> void:
	_tracker.count_crossing(BOW_VALLEY)
	assert_eq(_fired.size(), 0, "counting announces nothing")

# --- capstone -----------------------------------------------------------------

func _full_chain() -> Array:
	var links: Array = []
	for a in range(MilestoneTracker.YELLOWSTONE_SUB_AREA_ID, MilestoneTracker.MACKENZIE_SUB_AREA_ID):
		links.append([a, a + 1])
	return links

func test_continental_connection_reachability() -> void:
	var from_id: int = MilestoneTracker.YELLOWSTONE_SUB_AREA_ID
	var to_id: int = MilestoneTracker.MACKENZIE_SUB_AREA_ID
	assert_false(MilestoneTracker.chain_connected([], from_id, to_id), "no links, no chain")
	assert_true(MilestoneTracker.chain_connected(_full_chain(), from_id, to_id), "the full chain connects")
	var broken: Array = _full_chain()
	broken.remove_at(5)
	assert_false(MilestoneTracker.chain_connected(broken, from_id, to_id), "one missing link breaks it")
	var reversed: Array = []
	for link: Array in _full_chain():
		reversed.append([link[1], link[0]])
	assert_true(MilestoneTracker.chain_connected(reversed, from_id, to_id), "links are undirected")

func test_capstone_and_non_gating() -> void:
	# The shipped one-sub-area world has no links: the capstone is false and nothing waits on it.
	_tracker.on_crossing_completed(BOW_VALLEY)
	assert_false(_tracker.capstone_reached, "false in the shipped world")
	assert_eq(_fired.size(), 1, "and the first-crossing milestone fired regardless")
	# A complete chain fires the capstone exactly once, flagged as such.
	_tracker.set_area_links(_full_chain())
	_tracker.set_area_links(_full_chain())
	assert_true(_tracker.capstone_reached, "the full chain reaches the capstone")
	assert_eq(_fired.back(), [CAPSTONE_ID, true], "announced as the capstone")
	assert_eq(_fired.size(), 2, "once")

func test_capstone_before_any_crossing_blocks_nothing() -> void:
	_tracker.set_area_links(_full_chain())
	_tracker.on_crossing_completed(BOW_VALLEY)
	assert_true(_tracker.reached.has(FIRST_CROSSING_ID), "ordinary milestones fire in any order relative to the capstone")
