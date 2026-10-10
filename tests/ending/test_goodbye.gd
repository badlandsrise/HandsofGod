extends "res://tests/guard_tree.gd"
## Headless test of the goodbye (DESIGN 9), on the generated Era 4 setup that
## `--goodbye` uses:
##   1. the cast: a crew of four living descendants of the first two, the
##      commander the most trusting; last words and memories from the Book;
##   2. every beat in order, with skips: the countdown runs only while held and
##      pauses gently (cue_level) when let go; the credits cannot be skipped the
##      first time; it ends in free play at dawn with the crew among the stars
##      and nobody dead;
##   3. the whole sequence played through by the autopilot, sped up, with the
##      credits skippable the second time.
## Run: godot --headless --path . -s tests/ending/test_goodbye.gd

var _frame := 0
var _cases

func _initialize() -> void:
	time_limit = 300.0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame < 2:
		return false
	if _frame == 2:
		_cases = load("res://tests/ending/goodbye_cases.gd").new()
		_cases.start(self)
		return false
	if not _cases.finished:
		return false
	quit(1 if _cases.fails > 0 else 0)
	return false
