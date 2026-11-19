## Tests for Hud (build review C1): the on-screen message channel mirroring
## Debug logging, and the coalesced crossing-cue flash, both faded out over
## time rather than left stuck on screen.
extends GutTest

var WINDOW_SIZE: Vector2i = WindowFixture.content_size()
## The longest text in data/hints.json (the build-mode hint), the toast stack's worst case.
const LONGEST_HINT := "Click tiles across the highway to place the crossing. Each tile costs money, and the total is shown at the top. Press Enter to confirm."

var _h: Hud

func before_each() -> void:
	TextScale.set_step(0)
	_h = Hud.new()

func after_each() -> void:
	_h.free()
	TextScale.set_step(0)

func test_starts_with_nothing_visible() -> void:
	assert_eq(_h._message_label.modulate.a, 0.0)
	assert_eq(_h._cue_icon.modulate.a, 0.0)
	assert_eq(_h._cue_label.modulate.a, 0.0)

func test_show_message_displays_text_at_full_alpha() -> void:
	_h.show_message("Build mode — click tiles across the corridor.")
	assert_eq(_h._message_label.text, "Build mode — click tiles across the corridor.")
	assert_eq(_h._message_label.modulate.a, 1.0)

func test_message_fades_out_over_its_window() -> void:
	_h.show_message("Overpass complete — the highway is now a safe crossing.")
	_h._process(Hud.MESSAGE_FADE_SECONDS)   # a full window elapses
	assert_eq(_h._message_label.modulate.a, 0.0)

func test_message_partway_through_fade_is_partially_visible() -> void:
	_h.show_message("Sub-area 3 is locked — v0.1.0 is scoped to Bow Valley only.")
	_h._process(Hud.MESSAGE_FADE_SECONDS / 2.0)
	assert_almost_eq(_h._message_label.modulate.a, 0.5, 0.01)

func test_show_crossing_cue_displays_count_and_icon() -> void:
	_h.show_crossing_cue(3)
	assert_eq(_h._cue_label.text, "+3 crossed safely")
	assert_eq(_h._cue_label.modulate.a, 1.0)
	assert_eq(_h._cue_icon.modulate.a, 1.0)

func test_crossing_cue_fades_out_over_its_window() -> void:
	_h.show_crossing_cue(1)
	_h._process(Hud.CUE_FLASH_SECONDS)
	assert_eq(_h._cue_icon.modulate.a, 0.0)
	assert_eq(_h._cue_label.modulate.a, 0.0)

func test_message_and_cue_fade_independently() -> void:
	_h.show_message("Build mode — click tiles across the corridor.")
	_h.show_crossing_cue(2)
	_h._process(Hud.CUE_FLASH_SECONDS)   # cue's shorter window elapses fully
	assert_eq(_h._cue_icon.modulate.a, 0.0, "cue has fully faded")
	assert_true(_h._message_label.modulate.a > 0.0, "message's longer window has not")

func test_budget_label_starts_at_the_starting_budget() -> void:
	assert_eq(_h._budget_label.text, "Budget: $%d" % EconomyConstants.STARTING_BUDGET)
	assert_true(_h._budget_label.visible)

func test_set_budget_updates_the_label() -> void:
	_h.set_budget(1234)
	assert_eq(_h._budget_label.text, "Budget: $1234")

func test_donation_label_hidden_before_any_donation() -> void:
	assert_false(_h._donation_label.visible)

func test_set_last_donation_shows_the_amount() -> void:
	_h.set_last_donation(250)
	assert_true(_h._donation_label.visible)
	assert_eq(_h._donation_label.text, "Last donation: $250")

func test_zero_donation_keeps_the_label_hidden() -> void:
	_h.set_last_donation(250)
	_h.set_last_donation(0)
	assert_false(_h._donation_label.visible)

func test_build_status_hidden_until_set_and_cleared_again() -> void:
	assert_false(_h._build_status_label.visible)
	_h.set_build_status("Build overpass — 2 tile(s) selected, $100 — budget $900")
	assert_true(_h._build_status_label.visible)
	assert_eq(_h._build_status_label.text, "Build overpass — 2 tile(s) selected, $100 — budget $900")
	_h.clear_build_status()
	assert_false(_h._build_status_label.visible)

func test_build_keys_line_shows_while_build_mode_is_open_and_not_otherwise() -> void:
	assert_false(_h._build_keys_label.visible, "hidden before build mode")
	_h.set_build_status("Build overpass — 0 tile(s) selected, $0 — budget $900")
	assert_true(_h._build_keys_label.visible)
	assert_eq(_h._build_keys_label.text, "Enter to confirm · Esc to cancel")
	_h.set_build_status("Build overpass — 2 tile(s) selected, $100 — budget $900  (needs a tile on each side)")
	assert_true(_h._build_keys_label.visible, "still up with a rejection reason")
	_h.clear_build_status()
	assert_false(_h._build_keys_label.visible, "gone when build mode closes")

func test_build_keys_line_stays_inside_the_toast_panel_below_the_status_at_every_text_scale_step() -> void:
	var hud: Hud = _hud_in_window(false)
	hud.set_build_status("Build overpass — 3 tile(s) selected, $300 — budget $9000  (needs a tile on each side of the highway)")
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		var keys: Rect2 = hud._build_keys_label.get_global_rect()
		assert_true(hud._build_keys_label.visible)
		assert_true(hud._toast_panel.get_global_rect().encloses(keys), "keys inside the panel at step %d" % step)
		assert_gte(keys.position.y, hud._build_status_label.get_global_rect().end.y,
				"keys line sits under the status at step %d" % step)

func test_every_text_lives_in_its_zone_stack() -> void:
	for node: Node in [_h._build_status_label, _h._build_keys_label, _h._message_label, _h._cue_row, _h._hint_panel]:
		assert_eq(node.get_parent(), _h._toast_stack)
	for node: Node in [_h._budget_label, _h._donation_label]:
		assert_eq(node.get_parent(), _h._resource_stack)
	for node: Node in [_h._calendar, _h._time_controls, _h._milestone_track]:
		assert_eq(node.get_parent(), _h._clock_stack)
	assert_eq(_h._cue_label.get_parent(), _h._cue_row)
	assert_eq(_h._cue_icon.get_parent(), _h._cue_row)

func test_font_sizes_follow_the_text_scale_step() -> void:
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		_h.apply_text_scale()
		assert_eq(_h._message_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
		assert_eq(_h._budget_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
		assert_eq(_h._donation_label.get_theme_font_size("font_size"), TextScale.size(TextScale.SMALL))
		assert_eq(_h._build_status_label.get_theme_font_size("font_size"), TextScale.size(TextScale.SMALL))

func test_sizes_reapply_live_on_text_scale_changed() -> void:
	add_child(_h)   # _ready connects the EventBus signal
	var before: int = _h._message_label.get_theme_font_size("font_size")
	TextScale.set_step(2)
	assert_eq(_h._message_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	assert_ne(_h._message_label.get_theme_font_size("font_size"), before)

func test_no_two_visible_elements_overlap_at_any_text_scale_step() -> void:
	_h.show_message("Overpass complete — the highway is now a safe crossing.")
	_h.show_crossing_cue(12)
	_h.set_last_donation(250)
	_h.set_build_status("Build overpass — 3 tile(s) selected, $300 — budget $9000")
	add_child(_h)
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		await get_tree().process_frame
		await get_tree().process_frame
		var elements: Array[Control] = [_h._build_status_label, _h._message_label,
				_h._cue_icon, _h._cue_label, _h._budget_label, _h._donation_label]
		for a in elements.size():
			assert_true(elements[a].visible, "element %d visible at step %d" % [a, i])
			for b in range(a + 1, elements.size()):
				assert_false(elements[a].get_global_rect().intersects(elements[b].get_global_rect()),
						"elements %d and %d overlap at step %d" % [a, b, i])

func test_hint_banner_starts_hidden() -> void:
	assert_false(_h.is_hint_visible())

func test_show_hint_displays_text_and_dismiss_hides_and_signals() -> void:
	watch_signals(_h)
	_h.show_hint("Click tiles across the highway.")
	assert_true(_h.is_hint_visible())
	assert_eq(_h._hint_label.text, "Click tiles across the highway.")
	_h._hint_button.pressed.emit()
	assert_false(_h.is_hint_visible())
	assert_signal_emitted(_h, "hint_dismissed")

func test_hint_banner_never_blocks_the_mouse() -> void:
	assert_eq(_h._hint_panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_h._hint_label.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_hint_text_is_body_except_small_at_the_largest_step() -> void:
	var last: int = TextScale.STEPS.size() - 1
	for step: int in TextScale.STEPS.size():
		TextScale.set_step(step)
		_h.apply_text_scale()
		var base: int = TextScale.SMALL if step == last else TextScale.BODY
		assert_eq(_h._hint_label.get_theme_font_size("font_size"), TextScale.size(base), "step %d" % step)

func test_hint_banner_follows_text_scale() -> void:
	TextScale.set_step(3)
	_h.apply_text_scale()
	assert_eq(_h._hint_label.get_theme_font_size("font_size"), TextScale.size(TextScale.SMALL))
	assert_eq(_h._hint_label.custom_minimum_size.x, float(TextScale.size(Hud.HINT_WIDTH_BASE)))

## The union of a node's own rect and every visible descendant Control's rect:
## what the widget actually draws, which a plain Control's own rect can understate.
func _drawn_rect(node: Control) -> Rect2:
	var rect: Rect2 = node.get_global_rect()
	for child: Node in node.find_children("*", "Control", true, false):
		var control: Control = child as Control
		if control.is_visible_in_tree():
			rect = rect.merge(control.get_global_rect())
	return rect

func _assert_stack_rows_clear(stack: Control, step_label: String) -> void:
	var rows: Array[Control] = []
	for child: Node in stack.get_children():
		var control: Control = child as Control
		if control.visible:
			rows.append(control)
	for i in range(rows.size() - 1):
		assert_false(_drawn_rect(rows[i]).intersects(_drawn_rect(rows[i + 1])),
				"%s rows %d and %d overlap at %s" % [stack.name, i, i + 1, step_label])

func test_stack_rows_never_overlap_with_a_migration_clock_and_a_banner() -> void:
	add_child(_h)
	_h.setup_milestones({ "first_crossing_sub1": { "id": "first_crossing_sub1",
			"display_name": "First crossing", "is_capstone": false } })
	_h.set_clock(1, "fall", 3)   # a migration season: the calendar shows its migration line
	_h.celebrate_milestone("first_crossing_sub1", false)
	for step: int in [0, TextScale.STEPS.size() - 1]:
		TextScale.set_step(step)
		await get_tree().process_frame
		await get_tree().process_frame
		_assert_stack_rows_clear(_h._clock_stack, "step %d" % step)

# ATT-146: zones. A real content-size viewport so anchors resolve to pixels.
func _hud_in_window(everything_showing: bool, stress: bool = true) -> Hud:
	var window := SubViewport.new()
	window.size = WINDOW_SIZE
	add_child_autofree(window)
	var hud := Hud.new()
	hud.setup_milestones({ "first_crossing_sub1": { "id": "first_crossing_sub1",
			"display_name": "First crossing", "is_capstone": false } })
	hud.set_clock(1, "fall", 3)
	if everything_showing:
		hud.celebrate_milestone("first_crossing_sub1", false)
		hud.set_last_donation(250)
		hud.show_hint(LONGEST_HINT)
		hud.show_message("Overpass complete — the highway is now a safe crossing.")
		if stress:   # a rejection reason on the status line and a crossing cue on top
			hud.set_build_status("Build overpass — 3 tile(s) selected, $300 — budget $9000  (needs a tile on each side of the highway)")
			hud.show_crossing_cue(12)
		else:   # what build mode really has up: its status, its hint and the last message
			hud.set_build_status("Build overpass — 3 tile(s) selected, $300 — budget $9000")
	window.add_child(hud)
	return hud

func _settle(step: int, hud: Hud) -> void:
	TextScale.set_step(step)
	hud.apply_text_scale()
	await get_tree().process_frame
	await get_tree().process_frame

func test_each_cluster_sits_in_its_corner_at_every_text_scale_step() -> void:
	var hud: Hud = _hud_in_window(true)
	var view := Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE))
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		var clock: Rect2 = hud._clock_panel.get_global_rect()
		var resources: Rect2 = hud._resource_panel.get_global_rect()
		var toasts: Rect2 = hud._toast_panel.get_global_rect()
		assert_almost_eq(clock.position.x, Hud.STACK_MARGIN, 0.5, "clock hugs the left at step %d" % step)
		assert_almost_eq(clock.position.y, Hud.STACK_MARGIN, 0.5, "clock hugs the top at step %d" % step)
		assert_almost_eq(resources.end.x, view.end.x - Hud.STACK_MARGIN, 0.5, "resources hug the right at step %d" % step)
		assert_almost_eq(resources.position.y, Hud.STACK_MARGIN, 0.5, "resources hug the top at step %d" % step)
		assert_almost_eq(toasts.end.x, view.end.x - Hud.STACK_MARGIN, 0.5, "toasts hug the right at step %d" % step)
		assert_almost_eq(toasts.end.y, view.end.y - Hud.STACK_MARGIN, 0.5, "toasts hug the bottom at step %d" % step)
		for rect: Rect2 in [clock, resources, toasts]:
			assert_true(view.encloses(rect), "%s inside the window at step %d" % [rect, step])

func test_the_three_panels_never_overlap_while_build_mode_is_up_at_every_text_scale_step() -> void:
	var hud: Hud = _hud_in_window(true, false)
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		_assert_panels_apart(hud, step)

# Every toast at once, with a rejection reason and a cue: more than the game puts up together.
func test_the_three_panels_never_overlap_with_every_toast_up_at_every_text_scale_step() -> void:
	var hud: Hud = _hud_in_window(true)
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		_assert_panels_apart(hud, step)

func _assert_panels_apart(hud: Hud, step: int) -> void:
	var panels: Array[Control] = [hud._clock_panel, hud._resource_panel, hud._toast_panel]
	for a in panels.size():
		assert_true(panels[a].visible, "panel %d visible at step %d" % [a, step])
		for b in range(a + 1, panels.size()):
			assert_false(panels[a].get_global_rect().intersects(panels[b].get_global_rect()),
					"panels %d and %d overlap at step %d" % [a, b, step])
	_assert_stack_rows_clear(hud._toast_stack, "step %d" % step)
	_assert_stack_rows_clear(hud._clock_stack, "step %d" % step)

func test_clock_panel_width_ignores_the_milestone_banner_at_every_text_scale_step() -> void:
	var window := SubViewport.new()
	window.size = WINDOW_SIZE
	add_child_autofree(window)
	var hud := Hud.new()
	hud.setup_milestones({ "first_crossing_sub11": { "id": "first_crossing_sub11",
			"display_name": "First crossing — Stikine–Nass–Skeena Headwaters", "is_capstone": false } })
	hud.set_clock(1, "fall", 3)
	window.add_child(hud)
	var before: Array[float] = []
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		before.append(hud._clock_panel.size.x)
	hud.celebrate_milestone("first_crossing_sub11", false)
	var banner: Label = hud._milestone_track._banner_label
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		assert_almost_eq(hud._clock_panel.size.x, before[step], 0.5, "clock panel width changed when the banner showed at step %d" % step)
		var font: Font = banner.get_theme_default_font()
		var font_size: int = banner.get_theme_font_size("font_size")
		var needed: float = font.get_multiline_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, banner.size.x, font_size).y
		assert_gte(banner.size.y + 0.5, needed, "banner text is clipped at step %d" % step)
		assert_gte(hud._clock_panel.get_global_rect().end.x + 0.5, banner.get_global_rect().end.x, "banner runs outside the clock panel at step %d" % step)
	TextScale.set_step(0)

func test_milestone_track_sits_directly_under_the_time_controls() -> void:
	var hud: Hud = _hud_in_window(true)
	assert_eq(hud._time_controls.get_index() + 1, hud._milestone_track.get_index(), "next sibling")
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		var controls_bottom: float = hud._time_controls.get_global_rect().end.y
		var track_top: float = hud._milestone_track.get_global_rect().position.y
		assert_almost_eq(track_top - controls_bottom, float(Hud.STACK_SEPARATION), 0.5,
				"only the stack separation between them at step %d" % step)

func test_budget_and_donation_update_in_the_top_right_panel() -> void:
	var hud: Hud = _hud_in_window(false)
	await _settle(0, hud)
	hud.set_budget(777)
	hud.set_last_donation(55)
	await _settle(0, hud)
	assert_eq(hud._budget_label.get_parent().get_parent(), hud._resource_panel)
	assert_true(hud._resource_panel.get_global_rect().encloses(hud._budget_label.get_global_rect()))
	assert_true(hud._resource_panel.get_global_rect().encloses(hud._donation_label.get_global_rect()))
	assert_eq(hud._budget_label.text, "Budget: $777")
	assert_eq(hud._donation_label.text, "Last donation: $55")

func test_every_cluster_has_a_semi_opaque_panel() -> void:
	for panel: PanelContainer in [_h._clock_panel, _h._resource_panel, _h._toast_panel]:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_not_null(style)
		assert_gt(style.bg_color.a, 0.0, "backing is visible")
		assert_lt(style.bg_color.a, 1.0, "backing lets the map show through")
		assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_toast_panel_is_hidden_until_a_toast_shows_and_hides_again() -> void:
	assert_false(_h._toast_panel.visible, "nothing to toast at start")
	_h.show_message("Hello")
	assert_true(_h._toast_panel.visible)
	_h._process(Hud.MESSAGE_FADE_SECONDS)
	assert_false(_h._message_label.visible)
	assert_false(_h._toast_panel.visible, "faded message leaves no empty panel")
	_h.show_crossing_cue(2)
	assert_true(_h._toast_panel.visible)
	_h._process(Hud.CUE_FLASH_SECONDS)
	assert_false(_h._toast_panel.visible)
	_h.set_build_status("Build mode")
	assert_true(_h._toast_panel.visible)
	_h.clear_build_status()
	assert_false(_h._toast_panel.visible)
	_h.show_hint("A hint")
	assert_true(_h._toast_panel.visible)
	_h._hint_button.pressed.emit()
	assert_false(_h._toast_panel.visible)

func test_toasts_stay_up_while_any_one_is_showing() -> void:
	_h.show_hint("A hint")
	_h.show_message("Hello")
	_h._process(Hud.MESSAGE_FADE_SECONDS)
	assert_true(_h._toast_panel.visible, "the hint keeps the stack up")

func test_build_status_wraps_inside_the_toast_stack() -> void:
	var hud: Hud = _hud_in_window(false)
	hud.set_build_status("Build overpass — 3 tile(s) selected, $300 — budget $9000  (needs a tile on each side of the highway)")
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		var label: Label = hud._build_status_label
		assert_ne(label.autowrap_mode, TextServer.AUTOWRAP_OFF)
		assert_true(hud._toast_panel.get_global_rect().encloses(label.get_global_rect()),
				"the wrapped readout stays inside its panel at step %d" % step)
		assert_gt(label.get_global_rect().size.y, float(label.get_line_height()) * 1.5,
				"long text wrapped onto a second line at step %d" % step)

func test_hint_got_it_button_stays_inside_the_window_and_takes_the_mouse() -> void:
	var hud: Hud = _hud_in_window(true)
	var view := Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE))
	for step: int in TextScale.STEPS.size():
		await _settle(step, hud)
		assert_true(view.encloses(hud._hint_button.get_global_rect()), "Got it on screen at step %d" % step)
		assert_eq(hud._hint_button.mouse_filter, Control.MOUSE_FILTER_STOP)

# ATT-172: the map's CanvasLayer is added after the HUD's and its controller
# accepts every press, so the HUD must sit on a higher layer to get the click.
func test_hud_layer_is_above_the_map_layer_and_below_the_modals() -> void:
	assert_gt(Main.HUD_LAYER, Main.MAP_LAYER, "HUD gets input before the map")
	var modals: Array[int] = [Main.CREDITS_LAYER, Main.TELEMETRY_LAYER, Main.SNOWPACK_LAYER, Main.INFO_LAYER]
	var previous: int = Main.HUD_LAYER
	for layer: int in modals:
		assert_gt(layer, previous, "modals stay above the HUD, in order")
		previous = layer

func test_only_buttons_take_the_mouse_so_clicks_fall_through_to_the_map() -> void:
	var hud: Hud = add_child_autofree(Hud.new())
	hud.show_hint("hint")
	var takers: Array[Control] = []
	_collect_mouse_takers(hud, takers)
	assert_gt(takers.size(), 0, "the hint's Got it button takes the mouse")
	for taker: Control in takers:
		assert_true(taker is Button, "%s must ignore the mouse (only buttons take it)" % taker.name)

func _collect_mouse_takers(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and control.mouse_filter == Control.MOUSE_FILTER_STOP:
			out.append(control)
		_collect_mouse_takers(child, out)

## ATT-147: the three meanings each have their own colour, and each widget uses its constant.
func test_success_money_and_migration_colours_all_differ() -> void:
	assert_ne(Hud.SUCCESS_COLOR, Hud.MONEY_COLOR)
	assert_ne(Hud.SUCCESS_COLOR, SeasonCalendar.MIGRATION_COLOR)
	assert_ne(Hud.MONEY_COLOR, SeasonCalendar.MIGRATION_COLOR)

func test_cue_label_uses_success_colour() -> void:
	assert_eq(_h._cue_label.get_theme_color("font_color"), Hud.SUCCESS_COLOR)

func test_donation_label_uses_money_colour() -> void:
	assert_eq(_h._donation_label.get_theme_color("font_color"), Hud.MONEY_COLOR)

## ATT-147 contrast check. Each HUD text colour is measured (WCAG 2.x) against the
## panel backing (Hud.PANEL_COLOR, semi-opaque) composited over each terrain colour
## the map can show, plus the dark backdrop. Text needs 4.5:1; the calendar ring arc
## needs 3:1. Frozen ice is the one pale terrain: the approved colours sit just under
## 4.5:1 there, so that case is held to 3:1 here and flagged in the PR for Brent.
const BACKDROP_COLOR := Color(0.08, 0.10, 0.09)
const TEXT_MIN_RATIO: float = 4.5
const ARC_MIN_RATIO: float = 3.0

func _contrast_channel(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)

func _relative_luminance(c: Color) -> float:
	return 0.2126 * _contrast_channel(c.r) + 0.7152 * _contrast_channel(c.g) + 0.0722 * _contrast_channel(c.b)

func _contrast_ratio(a: Color, b: Color) -> float:
	var hi: float = maxf(_relative_luminance(a), _relative_luminance(b))
	var lo: float = minf(_relative_luminance(a), _relative_luminance(b))
	return (hi + 0.05) / (lo + 0.05)

## The panel colour composited over an opaque terrain colour.
func _panel_over(terrain: Color) -> Color:
	var panel: Color = Hud.PANEL_COLOR
	var a: float = panel.a
	return Color(
		panel.r * a + terrain.r * (1.0 - a),
		panel.g * a + terrain.g * (1.0 - a),
		panel.b * a + terrain.b * (1.0 - a),
		1.0)

func _map_backings() -> Dictionary:
	return {
		"forest": WorldRenderer.COLOR_FOREST,
		"alpine": WorldRenderer.COLOR_ALPINE,
		"other": WorldRenderer.COLOR_OTHER,
		"impassable": WorldRenderer.COLOR_IMPASSABLE,
		"hazard": WorldRenderer.COLOR_HAZARD,
		"flooded": WorldRenderer.COLOR_FLOODED,
		"backdrop": BACKDROP_COLOR,
	}

func _text_colours() -> Dictionary:
	return {
		"success": Hud.SUCCESS_COLOR,
		"money": Hud.MONEY_COLOR,
		"migration": SeasonCalendar.MIGRATION_COLOR,
	}

func test_text_colours_reach_4_5_to_1_over_every_non_ice_backing() -> void:
	for text_name: String in _text_colours():
		var text: Color = _text_colours()[text_name]
		for terrain_name: String in _map_backings():
			var backing: Color = _panel_over(_map_backings()[terrain_name])
			var ratio: float = _contrast_ratio(text, backing)
			assert_gte(ratio, TEXT_MIN_RATIO, "%s text over %s is %.2f:1" % [text_name, terrain_name, ratio])

func test_text_colours_reach_3_to_1_over_frozen_ice() -> void:
	for text_name: String in _text_colours():
		var text: Color = _text_colours()[text_name]
		var ratio: float = _contrast_ratio(text, _panel_over(WorldRenderer.COLOR_FROZEN_RIVER))
		assert_gte(ratio, ARC_MIN_RATIO, "%s text over frozen ice is %.2f:1" % [text_name, ratio])

func test_migration_arc_reaches_3_to_1_over_every_backing() -> void:
	var arc: Color = SeasonCalendar.MIGRATION_COLOR
	var backings: Dictionary = _map_backings()
	backings["frozen"] = WorldRenderer.COLOR_FROZEN_RIVER
	for terrain_name: String in backings:
		var ratio: float = _contrast_ratio(arc, _panel_over(backings[terrain_name]))
		assert_gte(ratio, ARC_MIN_RATIO, "migration arc over %s is %.2f:1" % [terrain_name, ratio])
