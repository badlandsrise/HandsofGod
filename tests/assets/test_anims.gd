extends "res://tests/guard_tree.gd"
## Headless checks of the villager task animations, held and carried props, gifts, the
## wild animals' rigs and gaits, the two-person log carry and the hand's scoop pose.
##   godot --headless --path . -s res://tests/assets/test_anims.gd
## The cases live in anims_cases.gd, loaded after the first frames so the autoloads
## (Audio, Village, Defs...) exist when the game scripts compile. Exits 1 on any failure.

var _frame := 0
var _cases

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame < 2:
		return false
	if _frame == 2:
		_cases = load("res://tests/assets/anims_cases.gd").new()
		_cases.run(self)
		return false
	if _frame < 8:
		return false
	if _frame == 8:
		_cases.late()
		return false
	var fails: int = _cases.finish()
	quit(1 if fails > 0 else 0)
	return false
