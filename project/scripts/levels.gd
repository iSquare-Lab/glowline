class_name Levels
extends RefCounted
## The 40 journey levels and the daily puzzle: their sizes, their seeds, and the stars a result earns.

const COUNT := 40
const DAILY_SIZE := Vector2i(8, 8)
## The first levels teach: a small board with only a few tiles turned a quarter turn, so they take exactly
## that many moves. Level number -> tiles turned.
const TEACHING := {1: 3, 2: 4, 3: 5, 4: 8, 5: 12}


static func size_of(level: int) -> Vector2i:
	var side := 9
	if level <= 1:
		side = 3
	elif level <= 3:
		side = 4
	elif level <= 8:
		side = 5
	elif level <= 15:
		side = 6
	elif level <= 24:
		side = 7
	elif level <= 32:
		side = 8
	return Vector2i(side, side)


static func make(level: int) -> Puzzle:
	var level_size := size_of(level)
	var puzzle := Puzzle.new()
	puzzle.generate(level_size.x, level_size.y, 7919 * level + 17, TEACHING.get(level, 0))
	return puzzle


## The daily puzzle for `date` (YYYY-MM-DD, the player's local date).
static func make_daily(date: String) -> Puzzle:
	var puzzle := Puzzle.new()
	puzzle.generate(DAILY_SIZE.x, DAILY_SIZE.y, daily_seed(date))
	return puzzle


static func daily_seed(date: String) -> int:
	return fnv1a32("glowline-" + date)


## 32-bit FNV-1a over the UTF-8 bytes of `text`. Unlike String.hash(), it never changes between Godot versions,
## so a date always gives the same daily puzzle.
static func fnv1a32(text: String) -> int:
	var value := 0x811c9dc5
	for byte in text.to_utf8_buffer():
		value = ((value ^ byte) * 0x01000193) & 0xffffffff
	return value


## Today's local date as YYYY-MM-DD: the daily puzzle changes at local midnight.
static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Three stars within par, two within half as many moves again, one for any solution.
static func stars_for(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= ceili(par * 1.5):
		return 2
	return 1
