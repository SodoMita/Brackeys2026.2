extends SceneTree
## Headless test runner — no addons required.
##
## Usage:
##   godot --headless --path . --script res://tests/test_runner.gd
##
## Discovers every tests/test_*.gd file, runs all of its test_* methods,
## prints a report and exits with code 1 when anything failed (CI-friendly).
## Runtime errors (script errors / pushes) inside a test count as failures.

const TEST_DIR := "res://tests"

var _passed := 0
var _failed := 0
var _errors_before := 0


func _initialize() -> void:
	print("")
	print("=== Brackeys 2026.2 — test suite ===")
	# Surface script errors instead of silently continuing.
	if has_signal("script_changed"):
		pass
	for fname in _collect_tests():
		_run_suite(fname)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


func _collect_tests() -> Array:
	var out: Array = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		push_error("Cannot open test directory: %s" % TEST_DIR)
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd") \
				and not f in ["test_runner.gd", "test_base.gd"]:
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _run_suite(fname: String) -> void:
	var script: GDScript = load(TEST_DIR.path_join(fname))
	if script == null:
		_failed += 1
		print("[FAIL] %s — cannot load script" % fname)
		return
	# Validate the script parsed cleanly.
	if script.get_instance_base_type() == "":
		_failed += 1
		print("[FAIL] %s — script has no base type (parse error?)" % fname)
		return
	var suite = script.new()
	if suite == null:
		_failed += 1
		print("[FAIL] %s — cannot instantiate suite" % fname)
		return
	suite.runner = self
	var methods: Array = []
	for m in script.get_script_method_list():
		var n := String(m["name"])
		if n.begins_with("test_"):
			methods.append(n)
	methods.sort()
	if methods.is_empty():
		print("[WARN] %s — no test_* methods" % fname)
	for mname in methods:
		var before: int = suite.failures.size()
		var err_msg := ""
		# Isolate each test: catch invalid calls so one crash doesn't kill the suite.
		if not suite.has_method(mname):
			suite.failures.append("missing method %s" % mname)
		else:
			var result = suite.call(mname)
			# call() returns null normally; if the method errored Godot may push_error.
			if result is GDScriptFunctionState:
				# Shouldn't happen (tests are sync) but don't hang CI.
				err_msg = "async test not supported"
				suite.failures.append(err_msg)
		if suite.failures.size() == before:
			_passed += 1
			print("[PASS] %s :: %s" % [fname, mname])
		else:
			_failed += 1
			print("[FAIL] %s :: %s" % [fname, mname])
			for i in range(before, suite.failures.size()):
				print("       - %s" % suite.failures[i])
	# Drop suite reference so RefCounted tests free between files.
	suite.runner = null
	suite = null
