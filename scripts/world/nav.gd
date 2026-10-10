class_name Nav extends NavigationRegion3D
## The walkable navmesh, baked at runtime from the terrain of the open
## regions (water and locked regions left out) plus obstacles (trees, blockers,
## finished buildings). Re-baked in the background whenever something changes;
## the old mesh stays live until the new one is ready.

signal baked

const CELL_SIZE := 0.5
const CELL_HEIGHT := 0.1
const MERGE_SCALE := 0.05
const PATH_SEARCH_MAX := 0          # polygons a path search may visit (0: no cap)

var valley: Valley
var obstacles: Dictionary = {}       # key -> PackedVector3Array outline (y ignored)
var tree_points: Array = []
var use_tree_obstacles := true    # small holes so people walk round trunks
## Only trunks in and around the settlement get holes: every hole multiplies
## the navmesh's polygons, and by the Town era the open valley holds thousands
## of trees (a 176k-polygon mesh took 23 s to bake and made every path slow).
const TREE_HOLES_AROUND := Vector2(40.0, 10.0)
const TREE_HOLES_WITHIN := 150.0
var extra_faces := PackedVector3Array()   # walkable faces off the heightmap (the bridge decks)
## Callable(region id) -> bool: which regions are walkable. World sets
## Drops.accessible (the far bank only once there is a crossing).
var access: Callable = Callable()
var _baking := false
var _again := false
var bake_count := 0
var last_bake_ms := 0
var _t0 := 0
var _sync_from := -1
var _sync_map := -1

func setup(v: Valley, trees: Array) -> void:
	valley = v
	tree_points = trees
	name = "Nav"
	var map := get_world_3d().navigation_map if is_inside_tree() else RID()
	if map.is_valid():
		NavigationServer3D.map_set_cell_size(map, CELL_SIZE)
		NavigationServer3D.map_set_cell_height(map, CELL_HEIGHT)
		# Finer edge merging: at the default scale, neighbouring polygon edges
		# of the big flat valley collide in the merge raster ("edge errors") and
		# whole stretches of land silently fail to connect.
		NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, MERGE_SCALE)

func baking_now() -> bool:
	return _baking

## True once the latest baked mesh is live on the map: regions sync on a
## background thread, so paths can still run on the previous mesh for a few
## frames after `baked`.
func synced() -> bool:
	if _baking or _again:
		return false
	if _sync_from >= 0 and NavigationServer3D.region_get_iteration_id(get_rid()) != _sync_from \
			and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) != _sync_map:
		_sync_from = -1
	return _sync_from < 0

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
	if not extra_faces.is_empty():
		src.add_faces(extra_faces, Transform3D.IDENTITY)
	for key in obstacles:
		var pts: PackedVector3Array = obstacles[key]
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= maxf(pts.size(), 1)
		src.add_projected_obstruction(pts, valley.ground_y(c.x, c.z) - 2.0, 8.0, true)
	for t in (tree_points if use_tree_obstacles else []):
		var tp: Vector3 = t
		if bounds.has_point(Vector2(tp.x, tp.z)) and _open_at(tp.x, tp.z) and Vector2(tp.x, tp.z).distance_to(TREE_HOLES_AROUND) < TREE_HOLES_WITHIN:
			var r := 0.35
			src.add_projected_obstruction(PackedVector3Array([tp + Vector3(-r, 0, -r), tp + Vector3(r, 0, -r), tp + Vector3(r, 0, r), tp + Vector3(-r, 0, r)]), tp.y - 2.0, 6.0, false)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, _on_baked.bind(nm))

func _on_baked(nm: NavigationMesh) -> void:
	_finish.call_deferred(nm)

func _finish(nm: NavigationMesh) -> void:
	if not is_inside_tree():
		_baking = false
		return
	_sync_from = NavigationServer3D.region_get_iteration_id(get_rid())
	_sync_map = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)
	navigation_mesh = nm
	_baking = false
	bake_count += 1
	last_bake_ms = Time.get_ticks_msec() - _t0
	baked.emit()
	if _again:
		_again = false
		rebake()

func _region_ok(id: StringName) -> bool:
	return bool(access.call(id)) if access.is_valid() else Village.regions.has(id)

func _open_at(x: float, z: float) -> bool:
	return _region_ok(Valley.REGIONS[valley.region_index(x, z)])

func _open_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for id in Valley.REGIONS:
		if _region_ok(id):
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
		open[r] = 1 if _region_ok(Valley.REGIONS[r]) else 0
	for j in range(j0, j1):
		for i in range(i0, i1):
			var k := j * Valley.N + i
			if open[valley.region_ids[k]] == 0 or open[valley.region_ids[k + 1]] == 0 \
					or open[valley.region_ids[k + Valley.N]] == 0 or open[valley.region_ids[k + Valley.N + 1]] == 0:
				continue
			var x := -Valley.HALF + i * Valley.CELL
			var z := -Valley.HALF + j * Valley.CELL
			if valley.is_water(x + 1.0, z + 1.0) and not _ford(x + 1.0, z + 1.0):
				continue
			var a := Vector3(x, valley.heights[k], z)
			var b := Vector3(x + Valley.CELL, valley.heights[k + 1], z)
			var c := Vector3(x, valley.heights[k + Valley.N], z + Valley.CELL)
			var d := Vector3(x + Valley.CELL, valley.heights[k + Valley.N + 1], z + Valley.CELL)
			faces.append_array([a, b, c, b, d, c])
	return faces

## The Clearing's stream is shallow: people wade across it (otherwise the
## only way round is a gap by the cliff where they get stuck). Not in the
## gorge through the southern ridge: the way south is the Pass Road.
func _ford(x: float, z: float) -> bool:
	return z > Valley.STREAM_HEAD_Z and z < Valley.river_z(x) - 10.0 and absf(x - Valley.stream_x(z)) < 3.0 \
		and not Valley.GORGE.has_point(Vector2(x, z))

## A path on `map` (like map_get_path with optimize on) without the server's
## default 4096-polygon search cap: the open valley's mesh holds well over that
## and long routes (round by the eastern gap, out to the river) came back cut
## short at the polygon nearest the target "so far".
static var _query: NavigationPathQueryParameters3D
static var _result: NavigationPathQueryResult3D

static func find_path(map: RID, from: Vector3, to: Vector3, layers: int = 1) -> PackedVector3Array:
	if _query == null:
		_query = NavigationPathQueryParameters3D.new()
		_query.path_search_max_polygons = PATH_SEARCH_MAX
		_query.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
		_query.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
		_result = NavigationPathQueryResult3D.new()
	_query.map = map
	_query.start_position = from
	_query.target_position = to
	_query.navigation_layers = layers
	NavigationServer3D.query_path(_query, _result)
	return _result.path

## Nearest point on the navmesh to `p` (p itself if there is no mesh yet).
func closest(p: Vector3) -> Vector3:
	if not ready_for_paths():
		return p
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
