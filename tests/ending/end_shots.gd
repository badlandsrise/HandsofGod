extends Node
## Review screenshots of the goodbye on the generated Era 4 setup (`--goodbye`):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . res://tests/ending/end_shots.tscn
## Writes tests/shots/end_1..6.png (the last evening, the crew at the old stone,
## the countdown under the hand, liftoff, the light and the lineage, the credits),
## then quits. -- --end-shots=review writes a longer set to --out=<dir> instead.

const OUT := "res://tests/shots"
const B := GoodbyeSequence.B
## [file, beat, seconds into it, mouse (0..1 of the screen)]
const SHOTS := [
	["end_1.png", B.EVENING, 17.0, Vector2(0.62, 0.45)],
	["end_2.png", B.CREW, 9.6, Vector2(0.8, 0.42)],
	["end_3.png", B.COUNTDOWN, 13.0, Vector2(0.5, 0.3)],
	["end_4.png", B.LIFTOFF, 7.5, Vector2(0.5, 0.3)],
	["end_5.png", B.LINEAGE, 22.0, Vector2(0.84, 0.5)],
	["end_6.png", B.CREDITS, 52.0, Vector2(0.5, 0.5)],
]
const REVIEW := [
	["r_ev_a.png", B.EVENING, 6.0, Vector2(0.6, 0.45)],
	["r_ev_b.png", B.EVENING, 17.0, Vector2(0.62, 0.45)],
	["r_ev_c.png", B.EVENING, 28.0, Vector2(0.6, 0.45)],
	["r_crew_a.png", B.CREW, 4.4, Vector2(0.8, 0.42)],
	["r_crew_b.png", B.CREW, 9.6, Vector2(0.8, 0.42)],
	["r_board.png", B.BOARDING, 4.6, Vector2(0.6, 0.4)],
	["r_count.png", B.COUNTDOWN, 13.0, Vector2(0.5, 0.3)],
	["r_ignite.png", B.COUNTDOWN, 22.0, Vector2(0.5, 0.3)],
	["r_lift_a.png", B.LIFTOFF, 4.0, Vector2(0.5, 0.3)],
	["r_lift_b.png", B.LIFTOFF, 10.0, Vector2(0.5, 0.3)],
	["r_lift_c.png", B.LIFTOFF, 14.0, Vector2(0.5, 0.3)],
	["r_lift_d.png", B.LIFTOFF, 18.0, Vector2(0.5, 0.3)],
	["r_lift_e.png", B.LIFTOFF, 21.5, Vector2(0.5, 0.3)],
	["r_wave_a.png", B.WAVE, 3.0, Vector2(0.5, 0.3)],
	["r_wave_b.png", B.WAVE, 10.0, Vector2(0.5, 0.3)],
	["r_words.png", B.WORDS, 7.0, Vector2(0.84, 0.5)],
	["r_light.png", B.LIGHT, 4.2, Vector2(0.84, 0.5)],
	["r_lineage_a.png", B.LINEAGE, 22.0, Vector2(0.84, 0.5)],
	["r_lineage_b.png", B.LINEAGE, 30.0, Vector2(0.84, 0.5)],
	["r_rest.png", B.REST, 14.0, Vector2(0.5, 0.5)],
	["r_credits_a.png", B.CREDITS, 52.0, Vector2(0.5, 0.5)],
	["r_credits_b.png", B.CREDITS, 130.0, Vector2(0.5, 0.5)],
	["r_dawn.png", B.DONE, 0.0, Vector2(0.5, 0.5)],
]

var w: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	CreditsRoll.seen_path = "user://end_shots_ending.cfg"
	Game.flags["goodbye"] = true
	_run.call_deferred()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])

func _run() -> void:
	var review := str(Game.flags.get("end-shots", "")) == "review"
	var out_dir: String = ProjectSettings.globalize_path(OUT)
	if review:
		out_dir = str(Game.flags.get("out", "/tmp/end_review"))
		DirAccess.make_dir_recursive_absolute(out_dir)
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	for i in 900:
		if w.get(&"goodbye") != null:
			break
		await get_tree().process_frame
	var seq: GoodbyeSequence = w.goodbye
	seq.autopilot = true
	for s in (REVIEW if review else SHOTS):
		if not is_instance_valid(seq) or seq.done:
			if s[1] == B.DONE:
				await _wait(2.5)
				await _shot(out_dir.path_join(s[0]))
			continue
		seq.mouse_override = s[3]
		seq.rate = 1.0
		if seq.beat < s[1]:
			seq.jump_to(s[1], 0.0)
		if s[1] == B.DONE:
			seq.jump_to(B.DONE)
			await _wait(3.0)
			await _shot(out_dir.path_join(s[0]))
			continue
		var ahead: float = float(s[2]) - seq.bt
		if ahead > 1.0:
			seq.fast_forward(ahead - 1.0)
		# the last second in real time, so particles and blends settle
		seq.rate = 1.0
		await _wait(1.0)
		seq.rate = 0.0
		await _wait(0.2)
		await _shot(out_dir.path_join(s[0]))
	get_tree().quit()
