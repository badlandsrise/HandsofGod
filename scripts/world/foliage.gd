class_name Foliage extends Node3D
## The valley's plant and rock scatter, from the art catalog (AssetCatalog.baked_mesh)
## drawn as chunked MultiMeshes so frustum culling works: a forest ringing the Clearing,
## copses and mountain forest, understory bushes, ferns and flowers, rocks and boulders,
## fallen logs and stumps, reeds and stones along the stream and river, and grass tufts.
## Scattered once from fixed seeds (the valley is hand-authored). Trees and bushes swap
## to their autumn and winter variants with the season. Visuals under "Visual".

const CELL := 150.0
const SMALL_CELL := 50.0
const TREES := [&"tree_pine", &"tree_broad", &"tree_birch"]
## id -> [wind sway, seasonal swap, visibility range (0 = always)]
const KINDS := {
	&"tree_pine": [1.0, true, 0.0], &"tree_broad": [1.0, true, 0.0], &"tree_birch": [1.0, true, 0.0],
	&"tree_dead": [0.3, true, 0.0], &"bush": [1.0, true, 320.0], &"fern": [1.0, false, 160.0],
	&"flowers": [1.0, false, 130.0], &"grass_clump": [1.0, false, 130.0],
	&"rock_small": [0.0, true, 200.0], &"rock_large": [0.0, true, 0.0],
	&"log_fallen": [0.0, true, 240.0], &"stump": [0.0, true, 200.0], &"lilypad": [0.0, false, 160.0],
}

## contact-shadow radius (m at scale 1) per kind, for the ground mask
const CONTACT_R := {&"bush": 1.1, &"log_fallen": 1.5, &"stump": 0.9, &"rock_small": 0.45, &"rock_large": 1.8, &"fern": 0.5}

var valley: Valley
var terrain: Terrain
var visual: Node3D
var tree_points: Array = []          # Vector3 trunk positions, for the navmesh
var rock_points: Array = []          # [Vector3, radius] big rocks and logs, for the navmesh
var contact_points: Array = []       # [Vector3, radius, 0] small things that shade the ground (ground mask)
var counts: Dictionary = {}          # id -> instances placed (for tests and tuning)
var _keep_out: Array = []            # [Vector2 centre, radius] clear zones (sites, cave, gaps)
var _mmis: Array = []                # [MultiMeshInstance3D, id, variant]
var _season: StringName = &""

func build(v: Valley, t: Terrain, keep_out: Array) -> void:
	valley = v
	terrain = t
	_keep_out = keep_out
	name = "Foliage"
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var buckets: Dictionary = {}       # "id:variant|cx|cz" -> Array[Transform3D]
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	_scatter_trees(buckets, rng)
	_scatter_rocks(buckets, rng)
	_scatter_understory(buckets, rng)
	_scatter_water_edges(buckets, rng)
	for key in buckets:
		var head: String = key.split("|")[0]
		var id := StringName(head.split(":")[0])
		var variant := int(head.split(":")[1])
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(id, variant, &"")
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_").replace(":", "_")
		mmi.multimesh = mm
		var vis: float = KINDS[id][2]
		if vis > 0.0:
			mmi.visibility_range_end = vis
			mmi.visibility_range_end_margin = vis * 0.1
		if id in [&"fern", &"flowers", &"grass_clump", &"lilypad"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(mmi)
		_mmis.append([mmi, id, variant])
	_build_grass(rng)
	if not Events.season_changed.is_connected(_on_season):
		Events.season_changed.connect(_on_season)

## Mesh for a scatter kind: the catalog variant with scatter materials (wind, snow, dim).
func _mesh(id: StringName, variant: int, season: StringName) -> ArrayMesh:
	var key := "%s|%d|%s" % [id, variant, season]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var src := AssetCatalog.baked_mesh(id, variant, season)
	var m := src.duplicate() as ArrayMesh
	var sway: float = KINDS.get(id, [0.0])[0]
	for i in m.get_surface_count():
		m.surface_set_material(i, ArtPalette.scatter_material(src.surface_get_material(i), sway))
	_mesh_cache[key] = m
	return m

static var _mesh_cache: Dictionary = {}

func _on_season(season: int) -> void:
	set_season(season)

## Swaps trees, bushes, rocks and logs to their autumn / winter variants.
func set_season(season: int) -> void:
	var s: StringName = &""
	match season:
		Clock.Season.AUTUMN: s = &"autumn"
		Clock.Season.WINTER: s = &"winter"
	if s == _season:
		return
	_season = s
	for row in _mmis:
		var id: StringName = row[1]
		if not KINDS[id][1]:
			continue
		var want := s if s != &"" and AssetCatalog.variant_count(id, s) > 0 and _has_season(id, s) else &""
		(row[0] as MultiMeshInstance3D).multimesh.mesh = _mesh(id, row[2], want)

func _has_season(id: StringName, s: StringName) -> bool:
	return (AssetCatalog.entry(id).get("seasons", {}) as Dictionary).has(String(s))

func _add(buckets: Dictionary, id: StringName, variant: int, x: float, z: float, xf: Transform3D, cell: float = CELL) -> void:
	var n := maxi(AssetCatalog.variant_count(id), 1)
	var key := "%s:%d|%d|%d" % [id, posmod(variant, n), floori(x / cell), floori(z / cell)]
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(xf)
	counts[id] = int(counts.get(id, 0)) + 1
	var cr: float = CONTACT_R.get(id, 0.0)
	if cr > 0.0 and _in_detail(x, z):
		contact_points.append([xf.origin, cr * xf.basis.get_scale().x, 0])

func _xf(x: float, z: float, s: float, sink: float = 0.1, rng: RandomNumberGenerator = null, tilt: float = 0.0) -> Transform3D:
	var yaw := rng.randf() * TAU if rng else 0.0
	var b := Basis(Vector3.UP, yaw)
	if tilt > 0.0 and rng:
		b = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, tilt)) * b
	return Transform3D(b.scaled(Vector3.ONE * s), Vector3(x, valley.ground_y(x, z) - sink, z))

# ---------------------------------------------------------------- trees

func _scatter_trees(buckets: Dictionary, rng: RandomNumberGenerator) -> void:
	var step := 6.0
	var x := -Valley.HALF + 3.0
	while x < Valley.HALF:
		var z := -Valley.HALF + 3.0
		while z < Valley.HALF:
			var px := x + rng.randf_range(-2.6, 2.6)
			var pz := z + rng.randf_range(-2.6, 2.6)
			var d := _tree_density(px, pz)
			if d > 0.0 and rng.randf() < d:
				var y := valley.ground_y(px, pz)
				var id := _species(px, pz, y, rng)
				# 6 to 12 m tall: the catalog trees stand 5.7 to 7.5 m at scale 1
				var s := rng.randf_range(1.0, 1.6) * (1.0 if y < 40.0 else 0.85)
				_add(buckets, id, rng.randi(), px, pz, _xf(px, pz, s, 0.15, rng))
				tree_points.append(Vector3(px, y, pz))
				# a fallen log or stump now and then under the trees
				if rng.randf() < 0.06 and _in_detail(px, pz):
					var lx := px + rng.randf_range(-3.0, 3.0)
					var lz := pz + rng.randf_range(-3.0, 3.0)
					if not _blocked(lx, lz, 2.0) and not valley.is_water(lx, lz):
						var kind := &"log_fallen" if rng.randf() < 0.55 else &"stump"
						_add(buckets, kind, rng.randi(), lx, lz, _xf(lx, lz, rng.randf_range(0.8, 1.2), 0.05, rng))
			z += step
		x += step
	# the forest edge right round the Clearing: a second, denser row of trees
	for i in 520:
		var a := rng.randf() * TAU
		var r := rng.randf_range(29.0, 46.0)
		var px := sin(a) * r
		var pz := 2.0 + cos(a) * r / 1.08
		if _tree_density(px, pz, 28.0) <= 0.0 or rng.randf() > lerpf(0.35, 0.9, Valley.ss(29.0, 40.0, r)):
			continue
		var y := valley.ground_y(px, pz)
		var id := _species(px, pz, y, rng)
		_add(buckets, id, rng.randi(), px, pz, _xf(px, pz, rng.randf_range(0.95, 1.5), 0.15, rng))
		tree_points.append(Vector3(px, y, pz))

func _species(x: float, z: float, y: float, rng: RandomNumberGenerator) -> StringName:
	if rng.randf() < 0.03:
		return &"tree_dead"
	var broad := 0.15 if (y > 25.0 or z < -120.0) else 0.55 + 0.3 * valley.noise.get_noise_2d(x * 0.4, z * 0.4 + 99.0)
	if rng.randf() > broad:
		return &"tree_pine"
	return &"tree_birch" if rng.randf() < 0.3 else &"tree_broad"

func _in_detail(x: float, z: float) -> bool:
	return Terrain.DETAIL.has_point(Vector2(x, z))

# ---------------------------------------------------------------- rocks

func _scatter_rocks(buckets: Dictionary, rng: RandomNumberGenerator) -> void:
	for i in 1500:
		var px := rng.randf_range(-Valley.HALF, Valley.HALF)
		var pz := rng.randf_range(-Valley.HALF, Valley.HALF)
		var nrm := valley.normal_at(px, pz)
		var y := valley.ground_y(px, pz)
		var want := 0.04 + Valley.ss(0.08, 0.3, 1.0 - nrm.y) * 0.8 + Valley.ss(30.0, 60.0, y) * 0.4
		if valley.is_water(px, pz) or _blocked(px, pz, 1.5) or rng.randf() > want:
			continue
		if terrain.path_dist(px, pz) < 2.5:
			continue
		var big := rng.randf() < 0.35 or y > 35.0
		var s := rng.randf_range(0.6, 1.3) * (1.4 if y > 35.0 else 1.0)
		_add(buckets, &"rock_large" if big else &"rock_small", rng.randi(), px, pz, _xf(px, pz, s * (1.0 if big else 2.2), 0.25 * s, rng, 0.25))
		if big and _in_detail(px, pz):
			rock_points.append([Vector3(px, y, pz), 1.4 * s])
	# boulders tumbled at the foot of the cave cliff
	for i in 40:
		var px := rng.randf_range(-50.0, 50.0)
		if absf(px) < 8.0 or absf(px - Valley.stream_x(-29.0)) < 3.5:
			continue
		var pz := -26.5 + rng.randf_range(-1.5, 2.5)
		if _blocked(px, pz, 0.5):
			continue
		var big := rng.randf() < 0.4
		var s := rng.randf_range(0.6, 1.1)
		_add(buckets, &"rock_large" if big else &"rock_small", rng.randi(), px, pz, _xf(px, pz, s * (1.0 if big else 2.4), 0.3, rng, 0.3), SMALL_CELL)
		if big:
			rock_points.append([Vector3(px, valley.ground_y(px, pz), pz), 1.3 * s])

# ---------------------------------------------------------------- understory

func _scatter_understory(buckets: Dictionary, rng: RandomNumberGenerator) -> void:
	# bushes over the valley, thicker at the forest edges
	for i in 2600:
		var px := rng.randf_range(-230.0, 230.0)
		var pz := rng.randf_range(-120.0, 150.0)
		if valley.is_water(px, pz) or _blocked(px, pz, 1.5) or terrain.path_dist(px, pz) < 2.2:
			continue
		if valley.normal_at(px, pz).y < 0.85:
			continue
		var edge := _edge_weight(px, pz)
		if rng.randf() > 0.12 + edge * 0.6:
			continue
		_add(buckets, &"bush", rng.randi(), px, pz, _xf(px, pz, rng.randf_range(0.8, 1.4), 0.08, rng), SMALL_CELL)
	# ferns, flowers and grass clumps in drifts (noise patches), mostly where M1 plays
	for i in 9000:
		var px := rng.randf_range(Terrain.DETAIL.position.x, Terrain.DETAIL.end.x)
		var pz := rng.randf_range(Terrain.DETAIL.position.y, Terrain.DETAIL.end.y)
		if valley.is_water(px, pz) or _blocked(px, pz, 0.6) or terrain.path_dist(px, pz) < 1.4:
			continue
		var y := valley.ground_y(px, pz)
		var nrm := valley.normal_at(px, pz)
		if terrain.splat(px, pz, y, nrm).r < 0.55:
			continue
		var edge := _edge_weight(px, pz)
		var patch := valley.noise.get_noise_2d(px * 2.3 + 77.0, pz * 2.3)
		var r := rng.randf()
		if edge > 0.3 and r < 0.5 * edge:
			_add(buckets, &"fern", rng.randi(), px, pz, _xf(px, pz, rng.randf_range(0.9, 1.5), 0.05, rng), SMALL_CELL)
		elif patch > 0.18 and r < 0.55:
			_add(buckets, &"flowers", rng.randi(), px, pz, _xf(px, pz, rng.randf_range(0.8, 1.3), 0.02, rng), SMALL_CELL)
		elif patch < -0.1 and r < 0.35:
			_add(buckets, &"grass_clump", rng.randi(), px, pz, _xf(px, pz, rng.randf_range(1.2, 2.0), 0.02, rng), SMALL_CELL)

## 0..1: how close (x, z) is to the trees (the forest edge round the Clearing, copses).
func _edge_weight(x: float, z: float) -> float:
	var dc := Vector2(x, (z - 2.0) * 1.08).length()
	var ring := exp(-pow((dc - 32.0) / 7.0, 2.0))
	var n := valley.noise.get_noise_2d(x * 0.7 + 300.0, z * 0.7)
	return clampf(maxf(ring, Valley.ss(-0.1, 0.3, n) * 0.7), 0.0, 1.0)

# ---------------------------------------------------------------- water edges

func _scatter_water_edges(buckets: Dictionary, rng: RandomNumberGenerator) -> void:
	# the stream from the cliff to the river: stones and reeds on both banks
	var z := Valley.STREAM_HEAD_Z + 1.0
	var zend := Valley.river_z(Valley.stream_x(110.0)) - 6.0
	while z < zend:
		for side in [-1.0, 1.0]:
			var bx: float = Valley.stream_x(z) + side * rng.randf_range(2.1, 3.2)
			var bz: float = z + rng.randf_range(-0.8, 0.8)
			if _blocked(bx, bz, 0.0):
				continue
			var r := rng.randf()
			if r < 0.45:
				_add(buckets, &"rock_small", rng.randi(), bx, bz, _xf(bx, bz, rng.randf_range(1.0, 2.2), 0.15, rng, 0.4), SMALL_CELL)
			elif r < 0.8:
				_add(buckets, &"grass_clump", rng.randi(), bx, bz, _reed_xf(bx, bz, rng), SMALL_CELL)
			elif r < 0.9:
				_add(buckets, &"fern", rng.randi(), bx, bz, _xf(bx, bz, rng.randf_range(0.9, 1.3), 0.05, rng), SMALL_CELL)
		z += rng.randf_range(0.8, 1.6)
	# the great river: rocks and reed beds on its banks, lilies in the slack water
	var x := -230.0
	while x < 230.0:
		var rz := Valley.river_z(x)
		for side in [-1.0, 1.0]:
			var bz: float = rz + side * rng.randf_range(9.5, 13.0)
			var bx: float = x + rng.randf_range(-2.0, 2.0)
			if valley.is_water(bx, bz):
				continue
			var r := rng.randf()
			if r < 0.35:
				_add(buckets, &"rock_small", rng.randi(), bx, bz, _xf(bx, bz, rng.randf_range(1.2, 2.6), 0.2, rng, 0.4))
			elif r < 0.45:
				_add(buckets, &"rock_large", rng.randi(), bx, bz, _xf(bx, bz, rng.randf_range(0.5, 0.9), 0.4, rng, 0.3))
			else:
				for k in 3:
					var qx: float = bx + rng.randf_range(-1.2, 1.2)
					var qz: float = bz + rng.randf_range(-0.8, 0.8)
					if not valley.is_water(qx, qz):
						_add(buckets, &"grass_clump", rng.randi(), qx, qz, _reed_xf(qx, qz, rng))
		if rng.randf() < 0.3:
			var lx := x + rng.randf_range(-2.0, 2.0)
			var lz := rz + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(5.0, 8.0)
			if valley.is_water(lx, lz):
				var wy := valley.water_level(lx, lz)
				_add(buckets, &"lilypad", rng.randi(), lx, lz, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(lx, wy + 0.02, lz)))
		x += rng.randf_range(2.0, 3.5)

## Reeds: tall, thin grass clumps.
func _reed_xf(x: float, z: float, rng: RandomNumberGenerator) -> Transform3D:
	var s := rng.randf_range(1.6, 2.4)
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 0.8, s * rng.randf_range(1.6, 2.4), s * 0.8))
	return Transform3D(b, Vector3(x, valley.ground_y(x, z) - 0.05, z))

# ---------------------------------------------------------------- grass

## Fine grass tufts (cheap curved-blade mesh, grass shader) where M1 plays: dense in
## the Clearing, sparser further out, thinning on paths; plus ground clutter (clover,
## fallen leaves under the trees, tiny flowers, pebbles by the paths).
func _build_grass(rng: RandomNumberGenerator) -> void:
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://scenes/world/shaders/grass.gdshader")
	var tm: ShaderMaterial = terrain.material
	for k in ["noise_large", "noise_fine", "grass_deep", "grass_lush", "grass_yellow", "grass_bleached"]:
		var v = tm.get_shader_parameter(k)
		if v != null:
			gmat.set_shader_parameter(k, v)
	var cmat := ShaderMaterial.new()
	cmat.shader = load("res://scenes/world/shaders/clutter.gdshader")
	var grass := Props.grass_mesh()
	var clutter := [Props.clutter_mesh(0), Props.clutter_mesh(1), Props.clutter_mesh(2)]
	var buckets: Dictionary = {}          # "kind|cx|cz" -> Array[Transform3D]
	var core := Rect2(-70, -45, 140, 100)
	var gx := Terrain.DETAIL.position.x
	while gx < Terrain.DETAIL.end.x:
		var gz := Terrain.DETAIL.position.y
		while gz < Terrain.DETAIL.end.y:
			var in_core := core.has_point(Vector2(gx, gz))
			var g := 0.95 if in_core else 1.7
			var px := gx + rng.randf_range(-0.45, 0.45) * g
			var pz := gz + rng.randf_range(-0.45, 0.45) * g
			gz += g
			if valley.is_water(px, pz):
				continue
			var y := valley.ground_y(px, pz)
			var nrm := valley.normal_at(px, pz)
			var sp := terrain.splat(px, pz, y, nrm)
			var pd := terrain.path_dist(px, pz)
			var thin := sp.r * Valley.ss(0.5, 1.6, pd)
			if thin < 0.35 or rng.randf() > thin * 1.2:
				# bare ground: maybe a pebble by the path
				if pd < 2.2 and in_core and rng.randf() < 0.18 and sp.b < 0.3:
					_bucket(buckets, "pebble", px, pz, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.18, 0.4)), Vector3(px, y - 0.04, pz)))
				continue
			if valley.noise.get_noise_2d(px * 2.0, pz * 2.0) < -0.25 and rng.randf() < 0.5:
				continue
			var s := rng.randf_range(0.55, 0.95) * lerpf(0.65, 1.0, thin)
			_bucket(buckets, "grass", px, pz, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.35), s)), Vector3(px, y - 0.03, pz)))
			if in_core:
				var r := rng.randf()
				var cp := Vector2(px + rng.randf_range(-0.4, 0.4), pz + rng.randf_range(-0.4, 0.4))
				var cy := valley.ground_y(cp.x, cp.y)
				if r < 0.07:
					_bucket(buckets, "clover", cp.x, cp.y, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.8)), Vector3(cp.x, cy, cp.y)))
				elif r < 0.085:
					_bucket(buckets, "bloom", cp.x, cp.y, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(cp.x, cy, cp.y)))
		gx += 0.95 if (gx > core.position.x and gx < core.end.x) else 1.7
	# fallen leaves round the trees near the Clearing
	for t in tree_points:
		var tp: Vector3 = t
		if not core.grow(20.0).has_point(Vector2(tp.x, tp.z)):
			continue
		for i in 10:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 3.8
			var lx := tp.x + cos(a) * d
			var lz := tp.z + sin(a) * d
			if valley.is_water(lx, lz):
				continue
			_bucket(buckets, "leaf", lx, lz, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.8)), Vector3(lx, valley.ground_y(lx, lz) + 0.01, lz)))
	var pebble := _mesh(&"rock_small", 0, &"")
	for key in buckets:
		var kind: String = key.split("|")[0]
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = kind != "pebble"
		match kind:
			"grass": mm.mesh = grass
			"clover": mm.mesh = clutter[0]
			"leaf": mm.mesh = clutter[1]
			"bloom": mm.mesh = clutter[2]
			_: mm.mesh = pebble
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			if mm.use_custom_data:
				mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_")
		mmi.multimesh = mm
		if kind == "grass":
			mmi.material_override = gmat
		elif kind != "pebble":
			mmi.material_override = cmat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 120.0 if kind == "grass" else 80.0
		mmi.visibility_range_end_margin = 15.0
		visual.add_child(mmi)
		counts[StringName(kind)] = int(counts.get(StringName(kind), 0)) + list.size()

func _bucket(buckets: Dictionary, kind: String, x: float, z: float, xf: Transform3D) -> void:
	var key := "%s|%d|%d" % [kind, floori(x / SMALL_CELL), floori(z / SMALL_CELL)]
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(xf)

# ---------------------------------------------------------------- density

func _blocked(x: float, z: float, pad: float) -> bool:
	var p := Vector2(x, z)
	for k in _keep_out:
		if p.distance_to(k[0]) < k[1] + pad:
			return true
	return false

func _tree_density(x: float, z: float, open_r: float = 36.0) -> float:
	var y := valley.ground_y(x, z)
	if valley.is_water(x, z) or y < 0.8 or y > 62.0:
		return 0.0
	var nrm := valley.normal_at(x, z)
	if nrm.y < 0.72:
		return 0.0
	if _blocked(x, z, 3.0) or terrain.path_dist(x, z) < 4.0:
		return 0.0
	if absf(z - Valley.river_z(x)) < 15.0:
		return 0.0
	if z > Valley.STREAM_HEAD_Z and absf(x - Valley.stream_x(z)) < 4.5 and z < 120.0:
		return 0.0
	var dc := Vector2(x, (z - 2.0) * 1.08).length()
	# the open heart of the Clearing
	if dc < open_r:
		return 0.0
	var d := 0.0
	# the wooded ridge ringing the Clearing (but not in the two gaps)
	d = maxf(d, exp(-pow((dc - 56.0) / 14.0, 2.0)) * 0.9 * (1.0 - (1.0 - Valley.ss(6.0, 14.0, absf(z - 2.0))) * Valley.ss(30.0, 42.0, absf(x))))
	var n := valley.noise.get_noise_2d(x * 0.7 + 300.0, z * 0.7)
	d = maxf(d, Valley.ss(-0.05, 0.35, n) * 0.55)
	# mountain forests below the tree line
	d = maxf(d, Valley.ss(-100.0, -160.0, z) * Valley.ss(62.0, 40.0, y) * 0.55)
	# open flats with a few copses
	if Vector2(x - 110.0, z - 15.0).length() < 60.0 or Vector2(x + 115.0, z - 5.0).length() < 55.0:
		d *= 0.25
	if z > 170.0 and x < 150.0:
		d *= 0.12   # the dry Southern Plains
	if Valley.coast_d(x, z) > -40.0:
		d *= 0.3
	# far from where M1 plays the forest thins (cheaper, and it reads as distance)
	if not _in_detail(x, z):
		d *= 0.6
	return clampf(d, 0.0, 0.9)
