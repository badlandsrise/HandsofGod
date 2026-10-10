class_name Regions extends Node
## Which regions are open, how bright each one is drawn, and where the camera
## may go. A region the people cannot reach yet (locked, or on the far side of
## the great river before there is a crossing: Drops.accessible) lies under a
## soft mist: a low-res mask texture that every world shader samples (global
## hog_region_mask) dims and hazes the ground, and two drifting mist sheets
## hang over it so trees and props beyond read as shapes in the fog. Opening
## a region lifts its mist over 2 s.
##
## The camera may only look out over reachable land: camera_ok() is a
## distance field over the same mask (CAMERA_MARGIN metres past the edge).

signal bounds_changed(aabb: AABB)

const RES := 150                 # mask pixels per side (8 m each)
const PX := Valley.HALF * 2.0 / RES
const LIGHTEN_TIME := 2.0
const CAMERA_MARGIN := 12.0      # the camera focus may stray this far past reachable land
const MIST_STEP := 8.0           # metres per mist-sheet cell
const MIST_LAYERS := [[2.5, 0.85], [9.0, 0.55]]   # height above ground, opacity

var valley: Valley
var light: PackedFloat32Array = PackedFloat32Array()   # per region index, 0..1 drawn brightness
var target: PackedFloat32Array = PackedFloat32Array()
## Callable(id) -> bool; default: open in Village.regions. World sets Drops.accessible.
var access: Callable = Callable()
var _ids := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _dirty := true
var _cam_dist := PackedFloat32Array()     # metres from each mask pixel to reachable land
var _cam_dirty := true
var mist: Node3D = null

func setup(v: Valley) -> void:
	valley = v
	name = "Regions"
	light.resize(Valley.REGIONS.size())
	target.resize(Valley.REGIONS.size())
	_ids.resize(RES * RES)
	for j in RES:
		for i in RES:
			var x := -Valley.HALF + (i + 0.5) * PX
			var z := -Valley.HALF + (j + 0.5) * PX
			_ids[j * RES + i] = valley.region_index(x, z)
	_img = Image.create(RES, RES, false, Image.FORMAT_L8)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set(&"hog_region_mask", _tex)
	_build_mist()
	sync_instant()

func is_open(id: StringName) -> bool:
	if access.is_valid():
		return bool(access.call(Valley.canon(id)))
	return Village.regions.has(Valley.canon(id))

## Snaps brightness to the open regions (after load or new game).
func sync_instant() -> void:
	for i in Valley.REGIONS.size():
		var v := 1.0 if is_open(Valley.REGIONS[i]) else 0.0
		light[i] = v
		target[i] = v
	_dirty = true
	_cam_dirty = true
	_refresh()
	bounds_changed.emit(camera_bounds())

## Starts the 2 s lightening of a newly opened region.
func lighten(id: StringName) -> void:
	var i := Valley.REGIONS.find(Valley.canon(id))
	if i < 0:
		return
	if is_open(id):
		target[i] = 1.0
	_cam_dirty = true
	bounds_changed.emit(camera_bounds())

## Something changed which regions are reachable (a crossing, Drops.allow_region):
## lift (or lay) the mist where it changed.
func refresh_access() -> void:
	for i in Valley.REGIONS.size():
		target[i] = 1.0 if is_open(Valley.REGIONS[i]) else 0.0
	_cam_dirty = true
	bounds_changed.emit(camera_bounds())

func _process(delta: float) -> void:
	var dt := Clock.real_delta if Clock.real_delta > 0.0 else delta
	for i in light.size():
		if light[i] != target[i]:
			light[i] = move_toward(light[i], target[i], dt / LIGHTEN_TIME)
			_dirty = true
	_refresh()

func _refresh() -> void:
	if not _dirty or _img == null:
		return
	_dirty = false
	var data := PackedByteArray()
	data.resize(RES * RES)
	var lut := PackedByteArray()
	lut.resize(256)
	for i in light.size():
		lut[i] = int(clampf(light[i], 0.0, 1.0) * 255.0)
	for k in RES * RES:
		data[k] = lut[_ids[k]]
	_img.set_data(RES, RES, false, Image.FORMAT_L8, data)
	_tex.update(_img)

func open_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Valley.REGIONS:
		if is_open(id):
			out.append(id)
	return out

## The camera may roam the union of the open regions (plus a margin): the
## outer box. camera_ok() then keeps it off the land in between that is locked.
func camera_bounds() -> AABB:
	var r := Rect2()
	var first := true
	for id in open_ids():
		var rr: Rect2 = Valley.RECTS[id]
		r = rr if first else r.merge(rr)
		first = false
	if first:
		r = Valley.RECTS[&"clearing"]
	r = r.grow(10.0)
	return AABB(Vector3(r.position.x, -5.0, r.position.y), Vector3(r.size.x, 140.0, r.size.y))

# ---------------------------------------------------------------- camera

## Metres from (x, z) to the nearest reachable land (0 on it).
func distance_to_open(x: float, z: float) -> float:
	_update_cam_field()
	var fi := (x + Valley.HALF) / PX - 0.5
	var fj := (z + Valley.HALF) / PX - 0.5
	var i := clampi(int(floor(fi)), 0, RES - 2)
	var j := clampi(int(floor(fj)), 0, RES - 2)
	var tx := clampf(fi - i, 0.0, 1.0)
	var tz := clampf(fj - j, 0.0, 1.0)
	var k := j * RES + i
	var a := lerpf(_cam_dist[k], _cam_dist[k + 1], tx)
	var b := lerpf(_cam_dist[k + RES], _cam_dist[k + RES + 1], tx)
	return lerpf(a, b, tz)

func camera_ok(x: float, z: float) -> bool:
	return distance_to_open(x, z) <= CAMERA_MARGIN

## Keeps a camera focus on reachable land: `to` if allowed, else slides along
## the edge from `from`, else the nearest allowed point.
func clamp_camera(from: Vector3, to: Vector3) -> Vector3:
	if camera_ok(to.x, to.z):
		return to
	var sx := Vector3(to.x, to.y, from.z)
	if camera_ok(sx.x, sx.z):
		return sx
	var sz := Vector3(from.x, to.y, to.z)
	if camera_ok(sz.x, sz.z):
		return sz
	if camera_ok(from.x, from.z):
		return Vector3(from.x, to.y, from.z)
	return nearest_ok(to)

## The nearest point the camera may look at (a spiral over the mask).
func nearest_ok(p: Vector3) -> Vector3:
	_update_cam_field()
	var ci := clampi(int((p.x + Valley.HALF) / PX), 0, RES - 1)
	var cj := clampi(int((p.z + Valley.HALF) / PX), 0, RES - 1)
	for r in range(0, RES):
		var best := Vector3.INF
		var best_d := INF
		for j in range(cj - r, cj + r + 1):
			for i in range(ci - r, ci + r + 1):
				if i < 0 or j < 0 or i >= RES or j >= RES:
					continue
				if maxi(absi(i - ci), absi(j - cj)) != r:
					continue
				if _cam_dist[j * RES + i] > 0.0:
					continue
				var q := Vector3(-Valley.HALF + (i + 0.5) * PX, p.y, -Valley.HALF + (j + 0.5) * PX)
				var d := Vector2(q.x - p.x, q.z - p.z).length()
				if d < best_d:
					best_d = d
					best = q
		if best.is_finite():
			# step back out toward p as far as the margin allows
			var dir := Vector3(p.x - best.x, 0, p.z - best.z)
			var out := best
			for s in 12:
				var t := best + dir.normalized() * CAMERA_MARGIN * float(s + 1) / 12.0 if dir.length() > 0.01 else best
				if not camera_ok(t.x, t.z):
					break
				out = t
			return out
	return p

## A chamfer distance transform of the reachable pixels (rebuilt when access changes).
func _update_cam_field() -> void:
	if not _cam_dirty and _cam_dist.size() == RES * RES:
		return
	_cam_dirty = false
	_cam_dist.resize(RES * RES)
	var open := PackedByteArray()
	open.resize(Valley.REGIONS.size())
	for i in Valley.REGIONS.size():
		open[i] = 1 if is_open(Valley.REGIONS[i]) else 0
	var big := 1e6
	for k in RES * RES:
		_cam_dist[k] = 0.0 if open[_ids[k]] == 1 else big
	var d1 := PX
	var d2 := PX * 1.4142
	for j in RES:
		for i in RES:
			var k := j * RES + i
			var v := _cam_dist[k]
			if v == 0.0:
				continue
			if i > 0: v = minf(v, _cam_dist[k - 1] + d1)
			if j > 0:
				v = minf(v, _cam_dist[k - RES] + d1)
				if i > 0: v = minf(v, _cam_dist[k - RES - 1] + d2)
				if i < RES - 1: v = minf(v, _cam_dist[k - RES + 1] + d2)
			_cam_dist[k] = v
	for j in range(RES - 1, -1, -1):
		for i in range(RES - 1, -1, -1):
			var k := j * RES + i
			var v := _cam_dist[k]
			if v == 0.0:
				continue
			if i < RES - 1: v = minf(v, _cam_dist[k + 1] + d1)
			if j < RES - 1:
				v = minf(v, _cam_dist[k + RES] + d1)
				if i < RES - 1: v = minf(v, _cam_dist[k + RES + 1] + d2)
				if i > 0: v = minf(v, _cam_dist[k + RES - 1] + d2)
			_cam_dist[k] = v
	# pixel centres are PX/2 inside their region: count from the region's edge
	for k in RES * RES:
		_cam_dist[k] = maxf(_cam_dist[k] - PX * 0.5, 0.0)

# ---------------------------------------------------------------- mist

## Two terrain-following sheets of drifting mist over the whole map; the
## shader shows them only where the region mask is dark (locked land).
func _build_mist() -> void:
	mist = Node3D.new()
	mist.name = "Mist"
	add_child(mist)
	var sh: Shader = load("res://scenes/world/shaders/mist.gdshader")
	var chunk := 200.0
	var n := int(Valley.HALF * 2.0 / chunk)
	for layer in MIST_LAYERS:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter(&"opacity", float(layer[1]))
		mat.set_shader_parameter(&"drift", 1.0 if float(layer[0]) < 5.0 else -0.7)
		mat.render_priority = -2 if float(layer[0]) < 5.0 else -1
		for cj in n:
			for ci in n:
				var mi := MeshInstance3D.new()
				mi.mesh = _mist_mesh(-Valley.HALF + ci * chunk, -Valley.HALF + cj * chunk, chunk, float(layer[0]))
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mist.add_child(mi)

func _mist_mesh(x0: float, z0: float, size: float, lift: float) -> ArrayMesh:
	var cells := int(size / MIST_STEP)
	var w := cells + 1
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize(w * w)
	for j in w:
		for i in w:
			var x := x0 + i * MIST_STEP
			var z := z0 + j * MIST_STEP
			# ride over the highest ground nearby so peaks do not poke through
			var y := valley.ground_y(x, z)
			for o in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
				y = maxf(y, valley.ground_y(x + o.x, z + o.y) - 1.0)
			verts[j * w + i] = Vector3(x, maxf(y, Valley.SEA_LEVEL) + lift, z)
	for j in cells:
		for i in cells:
			var a := j * w + i
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
