extends SceneTree
## Dev tool: renders clips of an animation library on the villager mannequin, a few
## frames per clip, to pick and check villager task animations.
## xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##   -s res://scripts/assets/tools/clip_sheet.gd -- <glb or .res> <out.png> [first] [count]

const BODY := "res://assets/models/characters/Superhero_Male_FullBody.gltf"
const FRACS := [0.0, 0.25, 0.5, 0.75]


func shown_count(args: PackedStringArray) -> int:
	if args.size() > 2 and not args[2].is_valid_int():
		return args[2].split(",").size()
	return 12


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0] if args.size() > 0 else "res://assets/models/characters/anims/UAL2_Standard.glb"
	var out: String = args[1] if args.size() > 1 else "user://clips.png"
	var first := 0
	var count := int(args[3]) if args.size() > 3 else 12
	var pick := PackedStringArray()
	if args.size() > 2:
		if args[2].is_valid_int():
			first = int(args[2])
		else:
			pick = args[2].split(",")
	var lib: AnimationLibrary
	var res = load(src)
	if res is AnimationLibrary:
		lib = res
	else:
		var n := (res as PackedScene).instantiate()
		lib = (n.get_node("AnimationPlayer") as AnimationPlayer).get_animation_library(&"")
	var names := lib.get_animation_list()
	var vp := SubViewport.new()
	vp.size = Vector2i(2400, 1800)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#d8cbb0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#a09888")
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	world.add_child(sun)
	var cols := 2 if shown_count(args) > 2 else 1   # clips per row
	var shown := names.slice(first, first + count) if pick.is_empty() else Array(pick)
	var dx := 1.6
	var dy := 2.5
	for i in shown.size():
		var r := i / cols
		var c := i % cols
		for f in FRACS.size():
			var body := (load(BODY) as PackedScene).instantiate() as Node3D
			var ap := AnimationPlayer.new()
			body.add_child(ap)
			ap.root_node = NodePath("..")
			ap.add_animation_library(&"", lib)
			body.position = Vector3((c * (FRACS.size() + 0.6) + f) * dx, -r * dy, 0)
			body.rotation_degrees.y = float(OS.get_environment("YAW")) if OS.get_environment("YAW") != "" else 35.0
			world.add_child(body)
			var a := lib.get_animation(shown[i])
			ap.play(shown[i])
			ap.seek(a.length * FRACS[f], true)
			ap.pause()
		var l := Label3D.new()
		l.text = String(shown[i])
		l.font_size = 64
		l.pixel_size = 0.004
		l.modulate = Color.BLACK
		l.outline_size = 0
		l.position = Vector3((c * (FRACS.size() + 0.6) + 1.5) * dx, -r * dy - 0.25, 1.0)
		world.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var rows := ceili(float(shown.size()) / cols)
	rows = maxi(rows, 2)
	cam.size = maxf(rows * dy, (cols * FRACS.size() + (cols - 1) * 0.6 + 0.4) * dx / (4.0 / 3.0))
	cam.rotation_degrees = Vector3(-18, 0, 0)
	cam.position = Vector3((cols * FRACS.size() + (cols - 1) * 0.6) * dx * 0.5 - dx * 0.5, -(rows - 1) * 0.5 * dy + 0.3 + 6.5, 20.0)
	world.add_child(cam)
	cam.current = true
	for _i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	quit()
