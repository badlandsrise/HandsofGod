class_name Drops extends RefCounted
## Where the hand may set people down (world.drops). People can only be put
## where they could walk home from: on the navmesh, in a region that is open
## and reachable, and joined to the village by a path. The far side of the
## great river (the East Bank, the Southern Plains and the Coast beyond them)
## stays shut until there is a way across (a crossing: the people's
## footbridge, or the great bridge), and a far region is only droppable once
## the progression allows it (allow_region) or a crossing exists.
##
## The hand asks check(p) every frame while it holds people; answers are
## cached per 2 m cell until the navmesh changes.

const FAR_SIDE: Array[StringName] = [&"east_bank", &"southern_plains", &"coast"]
const CANT_GET_BACK := "They can't get back from there"
const NOT_YET := "That land is still closed to them"
const OFF_MESH := 2.6          # metres from the navmesh a drop may still snap onto it
const CELL := 2.0

var world
var allowed: Dictionary = {}        # region id -> true (progression allowed drops there)
var crossings: Dictionary = {}      # crossing id -> true (the footbridge, ...)
var _cache: Dictionary = {}         # Vector2i -> String
var _cache_it: int = -1
var _anchor := Vector3.INF

func _init(w = null) -> void:
	world = w

# ---------------------------------------------------------------- progression API

## [C] Lets the hand set people down in a far region (East Bank, Plains, Coast).
func allow_region(id: StringName) -> void:
	id = Valley.canon(id)
	if allowed.has(id):
		return
	allowed[id] = true
	_changed()

func is_allowed(id: StringName) -> bool:
	return allowed.has(Valley.canon(id))

## A crossing of the great river now exists.
func add_crossing(id: StringName) -> void:
	if crossings.has(id):
		return
	crossings[id] = true
	_changed()

func has_crossing() -> bool:
	if not crossings.is_empty():
		return true
	return world != null and world.era2 != null and world.era2.bridge_built()

static func is_far(id: StringName) -> bool:
	return FAR_SIDE.has(Valley.canon(id))

## Open, and (for the far side of the river) reachable over a crossing.
## Locked-looking (fogged, camera kept out) when false.
func accessible(id: StringName) -> bool:
	id = Valley.canon(id)
	if not Village.regions.has(id):
		return false
	if not is_far(id):
		return true
	return has_crossing() or allowed.has(id)

func _changed() -> void:
	_cache.clear()
	if world != null and world.regions != null:
		world.regions.refresh_access()

# ---------------------------------------------------------------- the check

## "" when people may be set down at `p`, else the reason (for the tooltip).
func check(p: Vector3, off_mesh: float = OFF_MESH) -> String:
	if world == null or world.valley == null or not p.is_finite():
		return ""
	var rid: StringName = world.region_at(p)
	if not accessible(rid):
		return CANT_GET_BACK if Village.regions.has(rid) else NOT_YET
	var nav: Nav = world.nav
	if nav == null or not nav.ready_for_paths() or not nav.is_inside_tree():
		return ""
	if not nav.synced():
		return ""      # [polish] still baking (just after a load): don't refuse on the old mesh
	var map: RID = nav.get_world_3d().navigation_map
	var it := NavigationServer3D.map_get_iteration_id(map)
	if it <= 0:
		return ""
	if it != _cache_it:
		_cache.clear()
		_cache_it = it
		_anchor = Vector3.INF
	var key := Vector3i(floori(p.x / CELL), floori(p.z / CELL), int(off_mesh * 10.0))
	# While a new mesh bakes (just after a load, or a region opening) the live
	# mesh is the old one: a refusal from it isn't trusted or cached, only the
	# region rule above and open water (for a drop on bare ground) still hold.
	var stale := not nav.synced()
	if _cache.has(key) and not (stale and _cache[key] != ""):
		return _cache[key]
	var r := _reach(map, Vector3((key.x + 0.5) * CELL, p.y, (key.y + 0.5) * CELL), off_mesh)
	if stale and r != "":
		return CANT_GET_BACK if off_mesh <= OFF_MESH and world.valley.is_water(p.x, p.z) else ""
	_cache[key] = r
	return r

func ok(p: Vector3) -> bool:
	return check(p) == ""

func _reach(map: RID, p: Vector3, off_mesh: float) -> String:
	p.y = world.ground_y(p.x, p.z)
	var q := NavigationServer3D.map_get_closest_point(map, p)
	if Vector2(q.x - p.x, q.z - p.z).length() > off_mesh or absf(q.y - p.y) > 3.0:
		return CANT_GET_BACK
	if not _anchor.is_finite():
		_anchor = NavigationServer3D.map_get_closest_point(map, world.fire_position())
	var path := Nav.find_path(map, _anchor, q)
	if path.size() < 1 or path[path.size() - 1].distance_to(q) > 1.5:
		return CANT_GET_BACK
	return ""

# ---------------------------------------------------------------- state

func reset() -> void:
	allowed.clear()
	crossings.clear()
	_cache.clear()

func save_state() -> Dictionary:
	return {"allowed": allowed.keys().map(func(k): return str(k)), "crossings": crossings.keys().map(func(k): return str(k))}

func load_state(d: Dictionary) -> void:
	reset()
	for k in d.get("allowed", []):
		allowed[StringName(k)] = true
	for k in d.get("crossings", []):
		crossings[StringName(k)] = true
