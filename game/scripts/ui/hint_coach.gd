## Shows each first-time hint once, in order, and remembers which were seen in the settings file.
class_name HintCoach
extends RefCounted

signal hint_shown(hint_id: String, text: String)
signal hint_cleared()

const DEFAULT_HINTS_PATH := "res://data/hints.json"

## The event names `notify` takes; each is the `event` field in hints.json.
const EVENT_OVERLAY_SHOWN := "overlay_shown"
const EVENT_BUILD_MODE_OPENED := "build_mode_opened"
const EVENT_CROSSING_COMPLETED := "crossing_completed"
const EVENT_DONATION_RECEIVED := "donation_received"

## The hint on screen right now, or "" when none is.
var current_id := ""

var _settings: GameSettings
## hint id -> { "event": String, "text": String }, in file order.
var _hints: Dictionary = {}
var _seen: Array[String] = []
## Hints triggered while another was still on screen, oldest first.
var _queue: Array[String] = []

func _init(settings: GameSettings = null, hints_path: String = DEFAULT_HINTS_PATH) -> void:
	_settings = settings if settings != null else GameSettings.new()
	_seen = _settings.load_seen_hints()
	_load_hints(hints_path)

## An event the game just saw. Queues every unseen hint tied to it, marks it
## seen right away (so it never repeats), and shows it if nothing else is up.
func notify(event: String) -> void:
	for hint_id: String in _hints:
		var record: Dictionary = _hints[hint_id]
		if record["event"] != event or _seen.has(hint_id):
			continue
		_seen.append(hint_id)
		_settings.mark_hint_seen(hint_id)
		_queue.append(hint_id)
	if current_id == "":
		_show_next()

## The player closed the banner: show the next waiting hint, if any.
func dismiss() -> void:
	if current_id == "":
		return
	current_id = ""
	hint_cleared.emit()
	_show_next()

## True once the hint has been shown.
func has_seen(hint_id: String) -> bool:
	return _seen.has(hint_id)

## Every hint id in the data file.
func hint_ids() -> Array:
	return _hints.keys()

## The hint's text, or "" for an unknown id.
func text_for(hint_id: String) -> String:
	return String(_hints.get(hint_id, {}).get("text", ""))

func _show_next() -> void:
	if _queue.is_empty():
		return
	current_id = _queue.pop_front()
	hint_shown.emit(current_id, text_for(current_id))

func _load_hints(hints_path: String) -> void:
	if not FileAccess.file_exists(hints_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(hints_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var records: Variant = parsed.get("hints", [])
	if typeof(records) != TYPE_ARRAY:
		return
	for record: Variant in records:
		if typeof(record) == TYPE_DICTIONARY and record.has("id") and record.has("event"):
			_hints[String(record["id"])] = {
				"event": String(record["event"]),
				"text": String(record.get("text", "")),
			}
