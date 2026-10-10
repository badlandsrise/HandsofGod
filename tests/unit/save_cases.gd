extends Node
## Cases for tests/unit/test_save.gd.

signal done(fails: int)

const STUB := preload("res://tests/unit/save_stub.gd")

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

class BareWorld extends Node3D:
	var marker: String = ""
	func save_state() -> Dictionary: return {"marker": marker}
	func load_state(d: Dictionary, nodes: Array) -> void:
		marker = d.get("marker", "")
		for n in get_tree().get_nodes_in_group("persist"):
			if is_ancestor_of(n):
				remove_child(n); n.queue_free()
		Save.restore_nodes(self, nodes)

func run() -> void:
	var save: Node = Save
	save.dir = "user://test_saves"
	DirAccess.make_dir_recursive_absolute(save.dir)
	for f in DirAccess.get_files_at(save.dir):
		DirAccess.remove_absolute(save.dir.path_join(f))
	await _part1(save)
	await _part2(save)
	for f in DirAccess.get_files_at(save.dir):
		DirAccess.remove_absolute(save.dir.path_join(f))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)

func _part1(save: Node) -> void:
	var w := BareWorld.new()
	get_tree().root.add_child(w)
	Game.world = w
	w.marker = "hello"
	for i in 3:
		var n: Node3D = STUB.new()
		n.uid = 100 + i
		n.value = "stub%d" % i
		n.position = Vector3(i, 2, -i)
		w.add_child(n)
	Clock.day = 7; Clock.season = 2; Clock.total_t = 1234.5
	Faith.total = 42.0; Faith.spent = 10.0
	Village.stores = {&"berries": 9, &"wood": 4}
	Village.regions = {&"clearing": true, &"valley_floor": true}
	check(save.write("slot_1"), "write slot_1")
	check(save.exists("slot_1"), "slot_1 exists on disk")
	var info: Dictionary = save.slot_info("slot_1")
	check(int(info.get("day", 0)) == 7, "slot_info reports the day")
	# scramble everything
	Clock.day = 1; Clock.season = 0; Faith.total = 0.0; Village.stores = {}; Village.regions = {&"clearing": true}
	w.marker = ""
	for n in w.get_children():
		n.value = "changed"
	check(save.load_manual(1), "load_manual(1) returns true")
	await get_tree().process_frame
	var stubs: Array = w.get_children().filter(func(n): return n.get_script() == STUB and not n.is_queued_for_deletion())
	check(stubs.size() == 3, "3 stub nodes re-instanced (got %d)" % stubs.size())
	var vals: Array = stubs.map(func(n): return n.value)
	vals.sort()
	check(vals == ["stub0", "stub1", "stub2"], "stub values restored %s" % str(vals))
	var s1: Array = stubs.filter(func(n): return n.uid == 101)
	check(s1.size() == 1 and s1[0].position.is_equal_approx(Vector3(1, 2, -1)), "stub position restored")
	check(Clock.day == 7 and Clock.season == 2 and is_equal_approx(Clock.total_t, 1234.5), "clock restored")
	check(is_equal_approx(Faith.total, 42.0) and is_equal_approx(Faith.available(), 32.0), "faith restored")
	check(Village.store(&"berries") == 9 and Village.store(&"wood") == 4, "stores restored")
	check(Village.regions.has(&"valley_floor"), "regions restored")
	check(w.marker == "hello", "world state restored")
	# autosave rotation and the latest autosave
	save.autosave()
	var first: String = save.latest_autosave()
	save.autosave()
	var second: String = save.latest_autosave()
	check(first != "" and second != "" and first != second, "autosaves rotate (%s then %s)" % [first, second])
	check(not save.read("nope").size(), "missing slot reads empty")
	check(int(save.migrate({"version": 1}).get("version", 0)) == save.VERSION, "migrate stamps the current version")
	w.queue_free()
	Game.world = null
	await get_tree().process_frame

func _part2(save: Node) -> void:
	var t0 := Time.get_ticks_msec()
	var ws: PackedScene = load("res://scenes/world/world.tscn")
	var w: Node3D = ws.instantiate()
	get_tree().root.add_child(w)     # _ready builds the valley (not testing, so it shows the title)
	await get_tree().process_frame
	check(Game.world == w, "world registers as Game.world")
	w.new_game()
	await get_tree().process_frame
	var pop0 := Village.population()
	var sites0 := Village.sites.size()
	check(pop0 == 2, "new game has the two storm-night people (got %d)" % pop0)
	check(sites0 > 5, "new game spawned sites (%d)" % sites0)
	# play a little: lift the branch, open both regions
	w.branch.on_lifted(); w.branch.on_placed(w.branch.global_position + Vector3(6, 0, 4))
	for i in w.logs.size():
		w.logs[i].on_lifted(); w.logs[i].on_placed(Vector3(-56, 0, -10 + i * 3))
	check(Village.regions.has(&"western_meadow"), "moving the logs off the gap opens the Western Meadow")
	w.open_region(&"valley_floor")
	check(w.trunk.cleared, "opening the Valley Floor clears the trunk")
	Village.stores[&"berries"] = 5
	pop0 = Village.population()     # the meadow brought wanderers
	check(save.write("slot_2"), "write a real world save")
	var log0: Vector3 = w.logs[0].global_position
	# a new game resets everything, then loading brings it back
	w.new_game()
	await get_tree().process_frame
	check(not Village.regions.has(&"western_meadow") and not w.trunk.cleared, "new game resets regions and blockers")
	check(save.load_slot("slot_2"), "load the real world save")
	await get_tree().process_frame
	check(Village.regions.has(&"western_meadow") and Village.regions.has(&"valley_floor"), "regions restored after load")
	check(w.trunk.cleared and not w.trunk.visible, "trunk stays cleared after load")
	check(w.logs[0].global_position.distance_to(log0) < 0.1, "meadow log position restored")
	check(Village.population() == pop0, "people restored (%d)" % Village.population())
	check(Village.sites.size() >= sites0 - 1, "sites restored (%d of %d)" % [Village.sites.size(), sites0])
	check(Village.store(&"berries") == 5, "stores restored with the world")
	check(not w.storm.active(), "storm opening stays finished after load")
	var b: AABB = w.camera_bounds()
	check(b.size.x > 300.0, "camera bounds widened to three regions (%.0f m)" % b.size.x)
	print("world part took %d ms" % (Time.get_ticks_msec() - t0))
	w.queue_free()
	await get_tree().process_frame
