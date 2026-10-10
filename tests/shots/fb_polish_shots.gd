extends "res://tests/shots/fb_world_shots.gd"
## [polish] Review shots for the Eras 1-2 leftovers. Attached by the world when
## Game.flags has "polish-shots". Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -- \
##     --polish-shots[=rivers,ghost,scree,wolf,warmth,wanderer]
## Writes tests/shots/fb_polish_*.png, then quits.

const POLISH_ALL := ["rivers", "ghost", "scree", "wolf", "warmth", "wanderer"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	var f: Dictionary = Game.flags
	want = POLISH_ALL
	if f.get("polish-shots") is String:
		want = str(f["polish-shots"]).split(",", false)
	_run.call_deferred()

func _run() -> void:
	var w = _w()
	await _wait(1.5)
	var t0 := Time.get_ticks_msec()
	w.camera_rig.tilt_shift = false
	await _to_day()
	_quiet_hud()
	_spread_people()
	Village.stats["guide_first_wanderer"] = true    # its cutscene gets its own shot, last
	if not w.is_region_open(&"valley_floor"):
		w.open_region(&"valley_floor")
	if w.regions.has_method(&"sync_instant"):
		w.regions.sync_instant()
	if "rivers" in want:
		w.camera_rig.target_yaw = 0.0
		w.camera_rig.snap_to(Vector3(14.0, 0, 8.0), 28.0)
		w.hand.aim_override = Vector3(-14.0, w.ground_y(-14, 0), 0.0)
		await _settle(10)
		await _shot("fb_polish_rivers_stream.png")
		w.open_region(&"southern_plains")
		w.regions.sync_instant()
		w.camera_rig.snap_to(Vector3(70.0, 0, 120.0), 44.0)
		await _settle(10)
		await _shot("fb_polish_rivers_great.png")
	if "ghost" in want:
		await _ghost_shot()
	if "scree" in want:
		w.camera_rig.target_yaw = 0.55
		w.camera_rig.snap_to(Vector3(-6.0, 0, 50.0), 34.0)
		w.hand.aim_override = Vector3(10.0, w.ground_y(10, 30), 30.0)
		await _settle(12)
		await _shot("fb_polish_scree.png")
	if "wolf" in want:
		await _wolf_shot()
	for g in get_tree().get_nodes_in_group(&"beacon"):
		g.queue_free()
	if "warmth" in want:
		await _warmth_shot()
	if "wanderer" in want:
		await _wanderer_shot()
	print("SHOTS done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	OS.kill(OS.get_process_id())

## The red no-drop sign at normal zoom (28 m), over the mist west of the Clearing.
func _ghost_shot() -> void:
	var w = _w()
	var hand = w.hand
	var people: Array = Village.alive().filter(func(p): return p.pickable()).slice(0, 3)
	w.camera_rig.target_yaw = 1.35
	w.camera_rig.snap_to(Vector3(-46.0, 0, 3.0), 28.0)
	hand.aim_override = people[0].global_position
	await _frames(2)
	hand.lift_many(people)
	var at := Vector3(-58.0, 0, 4.0)
	at.y = w.ground_y(at.x, at.z)
	hand.aim_override = at
	await _frames(3)
	hand.air_pos = hand.ground + Vector3(0, Hand.HOVER_H_HOLD, 0)
	w.camera_rig.snap_to(Vector3(-52.0, 0, 4.0), 28.0)
	_quiet_hud()
	w.hud.visible = true
	await _settle(8)
	print("SHOTS drop reason: '%s'" % hand.aim_drop_reason())
	await _shot("fb_polish_ghost.png")
	w.hud.visible = false
	hand.aim_override = Vector3(-20.0, w.ground_y(-20, 0), 0.0)
	await _frames(2)
	hand.release_all()
	hand.aim_override = Vector3(14.0, w.ground_y(14, 30), 30.0)

## The wolf in Era 1's warm light, beside a deer for comparison.
func _wolf_shot() -> void:
	var w = _w()
	var at := Vector3(-14.0, 0, 10.0)
	for i in 2:
		var a: Node3D = AssetCatalog.instance(&"wolf")
		w.add_child(a)
		a.global_position = Vector3(at.x + i * 2.4, w.ground_y(at.x + i * 2.4, at.z + i), at.z + i)
		a.rotation.y = 0.6 + i * 0.9
	var d: Node3D = AssetCatalog.instance(&"deer")
	w.add_child(d)
	d.global_position = Vector3(at.x - 3.0, w.ground_y(at.x - 3.0, at.z + 2.0), at.z + 2.0)
	d.rotation.y = 2.4
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(at, 13.0)
	w.hand.aim_override = Vector3(at.x + 12.0, w.ground_y(at.x + 12.0, at.z), at.z)
	await _settle(10)
	await _shot("fb_polish_wolf.png")

## Warming up: one by the fire, one under the hand's Warmth, one shivering.
func _warmth_shot() -> void:
	var w = _w()
	var fire: Vector3 = w.fire_position()
	var ppl: Array = Village.alive().filter(func(p): return p.pickable()).slice(0, 3)
	Clock.season = Clock.Season.WINTER
	for i in ppl.size():
		var p = ppl[i]
		p.go_idle()
		p.set_physics_process(false)
		p.global_position = fire + Vector3(-2.2 + i * 2.6, 0, 2.6)
		p.global_position.y = w.ground_y(p.global_position.x, p.global_position.z)
		p.needs[&"warmth"] = 0.15
	if ppl.size() >= 3:
		ppl[0].visual.set_warmth_cue(0.65, false)       # by the fire
		ppl[1].warm(30.0)                               # the hand's Warmth
		ppl[2].global_position = fire + Vector3(6.0, 0, 3.5)
		ppl[2].visual.set_warmth_cue(0.0, true)         # cold: frosty and shivering
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(fire + Vector3(1.5, 0, 2.5), 13.0)
	w.hand.aim_override = ppl[1].global_position + Vector3(0, 0, 0.4) if ppl.size() > 1 else fire
	for i in 30:
		for p in ppl:
			p.visual.animate(0.05, p._pose(), false, Vector3.INF)
		await _frames(1)
	await _shot("fb_polish_warmth.png")
	Clock.season = Clock.Season.SPRING
	for p in ppl:
		p.set_physics_process(true)

## The first wanderer's mini-cutscene: the walk in, then the tribe turns to look.
func _wanderer_shot() -> void:
	var w = _w()
	Village.stats.erase("guide_first_wanderer")
	w.hud.visible = true
	var ai = w.village_ai
	var arr: Array = ai.wanderers.arrive(1, &"")
	await _frames(4)
	var g = w.hud.get(&"guidance")
	var sc: WandererScene = g.scene if g != null else null
	print("SHOTS wanderer scene: %s" % [sc])
	if sc == null:
		return
	sc.set_process(false)
	sc.t = 1.6
	sc._process(0.0)
	w.camera_rig.step(1.0)
	await _frames(6)
	await _shot("fb_polish_wanderer_1.png")
	sc.t = WandererScene.PULL_AT + 1.5
	sc._process(0.0)
	for i in 4:
		w.camera_rig.step(1.0)
		for p in Village.alive():
			if p.visual:
				p.visual.animate(0.1, p._pose(), false, p._hand_look())
		await _frames(2)
	await _shot("fb_polish_wanderer_2.png")
	sc.skip()
