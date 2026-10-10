extends "res://tests/guard_tree.gd"
## Headless unit tests for people, sites, data and village AI.
## Run: godot --headless --path . -s tests/unit/test_people.gd
## Spawns on flat ground with no world, and steps the sim by hand
## (Person.sim + Person.motion + Site.sim) so no real time passes.
## The cases live in people_cases.gd, loaded after the first frame so the
## autoloads (Village, Defs...) exist when the game scripts compile.

var _frame := 0
var _cases

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame < 2:
		return false
	if _frame == 2:
		_cases = load("res://tests/unit/people_cases.gd").new()
		_cases.run(self)
		_cases.smoke_setup()      # then a short live run with real frames
		return false
	if _frame == 60:
		_cases.smoke_night()
	if _frame == 120:
		_cases.smoke_day()
	if _frame < 200:
		return false
	var fails: int = _cases.smoke_finish()
	quit(1 if fails > 0 else 0)
	return false
