extends "res://tests/guard_tree.gd"
## Workplaces and the calmer pacing (2026-10-10 feedback, worker C): the
## hunting lodge, the woodcutters' camp, the farmhouse with its fields, bin
## and carter, the Call gesture, the first fire circle round the fire, the
## second fire only for a bigger village, the elk only after the festival,
## Era 1's slower needs and trust, the heavier log haul, Era 2's den wolves and
## quarry bears. Run: godot --headless --path . -s tests/unit/test_work.gd
## The cases live in work_cases.gd, loaded after the first frame so the
## autoloads exist when the game scripts compile.

var _frame := 0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame == 2:
		time_limit = 200.0
		var c: Node = load("res://tests/unit/work_cases.gd").new()
		root.add_child(c)
		c.done.connect(func(fails: int): quit(1 if fails > 0 else 0))
		c.run()
	return false
