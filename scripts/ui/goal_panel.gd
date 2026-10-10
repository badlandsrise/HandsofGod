class_name GoalPanel extends PanelContainer
## The always-visible goal (playtest era 1, section 1): the HUD's top-left
## panel shows the people's current dream with a live checklist of everything
## it still needs (Dreams.checklist: buildings, people x/y, winters x/y, the
## festival, regions, stores). Before the next dream appears it shows "The
## people are restless..." with a hint and a stirring bar; when the age's
## last dream is done it says so. Rows with a place to look at (a plot, the
## dance spot) pan the camera when clicked; every row's tooltip is its hint.
## Rebuilt only when what it shows changes (refresh() is cheap to call often).

signal look_at(at: Vector3)

const W := 318.0

var mode: StringName = &""          # &"dream", &"teaser", &"age_done", &"free", &"none"
var dream_id: StringName = &""
var _sig: String = "~"
var _box: VBoxContainer
var _bar: StirBar = null
var _flash_t: float = 0.0

func _ready() -> void:
	name = "GoalPanel"
	custom_minimum_size.x = W
	mouse_filter = Control.MOUSE_FILTER_PASS
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 3)
	add_child(_box)
	Events.dream_done.connect(func(_id): _flash_t = 1.2; _sig = "~")
	refresh()

## The state shown now, without building anything (tests read it).
static func state() -> Dictionary:
	var e := Defs.era(Village.era)
	if e == null:
		return {"mode": &"none"}
	if not e.playable:
		return {"mode": &"free"}       # an era not built yet: the playtest ends here
	var d := Dreams.active_dream()
	if d == null:
		return {"mode": &"age_done"}
	if Dreams.revealed(d):
		return {"mode": &"dream", "dream": d, "items": Dreams.checklist(d)}
	return {"mode": &"teaser", "dream": d, "hint": Dreams.teaser_hint(d), "stir": Dreams.stirring(d)}

func refresh() -> void:
	var st := GoalPanel.state()
	mode = st["mode"]
	# the HUD shows or hides the panel (mode, and the Book)
	if mode == &"none":
		return
	var d: DreamDef = st.get("dream", null)
	dream_id = d.id if d != null else &""
	if _bar != null and is_instance_valid(_bar) and mode == &"teaser":
		_bar.value = float(st["stir"])
	var sig := "%s|%s" % [mode, dream_id]
	if mode == &"dream":
		for it in st["items"]:
			sig += "|%s%d/%d%s" % [it["key"], it["have"], it["need"], "+" if it["done"] else "-"]
	elif mode == &"teaser":
		sig += "|" + str(st["hint"])
	if sig == _sig:
		return
	_sig = sig
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_bar = null
	match mode:
		&"dream": _build_dream(d, st["items"])
		&"teaser": _build_teaser(str(st["hint"]), float(st["stir"]))
		&"age_done": _build_age_done()
		&"free": _build_free()

func _process(_d: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - Clock.real_delta, 0.0)
		self_modulate = Color(1, 1, 1).lerp(Color(1.4, 1.3, 0.9), _flash_t / 1.2)

# ---------------------------------------------------------------- building

func _head(text: String, col: Color = UiTheme.ACCENT) -> void:
	var l := Hud.make_label(text, 13, col)
	_box.add_child(l)

func _build_dream(d: DreamDef, items: Array) -> void:
	_head("THE GREAT DREAM OF THIS AGE" if d.gate else "OUR DREAM")
	var t := Hud.make_label("“%s”" % d.text, 16)
	t.add_theme_font_override(&"font", UiTheme.font(&"italic"))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = W - 24.0
	_box.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size.y = 2
	_box.add_child(gap)
	var hinted := false
	for it in items:
		_box.add_child(_row(it))
		if not it["done"] and not hinted and str(it["hint"]) != "":
			hinted = true
			var h := Hud.make_label(str(it["hint"]), 13, UiTheme.TEXT_DIM)
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h.custom_minimum_size.x = W - 50.0
			var m := MarginContainer.new()
			m.add_theme_constant_override(&"margin_left", 28)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.add_child(h)
			_box.add_child(m)

func _row(it: Dictionary) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(W - 24.0, 24)
	var at: Vector3 = it.get("at", Vector3.INF)
	b.tooltip_text = str(it["hint"]) if str(it["hint"]) != "" else ("Done." if it["done"] else "")
	if at.is_finite():
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text += ("\n" if b.tooltip_text != "" else "") + "Click to look."
		b.pressed.connect(func(): look_at.emit(at))
	else:
		b.mouse_filter = Control.MOUSE_FILTER_PASS
	var hov := UiTheme.box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 6, 4.0, 0)
	b.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"hover", hov if at.is_finite() else StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"pressed", hov)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override(&"separation", 8)
	b.add_child(h)
	var tick := Tick.new()
	tick.done = it["done"]
	tick.part = float(it["have"]) / float(maxi(int(it["need"]), 1))
	h.add_child(tick)
	var l := Hud.make_label(str(it["text"]), 15, UiTheme.TEXT_DIM if it["done"] else UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	if int(it["need"]) > 1 or (str(it["key"]).begins_with("b:")):
		var n := Hud.make_label("%d/%d" % [int(it["have"]), int(it["need"])], 15, UiTheme.GOOD if it["done"] else UiTheme.ACCENT)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(n)
	# tall enough for a wrapped line
	var f := UiTheme.font(&"body")
	var lines := ceili(f.get_string_size(str(it["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x / (W - 110.0))
	b.custom_minimum_size.y = maxf(24.0, 20.0 * lines + 4.0)
	return b

func _build_teaser(hint: String, stir: float) -> void:
	_head("THE PEOPLE ARE RESTLESS…")
	var l := Hud.make_label(hint, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W - 24.0
	_box.add_child(l)
	_bar = StirBar.new()
	_bar.value = stir
	_bar.tooltip_text = "A dream is stirring in them."
	_box.add_child(_bar)

func _build_age_done() -> void:
	_head("EVERY DREAM OF THIS AGE CAME TRUE", UiTheme.GOOD)
	var next := Defs.era(Village.era + 1)
	var l := Hud.make_label("The age can turn. Open the Village Book (F1) and begin the next one when you are ready." if next != null else "The people have everything they dreamed of.", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W - 24.0
	_box.add_child(l)

## An era that is not built yet (EraDef.playable = false): the playtest ends,
## the town lives on.
func _build_free() -> void:
	_head("THE PLAYTEST ENDS HERE", UiTheme.GOOD)
	var ed := Defs.era(Village.era)
	var l := Hud.make_label("Era %d, %s, is still being built. Your town lives on: stay as long as you like. Thank you for playing!" % [Village.era, ed.title if ed != null else "the next age"], 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W - 24.0
	_box.add_child(l)

## A drawn checkbox: a ring filling with progress, a tick when done.
class Tick extends Control:
	var done := false
	var part := 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c := size * 0.5
		if done:
			draw_circle(c, 8.5, UiTheme.GOOD.darkened(0.15))
			draw_polyline(PackedVector2Array([c + Vector2(-4.2, 0.2), c + Vector2(-1.2, 3.4), c + Vector2(4.6, -3.6)]), Color(0.1, 0.14, 0.06), 2.4, true)
		else:
			draw_arc(c, 7.5, 0, TAU, 28, Color(1, 1, 1, 0.35), 2.0, true)
			if part > 0.0:
				draw_arc(c, 7.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(part, 0.0, 1.0), 28, UiTheme.ACCENT, 2.6, true)

## How close the next dream is: a thin ember line.
class StirBar extends Control:
	var value := 0.0:
		set(v): value = v; queue_redraw()
	func _init() -> void:
		custom_minimum_size = Vector2(0, 12)
	func _draw() -> void:
		var y := size.y * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.15), 3.0, true)
		var t := Time.get_ticks_msec() * 0.003
		var col := UiTheme.ACCENT
		col.a = 0.75 + 0.25 * sin(t)
		draw_line(Vector2(0, y), Vector2(size.x * clampf(value, 0.0, 1.0), y), col, 3.0, true)
	func _process(_d: float) -> void:
		queue_redraw()
