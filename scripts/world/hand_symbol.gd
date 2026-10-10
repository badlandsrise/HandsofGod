class_name HandSymbol extends Node3D
## The open hand the people paint on their buildings and pots (doc 7, the hand
## symbol through the ages). A flat palm with four fingers and a thumb in hand
## gold, facing +z, about `size` metres tall. Shares one mesh per size.

static var _meshes: Dictionary = {}

static func make(size: float = 0.6, mat_name: String = "hand_gold") -> HandSymbol:
	var h := HandSymbol.new()
	h.name = "HandSymbol"
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _mesh(size)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: Material = ArtPalette.material(mat_name)
	if m == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color("#e2b44c")
		m = sm
	mi.material_override = m
	h.add_child(mi)
	return h

static func _mesh(size: float) -> ArrayMesh:
	var key := snappedf(size, 0.01)
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := 0.03
	# palm, four fingers, thumb: [centre x, centre y, width, height, tilt deg]
	var parts := [[0.0, 0.0, 0.62, 0.55, 0.0],
		[-0.25, 0.47, 0.13, 0.42, 8.0], [-0.085, 0.52, 0.13, 0.5, 2.0], [0.085, 0.51, 0.13, 0.48, -2.0], [0.245, 0.45, 0.12, 0.38, -8.0],
		[-0.4, 0.04, 0.13, 0.36, 40.0]]
	for p in parts:
		var b := Basis(Vector3(0, 0, 1), deg_to_rad(float(p[4])))
		var c := Vector3(float(p[0]), float(p[1]), 0.0) * size
		var hx := float(p[2]) * size * 0.5
		var hy := float(p[3]) * size * 0.5
		var corners := [Vector3(-hx, -hy, 0), Vector3(hx, -hy, 0), Vector3(hx, hy, 0), Vector3(-hx, hy, 0)]
		var front: Array = []
		var back: Array = []
		for k in corners:
			front.append(c + b * (k + Vector3(0, 0, d)))
			back.append(c + b * k)
		_quad(st, front[0], front[1], front[2], front[3], Vector3(0, 0, 1))
		_quad(st, back[1], back[0], back[3], back[2], Vector3(0, 0, -1))
		for i in 4:
			var j := (i + 1) % 4
			var n: Vector3 = ((front[i] + front[j]) * 0.5 - c).normalized()
			_quad(st, back[i], back[j], front[j], front[i], n)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	# both windings, so it reads from either side whatever the material culls
	for v in [a, b, c, a, c, d, a, c, b, a, d, c]:
		st.set_normal(n)
		st.add_vertex(v)
