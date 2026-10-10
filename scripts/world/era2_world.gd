class_name Era2World extends Node3D
## The world side of Era 2 (Village), kept out of world.gd:
##   - what a new region holds when it opens (LayoutEra2.REGION_JOBS, a camp,
##     the dry fields of the Southern Plains)
##   - the rockfall that closes the Hill Quarry: three boulders the hand lifts
##     once it has Strength II; the quarry opens when they are clear
##   - the great bridge: once built, its deck is walkable ground (ground_y and
##     navmesh faces) from the Valley Floor to the East Bank
##   - the flood water, raised over the river banks while a flood runs

const FLOOD_ZONE := 30.0          # metres either side of the river the flood reaches
const DECK_HALF_W := 1.7
const DECK_HALF_L := 9.0
const DECK_RAMP := 2.5

var world
var boulders: Array[Liftable] = []
var rockfall: Node3D = null
var flood_mesh: MeshInstance3D = null
var flood_k: float = 0.0           # 0..1 how high the flood water stands
var _bridge: Site = null
var _bridge_base: float = 0.0
var _bridge_check_t: float = 0.0

func setup(w) -> void:
	world = w
	name = "Era2World"
	_build_rockfall()
	_build_flood()
	Events.building_finished.connect(_on_building_finished)
	reset()

# ================================================================ regions

## A region just opened (not on load: the saved sites come back by themselves).
func on_region_opened(id: StringName, instant: bool) -> void:
	if instant:
		return
	populate(id)

## Spawns a region's work, its camp and (on the plains) its fields, once.
func populate(id: StringName) -> int:
	if not LayoutEra2.REGION_JOBS.has(id) and not LayoutEra2.CAMPS.has(id):
		return 0
	var key := "populated_%s" % id
	if Village.stats.get(key, false):
		return 0
	Village.stats[key] = true
	var n := 0
	for row in LayoutEra2.REGION_JOBS.get(id, []):
		if world.spawn_site(row[0], Vector3(row[1], 0, row[2])) != null:
			n += 1
	if LayoutEra2.CAMPS.has(id):
		var c: Vector2 = LayoutEra2.CAMPS[id]
		var camp: Site = world.spawn_plot(&"camp", Vector3(c.x, 0, c.y))
		if camp != null:
			camp._finish(true)
			n += 1
	if id == &"southern_plains":
		for spot in LayoutEra2.PLAINS_FIELDS:
			var f: Site = world.spawn_plot(&"field", Vector3(spot.x, 0, spot.y))
			if f != null:
				f.dry_land = true
				n += 1
	return n

# ================================================================ rockfall

func _build_rockfall() -> void:
	rockfall = Node3D.new()
	rockfall.name = "Rockfall"
	add_child(rockfall)
	if AssetCatalog.has(&"rockfall"):
		var art := AssetCatalog.instance(&"rockfall")
		art.name = "Visual"
		art.rotation.y = PI * 0.5      # lies across the way into the quarry (north-south)
		rockfall.add_child(art)
	for i in LayoutEra2.BOULDERS.size():
		var b := Liftable.new()
		b.name = "Boulder%d" % (i + 1)
		b.kind = &"boulder"
		b.label = "Boulder"
		b.weight = LayoutEra2.BOULDER_WEIGHT
		b.length = 3.0
		var v := AssetCatalog.instance(&"rock_large", i + 1)
		v.name = "Visual"
		v.scale = Vector3.ONE * 0.75
		b.add_child(v)
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 2
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.6, 2.2, 2.6)
		cs.shape = box
		cs.position = Vector3(0, 1.1, 0)
		body.add_child(cs)
		b.add_child(body)
		add_child(b)
		b.placed.connect(_on_boulder_placed)
		boulders.append(b)

func _reset_rockfall() -> void:
	rockfall.position = world._v3(LayoutEra2.ROCKFALL)
	rockfall.scale = Vector3.ONE
	rockfall.visible = true
	for i in boulders.size():
		var b := boulders[i]
		b.position = world._v3(LayoutEra2.BOULDERS[i], 0.6)
		b.rotation = Vector3(0, i * 1.3, 0)
		b.moved_count = 0
		b.held = false
	_shape_rockfall()

func boulders_clear() -> int:
	var n := 0
	for b in boulders:
		if b.held:
			continue
		var p := Vector2(b.global_position.x, b.global_position.z)
		if p.distance_to(LayoutEra2.ROCKFALL) >= LayoutEra2.ROCKFALL_CLEAR:
			n += 1
	return n

func rockfall_cleared() -> bool:
	return boulders_clear() >= boulders.size()

func _on_boulder_placed(_at: Vector3) -> void:
	_shape_rockfall()
	Village.stats["boulders_moved"] = boulders_clear()
	if rockfall_cleared() and not world.is_region_open(&"hill_quarry"):
		world.open_region(&"hill_quarry")
		Events.alert.emit("The way to the hill quarry is open", world._v3(LayoutEra2.ROCKFALL))
		Flags.remember("The hand rolled the rockfall aside, and the hill quarry opened to us")

## The scree shrinks with each boulder moved; once clear only a low spill is left.
func _shape_rockfall() -> void:
	var left := boulders.size() - boulders_clear()
	var k := float(left) / maxf(boulders.size(), 1)
	rockfall.scale = Vector3(1.0, lerpf(0.25, 1.0, k), lerpf(0.55, 1.0, k))

# ================================================================ bridge

func _on_building_finished(site) -> void:
	if is_instance_valid(site) and site.building != null and site.building.id == &"bridge":
		_set_bridge(site)
		world.nav.rebake()

func _find_bridge() -> void:
	_bridge = null
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == &"bridge" and s.state == Site.State.FINISHED:
			_set_bridge(s)
			return
	world.nav.extra_faces = deck_faces()

func _set_bridge(s: Site) -> void:
	_bridge = s
	var c := s.global_position
	_bridge_base = bank_height(Vector2(c.x, c.z))
	world.nav.extra_faces = deck_faces()

func bridge_built() -> bool:
	return _bridge != null and is_instance_valid(_bridge) and _bridge.state == Site.State.FINISHED

## The banks either end of the bridge, which the deck rests on.
func bank_height(c: Vector2) -> float:
	var v: Valley = world.valley
	return maxf(v.ground_y(c.x, c.y - DECK_HALF_L - 0.5), v.ground_y(c.x, c.y + DECK_HALF_L + 0.5))

## Deck height (world) at x,z, or -INF off every bridge (the great bridge
## once built, and the people's footbridges: add_crossing).
func deck_y(x: float, z: float) -> float:
	var y := _great_deck_y(x, z)
	for d in _crossings.values():
		y = maxf(y, _crossing_y(d, x, z))
	return y

func _great_deck_y(x: float, z: float) -> float:
	if _bridge == null:
		return -INF
	if not is_instance_valid(_bridge):
		_bridge = null
		return -INF
	var c := _bridge.global_position
	var lat := absf(x - c.x)
	var l := absf(z - c.z)
	if lat > DECK_HALF_W or l > DECK_HALF_L + DECK_RAMP:
		return -INF
	if l <= DECK_HALF_L:
		return _bridge_base + 0.5 + 1.1 * (1.0 - pow(l / DECK_HALF_L, 2.0)) + 0.06
	var t := (l - DECK_HALF_L) / DECK_RAMP
	return lerpf(_bridge_base + 0.56, world.valley.ground_y(x, z), t)

# ================================================================ crossings

## The people's footbridges over the great river (a crossing joins the far
## bank to the village: World.add_crossing). id -> {x, z, half_l, half_w, base}.
var _crossings: Dictionary = {}
const CROSSING_HALF_W := 1.25
const CROSSING_RAMP := 2.0

## A walkable footbridge deck across the river at `c` (north-south), as long
## as the water there is wide (plus a metre onto each bank).
func add_crossing(id: StringName, c: Vector2) -> void:
	var v: Valley = world.valley
	var n := 0.0
	while n < 30.0 and v.is_water(c.x, c.y - n):
		n += 0.5
	var sth := 0.0
	while sth < 30.0 and v.is_water(c.x, c.y + sth):
		sth += 0.5
	var z0 := c.y - n - 1.0
	var z1 := c.y + sth + 1.0
	var mid := (z0 + z1) * 0.5
	var base := maxf(v.ground_y(c.x, z0), v.ground_y(c.x, z1))
	base = maxf(base, Valley.river_level(c.x) + 0.45)
	_crossings[id] = {"x": c.x, "z": mid, "half_l": (z1 - z0) * 0.5, "half_w": CROSSING_HALF_W, "base": base}
	world.nav.extra_faces = deck_faces()

func has_crossing(id: StringName) -> bool:
	return _crossings.has(id)

func crossing_ids() -> Array:
	return _crossings.keys()

func _crossing_y(d: Dictionary, x: float, z: float) -> float:
	var lat := absf(x - float(d["x"]))
	var l := absf(z - float(d["z"]))
	var hl: float = d["half_l"]
	if lat > float(d["half_w"]) or l > hl + CROSSING_RAMP:
		return -INF
	var top := float(d["base"]) + 0.3 + 0.4 * (1.0 - pow(minf(l / hl, 1.0), 2.0))
	if l <= hl:
		return top
	return lerpf(float(d["base"]) + 0.3, world.valley.ground_y(x, z), (l - hl) / CROSSING_RAMP)

func _crossing_faces(d: Dictionary) -> PackedVector3Array:
	var f := PackedVector3Array()
	var len: float = float(d["half_l"]) + CROSSING_RAMP
	var steps := 20
	var xa: float = float(d["x"]) - float(d["half_w"])
	var xb: float = float(d["x"]) + float(d["half_w"])
	for i in steps:
		var z0: float = float(d["z"]) - len + 2.0 * len * i / steps
		var z1: float = float(d["z"]) - len + 2.0 * len * (i + 1) / steps
		var a := Vector3(xa, _crossing_y(d, xa, z0), z0)
		var b := Vector3(xb, _crossing_y(d, xb, z0), z0)
		var cc := Vector3(xa, _crossing_y(d, xa, z1), z1)
		var dd := Vector3(xb, _crossing_y(d, xb, z1), z1)
		f.append_array([a, b, cc, b, dd, cc])
	return f

## Walkable triangles along every deck for the navmesh bake.
func deck_faces() -> PackedVector3Array:
	var f := _great_deck_faces()
	for d in _crossings.values():
		f.append_array(_crossing_faces(d))
	return f

func _great_deck_faces() -> PackedVector3Array:
	var f := PackedVector3Array()
	if _bridge == null:
		return f
	var c := _bridge.global_position
	var steps := 24
	var len := DECK_HALF_L + DECK_RAMP
	for i in steps:
		var z0 := c.z - len + 2.0 * len * i / steps
		var z1 := c.z - len + 2.0 * len * (i + 1) / steps
		var xa := c.x - DECK_HALF_W
		var xb := c.x + DECK_HALF_W
		var a := Vector3(xa, _great_deck_y(xa, z0), z0)
		var b := Vector3(xb, _great_deck_y(xb, z0), z0)
		var cc := Vector3(xa, _great_deck_y(xa, z1), z1)
		var d := Vector3(xb, _great_deck_y(xb, z1), z1)
		f.append_array([a, b, cc, b, d, cc])
	return f

# ================================================================ flood

func _build_flood() -> void:
	flood_mesh = MeshInstance3D.new()
	flood_mesh.name = "FloodWater"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -130.0
	var x1 := 230.0
	var n := 72
	for i in n:
		var xa := lerpf(x0, x1, float(i) / n)
		var xb := lerpf(x0, x1, float(i + 1) / n)
		var za := Valley.river_z(xa)
		var zb := Valley.river_z(xb)
		var q := [Vector3(xa, 0, za - FLOOD_ZONE), Vector3(xb, 0, zb - FLOOD_ZONE), Vector3(xb, 0, zb + FLOOD_ZONE), Vector3(xa, 0, za + FLOOD_ZONE)]
		for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	flood_mesh.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.42, 0.33, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	flood_mesh.material_override = m
	flood_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flood_mesh.visible = false
	add_child(flood_mesh)

## Raises the flood water (k 0..1): from the river's surface up over the low banks.
func set_flood(k: float) -> void:
	flood_k = clampf(k, 0.0, 1.0)
	flood_mesh.visible = flood_k > 0.01
	flood_mesh.position.y = lerpf(1.2, 3.6, flood_k)

## True when `p` is under the flood water now.
func flooded(p: Vector3) -> bool:
	if flood_k <= 0.05:
		return false
	if absf(p.z - Valley.river_z(p.x)) > FLOOD_ZONE or p.x < -130.0 or p.x > 230.0:
		return false
	return world.valley.ground_y(p.x, p.z) < flood_mesh.position.y - 0.1

## Is `p` in the flood's reach at all (for warnings and the bot)?
static func in_flood_zone(p: Vector3) -> bool:
	return absf(p.z - Valley.river_z(p.x)) < FLOOD_ZONE * 0.9 and p.x > -130.0 and p.x < 230.0

# ================================================================ state

func reset() -> void:
	_reset_rockfall()
	set_flood(0.0)
	_bridge = null
	_crossings.clear()
	if world.nav:
		world.nav.extra_faces = PackedVector3Array()

## After a load or an era change: find the bridge among the restored sites.
func refresh() -> void:
	_find_bridge()
	_shape_rockfall()
	if world.is_region_open(&"hill_quarry"):
		rockfall.scale = Vector3(1.0, 0.25, 0.55)

func save_state() -> Dictionary:
	var b: Array = []
	for x in boulders:
		b.append(x.save_state())
	return {"boulders": b, "flood": flood_k}

func load_state(d: Dictionary) -> void:
	reset()
	var b: Array = d.get("boulders", [])
	for i in mini(b.size(), boulders.size()):
		boulders[i].load_state(b[i])
	set_flood(float(d.get("flood", 0.0)))
	refresh()
