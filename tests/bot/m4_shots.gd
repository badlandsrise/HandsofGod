extends SceneTree
## M4 review screenshots of Era 3 (Town): the town at work, the harbour at
## dusk with the ship on the sea, a threat (a town fire and its bucket line),
## a new region (the Coast opening), the great hall and the Era 3 card.
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -s tests/bot/m4_shots.gd -- --no-title [--only=town,harbour]
## Starts from tests/bot/era3_start.json (the bot's save at the start of Era 3)
## and stages the rest. Writes tests/shots/m4_*.png.

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		var c: Node = load("res://tests/bot/m4_shot_cases.gd").new()
		root.add_child(c)
		c.run()
	return false
