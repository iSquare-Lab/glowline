extends SceneTree
## Runs every test_*.gd file in this folder, headless:
##   godot --headless --path project --script res://tests/run_tests.gd
## Each file extends test_case.gd; each of its methods named test_* is one test (it may await).
## Exits with 1 when a check fails, and with 2 when the tests do not finish in time (a test that crashed
## mid-way never returns, so the time limit turns it into a failure instead of a hang).

const TIME_LIMIT := 120.0


func _initialize() -> void:
	create_timer(TIME_LIMIT).timeout.connect(_give_up)
	_run.call_deferred()


func _give_up() -> void:
	printerr("  FAIL the tests did not finish within %d s (see the error above)" % TIME_LIMIT)
	quit(2)


func _run() -> void:
	var tests := 0
	var checks := 0
	var failures := 0
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			printerr("  FAIL %s does not load" % file)
			failures += 1
			continue
		var case: Variant = script.new()
		case.tree = self
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			case.current = "%s/%s" % [file.get_basename(), method_name]
			var before: int = case.failures
			await case.call(method_name)
			tests += 1
			if case.failures == before:
				print("  ok   ", case.current)
		checks += case.checks
		failures += case.failures
	print("%d tests, %d checks, %d failure(s)" % [tests, checks, failures])
	quit(1 if failures else 0)
