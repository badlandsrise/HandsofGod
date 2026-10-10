extends "res://tests/assets/era3_shots.gd"
## Era 4 (Launch) art review shots. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##     -s res://tests/assets/era4_shots.gd -- --shot=kit        -> tests/shots/era4_art_kit.png
##   ... -- --shot=city                                          -> tests/shots/era4_city.png
##   ... -- --shot=launch                                        -> tests/shots/era4_rocket_launch.png
##   ... -- --shot=preview --ids=rocket,launch_tower [--yaw=30] [--dusk=1]
##   [--out=/abs/path.png]
## kit is the contact sheet: every Era 4 catalog id (and variant) in labelled sections.
## city is one composed diorama of the mid-century city: apartment streets round a square,
## the institute, mission control, the rail line and station, the works and powerhouse,
## wind turbines on the ridge and the launch plateau beyond, villagers in Era 4 clothes.
## launch is the goodbye's first beat (DESIGN 9.2): the rocket on the pad at dusk,
## steaming under the floodlights, the crowd gathered on the plateau in the clothes of
## their trade, the crew in their suits at the shrine garden.
## Reuses era2_shots.gd's and era3_shots.gd's lighting, labels, terrain and globals.


func _run() -> void:
	_register_globals()
	AssetCatalog.set_era(4)
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
	match shot:
		"city":
			_city()
			out = SHOTS + "era4_city.png"
		"launch":
			_launch()
			out = SHOTS + "era4_rocket_launch.png"
		"preview":
			_preview(String(_args.get("ids", "rocket")).split(","))
			if _args.has("dusk"):
				_dusk_preview()
			out = "/tmp/era4_preview.png"
		_:
			_kit4()
			out = SHOTS + "era4_art_kit.png"
	out = _args.get("out", out)
	if DisplayServer.get_name() != "headless":
		for i in int(_args.get("frames", "30")):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
		print("era4 shot saved: ", out)
	quit()


func _villager(i: int, state: StringName, cloth: String) -> VillagerVisual:
	var v := (load("res://scenes/people/villager_visual.tscn") as PackedScene).instantiate() as VillagerVisual
	v.set_era(4)
	v.set_look(Color(SKINS[(i * 2 + 1) % SKINS.size()]), Color(HAIRS[(i * 3) % HAIRS.size()]), Color(cloth), i)
	_world.add_child(v)
	v.play(state, 0.0)
	return v


## Turns every hidden light and NightGlow on (what gameplay does at dusk).
func _lights_on(n: Node) -> void:
	if n is Light3D or String(n.name) == "NightGlow":
		(n as Node3D).visible = true
	for c in n.get_children():
		_lights_on(c)


func _dusk_preview() -> void:
	for c in _world.get_children():
		if c is WorldEnvironment or c is DirectionalLight3D:
			c.free()
	_dusk_light()
	_lights_on(_world)


## Dusk: the sun just down behind the hills, a deep blue sky with a warm band on the
## horizon, cool ambient, a low amber key light (DESIGN 12.2: deep night blue, launch
## floodlights).
func _dusk_light() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#14204a")
	sky_mat.sky_horizon_color = Color("#e8956a")
	sky_mat.ground_horizon_color = Color("#6a5a68")
	sky_mat.ground_bottom_color = Color(0.08, 0.08, 0.1)
	sky_mat.sky_curve = 0.07
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#5f6a9a")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0022
	env.fog_light_color = Color("#8a7f9a")
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ff9a5c")
	sun.light_energy = 0.75
	sun.rotation_degrees = Vector3(-9, -70, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	_world.add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8fa6e0")
	moon.light_energy = 0.25
	moon.rotation_degrees = Vector3(-55, 140, 0)
	_world.add_child(moon)




## Era 4 trades in the colours of their clothes: overalls, coats, suits and dresses.
const JOBS4 := ["#2f5f8a", "#f26b1d", "#3f6f8f", "#2f8c88", "#4a4f5a", "#e0a526", "#c8442e", "#1c2a4a", "#6f8a3c", "#8a5a9e"]


# ------------------------------------------------------------------ contact sheet

func _kit4() -> void:
	_studio_light()
	_flat_ground(Color("#8a9658"))
	for c in _world.get_children():
		if c is DirectionalLight3D:
			(c as DirectionalLight3D).directional_shadow_max_distance = 900.0
		elif c is MeshInstance3D:
			(c as Node3D).scale = Vector3(5, 1, 5)   # the sheet is long: a bigger table
	var z := 0.0
	var row_w := 120.0
	z = _section3("THE ROCKET (BUILD STAGES, LIFTOFF-READY, SEGMENTS) AND THE LAUNCH TOWER (SHRINE, ERA 4)",
		["rocket_stage_1", "rocket_stage_2", "rocket", "rocket_ready", "rocket_segment_booster", "rocket_segment_tank",
		"rocket_segment_upper", "launch_tower"], z, row_w)
	z = _section3("CITY BUILDINGS", ["apartment", "apartment:1", "apartment:2", "institute", "mission_control",
		"radio_telescope", "assembly_hall", "training_centre", "rail_station", "powerhouse", "coal_mine", "foundry",
		"refinery", "factory", "test_stand", "wind_turbine"], z, row_w)
	var st := []
	for id in ["launch_tower", "apartment", "institute", "mission_control", "radio_telescope", "assembly_hall",
			"training_centre", "rail_station", "powerhouse", "coal_mine", "foundry", "refinery", "factory", "test_stand",
			"wind_turbine"]:
		st.append(id + "_plot@0.6")
		st.append(id + "_frame@0.6")
	z = _section3("CONSTRUCTION (x0.6): STAKED PLOT, THEN STEEL FRAME AND CRANE", st, z, row_w)
	z = _section3("STREETS AND THE RAIL LINE", ["road_asphalt", "road_asphalt_cross", "road_asphalt_end", "rail_track",
		"rail_buffer", "rail_crossing", "rail_bridge", "park", "power_pylon", "water_tower", "flag_mission",
		"street_light@2", "bus_stop@2", "phone_box@2", "kiosk@2", "bench_modern@2", "planter_modern@2", "fire_hydrant@2",
		"poster_board@2", "cafe_parasol@2", "city_block_far@0.5", "city_block_far:1@0.5", "city_block_far:2@0.5",
		"city_block_far:3@0.5", "city_block_far:4@0.5"], z, row_w)
	z = _section3("VEHICLES AND TRAINS", ["car@1.5", "car:1@1.5", "car:2@1.5", "bus", "truck", "truck:1", "locomotive",
		"rail_wagon", "rail_wagon:1", "rail_wagon:2", "rail_wagon:3", "passenger_coach"], z, row_w)
	z = _section3("RESOURCES (x2) AND NODES", ["steel_beams@2", "parts_crates@2", "fuel_tanks@2", "coal_pile@2",
		"oil_drums@2", "cable_drum@2", "shipping_container", "shipping_container:1", "shipping_container:2",
		"coal_seam", "oil_seep"], z, row_w)
	z = _section3("TOOLS AND GIFTS (x4)", ["tool_wrench@4", "tool_toolbox@4", "tool_clipboard@4", "tool_welder@4",
		"gift_model_rocket@4", "gift_photograph@4"], z, row_w)
	_title("VILLAGERS: ERA 4 OUTFITS 0-7, THEN THE CREW IN FLIGHT SUITS (x2.5)", z)
	z += 6.0
	for i in 10:
		var v := _villager(i, &"idle", JOBS4[i % JOBS4.size()])
		if i >= 8:
			v.set_look(Color(SKINS[(i * 2 + 1) % SKINS.size()]), Color(HAIRS[(i * 3) % HAIRS.size()]), Color("#ffffff"), i - 8)
			v.set_crew(true)
		v.scale = Vector3.ONE * 2.5
		v.position = Vector3(4.0 + i * 9.0, 0, z + 1.6)
		_caption("outfit %d" % i if i < 8 else "crew %d" % (i - 8), Vector3(4.0 + i * 9.0, 0.05, z + 3.4), 1.0)
	z += 5.0
	var pitch := -42.0
	var tall := z * sin(deg_to_rad(-pitch)) + 14.0
	_vp.size = Vector2i(2400, int(2400.0 * tall / (row_w + 2.0)))
	_ortho_camera(Vector3(row_w * 0.5, 0, z * 0.5 - 3.0), row_w + 2.0, pitch)
	for c in _world.get_children():
		if c is Camera3D:
			(c as Camera3D).position += (c as Camera3D).basis.z * 450.0
			(c as Camera3D).far = 2000.0


# ------------------------------------------------------------------ the city diorama

## Places an id on the ground (height from _height at its origin).
func _put(id: String, x: float, z: float, rot := 0.0, variant := 0) -> Node3D:
	var n := AssetCatalog.instance(StringName(id), variant)
	n.position = Vector3(x, _height(x, z), z)
	n.rotation_degrees.y = rot
	_world.add_child(n)
	return n


func _city() -> void:
	_rng.seed = 4
	_game_light()
	_paths.append([Vector2(-60, 8), Vector2(60, 8), 3.6])
	_paths.append([Vector2(0, 44), Vector2(0, -60), 3.6])
	_yards.append([Vector2(0, -50), Vector2(60, 6)])
	_ground4()
	# the avenue north-south through the city, the cross street, the square (park)
	for k in 24:
		var z := 44.0 - k * 4.0
		if absf(z - 8.0) < 3.0 or absf(z) < 6.0:
			continue
		_put("road_asphalt", 0, z)
	_put("road_asphalt_cross", 0, 8)
	for k in 14:
		var x := 6.0 + k * 4.0 - 2.25
		if x < 5.0:
			continue
		_put("road_asphalt", x, 8, 90)
		_put("road_asphalt", -x, 8, 90)
	_put("park", 0, -2)
	_put("flag_mission", -5.5, -7.5)
	_put("flag_mission", 4.0, -7.5)
	_put("kiosk", 8.5, -2.0)
	_put("cafe_parasol", 8.5, 3.0)
	_put("phone_box", -6.0, 3.5)
	_put("bus_stop", 4.6, 18.0, -90)
	_put("poster_board", -4.6, 14.0, 90)
	for z in [22.0, 34.0, -12.0, -24.0, -36.0]:
		_put("street_light", -3.7, z, 90)
		_put("street_light", 3.7, z + 6.0, -90)
	_put("fire_hydrant", 4.0, 26.0)
	_put("planter_modern", -5.5, -11.0)
	_put("planter_modern", 5.5, -11.0)
	# apartment blocks along the avenue, south of the square and either side of it
	_put("apartment", -12.5, 20.0, 90, 0)
	_put("apartment", -12.5, 36.0, 90, 2)
	_put("apartment", 12.5, 22.0, -90, 1)
	_put("apartment", 12.5, 37.0, -90, 0)
	_put("apartment", -26.0, 20.0, 90, 1)
	_put("apartment_frame", 27.0, 22.0, -90)
	_put("apartment", -14.0, -4.0, 90, 2)
	_put("apartment", 15.0, -4.0, -90, 1)
	# the institute and mission control face each other across the north end of the avenue
	_put("institute", -24.0, -24.0, 90)
	_put("mission_control", 20.0, -26.0, -90)
	_put("radio_telescope", 78.0, -66.0, -40)
	_put("training_centre", 40.0, -12.0, -90)
	# the rail line along the north, the station on the avenue's end, a train in
	for k in 30:
		var x := -116.0 + k * 8.0
		var t := _put("rail_track", x, -50.0, 90)
		t.position.y = 0.0
	(_put("rail_station", -6.0, -44.8, 0) as Node3D).position.y = 0.0
	var train := [["locomotive", 0, 14.4], ["rail_wagon", 3, 10.4], ["rail_wagon", 2, 10.4], ["rail_wagon", 1, 10.4], ["rail_wagon", 0, 10.4]]
	var tx := 26.0
	for c in train:
		var n := AssetCatalog.instance(StringName(c[0]), c[1])
		n.rotation_degrees.y = -90 if c[0] == "locomotive" else 90
		n.position = Vector3(tx, 0.02, -50.0)
		_world.add_child(n)
		tx += float(c[2]) * 0.5 + 5.5
	for k in 2:
		var n := AssetCatalog.instance(&"passenger_coach")
		n.rotation_degrees.y = 90
		n.position = Vector3(-14.0 + k * 16.6, 0.02, -50.0)
		_world.add_child(n)
	# the works east of the avenue: factory, foundry, refinery, powerhouse and the mine
	_put("factory", 36.0, 26.0, -90)
	_put("parts_crates", 26.0, 14.0, 10)
	_put("steel_beams", 30.0, 13.5, 80)
	_put("foundry", 64.0, 10.0, -90)
	_put("refinery", 70.0, -16.0, 0)
	_put("fuel_tanks", 58.0, -4.0, 30)
	_put("powerhouse", -46.0, 30.0, 90)
	_put("coal_pile", -36.0, 44.0)
	_put("coal_mine", -66.0, 6.0, 90)
	for k in 4:
		_put("power_pylon", -52.0, 4.0 - k * 26.0, 0)
	_put("water_tower", -36.0, -12.0)
	# wind turbines on the western ridge
	for k in 4:
		var z := -40.0 + k * 22.0
		_put("wind_turbine", -86.0 - (k % 2) * 6.0, z, 90)
	# the launch plateau beyond the line: the assembly hall, the test stand, the tower and rocket
	_put("assembly_hall", 10.0, -86.0, 0)
	_put("test_stand", 52.0, -82.0, 0)
	var tower := _put("launch_tower", 34.0, -104.0, 180)
	var mount := tower.find_child("RocketMount", true, false) as Node3D
	var rocket := AssetCatalog.instance(&"rocket")
	mount.add_child(rocket)
	_put("road_asphalt_end", 0.0, 46.0, 180)
	# traffic
	var cars := [[1.3, 30.0, 0, 0], [-1.3, 12.0, 180, 1], [1.3, -16.0, 0, 2], [-1.3, -30.0, 180, 0], [18.0, 9.3, 90, 1],
		[-22.0, 6.7, -90, 2], [40.0, 6.7, -90, 0]]
	for c in cars:
		var n := _put("car", c[0], c[1], c[2], c[3])
		n.position.y = 0.08
	(_put("bus", 1.4, 4.0 + 0.0, 0) as Node3D).position.y = 0.08
	(_put("truck", 28.0, 9.3, 90, 0) as Node3D).position.y = 0.08
	(_put("truck", 50.0, 6.7, -90, 1) as Node3D).position.y = 0.08
	_put("shipping_container", 22.0, 34.0, 0, 1)
	_put("shipping_container", 24.6, 34.0, 0, 2)
	# trees round the edges and in the yards
	for t in [[-40, -4], [-44, 12], [30, -40], [-50, -30], [60, 30], [74, 20], [-20, 46], [20, 48], [-8, -60], [50, -58],
			[-60, 40], [-70, 26], [84, -4], [-34, -40], [10, 44]]:
		_put("tree_broad" if _rng.randf() < 0.7 else "tree_pine", t[0] + _rng.randf_range(-2, 2), t[1], _rng.randf_range(0, 360), _rng.randi() % 4)
	for i in 120:
		var a := Vector2(_rng.randf_range(-110, 100), _rng.randf_range(-100, 60))
		if _busy4(a):
			continue
		_put(["grass_clump", "grass_clump", "flowers", "bush"][i % 4], a.x, a.y, _rng.randf_range(0, 360), _rng.randi() % 3)
	# people in the clothes of their trade
	var people := [
		[&"walk", -4.4, 24.0, 180], [&"walk", 4.4, 30.0, 0], [&"idle", 4.8, 17.0, -90], [&"talk", 5.4, 18.6, 200],
		[&"talk", -2.0, -6.0, 30], [&"talk", -1.0, -5.0, 210], [&"sit", 1.6, 1.2, 180], [&"walk", -6.0, -1.0, 90],
		[&"idle", 9.6, 3.6, -40], [&"carry", 27.0, 15.0, -90], [&"work", 30.5, 15.0, 90], [&"walk", -4.4, -20.0, 0],
		[&"walk", 4.4, -32.0, 180], [&"idle", -6.0, -38.0, 10], [&"wave", -9.0, -40.0, 180], [&"cheer", 3.0, -9.0, 0],
		[&"walk", -20.0, 10.6, 90], [&"walk", 14.0, 5.2, -90], [&"work", -38.0, 42.0, 200], [&"carry", 56.0, -2.0, 60],
		[&"idle", 6.6, -2.4, -90], [&"walk", 10.0, 10.6, 90], [&"talk", -8.0, 30.0, 90], [&"talk", -6.8, 30.6, 260],
	]
	for i in people.size():
		var p: Array = people[i]
		var v := _villager(i, p[0], JOBS4[(i * 7 + 3) % JOBS4.size()])
		v.position = Vector3(p[1], _height(p[1], p[2]) + 0.14, p[2])
		v.rotation_degrees.y = p[3]
		v.set_age_scale(1 if i == 7 else 2)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.rotation_degrees = Vector3(float(_args.get("pitch", "-24")), float(_args.get("yaw", "-16")), 0)
	cam.position = Vector3(float(_args.get("cx", "0")), 0, float(_args.get("cz", "-34"))) + cam.basis.z * float(_args.get("dist", "155"))
	cam.far = 900.0
	_world.add_child(cam)
	cam.current = true


func _busy4(a: Vector2) -> bool:
	if a.x > -62.0 and a.x < 80.0 and a.y > -60.0 and a.y < 48.0:
		return true   # the city and the works
	if a.y < -60.0 and a.y > -120.0 and a.x > -10.0 and a.x < 70.0:
		return true   # the launch plateau
	if a.x < -80.0 and a.x > -98.0:
		return true   # the turbine ridge
	return false


## Ground: a flat city shelf, a ridge rising in the west for the turbines, a low rise to
## the north for the launch plateau, gentle swells far out.
func _height(x: float, z: float) -> float:
	var h := _ss(-70.0, -92.0, x) * (5.0 + sin(z * 0.06) * 1.6)
	var far := _ss(90.0, 140.0, Vector2(x, z + 20.0).length())
	h += far * (sin(x * 0.07) * cos(z * 0.09) + 0.8) * 3.0
	return h


func _ground_mix(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var dirt := 0.0
	for s in _paths:
		var q := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		dirt = maxf(dirt, _ss(s[2] + 1.0, s[2] - 0.4, p.distance_to(q)))
	for y in _yards:
		var d: Vector2 = ((p - y[0]).abs() - y[1])
		dirt = maxf(dirt, _ss(1.5, -0.5, maxf(d.x, d.y)) * 0.85)
	var slope := Vector2(_height(x + 1.0, z) - _height(x - 1.0, z), _height(x, z + 1.0) - _height(x, z - 1.0)).length() * 0.5
	var rock := _ss(0.35, 0.8, slope)
	return Color((1.0 - dirt) * (1.0 - rock), dirt, rock, 0.0)


## The game's terrain shader on a 1 m grid (as era3_shots' _ground3, without the coast).
func _ground4() -> void:
	var cell := 1.5
	var x0 := -300.0
	var z0 := -330.0
	var nx := 400
	var nz := 300
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + i * cell
			var z := z0 + j * cell
			verts.append(Vector3(x, _height(x, z), z))
			cols.append(_ground_mix(x, z))
	var idx := PackedInt32Array()
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
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/shaders/terrain.gdshader")
	mat.set_shader_parameter("noise_large", _noise_tex(11, 0.012, 4))
	mat.set_shader_parameter("noise_mid", _noise_tex(23, 0.03, 3))
	mat.set_shader_parameter("noise_fine", _noise_tex(37, 0.06, 2))
	mat.set_shader_parameter("mask_rect", Vector4(-1000, -1000, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_world.add_child(mi)


# ------------------------------------------------------------------ the launch at dusk

## DESIGN 9.2: the rocket on the pad at dusk, fuelled and steaming under the floodlights;
## the whole people gathered on the plateau in the clothes of their trade; the crew in
## their suits at the shrine garden by the old stone.
func _launch() -> void:
	_rng.seed = 9
	_dusk_light()
	_paths.append([Vector2(-60, 40), Vector2(-14, 4), 3.0])
	_yards.append([Vector2(-2, 0), Vector2(15, 13)])
	_ground4()
	var tower := _put("launch_tower", 0, 0, 0)
	tower.position.y = 0.0
	var mount := tower.find_child("RocketMount", true, false) as Node3D
	var rocket := AssetCatalog.instance(&"rocket_ready")
	mount.add_child(rocket)
	# more steam for the photograph: a second, broader plume rolling off the pad
	var steam := rocket.find_child("Steam", true, false) as GPUParticles3D
	if steam:
		for k in 2:
			var s2 := steam.duplicate() as GPUParticles3D
			s2.amount = 60
			s2.rotation_degrees.y = 180.0 - k * 90.0
			s2.position += Vector3(0, 0.2, 0)
			rocket.add_child(s2)
	_lights_on(tower)
	_lights_on(rocket)
	(rocket.find_child("ExhaustLight", true, false) as Node3D).visible = false   # not yet
	# the plateau: the crowd behind a rope line south-west of the pad, flags, lamps
	for k in 6:
		var a := deg_to_rad([222.0, 232.0, 242.0, 298.0, 308.0, 318.0][k])
		var p := Vector3(cos(a), 0, -sin(a)) * 33.0
		var post := AssetCatalog.instance(&"street_light" if k % 3 == 1 else &"flag_mission")
		post.position = p
		post.rotation_degrees.y = rad_to_deg(a) + 90.0
		_world.add_child(post)
	_lights_on(_world)
	_put("mission_control", 62.0, -30.0, -110)
	_put("radio_telescope", -60.0, -50.0, 30)
	_lights_on(_world)
	_put("assembly_hall", -42.0, -44.0, 40)
	_lights_on(_world)
	_put("bus", -40.0, 28.0, 130)
	_put("car", -34.0, 38.0, 40, 1)
	_put("car", -44.0, 34.0, 60, 2)
	_put("truck", 22.0, -24.0, 20, 1)
	_put("fuel_tanks", 16.0, -18.0, 20)
	var n := 0
	for ring in 5:
		var r := 34.0 + ring * 1.3
		var count := 22 + ring * 2
		for k in count:
			var a := deg_to_rad(232.0 + (k + _rng.randf() * 0.6) * 76.0 / count)
			var p := Vector3(cos(a), 0, -sin(a)) * (r + _rng.randf_range(-0.4, 0.4))
			var states := [&"cheer", &"wave", &"idle", &"idle", &"talk", &"cheer"]
			var v := _villager(n, states[(n * 5 + ring) % states.size()], JOBS4[(n * 7 + 3) % JOBS4.size()])
			v.position = p
			v.look_at_from_position(p, Vector3(0, 0, 0), Vector3.UP)
			v.rotate_y(PI)
			v.set_age_scale(1 if n % 9 == 4 else 2)
			n += 1
	# the crew at the shrine garden, by the old stone, before they board
	var bench := tower.find_child("CrewBench", true, false) as Node3D
	for k in 4:
		var seat := bench.find_child("Seat%d" % (k + 1), true, false) as Node3D
		var v := _villager(200 + k, &"idle" if k != 1 else &"wave", "#ffffff")
		v.set_look(Color(SKINS[(k * 3 + 1) % SKINS.size()]), Color(HAIRS[(k * 2) % HAIRS.size()]), Color("#ffffff"), k)
		v.set_crew(true)
		var gp := seat.global_position if seat.is_inside_tree() else seat.position
		var stone := bench.global_position
		v.position = Vector3(gp.x, 0.2, gp.z) + (Vector3(gp.x, 0, gp.z) - Vector3(stone.x, 0, stone.z)).normalized() * 0.9
		v.look_at_from_position(v.position, Vector3(stone.x, 0.2, stone.z), Vector3.UP)
		v.rotate_y(PI)
	var cam := Camera3D.new()
	cam.fov = float(_args.get("fov", "50"))
	cam.rotation_degrees = Vector3(float(_args.get("pitch", "3")), float(_args.get("yaw", "11")), 0)
	cam.position = Vector3(float(_args.get("cx", "8")), float(_args.get("cy", "5.5")), float(_args.get("cz", "57")))
	cam.far = 900.0
	_world.add_child(cam)
	cam.current = true
