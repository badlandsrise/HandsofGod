extends "res://tests/guard_tree.gd"
## The onboarding beats of doc 11.4 happen in order in a real world, played
## through the hand's API; then Era 1 progression rules (dreams, powers,
## blessing, safety net, baby prayer, era transition) as unit checks.
## Run: godot --headless --path . -s tests/unit/test_onboarding.gd
## The cases live in onboarding_cases.gd, loaded after the first frame so the
## autoloads exist when the game scripts compile.

var _frame := 0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame == 2:
		time_limit = 240.0
		var c: Node = load("res://tests/unit/onboarding_cases.gd").new()
		root.add_child(c)
		c.done.connect(func(fails: int): quit(1 if fails > 0 else 0))
		c.run()
	return false
