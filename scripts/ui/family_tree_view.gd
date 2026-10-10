class_name FamilyTreeView extends Control
## The Family Tree page: everyone from the first two down, laid out by
## BookData.tree_layout. Wheel zooms about the cursor, dragging pans, clicking a
## person picks them (the Book opens their page). The dead are greyed with a
## memorial stone; names the hand gave carry its mark.

signal person_picked(uid: int)

const SX := 150.0          # slot width at zoom 1
const SY := 172.0          # generation height at zoom 1
const NODE := 74.0         # portrait size at zoom 1
const GEN_NAMES := ["The first two", "Their children", "Grandchildren", "Great-grandchildren"]

var records: Array = []
var layout: Dictionary = {}
var zoom: float = 1.0
var offset: Vector2 = Vector2.ZERO
var selected: int = 0
var _by: Dictionary = {}
var _frames: Dictionary = {}
var _drag := false
var _drag_moved := 0.0
var _press_pos := Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(_place)

func set_records(r: Array) -> void:
	records = r
	_by = BookData.by_uid(r)
	layout = BookData.tree_layout(r)
	for c in _frames.values():
		c.queue_free()
	_frames.clear()
	for u in _by:
		var f := PortraitFrame.make(_by[u], NODE)
		f.backdrop = Color("#ead6aa")
		add_child(f)
		_frames[u] = f
	fit()

## Zoom and centre so the whole tree fits.
func fit() -> void:
	if layout.is_empty() or size.x < 10.0:
		_place.call_deferred()
		return
	var w := (float(layout.get("width", 0.0)) + 1.0) * SX
	var h := (float(layout.get("depth", 0)) + 1.0) * SY
	zoom = clampf(minf((size.x - 160.0) / w, (size.y - 40.0) / h), 0.45, 1.25)
	var tw := w * zoom
	offset = Vector2((size.x - tw) * 0.5 + SX * 0.5 * zoom + 40.0, 30.0 + NODE * 0.5 * zoom)
	_place()

func zoom_by(f: float, about: Vector2) -> void:
	var nz := clampf(zoom * f, 0.35, 2.4)
	var k := nz / zoom
	offset = about + (offset - about) * k
	zoom = nz
	_place()

func node_center(uid: int) -> Vector2:
	var p: Vector2 = layout["pos"].get(uid, Vector2.ZERO)
	return offset + Vector2(p.x * SX, p.y * SY) * zoom

func _place() -> void:
	if layout.is_empty():
		queue_redraw()
		return
	var s := NODE * zoom
	for u in _frames:
		var f: PortraitFrame = _frames[u]
		var c := node_center(u)
		f.custom_minimum_size = Vector2(s, s)
		f.size = Vector2(s, s)
		f.position = c - Vector2(s, s) * 0.5
		f.ring = UiTheme.OCHRE if u == selected else UiTheme.INK_SOFT
		f.ring_width = 3.5 if u == selected else 2.0
		f.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if layout.is_empty() or _by.is_empty():
		var f := UiTheme.font(&"italic")
		draw_string(f, Vector2(0, size.y * 0.45), "The tree has no names yet.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UiTheme.INK_SOFT)
		return
	var ink := Color(UiTheme.INK_SOFT, 0.85)
	var lw := maxf(1.6 * zoom, 1.0)
	var r := NODE * zoom * 0.5
	# generation labels
	var gf := UiTheme.font(&"title_italic")
	for g in int(layout["depth"]) + 1:
		var y := offset.y + g * SY * zoom
		var label: String = GEN_NAMES[g] if g < GEN_NAMES.size() else "Generation %d" % (g + 1)
		draw_string(gf, Vector2(10, y + 6), label, HORIZONTAL_ALIGNMENT_LEFT, 150, 17, Color(UiTheme.INK_SOFT, 0.75))
		draw_dashed_line(Vector2(10, y + 14), Vector2(120, y + 14), Color(UiTheme.INK_SOFT, 0.3), 1.0, 4.0)
	# couples: a double line between partners
	for cp in layout["couples"]:
		var a := node_center(int(cp[0]))
		var b := node_center(int(cp[1]))
		if a.x > b.x:
			var t := a; a = b; b = t
		var off := Vector2(0, 3.0 * zoom)
		draw_line(a + Vector2(r, 0) - off, b - Vector2(r, 0) - off, ink, lw, true)
		draw_line(a + Vector2(r, 0) + off, b - Vector2(r, 0) + off, ink, lw, true)
	# families: from the parents down to a bar, then to each child
	for fam in layout["families"]:
		var ps: Array = fam["parents"]
		var top := Vector2.ZERO
		for u in ps:
			top += node_center(int(u))
		top /= maxf(ps.size(), 1)
		var start := top + Vector2(0, 3.0 * zoom + (0.0 if ps.size() > 1 else r))
		var kids: Array = fam["children"]
		var bar_y := top.y + SY * zoom * 0.58
		draw_line(start, Vector2(top.x, bar_y), ink, lw, true)
		var minx := top.x
		var maxx := top.x
		for k in kids:
			var c := node_center(int(k))
			minx = minf(minx, c.x)
			maxx = maxf(maxx, c.x)
			draw_line(Vector2(c.x, bar_y), c - Vector2(0, r), ink, lw, true)
		draw_line(Vector2(minx, bar_y), Vector2(maxx, bar_y), ink, lw, true)
	# names and dates
	var nf := UiTheme.font(&"hand_bold")
	var df := UiTheme.font(&"italic")
	var fs := int(clampf(24.0 * zoom, 13.0, 40.0))
	var ds := int(clampf(14.0 * zoom, 10.0, 22.0))
	for u in _by:
		var rec: Dictionary = _by[u]
		var c := node_center(u)
		var dead := not bool(rec["alive"])
		var col := UiTheme.INK if not dead else Color(UiTheme.INK_SOFT, 0.6)
		draw_string(nf, Vector2(c.x - SX * zoom * 0.5, c.y + r + fs * 0.95), str(rec["name"]), HORIZONTAL_ALIGNMENT_CENTER, SX * zoom, fs, col)
		var sub := ""
		if dead:
			sub = "rests since day %d" % int(rec["died_day"]) if int(rec["died_day"]) > 0 else "remembered"
		elif int(rec["born_day"]) > 0:
			sub = "born day %d" % int(rec["born_day"])
		elif rec.get("first_two", false):
			sub = "came with the storm"
		elif rec.get("wanderer", false):
			sub = "a wanderer"
		if sub != "" and zoom > 0.55:
			draw_string(df, Vector2(c.x - SX * zoom * 0.5, c.y + r + fs * 0.95 + ds * 1.2), sub, HORIZONTAL_ALIGNMENT_CENTER, SX * zoom, ds, Color(UiTheme.INK_SOFT, 0.7))
		if u == selected:
			draw_arc(c, r + 6.0 * zoom, 0, TAU, 40, Color(UiTheme.OCHRE, 0.5), 2.0, true)

func uid_at(p: Vector2) -> int:
	var r := NODE * zoom * 0.5
	for u in _by:
		if node_center(u).distance_to(p) <= r + 2.0:
			return int(u)
	return 0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.12, mb.position)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.12, mb.position)
			accept_event()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				_drag = true
				_drag_moved = 0.0
				_press_pos = mb.position
			else:
				if _drag and _drag_moved < 6.0 and mb.button_index == MOUSE_BUTTON_LEFT:
					var u := uid_at(mb.position)
					if u != 0:
						selected = u
						_place()
						person_picked.emit(u)
				_drag = false
			accept_event()
	elif e is InputEventMouseMotion and _drag:
		var mm := e as InputEventMouseMotion
		_drag_moved += mm.relative.length()
		offset += mm.relative
		_place()
		accept_event()
	elif e is InputEventMagnifyGesture:
		zoom_by((e as InputEventMagnifyGesture).factor, (e as InputEventMagnifyGesture).position)
	elif e is InputEventPanGesture:
		offset -= (e as InputEventPanGesture).delta * 12.0
		_place()
