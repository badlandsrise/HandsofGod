class_name RiverNames extends Node3D
## [polish] The waters' names, lettered on the water like a map: "the Stream"
## down the Clearing and "the Great River" along its course. Each label shows
## once the land beside it is open (Regions.light), so locked land under the
## mist keeps its secrets. Austin's note: "unclear which river is the Great River".

const STREAM_NAME := "the Stream"
const RIVER_NAME := "the Great River"
## Depths (z) down the stream where its name is lettered.
const STREAM_AT: Array[float] = [6.0, 66.0]
## Points (x) along the river where its name is lettered.
const RIVER_AT: Array[float] = [-150.0, -40.0, 70.0, 200.0, 330.0]
const INK := Color(0.93, 0.96, 1.0)
const OUTLINE := Color(0.08, 0.2, 0.3)

var regions: Regions = null
var _labels: Array[Label3D] = []
var _region_of: Array[int] = []

static func make(v: Valley, r: Regions) -> RiverNames:
	var n := RiverNames.new()
	n.name = "RiverNames"
	n.regions = r
	for z in STREAM_AT:
		var x := Valley.stream_x(z)
		var dir := Vector2(Valley.stream_x(z + 1.0) - x, 1.0)
		n._add(STREAM_NAME, Vector3(x, v.stream_level(z) + 0.12, z), dir, 1.5, v.region_index(x - 6.0, z))
	for x in RIVER_AT:
		var z := Valley.river_z(x)
		var dir := Vector2(1.0, Valley.river_z(x + 1.0) - z)
		n._add(RIVER_NAME, Vector3(x, Valley.river_level(x) + 0.12, z), dir, 3.4, v.region_index(x, z - 16.0))
	return n

## A label lying flat on the water, its text running along `dir` (x, z).
func _add(text: String, at: Vector3, dir: Vector2, em: float, region: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.font(&"title_italic")
	l.font_size = 128
	l.pixel_size = em / 128.0
	l.outline_size = 18
	l.modulate = INK
	l.outline_modulate = OUTLINE
	l.shaded = false
	l.double_sided = true
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.render_priority = 2
	l.outline_render_priority = 1
	l.position = at
	# lie flat (face up), then turn so the text runs downstream
	l.rotation = Vector3(-PI * 0.5, -atan2(dir.y, dir.x), 0.0)
	l.rotation_order = EULER_ORDER_YXZ
	add_child(l)
	_labels.append(l)
	_region_of.append(region)

func _process(_delta: float) -> void:
	for i in _labels.size():
		var a := 1.0
		if regions != null and _region_of[i] >= 0 and _region_of[i] < regions.light.size():
			a = regions.light[_region_of[i]]
		var l := _labels[i]
		l.visible = a > 0.02
		l.modulate.a = 0.85 * a
		l.outline_modulate.a = 0.6 * a

## The labels' text, for tests.
func names() -> Array[String]:
	var out: Array[String] = []
	for l in _labels:
		if not out.has(l.text):
			out.append(l.text)
	return out
