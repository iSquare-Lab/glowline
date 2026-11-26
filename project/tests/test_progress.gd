extends "res://tests/test_case.gd"
## Progress: stars, the next level, daily results, settings and the board left half done. All in memory.


func test_fresh_progress() -> void:
	var p := Progress.new()
	check_eq(p.solved_count(), 0, "nothing solved")
	check_eq(p.star_total(), 0, "no stars")
	check_eq(p.next_level(), 1, "level 1 comes first")
	check(p.sound, "sound starts on")
	check(not p.seen_help, "How to play not seen yet")


func test_stars_keep_the_best() -> void:
	var p := Progress.new()
	p.record_level(1, 2)
	check_eq(p.stars(1), 2, "two stars saved")
	p.record_level(1, 1)
	check_eq(p.stars(1), 2, "a worse result keeps the best")
	p.record_level(1, 3)
	check_eq(p.stars(1), 3, "a better result replaces it")
	p.record_level(2, 1)
	check_eq(p.solved_count(), 2, "two levels solved")
	check_eq(p.star_total(), 4, "four stars in all")


func test_next_level() -> void:
	var p := Progress.new()
	p.record_level(1, 3)
	p.record_level(2, 1)
	check_eq(p.next_level(), 3, "the first level not solved")
	p.record_level(4, 2)
	check_eq(p.next_level(), 3, "a gap is still the next level")
	for level in range(1, Levels.COUNT + 1):
		p.record_level(level, 1)
	check_eq(p.next_level(), Levels.COUNT + 1, "past the last level when all are solved")


func test_daily_keeps_fewest_moves() -> void:
	var p := Progress.new()
	check_eq(p.daily_best("2026-11-26"), 0, "not solved yet")
	p.record_daily("2026-11-26", 30)
	p.record_daily("2026-11-26", 40)
	check_eq(p.daily_best("2026-11-26"), 30, "more moves keep the best")
	p.record_daily("2026-11-26", 25)
	check_eq(p.daily_best("2026-11-26"), 25, "fewer moves replace it")
	check_eq(p.daily_best("2026-11-27"), 0, "another day is separate")


func test_settings() -> void:
	var p := Progress.new()
	p.sound = false
	p.seen_help = true
	check(not p.sound and p.seen_help, "settings are kept")


func test_board_comes_back() -> void:
	var p := Progress.new()
	var played := Levels.make(6)
	played.turn(0)
	played.turn(7, false)
	played.locked[3] = 1
	var undo: Array[Vector2i] = [Vector2i(0, 1), Vector2i(7, 0)]
	p.save_board("journey", "6", played, 2, 12.5, undo)
	var fresh := Levels.make(6)
	var saved := p.restore_board("journey", "6", fresh)
	check_eq(fresh.tiles, played.tiles, "the turned tiles come back")
	check_eq(fresh.locked, played.locked, "the locks come back")
	check_eq(saved.get("moves"), 2, "the moves come back")
	check_eq(saved.get("seconds"), 12.5, "the time comes back")
	check_eq(saved.get("undo"), [Vector2i(0, 1), Vector2i(7, 0)], "the undo list comes back")


func test_board_for_another_level_is_ignored() -> void:
	var p := Progress.new()
	var played := Levels.make(6)
	played.turn(0)
	p.save_board("journey", "6", played, 1, 1.0, [])
	var other := Levels.make(7)
	var before := other.tiles.duplicate()
	check(p.restore_board("journey", "7", other).is_empty(), "nothing for level 7")
	check_eq(other.tiles, before, "level 7 is left as it was")
	check(p.restore_board("daily", "6", Levels.make(6)).is_empty(), "the daily slot is separate")
	p.clear_board("journey")
	check(p.restore_board("journey", "6", Levels.make(6)).is_empty(), "nothing after clearing")


func test_board_that_no_longer_fits_is_ignored() -> void:
	var p := Progress.new()
	var played := Levels.make(6)
	played.tiles[0] = 15 if played.solution[0] != 15 else 1
	p.save_board("journey", "6", played, 1, 1.0, [])
	var fresh := Levels.make(6)
	var before := fresh.tiles.duplicate()
	check(p.restore_board("journey", "6", fresh).is_empty(), "a tile that cannot turn into the saved one")
	check_eq(fresh.tiles, before, "the fresh board is kept")
	var solved := Levels.make(6)
	solved.tiles = solved.solution.duplicate()
	p.save_board("journey", "6", solved, 9, 1.0, [])
	check(p.restore_board("journey", "6", Levels.make(6)).is_empty(), "a solved board is not resumed")
	p.save_board("journey", "6", Levels.make(6), 1, 1.0, [Vector2i(999, 1)])
	check(p.restore_board("journey", "6", Levels.make(6)).is_empty(), "an undo step off the board")
