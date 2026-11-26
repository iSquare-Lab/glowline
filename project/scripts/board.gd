class_name Board
extends Control
## Draws a Puzzle as a garden at dusk and turns its tiles. Tap or click turns a tile clockwise (Shift: the
## other way); a long press or a right click locks it. Keys: arrows or WASD move, Space, Enter or E turns
## (Shift: the other way), Q turns back, L locks.
## Light flows out from the sun along the vines, one tile after another; a solved board sends a ripple of
## light out from the sun and lets fireflies out. With reduced motion, light shows at once and nothing sways.

signal turned(index: int, clockwise: bool)
signal lock_changed(index: int)
signal solved

const LONG_PRESS := 0.42
const TURN_SPEED := 14.0
## Seconds between one ring of tiles lighting up and the next, and for light to cross one tile.
const FLOW_STEP := 0.06
const FLOW_FILL := 0.12
## Seconds for the win ripple to move one tile further from the sun.
const RIPPLE_STEP := 0.04
## Seconds the ripple takes to pass over one tile (half of it on each side of its peak).
const RIPPLE_WIDTH := 0.36

## Flagstones in three shades of moss, so the board does not look like a grid of identical cells.
const STONES: Array[Color] = [Color("3a4535"), Color("404b3a"), Color("36412f")]
const STONE_LOCKED := Color("5a644f")
const STONE_SHADOW := Color(0.08, 0.05, 0.09, 0.55)

var puzzle: Puzzle
var interactive := true
var _angles := PackedFloat32Array()
## When each tile began to light up (in _clock time), or -1 while it is dark.
var _light_start := PackedFloat32Array()
var _depth := PackedInt32Array()
var _entry := PackedInt32Array()
var _cell := 48.0
var _origin := Vector2.ZERO
var _press_index := -1
var _press_time := 0.0
var _press_pos := Vector2.ZERO
var _press_consumed := false
var _cursor := Vector2i.ZERO
var _show_cursor := false
var _win_time := -1.0
var _clock := 0.0
## One rounded tile style per colour, made again when the tile size changes.
var _tile_boxes := {}
var _fireflies: Fireflies


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_fireflies = Fireflies.new(12, 3)
	add_child(_fireflies)


func show_puzzle(p: Puzzle) -> void:
	puzzle = p
	var count := p.width * p.height
	_angles = PackedFloat32Array()
	_angles.resize(count)
	_light_start = PackedFloat32Array()
	_light_start.resize(count)
	_light_start.fill(-1.0)
	_cursor = p.source
	_win_time = -1.0
	interactive = true
	if _fireflies:
		_fireflies.set_active(false)
	_refresh()
	_layout()


func celebrate() -> void:
	_win_time = _clock
	interactive = false
	_fireflies.set_active(true)


## How far the light has crossed tile `i`: 0 dark, 1 fully lit.
func light_of(i: int) -> float:
	if _light_start[i] < 0.0:
		return 0.0
	return clampf((_clock - _light_start[i]) / FLOW_FILL, 0.0, 1.0)


## True while light is still flowing somewhere on the board.
func is_flowing() -> bool:
	for i in _light_start.size():
		if _light_start[i] >= 0.0 and _clock - _light_start[i] < FLOW_FILL:
			return true
	return false


## Light newly reached tiles one ring after another, starting at the nearest of them; tiles that lost the
## light go dark at once.
func _refresh() -> void:
	var paths := puzzle.light_paths()
	_depth = paths.depth
	_entry = paths.entry
	var first := -1
	for i in _depth.size():
		if _depth[i] >= 0 and _light_start[i] < 0.0:
			first = _depth[i] if first < 0 else mini(first, _depth[i])
	var instant := Ui.reduced_motion()
	for i in _depth.size():
		if _depth[i] < 0:
			_light_start[i] = -1.0
		elif _light_start[i] < 0.0:
			_light_start[i] = _clock - FLOW_FILL if instant else _clock + (_depth[i] - first) * FLOW_STEP
	queue_redraw()


func _layout() -> void:
	if puzzle == null:
		return
	_cell = floorf(minf(size.x / puzzle.width, size.y / puzzle.height))
	_tile_boxes.clear()
	_origin = ((size - Vector2(_cell * puzzle.width, _cell * puzzle.height)) / 2.0).floor()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	for i in _angles.size():
		if _angles[i] != 0.0:
			_angles[i] = move_toward(_angles[i], 0.0, delta * TURN_SPEED)
	if _press_index >= 0 and not _press_consumed and _clock - _press_time >= LONG_PRESS:
		_press_consumed = true
		_toggle_lock(_press_index)
	# Lanterns sway and the sun turns slowly, so the board is redrawn every frame while it shows.
	if puzzle != null and is_visible_in_tree():
		queue_redraw()


func _cell_at(point: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var local := (point - _origin) / _cell
	var cell := Vector2i(floor(local.x), floor(local.y))
	return puzzle.index(cell) if puzzle.in_bounds(cell) else -1


func _gui_input(event: InputEvent) -> void:
	if puzzle == null or not interactive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var i := _cell_at(mb.position)
			if i >= 0:
				_toggle_lock(i)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_index = _cell_at(mb.position)
				_press_time = _clock
				_press_pos = mb.position
				_press_consumed = false
				_show_cursor = false
				grab_focus()
			else:
				var i := _press_index
				_press_index = -1
				if i >= 0 and not _press_consumed and i == _cell_at(mb.position):
					_turn(i, not mb.shift_pressed)
			accept_event()
	elif event is InputEventMouseMotion and _press_index >= 0:
		if (event as InputEventMouseMotion).position.distance_to(_press_pos) > _cell * 0.4:
			_press_index = -1
	elif event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		var move := Vector2i.ZERO
		match key.keycode:
			KEY_UP, KEY_W:
				move = Vector2i(0, -1)
			KEY_DOWN, KEY_S:
				move = Vector2i(0, 1)
			KEY_LEFT, KEY_A:
				move = Vector2i(-1, 0)
			KEY_RIGHT, KEY_D:
				move = Vector2i(1, 0)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E:
				_show_cursor = true
				_turn(puzzle.index(_cursor), not key.shift_pressed)
				accept_event()
				return
			KEY_Q:
				_show_cursor = true
				_turn(puzzle.index(_cursor), false)
				accept_event()
				return
			KEY_L:
				_show_cursor = true
				_toggle_lock(puzzle.index(_cursor))
				accept_event()
				return
			_:
				return
		_show_cursor = true
		_cursor = Vector2i(clampi(_cursor.x + move.x, 0, puzzle.width - 1), clampi(_cursor.y + move.y, 0, puzzle.height - 1))
		queue_redraw()
		accept_event()


func _turn(i: int, clockwise: bool) -> void:
	if not puzzle.turn(i, clockwise):
		return
	_angles[i] = -PI / 2.0 if clockwise else PI / 2.0
	_refresh()
	turned.emit(i, clockwise)
	if puzzle.is_solved():
		solved.emit()


## Undo support: turns a tile back even when it is locked, without emitting `turned`.
func turn_silently(i: int, clockwise: bool) -> void:
	puzzle.tiles[i] = Puzzle.rotate_cw(puzzle.tiles[i], 1 if clockwise else 3)
	_angles[i] = -PI / 2.0 if clockwise else PI / 2.0
	_refresh()


func _toggle_lock(i: int) -> void:
	puzzle.locked[i] = 0 if puzzle.locked[i] else 1
	lock_changed.emit(i)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_FOCUS_ENTER:
		queue_redraw()


func _draw() -> void:
	if puzzle == null:
		return
	var calm := Ui.reduced_motion()
	var since_win := _clock - _win_time if _win_time >= 0.0 else -1.0
	var pulse := 0.0
	if since_win >= 0.0 and not calm:
		pulse = 0.5 + 0.5 * sin(since_win * 3.0)
	var gap := maxf(2.0, _cell * 0.06)
	var vine := maxf(3.0, _cell * 0.14)
	var reach := _cell / 2.0
	var count := puzzle.width * puzzle.height
	# Passes, so nothing is painted over by the next tile: stones, glows, vines and leaves, then lights.
	for i in count:
		var top_left := _origin + Vector2(puzzle.cell_of(i)) * _cell
		var rect := Rect2(top_left + Vector2(gap, gap) / 2.0, Vector2(_cell - gap, _cell - gap))
		var stone := STONE_LOCKED if puzzle.locked[i] else STONES[(i + puzzle.cell_of(i).y) % STONES.size()]
		if _press_index == i and not _press_consumed:
			stone = stone.lightened(0.1)
		_draw_rounded_rect(Rect2(rect.position + Vector2(0, gap * 0.7), rect.size), STONE_SHADOW)
		_draw_rounded_rect(rect, stone)
	# A soft round halo on every lit tile (wide glow lines looked like boxes on big tiles).
	for i in count:
		var lit := light_of(i)
		if lit > 0.0:
			draw_circle(_center(i), _cell * 0.46, Color(GardenPainter.GLOW, 0.05 * lit))
			draw_circle(_center(i), _cell * 0.32, Color(GardenPainter.GLOW, 0.06 * lit))
	for i in count:
		_draw_vines(i, reach, vine, _ripple_at(i, since_win, calm) + pulse * 0.25)
	for i in count:
		var center := _center(i)
		var lit := light_of(i)
		if puzzle.cell_of(i) == puzzle.source:
			GardenPainter.sun(self, center, _cell * 0.22, 0.0 if calm else _clock * 0.25, pulse)
		elif puzzle.is_lantern(i):
			var swing := 0.0 if calm else sin(_clock * 1.7 + i * 1.3) * 0.07 * lit
			GardenPainter.lantern(self, center, _cell * 0.19, lit, swing, _ripple_at(i, since_win, calm))
		if puzzle.locked[i]:
			var top_left := _origin + Vector2(puzzle.cell_of(i)) * _cell
			LockIcon.draw_lock(self, top_left + Vector2(_cell - gap - _cell * 0.16, gap + _cell * 0.14), _cell * 0.12, LockIcon.COLOR)
	if _show_cursor and has_focus() and interactive:
		var top_left := _origin + Vector2(_cursor) * _cell
		draw_rect(Rect2(top_left + Vector2(1, 1), Vector2(_cell - 2, _cell - 2)), Ui.FOCUS, false, maxf(2.0, _cell * 0.05))


## How bright the win ripple makes tile `i` now (0-1), `since_win` seconds after the board was solved:
## it peaks when the ripple, moving out from the sun, reaches the tile. 0 before a win or with reduced motion.
func _ripple_at(i: int, since_win: float, calm: bool) -> float:
	if since_win < 0.0 or calm:
		return 0.0
	return clampf(1.0 - absf(since_win - _depth[i] * RIPPLE_STEP) / (RIPPLE_WIDTH / 2.0), 0.0, 1.0)


func _center(i: int) -> Vector2:
	return _origin + (Vector2(puzzle.cell_of(i)) + Vector2(0.5, 0.5)) * _cell


## The vines of tile `i`, dark, then the part the light has reached on top: on the side the light comes in
## from it runs from the edge to the middle, then out along the other vines. `flash` brightens lit vines.
func _draw_vines(i: int, reach: float, width: float, flash: float) -> void:
	var mask := puzzle.tiles[i]
	var lit := light_of(i)
	var is_sun := puzzle.cell_of(i) == puzzle.source
	draw_set_transform(_center(i), _angles[i], Vector2.ONE)
	for d in 4:
		if mask & (1 << d):
			GardenPainter.vine(self, Vector2.ZERO, Vector2(Puzzle.DIRS[d]) * reach, width, GardenPainter.VINE_DARK, true, false)
	var color := GardenPainter.VINE_LIT.lerp(GardenPainter.VINE_FLASH, clampf(flash, 0.0, 1.0) * 0.6)
	if lit > 0.0:
		for d in 4:
			if (mask & (1 << d)) == 0:
				continue
			var out := Vector2(Puzzle.DIRS[d]) * reach
			if is_sun:
				GardenPainter.vine(self, Vector2.ZERO, out * lit, width, color, false, lit < 1.0)
			elif d == _entry[i]:
				GardenPainter.vine(self, out * (1.0 - minf(1.0, lit * 2.0)), out, width, color, false, false)
			elif lit > 0.5:
				GardenPainter.vine(self, Vector2.ZERO, out * (lit * 2.0 - 1.0), width, color, false, lit < 1.0)
	# One leaf on each vine, on alternating sides, greening as the light passes.
	for d in 4:
		if mask & (1 << d):
			var dir := Vector2(Puzzle.DIRS[d])
			var side := PI / 2.6 if (i + d) % 2 == 0 else -PI / 2.6
			var leaf_color := GardenPainter.LEAF_DARK.lerp(GardenPainter.LEAF_LIT, lit)
			GardenPainter.leaf(self, dir * reach * 0.58, dir.angle() + side, width * 1.6, leaf_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rounded_rect(rect: Rect2, color: Color) -> void:
	var box: StyleBoxFlat = _tile_boxes.get(color)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(_cell * 0.2))
		box.anti_aliasing = true
		_tile_boxes[color] = box
	draw_style_box(box, rect)
