extends SceneTree
## Renders a labelled grid of raw models (or catalog ids) under the palette shader, for
## picking pack pieces. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##     -s res://scripts/assets/tools/preview_models.gd -- --dir=res://assets/models/village \
##     [--filter=Wall_] [--ids=granary,kiln] [--era=2] [--cols=6] [--out=/tmp/x.png] [--pitch=-35]
## Each model is scaled to fit its grid cell (the scale is printed in the caption).

var _args := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	AssetCatalog.set_era(int(_args.get("era", "2")))
	var items: Array = []   # [label, Node3D]
	if _args.has("ids"):
		for id in String(_args["ids"]).split(",", false):
			items.append([id, AssetCatalog.instance(StringName(id), int(_args.get("variant", "0")), StringName(_args.get("season", "")))])
	if _args.has("dir"):
		var filt: String = _args.get("filter", "")
		var d := DirAccess.open(String(_args["dir"]))
		var files := d.get_files()
		files.sort()
		for f in files:
			if not (f.ends_with(".gltf") or f.ends_with(".glb") or f.ends_with(".fbx") or f.ends_with(".tscn") or f.ends_with(".scn")):
				continue
			if filt != "" and not f.contains(filt):
				continue
			if _args.has("names") and not (f.get_basename() in String(_args["names"]).split(",")):
				continue
			var ps := load(String(_args["dir"]).path_join(f)) as PackedScene
			if ps == null:
				continue
			var n := ps.instantiate() as Node3D
			ArtPalette.apply_to_tree(n, float(_args.get("pull", "0.3")), Color.WHITE, float(_args.get("sat", "1.0")))
			var w := Node3D.new()
			w.add_child(n)
			items.append([f.get_basename(), w])
	var cols := int(_args.get("cols", "6"))
	var cell := float(_args.get("cell", "6"))
	var fit := bool(int(_args.get("fit", "1")))
	var world := Node3D.new()
	root.add_child(world)
	_setup(world)
	for i in items.size():
		var label: String = items[i][0]
		var n: Node3D = items[i][1]
		world.add_child(n)
		var box := _aabb(n, Transform3D.IDENTITY)
		var s := 1.0
		if fit:
			s = (cell * 0.8) / maxf(maxf(box.size.x, box.size.z), maxf(box.size.y, 0.01))
		n.scale = Vector3.ONE * s
		var cx := (i % cols) * cell
		var cz := (i / cols) * cell
		var c := box.get_center() * s
		n.position = Vector3(cx - c.x, -box.position.y * s, cz - c.z)
		var l := Label3D.new()
		l.text = "%s  %.2f\n%.1fx%.1fx%.1f" % [label, s, box.size.x, box.size.y, box.size.z]
		l.font_size = 48
		l.pixel_size = 0.006 * cell / 6.0
		l.modulate = Color("#2b2320")
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.position = Vector3(cx, 0.05, cz + cell * 0.45)
		world.add_child(l)
	var rows := ceili(items.size() / float(cols))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(rows * cell * 1.15, cols * cell * 0.5625) + 1.0
	cam.rotation_degrees = Vector3(float(_args.get("pitch", "-35")), float(_args.get("yaw", "-20")), 0)
	cam.position = Vector3((cols - 1) * cell * 0.5, 0, (rows - 1) * cell * 0.5) + cam.basis.z * 120.0
	cam.far = 400.0
	world.add_child(cam)
	cam.current = true
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var out: String = _args.get("out", "/tmp/preview.png")
	root.get_texture().get_image().save_png(out)
	print("preview saved: ", out, " (", items.size(), " items)")
	OS.kill(OS.get_process_id())


func _setup(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#e9d9bc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b4b0a4")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe6c8")
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = ArtPalette.SHADER
	gm.set_shader_parameter("albedo_color", Color("#8f9a5a"))
	gm.set_shader_parameter("palette_pull", 0.0)
	ArtPalette.register(gm)
	ground.material_override = gm
	world.add_child(ground)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is VisualInstance3D and not n is Light3D and not n is Label3D:
		out = t * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out
