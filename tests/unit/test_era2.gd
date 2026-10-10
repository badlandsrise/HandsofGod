extends "res://tests/guard_tree.gd"
## Era 2 (Village): the transition from Era 1, the farming and craft economy,
## raising crews, the new regions (Reach, Rain, the rockfall), the bridge, the
## Era 2 threats with their counterplay, trust made visible, and save/load of
## all of it. Run: godot --headless --path . -s tests/unit/test_era2.gd
## The cases live in era2_cases.gd, loaded after the first frame so the
## autoloads exist when the game scripts compile.

var _frame := 0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame == 2:
		time_limit = 200.0
		var c: Node = load("res://tests/unit/era2_cases.gd").new()
		root.add_child(c)
		c.done.connect(func(fails: int): quit(1 if fails > 0 else 0))
		c.run()
	return false
