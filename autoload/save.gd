extends Node
## Versioned JSON saves. Autoload state + every node in group "persist".
## A persisted node implements:
##   func save_state() -> Dictionary      (must include "scene": res path to re-instance, and "uid")
##   func load_state(d: Dictionary) -> void
## Autosave at each dawn and on quit: autosave_0..2 rotating, plus 3 manual
## slots (slot_1..slot_3) and a quicksave ("quick").

const VERSION := 1
const DIR := "user://saves"
const AUTOSAVES := 3
const MANUAL_SLOTS := 3

var _auto_i: int = 0
var enabled: bool = true          # the bot turns this off
var dir: String = DIR             # tests point this elsewhere
var last_applied: Dictionary = {} # the snapshot most recently applied (world reads its clock)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Events.day_started.connect(func(_d): if enabled and Clock.running: autosave())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled and Clock.running:
		autosave()

func _path(slot: String) -> String:
	return "%s/%s.json" % [dir, slot]

func autosave() -> void:
	# continue the rotation after the newest existing autosave
	var latest := latest_autosave()
	if latest != "":
		_auto_i = (int(latest.trim_prefix("autosave_")) + 1) % AUTOSAVES
	write("autosave_%d" % _auto_i)
	_auto_i = (_auto_i + 1) % AUTOSAVES

func manual_slot(i: int) -> String:
	return "slot_%d" % clampi(i, 1, MANUAL_SLOTS)

func save_manual(i: int) -> bool:
	return write(manual_slot(i))

func load_manual(i: int) -> bool:
	return load_slot(manual_slot(i))

func snapshot() -> Dictionary:
	var nodes: Array = []
	for n in get_tree().get_nodes_in_group("persist"):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and n.has_method("save_state"):
			var st = n.save_state()
			if st is Dictionary and not st.is_empty():
				if not st.has("scene"):
					st["scene"] = _scene_of(n)
				nodes.append(st)
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"saved_unix": Time.get_unix_time_from_system(),
		"summary": {"day": Clock.day, "year": Clock.year, "season": Clock.season, "era": Village.era,
			"population": Village.population(), "faith": Faith.total},
		"clock": Clock.save_state(),
		"faith": Faith.save_state(),
		"village": Village.save_state(),
		"world": Game.world.save_state() if Game.world and Game.world.has_method("save_state") else {},
		"nodes": nodes,
	}

## Best guess at how to re-instance a node that did not say: its scene file,
## else its script.
func _scene_of(n: Node) -> String:
	if n.scene_file_path != "":
		return n.scene_file_path
	var s: Script = n.get_script()
	return s.resource_path if s else ""

func write(slot: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(snapshot()))
	f.close()
	return true

func exists(slot: String) -> bool:
	return FileAccess.file_exists(_path(slot))

func delete(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(_path(slot))

func read(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	return migrate(d) if d is Dictionary else {}

## Short description for the Load menu: {saved_at, day, era, population} or {}.
func slot_info(slot: String) -> Dictionary:
	var d := read(slot)
	if d.is_empty():
		return {}
	var info: Dictionary = d.get("summary", {}).duplicate()
	info["saved_at"] = d.get("saved_at", "")
	if not info.has("day"):
		info["day"] = d.get("clock", {}).get("day", 1)
	return info

## One step per version bump: if d.version == 1: ...; d.version = 2
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v > VERSION:
		push_warning("Save is from a newer version (%d > %d); loading what we can." % [v, VERSION])
	d["version"] = VERSION
	return d

## Applies a snapshot to the running world. The world clears its dynamic
## nodes, then re-instances each saved node from its "scene" and calls load_state.
func apply(d: Dictionary) -> void:
	if d.is_empty():
		return
	last_applied = d
	Clock.load_state(d.get("clock", {}))
	Faith.load_state(d.get("faith", {}))
	Village.load_state(d.get("village", {}))
	if Game.world and Game.world.has_method("load_state"):
		Game.world.load_state(d.get("world", {}), d.get("nodes", []))
	else:
		restore_nodes(get_tree().current_scene if get_tree().current_scene else get_tree().root, d.get("nodes", []))

func load_slot(slot: String) -> bool:
	var d := read(slot)
	apply(d)
	return not d.is_empty()

## Re-instances saved nodes under `parent` from each entry's "scene" (a
## PackedScene or a script path), adds them to the tree, then calls
## load_state: sites first, then everything else, so people can resolve the
## site they work at. Returns the new nodes.
func restore_nodes(parent: Node, nodes: Array) -> Array:
	var made: Array = []      # [node, dict]
	for nd in nodes:
		if not (nd is Dictionary):
			continue
		var path := str(nd.get("scene", ""))
		var n := _instance(path)
		if n == null:
			push_warning("Save: cannot re-instance '%s'; skipped." % path)
			continue
		parent.add_child(n)
		made.append([n, nd])
	made.sort_custom(func(a, b): return _order(a[0]) < _order(b[0]))
	var out: Array = []
	for pair in made:
		var n: Node = pair[0]
		if is_instance_valid(n) and n.has_method("load_state"):
			n.load_state(pair[1])
		out.append(n)
	return out

func _order(n: Node) -> int:
	if n.is_in_group("sites") or n is Site:
		return 0
	if n.is_in_group("people") or n is Person:
		return 2
	return 1

func _instance(path: String) -> Node:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var r = load(path)
	if r is PackedScene:
		return r.instantiate()
	if r is Script and r.can_instantiate():
		var o = r.new()
		return o if o is Node else null
	return null

func latest_autosave() -> String:
	var best := ""
	var best_t := -1.0
	for i in AUTOSAVES:
		var slot := "autosave_%d" % i
		if not exists(slot):
			continue
		var t := float(FileAccess.get_modified_time(_path(slot)))
		var d := read(slot)
		t = maxf(t, float(d.get("saved_unix", 0.0)))
		if t > best_t:
			best_t = t; best = slot
	return best
