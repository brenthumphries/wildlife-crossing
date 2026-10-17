## Tests for InformationPanel — each layer's before and after text, selection, Enter, and the disabled cases.
extends GutTest

const AREA := 7
const HOT_TILE := Vector2i(12, 5)

var _sim: Simulation
var _panel: InformationPanel

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _registries() -> Dictionary:
	var treg: Dictionary = {}
	for t: Dictionary in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var sreg: Dictionary = {}
	for s: Dictionary in _load_json("res://data/species_stats.json")["species"]:
		sreg[s["id"]] = s
	var ireg: Dictionary = {}
	for c: Dictionary in _load_json("res://data/infrastructure.json")["infrastructure"]:
		ireg[c["crossing_type"]] = c
	var seg: Dictionary = {}
	for s: Dictionary in _load_json("res://data/segments.json")["segments"]:
		seg[s["id"]] = s
	return { "tiles": treg, "species": sreg, "infrastructure": ireg, "segments": seg,
		"biome_groups": _load_json("res://data/biome_groups.json") }

func before_each() -> void:
	TextScale.set_step(0)
	_sim = Simulation.new()
	autofree(_sim)
	_sim.load_world(AREA, _registries(), 42)
	_panel = InformationPanel.new()
	autofree(_panel)
	_panel.setup(_sim.information, _sim.economy, AREA)

func after_each() -> void:
	TextScale.set_step(0)

func _select(index: int) -> void:
	_panel.selected = index
	_panel.refresh()

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func test_rows_show_price_state_and_budget() -> void:
	assert_string_contains(_panel.product_row_text(0), "Habitat assessment")
	assert_string_contains(_panel.product_row_text(0), "$%d" % EconomyConstants.INFO_HABITAT_ASSESSMENT)
	assert_string_contains(_panel.product_row_text(1), "$%d" % EconomyConstants.INFO_POPULATION_SURVEY)
	assert_string_contains(_panel.product_row_text(2), "$%d" % EconomyConstants.INFO_CORRIDOR_STUDY)
	assert_string_contains(_panel.product_row_text(0), "not bought")
	assert_string_contains(_panel.budget_text(), "$%d" % _sim.economy.budget)

func test_before_any_purchase_patches_are_labelled_with_unknowns() -> void:
	var text: String = _panel.details_text()
	var overview: Array = _sim.information.patch_overview(AREA)
	var first: Dictionary = overview[0]
	assert_string_contains(text, "Patch 1: %s patch, %d tiles" % [first["biome"], first["tile_count"]])
	assert_string_contains(text, "Habitat: %s\n" % first["band"])
	assert_string_contains(text, "Population: unknown")
	assert_string_contains(text, "no data")
	assert_false(text.contains("quality"), "no quality wording before the assessment")
	assert_false(text.contains("deaths"), "no corridor data")
	assert_false(text.contains(_sim.graph.patch_key(0)), "raw patch ids stay out of the panel")

func test_numeric_quality_is_absent_until_the_assessment_is_bought() -> void:
	var exact: String = "%.1f" % _sim.habitat.quality(0)
	assert_false(_panel.details_text().contains("quality " + exact), "absent before purchase")
	_select(0)
	assert_true(_panel.buy_selected(), "the assessment is bought")
	assert_string_contains(_panel.details_text(), "quality " + exact)

func test_habitat_assessment_shows_only_its_layer() -> void:
	_select(0)
	_panel.buy_selected()
	var text: String = _panel.details_text()
	assert_string_contains(text, "of 100 over")
	assert_string_contains(text, "Population: unknown")
	assert_string_contains(text, "no data")
	assert_string_contains(_panel.product_row_text(0), "— bought")
	assert_string_contains(_panel.status_text, "Bought Habitat assessment")

func test_population_survey_shows_only_its_layer() -> void:
	_select(1)
	assert_true(_panel.buy_selected(), "the survey is bought")
	var text: String = _panel.details_text()
	assert_false(text.contains("Population: unknown"), "population is no longer unknown")
	assert_string_contains(text, "grizzly_bear 18")
	assert_false(text.contains("quality"), "no exact quality")
	assert_string_contains(text, "no data")

func test_corridor_study_shows_hotspots_deadliest_first() -> void:
	_sim.information.record_attempt(HOT_TILE)
	_sim.information.record_attempt(HOT_TILE)
	_sim.information.record_death(HOT_TILE)
	_sim.information.record_attempt(Vector2i(13, 5))
	_sim.information.record_death(Vector2i(13, 5))
	_sim.information.record_death(Vector2i(13, 5))
	_select(2)
	assert_true(_panel.buy_selected(), "the study is bought")
	var text: String = _panel.details_text()
	assert_string_contains(text, "since the session started or loaded")
	assert_lt(text.find("Tile (13, 5): 2 deaths"), text.find("Tile (12, 5): 1 deaths"), "deadliest first")
	assert_string_contains(text, "Population: unknown")
	assert_false(text.contains("quality"), "no exact quality")

func test_patch_numbering_is_identical_across_layers() -> void:
	var before: PackedStringArray = _patch_headings(_panel.details_text())
	for i in 3:
		_select(i)
		_panel.buy_selected()
	assert_eq(_patch_headings(_panel.details_text()), before, "same numbers and labels after every purchase")

func test_arrow_keys_move_and_clamp_the_selection() -> void:
	_panel.move_selection(1)
	assert_eq(_panel.selected, 1)
	_panel.move_selection(5)
	assert_eq(_panel.selected, 2, "stops at the last product")
	_panel.move_selection(-9)
	assert_eq(_panel.selected, 0, "stops at the first")
	assert_string_contains(_panel.product_row_text(0), InformationPanel.SELECTION_MARK)

func test_enter_buys_the_selected_product_once() -> void:
	_select(1)
	var before: int = _sim.economy.budget
	assert_true(_panel.buy_selected())
	assert_eq(before - _sim.economy.budget, EconomyConstants.INFO_POPULATION_SURVEY, "charged its price")
	assert_true(_sim.information.holds("population_survey", AREA))
	assert_false(_sim.information.holds("habitat_assessment", AREA), "and only that one")
	assert_string_contains(_panel.budget_text(), "$%d" % _sim.economy.budget)

func test_held_product_is_disabled_and_charges_nothing() -> void:
	_select(0)
	_panel.buy_selected()
	var before: int = _sim.economy.budget
	assert_false(_panel.is_product_enabled(0), "held is disabled")
	assert_false(_panel.buy_selected(), "Enter on it buys nothing")
	assert_eq(_sim.economy.budget, before, "and charges nothing")
	assert_string_contains(_panel.status_text, "already held")

func test_unaffordable_product_is_disabled_and_charges_nothing() -> void:
	_sim.economy.spend(_sim.economy.budget - (EconomyConstants.INFO_HABITAT_ASSESSMENT - 1))
	var before: int = _sim.economy.budget
	_select(0)
	assert_false(_panel.is_product_enabled(0), "unaffordable is disabled")
	assert_false(_panel.buy_selected(), "Enter on it buys nothing")
	assert_eq(_sim.economy.budget, before, "and charges nothing")
	assert_false(_sim.information.holds("habitat_assessment", AREA))
	assert_string_contains(_panel.status_text, "Not enough")

func test_open_close_and_keys() -> void:
	assert_false(_panel.is_open)
	_panel.open()
	assert_true(_panel.is_open)
	_panel._unhandled_input(_key(KEY_DOWN))
	assert_eq(_panel.selected, 1, "Down moves the selection")
	_panel._unhandled_input(_key(KEY_I))
	assert_false(_panel.is_open, "I closes")
	_panel.open()
	_panel._unhandled_input(_key(KEY_ESCAPE))
	assert_false(_panel.is_open, "Escape closes")
	_panel._unhandled_input(_key(KEY_ENTER))
	assert_eq(_sim.information.products_by_area.size(), 0, "a closed panel buys nothing")

func test_panel_blocks_clicks_behind_it() -> void:
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_STOP)

func _patch_headings(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for line in text.split("\n"):
		if line.begins_with("Patch "):
			out.append(line)
	return out

func test_font_sizes_follow_the_text_scale_step() -> void:
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		_panel.apply_text_scale()
		assert_eq(_panel._title_label.get_theme_font_size("font_size"), TextScale.size(TextScale.TITLE))
		assert_eq(_panel._budget_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
		for row: Label in _panel._product_labels:
			assert_eq(row.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
		assert_eq(_panel._body.get_theme_font_size("normal_font_size"), TextScale.size(TextScale.BODY))
		assert_eq(_panel._hint_label.get_theme_font_size("font_size"), TextScale.size(TextScale.SMALL))

func test_sizes_reapply_live_on_text_scale_changed() -> void:
	add_child_autofree(_panel)   # _ready connects the EventBus signal
	var before: int = _panel._title_label.get_theme_font_size("font_size")
	TextScale.set_step(2)
	assert_eq(_panel._title_label.get_theme_font_size("font_size"), TextScale.size(TextScale.TITLE))
	assert_ne(_panel._title_label.get_theme_font_size("font_size"), before)

func test_rows_and_hint_stay_in_the_viewport_at_every_text_scale_step() -> void:
	_panel.status_text = "Not enough budget for Population survey."
	add_child_autofree(_panel)
	_panel.open()
	var view := get_viewport().get_visible_rect()
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		await get_tree().process_frame
		await get_tree().process_frame
		var shown: Array[Control] = [_panel._title_label, _panel._budget_label,
				_panel._status_label, _panel._hint_label]
		shown.append_array(_panel._product_labels)
		for c in shown.size():
			assert_true(view.encloses(shown[c].get_global_rect()),
					"element %d within the viewport at step %d" % [c, i])
		assert_gt(_panel._body.size.y, 0.0, "body keeps room to scroll at step %d" % i)
