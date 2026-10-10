extends SceneTree
## M2 review screenshots: build stages of a hut, people held under the hand,
## winter in the village, the first festival, and the Era 1 complete pull-back.
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -s tests/bot/m2_shots.gd -- --no-title [--only=plots,held]
## Writes tests/bot/shots/m2_*.png. The staging lives in m2_shot_cases.gd,
## loaded after the first frames so the autoloads exist when it compiles.

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		var c: Node = load("res://tests/bot/m2_shot_cases.gd").new()
		root.add_child(c)
		c.run()
	return false
