class_name LineageView extends Control
## The lineage (DESIGN 9.2 beat 9): the family line draws itself across the night
## sky from the first two names down to the crew, one generation at a time, as a
## descending family tree: each couple joined by a bar, a line down from the
## middle of the bar to their children. Each person is a small star with their
## name in the hand of the Book; the direct line from the first two to each crew
## member is bright, the other parent of each child (a relative by marriage) is
## faint. Then the names fade and the stars drift up and become part of the sky.
##
##   set_data(cast.lineage()); then drive `t` (seconds) and `dissolve` (0..1).
## Row k appears at row_times[k] (seconds); set_row_times() spreads them.

const INK := Color("#f4e6c8")
const LINE := Color(1.0, 0.82, 0.5)
const CREW := Color(1.0, 0.9, 0.66)
const ROW_DRAW := 1.6       # seconds for a family's drop line to draw down
const SPOUSE_LAG := 0.5     # a relative appears this long after their row
const LINE_A := 0.85        # alpha of the direct line
const FAINT_A := 0.28       # alpha of the relatives' lines
const SLOT_MAX := 190.0     # widest spacing between two stars (px)

var nodes: Array = []       # {uid, name, depth, crew, commander, line}
var edges: Array = []
var families: Array = []    # {parents: [a, b], children: [...]}
var depth: int = 0
var row_times: Array = []
var t: float = -1.0
var dissolve: float = 0.0
var _pos: Dictionary = {}   # uid -> Vector2 (x in slots, y = depth)
var _by: Dictionary = {}    # uid -> node
var _span := Vector2.ZERO   # min, max x in slots
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
	families = d.get("families", [])
	if families.is_empty() and not edges.is_empty():
		families = _families_from_edges()
	depth = maxi(int(d.get("depth", 0)), 1)
	_by.clear()
	for n in nodes:
		_by[int(n["uid"])] = n
	_layout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_drift.clear()
	for n in nodes:
		_drift[int(n["uid"])] = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.6, -0.6))
	set_row_times(0.0, 1.8 * depth)
	queue_redraw()

func _families_from_edges() -> Array:
	var fam := {}
	var parents_of := {}
	for e in edges:
		if not parents_of.has(int(e[1])):
			parents_of[int(e[1])] = []
		parents_of[int(e[1])].append(int(e[0]))
	for c in parents_of:
		var ps: Array = parents_of[c]
		ps.sort()
		var key := str(ps)
		if not fam.has(key):
			fam[key] = {"parents": ps, "children": []}
		fam[key]["children"].append(c)
	return fam.values()

func is_line(u: int) -> bool:
	return bool(_by.get(u, {}).get("line", true))

## Rows top-down: each person on the line sits under the middle of their
## parents, the other parent of their children beside them on the outside;
## units are pushed apart to one slot, then the row re-centred.
func _layout() -> void:
	_pos.clear()
	var partner := {}   # uid -> the other parent they share a drawn child with
	for f in families:
		var ps: Array = f["parents"]
		if ps.size() == 2 and _by.has(int(ps[0])) and _by.has(int(ps[1])) \
				and int(_by[int(ps[0])]["depth"]) == int(_by[int(ps[1])]["depth"]):
			if not partner.has(int(ps[0])) and not partner.has(int(ps[1])):
				partner[int(ps[0])] = int(ps[1])
				partner[int(ps[1])] = int(ps[0])
	var parents_of := {}
	for f in families:
		for c in f["children"]:
			parents_of[int(c)] = f["parents"]
	var rows := {}
	for n in nodes:
		var k := int(n["depth"])
		if not rows.has(k):
			rows[k] = []
		rows[k].append(int(n["uid"]))
	var keys: Array = rows.keys()
	keys.sort()
	for k in keys:
		var row: Array = rows[k]
		row.sort()
		var want := {}
		for u in row:
			var xs: Array = []
			for pu in parents_of.get(u, []):
				if _pos.has(int(pu)):
					xs.append(float(_pos[int(pu)].x))
			if not xs.is_empty():
				var s := 0.0
				for x in xs:
					s += x
				want[u] = s / xs.size()
		if want.is_empty():
			for i in row.size():
				want[row[i]] = float(i) - (row.size() - 1) * 0.5
		var centre := 0.0
		for u in want:
			centre += float(want[u])
		centre /= maxf(want.size(), 1.0)
		# units: [[uid, offset]...] around an anchor
		var units: Array = []
		var used := {}
		var ties := 0
		for u in row:
			if used.has(u):
				continue
			used[u] = true
			var p: int = partner.get(u, -1)
			if p >= 0 and row.has(p) and not used.has(p):
				used[p] = true
				if want.has(u) and want.has(p):
					var a: float = (float(want[u]) + float(want[p])) * 0.5
					var lo: int = u if float(want[u]) <= float(want[p]) else p
					var hi: int = p if lo == u else u
					units.append({"at": a, "m": [[lo, -0.5], [hi, 0.5]], "i": units.size()})
				else:
					var anchor: int = u if want.has(u) else p
					var other: int = p if anchor == u else u
					var a: float = float(want.get(anchor, centre))
					var side := -1.0 if a < centre - 0.001 else 1.0
					if absf(a - centre) <= 0.001:
						side = -1.0 if ties % 2 == 0 else 1.0
						ties += 1
					var m: Array = [[anchor, 0.0], [other, side]]
					if side < 0.0:
						m.reverse()
					units.append({"at": a, "m": m, "i": units.size()})
			else:
				units.append({"at": float(want.get(u, centre)), "m": [[u, 0.0]], "i": units.size()})
		units.sort_custom(func(x, y): return float(x["at"]) < float(y["at"]) or (float(x["at"]) == float(y["at"]) and int(x["i"]) < int(y["i"])))
		var placed: Array = []
		var cursor := -INF
		var moved := 0.0
		var count := 0
		for un in units:
			var at: float = un["at"]
			var lo: float = at + float(un["m"][0][1])
			var shift := maxf(0.0, cursor + 1.0 - lo) if cursor > -INF else 0.0
			for it in un["m"]:
				placed.append([int(it[0]), at + float(it[1]) + shift])
				moved += shift
				count += 1
			cursor = at + float(un["m"][-1][1]) + shift
		var back := moved / maxf(count, 1.0) if k > 0 else 0.0
		for it in placed:
			_pos[int(it[0])] = Vector2(float(it[1]) - back, float(k))
	_span = Vector2(INF, -INF)
	for u in _pos:
		_span.x = minf(_span.x, _pos[u].x)
		_span.y = maxf(_span.y, _pos[u].x)
	if _span.x == INF:
		_span = Vector2.ZERO

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
	var w := minf(vs.x * 0.86, 1240.0)
	return Rect2(Vector2((vs.x - w) * 0.5, vs.y * 0.12), Vector2(w, h))

## Screen position of a star (before the dissolve drift).
func _at(u: int, box: Rect2) -> Vector2:
	var p: Vector2 = _pos.get(u, Vector2(0.0, 0.0))
	var span := _span.y - _span.x
	var slot := minf(box.size.x / maxf(span + 1.0, 1.0), SLOT_MAX)
	var mid := (_span.x + _span.y) * 0.5
	var at := Vector2(box.position.x + box.size.x * 0.5 + (p.x - mid) * slot,
		box.position.y + p.y / float(depth) * box.size.y)
	if dissolve > 0.0:
		var d: Vector2 = _drift.get(u, Vector2(0, -1))
		at += d * dissolve * dissolve * 140.0
	return at

func _row_t(k: int) -> float:
	return float(row_times[k]) if k < row_times.size() else 0.0

func _depth_of(u: int) -> int:
	return int(_by.get(u, {}).get("depth", 0))

## When a person's star starts to appear.
func _appear_t(u: int) -> float:
	return _row_t(_depth_of(u)) + (0.0 if is_line(u) else SPOUSE_LAG)

func _process(_d: float) -> void:
	if visible and t >= 0.0:
		queue_redraw()

## Draws the part 0..u of a polyline (by length).
func _partial(pts: PackedVector2Array, u: float, c: Color, w: float) -> void:
	if u <= 0.0 or pts.size() < 2:
		return
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var left := total * clampf(u, 0.0, 1.0)
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if seg >= left:
			out.append(pts[i].lerp(pts[i + 1], left / maxf(seg, 0.001)))
			break
		out.append(pts[i + 1])
		left -= seg
	if out.size() >= 2:
		draw_polyline(out, c, w, true)

func _draw() -> void:
	if t < 0.0 or nodes.is_empty():
		return
	var box := _box()
	var fade := 1.0 - dissolve
	var row_h := box.size.y / float(depth)
	# couples: a bar between the two stars, drawn out from the one on the line
	for f in families:
		var ps: Array = f["parents"]
		if ps.size() != 2 or not _pos.has(int(ps[0])) or not _pos.has(int(ps[1])):
			continue
		var a := int(ps[0])
		var b := int(ps[1])
		if _depth_of(a) != _depth_of(b):
			continue
		if not is_line(a) and is_line(b):
			var s := a
			a = b
			b = s
		var u := clampf((t - maxf(_appear_t(a), _appear_t(b))) / 0.9, 0.0, 1.0)
		if u <= 0.0:
			continue
		var pa := _at(a, box)
		var pb := _at(b, box)
		var dir := (pb - pa).normalized()
		var m := (pa + pb) * 0.5
		var both := is_line(a) and is_line(b)
		_partial(PackedVector2Array([pa + dir * 9.0, m]), minf(u * 2.0, 1.0), Color(LINE, LINE_A * fade), 2.4)
		_partial(PackedVector2Array([m, pb - dir * 9.0]), maxf(u * 2.0 - 1.0, 0.0),
			Color(LINE, (LINE_A if both else FAINT_A) * fade), 2.4 if both else 1.6)
	# families: from the middle of the couple (or the one parent) down to a bar
	# over the children, then down to each child
	for f in families:
		var ps: Array = (f["parents"] as Array).filter(func(x): return _pos.has(int(x)))
		var cs: Array = (f["children"] as Array).filter(func(x): return _pos.has(int(x)))
		if ps.is_empty() or cs.is_empty():
			continue
		var k := _depth_of(int(cs[0]))
		var u := clampf((t - _row_t(k) + 0.8) / ROW_DRAW, 0.0, 1.0)
		if u <= 0.0:
			continue
		var top := Vector2.ZERO
		for p in ps:
			top += _at(int(p), box)
		top /= ps.size()
		if ps.size() == 1:
			top += Vector2(0, 10)
		var bar_y := _at(int(cs[0]), box).y - row_h * 0.36
		var lit := cs.any(func(c): return is_line(int(c)))
		var col := Color(LINE, (LINE_A if lit else FAINT_A) * fade)
		var wd := 2.4 if lit else 1.6
		_partial(PackedVector2Array([top, Vector2(top.x, bar_y)]), u / 0.4, col, wd)
		for c in cs:
			var pc := _at(int(c), box)
			var cc := Color(LINE, (LINE_A if is_line(int(c)) else FAINT_A) * fade)
			_partial(PackedVector2Array([Vector2(top.x, bar_y), Vector2(pc.x, bar_y), pc - Vector2(0, 9)]),
				(u - 0.4) / 0.6, cc, wd if is_line(int(c)) else 1.6)
	# stars and names
	for n in nodes:
		var u := int(n["uid"])
		var a := clampf((t - _appear_t(u)) / 1.2, 0.0, 1.0)
		if a <= 0.0:
			continue
		var p := _at(u, box)
		var crew := bool(n.get("crew", false))
		var line := bool(n.get("line", true))
		var dim := 1.0 if line else 0.42
		var tw := 0.75 + 0.25 * sin(t * 2.3 + u)
		var r := (5.5 if crew else (4.0 if line else 3.0)) * (0.6 + 0.4 * a)
		var star_a := a * (1.0 - dissolve * 0.35) * tw * dim
		_star(p, r * (1.0 - dissolve * 0.5), Color(CREW if crew else Color(1, 0.96, 0.86), star_a))
		var name_a := a * fade * (1.0 if line else 0.5)
		if name_a > 0.01:
			var f: Font = _font_b if crew else _font
			var fs := 40 if bool(n.get("commander", false)) else (34 if crew else (30 if line else 24))
			var text := str(n["name"])
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := p + Vector2(-w * 0.5, 40 if line else 36)
			draw_string(f, at + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * name_a))
			draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, name_a))

## A soft four-pointed star.
func _star(p: Vector2, r: float, c: Color) -> void:
	draw_circle(p, r * 3.2, Color(c, c.a * 0.12))
	draw_circle(p, r * 1.6, Color(c, c.a * 0.3))
	draw_line(p - Vector2(r * 3.0, 0), p + Vector2(r * 3.0, 0), Color(c, c.a * 0.55), 1.4, true)
	draw_line(p - Vector2(0, r * 3.0), p + Vector2(0, r * 3.0), Color(c, c.a * 0.55), 1.4, true)
	draw_circle(p, r * 0.7, c)
