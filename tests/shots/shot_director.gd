extends Node
## Stages and captures the review screenshots (DESIGN 12.5: each kit is reviewed as
## screenshots). Attached by the world when Game.flags has "shots". Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -- --shots
## Optional: --shots=storm,day,hand,night,book (default all), --shot-dir=tests/shots
## Writes 01_storm_night.png, 02_day_clearing.png, 03_hand_group_job.png,
## 04_night_fire.png, 05_village_book.png, then quits.

const ALL := ["storm", "day", "hand", "night", "book"]

var out_dir := "res://tests/shots"
var want: Array = ALL

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	var f: Dictionary = Game.flags
	if f.get("shots") is String:
		want = str(f["shots"]).split(",", false)
	if f.has("shot-dir"):
		out_dir = str(f["shot-dir"])
	_run.call_deferred()

func _w():
	return Game.world

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _run() -> void:
	var w = _w()
	await _wait(1.5)
	var t0 := Time.get_ticks_msec()
	if "storm" in want:
		w.camera_rig.snap_to(w.cave_position() + Vector3(0, 0, 9.0), 26.0)
		await _wait(2.5)
		await _shot("01_storm_night.png")
	await _to_day()
	if "day" in want:
		w.camera_rig.snap_to(Vector3(-2.0, w.ground_y(-2, -12), -12.0), 28.0)
		await _wait(9.0)
		await _shot("02_day_clearing.png")
	if "hand" in want:
		await _hand_shot()
	if "night" in want:
		await _night_shot()
	if "book" in want:
		await _book_shot()
	print("SHOTS done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# llvmpipe teardown under xvfb can hang in quit(); the shots are on disk, so leave hard.
	OS.kill(OS.get_process_id())

## Past the storm: a sunny morning, a few more people, everyone at work.
func _to_day() -> void:
	var w = _w()
	if w.storm.active():
		w.branch.on_lifted()
		w.branch.on_placed(w.cave_position() + Vector3(7.0, 0, 6.0))
	w.storm.skip()
	w.storm.set_process(false)
	await _wait(0.5)
	w.look.set_weather(0.0, false)
	Clock.is_night = false
	Clock.day = 2
	Clock.phase_t = 22.0
	w.look.update_now()
	var names := ["Ama", "Bo", "Kesi", "Rin", "Tavi"]
	for i in names.size():
		w.spawn_person(Vector3(-4.0 + i * 1.8, 0, -8.0), names[i])
	Faith.grant(&"grip_2")
	var jobs := {&"gather_berries": 3, &"collect_sticks": 2, &"tend_fire": 1, &"fetch_water": 1}
	var people: Array = Village.alive().duplicate()
	people.reverse()
	for id in jobs:
		var n: int = jobs[id]
		for s in Village.sites:
			if n <= 0 or people.is_empty():
				break
			if is_instance_valid(s) and s.job != null and s.job.id == id and s.free_slots() > 0:
				var p: Person = people.pop_back()
				p.on_lifted()
				p.on_placed(s.global_position, s)
				n -= 1
	if w.fire:
		w.fire.add_fuel(1.0)
	Clock.running = true

func _hand_shot() -> void:
	var w = _w()
	var hand = w.hand
	var site: Site = w.trunk_site
	if site == null:
		for s in Village.sites:
			if is_instance_valid(s) and s.job != null and s.job.id == &"haul_log":
				site = s
	var idle: Array = []
	for p in Village.alive():
		if p.pickable() and p.job_site == null:
			idle.append(p)
	for p in Village.alive():
		if idle.size() >= 3:
			break
		if p.pickable() and not idle.has(p):
			idle.append(p)
	Faith.grant(&"grip_3")
	var focus: Vector3 = site.global_position if site else Vector3(40, 4, 2)
	w.camera_rig.snap_to(focus + Vector3(-6.0, 0, 4.0), 30.0)
	hand.aim_override = idle[0].global_position if not idle.is_empty() else focus
	await _wait(0.3)
	for p in idle.slice(0, 3):
		hand.try_lift(p)
	hand.aim_override = focus + Vector3(0.0, 0, 0.6)
	await _wait(1.6)
	await _shot("03_hand_group_job.png")
	hand.aim_override = Vector3.INF
	if site:
		hand.place_on_site(site)
	else:
		hand.release_all()

func _night_shot() -> void:
	var w = _w()
	Clock.is_night = true
	Clock.phase_t = 6.0
	if w.fire:
		w.fire.add_fuel(1.0)
	for s in Village.sites:
		if is_instance_valid(s) and s.is_fire():
			s.add_fuel(Site.FIRE_MAX_FUEL)
	w.look.update_now()
	w.camera_rig.snap_to(w.fire_position() + Vector3(0, 0, 2.0), 24.0)
	await _wait(5.0)
	await _shot("04_night_fire.png")
	Clock.is_night = false
	Clock.phase_t = 30.0
	w.look.update_now()

func _book_shot() -> void:
	var w = _w()
	w.camera_rig.snap_to(Vector3(0, 4, -8), 34.0)
	await _wait(1.0)
	w.hud.book.open_book()
	await _wait(1.0)
	await _shot("05_village_book.png")
	w.hud.book.close_book()

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s %s (fps %.0f)" % [path, "ok" if err == OK else "error %d" % err, Engine.get_frames_per_second()])
