class_name NamingCard extends Control
## The naming box (DESIGN 3, ruling 3). On Events.name_requested(people, reason)
## the game pauses softly and a parchment card shows each person's portrait and
## a handwritten name field, prefilled with their generated name. The die rolls
## a new one; "Keep these names" applies them, emits Events.names_given(people)
## and restores the game speed.
## A name the hand chose (typed or rolled on the storm night; any name for a
## baby the parents asked the hand to name) gets the named_by_hand meta and a
## hand mark in the Book. Requests that arrive while the title menu is up wait
## until play starts. In --test runs names are accepted at once.

signal closed

const MAX_LEN := 14

var _queue: Array = []          # [{people, reason}]
var _people: Array = []
var _reason: StringName = &""
var _fields: Array = []         # LineEdit per person
var _initial: Array = []        # generated names
var _rolled: Array = []         # bool per person
var _prev_speed: int = 1
var _card: PanelContainer
var _shade: ColorRect
var _open := false

func _ready() -> void:
	name = "NamingCard"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.paper_theme()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.name_requested.connect(request)

func is_open() -> bool:
	return _open

func request(people: Array, reason: StringName) -> void:
	var list: Array = people.filter(func(p): return p != null and is_instance_valid(p))
	if list.is_empty():
		return
	if Game.testing():
		_auto_accept.call_deferred(list)
		return
	_queue.append({"people": list, "reason": reason})

func _auto_accept(list: Array) -> void:
	Events.names_given.emit(list)

func _can_show() -> bool:
	if not Clock.running:
		return false
	var hud := get_tree().get_first_node_in_group(&"hud")
	return hud == null or not ("visible" in hud) or hud.visible

func _process(_d: float) -> void:
	if not _open and not _queue.is_empty() and _can_show():
		var job: Dictionary = _queue.pop_front()
		_show(job["people"], job["reason"])

# ---------------------------------------------------------------- building

static func prompt(people: Array, reason: StringName) -> String:
	if reason == &"baby_prayer":
		var names: Array = []
		var p = people[0]
		for u in p.parents:
			for q in Village.people:
				if is_instance_valid(q) and int(q.uid) == int(u):
					names.append(q.given_name)
		if names.size() >= 2:
			# mother first
			var a = _find(int(p.parents[0]))
			if a != null and a.sex != "f":
				names.reverse()
			return "%s and %s kneel at the shrine and ask the hand to name their child." % [names[0], names[1]]
		if names.size() == 1:
			return "%s kneels at the shrine and asks the hand to name the child." % names[0]
		return "A family kneels at the shrine and asks the hand to name their child."
	if reason == &"first_two" or people.size() == 2:
		return "Two people shelter in the cave. What will you call them?"
	return "What will you call them?"

static func _find(uid: int):
	for q in Village.people:
		if is_instance_valid(q) and int(q.uid) == uid:
			return q
	return null

func _show(people: Array, reason: StringName) -> void:
	_people = people.filter(func(p): return is_instance_valid(p))
	if _people.is_empty():
		return
	_reason = reason
	_open = true
	_prev_speed = Clock.speed_index
	Clock.set_speed(0)
	for c in get_children():
		c.queue_free()
	_fields.clear(); _initial.clear(); _rolled.clear()
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
	_card.add_theme_stylebox_override(&"panel", UiTheme.paper_box(48.0, 1))
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	_card.add_child(v)
	var small := UiTheme.ink_label("The hand is asked" if reason == &"baby_prayer" else "The first night", 17, &"title_italic", UiTheme.INK_SOFT)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(small)
	var t := UiTheme.ink_label(prompt(_people, reason), 30, &"title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = maxf(560.0, 300.0 * _people.size())
	v.add_child(t)
	v.add_child(InkWidgets.Rule.new(320))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 56)
	v.add_child(row)
	for i in _people.size():
		row.add_child(_person_column(_people[i], i))
	var hint := UiTheme.ink_label("Write a name, roll the die for another, or keep the ones they have.", 17, &"italic", UiTheme.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	var keep := Button.new()
	keep.text = "Keep these names" if _people.size() > 1 else "Give this name"
	keep.custom_minimum_size = Vector2(250, 50)
	keep.add_theme_font_size_override(&"font_size", 21)
	keep.pressed.connect(accept)
	bh.add_child(keep)
	visible = true
	# a soft arrival that runs while the game is paused
	_card.pivot_offset = _card.size * 0.5
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_shade, "color:a", 0.42, 0.45)
	tw.tween_property(_card, "modulate:a", 1.0, 0.35)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	if is_instance_valid(_card):
		_card.pivot_offset = _card.size * 0.5
	if not _fields.is_empty() and is_instance_valid(_fields[0]):
		(_fields[0] as LineEdit).grab_focus()
		(_fields[0] as LineEdit).caret_column = (_fields[0] as LineEdit).text.length()

func _person_column(p, i: int) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 6)
	var rec := BookData.record_of(p)
	rec["hand_named"] = false
	var pc := CenterContainer.new()
	var pf := PortraitFrame.make(rec, 150.0)
	pf.ring_width = 3.0
	pc.add_child(pf)
	col.add_child(pc)
	var who := "a woman" if p.sex == "f" else "a man"
	if int(p.stage) <= 1:
		who = "a baby girl" if p.sex == "f" else "a baby boy"
	var wl := UiTheme.ink_label(who, 17, &"italic", UiTheme.INK_SOFT)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(wl)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	col.add_child(h)
	var le := LineEdit.new()
	le.text = str(p.given_name)
	le.max_length = MAX_LEN
	le.custom_minimum_size = Vector2(200, 56)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.placeholder_text = "a name"
	le.select_all_on_focus = true
	le.text_submitted.connect(func(_t): _next_or_accept(i))
	le.text_changed.connect(func(_t): _rolled[i] = false)
	h.add_child(le)
	var dice := InkWidgets.Dice.new()
	dice.pressed.connect(_reroll.bind(i))
	h.add_child(dice)
	_fields.append(le)
	_initial.append(str(p.given_name))
	_rolled.append(false)
	return col

func _taken(except: int) -> Array:
	var t: Array = Names.taken_names()
	for j in _fields.size():
		if j != except:
			t.append((_fields[j] as LineEdit).text.strip_edges())
	return t

func _reroll(i: int) -> void:
	var p = _people[i]
	var taken := _taken(i)
	taken.append((_fields[i] as LineEdit).text)
	var n := Names.pick(str(p.sex), Village.era, Game.rng, taken)
	(_fields[i] as LineEdit).text = n
	_rolled[i] = true
	Audio.sfx("res://assets/audio/sfx/ui_click.ogg", Vector3.INF, randf_range(0.9, 1.15), -6.0)

func _next_or_accept(i: int) -> void:
	if i + 1 < _fields.size():
		(_fields[i + 1] as LineEdit).grab_focus()
	else:
		accept()

## Cleans a typed name: trimmed, capitalised, at most MAX_LEN letters.
static func clean_name(s: String, fallback: String) -> String:
	var t := s.strip_edges().replace("\n", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	if t == "":
		return fallback
	t = t.substr(0, MAX_LEN)
	return t[0].to_upper() + t.substr(1)

## Applies the names and closes. Also callable from tests.
func accept() -> void:
	if not _open:
		return
	for i in _people.size():
		var p = _people[i]
		if not is_instance_valid(p):
			continue
		var n := clean_name((_fields[i] as LineEdit).text, _initial[i])
		var by_hand: bool = _reason == &"baby_prayer" or n != _initial[i]
		p.given_name = n
		if by_hand:
			p.set_meta(&"named_by_hand", true)
			BookData.mark_hand_named(int(p.uid))
	var people := _people.duplicate()
	_close()
	Events.names_given.emit(people)

func set_name_field(i: int, text: String) -> void:
	if i >= 0 and i < _fields.size():
		(_fields[i] as LineEdit).text = text

func field_text(i: int) -> String:
	return (_fields[i] as LineEdit).text if i >= 0 and i < _fields.size() else ""

func _close() -> void:
	_open = false
	Clock.set_speed(_prev_speed)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	if is_instance_valid(_card):
		tw.tween_property(_card, "modulate:a", 0.0, 0.25)
	if is_instance_valid(_shade):
		tw.tween_property(_shade, "color:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		if not _open:
			visible = false
			for c in get_children():
				c.queue_free())
	_people.clear()
	closed.emit()

## Shows the next queued request immediately (tests and the shot director).
func show_now() -> void:
	if not _open and not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		_show(job["people"], job["reason"])

func _unhandled_input(e: InputEvent) -> void:
	if _open and e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		accept()
		get_viewport().set_input_as_handled()
