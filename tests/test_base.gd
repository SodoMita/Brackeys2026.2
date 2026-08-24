class_name TestBase
extends RefCounted
## Base class for test suites. Assertion failures are collected in `failures`;
## the runner checks the list after each test_ method.

var failures: Array = []
## Injected by the runner; gives integration tests access to the SceneTree.
var runner: SceneTree = null
## Nodes spawned during a test; auto-freed after each test_* method.
var _owned: Array = []


func assert_true(cond: bool, msg: String = "condition") -> void:
	if not cond:
		failures.append("expected TRUE — %s" % msg)


func assert_false(cond: bool, msg: String = "condition") -> void:
	if cond:
		failures.append("expected FALSE — %s" % msg)


func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
			if absf(float(a) - float(b)) > 0.0001:
				failures.append("expected '%s' == '%s' — %s" % [str(a), str(b), msg])
			return
	if a != b:
		failures.append("expected '%s' == '%s' — %s" % [str(a), str(b), msg])


func assert_ne(a: Variant, b: Variant, msg: String = "") -> void:
	if a == b:
		failures.append("expected '%s' != '%s' — %s" % [str(a), str(b), msg])


func assert_near(a: float, b: float, eps: float = 0.001, msg: String = "") -> void:
	if absf(a - b) > eps:
		failures.append("expected |%f - %f| <= %f — %s" % [a, b, eps, msg])


func assert_gt(a: float, b: float, msg: String = "") -> void:
	if not (a > b):
		failures.append("expected %f > %f — %s" % [a, b, msg])


func assert_ge(a: float, b: float, msg: String = "") -> void:
	if not (a >= b):
		failures.append("expected %f >= %f — %s" % [a, b, msg])


func assert_lt(a: float, b: float, msg: String = "") -> void:
	if not (a < b):
		failures.append("expected %f < %f — %s" % [a, b, msg])


func assert_le(a: float, b: float, msg: String = "") -> void:
	if not (a <= b):
		failures.append("expected %f <= %f — %s" % [a, b, msg])


func assert_not_null(v: Variant, msg: String = "value") -> void:
	if v == null:
		failures.append("expected non-null — %s" % msg)


func assert_null(v: Variant, msg: String = "value") -> void:
	if v != null:
		failures.append("expected null — %s" % msg)


func assert_has_method(obj: Object, method: String, msg: String = "") -> void:
	if obj == null or not obj.has_method(method):
		failures.append("expected method '%s' — %s" % [method, msg])


## Track a node for auto-cleanup after the current test.
func own(n: Node) -> Node:
	if n != null:
		_owned.append(n)
	return n


## Add child under the SceneTree root and track it.
func add_to_root(n: Node) -> Node:
	if runner and runner.root and n:
		runner.root.add_child(n)
		_owned.append(n)
	return n


func _cleanup() -> void:
	for n in _owned:
		if n != null and is_instance_valid(n):
			n.free()
	_owned.clear()
	# Sweep any leftover non-autoload children under root (tests must not leak).
	if runner and runner.root:
		var keep := {"Cfg": true, "Dialogic": true}
		for c in runner.root.get_children():
			if c != null and is_instance_valid(c) and not keep.has(String(c.name)):
				c.free()
