## Tests for HintCoach: five first-time hints, each shown once, stored in settings and not in saves.
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/systems/game_state.gd")
const SETTINGS_PATH := "user://hint_coach_test.cfg"
const EVENTS: Array[String] = [
	HintCoach.EVENT_GAME_STARTED,
	HintCoach.EVENT_OVERLAY_SHOWN,
	HintCoach.EVENT_BUILD_MODE_OPENED,
	HintCoach.EVENT_CROSSING_COMPLETED,
	HintCoach.EVENT_DONATION_RECEIVED,
]

var _settings: GameSettings
var _coach: HintCoach
var _shown: Array[String] = []

func before_each() -> void:
	_cleanup()
	_settings = GameSettings.new(SETTINGS_PATH)
	_shown = []
	_coach = _make_coach()

func after_each() -> void:
	_cleanup()

func _cleanup() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)

func _make_coach() -> HintCoach:
	var coach := HintCoach.new(_settings)
	coach.hint_shown.connect(func(hint_id: String, _text: String) -> void: _shown.append(hint_id))
	return coach

func test_data_file_has_five_hints_each_with_text() -> void:
	assert_eq(_coach.hint_ids().size(), 5)
	for hint_id: String in _coach.hint_ids():
		assert_ne(_coach.text_for(hint_id).strip_edges(), "", "hint %s has text" % hint_id)

func test_each_event_fires_exactly_one_hint_once() -> void:
	for event in EVENTS:
		_shown.clear()
		_coach.notify(event)
		assert_eq(_shown.size(), 1, "%s shows one hint" % event)
		_coach.dismiss()
		_coach.notify(event)
		assert_eq(_shown.size(), 1, "%s does not repeat" % event)

func test_unknown_event_shows_nothing() -> void:
	_coach.notify("unrelated")
	assert_eq(_shown.size(), 0)
	assert_eq(_coach.current_id, "")

func test_second_hint_waits_for_the_first_to_be_dismissed() -> void:
	_coach.notify(HintCoach.EVENT_OVERLAY_SHOWN)
	_coach.notify(HintCoach.EVENT_BUILD_MODE_OPENED)
	assert_eq(_shown.size(), 1)
	_coach.dismiss()
	assert_eq(_shown.size(), 2)
	assert_ne(_shown[0], _shown[1])

func test_dismiss_emits_cleared_and_empties_current() -> void:
	watch_signals(_coach)
	_coach.notify(HintCoach.EVENT_DONATION_RECEIVED)
	_coach.dismiss()
	assert_signal_emitted(_coach, "hint_cleared")
	assert_eq(_coach.current_id, "")

func test_seen_hints_persist_in_settings_across_coaches() -> void:
	_coach.notify(HintCoach.EVENT_CROSSING_COMPLETED)
	assert_eq(_settings.load_seen_hints().size(), 1)
	_shown.clear()
	var later := _make_coach()
	later.notify(HintCoach.EVENT_CROSSING_COMPLETED)
	assert_eq(_shown.size(), 0, "a new session does not replay a seen hint")

func test_seen_hints_are_not_written_to_a_save() -> void:
	_coach.notify(HintCoach.EVENT_OVERLAY_SHOWN)
	var state: Node = GameStateScript.new()
	assert_false(JSON.stringify(state.to_dict()).contains("hint"))
	state.free()

func test_game_started_shows_the_first_step_hint() -> void:
	_coach.notify(HintCoach.EVENT_GAME_STARTED)
	assert_eq(_coach.current_id, "first_step")
	assert_true(_coach.text_for("first_step").begins_with("Welcome. Click Add crossing"))

func test_first_step_stays_until_dismissed() -> void:
	_coach.notify(HintCoach.EVENT_GAME_STARTED)
	_coach.notify("unrelated")
	assert_eq(_coach.current_id, "first_step")

func test_dismiss_if_current_clears_the_matching_hint() -> void:
	watch_signals(_coach)
	_coach.notify(HintCoach.EVENT_GAME_STARTED)
	_coach.dismiss_if_current("first_step")
	assert_eq(_coach.current_id, "")
	assert_signal_emitted(_coach, "hint_cleared")

func test_dismiss_if_current_leaves_another_hint_alone() -> void:
	_coach.notify(HintCoach.EVENT_OVERLAY_SHOWN)
	_coach.dismiss_if_current("first_step")
	assert_eq(_coach.current_id, "overlay_colors")

func test_dismiss_before_build_hint_lets_it_show_next() -> void:
	_coach.notify(HintCoach.EVENT_GAME_STARTED)
	_coach.dismiss_if_current("first_step")
	_coach.notify(HintCoach.EVENT_BUILD_MODE_OPENED)
	assert_eq(_coach.current_id, "build_mode")

func test_first_step_does_not_return_once_seen() -> void:
	_coach.notify(HintCoach.EVENT_GAME_STARTED)
	_coach.dismiss()
	var later: HintCoach = _make_coach()
	_shown.clear()
	later.notify(HintCoach.EVENT_GAME_STARTED)
	assert_eq(_shown.size(), 0)
	assert_eq(later.current_id, "")
