extends RefCounted
## The cases for tests/capture/test_capture.gd (loaded once the autoloads exist).

var tree: SceneTree
var fails := 0
var finished := false
var w: Node = null
var cap: Node = null

func start(t: SceneTree) -> void:
	tree = t
	_run()

func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		printerr("FAIL ", what)

func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame

func _until(cond: Callable, limit_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > limit_s:
			return false
		await tree.process_frame
	return true

func _cam() -> Camera3D:
	return tree.root.get_viewport().get_camera_3d()

func _run() -> void:
	Game.flags["capture"] = true
	Game.flags["era"] = "1"
	Game.flags["seed"] = "3"
	w = load("res://scenes/world/world.tscn").instantiate()
	tree.root.add_child(w)
	tree.current_scene = w
	cap = w.get_node_or_null(^"Capture")
	check(cap != null, "--capture: the world attaches the capture director")
	if cap == null:
		finished = true
		return
	var got := await _until(func(): return cap.loaded, 120.0)
	check(got, "--capture --era=1: the start state loads")
	await _frames(3)
	await _launch()
	await _cameras()
	await _controls()
	await _reset()
	await _demos()
	await _spoiler()
	cap.stop_demo()
	finished = true

# ---------------------------------------------------------------- 1. launch

func _launch() -> void:
	check(Village.era == 1 and Village.population() >= 8 and Village.count_buildings(&"hut") >= 2 and w.fire_lit(),
		"era 1: mid-era Clearing: huts, a lit fire, %d people" % Village.population())
	check(not w.title_camera.current and Clock.running, "no title: the play camera is live and the clock runs")
	check(not Save.enabled, "saves are off in capture mode (the player's valley is never written)")
	var speed_keys := InputMap.action_get_events(&"speed_1").filter(func(e): return e is InputEventKey and e.physical_keycode == KEY_1)
	check(speed_keys.is_empty(), "the number keys are capture's (no longer the game speed)")
	check(Clock.process_priority < -90, "the capture clock runs straight after Clock (frame-exact real_delta)")
	check(tree.root.get_child(tree.root.get_child_count() - 1).name == "CaptureInput", "capture keys are read before the game's (last child of the root)")
	check(w.threats.enabled == false, "threats are off unless --threats")
	for e in [2, 3]:
		cap.load_era(e, false)
		await _frames(4)
		check(Village.era == e and Village.population() >= 15, "--era=%d: its bundled start state (%d people)" % [e, Village.population()])
	cap.load_era(1, false)
	await _frames(4)

# ---------------------------------------------------------------- 2. cameras

func _cameras() -> void:
	check(cap.cam.name_for_key(1) == "valley_wide" and cap.cam.name_for_key(9) != "", "keys 1-9 map to presets and moves from cameras.json")
	var names: Array = cap.cam.presets().keys()
	check(names.has("valley_wide") and names.has("village_close") and names.has("fire_green") and names.has("river") and names.has("workplace") and names.has("hero_low"),
		"presets: valley wide, village close, fire/green, river, workplace, hero low")
	var xf: Dictionary = {}
	for e in [1, 2, 3]:
		if e != Village.era:
			cap.load_era(e, true)
		check(cap.cam.go("valley_wide", e), "preset valley_wide in era %d" % e)
		await _frames(3)
		xf[e] = _cam().global_transform
	var same: bool = (xf[1] as Transform3D).is_equal_approx(xf[2]) and (xf[2] as Transform3D).is_equal_approx(xf[3])
	check(same, "matching valley views: valley_wide frames the same shot in Eras 1, 2 and 3")
	var w1: Dictionary = cap.cam.preset_spec("workplace", 1)
	var w3: Dictionary = cap.cam.preset_spec("workplace", 3)
	check(w1["focus"] != w3["focus"], "the workplace preset moves to the era's own work (Era 3: the smithies)")
	# a move: fixed duration, eased, repeatable
	cap.cam.go("orbit_fire", 3)
	var y0 := float(cap.cam.spec["yaw_deg"])
	cap.cam.step(15.0)
	var ymid := float(cap.cam.spec["yaw_deg"])
	cap.cam.step(100.0)
	check(is_equal_approx(y0, -60.0) and absf(ymid) < 0.5 and is_equal_approx(float(cap.cam.spec["yaw_deg"]), 60.0) and cap.cam.move_done(),
		"orbit_fire: 30 s from -60 to +60 degrees, halfway at the middle (%.1f)" % ymid)
	cap.cam.release()
	await _frames(2)
	check(cap.cam.mode == &"free" and w.camera_rig.process_mode != Node.PROCESS_MODE_DISABLED, "key 0: the rig has the camera again")
	cap.load_era(1, false)
	await _frames(3)

# ---------------------------------------------------------------- 3. controls

func _key(code: Key, pressed: bool = true, shift: bool = false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = pressed
	k.shift_pressed = shift
	Input.parse_input_event(k)
	await _frames(2)

func _controls() -> void:
	var hud: CanvasLayer = w.hud
	check(hud.visible, "UI shows until H")
	await _key(KEY_H)
	await _key(KEY_H, false)
	await _frames(2)
	var tip: CanvasLayer = w.hand.get_node(^"Visual").get(&"tip_layer")
	check(cap.clean.on and not hud.visible and not tip.visible and cap.clean.ui_hidden(), "H: every UI layer is hidden (HUD, tooltip, cards)")
	check(not w.hand.visible, "H: the ghost hand is hidden")
	check(_cam().cull_mask & cap.clean.HIDE_LAYER_BIT == 0, "H: 3D UI (site bars, labels, the hand's helpers) is culled")
	await _key(KEY_G)
	await _key(KEY_G, false)
	var dot: VisualInstance3D = w.hand.get_node(^"Visual/CursorDot")
	check(w.hand.visible and dot.layers == cap.clean.HIDE_LAYER_BIT, "G: the hand stays in shot, its cursor dot and ghosts do not")
	check(not cap.overlay.visible, "the controls card is hidden unless F1 is held")
	await _key(KEY_F1)
	check(cap.overlay.visible and cap.overlay.visible == cap.overlay.is_visible() and cap.overlay.text().contains("hide / show all UI"), "F1 held: the controls card")
	await _key(KEY_F1, false)
	check(not cap.overlay.visible, "F1 released: the card goes")
	await _key(KEY_H)
	await _key(KEY_H, false)
	check(not cap.clean.on and hud.visible and w.hand.visible, "H again: the UI and the hand are back")
	check(_cam().cull_mask & cap.clean.HIDE_LAYER_BIT != 0, "H again: 3D UI drawn again")
	cap.clean.set_hand_visible(false)
	# pause
	await _key(KEY_P)
	await _key(KEY_P, false)
	var t0 := Clock.total_t
	await _frames(10)
	check(cap.paused and Clock.paused() and is_equal_approx(Clock.total_t, t0), "P: the valley freezes")
	await _key(KEY_P)
	await _key(KEY_P, false)
	await _frames(5)
	check(not cap.paused and Clock.total_t > t0, "P again: it runs on")
	# time of day and season
	cap.set_day_fraction(0.8)
	check(Clock.is_night, "time of day: 0.8 of the day is night")
	var f0 := Clock.day_fraction()
	await _key(KEY_BRACKETRIGHT)
	await _key(KEY_BRACKETRIGHT, false)
	check(absf(fposmod(Clock.day_fraction() - f0, 1.0) - 1.0 / 24.0) < 0.01, "]: an hour later")
	await _key(KEY_BRACKETLEFT)
	await _key(KEY_BRACKETLEFT, false)
	check(absf(Clock.day_fraction() - f0) < 0.01, "[: an hour earlier")
	cap.set_day_fraction(0.3)
	var s0 := Clock.season
	await _key(KEY_N)
	await _key(KEY_N, false)
	check(Clock.season == (s0 + 1) % 4, "N: the next season")
	await _key(KEY_3)
	await _key(KEY_3, false)
	check(cap.cam.mode == &"preset" and cap.cam.current == "fire_green" and Clock.speed_index == 1, "3: the fire/green preset (and not game speed 3)")

# ---------------------------------------------------------------- 4. reset

func _person(uid: int) -> Person:
	for p in Village.people:
		if is_instance_valid(p) and p.uid == uid:
			return p
	return null

func _reset() -> void:
	var saved: Dictionary = {}
	for nd in cap.start_state.get("nodes", []):
		if str(nd.get("scene", "")).ends_with("person.tscn"):
			saved[int(nd["uid"])] = nd["pos"]
	var uid: int = -1
	for u in saved:
		var c := _person(u)
		if c != null and c.pickable() and c.stage == Person.Stage.ADULT:
			uid = u
			break
	var pop0: int = int(cap.start_state["summary"]["population"])
	# change the valley: carry someone off, run time on
	var p := _person(uid)
	w.hand.input_enabled = false
	w.hand.try_lift(p)
	w.hand.aim_override = p.global_position + Vector3(25, 0, 25)
	await _frames(20)
	w.hand.place_on_ground(w.hand.aim_override)
	w.hand.aim_override = Vector3.INF
	w.hand.input_enabled = true
	await _frames(20)
	var moved := _person(uid).global_position.distance_to(Vector3(saved[uid][0], saved[uid][1], saved[uid][2])) > 5.0
	await _key(KEY_R)
	await _key(KEY_R, false)
	await _frames(2)
	var q := _person(uid)
	var back := q != null and q.global_position.distance_to(Vector3(saved[uid][0], saved[uid][1], saved[uid][2])) < 1.0
	check(moved and back and Village.population() == pop0 and Clock.day == int(cap.start_state["clock"]["day"]) and absf(Clock.total_t - float(cap.start_state["clock"]["total_t"])) < 1.0,
		"R: reset to the start state (the person is home, pop %d, day %d)" % [Village.population(), Clock.day])
	check(cap.cam.mode == &"preset" and cap.cam.current == "fire_green", "R: the camera is back on its preset")

# ---------------------------------------------------------------- 5. demos

func _demo(e: int, id: String, length: float) -> Variant:
	if Village.era != e:
		cap.load_era(e, false)
		await _frames(3)
	cap.demo_length = length
	cap.queue_demo(id)
	await _until(func(): return cap.demo != null, 30.0)
	Clock.set_speed(3)
	var d = cap.demo
	var ok := await _until(func(): return d.done, 120.0)
	Clock.set_speed(1)
	check(ok and absf(d.t - length) < 0.2, "%s (era %d): runs its fixed %.0f s and ends" % [id, e, length])
	return d

func _demos() -> void:
	for e in [1, 3]:
		var d = await _demo(e, "worker_placement", 12.0)
		check(d.has_event("lift") and d.lifted >= 3, "worker_placement era %d: try_lift then %s: %d people in the hand" % [e, "scoop_lift" if d.has_event("scoop") else "try_lift", d.lifted])
		check(d.has_event("place") and d.placed_list.size() >= 3 and d._placed == d.placed_list.size(), "worker_placement era %d: Hand.place_on_site sets %d on %s" % [e, d.placed_list.size(), d.site.title()])
		var working: Array = d.placed_people().filter(func(p): return p.state in [Person.S.WORK, Person.S.WAIT_GROUP, Person.S.WALK] and p.job_site == d.site)
		check(working.size() >= 2, "worker_placement era %d: the workers start the job (%d)" % [e, working.size()])
		check(w.hand.input_enabled and not w.hand.aim_override.is_finite() and cap.cam.mode == &"free", "worker_placement era %d: the hand and camera are the player's again" % e)
	var v = await _demo(3, "village_life", 12.0)
	check(v.has_event("dusk") and Clock.is_night and w.fire_lit(), "village_life: day turns to dusk with the fires lit")
	check(v.from_spec["focus"] != v.to_spec["focus"] and float(v.from_spec["yaw_deg"]) != float(v.to_spec["yaw_deg"]), "village_life: the camera drifts through the village")
	# a demo started from a key, then reset restarts it from frame one
	cap.demo_length = 30.0
	cap.set_day_fraction(0.3)        # people are up and about
	await _frames(5)
	await _key(KEY_K)
	await _key(KEY_K, false)
	check(cap.demo != null and cap.demo_id == "worker_placement", "K: the worker-placement demo")
	cap.stop_demo()
	cap.cam.release()

# ---------------------------------------------------------------- 6. SPOILER

func _spoiler() -> void:
	cap.spoiler = "goodbye"
	cap._begin_spoiler()
	var g = cap.goodbye()
	check(g != null and g.autopilot and g.beat == GoodbyeSequence.B.EVENING, "--spoiler=goodbye: the goodbye dev entry, autopiloted, from the evening")
	if g == null:
		return
	check(cap.spoiler_preset("liftoff") and cap.goodbye().beat == GoodbyeSequence.B.LIFTOFF, "spoiler preset liftoff: jumps to the liftoff")
	check(cap.spoiler_preset("rocket") and cap.goodbye().beat == GoodbyeSequence.B.COUNTDOWN, "spoiler preset rocket (behind): rebuilt, then the countdown")
	cap.clean.set_on(true)
	await _frames(2)
	check(not cap.goodbye()._layer.visible and cap.clean.ui_hidden(), "spoiler: H hides the goodbye's captions too")
	cap.clean.set_on(false)
	cap.spoiler_preset("rocket_low")
	await _frames(2)
	var want: Vector3 = cap.goodbye().L(Vector3(14, 2.2, 30))
	check(cap.cam.mode == &"pinned" and _cam().global_position.distance_to(want) < 0.05, "spoiler: a pinned camera in the launch site's frame")
	check(cap.spoiler_preset("lineage") and cap.goodbye().beat == GoodbyeSequence.B.LINEAGE, "spoiler preset lineage")
	cap.set_paused(true)
	await _frames(2)
	var bt: float = cap.goodbye().bt
	await _frames(10)
	check(is_equal_approx(cap.goodbye().bt, bt), "spoiler: P freezes the goodbye")
	cap.set_paused(false)
	cap.reset()
	await _frames(2)
	check(cap.goodbye() != null and cap.goodbye().beat == GoodbyeSequence.B.EVENING, "spoiler: R starts the goodbye again")
