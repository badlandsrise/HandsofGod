extends Node
## Review shots of the hand in the real valley (DESIGN 2, 12.1). Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . tests/hand/hand_shots.tscn -- --no-title [--prefix=hand_]
## Writes tests/shots/<prefix>empty.png (empty hand over the Clearing),
## <prefix>hold3.png (holding 3 over the log-haul group job), <prefix>scoop.png
## (mid-scoop) and <prefix>wave.png (waving back at a friend), then quits.

const WORLD := preload("res://scenes/world/world.tscn")

var prefix := "hand_"
var w: Node
var hand: Hand

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prefix = str(Game.flags.get("prefix", "hand_"))
	Save.enabled = false
	w = WORLD.instantiate()
	add_child(w)
	_run.call_deferred()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	await _wait(1.5)
	hand = w.hand
	hand.input_enabled = false
	w.camera_rig.input_enabled = false
	await _to_day()
	var only := str(Game.flags.get("only", "empty,hold3,scoop,wave")).split(",", false)
	if "empty" in only:
		# the default camera over the Clearing, the empty hand idling by the fire
		w.camera_rig.snap_to(w.fire_position() + Vector3(0, 0, 3.0), 28.0)
		hand.aim_override = w.fire_position() + Vector3(5.0, 0, 2.0)
		await _settle()
		await _shot("empty.png")
	if "hold3" in only:
		await _hold_shot()
	if "scoop" in only:
		await _scoop_shot()
	if "wave" in only:
		await _wave_shot()
	OS.kill(OS.get_process_id())

func _settle(n: int = 10) -> void:
	# llvmpipe runs at a few fps: run the hand's own step with a large dt so it settles
	for i in n:
		hand.step(0.12)
		await get_tree().process_frame

func _to_day() -> void:
	if w.storm.active():
		w.branch.on_lifted()
		w.branch.on_placed(w.cave_position() + Vector3(7.0, 0, 6.0))
	w.storm.skip()
	w.storm.set_process(false)
	await _wait(0.4)
	w.look.set_weather(0.0, false)
	Clock.is_night = false
	Clock.day = 2
	Clock.phase_t = 22.0
	w.look.update_now()
	var names := ["Ama", "Bo", "Kesi", "Rin", "Tavi"]
	for i in names.size():
		w.spawn_person(w.fire_position() + Vector3(-4.0 + i * 1.8, 0, 5.0), names[i])
	Faith.grant(&"grip_2")
	Faith.grant(&"grip_3")
	if w.fire:
		w.fire.add_fuel(1.0)
	Clock.running = true

func _hold_shot() -> void:
	var site: Site = w.trunk_site
	var idle: Array = []
	for i in 3:
		idle.append(w.spawn_person(Vector3(36.0 + i * 1.5, 0, 6.0), ["Oru", "Pell", "Sami"][i]))
	await _frames(3)
	var focus: Vector3 = site.global_position if site else Vector3(40, 4, 2)
	w.camera_rig.snap_to(focus + Vector3(0.0, 0, 3.0), 28.0)
	hand.lift_many(idle.slice(0, 3))
	hand.aim_override = focus + Vector3(0.0, 0, 0.6)
	await _settle(14)
	await _shot("hold3.png")
	if site:
		hand.place_on_site(site)
	hand.release_all()
	await _settle(4)

func _scoop_shot() -> void:
	var c: Vector3 = w.fire_position() + Vector3(-1.0, 0, 6.0)
	w.camera_rig.snap_to(c + Vector3(0, 0, 1.0), 28.0)
	var ppl: Array = []
	for i in 4:
		var a := TAU * float(i) / 4.0
		ppl.append(w.spawn_person(c + Vector3(cos(a), 0, sin(a)) * 1.6, ""))
	await _frames(2)
	hand.aim_override = c
	hand.step_hover_now()
	hand.scooping = true
	hand.scoop_center = c
	for k in 8:
		var a := -0.6 + 0.25 * float(k)
		hand.aim_override = c + Vector3(cos(a), 0, sin(a)) * 3.2
		hand.scoop_radius = 3.2
		hand.step(0.08)
		await get_tree().process_frame
	await _shot("scoop.png")
	hand.scooping = false
	hand.scoop_radius = 0.0
	await _settle(3)

func _wave_shot() -> void:
	var p: Person = null
	for q in Village.alive():
		if q.pickable():
			p = q
			break
	if p == null:
		return
	p.trust = 4
	p.trust_f = 4.2
	w.camera_rig.snap_to(p.global_position + Vector3(0, 0, 2.0), 24.0)
	hand.aim_override = p.global_position
	await _settle(16)
	await _shot("wave.png")

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://tests/shots").path_join(prefix + file)
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])
