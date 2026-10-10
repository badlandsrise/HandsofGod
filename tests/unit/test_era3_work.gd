extends "res://tests/guard_tree.gd"
## [era3] Era 3 workplaces: the mason's yard on the quarry floor (ledges, its
## bench, paving), the forge (iron seams, its bench), the mills fetching the
## farmhouses' grain, a master calling helpers to a workplace, suggestions one
## at a time, old saves' workshops becoming workplaces, and paving the busiest
## road. Run: godot --headless --path . -s tests/unit/test_era3_work.gd
## The cases live in era3_work_cases.gd.

var _frame := 0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame == 2:
		time_limit = 300.0
		var c: Node = load("res://tests/unit/era3_work_cases.gd").new()
		root.add_child(c)
		c.done.connect(func(fails: int): quit(1 if fails > 0 else 0))
		c.run()
	return false
