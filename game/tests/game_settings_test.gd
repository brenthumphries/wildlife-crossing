## Tests for GameSettings.
extends GutTest

const TEST_PATH := "user://game_settings_test.cfg"

var _settings: GameSettings

func before_each() -> void:
	_cleanup()
	_settings = GameSettings.new(TEST_PATH)
	TextScale.set_step(0)

func after_each() -> void:
	_cleanup()
	TextScale.set_step(0)

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)

func _write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func test_default_path_is_settings_cfg_outside_saves() -> void:
	assert_eq(GameSettings.DEFAULT_PATH, "user://settings.cfg")
	assert_false(GameSettings.DEFAULT_PATH.begins_with(SaveManager.SAVE_DIR))

func test_missing_file_loads_default() -> void:
	assert_eq(_settings.load_text_scale_step(), GameSettings.DEFAULT_TEXT_SCALE_STEP)

func test_round_trips_every_step() -> void:
	for i in TextScale.STEPS.size():
		assert_true(_settings.save_text_scale_step(i))
		assert_eq(GameSettings.new(TEST_PATH).load_text_scale_step(), i)

func test_stored_under_ui_text_scale_step() -> void:
	_settings.save_text_scale_step(2)
	var config := ConfigFile.new()
	assert_eq(config.load(TEST_PATH), OK)
	assert_eq(config.get_value("ui", "text_scale_step"), 2)

func test_out_of_range_loads_default() -> void:
	for bad in [-1, TextScale.STEPS.size(), 99]:
		_write_raw("[ui]\ntext_scale_step=%d\n" % bad)
		assert_eq(_settings.load_text_scale_step(), GameSettings.DEFAULT_TEXT_SCALE_STEP)

func test_wrong_type_loads_default() -> void:
	_write_raw("[ui]\ntext_scale_step=\"big\"\n")
	assert_eq(_settings.load_text_scale_step(), GameSettings.DEFAULT_TEXT_SCALE_STEP)
	_write_raw("[ui]\ntext_scale_step=1.5\n")
	assert_eq(_settings.load_text_scale_step(), GameSettings.DEFAULT_TEXT_SCALE_STEP)

func test_unreadable_file_loads_default() -> void:
	_write_raw("this is [not a config file\n===")
	assert_eq(_settings.load_text_scale_step(), GameSettings.DEFAULT_TEXT_SCALE_STEP)
	assert_engine_error("ConfigFile parse error")   # the engine logs it; we fall back quietly

func test_save_over_unreadable_file_recovers() -> void:
	_write_raw("garbage [[[")
	assert_true(_settings.save_text_scale_step(3))
	assert_eq(_settings.load_text_scale_step(), 3)

func test_save_keeps_other_keys() -> void:
	_write_raw("[audio]\nvolume=0.5\n")
	_settings.save_text_scale_step(1)
	var config := ConfigFile.new()
	config.load(TEST_PATH)
	assert_eq(config.get_value("audio", "volume"), 0.5)

func test_save_to_unwritable_path_returns_false() -> void:
	var bad := GameSettings.new("user://no_such_dir/settings.cfg")
	assert_false(bad.save_text_scale_step(1))

func test_apply_saved_text_scale_sets_the_step() -> void:
	_settings.save_text_scale_step(2)
	_settings.apply_saved_text_scale()
	assert_eq(TextScale.step(), 2)

func test_apply_saved_text_scale_with_no_file_is_default() -> void:
	TextScale.set_step(3)
	_settings.apply_saved_text_scale()
	assert_eq(TextScale.step(), GameSettings.DEFAULT_TEXT_SCALE_STEP)

func test_ctrl_keys_map_to_actions() -> void:
	assert_eq(GameSettings.text_size_action(KEY_EQUAL, true), GameSettings.TextSizeAction.LARGER)
	assert_eq(GameSettings.text_size_action(KEY_PLUS, true), GameSettings.TextSizeAction.LARGER)
	assert_eq(GameSettings.text_size_action(KEY_KP_ADD, true), GameSettings.TextSizeAction.LARGER)
	assert_eq(GameSettings.text_size_action(KEY_MINUS, true), GameSettings.TextSizeAction.SMALLER)
	assert_eq(GameSettings.text_size_action(KEY_KP_SUBTRACT, true), GameSettings.TextSizeAction.SMALLER)
	assert_eq(GameSettings.text_size_action(KEY_0, true), GameSettings.TextSizeAction.RESET)
	assert_eq(GameSettings.text_size_action(KEY_KP_0, true), GameSettings.TextSizeAction.RESET)

func test_keys_without_ctrl_do_nothing() -> void:
	for key in [KEY_EQUAL, KEY_MINUS, KEY_0]:
		assert_eq(GameSettings.text_size_action(key, false), GameSettings.TextSizeAction.NONE)

func test_unrelated_ctrl_key_does_nothing() -> void:
	assert_eq(GameSettings.text_size_action(KEY_B, true), GameSettings.TextSizeAction.NONE)

func test_label_shows_percentage() -> void:
	assert_eq(GameSettings.text_size_label(1.0), "Text size 100%")
	assert_eq(GameSettings.text_size_label(1.25), "Text size 125%")
	assert_eq(GameSettings.text_size_label(1.75), "Text size 175%")

func test_seen_hints_default_to_empty() -> void:
	assert_eq(_settings.load_seen_hints().size(), 0)

func test_marking_a_hint_seen_persists_it_once() -> void:
	assert_true(_settings.mark_hint_seen("build_mode"))
	assert_true(_settings.mark_hint_seen("build_mode"))
	assert_eq(_settings.load_seen_hints(), ["build_mode"] as Array[String])

func test_marking_a_hint_keeps_the_text_size() -> void:
	_settings.save_text_scale_step(2)
	_settings.mark_hint_seen("build_mode")
	assert_eq(_settings.load_text_scale_step(), 2)

func test_malformed_seen_hints_load_empty() -> void:
	_write_raw("[hints]\nseen=7\n")
	assert_eq(_settings.load_seen_hints().size(), 0)
