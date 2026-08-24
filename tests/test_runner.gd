extends SceneTree
## Headless test runner — no addons required.
##
## Usage:
##   godot --headless --path . --script res://tests/test_runner.gd
##
## Discovers every tests/test_*.gd file, runs all of its test_* methods,
## prints a report and exits with code 1 when anything failed (CI-friendly).

const TEST_DIR := "res://tests"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("")
	print("=== Brackeys 2026.2 — test suite ===")
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

	var cfg := root.get_node_or_null("Cfg")
	var max_hp_snap: float = float(cfg.max_hp) if cfg else 100.0

	for mname in methods:
		var before: int = suite.failures.size()
		suite.call(mname)
		if suite.has_method("_cleanup"):
			suite._cleanup()
		if cfg:
			cfg.max_hp = max_hp_snap
		if suite.failures.size() == before:
			_passed += 1
			print("[PASS] %s :: %s" % [fname, mname])
		else:
			_failed += 1
			print("[FAIL] %s :: %s" % [fname, mname])
			for i in range(before, suite.failures.size()):
				print("       - %s" % suite.failures[i])
	suite.runner = null
	suite = null
