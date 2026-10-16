## Tests for Hud (build review C1): the on-screen message channel mirroring
## Debug logging, and the coalesced crossing-cue flash, both faded out over
## time rather than left stuck on screen.
extends GutTest

var _h: Hud

func before_each() -> void:
	_h = Hud.new()

func after_each() -> void:
	_h.free()

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

func test_ledger_labels_do_not_overlap_other_hud_elements() -> void:
	var budget := Rect2(Hud.BUDGET_LABEL_POSITION, Hud.BUDGET_LABEL_SIZE)
	var donation := Rect2(Hud.DONATION_LABEL_POSITION, Hud.DONATION_LABEL_SIZE)
	var cue := Rect2(_h._cue_icon.position, _h._cue_icon.custom_minimum_size)
	var message := Rect2(_h._message_label.position, Vector2(0.0, 24.0))
	assert_false(budget.intersects(donation), "budget vs donation")
	assert_false(budget.intersects(cue), "budget vs cue icon")
	assert_false(donation.intersects(cue), "donation vs cue icon")
	assert_true(budget.position.y >= message.end.y, "budget below message line")
