extends "res://tests/guard_tree.gd"
## Headless test of the front-end flow, with skips:
##   boot -> studio splash (skipped by a key) -> world + title (no save: no
##   Continue) -> New Game -> intro (skipped) -> storm night in play, then
##   lifting the branch brings the naming card for the first two; the intro
##   also runs to its end on its own (time-scaled), and with Options
##   "skip_intros" New Game goes straight to the storm night.
## Run: godot --headless --path . -s tests/front/test_front.gd
## The cases live in front_cases.gd, loaded after the first frames so the
## autoloads exist when the front-end scripts compile.

var _frame := 0
var _cases

func _initialize() -> void:
	time_limit = 240.0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame < 2:
		return false
	if _frame == 2:
		_cases = load("res://tests/front/front_cases.gd").new()
		_cases.start(self)
		return false
	if not _cases.finished:
		return false
	quit(1 if _cases.fails > 0 else 0)
	return false
