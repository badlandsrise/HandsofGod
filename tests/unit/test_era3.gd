extends "res://tests/guard_tree.gd"
## Era 3 (Town): the town laid out from the Era 2 village, the three dreams
## (school, aqueduct, observatory), the new powers (Grip IV, Calm Waters,
## Lift Buildings, Guiding Light) and what each opens, the Coast and the ship,
## foremen and schooling, the town fire, sickness and storms with their
## counterplay, trust made visible, the gate to Era 4, and save/load.
## Run: godot --headless --path . -s tests/unit/test_era3.gd
## The cases live in era3_cases.gd, loaded after the first frame so the
## autoloads exist when the game scripts compile.

var _frame := 0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame == 2:
		time_limit = 240.0
		var c: Node = load("res://tests/unit/era3_cases.gd").new()
		root.add_child(c)
		c.done.connect(func(fails: int): quit(1 if fails > 0 else 0))
		c.run()
	return false
