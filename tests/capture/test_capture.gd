extends "res://tests/guard_tree.gd"
## Headless test of the marketing capture mode (scripts/capture/, docs/CAPTURE.md):
##   1. `--capture --era=1|2|3` loads each bundled start state (no splash,
##      title or intro; saves off; the capture keys lifted from the game's);
##   2. camera presets from data/capture/cameras.json, the matching valley
##      views (the same framing in every era), a timed move;
##   3. hide-UI (and hand-visible), the F1 card, pause, time of day, season;
##   4. reset puts the valley back to its start state;
##   5. both demos, sped up and short, through the real hand, people and jobs;
##   6. the SPOILER entry: the goodbye with capture presets and reset.
## Run: godot --headless --path . -s tests/capture/test_capture.gd

var _frame := 0
var _cases

func _initialize() -> void:
	time_limit = 900.0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame < 2:
		return false
	if _frame == 2:
		_cases = load("res://tests/capture/capture_cases.gd").new()
		_cases.start(self)
		return false
	if not _cases.finished:
		return false
	quit(1 if _cases.fails > 0 else 0)
	return false
