class_name SiteVisual extends Node3D
## Placeholder low-poly visuals for sites, built from primitives. The Site
## puts the result under its child named "Visual"; real art replaces it.
## (Slot pips and hover rings are drawn by the hand.)

var _fill_nodes: Array[Node3D] = []   # berries, sticks: shown in proportion to amount

static func make(s: Site) -> SiteVisual:
	var v := SiteVisual.new()
	if s.building != null and s.building.scene != null and s.state == Site.State.FINISHED:
		v.add_child(s.building.scene.instantiate())
		return v
	if s.is_plot():
		v._plot(s)
	elif s.building != null:
		v._building(s.building.id, s.building.footprint)
	elif s.job != null:
		v._job(s.job.id)
	return v

func set_fill(f: float) -> void:
	var n := _fill_nodes.size()
	for i in n:
		if is_instance_valid(_fill_nodes[i]):
			_fill_nodes[i].visible = float(i) < f * float(n) - 0.01

func _m(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m

func _mesh(mesh: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _m(c)
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi

func _box(size: Vector3, c: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return _mesh(b, c, pos, rot)

func _ball(r: float, c: Color, pos: Vector3, segs := 8) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = segs; s.rings = maxi(segs / 2, 3)
	return _mesh(s, c, pos)

func _cyl(r_top: float, r_bot: float, h: float, c: Color, pos: Vector3, segs := 8, rot := Vector3.ZERO) -> MeshInstance3D:
	var cy := CylinderMesh.new(); cy.top_radius = r_top; cy.bottom_radius = r_bot; cy.height = h; cy.radial_segments = segs; cy.rings = 1
	return _mesh(cy, c, pos, rot)

func _job(id: StringName) -> void:
	match id:
		&"gather_berries":
			_ball(0.7, Color(0.2, 0.45, 0.2), Vector3(0, 0.55, 0), 7)
			_ball(0.5, Color(0.25, 0.5, 0.22), Vector3(0.45, 0.4, 0.2), 6)
			for i in 8:
				var a := TAU * i / 8.0
				_fill_nodes.append(_ball(0.1, Color(0.8, 0.12, 0.25), Vector3(cos(a) * 0.62, 0.5 + 0.25 * sin(i * 1.7), sin(a) * 0.62), 5))
		&"fetch_water", &"fish_by_hand":
			_cyl(1.9, 1.9, 0.06, Color(0.25, 0.5, 0.85), Vector3(0, 0.03, 0), 12)
			if id == &"fish_by_hand":
				_box(Vector3(0.3, 0.08, 0.12), Color(0.75, 0.75, 0.8), Vector3(0.6, 0.1, 0.3))
		&"collect_sticks":
			for i in 10:
				var a := TAU * i / 10.0
				_fill_nodes.append(_cyl(0.04, 0.04, 0.9, Color(0.45, 0.3, 0.15), Vector3(cos(a) * 0.5, 0.06, sin(a) * 0.5), 4, Vector3(0, a, PI * 0.5)))
			_ball(0.5, Color(0.3, 0.42, 0.2), Vector3(0, 0.3, 0), 6)
		&"fell_tree":
			_cyl(0.18, 0.25, 2.0, Color(0.4, 0.27, 0.15), Vector3(0, 1.0, 0), 6)
			_cyl(0.0, 1.1, 2.4, Color(0.18, 0.4, 0.2), Vector3(0, 2.8, 0), 7)
		&"knap_flint":
			_box(Vector3(1.2, 0.7, 1.0), Color(0.5, 0.5, 0.55), Vector3(0, 0.35, 0), Vector3(0.1, 0.4, 0.05))
			_box(Vector3(0.6, 0.45, 0.6), Color(0.35, 0.35, 0.42), Vector3(0.6, 0.22, 0.3), Vector3(0, 0.9, 0.1))
		&"tend_fire":
			_fire(1.0)
		&"carry_log", &"haul_log":
			var len := 2.6 if id == &"carry_log" else 3.6
			var r := 0.28 if id == &"carry_log" else 0.4
			_cyl(r, r, len, Color(0.42, 0.28, 0.14), Vector3(0, r, 0), 8, Vector3(0, 0, PI * 0.5))
			_cyl(r * 0.8, r * 0.8, 0.02, Color(0.75, 0.6, 0.4), Vector3(len * 0.5 + 0.01, r, 0), 8, Vector3(0, 0, PI * 0.5))
		&"hunt":
			for i in 3:
				var a := TAU * i / 3.0
				var p := Vector3(cos(a), 0, sin(a)) * 0.9
				_fill_nodes.append(_box(Vector3(0.35, 0.45, 0.9), Color(0.55, 0.38, 0.22), p + Vector3(0, 0.7, 0), Vector3(0, a, 0)))
		&"pray":
			_box(Vector3(0.8, 0.5, 0.8), Color(0.55, 0.55, 0.58), Vector3(0, 0.25, 0))
		_:
			_cyl(0.5, 0.6, 0.4, Color(0.6, 0.5, 0.35), Vector3(0, 0.2, 0), 6)

func _fire(scale_f: float) -> void:
	for i in 7:
		var a := TAU * i / 7.0
		_ball(0.18 * scale_f, Color(0.45, 0.45, 0.48), Vector3(cos(a), 0.1, sin(a)) * 0.7 * scale_f, 5)
	var flame := _cyl(0.0, 0.35 * scale_f, 0.8 * scale_f, Color(1.0, 0.55, 0.15), Vector3(0, 0.4 * scale_f, 0), 6)
	(flame.material_override as StandardMaterial3D).emission_enabled = true
	(flame.material_override as StandardMaterial3D).emission = Color(1.0, 0.5, 0.1)
	_fill_nodes.clear()

func _plot(s: Site) -> void:
	var fp := s.building.footprint
	_box(Vector3(fp.x, 0.05, fp.y), Color(0.45, 0.33, 0.2), Vector3(0, 0.025, 0))
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(Vector3(0.1, 0.7, 0.1), Color(0.6, 0.45, 0.25), Vector3(c.x * fp.x * 0.45, 0.35, c.y * fp.y * 0.45))
	# Material piles grow as builders deliver.
	var i := 0
	for k in s.building.cost:
		var got := int(s.delivered.get(k, 0))
		var col := Color(0.5, 0.33, 0.18) if k == &"wood" else Color(0.6, 0.6, 0.62)
		for j in got:
			_box(Vector3(0.25, 0.18, 0.25), col, Vector3(-fp.x * 0.3 + i * 0.6, 0.12 + (j / 3) * 0.18, -fp.y * 0.25 + (j % 3) * 0.27))
		i += 1
	if s.state == Site.State.BUILDING:
		var h := 0.3 + 1.5 * s.build_progress()
		_box(Vector3(fp.x * 0.6, h, fp.y * 0.6), Color(0.6, 0.5, 0.35, 1.0), Vector3(0, h * 0.5, 0))

func _building(id: StringName, fp: Vector2) -> void:
	match id:
		&"hut", &"cottage":
			_cyl(1.3, 1.4, 1.3, Color(0.5, 0.38, 0.25), Vector3(0, 0.65, 0), 8)
			_cyl(0.0, 1.8, 1.4, Color(0.75, 0.62, 0.3), Vector3(0, 2.0, 0), 8)
			_box(Vector3(0.6, 0.9, 0.1), Color(0.15, 0.1, 0.06), Vector3(0, 0.45, 1.33))
		&"fire_circle":
			_fire(1.3)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				_box(Vector3(1.0, 0.3, 0.3), Color(0.4, 0.27, 0.14), Vector3(cos(a), 0.15, sin(a)) * 1.6, Vector3(0, -a, 0))
		&"food_store", &"granary":
			_box(Vector3(fp.x, 1.3, fp.y), Color(0.55, 0.4, 0.22), Vector3(0, 0.75, 0))
			_box(Vector3(fp.x + 0.3, 0.2, fp.y + 0.3), Color(0.75, 0.62, 0.3), Vector3(0, 1.5, 0))
		&"drying_rack":
			_box(Vector3(0.1, 1.2, 0.1), Color(0.45, 0.3, 0.15), Vector3(-0.8, 0.6, 0))
			_box(Vector3(0.1, 1.2, 0.1), Color(0.45, 0.3, 0.15), Vector3(0.8, 0.6, 0))
			_box(Vector3(1.8, 0.08, 0.08), Color(0.45, 0.3, 0.15), Vector3(0, 1.15, 0))
		&"cairn":
			for i in 4:
				_box(Vector3(0.9 - i * 0.18, 0.35, 0.9 - i * 0.18), Color(0.55, 0.55, 0.58), Vector3(0, 0.18 + i * 0.35, 0), Vector3(0, i * 0.5, 0))
			_box(Vector3(0.3, 0.3, 0.05), Color(0.75, 0.35, 0.15), Vector3(0, 0.75, 0.38))
		&"shrine", &"temple":
			_box(Vector3(fp.x, 0.4, fp.y), Color(0.55, 0.55, 0.58), Vector3(0, 0.2, 0))
			_box(Vector3(1.0, 2.0, 0.5), Color(0.6, 0.6, 0.62), Vector3(0, 1.4, 0))
			_box(Vector3(0.5, 0.5, 0.06), Color(0.8, 0.4, 0.15), Vector3(0, 1.8, 0.28))
		&"stone_circle":
			for i in 10:
				var a := TAU * i / 10.0
				_box(Vector3(0.6, 2.4, 0.4), Color(0.55, 0.55, 0.6), Vector3(cos(a), 0, sin(a)) * fp.x * 0.42 + Vector3(0, 1.2, 0), Vector3(0, -a, 0))
			_box(Vector3(1.0, 0.5, 1.0), Color(0.5, 0.5, 0.55), Vector3(0, 0.25, 0))
		_:
			_box(Vector3(fp.x, 1.6, fp.y), Color(0.6, 0.55, 0.5), Vector3(0, 0.8, 0))
