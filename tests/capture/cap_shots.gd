extends SceneTree
## Example stills of the marketing capture mode (docs/CAPTURE.md), through
## the capture director itself: the same valley views (valley_wide and
## hero_low) in Eras 1, 2 and 3 for before/after shots, and a worker-placement
## frame mid-carry. Writes tests/shots/cap_*.png. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . -s tests/capture/cap_shots.gd [-- --only=valley,hero,worker]

const OUT := "res://tests/shots"

var _frame := 0
var _w: Node = null
var _cap: Node = null
var _want: Array = ["valley", "hero", "worker"]

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		_run()
	return false

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait(s: float) -> void:
	var clock: Node = root.get_node("Clock")
	var t0: float = clock.total_t
	var r0 := Time.get_ticks_msec()
	while clock.total_t - t0 < s and Time.get_ticks_msec() - r0 < 90000:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(name)
	img.save_png(path)
	print("CAP SHOT %s" % path)

func _run() -> void:
	var game: Node = root.get_node("Game")
	if game.flags.get("only") is String:
		_want = str(game.flags["only"]).split(",", false)
	game.flags["capture"] = true
	game.flags["era"] = "1"
	game.flags["seed"] = "1"
	game.flags["hide-ui"] = true
	_w = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w
	_cap = _w.get_node("Capture")
	while not _cap.loaded:
		await process_frame
	for e in [1, 2, 3]:
		if e != _cap.era:
			_cap.load_era(e, false)
		_cap.clean.set_on(true)
		await _wait(2.5)
		if "valley" in _want:
			_cap.cam.go("valley_wide", e)
			await _frames(12)
			await _shot("cap_valley_wide_era%d.png" % e)
		if "hero" in _want:
			_cap.cam.go("hero_low", e)
			await _frames(12)
			await _shot("cap_hero_low_era%d.png" % e)
	if "worker" in _want:
		_cap.load_era(3, false)
		_cap.clean.set_on(true)
		_cap.clean.set_hand_visible(true)
		await _wait(1.5)
		_cap.demo_length = 30.0
		_cap.start_demo("worker_placement")
		var r0 := Time.get_ticks_msec()
		while _cap.demo != null and not (_cap.demo._beat == "carry" and _cap.demo._bt > _cap.demo._blen * 0.45) and Time.get_ticks_msec() - r0 < 120000:
			await process_frame
		await _shot("cap_worker_placement_mid.png")
	print("CAP SHOTS done")
	quit(0)
