## Minimal always-on HUD (build review C1): an on-screen channel beside
## `Debug`'s stdout logging, plus a dedicated flash for the coalesced
## crossing-success cue (roadmap Phase 1 "visual + audio placeholder cue").
## `Debug` logging is unchanged by this -- `Main._log()` calls both, so every
## existing log call site (mode changes, build results, rejections) becomes
## legible in a windowed export without new call sites at each one.
## The crossing cue is a separate element from the message line so an event
## reads distinctly even if a mode message lands in the same frame.
## C16 adds two persistent labels under the cue: the budget (always shown) and
## the last donation (hidden until one arrives).
## C20 stacks every HUD text in one VBoxContainer (no fixed positions), takes
## sizes from TextScale, and re-applies them on `text_scale_changed`. The
## build status readout, formerly a free-floating label in Main, lives here.
## C43 adds a dismissible hint banner at the foot of the stack for HintCoach.
## C36 puts the SeasonCalendar at the head of the stack, always visible.
## C34 adds the TimeControls row directly beneath it.
class_name Hud
extends BaseScreen

signal hint_dismissed()
## The player picked a speed (button or key) on the TimeControls row.
signal time_speed_selected(multiplier: float)

const MESSAGE_FADE_SECONDS := 4.0
const CUE_FLASH_SECONDS := 1.2
const CUE_ICON := preload("res://assets/sprites/crossing_cue.png")
## Placeholder art (game/CLAUDE.md asset pipeline: no Aseprite `_src/` --
## generated as a flat-colour stand-in, not exported from source art).
const CUE_COLOR := Color(0.35, 0.85, 0.55)
const STACK_MARGIN := 16.0
const STACK_SEPARATION := 4
const CUE_ROW_SEPARATION := 8
## The cue icon's edge in px at text-scale step 1.0; scaled with the text.
const CUE_ICON_BASE_SIZE := 24.0
## The hint banner's text width in px at text-scale step 1.0; scaled with the text.
const HINT_WIDTH_BASE := 420
const HINT_DISMISS_TEXT := "Got it"

var _stack: VBoxContainer
var _calendar: SeasonCalendar
var _time_controls: TimeControls
var _build_status_label: Label
var _message_label: Label
var _cue_row: HBoxContainer
var _cue_icon: TextureRect
var _cue_label: Label
var _budget_label: Label
var _donation_label: Label
var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_button: Button
var _message_timer := 0.0
var _cue_timer := 0.0

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT,
			Control.PRESET_MODE_MINSIZE, int(STACK_MARGIN))
	_stack.add_theme_constant_override("separation", STACK_SEPARATION)
	add_child(_stack)

	_calendar = SeasonCalendar.new()
	_stack.add_child(_calendar)

	_time_controls = TimeControls.new()
	_time_controls.speed_selected.connect(_on_time_controls_speed_selected)
	_stack.add_child(_time_controls)

	_build_status_label = _add_label(Color.WHITE)
	_build_status_label.hide()   # shown only while build mode is open

	_message_label = _add_label(Color.WHITE)
	_message_label.modulate.a = 0.0

	_cue_row = HBoxContainer.new()
	_cue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue_row.add_theme_constant_override("separation", CUE_ROW_SEPARATION)
	_stack.add_child(_cue_row)

	_cue_icon = TextureRect.new()
	_cue_icon.texture = CUE_ICON
	_cue_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cue_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cue_icon.modulate.a = 0.0
	_cue_row.add_child(_cue_icon)

	_cue_label = Label.new()
	_cue_label.add_theme_color_override("font_color", CUE_COLOR)
	_cue_label.modulate.a = 0.0
	_cue_row.add_child(_cue_label)

	_budget_label = _add_label(Color.WHITE)
	set_budget(EconomyConstants.STARTING_BUDGET)

	_donation_label = _add_label(CUE_COLOR)
	_donation_label.hide()   # nothing to show until a donation arrives

	_build_hint_banner()

	apply_text_scale()

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)

## Re-size every HUD text from TextScale's current step.
func apply_text_scale() -> void:
	_set_font_size(_build_status_label, TextScale.SMALL)
	_set_font_size(_message_label, TextScale.BODY)
	_set_font_size(_cue_label, TextScale.BODY)
	_set_font_size(_budget_label, TextScale.BODY)
	_set_font_size(_donation_label, TextScale.SMALL)
	_set_font_size(_hint_label, TextScale.BODY)
	_hint_button.add_theme_font_size_override("font_size", TextScale.size(TextScale.BODY))
	_hint_label.custom_minimum_size.x = TextScale.size(HINT_WIDTH_BASE)
	_cue_icon.custom_minimum_size = Vector2.ONE * TextScale.size(roundi(CUE_ICON_BASE_SIZE))

## Show the clock in the season calendar; call on `season_changed` and as days pass.
func set_clock(year: int, season: String, day_of_season: int) -> void:
	_calendar.set_clock(year, season, day_of_season)

## Highlight the running speed on the time controls; call on `time_speed_changed`.
func set_time_speed(multiplier: float) -> void:
	_time_controls.show_speed(multiplier)

## Handle a Space / 1 / 2 / 3 press; true if it was a time-control key.
func handle_time_key(keycode: Key) -> bool:
	return _time_controls.handle_key(keycode)

## Show the build-mode cost/status readout above the message line.
func set_build_status(text: String) -> void:
	_build_status_label.text = text
	_build_status_label.show()

## Hide the build-mode readout (build mode closed).
func clear_build_status() -> void:
	_build_status_label.hide()

## Show a first-time hint in the banner until the player dismisses it.
func show_hint(text: String) -> void:
	_hint_label.text = text
	_hint_panel.show()

## Hide the hint banner.
func clear_hint() -> void:
	_hint_panel.hide()

## Whether the hint banner is up.
func is_hint_visible() -> bool:
	return _hint_panel.visible

# The banner and its text ignore the mouse so play continues underneath;
# only the button takes clicks.
func _build_hint_banner() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.hide()
	_stack.add_child(_hint_panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(column)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hint_label)

	_hint_button = Button.new()
	_hint_button.text = HINT_DISMISS_TEXT
	_hint_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hint_button.focus_mode = Control.FOCUS_NONE   # Enter confirms a build; the button must not steal it
	_hint_button.pressed.connect(_on_hint_button_pressed)
	column.add_child(_hint_button)

func _on_time_controls_speed_selected(multiplier: float) -> void:
	time_speed_selected.emit(multiplier)

func _on_hint_button_pressed() -> void:
	clear_hint()
	hint_dismissed.emit()

func _add_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	_stack.add_child(label)
	return label

func _set_font_size(label: Label, base: int) -> void:
	label.add_theme_font_size_override("font_size", TextScale.size(base))

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	apply_text_scale()

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

## Show the current balance; call on every `budget_changed`.
func set_budget(balance: int) -> void:
	_budget_label.text = "Budget: $%d" % balance

## Show the most recent donation; call on `donation_received`. A zero amount
## (a fresh game, or a save with no donation yet) keeps the label hidden.
func set_last_donation(amount: int) -> void:
	_donation_label.visible = amount > 0
	_donation_label.text = "Last donation: $%d" % amount

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer = maxf(_message_timer - delta, 0.0)
		_message_label.modulate.a = _message_timer / MESSAGE_FADE_SECONDS
	if _cue_timer > 0.0:
		_cue_timer = maxf(_cue_timer - delta, 0.0)
		var a := _cue_timer / CUE_FLASH_SECONDS
		_cue_icon.modulate.a = a
		_cue_label.modulate.a = a
