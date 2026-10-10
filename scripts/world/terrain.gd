class_name Terrain extends Node3D
## Renders the Valley heightmap as chunked meshes (2 m cells where M1 plays,
## 4 m cells for the roughed-in regions, with skirts hiding the seams), plus
## a HeightMapShape3D for physics and the water surfaces.
## Visuals live under the child "Visual" so real art can replace them.

const CHUNK := 100.0
const DETAIL := Rect2(-220, -110, 440, 250)   # the Clearing, Valley Floor and Western Meadow

var valley: Valley
var material: ShaderMaterial
var water_material: ShaderMaterial
var visual: Node3D
var water: Node3D

# Hand-authored dirt paths of the Clearing (pairs of points).
var paths: Array = []

func build(v: Valley) -> void:
	valley = v
	name = "Terrain"
	var fire := Valley.FIRE
	paths = [
		[fire, Valley.CAVE_MOUTH], [fire, Vector2(Valley.stream_x(-9.0) - 2.0, -9.0)],
		[fire, Vector2(18.0, 0.0)], [Vector2(18.0, 0.0), Valley.EAST_GAP + Vector2(10, 0)],
		[fire, Vector2(-18.0, -2.0)], [Vector2(-18.0, -2.0), Valley.WEST_GAP + Vector2(-10, 0)],
		[Valley.EAST_GAP + Vector2(10, 0), Vector2(110.0, 15.0)],
		[Valley.WEST_GAP + Vector2(-10, 0), Vector2(-115.0, 5.0)],
	]
	material = ShaderMaterial.new()
	material.shader = load("res://scenes/world/shaders/terrain.gdshader")
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var n := int(Valley.HALF * 2.0 / CHUNK)
	for cj in n:
		for ci in n:
			var x0 := -Valley.HALF + ci * CHUNK
			var z0 := -Valley.HALF + cj * CHUNK
			var detailed := DETAIL.intersects(Rect2(x0, z0, CHUNK, CHUNK))
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [ci, cj]
			mi.mesh = _chunk_mesh(x0, z0, 2.0 if detailed else 4.0)
			mi.material_override = material
			visual.add_child(mi)
	_build_collision()
	_build_water()

func _chunk_mesh(x0: float, z0: float, step: float) -> ArrayMesh:
	var cells := int(CHUNK / step)
	var w := cells + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(w * w); norms.resize(w * w); cols.resize(w * w)
	for j in w:
		for i in w:
			var x := x0 + i * step
			var z := z0 + j * step
			var k := j * w + i
			var y := valley.ground_y(x, z)
			verts[k] = Vector3(x, y, z)
			var nrm := valley.normal_at(x, z)
			norms[k] = nrm
			cols[k] = splat(x, z, y, nrm)
	for j in cells:
		for i in cells:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var d := c + 1
			# clockwise front faces seen from above
			idx.append_array([a, b, c, b, d, c])
	# skirts: drop each border edge 3 m to hide cracks between resolutions
	var border: Array = []
	for i in w: border.append(i)                      # north edge
	for j in range(1, w): border.append(j * w + cells) # east
	for i in range(cells - 1, -1, -1): border.append(cells * w + i)  # south
	for j in range(cells - 1, -1, -1): border.append(j * w)          # west
	var base := verts.size()
	for bi in border.size():
		var v: Vector3 = verts[border[bi]]
		verts.append(v - Vector3(0, 3.0, 0))
		norms.append(norms[border[bi]])
		cols.append(cols[border[bi]])
	for bi in border.size() - 1:
		var t0: int = border[bi]
		var t1: int = border[bi + 1]
		var s0 := base + bi
		var s1 := base + bi + 1
		idx.append_array([t0, s0, t1, t1, s0, s1])
		idx.append_array([t0, t1, s0, t1, s1, s0])   # both sides, cheap
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for s in paths:
		best = minf(best, _seg_dist(p, s[0], s[1]))
	return best

## Splat weights (grass, dirt, rock, sand) as a Color.
func splat(x: float, z: float, y: float, nrm: Vector3) -> Color:
	var slope := 1.0 - nrm.y
	var n := valley.noise.get_noise_2d(x * 3.0, z * 3.0)
	var rock := Valley.ss(0.18, 0.36, slope + n * 0.05)
	rock = maxf(rock, Valley.ss(45.0, 70.0, y + n * 8.0) * 0.8)
	var p := Vector2(x, z)
	var dirt := 1.0 - Valley.ss(4.0, 8.5, p.distance_to(Valley.FIRE) + n * 2.0)
	dirt = maxf(dirt, 1.0 - Valley.ss(3.0, 8.0, p.distance_to(Valley.CAVE_MOUTH) + n * 2.0))
	dirt = maxf(dirt, (1.0 - Valley.ss(0.5, 1.6, path_dist(x, z) + n * 1.0)) * 0.75)
	if Rect2(-205, -85, 405, 195).has_point(p):
		dirt = maxf(dirt, Valley.ss(0.55, 0.7, valley.noise.get_noise_2d(x * 1.7 + 50.0, z * 1.7)) * 0.45)
	# dry Southern Plains read dusty
	if z > 160.0 and x < 150.0:
		dirt = maxf(dirt, 0.35 + 0.2 * n)
	var sand := 0.0
	var dr := absf(z - Valley.river_z(x))
	if dr < 16.0 and y < Valley.river_level(x) + 1.1:
		sand = 1.0 - Valley.ss(0.4, 1.1, y - Valley.river_level(x))
	if y < 1.4 and Valley.coast_d(x, z) > -60.0:
		sand = maxf(sand, 1.0 - Valley.ss(0.6, 1.4, y))
	if z > Valley.STREAM_HEAD_Z and absf(x - Valley.stream_x(z)) < 2.8:
		dirt = maxf(dirt, 0.7)
	sand *= 1.0 - rock
	dirt *= (1.0 - rock) * (1.0 - sand)
	var grass := maxf(0.0, 1.0 - rock - dirt - sand)
	return Color(grass, dirt, rock, sand)

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.add_to_group("terrain")
	var shape := HeightMapShape3D.new()
	shape.map_width = Valley.N
	shape.map_depth = Valley.N
	shape.map_data = valley.heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(Valley.CELL, 1.0, Valley.CELL)
	body.add_child(cs)
	add_child(body)

func _build_water() -> void:
	water = Node3D.new()
	water.name = "Water"
	add_child(water)
	var wv := Node3D.new()
	wv.name = "Visual"
	water.add_child(wv)
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://scenes/world/shaders/water.gdshader")
	# The great river: a ribbon along its centre line, west to east.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var x := -Valley.HALF
	var first := true
	while x <= 560.0:
		var z := Valley.river_z(x)
		var dz := (Valley.river_z(x + 1.0) - z)
		var side := Vector3(-dz, 0, 1).normalized()
		var y := Valley.river_level(x)
		var l := Vector3(x, y, z) - side * 11.0
		var r := Vector3(x, y, z) + side * 11.0
		if not first:
			_quad(st, prev_l, l, prev_r, r)
		prev_l = l; prev_r = r; first = false
		x += 6.0
	var river := MeshInstance3D.new()
	river.name = "River"
	river.mesh = st.commit()
	river.material_override = water_material
	wv.add_child(river)
	# The stream from the cave cliff to the river.
	var sm := water_material.duplicate() as ShaderMaterial
	sm.set_shader_parameter("flow_dir", Vector2(0, 1))
	sm.set_shader_parameter("flow_speed", 1.2)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z2 := Valley.STREAM_HEAD_Z
	first = true
	var zend := Valley.river_z(Valley.stream_x(110.0)) - 4.0
	while z2 <= zend:
		var sx := Valley.stream_x(z2)
		var y2 := valley.stream_level(z2)
		var dx := Valley.stream_x(z2 + 0.5) - sx
		var side2 := Vector3(1, 0, -dx * 2.0).normalized()
		var l2 := Vector3(sx, y2, z2) - side2 * 2.0
		var r2 := Vector3(sx, y2, z2) + side2 * 2.0
		if not first:
			_quad(st, prev_l, l2, prev_r, r2)
		prev_l = l2; prev_r = r2; first = false
		z2 += 1.5
	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = st.commit()
	stream.material_override = sm
	wv.add_child(stream)
	# The sea, south-east.
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	sea.mesh = pm
	var seam := water_material.duplicate() as ShaderMaterial
	seam.set_shader_parameter("flow_speed", 0.15)
	seam.set_shader_parameter("deep", Color(0.08, 0.24, 0.38))
	sea.material_override = seam
	sea.position = Vector3(560, Valley.SEA_LEVEL, 560)
	wv.add_child(sea)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a-b along the left bank, c-d along the right
	for v in [a, b, c, b, d, c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
