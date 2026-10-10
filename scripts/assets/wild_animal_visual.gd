class_name WildAnimalVisual
extends Node3D
## The wild animals: wolf (Quaternius, CC0), deer (a rigged low-poly stag, CC0) and bear
## (a low-poly bear mesh, CC0, rigged here in code). Each is shaded in the house style
## (flat palette shader, a lighter belly and muzzle from vertex colours) and moved by
## QuadrupedGait: walk and gallop cycles timed to the ground they really cover, the
## attack lunge, flight, grazing, struggling in the hand and lying dead.
## Scenes: res://scenes/props/{wolf,deer,bear}.tscn (catalog ids wolf, deer, bear).
##
## API (the owner moves the node; the visual watches its own motion):
##   play(state)  &"auto" (default: idle / walk / run by speed), &"idle", &"walk",
##                &"run" (force a gait), &"flee" (gallop, head low, tail tucked, while
##                moving), &"attack" (one lunge, then back to auto), &"graze", &"held"
##                (legs paddle), &"dead"
##   set_eyes(on) a wolf's eyes shine (at night)
##   current_gait() -> StringName   idle, walk or run, as shown now
## Faces +Z, origin on the ground under the body's middle.

const SPECIES := {
	&"wolf": {
		"path": "res://assets/models/animals/wild/Wolf_Q.glb", "fwd": Vector3(1, 0, 0), "height": 0.98,
		# [polish] a cool blue-grey, kept out of the era palette pull: Era 1's warm
		# grade turned the old warm grey tan (Austin: "the wolf looks tan")
		"colour": "#59606a", "light": "#cfd3d8", "dark": "#2b2f36", "pull": 0.0,
		"root": "Bone", "spine": ["Bone", "Bone.001"], "neck": ["Bone.002", "Bone.003"], "head": "Bone.003",
		"tail": ["Bone.004", "Bone.005", "Bone.006", "Bone.007"],
		"legs": [["Bone.017", "Bone.018", "Bone.019", true, true], ["Bone.014", "Bone.015", "Bone.016", true, false],
			["Bone.008", "Bone.009", "Bone.010", false, true], ["Bone.011", "Bone.012", "Bone.013", false, false]],
		"stride_walk": 1.15, "stride_run": 2.4, "walk_max": 2.4, "swing": [24.0, 44.0], "knee": [34.0, 62.0],
		"eyes": true, "graze": false,
	},
	&"deer": {
		"path": "res://assets/models/animals/wild/Deer.glb", "fwd": Vector3(1, 0, 0), "height": 1.75,
		"colour": "#9b6a3f", "light": "#e2cfac", "dark": "#6e4a2c",
		"surfaces": {"horn": "#d9c9a6", "hoav": "#3b302a", "hoov": "#3b302a", "hoof": "#3b302a"},
		"root": "Back Spine", "spine": ["Back Spine", "front Spine"],
		"neck": ["Neck Base", "Neck Mid-Bottom", "Neck Mid-Top", "Neck Top", "Head"], "head": "Head", "tail": [],
		"legs": [["Front Thigh.L", "Front Sheen.L", "", true, true], ["Front Thigh.R", "Front Sheen.R", "", true, false],
			["Back Thigh.L", "Back Sheen.L", "", false, true], ["Back Thigh.R", "Back Sheen.R", "", false, false]],
		"stride_walk": 1.3, "stride_run": 3.2, "walk_max": 2.6, "swing": [20.0, 40.0], "knee": [36.0, 70.0],
		"eyes": false, "graze": true,
	},
	&"bear": {
		"path": "res://assets/models/animals/wild/Bear.glb", "fwd": Vector3(0, 0, -1), "height": 1.3, "rig": true,
		"colour": "#6b4a33", "light": "#a8825e", "dark": "#3f2a1d",
		"root": "hips", "spine": ["hips", "chest"], "neck": ["neck", "head"], "head": "head", "tail": [],
		"legs": [["fl_upper", "fl_lower", "", true, true], ["fr_upper", "fr_lower", "", true, false],
			["bl_upper", "bl_lower", "", false, true], ["br_upper", "br_lower", "", false, false]],
		"stride_walk": 1.4, "stride_run": 3.0, "walk_max": 2.4, "swing": [18.0, 34.0], "knee": [28.0, 50.0],
		"eyes": false, "graze": false,
	},
}
const ATTACK_TIME := 0.55

@export var species: StringName = &"wolf"

var gait: QuadrupedGait
var _cfg: Dictionary
var _model: Node3D
var _skeleton: Skeleton3D
var _mode: StringName = &"auto"
var _attack_t := -1.0
var _last_pos := Vector3.INF
var _speed := 0.0
var _eyes: Array[Node3D] = []
var _graze_t := 0.0
var _grazing := false
var _built := false


func _ready() -> void:
	_build()


func play(state: StringName) -> void:
	if state == &"attack":
		_attack_t = 0.0
		return
	_mode = state


func set_eyes(on: bool) -> void:
	for e in _eyes:
		e.visible = on


func current_gait() -> StringName:
	if gait == null:
		return &"idle"
	return [&"idle", &"walk", &"run"][gait.gait]


## Hold one pose (contact sheets, tests): a state as for play() at a point of its cycle.
func freeze(state: StringName, phase: float) -> void:
	_build()
	set_process(false)
	gait.gait = QuadrupedGait.Gait.IDLE
	match state:
		&"walk": gait.gait = QuadrupedGait.Gait.WALK
		&"run", &"flee": gait.gait = QuadrupedGait.Gait.RUN
	gait.flee = state == &"flee"
	gait.graze = state == &"graze"
	gait.held = state == &"held"
	gait.dead = state == &"dead"
	gait.attack = 0.5 if state == &"attack" else 0.0
	gait.cycles = 0.0
	gait.settle(phase)


## Measured ground speed (m/s), smoothed.
func ground_speed() -> float:
	return _speed


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	if gait == null or delta <= 0.0:
		return
	var p := global_position
	var v := 0.0
	if _last_pos != Vector3.INF:
		var d := p - _last_pos
		d.y = 0.0
		v = d.length() / delta
	_last_pos = p
	if v > 30.0:
		v = _speed
	_speed = lerpf(_speed, v, minf(delta * 6.0, 1.0))
	# held by the hand: the owner (the Bear, a Liftable) says so; the catalog node may sit between
	var owner_held := false
	var par := get_parent()
	for i in 2:
		if par == null:
			break
		if par.get(&"held") == true:
			owner_held = true
		par = par.get_parent()
	gait.held = _mode == &"held" or owner_held
	gait.dead = _mode == &"dead"
	gait.flee = _mode == &"flee"
	# gait: forced, or from the speed
	var g := QuadrupedGait.Gait.IDLE
	match _mode:
		&"idle", &"graze": g = QuadrupedGait.Gait.IDLE
		&"walk": g = QuadrupedGait.Gait.WALK
		&"run": g = QuadrupedGait.Gait.RUN
		_:
			if _speed > float(_cfg["walk_max"]):
				g = QuadrupedGait.Gait.RUN
			elif _speed > 0.15:
				g = QuadrupedGait.Gait.WALK
	if gait.held or gait.dead:
		g = QuadrupedGait.Gait.IDLE
	gait.gait = g
	var stride: float = _cfg["stride_run"] if g == QuadrupedGait.Gait.RUN else _cfg["stride_walk"]
	var size := _model.scale.x / float(_cfg.get("base_scale", _model.scale.x))
	if _speed > 0.15:
		gait.cycles = clampf(_speed / (stride * size), 0.4, 4.0)
	else:
		gait.cycles = 2.2 if g == QuadrupedGait.Gait.RUN else 1.0
	# grazing: asked for, or a deer at rest now and then
	_graze_t -= delta
	if _graze_t <= 0.0:
		_grazing = not _grazing
		_graze_t = randf_range(5.0, 9.0) if _grazing else randf_range(3.0, 7.0)
	gait.graze = _mode == &"graze" or (_mode == &"auto" and bool(_cfg["graze"]) and _grazing)
	# the lunge
	if _attack_t >= 0.0:
		_attack_t += delta / ATTACK_TIME
		if _attack_t >= 1.0:
			_attack_t = -1.0
	gait.attack = maxf(_attack_t, 0.0)


# ------------------------------------------------------------------ building

func _build() -> void:
	if _built:
		return
	_built = true
	_cfg = SPECIES.get(species, SPECIES[&"wolf"])
	_model = (load(_cfg["path"]) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	for ap in _model.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
		ap.queue_free()
	if _cfg.get("rig", false):
		_rig_from_mesh(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# face +Z, stand on the ground, centred
	var f: Vector3 = _cfg["fwd"]
	_model.rotation.y = -atan2(f.x, f.z)
	var box := _mesh_box()
	var s: float = float(_cfg["height"]) / maxf(box.size.y, 0.001)
	_model.scale = Vector3.ONE * s
	_cfg = _cfg.duplicate()
	_cfg["base_scale"] = s
	box = _mesh_box()
	_model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	_shade()
	_rig_gait()
	if _cfg["eyes"]:
		_add_eyes()


## The meshes' bounds in this node's space.
## (From the posed vertices: a skinned mesh's own bounds are in its bind space.)
func _mesh_box() -> AABB:
	var out := AABB()
	var first := true
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for si in m.mesh.get_surface_count():
			var pn := _posed(m, m.mesh.surface_get_arrays(si))
			for v in (pn[0] as PackedVector3Array):
				if first:
					out = AABB(v, Vector3.ZERO)
					first = false
				else:
					out = out.expand(v)
	return out


## A surface's vertices and normals as they stand in the rest pose, in this node's space
## (skinned meshes are skinned on the CPU here, once).
func _posed(m: MeshInstance3D, arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	out_v.resize(verts.size())
	out_n.resize(verts.size())
	var sk := m.get_node_or_null(m.skeleton) as Skeleton3D if m.skin != null else null
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if sk == null or bones == null or weights == null:
		var xf := _rel(m)
		for i in verts.size():
			out_v[i] = xf * verts[i]
			out_n[i] = (xf.basis * norms[i]).normalized() if norms.size() > i else Vector3.UP
		return [out_v, out_n]
	var sk_xf := _rel(sk)
	var mats: Array[Transform3D] = []
	for b in m.skin.get_bind_count():
		var bone := m.skin.get_bind_bone(b)
		if bone < 0:
			bone = sk.find_bone(m.skin.get_bind_name(b))
		var g := sk.get_bone_global_rest(bone) if bone >= 0 else Transform3D()
		mats.append(sk_xf * g * m.skin.get_bind_pose(b))
	var per := (bones as PackedInt32Array).size() / maxi(verts.size(), 1)
	for i in verts.size():
		var acc := Vector3.ZERO
		var nacc := Vector3.ZERO
		var wsum := 0.0
		for k in per:
			var w: float = weights[i * per + k]
			if w <= 0.0:
				continue
			var t: Transform3D = mats[bones[i * per + k]]
			acc += (t * verts[i]) * w
			if norms.size() > i:
				nacc += (t.basis * norms[i]) * w
			wsum += w
		out_v[i] = acc / maxf(wsum, 0.0001)
		out_n[i] = nacc.normalized() if nacc != Vector3.ZERO else Vector3.UP
	return [out_v, out_n]


func _rel(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != self:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _bone(n: String) -> int:
	return _skeleton.find_bone(n) if n != "" else -1


func _rig_gait() -> void:
	gait = QuadrupedGait.new()
	gait.name = "Gait"
	_skeleton.add_child(gait)
	# this node's axes in skeleton space
	var rel := _rel(_skeleton)
	var inv := rel.basis.inverse()
	gait.fwd = (inv * Vector3.BACK).normalized()
	gait.up = (inv * Vector3.UP).normalized()
	gait.side = gait.up.cross(gait.fwd).normalized()
	gait.size = 1.0 / maxf(rel.basis.get_scale().x, 0.0001)
	gait.root_bone = _bone(_cfg["root"])
	for b in _cfg["spine"]:
		if b != _cfg["root"]:
			gait.spine.append(_bone(b))
	for b in _cfg["neck"]:
		gait.neck.append(_bone(b))
	for b in _cfg["tail"]:
		gait.tail.append(_bone(b))
	for l in _cfg["legs"]:
		gait.legs.append({"upper": _bone(l[0]), "lower": _bone(l[1]), "foot": _bone(l[2]), "front": l[3], "left": l[4]})
	gait.swing_walk = _cfg["swing"][0]
	gait.swing_run = _cfg["swing"][1]
	gait.knee_walk = _cfg["knee"][0]
	gait.knee_run = _cfg["knee"][1]


# ------------------------------------------------------------------ shading

## Every surface gets the flat palette shader; the body's vertex colours darken the back
## and lighten the belly, legs' insides and muzzle.
func _shade() -> void:
	var base := Color(_cfg["colour"])
	var light := Color(_cfg["light"])
	var dark := Color(_cfg["dark"])
	var box := _mesh_box()
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := _rel(m)
		var src := m.mesh
		var out := ArrayMesh.new()
		for si in src.get_surface_count():
			var arrays := src.surface_get_arrays(si)
			var mat_name := ""
			var sm := src.surface_get_material(si)
			if sm != null:
				mat_name = sm.resource_name.to_lower()
			var own := ""
			for key in (_cfg.get("surfaces", {}) as Dictionary):
				if mat_name.contains(key):
					own = _cfg["surfaces"][key]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var pn := _posed(m, arrays)
			var pos: PackedVector3Array = pn[0]
			var nrm: PackedVector3Array = pn[1]
			var cols := PackedColorArray()
			cols.resize(verts.size())
			for i in verts.size():
				if own != "":
					cols[i] = Color.WHITE
					continue
				var p := pos[i]
				var n := nrm[i]
				var h := (p.y - box.position.y) / maxf(box.size.y, 0.001)
				var along := (p.z - box.position.z) / maxf(box.size.z, 0.001)   # 1 = the nose
				var c := base
				# belly and the undersides: light; the back: dark
				var under := clampf((-n.y - 0.15) / 0.6, 0.0, 1.0) * clampf((0.75 - h) / 0.3, 0.0, 1.0)
				var back := clampf((n.y - 0.55) / 0.4, 0.0, 1.0) * clampf((h - 0.45) / 0.2, 0.0, 1.0)
				var muzzle := clampf((along - 0.9) / 0.07, 0.0, 1.0) * clampf((0.85 - h) / 0.3, 0.0, 1.0)
				var socks := clampf((0.12 - h) / 0.1, 0.0, 1.0)
				c = c.lerp(light, maxf(under, muzzle) * 0.85)
				c = c.lerp(dark, maxf(back * 0.7, socks * 0.8))
				cols[i] = c
			arrays[Mesh.ARRAY_COLOR] = cols
			var flags: int = src.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays, [], {}, flags)
			var mat := ShaderMaterial.new()
			mat.shader = ArtPalette.SHADER_VC
			mat.set_shader_parameter("albedo_color", Color(own) if own != "" else Color.WHITE)
			mat.set_shader_parameter("palette_pull", float(_cfg.get("pull", 0.08)))
			ArtPalette.register(mat)
			out.surface_set_material(si, mat)
		m.mesh = out
		m.material_override = null


# ------------------------------------------------------------------ eyes

func _add_eyes() -> void:
	var hb := _bone(_cfg["head"])
	if hb < 0:
		return
	# the head's own vertices (posed, in this node's space: metres, nose to +Z) place them:
	# a third of the way from the head bone to the nose tip, high on the sides of the head
	var sk_xf := _rel(_skeleton)
	var head_node := sk_xf * _skeleton.get_bone_global_rest(hb)
	var hp := head_node.origin
	var mi := _model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var pos: PackedVector3Array = _posed(mi, mi.mesh.surface_get_arrays(0))[0]
	var nose := -INF
	for v in pos:
		if absf(v.x) < 0.2 and v.y > hp.y - 0.4:
			nose = maxf(nose, v.z)
	if nose == -INF or nose <= hp.z:
		return
	var ez := lerpf(hp.z, nose, 0.42)
	var y0 := INF
	var y1 := -INF
	var w := 0.0
	for v in pos:
		if absf(v.z - ez) < 0.035 and v.y > hp.y - 0.3:
			y0 = minf(y0, v.y)
			y1 = maxf(y1, v.y)
			w = maxf(w, absf(v.x))
	if y1 == -INF:
		return
	var ey := lerpf(y0, y1, 0.7)
	var att := BoneAttachment3D.new()
	att.bone_name = _skeleton.get_bone_name(hb)
	_skeleton.add_child(att)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.3)
	var unit := 1.0 / head_node.basis.get_scale().x   # bone units per metre
	for sgn in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.028 * unit
		sm.height = 0.05 * unit
		sm.radial_segments = 6
		sm.rings = 3
		e.mesh = sm
		e.material_override = m
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.position = head_node.affine_inverse() * Vector3(sgn * w * 0.7, ey, ez)
		att.add_child(e)
		e.visible = false
		_eyes.append(e)


# ------------------------------------------------------------------ rigging a mesh

## Gives an unrigged four-legged mesh (the bear) a skeleton and skin: a spine chain
## (hips, chest, neck, head) along its length and two bones per leg, found from where
## its feet touch the ground; weights from each vertex's place on the body, blended at
## the joints.
func _rig_from_mesh(model: Node3D) -> void:
	var src := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var xf := _rel_to(src, model)
	var arrays := src.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var f: Vector3 = (_cfg["fwd"] as Vector3).normalized()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in verts.size():
		verts[i] = xf * verts[i]
		lo = lo.min(verts[i])
		hi = hi.max(verts[i])
		if norms.size() > i:
			norms[i] = (xf.basis * norms[i]).normalized()
	var height := hi.y - lo.y
	var length := absf((hi - lo).dot(f))
	var mid := (lo + hi) * 0.5
	# feet: where the mesh meets the ground, by quadrant
	var feet := {}
	for v in verts:
		if v.y - lo.y < height * 0.1:
			var key := Vector2i(1 if v.x - mid.x > 0.0 else -1, 1 if (v - mid).dot(f) > 0.0 else -1)
			if not feet.has(key):
				feet[key] = [Vector3.ZERO, 0]
			feet[key][0] += v
			feet[key][1] += 1
	var foot_at := {}
	for key in feet:
		foot_at[key] = feet[key][0] / float(feet[key][1])
	var front_z := 0.0
	var back_z := 0.0
	for key in foot_at:
		if key.y > 0:
			front_z += (foot_at[key] - mid).dot(f) * 0.5
		else:
			back_z += (foot_at[key] - mid).dot(f) * 0.5
	var y_body := lo.y + height * 0.62
	var bones := {}   # name -> [position, parent name]
	bones["hips"] = [mid + f * back_z + Vector3(0, y_body - mid.y, 0), ""]
	bones["chest"] = [mid + f * front_z + Vector3(0, y_body - mid.y, 0), "hips"]
	bones["neck"] = [mid + f * (front_z + length * 0.16) + Vector3(0, lo.y + height * 0.62 - mid.y, 0), "chest"]
	bones["head"] = [mid + f * (front_z + length * 0.3) + Vector3(0, lo.y + height * 0.55 - mid.y, 0), "neck"]
	var knee_h := lo.y + height * 0.25
	var top_h := lo.y + height * 0.5
	for key in foot_at:
		var nm := ("f" if key.y > 0 else "b") + ("l" if _is_left(key, f) else "r")
		var ft: Vector3 = foot_at[key]
		bones[nm + "_upper"] = [Vector3(ft.x, top_h, ft.z), "chest" if key.y > 0 else "hips"]
		bones[nm + "_lower"] = [Vector3(ft.x, knee_h, ft.z), nm + "_upper"]
	# the skeleton
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	model.add_child(sk)
	var order := ["hips", "chest", "neck", "head"]
	for nm in bones:
		if not nm in order:
			order.append(nm)
	for nm in order:
		sk.add_bone(nm)
	for nm in order:
		var bi := sk.find_bone(nm)
		var par: String = bones[nm][1]
		var pos: Vector3 = bones[nm][0]
		if par != "":
			sk.set_bone_parent(bi, sk.find_bone(par))
			pos -= bones[par][0]
		sk.set_bone_rest(bi, Transform3D(Basis(), pos))
	sk.reset_bone_poses()
	var skin := Skin.new()
	for nm in order:
		skin.add_bind(sk.find_bone(nm), Transform3D(Basis(), -(bones[nm][0] as Vector3)))
	# weights
	var bw := PackedInt32Array()
	var ww := PackedFloat32Array()
	bw.resize(verts.size() * 4)
	ww.resize(verts.size() * 4)
	var chain := ["hips", "chest", "neck", "head"]
	for i in verts.size():
		var v := verts[i]
		var w := {}
		# along the spine chain
		var a := (v - mid).dot(f)
		var cw := _chain_weights(a, chain.map(func(n): return (bones[n][0] - mid).dot(f)))
		for k in chain.size():
			if cw[k] > 0.0:
				w[chain[k]] = cw[k]
		# a leg?
		var rel_h := v.y - lo.y
		var key := Vector2i(1 if v.x - mid.x > 0.0 else -1, 1 if a > 0.0 else -1)
		if foot_at.has(key) and rel_h < height * 0.56:
			var ft: Vector3 = foot_at[key]
			var near := Vector2(v.x - ft.x, v.z - ft.z).length() < height * 0.3
			if near:
				var nm := ("f" if key.y > 0 else "b") + ("l" if _is_left(key, f) else "r")
				var body := smoothstep(height * 0.38, height * 0.56, rel_h)
				var lower := 1.0 - smoothstep(height * 0.18, height * 0.32, rel_h)
				for k in w:
					w[k] *= body
				w[nm + "_lower"] = (1.0 - body) * lower
				w[nm + "_upper"] = (1.0 - body) * (1.0 - lower)
		var ks: Array = w.keys()
		ks.sort_custom(func(x, y): return w[x] > w[y])
		var total := 0.0
		for k in mini(ks.size(), 4):
			total += w[ks[k]]
		for k in 4:
			if k < ks.size() and total > 0.0:
				bw[i * 4 + k] = sk.find_bone(ks[k])
				ww[i * 4 + k] = w[ks[k]] / total
			else:
				bw[i * 4 + k] = 0
				ww[i * 4 + k] = 0.0
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_BONES] = bw
	arrays[Mesh.ARRAY_WEIGHTS] = ww
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	sk.add_child(mi)
	mi.skin = skin
	mi.skeleton = NodePath("..")
	src.get_parent().remove_child(src)
	src.free()


static func _is_left(key: Vector2i, f: Vector3) -> bool:
	# the animal's left: up x forward
	var left := Vector3.UP.cross(f)
	return signf(left.x) == float(key.x) if absf(left.x) > 0.5 else signf(left.z) == float(key.x)


## Weights over a chain of bones at positions `at` (sorted either way) for a point at a.
static func _chain_weights(a: float, at: Array) -> Array:
	var out := []
	out.resize(at.size())
	out.fill(0.0)
	# find the segment
	var idx := range(at.size())
	idx.sort_custom(func(x, y): return at[x] < at[y])
	if a <= at[idx[0]]:
		out[idx[0]] = 1.0
		return out
	if a >= at[idx[idx.size() - 1]]:
		out[idx[idx.size() - 1]] = 1.0
		return out
	for k in idx.size() - 1:
		var p: float = at[idx[k]]
		var q: float = at[idx[k + 1]]
		if a >= p and a <= q:
			var t := (a - p) / maxf(q - p, 0.0001)
			out[idx[k]] = 1.0 - t
			out[idx[k + 1]] = t
			break
	return out


static func _rel_to(n: Node3D, top: Node) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != top:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
