extends "res://tests/test_case.gd"
## Puzzle: turning tiles, where the light goes, when a board is solved, par, and the generator.

const N := Puzzle.N
const E := Puzzle.E
const S := Puzzle.S
const W := Puzzle.W


## A 3×1 board: a lantern, the sun, a lantern, joined by a straight line.
func _line() -> Puzzle:
	var p := Puzzle.new()
	p.setup(3, 1, Vector2i(1, 0), [E, E | W, W], [E, E | W, W])
	return p


func test_rotation() -> void:
	check_eq(Puzzle.rotate_cw(N), E, "north turns to east")
	check_eq(Puzzle.rotate_cw(W), N, "west turns to north")
	check_eq(Puzzle.rotate_cw(N | S), E | W, "a straight turns sideways")
	check_eq(Puzzle.rotate_cw(N | E, 4), N | E, "four turns are a full circle")
	check_eq(Puzzle.rotate_cw(N | E, -1), W | N, "a negative turn goes the other way")
	check_eq(Puzzle.turns_between(N, W), 3, "north to west is three clockwise turns")
	check_eq(Puzzle.turns_between(N, N | E), -1, "an end never turns into a corner")


func test_fewest_turns_go_either_way() -> void:
	check_eq(Puzzle.fewest_turns(N, W), 1, "north to west is one turn back")
	check_eq(Puzzle.fewest_turns(N, S), 2, "north to south is two turns")
	check_eq(Puzzle.fewest_turns(N | E, N | E), 0, "no turn when it already fits")
	check_eq(Puzzle.fewest_turns(N | S, E | W), 1, "a straight needs one turn at most")
	check_eq(Puzzle.fewest_turns(N, N | S), -1, "an end never turns into a straight")


func test_counter_clockwise_turn() -> void:
	var p := _line()
	check(p.turn(0, false), "an unlocked tile turns")
	check_eq(p.tiles[0], N, "east turned back once points north")
	check(p.turn(0, true), "and turns forward again")
	check_eq(p.tiles[0], E, "back to east")


func test_locked_tile_does_not_turn() -> void:
	var p := _line()
	p.locked[0] = 1
	check(not p.turn(0) and not p.turn(0, false), "a locked tile refuses both turns")
	check_eq(p.tiles[0], E, "and stays as it was")


func test_connected_needs_both_ends() -> void:
	var p := _line()
	check(p.connected(Vector2i(0, 0), 1), "the lantern meets the sun to the east")
	check(p.connected(Vector2i(1, 0), 3), "the sun meets the lantern to the west")
	check(not p.connected(Vector2i(0, 0), 3), "nothing past the left edge")
	check(not p.connected(Vector2i(1, 0), 0), "the sun has no end to the north")
	p.tiles[0] = S
	check(not p.connected(Vector2i(1, 0), 3), "the sun's end alone does not connect")


func test_lit_follows_the_pipes() -> void:
	var p := _line()
	check_eq(p.lit(), PackedByteArray([1, 1, 1]), "a joined line is lit end to end")
	check_eq(p.lanterns_lit(), Vector2i(2, 2), "both lanterns glow")
	p.tiles[2] = N
	check_eq(p.lit(), PackedByteArray([1, 1, 0]), "a lantern turned away stays dark")
	check_eq(p.lanterns_lit(), Vector2i(1, 2), "one lantern of two")


func test_is_solved() -> void:
	var p := _line()
	check(p.is_solved(), "the answer is solved")
	p.turn(0)
	check(not p.is_solved(), "a lantern pointing out of the board is not solved")
	p = _line()
	p.tiles[1] = N | E | W
	check(not p.is_solved(), "a pipe ending in the dark is not solved, even with every lantern lit")
	check_eq(p.lanterns_lit(), Vector2i(2, 2), "(every lantern is lit there)")
	# 4×2: a closed loop on the left that the sun on the right never reaches. Every end meets another one.
	var loop := [E | S, W | S, E | S, W, N | E, N | W, N | E, W]
	p = Puzzle.new()
	p.setup(4, 2, Vector2i(2, 0), loop, loop)
	check_eq(p.lit(), PackedByteArray([0, 0, 1, 1, 0, 0, 1, 1]), "the light stays on the right")
	check(not p.is_solved(), "a closed loop out of the light is not solved")


func test_par_counts_turns_either_way() -> void:
	var p := Puzzle.new()
	p.setup(3, 1, Vector2i(1, 0), [E, E | W, W], [N, E | W, W])
	check_eq(p.par, 1, "east from north is one turn (clockwise it would take three)")
	p.setup(3, 1, Vector2i(1, 0), [E, E | W, W], [W, N | S, E])
	check_eq(p.par, 5, "two half turns and a straight")
	p.setup(3, 1, Vector2i(1, 0), [E, E | W, W], [E, E | W, W])
	check_eq(p.par, 0, "a solved board needs no turn")


func test_generated_boards() -> void:
	for board_size: Vector2i in [Vector2i(3, 3), Vector2i(4, 4), Vector2i(7, 7), Vector2i(9, 9), Vector2i(6, 8)]:
		for seed_value: int in [1, 42, 99991]:
			var p := Puzzle.new()
			p.generate(board_size.x, board_size.y, seed_value)
			var label := "%dx%d seed %d" % [board_size.x, board_size.y, seed_value]
			check(not p.is_solved(), label + " starts unsolved")
			check(p.par > 0, label + " needs turns")
			var lanterns := p.lanterns_lit()
			check(lanterns.y >= 2, label + " has lanterns")
			var edges := 0
			for mask in p.solution:
				edges += Puzzle.bit_count(mask)
			check_eq(edges, 2 * (p.width * p.height - 1), label + " answer is a tree over every tile")
			var par := 0
			for i in p.width * p.height:
				var turns := Puzzle.fewest_turns(p.tiles[i], p.solution[i])
				if turns < 0:
					check(false, "%s tile %d (%s) cannot turn into its answer" % [label, i, p.cell_of(i)])
				par += turns
				p.tiles[i] = p.solution[i]
			check_eq(p.par, par, label + " par is the sum of the fewest turns")
			check(p.is_solved(), label + " is solved by its answer")
			check_eq(p.lanterns_lit().x, lanterns.y, label + " lights every lantern when solved")


func test_scramble_turns_only_some_tiles() -> void:
	for amount in [3, 5, 8]:
		var p := Puzzle.new()
		p.generate(5, 5, 100 + amount, amount)
		var changed := 0
		for i in 25:
			if p.tiles[i] != p.solution[i]:
				changed += 1
				check_eq(Puzzle.fewest_turns(p.tiles[i], p.solution[i]), 1, "tile %d is one turn off" % i)
		check_eq(changed, amount, "%d tiles turned" % amount)
		check_eq(p.par, amount, "par is %d" % amount)
		check(not p.is_solved(), "a scrambled board starts unsolved")


func test_same_seed_same_board() -> void:
	var a := Puzzle.new()
	var b := Puzzle.new()
	a.generate(7, 7, 2026)
	b.generate(7, 7, 2026)
	check(a.tiles == b.tiles and a.solution == b.solution, "the same seed gives the same board")
	b.generate(7, 7, 2027)
	check(a.solution != b.solution, "another seed gives another board")


func test_light_paths() -> void:
	var p := _line()
	var paths := p.light_paths()
	check_eq(paths.depth, PackedInt32Array([1, 0, 1]), "the lanterns are one step from the sun")
	check_eq(paths.entry, PackedInt32Array([1, -1, 3]), "light enters the left lantern from the east, the right from the west")
	p.tiles[2] = N
	paths = p.light_paths()
	check_eq(paths.depth[2], -1, "a lantern turned away is not reached")
	check_eq(paths.entry[2], -1, "and has no way in")
	var level := Levels.make(12)
	paths = level.light_paths()
	var reached := level.lit()
	for i in level.width * level.height:
		check_eq(paths.depth[i] >= 0, reached[i] == 1, "tile %d: depth agrees with lit()" % i)
