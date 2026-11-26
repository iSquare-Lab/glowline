extends RefCounted
## Base of every test file. run_tests.gd calls each method whose name starts with test_ (a test may await);
## a failed check prints the file, the test and what went wrong.

var tree: SceneTree
var current := ""
var checks := 0
var failures := 0


func check(condition: bool, what: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("  FAIL %s: %s" % [current, what])


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [what, actual, expected])


## Waits `seconds` of game time.
func wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout
