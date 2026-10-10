class_name Props extends RefCounted
## Placeholder low-poly art built from primitives. Every mesh here is meant to
## be replaced by a CC0 model later, so callers put the result under a child
## node named "Visual".
##
## Vertex colour convention for the foliage shader: rgb = base colour,
## a = 1 for leaves (season tinted, wind sway), 0 for wood and stone.

static var _mats: Dictionary = {}

static func mat(c: Color, emissive: float = 0.0, rough: float = 0.9) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [c.to_html(), emissive, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m

static func add_mesh(parent: Node3D, m: Mesh, c: Color, pos: Vector3 = Vector3.ZERO, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c, emissive)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = size
	return b

static func ball(r: float, segs: int = 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r; s.height = r * 2.0; s.radial_segments = segs; s.rings = maxi(segs / 2, 3)
	return s

static func cyl(top: float, bottom: float, h: float, segs: int = 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top; c.bottom_radius = bottom; c.height = h; c.radial_segments = segs; c.rings = 1
	return c

## Merges primitive parts [[Mesh, Transform3D, Color(with alpha flag)], ...]
## into one flat-shaded ArrayMesh with vertex colours.
static func merge(parts: Array, jitter: float = 0.0, seed_v: int = 1) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for part in parts:
		var m: Mesh = part[0]
		var xf: Transform3D = part[1]
		var col: Color = part[2]
		var arr: Array = m.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i in verts.size():
			var v := verts[i]
			if jitter > 0.0:
				# deterministic per-position jitter keeps shared vertices together
				var h := hash(Vector3i(roundi(v.x * 100), roundi(v.y * 100), roundi(v.z * 100)))
				rng.seed = h + seed_v
				v += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * jitter
			moved[i] = xf * v
		var tri_count := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		for t in tri_count:
			var a: int = idx[t * 3] if idx.size() > 0 else t * 3
			var b: int = idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
			var c: int = idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
			var n := (moved[b] - moved[a]).cross(moved[c] - moved[a]).normalized() * -1.0
			# Godot primitives wind clockwise; flat normal per face.
			var shade := 1.0 - 0.06 * float(t % 3)
			var cc := Color(col.r * shade, col.g * shade, col.b * shade, col.a)
			for vi in [a, b, c]:
				st.set_color(cc)
				st.set_normal(n)
				st.add_vertex(moved[vi])
	return st.commit()

static func pine_mesh() -> ArrayMesh:
	var bark := Color(0.36, 0.24, 0.15, 0.0)
	var leaf := Color(0.18, 0.34, 0.2, 1.0)
	return merge([
		[cyl(0.16, 0.26, 1.6, 6), Transform3D(Basis(), Vector3(0, 0.8, 0)), bark],
		[cyl(0.0, 1.5, 2.6, 7), Transform3D(Basis(), Vector3(0, 2.6, 0)), leaf],
		[cyl(0.0, 1.15, 2.1, 7), Transform3D(Basis(), Vector3(0, 3.7, 0)), leaf.lightened(0.06)],
		[cyl(0.0, 0.75, 1.6, 7), Transform3D(Basis(), Vector3(0, 4.7, 0)), leaf.lightened(0.12)],
	], 0.05, 3)

static func broadleaf_mesh() -> ArrayMesh:
	var bark := Color(0.4, 0.28, 0.17, 0.0)
	var leaf := Color(0.3, 0.45, 0.22, 1.0)
	return merge([
		[cyl(0.14, 0.24, 2.2, 6), Transform3D(Basis(), Vector3(0, 1.1, 0)), bark],
		[ball(1.5, 7), Transform3D(Basis().scaled(Vector3(1, 0.85, 1)), Vector3(0, 3.1, 0)), leaf],
		[ball(0.95, 6), Transform3D(Basis(), Vector3(0.8, 2.7, 0.4)), leaf.lightened(0.07)],
		[ball(0.9, 6), Transform3D(Basis(), Vector3(-0.7, 3.4, -0.3)), leaf.darkened(0.05)],
	], 0.12, 5)

static func rock_mesh() -> ArrayMesh:
	var stone := Color(0.46, 0.44, 0.42, 0.0)
	return merge([[ball(1.0, 6), Transform3D(Basis().scaled(Vector3(1.2, 0.7, 1.0)), Vector3(0, 0.25, 0)), stone]], 0.22, 7)

static func bush_mesh() -> ArrayMesh:
	var leaf := Color(0.24, 0.4, 0.2, 1.0)
	return merge([
		[ball(0.8, 6), Transform3D(Basis().scaled(Vector3(1, 0.75, 1)), Vector3(0, 0.45, 0)), leaf],
		[ball(0.55, 6), Transform3D(Basis(), Vector3(0.5, 0.4, 0.2)), leaf.lightened(0.08)],
	], 0.08, 9)

## A tuft of three crossed blades, ~0.5 m tall. Alpha 1 = sways; base is darker.
static func grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * PI / 3.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a)) * 0.16
		var side := Vector3(-d.z, 0, d.x).normalized()
		var tip := d * 1.6 + Vector3(0, 0.55 + 0.1 * k, 0)
		for tri in [[d * 0.2 - side * 0.08, d * 0.2 + side * 0.08, tip]]:
			for v in tri:
				st.set_normal(Vector3.UP)
				st.set_color(Color(0.8, 0.8, 0.8, 1.0) if v == tip else Color(0.55, 0.55, 0.55, 0.0))
				st.add_vertex(v)
	return st.commit()
