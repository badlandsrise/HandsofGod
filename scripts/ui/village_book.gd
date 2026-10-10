class_name VillageBook extends Control
## F1: the Village Book (DESIGN 11.2), a leather-bound book of two parchment
## pages with bookmark tabs:
##   People       portraits, age, trust, skills, wish, traits, family links; click to look
##   Family Tree  zoomable and pannable, from the first two down; the dead greyed
##   Dreams       this age's dreams, current and completed, with the day achieved
##   Memories     firsts, gifts received, memorials (the people's own words)
##   Powers       what the hand can do, and what it may yet do (and what each opens)
## Text is written in the people's voice. Data comes from BookData and the
## journal the Chronicle keeps.

signal person_clicked(p: Person)

const TABS := ["People", "Family Tree", "Dreams", "Memories", "Powers"]
const BOOK_SIZE := Vector2(1300, 790)
const PAGE_PAD := Vector2(54, 46)

var tab: int = 0
var selected_uid: int = 0
var _hud: Node = null
var _shade: ColorRect
var _book: Control
var _cover: BookCover
var _tab_buttons: Array = []
var _left: VBoxContainer
var _right: VBoxContainer
var _spread: Control
var _tree: FamilyTreeView
var _records: Array = []
var _by: Dictionary = {}
var _left_scroll: ScrollContainer = null

func _init(hud: Node = null) -> void:
	_hud = hud

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.paper_theme()
	_shade = ColorRect.new()
	_shade.color = Color(0.04, 0.025, 0.015, 0.5)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_book = Control.new()
	_book.name = "Book"
	_book.size = BOOK_SIZE
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book)
	# tabs sit behind the cover so the cover's edge overlaps them
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	tabs.position = Vector2(110, -48)
	_book.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 58)
		b.add_theme_font_override(&"font", UiTheme.font(&"title"))
		b.add_theme_font_size_override(&"font_size", 21)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(show_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_cover = BookCover.new()
	_cover.size = BOOK_SIZE
	_book.add_child(_cover)
	var pw := BOOK_SIZE.x * 0.5
	_left = _page_box(Rect2(Vector2(26, 22), Vector2(pw - 26, BOOK_SIZE.y - 44)))
	_right = _page_box(Rect2(Vector2(pw, 22), Vector2(pw - 26, BOOK_SIZE.y - 44)))
	_spread = Control.new()
	_spread.position = Vector2(44, 34)
	_spread.size = BOOK_SIZE - Vector2(88, 68)
	_spread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_spread)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Close the book (F1)"
	close.custom_minimum_size = Vector2(110, 54)
	close.add_theme_font_override(&"font", UiTheme.font(&"title"))
	close.add_theme_font_size_override(&"font_size", 20)
	close.pressed.connect(close_book)
	_style_tab(close, false)
	var close_row := HBoxContainer.new()
	close_row.position = Vector2(BOOK_SIZE.x - 150, -48)
	close_row.size = Vector2(120, 64)
	close_row.alignment = BoxContainer.ALIGNMENT_END
	_book.add_child(close_row)
	_book.move_child(close_row, _cover.get_index())
	close_row.add_child(close)
	get_viewport().size_changed.connect(_center)
	_center()

func _page_box(r: Rect2) -> VBoxContainer:
	var m := MarginContainer.new()
	m.position = r.position
	m.size = r.size
	m.add_theme_constant_override(&"margin_left", int(PAGE_PAD.x))
	m.add_theme_constant_override(&"margin_right", int(PAGE_PAD.x))
	m.add_theme_constant_override(&"margin_top", int(PAGE_PAD.y))
	m.add_theme_constant_override(&"margin_bottom", int(PAGE_PAD.y) + 8)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	return v

func _center() -> void:
	if _book == null:
		return
	var area := get_parent_area_size() if is_inside_tree() else BOOK_SIZE
	if area.x < 10.0:
		area = get_viewport_rect().size
	_book.position = ((area - BOOK_SIZE) * 0.5 + Vector2(0, 22)).floor()

# ---------------------------------------------------------------- open / close

func is_open() -> bool:
	return visible

func toggle() -> void:
	if visible: close_book()
	else: open_book()

func open_book(which: int = -1) -> void:
	if which >= 0:
		tab = which
	visible = true
	_center()
	refresh()
	_book.modulate.a = 0.0
	_book.position.y += 14
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_book, "modulate:a", 1.0, 0.18)
	tw.tween_property(_book, "position:y", _book.position.y - 14, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Audio.sfx("res://assets/audio/sfx/ui_click.ogg", Vector3.INF, 0.7, -8.0)

func close_book() -> void:
	visible = false

func show_tab(i: int) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	refresh()

func select_person(uid: int) -> void:
	selected_uid = uid
	tab = 0
	refresh()

func refresh() -> void:
	_records = BookData.all_records()
	_by = BookData.by_uid(_records)
	for i in _tab_buttons.size():
		_style_tab(_tab_buttons[i], i == tab)
	_clear(_left); _clear(_right)
	for c in _spread.get_children():
		_spread.remove_child(c); c.queue_free()
	_tree = null
	_left.get_parent().visible = tab != 1
	_right.get_parent().visible = tab != 1
	_spread.visible = tab == 1
	_cover.page_numbers = Vector2i(tab * 2 + 1, tab * 2 + 2)
	_cover.ribbon = tab != 1
	_cover.queue_redraw()
	match tab:
		0: _fill_people()
		1: _fill_tree()
		2: _fill_dreams()
		3: _fill_memories()
		4: _fill_powers()

func _style_tab(b: Button, on: bool) -> void:
	var fill := UiTheme.PAPER if on else UiTheme.PAPER_DARK.darkened(0.08)
	var n := InkBox.make(fill, Color(UiTheme.INK_SOFT, 0.9 if on else 0.6), 14.0, 9.0, 1.6)
	n.content_margin_bottom = 14 if on else 6
	n.content_margin_top = 6
	n.shadow = Color(0.1, 0.05, 0.02, 0.25)
	var h := n.duplicate() as InkBox
	h.fill = UiTheme.PAPER.lightened(0.05) if on else UiTheme.PAPER_DARK.lightened(0.05)
	for k in [&"normal", &"pressed", &"focus", &"hover_pressed"]:
		b.add_theme_stylebox_override(k, n)
	b.add_theme_stylebox_override(&"hover", h)
	b.custom_minimum_size.y = 64.0 if on else 54.0
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.add_theme_color_override(&"font_color", UiTheme.INK if on else UiTheme.INK_SOFT)
	b.add_theme_color_override(&"font_hover_color", UiTheme.INK)

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

# ---------------------------------------------------------------- page helpers

func _header(box: VBoxContainer, title: String, sub: String = "") -> void:
	var t := UiTheme.ink_label(title, 36, &"title")
	box.add_child(t)
	if sub != "":
		var s := UiTheme.wrap(UiTheme.ink_label(sub, 18, &"italic", UiTheme.INK_SOFT))
		box.add_child(s)
	box.add_child(InkWidgets.Rule.new())

func _para(text: String, fs: int = 18, kind: StringName = &"body", col: Color = UiTheme.INK) -> Label:
	return UiTheme.wrap(UiTheme.ink_label(text, fs, kind, col))

func _section(box: Control, title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box.add_child(gap)
	box.add_child(UiTheme.ink_label(title, 22, &"title", UiTheme.INK_RED))

func _scroll(box: VBoxContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 8)
	sc.add_child(v)
	return v

func _node_of(uid: int) -> Person:
	for p in Village.people:
		if is_instance_valid(p) and p is Person and int(p.uid) == uid:
			return p
	return null

# ---------------------------------------------------------------- People

func _fill_people() -> void:
	var living: Array = _records.filter(func(r): return r["alive"])
	var dead: Array = _records.filter(func(r): return not r["alive"])
	var sub := "Nobody lives here yet."
	if not living.is_empty():
		sub = "%s of us live in the valley." % BookData.cap(BookData.cardinal(living.size()))
		if living.size() == 1:
			sub = "One of us lives in the valley."
		if not dead.is_empty():
			sub += " %s rest%s under the stones." % [BookData.cap(BookData.cardinal(dead.size())), "s" if dead.size() == 1 else ""]
	_header(_left, "Our People", sub)
	var list := _scroll(_left)
	list.add_theme_constant_override(&"separation", 2)
	if selected_uid == 0 or not _by.has(selected_uid):
		selected_uid = int(living[0]["uid"]) if not living.is_empty() else (int(dead[0]["uid"]) if not dead.is_empty() else 0)
	for r in living:
		list.add_child(_person_row(r))
	if not dead.is_empty():
		var l := UiTheme.ink_label("Remembered", 20, &"title_italic", UiTheme.INK_SOFT)
		list.add_child(l)
		for r in dead:
			list.add_child(_person_row(r))
	if _by.has(selected_uid):
		_person_page(_by[selected_uid])
	else:
		_header(_right, "", "")
		_right.add_child(_para("When people come to the valley, their names will be written here.", 19, &"italic", UiTheme.INK_SOFT))

func _person_row(r: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 62)
	var sel := int(r["uid"]) == selected_uid
	var clear := StyleBoxEmpty.new()
	var hov := InkBox.make(Color(UiTheme.PAPER_DARK, 0.55), Color(0, 0, 0, 0), 4.0, 8.0, 0.0)
	var on := InkBox.make(Color(UiTheme.OCHRE, 0.18), Color(UiTheme.OCHRE, 0.7), 4.0, 8.0, 1.4)
	b.add_theme_stylebox_override(&"normal", on if sel else clear)
	b.add_theme_stylebox_override(&"hover", on if sel else hov)
	b.add_theme_stylebox_override(&"pressed", on)
	b.add_theme_stylebox_override(&"hover_pressed", on)
	b.tooltip_text = "Read about %s (double-click to look at them)" % r["name"] if r["alive"] else "Read about %s" % r["name"]
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.add_theme_constant_override(&"separation", 12)
	b.add_child(row)
	var pf := PortraitFrame.make(r, 52.0)
	var pc := CenterContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(pf)
	row.add_child(pc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var dead: bool = not r["alive"]
	var nl := UiTheme.ink_label(str(r["name"]), 26, &"hand_bold", UiTheme.INK if not dead else UiTheme.INK_FADED)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	var al := UiTheme.ink_label(BookData.age_line(r) if not dead else "lived %d years" % int(r["years"]), 15, &"italic", UiTheme.INK_SOFT)
	al.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(al)
	if not dead:
		var tr := InkWidgets.TrustRow.new(int(r["trust"]), 15.0)
		var tc := CenterContainer.new()
		tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tc.add_child(tr)
		row.add_child(tc)
	var uid := int(r["uid"])
	b.pressed.connect(func():
		if selected_uid == uid:
			_look_at(uid)
		else:
			selected_uid = uid
			var keep := _scroll_of(b)
			refresh()
			_restore_scroll(keep))
	return b

func _scroll_of(n: Node) -> int:
	var p := n.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	return (p as ScrollContainer).scroll_vertical if p is ScrollContainer else 0

func _restore_scroll(v: int) -> void:
	await get_tree().process_frame
	for c in _left.get_children():
		if c is ScrollContainer:
			(c as ScrollContainer).scroll_vertical = v

func _look_at(uid: int) -> void:
	var p := _node_of(uid)
	if p != null and p.alive():
		person_clicked.emit(p)

func _person_page(r: Dictionary) -> void:
	var dead: bool = not r["alive"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 18)
	_right.add_child(top)
	var pf := PortraitFrame.make(r, 150.0)
	pf.ring_width = 3.0
	top.add_child(pf)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", 2)
	top.add_child(v)
	var nh := HBoxContainer.new()
	v.add_child(nh)
	nh.add_child(UiTheme.ink_label(str(r["name"]), 50, &"hand_bold"))
	if r["hand_named"]:
		var mark := HandMarkLabel.new()
		mark.tooltip_text = "The hand gave this name."
		nh.add_child(mark)
	v.add_child(UiTheme.ink_label(BookData.age_line(r) if not dead else "Lived %d years" % int(r["years"]), 18, &"italic", UiTheme.INK_SOFT))
	v.add_child(_para(BookData.origin_line(r, _by), 17))
	if not dead:
		var th := HBoxContainer.new()
		th.add_theme_constant_override(&"separation", 8)
		th.add_child(InkWidgets.TrustRow.new(int(r["trust"]), 20.0))
		th.add_child(UiTheme.ink_label(BookData.TRUST_NAMES[clampi(int(r["trust"]), 0, 5)], 17, &"italic", UiTheme.OCHRE.darkened(0.25)))
		v.add_child(th)
		if _node_of(int(r["uid"])) != null:
			var uid := int(r["uid"])
			var look := InkWidgets.link("Find %s in the valley" % BookData.pronoun(r["sex"], "herobj"), func(): _look_at(uid), 17)
			look.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(look)
	_right.add_child(InkWidgets.Rule.new())
	var body := _scroll(_right)
	if dead:
		var when := " since the %s day" % BookData.ordinal(int(r["died_day"])) if int(r["died_day"]) > 0 else ""
		var why := " (%s)" % r["cause"] if str(r["cause"]) != "" else ""
		body.add_child(_para("%s rests under the stones by the shrine%s%s. We say %s name at the fire." % [str(r["name"]), when, why, BookData.pronoun(r["sex"], "her")], 19, &"italic"))
	else:
		var st := str(r["status"])
		if st != "":
			body.add_child(_para("Now: %s." % st.trim_suffix("."), 19))
		body.add_child(_para(BookData.wish_line(r), 19, &"italic"))
	# skills
	_section(body, "Skills")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 2)
	body.add_child(grid)
	var sk: Dictionary = r.get("skills", {})
	for k in Person.SKILLS:
		var n := float(sk.get(str(k), 1.0))
		var l := UiTheme.ink_label(BookData.SKILL_TITLES.get(str(k), str(k).capitalize()), 16)
		l.custom_minimum_size.x = 104
		grid.add_child(l)
		var sc := CenterContainer.new()
		sc.add_child(InkWidgets.stars(int(floor(n)), 5, 6.5))
		grid.add_child(sc)
	# traits
	var traits: Array = r.get("traits", [])
	if not traits.is_empty():
		_section(body, "Nature")
		for t in traits:
			body.add_child(_para(BookData.TRAIT_TEXT.get(str(t), str(t).capitalize()), 17))
	# family
	_section(body, "Family")
	var any := false
	any = _link_row(body, "Parents", r["parents"]) or any
	if int(r["partner"]) != 0:
		any = _link_row(body, "Partner", [r["partner"]]) or any
	any = _link_row(body, "Children", r["children"]) or any
	if not any:
		body.add_child(_para("No family in the valley yet." if not r.get("first_two", false) else "The first two have only each other, and the hand.", 17, &"italic", UiTheme.INK_SOFT))
	var line := BookData.line_to(_records, int(r["uid"]))
	if line.size() > 2:
		body.add_child(_para("Of the line of %s." % BookData.join_names(line.slice(0, line.size() - 1).map(func(u): return _by[u]["name"] if _by.has(u) else "?")), 16, &"italic", UiTheme.INK_SOFT))

func _link_row(box: Control, title: String, uids: Array) -> bool:
	var list: Array = []
	for u in uids:
		if _by.has(int(u)):
			list.append(int(u))
	if list.is_empty():
		return false
	var h := HFlowContainer.new()
	h.add_theme_constant_override(&"h_separation", 4)
	box.add_child(h)
	var l := UiTheme.ink_label(title + ":", 17, &"italic", UiTheme.INK_SOFT)
	l.custom_minimum_size.x = 86
	h.add_child(l)
	for u in list:
		var r: Dictionary = _by[u]
		h.add_child(InkWidgets.link(str(r["name"]) + ("" if r["alive"] else " (rests)"), select_person.bind(u), 19))
	return true

# ---------------------------------------------------------------- Family Tree

func _fill_tree() -> void:
	var head := HBoxContainer.new()
	head.position = Vector2(10, 6)
	head.size = Vector2(_spread.size.x - 20, 50)
	head.add_theme_constant_override(&"separation", 10)
	_spread.add_child(head)
	var tl := UiTheme.ink_label("The Family Tree", 36, &"title")
	head.add_child(tl)
	var sub := UiTheme.ink_label("from the first two down. Scroll to zoom, drag to move, click a name to read about them.", 17, &"italic", UiTheme.INK_SOFT)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(sub)
	_tree = FamilyTreeView.new()
	_tree.position = Vector2(0, 62)
	_tree.size = _spread.size - Vector2(0, 62)
	_spread.add_child(_tree)
	_tree.selected = selected_uid
	_tree.set_records(_records)
	_tree.person_picked.connect(func(u: int): select_person(u))
	for pair in [["+", func(): _tree.zoom_by(1.2, _tree.size * 0.5)], ["-", func(): _tree.zoom_by(1.0 / 1.2, _tree.size * 0.5)], ["Fit", func(): _tree.fit()]]:
		var b := Button.new()
		b.text = pair[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(48, 38)
		b.pressed.connect(pair[1])
		head.add_child(b)

# ---------------------------------------------------------------- Dreams

func _dream_text(id) -> String:
	var d: DreamDef = Defs.dream(StringName(str(id)))
	return d.text if d != null and d.text != "" else String(str(id)).capitalize()

func _fill_dreams() -> void:
	var era := Village.era
	var ed: EraDef = Defs.era(era)
	var j: Dictionary = BookData.journal()["dreams"]
	_header(_left, "Our Dreams", "The dreams of %s. When the last comes true, a new age begins." % BookData.ERA_AGES.get(era, "this age"))
	var body := _scroll(_left)
	var active: DreamDef = Dreams.active_dream()
	var ids: Array = ed.dreams if ed != null else []
	var shown_future := false
	for id in ids:
		var done: bool = Dreams.is_done(id)
		var is_active: bool = active != null and active.id == id
		var info: Dictionary = j.get(str(id), {})
		if not done and not is_active:
			if not shown_future:
				shown_future = true
				body.add_child(_dream_card("?", "A dream we have not dreamed yet.", "", &"future"))
			continue
		if is_active and not Dreams.revealed(active):
			if not shown_future:
				shown_future = true
				body.add_child(_dream_card("?", "The people are restless. A dream is stirring.", Dreams.teaser_hint(active), &"future"))
			continue
		var when := ""
		if done:
			when = "Came true on the %s day." % BookData.ordinal(int(info.get("done", Clock.day)))
			if info.has("start"):
				when = "Dreamed on the %s day. " % BookData.ordinal(int(info["start"])) + when
		else:
			when = "We are working on it."
			if info.has("start"):
				when = "Dreamed on the %s day. " % BookData.ordinal(int(info["start"])) + when
		var card := _dream_card("", "\"%s\"" % _dream_text(id), when, &"done" if done else &"active", Defs.dream(id).gate if Defs.dream(id) != null else false)
		if is_active:
			var cv: VBoxContainer = card.get_child(0).get_child(1)
			if active.voice != "":
				cv.add_child(_para(active.voice, 18, &"hand", UiTheme.INK_SOFT))
			for it in Dreams.checklist(active):
				cv.add_child(DreamCard.ink_row(it))
		body.add_child(card)
	if ids.is_empty():
		body.add_child(_para("No dreams yet. They will come.", 18, &"italic", UiTheme.INK_SOFT))
	# right page: every dream that came true, and the turn of the age
	_header(_right, "Dreams Come True", "")
	var rb := _scroll(_right)
	var done_all: Array = Dreams.done_list()
	if done_all.is_empty():
		rb.add_child(_para("None yet. The people are still dreaming.", 18, &"italic", UiTheme.INK_SOFT))
	var last_era := 0
	for id in done_all:
		var d: DreamDef = Defs.dream(StringName(str(id)))
		var de := d.era if d != null else 1
		if de != last_era:
			last_era = de
			rb.add_child(UiTheme.ink_label(BookData.cap(BookData.ERA_AGES.get(de, "An age")), 20, &"title_italic", UiTheme.INK_RED))
		var info: Dictionary = j.get(str(id), {})
		var day := int(info.get("done", 0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 10)
		var tick := TickMark.new()
		h.add_child(tick)
		h.add_child(_para("%s%s" % [_dream_text(id), "  (the %s day)" % BookData.ordinal(day) if day > 0 else ""], 18))
		rb.add_child(h)
	var gate_done := int(Village.stats.get("era_gate_done", 0)) >= era
	if gate_done and Defs.era(era + 1) != null:
		var gap := Control.new()
		gap.custom_minimum_size.y = 10
		rb.add_child(gap)
		rb.add_child(_para("Every dream of this age has come true.", 19, &"italic"))
		var b := Button.new()
		b.text = "Begin Era %d: %s" % [era + 1, Defs.era(era + 1).title]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			close_book()
			EraCard.advance_era(era))
		rb.add_child(b)

func _dream_card(mark: String, text: String, when: String, state: StringName, gate: bool = false) -> Control:
	var p := PanelContainer.new()
	var fill := Color(UiTheme.PAPER_DARK, 0.35)
	var ink := Color(UiTheme.INK_SOFT, 0.55)
	if state == &"active":
		fill = Color(UiTheme.OCHRE, 0.13)
		ink = Color(UiTheme.OCHRE, 0.9)
	elif state == &"future":
		fill = Color(UiTheme.PAPER_DARK, 0.15)
		ink = Color(UiTheme.INK_SOFT, 0.3)
	var box := InkBox.make(fill, ink, 16.0, 10.0, 1.6)
	if state == &"active":
		box.double_line = true
	p.add_theme_stylebox_override(&"panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	p.add_child(h)
	var icon := DreamIcon.new()
	icon.state = state
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var label := ("The great dream of this age" if gate else ("Our dream now" if state == &"active" else ("Came true" if state == &"done" else "To come")))
	v.add_child(UiTheme.ink_label(label.to_upper(), 13, &"semibold", UiTheme.INK_RED if state == &"active" else UiTheme.INK_SOFT))
	v.add_child(_para(text, 21 if state != &"future" else 18, &"italic" if state != &"future" else &"italic", UiTheme.INK if state != &"future" else UiTheme.INK_FADED))
	if when != "":
		v.add_child(_para(when, 16, &"body", UiTheme.INK_SOFT))
	return p

# ---------------------------------------------------------------- Memories

func _fill_memories() -> void:
	var j := BookData.journal()
	_header(_left, "What We Remember", "Told at the fire, so we do not forget.")
	var body := _scroll(_left)
	# firsts
	var firsts := [["fire", "Our first fire"], ["hut", "Our first hut"], ["birth", "Our first child"], ["winter", "Our first winter, lived through"]]
	var fg := GridContainer.new()
	fg.columns = 2
	fg.add_theme_constant_override(&"h_separation", 16)
	body.add_child(fg)
	for f in firsts:
		var has := (j["firsts"] as Dictionary).has(f[0])
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 6)
		var t := TickMark.new()
		t.on = has
		h.add_child(t)
		var day := int(j["firsts"].get(f[0], 0))
		h.add_child(UiTheme.ink_label("%s%s" % [f[1], ", day %d" % day if has else ": not yet"], 16, &"body" if has else &"italic", UiTheme.INK if has else UiTheme.INK_FADED))
		fg.add_child(h)
	body.add_child(InkWidgets.Rule.new())
	var entries: Array = j["entries"]
	if entries.is_empty():
		body.add_child(_para("Nothing has happened yet that we would tell our children.", 18, &"italic", UiTheme.INK_SOFT))
	for e in entries:
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 10)
		var icon := EntryIcon.new()
		icon.kind = str(e.get("kind", ""))
		h.add_child(icon)
		h.add_child(_para(str(e.get("text", "")), 18, &"italic" if str(e.get("kind", "")) == "first" else &"body"))
		body.add_child(h)
	_scroll_to_end(body)
	# right page: gifts and memorials
	var gifts: Array = j["gifts"]
	_header(_right, "Gifts on the Shelf", "Kept here, a little museum of us and the hand." if not gifts.is_empty() else "")
	var rb := _scroll(_right)
	if gifts.is_empty():
		rb.add_child(_para("No gifts yet. They will come when the people are glad of the hand.", 18, &"italic", UiTheme.INK_SOFT))
	else:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override(&"h_separation", 14)
		grid.add_theme_constant_override(&"v_separation", 10)
		rb.add_child(grid)
		for g in gifts:
			var v := VBoxContainer.new()
			v.custom_minimum_size.x = 150
			v.add_theme_constant_override(&"separation", 0)
			var ic := CenterContainer.new()
			ic.add_child(InkWidgets.GiftIcon.new(str(g.get("kind", "")), 54.0))
			v.add_child(ic)
			var kl := UiTheme.ink_label(str(g.get("kind", "gift")).capitalize(), 17, &"semibold")
			kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(kl)
			var fl := UiTheme.ink_label("from %s, day %d" % [str(g.get("from", "someone")) if str(g.get("from", "")) != "" else "someone", int(g.get("day", 1))], 14, &"italic", UiTheme.INK_SOFT)
			fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(fl)
			grid.add_child(v)
	_section(rb, "The Memorial Stones")
	var dead: Array = _records.filter(func(r): return not r["alive"])
	if dead.is_empty():
		rb.add_child(_para("No one has died. The stones are bare.", 18, &"italic", UiTheme.INK_SOFT))
	for r in dead:
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 10)
		h.add_child(PortraitFrame.make(r, 46.0))
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", -4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiTheme.ink_label(str(r["name"]), 24, &"hand_bold", UiTheme.INK_SOFT))
		var when := "died on the %s day" % BookData.ordinal(int(r["died_day"])) if int(r["died_day"]) > 0 else "remembered"
		v.add_child(UiTheme.ink_label("Lived %d years, %s%s" % [int(r["years"]), when, " (%s)" % r["cause"] if str(r["cause"]) != "" else ""], 15, &"italic", UiTheme.INK_SOFT))
		rb.add_child(h)

func _scroll_to_end(box: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(box) and box.get_parent() is ScrollContainer:
		var sc := box.get_parent() as ScrollContainer
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

# ---------------------------------------------------------------- Powers

func _fill_powers() -> void:
	var ps: Array = Defs.powers.values()
	ps.sort_custom(func(a, b): return a.era < b.era or (a.era == b.era and a.cost < b.cost))
	var owned: Array = ps.filter(func(d): return Faith.has(d.id))
	var now: Array = ps.filter(func(d): return not Faith.has(d.id) and d.era <= Village.era)
	var later: Array = ps.filter(func(d): return not Faith.has(d.id) and d.era > Village.era)
	_header(_left, "What the Hand Can Do", "Faith is never spent away: it is what the people give, and the hand grows with it.")
	var lb := _scroll(_left)
	if owned.is_empty():
		lb.add_child(_para("The hand can lift one of us at a time, and that is already a wonder.", 18, &"italic", UiTheme.INK_SOFT))
	for d in owned:
		lb.add_child(_power_card(d, &"owned"))
	_header(_right, "What It May Yet Do", "We have %d faith to give." % int(Faith.available()))
	var rb := _scroll(_right)
	var next_marked := false
	for d in now:
		var st := &"affordable" if Faith.can_buy(d.id) else &"locked"
		var card := _power_card(d, st, not next_marked and not d.free)
		if not d.free:
			next_marked = true
		rb.add_child(card)
	if now.is_empty():
		rb.add_child(_para("The hand has every power this age can give.", 18, &"italic", UiTheme.INK_SOFT))
	if not later.is_empty():
		_section(rb, "In a later age")
		var by_era := {}
		for d in later:
			if not by_era.has(d.era):
				by_era[d.era] = []
			by_era[d.era].append(d.title)
		for e in by_era:
			rb.add_child(_para("%s: %s" % [BookData.cap(BookData.ERA_AGES.get(e, "Later")), ", ".join(by_era[e])], 16, &"italic", UiTheme.INK_FADED))

func _power_card(d: PowerDef, state: StringName, is_next: bool = false) -> Control:
	var p := PanelContainer.new()
	var fill := Color(UiTheme.PAPER_DARK, 0.3)
	var ink := Color(UiTheme.INK_SOFT, 0.5)
	if state == &"owned":
		fill = Color(UiTheme.LEAF, 0.08); ink = Color(UiTheme.LEAF, 0.7)
	elif state == &"affordable":
		fill = Color(UiTheme.OCHRE, 0.14); ink = UiTheme.OCHRE
	var box := InkBox.make(fill, ink, 14.0, 9.0, 1.5)
	box.double_line = is_next
	p.add_theme_stylebox_override(&"panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := UiTheme.ink_label(d.title, 24, &"title")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var tag := ""
	match state:
		&"owned": tag = "the hand has this"
		&"affordable": tag = "ready: %d faith" % int(d.cost)
		_: tag = "a gift will bring it" if d.free else "%d faith" % int(d.cost)
	if is_next and state != &"owned":
		tag = "next  ·  " + tag
	h.add_child(UiTheme.ink_label(tag, 15, &"semibold", UiTheme.LEAF.darkened(0.2) if state == &"owned" else (UiTheme.OCHRE.darkened(0.2) if state == &"affordable" else UiTheme.INK_SOFT)))
	v.add_child(_para(d.what_it_does, 17))
	if d.what_it_opens != "":
		v.add_child(_para(("Opened: " if state == &"owned" else "Opens: ") + d.what_it_opens, 16, &"italic", UiTheme.INK_SOFT))
	if state != &"owned" and not d.free:
		var bar := FaithBar.new()
		bar.value = clampf(Faith.available() / maxf(d.cost, 1.0), 0.0, 1.0)
		v.add_child(bar)
	return p

# ---------------------------------------------------------------- small drawings

class BookCover extends Control:
	var page_numbers := Vector2i(1, 2)
	var ribbon := true
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# shadow
		var sh := InkBox.make(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0.0, 22.0, 0.0)
		sh.draw(get_canvas_item(), Rect2(r.position + Vector2(8, 14), r.size))
		# leather cover
		var leather := StyleBoxTexture.new()
		leather.texture = UiTheme.paper_texture(2)
		leather.set_texture_margin_all(40)
		draw_style_box(leather, r)
		var edge := InkBox.make(Color(0, 0, 0, 0), Color(0.12, 0.06, 0.02, 0.9), 0.0, 20.0, 3.0)
		edge.wobble = 0.4
		edge.draw(get_canvas_item(), r)
		var stitch := r.grow(-9.0)
		_dashed_rect(stitch, Color(0.85, 0.66, 0.38, 0.55))
		# page block edges (the thickness of the pages)
		var half := size.x * 0.5
		for i in 4:
			var k := float(i) * 2.0
			draw_rect(Rect2(Vector2(24 - k * 0.6, 20 + k), Vector2(half - 24, size.y - 40)), Color("#cdb488").darkened(0.05 * i), true)
			draw_rect(Rect2(Vector2(half, 20 + k), Vector2(half - 24 + k * 0.6, size.y - 40)), Color("#cdb488").darkened(0.05 * i), true)
		# the two pages
		var page := UiTheme.paper_box()
		draw_style_box(page, Rect2(Vector2(26, 18), Vector2(half - 22, size.y - 44)))
		draw_style_box(page, Rect2(Vector2(half - 4, 18), Vector2(half - 22, size.y - 44)))
		# spine shading
		var w := 70.0
		for side in [-1, 1]:
			var pts := PackedVector2Array([Vector2(half, 22), Vector2(half + side * w, 22), Vector2(half + side * w, size.y - 26), Vector2(half, size.y - 26)])
			var cols := PackedColorArray([Color(0.3, 0.18, 0.06, 0.32), Color(0.3, 0.18, 0.06, 0.0), Color(0.3, 0.18, 0.06, 0.0), Color(0.3, 0.18, 0.06, 0.32)])
			draw_polygon(pts, cols)
		draw_line(Vector2(half, 24), Vector2(half, size.y - 28), Color(0.25, 0.14, 0.05, 0.45), 1.5)
		# page numbers
		var f := UiTheme.font(&"title_italic")
		draw_string(f, Vector2(26, size.y - 46), "~ %d ~" % page_numbers.x, HORIZONTAL_ALIGNMENT_CENTER, half - 22, 16, Color(UiTheme.INK_SOFT, 0.6))
		draw_string(f, Vector2(half - 4, size.y - 46), "~ %d ~" % page_numbers.y, HORIZONTAL_ALIGNMENT_CENTER, half - 22, 16, Color(UiTheme.INK_SOFT, 0.6))
		# a bookmark ribbon
		if not ribbon:
			return
		var rx := size.x - 140.0
		draw_colored_polygon(PackedVector2Array([Vector2(rx, 10), Vector2(rx + 22, 10), Vector2(rx + 22, 96), Vector2(rx + 11, 84), Vector2(rx, 96)]), Color("#8e2f1c"))
	func _dashed_rect(rr: Rect2, c: Color) -> void:
		var pts := [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y), rr.position]
		for i in 4:
			draw_dashed_line(pts[i], pts[i + 1], c, 1.5, 7.0)

class HandMarkLabel extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(34, 40)
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		PortraitFrame.draw_hand_mark(self, Vector2(17, 26), 15.0, UiTheme.OCHRE)

class TickMark extends Control:
	var on := true
	func _init() -> void:
		custom_minimum_size = Vector2(22, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(11, 12)
		draw_arc(c, 8.5, 0, TAU, 24, Color(UiTheme.INK_SOFT, 0.7 if on else 0.3), 1.4, true)
		if on:
			draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(7, -7)]), UiTheme.LEAF, 2.6, true)

class DreamIcon extends Control:
	var state: StringName = &"active"
	func _init() -> void:
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var col := UiTheme.OCHRE if state == &"active" else (UiTheme.LEAF if state == &"done" else Color(UiTheme.INK_SOFT, 0.35))
		# a thought cloud drawn by the people
		var puffs := [[Vector2(-10, 3), 11.0], [Vector2(3, -6), 13.0], [Vector2(13, 4), 10.0], [Vector2(0, 8), 11.0]]
		for p in puffs:
			draw_circle(c + p[0], p[1] + 1.5, Color(col, 0.8))
		for p in puffs:
			draw_circle(c + p[0], p[1] - 0.2, UiTheme.PAPER.lerp(col, 0.12))
		draw_circle(c + Vector2(-16, 20), 3.0, Color(col, 0.75))
		draw_circle(c + Vector2(-21, 25), 1.8, Color(col, 0.75))
		if state == &"done":
			draw_polyline(PackedVector2Array([c + Vector2(-7, 1), c + Vector2(-1, 7), c + Vector2(10, -6)]), UiTheme.LEAF.darkened(0.2), 3.0, true)
		elif state == &"future":
			var f := UiTheme.font(&"title")
			draw_string(f, c + Vector2(-20, 9), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color(UiTheme.INK_SOFT, 0.6))
		else:
			PortraitFrame.draw_hand_mark(self, c + Vector2(1, 2), 10.0, UiTheme.OCHRE.darkened(0.15))

class EntryIcon extends Control:
	var kind := ""
	func _init() -> void:
		custom_minimum_size = Vector2(22, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(11, 13)
		match kind:
			"first":
				var pts := PackedVector2Array()
				for k in 10:
					var r := 8.0 if k % 2 == 0 else 3.6
					var a := -PI / 2 + TAU * k / 10.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(pts, UiTheme.GOLD)
			"memorial":
				draw_rect(Rect2(c + Vector2(-5, -6), Vector2(10, 13)), Color(0.6, 0.58, 0.56))
				draw_circle(c + Vector2(0, -6), 5.0, Color(0.6, 0.58, 0.56))
			"gift":
				draw_circle(c, 5.5, Color("#d2617a"))
			"dream":
				draw_circle(c, 6.0, Color(UiTheme.LEAF, 0.7))
			"dreamt":
				draw_arc(c, 5.5, 0, TAU, 20, Color(UiTheme.LEAF, 0.8), 2.0, true)
			"power":
				PortraitFrame.draw_hand_mark(self, c + Vector2(0, 2), 7.0, UiTheme.OCHRE)
			_:
				draw_circle(c, 3.0, Color(UiTheme.INK_SOFT, 0.7))

class FaithBar extends Control:
	var value := 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(0, 14)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2(0, 4), Vector2(size.x, 7))
		draw_rect(r, Color(UiTheme.INK_SOFT, 0.15))
		draw_rect(Rect2(r.position, Vector2(r.size.x * value, r.size.y)), Color(UiTheme.OCHRE, 0.85))
		draw_rect(r, Color(UiTheme.INK_SOFT, 0.5), false, 1.0)
