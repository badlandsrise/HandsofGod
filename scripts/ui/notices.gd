class_name Notices extends Control
## Moments worth a flourish: a "dream came true" card with a burst of petals,
## and a ribbon banner when a region opens. Also builds the alert cards the
## HUD stacks on the right edge (portrait of the person the alert is about,
## click to look). Everything animates on real time, so it plays while paused.

const DREAM_SECONDS := 5.5
const REGION_SECONDS := 6.0

var _items: Array = []          # {node, t, life}
var _petals: Petals

func _ready() -> void:
	name = "Notices"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.paper_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_petals = Petals.new()
	add_child(_petals)
	Events.dream_done.connect(dream_done)
	Events.region_opened.connect(region_opened)

func dream_done(id: StringName) -> void:
	var d: DreamDef = Defs.dream(id)
	var text := d.text if d != null and d.text != "" else String(id).capitalize()
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.paper_box(34.0, 1)
	p.add_theme_stylebox_override(&"panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	p.add_child(v)
	var k := UiTheme.ink_label("THE GREAT DREAM OF THIS AGE CAME TRUE" if d != null and d.gate else "A DREAM CAME TRUE", 14, &"semibold", UiTheme.INK_RED)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var t := UiTheme.ink_label("\"%s\"" % text, 26, &"title_italic")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 520
	v.add_child(t)
	var rw := ""
	if d != null:
		var bits: Array = []
		if d.reward_faith > 0.0:
			bits.append("+%d faith" % int(d.reward_faith))
		for pw in d.unlocks_powers:
			var pd: PowerDef = Defs.power(pw)
			if pd != null:
				bits.append(pd.title)
		rw = "  ·  ".join(bits)
	if rw != "":
		var r := UiTheme.ink_label(rw, 16, &"semibold", UiTheme.OCHRE.darkened(0.2))
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(r)
	add_child(p)
	_place_top(p)
	_items.append({"node": p, "t": DREAM_SECONDS, "life": DREAM_SECONDS})
	_pop_in(p)
	await get_tree().process_frame
	if is_instance_valid(p):
		_petals.burst(p.position + p.size * Vector2(0.5, 0.45), 70)

func region_opened(id: StringName) -> void:
	var opens := ""
	for pd in Defs.powers.values():
		if pd.opens_region == id and pd.what_it_opens != "":
			opens = pd.what_it_opens
	var b := RegionRibbon.new()
	b.title = BookData.region_title(id).capitalize()
	b.subtitle = opens if opens != "" else "A new place is open to the people."
	add_child(b)
	b.size = Vector2(760, 116)
	_place_top(b)
	_items.append({"node": b, "t": REGION_SECONDS, "life": REGION_SECONDS})
	_pop_in(b)

## Stacks banners down from the top of the screen, under the stores strip.
func _place_top(c: Control) -> void:
	var y := 92.0
	for it in _items:
		var n: Control = it["node"]
		if is_instance_valid(n) and n != c:
			y = maxf(y, n.position.y + n.size.y + 10.0)
	c.position.y = y
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	var w := get_size().x if get_size().x > 10.0 else get_viewport_rect().size.x
	c.position = Vector2((w - c.size.x) * 0.5, y)
	c.pivot_offset = c.size * 0.5

func _pop_in(c: Control) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.35)
	tw.tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(_d: float) -> void:
	var dt := Clock.real_delta
	for it in _items.duplicate():
		it["t"] -= dt
		var n: Control = it["node"]
		if not is_instance_valid(n):
			_items.erase(it)
			continue
		if it["t"] < 0.6:
			n.modulate.a = clampf(it["t"] / 0.6, 0.0, 1.0)
		if it["t"] <= 0.0:
			_items.erase(it)
			n.queue_free()

# ---------------------------------------------------------------- alerts

## Finds the person an alert is about: a name in the text, else whoever is
## standing where it happened.
static func person_for_alert(text: String, at: Vector3) -> Node:
	var best: Node = null
	var best_d := INF
	for p in Village.alive():
		if not (&"given_name" in p):
			continue
		var n := str(p.given_name)
		if n == "":
			continue
		var re := RegEx.create_from_string("\\b%s\\b" % n)
		if re.search(text) != null:
			var d: float = p.global_position.distance_to(at) if at.is_finite() and p is Node3D else 0.0
			if d < best_d:
				best_d = d
				best = p
	if best != null or not at.is_finite():
		return best
	for p in Village.alive():
		if p is Node3D:
			var d: float = (p as Node3D).global_position.distance_to(at)
			if d < 1.5 and d < best_d:
				best_d = d
				best = p
	return best

## An alert card: a portrait (or a warning sigil) and the message on parchment.
static func alert_card(text: String, at: Vector3, on_click: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 64)
	b.theme = UiTheme.paper_theme()
	var who := person_for_alert(text, at)
	var warm := text.to_lower().contains("arrived") or text.to_lower().contains("born") or text.to_lower().contains("friend")
	var accent := UiTheme.LEAF if warm else UiTheme.INK_RED
	var n := InkBox.make(Color(UiTheme.PAPER, 0.96), Color(accent, 0.85), 10.0, 10.0, 2.0)
	n.shadow = Color(0, 0, 0, 0.3)
	n.content_margin_left = 10
	var h := n.duplicate() as InkBox
	h.fill = UiTheme.PAPER.lightened(0.08)
	h.width = 2.6
	b.add_theme_stylebox_override(&"normal", n)
	b.add_theme_stylebox_override(&"hover", h)
	b.add_theme_stylebox_override(&"pressed", h)
	b.tooltip_text = "Click to look" if at.is_finite() else ""
	if at.is_finite():
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10; row.offset_right = -10; row.offset_top = 6; row.offset_bottom = -6
	row.add_theme_constant_override(&"separation", 10)
	b.add_child(row)
	var icon: Control
	if who != null:
		icon = PortraitFrame.make(BookData.record_of(who), 50.0)
	else:
		icon = Sigil.new()
		(icon as Sigil).warm = warm
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := CenterContainer.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(icon)
	row.add_child(ic)
	var l := UiTheme.ink_label(text, 16, &"semibold")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	if on_click.is_valid():
		b.pressed.connect(on_click)
	l.custom_minimum_size.x = 200
	# tall enough for the wrapped text
	var f := UiTheme.font(&"semibold")
	var lines := ceili(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 205.0)
	b.custom_minimum_size.y = maxf(64.0, lines * 22.0 + 20.0)
	return b

class Sigil extends Control:
	var warm := false
	func _init() -> void:
		custom_minimum_size = Vector2(46, 46)
	func _draw() -> void:
		var c := size * 0.5
		var col := UiTheme.LEAF if warm else UiTheme.INK_RED
		draw_circle(c, 20.0, Color(col, 0.15))
		draw_arc(c, 20.0, 0, TAU, 32, col, 2.0, true)
		if warm:
			PortraitFrame.draw_hand_mark(self, c + Vector2(0, 3), 14.0, col)
		else:
			draw_line(c + Vector2(0, -11), c + Vector2(0, 4), col, 4.0, true)
			draw_circle(c + Vector2(0, 11), 2.6, col)

## A red ribbon with notched ends carrying a region's name.
class RegionRibbon extends Control:
	var title := ""
	var subtitle := ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var red := Color("#8e2f1c")
		var dark := red.darkened(0.35)
		# tails
		for side in [-1, 1]:
			var x0: float = w * 0.5 + side * (w * 0.5 - 60)
			var x1: float = w * 0.5 + side * (w * 0.5)
			var pts := PackedVector2Array([Vector2(x0, 18), Vector2(x1, 18), Vector2(x1 - side * 26, 45), Vector2(x1, 72), Vector2(x0, 72)])
			draw_colored_polygon(pts, dark)
		var body := PackedVector2Array([Vector2(46, 6), Vector2(w - 46, 6), Vector2(w - 46, 62), Vector2(46, 62)])
		draw_colored_polygon(body, red)
		draw_line(Vector2(52, 12), Vector2(w - 52, 12), Color(1, 0.85, 0.6, 0.45), 1.5)
		draw_line(Vector2(52, 56), Vector2(w - 52, 56), Color(1, 0.85, 0.6, 0.45), 1.5)
		var f := UiTheme.font(&"title")
		draw_string(f, Vector2(0, 47), title, HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color("#fbeed2"))
		# the line under it, on a paper slip
		var fi := UiTheme.font(&"italic")
		var tw := fi.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40.0
		var slip := Rect2(Vector2((w - tw) * 0.5, 74), Vector2(tw, 34))
		var box := InkBox.make(Color(UiTheme.PAPER, 0.97), Color(UiTheme.INK_SOFT, 0.7), 0.0, 6.0, 1.4)
		box.shadow = Color(0, 0, 0, 0.25)
		box.draw(get_canvas_item(), slip)
		draw_string(fi, Vector2(slip.position.x, slip.position.y + 23), subtitle, HORIZONTAL_ALIGNMENT_CENTER, slip.size.x, 18, UiTheme.INK)
		var sm := UiTheme.font(&"semibold")
		draw_string(sm, Vector2(0, -2), "THE WAY IS OPEN", HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color("#fbeed2"))

## Falling petals and paper flecks for a celebration.
class Petals extends Control:
	var parts: Array = []
	const COLS := [Color("#d2617a"), Color("#e8b33a"), Color("#f4ead2"), Color("#b8661f"), Color("#8db35a")]
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func burst(at: Vector2, n: int) -> void:
		for i in n:
			var a := randf_range(-PI, 0.0)
			var sp := randf_range(160.0, 460.0)
			parts.append({"p": at + Vector2(randf_range(-200, 200), randf_range(-20, 20)), "v": Vector2(cos(a) * sp * 0.8, sin(a) * sp),
				"r": randf() * TAU, "w": randf_range(-6.0, 6.0), "c": COLS[randi() % COLS.size()], "life": randf_range(2.2, 3.6), "s": randf_range(4.0, 8.0)})
	func _process(_d: float) -> void:
		if parts.is_empty():
			return
		var dt := Clock.real_delta
		for p in parts.duplicate():
			p["life"] -= dt
			if p["life"] <= 0.0:
				parts.erase(p)
				continue
			p["v"] = p["v"] * (1.0 - minf(1.6 * dt, 1.0)) + Vector2(sin(p["r"] * 2.0) * 30.0, 260.0) * dt
			p["p"] += p["v"] * dt
			p["r"] += p["w"] * dt
		queue_redraw()
	func _draw() -> void:
		for p in parts:
			var c: Color = p["c"]
			c.a = clampf(p["life"], 0.0, 1.0)
			var s: float = p["s"]
			draw_set_transform(p["p"], p["r"], Vector2(1.0, 0.55 + 0.45 * absf(sin(p["r"] * 3.0))))
			draw_colored_polygon(PackedVector2Array([Vector2(-s, 0), Vector2(0, -s * 0.6), Vector2(s, 0), Vector2(0, s * 0.6)]), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
