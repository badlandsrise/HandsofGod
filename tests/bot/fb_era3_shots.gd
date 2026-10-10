extends SceneTree
## [era3] Review screenshots of the Era 3 rework: the quarry floor (the mason's
## yard and the forge with their crews out on the ledges and seams), a paved
## street with masons at work, the town at work (a mill and a caravan at the
## market hall) and a fire at the forge with its bucket line.
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -s tests/bot/fb_era3_shots.gd -- --no-title [--only=quarry,paving]
## Starts from tests/bot/era3_start.json. Writes tests/shots/fb_era3_*.png.

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		var c: Node = load("res://tests/bot/fb_era3_shot_cases.gd").new()
		root.add_child(c)
		c.run()
	return false
