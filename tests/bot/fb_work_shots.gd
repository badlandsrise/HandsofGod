extends SceneTree
## Workplace review screenshots (2026-10-10 feedback, worker C): the farmhouse
## with its fields, the hunting lodge with its hunters out at the deer, and
## the Call gesture gathering the idle round the hand. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -s tests/bot/fb_work_shots.gd -- --no-title [--only=farmhouse,lodge,call]
## Writes tests/shots/fb_work_*.png. The staging lives in fb_work_shot_cases.gd,
## loaded after the first frames so the autoloads exist when it compiles.

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		var c: Node = load("res://tests/bot/fb_work_shot_cases.gd").new()
		root.add_child(c)
		c.run()
	return false
