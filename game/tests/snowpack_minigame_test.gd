## Tests for SnowpackMinigame, the snow-pit overlay: state transitions, tool reveals, verdict submission and key handling. Snow logic is covered by snowpack_profile_test.
extends GutTest

const SEED := 7

var _m: SnowpackMinigame
var _closed_count := 0
var _verdicts: Array = []

func before_each() -> void:
	_closed_count = 0
	_verdicts = []
	_m = SnowpackMinigame.new()
	add_child_autofree(_m)
	_m.closed.connect(func() -> void: _closed_count += 1)
	_m.verdict_submitted.connect(
			func(player: SnowpackProfile.Verdict, truth: SnowpackProfile.Verdict) -> void:
				_verdicts.append([player, truth]))

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

# --- lifecycle ---------------------------------------------------------------

func test_starts_closed_and_hidden() -> void:
	assert_false(_m.is_open)
	assert_false(_m.visible)

func test_start_opens_with_nothing_revealed() -> void:
	_m.start(SEED)
	assert_true(_m.is_open)
	assert_true(_m.visible)
	assert_false(_m.depth_known)
	assert_false(_m.is_resolved())
	assert_eq(_m.grain_known.size(), _m.profile.layers.size())
	assert_false(_m.grain_known.has(true))
	assert_false(_m.hardness_known.has(true))

func test_close_emits_once_and_hides() -> void:
	_m.start(SEED)
	_m.close()
	_m.close()
	assert_false(_m.is_open)
	assert_false(_m.visible)
	assert_eq(_closed_count, 1)

# --- tools -------------------------------------------------------------------

func test_probe_reveals_depth_only() -> void:
	_m.start(SEED)
	_m.apply_tool_at_depth(0.0)
	assert_true(_m.depth_known)
	assert_false(_m.grain_known.has(true))

func test_crystal_card_reveals_one_layer_grain() -> void:
	_m.start(SEED)
	_m.select_tool(SnowpackMinigame.Tool.CRYSTAL_CARD)
	_m.apply_tool_at_depth(0.0)
	assert_true(_m.grain_known[0])
	assert_false(_m.hardness_known[0])
	assert_false(_m.depth_known)

func test_hardness_test_reveals_one_layer_hardness() -> void:
	_m.start(SEED)
	_m.select_tool(SnowpackMinigame.Tool.HARDNESS_TEST)
	_m.apply_tool_at_depth(0.0)
	assert_true(_m.hardness_known[0])
	assert_false(_m.grain_known[0])

func test_tool_past_the_pit_reveals_nothing() -> void:
	_m.start(SEED)
	_m.select_tool(SnowpackMinigame.Tool.CRYSTAL_CARD)
	_m.apply_tool_at_depth(_m.profile.total_depth_cm() + 1000.0)
	assert_false(_m.grain_known.has(true))

# --- verdict -----------------------------------------------------------------

func test_result_text_is_empty_before_a_verdict() -> void:
	_m.start(SEED)
	assert_eq(_m.result_text(), "")

func test_submit_reveals_everything_and_emits_the_truth() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	assert_true(_m.is_resolved())
	assert_true(_m.depth_known)
	assert_false(_m.grain_known.has(false))
	assert_false(_m.hardness_known.has(false))
	assert_eq(_verdicts.size(), 1)
	assert_eq(_verdicts[0][0], SnowpackProfile.Verdict.VIABLE)
	assert_eq(_verdicts[0][1], _m.profile.evaluate())

func test_second_submit_and_late_tools_are_ignored() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.MARGINAL)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	assert_eq(_verdicts.size(), 1)
	assert_eq(_m.player_verdict, SnowpackProfile.Verdict.MARGINAL)

func test_result_text_names_every_criterion_and_the_denning_note() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.MARGINAL)
	var text := _m.result_text()
	for title: String in SnowpackMinigame.CRITERION_TITLES.values():
		assert_string_contains(text, title)
	assert_string_contains(text, SnowpackMinigame.DENNING_NOTE)

func test_result_text_says_agree_only_when_the_call_matches() -> void:
	_m.start(SEED)
	var truth := _m.profile.evaluate()
	_m.submit_verdict(truth)
	assert_string_contains(_m.result_text(), SnowpackMinigame.AGREE_TEXT)
	_m.start(SEED)
	var wrong: SnowpackProfile.Verdict = SnowpackProfile.Verdict.NOT_VIABLE
	if truth == wrong:
		wrong = SnowpackProfile.Verdict.VIABLE
	_m.submit_verdict(wrong)
	assert_string_contains(_m.result_text(), SnowpackMinigame.DISAGREE_TEXT)

func test_restart_clears_a_resolved_pit() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	_m.start(SEED + 1)
	assert_false(_m.is_resolved())
	assert_false(_m.depth_known)

# --- input -------------------------------------------------------------------

func test_number_keys_select_tools() -> void:
	_m.start(SEED)
	_m._unhandled_input(_key(KEY_2))
	assert_eq(_m.current_tool, SnowpackMinigame.Tool.CRYSTAL_CARD)
	_m._unhandled_input(_key(KEY_3))
	assert_eq(_m.current_tool, SnowpackMinigame.Tool.HARDNESS_TEST)
	_m._unhandled_input(_key(KEY_1))
	assert_eq(_m.current_tool, SnowpackMinigame.Tool.PROBE)

func test_verdict_keys_submit() -> void:
	_m.start(SEED)
	_m._unhandled_input(_key(KEY_N))
	assert_eq(_m.player_verdict, SnowpackProfile.Verdict.NOT_VIABLE)

func test_escape_closes_and_r_restarts() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	_m._unhandled_input(_key(KEY_R))
	assert_false(_m.is_resolved())
	_m._unhandled_input(_key(KEY_ESCAPE))
	assert_false(_m.is_open)

func test_keys_are_ignored_while_closed() -> void:
	_m._unhandled_input(_key(KEY_V))
	assert_false(_m.is_resolved())

# --- helpers -----------------------------------------------------------------

func test_ramp_color_hits_both_ends_of_the_data_axis() -> void:
	assert_eq(SnowpackMinigame.ramp_color(0.0), SnowpackMinigame.DATA_AXIS[0])
	# The top end is a lerp, so it lands within float error of the last stop.
	var last: Color = SnowpackMinigame.DATA_AXIS[SnowpackMinigame.DATA_AXIS.size() - 1]
	assert_true(SnowpackMinigame.ramp_color(1.0).is_equal_approx(last))
	assert_eq(SnowpackMinigame.ramp_color(-3.0), SnowpackMinigame.ramp_color(0.0))
	assert_eq(SnowpackMinigame.ramp_color(9.0), SnowpackMinigame.ramp_color(1.0))
