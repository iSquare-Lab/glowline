class_name Board
extends Control
## Draws a Puzzle and turns its tiles. Tap or click turns a tile clockwise (Shift: the other way);
## a long press or a right click locks it. Keys: arrows move, Space or Enter turns, Q turns back, L locks.

signal turned(index: int, clockwise: bool)
signal lock_changed(index: int)
signal solved

const LONG_PRESS := 0.42
const TURN_SPEED := 14.0

const BG_TILE := Color("1a2232")
const BG_TILE_LOCKED := Color("232c3f")
const PIPE_DARK := Color("4b5873")
const PIPE_LIT := Color("ffc457")
const GLOW := Color(1.0, 0.72, 0.25, 0.18)
const LANTERN_OFF := Color("8a97b2")
const CURSOR := Color("9ec5ff")

var puzzle: Puzzle
var interactive := true
var _angles := PackedFloat32Array()
var _lit := PackedByteArray()
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


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func show_puzzle(p: Puzzle) -> void:
	puzzle = p
	_angles = PackedFloat32Array()
	_angles.resize(p.width * p.height)
	_cursor = p.source
	_win_time = -1.0
	interactive = true
	_refresh()
	_layout()


func celebrate() -> void:
	_win_time = _clock
	interactive = false


func _refresh() -> void:
	_lit = puzzle.lit()
	queue_redraw()


func _layout() -> void:
	if puzzle == null:
		return
	_cell = floor(min(size.x / puzzle.width, size.y / puzzle.height))
	_origin = ((size - Vector2(_cell * puzzle.width, _cell * puzzle.height)) / 2.0).floor()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	var moving := false
	for i in _angles.size():
		if _angles[i] != 0.0:
			_angles[i] = move_toward(_angles[i], 0.0, delta * TURN_SPEED)
			moving = true
	if _press_index >= 0 and not _press_consumed and _clock - _press_time >= LONG_PRESS:
		_press_consumed = true
		_toggle_lock(_press_index)
	if moving or _win_time >= 0.0 or _press_index >= 0:
		queue_redraw()


func _cell_at(point: Vector2) -> int:
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
	var pulse := 0.0
	if _win_time >= 0.0:
		pulse = 0.5 + 0.5 * sin((_clock - _win_time) * 4.0)
	var gap: float = max(2.0, _cell * 0.05)
	var radius: float = _cell * 0.16
	var pipe: float = max(3.0, _cell * 0.17)
	var reach := _cell / 2.0
	var count := puzzle.width * puzzle.height
	# Three passes, so a glow is never painted over by the next tile: tiles, then glows, then pipes and lights.
	for i in count:
		var top_left := _origin + Vector2(puzzle.cell_of(i)) * _cell
		var rect := Rect2(top_left + Vector2(gap, gap) / 2.0, Vector2(_cell - gap, _cell - gap))
		var bg := BG_TILE_LOCKED if puzzle.locked[i] else BG_TILE
		if _press_index == i and not _press_consumed:
			bg = bg.lightened(0.08)
		_draw_rounded_rect(rect, radius, bg)
	for i in count:
		if not _lit[i]:
			continue
		draw_set_transform(_origin + (Vector2(puzzle.cell_of(i)) + Vector2(0.5, 0.5)) * _cell, _angles[i], Vector2.ONE)
		for d in 4:
			if puzzle.tiles[i] & (1 << d):
				draw_rect(_arm(d, reach, pipe * 2.0), GLOW)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in count:
		var cell := puzzle.cell_of(i)
		var top_left := _origin + Vector2(cell) * _cell
		var center := top_left + Vector2(_cell, _cell) / 2.0
		var lit := _lit[i] != 0
		var color := PIPE_LIT if lit else PIPE_DARK
		if lit and pulse > 0.0:
			color = color.lightened(pulse * 0.35)
		draw_set_transform(center, _angles[i], Vector2.ONE)
		var mask := puzzle.tiles[i]
		for d in 4:
			if mask & (1 << d):
				draw_rect(_arm(d, reach, pipe), color)
		draw_circle(Vector2.ZERO, pipe / 2.0, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if cell == puzzle.source:
			_draw_sun(center, pulse)
		elif puzzle.is_lantern(i):
			_draw_lantern(center, lit, pulse)
		if puzzle.locked[i]:
			_draw_lock(top_left + Vector2(_cell - gap - _cell * 0.17, gap + _cell * 0.13))
	if _show_cursor and has_focus() and interactive:
		var top_left := _origin + Vector2(_cursor) * _cell
		draw_rect(Rect2(top_left + Vector2(1, 1), Vector2(_cell - 2, _cell - 2)), CURSOR, false, max(2.0, _cell * 0.05))


## The pipe arm from a tile's centre to the middle of side `d`, `thickness` wide, centred on its axis.
func _arm(d: int, reach: float, thickness: float) -> Rect2:
	var half := thickness / 2.0
	match d:
		0:
			return Rect2(-half, -reach, thickness, reach + half)
		1:
			return Rect2(-half, -half, reach + half, thickness)
		2:
			return Rect2(-half, -half, thickness, reach + half)
		_:
			return Rect2(-reach, -half, reach + half, thickness)


func _draw_sun(center: Vector2, pulse: float) -> void:
	var r := _cell * 0.24
	draw_circle(center, r * (1.7 + pulse * 0.3), Color(1.0, 0.78, 0.3, 0.12))
	draw_circle(center, r * 1.3, Color(1.0, 0.78, 0.3, 0.22))
	draw_circle(center, r, Color("ffd27a"))
	draw_circle(center, r * 0.55, Color("fff4d6"))


func _draw_lantern(center: Vector2, lit: bool, pulse: float) -> void:
	var r := _cell * 0.21
	if lit:
		draw_circle(center, r * (1.6 + pulse * 0.25), Color(1.0, 0.75, 0.3, 0.16))
		draw_circle(center, r, Color("ffcf6b"))
		draw_circle(center, r * 0.5, Color("fff7e3"))
	else:
		draw_circle(center, r, BG_TILE)
		draw_arc(center, r, 0.0, TAU, 32, LANTERN_OFF, max(2.0, _cell * 0.05), true)


func _draw_lock(at: Vector2) -> void:
	var s := _cell * 0.13
	var body := Rect2(at + Vector2(-s * 0.55, -s * 0.1), Vector2(s * 1.1, s * 0.85))
	draw_arc(at + Vector2(0, -s * 0.1), s * 0.36, PI, TAU, 12, Color("c9d4ea"), max(1.5, s * 0.18), true)
	draw_rect(body, Color("c9d4ea"))


func _draw_rounded_rect(rect: Rect2, r: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(r))
	box.anti_aliasing = true
	draw_style_box(box, rect)
