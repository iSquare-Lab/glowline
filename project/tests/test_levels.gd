extends "res://tests/test_case.gd"
## Levels: sizes, the teaching levels, the daily seed, stars, and golden boards that catch any change to the
## generator (which would silently change all 40 levels and every daily puzzle).

## Level number -> [par, checksum of its tiles and answer], recorded with Godot 4.7.2.
const GOLDEN := {
	1: [3, 1407183146], 2: [4, 1631590949], 3: [5, 442272382], 4: [8, 1869081748], 5: [12, 1735569649],
	6: [24, 933431420], 7: [24, 1058116898], 8: [22, 1973866201], 9: [33, 932406896], 10: [28, 1997875332],
	11: [24, 1018495361], 12: [30, 1495179128], 13: [32, 420004814], 14: [30, 1943748475], 15: [30, 367283558],
	16: [61, 714775207], 17: [35, 1472984906], 18: [45, 1206032149], 19: [47, 1378114115], 20: [46, 640291160],
	21: [43, 107379624], 22: [53, 739443885], 23: [47, 58421651], 24: [47, 1054272391], 25: [68, 1400160557],
	26: [59, 1345587327], 27: [65, 825151380], 28: [57, 1635995966], 29: [61, 217579271], 30: [53, 1581986501],
	31: [59, 317375867], 32: [57, 1655506807], 33: [73, 736024968], 34: [72, 1987616266], 35: [78, 568170241],
	36: [75, 260542055], 37: [78, 39495604], 38: [74, 1232600134], 39: [61, 2098906483], 40: [80, 32785228],
}


func _checksum(p: Puzzle) -> int:
	var sum := 0
	for value in p.tiles:
		sum = (sum * 31 + value) % 2147483647
	for value in p.solution:
		sum = (sum * 31 + value) % 2147483647
	return sum


func test_sizes_grow() -> void:
	check_eq(Levels.size_of(1), Vector2i(3, 3), "level 1 is 3×3")
	check_eq(Levels.size_of(2), Vector2i(4, 4), "level 2 is 4×4")
	check_eq(Levels.size_of(8), Vector2i(5, 5), "level 8 is 5×5")
	check_eq(Levels.size_of(9), Vector2i(6, 6), "level 9 is 6×6")
	check_eq(Levels.size_of(Levels.COUNT), Vector2i(9, 9), "the last level is 9×9")
	for level in range(2, Levels.COUNT + 1):
		check(Levels.size_of(level).x >= Levels.size_of(level - 1).x, "level %d is not smaller than the one before" % level)


func test_teaching_levels_are_short() -> void:
	for level: int in Levels.TEACHING:
		var p := Levels.make(level)
		check_eq(p.par, Levels.TEACHING[level], "level %d takes %d moves" % [level, Levels.TEACHING[level]])
	for level in [1, 2, 3]:
		var par := Levels.make(level).par
		check(par >= 3 and par <= 5, "level %d takes 3 to 5 moves (par %d)" % [level, par])


func test_golden_levels() -> void:
	for level in range(1, Levels.COUNT + 1):
		var p := Levels.make(level)
		check_eq([p.par, _checksum(p)], GOLDEN[level], "level %d is the same board as before" % level)
		check(not p.is_solved(), "level %d starts unsolved" % level)


func test_daily_seed_is_stable() -> void:
	check_eq(Levels.fnv1a32(""), 0x811c9dc5, "FNV-1a of nothing is its offset basis")
	check_eq(Levels.fnv1a32("a"), 0xe40c292c, "FNV-1a of \"a\"")
	check_eq(Levels.daily_seed("2026-11-26"), 1549603967, "the seed of 2026-11-26")
	var p := Levels.make_daily("2026-11-26")
	check_eq(Vector2i(p.width, p.height), Levels.DAILY_SIZE, "the daily is 8×8")
	check_eq([p.par, _checksum(p)], [56, 831371940], "the daily of 2026-11-26 is the same board as before")
	check(Levels.make_daily("2026-11-27").solution != p.solution, "the next day has another board")


func test_today_is_a_date() -> void:
	var regex := RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
	check(regex.search(Levels.today()) != null, "today looks like YYYY-MM-DD (%s)" % Levels.today())


func test_stars_for() -> void:
	check_eq(Levels.stars_for(10, 10), 3, "par is three stars")
	check_eq(Levels.stars_for(7, 10), 3, "under par is three stars")
	check_eq(Levels.stars_for(11, 10), 2, "one over par is two stars")
	check_eq(Levels.stars_for(15, 10), 2, "half as many again is still two stars")
	check_eq(Levels.stars_for(16, 10), 1, "more is one star")
	check_eq(Levels.stars_for(5, 3), 2, "par 3: five moves round up to two stars")
	check_eq(Levels.stars_for(6, 3), 1, "par 3: six moves is one star")
