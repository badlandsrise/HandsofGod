class_name Regions extends Node
## Which regions are open, how bright each one is drawn, and the camera bounds.
## Locked regions are dim through a low-res mask texture that every world
## shader samples (global hog_region_mask). Opening a region lightens it over 2 s.

signal bounds_changed(aabb: AABB)

const RES := 150                 # mask pixels per side (8 m each)
const LIGHTEN_TIME := 2.0

var valley: Valley
var light: PackedFloat32Array = PackedFloat32Array()   # per region index, 0..1 drawn brightness
var target: PackedFloat32Array = PackedFloat32Array()
var _ids := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _dirty := true

func setup(v: Valley) -> void:
	valley = v
	name = "Regions"
	light.resize(Valley.REGIONS.size())
	target.resize(Valley.REGIONS.size())
	_ids.resize(RES * RES)
	var px := Valley.HALF * 2.0 / RES
	for j in RES:
		for i in RES:
			var x := -Valley.HALF + (i + 0.5) * px
			var z := -Valley.HALF + (j + 0.5) * px
			_ids[j * RES + i] = valley.region_index(x, z)
	_img = Image.create(RES, RES, false, Image.FORMAT_L8)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set(&"hog_region_mask", _tex)
	sync_instant()

func is_open(id: StringName) -> bool:
	return Village.regions.has(Valley.canon(id))

## Snaps brightness to Village.regions (after load or new game).
func sync_instant() -> void:
	for i in Valley.REGIONS.size():
		var v := 1.0 if is_open(Valley.REGIONS[i]) else 0.0
		light[i] = v
		target[i] = v
	_dirty = true
	_refresh()
	bounds_changed.emit(camera_bounds())

## Starts the 2 s lightening of a newly opened region.
func lighten(id: StringName) -> void:
	var i := Valley.REGIONS.find(Valley.canon(id))
	if i < 0:
		return
	target[i] = 1.0
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

## The camera may roam the union of the open regions (plus a margin).
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
