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
	# The old trails of the Clearing are desire paths now (scripts/world/paths.gd,
	# seeded by seed_trails()); only the built Pass Road is laid into the ground.
	paths = []
	for i in Valley.PASS.size() - 1:
		paths.append([Valley.PASS[i], Valley.PASS[i + 1]])
	material = ShaderMaterial.new()
	material.shader = load("res://scenes/world/shaders/terrain.gdshader")
	material.set_shader_parameter("noise_large", _noise_tex(11, 0.012, 4))
	material.set_shader_parameter("noise_mid", _noise_tex(23, 0.03, 3))
	material.set_shader_parameter("noise_fine", _noise_tex(37, 0.06, 2))
	material.set_shader_parameter("mask_rect", Vector4(DETAIL.position.x, DETAIL.position.y, DETAIL.size.x, DETAIL.size.y))
	GroundLook.apply(material, GroundLook.current())
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
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(w * w); norms.resize(w * w); cols.resize(w * w); uv2.resize(w * w)
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
			uv2[k] = shore(x, z, y)
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
		uv2.append(uv2[border[bi]])
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
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## A seamless 256 px noise texture for the ground shader.
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

const MASK_PX := 0.5     # metres per ground-mask texel

## Bakes the ground mask (contact shadow, canopy, moss) over DETAIL from the trees,
## rocks and props, so the ground darkens under what stands on it.
## trees: Array[Vector3]; blobs: Array of [Vector3 centre, radius, kind] with kind
## 0 = contact shadow, 2 = moss.
func bake_ground_mask(trees: Array, blobs: Array) -> void:
	var w := int(DETAIL.size.x / MASK_PX)
	var h := int(DETAIL.size.y / MASK_PX)
	var data := PackedByteArray()
	data.resize(w * h * 3)
	data.fill(0)
	for t in trees:
		var p: Vector3 = t
		_stamp(data, w, h, p.x, p.z, 2.2, 0, 0.75)      # trunk contact shadow
		_stamp(data, w, h, p.x, p.z, 4.5, 1, 0.9)       # canopy: forest floor
	for b in blobs:
		var p: Vector3 = b[0]
		var r: float = b[1]
		var kind: int = b[2]
		_stamp(data, w, h, p.x, p.z, r, kind, 0.8)
		if kind == 0:
			_stamp(data, w, h, p.x, p.z, r * 1.4, 2, 0.45)   # a little moss round boulders
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	material.set_shader_parameter("ground_mask", ImageTexture.create_from_image(img))

func _stamp(data: PackedByteArray, w: int, h: int, x: float, z: float, r: float, ch: int, strength: float) -> void:
	var cx := (x - DETAIL.position.x) / MASK_PX
	var cz := (z - DETAIL.position.y) / MASK_PX
	var rp := r / MASK_PX
	var i0 := maxi(int(cx - rp), 0)
	var i1 := mini(int(cx + rp) + 1, w - 1)
	var j0 := maxi(int(cz - rp), 0)
	var j1 := mini(int(cz + rp) + 1, h - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := Vector2(i - cx, j - cz).length() / rp
			if d >= 1.0:
				continue
			var v := int(255.0 * strength * (1.0 - d * d) * (1.0 - d * d))
			var k := (j * w + i) * 3 + ch
			if v > data[k]:
				data[k] = v

## The trails of a new valley (as desire-path wear): from the fire to the cave,
## the stream, the two gaps and the bushes. Faint; use keeps them, or they fade.
func trail_lines() -> Array:
	var fire := Valley.FIRE
	var segs := [
		[fire, Valley.CAVE_MOUTH], [fire, Vector2(Valley.stream_x(-9.0) - 2.0, -9.0)],
		[fire, Vector2(18.0, 0.0)], [Vector2(18.0, 0.0), Valley.EAST_GAP + Vector2(10, 0)],
		[fire, Vector2(-18.0, -2.0)], [Vector2(-18.0, -2.0), Valley.WEST_GAP + Vector2(-10, 0)],
		[fire, Vector2(-9.5, -20.0)], [fire, Vector2(-14.0, 3.0)], [fire, Vector2(7.5, 9.0)],
	]
	var lines: Array = []
	for sg in _wiggle(segs):
		lines.append([sg[0], sg[1]])
	return lines

## Desire lines are never ruler-straight: split each segment and bend it gently.
func _wiggle(segs: Array) -> Array:
	var out: Array = []
	for sgm in segs:
		var a: Vector2 = sgm[0]
		var b: Vector2 = sgm[1]
		var n := maxi(int(a.distance_to(b) / 5.0), 1)
		var side := (b - a).orthogonal().normalized()
		var prev := a
		for i in range(1, n + 1):
			var t := float(i) / float(n)
			var p := a.lerp(b, t)
			if i < n:
				p += side * sin(t * PI) * valley.noise.get_noise_2d(p.x * 3.0, p.y * 3.0) * 4.0
			out.append([prev, p])
			prev = p
	return out

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	if x < -30.0 or x > 15.0 or z < 20.0 or z > 90.0:
		return best
	for s in paths:
		best = minf(best, _seg_dist(p, s[0], s[1]))
	# measured from the road's edge strip, so foliage keeps off the whole bed
	return maxf(best - (Valley.PASS_FLAT - 1.4), 0.0)

## Shore data for the ground shader (UV2): x = 1 at the waterline fading to 0 about
## 1.5 m up the bank, y = 1 on the sandy coast (else river mud).
func shore(x: float, z: float, y: float) -> Vector2:
	var above := INF
	if absf(z - Valley.river_z(x)) < 20.0:
		above = y - Valley.river_level(x)
	if z > Valley.STREAM_HEAD_Z and z < Valley.river_z(Valley.stream_x(z)) and absf(x - Valley.stream_x(z)) < 4.0:
		above = minf(above, y - valley.stream_level(z))
	var coast := Valley.coast_d(x, z) > -60.0 and y < 2.5
	if coast:
		above = minf(above, y - Valley.SEA_LEVEL)
	var band := 0.0
	if above < INF:
		band = 1.0 - Valley.ss(-0.1, 1.5, above)
	return Vector2(band, 1.0 if coast else 0.0)

## Splat weights (grass, dirt, rock, bank) as a Color.
func splat(x: float, z: float, y: float, nrm: Vector3) -> Color:
	var slope := 1.0 - nrm.y
	var n := valley.noise.get_noise_2d(x * 3.0, z * 3.0)
	var rock := Valley.ss(0.18, 0.36, slope + n * 0.05)
	rock = maxf(rock, Valley.ss(45.0, 70.0, y + n * 8.0) * 0.8)
	var p := Vector2(x, z)
	var dirt := 1.0 - Valley.ss(2.2, 4.4, p.distance_to(Valley.FIRE) + n * 1.5)
	dirt = maxf(dirt, 1.0 - Valley.ss(2.0, 5.0, p.distance_to(Valley.CAVE_MOUTH) + n * 1.5))
	# the Pass Road: a level dirt bed between the cutting walls
	var pd := path_dist(x, z) + n * 0.5
	dirt = maxf(dirt, (1.0 - Valley.ss(0.0, 1.2, pd)) * 0.92)
	if Rect2(-205, -85, 405, 195).has_point(p) and p.length() > 60.0:
		dirt = maxf(dirt, Valley.ss(0.65, 0.78, valley.noise.get_noise_2d(x * 1.7 + 50.0, z * 1.7)) * 0.2)
	# dry Southern Plains read dusty
	if z > 160.0 and x < 150.0:
		dirt = maxf(dirt, 0.35 + 0.2 * n)
	# the bank: damp mud along the river and the stream, sand on the coast
	var sand := 0.0
	var dr := absf(z - Valley.river_z(x))
	if dr < 18.0 and y < Valley.river_level(x) + 1.6:
		sand = 1.0 - Valley.ss(0.5, 1.6, y - Valley.river_level(x) + n * 0.3)
	if y < 1.4 and Valley.coast_d(x, z) > -60.0:
		sand = maxf(sand, 1.0 - Valley.ss(0.6, 1.4, y))
	if z > Valley.STREAM_HEAD_Z and z < Valley.river_z(Valley.stream_x(z)):
		sand = maxf(sand, 1.0 - Valley.ss(2.2, 3.4, absf(x - Valley.stream_x(z)) + n * 0.6))
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
