extends "res://tests/shots/shot_director.gd"
## World review shots (locked regions, drops, layout, the Pass Road, desire paths).
## Attached by the world when Game.flags has "world-shots". Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -- \
##     --world-shots[=fog,drop,village1,village2,pass,paths] [--paths-save=path.json]
## Writes tests/shots/fb_world_*.png, then quits. --paths-save is a save written by
## the bot (tests/bot/bot.gd --save-day=12:path.json) after ~20 game minutes.

const WORLD_ALL := ["fog", "drop", "village1", "village2", "pass", "paths"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	var f: Dictionary = Game.flags
	want = WORLD_ALL
	if f.get("world-shots") is String:
		want = str(f["world-shots"]).split(",", false)
	if f.has("shot-dir"):
		out_dir = str(f["shot-dir"])
	_run.call_deferred()

func _run() -> void:
	var w = _w()
	await _wait(1.5)
	var t0 := Time.get_ticks_msec()
	w.camera_rig.tilt_shift = false
	await _to_day()
	_quiet_hud()
	_spread_people()
	if "fog" in want:
		w.camera_rig.target_yaw = 1.2
		w.camera_rig.snap_to(Vector3(-46.0, 0, 6.0), 58.0)
		w.hand.aim_override = Vector3(-30.0, w.ground_y(-30, 0), 0.0)
		await _settle(10)
		await _shot("fb_world_fog.png")
	if "drop" in want:
		await _drop_shot()
	if "village1" in want:
		_build_era1_village()
		w.camera_rig.target_yaw = 0.0
		w.camera_rig.snap_to(Vector3(-4.0, 0, 6.0), 62.0)
		w.hand.aim_override = Vector3(14.0, w.ground_y(14, 30), 30.0)
		await _settle(14)
		await _shot("fb_world_village_era1.png")
	if "village2" in want:
		await _era2_village()
	if "pass" in want:
		await _pass_shots()
	if "paths" in want:
		await _paths_shot()      # last: it loads the bot's save over this world
	print("SHOTS done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	OS.kill(OS.get_process_id())

## No cards in the way: the naming card and the banners are closed, the HUD
## hidden (the drop shot shows it again for the hand's tooltip).
func _quiet_hud() -> void:
	var w = _w()
	for i in 6:
		if w.hud != null and "naming" in w.hud and w.hud.naming != null:
			w.hud.naming._queue.clear()       # queued while the HUD was hidden
			if w.hud.naming.is_open():
				w.hud.naming.accept()
		if w.hud != null and w.hud.has_method(&"close_top_modal"):
			w.hud.close_top_modal()
	Clock.set_speed(1)
	Clock.running = true
	if w.hud != null:
		w.hud.visible = false

func _settle(n: int) -> void:
	_w().camera_rig.step(1.0)
	await _frames(n)

func _spread_people() -> void:
	var w = _w()
	for i in 4:
		w.spawn_person(Vector3(-8.0 + i * 3.0, 0, -2.0), ["Ura", "Mok", "Teo", "Lin"][i])

func _finish_plot(id: StringName, at: Vector2) -> Site:
	var w = _w()
	var s: Site = w.spawn_plot(id, Vector3(at.x, 0, at.y))
	if s != null:
		s._finish(true)
	return s

func _drop_shot() -> void:
	var w = _w()
	var hand = w.hand
	var people: Array = Village.alive().filter(func(p): return p.pickable()).slice(0, 3)
	w.camera_rig.target_yaw = 1.35
	w.camera_rig.snap_to(Vector3(-46.0, 0, 3.0), 30.0)
	hand.aim_override = people[0].global_position
	await _frames(2)
	hand.lift_many(people)
	var at := Vector3(-58.0, 0, 4.0)
	at.y = w.ground_y(at.x, at.z)
	hand.aim_override = at
	await _frames(3)
	hand.air_pos = hand.ground + Vector3(0, Hand.HOVER_H_HOLD, 0)
	w.camera_rig.snap_to(Vector3(-53.0, 0, 4.0), 28.0)
	_quiet_hud()
	w.hud.visible = true
	await _settle(8)
	print("SHOTS drop reason at %s: '%s'" % [at, hand.aim_drop_reason()])
	await _shot("fb_world_drop_red.png")
	w.hud.visible = false
	hand.aim_override = Vector3(-20.0, w.ground_y(-20, 0), 0.0)
	await _frames(2)
	hand.release_all()
	print("SHOTS after the drop shot the hand holds %d" % hand.held.size())
	hand.aim_override = Vector3(14.0, w.ground_y(14, 30), 30.0)

func _build_era1_village() -> void:
	for spot in LayoutEra1.PLOT_SPOTS[&"hut"]:
		_finish_plot(&"hut", spot)
	_finish_plot(&"fire_circle", LayoutEra1.PLOT_SPOTS[&"fire_circle"][0])
	_finish_plot(&"shrine", LayoutEra1.PLOT_SPOTS[&"shrine"][0])
	_finish_plot(&"food_store", LayoutEra1.PLOT_SPOTS[&"food_store"][0])
	_finish_plot(&"drying_rack", LayoutEra1.PLOT_SPOTS[&"drying_rack"][0])

func _era2_village() -> void:
	var w = _w()
	if not w.is_region_open(&"western_meadow"):
		w.open_region(&"western_meadow")
	if not w.is_region_open(&"valley_floor"):
		w.open_region(&"valley_floor")
	for lg in w.logs:
		lg.on_lifted()
		lg.on_placed(Vector3(-40.0, 0, -14.0 + lg.get_index() * 0.5))
	# the transition: camera pulled back, huts rebuilding as cottages
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.max_dist = 95.0
	w.camera_rig.snap_to(w.transition_focus(1), 75.0)
	if w.regions.has_method(&"sync_instant"):
		w.regions.sync_instant()
	w.rebuild_homes_on_screen(4.0)
	# the render here can run at a frame a second: step the show to a fixed
	# moment (two cottages up, one rising, one hut coming down) instead of waiting
	if w.home_rebuild != null:
		w.home_rebuild.process_mode = Node.PROCESS_MODE_DISABLED
		w.home_rebuild._t = 1.9
		w.home_rebuild._process(0.0)
		w.home_rebuild._process(0.0)
	await _frames(3)
	await _shot("fb_world_transition_rebuild.png")
	w.finish_home_rebuild()
	EraTransition.enter_era(2)
	await _frames(4)
	for i in 8:
		_finish_plot(&"cottage", LayoutEra2.PLOT_SPOTS[&"cottage"][i])
	for id in [&"well", &"granary"]:
		_finish_plot(id, LayoutEra2.PLOT_SPOTS[id][0])
	for i in 6:
		w.spawn_person(Vector3(-70.0 + i * 3.0, 0, 2.0), "")
	w.camera_rig.snap_to(Vector3(-6.0, 0, 6.0), 70.0)
	await _settle(14)
	await _shot("fb_world_village_era2.png")
	w.camera_rig.target_yaw = 0.5
	w.camera_rig.snap_to(Vector3(-74.0, 0, 2.0), 60.0)
	await _settle(14)
	await _shot("fb_world_village_era2_westend.png")

func _pass_shots() -> void:
	var w = _w()
	if not w.is_region_open(&"valley_floor"):
		w.open_region(&"valley_floor")
	await _frames(4)
	w.camera_rig.target_yaw = 0.55
	w.camera_rig.snap_to(Vector3(-6.0, 0, 48.0), 46.0)
	w.hand.aim_override = Vector3(10.0, w.ground_y(10, 30), 30.0)
	await _settle(12)
	await _shot("fb_world_pass_before.png")
	w.open_pass()
	w.pass_road._t = -1.0
	w.pass_road._set_cleared(1.0)        # the end of the roll (the render runs far below real time)
	await _frames(3)
	await _settle(8)
	await _shot("fb_world_pass_after.png")

## The desire paths after a long bot run: load its save and look down on the village.
func _paths_shot() -> void:
	var w = _w()
	var path := str(Game.flags.get("paths-save", ""))
	if path == "" or not FileAccess.file_exists(path):
		print("SHOTS no --paths-save, skipping the paths shot")
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		return
	Save.apply(d)
	_quiet_hud()
	w.storm.skip()
	Clock.is_night = false
	Clock.phase_t = 30.0
	w.look.set_weather(0.0, false)
	w.look.update_now()
	await _wait(1.0)
	w.paths.flush()
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.max_dist = 95.0
	w.camera_rig.snap_to(Vector3(0.0, 0, 2.0), 80.0)
	w.hand.aim_override = Vector3(30.0, w.ground_y(30, 30), 30.0)
	await _settle(14)
	var segs: Array = w.paths.busiest_segments(5)
	var lv := [0, 0, 0, 0, 0]
	for k in w.paths.wear.size():
		if w.paths.wear[k] > 0.0:
			lv[w.paths.level_at(Paths.RECT.position.x + k % Paths.W, Paths.RECT.position.y + k / Paths.W)] += 1
	print("SHOTS paths: day %d %s, cells by level %s, busiest %s" % [Clock.day, Clock.Season.keys()[Clock.season], str(lv), str(segs.map(func(s): return [s["id"], int(s["wear"])]))])
	if Clock.season == Clock.Season.WINTER:
		await _shot("fb_world_paths_winter.png")      # trodden into the snow
		Clock.season = Clock.Season.AUTUMN
		Clock.season_t = Clock.season_seconds * 0.3
		Clock.running = false
		w.look.update_now()
		await _settle(6)
	await _shot("fb_world_paths.png")
	w.camera_rig.snap_to(Vector3(-8.0, 0, -6.0), 40.0)
	await _settle(14)
	await _shot("fb_world_paths_close.png")
