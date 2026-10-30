## The always-on milestone track: "Corridor N/12", a distinct gold capstone node, and a banner that celebrates each milestone.
class_name MilestoneTrack
extends BaseScreen

const ROW_SEPARATION := 8
const BANNER_FADE_SECONDS := 5.0
const CORRIDOR_PREFIX := "Corridor"
const BANNER_PREFIX := "Milestone reached"
const CAPSTONE_BANNER_PREFIX := "Capstone reached"
const CAPSTONE_NODE_TEXT := "◆"
const CAPSTONE_GOLD := Color(1.0, 0.84, 0.0)
## The capstone node before it is reached: the same shape, dimmed.
const CAPSTONE_PENDING_COLOR := Color(1.0, 0.84, 0.0, 0.35)
const CORRIDOR_COLOR := Color.WHITE
const BANNER_COLOR := Color(0.95, 0.85, 0.45)

var _milestones: Array = []
var _reached: Array[String] = []
var _capstone_reached: bool = false
var _row: HBoxContainer
var _corridor_label: Label
var _capstone_node: Label
var _banner_label: Label
var _banner_timer := 0.0

## "Corridor 3/12".
static func corridor_text(reached: int, total: int) -> String:
	return "%s %d/%d" % [CORRIDOR_PREFIX, reached, total]

## The celebration line for a milestone's display name.
static func banner_text(display_name: String, is_capstone: bool) -> String:
	var prefix := CAPSTONE_BANNER_PREFIX if is_capstone else BANNER_PREFIX
	return "%s: %s" % [prefix, display_name]

## How many sub-area milestones (the "N/12" denominator) the records hold; the capstone is not one.
static func sub_area_total(milestones: Array) -> int:
	var total := 0
	for m: Dictionary in milestones:
		if not bool(m.get("is_capstone", false)):
			total += 1
	return total

## How many of `reached_ids` are sub-area milestones in the records.
static func sub_area_reached(milestones: Array, reached_ids: Array) -> int:
	var count := 0
	for m: Dictionary in milestones:
		if not bool(m.get("is_capstone", false)) and reached_ids.has(String(m["id"])):
			count += 1
	return count

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", ROW_SEPARATION)
	column.add_child(_row)

	_corridor_label = Label.new()
	_corridor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corridor_label.add_theme_color_override("font_color", CORRIDOR_COLOR)
	_row.add_child(_corridor_label)

	_capstone_node = Label.new()
	_capstone_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capstone_node.text = CAPSTONE_NODE_TEXT
	_row.add_child(_capstone_node)

	_banner_label = Label.new()
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.add_theme_color_override("font_color", BANNER_COLOR)
	_banner_label.modulate.a = 0.0
	column.add_child(_banner_label)

	_refresh()
	apply_text_scale()

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)

## Read the milestone records (the registry's id -> record dictionary).
func setup(milestones_registry: Dictionary) -> void:
	_milestones = milestones_registry.values()
	_refresh()

## Show which milestones are reached; call whenever the tracker's record changes (a load included). Never celebrates.
func set_reached(reached_ids: Array, capstone_reached: bool) -> void:
	var ids: Array[String] = []
	for id: Variant in reached_ids:
		ids.append(String(id))
	if ids == _reached and capstone_reached == _capstone_reached:
		return
	_reached = ids
	_capstone_reached = capstone_reached
	_refresh()

## Raise the celebration banner for a milestone; it fades by itself and never takes input.
func celebrate(milestone_id: String, is_capstone: bool) -> void:
	_banner_label.text = banner_text(_display_name(milestone_id), is_capstone)
	_banner_label.modulate.a = 1.0
	_banner_timer = BANNER_FADE_SECONDS

## The track's count line as shown.
func corridor_line() -> String:
	return _corridor_label.text

## Whether the capstone node is lit gold (the capstone is reached).
func is_capstone_lit() -> bool:
	return _capstone_reached

## Re-size the track's texts from TextScale's current step.
func apply_text_scale() -> void:
	_corridor_label.add_theme_font_size_override("font_size", TextScale.size(TextScale.BODY))
	_capstone_node.add_theme_font_size_override("font_size", TextScale.size(TextScale.TITLE))
	_banner_label.add_theme_font_size_override("font_size", TextScale.size(TextScale.BODY))
	# A plain Control does not size to its children; reserve the track's size.
	custom_minimum_size = _row.get_combined_minimum_size()

func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer = maxf(_banner_timer - delta, 0.0)
		_banner_label.modulate.a = _banner_timer / BANNER_FADE_SECONDS

func _refresh() -> void:
	_corridor_label.text = corridor_text(sub_area_reached(_milestones, _reached),
			sub_area_total(_milestones))
	_capstone_node.add_theme_color_override("font_color",
			CAPSTONE_GOLD if _capstone_reached else CAPSTONE_PENDING_COLOR)

func _display_name(milestone_id: String) -> String:
	for m: Dictionary in _milestones:
		if String(m["id"]) == milestone_id:
			return String(m.get("display_name", milestone_id))
	return milestone_id

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	apply_text_scale()
