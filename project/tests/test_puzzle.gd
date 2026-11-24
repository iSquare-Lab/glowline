extends SceneTree
## Run with: godot --headless --path project --script res://tests/test_puzzle.gd
## Exits with 1 when a check fails.

var failures := 0


func check(condition: bool, what: String) -> void:
	if condition:
		print("  ok  ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _init() -> void:
	check(Puzzle.rotate_cw(Puzzle.N) == Puzzle.E, "north turns to east")
	check(Puzzle.rotate_cw(Puzzle.W) == Puzzle.N, "west turns to north")
	check(Puzzle.rotate_cw(Puzzle.N | Puzzle.S) == (Puzzle.E | Puzzle.W), "a straight turns sideways")
	check(Puzzle.rotate_cw(Puzzle.N | Puzzle.E, 4) == (Puzzle.N | Puzzle.E), "four turns are a full circle")
	check(Puzzle.turns_between(Puzzle.N, Puzzle.W) == 3, "north to west is three turns")
	check(Puzzle.turns_between(Puzzle.N, Puzzle.N | Puzzle.E) == -1, "an end never turns into a corner")

	for size in [Vector2i(4, 4), Vector2i(7, 7), Vector2i(9, 9), Vector2i(6, 8)]:
		for seed_value in [1, 42, 99991]:
			var puzzle := Puzzle.new()
			puzzle.generate(size.x, size.y, seed_value)
			var label := "%dx%d seed %d" % [size.x, size.y, seed_value]
			check(not puzzle.is_solved(), label + " starts unsolved")
			check(puzzle.par > 0, label + " needs turns")
			var lanterns := puzzle.lanterns_lit()
			check(lanterns.y >= 2, label + " has lanterns")
			# Turning every tile to the generator's answer solves it.
			for i in puzzle.width * puzzle.height:
				check_quiet(Puzzle.turns_between(puzzle.tiles[i], puzzle.solution[i]) >= 0, label)
				puzzle.tiles[i] = puzzle.solution[i]
			check(puzzle.is_solved(), label + " is solved by its answer")
			check(puzzle.lanterns_lit().x == lanterns.y, label + " lights every lantern when solved")
			var edges := 0
			for mask in puzzle.solution:
				edges += Puzzle.bit_count(mask)
			check(edges / 2 == puzzle.width * puzzle.height - 1, label + " answer is a tree over every tile")

	var a := Puzzle.new()
	var b := Puzzle.new()
	a.generate(7, 7, 2026)
	b.generate(7, 7, 2026)
	check(a.tiles == b.tiles and a.solution == b.solution, "the same seed gives the same board")

	var lockable := Puzzle.new()
	lockable.generate(5, 5, 3)
	var before := lockable.tiles[0]
	lockable.locked[0] = 1
	check(not lockable.turn(0) and lockable.tiles[0] == before, "a locked tile does not turn")

	print("%d failure(s)" % failures)
	quit(1 if failures else 0)


func check_quiet(condition: bool, what: String) -> void:
	if not condition:
		failures += 1
		printerr("  FAIL ", what, ": a tile cannot reach its answer")
