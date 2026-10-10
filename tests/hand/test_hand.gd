extends SceneTree
## Headless tests for the hand (grip, scoop, site overflow, weight, safe release,
## gestures, gifts, hover/tooltip/ghosts). Run:
##   godot --headless --path . -s tests/hand/test_hand.gd
## Prints PASS/FAIL lines; exits 1 on any failure.
## The tests live in hand_tests.gd and are loaded at runtime so the autoloads
## (Events, Faith, ...) exist before the hand scripts compile.

func _initialize() -> void:
	var t: Node = load("res://tests/hand/hand_tests.gd").new()
	root.add_child.call_deferred(t)
	t.ready.connect(func(): t.run(), CONNECT_ONE_SHOT)
