extends "res://tests/bot/m4_shot_cases.gd"
## [era3] Staging for tests/bot/fb_era3_shots.gd (helpers from m4_shot_cases.gd).

const FB := ["paving", "town", "fire"]      # "quarry" (--only=quarry) still loses its camera to life events

func run() -> void:
	Save.enabled = false
	want = FB
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
	Save.apply(JSON.parse_string(FileAccess.get_file_as_string(START)))
	Clock.running = true
	Clock.set_speed(1)
	Engine.time_scale = 1.0
	w.storm.skip()
	w.threats.enabled = false
	w.threats.era3.reset()
	await _wait(0.5)
	w.village_ai.era3.setup()
	_build_town()
	await _wait(6.0)
	if "quarry" in want: await _quarry()
	if "paving" in want: await _paving()
	if "town" in want: await _town3()
	if "fire" in want: await _fire3()
	print("FB ERA3 SHOTS done")
	OS.kill(OS.get_process_id())

func _site(bid: StringName) -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == bid and s.state == Site.State.FINISHED:
			return s
	return null

## Sets `n` people from the town onto workplace `s` (and one on its cart).
func _crew(s: Site, n: int) -> void:
	if s == null:
		return
	var folk: Array = Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT and p.state != Person.S.HELD)
	folk.sort_custom(func(a, b): return a.global_position.distance_squared_to(s.global_position) < b.global_position.distance_squared_to(s.global_position))
	var k := 0
	for p in folk:
		if k >= n or not s.can_accept(1):
			break
		if p.job_site == s:
			continue
		p.on_lifted()
		p.global_position = s.slot_position(s.slots_filled())
		p.on_placed(p.global_position, s)
		p._land()
		k += 1
	for c in Village.sites:
		if is_instance_valid(c) and c.parent_uid == s.uid and c.job != null and c.job.id == &"cart_haul" and c.can_accept(1) and k < folk.size():
			var q: Person = folk[folk.size() - 1 - k]
			q.on_lifted()
			q.global_position = c.slot_position(0)
			q.on_placed(q.global_position, c)
			q._land()

func _quarry() -> void:
	_time(Clock.Season.SUMMER, 0.4)
	Village.stores[&"charcoal"] = 30
	Village.stores[&"stone"] = 40
	var m := _site(&"mason")
	var f := _site(&"forge")
	await _wait(20.0)          # the paths settle after the load
	_crew(m, 6)
	_crew(f, 6)
	print("FB quarry crews: yard %d, forge %d" % [m.slots_filled() if m else -1, f.slots_filled() if f else -1])
	Clock.set_speed(3)
	await _wait(60.0)          # they walk up to the ledges and the seams
	Clock.set_speed(1)
	# from the west, looking up the quarry face: the yard and the forge on the
	# floor, the crews out on the ledges and the seams
	w.camera_rig.target_yaw = -0.9
	w.camera_rig.snap_to(w._v3(Vector2(204.0, -106.0)), 40.0)
	w.hand.aim_override = w._v3(Vector2(176.0, -70.0))
	await _frames(40)
	await _shot("fb_era3_quarry.png")
	w.hand.aim_override = Vector3.INF

func _paving() -> void:
	_time(Clock.Season.SUMMER, 0.5)
	var paths = w.paths
	# the town street, walked into a road, and its busiest stretches laid in stone
	paths.stamp_line([Vector2(60.0, 1.0), Vector2(160.0, 1.0)], 70.0, 1.6)
	paths.stamp_line([Vector2(100.0, 1.0), Vector2(100.0, -26.0)], 50.0, 1.2)
	for x in range(64, 128, 8):
		paths.pave(Paving.segment_id(Vector3(float(x), 0, 1.0)))
	paths.flush()
	var m := _site(&"mason")
	_crew(m, 4)
	Village.stores[&"blocks"] = 80
	var stake: Site = w.spawn_site(Paving.JOB, Vector3(132.0, 0, 1.0))
	await _wait(1.0)
	# two masons at the stakes, mid-work
	var k := 0
	for p in m.workers:
		if k >= 2 or not is_instance_valid(p) or stake == null:
			break
		Workplace.claim(m, stake, p)
		p.task_site = stake
		p._phase = "work"
		p.global_position = Workplace.task_spot(m, stake, p)
		Workplace._show_task(p, m, stake)
		k += 1
	await _wait(2.0)
	w.camera_rig.target_yaw = 0.2
	w.camera_rig.snap_to(w._v3(Vector2(118.0, 4.0)), 46.0)
	w.hand.aim_override = w._v3(Vector2(140.0, 16.0))
	await _frames(40)
	await _shot("fb_era3_paving.png")
	w.hand.aim_override = Vector3.INF

func _town3() -> void:
	_time(Clock.Season.SUMMER, 0.45)
	var hall := _site(&"market_hall")
	if hall != null:
		_crew(hall, 2)
		Village.stores[&"bread"] = 150
		Village.stats["caravan_next"] = Clock.total_t - 1.0
		w.village_ai.era3._caravans()
	_crew(_site(&"watermill"), 3)
	await _wait(3.0)
	w.camera_rig.target_yaw = 0.25
	w.camera_rig.snap_to(w._v3(Vector2(96.0, -8.0)), 64.0)
	w.hand.aim_override = w._v3(Vector2(104.0, 20.0))
	await _frames(40)
	await _shot("fb_era3_town.png", 1)
	w.hand.aim_override = Vector3.INF

func _fire3() -> void:
	_time(Clock.Season.AUTUMN, 0.45)
	var t: Era3Threats = w.threats.era3
	t.reset()
	var target := _site(&"forge")
	t.target = target
	t.warn(&"town_fire")
	await _wait(1.0)
	t._start()
	if target != null:
		var line: Site = target.ensure_child_job(&"fight_fire")
		var folk: Array = Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT and not p.is_sick())
		folk.sort_custom(func(a, b): return a.global_position.distance_squared_to(target.global_position) < b.global_position.distance_squared_to(target.global_position))
		if line != null:
			for p in folk.slice(0, 4):
				if line.can_accept(1):
					p.on_lifted()
					p.global_position = line.slot_position(line.slot_of(p))
					p.on_placed(p.global_position, line)
	await _wait(1.5)
	if target != null:
		target.burn = 0.8
		target._update_fire_fx()
	var at: Vector3 = target.global_position if target != null else w._v3(Vector2(186, -122))
	w.camera_rig.target_yaw = 0.3
	w.camera_rig.snap_to(at + Vector3(0, 0, 4), 44.0)
	w.hand.aim_override = at + Vector3(-6, 0, 8)
	for i in 8:
		await _frames(5)
		if target != null and target.burn > 0.0:
			target.burn = 0.8
			target._update_fire_fx()
	await _shot("fb_era3_fire.png", 1)
	t.reset()
	w.hand.aim_override = Vector3.INF
