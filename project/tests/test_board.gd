extends "res://tests/test_case.gd"
## Board: light flows out from the sun one ring after another, and goes dark at once.


func _board() -> Board:
	var board := Board.new()
	board.size = Vector2(300, 100)
	tree.root.add_child(board)
	var p := Puzzle.new()
	# 5×1: lantern, straight, sun, straight, lantern.
	p.setup(5, 1, Vector2i(2, 0), [2, 10, 10, 10, 8], [2, 10, 10, 10, 8])
	board.show_puzzle(p)
	return board


func test_light_flows_out_from_the_sun() -> void:
	var board := _board()
	var start := board._light_start
	check(start[2] < start[1] and start[1] < start[0], "the sun first, then its neighbour, then the lantern")
	check_eq(start[1], start[3], "both sides at the same pace")
	check(board.is_flowing(), "the light is still on its way")
	await wait(Board.FLOW_FILL + 2 * Board.FLOW_STEP + 0.2)
	check(not board.is_flowing(), "then it has arrived")
	for i in 5:
		check_eq(board.light_of(i), 1.0, "tile %d fully lit" % i)
	board.free()


func test_only_new_light_flows() -> void:
	var board := _board()
	await wait(Board.FLOW_FILL + 2 * Board.FLOW_STEP + 0.2)
	board.puzzle.tiles[4] = Puzzle.N
	board._refresh()
	check_eq(board.light_of(4), 0.0, "a lantern turned away goes dark at once")
	check_eq(board.light_of(3), 1.0, "the rest stays lit")
	board.puzzle.tiles[4] = Puzzle.W
	board._refresh()
	check(board._light_start[4] >= board._clock - 0.001, "the lantern lights again from now")
	check_eq(board.light_of(0), 1.0, "without the other tiles starting over")
	board.free()
