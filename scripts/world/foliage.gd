class_name Foliage extends Node3D
## MultiMesh trees, bushes, rocks and grass, scattered once from fixed seeds
## (the valley is hand-authored; only the placeholder scatter is noise-driven).
## Chunked so frustum culling works. Visuals under "Visual".

const CELL := 150.0
const GRASS_CELL := 50.0

var valley: Valley
var terrain: Terrain
var visual: Node3D
var tree_points: Array = []          # Vector3 trunk positions, for the navmesh
var _keep_out: Array = []            # [Vector2 centre, radius] clear zones (sites, cave, gaps)

func build(v: Valley, t: Terrain, keep_out: Array) -> void:
	valley = v
	terrain = t
	_keep_out = keep_out
	name = "Foliage"
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/world/shaders/foliage.gdshader")
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://scenes/world/shaders/grass.gdshader")
	var pine := Props.pine_mesh()
	var broad := Props.broadleaf_mesh()
	var rock := Props.rock_mesh()
	var bush := Props.bush_mesh()
	var grass := Props.grass_mesh()
	var buckets: Dictionary = {}       # "kind|cx|cz" -> Array[[Transform3D, Color custom]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# ---- trees: jittered grid, accepted by density
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
				var is_broad := rng.randf() < _broadleaf_share(px, pz, y)
				var s := rng.randf_range(0.8, 1.45) * (1.0 if y < 40.0 else 0.8)
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(px, y - 0.15, pz))
				_add(buckets, "broad" if is_broad else "pine", px, pz, xf, Color(rng.randf(), 1.0 if is_broad else 0.0, 0, 0))
				tree_points.append(Vector3(px, y, pz))
			z += step
		x += step
	# ---- rocks: on slopes, mountains and along the cliff
	for i in 1400:
		var px := rng.randf_range(-Valley.HALF, Valley.HALF)
		var pz := rng.randf_range(-Valley.HALF, Valley.HALF)
		var nrm := valley.normal_at(px, pz)
		var y := valley.ground_y(px, pz)
		var want := 0.04 + Valley.ss(0.08, 0.3, 1.0 - nrm.y) * 0.8 + Valley.ss(30.0, 60.0, y) * 0.4
		if valley.is_water(px, pz) or _blocked(px, pz, 1.5) or rng.randf() > want:
			continue
		var s := rng.randf_range(0.5, 1.6) * (1.6 if y > 35.0 else 1.0)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(px, y - 0.2 * s, pz))
		_add(buckets, "rock", px, pz, xf, Color(rng.randf(), 0, 0, 0))
	# boulders along the cave cliff so it reads as rock
	for i in 26:
		var px := rng.randf_range(-48.0, 48.0)
		if absf(px) < 6.0 or absf(px - Valley.stream_x(-29.0)) < 3.0:
			continue
		var pz := -29.5 - rng.randf_range(0.0, 2.5)
		var s := rng.randf_range(1.0, 2.2)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 1.3, s)), Vector3(px, valley.ground_y(px, pz) - 0.3, pz))
		_add(buckets, "rock", px, pz, xf, Color(rng.randf(), 0, 0, 0))
	# ---- bushes (decorative, not berry sites)
	for i in 900:
		var px := rng.randf_range(-220.0, 220.0)
		var pz := rng.randf_range(-110.0, 140.0)
		if valley.is_water(px, pz) or _blocked(px, pz, 2.0) or terrain.path_dist(px, pz) < 2.0:
			continue
		if valley.normal_at(px, pz).y < 0.85 or rng.randf() > 0.5:
			continue
		var s := rng.randf_range(0.6, 1.2)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(px, valley.ground_y(px, pz) - 0.1, pz))
		_add(buckets, "bush", px, pz, xf, Color(rng.randf(), 1.0, 0, 0))
	# ---- grass tufts where M1 plays
	var g := 1.6
	var gx := Terrain.DETAIL.position.x
	while gx < Terrain.DETAIL.end.x:
		var gz := Terrain.DETAIL.position.y
		while gz < Terrain.DETAIL.end.y:
			var px := gx + rng.randf_range(-0.7, 0.7)
			var pz := gz + rng.randf_range(-0.7, 0.7)
			gz += g
			var y := valley.ground_y(px, pz)
			var nrm := valley.normal_at(px, pz)
			var sp := terrain.splat(px, pz, y, nrm)
			if sp.r < 0.6 or valley.is_water(px, pz):
				continue
			if valley.noise.get_noise_2d(px * 2.0, pz * 2.0) < -0.15 and rng.randf() < 0.7:
				continue
			var s := rng.randf_range(0.7, 1.3)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s)), Vector3(px, y - 0.03, pz))
			_add(buckets, "grass", px, pz, xf, Color(rng.randf(), 0, 0, 0), GRASS_CELL)
		gx += g
	var meshes := {"pine": pine, "broad": broad, "rock": rock, "bush": bush, "grass": grass}
	for key in buckets:
		var kind: String = key.split("|")[0]
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_custom_data(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_")
		mmi.multimesh = mm
		mmi.material_override = gmat if kind == "grass" else mat
		if kind == "grass":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 140.0
			mmi.visibility_range_end_margin = 20.0
		elif kind == "bush":
			mmi.visibility_range_end = 320.0
		visual.add_child(mmi)

func _add(buckets: Dictionary, kind: String, x: float, z: float, xf: Transform3D, custom: Color, cell: float = CELL) -> void:
	var key := "%s|%d|%d" % [kind, floori(x / cell), floori(z / cell)]
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append([xf, custom])

func _blocked(x: float, z: float, pad: float) -> bool:
	var p := Vector2(x, z)
	for k in _keep_out:
		if p.distance_to(k[0]) < k[1] + pad:
			return true
	return false

func _tree_density(x: float, z: float) -> float:
	var y := valley.ground_y(x, z)
	if valley.is_water(x, z) or y < 0.8 or y > 62.0:
		return 0.0
	var nrm := valley.normal_at(x, z)
	if nrm.y < 0.72:
		return 0.0
	if _blocked(x, z, 3.0) or terrain.path_dist(x, z) < 3.5:
		return 0.0
	if absf(z - Valley.river_z(x)) < 15.0:
		return 0.0
	if z > Valley.STREAM_HEAD_Z and absf(x - Valley.stream_x(z)) < 4.0 and z < 120.0:
		return 0.0
	var p := Vector2(x, z - 2.0)
	var dc := Vector2(x, (z - 2.0) * 1.08).length()
	# open heart of the Clearing
	if dc < 34.0:
		return 0.0
	var d := 0.0
	# wooded ridge ringing the Clearing (but not in the two gaps)
	d = maxf(d, exp(-pow((dc - 58.0) / 12.0, 2.0)) * 0.8 * (1.0 - (1.0 - Valley.ss(6.0, 14.0, absf(z - 2.0))) * Valley.ss(30.0, 42.0, absf(x))))
	var n := valley.noise.get_noise_2d(x * 0.7 + 300.0, z * 0.7)
	d = maxf(d, Valley.ss(-0.05, 0.35, n) * 0.55)
	# mountain forests below the tree line
	d = maxf(d, Valley.ss(-100.0, -160.0, z) * Valley.ss(62.0, 40.0, y) * 0.55)
	# a few tall landmarks and copses on the open flats
	if Vector2(x - 110.0, z - 15.0).length() < 60.0 or Vector2(x + 115.0, z - 5.0).length() < 55.0:
		d *= 0.25
	if z > 170.0 and x < 150.0:
		d *= 0.12   # the dry Southern Plains
	if Valley.coast_d(x, z) > -40.0:
		d *= 0.3
	return clampf(d, 0.0, 0.9) * (1.0 if p.length() > 0.0 else 1.0)

func _broadleaf_share(x: float, z: float, y: float) -> float:
	if y > 25.0 or z < -120.0:
		return 0.15
	return 0.55 + 0.3 * valley.noise.get_noise_2d(x * 0.4, z * 0.4 + 99.0)
