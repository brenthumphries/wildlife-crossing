## Hexagonal-grid topology utility: axial [q, r] coordinates with cube-coordinate
## distance math (ADR 0002). Every tile has exactly six neighbours and no diagonal
## relationships exist. Coordinates are Vector2i(q, r). Stateless — all functions
## are static, so systems and tests use it without instantiation.
class_name HexGrid
extends RefCounted

## The six axial neighbour directions, in clockwise order.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

## The six neighbours of a cell.
static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRECTIONS:
		out.append(c + d)
	return out

## The neighbour of `c` in direction `dir_index` (0..5).
static func neighbor(c: Vector2i, dir_index: int) -> Vector2i:
	return c + DIRECTIONS[dir_index]

## Convert axial to cube coordinates (the three components sum to zero).
static func axial_to_cube(c: Vector2i) -> Vector3i:
	return Vector3i(c.x, -c.x - c.y, c.y)

## Hex distance (number of single-edge steps) between two cells.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var ac := axial_to_cube(a)
	var bc := axial_to_cube(b)
	return int((abs(ac.x - bc.x) + abs(ac.y - bc.y) + abs(ac.z - bc.z)) / 2.0)

## True when two cells share exactly one edge.
static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return distance(a, b) == 1
