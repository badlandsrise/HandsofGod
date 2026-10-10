extends Node
## Staging for tests/bot/m4_shots.gd.

const ALL := ["town", "region", "harbour", "threat", "hall", "era"]
const OUT := "res://tests/shots"
const START := "res://tests/bot/era3_start.json"

var w: Node3D
var want: Array = ALL

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Waits `s` seconds of game time, at most a minute of real time.
func _wait(s: float) -> void:
	var t0 := Clock.total_t
	var r0 := Time.get_ticks_msec()
	while Clock.total_t - t0 < s and Time.get_ticks_msec() - r0 < 60000:
		await get_tree().process_frame

func run() -> void:
	Save.enabled = false
	if Game.flags.get("only") is String:
		want = str(Game.flags["only"]).split(",", false)
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await _frames(3)
	Game.flags["test"] = true
	if Clock.running == false:
		w.new_game()
		w.start_play()
	await _wait(0.5)
	var d = JSON.parse_string(FileAccess.get_file_as_string(START))
	if not (d is Dictionary):
		print("M4 SHOTS: no %s (run the bot with --save-gate first)" % START)
		OS.kill(OS.get_process_id())
		return
	Save.apply(d)
	Clock.running = true
	Clock.set_speed(1)
	Engine.time_scale = 1.0
	w.storm.skip()
	w.threats.era3.reset()
	await _wait(0.5)
	_build_town()
	await _wait(10.0)
	if "town" in want: await _town()
	if "region" in want: await _region()
	if "harbour" in want: await _harbour()
	if "threat" in want: await _threat()
	if "hall" in want: await _hall()
	if "era" in want: await _era()
	print("M4 SHOTS done")
	OS.kill(OS.get_process_id())

func _finished(bid: StringName, at: Vector2) -> Site:
	var s: Site = w.spawn_plot(bid, Vector3(at.x, 0, at.y))
	if s == null:
		return null
	for k in s.building.cost:
		s.delivered[k] = int(s.building.cost[k])
	s._finish(false)
	return s

## Finishes the plot already at `at` (the people may have wished for it), or a new one.
func _finish_at(bid: StringName, at: Vector2) -> Site:
	var s: Site = w.site_near(Vector3(at.x, 0, at.y), 3.0)
	if s == null or s.building == null or s.building.id != bid:
		return _finished(bid, at)
	if s.state != Site.State.FINISHED:
		for k in s.building.cost:
			s.delivered[k] = int(s.building.cost[k])
		s._finish(false)
	return s

## The town as it stands mid Era 3: the street of townhouses, the workshops,
## the school and the aqueduct running.
func _build_town() -> void:
	for id in [&"strong_arms", &"grip_3", &"grip_4", &"rain", &"warmth", &"calm_waters", &"guiding_light"]:
		Faith.grant(id)
	w.look.set_weather(0.0, false)
	for bid in LayoutEra3.PLOT_SPOTS:
		if bid in [&"great_hall", &"observatory", &"harbour", &"lighthouse"]:
			continue
		for spot in LayoutEra3.PLOT_SPOTS[bid]:
			if w.site_near(Vector3(spot.x, 0, spot.y), 2.5) == null:
				_finished(bid, spot)
	Flags.set_flag(&"hand_symbol")
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null:
			s.rebuild_visual()
	_to_work(Vector2(70.0, 0.0), 120.0)

## Puts everyone near `c` to work so the town looks lived in.
func _to_work(c: Vector2, r: float) -> void:
	var jobs: Array = Village.sites.filter(func(s): return is_instance_valid(s) and s.job != null and s.state == Site.State.FINISHED \
		and not s.is_group() and s.job.id not in [&"rest_at_clinic", &"astronomy", &"sail_islands"] \
		and Vector2(s.global_position.x, s.global_position.z).distance_to(c) < r)
	var k := 0
	for p in Village.alive():
		if p.stage == Person.Stage.BABY or jobs.is_empty():
			continue
		var s: Site = jobs[k % jobs.size()]
		k += 1
		if s.can_accept(1):
			p.on_lifted()
			p.on_placed(s.slot_position(s.slot_of(p)), s)

func _time(season: int, phase: float, night := false) -> void:
	Clock.season = season
	Clock.season_t = Clock.season_seconds * 0.4
	Clock.is_night = night
	Clock.phase_t = Clock.day_seconds * phase
	Events.season_changed.emit(season)
	w.look.update_now()

func _town() -> void:
	_time(Clock.Season.SUMMER, 0.45)
	await _wait(2.0)
	w.camera_rig.target_yaw = 0.25
	w.camera_rig.snap_to(w._v3(Vector2(96.0, 4.0)), 62.0)
	w.hand.aim_override = w._v3(Vector2(104.0, 20.0))
	await _frames(40)
	await _shot("m4_town_at_work.png")

func _region() -> void:
	_time(Clock.Season.SUMMER, 0.45)
	if not w.is_region_open(&"coast"):
		w.open_region(&"coast")
	await _frames(3)
	w.camera_rig.target_yaw = -0.6
	w.camera_rig.snap_to(w._v3(Vector2(340.0, 420.0)), 80.0)
	w.hand.aim_override = w._v3(LayoutEra3.ROUGH_SEA)
	await _frames(30)
	await _shot("m4_region_coast.png", 1, false)

func _harbour() -> void:
	if not w.is_region_open(&"coast"):
		w.open_region(&"coast")
	var h: Site = _finish_at(&"harbour", LayoutEra3.PLOT_SPOTS[&"harbour"][0])
	_finish_at(&"lighthouse", LayoutEra3.PLOT_SPOTS[&"lighthouse"][0])
	w.era3.ship_on_beach()
	await _frames(3)
	var ship = w.era3.ship
	ship.on_lifted()
	ship.on_placed(w._v3(LayoutEra3.SHIP_ANCHOR))
	_to_work(LayoutEra3.CAMPS[&"coast"], 60.0)
	# late afternoon on the coast, the ship riding at anchor
	_time(Clock.Season.SUMMER, 0.7)
	await _wait(1.5)
	var c: Vector3 = h.global_position if h != null else w._v3(LayoutEra3.PLOT_SPOTS[&"harbour"][0])
	var mid: Vector3 = (c + w._v3(LayoutEra3.SHIP_ANCHOR)) * 0.5
	w.camera_rig.target_yaw = -0.9
	w.camera_rig.snap_to(mid, 58.0)
	w.hand.aim_override = Vector3.INF
	await _frames(40)
	await _shot("m4_harbour_dusk.png")

func _threat() -> void:
	_time(Clock.Season.AUTUMN, 0.45)
	var t: Era3Threats = w.threats.era3
	t.reset()
	var target: Site = w.site_near(w._v3(Vector2(106.0, 14.0)), 3.0)
	if target == null or target.building == null or target.building.id != &"townhouse":
		target = null
		for s in Village.sites:
			if is_instance_valid(s) and s.building != null and s.building.id == &"townhouse" and s.state == Site.State.FINISHED:
				target = s
				break
	t.target = target
	t.warn(&"town_fire")
	t._start()
	if target != null:
		# the bucket line, set to it by the hand
		var line: Site = target.ensure_child_job(&"fight_fire")
		var folk: Array = Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT and not p.is_sick())
		folk.sort_custom(func(a, b): return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
		if line != null:
			for p in folk.slice(0, 4):
				if line.can_accept(1):
					p.on_lifted()
					p.on_placed(line.slot_position(line.slot_of(p)), line)
	await _wait(1.5)
	if target != null:
		target.burn = 0.8          # well alight when the shot is taken
		target._update_fire_fx()
	var at: Vector3 = target.global_position if target != null else w._v3(Vector2(100, 0))
	w.camera_rig.target_yaw = 0.3
	w.camera_rig.snap_to(at + Vector3(0, 0, 4), 44.0)
	w.hand.aim_override = at + Vector3(0, 0, -2)
	for i in 8:
		await _frames(5)
		if target != null and target.burn > 0.0:
			target.burn = 0.8
			target._update_fire_fx()
	await _shot("m4_threat_fire.png", 1)
	t.reset()
	if target != null and target.burn > 0.0:
		target.douse(2.0)
	w.hand.aim_override = Vector3.INF

func _hall() -> void:
	_time(Clock.Season.SUMMER, 0.4)
	var g: Site = _finished(&"great_hall", LayoutEra3.PLOT_SPOTS[&"great_hall"][0])
	Flags.set_flag(&"great_hall")
	w.era3.raise_flag()
	_to_work(Vector2(0.0, 0.0), 40.0)
	await _wait(1.5)
	var c: Vector3 = g.global_position if g != null else w._v3(LayoutEra3.PLOT_SPOTS[&"great_hall"][0])
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(c + Vector3(0, 0, 6), 50.0)
	w.hand.aim_override = c + Vector3(-16, 0, 16)   # keep the hand off the facade
	await _frames(40)
	await _shot("m4_great_hall.png")
	w.hand.aim_override = Vector3.INF

func _era() -> void:
	_time(Clock.Season.SUMMER, 0.0, true)
	var ob: Site = _finished(&"observatory", LayoutEra3.PLOT_SPOTS[&"observatory"][0])
	w.era3.northern_lights(60.0)
	await _wait(1.0)
	if ob != null:
		w.camera_rig.target_yaw = 0.0
		w.camera_rig.snap_to(ob.global_position + Vector3(0, 0, 10), 40.0)
	await _frames(40)
	await _shot("m4_observatory_night.png")
	Game.flags.erase("test")
	Village.stats["dream_active"] = "observatory"
	Dreams.complete(Defs.dream(&"observatory"))
	var r0 := Time.get_ticks_msec()
	while not (w.hud.era_card.is_open()) and Time.get_ticks_msec() - r0 < 300000:
		await get_tree().process_frame
	var r1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - r1 < 4000:
		await get_tree().process_frame
	await _shot("m4_era_complete.png", 0, false)

func _clear_ui(keep: int = 0, banners := true) -> void:
	var hud = w.hud
	if banners:
		for it in hud.notices._items:
			if is_instance_valid(it["node"]):
				it["node"].queue_free()
		hud.notices._items.clear()
	for list in [hud._toasts, hud._alerts]:
		while list.size() > (keep if list == hud._alerts else 0):
			var old: Dictionary = list.pop_front()
			if is_instance_valid(old["node"]):
				(old["node"] as Node).queue_free()

func _shot(file: String, keep_alerts: int = 0, banners := true) -> void:
	w.camera_rig.tilt_shift = false
	_clear_ui(keep_alerts, banners)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])
