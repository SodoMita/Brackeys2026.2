extends SceneTree
## Headless test runner — no addons required.
##
## Usage:
##   godot --headless --path . --script res://tests/test_runner.gd
##
## Discovers every tests/test_*.gd file, runs all of its test_* methods,
## prints a report and exits with code 1 when anything failed (CI-friendly).
## Now also prints GitHub Actions ::error annotations so failures are visible
## even if log zip download fails.

const TEST_DIR := "res://tests"

var _passed := 0
var _failed := 0
var _exit_code := 0


func _initialize() -> void:
	print("")
	print("=== Brackeys 2026.2 — test suite ===")
	# First, quick scene parse check - catches Color() 3-arg errors etc.
	_quick_scene_check()
	for fname in _collect_tests():
		_run_suite(fname)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	print("")
	# GitHub Actions summary - also visible via API
	if _failed > 0:
		print("::error::%d tests failed" % _failed)
	quit(1 if _failed > 0 else 0)


func _quick_scene_check() -> void:
	var scenes := [
		"res://scenes/player.tscn",
		"res://scenes/companion.tscn",
		"res://scenes/enemy.tscn",
		"res://scenes/projectile.tscn",
		"res://scenes/shop_terminal.tscn",
		"res://scenes/level.tscn",
		"res://scenes/hud.tscn",
		"res://scenes/game.tscn",
		"res://scenes/main.tscn",
	]
	for path in scenes:
		if not ResourceLoader.exists(path):
			_failed += 1
			print("[FAIL] quick_check :: missing %s" % path)
			print("::error file=%s::Missing scene %s" % [path, path])
			continue
		var res = load(path)
		if res == null:
			_failed += 1
			print("[FAIL] quick_check :: load failed (parse error) %s" % path)
			print("::error file=%s::Failed to load %s - parse error? Check Color() needs 4 args, Transform3D format, load_steps, missing SubResource" % [path, path])
		else:
			_passed += 1
			print("[PASS] quick_check :: %s loads" % path)


func _collect_tests() -> Array:
	var out: Array = []
	var files = DirAccess.get_files_at(TEST_DIR)
	for f in files:
		if f.begins_with("test_") and f.ends_with(".gd") \
				and not f in ["test_runner.gd", "test_base.gd"]:
			out.append(f)
	out.sort()
	return out


func _run_suite(fname: String) -> void:
	var script: GDScript = load(TEST_DIR.path_join(fname))
	if script == null:
		_failed += 1
		print("[FAIL] %s — cannot load script" % fname)
		print("::error file=%s::Cannot load test script %s" % [TEST_DIR.path_join(fname), fname])
		return
	var suite = script.new()
	suite.runner = self
	var methods: Array = []
	for m in script.get_script_method_list():
		if String(m["name"]).begins_with("test_"):
			methods.append(m["name"])
	for mname in methods:
		var before: int = suite.failures.size()
		suite.call(mname)
		if suite.failures.size() == before:
			_passed += 1
			print("[PASS] %s :: %s" % [fname, mname])
		else:
			_failed += 1
			print("[FAIL] %s :: %s" % [fname, mname])
			for i in range(before, suite.failures.size()):
				var msg = suite.failures[i]
				print("       - %s" % msg)
				# GitHub annotation - visible in PR checks UI
				print("::error file=%s::%s :: %s - %s" % [TEST_DIR.path_join(fname), mname, fname, msg])
