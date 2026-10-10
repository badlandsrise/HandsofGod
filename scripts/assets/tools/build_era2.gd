extends SceneTree
## Builds the Era 2 (Village) art kit: every scene in scenes/props/era2/ plus the Era 2
## library materials. Re-run after changing this file:
##   godot --headless --path . -s res://scripts/assets/tools/build_era2.gd [-- --only=cottage,mill]
##
## Same conventions as build_props.gd (origin on the ground at the footprint centre, +Z is
## the front, metres) and the same look: pack pieces (Quaternius MegaKit walls, Kenney
## props and boats, Quaternius farm animals and rocks) are instanced, and everything the
## packs lack (thatch roofs, timber frames, crops, wattle, pots, the mill, the temple...) is
## modelled here as flat-shaded low-poly geometry on the named palette materials. Each
## scene's hand-made geometry is merged into one mesh per scene part (a few draw calls).
##
## Buildings come in three stages like the Era 1 hut: <id>_plot (pegged-out earth and the
## first materials), <id>_frame (footings, timber frame, ladder, scaffold) and <id>.

const N := "res://assets/models/nature/"
const K := "res://assets/models/props/"
const V := "res://assets/models/village/"
const BO := "res://assets/models/boats/"
const AN := "res://assets/models/animals/"
const OUT := "res://scenes/props/era2/"
const FLICKER := preload("res://scripts/assets/flicker.gd")
const SPINNER := preload("res://scripts/assets/spinner.gd")
const ANIMAL := preload("res://scripts/assets/animal_visual.gd")
const MK := {"hog_pull": 0.15, "hog_sat": 0.85}                       # MegaKit pieces
const BRONZE := {"hog_pull": 0.1, "hog_sat": 0.5, "hog_tint": Color("#f2d6a8")}   # Kenney "upgraded" tools as bronze
const KEN := {"hog_pull": 0.15, "hog_sat": 0.25, "hog_tint": Color("#cdb08c")}   # Kenney props

var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _parts: Dictionary = {}          # material name -> [verts, normals, uvs]
var _t := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []
var _only: PackedStringArray = []
var _count := 0


func _init() -> void:
	if (get_script() as Script).resource_path != "res://scripts/assets/tools/build_era2.gd":
		return   # a subclass (build_era3.gd) reuses the helpers and runs its own jobs
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_materials()
	var jobs := {
		"cottage": _cottage, "granary": _granary, "mill": _mill, "bakery": _bakery, "kiln": _kiln,
		"smelter": _smelter, "smithy": _smithy, "weaver": _weaver, "workshop": _workshop, "barn": _barn,
		"temple": _temple, "bridge": _bridge, "well": _well, "watchtower": _watchtower,
		"sheep_pen": _sheep_pen, "market_stall": _market_stall, "jetty": _jetty, "raft": _raft,
		"charcoal_clamp": _charcoal_clamp,
		"fields": _fields, "garden_plot": _garden_plot, "scarecrow": _scarecrow,
		"piles": _piles, "nodes": _nodes, "fences": _fences, "carts": _carts, "boats": _boats,
		"tools": _tools, "animals": _animals,
	}
	for k in jobs:
		if _only.is_empty() or k in _only:
			(jobs[k] as Callable).call()
	print("build_era2: %d scenes" % _count)
	quit()


# ================================================================== scene + geometry helpers

func _begin(scene_name: String) -> Node3D:
	_root = Node3D.new()
	_root.name = scene_name.to_pascal_case()
	_rng.seed = hash(scene_name)
	_parts = {}
	_t = Transform3D.IDENTITY
	_stack.clear()
	return _root


func _save(scene_name: String) -> void:
	_flush(_root, "Geometry")
	var ps := PackedScene.new()
	var err := ps.pack(_root)
	if err == OK:
		err = ResourceSaver.save(ps, OUT + scene_name + ".scn", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		print("  %s -> %s" % [scene_name, error_string(err)])
	_count += 1
	_root.free()


func _mat(mat_name: String) -> Material:
	if mat_name == "flame" or mat_name == "flame_core":
		return load("res://assets/models/materials/%s.tres" % mat_name)
	return load("res://assets/models/materials/%s.tres" % mat_name)


func _own(n: Node) -> void:
	n.owner = _root
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


## Instance a pack model. rot is degrees; s is a float or Vector3.
func _model(path: String, pos: Vector3, rot := Vector3.ZERO, s: Variant = 1.0, parent: Node3D = null, meta := {}) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	var sc: Vector3 = s if s is Vector3 else Vector3.ONE * float(s)
	n.transform = _t * Transform3D(Basis.from_euler(rot * PI / 180.0).scaled(sc), pos)
	for k in meta:
		n.set_meta(k, meta[k])
	(parent if parent else _root).add_child(n)
	n.owner = _root
	return n


func _group(node_name: String, pos := Vector3.ZERO, rot_y := 0.0, parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.name = node_name
	g.position = pos
	g.rotation.y = deg_to_rad(rot_y)
	(parent if parent else _root).add_child(g)
	g.owner = _root
	return g


func _push(xf: Transform3D) -> void:
	_stack.append(_t)
	_t = _t * xf


func _pop() -> void:
	_t = _stack.pop_back()


func _xf(pos: Vector3, rot_y := 0.0, s: Variant = 1.0) -> Transform3D:
	var sc: Vector3 = s if s is Vector3 else Vector3.ONE * float(s)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)).scaled(sc), pos)


## Merge the geometry gathered so far into one MeshInstance3D under parent.
func _flush(parent: Node3D, node_name: String) -> MeshInstance3D:
	if _parts.is_empty():
		return null
	var mesh := ArrayMesh.new()
	var keys := _parts.keys()
	keys.sort()
	for m in keys:
		var p: Array = _parts[m]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(p[0])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(p[1])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(p[2])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(m))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = node_name
	parent.add_child(mi)
	mi.owner = _root
	_parts = {}
	return mi


## Geometry built by `body` goes into its own node (for parts that move: sails, wheels).
func _part(node_name: String, pos: Vector3, body: Callable, parent: Node3D = null) -> Node3D:
	var saved_parts := _parts
	var saved_t := _t
	_parts = {}
	_t = Transform3D.IDENTITY
	var g := _group(node_name, saved_t * pos, 0.0, parent)
	g.basis = saved_t.basis
	body.call()
	_flush(g, "Mesh")
	_parts = saved_parts
	_t = saved_t
	return g


## One triangle; `out` is any direction on the visible side (front faces are clockwise).
func _tri(m: String, a: Vector3, b: Vector3, c: Vector3, out: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var A := _t * a
	var B := _t * b
	var C := _t * c
	var o := _t.basis * out
	var n := (C - A).cross(B - A)
	if n.length_squared() < 1e-14:
		return
	if n.dot(o) < 0.0:
		var tv := B
		B = C
		C = tv
		var tu := ub
		ub = uc
		uc = tu
		n = -n
	n = n.normalized()
	if not _parts.has(m):
		_parts[m] = [[], [], []]   # plain Arrays (reference types); packed at flush
	var p: Array = _parts[m]
	(p[0] as Array).append_array([A, B, C])
	(p[1] as Array).append_array([n, n, n])
	(p[2] as Array).append_array([ua, ub, uc])


func _auto_uv(p: Vector3, out: Vector3) -> Vector2:
	var ao := out.abs()
	if ao.y >= ao.x and ao.y >= ao.z:
		return Vector2(p.x, p.z) * 0.5
	if ao.x >= ao.z:
		return Vector2(p.z, -p.y) * 0.5
	return Vector2(p.x, -p.y) * 0.5


func _quad(m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, uvs: Array = []) -> void:
	var u: Array = uvs if uvs.size() == 4 else [_auto_uv(a, out), _auto_uv(b, out), _auto_uv(c, out), _auto_uv(d, out)]
	_tri(m, a, b, c, out, u[0], u[1], u[2])
	_tri(m, a, c, d, out, u[0], u[2], u[3])


func _box_b(m: String, c: Vector3, size: Vector3, b: Basis) -> void:
	var h := size * 0.5
	var ax: Array = [b.x.normalized(), b.y.normalized(), b.z.normalized()]
	var ext: Array = [h.x, h.y, h.z]
	for i in 3:
		var u: Vector3 = ax[(i + 1) % 3] * float(ext[(i + 1) % 3])
		var v: Vector3 = ax[(i + 2) % 3] * float(ext[(i + 2) % 3])
		for s in [-1.0, 1.0]:
			var n: Vector3 = ax[i] * s
			var fc: Vector3 = c + n * float(ext[i])
			_quad(m, fc - u - v, fc + u - v, fc + u + v, fc - u + v, n)


## Axis-aligned (then rotated, degrees) box centred at c.
func _box(m: String, c: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	_box_b(m, c, size, Basis.from_euler(rot * PI / 180.0))


## Square-section timber from a to b (h = depth, defaults to w).
func _beam(m: String, a: Vector3, b: Vector3, w: float, h := -1.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		return
	var y := d / l
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	_box_b(m, (a + b) * 0.5, Vector3(w, l, h if h > 0.0 else w), Basis(x, y, z))


## Round rod from a to b.
func _rod(m: String, a: Vector3, b: Vector3, r: float, seg := 6, r_end := -1.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		return
	var y := d / l
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	_push(Transform3D(Basis(x, y, z), a))
	_lathe(m, Vector3.ZERO, [Vector2(r, 0), Vector2(r if r_end < 0.0 else r_end, l)], seg)
	_pop()


## Surface of revolution round local +Y. prof: Array of Vector2(radius, height), bottom to
## top; going back down (an inner wall) makes an open vessel.
func _lathe(m: String, base: Vector3, prof: Array, seg := 8, rot := Vector3.ZERO, sc := Vector3.ONE, phase := 0.0, caps := true, v_scale := 1.6) -> void:
	_push(Transform3D(Basis.from_euler(rot * PI / 180.0).scaled(sc), base))
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var dr := p1.x - p0.x
		var dy := p1.y - p0.y
		for j in seg:
			var a0 := TAU * j / seg + phase
			var a1 := TAU * (j + 1) / seg + phase
			var c0 := Vector3(cos(a0), 0, sin(a0))
			var c1 := Vector3(cos(a1), 0, sin(a1))
			var mid := (c0 + c1).normalized()
			var out := mid * dy - Vector3.UP * dr
			if out.length_squared() < 1e-10:
				continue
			var u0 := float(j) / seg * maxf(p0.x, 0.3) * TAU * 0.5
			var u1 := float(j + 1) / seg * maxf(p0.x, 0.3) * TAU * 0.5
			_quad(m, c0 * p0.x + Vector3(0, p0.y, 0), c1 * p0.x + Vector3(0, p0.y, 0),
				c1 * p1.x + Vector3(0, p1.y, 0), c0 * p1.x + Vector3(0, p1.y, 0), out,
				[Vector2(u0, -p0.y / v_scale), Vector2(u1, -p0.y / v_scale), Vector2(u1, -p1.y / v_scale), Vector2(u0, -p1.y / v_scale)])
	if caps:
		var pb: Vector2 = prof[0]
		var pt: Vector2 = prof[prof.size() - 1]
		for j in seg:
			var a0 := TAU * j / seg + phase
			var a1 := TAU * (j + 1) / seg + phase
			var c0 := Vector3(cos(a0), 0, sin(a0))
			var c1 := Vector3(cos(a1), 0, sin(a1))
			if pb.x > 0.001:
				_tri(m, Vector3(0, pb.y, 0), c0 * pb.x + Vector3(0, pb.y, 0), c1 * pb.x + Vector3(0, pb.y, 0), Vector3.DOWN)
			if pt.x > 0.001:
				_tri(m, Vector3(0, pt.y, 0), c0 * pt.x + Vector3(0, pt.y, 0), c1 * pt.x + Vector3(0, pt.y, 0), Vector3.UP)
	_pop()


func _cyl(m: String, base: Vector3, r_bot: float, r_top: float, h: float, seg := 8, rot := Vector3.ZERO, sc := Vector3.ONE) -> void:
	_lathe(m, base, [Vector2(r_bot, 0), Vector2(r_top, h)], seg, rot, sc)


## Low-poly ball (centre c), squashable with sc.
func _ball(m: String, c: Vector3, r: float, seg := 7, rings := 4, sc := Vector3.ONE, rot := Vector3.ZERO) -> void:
	var prof := []
	for k in rings + 1:
		var a := -PI * 0.5 + PI * k / rings
		prof.append(Vector2(cos(a) * r, sin(a) * r))
	prof[0] = Vector2(0, -r)
	prof[rings] = Vector2(0, r)
	_lathe(m, c, prof, seg, rot, sc, 0.3)


## Thin three-sided spike from base leaning by `lean`: grass blades, wheat stalks, tines.
func _blade(m: String, base: Vector3, h: float, w: float, lean := Vector3.ZERO, phase := 0.0) -> void:
	var apex := base + Vector3(0, h, 0) + lean
	var pts := []
	for i in 3:
		var a := phase + TAU * i / 3.0
		pts.append(base + Vector3(cos(a), 0, sin(a)) * w)
	for i in 3:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % 3]
		_tri(m, p0, p1, apex, (p0 + p1) * 0.5 - base + Vector3(0, 0.001, 0))


## A slab of thickness `thick` hanging below the polygon `top` (3 or 4 points).
## uv_axes: [u axis, v axis, v scale] for the top face (thatch courses), or [] for planar.
func _slab(m: String, top: Array, thick: float, up: Vector3, uv_axes: Array = []) -> void:
	var n := top.size()
	var bot := []
	var cen := Vector3.ZERO
	for p in top:
		bot.append((p as Vector3) - Vector3(0, thick, 0))
		cen += p
	cen = cen / n - Vector3(0, thick * 0.5, 0)
	var uvs := []
	for p in top:
		if uv_axes.is_empty():
			uvs.append(_auto_uv(p, up))
		else:
			uvs.append(Vector2((p as Vector3).dot(uv_axes[0]) * 0.5, (p as Vector3).dot(uv_axes[1]) / float(uv_axes[2])))
	if n == 4:
		_quad(m, top[0], top[1], top[2], top[3], up, uvs)
		_quad(m, bot[0], bot[1], bot[2], bot[3], -up)
	else:
		_tri(m, top[0], top[1], top[2], up, uvs[0], uvs[1], uvs[2])
		_tri(m, bot[0], bot[1], bot[2], -up)
	for i in n:
		var a: Vector3 = top[i]
		var b: Vector3 = top[(i + 1) % n]
		var mid := (a + b) * 0.5 - Vector3(0, thick * 0.5, 0)
		_quad(m, a, b, bot[(i + 1) % n], bot[i], mid - cen)


## Roof over a w (x) by d (z) rectangle centred at the origin: ridge along x at y = e + h,
## outer eave edge at y = e. over = overhang beyond the walls; hip 0 = gable, 1 = full hip.
## Thatch gets rounded rolls on the eaves, hips and ridge.
func _roof(m: String, w: float, d: float, e: float, h: float, over: float, hip: float, thick := 0.3, trim := "straw_dark", rolls := true) -> void:
	var a := w * 0.5 + over
	var b := d * 0.5 + over
	var r := clampf(hip, 0.0, 1.0) * b
	var E1 := Vector3(-a, e, b)
	var E2 := Vector3(a, e, b)
	var E3 := Vector3(a, e, -b)
	var E4 := Vector3(-a, e, -b)
	var R1 := Vector3(-a + r, e + h, 0)
	var R2 := Vector3(a - r, e + h, 0)
	var ls := sqrt(b * b + h * h)
	var vs := 1.6 * h / ls       # one texture repeat per 1.6 m of slope
	_slab(m, [E1, E2, R2, R1], thick, Vector3(0, b, h), [Vector3.RIGHT, Vector3.DOWN, vs])
	_slab(m, [E3, E4, R1, R2], thick, Vector3(0, b, -h), [Vector3.LEFT, Vector3.DOWN, vs])
	if r > 0.01:
		var lh := sqrt(r * r + h * h)
		var vh := 1.6 * h / lh
		_slab(m, [E2, E3, R2], thick, Vector3(h, r, 0), [Vector3.BACK, Vector3.DOWN, vh])
		_slab(m, [E4, E1, R1], thick, Vector3(-h, r, 0), [Vector3.FORWARD, Vector3.DOWN, vh])
	if not rolls:
		return
	var rr := thick * 0.62
	var dn := Vector3(0, -thick * 0.45, 0)
	_rod(m, E1 + dn + Vector3(-0.05, 0, 0), E2 + dn + Vector3(0.05, 0, 0), rr, 6)
	_rod(m, E3 + dn + Vector3(0.05, 0, 0), E4 + dn + Vector3(-0.05, 0, 0), rr, 6)
	if r > 0.01:
		_rod(m, E2 + dn, E3 + dn, rr, 6)
		_rod(m, E4 + dn, E1 + dn, rr, 6)
		for pair in [[R2, E2], [R2, E3], [R1, E1], [R1, E4]]:
			_rod(trim, pair[0], (pair[1] as Vector3) + dn, thick * 0.55, 6)
		_rod(trim, R1 + Vector3(-0.12, -0.04, 0), R2 + Vector3(0.12, -0.04, 0), thick * 0.75, 7)
	else:
		_rod(trim, R1 + Vector3(-0.08, -0.04, 0), R2 + Vector3(0.08, -0.04, 0), thick * 0.75, 7)


## Eave height that puts a roof of pitch h (over d/2 + over) just above walls of height wall_h.
func _eave(d: float, over: float, h: float, wall_h: float) -> float:
	return wall_h + 0.12 - h * over / (d * 0.5 + over)


## Gable-end wall triangle at x, closing the space between the wall top and a gable roof.
func _gable(m: String, x: float, half_d: float, y0: float, peak: float, thick := 0.22, timber := "timber") -> void:
	var s := signf(x)
	var A := Vector3(x, y0, half_d)
	var B := Vector3(x, y0, -half_d)
	var C := Vector3(x, y0 + peak, 0)
	var o := Vector3(thick * 0.5 * s, 0, 0)
	_tri(m, A + o, B + o, C + o, Vector3(s, 0, 0))
	_tri(m, A - o, B - o, C - o, Vector3(-s, 0, 0))
	_quad(m, A + o, B + o, B - o, A - o, Vector3.DOWN)
	# timbering: a tie beam, a king post and two struts
	var to := Vector3(thick * 0.5 * s + 0.03 * s, 0, 0)
	_beam(timber, A + to + Vector3(0, -0.04, -0.1), B + to + Vector3(0, -0.04, 0.1), 0.14)
	_beam(timber, Vector3(x, y0, 0) + to, C + to - Vector3(0, 0.15, 0), 0.13)
	_beam(timber, Vector3(x, y0 + 0.08, half_d * 0.55) + to, Vector3(x, y0 + peak * 0.55, 0) + to, 0.11)
	_beam(timber, Vector3(x, y0 + 0.08, -half_d * 0.55) + to, Vector3(x, y0 + peak * 0.55, 0) + to, 0.11)


## The open hand, the game's symbol (DESIGN 7): palm, four fingers, thumb, as a thin relief
## on a surface. c = centre of the palm, n = surface normal, up = finger direction.
func _hand_symbol(m: String, c: Vector3, n: Vector3, up: Vector3, size: float, depth := 0.025) -> void:
	var z := n.normalized()
	var y := (up - z * up.dot(z)).normalized()
	var x := y.cross(z).normalized()
	_push(Transform3D(Basis(x, y, z), c))
	_lathe(m, Vector3.ZERO, [Vector2(size * 0.42, 0), Vector2(size * 0.42, depth)], 9, Vector3(90, 0, 0), Vector3(1, 1, 1.12))
	var fingers := [[-0.27, 0.62, 0.30, 8.0], [-0.09, 0.7, 0.34, 2.0], [0.09, 0.69, 0.33, -2.0], [0.26, 0.6, 0.28, -8.0]]
	for f in fingers:
		_box(m, Vector3(f[0], f[1] - 0.05, 0.5) * Vector3(size, size, depth), Vector3(size * 0.15, size * float(f[2]) * 1.4, depth),
			Vector3(0, 0, float(f[3])))
	_box(m, Vector3(-0.42, 0.02, 0.5) * Vector3(size, size, depth), Vector3(size * 0.17, size * 0.44, depth), Vector3(0, 0, 38))
	_pop()


# ================================================================== materials

func _build_materials() -> void:
	var era2 := false
	for mat_name in ArtPalette.NAMED:
		era2 = era2 or mat_name == "daub"   # everything before "daub" is build_props.gd's (Era 1)
		if era2:
			_save_material(mat_name, ArtPalette.NAMED[mat_name], "res://assets/models/materials/%s.tres" % mat_name)
	for mat_name in ArtPalette.NAMED_TEXTURED:
		_save_material(mat_name, ArtPalette.NAMED_TEXTURED[mat_name], "res://assets/models/materials/%s.tres" % mat_name)


func _save_material(mat_name: String, spec: Array, path: String) -> void:
	var m := ShaderMaterial.new()
	m.shader = ArtPalette.SHADER_2S if spec[1] else ArtPalette.SHADER
	m.resource_name = "hog_" + mat_name
	m.set_shader_parameter("albedo_color", Color(spec[0]))
	m.set_shader_parameter("palette_pull", 0.0)
	if spec.size() > 2:
		m.set_shader_parameter("albedo_texture", load(spec[2]))
		m.set_shader_parameter("use_texture", true)
	ArtPalette._apply_era_to(m)
	ResourceSaver.save(m, path)
	var text := FileAccess.get_file_as_string(path)
	var lines := PackedStringArray()
	for line in text.split("\n"):
		if line.begins_with("shader_parameter/") and line.ends_with("= null"):
			continue
		lines.append(line)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))


# ================================================================== shared building parts

## Pegged-out plot: tamped earth, corner pegs and string, footing stones started, a first
## pile of timber and stone. Every Era 2 building's first stage.
func _plot(w: float, d: float, round_plot := false) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	if round_plot:
		_cyl("dirt", Vector3(0, 0, 0), hw + 0.3, hw + 0.25, 0.05, 14)
	else:
		_box("dirt", Vector3(0, 0.025, 0), Vector3(w + 0.5, 0.05, d + 0.5))
	var cs := [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd)]
	for c in cs:
		_box("wood", c + Vector3(0, 0.32, 0), Vector3(0.08, 0.64, 0.08), Vector3(0, 20, 0))
	for i in 4:
		_beam("rope", (cs[i] as Vector3) + Vector3(0, 0.5, 0), (cs[(i + 1) % 4] as Vector3) + Vector3(0, 0.5, 0), 0.025)
	# first footing stones along the front and left side
	var x := -hw + 0.25
	while x < hw - 0.2:
		_stone(Vector3(x, 0, hd), 0.32)
		x += 0.42
	var z := hd - 0.45
	while z > -hd * 0.3:
		_stone(Vector3(-hw, 0, z), 0.32)
		z -= 0.42
	_model(K + "resource-planks.glb", Vector3(hw + 0.9, 0, hd - 0.5), Vector3(0, 80, 0), 5.0, null, KEN)
	_model(K + "resource-planks.glb", Vector3(hw + 0.95, 0.32, hd - 0.45), Vector3(0, 74, 0), 5.0, null, KEN)
	_model(K + "resource-stone-large.glb", Vector3(hw + 1.0, 0, -hd * 0.3), Vector3(0, 30, 0), 3.5, null, KEN)
	_model(K + "tool-shovel.glb", Vector3(-hw - 0.4, 0, hd + 0.1), Vector3(0, 30, 75), 3.5, null, KEN)


func _stone(p: Vector3, s: float) -> void:
	var sz := Vector3(_rng.randf_range(0.9, 1.2), _rng.randf_range(0.55, 0.75), _rng.randf_range(0.8, 1.05)) * s
	_box("stone", p + Vector3(0, sz.y * 0.5, 0), sz, Vector3(_rng.randf_range(-6, 6), _rng.randf_range(0, 360), _rng.randf_range(-6, 6)))


## Stone footing round a w x d rectangle.
func _footing(w: float, d: float, h := 0.3, m := "stone") -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	_box(m, Vector3(0, h * 0.5, hd), Vector3(w + 0.3, h, 0.36))
	_box(m, Vector3(0, h * 0.5, -hd), Vector3(w + 0.3, h, 0.36))
	_box(m, Vector3(hw, h * 0.5, 0), Vector3(0.36, h, d - 0.3))
	_box(m, Vector3(-hw, h * 0.5, 0), Vector3(0.36, h, d - 0.3))


## Timber frame of a w x d building with walls wall_h and a roof of height h (gable along x).
## Footings, posts, plates, braces, rafters, ridge, a ladder and a bundle of thatch.
func _frame(w: float, d: float, wall_h: float, h: float, over := 0.35) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	_box("dirt", Vector3(0, 0.025, 0), Vector3(w + 0.6, 0.05, d + 0.6))
	_footing(w, d, 0.28)
	var y0 := 0.28
	var xs := []
	var nx := maxi(1, roundi(w / 2.0))
	for i in nx + 1:
		xs.append(-hw + w * i / nx)
	var zs := []
	var nz := maxi(1, roundi(d / 2.0))
	for i in nz + 1:
		zs.append(-hd + d * i / nz)
	for x in xs:
		for z in [-hd, hd]:
			_beam("wood", Vector3(x, y0, z), Vector3(x, wall_h, z), 0.17)
	for z in zs:
		if absf(z) < hd - 0.01:
			for x in [-hw, hw]:
				_beam("wood", Vector3(x, y0, z), Vector3(x, wall_h, z), 0.17)
	for z in [-hd, hd]:
		_beam("wood", Vector3(-hw - 0.1, y0 + 0.08, z), Vector3(hw + 0.1, y0 + 0.08, z), 0.18)
		_beam("wood", Vector3(-hw - 0.15, wall_h, z), Vector3(hw + 0.15, wall_h, z), 0.2)
	for x in [-hw, hw]:
		_beam("wood", Vector3(x, y0 + 0.08, -hd), Vector3(x, y0 + 0.08, hd), 0.18)
		_beam("wood", Vector3(x, wall_h, -hd - 0.1), Vector3(x, wall_h, hd + 0.1), 0.2)
	# braces in the end bays
	for z in [-hd, hd]:
		_beam("wood", Vector3(-hw, wall_h * 0.45, z), Vector3(-hw + minf(1.0, w / nx * 0.5), wall_h, z), 0.1)
		_beam("wood", Vector3(hw, wall_h * 0.45, z), Vector3(hw - minf(1.0, w / nx * 0.5), wall_h, z), 0.1)
	# rafters and ridge
	var top := wall_h + h
	var n := maxi(2, roundi(w / 1.0))
	for i in n + 1:
		var x := -hw + w * i / n
		_beam("wood", Vector3(x, wall_h - over * h / hd, hd + over), Vector3(x, top, 0), 0.12)
		_beam("wood", Vector3(x, wall_h - over * h / hd, -hd - over), Vector3(x, top, 0), 0.12)
	_beam("wood", Vector3(-hw - 0.2, top + 0.02, 0), Vector3(hw + 0.2, top + 0.02, 0), 0.16)
	# a few battens on the front slope, the thatch about to go on
	for k in 3:
		var f := 0.25 + k * 0.25
		_beam("wood_dark", Vector3(-hw - 0.2, wall_h + h * f, hd * (1.0 - f)), Vector3(hw + 0.2, wall_h + h * f, hd * (1.0 - f)), 0.06)
	_ladder(Vector3(hw * 0.4, 0, hd + 1.0), Vector3(hw * 0.4, wall_h + 0.3, hd + 0.05), 0.5)
	_thatch_bundles(Vector3(-hw - 1.2, 0, hd * 0.2))
	_model(K + "resource-planks.glb", Vector3(hw + 1.0, 0, -hd * 0.4), Vector3(0, 95, 0), 5.0, null, KEN)


func _ladder(foot: Vector3, top: Vector3, width: float) -> void:
	var side := (top - foot).cross(Vector3.UP).normalized() * width * 0.5
	_beam("wood", foot + side, top + side, 0.07)
	_beam("wood", foot - side, top - side, 0.07)
	var n := int((top - foot).length() / 0.35)
	for i in range(1, n):
		var p := foot.lerp(top, float(i) / n)
		_beam("wood_dark", p + side, p - side, 0.05)


func _thatch_bundles(at: Vector3) -> void:
	for i in 6:
		var p := at + Vector3((i % 3) * 0.42 - 0.42, 0.17 + (i / 3) * 0.3, (i / 3) * 0.12)
		_rod("straw", p + Vector3(0, 0, 0.75), p - Vector3(0, 0, 0.75), 0.17, 6)
		_rod("rope", p + Vector3(0, 0, 0.32), p + Vector3(0, 0, 0.26), 0.18, 6)
		_rod("rope", p - Vector3(0, 0, 0.32), p - Vector3(0, 0, 0.26), 0.18, 6)


## MegaKit walls round an (nx*2) x (nz*2) box, height 3.12*sy. sides lists module names
## left to right as seen from outside: front (+Z), back, left (-X), right (+X).
func _mk_walls(nx: int, nz: int, sy: float, sides: Dictionary, corner := "Corner_Exterior_Wood") -> void:
	var hw := float(nx)
	var hd := float(nz)
	var specs := []
	var front: Array = sides.get("front", [])
	for i in front.size():
		specs.append([front[i], Vector3(-hw + 1 + 2 * i, 0, hd), 0.0])
	var back: Array = sides.get("back", [])
	for i in back.size():
		specs.append([back[i], Vector3(hw - 1 - 2 * i, 0, -hd), 180.0])
	var left: Array = sides.get("left", [])
	for i in left.size():
		specs.append([left[i], Vector3(-hw, 0, -hd + 1 + 2 * i), -90.0])
	var right: Array = sides.get("right", [])
	for i in right.size():
		specs.append([right[i], Vector3(hw, 0, hd - 1 - 2 * i), 90.0])
	for s in specs:
		var mod: String = s[0]
		var pos: Vector3 = s[1]
		var ry: float = s[2]
		_model(V + mod + ".gltf", pos, Vector3(0, ry, 0), Vector3(1, sy, 1), null, MK)
		var bx := Basis(Vector3.UP, deg_to_rad(ry))
		if mod.contains("Window_Wide_Round"):
			_model(V + "WindowShutters_Wide_Round_Open.gltf", pos, Vector3(0, ry, 0), Vector3(1, sy, 1), null, MK)
		elif mod.contains("Window_Thin_Round"):
			_model(V + "WindowShutters_Thin_Round_Open.gltf", pos, Vector3(0, ry, 0), Vector3(1, sy, 1), null, MK)
		elif mod.contains("Door_Round"):
			_model(V + "Door_2_Round.gltf", pos + bx * Vector3(-0.52, 0, -0.08), Vector3(0, ry, 0), Vector3(0.97, sy, 1), null, MK)
		elif mod.contains("Door_Flat"):
			_model(V + "Door_4_Flat.gltf", pos + bx * Vector3(-0.52, 0, -0.08), Vector3(0, ry, 0), Vector3(0.97, sy, 1), null, MK)
	for c in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd)]:
		_model(V + corner + ".gltf", c, Vector3.ZERO, Vector3(1, sy, 1), null, MK)
	# dark interior so window and door holes never show daylight through the house
	_box("cave_dark", Vector3(0, 3.12 * sy * 0.5, 0), Vector3(hw * 2 - 0.7, 3.12 * sy - 0.1, hd * 2 - 0.7))


## Plain plank-walled box (barn, granary, sheds): vertical boards on a frame.
func _plank_walls(w: float, d: float, y0: float, h: float, door_w := 0.0, door_h := 0.0) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var t := 0.12
	if door_w > 0.0:
		var side := (w - door_w) * 0.5
		_box("planks", Vector3(-hw + side * 0.5, y0 + h * 0.5, hd), Vector3(side, h, t))
		_box("planks", Vector3(hw - side * 0.5, y0 + h * 0.5, hd), Vector3(side, h, t))
		_box("planks", Vector3(0, y0 + door_h + (h - door_h) * 0.5, hd), Vector3(door_w, h - door_h, t))
		_box("cave_dark", Vector3(0, y0 + door_h * 0.5, hd - 0.05), Vector3(door_w, door_h, 0.05))
	else:
		_box("planks", Vector3(0, y0 + h * 0.5, hd), Vector3(w, h, t))
	_box("planks", Vector3(0, y0 + h * 0.5, -hd), Vector3(w, h, t))
	_box("planks", Vector3(hw, y0 + h * 0.5, 0), Vector3(t, h, d))
	_box("planks", Vector3(-hw, y0 + h * 0.5, 0), Vector3(t, h, d))
	for c in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd)]:
		_beam("timber", c + Vector3(0, y0, 0), c + Vector3(0, y0 + h + 0.05, 0), 0.2)
	for z in [hd, -hd]:
		_beam("timber", Vector3(-hw - 0.1, y0 + h, z + signf(z) * 0.04), Vector3(hw + 0.1, y0 + h, z + signf(z) * 0.04), 0.16)
		_beam("timber", Vector3(-hw - 0.1, y0 + 0.1, z + signf(z) * 0.04), Vector3(hw + 0.1, y0 + 0.1, z + signf(z) * 0.04), 0.14)


## A firewood stack against a wall (Kenney logs).
func _woodpile(p: Vector3, rot_y: float, n := 3) -> void:
	for i in n:
		_model(K + "resource-wood.glb", p + Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(i * 0.55 - (n - 1) * 0.27, (i % 2) * 0.05, 0),
			Vector3(0, rot_y + 90 + i * 5, 0), 4.5, null, KEN)


func _sack(p: Vector3, m := "rope", s := 1.0, lean := 0.0) -> void:
	var prof := [Vector2(0.18, 0), Vector2(0.27, 0.06), Vector2(0.3, 0.3), Vector2(0.24, 0.52), Vector2(0.1, 0.6),
		Vector2(0.08, 0.64), Vector2(0.12, 0.72), Vector2(0.0, 0.74)]
	_lathe(m, p, prof, 7, Vector3(lean, _rng.randf() * 60, 0), Vector3.ONE * s, 0.0, true)
	_cyl("rope", p + Vector3(0, 0.6 * s, 0), 0.1 * s, 0.1 * s, 0.05 * s, 7)


## Clay jar / amphora with an optional painted band and open hand (Era 2 hand symbol).
func _jar(p: Vector3, s := 1.0, m := "terracotta", painted := true, tall := false, rot_y := 0.0) -> void:
	var prof := [Vector2(0.11, 0), Vector2(0.2, 0.06), Vector2(0.27, 0.22), Vector2(0.26, 0.4), Vector2(0.17, 0.53),
		Vector2(0.12, 0.58), Vector2(0.14, 0.64), Vector2(0.11, 0.64), Vector2(0.09, 0.55)]
	if tall:
		prof = [Vector2(0.05, 0), Vector2(0.14, 0.08), Vector2(0.24, 0.35), Vector2(0.25, 0.55), Vector2(0.16, 0.75),
			Vector2(0.09, 0.82), Vector2(0.1, 0.92), Vector2(0.075, 0.92), Vector2(0.06, 0.84)]
	_lathe(m, p, prof, 9, Vector3(0, rot_y, 0), Vector3.ONE * s, 0.0, true)
	if painted:
		var y0 := 0.22 if not tall else 0.38
		var r0 := 0.272 if not tall else 0.252
		_lathe("daub", p, [Vector2(r0, y0), Vector2(r0 - 0.005, y0 + 0.16)], 9, Vector3(0, rot_y, 0), Vector3.ONE * s, 0.0, false)
		var dir := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1)
		_hand_symbol("red_ochre", p + (Vector3(0, y0 + 0.08, 0) + dir * (r0 + 0.004)) * s, dir, Vector3.UP, 0.12 * s, 0.012 * s)


func _bowl(p: Vector3, s := 1.0, m := "terracotta") -> void:
	_lathe(m, p, [Vector2(0.08, 0), Vector2(0.2, 0.06), Vector2(0.25, 0.14), Vector2(0.22, 0.14), Vector2(0.15, 0.05)], 9,
		Vector3.ZERO, Vector3.ONE * s, 0.0, true)


func _loaf(p: Vector3, s := 1.0, rot_y := 0.0) -> void:
	_ball("bread", p + Vector3(0, 0.07 * s, 0), 0.15 * s, 7, 4, Vector3(1.0, 0.55, 0.75), Vector3(0, rot_y, 0))


func _basket(p: Vector3, r := 0.35, h := 0.3) -> void:
	_lathe("straw_dark", p, [Vector2(r * 0.75, 0), Vector2(r, h), Vector2(r * 0.9, h), Vector2(r * 0.68, 0.04)], 10, Vector3.ZERO, Vector3.ONE, 0.0, true)
	_rod("straw_dark", p + Vector3(-r, h, 0), p + Vector3(-r * 0.5, h + r * 0.6, 0), 0.02, 4)
	_rod("straw_dark", p + Vector3(-r * 0.5, h + r * 0.6, 0), p + Vector3(r * 0.5, h + r * 0.6, 0), 0.02, 4)
	_rod("straw_dark", p + Vector3(r * 0.5, h + r * 0.6, 0), p + Vector3(r, h, 0), 0.02, 4)


func _bench(p: Vector3, rot_y: float, l := 1.6, h := 0.75, d := 0.55) -> void:
	_push(_xf(p, rot_y))
	_box("planks", Vector3(0, h, 0), Vector3(l, 0.08, d))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_beam("wood_dark", Vector3(sx * (l * 0.5 - 0.1), 0, sz * (d * 0.5 - 0.08)), Vector3(sx * (l * 0.5 - 0.1), h, sz * (d * 0.5 - 0.08)), 0.07)
	_pop()


func _flames_node(parent: Node3D, pos: Vector3, size: float, light := false) -> void:
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.set_script(FLICKER)
	fire.position = _t * pos
	parent.add_child(fire)
	fire.owner = _root
	var specs := [[Vector3(0, 0, 0), 1.0, "flame"], [Vector3(0.14, 0, 0.08), 0.7, "flame"],
		[Vector3(-0.12, 0, 0.1), 0.75, "flame"], [Vector3(0, 0, 0.02), 0.6, "flame_core"]]
	var i := 0
	for s in specs:
		var h: float = 0.9 * size * float(s[1])
		var pivot := Node3D.new()
		pivot.name = "Flame%d" % i
		pivot.position = s[0] * size
		fire.add_child(pivot)
		pivot.owner = _root
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.2 * size * float(s[1])
		cm.height = h
		cm.radial_segments = 5
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = _mat(s[2])
		mi.position.y = h * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		mi.owner = _root
		i += 1
	if light:
		var l := OmniLight3D.new()
		l.name = "FireLight"
		l.position.y = 0.5 * size
		l.light_color = Color("#ff9a4a")
		l.light_energy = 1.2
		l.omni_range = 5.0
		fire.add_child(l)
		l.owner = _root


## Glowing opening (kiln mouth, oven, furnace): an emissive disc set into a surface.
func _glow(p: Vector3, r: float, n: Vector3) -> void:
	var z := n.normalized()
	var ref := Vector3.UP if absf(z.y) < 0.9 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x)
	_push(Transform3D(Basis(x, y, z), p))
	_lathe("flame", Vector3.ZERO, [Vector2(r, 0), Vector2(0.0, 0.0)], 8, Vector3(90, 0, 0))
	_lathe("flame_core", Vector3(0, 0, 0.01), [Vector2(r * 0.55, 0), Vector2(0, 0)], 8, Vector3(90, 0, 0))
	_pop()


# ================================================================== houses

func _cottage() -> void:
	# A: three-bay timber-and-daub cottage, hipped thatch, stone chimney on the gable end.
	var sy := 0.8
	var wall_h := 3.12 * sy
	_begin("cottage_a")
	_mk_walls(3, 2, sy, {
		"front": ["Wall_Plaster_Window_Wide_Round", "Wall_Plaster_Door_Round", "Wall_Plaster_WoodGrid"],
		"back": ["Wall_Plaster_Straight", "Wall_Plaster_WoodGrid", "Wall_Plaster_Straight"],
		"left": ["Wall_Plaster_Straight_Base", "Wall_Plaster_Window_Thin_Round"],
		"right": ["Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Straight_Base"]})
	var h := 2.3
	var over := 0.55
	_roof("thatch", 6.0, 4.0, _eave(4.0, over, h, wall_h), h, over, 0.75)
	_model(V + "Prop_Chimney2.gltf", Vector3(-3.3, 0, -0.6), Vector3.ZERO, Vector3(0.85, 1.45, 0.85), null, MK)
	_woodpile(Vector3(3.6, 0, 1.0), 90, 3)
	_bench(Vector3(1.9, 0, 2.75), 0, 1.3, 0.45, 0.4)
	_jar(Vector3(-2.5, 0, 2.7), 0.9, "terracotta", true, false, 10)
	_model(K + "barrel.glb", Vector3(3.5, 0, -1.4), Vector3.ZERO, 3.2, null, KEN)
	_save("cottage_a")

	# B: two-bay cottage, gable thatch, lean-to log store, vine over the door.
	_begin("cottage_b")
	_mk_walls(2, 2, sy, {
		"front": ["Wall_Plaster_Door_Round", "Wall_Plaster_Window_Wide_Round"],
		"back": ["Wall_Plaster_WoodGrid", "Wall_Plaster_Straight"],
		"left": ["Wall_Plaster_Straight_Base", "Wall_Plaster_WoodGrid"],
		"right": ["Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Straight_Base"]})
	h = 2.2
	var e := _eave(4.0, over, h, wall_h)
	_roof("thatch", 4.4, 4.0, e, h, over, 0.0)
	var peak := e + h - wall_h - 0.3 + 0.0
	_gable("daub", 2.0, 2.0, wall_h, peak)
	_gable("daub", -2.0, 2.0, wall_h, peak)
	# lean-to on the right gable end
	_beam("timber", Vector3(3.3, 0, 1.6), Vector3(3.3, 1.7, 1.6), 0.14)
	_beam("timber", Vector3(3.3, 0, -1.6), Vector3(3.3, 1.7, -1.6), 0.14)
	_slab("planks", [Vector3(2.05, 2.25, 1.9), Vector3(3.6, 1.7, 1.9), Vector3(3.6, 1.7, -1.9), Vector3(2.05, 2.25, -1.9)], 0.08, Vector3(0.36, 1, 0))
	_woodpile(Vector3(2.75, 0, 0.9), 90, 2)
	_woodpile(Vector3(2.75, 0, -0.6), 90, 2)
	_sack(Vector3(1.2, 0, 2.6), "rope", 0.9)
	_basket(Vector3(0.6, 0, 2.7), 0.28, 0.25)
	_save("cottage_b")

	_begin("cottage_plot")
	_plot(6.0, 4.0)
	_save("cottage_plot")
	_begin("cottage_frame")
	_frame(6.0, 4.0, wall_h, 2.3)
	_save("cottage_frame")


func _granary() -> void:
	# Raised on staddle stones out of reach of rats and floods (the flood build answer).
	_begin("granary")
	var w := 3.6
	var d := 3.6
	var y0 := 0.85
	for x in [-1.5, 0.0, 1.5]:
		for z in [-1.5, 0.0, 1.5]:
			_cyl("stone", Vector3(x, 0, z), 0.22, 0.13, 0.62, 7)
			_cyl("stone", Vector3(x, 0.6, z), 0.36, 0.34, 0.12, 8)
	_box("planks", Vector3(0, y0 - 0.12, 0), Vector3(w + 0.3, 0.16, d + 0.3))
	_plank_walls(w, d, y0, 2.0, 0.9, 1.6)
	var h := 2.1
	_roof("thatch", w, d, _eave(d, 0.55, h, y0 + 2.0), h, 0.55, 1.0)
	# steps stand free of the door (rats cannot climb from them)
	for i in 3:
		_box("stone_light", Vector3(0, 0.12 + i * 0.22, d * 0.5 + 1.35 - i * 0.32), Vector3(1.0, 0.24 + i * 0.22, 0.34))
	_sack(Vector3(-1.4, 0, 2.6), "rope", 1.0)
	_sack(Vector3(-0.85, 0, 2.75), "rope", 0.9)
	_sack(Vector3(-1.15, 0.0, 3.2), "linen", 0.85)
	_jar(Vector3(1.6, 0, 2.6), 1.0, "terracotta", true, true, -15)
	_jar(Vector3(2.1, 0, 2.3), 0.8, "terracotta", true, false, 25)
	_save("granary")
	_begin("granary_plot")
	_plot(w, d)
	_save("granary_plot")
	_begin("granary_frame")
	for x in [-1.5, 0.0, 1.5]:
		for z in [-1.5, 0.0, 1.5]:
			_cyl("stone", Vector3(x, 0, z), 0.22, 0.13, 0.62, 7)
			_cyl("stone", Vector3(x, 0.6, z), 0.36, 0.34, 0.12, 8)
	_box("planks", Vector3(0, y0 - 0.12, 0), Vector3(w + 0.3, 0.16, d + 0.3))
	_push(_xf(Vector3(0, y0, 0)))
	for c in [Vector3(1.8, 0, 1.8), Vector3(-1.8, 0, 1.8), Vector3(1.8, 0, -1.8), Vector3(-1.8, 0, -1.8), Vector3(0, 0, 1.8), Vector3(0, 0, -1.8)]:
		_beam("wood", c, c + Vector3(0, 2.0, 0), 0.17)
	for z in [-1.8, 1.8]:
		_beam("wood", Vector3(-1.9, 2.0, z), Vector3(1.9, 2.0, z), 0.18)
	for x in [-1.8, 1.8]:
		_beam("wood", Vector3(x, 2.0, -1.9), Vector3(x, 2.0, 1.9), 0.18)
	for i in 4:
		var x := -1.8 + i * 1.2
		_beam("wood", Vector3(x, 2.0, 1.8), Vector3(0, 3.6, 0), 0.11)
		_beam("wood", Vector3(x, 2.0, -1.8), Vector3(0, 3.6, 0), 0.11)
	_pop()
	_ladder(Vector3(0.6, 0, 3.2), Vector3(0.6, y0 + 2.0, 1.85), 0.5)
	_thatch_bundles(Vector3(-2.8, 0, 0.5))
	_save("granary_frame")


func _bakery() -> void:
	var sy := 0.8
	var wall_h := 3.12 * sy
	_begin("bakery")
	_mk_walls(2, 2, sy, {
		"front": ["Wall_Plaster_Window_Wide_Round", "Wall_Plaster_Door_Round"],
		"back": ["Wall_Plaster_Straight", "Wall_Plaster_WoodGrid"],
		"left": ["Wall_Plaster_Straight_Base", "Wall_Plaster_Window_Thin_Round"],
		"right": ["Wall_Plaster_Straight_Base", "Wall_Plaster_Straight_Base"]})
	var h := 2.0
	var e := _eave(4.0, 0.5, h, wall_h)
	_roof("thatch", 4.4, 4.0, e, h, 0.5, 0.0)
	_gable("daub", 2.0, 2.0, wall_h, e + h - wall_h - 0.3)
	_gable("daub", -2.0, 2.0, wall_h, e + h - wall_h - 0.3)
	# the bread oven: a clay dome built against the right wall, with its own little roof
	var oc := Vector3(3.15, 0, 0.0)
	_lathe("stone", oc, [Vector2(1.25, 0), Vector2(1.25, 0.65), Vector2(0.0, 0.65)], 9)
	_lathe("clay_light", oc + Vector3(0, 0.65, 0), [Vector2(1.08, 0), Vector2(1.05, 0.35), Vector2(0.85, 0.85), Vector2(0.5, 1.15), Vector2(0.0, 1.25)], 10)
	_box("cave_dark", oc + Vector3(0, 1.02, 1.0), Vector3(0.6, 0.55, 0.3))
	_glow(oc + Vector3(0, 0.98, 1.08), 0.2, Vector3(0, 0, 1))
	_model(V + "Prop_Chimney2.gltf", oc + Vector3(0.35, 0, -0.75), Vector3.ZERO, Vector3(0.45, 1.25, 0.45), null, MK)
	_bench(Vector3(-1.2, 0, 2.9), 0, 1.5, 0.75, 0.55)
	for i in 5:
		_loaf(Vector3(-1.8 + i * 0.3, 0.79, 2.9 + (i % 2) * 0.1), 1.0, i * 23)
	_basket(Vector3(-0.2, 0, 3.0), 0.3, 0.26)
	for i in 3:
		_loaf(Vector3(-0.25 + i * 0.1, 0.24 + (i % 2) * 0.06, 3.0), 0.8, i * 50)
	_sack(Vector3(1.6, 0, 2.7), "linen", 1.0)
	_sack(Vector3(2.1, 0, 2.5), "linen", 0.9)
	_woodpile(Vector3(4.0, 0, -1.6), 0, 2)
	_save("bakery")
	_begin("bakery_plot")
	_plot(4.0, 4.0)
	_save("bakery_plot")
	_begin("bakery_frame")
	_frame(4.0, 4.0, wall_h, 2.0)
	_lathe("stone", Vector3(3.15, 0, 0), [Vector2(1.25, 0), Vector2(1.25, 0.65), Vector2(0.0, 0.65)], 9)
	_save("bakery_frame")


func _barn() -> void:
	# The barn raising (8 people): plank walls on a stone footing, a tall gable thatch roof
	# with the ridge running front to back, big doors and a hay loft on the front gable.
	var w := 6.0
	var d := 9.0
	var wall_h := 3.0
	_begin("barn")
	_footing(w, d, 0.4, "stone")
	_push(_xf(Vector3.ZERO, 90))   # build with the ridge along local x, then turn it front-to-back
	_plank_walls(d, w, 0.4, wall_h - 0.4)
	var h := 3.4
	var e := _eave(w, 0.6, h, wall_h)
	_roof("thatch", d + 0.4, w, e, h, 0.6, 0.0)
	_gable("planks", d * 0.5, w * 0.5, wall_h, e + h - wall_h - 0.35, 0.16, "timber")
	_gable("planks", -d * 0.5, w * 0.5, wall_h, e + h - wall_h - 0.35, 0.16, "timber")
	_pop()
	# big double doors on the front (+Z) end, open a little; loft door above
	_box("cave_dark", Vector3(0, 1.3, d * 0.5 + 0.02), Vector3(2.8, 2.5, 0.06))
	_box("planks", Vector3(-1.05, 1.3, d * 0.5 + 0.35), Vector3(1.4, 2.5, 0.1), Vector3(0, -35, 0))
	_box("planks", Vector3(1.05, 1.3, d * 0.5 + 0.35), Vector3(1.4, 2.5, 0.1), Vector3(0, 35, 0))
	for sx in [-1.0, 1.0]:
		_beam("timber", Vector3(sx * 1.45, 0.4, d * 0.5 + 0.1), Vector3(sx * 1.45, 2.65, d * 0.5 + 0.1), 0.18)
	_beam("timber", Vector3(-1.6, 2.65, d * 0.5 + 0.1), Vector3(1.6, 2.65, d * 0.5 + 0.1), 0.2)
	_box("cave_dark", Vector3(0, 4.0, d * 0.5 + 0.12), Vector3(1.0, 1.0, 0.05))
	_box("straw", Vector3(0, 3.62, d * 0.5 + 0.18), Vector3(0.9, 0.22, 0.2))
	_beam("timber", Vector3(0, 5.0, d * 0.5 + 0.1), Vector3(0, 5.0, d * 0.5 + 0.9), 0.14)   # hay hoist
	_rod("rope", Vector3(0, 5.0, d * 0.5 + 0.85), Vector3(0, 3.3, d * 0.5 + 0.85), 0.02, 4)
	_haystack(Vector3(4.6, 0, -2.0), 1.0)
	_model(K + "tool-shovel.glb", Vector3(-3.5, 0, 3.6), Vector3(0, 0, 18), 3.5, null, KEN)
	_save("barn")
	_begin("barn_plot")
	_plot(w, d)
	_save("barn_plot")
	_begin("barn_frame")
	_push(_xf(Vector3.ZERO, 90))
	_frame(d, w, wall_h, 3.4, 0.6)
	_pop()
	_save("barn_frame")


# ================================================================== workplaces

func _mill() -> void:
	# Post mill: a timber body on a trestle, turned to the wind; the sails spin (Sails node).
	_begin("mill")
	_mill_base()
	var by := 2.1
	var bw := 2.6
	var bd := 3.0
	var bh := 3.2
	_box("planks", Vector3(0, by + bh * 0.5, 0), Vector3(bw, bh, bd))
	for c in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		_beam("timber", Vector3(c.x * bw * 0.5, by - 0.05, c.z * bd * 0.5), Vector3(c.x * bw * 0.5, by + bh + 0.05, c.z * bd * 0.5), 0.18)
	_beam("timber", Vector3(-bw * 0.5 - 0.05, by, bd * 0.5 + 0.02), Vector3(bw * 0.5 + 0.05, by, bd * 0.5 + 0.02), 0.2)
	_beam("timber", Vector3(-bw * 0.5 - 0.05, by, -bd * 0.5 - 0.02), Vector3(bw * 0.5 + 0.05, by, -bd * 0.5 - 0.02), 0.2)
	_push(_xf(Vector3(0, 0, 0), 90))
	var h := 1.5
	var e := _eave(bw, 0.25, h, by + bh)
	_roof("planks", bd, bw, e, h, 0.25, 0.0, 0.14, "timber", false)
	_rod("timber", Vector3(-bd * 0.5 - 0.3, e + h, 0), Vector3(bd * 0.5 + 0.3, e + h, 0), 0.1, 6)
	_gable("planks", bd * 0.5, bw * 0.5, by + bh, e + h - (by + bh) - 0.12, 0.12)
	_gable("planks", -bd * 0.5, bw * 0.5, by + bh, e + h - (by + bh) - 0.12, 0.12)
	_pop()
	_box("cave_dark", Vector3(0.5, by + 1.9, bd * 0.5 + 0.05), Vector3(0.5, 0.6, 0.05))
	_box("cave_dark", Vector3(0, by + 0.9, -bd * 0.5 - 0.05), Vector3(0.8, 1.4, 0.05))
	# steps and tail pole at the back
	_ladder(Vector3(0, 0, -bd * 0.5 - 2.4), Vector3(0, by, -bd * 0.5 - 0.05), 0.75)
	_beam("timber", Vector3(0, by - 0.3, -bd * 0.5), Vector3(0, 0.6, -bd * 0.5 - 3.4), 0.18)
	# windshaft hub
	var hub := Vector3(0, by + 2.3, bd * 0.5 + 0.35)
	_rod("timber", hub - Vector3(0, 0, 0.6), hub, 0.18, 8)
	var sails := _part("Sails", hub, _mill_sails)
	sails.set_script(SPINNER)
	sails.set("speed", 0.55)
	sails.set("axis", Vector3(0, 0, 1))
	_sack(Vector3(1.4, 0, 2.2), "linen", 1.0)
	_sack(Vector3(1.9, 0, 1.8), "linen", 0.9)
	_sack(Vector3(1.6, 0, 1.4), "rope", 0.95)
	_save("mill")
	_begin("mill_plot")
	_plot(4.0, 4.0, true)
	_save("mill_plot")
	_begin("mill_frame")
	_mill_base()
	for c in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		_beam("wood", Vector3(c.x * 1.3, 2.1, c.z * 1.5), Vector3(c.x * 1.3, 5.3, c.z * 1.5), 0.17)
	_box("planks", Vector3(0, 2.05, 0), Vector3(2.6, 0.12, 3.0))
	for z in [-1.5, 1.5]:
		_beam("wood", Vector3(-1.4, 5.3, z), Vector3(1.4, 5.3, z), 0.18)
	_ladder(Vector3(0, 0, -3.9), Vector3(0, 2.1, -1.55), 0.75)
	_rod("wood", Vector3(-1.5, 0.15, 2.8), Vector3(2.8, 0.15, 2.4), 0.1, 6)   # a sail stock waiting
	_save("mill_frame")


func _mill_base() -> void:
	_lathe("stone", Vector3.ZERO, [Vector2(1.9, 0), Vector2(1.85, 0.45), Vector2(0.0, 0.45)], 10)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var foot := Vector3(cos(a) * 1.55, 0.45, sin(a) * 1.55)
		_beam("timber", foot, Vector3(0, 1.75, 0), 0.2)
		_beam("timber", foot + Vector3(0, 0.08, 0), Vector3(0, 0.6, 0), 0.18)
	_cyl("timber", Vector3(0, 0.45, 0), 0.24, 0.22, 1.7, 8)


func _mill_sails() -> void:
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		var dir := Vector3(cos(a), sin(a), 0)
		var side := Vector3(-sin(a), cos(a), 0)
		_beam("timber", dir * 0.2, dir * 4.3, 0.13)
		# lattice frame and a linen sail on one side of each stock
		var y0 := 1.0
		_beam("wood", dir * y0 + side * 0.85, dir * 4.25 + side * 0.85, 0.06)
		for k in 7:
			var t := y0 + k * (4.25 - y0) / 6.0
			_beam("wood", dir * t, dir * t + side * 0.85, 0.05)
		var c0 := dir * (y0 + 0.1) + side * 0.06 + Vector3(0, 0, 0.03)
		var c1 := dir * 4.15 + side * 0.06 + Vector3(0, 0, 0.03)
		_quad("linen", c0, c1, c1 + side * 0.74, c0 + side * 0.74, Vector3(0, 0, 1))
	_cyl("timber", Vector3(0, 0, -0.05), 0.3, 0.26, 0.3, 8, Vector3(90, 0, 0))


func _kiln() -> void:
	# Beehive pottery kiln with a glowing stoke hole, a potter's wheel and a drying shelf.
	_begin("kiln")
	_kiln_dome(Vector3(-0.9, 0, -0.4), true)
	_woodpile(Vector3(-2.9, 0, 0.5), 90, 2)
	# potter's corner: a thatched shelter with the drying shelves, the wheel out front
	var px := 1.6
	_yard(6.4, 4.6)
	_shelter(Vector3(px, 0, -1.25), 2.6, 1.0, 2.0, "thatch")
	_box("planks", Vector3(px, 0.9, -1.3), Vector3(2.2, 0.06, 0.45))
	_box("planks", Vector3(px, 1.45, -1.3), Vector3(2.2, 0.06, 0.45))
	for i in 5:
		_jar(Vector3(px - 0.8 + i * 0.4, 0.93, -1.3), 0.5, "clay_light", false)
		_bowl(Vector3(px - 0.8 + i * 0.4, 1.48, -1.3), 0.7, "clay_light")
	_cyl("wood_dark", Vector3(px - 0.3, 0, 0.35), 0.06, 0.06, 0.5, 6)
	var wheel := _part("Wheel", Vector3(px - 0.3, 0.5, 0.35), _potters_wheel)
	wheel.set_script(SPINNER)
	wheel.set("speed", 3.0)
	wheel.set("axis", Vector3.UP)
	_box("wood_dark", Vector3(px - 0.3, 0.22, -0.15), Vector3(0.5, 0.44, 0.35))
	_jar(Vector3(0.5, 0, 1.4), 1.0, "terracotta", true, true, 10)
	_jar(Vector3(1.0, 0, 1.6), 0.85, "terracotta", true, false, -20)
	_jar(Vector3(0.6, 0, 1.95), 0.7, "terracotta", true, false, 30)
	_clay_heap(Vector3(2.5, 0, 1.1), 0.8)
	_save("kiln")
	_begin("kiln_plot")
	_plot(5.0, 4.0)
	_save("kiln_plot")
	_begin("kiln_frame")
	_box("dirt", Vector3(0, 0.025, 0), Vector3(5.5, 0.05, 4.5))
	_kiln_dome(Vector3(-0.9, 0, -0.4), false)
	for c in [Vector3(0.5, 0, 1.2), Vector3(2.7, 0, 1.2), Vector3(0.5, 0, -1.1), Vector3(2.7, 0, -1.1)]:
		_beam("wood", c, c + Vector3(0, 2.3 if c.z > 0 else 2.6, 0), 0.14)
	_clay_heap(Vector3(2.4, 0, 1.9), 1.0)
	_model(K + "resource-planks.glb", Vector3(1.6, 0, -1.8), Vector3(0, 5, 0), 5.0, null, KEN)
	_save("kiln_frame")


func _potters_wheel() -> void:
	_cyl("wood", Vector3.ZERO, 0.32, 0.32, 0.08, 10)
	_lathe("clay", Vector3(0, 0.08, 0), [Vector2(0.09, 0), Vector2(0.12, 0.12), Vector2(0.08, 0.22), Vector2(0.06, 0.22), Vector2(0.05, 0.1)], 8)


func _kiln_dome(c: Vector3, finished: bool) -> void:
	_lathe("stone", c, [Vector2(1.55, 0), Vector2(1.5, 0.35), Vector2(0.0, 0.35)], 10)
	if finished:
		_lathe("clay_light", c + Vector3(0, 0.35, 0), [Vector2(1.35, 0), Vector2(1.32, 0.45), Vector2(1.12, 1.15), Vector2(0.72, 1.7),
			Vector2(0.34, 1.95), Vector2(0.3, 2.15), Vector2(0.22, 2.15), Vector2(0.22, 2.0)], 11)
		_lathe("cave_dark", c + Vector3(0, 2.4, 0), [Vector2(0.22, 0), Vector2(0.0, 0.0)], 8)
		# stoke hole on the front with a raised clay arch
		_box("clay", c + Vector3(0, 0.75, 1.25), Vector3(0.9, 0.85, 0.5))
		_box("cave_dark", c + Vector3(0, 0.68, 1.5), Vector3(0.5, 0.55, 0.05))
		_glow(c + Vector3(0, 0.62, 1.53), 0.17, Vector3(0, 0, 1))
		for i in 6:   # clay patches, the hand-built look
			var a := TAU * i / 6.0 + 0.4
			_ball("clay", c + Vector3(cos(a) * 1.15, 0.9 + (i % 3) * 0.3, sin(a) * 1.15), 0.18, 6, 3, Vector3(1, 0.5, 1))
	else:
		_lathe("clay_light", c + Vector3(0, 0.35, 0), [Vector2(1.35, 0), Vector2(1.32, 0.45), Vector2(1.18, 0.8), Vector2(0.95, 0.8),
			Vector2(1.08, 0.45), Vector2(1.1, 0.0)], 11)


func _clay_heap(p: Vector3, s: float) -> void:
	for i in 7:
		var a := TAU * i / 7.0
		var r := 0.0 if i == 0 else 0.35
		_ball("clay", p + Vector3(cos(a) * r, 0.12, sin(a) * r) * s, 0.26 * s, 6, 3, Vector3(1, 0.65, 1), Vector3(0, i * 40, 0))
	_ball("clay", p + Vector3(0.05, 0.36, 0.0) * s, 0.22 * s, 6, 3, Vector3(1, 0.7, 1))


func _smelter() -> void:
	# Copper to bronze: a clay shaft furnace fed by leather bellows in an open yard; a shallow
	# shelter at the back keeps the charcoal and ore dry. The yard reads from the high camera.
	_begin("smelter")
	_yard(4.6, 3.8)
	_shelter(Vector3(0, 0, -1.25), 4.2, 1.3, 2.1)
	_charcoal_lumps(Vector3(-1.2, 0.0, -1.3), 0.5, 12)
	_ore_heap(Vector3(0.9, 0, -1.3), 0.75)
	_furnace(Vector3(-0.9, 0, 0.4), true)
	# bellows: two leather wedges on a frame, a clay pipe into the furnace
	for sx in [-0.22, 0.22]:
		_slab("leather", [Vector3(0.2, 0.42, 0.4 + sx + 0.12), Vector3(0.9, 0.34, 0.4 + sx + 0.18), Vector3(0.9, 0.34, 0.4 + sx - 0.18),
			Vector3(0.2, 0.42, 0.4 + sx - 0.12)], 0.24, Vector3.UP)
		_beam("wood", Vector3(0.2, 0.45, 0.4 + sx), Vector3(1.3, 0.62, 0.4 + sx), 0.05)
	_rod("clay", Vector3(0.2, 0.3, 0.4), Vector3(-0.25, 0.42, 0.4), 0.07, 6)
	_ingots(Vector3(1.3, 0, 1.2))
	_model(K + "bucket.glb", Vector3(0.2, 0, 1.4), Vector3(0, 30, 0), 3.0, null, KEN)
	_save("smelter")
	_begin("smelter_plot")
	_plot(4.0, 3.0)
	_save("smelter_plot")
	_begin("smelter_frame")
	_yard(4.6, 3.8)
	_furnace(Vector3(-0.9, 0, 0.4), false)
	for c in [Vector3(-2.1, 0, -0.6), Vector3(2.1, 0, -0.6), Vector3(-2.1, 0, -1.9), Vector3(2.1, 0, -1.9)]:
		_beam("wood", c, c + Vector3(0, 2.1 if c.z > -1.0 else 2.5, 0), 0.15)
	_clay_heap(Vector3(1.2, 0, 0.8), 0.9)
	_save("smelter_frame")


func _furnace(c: Vector3, finished: bool) -> void:
	_lathe("stone", c, [Vector2(0.95, 0), Vector2(0.9, 0.3), Vector2(0.0, 0.3)], 9)
	var top := 2.0 if finished else 1.0
	_lathe("clay", c + Vector3(0, 0.3, 0), [Vector2(0.75, 0), Vector2(0.72, 0.4), Vector2(0.5, top * 0.8), Vector2(0.38, top),
		Vector2(0.26, top), Vector2(0.3, top - 0.3)], 9)
	if finished:
		_lathe("cave_dark", c + Vector3(0, 0.3 + top - 0.05, 0), [Vector2(0.27, 0), Vector2(0.0, 0.0)], 8)
		_flames_node(_root, c + Vector3(0, 0.3 + top - 0.1, 0), 0.35)
		_box("cave_dark", c + Vector3(0, 0.55, 0.7), Vector3(0.38, 0.4, 0.06))
		_glow(c + Vector3(0, 0.52, 0.74), 0.13, Vector3(0, 0, 1))


## Beaten-earth work yard (an eight-sided patch) that marks a workplace on the grass.
func _yard(w: float, d: float) -> void:
	_lathe("dirt", Vector3.ZERO, [Vector2(0.5, 0), Vector2(0.5, 0.03), Vector2(0.0, 0.03)], 8, Vector3.ZERO, Vector3(w * 1.08, 1, d * 1.08), PI / 8.0)


## Shallow open shelter: plank back wall, two front posts, mono-pitch roof (workplaces).
func _shelter(c: Vector3, w: float, d: float, h: float, roof := "planks") -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	_box("planks", c + Vector3(0, (h + 0.45) * 0.5, -hd), Vector3(w, h + 0.45, 0.1))
	for sx in [-1.0, 1.0]:
		_beam("timber", c + Vector3(sx * hw, 0, hd), c + Vector3(sx * hw, h, hd), 0.15)
		_beam("timber", c + Vector3(sx * hw, 0, -hd), c + Vector3(sx * hw, h + 0.5, -hd), 0.15)
		_beam("timber", c + Vector3(sx * hw, h * 0.65, hd), c + Vector3(sx * hw, h, hd - 0.5), 0.09)
	_beam("timber", c + Vector3(-hw - 0.1, h, hd), c + Vector3(hw + 0.1, h, hd), 0.15)
	var rt := 0.22 if roof == "thatch" else 0.1
	_slab(roof, [c + Vector3(-hw - 0.3, h + 0.08 + rt, hd + 0.45), c + Vector3(hw + 0.3, h + 0.08 + rt, hd + 0.45),
		c + Vector3(hw + 0.3, h + 0.6 + rt, -hd - 0.3), c + Vector3(-hw - 0.3, h + 0.6 + rt, -hd - 0.3)], rt, Vector3(0, 1, 0.3),
		[Vector3.RIGHT, Vector3.FORWARD, 1.6])
	if roof == "thatch":
		_rod("thatch", c + Vector3(-hw - 0.32, h + 0.18, hd + 0.42), c + Vector3(hw + 0.32, h + 0.18, hd + 0.42), rt * 0.6, 6)


func _smithy() -> void:
	# Bronze tools (+50% speed): an open forge with a stone hearth, anvil and quench barrel;
	# the tools hang in the shelter at the back.
	_begin("smithy")
	_yard(4.6, 3.8)
	_shelter(Vector3(0, 0, -1.25), 4.2, 1.3, 2.2)
	_beam("wood_dark", Vector3(-0.2, 1.75, -1.82), Vector3(1.8, 1.75, -1.82), 0.08)
	for i in 3:
		_model([K + "tool-axe-upgraded.glb", K + "tool-hammer-upgraded.glb", K + "tool-pickaxe-upgraded.glb"][i],
			Vector3(0.1 + i * 0.6, 1.05, -1.72), Vector3(0, 0, 0), 3.2, null, BRONZE)
	_model(K + "barrel.glb", Vector3(-1.5, 0, -1.3), Vector3.ZERO, 3.0, null, KEN)
	# forge hearth with its hood and chimney
	_box("stone", Vector3(-1.2, 0.42, 0.3), Vector3(1.3, 0.84, 1.0))
	_box("charcoal", Vector3(-1.2, 0.86, 0.32), Vector3(0.9, 0.05, 0.7))
	_flames_node(_root, Vector3(-1.2, 0.86, 0.32), 0.42, true)
	for c in [Vector3(-1.75, 0, -0.1), Vector3(-0.65, 0, -0.1)]:
		_beam("stone_dark", c + Vector3(0, 0.84, 0), c + Vector3(0, 1.75, 0), 0.14)
	_lathe("stone_dark", Vector3(-1.2, 1.75, 0.2), [Vector2(0.72, 0), Vector2(0.3, 0.55), Vector2(0.24, 0.6), Vector2(0.24, 1.6), Vector2(0.3, 1.6), Vector2(0.3, 1.7), Vector2(0.0, 1.7)], 4, Vector3(0, 45, 0))
	_model(K + "workbench-anvil.glb", Vector3(0.4, 0, 0.55), Vector3(0, -20, 0), 4.0, null, KEN)
	_model(K + "barrel-open.glb", Vector3(1.5, 0, 0.0), Vector3.ZERO, 3.0, null, KEN)
	_lathe("water", Vector3(1.5, 0.58, 0.0), [Vector2(0.26, 0), Vector2(0, 0)], 8)
	_ingots(Vector3(1.4, 0, 1.3))
	_charcoal_lumps(Vector3(-0.4, 0, 1.4), 0.3, 6)
	_save("smithy")
	_begin("smithy_plot")
	_plot(4.4, 3.4)
	_save("smithy_plot")
	_begin("smithy_frame")
	_yard(4.6, 3.8)
	for c in [Vector3(-2.1, 0, -0.6), Vector3(2.1, 0, -0.6), Vector3(-2.1, 0, -1.9), Vector3(2.1, 0, -1.9)]:
		_beam("wood", c, c + Vector3(0, 2.2 if c.z > -1.0 else 2.6, 0), 0.15)
	_box("stone", Vector3(-1.2, 0.3, 0.3), Vector3(1.3, 0.6, 1.0))
	_model(K + "resource-stone-large.glb", Vector3(1.0, 0, 0.8), Vector3(0, 30, 0), 3.5, null, KEN)
	_save("smithy_frame")


func _weaver() -> void:
	# Wool to cloth: a warp-weighted loom out in the light, fleece baskets, bolts of cloth
	# on a bench under a thatched shelter.
	_begin("weaver")
	_yard(4.6, 3.8)
	_shelter(Vector3(0, 0, -1.25), 4.2, 1.3, 2.1, "thatch")
	_bench(Vector3(0.9, 0, -1.3), 0, 1.6, 0.7, 0.5)
	for i in 4:
		_rod(["cloth_red", "cloth_blue", "linen", "cloth_gold"][i], Vector3(0.35 + i * 0.36, 0.88, -1.08), Vector3(0.35 + i * 0.36, 0.88, -1.52), 0.15, 8)
	_wool_bales(Vector3(-1.2, 0, -1.3))
	_loom(Vector3(-0.6, 0, 0.5))
	_basket(Vector3(1.0, 0, 0.7), 0.36, 0.3)
	_ball("wool", Vector3(1.0, 0.33, 0.7), 0.3, 7, 4, Vector3(1, 0.55, 1))
	_basket(Vector3(1.55, 0, 1.3), 0.3, 0.26)
	_ball("wool", Vector3(1.55, 0.28, 1.3), 0.25, 7, 4, Vector3(1, 0.5, 1))
	_save("weaver")
	_begin("weaver_plot")
	_plot(4.4, 3.2)
	_save("weaver_plot")
	_begin("weaver_frame")
	_yard(4.6, 3.8)
	for c in [Vector3(-2.1, 0, -0.6), Vector3(2.1, 0, -0.6), Vector3(-2.1, 0, -1.9), Vector3(2.1, 0, -1.9)]:
		_beam("wood", c, c + Vector3(0, 2.1 if c.z > -1.0 else 2.5, 0), 0.15)
	for sx in [-0.9, 0.9]:
		_beam("wood", Vector3(-0.6 + sx, 0, 0.8), Vector3(-0.6 + sx, 2.1, 0.4), 0.1)
	_thatch_bundles(Vector3(1.2, 0, 0.6))
	_save("weaver_frame")


func _loom(c: Vector3) -> void:
	# two uprights leaning back, a cloth beam, warp threads held taut by clay weights
	var top := 2.1
	for sx in [-0.9, 0.9]:
		_beam("wood", c + Vector3(sx, 0, 0.3), c + Vector3(sx, top, -0.1), 0.1)
	_rod("wood", c + Vector3(-1.05, top - 0.1, -0.08), c + Vector3(1.05, top - 0.1, -0.08), 0.07, 6)
	_beam("wood", c + Vector3(-0.95, 0.9, 0.17), c + Vector3(0.95, 0.9, 0.17), 0.06)
	# woven cloth from the top down, with a stripe
	var cloth_top := top - 0.15
	var cloth_bot := 1.25
	var f := func(y: float) -> float: return 0.3 - (y / top) * 0.4
	_quad("cloth_blue", c + Vector3(-0.8, cloth_top, f.call(cloth_top)), c + Vector3(0.8, cloth_top, f.call(cloth_top)),
		c + Vector3(0.8, cloth_bot, f.call(cloth_bot)), c + Vector3(-0.8, cloth_bot, f.call(cloth_bot)), Vector3(0, 0.2, 1))
	_quad("cloth_gold", c + Vector3(-0.8, 1.6, f.call(1.6) + 0.01), c + Vector3(0.8, 1.6, f.call(1.6) + 0.01),
		c + Vector3(0.8, 1.48, f.call(1.48) + 0.01), c + Vector3(-0.8, 1.48, f.call(1.48) + 0.01), Vector3(0, 0.2, 1))
	for i in 15:
		var x := -0.78 + i * 0.111
		_beam("linen", c + Vector3(x, cloth_bot, f.call(cloth_bot)), c + Vector3(x, 0.55, f.call(0.55)), 0.012)
		_lathe("clay", c + Vector3(x, 0.42, f.call(0.5) + (0.04 if i % 2 == 0 else -0.04)), [Vector2(0.05, 0), Vector2(0.05, 0.12), Vector2(0, 0.14)], 5)


func _workshop() -> void:
	# Carpenter: a log on the sawhorse, a workbench, planks stacked to season in the shelter.
	_begin("workshop")
	_yard(4.6, 3.8)
	_shelter(Vector3(0, 0, -1.25), 4.2, 1.3, 2.1)
	for i in 5:
		_box("planks", Vector3(-0.2 + (i % 2) * 0.05, 0.12 + i * 0.1, -1.3), Vector3(3.4, 0.08, 0.34))
		_box("wood_dark", Vector3(-1.4, 0.07 + i * 0.1, -1.3), Vector3(0.06, 0.05, 0.5))
		_box("wood_dark", Vector3(1.0, 0.07 + i * 0.1, -1.3), Vector3(0.06, 0.05, 0.5))
	_model(K + "workbench.glb", Vector3(-1.1, 0, 0.3), Vector3(0, 10, 0), 3.5, null, KEN)
	_model(K + "tool-hammer-upgraded.glb", Vector3(-1.0, 0.95, 0.4), Vector3(0, 30, 90), 3.0, null, BRONZE)
	_sawhorse(Vector3(1.0, 0, 0.6))
	_rod("wood", Vector3(0.3, 0.85, 0.6), Vector3(2.2, 0.85, 0.6), 0.2, 7)
	_lathe("straw", Vector3(2.2, 0.85, 0.6), [Vector2(0.2, 0), Vector2(0.0, 0.0)], 7, Vector3(0, 0, -90))
	_woodpile(Vector3(1.5, 0, 1.6), 0, 2)
	for i in 8:   # wood shavings
		_ball("straw", Vector3(1.0 + _rng.randf_range(-0.8, 0.8), 0.03, 0.6 + _rng.randf_range(-0.5, 0.6)), 0.08, 5, 2, Vector3(1, 0.3, 1))
	_save("workshop")
	_begin("workshop_plot")
	_plot(4.4, 3.2)
	_save("workshop_plot")
	_begin("workshop_frame")
	_yard(4.6, 3.8)
	for c in [Vector3(-2.1, 0, -0.6), Vector3(2.1, 0, -0.6), Vector3(-2.1, 0, -1.9), Vector3(2.1, 0, -1.9)]:
		_beam("wood", c, c + Vector3(0, 2.1 if c.z > -1.0 else 2.5, 0), 0.15)
	_sawhorse(Vector3(1.0, 0, 0.6))
	_save("workshop_frame")


func _sawhorse(c: Vector3) -> void:
	for sx in [-0.5, 0.5]:
		_beam("wood", c + Vector3(sx, 0, 0.3), c + Vector3(sx, 0.75, 0), 0.07)
		_beam("wood", c + Vector3(sx, 0, -0.3), c + Vector3(sx, 0.75, 0), 0.07)
	_beam("wood", c + Vector3(-0.65, 0.72, 0), c + Vector3(0.65, 0.72, 0), 0.1)


func _charcoal_clamp() -> void:
	# Turf-covered mound slowly charring a stack of wood; smoke vents glow.
	_begin("charcoal_clamp")
	_lathe("soil", Vector3.ZERO, [Vector2(1.7, 0), Vector2(1.6, 0.4), Vector2(1.2, 1.1), Vector2(0.6, 1.5), Vector2(0.0, 1.6)], 11)
	for i in 14:
		var a := TAU * i / 14.0 + 0.2
		var r := 0.9 + (i % 3) * 0.3
		var y := 1.6 * (1.0 - pow(r / 1.75, 2.0)) + 0.05
		_ball("leaf" if i % 3 != 1 else "soil_dark", Vector3(cos(a) * r, y, sin(a) * r), 0.24, 6, 3, Vector3(1, 0.3, 1), Vector3(0, i * 30, 0))
	for i in 3:
		var a := TAU * i / 3.0 + 1.0
		_glow(Vector3(cos(a) * 1.25, 0.85, sin(a) * 1.25), 0.1, Vector3(cos(a), 0.6, sin(a)))
	_glow(Vector3(0, 1.61, 0), 0.15, Vector3.UP)
	_woodpile(Vector3(2.4, 0, 0.6), 90, 2)
	_charcoal_lumps(Vector3(-2.1, 0, 0.9), 0.5, 10)
	_model(K + "tool-shovel.glb", Vector3(-1.9, 0, -0.5), Vector3(0, 40, 80), 3.5, null, KEN)
	_save("charcoal_clamp")


# ================================================================== the Temple of the Hand (Era 2 shrine stage)

func _temple() -> void:
	_begin("temple")
	_push(_xf(Vector3(0, 0, -1.7)))    # centre the 10 x 15 m footprint
	_temple_platform()
	var py := 0.9
	# hall: daub and timber on the platform, 3 x 4 MegaKit bays
	_push(_xf(Vector3(0, py, -0.6)))
	_mk_walls(3, 4, 1.1, {
		"front": ["Wall_Plaster_WoodGrid", "Wall_Plaster_Door_Flat", "Wall_Plaster_WoodGrid"],
		"back": ["Wall_Plaster_Straight", "Wall_Plaster_WoodGrid", "Wall_Plaster_Straight"],
		"left": ["Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Window_Thin_Round"],
		"right": ["Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Window_Thin_Round"]})
	var wall_h := 3.12 * 1.1
	# roof: steep gable thatch, ridge front to back, with a raised lantern roof on top
	var h := 4.4
	var e := _eave(6.0, 0.7, h, wall_h)
	_push(_xf(Vector3(0, 0, 0.65), 90))
	_roof("thatch", 9.3, 6.0, e, h, 0.7, 0.0, 0.36, "red_ochre")
	_pop()
	_push(_xf(Vector3.ZERO, 90))
	_gable("daub", 4.0, 3.0, wall_h, e + h - wall_h - 0.4)
	_pop()
	_pop()
	# portico: four timber columns carrying the roof's front overhang, and a pediment that
	# shows the open hand on an ochre sun
	var fz := 5.1    # under the front verge of the roof
	for x in [-2.6, -0.9, 0.9, 2.6]:
		_cyl("stone_light", Vector3(x, py, fz - 0.15), 0.3, 0.28, 0.25, 8)
		_cyl("timber", Vector3(x, py + 0.25, fz - 0.15), 0.18, 0.16, wall_h - 0.2, 8)
	var gy := py + wall_h
	_gable_front(Vector3(0, gy, fz - 0.1), 3.0, e + h - wall_h - 0.4)
	_lathe("red_ochre", Vector3(0, gy + 1.25, fz + 0.02), [Vector2(0.95, 0), Vector2(0.95, 0.06), Vector2(0, 0.06)], 14, Vector3(90, 0, 0))
	_hand_symbol("hand_gold", Vector3(0, gy + 1.2, fz + 0.1), Vector3(0, 0, 1), Vector3.UP, 1.25, 0.05)
	# the open hand raised on the ridge end, where everyone can see it
	var ridge := Vector3(0, py + e + h + 0.1, fz + 0.35)
	_beam("timber", ridge - Vector3(0, 0.4, 0.1), ridge + Vector3(0, 0.55, 0), 0.12)
	_hand_symbol("hand_gold", ridge + Vector3(0, 0.95, 0), Vector3(0, 0, 1), Vector3.UP, 1.1, 0.1)
	_hand_symbol("hand_gold", ridge + Vector3(0, 0.95, -0.1), Vector3(0, 0, -1), Vector3.UP, 1.1, 0.1)
	# great doors: the open hand painted across both leaves (DESIGN 7: on the temple doors)
	var dz := -0.6 + 4.0 + 0.12
	_box("cave_dark", Vector3(0, py + 1.15, dz - 0.05), Vector3(1.6, 2.3, 0.05))
	_box("planks", Vector3(-0.42, py + 1.1, dz), Vector3(0.82, 2.2, 0.08))
	_box("planks", Vector3(0.42, py + 1.1, dz), Vector3(0.82, 2.2, 0.08))
	_hand_symbol("hand_gold", Vector3(0, py + 1.1, dz + 0.05), Vector3(0, 0, 1), Vector3.UP, 0.85, 0.03)
	# braziers either side of the steps, the old shrine stone as the altar, offerings
	for sx in [-1.0, 1.0]:
		var bp := Vector3(sx * 2.1, 0, 6.7)
		_beam("bronze", bp, bp + Vector3(0, 1.0, 0), 0.07)
		for k in 3:
			var a := TAU * k / 3.0
			_beam("bronze", bp + Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), bp + Vector3(0, 0.6, 0), 0.04)
		_lathe("bronze", bp + Vector3(0, 1.0, 0), [Vector2(0.1, 0), Vector2(0.36, 0.2), Vector2(0.32, 0.22), Vector2(0.0, 0.08)], 9)
		_flames_node(_root, bp + Vector3(0, 1.1, 0), 0.5, sx > 0.0)
	_model(N + "Rock_1.fbx", Vector3(0, 0, 8.0), Vector3(0, 15, 0), Vector3(1.6, 1.7, 1.2), null, {"hog_pull": 0.3})
	_hand_symbol("red_ochre", Vector3(0, 1.25, 8.62), Vector3(0, 0.15, 1), Vector3.UP, 0.42, 0.03)
	_jar(Vector3(-0.9, 0, 8.3), 0.8, "terracotta", true, false, 20)
	_jar(Vector3(0.95, 0, 8.4), 0.9, "terracotta", true, true, -10)
	_bowl(Vector3(-0.5, 0, 8.8), 0.9)
	_rod("cloth_red", Vector3(0.5, 0.15, 8.9), Vector3(1.0, 0.15, 8.7), 0.14, 8)
	for i in 4:
		var a := TAU * i / 4.0 + 0.5
		_ball("cloth_gold", Vector3(-0.2 + cos(a) * 0.25, 0.06, 8.75 + sin(a) * 0.1), 0.07, 5, 3)
	# banners on the hall's front corners
	for sx in [-1.0, 1.0]:
		var bx: float = sx * 3.4
		_beam("timber", Vector3(bx, py, 3.6), Vector3(bx, py + 4.2, 3.6), 0.1)
		_beam("timber", Vector3(bx - 0.45, py + 4.1, 3.65), Vector3(bx + 0.45, py + 4.1, 3.65), 0.06)
		_quad("cloth_red", Vector3(bx - 0.4, py + 4.05, 3.7), Vector3(bx + 0.4, py + 4.05, 3.7), Vector3(bx + 0.4, py + 2.2, 3.7), Vector3(bx - 0.4, py + 2.2, 3.7), Vector3(0, 0, 1))
		_tri("cloth_red", Vector3(bx - 0.4, py + 2.2, 3.7), Vector3(bx + 0.4, py + 2.2, 3.7), Vector3(bx, py + 1.85, 3.7), Vector3(0, 0, 1))
		_hand_symbol("hand_gold", Vector3(bx, py + 3.2, 3.72), Vector3(0, 0, 1), Vector3.UP, 0.42, 0.012)
	_pop()
	_save("temple")

	_begin("temple_plot")
	_push(_xf(Vector3(0, 0, -1.7)))
	_plot(10.0, 11.6)
	_model(N + "Rock_1.fbx", Vector3(0, 0, 8.0), Vector3(0, 15, 0), Vector3(1.6, 1.7, 1.2), null, {"hog_pull": 0.3})
	_hand_symbol("red_ochre", Vector3(0, 1.25, 8.62), Vector3(0, 0.15, 1), Vector3.UP, 0.42, 0.03)
	_pop()
	_save("temple_plot")
	_begin("temple_frame")
	_push(_xf(Vector3(0, 0, -1.7)))
	_temple_platform()
	_push(_xf(Vector3(0, py, -0.6)))
	_frame(6.0, 8.0, wall_h, 3.6, 0.7)
	_pop()
	_model(N + "Rock_1.fbx", Vector3(0, 0, 8.0), Vector3(0, 15, 0), Vector3(1.6, 1.7, 1.2), null, {"hog_pull": 0.3})
	_hand_symbol("red_ochre", Vector3(0, 1.25, 8.62), Vector3(0, 0.15, 1), Vector3.UP, 0.42, 0.03)
	_pop()
	_save("temple_frame")


func _temple_platform() -> void:
	_box("stone_light", Vector3(0, 0.25, 0.2), Vector3(10.0, 0.5, 11.6))
	_box("stone", Vector3(0, 0.7, 0.0), Vector3(8.8, 0.4, 10.4))
	for i in 3:
		_box("stone_light", Vector3(0, (i + 1) * 0.15, 6.4 - i * 0.4), Vector3(3.2, 0.3 + i * 0.3, 0.4))
	for x in [-4.5, 4.5]:
		for z in [-5.1, 5.5]:
			_box("stone", Vector3(x, 0.4, z), Vector3(0.6, 0.8, 0.6))


## Front gable (pediment) triangle facing +Z at c (base centre), half width hw, height ph.
func _gable_front(c: Vector3, hw: float, ph: float) -> void:
	var A := c + Vector3(-hw, 0, 0)
	var B := c + Vector3(hw, 0, 0)
	var C := c + Vector3(0, ph, 0)
	_tri("daub", A, B, C, Vector3(0, 0, 1))
	_tri("daub", A + Vector3(0, 0, -0.2), B + Vector3(0, 0, -0.2), C + Vector3(0, 0, -0.2), Vector3(0, 0, -1))
	_beam("timber", A + Vector3(-0.1, 0, 0.06), B + Vector3(0.1, 0, 0.06), 0.24, 0.2)
	_beam("timber", A + Vector3(0, 0, 0.06), C + Vector3(0, 0, 0.06), 0.16)
	_beam("timber", B + Vector3(0, 0, 0.06), C + Vector3(0, 0, 0.06), 0.16)


# ================================================================== infrastructure

func _bridge() -> void:
	# Bridge over the great river (milestone 2): a gently arched timber deck on piers with
	# stone cutwaters. Runs along X, 18 m between banks; piers reach 2 m below ground level.
	_begin("bridge")
	_bridge_piers(true)
	var n := 40
	for i in n:
		var x := -9.0 + 18.0 * (i + 0.5) / n
		var y := _bridge_y(x)
		var tone: String = "wood" if i % 3 != 1 else "wood_dark"
		_box(tone, Vector3(x, y, 0), Vector3(18.0 / n - 0.03, 0.12, 3.6 + (0.1 if i % 2 == 0 else 0.0)), Vector3(0, 0, rad_to_deg(atan(_bridge_slope(x)))))
	for sz in [-1.0, 1.0]:
		var z: float = sz * 1.75
		for k in 10:
			var x0 := -9.0 + 18.0 * k / 10.0
			var x1 := -9.0 + 18.0 * (k + 1) / 10.0
			_beam("timber", Vector3(x0, _bridge_y(x0) - 0.15, z), Vector3(x1, _bridge_y(x1) - 0.15, z), 0.2, 0.3)
			_beam("timber", Vector3(x0, _bridge_y(x0) + 0.95, z), Vector3(x1, _bridge_y(x1) + 0.95, z), 0.12)
			_beam("wood", Vector3(x0, _bridge_y(x0) + 0.5, z), Vector3(x1, _bridge_y(x1) + 0.5, z), 0.06)
		for k in 11:
			var x := -9.0 + 18.0 * k / 10.0
			_beam("timber", Vector3(x, _bridge_y(x) + 0.05, z), Vector3(x, _bridge_y(x) + 1.05, z), 0.14)
	for sx in [-1.0, 1.0]:   # bank posts with a carved cap
		for sz in [-1.0, 1.0]:
			_cyl("timber", Vector3(sx * 9.1, 0, sz * 1.75), 0.17, 0.15, 1.35, 8)
			_lathe("wood_dark", Vector3(sx * 9.1, 1.35, sz * 1.75), [Vector2(0.2, 0), Vector2(0.16, 0.12), Vector2(0, 0.25)], 8)
	_save("bridge")
	_begin("bridge_plot")
	_box("dirt", Vector3(-8.2, 0.025, 0), Vector3(2.4, 0.05, 4.6))
	_box("dirt", Vector3(8.2, 0.025, 0), Vector3(2.4, 0.05, 4.6))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("wood", Vector3(sx * 9.0, 0.35, sz * 1.9), Vector3(0.1, 0.7, 0.1))
		_beam("rope", Vector3(sx * 9.0, 0.6, -1.9), Vector3(sx * 9.0, 0.6, 1.9), 0.025)
	_beam("rope", Vector3(-9.0, 0.6, 1.9), Vector3(9.0, 0.6, 1.9), 0.02)
	_beam("rope", Vector3(-9.0, 0.6, -1.9), Vector3(9.0, 0.6, -1.9), 0.02)
	for i in 4:
		_rod("wood", Vector3(-10.6, 0.2 + (i / 2) * 0.36, -1.2 + (i % 2) * 0.42 + (i / 2) * 0.2), Vector3(-6.8, 0.2 + (i / 2) * 0.36, -1.2 + (i % 2) * 0.42 + (i / 2) * 0.2), 0.19, 7)
	_model(K + "resource-planks.glb", Vector3(8.6, 0, -0.6), Vector3(0, 90, 0), 5.0, null, KEN)
	_model(K + "resource-stone-large.glb", Vector3(8.4, 0, 1.2), Vector3(0, 30, 0), 3.5, null, KEN)
	_save("bridge_plot")
	_begin("bridge_frame")
	_bridge_piers(false)
	for sz in [-1.0, 1.0]:
		var z: float = sz * 1.6
		for k in 10:
			var x0 := -9.0 + 18.0 * k / 10.0
			var x1 := -9.0 + 18.0 * (k + 1) / 10.0
			if k < 7:
				_beam("wood", Vector3(x0, _bridge_y(x0) - 0.15, z), Vector3(x1, _bridge_y(x1) - 0.15, z), 0.2, 0.3)
	for i in 14:   # first planks laid from the near bank
		var x := -9.0 + 0.45 * (i + 0.5)
		_box("wood", Vector3(x, _bridge_y(x), 0), Vector3(0.42, 0.12, 3.6), Vector3(0, 0, rad_to_deg(atan(_bridge_slope(x)))))
	_model(K + "resource-planks.glb", Vector3(-8.0, _bridge_y(-8.0) + 0.06, 0.6), Vector3(0, 5, 0), 4.0, null, KEN)
	_save("bridge_frame")


func _bridge_y(x: float) -> float:
	return 0.5 + 1.1 * (1.0 - pow(x / 9.0, 2.0))


func _bridge_slope(x: float) -> float:
	return -2.2 * x / 81.0


func _bridge_piers(finished: bool) -> void:
	for px in [-4.5, 0.0, 4.5]:
		var top := _bridge_y(px) - 0.3
		_box("stone", Vector3(px, -1.4, 0), Vector3(1.0, 1.4, 4.2))
		_lathe("stone", Vector3(px, -2.1, 2.1), [Vector2(0.5, 0), Vector2(0.5, 1.4), Vector2(0.0, 1.4)], 4, Vector3(0, 45, 0))
		_lathe("stone", Vector3(px, -2.1, -2.1), [Vector2(0.5, 0), Vector2(0.5, 1.4), Vector2(0.0, 1.4)], 4, Vector3(0, 45, 0))
		for z in [-1.6, -0.55, 0.55, 1.6]:
			_beam("timber", Vector3(px - 0.25, -0.7, z), Vector3(px - 0.25, top, z), 0.2)
			_beam("timber", Vector3(px + 0.25, -0.7, z), Vector3(px + 0.25, top, z), 0.2)
		_beam("timber", Vector3(px, top, -2.0), Vector3(px, top, 2.0), 0.3, 0.25)
		if finished:
			_beam("timber", Vector3(px - 0.25, -0.5, -1.6), Vector3(px - 0.25, top - 0.2, 1.6), 0.1)
			_beam("timber", Vector3(px + 0.25, -0.5, 1.6), Vector3(px + 0.25, top - 0.2, -1.6), 0.1)


func _well() -> void:
	# Drought answer: a stone well with a windlass and a little thatched roof.
	_begin("well")
	_well_ring()
	_lathe("water", Vector3(0, 0.55, 0), [Vector2(0.72, 0), Vector2(0, 0)], 12)
	for sx in [-1.0, 1.0]:
		_beam("timber", Vector3(sx * 0.95, 0.1, 0), Vector3(sx * 0.95, 2.2, 0), 0.16)
	var axle := _part("Windlass", Vector3(0, 1.45, 0), _windlass)
	axle.set_script(SPINNER)
	axle.set("spinning", false)
	axle.set("axis", Vector3.RIGHT)
	_beam("wood_dark", Vector3(1.05, 1.45, 0), Vector3(1.25, 1.45, 0), 0.06)
	_beam("wood_dark", Vector3(1.25, 1.45, 0), Vector3(1.25, 1.1, 0.0), 0.05)
	_rod("rope", Vector3(0, 1.32, 0.1), Vector3(0, 0.95, 0.1), 0.015, 4)
	_model(K + "bucket.glb", Vector3(0.0, 0.62, 0.1), Vector3(0, 30, 0), 3.0, null, KEN)
	_roof("thatch", 2.3, 1.5, 1.95, 0.9, 0.25, 0.0, 0.2)
	_model(K + "bucket.glb", Vector3(1.2, 0, 0.8), Vector3(0, 70, 0), 3.0, null, KEN)
	_trough(Vector3(-1.6, 0, 0.6), 90)
	_save("well")
	_begin("well_plot")
	_plot(2.4, 2.4, true)
	_save("well_plot")
	_begin("well_frame")
	_cyl("dirt", Vector3.ZERO, 1.3, 1.25, 0.05, 14)
	_lathe("stone", Vector3.ZERO, [Vector2(1.0, 0), Vector2(1.0, 0.4), Vector2(0.75, 0.4), Vector2(0.75, 0.1)], 12)
	_lathe("cave_dark", Vector3(0, 0.12, 0), [Vector2(0.75, 0), Vector2(0, 0)], 12)
	for i in 5:
		_stone(Vector3(1.4 + (i % 2) * 0.35, 0, -0.8 + i * 0.35), 0.35)
	_beam("wood", Vector3(-0.95, 0.1, 0), Vector3(-0.95, 2.2, 0), 0.16)
	_save("well_frame")


func _windlass() -> void:
	_rod("wood", Vector3(-0.95, 0, 0), Vector3(0.95, 0, 0), 0.11, 7)
	_rod("rope", Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0), 0.14, 7)


func _well_ring() -> void:
	_lathe("stone", Vector3.ZERO, [Vector2(1.0, 0), Vector2(1.02, 0.7), Vector2(1.05, 0.72), Vector2(1.05, 0.85),
		Vector2(0.75, 0.85), Vector2(0.75, 0.4)], 12)
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		_box("stone_dark", Vector3(cos(a) * 1.02, 0.35 + (i % 2) * 0.2, sin(a) * 1.02), Vector3(0.05, 0.04, 0.3), Vector3(0, -rad_to_deg(a), 0))


func _trough(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	_box("planks", Vector3(0, 0.38, 0.3), Vector3(1.4, 0.36, 0.08))
	_box("planks", Vector3(0, 0.38, -0.3), Vector3(1.4, 0.36, 0.08))
	_box("planks", Vector3(0.66, 0.38, 0), Vector3(0.08, 0.36, 0.6))
	_box("planks", Vector3(-0.66, 0.38, 0), Vector3(0.08, 0.36, 0.6))
	_box("planks", Vector3(0, 0.22, 0), Vector3(1.3, 0.06, 0.55))
	_box("water", Vector3(0, 0.48, 0), Vector3(1.26, 0.04, 0.52))
	for sx in [-0.55, 0.55]:
		_box("wood_dark", Vector3(sx, 0.1, 0), Vector3(0.1, 0.2, 0.7))
	_pop()


func _watchtower() -> void:
	# Bear watch: a timber tower with a ladder, a railed platform and a thatched cap.
	_begin("watchtower")
	_tower_legs()
	var py := 4.8
	_box("planks", Vector3(0, py, 0), Vector3(2.5, 0.12, 2.5))
	for sx in [-1.0, 1.0]:
		_box("planks", Vector3(sx * 1.2, py + 0.5, 0), Vector3(0.08, 0.9, 2.4))
		_box("planks", Vector3(0, py + 0.5, sx * 1.2), Vector3(2.4, 0.9, 0.08))
	for c in [Vector3(1.15, 0, 1.15), Vector3(-1.15, 0, 1.15), Vector3(1.15, 0, -1.15), Vector3(-1.15, 0, -1.15)]:
		_beam("timber", c + Vector3(0, py, 0), c + Vector3(0, py + 2.0, 0), 0.12)
	_roof("thatch", 2.4, 2.4, py + 2.0, 1.3, 0.35, 1.0, 0.22)
	_ladder(Vector3(0.3, 0, 2.3), Vector3(0.3, py + 0.05, 1.28), 0.5)
	_lathe("bone", Vector3(0.9, py + 1.05, 1.25), [Vector2(0.02, 0), Vector2(0.09, 0.35), Vector2(0.0, 0.35)], 6, Vector3(0, 0, -100))   # horn
	_save("watchtower")
	_begin("watchtower_plot")
	_plot(2.6, 2.6)
	_save("watchtower_plot")
	_begin("watchtower_frame")
	_tower_legs()
	_box("planks", Vector3(0.5, 4.8, 0), Vector3(1.5, 0.12, 2.5))
	_save("watchtower_frame")


func _tower_legs() -> void:
	_box("dirt", Vector3(0, 0.025, 0), Vector3(3.6, 0.05, 3.6))
	for c in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		_stone(c * 1.5, 0.45)
		_beam("timber", c * 1.5 + Vector3(0, 0.15, 0), c * 1.05 + Vector3(0, 4.8, 0), 0.2)
	for y in [1.4, 3.1]:
		var r: float = 1.5 - (y / 4.8) * 0.45
		for i in 4:
			var a: Vector3 = Vector3([1, -1, -1, 1][i], 0, [1, 1, -1, -1][i]) * r
			var b: Vector3 = Vector3([-1, -1, 1, 1][i], 0, [1, -1, -1, 1][i]) * r
			_beam("wood", a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.12)
			_beam("wood", a + Vector3(0, y, 0), b + Vector3(0, y + 1.6, 0) * Vector3(0.9, 1, 0.9), 0.08)


func _sheep_pen() -> void:
	# Wattle hurdles round an 8 x 6 fold, a gate, a hay rack and a trough.
	_begin("sheep_pen")
	var hw := 4.0
	var hd := 3.0
	for i in 4:
		_hurdle(Vector3(-hw + 1 + i * 2, 0, -hd), 0)
		if i != 1:
			_hurdle(Vector3(-hw + 1 + i * 2, 0, hd), 0)
	for i in 3:
		_hurdle(Vector3(-hw, 0, -hd + 1 + i * 2), 90)
		_hurdle(Vector3(hw, 0, -hd + 1 + i * 2), 90)
	_gate(Vector3(-hw + 3, 0, hd), 0, 25)
	# hay rack
	_push(_xf(Vector3(2.4, 0, -2.2), 0))
	for sx in [-0.7, 0.7]:
		_beam("timber", Vector3(sx, 0, 0), Vector3(sx, 1.3, 0), 0.1)
	for k in 7:
		var x := -0.6 + k * 0.2
		_beam("wood", Vector3(x, 0.4, 0.15), Vector3(x, 1.25, 0.4), 0.04)
	_box("straw", Vector3(0, 1.05, 0.18), Vector3(1.3, 0.5, 0.3), Vector3(-15, 0, 0))
	_pop()
	_trough(Vector3(-2.5, 0, -2.2), 0)
	for i in 10:   # trodden straw
		var c := Vector3(_rng.randf_range(-3.2, 3.2), 0.0, _rng.randf_range(-2.2, 2.2))
		for k in 5:
			var a := _rng.randf() * TAU
			_blade("straw", c + Vector3(cos(a), 0, sin(a)) * 0.15, 0.06, 0.05, Vector3(cos(a), 0, sin(a)) * 0.3, a)
	_save("sheep_pen")
	_begin("sheep_pen_plot")
	_box("dirt", Vector3(0, 0.02, 0), Vector3(8.4, 0.04, 6.4))
	for c in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd)]:
		_box("wood", c + Vector3(0, 0.4, 0), Vector3(0.08, 0.8, 0.08))
	for i in 3:
		_hurdle(Vector3(-hw + 1.5, 0.0, -hd - 1.2 - i * 0.12), 0, 0.12 + i * 0.12, 80)
	_save("sheep_pen_plot")
	_begin("sheep_pen_frame")
	_box("dirt", Vector3(0, 0.02, 0), Vector3(8.4, 0.04, 6.4))
	for i in 4:
		_hurdle(Vector3(-hw + 1 + i * 2, 0, -hd), 0)
	for i in 3:
		_hurdle(Vector3(-hw, 0, -hd + 1 + i * 2), 90)
	for k in 5:
		_box("wood", Vector3(-hw + k * 2.0, 0.55, hd), Vector3(0.08, 1.1, 0.08))
		_box("wood", Vector3(hw, 0.55, -hd + k * 1.5), Vector3(0.08, 1.1, 0.08))
	_save("sheep_pen_frame")


## Woven wattle hurdle, 2 m long, centred at p, along local X. y_lift/tilt lay one flat.
func _hurdle(p: Vector3, rot_y: float, y_lift := 0.0, tilt := 0.0) -> void:
	_push(Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)) * Basis(Vector3.RIGHT, deg_to_rad(-tilt)), p + Vector3(0, y_lift, 0)))
	var stakes := 6
	for i in stakes:
		var x := -0.95 + 1.9 * i / (stakes - 1)
		_beam("wood", Vector3(x, 0, 0), Vector3(x, 1.05 + (0.06 if i % 2 == 0 else 0.0), 0), 0.05)
	for row in 7:
		var y := 0.2 + row * 0.12
		for i in stakes - 1:
			var x0 := -0.95 + 1.9 * i / (stakes - 1)
			var x1 := -0.95 + 1.9 * (i + 1) / (stakes - 1)
			var s0 := 0.035 if (i + row) % 2 == 0 else -0.035
			_beam("wood_dark" if row % 3 == 1 else "wood", Vector3(x0, y, s0), Vector3(x1, y + 0.01, -s0), 0.045)
	_pop()


func _gate(p: Vector3, rot_y: float, open_deg: float) -> void:
	_push(_xf(p, rot_y))
	_beam("timber", Vector3(-1.0, 0, 0), Vector3(-1.0, 1.2, 0), 0.12)
	_beam("timber", Vector3(1.0, 0, 0), Vector3(1.0, 1.2, 0), 0.12)
	_push(Transform3D(Basis(Vector3.UP, deg_to_rad(open_deg)), Vector3(-0.92, 0, 0)))
	for y in [0.25, 0.6, 0.95]:
		_beam("wood", Vector3(0, y, 0), Vector3(1.8, y, 0), 0.07)
	_beam("wood", Vector3(0.05, 0.25, 0), Vector3(1.75, 0.95, 0), 0.06)
	_beam("wood", Vector3(0.05, 0.15, 0), Vector3(0.05, 1.05, 0), 0.08)
	_beam("wood", Vector3(1.75, 0.15, 0), Vector3(1.75, 1.05, 0), 0.08)
	_pop()
	_pop()


func _market_stall() -> void:
	# Joy and trade: a striped awning over a counter of goods. Three stalls.
	var looks := [["cloth_red", "bread"], ["cloth_blue", "pots"], ["cloth_gold", "cloth"]]
	for v in looks.size():
		var nm := "market_stall_%s" % ["a", "b", "c"][v]
		_begin(nm)
		var w := 2.8
		for c in [Vector3(-1.3, 0, 0.9), Vector3(1.3, 0, 0.9), Vector3(-1.3, 0, -0.9), Vector3(1.3, 0, -0.9)]:
			_beam("timber", c, c + Vector3(0, 2.3 if c.z > 0 else 2.6, 0), 0.1)
		_box("planks", Vector3(0, 0.85, 0.7), Vector3(w, 0.08, 0.7))
		_box("planks", Vector3(0, 0.42, 1.03), Vector3(w, 0.8, 0.06))
		_box("planks", Vector3(0, 0.6, -0.8), Vector3(w, 0.06, 0.5))
		# striped awning
		var stripes := 7
		for i in stripes:
			var x0 := -1.55 + 3.1 * i / stripes
			var x1 := -1.55 + 3.1 * (i + 1) / stripes
			var m: String = looks[v][0] if i % 2 == 0 else "linen"
			_quad(m, Vector3(x0, 2.7, -1.05), Vector3(x1, 2.7, -1.05), Vector3(x1, 2.25, 1.35), Vector3(x0, 2.25, 1.35), Vector3(0, 1, 0.2))
			_quad(m, Vector3(x0, 2.25, 1.35), Vector3(x1, 2.25, 1.35), Vector3(x1, 1.95, 1.42), Vector3(x0, 1.95, 1.42), Vector3(0, 0, 1))
		match looks[v][1]:
			"bread":
				for i in 7:
					_loaf(Vector3(-1.1 + i * 0.35, 0.89, 0.6 + (i % 2) * 0.15), 1.0, i * 30)
				_basket(Vector3(0.9, 0.89, 0.6), 0.25, 0.22)
				_sack(Vector3(1.75, 0, 0.3), "linen", 0.9)
				_sack(Vector3(-1.75, 0, -0.2), "rope", 0.9)
			"pots":
				for i in 4:
					_jar(Vector3(-1.0 + i * 0.6, 0.89, 0.65), 0.55 + (i % 2) * 0.15, "terracotta", true, i == 2, 10 - i * 7)
				for i in 3:
					_bowl(Vector3(-0.8 + i * 0.7, 0.63, -0.8), 0.8)
				_jar(Vector3(1.8, 0, 0.6), 1.0, "terracotta", true, true, -20)
			"cloth":
				var cm := ["cloth_red", "cloth_blue", "linen", "cloth_green", "cloth_gold"]
				for i in 5:
					_rod(cm[i], Vector3(-1.1 + i * 0.5, 0.98, 0.95), Vector3(-1.1 + i * 0.5, 0.98, 0.4), 0.11, 8)
				_wool_bales(Vector3(1.9, 0, -0.1))
				_quad("cloth_blue", Vector3(-1.2, 2.2, -0.85), Vector3(-0.3, 2.2, -0.85), Vector3(-0.3, 1.0, -0.85), Vector3(-1.2, 1.0, -0.85), Vector3(0, 0, 1))
				_quad("cloth_red", Vector3(0.2, 2.2, -0.85), Vector3(1.1, 2.2, -0.85), Vector3(1.1, 1.2, -0.85), Vector3(0.2, 1.2, -0.85), Vector3(0, 0, 1))
		_save(nm)
	_begin("market_stall_frame")
	for c in [Vector3(-1.3, 0, 0.9), Vector3(1.3, 0, 0.9), Vector3(-1.3, 0, -0.9), Vector3(1.3, 0, -0.9)]:
		_beam("wood", c, c + Vector3(0, 2.3 if c.z > 0 else 2.6, 0), 0.1)
	_box("planks", Vector3(0, 0.85, 0.7), Vector3(2.8, 0.08, 0.7))
	_rod("linen", Vector3(-1.0, 0.15, -0.3), Vector3(1.0, 0.15, -0.5), 0.15, 8)
	_save("market_stall_frame")


# ================================================================== water

func _jetty() -> void:
	# Fishing jetty: deck along Z from the bank (z = +4) out over the water (piles to y = -2).
	_begin("jetty")
	var n := 22
	for i in n:
		var z := 4.0 - 8.0 * (i + 0.5) / n
		_box("wood" if i % 4 != 2 else "wood_dark", Vector3(_rng.randf_range(-0.03, 0.03), 0.55, z), Vector3(2.4 + _rng.randf_range(-0.08, 0.08), 0.08, 8.0 / n - 0.03))
	for z in [3.8, 1.3, -1.2, -3.7]:
		for sx in [-1.1, 1.1]:
			_cyl("timber", Vector3(sx, -2.0, z), 0.13, 0.13, 2.85 if z > 3 else 2.7, 7)
		_beam("timber", Vector3(-1.25, 0.42, z), Vector3(1.25, 0.42, z), 0.16)
	for sx in [-1.0, 1.0]:
		_beam("timber", Vector3(sx * 1.1, 0.42, 4.0), Vector3(sx * 1.1, 0.42, -4.0), 0.16)
	_lathe("rope", Vector3(0.6, 0.6, -3.2), [Vector2(0.28, 0), Vector2(0.28, 0.1), Vector2(0.12, 0.1), Vector2(0.12, 0.0)], 10)
	_model(K + "barrel.glb", Vector3(-0.7, 0.59, -2.8), Vector3.ZERO, 3.0, null, KEN)
	_basket(Vector3(-0.6, 0.59, 2.6), 0.3, 0.25)
	_model(K + "fish.glb", Vector3(-0.6, 0.85, 2.6), Vector3(0, 60, 0), 2.5, null, {"hog_pull": 0.4, "hog_sat": 0.5})
	_save("jetty")


func _raft() -> void:
	# The first boat (raft launch, 5 people): lashed logs, cross bars, a steering oar.
	_begin("raft")
	_raft_logs(true)
	_beam("wood", Vector3(0.2, 0.42, -2.2), Vector3(0.2, 1.0, -2.2), 0.08)        # oar post
	_rod("wood", Vector3(0.55, 1.05, -0.9), Vector3(0.1, 0.25, -3.6), 0.045, 5)  # steering oar
	_box("wood", Vector3(0.12, 0.2, -3.55), Vector3(0.05, 0.35, 0.6), Vector3(-30, 0, 0))
	_model(K + "box.glb", Vector3(-0.5, 0.42, 0.6), Vector3(0, 15, 0), 3.0, null, KEN)
	_sack(Vector3(0.5, 0.42, 0.9), "rope", 0.8)
	_save("raft")
	_begin("raft_frame")
	_raft_logs(false)
	_save("raft_frame")


func _raft_logs(lashed: bool) -> void:
	for i in 7:
		var x := -1.2 + i * 0.4
		var l := 4.6 + (0.3 if i % 2 == 0 else 0.0)
		var off := Vector3(0, 0, 0) if lashed else Vector3(_rng.randf_range(-0.5, 0.5) + x * 0.6, 0, _rng.randf_range(-0.6, 0.6))
		var a := Vector3(x, 0.2, l * 0.5) + off
		var b := Vector3(x, 0.2, -l * 0.5) + off
		if not lashed:
			var yaw := _rng.randf_range(-0.25, 0.25)
			a = Vector3(x + yaw * 2, 0.2, l * 0.5) + off
			b = Vector3(x - yaw * 2, 0.2, -l * 0.5) + off
		_rod("wood", a, b, 0.2, 7)
		_lathe("bone", a + Vector3(0, 0, 0.005), [Vector2(0.17, 0), Vector2(0, 0)], 7, Vector3(90, 0, 0))
	if lashed:
		for z in [-1.6, 0.0, 1.6]:
			_beam("wood_dark", Vector3(-1.5, 0.42, z), Vector3(1.5, 0.42, z), 0.1)
			for i in 7:
				_rod("rope", Vector3(-1.2 + i * 0.4, 0.33, z + 0.12), Vector3(-1.2 + i * 0.4, 0.33, z + 0.18), 0.22, 6)


func _boats() -> void:
	_begin("rowboat")
	_model(BO + "boat-row-small.glb", Vector3.ZERO, Vector3(0, 0, 0), 1.5, null, {"hog_pull": 0.1, "hog_sat": 0.12, "hog_tint": Color("#b48a62")})
	_save("rowboat")
	_begin("fishing_boat")
	_model(BO + "boat-row-large.glb", Vector3.ZERO, Vector3(0, 0, 0), 1.5, null, {"hog_pull": 0.1, "hog_sat": 0.12, "hog_tint": Color("#b48a62")})
	_save("fishing_boat")


# ================================================================== farming

const FIELD_W := 8.0
const FIELD_D := 6.0
const ROWS := 8


func _fields() -> void:
	for stage in ["tilled", "sprouts", "growing", "ripe", "stubble", "blighted", "parched"]:
		_begin("field_" + stage)
		_field(stage)
		_save("field_" + stage)
	_begin("sheaves")
	_stook(Vector3.ZERO)
	_save("sheaves")
	_begin("haystack")
	_haystack(Vector3.ZERO, 1.0)
	_save("haystack")


func _field(stage: String) -> void:
	var soil := "soil" if stage != "parched" else "dirt"
	_box(soil, Vector3(0, 0.03, 0), Vector3(FIELD_W, 0.06, FIELD_D))
	# low earth bank all round
	for sz in [-1.0, 1.0]:
		_beam("soil_dark", Vector3(-FIELD_W * 0.5, 0.05, sz * FIELD_D * 0.5), Vector3(FIELD_W * 0.5, 0.05, sz * FIELD_D * 0.5), 0.3, 0.14)
	for sx in [-1.0, 1.0]:
		_beam("soil_dark", Vector3(sx * FIELD_W * 0.5, 0.05, -FIELD_D * 0.5), Vector3(sx * FIELD_W * 0.5, 0.05, FIELD_D * 0.5), 0.3, 0.14)
	var dz := FIELD_D / ROWS
	for r in ROWS:
		var z := -FIELD_D * 0.5 + dz * (r + 0.5)
		if stage != "stubble":
			_ridge(z, dz, "soil_dark" if stage != "parched" else "soil")
		var x := -FIELD_W * 0.5 + 0.25
		var i := 0
		while x < FIELD_W * 0.5 - 0.2:
			var p := Vector3(x + _rng.randf_range(-0.05, 0.05), 0.12, z + _rng.randf_range(-0.06, 0.06))
			match stage:
				"sprouts":
					_plant(p, 0.26, "crop_young", 4, 0.0)
				"growing":
					_clump(p, 0.62 + _rng.randf_range(-0.08, 0.08), 0.2, "crop_green", false)
				"ripe":
					_clump(p, 0.95 + _rng.randf_range(-0.1, 0.1), 0.27, "crop_gold", true)
				"blighted":
					var sick := _blight(p)
					if sick > 0.5:
						if _rng.randf() < 0.7:
							_clump(p, 0.32 + _rng.randf_range(0.0, 0.15), 0.17, "crop_blight", false, 0.2)
					else:
						_clump(p, 0.62 + _rng.randf_range(-0.08, 0.08), 0.2, "crop_green", false)
				"parched":
					if i % 2 == 0:
						_plant(p, 0.28, "crop_blight", 3, 0.0, 0.3)
				"stubble":
					_plant(p - Vector3(0, 0.07, 0), 0.12, "crop_gold", 3, 0.0)
			x += 0.26
			i += 1
	match stage:
		"tilled":
			for k in 8:
				_ball("soil_dark", Vector3(_rng.randf_range(-3.6, 3.6), 0.1, _rng.randf_range(-2.6, 2.6)), 0.12, 5, 3, Vector3(1, 0.6, 1))
		"stubble":
			_stook(Vector3(-2.0, 0, -1.2))
			_stook(Vector3(1.5, 0, 0.8))
			_stook(Vector3(-0.4, 0, 1.9))
		"ripe":
			pass
		"parched":
			for k in 14:   # cracks
				var a := _rng.randf() * TAU
				var c := Vector3(_rng.randf_range(-3.5, 3.5), 0.065, _rng.randf_range(-2.5, 2.5))
				_box("soil_dark", c, Vector3(_rng.randf_range(0.5, 1.1), 0.01, 0.04), Vector3(0, rad_to_deg(a), 0))


func _blight(p: Vector3) -> float:
	var centres := [Vector3(-1.8, 0, -1.0), Vector3(2.2, 0, 1.4), Vector3(0.6, 0, -2.0)]
	var best := 0.0
	for c in centres:
		best = maxf(best, 1.0 - Vector2(p.x - c.x, p.z - c.z).length() / 1.6)
	return best + _rng.randf_range(-0.15, 0.15)


func _ridge(z: float, dz: float, m: String) -> void:
	var hw := FIELD_W * 0.5 - 0.15
	var w := dz * 0.42
	var a := Vector3(-hw, 0.06, z - w)
	var b := Vector3(hw, 0.06, z - w)
	var c := Vector3(hw, 0.15, z)
	var d := Vector3(-hw, 0.15, z)
	_quad(m, a, b, c, d, Vector3(0, 1, -0.6))
	_quad(m, d, c, Vector3(hw, 0.06, z + w), Vector3(-hw, 0.06, z + w), Vector3(0, 1, 0.6))


## One cereal plant: n stalks, with ears (ear = 1) that nod; droop bends sick plants over.
func _plant(p: Vector3, h: float, m: String, n: int, ear: float, droop := 0.0) -> void:
	for k in n:
		var a := _rng.randf() * TAU
		var lean := Vector3(cos(a), 0, sin(a)) * (0.05 + droop + h * 0.08)
		var hh := h * _rng.randf_range(0.8, 1.05)
		_blade(m, p, hh, 0.018 if ear > 0.0 else 0.03, lean, a)
		if ear > 0.0:
			var top := p + Vector3(0, hh, 0) + lean
			var nod := Vector3(cos(a), 0, sin(a)) * 0.06
			_blade("straw", top - Vector3(0, 0.02, 0), 0.2, 0.035, nod + Vector3(0, -0.02, 0), a)
	if ear == 0.0 and h > 0.3:   # a couple of leaves
		for k in 2:
			var a := _rng.randf() * TAU
			_blade(m, p + Vector3(0, h * 0.25, 0), h * 0.5, 0.025, Vector3(cos(a), 0, sin(a)) * h * 0.45, a)


## A cereal clump: a solid tufted core so fields read as a mass from the high camera,
## leaves round it, and nodding ears when ripe. droop bends sick plants over.
func _clump(p: Vector3, h: float, r: float, m: String, ears: bool, droop := 0.0) -> void:
	var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * droop
	_push(Transform3D(Basis.IDENTITY, p))
	var ph := _rng.randf() * TAU
	_lathe(m, Vector3.ZERO, [Vector2(r * 0.45, 0), Vector2(r, h * 0.55), Vector2(r * 0.55, h * 0.85), Vector2(0.0, h)], 5,
		Vector3(rad_to_deg(lean.z), 0, -rad_to_deg(lean.x)), Vector3.ONE, ph)
	for k in 5:
		var a := ph + TAU * k / 5.0 + 0.3
		var out := Vector3(cos(a), 0, sin(a))
		_blade(m, out * r * 0.5, h * _rng.randf_range(0.75, 1.0), 0.035, out * (0.18 + r * 0.4) + lean, a)
	if ears:
		for k in 6:
			var a := ph + TAU * k / 6.0
			var out := Vector3(cos(a), 0, sin(a))
			var base := out * r * 0.55 + Vector3(0, h * _rng.randf_range(0.82, 1.0), 0)
			_blade("straw", base, 0.24, 0.045, out * 0.1 + Vector3(0, -0.02, 0), a)
	_pop()


func _stook(c: Vector3) -> void:
	# a stook: two rows of sheaves leaning together to dry, each tied round the middle
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		var along := (i / 2) * 0.3 - 0.45
		var foot := c + Vector3(along, 0, side * 0.42)
		var top := c + Vector3(along, 0.95, side * 0.1)
		_rod("straw", foot, top, 0.14, 6, 0.11)
		_rod("rope", foot.lerp(top, 0.5), foot.lerp(top, 0.58), 0.13, 6)
		var d := (top - foot).normalized()
		_push(Transform3D(Basis(d.cross(Vector3.FORWARD).normalized(), d, d.cross(Vector3.FORWARD).normalized().cross(d)), top))
		_lathe("crop_gold", Vector3.ZERO, [Vector2(0.11, 0), Vector2(0.2, 0.16), Vector2(0.12, 0.3), Vector2(0.0, 0.34)], 6)
		_pop()


func _haystack(c: Vector3, s: float) -> void:
	_lathe("thatch", c, [Vector2(1.15, 0), Vector2(1.35, 0.55), Vector2(1.3, 1.25), Vector2(0.95, 1.95), Vector2(0.45, 2.4),
		Vector2(0.0, 2.55)], 10, Vector3.ZERO, Vector3.ONE * s, 0.0, true, 0.8)
	_rod("wood", c + Vector3(0, 2.3, 0) * s, c + Vector3(0.05, 3.0, 0) * s, 0.05 * s, 5)
	for i in 5:
		var a := TAU * i / 5.0
		_ball("straw", c + Vector3(cos(a) * 1.3, 0.05, sin(a) * 1.3) * s, 0.3 * s, 6, 2, Vector3(1, 0.25, 1))


func _garden_plot() -> void:
	# Kitchen garden: two raised beds (cabbages, carrots), a bean row and a little fence.
	_begin("garden_plot")
	for bz in [-0.8, 0.8]:
		_box("soil", Vector3(0, 0.12, bz), Vector3(3.6, 0.24, 1.1))
		for sx in [-1.0, 1.0]:
			_box("wood", Vector3(sx * 1.82, 0.13, bz), Vector3(0.08, 0.26, 1.2))
			_box("wood", Vector3(0, 0.13, bz + sx * 0.58), Vector3(3.7, 0.26, 0.08))
	for i in 6:
		for j in 2:
			var p := Vector3(-1.45 + i * 0.58, 0.24, -1.05 + j * 0.5)
			_cabbage(p)
	for i in 9:
		for j in 2:
			var p := Vector3(-1.5 + i * 0.37, 0.24, 0.55 + j * 0.5)
			for k in 4:
				var a := TAU * k / 4.0 + i
				_blade("crop_young", p, 0.32, 0.03, Vector3(cos(a), 0, sin(a)) * 0.12, a)
			_lathe("carrot", p + Vector3(0, -0.02, 0), [Vector2(0.05, 0), Vector2(0.0, 0.06)], 5)
	# bean poles
	for i in 5:
		var x := -1.6 + i * 0.8
		_beam("wood", Vector3(x, 0, -1.9), Vector3(x + 0.2, 1.6, -1.75), 0.04)
		_beam("wood", Vector3(x + 0.4, 0, -1.6), Vector3(x + 0.2, 1.6, -1.75), 0.04)
		for k in 6:
			_ball("leaf", Vector3(x + 0.2 + _rng.randf_range(-0.2, 0.2), 0.3 + k * 0.22, -1.75 + _rng.randf_range(-0.1, 0.1)), 0.12, 5, 3, Vector3(1, 0.7, 0.6))
	_basket(Vector3(2.4, 0, 0.9), 0.3, 0.26)
	_cabbage(Vector3(2.4, 0.26, 0.9))
	_model(K + "tool-hoe-upgraded.glb", Vector3(2.3, 0, -0.5), Vector3(0, 40, 75), 3.5, null, BRONZE)
	_save("garden_plot")


func _cabbage(p: Vector3) -> void:
	_ball("leaf", p + Vector3(0, 0.12, 0), 0.15, 7, 4, Vector3(1, 0.85, 1))
	for k in 5:
		var a := TAU * k / 5.0 + p.x
		_ball("crop_green", p + Vector3(cos(a) * 0.14, 0.07, sin(a) * 0.14), 0.12, 5, 3, Vector3(1, 0.35, 0.8), Vector3(0, -rad_to_deg(a), 25))


func _scarecrow() -> void:
	_begin("scarecrow")
	_beam("wood", Vector3(0, 0, 0), Vector3(0, 2.0, 0), 0.08)
	_beam("wood", Vector3(-0.8, 1.45, 0), Vector3(0.8, 1.45, 0), 0.07)
	_lathe("linen", Vector3(0, 0.75, 0), [Vector2(0.24, 0), Vector2(0.27, 0.35), Vector2(0.22, 0.7), Vector2(0.0, 0.75)], 7)
	_beam("linen", Vector3(-0.75, 1.45, 0), Vector3(0.75, 1.45, 0), 0.16)
	_rod("rope", Vector3(0, 0.95, 0), Vector3(0, 1.0, 0), 0.26, 7)
	_ball("rope", Vector3(0, 1.82, 0), 0.2, 7, 4, Vector3(1, 1.1, 1))
	_lathe("straw", Vector3(0, 1.93, 0), [Vector2(0.42, 0), Vector2(0.42, 0.04), Vector2(0.2, 0.06), Vector2(0.17, 0.25), Vector2(0.0, 0.27)], 9)
	for sx in [-1.0, 1.0]:
		_blade("straw", Vector3(sx * 0.82, 1.45, 0), 0.25, 0.06, Vector3(sx * 0.15, -0.35, 0))
		_ball("charcoal", Vector3(sx * 0.07, 1.86, 0.18), 0.025, 5, 3)
	_ball("bone", Vector3(0.0, 1.2, 0.26), 0.03, 4, 2)
	_save("scarecrow")


# ================================================================== resource piles and nodes

func _piles() -> void:
	_begin("grain_sacks")
	for p in [Vector3(-0.35, 0, 0.2), Vector3(0.3, 0, 0.25), Vector3(-0.05, 0, -0.35), Vector3(0.55, 0, -0.3)]:
		_sack(p, "rope", _rng.randf_range(0.9, 1.05))
	_save("grain_sacks")
	_begin("flour_sacks")
	for p in [Vector3(-0.3, 0, 0.2), Vector3(0.32, 0, 0.15), Vector3(0.0, 0, -0.35)]:
		_sack(p, "linen", _rng.randf_range(0.9, 1.05))
	_save("flour_sacks")
	_begin("bread_basket")
	_basket(Vector3.ZERO, 0.38, 0.28)
	for i in 5:
		var a := TAU * i / 5.0
		_loaf(Vector3(cos(a) * 0.17, 0.22 + (i % 2) * 0.05, sin(a) * 0.17), 0.85, rad_to_deg(a))
	_loaf(Vector3(0, 0.33, 0), 0.9, 40)
	_save("bread_basket")
	_begin("pots")
	_jar(Vector3(-0.35, 0, 0.1), 1.1, "terracotta", true, true, 15)
	_jar(Vector3(0.3, 0, 0.2), 1.0, "terracotta", true, false, -10)
	_jar(Vector3(0.05, 0, -0.45), 0.8, "terracotta", true, false, 30)
	_bowl(Vector3(0.6, 0, -0.35), 1.0)
	_bowl(Vector3(0.6, 0.12, -0.35), 0.85)
	_save("pots")
	_begin("pots_unfired")
	_box("planks", Vector3(0, 0.04, 0), Vector3(1.4, 0.08, 0.6))
	for i in 4:
		_jar(Vector3(-0.5 + i * 0.33, 0.08, 0), 0.6 + (i % 2) * 0.1, "clay_light", false)
	_save("pots_unfired")
	_begin("clay_pile")
	_clay_heap(Vector3.ZERO, 1.0)
	_save("clay_pile")
	_begin("planks_pile")
	for i in 3:
		_model(K + "resource-planks.glb", Vector3((i % 2) * 0.1, i * 0.3, 0), Vector3(0, 90 + i * 4, 0), 5.0, null, KEN)
	_save("planks_pile")
	_begin("charcoal_pile")
	_charcoal_lumps(Vector3.ZERO, 0.6, 16)
	_sack(Vector3(0.75, 0, 0.3), "rope", 0.9)
	_save("charcoal_pile")
	_begin("ore_pile")
	_ore_heap(Vector3.ZERO, 1.0)
	_save("ore_pile")
	_begin("bronze_ingots")
	_ingots(Vector3.ZERO)
	_save("bronze_ingots")
	_begin("wool_bales")
	_wool_bales(Vector3.ZERO)
	_save("wool_bales")
	_begin("cloth_bolts")
	_box("planks", Vector3(0, 0.05, 0), Vector3(1.2, 0.1, 0.7))
	var cm := ["cloth_red", "cloth_blue", "linen", "cloth_gold", "cloth_green"]
	for i in 5:
		var y: float = 0.2 if i < 3 else 0.42
		var x: float = -0.36 + (i if i < 3 else i - 2.5) * 0.36
		_rod(cm[i], Vector3(x, y, 0.32), Vector3(x, y, -0.32), 0.15, 8)
	_save("cloth_bolts")
	_begin("barrels")
	_model(K + "barrel.glb", Vector3(-0.35, 0, 0), Vector3.ZERO, 3.2, null, KEN)
	_model(K + "barrel.glb", Vector3(0.35, 0, 0.1), Vector3(0, 40, 0), 3.2, null, KEN)
	_model(K + "barrel-open.glb", Vector3(0.0, 0, -0.55), Vector3.ZERO, 3.0, null, KEN)
	_save("barrels")
	_begin("water_trough")
	_trough(Vector3.ZERO, 0)
	_save("water_trough")


func _charcoal_lumps(c: Vector3, r: float, n: int) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		var y := (1.0 - d / r) * r * 0.5
		_ball("charcoal", c + Vector3(cos(a) * d, y, sin(a) * d), _rng.randf_range(0.09, 0.15), 5, 3, Vector3(1, 0.7, 1), Vector3(0, _rng.randf() * 90, _rng.randf() * 40))


func _ore_heap(c: Vector3, s: float) -> void:
	for i in 12:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * 0.6 * s
		var y := (1.0 - d / (0.6 * s)) * 0.3 * s
		_ball("verdigris" if i % 3 == 0 else "stone_dark", c + Vector3(cos(a) * d, y, sin(a) * d), _rng.randf_range(0.12, 0.2) * s, 4, 2,
			Vector3(1, 0.8, 1), Vector3(_rng.randf() * 40, _rng.randf() * 90, 0))
	for i in 4:
		var a := _rng.randf() * TAU
		_ball("bronze", c + Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3) * s, 0.1 * s, 4, 2)


func _ingots(c: Vector3) -> void:
	_box("planks", c + Vector3(0, 0.06, 0), Vector3(0.9, 0.12, 0.6))
	for layer in 3:
		for i in 3 - layer:
			var rot := 90.0 if layer % 2 == 1 else 0.0
			var off := Vector3((i - (2 - layer) * 0.5) * 0.26, 0.17 + layer * 0.1, 0)
			if layer % 2 == 1:
				off = Vector3(0, off.y, (i - 0.5) * 0.26)
			_box("bronze", c + off, Vector3(0.22, 0.09, 0.5), Vector3(0, rot, 0))


func _wool_bales(c: Vector3) -> void:
	for p in [Vector3(-0.35, 0, 0), Vector3(0.35, 0, 0.05), Vector3(0.0, 0.5, 0.02)]:
		_ball("wool", c + p + Vector3(0, 0.28, 0), 0.36, 8, 4, Vector3(1, 0.75, 0.85))
		_rod("rope", c + p + Vector3(-0.02, 0.0, 0.32), c + p + Vector3(0.02, 0.56, 0.3), 0.025, 4)


func _nodes() -> void:
	# Gather nodes on the East Bank and in the hills (DESIGN 10.1).
	_begin("clay_pit")
	_lathe("dirt", Vector3.ZERO, [Vector2(2.2, 0), Vector2(1.9, 0.35), Vector2(1.55, 0.3), Vector2(1.3, 0.05), Vector2(0.0, 0.05)], 12)
	_lathe("clay", Vector3(0, 0.06, 0), [Vector2(1.3, 0), Vector2(0, 0)], 12)
	_lathe("water", Vector3(-0.3, 0.075, 0.2), [Vector2(0.65, 0), Vector2(0, 0)], 10, Vector3.ZERO, Vector3(1, 1, 0.7))
	_clay_heap(Vector3(0.7, 0.03, -0.4), 0.7)
	_clay_heap(Vector3(2.4, 0, 1.1), 0.8)
	_model(K + "tool-shovel.glb", Vector3(0.9, 0.05, 0.6), Vector3(0, 20, -12), 3.5, null, KEN)
	_box("planks", Vector3(-1.4, 0.3, -1.0), Vector3(1.6, 0.06, 0.4), Vector3(0, 30, -8))
	_save("clay_pit")
	_begin("copper_ore")
	var tint := {"hog_pull": 0.15, "hog_tint": Color("#a08470")}
	_model(N + "Rock_3.fbx", Vector3(0, 0.1, 0), Vector3(0, 40, 0), 1.6, null, tint)
	_model(N + "Rock_5.fbx", Vector3(0.9, 0.0, 0.4), Vector3(0, 130, 0), 0.9, null, tint)
	_model(N + "Rock_2.fbx", Vector3(-0.9, 0.0, 0.6), Vector3(0, 10, 0), 0.8, null, tint)
	for i in 9:   # green copper bloom and a few bright nuggets on the faces
		var a := TAU * i / 9.0 + 0.3
		var r := 0.7 + (i % 3) * 0.12
		_ball("verdigris" if i % 3 != 0 else "bronze", Vector3(cos(a) * r, 0.25 + (i % 4) * 0.22, sin(a) * r), 0.13, 4, 2,
			Vector3(1, 0.7, 1), Vector3(_rng.randf() * 50, _rng.randf() * 90, 0))
	_ore_heap(Vector3(1.0, 0, 1.2), 0.6)
	_save("copper_ore")
	_begin("rockfall")
	var rocks := [["Rock_6.fbx", Vector3(-3.0, 0, 0.2), 20.0, Vector3(2.6, 2.4, 2.4)], ["Rock_4.fbx", Vector3(0.0, 0.2, -0.4), 75.0, Vector3(2.4, 3.4, 2.2)],
		["Rock_7.fbx", Vector3(2.8, 0.1, 0.1), 130.0, Vector3(2.6, 2.6, 2.4)], ["Rock_3.fbx", Vector3(-1.4, 0, 1.6), 40.0, Vector3(1.4, 1.2, 1.4)],
		["Rock_5.fbx", Vector3(1.5, 0, 1.7), 10.0, Vector3(1.3, 1.1, 1.2)], ["Rock_2.fbx", Vector3(4.2, 0, 1.4), 80.0, Vector3(1.0, 0.8, 1.0)],
		["Rock_2.fbx", Vector3(-4.3, 0, 1.3), 160.0, Vector3(0.9, 0.7, 0.9)], ["Rock_1.fbx", Vector3(0.8, 2.6, -0.3), 200.0, Vector3(1.1, 1.0, 1.0)]]
	for r in rocks:
		_model(N + r[0], r[1], Vector3(0, r[2], 0), r[3])
	_save("rockfall")


# ================================================================== fences, carts, tools, animals

func _fences() -> void:
	_begin("fence_wattle")
	_hurdle(Vector3.ZERO, 0)
	_save("fence_wattle")
	_begin("fence_wattle_gate")
	_gate(Vector3.ZERO, 0, 0)
	_save("fence_wattle_gate")


func _carts() -> void:
	for v in 2:
		var nm := "handcart" if v == 0 else "handcart_loaded"
		_begin(nm)
		_box("planks", Vector3(0, 0.75, -0.1), Vector3(1.1, 0.08, 1.5))
		for sx in [-1.0, 1.0]:
			_box("planks", Vector3(sx * 0.53, 0.92, -0.1), Vector3(0.06, 0.3, 1.5))
			_beam("timber", Vector3(sx * 0.4, 0.68, 0.6), Vector3(sx * 0.32, 0.72, 1.7), 0.07)
			_beam("timber", Vector3(sx * 0.4, 0.68, -0.85), Vector3(sx * 0.4, 0.68, 0.6), 0.08)
		_box("planks", Vector3(0, 0.92, -0.85), Vector3(1.1, 0.3, 0.06))
		_rod("wood_dark", Vector3(-0.32, 0.72, 1.7), Vector3(0.32, 0.72, 1.7), 0.04, 5)
		_beam("wood_dark", Vector3(0, 0, 1.0), Vector3(0, 0.66, 1.4), 0.05)   # prop leg
		_beam("wood_dark", Vector3(-0.75, 0.42, -0.25), Vector3(0.75, 0.42, -0.25), 0.07)
		for sx in [-1.0, 1.0]:
			_wheel(Vector3(sx * 0.68, 0.42, -0.25), 0.42)
		if v == 1:
			_sack(Vector3(-0.25, 0.79, -0.4), "rope", 0.8, 70)
			_sack(Vector3(0.25, 0.79, -0.35), "linen", 0.8, -70)
			_jar(Vector3(0.0, 0.79, 0.3), 0.7, "terracotta", true, false, 0)
		_save(nm)
	_begin("hay_wagon")
	_model(V + "Prop_Wagon.gltf", Vector3(0, 0, 1.15), Vector3.ZERO, 1.0, null, MK)
	_lathe("thatch", Vector3(0, 0.95, -0.3 + 0.0), [Vector2(1.1, 0), Vector2(1.2, 0.4), Vector2(0.9, 0.95), Vector2(0.0, 1.15)], 8,
		Vector3.ZERO, Vector3(0.85, 1, 1.45), PI / 8.0, true, 0.8)
	_save("hay_wagon")


func _wheel(c: Vector3, r: float) -> void:
	_push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), c))
	_lathe("wood", Vector3(0, -0.05, 0), [Vector2(r, 0), Vector2(r, 0.1), Vector2(r - 0.07, 0.1), Vector2(r - 0.07, 0.0)], 12)
	_cyl("wood_dark", Vector3(0, -0.08, 0), 0.09, 0.09, 0.16, 7)
	for k in 6:
		var a := TAU * k / 6.0
		_beam("wood", Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * (r - 0.05), 0.04)
	_pop()


## A flat plate in the local XY plane (z = z0), `thick` deep: axe and hoe blades, spades.
## pts: Vector2 outline, star-shaped round its centroid.
func _plate(m: String, pts: Array, z0: float, thick: float) -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var hf := thick * 0.5
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		_tri(m, Vector3(c.x, c.y, z0 + hf), Vector3(a.x, a.y, z0 + hf), Vector3(b.x, b.y, z0 + hf), Vector3.BACK)
		_tri(m, Vector3(c.x, c.y, z0 - hf), Vector3(a.x, a.y, z0 - hf), Vector3(b.x, b.y, z0 - hf), Vector3.FORWARD)
		var e := b - a
		var out := Vector3(e.y, -e.x, 0)
		var mid := (a + b) * 0.5 - c
		if out.dot(Vector3(mid.x, mid.y, 0)) < 0.0:
			out = -out
		_quad(m, Vector3(a.x, a.y, z0 + hf), Vector3(b.x, b.y, z0 + hf), Vector3(b.x, b.y, z0 - hf), Vector3(a.x, a.y, z0 - hf), out)


## Hand tools, built so they read at game distance: ash handles, cast bronze heads,
## leather grips. Each stands upright on its butt (origin), head at the top.
func _tools() -> void:
	# axe: flared bronze blade through a socket
	_begin("tool_axe_bronze")
	_rod("wood", Vector3.ZERO, Vector3(0, 0.78, 0), 0.018, 6, 0.016)
	_cyl("leather", Vector3(0, 0.04, 0), 0.022, 0.022, 0.13, 6)
	_cyl("bronze", Vector3(0, 0.62, 0), 0.03, 0.028, 0.11, 7)
	_plate("bronze", [Vector2(0.02, 0.63), Vector2(0.09, 0.61), Vector2(0.19, 0.55), Vector2(0.215, 0.665),
		Vector2(0.19, 0.78), Vector2(0.09, 0.72), Vector2(0.02, 0.715)], 0.0, 0.026)
	_plate("bronze", [Vector2(-0.02, 0.64), Vector2(-0.06, 0.65), Vector2(-0.06, 0.70), Vector2(-0.02, 0.71)], 0.0, 0.04)
	_save("tool_axe_bronze")
	# pickaxe: curved bronze head, points both ways
	_begin("tool_pickaxe_bronze")
	_rod("wood", Vector3.ZERO, Vector3(0, 0.82, 0), 0.019, 6, 0.017)
	_cyl("leather", Vector3(0, 0.04, 0), 0.023, 0.023, 0.13, 6)
	var arc := [Vector3(-0.3, 0.7, 0), Vector3(-0.16, 0.77, 0), Vector3(0, 0.8, 0), Vector3(0.16, 0.77, 0), Vector3(0.3, 0.7, 0)]
	var wid := [0.012, 0.035, 0.05, 0.035, 0.012]
	for i in 4:
		var w0: float = wid[i]
		var w1: float = wid[i + 1]
		_rod("bronze", arc[i], arc[i + 1], w0 * 0.75, 6, w1 * 0.75)
	_cyl("bronze", Vector3(0, 0.74, 0), 0.032, 0.03, 0.1, 7)
	_save("tool_pickaxe_bronze")
	# hoe: long handle, blade bent forward and down
	_begin("tool_hoe")
	_rod("wood", Vector3.ZERO, Vector3(0, 1.22, 0), 0.018, 6, 0.016)
	_cyl("bronze", Vector3(0, 1.16, 0), 0.026, 0.026, 0.07, 7)
	_beam("bronze", Vector3(0, 1.2, 0), Vector3(0, 1.21, 0.1), 0.035, 0.02)
	_plate("bronze", [Vector2(-0.085, 1.05), Vector2(0.085, 1.05), Vector2(0.07, 1.215), Vector2(-0.07, 1.215)], 0.11, 0.014)
	_save("tool_hoe")
	# spade: wooden blade shod with a bronze edge, T grip
	_begin("tool_shovel")
	_plate("wood", [Vector2(-0.1, 0.3), Vector2(-0.11, 0.14), Vector2(0.11, 0.14), Vector2(0.1, 0.3)], 0.0, 0.03)
	_plate("bronze", [Vector2(-0.112, 0.15), Vector2(-0.1, 0.06), Vector2(-0.05, 0.015), Vector2(0.0, 0.0),
		Vector2(0.05, 0.015), Vector2(0.1, 0.06), Vector2(0.112, 0.15)], 0.0, 0.022)
	_rod("wood", Vector3(0, 0.28, 0), Vector3(0, 1.05, 0), 0.019, 6, 0.017)
	_beam("wood_dark", Vector3(-0.07, 1.06, 0), Vector3(0.07, 1.06, 0), 0.035)
	_save("tool_shovel")
	# hammer: bronze head, leather-wrapped grip
	_begin("tool_hammer")
	_rod("wood", Vector3.ZERO, Vector3(0, 0.42, 0), 0.016, 6, 0.014)
	_cyl("leather", Vector3(0, 0.03, 0), 0.02, 0.02, 0.12, 6)
	_beam("bronze", Vector3(-0.075, 0.42, 0), Vector3(0.085, 0.42, 0), 0.05, 0.05)
	_beam("bronze", Vector3(0.085, 0.42, 0), Vector3(0.1, 0.42, 0), 0.058, 0.058)
	_save("tool_hammer")
	# sickle: short grip, crescent bronze blade
	_begin("tool_sickle")
	_rod("wood", Vector3.ZERO, Vector3(0, 0.15, 0), 0.02, 6, 0.018)
	_cyl("bronze", Vector3(0, 0.14, 0), 0.022, 0.02, 0.03, 6)
	var prev := Vector3(0, 0.16, 0)
	for k in 9:
		var a := PI * 0.9 * (k + 1) / 9.0
		var p := Vector3(0.16 - cos(a) * 0.16, 0.16 + sin(a) * 0.2, 0)
		_beam("bronze", prev, p, 0.006, 0.05 - k * 0.0045)
		prev = p
	_save("tool_sickle")
	# pitchfork: wooden hay fork
	_begin("tool_pitchfork")
	_rod("wood", Vector3.ZERO, Vector3(0, 1.5, 0), 0.02, 6, 0.018)
	_beam("wood_dark", Vector3(-0.13, 1.5, 0), Vector3(0.13, 1.5, 0), 0.045)
	for x in [-0.12, 0.0, 0.12]:
		_rod("wood_dark", Vector3(x, 1.5, 0), Vector3(x * 1.15, 1.86, 0.04), 0.017, 5, 0.007)
	_save("tool_pitchfork")


func _animals() -> void:
	for spec in [["cow", AN + "Cow.fbx", 0.22], ["pig", AN + "Pig.fbx", 0.16]]:
		_begin(spec[0])
		_root.set_script(ANIMAL)
		var m := _model(spec[1], Vector3.ZERO, Vector3.ZERO, spec[2])
		m.name = "Model"
		_save(spec[0])
