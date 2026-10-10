extends Node
## Review screenshots of the front end: the studio splash, the title over the
## live valley, and three moments of the intro.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . res://tests/front/fe_shots.tscn
## Optional: -- --fe-shots=splash,title,intro (default all)
## Writes tests/shots/fe_splash.png, fe_title.png, fe_intro_1..3.png, then quits.

const OUT := "res://tests/shots"
## intro moments: [file, intro time to jump to, real seconds to let it run]
const INTRO := [["fe_intro_1.png", 9.2, 0.6], ["fe_intro_2.png", 27.6, 1.2], ["fe_intro_3.png", 40.4, 1.0]]

var want: Array = ["splash", "title", "intro"]
var w: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	Save.dir = "user://fe_shots_saves"      # empty: a first launch, no Continue
	Options.path = "user://fe_shots_options.cfg"
	if Game.flags.get("fe-shots") is String:
		want = str(Game.flags["fe-shots"]).split(",", false)
	_run.call_deferred()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(file)
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])

func _run() -> void:
	if "splash" in want:
		var layer := CanvasLayer.new()
		add_child(layer)
		var sp := StudioSplash.new()
		layer.add_child(sp)
		await _wait(0.3)
		sp.set_process(false)
		sp.t = 2.7
		sp._apply()
		await _wait(0.2)
		await _shot("fe_splash.png")
		layer.queue_free()
		await _wait(0.2)
	if "title" in want or "intro" in want:
		w = load("res://scenes/world/world.tscn").instantiate()
		add_child(w)
		var menu = null
		for i in 600:
			menu = get_tree().get_first_node_in_group(&"game_menu")
			if menu != null and menu._fade.color.a <= 0.0 and menu._logo.reveal >= 1.0:
				break
			await get_tree().process_frame
		await _wait(1.0)
		if "title" in want:
			await _shot("fe_title.png")
	if "intro" in want:
		var menu = get_tree().get_first_node_in_group(&"game_menu")
		menu._on_new()
		var intro: IntroSequence = menu.intro
		await _wait(0.5)
		for s in INTRO:
			intro.t = s[1]
			intro._update(0.0)
			w.look.update_now()
			await _wait(s[2])
			await _shot(s[0])
	get_tree().quit()
