extends Node3D
## Art contact sheets: lays out catalog ids on a ground plane under warm low sun and saves
## a screenshot, so the kit can be reviewed as one picture.
##
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##     res://tests/assets/contact_sheet.tscn -- --sheet=era1
##   ... -- --sheet=villagers
##   ... -- --sheet=ids --ids=hut,campfire --out=res://tests/assets/x.png [--era=2] [--season=winter]
##
## era1 lays out every catalog id (plus a few villagers for scale) and writes
## tests/assets/contact_era1.png; villagers shows outfits, ages and animation states and
## writes tests/assets/villagers.png. Without a display it just builds the scene and quits.

const VILLAGER_STATES := [&"idle", &"walk", &"run", &"carry", &"work", &"sit", &"wave", &"cheer",
	&"cower", &"held", &"fall", &"dead"]
const SKINS := ["#f0c8a0", "#c99a72", "#9a6a48", "#6e4a32", "#e0b48c", "#b07a52"]
const HAIRS := ["#2b1d14", "#5a3a22", "#8a5a30", "#1a1410", "#b08850", "#d8d0c4"]
const CLOTHS := ["#6b4428", "#8a5a3b", "#5a3a24", "#7b4a2c", "#6e5034", "#7b3f2a"]

var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var sheet: String = _args.get("sheet", "era1")
	AssetCatalog.set_era(int(_args.get("era", "1")))
	_setup_world()
	var out := ""
	match sheet:
		"villagers":
			_villagers()
			out = "res://tests/assets/villagers.png"
		"ids":
			_layout(String(_args.get("ids", "")).split(",", false), false)
			out = "res://tests/assets/contact_ids.png"
		_:
			_layout(AssetCatalog.ids(), true)
			out = "res://tests/assets/contact_era1.png"
	out = _args.get("out", out)
	await _capture(out)
	get_tree().quit()


func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#e9d9bc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#aaa69a")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe6c8")
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = ArtPalette.SHADER
	gm.set_shader_parameter("albedo_color", Color("#7f8c50"))
	gm.set_shader_parameter("palette_pull", 0.0)
	ArtPalette.register(gm)
	ground.material_override = gm
	add_child(ground)


## Shelf-packs ids in rows, biggest first, with a caption under each.
func _layout(ids: PackedStringArray, with_people: bool) -> void:
	var items: Array = []
	for id in ids:
		items.append([id, AssetCatalog.footprint(StringName(id))])
	items.sort_custom(func(a, b): return maxf(a[1].x, a[1].y) > maxf(b[1].x, b[1].y))
	var row_w := 46.0
	var x := 0.0
	var z := 0.0
	var row_d := 0.0
	var max_x := 0.0
	var season: String = _args.get("season", "")
	for it in items:
		var id: String = it[0]
		var fp: Vector2 = it[1]
		var w := maxf(fp.x, 2.2) + 1.6
		if x + w > row_w and x > 0.0:
			z += row_d
			x = 0.0
			row_d = 0.0
		var n := AssetCatalog.instance(StringName(id), 0, StringName(season))
		n.position = Vector3(x + w * 0.5, 0, z + fp.y * 0.5 + 0.6)
		add_child(n)
		_caption(id, Vector3(x + w * 0.5, 0.05, z + fp.y + 1.3))
		x += w
		max_x = maxf(max_x, x)
		row_d = maxf(row_d, fp.y + 2.4)
	z += row_d
	if with_people:
		for i in 6:
			var v := _villager(i, VILLAGER_STATES[i % 3 * 3 + 0] if i < 3 else &"work")
			v.position = Vector3(2.0 + i * 1.6, 0, z + 1.0)
			_caption("villager %d" % i, Vector3(2.0 + i * 1.6, 0.05, z + 2.0), 0.7)
		z += 3.0
	_camera(Vector3(max_x * 0.5, 0, z * 0.5 - 0.5), maxf(max_x * 0.5625, z * 0.8 + 4.0), -50.0)


func _villagers() -> void:
	if _args.has("states"):
		var st: PackedStringArray = String(_args["states"]).split(",")
		for i in st.size():
			var v := _villager(int(_args.get("outfit", str(i))), StringName(st[i]))
			v.position = Vector3(i * 1.6, 0, 0)
			_caption(st[i], Vector3(i * 1.6, 0.05, 0.9), 0.45)
		_camera(Vector3(st.size() * 0.8 - 0.8, 0.9, 0), 3.0, -10.0)
		return
	# row 0: every outfit variant, adults idle
	for i in 8:
		var v := _villager(i, &"idle")
		v.position = Vector3(i * 1.5, 0, 0)
		_caption("outfit %d" % i, Vector3(i * 1.5, 0.05, 0.9), 0.45)
	# row 1: ages
	var ages := ["baby", "child", "adult", "elder"]
	for s in 4:
		var v := _villager(s + 2, &"idle")
		v.set_age_scale(s)
		if s == 3:
			v.set_look(Color(SKINS[1]), Color("#d8d0c4"), Color(CLOTHS[2]), 4)
		v.position = Vector3(1.5 + s * 1.5, 0, 3.0)
		_caption(ages[s], Vector3(1.5 + s * 1.5, 0.05, 3.9), 0.45)
	# rows 2-3: animation states
	for i in VILLAGER_STATES.size():
		var v := _villager(i, VILLAGER_STATES[i])
		v.position = Vector3((i % 6) * 2.0, 0, 6.0 + (i / 6) * 3.0)
		_caption(String(VILLAGER_STATES[i]), Vector3((i % 6) * 2.0, 0.05, 7.0 + (i / 6) * 3.0), 0.45)
	_camera(Vector3(5.25, 0.6, 5.2), 8.2, -32.0)


func _villager(i: int, state: StringName) -> VillagerVisual:
	var v := AssetCatalog.instance(&"villager").get_child(0) as VillagerVisual
	v.get_parent().remove_child(v)
	add_child(v)
	v.set_look(Color(SKINS[i % SKINS.size()]), Color(HAIRS[i % HAIRS.size()]), Color(CLOTHS[i % CLOTHS.size()]), i)
	v.play(state, 0.0)
	return v


func _caption(text: String, pos: Vector3, size := 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.012 * size
	l.modulate = Color("#2b2320")
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees = Vector3(-90, 0, 0)
	add_child(l)


func _camera(center: Vector3, ortho_size: float, pitch: float) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ortho_size
	cam.rotation_degrees = Vector3(pitch, 0, 0)
	cam.position = center + cam.basis.z * 80.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	print("contact sheet saved: ", path)
