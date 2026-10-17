## Tests for TextScale.
extends GutTest

const BASES: Array[int] = [TextScale.BODY, TextScale.TITLE, TextScale.SMALL]

func before_each() -> void:
	TextScale.set_step(0)

func after_all() -> void:
	TextScale.set_step(0)

func _bus() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventBus")

func test_named_sizes_are_the_q6_proposals() -> void:
	assert_eq(TextScale.BODY, 20)
	assert_eq(TextScale.TITLE, 36)
	assert_eq(TextScale.SMALL, 16)

func test_default_step_is_first() -> void:
	assert_eq(TextScale.step(), 0)
	assert_eq(TextScale.factor(), 1.0)
	assert_eq(TextScale.size(TextScale.BODY), 20)

func test_sizes_at_every_step() -> void:
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		for base in BASES:
			var expected: int = roundi(base * TextScale.STEPS[i])
			assert_eq(TextScale.size(base), expected, "base %d step %d" % [base, i])
	TextScale.set_step(1)
	assert_eq(TextScale.size(TextScale.BODY), 25)
	TextScale.set_step(3)
	assert_eq(TextScale.size(TextScale.TITLE), 63)

func test_size_never_below_one() -> void:
	assert_eq(TextScale.size(0), 1)
	assert_eq(TextScale.size(-5), 1)

func test_clamps_at_both_ends() -> void:
	assert_false(TextScale.step_down(), "already at the first step")
	assert_eq(TextScale.step(), 0)
	assert_true(TextScale.set_step(99))
	assert_eq(TextScale.step(), TextScale.STEPS.size() - 1)
	assert_false(TextScale.step_up(), "already at the last step")
	assert_false(TextScale.set_step(99))
	assert_true(TextScale.set_step(-4))
	assert_eq(TextScale.step(), 0)

func test_step_up_and_down_report_change() -> void:
	assert_true(TextScale.step_up())
	assert_eq(TextScale.step(), 1)
	assert_true(TextScale.step_down())
	assert_eq(TextScale.step(), 0)
	assert_false(TextScale.set_step(0), "same step is no change")

func test_change_emits_text_scale_changed() -> void:
	var bus := _bus()
	assert_not_null(bus, "EventBus autoload should exist in the suite")
	if bus == null:
		return
	watch_signals(bus)
	TextScale.step_up()
	assert_signal_emitted_with_parameters(bus, "text_scale_changed", [1.25])
	TextScale.step_down()
	assert_signal_emit_count(bus, "text_scale_changed", 2)

func test_no_change_does_not_emit() -> void:
	var bus := _bus()
	if bus == null:
		pending("no EventBus autoload")
		return
	watch_signals(bus)
	TextScale.step_down()
	assert_signal_not_emitted(bus, "text_scale_changed")

func test_silent_without_autoload() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var bus := _bus()
	if bus:
		root.remove_child(bus)
	assert_null(_bus())
	assert_true(TextScale.step_up(), "changes the step without erroring")
	assert_eq(TextScale.step(), 1)
	if bus:
		root.add_child(bus)
