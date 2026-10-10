class_name InkWidgets extends RefCounted
## Small drawn widgets for paper UI: dice, check boxes, segmented choices,
## ornaments, a link button, and the hand-trust row.

## A button that draws a six-sided die (for rerolling names).
class Dice extends Button:
	var face: int = 5
	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "Roll a new name"
		pressed.connect(func(): face = (face + 1 + randi() % 5) % 6 + 1; queue_redraw())
	func _draw() -> void:
		var s := minf(size.x, size.y) - 12.0
		var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		var hov := is_hovered()
		var tilt := -0.12 if hov else 0.0
		draw_set_transform(size * 0.5, tilt, Vector2.ONE)
		var rr := Rect2(-r.size * 0.5, r.size)
		var box := InkBox.make(Color("#fbf3e1") if not button_pressed else UiTheme.PAPER_DARK, UiTheme.INK, 0.0, 6.0, 2.0)
		box.shadow = Color(0.3, 0.2, 0.1, 0.25)
		box.draw(get_canvas_item(), rr)
		var pip := s * 0.09
		var q := s * 0.26
		var spots := {1: [Vector2.ZERO], 2: [Vector2(-q, -q), Vector2(q, q)], 3: [Vector2(-q, -q), Vector2.ZERO, Vector2(q, q)],
			4: [Vector2(-q, -q), Vector2(q, -q), Vector2(-q, q), Vector2(q, q)],
			5: [Vector2(-q, -q), Vector2(q, -q), Vector2.ZERO, Vector2(-q, q), Vector2(q, q)],
			6: [Vector2(-q, -q), Vector2(q, -q), Vector2(-q, 0), Vector2(q, 0), Vector2(-q, q), Vector2(q, q)]}
		for p in spots[clampi(face, 1, 6)]:
			draw_circle(p, pip, UiTheme.INK_RED if face == 1 else UiTheme.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A toggle drawn as an inked box with a tick, followed by its label.
class Check extends Button:
	func _init(label: String = "", on: bool = false) -> void:
		toggle_mode = true
		button_pressed = on
		text = label
		flat = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 36)
		add_theme_constant_override(&"h_separation", 0)
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 36
		for k in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(k, empty)
		add_theme_font_override(&"font", UiTheme.font(&"body"))
		toggled.connect(func(_on): queue_redraw())
	func _draw() -> void:
		var s := 22.0
		var r := Rect2(Vector2(4, (size.y - s) * 0.5), Vector2(s, s))
		var box := InkBox.make(Color(1, 1, 1, 0.25) if not is_hovered() else Color(UiTheme.PAPER_DARK, 0.8), UiTheme.INK, 0.0, 4.0, 1.8)
		box.draw(get_canvas_item(), r)
		if button_pressed:
			var a := r.position + Vector2(s * 0.2, s * 0.55)
			var b := r.position + Vector2(s * 0.43, s * 0.8)
			var c := r.position + Vector2(s * 0.95, s * 0.05)
			draw_polyline(PackedVector2Array([a, b, c]), UiTheme.INK_RED, 3.0, true)

## A row of mutually exclusive choices ("Gentle | Normal | Harsh").
static func segmented(options: Array, current: int, on_pick: Callable, min_w: float = 104.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	var g := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.toggle_mode = true
		b.button_group = g
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(min_w, 36)
		b.button_pressed = i == current
		b.add_theme_font_size_override(&"font_size", 17)
		b.pressed.connect(on_pick.bind(i))
		h.add_child(b)
	return h

## A flourish rule: a thin ink line with a diamond in the middle.
class Rule extends Control:
	var col: Color = Color(UiTheme.INK_SOFT, 0.7)
	func _init(w: float = 0.0) -> void:
		custom_minimum_size = Vector2(w, 14)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL if w == 0.0 else Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y * 0.5
		var m := size.x * 0.5
		draw_line(Vector2(size.x * 0.06, y), Vector2(m - 10, y), col, 1.2, true)
		draw_line(Vector2(m + 10, y), Vector2(size.x * 0.94, y), col, 1.2, true)
		draw_colored_polygon(PackedVector2Array([Vector2(m, y - 5), Vector2(m + 6, y), Vector2(m, y + 5), Vector2(m - 6, y)]), col)
		draw_circle(Vector2(m - 14, y), 1.6, col)
		draw_circle(Vector2(m + 14, y), 1.6, col)

## Five little open hands, filled to the person's trust.
class TrustRow extends Control:
	var trust: int = 0
	var s: float = 16.0
	func _init(t: int = 0, sz: float = 16.0) -> void:
		trust = t
		s = sz
		custom_minimum_size = Vector2(sz * 5.6, sz * 1.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in 5:
			var at := Vector2(s * 0.6 + i * s * 1.1, size.y * 0.58)
			PortraitFrame.draw_hand_mark(self, at, s * 0.55, UiTheme.OCHRE if i < trust else Color(UiTheme.INK_SOFT, 0.22))

## Ink stars for skills.
static func stars(n: int, total: int = 5, r: float = 7.0) -> UiPips:
	var st := UiPips.new()
	st.stars = true
	st.radius = r
	st.on_color = UiTheme.GOLD.darkened(0.1)
	st.off_color = Color(UiTheme.INK_SOFT, 0.18)
	st.setup(clampi(n, 0, total), total)
	return st

## A flat text link in ink (names of parents, children...).
static func link(text: String, cb: Callable, size_px: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var e := StyleBoxEmpty.new()
	e.content_margin_left = 2; e.content_margin_right = 2
	var hov := InkBox.new()
	hov.underline_only = true
	hov.ink = UiTheme.OCHRE
	hov.width = 1.5
	hov.content_margin_left = 2; hov.content_margin_right = 2
	for k in [&"normal", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(k, e)
	for k in [&"hover", &"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(k, hov)
	b.add_theme_color_override(&"font_color", UiTheme.INK_RED)
	b.add_theme_color_override(&"font_hover_color", UiTheme.OCHRE)
	b.add_theme_color_override(&"font_pressed_color", UiTheme.OCHRE)
	b.add_theme_color_override(&"font_hover_pressed_color", UiTheme.OCHRE)
	b.add_theme_font_override(&"font", UiTheme.font(&"semibold"))
	b.add_theme_font_size_override(&"font_size", size_px)
	b.pressed.connect(cb)
	return b

## A drawn icon for a gift kind (flowers, carved hand, stone, pot, cloth...).
class GiftIcon extends Control:
	var kind: String = ""
	func _init(k: String = "", sz: float = 40.0) -> void:
		kind = k
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.5
		draw_circle(c, s * 0.95, Color(UiTheme.PAPER_DARK, 0.6))
		draw_arc(c, s * 0.95, 0, TAU, 32, Color(UiTheme.INK_SOFT, 0.6), 1.2, true)
		if kind.contains("hand"):
			PortraitFrame.draw_hand_mark(self, c + Vector2(0, s * 0.15), s * 0.75, Color("#9a5a2a"))
		elif kind.contains("flower"):
			for i in 5:
				var a := TAU * i / 5.0
				draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.32, s * 0.22, Color("#d2617a"))
			draw_circle(c, s * 0.18, Color("#e8b33a"))
		elif kind.contains("stone"):
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, s * 0.3), c + Vector2(-s * 0.4, -s * 0.35), c + Vector2(s * 0.3, -s * 0.45), c + Vector2(s * 0.62, s * 0.1), c + Vector2(s * 0.3, s * 0.45)]), Color("#8d8a84"))
			PortraitFrame.draw_hand_mark(self, c + Vector2(0, s * 0.05), s * 0.45, Color("#a8492a"))
		elif kind.contains("pot"):
			draw_circle(c + Vector2(0, s * 0.12), s * 0.5, Color("#b86a3c"))
			draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.55), Vector2(s * 0.44, s * 0.3)), Color("#b86a3c"))
			draw_line(c + Vector2(-s * 0.45, s * 0.1), c + Vector2(s * 0.45, s * 0.1), Color("#f0d9a0"), 2.0)
		else:
			draw_rect(Rect2(c - Vector2(s * 0.5, s * 0.4), Vector2(s, s * 0.8)), Color("#7d8fa3"))
			for i in 3:
				draw_line(c + Vector2(-s * 0.5, -s * 0.2 + i * s * 0.2), c + Vector2(s * 0.5, -s * 0.2 + i * s * 0.2), Color(1, 1, 1, 0.5), 1.5)
