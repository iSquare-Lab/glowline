extends Control
## Glowline's screens and how a game flows: the menu, the level list, the game screen and its dialogs.
## The levels live in Levels, saved progress in Progress, the shared look in Ui.

## The browser tab title. Godot sets the window title to the project name after the main scene is ready, so
## set it again one step later (the page shell sets it too, once the engine has started).
const TITLE := "Glowline · a light puzzle"
## How long the lit board shows (the ripple from the sun and the fireflies) before the results open over it.
const RESULT_DELAY := 0.9
const TOUCH_HINT := "Tap a tile to turn it · hold it to lock it"
const MOUSE_HINT := "Click a tile to turn it · right-click to lock it · keys: arrows, Space, L"

## Where progress is saved. The tests set it to "" (memory only) before the node enters the tree.
var progress_path := Progress.PATH
var progress: Progress
var sfx: Sfx
var board: Board
var puzzle: Puzzle
## The last line given to screen readers (through the page's live region on the web).
var announcement := ""

var _menu: Control
var _menu_fireflies: Fireflies
var _levels: LevelSelect
var _game: Control
var _dialog: Dialog
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
## Goes up whenever the screen or the board changes, so results that wait for the lit board to show
## never open over the menu or a new board.
var _screen_id := 0


func _ready() -> void:
	DisplayServer.window_set_title.call_deferred(TITLE)
	progress = Progress.new(progress_path)
	theme = Ui.make_theme()
	sfx = Sfx.new()
	add_child(sfx)
	sfx.enabled = progress.sound
	add_child(Backdrop.new())
	_menu_fireflies = Fireflies.new()
	add_child(_menu_fireflies)
	_build_menu()
	_levels = LevelSelect.new()
	_levels.chosen.connect(_start_level)
	_levels.back.connect(_show_menu)
	add_child(_levels)
	_build_game()
	_dialog = Dialog.new()
	add_child(_dialog)
	_dialog.visibility_changed.connect(_on_dialog_visibility_changed)
	_show_menu()
	if not progress.seen_help:
		progress.seen_help = true
		_show_help()


func _process(delta: float) -> void:
	if _running:
		_seconds += delta
		_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _dialog.visible:
			if _dialog.closable:
				_close_dialog()
		elif _game.visible or _levels.visible:
			_show_menu()
		get_viewport().set_input_as_handled()
	elif _game.visible and not _dialog.visible and event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if (key.keycode == KEY_Z and (key.ctrl_pressed or key.meta_pressed)) or key.keycode == KEY_U:
			_undo_turn()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_R and not key.ctrl_pressed and not key.meta_pressed:
			_restart()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ Menu

func _build_menu() -> void:
	_menu = CenterContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	column.custom_minimum_size = Vector2(360, 0)
	_menu.add_child(column)
	var logo := MenuLogo.new()
	logo.custom_minimum_size = Vector2(0, 104)
	column.add_child(logo)
	var title := Ui.label("Glowline", 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var tagline := Ui.label("Turn the vines. Light the garden lanterns.", 20, Ui.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	column.add_child(Ui.spacer(8))
	_continue_button = Ui.accent(Ui.button("Play", _continue_journey))
	column.add_child(_continue_button)
	column.add_child(Ui.button("Levels", _show_levels))
	_daily_button = Ui.button("Daily puzzle", _start_daily)
	column.add_child(_daily_button)
	column.add_child(Ui.button("How to play", _show_help))
	_sound_button = Ui.button("", _toggle_sound)
	column.add_child(_sound_button)
	_menu_progress = Ui.label("", 16, Ui.MUTED)
	_menu_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(Ui.spacer(6))
	column.add_child(_menu_progress)


func _show_menu() -> void:
	_show(_menu)
	var solved := progress.solved_count()
	var level := _continue_level()
	if _saved_level() > 0 or (solved > 0 and solved < Levels.COUNT):
		_continue_button.text = "Continue · level %d" % level
	elif solved == 0:
		_continue_button.text = "Play"
	else:
		_continue_button.text = "Play again · level %d" % level
	_menu_progress.text = "%d of %d levels · %s" % [solved, Levels.COUNT, Ui.count_of(progress.star_total(), "star")]
	var today := Levels.today()
	var best := progress.daily_best(today)
	if best > 0:
		_daily_button.text = "Daily puzzle · solved in %s" % Ui.count_of(best, "move")
	else:
		_daily_button.text = "Daily puzzle · %s" % today
	_sound_button.text = "Sound: on" if sfx.enabled else "Sound: off"
	Ui.focus_later(_continue_button)


## Shows one screen and hides the rest. A board in play is saved first, so Continue picks it up again.
func _show(screen: Control) -> void:
	if _running:
		_save_board()
	_running = false
	_screen_id += 1
	for each in [_menu, _levels, _game, _dialog]:
		each.visible = each == screen
	_menu_fireflies.set_active(screen == _menu)


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	progress.sound = sfx.enabled
	_sound_button.text = "Sound: on" if sfx.enabled else "Sound: off"


func _show_levels() -> void:
	_show(_levels)
	_levels.refresh(progress)


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
	column.add_theme_constant_override("separation", 12)
	_game.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.add_child(Ui.button("‹ Menu", _show_menu))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	_title = Ui.label("", 22)
	_stats = Ui.label("", 15, Ui.MUTED)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_title)
	words.add_child(_stats)
	top.add_child(words)
	column.add_child(top)

	board = Board.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.turned.connect(_on_turned)
	board.lock_changed.connect(_on_lock_changed)
	board.solved.connect(_on_solved)
	column.add_child(board)

	# The hint has its own row above the buttons, so it never runs off the right edge, and the buttons
	# stay on the left: the host page's round button sits in the bottom-right corner.
	_hint = Ui.label("", 16, Ui.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_undo_button = Ui.button("Undo", _undo_turn)
	bottom.add_child(_undo_button)
	bottom.add_child(Ui.button("Restart", _restart))
	column.add_child(bottom)


func _start_level(level: int, resume: bool = true) -> void:
	_mode = "journey"
	_level = level
	puzzle = Levels.make(level)
	_title.text = "Level %d" % level
	_begin(resume)


func _continue_journey() -> void:
	_start_level(_continue_level())


## The level Continue opens: the half-done board if there is one, else the first level not solved yet,
## else (every level solved) level 1 again.
func _continue_level() -> int:
	var saved := _saved_level()
	if saved > 0:
		return saved
	var next := progress.next_level()
	return next if next <= Levels.COUNT else 1


## The level of the half-done journey board, 0 when there is none.
func _saved_level() -> int:
	var key := progress.saved_key("journey")
	if key.is_valid_int() and int(key) >= 1 and int(key) <= Levels.COUNT:
		return int(key)
	return 0


## Starts the daily puzzle of `date`, today's when empty. Restart passes the date it began with, so a
## restart after midnight keeps the same board.
func _start_daily(date: String = "", resume: bool = true) -> void:
	_mode = "daily"
	_daily_key = date if date != "" else Levels.today()
	puzzle = Levels.make_daily(_daily_key)
	_title.text = "Daily · %s" % _daily_key
	_begin(resume)


func _board_key() -> String:
	return str(_level) if _mode == "journey" else _daily_key


func _begin(resume: bool) -> void:
	_show(_game)
	_moves = 0
	_seconds = 0.0
	_undo.clear()
	if resume:
		var saved := progress.restore_board(_mode, _board_key(), puzzle)
		if not saved.is_empty():
			_moves = saved.moves
			_seconds = saved.seconds
			_undo.assign(saved.undo)
	_running = true
	board.show_puzzle(puzzle)
	_lanterns_on = puzzle.lanterns_lit().x
	_update_stats()
	_announce_board()
	Ui.focus_later(board)
	_hint.text = TOUCH_HINT if DisplayServer.is_touchscreen_available() else MOUSE_HINT


func _restart() -> void:
	_running = false
	progress.clear_board(_mode)
	if _mode == "daily":
		_start_daily(_daily_key, false)
	else:
		_start_level(_level, false)


func _on_turned(i: int, clockwise: bool) -> void:
	_moves += 1
	_undo.append(Vector2i(i, 1 if clockwise else 0))
	sfx.play("turn")
	var on := puzzle.lanterns_lit().x
	if on > _lanterns_on:
		sfx.play("lantern")
	_lanterns_on = on
	_update_stats()
	_announce_board()
	if _running:
		_save_board()


func _on_lock_changed(_i: int) -> void:
	sfx.play("lock")
	if _running:
		_save_board()


func _undo_turn() -> void:
	if _undo.is_empty() or not _running:
		return
	var last: Vector2i = _undo.pop_back()
	board.turn_silently(last.x, last.y == 0)
	_moves = maxi(0, _moves - 1)
	_lanterns_on = puzzle.lanterns_lit().x
	sfx.play("turn")
	_update_stats()
	_announce_board()
	_save_board()


## Saves the board in play into its mode's one slot, but only once it has a move in it: just opening a level
## and backing out must not replace a half-done board of another level. A board undone back to nothing
## frees the slot if it was its own.
func _save_board() -> void:
	if _moves > 0 or not _undo.is_empty():
		progress.save_board(_mode, _board_key(), puzzle, _moves, _seconds, _undo)
	elif progress.saved_key(_mode) == _board_key():
		progress.clear_board(_mode)


func _update_stats() -> void:
	if puzzle == null:
		return
	var lanterns := puzzle.lanterns_lit()
	_stats.text = "%d / %d lanterns · %s (par %d) · %s" % [lanterns.x, lanterns.y, Ui.count_of(_moves, "move"), puzzle.par, _clock(_seconds)]
	_undo_button.disabled = _undo.is_empty()


func _clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func _on_solved() -> void:
	_running = false
	progress.clear_board(_mode)
	board.celebrate()
	sfx.play("solved")
	var star_count := Levels.stars_for(_moves, puzzle.par)
	var heading := "All lanterns lit!"
	var lines: Array[String] = ["%s · par %d · %s" % [Ui.count_of(_moves, "move"), puzzle.par, _clock(_seconds)]]
	var buttons: Array = []
	if _mode == "journey":
		progress.record_level(_level, star_count)
		if _level < Levels.COUNT:
			buttons.append(["Next level", _start_level.bind(_level + 1), true])
		buttons.append(["Play again", _restart, _level >= Levels.COUNT])
		buttons.append(["Menu", _show_menu, false])
	else:
		progress.record_daily(_daily_key, _moves)
		lines.append("A new daily puzzle starts at midnight, your local time.")
		buttons = [["Menu", _show_menu, true], ["Play again", _restart, false]]
	_announce("%s %s. %s. %s." % [heading, Ui.count_of(star_count, "star"), _title.text, lines[0]])
	# Let the lit board show first. If the player leaves or restarts meanwhile, the results are dropped.
	var screen_id := _screen_id
	await get_tree().create_timer(RESULT_DELAY).timeout
	if screen_id != _screen_id:
		return
	_dialog.open(heading, star_count, lines, buttons, false)


# ------------------------------------------------------------------ Dialogs and announcements

func _close_dialog() -> void:
	_dialog.visible = false
	if _menu.visible:
		Ui.focus_later(_continue_button)
	elif _game.visible:
		Ui.focus_later(board)


func _show_help() -> void:
	var lines: Array[String] = [
		"Light flows from the sun in the middle along the vines. Turn the tiles so every paper lantern glows and no vine ends in the dark.",
		"Tap or click a tile to turn it. Hold it, or right-click it, to lock a tile you are sure of; it cannot turn until you unlock it.",
	]
	if not DisplayServer.is_touchscreen_available():
		lines.append("Keys: arrows or WASD move, Space, Enter or E turns, Q turns back, L locks, U or Ctrl+Z undoes, R restarts, Esc leaves.")
	lines.append("Finish within par for three stars. Each day brings a new 8×8 daily puzzle.")
	_dialog.open("How to play", -1, lines, [["Got it", _close_dialog, true]], true)


func _announce_board() -> void:
	var lanterns := puzzle.lanterns_lit()
	_announce("%s · %d of %d lanterns lit · %s" % [_title.text, lanterns.x, lanterns.y, Ui.count_of(_moves, "move")])


## Gives `text` to screen readers: the page shell has a hidden live region (the canvas itself has no text).
func _announce(text: String) -> void:
	announcement = text
	if OS.has_feature("web"):
		var window: Variant = JavaScriptBridge.get_interface("window")
		if window != null and window.glowlineAnnounce != null:
			window.glowlineAnnounce(text)


## While a dialog is open, nothing behind it can take the keyboard focus (Tab or arrows would reach it).
func _on_dialog_visibility_changed() -> void:
	var behavior := Control.FOCUS_BEHAVIOR_DISABLED if _dialog.visible else Control.FOCUS_BEHAVIOR_INHERITED
	for screen: Control in [_menu, _levels, _game]:
		screen.focus_behavior_recursive = behavior
