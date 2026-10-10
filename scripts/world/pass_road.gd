class_name PassRoad extends Node3D
## The Pass Road (Era 2): a road cut through the Clearing's southern ridge
## from the village green down to the river flats, where the fields, the barn
## and the workplaces go. The cutting is part of the terrain (Valley.PASS);
## until Strength II it is choked by a scree of fallen rock at its crest
## (a navmesh obstacle wall to wall), and the stream's gorge beside it is
## jammed with boulders, so the way south is the long walk round by the
## eastern gap. world.open_pass() (called by the progression when the hand
## has cleared the rockfall) rolls the scree aside and opens the road.

signal opened_now

const SCREE_SIZE := Vector2(17.0, 6.0)      # the obstacle across the cutting (x across, z along)
const SCREE_YAW := -0.165                   # the road's heading through the crest
const OPEN_TIME := 2.4

var world
var opened: bool = false
var scree: Node3D
var _rocks: Array[Node3D] = []
var _homes: Array[Vector3] = []
var _t: float = -1.0

func build(w) -> void:
	world = w
	name = "PassRoad"
	scree = Node3D.new()
	scree.name = "Scree"
	add_child(scree)
	var c := Valley.PASS_SCREE
	var basis := Basis(Vector3.UP, SCREE_YAW)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# the main spill, across the road bed and up both walls
	if AssetCatalog.has(&"rockfall"):
		for k in [-1, 0, 1]:
			var art := AssetCatalog.instance(&"rockfall")
			art.rotation.y = SCREE_YAW + [-0.12, PI + 0.05, 0.16][k + 1]
			art.scale = Vector3(1.05, 1.25, 1.2) if k != 0 else Vector3(0.9, 1.45, 1.1)
			art.position = _ground(c + _rot(Vector2(k * 4.4, k * 0.6 + (0.5 if k == 0 else 0.0))), -0.2)
			scree.add_child(art)
			_rocks.append(art)
	# big boulders wedged against the cutting walls, smaller ones between
	var spots := [Vector2(-7.4, -0.5), Vector2(7.6, 0.4), Vector2(-4.6, 1.8), Vector2(4.2, -1.6), Vector2(0.4, 1.4), Vector2(-1.2, -1.9), Vector2(9.6, 1.6), Vector2(-9.8, 1.2)]
	for i in spots.size():
		var r := AssetCatalog.instance(&"rock_large", i)
		var p: Vector2 = c + _rot(spots[i])
		r.position = _ground(p, -0.3)
		r.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		r.scale = Vector3.ONE * (rng.randf_range(0.9, 1.25) if absf(spots[i].x) > 6.0 else rng.randf_range(0.6, 0.9))
		scree.add_child(r)
		_rocks.append(r)
	for i in 10:
		var r := AssetCatalog.instance(&"rock_small", i)
		var p: Vector2 = c + _rot(Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-4.0, 4.0)))
		r.position = _ground(p, -0.05)
		r.rotation.y = rng.randf() * TAU
		r.scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
		scree.add_child(r)
		_rocks.append(r)
	for r in _rocks:
		_homes.append(r.position)
	# cairns mark the road's two ends
	for end in [Valley.PASS[0] + Vector2(-4.4, 0.5), Valley.PASS[Valley.PASS.size() - 1] + Vector2(4.6, -1.0)]:
		var cairn := AssetCatalog.instance(&"cairn")
		cairn.position = _ground(end, 0.0)
		cairn.rotation.y = rng.randf() * TAU
		add_child(cairn)
	_build_gorge(rng)
	world._props_blocking.append([_ground(Vector2(Valley.PASS[0].x - 4.4, Valley.PASS[0].y + 0.5), 0.0), Vector2(1.2, 1.2), 0.0])

## Boulders jammed in the stream's gorge: the water runs white between them.
func _build_gorge(rng: RandomNumberGenerator) -> void:
	var g := Node3D.new()
	g.name = "Gorge"
	add_child(g)
	for z in [43.0, 47.5, 52.0, 56.0, 60.0]:
		var sx := Valley.stream_x(z)
		for side in [-1.0, 1.0]:
			var r := AssetCatalog.instance(&"rock_large", int(z) + int(side))
			r.position = _ground(Vector2(sx + side * rng.randf_range(0.6, 1.8), z + rng.randf_range(-1.0, 1.0)), -0.6)
			r.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
			r.scale = Vector3.ONE * rng.randf_range(0.7, 1.05)
			g.add_child(r)

func _rot(v: Vector2) -> Vector2:
	return v.rotated(-SCREE_YAW)

func _ground(p: Vector2, lift: float) -> Vector3:
	return Vector3(p.x, world.valley.ground_y(p.x, p.y) + lift, p.y)

## Nav obstacles: the scree (until the road opens) and the gorge (always).
func apply_obstacles() -> void:
	var nav: Nav = world.nav
	var g := Valley.GORGE
	nav.set_box_obstacle("gorge", Vector3(g.get_center().x, 0, g.get_center().y), Vector2(9.0, g.size.y - 4.0), 0.0)
	if opened:
		nav.remove_obstacle("pass_scree")
	else:
		var c := Valley.PASS_SCREE
		nav.set_box_obstacle("pass_scree", Vector3(c.x, 0, c.y), SCREE_SIZE, SCREE_YAW)

## Opens the road: the scree rolls off the bed and settles against the walls.
func open(instant: bool = false) -> bool:
	if opened:
		return false
	opened = true
	world.nav.remove_obstacle("pass_scree")
	if instant:
		_set_cleared(1.0)
		_t = -1.0
	else:
		_t = 0.0
	opened_now.emit()
	return true

## Back to the blocked state (new game, load).
func close() -> void:
	opened = false
	_t = -1.0
	_set_cleared(0.0)

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += Clock.real_delta if Clock.real_delta > 0.0 else delta
	var k := clampf(_t / OPEN_TIME, 0.0, 1.0)
	_set_cleared(k * k * (3.0 - 2.0 * k))
	if k >= 1.0:
		_t = -1.0

## 0 = the scree across the road, 1 = cleared: the spill sinks into the bed,
## the boulders roll out to the foot of the walls (past the road's edge).
func _set_cleared(k: float) -> void:
	var c := Valley.PASS_SCREE
	for i in _rocks.size():
		var r := _rocks[i]
		var home := _homes[i]
		var local := Vector2(home.x - c.x, home.z - c.y).rotated(SCREE_YAW)
		var is_spill: bool = str(r.get_meta("asset_id", "")) == "rockfall"
		if is_spill:
			var s0: Vector3 = r.get_meta("home_scale", r.scale)
			r.set_meta("home_scale", s0)
			r.position = home + Vector3(0, -2.6 * k, 0)
			r.scale = Vector3(s0.x, s0.y * (1.0 - 0.75 * k), s0.z)
			r.visible = k < 0.999
			continue
		var side := signf(local.x) if absf(local.x) > 0.3 else (1.0 if i % 2 == 0 else -1.0)
		var out_x := side * maxf(absf(local.x), Valley.PASS_FLAT + 1.6 + float(i % 3) * 0.7)
		var to := c + Vector2(out_x, local.y + (i % 5) * 0.8 - 1.6).rotated(-SCREE_YAW)
		var dest := _ground(to, -0.3)
		r.position = home.lerp(dest, k) + Vector3(0, sin(k * PI) * 0.8, 0)
		r.rotation.z = home.x * 0.1 + k * side * 2.2

func save_state() -> Dictionary:
	return {"open": opened}
