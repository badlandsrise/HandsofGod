extends SceneTree
## Base for the headless test runners. It fails fast instead of hanging:
## - if an autoload did not compile (usually a stale class cache after a merge:
##   run `godot --headless --path . --import` once), it quits with code 2;
## - if the suite runs past `time_limit` seconds of real time, it quits with 1.

var time_limit := 150.0
var _guard_t0 := Time.get_ticks_msec()
var _guard_checked := false

const AUTOLOADS := ["Events", "Defs", "Clock", "Faith", "Village", "Save", "Audio", "Game"]

## Call at the top of _process. Returns false when the run was stopped.
func guard() -> bool:
	if not _guard_checked:
		_guard_checked = true
		var bad: Array = []
		for a in AUTOLOADS:
			var n := root.get_node_or_null(a)
			if n == null or n.get_script() == null or not n.get_script().can_instantiate():
				bad.append(a)
		if not bad.is_empty():
			printerr("FAIL autoloads did not load: %s (stale import cache? run: godot --headless --path . --import)" % [bad])
			quit(2)
			return false
	if (Time.get_ticks_msec() - _guard_t0) / 1000.0 > time_limit:
		printerr("FAIL suite timed out after %d s" % int(time_limit))
		quit(1)
		return false
	return true
