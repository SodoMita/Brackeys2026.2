class_name TestBase
extends RefCounted
## Base class for test suites. Assertion failures are collected in `failures`;
## the runner checks the list after each test_ method.

var failures: Array = []
## Injected by the runner; gives integration tests access to the SceneTree.
var runner: SceneTree = null


func assert_true(cond: bool, msg: String = "condition") -> void:
	if not cond:
		failures.append("expected TRUE — %s" % msg)


func assert_false(cond: bool, msg: String = "condition") -> void:
	if cond:
		failures.append("expected FALSE — %s" % msg)


func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
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
