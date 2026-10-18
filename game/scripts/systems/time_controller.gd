## Owns the simulation speed multiplier: paused, 1x, 2x or 4x (architecture §4).
class_name TimeController
extends RefCounted

signal time_speed_changed(multiplier: float)

const PAUSED := 0.0
const SPEED_1X := 1.0
const SPEED_2X := 2.0
const SPEED_4X := 4.0
## The only multipliers `set_speed` accepts, slowest first.
const STEPS: Array[float] = [PAUSED, SPEED_1X, SPEED_2X, SPEED_4X]

var multiplier: float = SPEED_1X

## Whether the simulation is halted. UI, build and information actions do not
## run on the sim tick, so they are unaffected.
func is_paused() -> bool:
	return multiplier == PAUSED

## Move to `value`. Refused, leaving the speed alone, for anything that is not
## one of `STEPS`. Returns whether the speed changed; setting the current speed
## is not a change and announces nothing.
func set_speed(value: float) -> bool:
	if not _is_step(value) or is_equal_approx(value, multiplier):
		return false
	multiplier = value
	time_speed_changed.emit(multiplier)
	return true

func _is_step(value: float) -> bool:
	for step: float in STEPS:
		if is_equal_approx(value, step):
			return true
	return false
