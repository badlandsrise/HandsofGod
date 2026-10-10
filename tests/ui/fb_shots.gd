extends SceneTree
## Playtest-feedback UI screenshots (worker A's clarity pass): the goal
## checklist, the dream card, power lock reasons, blessing rings, a birth
## alert, the festival guidance beat, and the pause menu's Save page.
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -s tests/ui/fb_shots.gd -- --no-title [--only=locks,goal]
## Writes tests/shots/fb_ui_*.png. The staging lives in fb_shot_cases.gd,
## loaded after the first frames so the autoloads exist when it compiles.

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		var c: Node = load("res://tests/ui/fb_shot_cases.gd").new()
		root.add_child(c)
		c.run()
	return false
