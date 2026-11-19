## Legibility floor for the window: the smallest size at which 100% body text stays readable.
class_name WindowFloor
extends RefCounted

## Smallest physical body text, in screen px, the window may show at the 100%
## step. It is the old body size (before ATT-169 raised the baseline to 25), so
## the game never reads smaller than it did before the text change.
const MIN_PHYSICAL_BODY_PX := 20

## The floor for a content size and a base body size. Under `canvas_items` +
## `keep` the picture scales by window width / content width, so body text is
## `base_body * width / content.x` physical px; solving for the smallest width
## that keeps it at or above MIN_PHYSICAL_BODY_PX gives the width, and the height
## follows the content aspect. Rounded up so the rule holds exactly.
static func compute(content: Vector2i, base_body: int) -> Vector2i:
	var width: int = ceili(float(content.x) * MIN_PHYSICAL_BODY_PX / base_body)
	var height: int = ceili(float(content.y) * MIN_PHYSICAL_BODY_PX / base_body)
	return Vector2i(width, height)

## The floor for the project's configured content size and TextScale.BODY.
## Independent of the live text step: the rule is about the 100% body size.
static func current() -> Vector2i:
	var content := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width") as int,
		ProjectSettings.get_setting("display/window/size/viewport_height") as int)
	return compute(content, TextScale.BODY)

## Set `window.min_size` to the floor. Returns the floor applied.
static func apply(window: Window) -> Vector2i:
	var floor_size: Vector2i = current()
	window.min_size = floor_size
	return floor_size
