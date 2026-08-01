## Minimal always-on HUD (build review C1): an on-screen channel beside
## `Debug`'s stdout logging, plus a dedicated flash for the coalesced
## crossing-success cue (roadmap Phase 1 "visual + audio placeholder cue").
## `Debug` logging is unchanged by this -- `Main._log()` calls both, so every
## existing log call site (mode changes, build results, rejections) becomes
## legible in a windowed export without new call sites at each one.
## The crossing cue is a separate element from the message line so an event
## reads distinctly even if a mode message lands in the same frame.
class_name Hud
extends BaseScreen

const MESSAGE_FADE_SECONDS := 4.0
const CUE_FLASH_SECONDS := 1.2
const CUE_ICON := preload("res://assets/sprites/crossing_cue.png")
## Placeholder art (game/CLAUDE.md asset pipeline: no Aseprite `_src/` --
## generated as a flat-colour stand-in, not exported from source art).
const CUE_COLOR := Color(0.35, 0.85, 0.55)

var _message_label: Label
var _cue_icon: TextureRect
var _cue_label: Label
var _message_timer := 0.0
var _cue_timer := 0.0

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_message_label = Label.new()
	_message_label.position = Vector2(16.0, 44.0)   # below Main's build-status label at (16,16)
	_message_label.add_theme_color_override("font_color", Color.WHITE)
	_message_label.modulate.a = 0.0
	add_child(_message_label)

	_cue_icon = TextureRect.new()
	_cue_icon.texture = CUE_ICON
	_cue_icon.custom_minimum_size = Vector2(24.0, 24.0)
	_cue_icon.position = Vector2(16.0, 72.0)
	_cue_icon.modulate.a = 0.0
	add_child(_cue_icon)

	_cue_label = Label.new()
	_cue_label.position = Vector2(48.0, 76.0)
	_cue_label.add_theme_color_override("font_color", CUE_COLOR)
	_cue_label.modulate.a = 0.0
	add_child(_cue_label)

## Mirror a Debug-logged message on screen; fades over MESSAGE_FADE_SECONDS.
func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	_message_timer = MESSAGE_FADE_SECONDS

## The coalesced crossing-success cue: icon + "+N crossed safely", distinct
## from show_message so it reads as an event, not just the latest log line.
func show_crossing_cue(count: int) -> void:
	_cue_label.text = "+%d crossed safely" % count
	_cue_icon.modulate.a = 1.0
	_cue_label.modulate.a = 1.0
	_cue_timer = CUE_FLASH_SECONDS

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer = maxf(_message_timer - delta, 0.0)
		_message_label.modulate.a = _message_timer / MESSAGE_FADE_SECONDS
	if _cue_timer > 0.0:
		_cue_timer = maxf(_cue_timer - delta, 0.0)
		var a := _cue_timer / CUE_FLASH_SECONDS
		_cue_icon.modulate.a = a
		_cue_label.modulate.a = a
