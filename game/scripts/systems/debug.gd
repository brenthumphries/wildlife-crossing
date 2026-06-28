## Configurable logging singleton. Replaces print(); set verbosity via `level`.
extends Node

enum Level { VERBOSE, INFO, WARN, NONE }

@export var level: Level = Level.INFO

## Detailed tracing; emitted only at VERBOSE.
func verbose(msg: String) -> void:
	if level <= Level.VERBOSE:
		print("[V] ", msg)

## Normal informational logging.
func info(msg: String) -> void:
	if level <= Level.INFO:
		print("[I] ", msg)

## Warnings; routed to the Godot warning channel.
func warn(msg: String) -> void:
	if level <= Level.WARN:
		push_warning(msg)
