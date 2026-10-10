extends SceneTree
## Dev tool: renders every animation of the Universal Animation Library on its mannequin,
## frozen at a fraction of its length, to pick villager states.
## xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##   -s res://scripts/assets/tools/anim_preview.gd -- 0.4 /tmp/anims.png

const UAL := "res://assets/models/characters/anims/UAL1_Standard.glb"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var frac := float(args[0]) if args.size() > 0 else 0.4
	var out: String = args[1] if args.size() > 1 else "/tmp/anims.png"
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#d8cbb0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9a8f80")
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var ps := load(UAL) as PackedScene
	var probe := ps.instantiate()
	var names: PackedStringArray = (probe.get_node("AnimationPlayer") as AnimationPlayer).get_animation_list()
	probe.free()
	var cols := 11
	for i in names.size():
		var n := ps.instantiate() as Node3D
		n.position = Vector3((i % cols) * 2.0, (i / cols) * -2.6, 0)
		world.add_child(n)
		var ap := n.get_node("AnimationPlayer") as AnimationPlayer
		ap.play(names[i])
		ap.seek(ap.current_animation_length * frac, true)
		ap.pause()
		var l := Label3D.new()
		l.text = names[i]
		l.font_size = 40
		l.pixel_size = 0.006
		l.modulate = Color.BLACK
		l.position = n.position + Vector3(0, -0.15, 0.6)
		l.rotation_degrees = Vector3(0, 0, 0)
		world.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.5
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.position = Vector3(10.0, -3.6, 20.0)
	world.add_child(cam)
	cam.current = true
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
