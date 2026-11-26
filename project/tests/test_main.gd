extends "res://tests/test_case.gd"
## The game screens, driven the way a player would: results timing, restart, resume, wording.

const MainScene := preload("res://main.tscn")


## A fresh game that saves nothing to disk, on the menu.
func _make_main() -> Control:
	var main := MainScene.instantiate()
	main.progress_path = ""
	tree.root.add_child(main)
	main._close_dialog()
	return main


## Turns every tile but one into the answer, then gives that one its last turn through the board,
## as a click would.
func _solve(main: Control) -> void:
	var p: Puzzle = main.puzzle
	var last := -1
	for i in p.width * p.height:
		p.tiles[i] = p.solution[i]
		if last < 0 and Puzzle.rotate_cw(p.solution[i]) != p.solution[i]:
			last = i
	p.tiles[last] = Puzzle.rotate_cw(p.solution[last], 3)
	main.board._turn(last, true)


func _press(main: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	main._unhandled_input(event)


func test_first_visit_opens_how_to_play() -> void:
	var main := MainScene.instantiate()
	main.progress_path = ""
	tree.root.add_child(main)
	check_eq(main._dialog.heading(), "How to play", "How to play opens on the first visit")
	check(main.progress.seen_help, "and is remembered")
	_press(main, KEY_ESCAPE)
	check(not main._dialog.visible, "Esc closes it")
	check(main._menu.visible, "the menu is under it")
	main.free()


func test_results_open_after_the_lit_board() -> void:
	var main := _make_main()
	main._start_level(1)
	_solve(main)
	check(not main._dialog.visible, "the lit board shows first")
	await wait(main.RESULT_DELAY + 0.2)
	check_eq(main._dialog.heading(), "All lanterns lit!", "then the results open")
	check_eq(main.progress.stars(1), 3, "a one-move finish on level 1 gets three stars")
	main.free()


func test_leaving_before_the_results_drops_them() -> void:
	var main := _make_main()
	main._start_level(1)
	_solve(main)
	_press(main, KEY_ESCAPE)
	await wait(main.RESULT_DELAY + 0.2)
	check(main._menu.visible, "Esc went to the menu")
	check(not main._dialog.visible, "the results do not open over the menu")
	main.free()


func test_restarting_before_the_results_drops_them() -> void:
	var main := _make_main()
	main._start_level(1)
	_solve(main)
	_press(main, KEY_R)
	await wait(main.RESULT_DELAY + 0.2)
	check(main._game.visible, "R started the level again")
	check(not main._dialog.visible, "the results do not open over the new board")
	check(not main.puzzle.is_solved(), "the new board is not solved")
	check(main.board.interactive, "and it can be played")
	main.free()


func test_continue_resumes_the_board() -> void:
	var main := _make_main()
	main._start_level(2)
	main.board._turn(0, true)
	main.board._turn(1, false)
	var tiles: PackedInt32Array = main.puzzle.tiles.duplicate()
	main._show_menu()
	main._start_level(2)
	check_eq(main._moves, 2, "the moves are kept")
	check_eq(main.puzzle.tiles, tiles, "the board is as it was left")
	main._undo_turn()
	check_eq(main._moves, 1, "and undo still works")
	main._restart()
	check_eq(main._moves, 0, "restart starts from zero")
	check_eq(main.puzzle.tiles, Levels.make(2).tiles, "with the fresh board")
	main._show_menu()
	main._start_level(2)
	check_eq(main._moves, 0, "and a restarted board is not resumed")
	main.free()


func test_daily_restart_keeps_its_date() -> void:
	var main := _make_main()
	main._start_daily("2001-02-03")
	main.board._turn(0, true)
	main._restart()
	check_eq(main._daily_key, "2001-02-03", "restart keeps the date the puzzle began with")
	check_eq(main.puzzle.tiles, Levels.make_daily("2001-02-03").tiles, "and its board")
	main.free()


func test_wording() -> void:
	var main := _make_main()
	main._start_level(1)
	main.board._turn(0, true)
	check(main._stats.text.contains("1 move (par"), "one move, not 1 moves: %s" % main._stats.text)
	check(main.announcement.begins_with("Level 1 · "), "the board is announced: %s" % main.announcement)
	check(main.announcement.ends_with("lanterns lit · 1 move"), "with lanterns and moves: %s" % main.announcement)
	main.progress.record_daily(Levels.today(), 18)
	main._show_menu()
	check_eq(main._daily_button.text, "Daily puzzle · solved in 18 moves", "the daily button says moves")
	main.progress.record_level(1, 1)
	main._show_menu()
	check(main._menu_progress.text.ends_with("· 1 star"), "one star, not 1 stars: %s" % main._menu_progress.text)
	main.free()


func test_locked_levels_show_a_padlock() -> void:
	var main := _make_main()
	main._show_levels()
	var grid: GridContainer = main._levels._grid
	var first: Button = grid.get_child(0)
	var second: Button = grid.get_child(1)
	check(not first.disabled and not first.get_child(0).get_node("Lock").visible, "level 1 is open")
	check(second.disabled and second.get_child(0).get_node("Lock").visible, "level 2 is locked, with a padlock")
	main.free()
