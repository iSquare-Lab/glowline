class_name Puzzle
extends RefCounted
## One Glowline board: a grid of tiles, each with pipe ends on some of its four sides.
## The generator lays a random tree of pipes over every cell from the sun in the middle, then turns each
## tile at random. The board is solved when every pipe end meets another one and light reaches every tile.

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var width := 0
var height := 0
var source := Vector2i.ZERO
var tiles := PackedInt32Array()
var solution := PackedInt32Array()
var locked := PackedByteArray()
var par := 0


static func rotate_cw(mask: int, times: int = 1) -> int:
	var m := mask
	for i in posmod(times, 4):
		m = ((m << 1) | (m >> 3)) & 15
	return m


static func bit_count(mask: int) -> int:
	var count := 0
	for i in 4:
		if mask & (1 << i):
			count += 1
	return count


## Fewest clockwise quarter turns from `from` to `to`, or -1 when no turn gets there.
static func turns_between(from: int, to: int) -> int:
	for k in 4:
		if rotate_cw(from, k) == to:
			return k
	return -1


func index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func cell_of(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_lantern(i: int) -> bool:
	return i != index(source) and bit_count(solution[i]) == 1


func generate(w: int, h: int, seed_value: int) -> void:
	width = w
	height = h
	source = Vector2i(w / 2, h / 2)
	var count := w * h
	solution = PackedInt32Array()
	solution.resize(count)
	locked = PackedByteArray()
	locked.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var visited := PackedByteArray()
	visited.resize(count)
	visited[index(source)] = 1
	# Randomized Prim: grow the tree one edge at a time. The first pass keeps tiles at three ends or fewer
	# (crosses are dull: every turn fits); the second pass reaches any cell the first one walled in.
	for max_degree in [3, 4]:
		var frontier: Array[Vector3i] = []
		for i in count:
			if visited[i]:
				_add_edges(cell_of(i), visited, frontier)
		while not frontier.is_empty():
			var pick := rng.randi_range(0, frontier.size() - 1)
			var edge: Vector3i = frontier[pick]
			frontier[pick] = frontier[frontier.size() - 1]
			frontier.pop_back()
			var from := Vector2i(edge.x, edge.y)
			var d := edge.z
			var to := from + DIRS[d]
			if visited[index(to)] or bit_count(solution[index(from)]) >= max_degree:
				continue
			solution[index(from)] |= 1 << d
			solution[index(to)] |= 1 << ((d + 2) % 4)
			visited[index(to)] = 1
			_add_edges(to, visited, frontier)
	tiles = solution.duplicate()
	for i in count:
		tiles[i] = rotate_cw(solution[i], rng.randi_range(0, 3))
	# Never start solved: turn the first tile whose turns matter until the board is not.
	var guard := 0
	while is_solved() and guard < count:
		var i := (guard * 7 + 3) % count
		if rotate_cw(tiles[i]) != tiles[i]:
			tiles[i] = rotate_cw(tiles[i])
		guard += 1
	par = 0
	for i in count:
		par += turns_between(tiles[i], solution[i])


func _add_edges(cell: Vector2i, visited: PackedByteArray, frontier: Array[Vector3i]) -> void:
	for d in 4:
		var next := cell + DIRS[d]
		if in_bounds(next) and not visited[index(next)]:
			frontier.append(Vector3i(cell.x, cell.y, d))


func turn(i: int, clockwise: bool = true) -> bool:
	if locked[i]:
		return false
	tiles[i] = rotate_cw(tiles[i], 1 if clockwise else 3)
	return true


func connected(cell: Vector2i, d: int) -> bool:
	var next := cell + DIRS[d]
	if not in_bounds(next):
		return false
	return (tiles[index(cell)] & (1 << d)) != 0 and (tiles[index(next)] & (1 << ((d + 2) % 4))) != 0


## 1 for every tile the light reaches from the sun, following pipe ends that meet.
func lit() -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(width * height)
	var queue: Array[Vector2i] = [source]
	result[index(source)] = 1
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for d in 4:
			if connected(cell, d):
				var next := cell + DIRS[d]
				if not result[index(next)]:
					result[index(next)] = 1
					queue.append(next)
	return result


func is_solved() -> bool:
	for i in width * height:
		var cell := cell_of(i)
		for d in 4:
			if (tiles[i] & (1 << d)) and not connected(cell, d):
				return false
	var reached := lit()
	for value in reached:
		if not value:
			return false
	return true


func lanterns_lit() -> Vector2i:
	var reached := lit()
	var total := 0
	var on := 0
	for i in width * height:
		if is_lantern(i):
			total += 1
			if reached[i]:
				on += 1
	return Vector2i(on, total)
