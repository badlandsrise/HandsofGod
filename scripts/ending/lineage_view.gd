class_name LineageView extends Control
## The lineage (DESIGN 9.2 beat 9): the family line draws itself across the night
## sky from the first two names down to the crew, one generation at a time, each
## person a small star with their name in the hand of the Book; then the names
## fade and the stars drift up and become part of the sky.
##
##   set_data(cast.lineage()); then drive `t` (seconds) and `dissolve` (0..1).
## Row k appears at row_times[k] (seconds); set_row_times() spreads them.

const INK := Color("#f4e6c8")
const LINE := Color(1.0, 0.82, 0.5)
const CREW := Color(1.0, 0.9, 0.66)
const ROW_DRAW := 1.6       # seconds for a row's lines to draw down

var nodes: Array = []       # {uid, name, depth, crew, commander}
var edges: Array = []
var depth: int = 0
var row_times: Array = []
var t: float = -1.0
var dissolve: float = 0.0
var _pos: Dictionary = {}   # uid -> Vector2 (0..1 of the drawing box)
var _drift: Dictionary = {} # uid -> Vector2 drift direction for the dissolve
var _font: Font
var _font_b: Font

func _init() -> void:
	name = "Lineage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_font = UiTheme.font(&"hand")
	_font_b = UiTheme.font(&"hand_bold")

func set_data(d: Dictionary) -> void:
	nodes = d.get("nodes", [])
	edges = d.get("edges", [])
	depth = maxi(int(d.get("depth", 0)), 1)
	_pos.clear()
	var rows := {}
	for n in nodes:
		var k := int(n["depth"])
		if not rows.has(k):
			rows[k] = []
		rows[k].append(n)
	for k in rows:
		var row: Array = rows[k]
		row.sort_custom(func(a, b): return _order(a) < _order(b))
		for i in row.size():
			var x := 0.5 + (float(i) - (row.size() - 1) * 0.5) * (0.17 if row.size() <= 4 else 0.68 / row.size())
			_pos[int(row[i]["uid"])] = Vector2(x, float(k) / float(depth))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for n in nodes:
		_drift[int(n["uid"])] = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.6, -0.6))
	set_row_times(0.0, 1.8 * depth)
	queue_redraw()

## Keeps parents above children in the same left-right order (a light touch:
## nodes follow the x of their parent where they have one).
func _order(n: Dictionary) -> float:
	var u := int(n["uid"])
	for e in edges:
		if int(e[1]) == u and _pos.has(int(e[0])):
			return _pos[int(e[0])].x + u * 0.0001
	return float(u)

## Row 0 at `from` seconds, the last row at `to`.
func set_row_times(from: float, to: float) -> void:
	row_times.clear()
	for k in depth + 1:
		row_times.append(lerpf(from, to, float(k) / float(maxi(depth, 1))))

func rows_shown() -> int:
	var n := 0
	for rt in row_times:
		if t >= float(rt):
			n += 1
	return n

func _box() -> Rect2:
	var vs := size
	var h := vs.y * 0.58
	var w := minf(vs.x * 0.8, 1100.0)
	return Rect2(Vector2((vs.x - w) * 0.5, vs.y * 0.12), Vector2(w, h))

func _at(u: int, box: Rect2) -> Vector2:
	var p: Vector2 = _pos.get(u, Vector2(0.5, 0.5))
	var at := box.position + Vector2(p.x * box.size.x, p.y * box.size.y)
	if dissolve > 0.0:
		var d: Vector2 = _drift.get(u, Vector2(0, -1))
		at += d * dissolve * dissolve * 140.0
	return at

func _row_t(k: int) -> float:
	return float(row_times[k]) if k < row_times.size() else 0.0

func _depth_of(u: int) -> int:
	for n in nodes:
		if int(n["uid"]) == u:
			return int(n["depth"])
	return 0

func _process(_d: float) -> void:
	if visible and t >= 0.0:
		queue_redraw()

func _draw() -> void:
	if t < 0.0 or nodes.is_empty():
		return
	var box := _box()
	var fade := 1.0 - dissolve
	var roots: Array = nodes.filter(func(n): return int(n["depth"]) == 0)
	var root_ids: Array = roots.map(func(n): return int(n["uid"]))
	# lines: each draws down from the parent as the child's row arrives
	for e in edges:
		var a := int(e[0])
		var b := int(e[1])
		var k := _depth_of(b)
		var u := clampf((t - _row_t(k) + 0.6) / ROW_DRAW, 0.0, 1.0)
		if u <= 0.0:
			continue
		var pa := _at(a, box) + Vector2(0, 16)
		if roots.size() == 2 and root_ids.has(a):
			# the first two's children hang from the middle of the couple's bar
			if a != int(root_ids[0]) and edges.has([int(root_ids[0]), b]):
				continue
			if edges.has([int(root_ids[0]), b]) and edges.has([int(root_ids[1]), b]):
				pa = (_at(int(root_ids[0]), box) + _at(int(root_ids[1]), box)) * 0.5
		var pb := _at(b, box) - Vector2(0, 30)
		var mid := Vector2(pb.x, lerpf(pa.y, pb.y, 0.5))
		var c := Color(LINE, 0.55 * fade)
		var pts := PackedVector2Array()
		for i in 17:
			var s := float(i) / 16.0 * u
			var q := pa.lerp(Vector2(pa.x, mid.y), s).lerp(Vector2(pa.x, mid.y).lerp(pb, s), s)
			pts.append(q)
		if pts.size() >= 2:
			draw_polyline(pts, c, 2.0, true)
	# the first two are a couple: a short bar between them
	if roots.size() == 2 and t >= _row_t(0):
		var u := clampf((t - _row_t(0)) / 1.0, 0.0, 1.0)
		var p0 := _at(int(roots[0]["uid"]), box)
		var p1 := _at(int(roots[1]["uid"]), box)
		draw_line(p0, p0.lerp(p1, u), Color(LINE, 0.45 * fade), 2.0, true)
	# stars and names
	for n in nodes:
		var u := int(n["uid"])
		var k := int(n["depth"])
		var a := clampf((t - _row_t(k)) / 1.2, 0.0, 1.0)
		if a <= 0.0:
			continue
		var p := _at(u, box)
		var crew := bool(n.get("crew", false))
		var tw := 0.75 + 0.25 * sin(t * 2.3 + u)
		var r := (5.5 if crew else 4.0) * (0.6 + 0.4 * a)
		var star_a := a * (1.0 - dissolve * 0.35) * tw
		_star(p, r * (1.0 - dissolve * 0.5), Color(CREW if crew else Color(1, 0.96, 0.86), star_a))
		var name_a := a * fade
		if name_a > 0.01:
			var f: Font = _font_b if crew else _font
			var fs := 40 if bool(n.get("commander", false)) else (34 if crew else 30)
			var text := str(n["name"])
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := p + Vector2(-w * 0.5, 44)
			draw_string(f, at + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * name_a))
			draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, name_a))

## A soft four-pointed star.
func _star(p: Vector2, r: float, c: Color) -> void:
	draw_circle(p, r * 3.2, Color(c, c.a * 0.12))
	draw_circle(p, r * 1.6, Color(c, c.a * 0.3))
	draw_line(p - Vector2(r * 3.0, 0), p + Vector2(r * 3.0, 0), Color(c, c.a * 0.55), 1.4, true)
	draw_line(p - Vector2(0, r * 3.0), p + Vector2(0, r * 3.0), Color(c, c.a * 0.55), 1.4, true)
	draw_circle(p, r * 0.7, c)
