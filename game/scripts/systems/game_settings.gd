## Player preferences kept in user://settings.cfg, separate from saves.
class_name GameSettings
extends RefCounted

## Where preferences live. Not part of the save: a settings change must never
## touch a slot, and loading a save must never change how the game looks.
const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "ui"
const KEY_TEXT_SCALE_STEP := "text_scale_step"
const DEFAULT_TEXT_SCALE_STEP := 0
const RESET_STEP := DEFAULT_TEXT_SCALE_STEP

## What a text-size shortcut asks for.
enum TextSizeAction { NONE, LARGER, SMALLER, RESET }

## The file this instance reads and writes; tests point it at a temporary path.
var path: String

func _init(settings_path: String = DEFAULT_PATH) -> void:
	path = settings_path

## The saved text-size step, or the default when the file is missing,
## unreadable, or holds a value that is not a valid step.
func load_text_scale_step() -> int:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return DEFAULT_TEXT_SCALE_STEP
	var value: Variant = config.get_value(SECTION, KEY_TEXT_SCALE_STEP, DEFAULT_TEXT_SCALE_STEP)
	if typeof(value) != TYPE_INT:
		return DEFAULT_TEXT_SCALE_STEP
	var step: int = value
	if step < 0 or step >= TextScale.STEPS.size():
		return DEFAULT_TEXT_SCALE_STEP
	return step

## Write the text-size step, keeping any other keys already in the file.
## Returns true on success.
func save_text_scale_step(step: int) -> bool:
	var config := ConfigFile.new()
	config.load(path)   # a missing or broken file just starts empty
	config.set_value(SECTION, KEY_TEXT_SCALE_STEP, step)
	return config.save(path) == OK

## Apply the saved step to TextScale. Call before the first screen is built.
func apply_saved_text_scale() -> void:
	TextScale.set_step(load_text_scale_step())

## Which text-size action a key press means: Ctrl+= larger, Ctrl+- smaller,
## Ctrl+0 reset (the keypad twins included, and Ctrl++ for layouts that need
## Shift to reach =). Pure so the mapping is testable without an input event.
static func text_size_action(keycode: Key, ctrl_pressed: bool) -> TextSizeAction:
	if not ctrl_pressed:
		return TextSizeAction.NONE
	match keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			return TextSizeAction.LARGER
		KEY_MINUS, KEY_KP_SUBTRACT:
			return TextSizeAction.SMALLER
		KEY_0, KEY_KP_0:
			return TextSizeAction.RESET
	return TextSizeAction.NONE

## "Text size 125%" for the HUD message and the title row.
static func text_size_label(factor: float) -> String:
	return "Text size %d%%" % roundi(factor * 100.0)
