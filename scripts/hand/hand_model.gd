class_name HandModel extends Node3D
## The hand's body: the white cartoon glove (assets/models/hand/cartoon_glove,
## modelled for Hands of God on the CC0 godot-xr-tools hand by Miodrag Sejic:
## 26-joint OpenXR skeleton, rolled cuff, three stitches), with the fingers puffed
## a little more, a dark cap closing the hollow cuff, a soft matte cloth shader
## with an era-coloured rim, a ghostly glowing state, and an ink outline. Swappable: HandVisual only uses the API below, so another
## rigged hand scene with the same functions can replace scenes/hand/hand_model.tscn.
##
## Space: this node is in "hand units": the wrist at the origin, the middle
## fingertip ~1.0 along -Z, the back of the hand +Y, the thumb toward -X (a right
## hand, palm down). HandVisual scales and places it.
##
## API
##   set_pose(curl, cup, point, spread)  curl: 5 floats thumb..little, -1 straight, 0 relaxed, 1 fist;
##                                        cup 0..1 (scoop/hold), point 0..1, spread -1..2
##   set_look(solidity, opacity, glow, glow_color)  solidity 0 ghost .. 1 solid
##   anchor_local(hold) -> Vector3        the cursor point: the fingertips (hold 0)
##                                        or the cupped palm people hang from (hold 1)

const MODEL := preload("res://assets/models/hand/cartoon_glove/cartoon_glove_R.glb")
const ANIM_DIR := "res://assets/models/hand/xr_hand/animations/"
const GLOVE := preload("res://assets/textures/shaders/hand_glove.gdshader")
const GHOST := preload("res://assets/textures/shaders/hand_glove_ghost.gdshader")
const DEPTH := preload("res://assets/textures/shaders/hand_depth.gdshader")
const OUTLINE := preload("res://assets/textures/shaders/hand_outline.gdshader")
const FINGER_BONES := [
	["Thumb_Metacarpal_R", "Thumb_Proximal_R", "Thumb_Distal_R"],
	["Index_Metacarpal_R", "Index_Proximal_R", "Index_Intermediate_R", "Index_Distal_R"],
	["Middle_Metacarpal_R", "Middle_Proximal_R", "Middle_Intermediate_R", "Middle_Distal_R"],
	["Ring_Metacarpal_R", "Ring_Proximal_R", "Ring_Intermediate_R", "Ring_Distal_R"],
	["Little_Metacarpal_R", "Little_Proximal_R", "Little_Intermediate_R", "Little_Distal_R"],
]
const SPREAD_K := [0.5, 1.0, 0.3, -0.45, -1.0]
## How much the glove is puffed out along its normals, in skeleton metres.
const PUFF_PALM := 0.0
const PUFF_FINGER := 0.0012
const SUBDIV := 0
static var _glove_cache: ArrayMesh = null

var rig: Node3D
var skeleton: Skeleton3D
var glove: MeshInstance3D
var cuff: MeshInstance3D           # the cap closing the cuff
var mat_stitch: StandardMaterial3D
var mat_solid: ShaderMaterial
var mat_ghost: ShaderMaterial
var mat_depth: ShaderMaterial
var mat_outline: ShaderMaterial
var to_skel: Transform3D          # hand units -> skeleton space
var hand_len: float = 0.2         # wrist to middle tip, skeleton metres
var cap_radius: float = 0.0       # fitted radius of the cuff cap (skeleton metres)
var solid: bool = true

var _poses: Dictionary = {}       # name -> {bone: Quaternion}
var _chains: Array = []           # per finger: Array[int] bone ids
var _parent_rest: Dictionary = {} # bone -> parent global rest rotation
var _anchor_open := Vector3(0, 0, -1)
var _anchor_cup := Vector3(0, -0.2, -0.55)
var _built := false

func _ready() -> void:
	build()

func build() -> void:
	if _built:
		return
	_built = true
	var inst: Node3D = MODEL.instantiate()
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	glove = inst.find_children("*", "MeshInstance3D", true, false)[0]
	# orientation: the model's fingers run -Z, thumb +Y, back of the hand +X
	var wrist := skeleton.get_bone_global_rest(skeleton.find_bone("Wrist_R")).origin
	var mid_tip := skeleton.get_bone_global_rest(skeleton.find_bone("Middle_Tip_R")).origin
	hand_len = wrist.distance_to(mid_tip)
	var b := Basis(Vector3.BACK, PI / 2).scaled(Vector3.ONE / hand_len)
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	rig.transform = Transform3D(b, -(b * wrist))
	rig.add_child(inst)
	to_skel = rig.transform.affine_inverse()
	for chain in FINGER_BONES:
		var ids: Array = []
		for n in chain:
			ids.append(skeleton.find_bone(n))
		_chains.append(ids)
	for ids in _chains:
		var bi: int = ids[1]
		var par := skeleton.get_bone_parent(bi)
		_parent_rest[bi] = skeleton.get_bone_global_rest(par).basis.get_rotation_quaternion()
	for n in ["Default pose", "Cup", "Grip", "Sign_Point", "Straight"]:
		_poses[n] = _load_pose(ANIM_DIR + n + ".res")
	_rebuild_glove()
	_build_cap()
	_build_materials()
	var it := rig.transform
	var tip_i := skeleton.get_bone_global_rest(skeleton.find_bone("Index_Tip_R")).origin
	var tip_m := mid_tip
	_anchor_open = it * ((tip_i + tip_m) * 0.5) + Vector3(0, -0.06, 0.02)
	var palm := skeleton.get_bone_global_rest(skeleton.find_bone("Palm_R")).origin
	_anchor_cup = it * palm + Vector3(0.02, -0.22, -0.22)
	set_pose(PackedFloat32Array([0.1, 0.1, 0.1, 0.1, 0.1]), 0.0, 0.0, 0.5)

func anchor_local(hold: float) -> Vector3:
	return _anchor_open.lerp(_anchor_cup, clampf(hold, 0.0, 1.0))

# ---------------------------------------------------------------- pose

func _load_pose(path: String) -> Dictionary:
	var out := {}
	var a: Animation = load(path)
	if a == null:
		return out
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bi := skeleton.find_bone(String(a.track_get_path(t).get_concatenated_subnames()))
		if bi >= 0:
			out[bi] = a.rotation_track_interpolate(t, 0.0)
	return out

func _q(pose: String, bi: int) -> Quaternion:
	var p: Dictionary = _poses.get(pose, {})
	return p.get(bi, skeleton.get_bone_rest(bi).basis.get_rotation_quaternion())

func set_pose(curl: PackedFloat32Array, cup: float, point: float, spread: float) -> void:
	if skeleton == null:
		return
	for f in 5:
		var raw: float = curl[f] if f < curl.size() else 0.0
		var c := clampf(raw, 0.0, 1.0)
		var ids: Array = _chains[f]
		for k in ids.size():
			var bi: int = ids[k]
			var q := _q("Default pose", bi)
			if cup > 0.0:
				q = q.slerp(_q("Cup", bi), clampf(cup, 0.0, 1.0))
			if point > 0.0:
				q = q.slerp(_q("Sign_Point", bi), clampf(point, 0.0, 1.0))
			if raw < 0.0:
				q = q.slerp(_q("Straight", bi), clampf(-raw, 0.0, 1.0))
			if c > 0.0:
				q = q.slerp(_q("Grip", bi), c)
			if k == 1 and spread != 0.0:
				# fan the fingers about the palm normal (skeleton X)
				var pr: Quaternion = _parent_rest[bi]
				var rot := Quaternion(Vector3.RIGHT, 0.11 * spread * float(SPREAD_K[f]) * (1.0 - c))
				q = pr.inverse() * rot * pr * q
			skeleton.set_bone_pose_rotation(bi, q)

# ---------------------------------------------------------------- look

func set_look(solidity: float, opacity: float, glow: float, glow_color: Color) -> void:
	var want_solid := solidity >= 0.985 and opacity >= 0.985
	if want_solid != solid:
		solid = want_solid
		var m: Material = mat_solid if solid else mat_depth
		glove.set_surface_override_material(0, m)
		cuff.material_override = m
	for m in [mat_solid, mat_ghost]:
		(m as ShaderMaterial).set_shader_parameter(&"glow_color", glow_color)
		(m as ShaderMaterial).set_shader_parameter(&"glow_strength", glow)
	mat_ghost.set_shader_parameter(&"solidity", solidity)
	mat_ghost.set_shader_parameter(&"opacity", opacity)
	mat_outline.set_shader_parameter(&"opacity", clampf(opacity * lerpf(0.25, 1.0, solidity), 0.0, 1.0))
	mat_stitch.albedo_color.a = clampf(opacity * lerpf(0.3, 1.0, solidity), 0.0, 1.0)

func _build_materials() -> void:
	mat_outline = ShaderMaterial.new()
	mat_outline.shader = OUTLINE
	mat_solid = ShaderMaterial.new()
	mat_solid.shader = GLOVE
	mat_solid.next_pass = mat_outline
	mat_ghost = ShaderMaterial.new()
	mat_ghost.shader = GHOST
	mat_ghost.next_pass = mat_outline
	mat_depth = ShaderMaterial.new()
	mat_depth.shader = DEPTH
	mat_depth.next_pass = mat_ghost
	# depth first, then the ghost colour, then the ink line
	mat_depth.render_priority = -2
	mat_ghost.render_priority = -1
	mat_stitch = StandardMaterial3D.new()
	mat_stitch.albedo_color = Color(0.12, 0.1, 0.1, 1.0)
	mat_stitch.roughness = 0.9
	mat_stitch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_stitch.render_priority = 1
	solid = false
	glove.set_surface_override_material(0, mat_depth)
	if glove.mesh.get_surface_count() > 1:
		glove.set_surface_override_material(1, mat_stitch)
	cuff.material_override = mat_depth
	for mi in [glove, cuff]:
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------------------------------------------------------- mesh

## Smooth (welded) normals, puffier fingers, the stitch mask and rest coordinates.
func _rebuild_glove() -> void:
	if _glove_cache != null:
		glove.mesh = _glove_cache
		return
	var src: ArrayMesh = glove.mesh
	var arr := src.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / maxi(v.size(), 1)
	# weld by position (the glove needs no UVs), keeping the top 4 bone weights
	var pos := PackedVector3Array()
	var bw: Array = []                 # per vertex: Dictionary bone -> weight
	var remap := PackedInt32Array()
	remap.resize(v.size())
	var groups := {}
	for i in v.size():
		var k := Vector3i(roundi(v[i].x * 1e5), roundi(v[i].y * 1e5), roundi(v[i].z * 1e5))
		if not groups.has(k):
			groups[k] = pos.size()
			pos.append(v[i])
			var d := {}
			for j in per:
				var w := weights[i * per + j]
				if w > 0.0:
					d[bones[i * per + j]] = d.get(bones[i * per + j], 0.0) + w
			bw.append(d)
		remap[i] = groups[k]
	var tris := PackedInt32Array()
	tris.resize(idx.size())
	for t in idx.size():
		tris[t] = remap[idx[t]]
	var src_n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var nrm := _normals(pos, tris)
	var agree := 0.0
	for i in mini(v.size(), 400):
		agree += nrm[remap[i]].dot(src_n[i])
	var sgn := 1.0 if agree >= 0.0 else -1.0
	for i in nrm.size():
		nrm[i] *= sgn
	# puff: fingers more than the palm
	var finger_bones := {}
	for ids in _chains:
		for k in range(1, ids.size()):
			finger_bones[ids[k]] = true
	for n in ["Thumb_Tip_R", "Index_Tip_R", "Middle_Tip_R", "Ring_Tip_R", "Little_Tip_R"]:
		finger_bones[skeleton.find_bone(n)] = true
	# mesh bone indices are skin binds: map them to skeleton bones
	var skin := glove.skin
	var bind_bone := {}
	if skin != null:
		for i in skin.get_bind_count():
			var bb := skin.get_bind_bone(i)
			bind_bone[i] = bb if bb >= 0 else skeleton.find_bone(skin.get_bind_name(i))
	var fing := PackedFloat32Array()
	fing.resize(pos.size())
	for i in pos.size():
		var f := 0.0
		for b in bw[i]:
			if finger_bones.has(bind_bone.get(b, b)):
				f += float(bw[i][b])
		fing[i] = clampf(f, 0.0, 1.0)
		pos[i] += nrm[i] * lerpf(PUFF_PALM, PUFF_FINGER, fing[i])
	# rest coordinates (before puffing) for the stitches: keep the original y, z
	var rest := PackedVector3Array(pos)
	for i in rest.size():
		rest[i] -= nrm[i] * lerpf(PUFF_PALM, PUFF_FINGER, fing[i])
	# two levels of curved (PN-triangle) subdivision: round silhouettes
	for level in SUBDIV:
		var edge := {}
		var nt := PackedInt32Array()
		for t in range(0, tris.size(), 3):
			var a := tris[t]
			var b := tris[t + 1]
			var c := tris[t + 2]
			var ab := _mid(a, b, edge, pos, nrm, bw, fing, rest)
			var bc := _mid(b, c, edge, pos, nrm, bw, fing, rest)
			var ca := _mid(c, a, edge, pos, nrm, bw, fing, rest)
			nt.append_array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca])
		tris = nt
		var gn := _normals(pos, tris)
		for i in nrm.size():
			nrm[i] = (gn[i] * sgn).normalized()
	var bo := PackedInt32Array()
	var wo := PackedFloat32Array()
	var col := PackedColorArray()
	var uv2 := PackedVector2Array()
	for i in pos.size():
		var d: Dictionary = bw[i]
		var keys: Array = d.keys()
		keys.sort_custom(func(x, y): return float(d[x]) > float(d[y]))
		var tot := 0.0
		for j in mini(4, keys.size()):
			tot += float(d[keys[j]])
		for j in 4:
			if j < keys.size():
				bo.append(int(keys[j]))
				wo.append(float(d[keys[j]]) / maxf(tot, 1e-6))
			else:
				bo.append(0)
				wo.append(0.0)
		var r := rest[i]
		var region := smoothstep(-0.075, -0.06, r.z) * (1.0 - smoothstep(0.0, 0.012, r.z))
		var back := 0.0 * region     # the glove model has its own stitches
		col.append(Color(back, 0.0, fing[i], 1.0))
		uv2.append(Vector2(r.y, r.z))
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pos
	out[Mesh.ARRAY_NORMAL] = nrm
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_TEX_UV2] = uv2
	out[Mesh.ARRAY_BONES] = bo
	out[Mesh.ARRAY_WEIGHTS] = wo
	out[Mesh.ARRAY_INDEX] = tris
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	for si in range(1, src.get_surface_count()):     # the stitches, untouched
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(si), [], {},
				src.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	_glove_cache = m
	glove.mesh = m

static func _normals(pos: PackedVector3Array, tris: PackedInt32Array) -> PackedVector3Array:
	var acc := PackedVector3Array()
	acc.resize(pos.size())
	for t in range(0, tris.size(), 3):
		var a := pos[tris[t]]
		var fn := (pos[tris[t + 1]] - a).cross(pos[tris[t + 2]] - a)
		acc[tris[t]] += fn
		acc[tris[t + 1]] += fn
		acc[tris[t + 2]] += fn
	for i in acc.size():
		acc[i] = acc[i].normalized()
	return acc

## The midpoint of edge a-b on the PN-triangle cubic through both vertices'
## tangent planes, with blended normal, weights and rest position.
static func _mid(a: int, b: int, edge: Dictionary, pos: PackedVector3Array, nrm: PackedVector3Array,
		bw: Array, fing: PackedFloat32Array, rest: PackedVector3Array) -> int:
	var key := mini(a, b) * 1048576 + maxi(a, b)
	if edge.has(key):
		return edge[key]
	var p0 := pos[a]
	var p1 := pos[b]
	var n0 := nrm[a]
	var n1 := nrm[b]
	var c01 := (2.0 * p0 + p1 - (p1 - p0).dot(n0) * n0) / 3.0
	var c10 := (2.0 * p1 + p0 - (p0 - p1).dot(n1) * n1) / 3.0
	var m := (p0 + 3.0 * c01 + 3.0 * c10 + p1) / 8.0
	var i := pos.size()
	pos.append(m)
	nrm.append((n0 + n1).normalized())
	var d := {}
	for k in bw[a]:
		d[k] = float(bw[a][k]) * 0.5
	for k in bw[b]:
		d[k] = float(d.get(k, 0.0)) + float(bw[b][k]) * 0.5
	bw.append(d)
	fing.append((fing[a] + fing[b]) * 0.5)
	rest.append((rest[a] + rest[b]) * 0.5)
	edge[key] = i
	return i

## A dark, slightly dished cap just inside the cuff's opening, so the hollow
## sleeve can never be seen into from any angle. Fitted to the opening's own
## shape (the innermost lip vertices per angle).
func _build_cap() -> void:
	var v: PackedVector3Array = glove.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var zmax := -INF
	for p in v:
		zmax = maxf(zmax, p.z)
	var c := Vector2.ZERO
	var n := 0
	for p in v:
		if p.z > zmax - 0.008:
			c += Vector2(p.x, p.y)
			n += 1
	c /= float(maxi(n, 1))
	const BINS := 36
	var rin := PackedFloat32Array()
	rin.resize(BINS)
	rin.fill(INF)
	for p in v:
		if p.z > zmax - 0.008:
			var d := Vector2(p.x, p.y) - c
			var bi := posmod(int(floor((d.angle() + PI) / TAU * BINS)), BINS)
			rin[bi] = minf(rin[bi], d.length())
	var avg := 0.0
	var cnt := 0
	for r in rin:
		if r < INF:
			avg += r
			cnt += 1
	avg = avg / float(maxi(cnt, 1)) if cnt > 0 else 0.03
	for i in BINS:
		if rin[i] == INF:
			rin[i] = avg
	cap_radius = avg
	var z := zmax - 0.0035
	var verts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var cols := PackedColorArray()
	verts.append(Vector3(c.x, c.y, z - 0.004))
	nrm.append(Vector3(0, 0, 1))
	cols.append(Color(0, 1, 0, 1))
	const RINGS := 4
	for k in RINGS:
		var t := float(k + 1) / float(RINGS)
		for i in BINS:
			var ang := (float(i) + 0.5) / float(BINS) * TAU - PI
			var r := rin[i] * 1.06 * t
			verts.append(Vector3(c.x + cos(ang) * r, c.y + sin(ang) * r, z - 0.004 * (1.0 - t * t)))
			nrm.append(Vector3(0, 0, 1))
			cols.append(Color(0, 1, 0, 1))
	var ind := PackedInt32Array()
	for i in BINS:
		ind.append_array([0, 1 + (i + 1) % BINS, 1 + i])
	for k in RINGS - 1:
		var a0 := 1 + k * BINS
		var b0 := a0 + BINS
		for i in BINS:
			var i1 := (i + 1) % BINS
			ind.append_array([a0 + i, a0 + i1, b0 + i, a0 + i1, b0 + i1, b0 + i])
	# Godot front faces wind clockwise as seen from the front (+Z, the camera side)
	var f0 := verts[ind[0]]
	var cr := (verts[ind[1]] - f0).cross(verts[ind[2]] - f0)
	if cr.z > 0.0:
		for t in range(0, ind.size(), 3):
			var tmp := ind[t + 1]
			ind[t + 1] = ind[t + 2]
			ind[t + 2] = tmp
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = ind
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	cuff = MeshInstance3D.new()
	cuff.name = "CuffCap"
	cuff.mesh = m
	skeleton.add_child(cuff)
