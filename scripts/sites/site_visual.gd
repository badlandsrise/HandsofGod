class_name SiteVisual extends Node3D
## The look of a Site, from the art catalog (scripts/assets/asset_catalog.gd).
## The Site puts the result under its child named "Visual". Huts go through their
## build stages (hut_plot, hut_frame, hut); other buildings rise out of their plot.
## Slot pips and hover rings are drawn by the hand.

## BuildingDef id -> catalog id, when the names differ.
const BUILDING_ART := {&"granary": &"food_store", &"cottage": &"era2_cottage", &"temple": &"shrine"}

var site: Site = null
var _fill_nodes: Array[Node3D] = []   # berries, sticks, deer: shown in proportion to amount
var _flame: Node3D = null             # the campfire's Fire node (flicker.gd)
var _rising: Node3D = null            # building model that grows with build progress
var _rising_h := 1.0

static func make(s: Site) -> SiteVisual:
	var v := SiteVisual.new()
	v.site = s
	var seed_v := absi(hash(Vector2i(roundi(s.position.x * 10.0), roundi(s.position.z * 10.0))))
	if s.building != null and s.building.scene != null and s.state == Site.State.FINISHED:
		v.add_child(s.building.scene.instantiate())
		return v
	if s.is_plot():
		v._plot(s, seed_v)
	elif s.building != null:
		v._building(s.building.id, s.building.footprint, seed_v)
	elif s.job != null:
		v._job(s.job.id, seed_v)
	v.rotation.y = 0.0
	return v

func set_fill(f: float) -> void:
	var n := _fill_nodes.size()
	for i in n:
		if is_instance_valid(_fill_nodes[i]):
			_fill_nodes[i].visible = float(i) < f * float(n) - 0.01

func _process(_dt: float) -> void:
	if site == null or not is_instance_valid(site):
		return
	if _flame != null:
		var on := site.lit()
		if _flame.visible != on:
			_flame.set("burning", on)
	if _rising != null and site.state == Site.State.BUILDING:
		var p := site.build_progress()
		_rising.scale = Vector3(1.0, lerpf(0.15, 1.0, p), 1.0)

# ---------------------------------------------------------------- helpers

func _art(id: StringName, variant: int = 0, pos := Vector3.ZERO, yaw := 0.0, s := 1.0) -> Node3D:
	var n := AssetCatalog.instance(id, variant)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	add_child(n)
	return n

func _ball(r: float, mat: Material, pos: Vector3, segs := 6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = segs; sm.rings = maxi(segs / 2, 3)
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _stick(mat: Material, pos: Vector3, yaw: float, len_m: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 0.035; cy.bottom_radius = 0.045; cy.height = len_m; cy.radial_segments = 5; cy.rings = 1
	mi.mesh = cy
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(0, yaw, PI * 0.5)
	add_child(mi)
	return mi

# ---------------------------------------------------------------- jobs

func _job(id: StringName, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match id:
		&"gather_berries":
			_art(&"berry_bush", seed_v, Vector3.ZERO, rng.randf() * TAU, 1.15)
			var berry := ArtPalette.material("berry")
			for i in 9:
				var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
				var h := rng.randf_range(0.55, 1.25)
				var r := 0.82 * sqrt(maxf(0.0, 1.0 - pow((h - 0.7) / 0.8, 2.0)))
				_fill_nodes.append(_ball(0.09, berry, Vector3(cos(a) * r, h, sin(a) * r), 5))
		&"fetch_water", &"fish_by_hand":
			for i in 3:
				var a := rng.randf() * TAU
				_art(&"rock_small", i + seed_v, Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.3, 1.9), rng.randf() * TAU, rng.randf_range(0.7, 1.2))
			if id == &"fish_by_hand":
				_art(&"fish", seed_v, Vector3(0.8, 0.05, 0.6), rng.randf() * TAU)
		&"collect_sticks":
			_art(&"stump", seed_v, Vector3(0.2, 0, -0.3), rng.randf() * TAU)
			_art(&"fern", seed_v, Vector3(-0.9, 0, 0.4), rng.randf() * TAU)
			var wood := ArtPalette.material("wood")
			for i in 10:
				var a := TAU * i / 10.0 + rng.randf_range(-0.2, 0.2)
				_fill_nodes.append(_stick(wood, Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 1.3) + Vector3(0, 0.05, 0), rng.randf() * TAU, rng.randf_range(0.6, 1.0)))
		&"fell_tree":
			_art(&"tree_pine" if seed_v % 2 == 0 else &"tree_broad", seed_v, Vector3.ZERO, rng.randf() * TAU, rng.randf_range(1.5, 1.8))
			_art(&"tool_axe", 0, Vector3(1.2, 0.0, 0.6), 0.6)
		&"knap_flint":
			_art(&"flint_node", seed_v, Vector3.ZERO, rng.randf() * TAU)
		&"tend_fire":
			var fire := _art(&"campfire", 0, Vector3.ZERO, 0.0, 1.25)
			# The world's FirePit owns the firelight; keep only the flames here.
			for l in fire.find_children("*", "OmniLight3D", true, false):
				l.queue_free()
			_flame = fire.find_child("Fire", true, false) as Node3D
			for i in 3:
				var a := TAU * i / 3.0 + 0.5
				_art(&"log_fallen", i, Vector3(cos(a), 0, sin(a)) * 2.7, -a + PI * 0.5, 0.5)
		&"carry_log":
			_art(&"log_fallen", seed_v, Vector3.ZERO, 0.0, 0.85)
		&"haul_log":
			pass    # the world's fallen trunk (a Blocker) is the visual and rolls with the haulers
		&"hunt":
			for i in 3:
				var a := TAU * i / 3.0 + rng.randf_range(-0.3, 0.3)
				_fill_nodes.append(_art(&"deer", i, Vector3(cos(a), 0, sin(a)) * 2.2, rng.randf() * TAU))
		&"pray":
			_art(&"cairn", 0)
		_:
			_art(&"rock_small", seed_v)

# ---------------------------------------------------------------- buildings

func _art_id(bid: StringName) -> StringName:
	var id: StringName = BUILDING_ART.get(bid, bid)
	return id if AssetCatalog.has(id) else &""

func _plot(s: Site, seed_v: int) -> void:
	var fp := s.building.footprint
	var span := maxf(fp.x, fp.y)
	if s.state == Site.State.BUILDING and s.building.id == &"hut":
		_art(&"hut_frame", 0)
	else:
		var k := maxf(span / 4.0, 0.75)
		_art(&"hut_plot", 0, Vector3.ZERO, 0.0, k)
		if s.state == Site.State.BUILDING:
			var id := _art_id(s.building.id)
			if id != &"":
				_rising = _art(id, seed_v, Vector3.ZERO, 0.0, _fit(id, fp))
				_rising.scale.y = lerpf(0.15, 1.0, s.build_progress())
	# Material piles grow as builders deliver.
	var i := 0
	for k in s.building.cost:
		var got := int(s.delivered.get(k, 0))
		var need := maxi(int(s.building.cost[k]), 1)
		if got > 0:
			var f := clampf(float(got) / float(need), 0.15, 1.0)
			var at := Vector3(span * 0.5 + 0.8, 0, -span * 0.25 + i * 1.6)
			if k == &"wood":
				_art(&"firewood_pile", 0, at, 0.3, lerpf(0.45, 0.9, f))
			else:
				_art(&"rock_small", i, at, 0.0, lerpf(0.8, 1.6, f))
		i += 1

## Scale that fits a catalog model into a building's footprint (never above 1.15).
func _fit(id: StringName, fp: Vector2) -> float:
	var cf := AssetCatalog.footprint(id)
	var k := minf(fp.x / maxf(cf.x, 0.1), fp.y / maxf(cf.y, 0.1))
	return clampf(k, 0.6, 1.15) if k < 1.0 else 1.0

func _building(bid: StringName, fp: Vector2, seed_v: int) -> void:
	match bid:
		&"fire_circle":
			var fire := _art(&"campfire", 0, Vector3.ZERO, 0.0, 1.4)
			_flame = fire.find_child("Fire", true, false) as Node3D
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				_art(&"log_fallen", i, Vector3(cos(a), 0, sin(a)) * 2.6, -a + PI * 0.5, 0.55)
			return
		&"hut":
			_art(&"hut", seed_v, Vector3.ZERO, 0.0)
			return
	var id := _art_id(bid)
	if id != &"":
		_art(id, seed_v, Vector3.ZERO, 0.0, _fit(id, fp))
	else:
		_art(&"hut_plot", 0, Vector3.ZERO, 0.0, maxf(fp.x, fp.y) / 4.0)
