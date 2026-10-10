extends "res://tests/guard_tree.gd"
## Headless tests for the M2 UI: the naming flow (signals round trip, names
## applied, hand marks), the Village Book data model (family tree from mock
## people, the journal), the Chronicle, the era card summary, options and alerts.
## Run: godot --headless --path . -s tests/ui/test_ui.gd
## The cases live in ui_cases.gd, loaded after the first frames so the
## autoloads exist when the UI scripts compile.

var _frame := 0
var _cases

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame < 2:
		return false
	if _frame == 2:
		_cases = load("res://tests/ui/ui_cases.gd").new()
		_cases.start(self)
		return false
	if not _cases.finished:
		return false
	quit(1 if _cases.fails > 0 else 0)
	return false
