extends "res://tests/assets/era2_shots.gd"
## Era 3 (Town) art review shots. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . \
##     -s res://tests/assets/era3_shots.gd -- --shot=kit        -> tests/shots/era3_art_kit.png
##   ... -- --shot=town                                          -> tests/shots/era3_town.png
##   ... -- --shot=preview --ids=townhouse,forge [--yaw=30]      -> a quick lit look at a few ids
##   [--out=/abs/path.png]
## kit is the contact sheet: every Era 3 catalog id (and variant) in labelled sections.
## town is one composed diorama: harbour and lighthouse on the coast, the square with the
## market hall, clock tower and fountain, the great hall of the hand, streets of
## townhouses, the workshops, the aqueduct from the hills, the observatory on its hilltop,
## and villagers in town clothes, on the game's terrain and water shaders.
## Reuses era2_shots.gd's lighting, labels, terrain and globals.

const COAST_Y := -0.7


func _run() -> void:
	_register_globals()
	AssetCatalog.set_era(3)
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
		"town":
			_town()
			out = SHOTS + "era3_town.png"
		"preview":
			_preview(String(_args.get("ids", "townhouse")).split(","))
			out = "/tmp/era3_preview.png"
		_:
			_kit3()
			out = SHOTS + "era3_art_kit.png"
	out = _args.get("out", out)
	if DisplayServer.get_name() != "headless":
		for i in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
		print("era3 shot saved: ", out)
	quit()


func _villager(i: int, state: StringName, cloth: String) -> VillagerVisual:
	var v := (load("res://scenes/people/villager_visual.tscn") as PackedScene).instantiate() as VillagerVisual
	v.set_era(3)
	v.set_look(Color(SKINS[(i * 2 + 1) % SKINS.size()]), Color(HAIRS[(i * 3) % HAIRS.size()]), Color(cloth), i)
	_world.add_child(v)
	v.play(state, 0.0)
	return v


# ------------------------------------------------------------------ quick preview

## A row of ids ("id:variant@scale" as in the kit), lit like the game, seen from the
## three-quarter camera.
func _preview(ids: PackedStringArray) -> void:
	_game_light()
	_flat_ground(Color("#7f9a52"))
	var x := 0.0
	var depth := 0.0
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
		if s == "villager_row":
			continue
		var box := _aabb(n, Transform3D.IDENTITY)
		n.position = Vector3(x - box.position.x, 0, 0)
		x += box.size.x + 2.0
		depth = maxf(depth, maxf(box.size.z, box.size.y))
	if _args.has("people"):
		for i in 8:
			var v := _villager(i, &"idle", JOBS[(i * 3) % JOBS.size()])
			v.position = Vector3(i * 1.2, 0, depth * 0.5 + 3.0)
	var cam := Camera3D.new()
	cam.fov = 35.0
	cam.rotation_degrees = Vector3(float(_args.get("pitch", "-35")), float(_args.get("yaw", "-20")), 0)
	var span := maxf(x, depth * 1.6)
	cam.position = Vector3(x * 0.5, depth * 0.25, 0) + cam.basis.z * (span * 1.25 + 6.0) * float(_args.get("zoom", "1"))
	cam.far = 800.0
	_world.add_child(cam)
	cam.current = true


# ------------------------------------------------------------------ contact sheet

func _kit3() -> void:
	_studio_light()
	_flat_ground(Color("#8a9658"))
	var z := 0.0
	var row_w := 70.0
	z = _section3("TOWN BUILDINGS", ["great_hall", "clocktower", "observatory", "windmill", "lighthouse",
		"townhouse", "townhouse:1", "townhouse:2", "market_hall", "school", "printing_house", "laboratory", "clinic",
		"fire_station", "forge", "mason", "watermill", "harbour", "aqueduct", "aqueduct_end"], z, row_w)
	var st := []
	for id in ["townhouse", "great_hall", "market_hall", "clocktower", "school", "printing_house", "laboratory", "clinic",
			"fire_station", "forge", "mason", "windmill", "watermill", "observatory", "harbour", "lighthouse", "aqueduct"]:
		st.append(id + "_plot")
		st.append(id + "_frame")
	z = _section3("CONSTRUCTION: PLOT, THEN MASONRY AND SCAFFOLD", st, z, row_w)
	z = _section3("STREETS AND SQUARES", ["road_paved", "road_paved_cross", "road_paved_end", "plaza", "fountain", "town_flag",
		"street_lamp@2", "banner_pole@2", "bench_iron@2", "planter@2", "pump@2", "notice_board@2", "statue_hand"], z, row_w)
	z = _section3("CARTS, WAGONS AND SHIPS", ["cart@1.5", "cart:1@1.5", "caravan_wagon@1.5", "fire_cart@1.5", "ship_small", "ship_merchant"], z, row_w)
	z = _section3("RESOURCES (x2)", ["stone_blocks@2", "bricks_pile@2", "iron_ore_pile@2", "iron_bars@2", "books_pile@2", "paper_stack@2",
		"crates@2", "glassware@2", "fire_buckets@2"], z, row_w)
	z = _section3("RESOURCE NODES", ["quarry", "iron_ore"], z, row_w)
	z = _section3("TOOLS (x4)", ["tool_axe_iron@4", "tool_pickaxe_iron@4", "tool_mallet@4", "tool_chisel@4", "tool_saw@4",
		"tool_trowel@4"], z, row_w)
	_title("VILLAGERS: ERA 3 OUTFITS 0-7 (x2.5)", z)
	z += 6.0
	for i in 8:
		var v := _villager(i, &"idle", JOBS[(i * 3) % JOBS.size()])
		v.scale = Vector3.ONE * 2.5
		v.position = Vector3(4.0 + i * 8.2, 0, z + 1.6)
		_caption("outfit %d" % i, Vector3(4.0 + i * 8.2, 0.05, z + 3.4), 1.0)
	z += 5.0
	var pitch := -42.0
	var tall := z * sin(deg_to_rad(-pitch)) + 10.0
	_vp.size = Vector2i(2400, int(2400.0 * tall / (row_w + 2.0)))
	_ortho_camera(Vector3(row_w * 0.5, 0, z * 0.5 - 3.0), row_w + 2.0, pitch)


## The Era 2 sheet layout, made height-aware: Era 3 has towers, and a tall piece seen from
## the 42-degree camera would cover the row (or title) behind it, so each row starts far
## enough back for its tallest piece.
func _section3(title: String, ids: Array, z0: float, row_w: float) -> float:
	_title(title, z0)
	var rows: Array = [[]]
	var x := 0.0
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
			rows.append([])
			x = 0.0
		rows[-1].append([n, box, label, x, w])
		x += w
	var z := z0 + 3.0
	for row in rows:
		var row_d := 0.0
		var lift := 2.5
		for e in row:
			lift = maxf(lift, (e[1] as AABB).size.y * 0.95 - (e[1] as AABB).size.z * 0.4)
			row_d = maxf(row_d, (e[1] as AABB).size.z + 2.4)
		z += lift
		for e in row:
			var box: AABB = e[1]
			var cx: float = e[3] + e[4] * 0.5
			(e[0] as Node3D).position = Vector3(cx - (box.position.x + box.size.x * 0.5), 0, z - box.position.z + 0.3)
			_caption(e[2], Vector3(cx, 0.05, z + box.size.z + 0.9), clampf(e[4] / 8.0, 0.75, 1.0))
		z += row_d
	return z + 1.0


# ------------------------------------------------------------------ town diorama

func _town() -> void:
	_rng.seed = 3
	_game_light()
	# streets first: the ground mesh wears dirt along them and under the square
	for p in [[Vector2(-2, -2), Vector2(-2, 30)], [Vector2(4, -8), Vector2(26, -8)], [Vector2(-8, -8), Vector2(-24, -8)],
			[Vector2(-24, -8), Vector2(-26, 24)], [Vector2(-2, 26), Vector2(-30, 36)], [Vector2(-26, -16), Vector2(-40, -26)]]:
		_paths.append([p[0], p[1], 2.0])
	_yards.append([Vector2(-2, -8), Vector2(6.5, 6.5)])
	_yards.append([Vector2(10, -24), Vector2(10, 5)])
	_ground3()
	_sea()
	var P := func(id: String, x: float, z: float, rot: float = 0.0, variant: int = 0) -> Node3D:
		var n := AssetCatalog.instance(StringName(id), variant)
		n.position = Vector3(x, _height(x, z), z)
		n.rotation_degrees.y = rot
		_world.add_child(n)
		return n
	# the square: plaza paving, the fountain, the town flag, the statue of the hand
	for t in [[-5, -11], [1, -11], [-5, -5], [1, -5]]:
		P.call("plaza", t[0], t[1])
	P.call("fountain", -2, -8)
	P.call("town_flag", 3.5, -12.5)
	P.call("notice_board", -7.2, -1.5, 90)
	P.call("bench_iron", 2.8, -3.0, 180)
	P.call("bench_iron", -6.8, -12.8, 90)
	P.call("planter", 4.2, -2.6)
	P.call("planter", -8.2, -2.6)
	# the great hall of the hand closes the square; the clock tower and market hall flank it
	P.call("great_hall", -2, -29)
	P.call("clocktower", 8.5, -16, -10)
	P.call("market_hall", -15.5, -8, 90)
	P.call("street_lamp", 4.6, -14.5)
	P.call("street_lamp", -8.6, -14.5)
	# the high street south from the square, townhouses both sides
	for k in 7:
		P.call("road_paved", -2, 0 + k * 4)
	P.call("road_paved_end", -2, 28)
	var left := [[-9.5, 3.5, 0], [-9.5, 11.5, 1], [-9.5, 19.5, 2]]
	var right := [[5.5, 3.5, 2], [5.5, 11.5, 0], [5.5, 19.5, 1]]
	for h in left:
		P.call("townhouse", h[0], h[1], 90, h[2])
	for h in right:
		P.call("townhouse", h[0], h[1], -90, h[2])
	for z in [1.5, 9.5, 17.5, 25.5]:
		P.call("street_lamp", -4.6, z, 90)
		P.call("street_lamp", 0.6, z + 4.0, -90)
	P.call("banner_pole", -4.4, 6.0, 90)
	P.call("banner_pole", 0.4, 14.0, -90)
	P.call("cart", -1.0, 12.0, 8, 1)
	P.call("pump", -5.0, 22.5)
	# the harbour road east to the quay
	for k in 5:
		var tile := P.call("road_paved", 7 + k * 4, -8) as Node3D
		tile.rotation_degrees.y = 90
	P.call("caravan_wagon", 14.0, -9.0, 95)
	P.call("printing_house", 16.5, 3.5, -90)
	P.call("books_pile", 11.5, 0.5, 20)
	P.call("school", 17.5, 18.5, -90)
	P.call("fire_station", 17.5, -20.0, -90)
	P.call("fire_cart", 12.0, -21.5, 80)
	# the coast: quay, ships, lighthouse on the point
	P.call("harbour", _coast_x(-6.0) - 6.4, -6.0, -90)
	P.call("crates", 27.0, 1.5, 10)
	P.call("cart", 25.5, -14.0, 170, 1)
	var ship := P.call("ship_merchant", 46.0, -4.0, -10) as Node3D
	ship.position.y = COAST_Y - 0.9
	ship = P.call("ship_small", 52.0, 22.0, 30) as Node3D
	ship.position.y = COAST_Y - 0.8
	P.call("lighthouse", _coast_x(-40.0) + 1.5, -40.0, -90)
	# workshops to the west: forge, mason and the quarry under the hills
	P.call("forge", -24.0, 4.0, 90)
	P.call("iron_bars", -18.5, 1.0, 20)
	P.call("iron_ore_pile", -19.0, 7.5)
	P.call("mason", -24.0, 16.5, 90)
	P.call("stone_blocks", -18.6, 18.5, 80)
	P.call("bricks_pile", -19.2, 13.0, 10)
	P.call("laboratory", -24.0, -22.0, 60)
	P.call("glassware", -19.5, -18.0, 30)
	P.call("clinic", -29.0, -6.5, 90)
	# the hills: observatory on its crown, the aqueduct striding in, a windmill on the rise
	P.call("observatory", -50.0, -28.0, 40)
	for k in 3:   # one level line: the piers run into the hillside rather than following it
		(P.call("aqueduct", -62.0 + k * 12.0, -44.0) as Node3D).position.y = 0.0
	(P.call("aqueduct_end", -30.0, -44.0, 0) as Node3D).position.y = 0.0
	P.call("windmill", -38.0, 30.0, 30)
	P.call("field_ripe", -48.0, 18.0, 5)
	P.call("field_growing", -48.0, 26.0, 5)
	P.call("haystack", -40.0, 12.5)
	P.call("townhouse_frame", -12.0, 31.0, 0)
	P.call("cart", -16.5, 29.0, 60, 0)
	P.call("townhouse_plot", 8.0, 31.0, 0)
	# trees and grass round the edges
	var trees := [[-58, -10], [-62, 4], [-56, 40], [-64, 30], [-30, -34], [-36, -18], [26, 32], [34, 36], [-20, 40], [12, 42],
		[-46, -42], [-60, -50], [-12, -44], [4, -46], [20, -40], [-70, 14], [-52, 6], [30, 24], [-6, 44], [-44, 42]]
	for t in trees:
		var id := "tree_pine" if t[1] < -30 or _rng.randf() < 0.3 else "tree_broad"
		var tx: float = t[0] + _rng.randf_range(-2, 2)
		var tz: float = t[1] + _rng.randf_range(-2, 2)
		P.call(id, tx, tz, _rng.randf_range(0, 360), _rng.randi() % 4)
	for i in 160:
		var a := Vector2(_rng.randf_range(-70, 40), _rng.randf_range(-50, 46))
		if _busy3(a):
			continue
		P.call(["grass_clump", "grass_clump", "flowers", "bush"][i % 4], a.x, a.y, _rng.randf_range(0, 360), _rng.randi() % 3)
	# townsfolk in Era 3 clothes
	var people := [
		[&"talk", -0.6, -3.2, 200], [&"talk", 0.6, -2.4, 30], [&"idle", -5.0, -9.5, 90], [&"walk", 2.6, -9.0, -90],
		[&"carry", -1.0, 4.0, 180], [&"walk", -3.0, 9.5, 0], [&"sit", 2.8, -3.6, 180], [&"cheer", -3.0, -16.5, 0],
		[&"idle", -1.0, -16.0, 10], [&"work", -18.8, 4.0, -90], [&"work", -19.5, 16.0, -100], [&"carry", 22.0, -6.5, 90],
		[&"work", 26.5, -2.5, 60], [&"walk", 9.5, -7.0, 90], [&"wave", 26.0, -10.5, 120], [&"walk", -2.0, 20.0, 180],
		[&"idle", 12.0, 16.0, -60], [&"carry", -14.0, 27.0, 40], [&"work", -40.0, 18.0, 10], [&"idle", -9.5, -14.5, 30],
		[&"walk", -12.0, -6.0, 90], [&"talk", 13.0, 4.5, 200], [&"sit", -6.6, -13.0, 90], [&"work", 12.5, -19.5, 80],
	]
	for i in people.size():
		var p: Array = people[i]
		var v := _villager(i, p[0], JOBS[(i * 7 + 3) % JOBS.size()])
		v.position = Vector3(p[1], _height(p[1], p[2]), p[2])
		v.rotation_degrees.y = p[3]
		v.set_age_scale(1 if i == 15 else 2)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.rotation_degrees = Vector3(float(_args.get("pitch", "-42")), float(_args.get("yaw", "-14")), 0)
	cam.position = Vector3(float(_args.get("cx", "-10")), 0, float(_args.get("cz", "3"))) + cam.basis.z * float(_args.get("dist", "86"))
	cam.far = 700.0
	_world.add_child(cam)
	cam.current = true


static func _coast_x(z: float) -> float:
	return 31.0 + sin(z * 0.045 + 0.4) * 3.0 + _ss(-20.0, -42.0, z) * 4.0


func _busy3(a: Vector2) -> bool:
	if a.x > _coast_x(a.y) - 3.0:
		return true
	if a.x > -34.0 and a.x < 24.0 and a.y > -40.0 and a.y < 34.0:
		return true   # the town
	if a.x < -40.0 and a.x > -58.0 and a.y > 12.0 and a.y < 32.0:
		return true   # fields
	if a.distance_to(Vector2(-50, -28)) < 11.0 or (a.y > -48.0 and a.y < -40.0 and a.x < -22.0):
		return true   # observatory, aqueduct
	return false


## Ground: a flat town shelf, the shore dropping to the sea in the east, hills rising
## in the west with the observatory's crown, swells far out.
func _height(x: float, z: float) -> float:
	var h := -3.4 * _ss(_coast_x(z) - 1.0, _coast_x(z) + 7.0, x)
	var hills := _ss(-36.0, -66.0, x) * (2.5 + sin(z * 0.09) * 1.2 + cos(x * 0.13) * 0.8)
	h += hills
	var d := Vector2(x, z).distance_to(Vector2(-50, -28))
	h += 3.2 * _ss(18.0, 7.0, d) - hills * _ss(14.0, 7.0, d) * 0.6
	var far := _ss(48.0, 80.0, Vector2(x + 10.0, z).length()) * (1.0 - _ss(_coast_x(z) - 6.0, _coast_x(z), x))
	h += far * (sin(x * 0.11) * cos(z * 0.13) + 0.6) * 1.2
	return h


## The Era 2 mix plus sand: alpha marks the bank, and the coast flag (UV2.y) turns it to
## beach rather than river mud; rock shows on the steep hill flanks.
func _ground_mix(x: float, z: float) -> Color:
	var c := super(x, z)
	var shore := _ss(_coast_x(z) - 6.0, _coast_x(z) + 0.5, x)
	var slope := Vector2(_height(x + 1.0, z) - _height(x - 1.0, z), _height(x, z + 1.0) - _height(x, z - 1.0)).length() * 0.5
	var rock := _ss(0.35, 0.8, slope) * (1.0 - shore)
	return Color(c.r * (1.0 - rock), c.g, rock, shore)


func _ground3() -> void:
	var cell := 1.0
	var x0 := -140.0
	var z0 := -130.0
	var nx := 280
	var nz := 220
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uv2 := PackedVector2Array()
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + i * cell
			var z := z0 + j * cell
			var h := _height(x, z)
			verts.append(Vector3(x, h, z))
			cols.append(_ground_mix(x, z))
			uv2.append(Vector2(_ss(1.2, 0.0, absf(h - COAST_Y)), 1.0))
	var idx := PackedInt32Array()
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			idx.append_array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
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


## The sea: one wide sheet of the game's water shader east of the coast.
func _sea() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(220, 300)
	pm.subdivide_width = 40
	pm.subdivide_depth = 40
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/shaders/water.gdshader")
	mat.set_shader_parameter("flow_dir", Vector2(-0.3, 0.2))
	mat.set_shader_parameter("flow_speed", 0.15)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(20.0 + 110.0, COAST_Y, -20.0)
	_world.add_child(mi)
