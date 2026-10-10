extends "res://tests/guard_tree.gd"
## Headless tests for the hand (grip, scoop, site overflow, weight, safe release,
## gestures, gifts, hover/tooltip/ghosts). Run:
##   godot --headless --path . -s tests/hand/test_hand.gd
## Prints PASS/FAIL lines; exits 1 on any failure.
## The tests live in hand_tests.gd and are loaded after the first frame so the
## autoloads (Events, Faith, ...) exist before the hand scripts compile.

var _frame := 0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame == 2:
		var t: Node = load("res://tests/hand/hand_tests.gd").new()
		root.add_child(t)
		t.run()
	return false
