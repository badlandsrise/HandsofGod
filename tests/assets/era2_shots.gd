extends SceneTree
## Era 2 (Village) art review shots. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##     -s res://tests/assets/era2_shots.gd -- --shot=kit       -> tests/shots/era2_art_kit.png
##   ... -- --shot=village                                       -> tests/shots/era2_village.png
##   [--out=/abs/path.png]
## kit is the contact sheet: every Era 2 catalog id (and variant) in labelled sections.
## village is one composed diorama: river, bridge, temple, square, houses, workshops,
## fields and villagers in Era 2 clothes, lit like the game. Headless it builds and quits.

const SHOTS := "res://tests/shots/"
## Garment colours by job family (the same ones Person uses), for the villagers.
const JOBS := ["#9e3b26", "#5b4a2a", "#c8902e", "#6b7f3a", "#7d7a72", "#4a4744", "#e6d5b0", "#3e5a78", "#b07a3a", "#d8c39e"]
const SKINS := ["#e9c4a0", "#d4a27a", "#a8714c", "#7a4e33", "#5c3a26"]
const HAIRS := ["#1f1712", "#3b2a1e", "#6b4426", "#a5763f", "#7a2f1c"]

var _args := {}
var _vp: SubViewport
var _world: Node3D


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	_register_globals()
	AssetCatalog.set_era(2)
	var shot: String = _args.get("shot", "kit")
	_vp = SubViewport.new()
	_vp.size = Vector2i(2400, 2400) if shot == "kit" else Vector2i(1920, 1080)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var out := ""
	if shot == "village":
		_village()
		out = SHOTS + "era2_village.png"
	else:
		_kit()
		out = SHOTS + "era2_art_kit.png"
	out = _args.get("out", out)
	if DisplayServer.get_name() != "headless":
		for i in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
		print("era2 shot saved: ", out)
	quit()


# ------------------------------------------------------------------ contact sheet

func _kit() -> void:
	_studio_light()
	_flat_ground(Color("#8a9658"))
	var z := 0.0
	var row_w := 60.0
	var b := []
	for id in ["cottage", "cottage:1", "granary", "mill", "bakery", "kiln", "smelter", "smithy", "weaver",
			"workshop", "barn", "temple", "bridge", "well", "watchtower", "sheep_pen", "market_stall",
			"market_stall:1", "market_stall:2", "charcoal_clamp", "jetty"]:
		b.append(id)
	z = _section("BUILDINGS", b, z, row_w)
	var st := []
	for id in ["cottage", "granary", "mill", "bakery", "kiln", "smelter", "smithy", "weaver", "workshop",
			"barn", "temple", "bridge", "well", "watchtower", "sheep_pen"]:
		st.append(id + "_plot")
		st.append(id + "_frame")
	st.append_array(["market_stall_frame", "raft_frame"])
	z = _section("CONSTRUCTION: PLOT, THEN FRAME", st, z, row_w)
	z = _section("FARMING", ["field_tilled", "field_sprouts", "field_growing", "field_ripe", "field_stubble",
		"field_blighted", "field_parched", "garden_plot", "haystack", "sheaves", "scarecrow"], z, row_w)
	z = _section("RESOURCE PILES (x2)", ["grain_sacks@2", "flour_sacks@2", "bread_basket@2", "pots@2",
		"pots_unfired@2", "clay_pile@2", "planks_pile@2", "charcoal_pile@2", "ore_pile@2", "bronze_ingots@2",
		"wool_bales@2", "cloth_bolts@2", "barrels@2", "water_trough@2"], z, row_w)
	z = _section("RESOURCE NODES AND HAZARDS", ["clay_pit", "copper_ore", "rockfall"], z, row_w)
	z = _section("PROPS, BOATS AND ANIMALS (small ones enlarged)", ["fence_wattle@2", "fence_wattle_gate@2", "handcart@2", "handcart:1@2",
		"hay_wagon@1.5", "raft", "rowboat", "fishing_boat", "cow@2.5", "pig@2.5", "sheep@2.5", "horse@2.5"], z, row_w)
	z = _section("TOOLS (x4)", ["tool_axe_bronze@4", "tool_pickaxe_bronze@4", "tool_hoe@4", "tool_sickle@4",
		"tool_pitchfork@4", "tool_shovel@4", "tool_hammer@4"], z, row_w)
	# villagers: the eight Era 2 outfits in job colours (x1.6)
	_title("VILLAGERS: ERA 2 OUTFITS 0-7 (x2.5)", z)
	z += 6.0
	for i in 8:
		var v := _villager(i, &"idle", JOBS[(i * 3) % JOBS.size()])
		v.scale = Vector3.ONE * 2.5
		v.position = Vector3(4.0 + i * 7.0, 0, z + 1.6)
		_caption("outfit %d" % i, Vector3(4.0 + i * 7.0, 0.05, z + 3.4), 1.0)
	z += 5.0
	# fit the width; the image is as tall as the sheet needs
	var pitch := -42.0
	var tall := z * sin(deg_to_rad(-pitch)) + 10.0
	_vp.size = Vector2i(2400, int(2400.0 * tall / (row_w + 2.0)))
	_ortho_camera(Vector3(row_w * 0.5, 0, z * 0.5 - 3.0), row_w + 2.0, pitch)


## Shelf-packs one section of ids; "id:2" picks a variant, "id@2" scales for display.
func _section(title: String, ids: Array, z0: float, row_w: float) -> float:
	_title(title, z0)
	var z := z0 + 5.5
	var x := 0.0
	var row_d := 0.0
	for spec in ids:
		var s := String(spec)
		var disp := 1.0
		if s.contains("@"):
			disp = float(s.get_slice("@", 1))
			s = s.get_slice("@", 0)
		var variant := 0
		if s.contains(":"):
			variant = int(s.get_slice(":", 1))
			s = s.get_slice(":", 0)
		var n := AssetCatalog.instance(StringName(s), variant)
		n.scale = Vector3.ONE * disp
		_world.add_child(n)
		var box := _aabb(n, Transform3D.IDENTITY)
		var label := s + ((" #%d" % variant) if variant > 0 else "")
		var w := maxf(box.size.x + 1.4, label.length() * 0.33)
		if x + w > row_w and x > 0.0:
			z += row_d
			x = 0.0
			row_d = 0.0
		var cx := x + w * 0.5
		n.position = Vector3(cx - (box.position.x + box.size.x * 0.5), 0, z - box.position.z + 0.3)
		_caption(label, Vector3(cx, 0.05, z + box.size.z + 0.9), clampf(w / 8.0, 0.75, 1.0))
		x += w
		row_d = maxf(row_d, box.size.z + 2.4)
	return z + row_d + 1.0


func _title(text: String, z: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.016
	l.modulate = Color("#2b2320")
	l.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.position = Vector3(0.2, 0.05, z + 1.0)
	l.rotation_degrees = Vector3(-90, 0, 0)
	_world.add_child(l)


func _caption(text: String, pos: Vector3, size := 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.0115 * size
	l.modulate = Color("#2b2320")
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees = Vector3(-90, 0, 0)
	_world.add_child(l)


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
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	_world.add_child(sun)


func _flat_ground(c: Color) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = ArtPalette.SHADER
	gm.set_shader_parameter("albedo_color", c)
	gm.set_shader_parameter("palette_pull", 0.0)
	ArtPalette.register(gm)
	ground.material_override = gm
	_world.add_child(ground)


func _ortho_camera(center: Vector3, ortho_size: float, pitch: float) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = ortho_size
	cam.rotation_degrees = Vector3(pitch, 0, 0)
	cam.position = center + cam.basis.z * 150.0
	cam.far = 500.0
	_world.add_child(cam)
	cam.current = true


func _villager(i: int, state: StringName, cloth: String) -> VillagerVisual:
	var v := (load("res://scenes/people/villager_visual.tscn") as PackedScene).instantiate() as VillagerVisual
	v.set_era(2)
	v.set_look(Color(SKINS[(i * 2 + 1) % SKINS.size()]), Color(HAIRS[(i * 3) % HAIRS.size()]), Color(cloth), i)
	_world.add_child(v)
	v.play(state, 0.0)
	return v


# ------------------------------------------------------------------ village diorama

const RIVER_X := 31.0
const RIVER_HALF := 6.5
const WATER_Y := -0.55

var _paths: Array = []    # [Vector2 a, Vector2 b, half width]
var _yards: Array = []    # [Vector2 centre, Vector2 half size] worn ground under buildings
var _rng := RandomNumberGenerator.new()


static func _river_x(z: float) -> float:
	return RIVER_X + sin(z * 0.05 + 0.6) * 4.0


func _village() -> void:
	_rng.seed = 2
	_game_light()
	# paths first: the ground mesh paints them
	var sq := Vector2(0, -6)
	for p in [[sq, Vector2(0, -16)], [sq, Vector2(-16, -2)], [Vector2(-16, -2), Vector2(-30, -12)],
			[sq, Vector2(15, -4)], [Vector2(15, -4), Vector2(22, -4)], [Vector2(40, -4), Vector2(56, -2)],
			[sq, Vector2(-4, 12)], [Vector2(-4, 12), Vector2(12, 14)],
			[Vector2(-16, -2), Vector2(-27, 7)], [Vector2(15, -4), Vector2(14, -16)], [Vector2(12, 14), Vector2(20, 22)],
			[Vector2(-4, 12), Vector2(-4, 40)]]:
		_paths.append([p[0], p[1], 1.0])
	_yards.append([sq, Vector2(7.5, 5.0)])
	_ground()
	_water()
	var P := func(id: String, x: float, z: float, rot: float = 0.0, variant: int = 0) -> Node3D:
		var n := AssetCatalog.instance(StringName(id), variant)
		n.position = Vector3(x, 0, z)
		n.rotation_degrees.y = rot
		_world.add_child(n)
		return n
	# the temple of the hand at the head of the square, the old shrine inside it
	P.call("temple", 0, -27)
	# the square: well, market stalls, goods
	P.call("well", 1.5, -6.5, 15)
	P.call("market_stall", -6.5, -9.5, 20, 0)
	P.call("market_stall", -7.0, -3.0, 70, 1)
	P.call("market_stall", 7.0, -9.0, -25, 2)
	P.call("barrels", 8.6, -5.5, 30)
	P.call("bread_basket", -4.8, -7.6)
	P.call("pots", -5.2, -1.4, 40)
	P.call("cloth_bolts", 5.0, -11.2, -10)
	P.call("water_trough", 3.8, -4.4, 90)
	# houses
	P.call("cottage", -17, -9, 25, 0)
	P.call("cottage", -26, -2, 70, 1)
	P.call("cottage", -15, 5, 160, 1)
	P.call("cottage", 13, -18, -20, 1)
	P.call("cottage", 9, 6, -150, 0)
	P.call("cottage_frame", -31, -12, 60)
	P.call("planks_pile", -27.5, -7.5, 20)
	P.call("cottage_plot", 20, -22, -10)
	# food: granary, mill, bakery
	P.call("granary", 17, 3, -70)
	P.call("grain_sacks", 14.2, 1.0, 20)
	P.call("mill", -31, 8, 50)
	P.call("flour_sacks", -26.5, 10.5, 10)
	P.call("bakery", -11, 13, 160)
	P.call("bread_basket", -7.0, 10.0)
	# crafts by the river: pottery, metal, weaving
	P.call("kiln", 19, 15, -100)
	P.call("clay_pit", 22.5, 21.5, 10)
	P.call("pots_unfired", 15.0, 18.8, -20)
	P.call("smithy", 19, -12, -80)
	P.call("charcoal_pile", 22.5, -15.5, 30)
	P.call("bronze_ingots", 15.8, -9.2, 10)
	P.call("weaver", -27, -19, 40)
	P.call("wool_bales", -23.5, -21.5, 30)
	# the river: bridge, jetty, boats
	P.call("bridge", _river_x(-4.0), -4.0, 0)
	P.call("jetty", 25.5, 8.5, 90)
	P.call("rowboat", 29.5, 11.0, 15)
	P.call("raft", 33.0, 19.0, -30)
	P.call("fishing_boat", 34.0, -16.0, 160)
	P.call("watchtower", 44, -14, -30)
	# farm: fields, hay, barn, pens
	var fx := [-30.0, -21.0, -30.0, -21.0, -12.0, -12.0]
	var fz := [22.5, 22.5, 29.5, 29.5, 29.5, 22.5]
	var fid := ["field_ripe", "field_ripe", "field_growing", "field_sprouts", "field_tilled", "field_stubble"]
	for i in 6:
		P.call(fid[i], fx[i], fz[i], 0)
	P.call("haystack", -5.5, 25.5)
	P.call("sheaves", -6.8, 21.6, 20)
	P.call("scarecrow", -25.5, 22.2, 15)
	P.call("hay_wagon", -3.0, 30.0, 80)
	P.call("garden_plot", -20, 13.5, 10)
	P.call("barn", -42, 25, 90)
	P.call("sheep_pen", 7, 24, -5)
	for i in 5:
		var sh := P.call("sheep", 4.0 + i * 1.5, 23.0 + (i % 2) * 1.6, _rng.randf_range(0, 360)) as Node3D
		sh.position.y = 0.0
	P.call("cow", -38, 33, 70)
	P.call("cow", -40.5, 35, 140)
	P.call("pig", -26, 15, 200)
	P.call("handcart", -2.0, 11.0, 30, 1)
	P.call("handcart", 23.0, -1.0, 100)
	# fences
	for i in 6:
		P.call("fence_wattle", -34.0 + i * 2.0, 18.6, 0)
	P.call("fence_wattle_gate", -22.0, 18.6, 0)
	for i in 3:
		P.call("fence_wattle", -35.5, 20.5 + i * 2.0, 90)
	# trees, bushes and rocks around the edges
	var trees := [[-52, -20], [-48, -30], [-40, -32], [-30, -34], [-19, -36], [14, -36], [24, -34],
		[-56, 0], [-55, 12], [-58, 32], [48, 6], [52, 16], [46, 28], [56, -26], [40, 30], [-12, -34],
		[36, -30], [-50, 40], [6, 44], [30, 40], [-44, -24], [-36, -28], [-24, -30], [-6, -38], [4, -38],
		[18, -32], [42, -22], [50, -10], [48, -30], [-48, -12], [-52, -4], [16, 40], [24, 38], [-36, 42], [44, 40]]
	for t in trees:
		var id := "tree_pine" if _rng.randf() < 0.35 else "tree_broad"
		P.call(id, t[0] + _rng.randf_range(-2, 2), t[1] + _rng.randf_range(-2, 2), _rng.randf_range(0, 360), _rng.randi() % 4)
	for i in 26:
		var a := Vector2(_rng.randf_range(-58, 58), _rng.randf_range(-38, 44))
		if _busy(a):
			continue
		P.call("bush" if i % 3 else "flowers", a.x, a.y, _rng.randf_range(0, 360), _rng.randi() % 3)
	for r in [[39, 8], [40.5, 10], [24, 30], [-44, -6], [11, 36], [44, -4]]:
		P.call("rock_small", r[0], r[1], _rng.randf_range(0, 360), _rng.randi() % 3)
	for i in 160:
		var a := Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-40, 46))
		if _busy(a):
			continue
		P.call("grass_clump", a.x, a.y, _rng.randf_range(0, 360), _rng.randi() % 3)
	# people at work
	var people := [
		[&"work", 0.2, -4.9, 200], [&"carry", -10.5, -1.0, 60], [&"talk", -4.2, -6.3, 110], [&"idle", -3.4, -5.6, -80],
		[&"walk", 4.0, 1.0, 160], [&"work", -27.5, 21.0, 30], [&"work", -19.0, 24.0, -20], [&"carry", -10.6, 20.0, 10],
		[&"work", 14.6, 13.2, 70], [&"work", 16.8, -13.5, 90], [&"walk", 25.5, -4.2, 90], [&"sit", -6.0, 7.0, 180],
		[&"idle", 1.6, -18.5, 0], [&"cheer", -1.4, -18.0, 20], [&"work", -24.0, -16.5, 120], [&"walk", -2.6, 30.0, 180],
		[&"carry", 21.0, 20.5, -60], [&"wave", 26.2, 8.6, 90], [&"work", 6.2, 21.4, 0], [&"idle", 5.2, -7.6, -60],
	]
	for i in people.size():
		var p: Array = people[i]
		var v := _villager(i, p[0], JOBS[(i * 7 + 3) % JOBS.size()])
		v.position = Vector3(p[1], 0, p[2])
		v.rotation_degrees.y = p[3]
		v.set_age_scale(1 if i == 13 else 2)
	# the camera: the game's high three-quarter view, a little closer
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.rotation_degrees = Vector3(-48, -6, 0)
	cam.position = Vector3(-4, 0, 6) + cam.basis.z * 68.0
	cam.far = 600.0
	_world.add_child(cam)
	cam.current = true


func _busy(a: Vector2) -> bool:
	if absf(a.x - _river_x(a.y)) < RIVER_HALF + 2.5:
		return true
	if a.y > 17.0 and a.y < 34.0 and a.x > -36.0 and a.x < 13.0:
		return true   # fields and pen
	if a.length() < 30.0 and a.y < 22.0:
		return true   # the village
	if a.x < -34.0 and a.x > -50.0 and a.y > 16.0 and a.y < 38.0:
		return true   # barn
	return false


func _game_light() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#6d9cc4")
	sky_mat.sky_horizon_color = Color("#d9e2df")
	sky_mat.ground_horizon_color = Color("#d9e2df")
	sky_mat.ground_bottom_color = Color(0.16, 0.15, 0.13)
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9bdb4")
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0009
	env.fog_light_color = Color("#d8dccf")
	env.fog_aerial_perspective = 0.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe8cc")
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-40, -40, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 200.0
	sun.shadow_blur = 1.5
	_world.add_child(sun)


## Ground height: flat village, a river channel with muddy banks, gentle swells far out.
func _height(x: float, z: float) -> float:
	var d := absf(x - _river_x(z))
	var h := -2.2 * _ss(RIVER_HALF + 2.0, RIVER_HALF - 1.5, d)
	var far := _ss(34.0, 60.0, Vector2(x, z).length())
	h += far * (sin(x * 0.11) * cos(z * 0.13) + 0.6) * 1.4
	return h


func _ground() -> void:
	var cell := 1.0
	var x0 := -130.0
	var z0 := -120.0
	var nx := 260
	var nz := 200
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + i * cell
			var z := z0 + j * cell
			verts.append(Vector3(x, _height(x, z), z))
			cols.append(_ground_mix(x, z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			idx.append_array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/shaders/terrain.gdshader")
	mat.set_shader_parameter("noise_large", _noise_tex(11, 0.012, 4))
	mat.set_shader_parameter("noise_mid", _noise_tex(23, 0.03, 3))
	mat.set_shader_parameter("noise_fine", _noise_tex(37, 0.06, 2))
	mat.set_shader_parameter("mask_rect", Vector4(-1000, -1000, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_world.add_child(mi)


## COLOR r grass, g worn dirt, b rock, a bank (mud) - the terrain shader's inputs.
func _ground_mix(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var dirt := 0.0
	for s in _paths:
		var q := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		dirt = maxf(dirt, _ss(s[2] + 1.0, s[2] - 0.4, p.distance_to(q)))
	for y in _yards:
		var d: Vector2 = ((p - y[0]).abs() - y[1])
		dirt = maxf(dirt, _ss(1.5, -0.5, maxf(d.x, d.y)) * 0.85)
	var bank := _ss(RIVER_HALF + 3.0, RIVER_HALF + 0.5, absf(x - _river_x(z)))
	return Color(1.0 - dirt, dirt, 0.0, bank)


func _water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -80.0
	while z < 80.0:
		var a := _river_x(z)
		var b := _river_x(z + 4.0)
		var w := RIVER_HALF + 1.0
		var p0 := Vector3(a - w, WATER_Y, z)
		var p1 := Vector3(a + w, WATER_Y, z)
		var p2 := Vector3(b - w, WATER_Y, z + 4.0)
		var p3 := Vector3(b + w, WATER_Y, z + 4.0)
		for v in [p0, p1, p2, p1, p3, p2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		z += 4.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/shaders/water.gdshader")
	mat.set_shader_parameter("flow_dir", Vector2(0, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_world.add_child(mi)


static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## The hog_* shader globals the world shaders read (the game's Look registers them; this
## runs without the game's autoloads, so it adds the same defaults itself).
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


static func _noise_tex(seed_v: int, freq: float, octaves: int) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.seed = seed_v
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq
	fn.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = fn
	return t


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
