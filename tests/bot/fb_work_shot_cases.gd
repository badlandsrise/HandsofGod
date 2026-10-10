extends Node
## Staging for tests/bot/fb_work_shots.gd.

const ALL := ["lodge", "call", "farmhouse"]
const OUT := "res://tests/shots"

var w: Node3D
var want: Array = ALL

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func run() -> void:
	Save.enabled = false
	if Game.flags.get("only") is String:
		want = str(Game.flags["only"]).split(",", false)
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await _frames(3)
	if Clock.running == false:
		w.new_game()
		w.start_play()
	await _wait(1.0)
	_skip_onboarding()
	# open the Valley Floor quietly (no banner over the shots)
	Village.regions[&"valley_floor"] = true
	w._open_region_visual(&"valley_floor", true)
	_run()
	await _wait(1.0)
	if "lodge" in want: await _lodge()
	if "call" in want: await _call()
	if "farmhouse" in want: await _farmhouse()
	print("FB WORK SHOTS done")
	OS.kill(OS.get_process_id())

func _skip_onboarding() -> void:
	if w.storm.active():
		w.branch.on_lifted()
		w.branch.on_placed(w.cave_position() + Vector3(7.0, 0, 6.0))
	w.storm.skip()
	w.storm.set_process(false)
	w.look.set_weather(0.0, false)
	Clock.is_night = false
	Clock.day = 3
	Clock.phase_t = 20.0
	Village.stats["onboarding"] = Onboarding.Beat.DONE
	Faith.grant(&"grip_2")
	Village.stores[&"berries"] = 30
	Village.stores[&"water"] = 30
	for s in Village.sites:
		if is_instance_valid(s) and s.is_fire():
			s.add_fuel(Site.FIRE_MAX_FUEL)
	var names := ["Ama", "Bo", "Kesi", "Rin", "Tavi", "Lok", "Mira", "Senna"]
	for i in names.size():
		w.spawn_person(Vector3(-6.0 + i * 1.8, 0, -9.0), names[i])
	w.look.update_now()

## Time runs (a naming card may have stopped the clock).
func _run() -> void:
	for c in get_tree().root.find_children("*", "", true, false):
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("naming_card.gd") and c is CanvasItem:
			c.visible = false
	Clock.running = true
	Clock.set_speed(1)

func _built(bid: StringName, at: Vector2) -> Site:
	var s: Site = w.spawn_plot(bid, Vector3(at.x, 0, at.y))
	for k in s.building.cost:
		s.deliver(k, int(s.building.cost[k]))
	s.add_build_work(1000.0)
	return s

## The hunting lodge in the Valley Floor; its two hunters out at a herd.
func _lodge() -> void:
	_run()
	var lodge := _built(&"hunting_lodge", Progression.LODGE_SPOT)
	await _frames(2)
	var crew: Array = Village.alive().slice(0, 2)
	for p in crew:
		p.on_lifted()
		p.on_placed(lodge.slot_position(lodge.slot_of(p)), lodge)
	await _wait(2.0)
	# under a software renderer the sim crawls: set the hunters down where
	# their walk out to the herd ends
	for p in crew:
		var t: Site = p.task_site
		if t != null and is_instance_valid(t):
			p.global_position = Workplace.task_spot(lodge, t, p)
	await _frames(3)
	var at := lodge.global_position + Vector3(6.0, 0, -2.0)
	w.camera_rig.target_yaw = 0.5
	w.camera_rig.snap_to(at, 26.0)
	w.hand.aim_override = lodge.global_position + Vector3(-3, 0, 4)
	await _frames(12)
	await _shot("fb_work_lodge.png")
	w.hand.aim_override = Vector3.INF

## The Call gesture: the idle walk over to the hand and wait there.
func _call() -> void:
	_run()
	for p in Village.alive():
		if p.job_site == null:
			p.global_position = Vector3(randf_range(-10, 16), 0, randf_range(-2, 14))
	var at := Vector3(4.0, 0, 6.0)
	at.y = w.ground_y(at.x, at.z)
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(at, 22.0)
	w.hand.aim_override = at
	await _frames(4)
	Village.call_idle(at)
	await _wait(1.0)
	# where each answers the call (the walk itself is too slow to wait for here)
	for p in Village.alive():
		if p._target.is_finite() and p._target.distance_to(at) < 5.0:
			p.global_position = p._target
	await _frames(3)
	await _shot("fb_work_call.png")
	w.hand.aim_override = Vector3.INF

## Era 2: the farmhouse among its fields, a crew at work, grain in the bin.
func _farmhouse() -> void:
	Village.era = 2
	AssetCatalog.set_era(2)
	_run()
	var e2: VillageEra2 = w.village_ai.era2
	var spot: Vector2 = VillageEra2.FARMHOUSE_SPOTS[0]
	var fh := _built(&"farmhouse", spot)
	Workplace.lay_fields(fh, 2)
	await _frames(2)
	var fields: Array = Workplace.tasks(fh).filter(func(t): return t.building != null and t.building.id == &"field")
	for i in fields.size():
		var f: Site = fields[i]
		f.add_build_work(1000.0)
		f._set_field_stage(Site.Field.RIPE if i == 0 else Site.Field.GROWING)
	Workplace.bin_add(fh, &"grain", 18)
	var crew: Array = Village.alive().slice(2, 6)
	for p in crew:
		p.on_lifted()
		p.on_placed(fh.slot_position(fh.slot_of(p)), fh)
	await _wait(5.0)
	w.look.update_now()
	w.camera_rig.target_yaw = -0.4
	w.camera_rig.snap_to(fh.global_position + Vector3(0, 0, 6), 38.0)
	w.hand.aim_override = fh.global_position + Vector3(5, 0, -3)
	await _frames(12)
	await _shot("fb_work_farmhouse.png")
	w.hand.aim_override = Vector3.INF

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])
