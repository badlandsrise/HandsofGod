extends SceneTree
## Rebuilds the shared material library (assets/models/materials/*.tres) and every composite
## prop scene in scenes/props/ from the imported pack models plus a few primitives.
## Re-run after changing this file:
##   godot --headless --path . -s res://scripts/assets/tools/build_props.gd
##
## Conventions: origin on the ground at the footprint centre, +Z is the front (Godot's
## model front), metres. Pack models are instanced (not copied), so the scenes stay small.

const N := "res://assets/models/nature/"
const K := "res://assets/models/props/"
const V := "res://assets/models/village/"
const OUT := "res://scenes/props/"
const FLICKER := preload("res://scripts/assets/flicker.gd")
const ANIMAL := preload("res://scripts/assets/animal_visual.gd")

var _root: Node3D
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_build_materials()
	_campfire()
	_firewood_pile()
	_flint_node()
	_hut()
	_hut_frame()
	_hut_plot()
	_food_store()
	_drying_rack()
	_cairn()
	_shrine()
	_stone_circle()
	_cliff()
	_cave_mouth()
	_deer()
	_wolf()
	_bear()
	_farm_animal("sheep", "res://assets/models/animals/Sheep.fbx", 0.17)
	_farm_animal("horse", "res://assets/models/animals/Horse.fbx", 0.25)
	_era2_cottage()
	_era2_longhouse()
	_era2_shed()
	print("build_props: done")
	quit()


# ------------------------------------------------------------------ helpers

func _begin(scene_name: String) -> Node3D:
	_root = Node3D.new()
	_root.name = scene_name.to_pascal_case()
	_rng.seed = hash(scene_name)
	return _root


func _save(scene_name: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(_root)
	if err == OK:
		err = ResourceSaver.save(ps, OUT + scene_name + ".tscn")
	print("  %s -> %s" % [scene_name, error_string(err)])
	_root.free()


func _own(n: Node) -> void:
	n.owner = _root
	if n.scene_file_path != "":
		return   # instanced scene: its insides belong to it
	for c in n.get_children():
		_own(c)


## Instance a pack model. rot is degrees (x, y, z); s is a float or Vector3 scale.
func _model(path: String, pos: Vector3, rot := Vector3.ZERO, s: Variant = 1.0, parent: Node3D = null, meta := {}) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	var sc: Vector3 = s if s is Vector3 else Vector3.ONE * float(s)
	n.transform = Transform3D(Basis.from_euler(rot * PI / 180.0).scaled(sc), pos)
	for k in meta:
		n.set_meta(k, meta[k])
	(parent if parent else _root).add_child(n)
	n.owner = _root
	return n


func _prim(mesh: Mesh, mat: String, pos: Vector3, rot := Vector3.ZERO, s: Variant = 1.0, parent: Node3D = null, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	var sc: Vector3 = s if s is Vector3 else Vector3.ONE * float(s)
	mi.transform = Transform3D(Basis.from_euler(rot * PI / 180.0).scaled(sc), pos)
	if node_name != "":
		mi.name = node_name
	(parent if parent else _root).add_child(mi)
	_own(mi)
	return mi


func _group(node_name: String, pos := Vector3.ZERO, rot_y := 0.0, parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.name = node_name
	g.position = pos
	g.rotation.y = deg_to_rad(rot_y)
	(parent if parent else _root).add_child(g)
	g.owner = _root
	return g


func _mat(mat_name: String) -> Material:
	if mat_name == "flame":
		return load("res://assets/models/materials/flame.tres")
	if mat_name == "flame_core":
		return load("res://assets/models/materials/flame_core.tres")
	return load("res://assets/models/materials/%s.tres" % mat_name)


func _cyl(r_top: float, r_bot: float, h: float, seg := 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _sphere(r: float, seg := 6, rings := 4) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 7
	m.rings = 1
	return m


# ------------------------------------------------------------------ material library

func _build_materials() -> void:
	for mat_name in ArtPalette.NAMED:
		var spec: Array = ArtPalette.NAMED[mat_name]
		var m := ShaderMaterial.new()
		m.shader = ArtPalette.SHADER_2S if spec[1] else ArtPalette.SHADER
		m.resource_name = "hog_" + mat_name
		m.set_shader_parameter("albedo_color", Color(spec[0]))
		m.set_shader_parameter("palette_pull", 0.0)
		ArtPalette._apply_era_to(m)
		var path := "res://assets/models/materials/%s.tres" % mat_name
		ResourceSaver.save(m, path)
		_strip_null_params(path)
	for pair in [["flame", "#ff9a3c", "#ff7a1a", 2.2], ["flame_core", "#ffe08a", "#ffc94a", 3.0]]:
		var f := StandardMaterial3D.new()
		f.resource_name = "hog_" + pair[0]
		f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		f.albedo_color = Color(pair[1])
		f.emission_enabled = true
		f.emission = Color(pair[2])
		f.emission_energy_multiplier = pair[3]
		ResourceSaver.save(f, "res://assets/models/materials/%s.tres" % pair[0])
	for part in [["villager_body", 0], ["villager_hair", 1], ["villager_eyes", 2]]:
		var vm := ShaderMaterial.new()
		vm.shader = ArtPalette.VILLAGER_SHADER
		vm.resource_name = "hog_" + part[0]
		vm.set_shader_parameter("part", part[1])
		ArtPalette._apply_era_to(vm)
		var vpath := "res://assets/models/materials/%s.tres" % part[0]
		ResourceSaver.save(vm, vpath)
		_strip_null_params(vpath)
	print("  materials saved")


## Headless saves list uniforms the material never set as "= null"; drop them so the shader
## defaults apply.
func _strip_null_params(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var lines := PackedStringArray()
	for line in text.split("\n"):
		if line.begins_with("shader_parameter/") and line.ends_with("= null"):
			continue
		lines.append(line)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))


# ------------------------------------------------------------------ Era 1 props

func _flames(parent: Node3D, y: float, size: float) -> void:
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.set_script(FLICKER)
	fire.position.y = y
	parent.add_child(fire)
	fire.owner = _root
	var specs := [[Vector3(0, 0, 0), 1.0, "flame"], [Vector3(0.14, 0, 0.08), 0.7, "flame"],
		[Vector3(-0.12, 0, 0.1), 0.75, "flame"], [Vector3(0.02, 0, -0.13), 0.65, "flame"],
		[Vector3(0, 0, 0.02), 0.6, "flame_core"]]
	var i := 0
	for s in specs:
		var h: float = 0.9 * size * float(s[1])
		var pivot := Node3D.new()
		pivot.name = "Flame%d" % i
		pivot.position = s[0] * size
		fire.add_child(pivot)
		pivot.owner = _root
		_prim(_cyl(0.0, 0.2 * size * float(s[1]), h, 5), s[2], Vector3(0, h * 0.5, 0), Vector3(0, i * 37, 0), 1.0, pivot)
		i += 1
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position.y = 0.6 * size
	light.light_color = Color("#ff9a4a")
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.shadow_enabled = false
	fire.add_child(light)
	light.owner = _root


func _campfire() -> void:
	_begin("campfire")
	_model(K + "campfire-pit.glb", Vector3.ZERO, Vector3.ZERO, 6.0, null, {"hog_pull": 0.4, "hog_sat": 0.55})
	_flames(_root, 0.15, 1.0)
	_save("campfire")


func _firewood_pile() -> void:
	_begin("firewood_pile")
	var meta := {"hog_pull": 0.5, "hog_sat": 0.45, "hog_tint": Color("#e0c4a8")}
	_model(K + "resource-wood.glb", Vector3(0, 0, -0.3), Vector3.ZERO, 7.0, null, meta)
	_model(K + "resource-wood.glb", Vector3(0, 0, 0.3), Vector3(0, 4, 0), 7.0, null, meta)
	_model(K + "resource-wood.glb", Vector3(0.05, 0.4, 0.0), Vector3(0, -3, 0), 7.0, null, meta)
	_model(K + "resource-wood.glb", Vector3(-0.1, 0.0, 0.85), Vector3(0, 70, 0), 5.0, null, meta)
	_save("firewood_pile")


func _flint_node() -> void:
	_begin("flint_node")
	var meta := {"hog_pull": 0.1, "hog_tint": Color("#7d8494")}
	_model(N + "Rock_3.fbx", Vector3(0, 0.1, 0), Vector3(0, 20, 0), 1.7, null, meta)
	_model(N + "Rock_5.fbx", Vector3(0.75, 0.0, 0.35), Vector3(0, 100, 0), 0.9, null, meta)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var r := 0.95 + 0.2 * (i % 2)
		_model(K + "resource-stone.glb", Vector3(cos(a) * r, 0, sin(a) * r), Vector3(0, i * 53, 0), 2.6, null,
			{"hog_pull": 0.2, "hog_tint": Color("#5a5f6e")})
	_save("flint_node")


## Era 1 hide hut: a cone of hides over a ring of poles (reads clearly from a high camera).
func _hut_poles(parent: Node3D, r: float, h: float, count: int, tip: float) -> void:
	for i in count:
		var a := TAU * i / count + 0.2
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var top := Vector3(0, h + tip, 0) - base * (tip / h)
		var mid := (base + top) * 0.5
		var length := base.distance_to(top)
		var mi := _prim(_cyl(0.035, 0.05, length, 5), "wood", mid, Vector3.ZERO, 1.0, parent)
		mi.basis = Basis(Quaternion(Vector3.UP, (top - base).normalized()))


func _hut() -> void:
	_begin("hut")
	var r := 1.8
	var h := 2.9
	_prim(_cyl(0.0, r, h, 8), "hide", Vector3(0, h * 0.5, 0), Vector3(0, 0, 0), 1.0, null, "Hides")
	_prim(_cyl(0.0, r * 1.01, h * 0.35, 8), "wood_dark", Vector3(0, h * 0.175 + 0.55, 0), Vector3(0, 0, 0), Vector3(1, 1, 1), null, "HideBand")
	_hut_poles(_root, r * 0.98, h, 8, 0.55)
	# door: a dark opening and a folded-back flap on the front (+Z)
	_prim(_box(Vector3(0.75, 1.15, 0.5)), "cave_dark", Vector3(0, 0.55, r - 0.38), Vector3(-30, 0, 0), 1.0, null, "Door")
	_prim(_box(Vector3(0.45, 1.0, 0.04)), "hide", Vector3(0.55, 0.6, r - 0.05), Vector3(-25, 35, 0), 1.0, null, "Flap")
	for i in 9:
		var a := TAU * i / 9.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.4:
			continue   # leave the doorway clear
		_model(N + "Rock_2.fbx", Vector3(cos(a) * (r + 0.05), 0, sin(a) * (r + 0.05)), Vector3(0, i * 41, 0), 0.42)
	_model(K + "resource-wood.glb", Vector3(1.6, 0, 1.9), Vector3(0, 30, 0), 5.0, null, {"hog_pull": 0.5, "hog_sat": 0.45, "hog_tint": Color("#e0c4a8")})
	_save("hut")


func _hut_frame() -> void:
	_begin("hut_frame")
	_prim(_cyl(1.9, 1.95, 0.04, 10), "dirt", Vector3(0, 0.02, 0))
	_hut_poles(_root, 1.75, 2.9, 8, 0.55)
	_model(K + "resource-wood.glb", Vector3(1.6, 0, 1.6), Vector3(0, 40, 0), 6.0, null, {"hog_pull": 0.5, "hog_sat": 0.45, "hog_tint": Color("#e0c4a8")})
	_save("hut_frame")


func _hut_plot() -> void:
	_begin("hut_plot")
	_prim(_cyl(1.9, 1.95, 0.04, 10), "dirt", Vector3(0, 0.02, 0))
	for i in 10:
		var a := TAU * i / 10.0
		_model(N + "Rock_2.fbx", Vector3(cos(a) * 1.85, 0, sin(a) * 1.85), Vector3(0, i * 67, 0), 0.32)
	for c in [Vector3(1.3, 0, 1.3), Vector3(-1.3, 0, 1.3), Vector3(1.3, 0, -1.3), Vector3(-1.3, 0, -1.3)]:
		_prim(_cyl(0.035, 0.05, 1.1, 5), "wood", c + Vector3(0, 0.55, 0), Vector3(0, 0, 4))
	_save("hut_plot")


## Raised food store: a platform on posts, out of reach of animals, under a hide roof.
func _food_store() -> void:
	_begin("food_store")
	var ph := 1.0
	for c in [Vector3(0.95, 0, 0.95), Vector3(-0.95, 0, 0.95), Vector3(0.95, 0, -0.95), Vector3(-0.95, 0, -0.95)]:
		_prim(_cyl(0.06, 0.08, ph + 1.5, 5), "wood", c + Vector3(0, (ph + 1.5) * 0.5, 0))
	_prim(_box(Vector3(2.3, 0.14, 2.3)), "wood_dark", Vector3(0, ph, 0), Vector3.ZERO, 1.0, null, "Platform")
	_prim(_cyl(0.0, 1.75, 1.2, 8), "hide", Vector3(0, ph + 1.5 + 0.55, 0), Vector3(0, 22, 0), 1.0, null, "Roof")
	_prim(_box(Vector3(0.12, 0.9, 0.08)), "wood", Vector3(0.45, ph * 0.5, 1.25), Vector3(-20, 0, 0), 1.0, null, "Ladder")
	var meta := {"hog_pull": 0.5, "hog_sat": 0.35, "hog_tint": Color("#d8b090")}
	_model(K + "bucket.glb", Vector3(-0.6, ph + 0.07, -0.55), Vector3.ZERO, 4.0, null, meta)
	_model(K + "bucket.glb", Vector3(0.6, ph + 0.07, -0.6), Vector3(0, 40, 0), 3.6, null, meta)
	var heap := _group("Berries", Vector3(-0.1, ph + 0.08, 0.3))
	var berry := _sphere(0.085, 6, 3)
	for layer in 3:
		var cnt: int = [9, 5, 2][layer]
		for i in cnt:
			var a: float = TAU * i / cnt + layer
			var r: float = [0.28, 0.16, 0.06][layer]
			_prim(berry, "berry", Vector3(cos(a) * r, 0.07 + layer * 0.12, sin(a) * r), Vector3.ZERO, 1.0, heap)
	_model(K + "fish.glb", Vector3(0.5, ph + 0.08, 0.45), Vector3(0, 60, 0), 3.0, null, {"hog_pull": 0.4, "hog_sat": 0.5})
	_save("food_store")


func _drying_rack() -> void:
	_begin("drying_rack")
	_model(K + "campfire-stand.glb", Vector3.ZERO, Vector3.ZERO, 6.0, null, {"hog_pull": 0.5, "hog_sat": 0.45, "hog_tint": Color("#e0c4a8")})
	_prim(_box(Vector3(1.2, 0.9, 0.03)), "hide", Vector3(-0.35, 1.05, 0), Vector3(0, 0, 3))
	_model(K + "fish-large.glb", Vector3(0.6, 0.95, 0.03), Vector3(0, 0, 90), 2.5, null, {"hog_pull": 0.4, "hog_sat": 0.5})
	_save("drying_rack")


func _cairn() -> void:
	_begin("cairn")
	_cairn_stack(_root, 1.0)
	_save("cairn")


func _cairn_stack(parent: Node3D, s: float) -> void:
	_model(N + "Rock_6.fbx", Vector3(0, 0, 0), Vector3(0, 10, 0), Vector3(1.3, 0.7, 1.2) * s, parent)
	_model(N + "Rock_5.fbx", Vector3(0.02, 0.45, 0) * s, Vector3(0, 80, 0), Vector3(0.95, 0.6, 0.85) * s, parent)
	_model(N + "Rock_2.fbx", Vector3(-0.02, 0.83, 0.02) * s, Vector3(0, 150, 0), Vector3(0.8, 0.6, 0.8) * s, parent)
	_model(N + "Rock_3.fbx", Vector3(0.03, 1.2, 0) * s, Vector3(0, 230, 0), Vector3(0.55, 0.5, 0.55) * s, parent)
	_model(N + "Rock_1.fbx", Vector3(0, 1.42, 0) * s, Vector3(0, 300, 0), Vector3(0.45, 0.4, 0.45) * s, parent)


func _shrine() -> void:
	_begin("shrine")
	_model(N + "Rock_1.fbx", Vector3(0, 0, -1.0), Vector3(0, 15, 0), Vector3(3.2, 3.6, 2.3))
	_model(N + "Rock_6.fbx", Vector3(0, 0, 0.6), Vector3(0, 90, 0), Vector3(2.0, 0.8, 2.4))
	# red ochre handprint painted on the altar top: the hand symbol of Era 1 (DESIGN 7)
	var hand := _group("Handprint", Vector3(0, 0.6, 0.6), 0.0)
	hand.scale = Vector3.ONE * 1.7
	_prim(_cyl(0.17, 0.17, 0.02, 8), "red_ochre", Vector3(0, 0, 0.06), Vector3.ZERO, Vector3(1.0, 1.0, 1.15), hand)
	var fingers := [[-0.12, 0.22, 10.0], [-0.04, 0.27, 3.0], [0.04, 0.28, -3.0], [0.12, 0.23, -10.0]]
	for f in fingers:
		_prim(_box(Vector3(0.065, 0.02, 0.24)), "red_ochre", Vector3(f[0], 0, -f[1] + 0.07), Vector3(0, f[2], 0), 1.0, hand)
	_prim(_box(Vector3(0.07, 0.02, 0.2)), "red_ochre", Vector3(0.21, 0, 0.02), Vector3(0, -55, 0), 1.0, hand)
	var lc := _group("CairnL", Vector3(-1.9, 0, 0.4))
	_cairn_stack(lc, 0.8)
	var rc := _group("CairnR", Vector3(1.9, 0, 0.4))
	_cairn_stack(rc, 0.7)
	for i in 3:
		_prim(_sphere(0.09, 6, 3), "bone", Vector3(-0.5 + i * 0.5, 0.0, 1.9), Vector3.ZERO, Vector3(1, 0.6, 1.4))
	_save("shrine")


func _stone_circle() -> void:
	_begin("stone_circle")
	var count := 9
	for i in count:
		var a := TAU * i / count
		var p := Vector3(sin(a) * 5.0, -0.1, cos(a) * 5.0)
		var h := 3.2 + _rng.randf_range(-0.4, 0.5)
		_model(N + "Rock_1.fbx", p, Vector3(0, rad_to_deg(a) + _rng.randf_range(-12, 12), _rng.randf_range(-3, 3)),
			Vector3(2.6, h, 2.1))
	_model(N + "Rock_6.fbx", Vector3(0, 0, 0), Vector3(0, 30, 0), Vector3(2.2, 0.55, 1.6))
	_save("stone_circle")


func _cliff_rocks(parent: Node3D) -> void:
	var rocks := [
		["Rock_6.fbx", Vector3(-5.5, 0, -0.5), 20.0, Vector3(5.0, 6.5, 4.5)],
		["Rock_4.fbx", Vector3(-2.2, 1.0, -1.0), 75.0, Vector3(4.5, 8.0, 4.0)],
		["Rock_7.fbx", Vector3(1.5, 1.2, -0.8), 130.0, Vector3(5.0, 8.5, 4.5)],
		["Rock_Moss_6.fbx", Vector3(5.2, 0, -0.3), 200.0, Vector3(5.0, 6.0, 4.5)],
		["Rock_3.fbx", Vector3(-3.8, 0.0, 1.6), 40.0, Vector3(2.5, 2.2, 2.5)],
		["Rock_Moss_5.fbx", Vector3(3.6, 0.0, 1.8), 10.0, Vector3(2.4, 2.0, 2.2)],
	]
	for r in rocks:
		_model(N + r[0], r[1], Vector3(0, r[2], 0), r[3], parent)


func _cliff() -> void:
	_begin("cliff")
	_cliff_rocks(_root)
	_save("cliff")


func _cave_mouth() -> void:
	_begin("cave_mouth")
	# dark interior first, so the rocks frame it
	_prim(_box(Vector3(4.2, 3.6, 3.0)), "cave_dark", Vector3(0, 1.8, -0.4))
	_model(N + "Rock_4.fbx", Vector3(-3.6, 1.0, 0.2), Vector3(0, 70, 0), Vector3(4.0, 7.5, 3.6))
	_model(N + "Rock_7.fbx", Vector3(3.7, 1.2, 0.0), Vector3(0, 120, 0), Vector3(4.2, 7.5, 3.8))
	_model(N + "Rock_6.fbx", Vector3(0.0, 3.7, -0.2), Vector3(0, 95, 180), Vector3(3.2, 2.6, 7.5))
	_model(N + "Rock_6.fbx", Vector3(0.2, 0.0, -3.4), Vector3(0, 10, 0), Vector3(12.0, 9.0, 5.0))
	_model(N + "Rock_Moss_6.fbx", Vector3(-6.4, 0.0, -1.2), Vector3(0, 200, 0), Vector3(4.0, 5.0, 4.0))
	_model(N + "Rock_Moss_5.fbx", Vector3(6.3, 0.0, -1.0), Vector3(0, 30, 0), Vector3(3.5, 4.0, 3.2))
	_model(N + "Rock_2.fbx", Vector3(-2.0, 0.0, 2.2), Vector3(0, 30, 0), 1.0)
	_model(N + "Rock_5.fbx", Vector3(2.4, 0.0, 2.0), Vector3(0, 80, 0), 1.2)
	_save("cave_mouth")


# ------------------------------------------------------------------ placeholder wild animals (primitives)
# Low-poly stand-ins until the Quaternius Animated Animals pack arrives. Face +Z.

func _quadruped(body_r: float, body_len: float, leg_h: float, leg_r: float, coat: String, light: String) -> Node3D:
	var body_y := leg_h + body_r * 0.7
	var b := _group("Body")
	_prim(_capsule(body_r, body_len), coat, Vector3(0, body_y, 0), Vector3(90, 0, 0), 1.0, b, "Torso")
	_prim(_capsule(body_r * 0.8, body_len * 0.75), light, Vector3(0, body_y - body_r * 0.3, 0.02), Vector3(90, 0, 0), Vector3(0.9, 1, 0.8), b, "Belly")
	var lx := body_r * 0.55
	var lz := body_len * 0.5 - body_r * 0.9
	for p in [Vector3(lx, 0, lz), Vector3(-lx, 0, lz), Vector3(lx, 0, -lz), Vector3(-lx, 0, -lz)]:
		_prim(_cyl(leg_r, leg_r * 0.75, leg_h + body_r * 0.4, 5), coat, p + Vector3(0, (leg_h + body_r * 0.4) * 0.5, 0), Vector3.ZERO, 1.0, b, "Leg")
	return b


func _deer() -> void:
	_begin("deer")
	_root.set_script(ANIMAL)
	var b := _quadruped(0.24, 1.15, 0.78, 0.045, "deer", "deer_light")
	_prim(_cyl(0.07, 0.11, 0.55, 6), "deer", Vector3(0, 1.32, 0.5), Vector3(35, 0, 0), 1.0, b, "Neck")
	var head := _group("Head", Vector3(0, 1.58, 0.68), 0.0, b)
	_prim(_cyl(0.055, 0.11, 0.36, 6), "deer", Vector3(0, 0, 0.08), Vector3(80, 0, 0), 1.0, head)
	_prim(_sphere(0.03, 5, 3), "charcoal", Vector3(0, -0.05, 0.27), Vector3.ZERO, 1.0, head)
	for sx in [-1.0, 1.0]:
		_prim(_cyl(0.0, 0.05, 0.16, 4), "deer", Vector3(sx * 0.1, 0.08, -0.06), Vector3(0, 0, -sx * 55), Vector3(1, 1, 0.5), head)
		_prim(_cyl(0.015, 0.025, 0.42, 4), "antler", Vector3(sx * 0.08, 0.24, -0.04), Vector3(-15, 0, -sx * 20), 1.0, head)
		_prim(_cyl(0.012, 0.02, 0.22, 4), "antler", Vector3(sx * 0.13, 0.36, 0.06), Vector3(40, 0, -sx * 30), 1.0, head)
		_prim(_cyl(0.01, 0.018, 0.2, 4), "antler", Vector3(sx * 0.17, 0.42, -0.08), Vector3(-30, 0, -sx * 35), 1.0, head)
	_prim(_cyl(0.03, 0.06, 0.18, 5), "deer_light", Vector3(0, 1.12, -0.66), Vector3(-130, 0, 0), 1.0, b, "Tail")
	_save("deer")


func _wolf() -> void:
	_begin("wolf")
	_root.set_script(ANIMAL)
	var b := _quadruped(0.18, 0.95, 0.5, 0.04, "wolf", "wolf_light")
	_prim(_cyl(0.09, 0.13, 0.3, 6), "wolf", Vector3(0, 0.82, 0.48), Vector3(55, 0, 0), 1.0, b, "Neck")
	var head := _group("Head", Vector3(0, 0.92, 0.62), 0.0, b)
	_prim(_sphere(0.13, 6, 4), "wolf", Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.1), head)
	_prim(_cyl(0.035, 0.08, 0.24, 5), "wolf_light", Vector3(0, -0.04, 0.19), Vector3(90, 0, 0), 1.0, head)
	_prim(_sphere(0.025, 5, 3), "charcoal", Vector3(0, -0.03, 0.31), Vector3.ZERO, 1.0, head)
	for sx in [-1.0, 1.0]:
		_prim(_cyl(0.0, 0.05, 0.13, 4), "wolf", Vector3(sx * 0.07, 0.15, -0.02), Vector3(0, 0, -sx * 12), 1.0, head)
		_prim(_sphere(0.018, 4, 2), "charcoal", Vector3(sx * 0.06, 0.04, 0.1), Vector3.ZERO, 1.0, head)
	_prim(_cyl(0.03, 0.07, 0.5, 5), "wolf", Vector3(0, 0.6, -0.68), Vector3(-140, 0, 0), 1.0, b, "Tail")
	_save("wolf")


func _bear() -> void:
	_begin("bear")
	_root.set_script(ANIMAL)
	var b := _quadruped(0.42, 1.55, 0.5, 0.13, "wood_dark", "wood")
	var head := _group("Head", Vector3(0, 1.1, 0.95), 0.0, b)
	_prim(_sphere(0.28, 7, 4), "wood_dark", Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.05), head)
	_prim(_cyl(0.09, 0.14, 0.22, 6), "wood", Vector3(0, -0.06, 0.26), Vector3(90, 0, 0), 1.0, head)
	_prim(_sphere(0.04, 5, 3), "charcoal", Vector3(0, -0.04, 0.38), Vector3.ZERO, 1.0, head)
	for sx in [-1.0, 1.0]:
		_prim(_sphere(0.08, 5, 3), "wood_dark", Vector3(sx * 0.18, 0.22, -0.04), Vector3.ZERO, Vector3(1, 1, 0.6), head)
	_save("bear")


# ------------------------------------------------------------------ farm animals (Quaternius Farm Animals, rigged)

func _farm_animal(scene_name: String, path: String, s: float) -> void:
	_begin(scene_name)
	_root.set_script(ANIMAL)
	var m := _model(path, Vector3.ZERO, Vector3.ZERO, s)
	m.name = "Model"
	_save(scene_name)


# ------------------------------------------------------------------ Era 2 (Quaternius Medieval Village MegaKit)
# Wall modules are 2 m wide and 3.12 m high, outer face toward +Z.

func _wall(module: String, x: float, z: float, rot_y: float) -> void:
	_model(V + module + ".gltf", Vector3(x, 0, z), Vector3(0, rot_y, 0), 1.0)


func _era2_cottage() -> void:
	_begin("era2_cottage")
	_wall("Wall_Plaster_Door_Round", -1, 2, 0)
	_wall("Wall_Plaster_Window_Wide_Round", 1, 2, 0)
	_wall("Wall_Plaster_WoodGrid", -1, -2, 180)
	_wall("Wall_Plaster_Straight", 1, -2, 180)
	_wall("Wall_Plaster_Window_Wide_Round", -2, 1, -90)
	_wall("Wall_Plaster_Straight", -2, -1, -90)
	_wall("Wall_Plaster_Straight", 2, 1, 90)
	_wall("Wall_Plaster_WoodGrid", 2, -1, 90)
	for c in [Vector3(2, 0, 2), Vector3(-2, 0, 2), Vector3(2, 0, -2), Vector3(-2, 0, -2)]:
		_model(V + "Corner_Exterior_Wood.gltf", c, Vector3.ZERO, 1.0)
	_model(V + "Roof_RoundTiles_4x4.gltf", Vector3(0, 3.12, 0), Vector3.ZERO, 1.0)
	_save("era2_cottage")


func _era2_longhouse() -> void:
	_begin("era2_longhouse")
	_wall("Wall_UnevenBrick_Door_Round", -1, 3, 0)
	_wall("Wall_UnevenBrick_Window_Wide_Round", 1, 3, 0)
	_wall("Wall_UnevenBrick_Straight", -1, -3, 180)
	_wall("Wall_UnevenBrick_Straight", 1, -3, 180)
	for z in [-2.0, 0.0, 2.0]:
		_wall("Wall_UnevenBrick_Window_Wide_Round" if z == 0.0 else "Wall_UnevenBrick_Straight", -2, z, -90)
		_wall("Wall_UnevenBrick_Straight" if z == 0.0 else "Wall_UnevenBrick_Window_Wide_Round", 2, z, 90)
	for c in [Vector3(2, 0, 3), Vector3(-2, 0, 3), Vector3(2, 0, -3), Vector3(-2, 0, -3)]:
		_model(V + "Corner_Exterior_Brick.gltf", c, Vector3.ZERO, 1.0)
	_model(V + "Roof_RoundTiles_4x6.gltf", Vector3(0, 3.12, 0), Vector3.ZERO, 1.0)
	_model(V + "Prop_Chimney.gltf", Vector3(1.0, 4.2, -2.0), Vector3.ZERO, 0.8)
	_save("era2_longhouse")


func _era2_shed() -> void:
	_begin("era2_shed")
	for c in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		_model(V + "Corner_Exterior_Wood.gltf", c, Vector3.ZERO, Vector3(1, 0.8, 1))
	_model(V + "Roof_Wooden_2x1.gltf", Vector3(0, 2.4, 0), Vector3.ZERO, 1.0)
	_model(V + "Roof_Wooden_2x1.gltf", Vector3(0, 2.4, 0), Vector3(0, 180, 0), 1.0)
	_model(V + "Prop_Crate.gltf", Vector3(0.3, 0, -0.3), Vector3(0, 15, 0), 0.7)
	_model(V + "Prop_Crate.gltf", Vector3(-0.5, 0, 0.2), Vector3(0, -20, 0), 0.55)
	_save("era2_shed")
