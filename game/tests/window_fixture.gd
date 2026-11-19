## Test helper: the project's configured content size, so fit tests follow project.godot.
class_name WindowFixture
extends RefCounted

## The content (viewport) size from the project settings.
static func content_size() -> Vector2i:
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	return Vector2i(width, height)
