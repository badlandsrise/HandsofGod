extends Node
## Staging for tests/bot/m3_shots.gd.

const ALL := ["summer", "harvest", "threat", "region", "era"]
const OUT := "res://tests/shots"
const START := "res://tests/bot/era2_start.json"

var w: Node3D
var want: Array = ALL

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Waits `s` seconds of game time (software rendering under xvfb runs at a
## few frames a second, so real time says little), at most a minute.
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
	Game.flags["test"] = true      # after the world's _ready (no bot): name boxes accept themselves, the era card closes by itself
	if Clock.running == false:
		w.new_game()
		w.start_play()
	await _wait(0.5)
	var d = JSON.parse_string(FileAccess.get_file_as_string(START))
	if not (d is Dictionary):
		print("M3 SHOTS: no %s (run the bot with --save-gate first)" % START)
		OS.kill(OS.get_process_id())
		return
	Save.apply(d)
	Clock.running = true
	Clock.set_speed(1)
	Engine.time_scale = 1.0
	w.storm.skip()
	await _wait(0.5)
	_build_village()
	await _wait(10.0)         # the region banners and toasts fade
	if "summer" in want: await _summer()
	if "harvest" in want: await _harvest()
	if "threat" in want: await _threat()
	if "region" in want: await _region()
	if "era" in want: await _era()
	print("M3 SHOTS done")
	OS.kill(OS.get_process_id())

func _finished(bid: StringName, at: Vector2) -> Site:
	var s: Site = w.spawn_plot(bid, Vector3(at.x, 0, at.y))
	if s == null:
		return null
	for k in s.building.cost:
		s.delivered[k] = int(s.building.cost[k])
	s._finish(false)
	return s

## The village as it stands late in Era 2: every chain built, the fields sown.
func _build_village() -> void:
	Faith.grant(&"reach")
	Faith.grant(&"grip_3")
	Faith.grant(&"rain")
	w.look.set_weather(0.0, false)
	for bid in LayoutEra2.PLOT_SPOTS:
		if bid in [&"bridge", &"temple", &"watchtower"]:
			continue
		for spot in LayoutEra2.PLOT_SPOTS[bid]:
			if w.site_near(Vector3(spot.x, 0, spot.y), 2.5) == null:
				_finished(bid, spot)
	var stages := [Site.Field.RIPE, Site.Field.GROWING, Site.Field.SPROUTS, Site.Field.RIPE]
	var i := 0
	for s in Village.sites:
		if is_instance_valid(s) and s.is_field():
			s.moisture = 0.8
			s.field_grow = 0.7
			s._set_field_stage(stages[i % stages.size()])
			i += 1
	Flags.set_flag(&"hand_symbol")
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null:
			s.rebuild_visual()
	# put everyone to work around the village so it looks lived in
	var jobs: Array = Village.sites.filter(func(s): return is_instance_valid(s) and s.job != null and s.state == Site.State.FINISHED and not s.is_group() and s.global_position.length() < 110.0)
	var k := 0
	for p in Village.alive():
		if p.stage == Person.Stage.BABY or jobs.is_empty():
			continue
		var s: Site = jobs[k % jobs.size()]
		k += 1
		if s.can_accept(1):
			p.on_lifted()
			p.on_placed(s.slot_position(s.slot_of(p)), s)

func _midday(season: int) -> void:
	Clock.season = season
	Clock.season_t = Clock.season_seconds * 0.4
	Clock.is_night = false
	Clock.phase_t = Clock.day_seconds * 0.45
	Events.season_changed.emit(season)
	w.look.update_now()

func _summer() -> void:
	_midday(Clock.Season.SUMMER)
	await _wait(1.0)
	w.camera_rig.target_yaw = 0.35
	w.camera_rig.snap_to(Vector3(-2, w.ground_y(-2, 14), 14.0), 52.0)
	w.hand.aim_override = Vector3(-4, w.ground_y(-4, 30), 30)
	await _frames(40)
	await _shot("m3_village_summer.png")

func _harvest() -> void:
	_midday(Clock.Season.AUTUMN)
	var fields: Array = Village.sites.filter(func(s): return is_instance_valid(s) and s.is_field() and Vector2(s.global_position.x, s.global_position.z).length() < 120.0)
	var farmers: Array = Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT)
	var fi := 0
	for f in fields:
		f._set_field_stage(Site.Field.RIPE)
		for j in 2:
			if fi >= farmers.size():
				break
			var p: Person = farmers[fi]
			fi += 1
			p.on_lifted()
			p.on_placed(f.slot_position(f.slot_of(p)), f)
	await _wait(2.5)
	var c: Vector3 = fields[0].global_position if not fields.is_empty() else Vector3.ZERO
	w.camera_rig.target_yaw = -0.4
	w.camera_rig.snap_to(c + Vector3(6, 0, 4), 26.0)
	w.hand.aim_override = c + Vector3(14, 0, -4)
	await _frames(40)
	await _shot("m3_harvest.png")

func _threat() -> void:
	_midday(Clock.Season.SPRING)
	var t: Era2Threats = w.threats.era2
	t.reset()
	t.warn(&"flood")
	t._start()
	w.era2.set_flood(0.85)
	w.look.set_weather(0.7, false)
	# a few people caught by the water near the barn, one in the hand
	var near: Array = Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT).slice(0, 5)
	for i in near.size():
		var p: Person = near[i]
		p.go_idle()
		p.global_position = w._v3(Vector2(-10.0 + i * 3.0, 94.0 + (i % 2) * 2.0))
	await _wait(1.5)
	var at: Vector3 = w._v3(Vector2(-4.0, 92.0))
	w.camera_rig.target_yaw = 0.2
	w.camera_rig.snap_to(at, 34.0)
	w.hand.aim_override = at + Vector3(-3, 0, 0)
	await _frames(3)
	w.hand.lift_many(near.slice(0, 2))
	await _frames(40)
	await _shot("m3_threat_flood.png", 1)
	w.hand.place_on_ground(w._v3(Vector2(-6.0, 60.0)))
	t.reset()
	w.era2.set_flood(0.0)
	w.look.set_weather(0.0, false)
	await _frames(5)
	# the bear on the East Bank
	if not w.is_region_open(&"east_bank"):
		w.open_region(&"east_bank")
	t.warn(&"bears")
	t._start()
	var den: Vector3 = t.bear.den
	t.bear.global_position = w._v3(Vector2(178.0, 168.0))
	var camp: Vector3 = w._v3(LayoutEra2.CAMPS[&"east_bank"])
	var workers: Array = Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT).slice(6, 9)
	for i in workers.size():
		workers[i].go_idle()
		workers[i].global_position = camp + Vector3(4.0 + i * 1.5, 0, 6.0)
	await _wait(1.2)
	w.camera_rig.target_yaw = -0.3
	w.camera_rig.snap_to(camp + Vector3(8, 0, 10), 30.0)
	w.hand.aim_override = t.bear.global_position + Vector3(-2, 0, -2)
	await _frames(40)
	await _shot("m3_threat_bear.png", 1)
	t.reset()
	w.hand.aim_override = Vector3.INF

func _region() -> void:
	_midday(Clock.Season.SUMMER)
	Faith.grant(&"strength_2")
	var bs: Array = w.era2.boulders
	var rf: Vector3 = w._v3(LayoutEra2.ROCKFALL)
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(rf + Vector3(-6, 0, 2), 24.0)
	# the rockfall whole, the hand lifting its first boulder
	w.hand.aim_override = bs[0].global_position
	await _frames(6)
	w.hand.try_lift_object(bs[0])
	w.hand.aim_override = bs[0].global_position + Vector3(-5.0, 0, 2.0)
	await _frames(40)
	await _shot("m3_region_rockfall.png")
	w.hand.place_object(rf + Vector3(-11.0, 0, -4.0))
	await _frames(3)
	_clear_ui()
	w.camera_rig.target_yaw = -0.5
	w.camera_rig.snap_to(w._v3(Vector2(212.0, -78.0)), 70.0)
	for i in [1, 2]:
		bs[i].on_lifted()
		bs[i].on_placed(rf + Vector3(-11.0, 0, -4.0 + i * 5.0))
	await _frames(30)         # the Hill Quarry lightens; its banner is up
	await _shot("m3_region_open.png", 1, false)
	w.hand.aim_override = Vector3.INF

func _era() -> void:
	_midday(Clock.Season.SUMMER)
	var t: Site = _finished(&"temple", LayoutEra2.PLOT_SPOTS[&"temple"][0])
	Flags.set_flag(&"harvest_festival")
	await _wait(1.0)
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(t.global_position + Vector3(0, 0, 10), 30.0)
	await _frames(40)
	await _shot("m3_temple.png")
	Game.flags.erase("test")       # the card stays up (in tests it closes itself after 2 s)
	Village.stats["dream_active"] = "temple_of_the_hand"
	Dreams.complete(Defs.dream(&"temple_of_the_hand"))
	var r0 := Time.get_ticks_msec()
	while not (w.hud.era_card.is_open()) and Time.get_ticks_msec() - r0 < 300000:
		await get_tree().process_frame
	var r1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - r1 < 4000:     # the card fades in
		await get_tree().process_frame
	await _shot("m3_era_complete.png", 0, false)

## Clears the banners, alerts and toasts the staging raised (they live on
## real time, which crawls under software rendering), keeping `keep` alerts.
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
	w.camera_rig.tilt_shift = false     # crisp review shots (software DOF smears everything)
	_clear_ui(keep_alerts, banners)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])
