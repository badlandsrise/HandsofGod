extends SceneTree
## Save/load round trips: stub nodes under a bare world, then the real world.
## Run: godot --headless --path . -s tests/unit/test_save.gd
## The cases live in save_cases.gd, loaded after the first frame so the autoloads
## exist when the game scripts compile.

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 2:
		var c: Node = load("res://tests/unit/save_cases.gd").new()
		root.add_child(c)
		c.done.connect(func(fails: int): quit(1 if fails > 0 else 0))
		c.run()
	return false
