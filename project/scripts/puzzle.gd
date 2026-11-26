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


## Fewest moves from `from` to `to` when a move turns a tile either way (three clockwise turns are one turn
## back), or -1 when no turn gets there.
static func fewest_turns(from: int, to: int) -> int:
	var k := turns_between(from, to)
	return -1 if k < 0 else mini(k, 4 - k)


func index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func cell_of(i: int) -> Vector2i:
	return Vector2i(i % width, floori(float(i) / width))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_lantern(i: int) -> bool:
	return i != index(source) and bit_count(solution[i]) == 1


## A board made by hand (the tests use it): `answer` is the solved board, `start` how its tiles are turned now.
func setup(w: int, h: int, sun: Vector2i, answer: Array, start: Array) -> void:
	width = w
	height = h
	source = sun
	solution = PackedInt32Array(answer)
	tiles = PackedInt32Array(start)
	locked = PackedByteArray()
	locked.resize(w * h)
	par = compute_par()


## Makes the board for `seed_value`. With `scramble` 0 every tile starts turned at random; a positive `scramble`
## turns only that many tiles a quarter turn, so the board takes exactly that many moves (the teaching levels).
func generate(w: int, h: int, seed_value: int, scramble: int = 0) -> void:
	width = w
	height = h
	source = Vector2i(floori(w / 2.0), floori(h / 2.0))
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
	if scramble <= 0:
		for i in count:
			tiles[i] = rotate_cw(solution[i], rng.randi_range(0, 3))
	else:
		_scramble_some(scramble, rng)
	# Never start solved: turn the first tile whose turns matter until the board is not.
	var guard := 0
	while is_solved() and guard < count:
		var i := (guard * 7 + 3) % count
		if rotate_cw(tiles[i]) != tiles[i]:
			tiles[i] = rotate_cw(tiles[i])
		guard += 1
	par = compute_par()


## The fewest moves from the board as it is now to the generator's answer. Another answer may need fewer.
func compute_par() -> int:
	var total := 0
	for i in width * height:
		total += fewest_turns(tiles[i], solution[i])
	return total


## Turns `amount` different tiles (only ones a quarter turn changes) one quarter turn, either way.
func _scramble_some(amount: int, rng: RandomNumberGenerator) -> void:
	var turnable: Array[int] = []
	for i in width * height:
		if rotate_cw(solution[i]) != solution[i]:
			turnable.append(i)
	for n in mini(amount, turnable.size()):
		var pick := rng.randi_range(n, turnable.size() - 1)
		var i := turnable[pick]
		turnable[pick] = turnable[n]
		turnable[n] = i
		tiles[i] = rotate_cw(solution[i], 1 if rng.randi_range(0, 1) == 0 else 3)


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


## How the light travels: for every tile, how many steps from the sun the light reaches it ("depth", -1 when
## it does not) and the side it comes in from ("entry", a direction 0-3, -1 for the sun and dark tiles).
## The board uses it to let light flow outward from the sun.
func light_paths() -> Dictionary:
	var count := width * height
	var depth := PackedInt32Array()
	depth.resize(count)
	depth.fill(-1)
	var entry := PackedInt32Array()
	entry.resize(count)
	entry.fill(-1)
	depth[index(source)] = 0
	var queue: Array[Vector2i] = [source]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for d in 4:
			if connected(cell, d):
				var next := cell + DIRS[d]
				var n := index(next)
				if depth[n] < 0:
					depth[n] = depth[index(cell)] + 1
					entry[n] = (d + 2) % 4
					queue.append(next)
	return {"depth": depth, "entry": entry}


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
