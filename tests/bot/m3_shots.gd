extends SceneTree
## M3 review screenshots of Era 2 (Village): the village in summer, the
## harvest, a threat (the flood and the bear), a region opening (the rockfall
## lifted, the Hill Quarry lightening) and the Era 2 complete card.
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -s tests/bot/m3_shots.gd -- --no-title [--only=summer,harvest]
## Starts from tests/bot/era2_start.json (the bot's save at the start of Era 2)
## and stages the rest. Writes tests/shots/m3_*.png.

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		var c: Node = load("res://tests/bot/m3_shot_cases.gd").new()
		root.add_child(c)
		c.run()
	return false
