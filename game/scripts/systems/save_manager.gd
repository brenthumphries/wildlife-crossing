## Serialise and deserialise `GameState` to disk (architecture §7, ADR 0005):
## versioned JSON, written atomically (temp file, then rename) into the user data
## directory, and read back through a migration chain keyed on `save_version`.
##
## Stateless and path-parameterised on purpose — every entry point takes the
## target path, so the round-trip unit-tests against a throwaway file instead of
## the player's real slot, and nothing here reaches for an autoload.
class_name SaveManager
extends RefCounted

const SAVE_DIR := "user://saves"
const DEFAULT_SLOT := "slot_1"
## Suffix of the in-progress write. Deliberately not ".tmp": the launcher and
## some backup tools sweep ".tmp", and a swept temp file mid-save would leave
## `save()` renaming something that no longer exists.
const TEMP_SUFFIX := ".part"

## Highest `save_version` this build can read. A payload above it is refused
## rather than guessed at (ADR 0005: a format change bumps MAJOR and adds a
## migration step); a payload below it is migrated up to this.
const READABLE_VERSION := 1

## Path of a named save slot in the user data directory.
static func slot_path(slot: String = DEFAULT_SLOT) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]

static func has_save(path: String = slot_path()) -> bool:
	return FileAccess.file_exists(path)

## Write `state` (a §14 payload, normally `GameState.to_dict()`) atomically: the
## bytes go to a sibling temp file which is renamed over the target only once it
## is completely on disk, so an interrupted save can never truncate the previous
## one (ADR 0005). Returns "" on success, or a human-readable reason on failure
## — the caller decides how to surface it, since a failed save is a message to
## the player rather than a crash.
static func save(state: Dictionary, path: String = slot_path()) -> String:
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return "could not create the save directory %s (error %d)" % [dir, mk]
	var tmp := path + TEMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "could not open %s for writing (error %d)" % [tmp, FileAccess.get_open_error()]
	# Tab-indented rather than minified: ADR 0005 chose JSON specifically so a
	# save can be read and diffed during bug triage.
	f.store_string(JSON.stringify(state, "\t"))
	f.close()   # the rename must not race an open write handle
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return "could not move the completed save into place (error %d)" % err
	return ""

## Read a save and bring it up to `READABLE_VERSION`. Returns the migrated §14
## payload, or {} when the file is missing, unparseable, or written by a newer
## build. Nothing here touches GameState — `GameState.from_dict()` applies the
## result, so a bad file leaves the running game untouched.
static func load_save(path: String = slot_path()) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# A JSON instance rather than `JSON.parse_string`: the static helper raises an
	# engine-level error on malformed input, which is noise for a case that is
	# expected and handled. This reports the parse failure with the line number
	# instead, which is what makes a hand-edited save debuggable.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("Save file is not valid JSON (line %d: %s): %s"
			% [json.get_error_line(), json.get_error_message(), path])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Save file is not a JSON object: " + path)
		return {}
	return migrate(json.data as Dictionary)

## Walk a payload up the migration chain to `READABLE_VERSION`. Returns {} when
## `save_version` is absent, newer than this build, or has no step defined —
## refusing to load is always better than loading a shape the systems will
## misread.
static func migrate(data: Dictionary) -> Dictionary:
	if not data.has("save_version"):
		push_error("Save file has no save_version")
		return {}
	var version := int(data["save_version"])
	if version > READABLE_VERSION:
		push_error("Save file version %d was written by a newer build (this build reads %d)"
			% [version, READABLE_VERSION])
		return {}
	var steps := _migrations()
	var out := data.duplicate(true)
	while version < READABLE_VERSION:
		if not steps.has(version):
			push_error("No migration step from save_version %d" % version)
			return {}
		var step: Callable = steps[version]
		out = step.call(out)
		version += 1
		out["save_version"] = version
	return out

## The migration chain (ADR 0005): `save_version` -> a Callable upgrading a
## payload of that version to the next one. **Empty by design** — `save_version`
## starts at 1 and no format change has superseded it yet. Add an entry here in
## the same commit that bumps `GameState.SAVE_VERSION`, never after.
static func _migrations() -> Dictionary:
	return {}
