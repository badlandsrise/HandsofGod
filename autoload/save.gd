extends Node
## Versioned JSON saves. Autoload state + every node in group "persist".
## A persisted node implements:
##   func save_state() -> Dictionary      (must include "scene": res path to re-instance, and "uid")
##   func load_state(d: Dictionary) -> void
## Autosave at each dawn and on quit: autosave_0..2 rotating, plus 3 manual slots.

const VERSION := 1
const DIR := "user://saves"
const AUTOSAVES := 3

var _auto_i: int = 0
var enabled: bool = true          # the bot turns this off

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	Events.day_started.connect(func(_d): if enabled: autosave())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled and Clock.running:
		autosave()

func autosave() -> void:
	write("autosave_%d" % _auto_i)
	_auto_i = (_auto_i + 1) % AUTOSAVES

func snapshot() -> Dictionary:
	var nodes: Array = []
	for n in get_tree().get_nodes_in_group("persist"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			nodes.append(n.save_state())
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"clock": Clock.save_state(),
		"faith": Faith.save_state(),
		"village": Village.save_state(),
		"world": Game.world.save_state() if Game.world and Game.world.has_method("save_state") else {},
		"nodes": nodes,
	}

func write(slot: String) -> bool:
	var f := FileAccess.open("%s/%s.json" % [DIR, slot], FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(snapshot()))
	return true

func exists(slot: String) -> bool:
	return FileAccess.file_exists("%s/%s.json" % [DIR, slot])

func read(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [DIR, slot]))
	return migrate(d) if d is Dictionary else {}

## One step per version bump: if d.version == 1: ...; d.version = 2
func migrate(d: Dictionary) -> Dictionary:
	return d

## Applies a snapshot to the running world. The world clears its dynamic
## nodes, then re-instances each saved node from its "scene" and calls load_state.
func apply(d: Dictionary) -> void:
	if d.is_empty():
		return
	Clock.load_state(d.get("clock", {}))
	Faith.load_state(d.get("faith", {}))
	Village.load_state(d.get("village", {}))
	if Game.world and Game.world.has_method("load_state"):
		Game.world.load_state(d.get("world", {}), d.get("nodes", []))

func load_slot(slot: String) -> bool:
	var d := read(slot)
	apply(d)
	return not d.is_empty()

func latest_autosave() -> String:
	var best := ""
	var best_t := 0
	for i in AUTOSAVES:
		var p := "%s/autosave_%d.json" % [DIR, i]
		if FileAccess.file_exists(p):
			var t := FileAccess.get_modified_time(p)
			if t > best_t:
				best_t = t; best = "autosave_%d" % i
	return best
