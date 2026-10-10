class_name Nav extends NavigationRegion3D
## The walkable navmesh, baked at runtime from the terrain of the open
## regions (water and locked regions left out) plus obstacles (trees, blockers,
## finished buildings). Re-baked in the background whenever something changes;
## the old mesh stays live until the new one is ready.

signal baked

const CELL_SIZE := 0.5
const CELL_HEIGHT := 0.1

var valley: Valley
var obstacles: Dictionary = {}       # key -> PackedVector3Array outline (y ignored)
var tree_points: Array = []
var use_tree_obstacles := true    # small holes so people walk round trunks
var _baking := false
var _again := false
var bake_count := 0
var last_bake_ms := 0
var _t0 := 0

func setup(v: Valley, trees: Array) -> void:
	valley = v
	tree_points = trees
	name = "Nav"
	var map := get_world_3d().navigation_map if is_inside_tree() else RID()
	if map.is_valid():
		NavigationServer3D.map_set_cell_size(map, CELL_SIZE)
		NavigationServer3D.map_set_cell_height(map, CELL_HEIGHT)

func baking_now() -> bool:
	return _baking

func ready_for_paths() -> bool:
	return navigation_mesh != null and navigation_mesh.get_polygon_count() > 0

## Adds or replaces an obstacle outline (a rectangle around `center`).
func set_box_obstacle(key: String, center: Vector3, size: Vector2, yaw: float = 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var pts := PackedVector3Array()
	for c in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
		pts.append(center + b * c)
	obstacles[key] = pts

func remove_obstacle(key: String) -> void:
	obstacles.erase(key)

## Starts a background bake (coalesces requests made while one is running).
func rebake() -> void:
	if valley == null:
		return
	if _baking:
		_again = true
		return
	_baking = true
	_t0 = Time.get_ticks_msec()
	var nm := NavigationMesh.new()
	nm.cell_size = CELL_SIZE
	nm.cell_height = CELL_HEIGHT
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 38.0
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.5
	nm.detail_sample_distance = 2.0
	nm.detail_sample_max_error = 0.3
	var src := NavigationMeshSourceGeometryData3D.new()
	var bounds := _open_rect()
	nm.filter_baking_aabb = AABB(Vector3(bounds.position.x, -20.0, bounds.position.y), Vector3(bounds.size.x, 200.0, bounds.size.y))
	src.add_faces(_terrain_faces(bounds), Transform3D.IDENTITY)
	for key in obstacles:
		var pts: PackedVector3Array = obstacles[key]
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= maxf(pts.size(), 1)
		src.add_projected_obstruction(pts, valley.ground_y(c.x, c.z) - 2.0, 8.0, true)
	for t in (tree_points if use_tree_obstacles else []):
		var tp: Vector3 = t
		if bounds.has_point(Vector2(tp.x, tp.z)) and _open_at(tp.x, tp.z):
			var r := 0.35
			src.add_projected_obstruction(PackedVector3Array([tp + Vector3(-r, 0, -r), tp + Vector3(r, 0, -r), tp + Vector3(r, 0, r), tp + Vector3(-r, 0, r)]), tp.y - 2.0, 6.0, false)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, _on_baked.bind(nm))

func _on_baked(nm: NavigationMesh) -> void:
	_finish.call_deferred(nm)

func _finish(nm: NavigationMesh) -> void:
	if not is_inside_tree():
		_baking = false
		return
	navigation_mesh = nm
	_baking = false
	bake_count += 1
	last_bake_ms = Time.get_ticks_msec() - _t0
	baked.emit()
	if _again:
		_again = false
		rebake()

func _open_at(x: float, z: float) -> bool:
	return Village.regions.has(Valley.REGIONS[valley.region_index(x, z)])

func _open_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for id in Valley.REGIONS:
		if Village.regions.has(id):
			var rr: Rect2 = Valley.RECTS[id]
			r = rr if first else r.merge(rr)
			first = false
	if first:
		r = Valley.RECTS[&"clearing"]
	return r.grow(2.0)

## Terrain triangles at 2 m inside `bounds`, leaving out water and any cell that
## touches a locked region.
func _terrain_faces(bounds: Rect2) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var i0 := clampi(floori((bounds.position.x + Valley.HALF) / Valley.CELL), 0, Valley.N - 2)
	var i1 := clampi(ceili((bounds.end.x + Valley.HALF) / Valley.CELL), 0, Valley.N - 2)
	var j0 := clampi(floori((bounds.position.y + Valley.HALF) / Valley.CELL), 0, Valley.N - 2)
	var j1 := clampi(ceili((bounds.end.y + Valley.HALF) / Valley.CELL), 0, Valley.N - 2)
	var open := PackedByteArray()
	open.resize(Valley.REGIONS.size())
	for r in Valley.REGIONS.size():
		open[r] = 1 if Village.regions.has(Valley.REGIONS[r]) else 0
	for j in range(j0, j1):
		for i in range(i0, i1):
			var k := j * Valley.N + i
			if open[valley.region_ids[k]] == 0 or open[valley.region_ids[k + 1]] == 0 \
					or open[valley.region_ids[k + Valley.N]] == 0 or open[valley.region_ids[k + Valley.N + 1]] == 0:
				continue
			var x := -Valley.HALF + i * Valley.CELL
			var z := -Valley.HALF + j * Valley.CELL
			if valley.is_water(x + 1.0, z + 1.0):
				continue
			var a := Vector3(x, valley.heights[k], z)
			var b := Vector3(x + Valley.CELL, valley.heights[k + 1], z)
			var c := Vector3(x, valley.heights[k + Valley.N], z + Valley.CELL)
			var d := Vector3(x + Valley.CELL, valley.heights[k + Valley.N + 1], z + Valley.CELL)
			faces.append_array([a, b, c, b, d, c])
	return faces

## Nearest point on the navmesh to `p` (p itself if there is no mesh yet).
func closest(p: Vector3) -> Vector3:
	if not ready_for_paths():
		return p
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
