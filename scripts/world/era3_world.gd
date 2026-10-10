class_name Era3World extends Node3D
## The world side of Era 3 (Town), kept out of world.gd:
##   - street lamps along the town street, lit at dusk (and the lighthouse
##     beam, which turns all night)
##   - the town square: a fountain once the aqueduct runs, the town flag once
##     the town loves the hand
##   - the Coast (Calm Waters): its camp and work when it opens, the ship the
##     harbour builds (the hand lifts it off the beach and sets it on the sea),
##     the calm the hand lays on the water so the ship can sail, and the
##     voyage itself (the ship sails out to the island and back)
##   - the northern lights the Guiding Light brings out over the observatory
##   - Lift Buildings: while that power is selected, finished buildings light
##     enough for the hand join the "liftable" group
## Everything one-off is kept in Village.stats so it saves with Village.

const LIGHT_CHECK := 0.5
const CALM_PER_PULSE := 4.0         # seconds of calm sea per Calm Waters pulse
const CALM_MAX := 70.0

var world
var lamps: Array[Node3D] = []
var fountain: Node3D = null
var flag: Node3D = null
var ship: Liftable = null
var calm_t: float = 0.0             # seconds of calm sea left
var calm_mesh: MeshInstance3D = null
var aurora: Node3D = null
var aurora_t: float = 0.0
var _acc: float = 0.0
var _lifting: Dictionary = {}       # Site -> true while in the liftable group

func setup(w) -> void:
	world = w
	name = "Era3World"
	_build_lamps()
	_build_calm()
	_build_aurora()
	reset()

# ================================================================ regions

func on_region_opened(id: StringName, instant: bool) -> void:
	if instant:
		return
	populate(id)

## Spawns a region's work and its camp, once.
func populate(id: StringName) -> int:
	if not LayoutEra3.REGION_JOBS.has(id) and not LayoutEra3.CAMPS.has(id):
		return 0
	var key := "populated_%s" % id
	if Village.stats.get(key, false):
		return 0
	Village.stats[key] = true
	var n := 0
	for row in LayoutEra3.REGION_JOBS.get(id, []):
		if world.spawn_site(row[0], Vector3(row[1], 0, row[2])) != null:
			n += 1
	if LayoutEra3.CAMPS.has(id):
		var c: Vector2 = LayoutEra3.CAMPS[id]
		var camp: Site = world.spawn_plot(&"camp", Vector3(c.x, 0, c.y))
		if camp != null:
			camp._finish(true)
			n += 1
	return n

# ================================================================ lamps and square

func _build_lamps() -> void:
	for i in LayoutEra3.LAMPS.size():
		var l := AssetCatalog.instance(&"street_lamp", i)
		l.name = "Lamp%d" % i
		add_child(l)
		lamps.append(l)

func _place_props() -> void:
	var on := Village.era >= 3
	for i in lamps.size():
		lamps[i].visible = on
		lamps[i].position = world._v3(LayoutEra3.LAMPS[i])
	_set_fountain(on and Flags.has(&"clean_water"))
	_set_flag(on and Flags.has(&"town_flag"))

func _set_fountain(on: bool) -> void:
	if on and fountain == null and AssetCatalog.has(&"fountain"):
		fountain = AssetCatalog.instance(&"fountain")
		fountain.name = "Fountain"
		add_child(fountain)
		fountain.position = world._v3(LayoutEra3.FOUNTAIN)
		world.nav.set_box_obstacle("fountain", fountain.position, Vector2(3.6, 3.6), 0.0)
	if fountain != null:
		fountain.visible = on

func _set_flag(on: bool) -> void:
	if on and flag == null and AssetCatalog.has(&"town_flag"):
		flag = AssetCatalog.instance(&"town_flag")
		flag.name = "TownFlag"
		add_child(flag)
		flag.position = world._v3(LayoutEra3.FLAG)
	if flag != null:
		flag.visible = on

## The aqueduct is running: water in the square.
func water_arrives() -> void:
	_set_fountain(true)
	world.nav.rebake()

func raise_flag() -> void:
	_set_flag(true)

static func night_lights() -> bool:
	return Clock.is_night or Clock.phase_t > Clock.day_seconds - 8.0

func _update_lights() -> void:
	var on := night_lights() and Village.era >= 3
	for l in lamps:
		var light := l.find_child("Light", true, false) as Light3D
		if light != null:
			light.visible = on
	for s in Village.sites:
		if not is_instance_valid(s) or s.building == null or s.state != Site.State.FINISHED:
			continue
		if s.building.id == &"lighthouse" and s.visual != null:
			var beam := s.visual.find_child("BeamLight", true, false) as Light3D
			if beam != null:
				beam.visible = on
			var b2: Node = s.visual.find_child("Beam", true, false)
			if b2 != null and "spinning" in b2:
				b2.set("spinning", on)

# ================================================================ the ship and the calm sea

func _build_calm() -> void:
	calm_mesh = MeshInstance3D.new()
	calm_mesh.name = "CalmSea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(220, 220)
	calm_mesh.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.92, 1.0, 0.0)
	calm_mesh.material_override = m
	calm_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	calm_mesh.visible = false
	add_child(calm_mesh)

## A Calm Waters pulse over the sea (or anywhere on open water).
func calm(at: Vector3) -> void:
	calm_t = minf(calm_t + CALM_PER_PULSE, CALM_MAX)
	Village.stats["calm_pulses"] = int(Village.stats.get("calm_pulses", 0)) + 1
	if calm_mesh != null:
		calm_mesh.position = Vector3(at.x, Valley.SEA_LEVEL + 0.08, at.z)

func sea_calm() -> bool:
	return calm_t > 0.0

func _make_ship() -> void:
	if ship != null:
		return
	ship = Liftable.new()
	ship.name = "Ship"
	ship.kind = &"ship"
	ship.label = "The ship (set it on the sea)"
	ship.weight = LayoutEra3.SHIP_WEIGHT
	ship.length = 10.0
	var v := AssetCatalog.instance(&"ship_small")
	v.name = "Visual"
	ship.add_child(v)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 3.0, 10.0)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	body.add_child(cs)
	ship.add_child(body)
	add_child(ship)
	ship.placed.connect(_on_ship_placed)
	ship.visible = false

## The harbour is finished: the ship waits on the beach for the hand.
func ship_on_beach() -> void:
	_make_ship()
	ship.visible = true
	ship.position = world._v3(LayoutEra3.SHIP_BEACH)
	ship.rotation.y = -2.4981
	if not ship.is_in_group(&"liftable"):
		ship.add_to_group(&"liftable")

func ship_launched() -> bool:
	return Flags.has(&"ship")

func _on_ship_placed(at: Vector3) -> void:
	if not world.is_water(at) or world.valley.ground_y(at.x, at.z) > Valley.SEA_LEVEL - 0.3:
		Events.alert.emit("The ship needs deep water: set it down on the sea", at)
		return
	ship.global_position = Vector3(at.x, Valley.SEA_LEVEL - 0.25, at.z)
	if Flags.set_flag(&"ship"):
		ship.remove_from_group(&"liftable")
		Flags.remember("The hand lifted our ship off the beach and set it on the sea. It floated!")
		Events.alert.emit("The ship floats! Now they can fish from it, and sail to the islands when the hand calms the sea", ship.global_position)
		Faith.add(10.0, ship.global_position)
		Village.stats["ship_at"] = [ship.global_position.x, ship.global_position.z]

## Where the ship rides when nobody sails it.
func _ship_home() -> Vector3:
	var a: Array = Village.stats.get("ship_at", [])
	var p := LayoutEra3.SHIP_ANCHOR if a.size() < 2 else Vector2(float(a[0]), float(a[1]))
	return Vector3(p.x, Valley.SEA_LEVEL - 0.25, p.y)

## Moves the ship along its voyage (0 at anchor, 0.5 at the island, 1 home).
func _sail_ship() -> void:
	if ship == null or not ship_launched():
		return
	var voyage: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"sail_islands" and not s.is_plot():
			voyage = s
			break
	var home := _ship_home()
	var isl := Vector3(LayoutEra3.ISLAND.x - 28.0, Valley.SEA_LEVEL - 0.25, LayoutEra3.ISLAND.y - 10.0)
	var k := 0.0
	if voyage != null and (voyage.group_running or voyage.progress > 0.0):
		k = voyage.progress
	var leg := 1.0 - absf(1.0 - 2.0 * k)        # 0 -> 1 -> 0
	var p := home.lerp(isl, leg)
	var dir := (isl - home) * (1.0 if k < 0.5 else -1.0)
	ship.global_position = p
	if dir.length() > 0.1 and k > 0.0:
		ship.rotation.y = atan2(dir.x, dir.z) + PI

# ================================================================ the northern lights

func _build_aurora() -> void:
	aurora = Node3D.new()
	aurora.name = "NorthernLights"
	add_child(aurora)
	var cols := [Color(0.3, 1.0, 0.6, 0.0), Color(0.4, 0.8, 1.0, 0.0), Color(0.8, 0.5, 1.0, 0.0)]
	for i in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(420.0 - i * 60.0, 70.0 - i * 12.0)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = cols[i]
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(i * 40.0 - 40.0, 150.0 + i * 18.0, -i * 30.0)
		mi.rotation = Vector3(-0.35, 0.15 * (i - 1), 0)
		aurora.add_child(mi)
	aurora.position = Vector3(250, 0, -330)
	aurora.visible = false

## The Guiding Light at night: the sky over the observatory lights up.
func northern_lights(seconds: float = 20.0) -> void:
	aurora_t = maxf(aurora_t, seconds)
	aurora.visible = true

func _update_aurora(dt: float) -> void:
	if aurora_t <= 0.0 and not aurora.visible:
		return
	aurora_t = maxf(aurora_t - dt, 0.0)
	var a := clampf(aurora_t / 4.0, 0.0, 1.0) * (0.35 if Clock.is_night else 0.08)
	var i := 0
	for mi in aurora.get_children():
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		var c := m.albedo_color
		c.a = a * (1.0 - i * 0.2) * (0.8 + 0.2 * sin(Clock.total_t * 0.7 + i))
		m.albedo_color = c
		i += 1
	if aurora_t <= 0.0:
		aurora.visible = false

# ================================================================ lift buildings

## Lift Buildings is selected: finished buildings light enough join the
## liftable group, so the hand can pick them up and set them down elsewhere.
func _sync_lift_mode() -> void:
	var hand = world.get("hand")
	var on: bool = Faith.has(&"lift_buildings") and hand != null and is_instance_valid(hand) and hand.get("selected_power") == &"lift_buildings"
	for s in _lifting.keys():
		if not is_instance_valid(s) or not on or s.lift_held:
			if is_instance_valid(s) and not s.lift_held:
				s.remove_from_group(&"liftable")
			if not is_instance_valid(s) or not s.lift_held:
				_lifting.erase(s)
	if not on:
		return
	for s in Village.sites:
		if is_instance_valid(s) and s.can_be_lifted() and not _lifting.has(s):
			s.add_to_group(&"liftable")
			_lifting[s] = true

# ================================================================ frame

func _process(delta: float) -> void:
	if not Clock.running:
		return
	if calm_t > 0.0:
		calm_t = maxf(calm_t - delta, 0.0)
	if calm_mesh != null:
		var want := calm_t > 0.0 and Village.era >= 3
		calm_mesh.visible = want
		if want:
			var m := calm_mesh.material_override as StandardMaterial3D
			m.albedo_color.a = clampf(calm_t / 10.0, 0.0, 1.0) * 0.18
	_update_aurora(delta)
	_sail_ship()
	_acc += delta
	if _acc < LIGHT_CHECK:
		return
	_acc = 0.0
	if Village.era >= 3:
		_update_lights()
		_sync_lift_mode()

# ================================================================ state

func reset() -> void:
	calm_t = 0.0
	aurora_t = 0.0
	if aurora != null:
		aurora.visible = false
	if ship != null:
		ship.visible = false
		ship.remove_from_group(&"liftable")
	for s in _lifting.keys():
		if is_instance_valid(s):
			s.remove_from_group(&"liftable")
	_lifting.clear()
	if fountain != null:
		fountain.visible = false
	if flag != null:
		flag.visible = false
	for l in lamps:
		l.visible = false

## After a load or an era change: the square, the ship, the lamps.
func refresh() -> void:
	_place_props()
	if Village.era < 3:
		return
	if Village.count_buildings(&"harbour") > 0:
		if ship_launched():
			_make_ship()
			ship.visible = true
			ship.remove_from_group(&"liftable")
			ship.global_position = _ship_home()
		else:
			ship_on_beach()
	_update_lights()

func save_state() -> Dictionary:
	var d := {"calm": calm_t}
	if ship != null and ship.visible and not ship_launched():
		d["ship"] = ship.save_state()
	return d

func load_state(d: Dictionary) -> void:
	reset()
	calm_t = float(d.get("calm", 0.0))
	refresh()
	if d.has("ship") and ship != null and not ship_launched():
		ship.load_state(d["ship"])
