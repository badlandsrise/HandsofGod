class_name InkBox extends StyleBox
## A hand-drawn box: a softly wobbling rounded outline in ink over an optional
## fill, like a frame drawn with a quill on parchment. The wobble is seeded from
## the rect size, so a given box looks the same every frame.

var fill: Color = Color(0, 0, 0, 0)
var ink: Color = Color(0.23, 0.15, 0.08, 0.85)
var width: float = 1.6
var wobble: float = 1.1
var radius: float = 7.0
var seed_i: int = 0
var double_line: bool = false
var underline_only: bool = false
var shadow: Color = Color(0, 0, 0, 0)
var shadow_offset: Vector2 = Vector2(2, 3)
var grow: float = 0.0

static func make(fill_c: Color, ink_c: Color, pad: float = 10.0, rad: float = 7.0, w: float = 1.6) -> InkBox:
	var b := InkBox.new()
	b.fill = fill_c
	b.ink = ink_c
	b.radius = rad
	b.width = w
	b.content_margin_left = pad
	b.content_margin_right = pad
	b.content_margin_top = pad * 0.6
	b.content_margin_bottom = pad * 0.6
	return b

func _draw(ci: RID, rect: Rect2) -> void:
	rect = rect.grow(grow)
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var s := seed_i + int(rect.size.x * 7.0 + rect.size.y * 13.0)
	if underline_only:
		if fill.a > 0.0:
			RenderingServer.canvas_item_add_rect(ci, rect, fill)
		var line := PackedVector2Array()
		var n := maxi(int(rect.size.x / 14.0), 2)
		for i in n + 1:
			var t := float(i) / n
			line.append(Vector2(rect.position.x + rect.size.x * t, rect.end.y - 1.0 + _j(s, i) * wobble))
		RenderingServer.canvas_item_add_polyline(ci, line, PackedColorArray([ink]), width, true)
		return
	var pts := outline(rect, radius, s, wobble)
	if shadow.a > 0.0:
		var sp := PackedVector2Array()
		for p in pts:
			sp.append(p + shadow_offset)
		_poly(ci, sp, shadow)
	if fill.a > 0.0:
		_poly(ci, pts, fill)
	if ink.a > 0.0 and width > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, closed, PackedColorArray([ink]), width, true)
		if double_line:
			var inner := outline(rect.grow(-4.0), maxf(radius - 3.0, 1.0), s + 17, wobble * 0.8)
			inner.append(inner[0])
			RenderingServer.canvas_item_add_polyline(ci, inner, PackedColorArray([Color(ink, ink.a * 0.55)]), maxf(width * 0.6, 1.0), true)

static func _poly(ci: RID, pts: PackedVector2Array, c: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(c)
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)

## Smooth deterministic jitter in -1..1.
static func _j(s: int, i: int) -> float:
	var a := float(s % 97) * 0.731
	return sin(i * 1.71 + a) * 0.55 + sin(i * 0.43 + a * 2.3) * 0.45

## A wobbly rounded rectangle outline (clockwise points).
static func outline(rect: Rect2, rad: float, s: int, wob: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := minf(rad, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	var i := 0
	for ci in 4:
		var c: Vector2 = corners[ci][0]
		var a0: float = corners[ci][1]
		# straight edge leading into this corner
		var prev: Vector2 = corners[(ci + 3) % 4][0]
		var pa: float = corners[(ci + 3) % 4][1] + PI * 0.5
		var from := prev + Vector2(cos(pa), sin(pa)) * r
		var to := c + Vector2(cos(a0), sin(a0)) * r
		var seg := maxi(int(from.distance_to(to) / 16.0), 1)
		var nrm := Vector2(cos(a0), sin(a0))
		for k in seg:
			var t := float(k) / seg
			pts.append(from.lerp(to, t) + nrm * _j(s, i) * wob)
			i += 1
		var steps := maxi(int(r / 2.5), 2)
		for k in steps + 1:
			var a := a0 + PI * 0.5 * float(k) / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (r + _j(s, i) * wob * 0.5))
			i += 1
	return pts
