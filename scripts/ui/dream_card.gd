class_name DreamCard extends Control
## A new Village Dream is announced on a parchment card that waits for a
## click (playtest era 1, note 14: "I looked away while they announced their
## first dream"). The game pauses softly underneath; the card shows the dream
## in the people's words, the line they said at the fire, the full checklist
## and what it will bring, and "We will help them" closes it. The Book keeps
## the dream (Chronicle) and the goal panel keeps the checklist on screen.
## Dreams that start while the title, a naming card or the era card is up wait
## their turn. In --test runs the card is never shown (the bot plays on).

signal closed(id: StringName)

var dream_id: StringName = &""
var _queue: Array = []          # dream ids waiting to be shown
var _open := false
var _prev_speed: int = 1
var _card: PanelContainer
var _shade: ColorRect

func _ready() -> void:
	name = "DreamCard"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.paper_theme()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.dream_started.connect(request)

func is_open() -> bool:
	return _open

func pending() -> bool:
	return _open or not _queue.is_empty()

func request(id: StringName) -> void:
	if Defs.dream(id) == null or Game.testing():
		return
	if dream_id == id and _open or _queue.has(id):
		return
	_queue.append(id)

func _can_show() -> bool:
	if not Clock.running:
		return false
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud == null:
		return true
	if "visible" in hud and not hud.visible:
		return false
	if hud.get(&"naming") != null and hud.naming.is_open():
		return false
	if hud.get(&"era_card") != null and hud.era_card.is_open():
		return false
	return true

func _process(_d: float) -> void:
	if not _open and not _queue.is_empty() and _can_show():
		show_dream(_queue.pop_front())

## Everything the card says (tests read it).
static func content(d: DreamDef) -> Dictionary:
	var rewards: Array = []
	if d.reward_faith > 0.0:
		rewards.append("+%d faith" % int(d.reward_faith))
	for pw in d.unlocks_powers:
		var pd: PowerDef = Defs.power(pw)
		if pd != null:
			rewards.append(pd.title)
	if d.gate:
		var nx := Defs.era(d.era + 1)
		if nx != null:
			rewards.append("the %s age" % nx.title.to_lower())
	return {
		"kicker": "THE GREAT DREAM OF THIS AGE" if d.gate else "THE PEOPLE HAVE A DREAM",
		"text": d.text,
		"voice": d.voice,
		"items": Dreams.checklist(d),
		"rewards": rewards,
	}

func show_dream(id: StringName) -> void:
	var d: DreamDef = Defs.dream(id)
	if d == null:
		return
	dream_id = id
	_open = true
	_prev_speed = Clock.speed_index
	Clock.set_speed(0)
	var c := DreamCard.content(d)
	for ch in get_children():
		ch.queue_free()
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.05, 0.03, 0.02, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override(&"panel", UiTheme.paper_box(50.0, 1))
	_card.custom_minimum_size = Vector2(640, 0)
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	_card.add_child(v)
	var mark := DreamMark.new()
	var mc := CenterContainer.new()
	mc.add_child(mark)
	v.add_child(mc)
	var k := UiTheme.ink_label(c["kicker"], 15, &"semibold", UiTheme.INK_RED)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var t := UiTheme.wrap(UiTheme.ink_label("“%s”" % c["text"], 30, &"title_italic"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.x = 560
	v.add_child(t)
	if str(c["voice"]) != "":
		var vl := UiTheme.wrap(UiTheme.ink_label(str(c["voice"]), 21, &"hand", UiTheme.INK_SOFT))
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(vl)
	v.add_child(InkWidgets.Rule.new(360))
	var need := UiTheme.ink_label("What it needs", 20, &"title", UiTheme.INK_RED)
	need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(need)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 2)
	var lc := CenterContainer.new()
	lc.add_child(list)
	v.add_child(lc)
	for it in c["items"]:
		list.add_child(DreamCard.ink_row(it))
	if not (c["rewards"] as Array).is_empty():
		var r := UiTheme.ink_label("When it comes true:  " + "  ·  ".join(c["rewards"]), 17, &"semibold", UiTheme.OCHRE.darkened(0.2))
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(r)
	var note := UiTheme.ink_label("The dream stays in the top-left corner, and in the Village Book.", 15, &"italic", UiTheme.INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	var ok := Button.new()
	ok.text = "We will help them"
	ok.custom_minimum_size = Vector2(260, 50)
	ok.add_theme_font_size_override(&"font_size", 21)
	var sb := InkBox.make(Color(UiTheme.OCHRE, 0.24), UiTheme.INK, 14.0, 8.0, 2.0)
	sb.double_line = true
	ok.add_theme_stylebox_override(&"normal", sb)
	ok.pressed.connect(accept)
	bh.add_child(ok)
	visible = true
	Audio.sfx("res://assets/audio/sfx/ui_click.ogg", Vector3.INF, 0.6, -8.0)
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_shade, "color:a", 0.4, 0.45)
	tw.tween_property(_card, "modulate:a", 1.0, 0.4)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	if is_instance_valid(_card):
		_card.pivot_offset = _card.size * 0.5

## A checklist line in ink: a drawn box (ticked when done), the need, x/y.
static func ink_row(it: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	var box := InkTick.new()
	box.done = it["done"]
	h.add_child(box)
	var l := UiTheme.ink_label(str(it["text"]), 18, &"body", UiTheme.INK_FADED if it["done"] else UiTheme.INK)
	l.custom_minimum_size.x = 320
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var n := UiTheme.ink_label("%d/%d" % [int(it["have"]), int(it["need"])] if int(it["need"]) > 1 or str(it["key"]).begins_with("b:") else ("done" if it["done"] else ""), 17, &"semibold", UiTheme.LEAF if it["done"] else UiTheme.OCHRE.darkened(0.15))
	n.custom_minimum_size.x = 48
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	if str(it.get("hint", "")) != "":
		h.tooltip_text = str(it["hint"])
		h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h

func accept() -> void:
	if not _open:
		return
	_open = false
	Clock.set_speed(_prev_speed if _prev_speed > 0 else 1)
	var id := dream_id
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	if is_instance_valid(_card):
		tw.tween_property(_card, "modulate:a", 0.0, 0.25)
	if is_instance_valid(_shade):
		tw.tween_property(_shade, "color:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		if not _open:
			visible = false)
	closed.emit(id)

func _unhandled_input(e: InputEvent) -> void:
	if not _open:
		return
	if e is InputEventKey and e.pressed and ((e as InputEventKey).keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]):
		accept()
		get_viewport().set_input_as_handled()

## A drawn box with an ink tick.
class InkTick extends Control:
	var done := false
	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var b := InkBox.make(Color(UiTheme.PAPER_DARK, 0.4), UiTheme.INK_SOFT, 0.0, 3.0, 1.5)
		b.draw(get_canvas_item(), r)
		if done:
			draw_polyline(PackedVector2Array([r.position + Vector2(2, r.size.y * 0.5), r.position + Vector2(r.size.x * 0.42, r.size.y - 2), r.end + Vector2(3, -r.size.y - 2)]), UiTheme.LEAF.darkened(0.1), 2.6, true)

## A small drawn crest for the card: a crescent moon over a sleeping fire.
class DreamMark extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(90, 62)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 30)
		var ink := Color(UiTheme.OCHRE, 0.9)
		draw_circle(c, 22.0, Color(UiTheme.OCHRE, 0.12))
		draw_arc(c, 22.0, 0, TAU, 40, Color(UiTheme.OCHRE, 0.65), 1.6, true)
		# a crescent: a disc with a disc taken out of it
		var moon := PackedVector2Array()
		for i in 25:
			var a := -PI * 0.5 + PI * float(i) / 24.0
			moon.append(c + Vector2(cos(a), sin(a)) * 13.0)
		for i in 25:
			var a := PI * 0.5 - PI * float(i) / 24.0
			moon.append(c + Vector2(-5.0, 0) + Vector2(cos(a) * 9.0, sin(a) * 13.0))
		draw_colored_polygon(moon, ink)
		for i in 3:
			var x := c.x - 26.0 + i * 26.0
			draw_circle(Vector2(x, 58), 2.2, Color(UiTheme.INK_SOFT, 0.6))
