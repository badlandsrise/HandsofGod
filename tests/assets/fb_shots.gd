extends SceneTree
## Feedback-round art review sheets (villager tasks, props, animals, the scooping hand).
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##     -s res://tests/assets/fb_shots.gd -- --shot=props     -> tests/shots/fb_props.png
##   ... --shot=anims    -> tests/shots/fb_anims.png   every task pose, clothed, with props
##   ... --shot=animals  -> tests/shots/fb_animals.png wolf, deer, bear: idle/walk/run/attack/flee
##   ... --shot=scoop    -> tests/shots/fb_scoop.png   the hand's scoop pose from three sides
##   [--out=/abs/path.png]
## Headless it builds the scene and quits (a smoke test of the builders).

const SHOTS := "res://tests/shots/"
const SKINS := ["#e9c4a0", "#d4a27a", "#a8714c", "#7a4e33", "#5c3a26"]
const HAIRS := ["#1f1712", "#3b2a1e", "#6b4426", "#a5763f", "#7a2f1c"]
const CLOTH := ["#9e3b26", "#5b4a2a", "#c8902e", "#6b7f3a", "#7d7a72", "#3e5a78", "#b07a3a", "#d8c39e"]

var _args := {}
var _vp: SubViewport
var _world: Node3D
var _frames := 24


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	_register_globals()
	var shot: String = _args.get("shot", "props")
	_vp = SubViewport.new()
	_vp.size = Vector2i(2400, 1800)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_studio_light()
	match shot:
		"anims":
			await _anims()
		"animals":
			await _animals()
		"scoop":
			await _scoop()
		_:
			_props()
	var out: String = _args.get("out", SHOTS + "fb_%s.png" % shot)
	if DisplayServer.get_name() != "headless":
		for i in _frames:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
		print("fb shot saved: ", out)
	quit()


# ------------------------------------------------------------------ props

func _props() -> void:
	_flat_ground(Color("#9aa468"))
	var groups := [
		["TOOLS (HELD IN THE FIST)", PropKit.GRIP],
		["HELD ON THE PALM", PropKit.PALM],
		["CARRIED HOME (ONE PER RESOURCE)", _cargo_ids()],
		["SEATS", PropKit.SEATS],
		["GIFTS FOR THE HAND", PropKit.GIFTS],
	]
	var z := 0.0
	var cols := 10
	var cell := 1.3
	for g in groups:
		_title(g[0], Vector3(0.1, 0.02, z + 0.35), 0.6)
		z += 0.9
		var i := 0
		for id in g[1]:
			var holder := Node3D.new()
			var p := PropKit.make(id)
			holder.add_child(p)
			if PropKit.mount(id) == &"grip":
				p.rotation_degrees = Vector3(0, 0, -90)   # tools lie on the ground, head to the right
			_world.add_child(holder)
			var box := _aabb(holder, Transform3D.IDENTITY)
			var s := clampf(0.85 / maxf(box.size.x, maxf(box.size.y, box.size.z)), 0.5, 3.0)
			if id in PropKit.SEATS or id in PropKit.GIFTS:
				s = minf(s, 1.6)
			holder.scale = Vector3.ONE * s
			var cx := (i % cols) * cell + cell * 0.5
			var cz := z + (i / cols) * cell + 0.5
			holder.position = Vector3(cx, -box.position.y * s, cz) - Vector3(box.get_center().x, 0, box.get_center().z) * s
			_caption(String(id).trim_prefix("cargo_").trim_prefix("gift_"), Vector3(cx, 0.02, cz + 0.55), 0.55)
			i += 1
		z += ceili(i / float(cols)) * cell + 0.2
	_ortho_camera(Vector3(cols * cell * 0.5, 0, z * 0.5 + 0.2), maxf(cols * cell + 0.4, (z * 0.86 + 0.6) * 4.0 / 3.0), -58.0)


func _cargo_ids() -> Array:
	var out := []
	for id in PropKit.CARGO.values():
		if not id in out:
			out.append(id)
	if not &"cargo_crate" in out:
		out.append(&"cargo_crate")
	return out


# ------------------------------------------------------------------ villager tasks

## [label, clip, phase 0..1, era, cargo kind, right prop, left prop]  (props "_" = clip's own)
const POSES := [
	["pick berries", &"pick", 0.3, 1, &"", "_", "_"],
	["collect sticks", &"gather", 0.45, 1, &"", "_", "_"],
	["fell tree", &"chop", 0.35, 1, &"", &"stone_axe", "_"],
	["knap flint", &"knap", 0.3, 1, &"", "_", "_"],
	["tend fire", &"tend", 0.5, 1, &"", "_", "_"],
	["pray", &"pray", 0.4, 1, &"", "_", "_"],
	["sit (log)", &"sit", 0.3, 1, &"", "_", "_"],
	["sit and talk", &"sit_talk", 0.3, 2, &"", "_", "_"],
	["carry berries", &"carry_walk", 0.3, 1, &"berries", "_", "_"],
	["carry sticks", &"carry", 0.3, 1, &"wood", "_", "_"],
	["carry meat", &"carry_walk", 0.6, 1, &"meat", "_", "_"],
	["carry hide", &"carry", 0.3, 1, &"hide", "_", "_"],
	["log on shoulder", &"carry_log", 0.3, 1, &"", "_", "_"],
	["haul log", &"push", 0.3, 1, &"", "_", "_"],
	["hunt: walk", &"spear_walk", 0.3, 1, &"", "_", "_"],
	["hunt: ready", &"spear_ready", 0.5, 1, &"", "_", "_"],
	["dance", &"dance", 0.3, 1, &"", "_", "_"],
	["cheer", &"cheer", 0.25, 1, &"", "_", "_"],
	["wave", &"wave", 0.4, 1, &"", "_", "_"],
	["fetch water", &"fish", 0.35, 1, &"", "_", &"waterskin"],
	["sow", &"sow", 0.4, 2, &"", "_", "_"],
	["harvest", &"harvest", 0.4, 2, &"", "_", "_"],
	["water", &"water", 0.4, 2, &"", "_", "_"],
	["hammer", &"hammer", 0.3, 2, &"", "_", "_"],
	["build, kneeling", &"build_kneel", 0.4, 2, &"", "_", "_"],
	["craft at bench", &"craft", 0.4, 2, &"", "_", "_"],
	["dig", &"dig", 0.3, 2, &"", &"spade", "_"],
	["haul rope", &"rope", 0.3, 2, &"", "_", "_"],
	["carry grain", &"carry_walk", 0.3, 2, &"grain", "_", "_"],
	["carry pots", &"carry", 0.3, 2, &"pots", "_", "_"],
	["read", &"read", 0.4, 3, &"", "_", "_"],
	["lookout", &"lookout", 0.3, 3, &"", "_", "_"],
	["hands on hips", &"idle_hips", 0.4, 3, &"", "_", "_"],
	["arms folded", &"idle_fold", 0.4, 3, &"", "_", "_"],
	["talk", &"talk", 0.4, 3, &"", "_", "_"],
	["forge", &"hammer", 0.45, 3, &"", &"hammer", &"tongs"],
	["walk", &"walk", 0.3, 1, &"", "_", "_"],
	["run", &"run", 0.3, 1, &"", "_", "_"],
	["eat", &"eat", 0.4, 1, &"", "_", "_"],
	["baby sitting", &"baby_sit", 0.4, 1, &"", "_", "_"],
]


func _anims() -> void:
	var poses: Array = POSES
	if _args.has("only"):   # --only=label,label: a closer look at a few
		var keep: PackedStringArray = String(_args["only"]).split(",")
		poses = POSES.filter(func(p): return p[0] in keep)
	var cols := mini(8, poses.size())
	var cw := 2.0
	var rh := 2.9
	var rows := ceili(poses.size() / float(cols))
	var plate_m := ShaderMaterial.new()
	plate_m.shader = ArtPalette.SHADER
	plate_m.set_shader_parameter("albedo_color", Color("#a5a86f"))
	plate_m.set_shader_parameter("palette_pull", 0.0)
	ArtPalette.register(plate_m)
	var vs: Array = []
	for i in poses.size():
		var spec: Array = poses[i]
		var col := i % cols
		var row := i / cols
		var at := Vector3(col * cw, -row * rh, 0)
		var plate := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.85
		pm.bottom_radius = 0.9
		pm.height = 0.08
		plate.mesh = pm
		plate.material_override = plate_m
		plate.position = at + Vector3(0, -0.04, 0)
		_world.add_child(plate)
		var v := (load("res://scenes/people/villager_visual.tscn") as PackedScene).instantiate() as VillagerVisual
		v.set_era(spec[3])
		v.set_look(Color(SKINS[(i * 2 + 1) % SKINS.size()]), Color(HAIRS[(i * 3) % HAIRS.size()]), Color(CLOTH[i % CLOTH.size()]), i)
		if spec[1] == &"baby_sit":
			v.set_age_scale(0)
		_world.add_child(v)
		v.position = at
		v.rotation_degrees.y = 32.0
		var r: StringName = VillagerVisual.DEFAULT if String(spec[5]) == "_" else StringName(spec[5])
		var l: StringName = VillagerVisual.DEFAULT if String(spec[6]) == "_" else StringName(spec[6])
		v.play_task(spec[1], r, l, 0.0)
		v.hold_cargo(spec[4])
		vs.append(v)
		_caption(spec[0], at + Vector3(0, -0.3, 0.9), 0.95, true)
	var phases: Array = poses.map(func(p): return p[2])
	if not _args.has("only") or String(_args["only"]).contains("log"):
		# the two-person log carry, with the LogCarry the carry_log site uses
		var c := Vector3(minf(cw * 1.5, (cols - 1) * cw * 0.5), -rows * rh, 0)
		rows += 1
		var site := _fake_site(c, Vector3.RIGHT)
		for k in 2:
			var holder := Node3D.new()
			holder.set_script(_prop_script(["visual"]))
			_world.add_child(holder)
			var spot := LogCarry.slot(site, k)
			holder.global_position = Vector3(spot.x, c.y, spot.z)
			holder.rotation.y = PI * 0.5   # facing +X, the way the log goes
			var v := (load("res://scenes/people/villager_visual.tscn") as PackedScene).instantiate() as VillagerVisual
			v.set_era(1)
			v.set_look(Color(SKINS[k + 1]), Color(HAIRS[k + 2]), Color(CLOTH[k + 4]), k + 2)
			holder.add_child(v)
			var vis := Node3D.new()
			vis.set_script(_prop_script(["villager"]))
			vis.set(&"villager", v)
			holder.set(&"visual", vis)
			v.play_task(&"carry_log")
			vs.append(v)
			phases.append(0.3 + 0.45 * k)
			site.workers.append(holder)
		_world.add_child(LogCarry.make(site, 0))
		_caption("two-person log carry", c + Vector3(0, -0.3, 0.9), 0.95, true)
	await process_frame
	for i in vs.size():
		var ap := (vs[i] as Node).get_node("AnimationPlayer") as AnimationPlayer
		ap.seek(ap.current_animation_length * float(phases[i]), true)
		ap.pause()
	var w := cols * cw
	var cam := _ortho_camera(Vector3((cols - 1) * cw * 0.5, -(rows - 1) * rh * 0.5 + 0.7, 0), w + 0.2, -8.0)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = rows * rh + 0.3
	_vp.size = Vector2i(roundi(2000.0 * (w + 0.2) / (rows * rh + 0.3)), 2000)



## A stand-in for a carry_log Site: what LogCarry reads (workers, group_running, job).
func _fake_site(at: Vector3, heading: Vector3) -> Node3D:
	var s := Node3D.new()
	s.set_script(_prop_script(["workers", "group_running", "job"]))
	_world.add_child(s)
	s.global_position = at
	s.set(&"workers", [])
	s.set(&"group_running", true)
	s.set_meta(&"log_heading", heading)
	return s


## A throwaway Node3D script with these untyped properties.
func _prop_script(props: Array) -> GDScript:
	var g := GDScript.new()
	var src := "extends Node3D\n"
	for p in props:
		src += "var %s\n" % p
	g.source_code = src
	g.reload()
	return g


# ------------------------------------------------------------------ animals

const ANIMAL_STATES := [["idle", 0.0], ["walk", 0.15], ["run", 0.3], ["attack", 0.0], ["flee", 0.65], ["graze", 0.0], ["held", 0.0], ["dead", 0.0]]


func _animals() -> void:
	var species := [&"wolf", &"deer", &"bear"]
	var cw := 2.9
	var rh := 2.5
	var plate_m := ShaderMaterial.new()
	plate_m.shader = ArtPalette.SHADER
	plate_m.set_shader_parameter("albedo_color", Color("#a5a86f"))
	plate_m.set_shader_parameter("palette_pull", 0.0)
	ArtPalette.register(plate_m)
	for r in species.size():
		_caption(String(species[r]).to_upper(), Vector3(-1.6, -r * rh + 0.6, 0.6), 1.3, true)
		for c in ANIMAL_STATES.size():
			var at := Vector3(c * cw, -r * rh, 0)
			var plate := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 1.25
			pm.bottom_radius = 1.3
			pm.height = 0.06
			plate.mesh = pm
			plate.material_override = plate_m
			plate.position = at + Vector3(0, -0.03, 0)
			_world.add_child(plate)
			var a := WildAnimalVisual.new()
			a.species = species[r]
			_world.add_child(a)
			a.position = at
			a.rotation_degrees.y = 72.0
			if species[r] == &"bear" and c == 0:
				a.rotation_degrees.y = 40.0
			a.freeze(StringName(ANIMAL_STATES[c][0]), ANIMAL_STATES[c][1])
			a.set_eyes(species[r] == &"wolf" and c == 3)
			if r == 0:
				_caption(ANIMAL_STATES[c][0], at + Vector3(0, 2.0, 0), 1.2, true)
	var cols := ANIMAL_STATES.size()
	var w := (cols - 1) * cw + 4.2
	var h := species.size() * rh + 1.0
	var cam := _ortho_camera(Vector3((cols - 1) * cw * 0.5 - 0.6, -(species.size() - 1) * rh * 0.5 + 0.7, 0), w, -10.0)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = h
	_vp.size = Vector2i(roundi(1500.0 * w / h), 1500)


# ------------------------------------------------------------------ hand scoop

## Three scooping hands as the game shows them (HandVisual's scoop pose and placement):
## sweeping right to left, left to right, and towards the camera, each with people in
## front of the palm, under the game's camera angle.
func _scoop() -> void:
	_flat_ground(Color("#7f9a4c"))
	var hand_len := 6.0
	var cam_fwd := Vector3(0, 0, -1)
	var sweeps := [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK]
	var model_scene := load("res://scenes/hand/hand_model.tscn") as PackedScene
	for i in sweeps.size():
		var at := Vector3((i - 1) * 11.0, 0, 0)
		var m := model_scene.instantiate() as Node3D
		_world.add_child(m)
		m.call(&"set_pose", PackedFloat32Array(HandScoop.CURL), HandScoop.CUP, 0.0, HandScoop.SPREAD)
		m.call(&"set_look", 0.85, 1.0, 1.0, Color(1.0, 0.75, 0.4))
		var b: Basis = HandScoop.basis(sweeps[i], cam_fwd).scaled(Vector3.ONE * hand_len)
		var anchor: Vector3 = at + Vector3(0, 2.2, 0)
		var origin: Vector3 = anchor - b * (m.call(&"anchor_local", 0.7) as Vector3)
		origin.y += HandScoop.lift(b, origin, HandScoop.CLEAR * hand_len)
		m.global_transform = Transform3D(b, origin)
		# people just ahead of the palm, being swept up
		for k in 3:
			var v := (load("res://scenes/people/villager_visual.tscn") as PackedScene).instantiate() as VillagerVisual
			v.set_era(1)
			v.set_look(Color(SKINS[(i + k) % 5]), Color(HAIRS[(i * 2 + k) % 5]), Color(CLOTH[(i * 3 + k) % 8]), i * 3 + k)
			_world.add_child(v)
			var side: Vector3 = sweeps[i].cross(Vector3.UP)
			v.position = anchor + sweeps[i] * (2.2 + 0.6 * k) + side * (k - 1) * 1.1
			v.position.y = 0.0
			v.rotation.y = atan2(-sweeps[i].x, -sweeps[i].z)
			v.play(&"cower" if k != 1 else &"fall", 0.0)
		_caption(["sweeping right to left", "sweeping left to right", "sweeping towards you"][i], at + Vector3(0, 0.02, 5.2), 4.0)
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.rotation_degrees = Vector3(-42, 0, 0)   # the game camera's middle pitch
	cam.position = Vector3(0, 1.5, 1.0) + cam.basis.z * 32.0
	_world.add_child(cam)
	cam.current = true
	_vp.size = Vector2i(2400, 1200)


# ------------------------------------------------------------------ helpers

func _studio_light() -> void:
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
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe6c8")
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	_world.add_child(sun)


func _flat_ground(c: Color) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = ArtPalette.SHADER
	gm.set_shader_parameter("albedo_color", c)
	gm.set_shader_parameter("palette_pull", 0.0)
	ArtPalette.register(gm)
	ground.material_override = gm
	_world.add_child(ground)


func _ortho_camera(center: Vector3, width: float, pitch: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = width
	cam.rotation_degrees = Vector3(pitch, 0, 0)
	cam.position = center + cam.basis.z * 60.0
	cam.far = 200.0
	_world.add_child(cam)
	cam.current = true
	return cam


func _title(text: String, pos: Vector3, size := 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.004 * size
	l.modulate = Color("#2b2320")
	l.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.position = pos
	l.rotation_degrees = Vector3(-90, 0, 0)
	_world.add_child(l)


func _caption(text: String, pos: Vector3, size := 1.0, upright := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.004 * size
	l.modulate = Color("#2b2320")
	l.outline_size = 0
	l.position = pos
	if not upright:
		l.rotation_degrees = Vector3(-90, 0, 0)
	_world.add_child(l)


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


func _register_globals() -> void:
	var pal := [Color(0.8, 0.58, 0.27), Color(0.38, 0.48, 0.22), Color(0.2, 0.19, 0.18), Color(1.0, 0.55, 0.2)]
	var add := func(n: StringName, t: int, v) -> void:
		if not ProjectSettings.has_setting("shader_globals/" + str(n)):
			RenderingServer.global_shader_parameter_add(n, t, v)
	for i in 4:
		add.call(StringName("hog_pal_%d" % i), RenderingServer.GLOBAL_VAR_TYPE_COLOR, pal[i])
	add.call(&"hog_grass", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.36, 0.55, 0.23))
	add.call(&"hog_leaf", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.38, 0.62, 0.26))
	add.call(&"hog_snow", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	add.call(&"hog_frost", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	add.call(&"hog_wet", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	add.call(&"hog_wind", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.6)
	add.call(&"hog_map_rect", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(-600, -600, 1200, 1200))
	if not ProjectSettings.has_setting("shader_globals/hog_region_mask"):
		var img := Image.create(4, 4, false, Image.FORMAT_L8)
		img.fill(Color.WHITE)
		RenderingServer.global_shader_parameter_add(&"hog_region_mask", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, ImageTexture.create_from_image(img))
