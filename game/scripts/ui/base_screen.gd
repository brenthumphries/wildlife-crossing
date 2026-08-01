## Base class for code-instantiated UI screens/overlays: standardises the
## full-rect anchoring and build-in-`_init()` pattern already used ad-hoc by
## `ConfirmPanel` and `ConnectivityOverlay` (`game/CLAUDE.md`: "UI scenes
## inherit from a BaseScreen scene where possible"). New UI extends this
## script directly -- there is no `BaseScreen.tscn`, because none of this
## project's UI is scene-authored; every screen is instanced with `.new()`,
## so a script base is the equivalent for this codebase. `ConfirmPanel` and
## `ConnectivityOverlay` are not retrofitted here; migrating them is
## separate, deliberately deferred work (flagged in the 2026-07-28 and
## 2026-07-30 build-review amendments as the "BaseScreen convention debt").
class_name BaseScreen
extends Control

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

## Override in subclasses to construct child nodes. Called once from
## `_init()`, before the node enters the tree. Subclasses own their own
## initial visibility (e.g. `hide()`) since that varies -- an always-on HUD
## and an on-demand panel don't share a default.
func _build_ui() -> void:
	pass
