class_name Progress
extends RefCounted
## What the player has done: stars per level, the best daily results, settings, and the board they left
## half done. Kept in a ConfigFile at `path` (Godot's user://, which is IndexedDB on the web).
## An empty path keeps everything in memory; the tests use that.

const PATH := "user://glowline.cfg"

var path := ""
var _file := ConfigFile.new()

var sound: bool:
	get:
		return _file.get_value("settings", "sound", true)
	set(value):
		_file.set_value("settings", "sound", value)
		save()

## True once the player has seen "How to play", which opens by itself on the first visit.
var seen_help: bool:
	get:
		return _file.get_value("settings", "seen_help", false)
	set(value):
		_file.set_value("settings", "seen_help", value)
		save()


func _init(file_path: String = "") -> void:
	path = file_path
	if path != "":
		_file.load(path)


func save() -> void:
	if path != "":
		_file.save(path)


func stars(level: int) -> int:
	return int(_file.get_value("stars", str(level), 0))


## Keeps the best result for `level`.
func record_level(level: int, star_count: int) -> void:
	if star_count > stars(level):
		_file.set_value("stars", str(level), star_count)
		save()


func solved_count() -> int:
	var count := 0
	for level in range(1, Levels.COUNT + 1):
		if stars(level) > 0:
			count += 1
	return count


func star_total() -> int:
	var total := 0
	for level in range(1, Levels.COUNT + 1):
		total += stars(level)
	return total


## The first level not solved yet, or Levels.COUNT + 1 when every level is.
func next_level() -> int:
	for level in range(1, Levels.COUNT + 1):
		if stars(level) == 0:
			return level
	return Levels.COUNT + 1


## Fewest moves the daily puzzle of `date` was solved in, 0 when it was not.
func daily_best(date: String) -> int:
	return int(_file.get_value("daily", date, 0))


func record_daily(date: String, moves: int) -> void:
	var best := daily_best(date)
	if best == 0 or moves < best:
		_file.set_value("daily", date, moves)
		save()


## Remembers a board in play, so Continue picks it up where it was left. One slot per mode
## ("journey", "daily"); `key` says which level or date the board belongs to.
func save_board(mode: String, key: String, puzzle: Puzzle, moves: int, seconds: float, undo: Array) -> void:
	var section := "board_" + mode
	_file.set_value(section, "key", key)
	_file.set_value(section, "tiles", puzzle.tiles)
	_file.set_value(section, "locked", puzzle.locked)
	_file.set_value(section, "moves", moves)
	_file.set_value(section, "seconds", seconds)
	_file.set_value(section, "undo", undo.duplicate())
	save()


## Puts the saved board for `key` back on `puzzle` (made fresh for that level or date) and returns its
## moves, seconds and undo list. Returns {} and changes nothing when there is none, or when it no longer
## fits the puzzle (a different size, a tile that cannot turn into the saved one, or already solved).
func restore_board(mode: String, key: String, puzzle: Puzzle) -> Dictionary:
	var section := "board_" + mode
	if _file.get_value(section, "key", "") != key:
		return {}
	var saved_tiles: Variant = _file.get_value(section, "tiles")
	var saved_locked: Variant = _file.get_value(section, "locked")
	var undo: Variant = _file.get_value(section, "undo", [])
	var count := puzzle.width * puzzle.height
	if not (saved_tiles is PackedInt32Array and saved_locked is PackedByteArray and undo is Array):
		return {}
	if saved_tiles.size() != count or saved_locked.size() != count:
		return {}
	for i in count:
		if Puzzle.turns_between(puzzle.tiles[i], saved_tiles[i]) < 0:
			return {}
	for entry: Variant in undo:
		if not (entry is Vector2i and entry.x >= 0 and entry.x < count):
			return {}
	var fresh_tiles := puzzle.tiles
	var fresh_locked := puzzle.locked
	puzzle.tiles = saved_tiles
	puzzle.locked = saved_locked
	if puzzle.is_solved():
		puzzle.tiles = fresh_tiles
		puzzle.locked = fresh_locked
		return {}
	return {
		"moves": int(_file.get_value(section, "moves", 0)),
		"seconds": float(_file.get_value(section, "seconds", 0.0)),
		"undo": undo,
	}


## Which level or date the saved board of `mode` belongs to, "" when there is none.
func saved_key(mode: String) -> String:
	return str(_file.get_value("board_" + mode, "key", ""))


func clear_board(mode: String) -> void:
	var section := "board_" + mode
	if _file.has_section(section):
		_file.erase_section(section)
		save()
