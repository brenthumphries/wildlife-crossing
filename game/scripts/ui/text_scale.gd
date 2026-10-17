## Named base text sizes and the live text-scale step every screen applies.
class_name TextScale
extends RefCounted

# Base sizes in px at step 1.0 (Q6, 2026-10-16; V15 tunes them on screen).
const BODY := 20
const TITLE := 36
const SMALL := 16

## Scale factors, smallest to largest.
const STEPS: Array[float] = [1.0, 1.25, 1.5, 1.75]
const MIN_SIZE := 1

static var _step: int = 0

## The current scale factor.
static func factor() -> float:
	return STEPS[_step]

## The current index into STEPS.
static func step() -> int:
	return _step

## The base size times the current factor, rounded to an int, never below 1.
static func size(base: int) -> int:
	return maxi(MIN_SIZE, roundi(base * factor()))

## Select a step (clamped to STEPS); true if the step changed.
static func set_step(index: int) -> bool:
	var clamped := clampi(index, 0, STEPS.size() - 1)
	if clamped == _step:
		return false
	_step = clamped
	var bus := _event_bus()
	if bus:
		bus.text_scale_changed.emit(factor())
	return true

## Move one step larger; true if the step changed.
static func step_up() -> bool:
	return set_step(_step + 1)

## Move one step smaller; true if the step changed.
static func step_down() -> bool:
	return set_step(_step - 1)

## The EventBus autoload if present, else null (so unit tests need no tree).
static func _event_bus() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("EventBus")
