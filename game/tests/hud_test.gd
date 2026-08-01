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
