extends Node3D
## Close-up review renders of the glove (open, holding, point, ghost):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . tests/hand/hand_closeup.tscn
## Writes tests/shots/hand_closeup_<pose>.png and quits.

const ModelScene := preload("res://scenes/hand/hand_model.tscn")
const POSES := {
	"open": [[0.0, -0.6, -0.6, -0.5, -0.4], 0.0, 0.0, 0.8, 1.0],
	"holding": [[0.55, 0.7, 0.75, 0.8, 0.85], 0.8, 0.0, 0.0, 1.0],
	"point": [[0.0, 0.0, 0.0, 0.0, 0.0], 0.0, 1.0, 0.0, 1.0],
	"ghost": [[0.05, 0.05, 0.05, 0.08, 0.12], 0.0, 0.0, 0.8, 0.28],
}

var model: HandModel
var cam: Camera3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.light_energy = 1.1
	add_child(sun)
	model = ModelScene.instantiate()
	add_child(model)
	cam = Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	cam.look_at_from_position(Vector3(1.05, 1.25, 0.15), Vector3(-0.05, -0.05, -0.48), Vector3.UP)
	_run.call_deferred()

func _run() -> void:
	var only := str(Game.flags.get("only", ",".join(POSES.keys()))).split(",", false)
	for name in POSES:
		if not name in only:
			continue
		var p: Array = POSES[name]
		model.set_pose(PackedFloat32Array(p[0]), p[1], p[2], p[3])
		model.set_look(p[4], 1.0, 1.0, Color(1.0, 0.7, 0.35))
		model.rotation = Vector3(deg_to_rad(-15), deg_to_rad(20), deg_to_rad(10))
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://tests/shots/hand_closeup_%s.png" % name)
		img.save_png(path)
		print("SHOT ", path)
	OS.kill(OS.get_process_id())
