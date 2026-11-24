extends Control
## Glowline: screens (menu, levels, game, results, how to play), progress saved in user:// (IndexedDB on the web).

const LEVELS := 40
const LEVEL_BUTTON := 84
const SAVE_PATH := "user://glowline.cfg"
const DAILY_SIZE := Vector2i(8, 8)

const C_BG := Color("10141e")
const C_PANEL := Color("171e2c")
const C_BUTTON := Color("222b3d")
const C_BUTTON_HOVER := Color("2c3750")
const C_ACCENT := Color("ffc457")
const C_TEXT := Color("eef2fa")
const C_MUTED := Color("a9b4cb")

var save := ConfigFile.new()
var sfx: Sfx
var board: Board
var puzzle: Puzzle

var _menu: Control
var _levels: Control
var _level_grid: GridContainer
var _game: Control
var _overlay: Control
var _overlay_box: VBoxContainer
var _title: Label
var _stats: Label
var _hint: Label
var _menu_progress: Label
var _continue_button: Button
var _daily_button: Button
var _sound_button: Button
var _undo_button: Button

var _mode := "journey"
var _level := 1
var _daily_key := ""
var _moves := 0
var _seconds := 0.0
var _running := false
var _undo: Array[Vector2i] = []
var _lanterns_on := 0


func _ready() -> void:
	save.load(SAVE_PATH)
	theme = _make_theme()
	sfx = Sfx.new()
	add_child(sfx)
	sfx.enabled = save.get_value("settings", "sound", true)
	_build_menu()
	_build_levels()
	_build_game()
	_build_overlay()
	_show_menu()


func _process(delta: float) -> void:
	if _running:
		_seconds += delta
		_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overlay.visible and _overlay_box.has_meta("closable"):
			_close_overlay()
		elif _game.visible and not _overlay.visible:
			_show_menu()
		elif _levels.visible:
			_show_menu()
		get_viewport().set_input_as_handled()
	elif _game.visible and not _overlay.visible and event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if (key.keycode == KEY_Z and (key.ctrl_pressed or key.meta_pressed)) or key.keycode == KEY_U:
			_undo_turn()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_R and not key.ctrl_pressed:
			_restart()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ Theme

func _box(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	if border.a > 0.0:
		box.set_border_width_all(3)
		box.border_color = border
	box.anti_aliasing = true
	return box


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_TEXT)
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", Color(C_MUTED, 0.55))
	t.set_stylebox("normal", "Button", _box(C_BUTTON))
	t.set_stylebox("hover", "Button", _box(C_BUTTON_HOVER))
	t.set_stylebox("pressed", "Button", _box(C_BUTTON.darkened(0.2)))
	t.set_stylebox("disabled", "Button", _box(Color(C_BUTTON, 0.45)))
	t.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, 14, Color("9ec5ff")))
	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, 22))
	return t


func _accent(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", _box(C_ACCENT))
	button.add_theme_stylebox_override("hover", _box(C_ACCENT.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _box(C_ACCENT.darkened(0.12)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("1b1405"))
	return button


func _label(text: String, size: int = 24, color: Color = C_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	return button


# ------------------------------------------------------------------ Menu

func _build_menu() -> void:
	_menu = CenterContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	column.custom_minimum_size = Vector2(360, 0)
	_menu.add_child(column)
	var logo := _MenuLogo.new()
	logo.custom_minimum_size = Vector2(0, 104)
	column.add_child(logo)
	var title := _label("Glowline", 50, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var tagline := _label("Turn the tiles. Light every lantern.", 20, C_MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	column.add_child(_spacer(8))
	_continue_button = _accent(_button("Play", _continue_journey))
	column.add_child(_continue_button)
	column.add_child(_button("Levels", _show_levels))
	_daily_button = _button("Daily puzzle", _start_daily)
	column.add_child(_daily_button)
	column.add_child(_button("How to play", _show_help))
	_sound_button = _button("", _toggle_sound)
	column.add_child(_sound_button)
	_menu_progress = _label("", 16, C_MUTED)
	_menu_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_spacer(6))
	column.add_child(_menu_progress)


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _show_menu() -> void:
	_running = false
	_hide_all()
	_menu.visible = true
	var solved := _solved_count()
	var stars := _star_total()
	_continue_button.text = "Play" if solved == 0 else ("Continue · level %d" % _next_level() if solved < LEVELS else "Play again")
	_menu_progress.text = "%d of %d levels · %d stars" % [solved, LEVELS, stars]
	var today := _today()
	var best: int = save.get_value("daily", today, 0)
	_daily_button.text = "Daily puzzle · solved in %d" % best if best > 0 else "Daily puzzle · %s" % today
	_sound_button.text = "Sound: on" if sfx.enabled else "Sound: off"
	_continue_button.grab_focus.call_deferred()


func _hide_all() -> void:
	_menu.visible = false
	_levels.visible = false
	_game.visible = false
	_overlay.visible = false


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	save.set_value("settings", "sound", sfx.enabled)
	save.save(SAVE_PATH)
	_sound_button.text = "Sound: on" if sfx.enabled else "Sound: off"


# ------------------------------------------------------------------ Levels

func _build_levels() -> void:
	_levels = MarginContainer.new()
	_levels.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_levels.add_theme_constant_override("margin_" + side, 22)
	add_child(_levels)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_levels.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.add_child(_button("‹ Menu", _show_menu))
	header.add_child(_label("Levels", 28))
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_level_grid = GridContainer.new()
	_level_grid.columns = 5
	_level_grid.add_theme_constant_override("h_separation", 12)
	_level_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(_level_grid)
	for level in range(1, LEVELS + 1):
		var button := _button("", _start_level.bind(level))
		button.custom_minimum_size = Vector2(LEVEL_BUTTON, LEVEL_BUTTON - 8)
		button.add_theme_font_size_override("font_size", 22)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 4)
		var number := _label(str(level), 20)
		number.name = "Number"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var detail := _label("", 14, C_MUTED)
		detail.name = "Detail"
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stars := Stars.new(0, 14.0)
		stars.name = "Stars"
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(number)
		content.add_child(detail)
		content.add_child(stars)
		button.add_child(content)
		_level_grid.add_child(button)


func _show_levels() -> void:
	_hide_all()
	_levels.visible = true
	var next := _next_level()
	for level in range(1, LEVELS + 1):
		var button: Button = _level_grid.get_child(level - 1)
		var stars: int = save.get_value("stars", str(level), 0)
		var size := _level_size(level)
		var content := button.get_child(0)
		var row: Stars = content.get_node("Stars")
		row.filled = stars
		row.visible = stars > 0
		var detail: Label = content.get_node("Detail")
		detail.text = "%d×%d" % [size.x, size.y]
		detail.visible = stars == 0
		button.disabled = level > next
		button.modulate = Color(1, 1, 1, 0.45) if button.disabled else Color.WHITE
		button.tooltip_text = "Level %d, %d×%d, %d of 3 stars" % [level, size.x, size.y, stars]
	var focus_index: int = clampi(next, 1, LEVELS) - 1
	(_level_grid.get_child(focus_index) as Button).grab_focus.call_deferred()
	_level_grid.columns = clampi(int((get_viewport_rect().size.x - 44) / (LEVEL_BUTTON + 10)), 3, 8)



# ------------------------------------------------------------------ Game

func _build_game() -> void:
	_game = MarginContainer.new()
	_game.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		_game.add_theme_constant_override("margin_" + side, 14)
	_game.add_theme_constant_override("margin_top", 16)
	_game.add_theme_constant_override("margin_bottom", 16)
	add_child(_game)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_game.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.add_child(_button("‹ Menu", _show_menu))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	_title = _label("", 22)
	_stats = _label("", 15, C_MUTED)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_title)
	words.add_child(_stats)
	top.add_child(words)
	column.add_child(top)

	board = Board.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.turned.connect(_on_turned)
	board.lock_changed.connect(func(_i: int) -> void: sfx.play("lock"))
	board.solved.connect(_on_solved)
	column.add_child(board)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_undo_button = _button("Undo", _undo_turn)
	bottom.add_child(_undo_button)
	bottom.add_child(_button("Restart", _restart))
	_hint = _label("Tap a tile to turn it · hold to lock it", 14, C_MUTED)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_hint)
	column.add_child(bottom)


func _level_size(level: int) -> Vector2i:
	var side := 4
	if level > 3:
		side = 5
	if level > 8:
		side = 6
	if level > 15:
		side = 7
	if level > 24:
		side = 8
	if level > 32:
		side = 9
	return Vector2i(side, side)


func _start_level(level: int) -> void:
	_mode = "journey"
	_level = level
	var size := _level_size(level)
	puzzle = Puzzle.new()
	puzzle.generate(size.x, size.y, 7919 * level + 17)
	_title.text = "Level %d" % level
	_begin()


func _continue_journey() -> void:
	_start_level(clampi(_next_level(), 1, LEVELS))


func _start_daily() -> void:
	_mode = "daily"
	_daily_key = _today()
	puzzle = Puzzle.new()
	puzzle.generate(DAILY_SIZE.x, DAILY_SIZE.y, absi(("glowline-" + _daily_key).hash()))
	_title.text = "Daily · %s" % _daily_key
	_begin()


func _begin() -> void:
	_hide_all()
	_game.visible = true
	_moves = 0
	_seconds = 0.0
	_undo.clear()
	_running = true
	board.show_puzzle(puzzle)
	_lanterns_on = puzzle.lanterns_lit().x
	_update_stats()
	board.grab_focus.call_deferred()
	_hint.text = "Tap a tile to turn it · hold to lock it" if DisplayServer.is_touchscreen_available() else "Click: turn · right-click: lock · keys: arrows, Space"


func _restart() -> void:
	if _mode == "daily":
		_start_daily()
	else:
		_start_level(_level)


func _on_turned(i: int, clockwise: bool) -> void:
	_moves += 1
	_undo.append(Vector2i(i, 1 if clockwise else 0))
	sfx.play("turn")
	var on := puzzle.lanterns_lit().x
	if on > _lanterns_on:
		sfx.play("lantern")
	_lanterns_on = on
	_update_stats()


func _undo_turn() -> void:
	if _undo.is_empty() or not _running:
		return
	var last: Vector2i = _undo.pop_back()
	board.turn_silently(last.x, last.y == 0)
	_moves = maxi(0, _moves - 1)
	_lanterns_on = puzzle.lanterns_lit().x
	sfx.play("turn")
	_update_stats()


func _update_stats() -> void:
	if puzzle == null:
		return
	var lanterns := puzzle.lanterns_lit()
	_stats.text = "%d / %d lanterns · %d moves (par %d) · %s" % [lanterns.x, lanterns.y, _moves, puzzle.par, _clock(_seconds)]
	_undo_button.disabled = _undo.is_empty()


func _clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


func _stars_for(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= ceili(par * 1.5):
		return 2
	return 1


func _on_solved() -> void:
	_running = false
	board.celebrate()
	sfx.play("solved")
	var stars := _stars_for(_moves, puzzle.par)
	var heading := "All lanterns lit!"
	var lines: Array[String] = []
	lines.append("%d moves · par %d · %s" % [_moves, puzzle.par, _clock(_seconds)])
	if _mode == "journey":
		var key := str(_level)
		var best: int = save.get_value("stars", key, 0)
		if stars > best:
			save.set_value("stars", key, stars)
		save.save(SAVE_PATH)
		var buttons: Array = []
		if _level < LEVELS:
			buttons.append(["Next level", func() -> void: _start_level(_level + 1), true])
		buttons.append(["Play again", _restart, false])
		buttons.append(["Menu", _show_menu, false])
		await get_tree().create_timer(0.7).timeout
		_open_overlay(heading, stars, lines, buttons, false)
	else:
		var best: int = save.get_value("daily", _daily_key, 0)
		if best == 0 or _moves < best:
			save.set_value("daily", _daily_key, _moves)
		save.save(SAVE_PATH)
		lines.append("A new daily puzzle starts at midnight.")
		await get_tree().create_timer(0.7).timeout
		_open_overlay(heading, stars, lines, [["Menu", _show_menu, true], ["Play again", _restart, false]], false)


# ------------------------------------------------------------------ Overlay (results, how to play)

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	_overlay_box = VBoxContainer.new()
	_overlay_box.add_theme_constant_override("separation", 14)
	margin.add_child(_overlay_box)


func _open_overlay(heading: String, star_count: int, lines: Array[String], buttons: Array, closable: bool) -> void:
	for child in _overlay_box.get_children():
		child.queue_free()
	if closable:
		_overlay_box.set_meta("closable", true)
	elif _overlay_box.has_meta("closable"):
		_overlay_box.remove_meta("closable")
	var title := _label(heading, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(title)
	if star_count >= 0:
		var stars := Stars.new(star_count, 44.0)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_overlay_box.add_child(stars)
	for line in lines:
		var label := _label(line, 17, C_MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(330, 0)
		_overlay_box.add_child(label)
	_overlay_box.add_child(_spacer(4))
	var first: Button = null
	for entry in buttons:
		var button := _button(entry[0], entry[1])
		if entry[2]:
			_accent(button)
		_overlay_box.add_child(button)
		if first == null:
			first = button
	_overlay.visible = true
	if first:
		first.grab_focus.call_deferred()


func _close_overlay() -> void:
	_overlay.visible = false
	if _menu.visible:
		_continue_button.grab_focus.call_deferred()


func _show_help() -> void:
	var lines: Array[String] = [
		"Light flows from the sun in the middle along the pipes. Turn the tiles so every lantern glows and no pipe ends in the dark.",
		"Tap or click a tile to turn it. Hold it, or right-click, to lock a tile you are sure of.",
		"Keyboard: arrows move, Space turns, Q turns back, L locks, U undoes, R restarts, Esc leaves.",
		"Finish within par for three stars. Each day brings a new 8×8 daily puzzle.",
	]
	_open_overlay("How to play", -1, lines, [["Got it", _close_overlay, true]], true)


# ------------------------------------------------------------------ Progress

func _solved_count() -> int:
	var count := 0
	for level in range(1, LEVELS + 1):
		if int(save.get_value("stars", str(level), 0)) > 0:
			count += 1
	return count


func _star_total() -> int:
	var total := 0
	for level in range(1, LEVELS + 1):
		total += int(save.get_value("stars", str(level), 0))
	return total


func _next_level() -> int:
	for level in range(1, LEVELS + 1):
		if int(save.get_value("stars", str(level), 0)) == 0:
			return level
	return LEVELS + 1


func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## The sun and three lanterns on the menu, drawn like the board.
class _MenuLogo extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, 6)
		var glow := 0.5 + 0.5 * sin(_t * 2.0)
		var pipe := 12.0
		var ends := [Vector2(-90, 8), Vector2(90, 8), Vector2(0, -36)]
		for e in ends:
			draw_line(c, c + e, Color(1.0, 0.72, 0.25, 0.22), pipe * 2.4)
			draw_line(c, c + e, Color("ffc457"), pipe)
		for e in ends:
			draw_circle(c + e, 24.0 + glow * 6.0, Color(1.0, 0.75, 0.3, 0.16))
			draw_circle(c + e, 18.0, Color("ffcf6b"))
			draw_circle(c + e, 9.0, Color("fff7e3"))
		draw_circle(c, 44.0 + glow * 8.0, Color(1.0, 0.78, 0.3, 0.12))
		draw_circle(c, 32.0, Color("ffd27a"))
		draw_circle(c, 17.0, Color("fff4d6"))
