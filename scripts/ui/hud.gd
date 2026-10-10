class_name Hud extends CanvasLayer
## The HUD (design doc 11.1): Dreams top-left, Stores top-centre, Faith ring and
## power buttons bottom-left, Time top-right, Alerts on the right edge, Toasts
## bottom-centre; Tab shows all labels, F1 opens the Village Book. The hand's
## own tooltip is drawn by the hand (scripts/hand/hand_visual.gd).
## Everything is built in code with UiTheme; set_ui_scale() scales it all (0.8..1.5).
## M2: alerts are parchment cards with the portrait of the person they are about;
## the HUD also owns the Chronicle (the Book's journal), Portraits, Notices (dream
## and region banners), the naming card and the era card.

const FOOD_PER_PERSON_PER_DAY := 1.0
## Materials that matter in each era even at zero (food is always shown).
const RELEVANT := {
	1: [&"wood", &"stone"],
	2: [&"wood", &"stone", &"clay", &"grain"],
	3: [&"wood", &"stone", &"iron", &"cloth"],
	4: [&"steel", &"fuel", &"parts"],
}
const STORE_COLORS := {
	&"food": Color(0.92, 0.42, 0.45), &"wood": Color(0.72, 0.5, 0.3), &"stone": Color(0.7, 0.72, 0.75),
	&"clay": Color(0.8, 0.5, 0.35), &"grain": Color(0.95, 0.82, 0.4), &"iron": Color(0.55, 0.6, 0.68),
}
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const ALERT_SECONDS := 10.0
const TOAST_SECONDS := 4.0
const MAX_ALERTS := 5
const MAX_DREAMS := 3

var ui_scale: float = 1.0
var root: Control
var dreams_panel: PanelContainer
var dreams_box: VBoxContainer
var stores_panel: PanelContainer
var stores_box: HBoxContainer
var faith_ring: FaithRing
var power_bar: HBoxContainer
var time_label: Label
var speed_buttons: Array = []
var alerts_box: VBoxContainer
var toast_box: VBoxContainer
var labels: LabelsOverlay
var book: VillageBook
var portraits: Portraits
var chronicle: Chronicle
var notices: Notices
var naming: NamingCard
var era_card: EraCard

var _dreams: Array = []        # {id, node, pips, done_t}
var _alerts: Array = []        # {node, t}
var _toasts: Array = []        # {node, t}
var _power_buttons: Dictionary = {}   # id -> Button
var _refresh_t: float = 0.0
var _chrome: Array = []        # panels hidden while the book is open
var _modal_was := false
var _hand_paused := false

func _ready() -> void:
	add_to_group(&"hud")
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Options.loaded:
		Options.load_options()
	portraits = Portraits.new()
	add_child(portraits)
	chronicle = Chronicle.new()
	add_child(chronicle)
	root = Control.new()
	root.name = "Root"
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	labels = LabelsOverlay.new()
	root.add_child(labels)
	_build_dreams()
	_build_stores()
	_build_time()
	_build_faith()
	_build_alerts()
	_build_toasts()
	notices = Notices.new()
	root.add_child(notices)
	book = VillageBook.new(self)
	root.add_child(book)
	era_card = EraCard.new()
	root.add_child(era_card)
	naming = NamingCard.new()
	root.add_child(naming)
	book.person_clicked.connect(func(p: Person):
		pan_to(p.global_position)
		book.close_book())
	get_viewport().size_changed.connect(_fit)
	_fit()
	Events.dream_started.connect(add_dream)
	Events.dream_done.connect(finish_dream)
	Events.alert.connect(add_alert)
	Events.toast.connect(add_toast)
	Events.power_unlocked.connect(func(_id): rebuild_powers())
	Events.era_changed.connect(func(_e): rebuild_powers(); refresh())
	Events.resource_changed.connect(func(_k, _a): _refresh_t = 0.0)
	rebuild_powers()
	refresh()

func set_ui_scale(s: float) -> void:
	ui_scale = clampf(s, 0.8, 1.5)
	_fit()

func _fit() -> void:
	if root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	root.scale = Vector2(ui_scale, ui_scale)
	root.position = Vector2.ZERO
	root.size = vs / ui_scale

# ---------------------------------------------------------------- building

func _panel(preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	root.add_child(p)
	p.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 14)
	return p

func _label(text: String, fs: int = 17, col: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", fs)
	l.add_theme_color_override(&"font_color", col)
	return l

func _build_dreams() -> void:
	dreams_panel = _panel(Control.PRESET_TOP_LEFT)
	dreams_panel.custom_minimum_size.x = 290
	var v := VBoxContainer.new()
	dreams_panel.add_child(v)
	v.add_child(_label("VILLAGE DREAMS", 13, UiTheme.ACCENT))
	dreams_box = VBoxContainer.new()
	dreams_box.add_theme_constant_override(&"separation", 6)
	v.add_child(dreams_box)
	dreams_panel.visible = false

func _build_stores() -> void:
	stores_panel = _panel(Control.PRESET_CENTER_TOP)
	stores_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chrome.append(stores_panel)
	stores_box = HBoxContainer.new()
	stores_box.add_theme_constant_override(&"separation", 18)
	stores_panel.add_child(stores_box)

func _build_time() -> void:
	var p := _panel(Control.PRESET_TOP_RIGHT)
	_chrome.append(p)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	p.add_child(h)
	h.add_child(DayDial.new())
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	time_label = _label("Day 1", 17)
	v.add_child(time_label)
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override(&"separation", 4)
	v.add_child(sp)
	var group := ButtonGroup.new()
	for i in 4:
		var b := Button.new()
		b.text = ["||", "1x", "2x", "3x"][i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 30)
		b.tooltip_text = ["Pause (Space)", "Normal speed (1)", "Fast (2)", "Fastest (3)"][i]
		b.pressed.connect(Clock.set_speed.bind(i))
		sp.add_child(b)
		speed_buttons.append(b)

func _build_faith() -> void:
	var p := _panel(Control.PRESET_BOTTOM_LEFT)
	_chrome.append(p)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	p.add_child(h)
	faith_ring = FaithRing.new()
	faith_ring.tooltip_text = "Faith: earned by caring for your people. Spend it on powers."
	h.add_child(faith_ring)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(_label("POWERS OF THE HAND", 13, UiTheme.ACCENT))
	power_bar = HBoxContainer.new()
	power_bar.add_theme_constant_override(&"separation", 6)
	v.add_child(power_bar)

func _build_alerts() -> void:
	alerts_box = VBoxContainer.new()
	root.add_child(alerts_box)
	alerts_box.anchor_left = 1.0
	alerts_box.anchor_right = 1.0
	alerts_box.offset_left = -330
	alerts_box.offset_right = -14
	alerts_box.offset_top = 130
	alerts_box.add_theme_constant_override(&"separation", 6)
	alerts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	root.add_child(toast_box)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 130)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---------------------------------------------------------------- dreams

func dream_ids() -> Array:
	return _dreams.map(func(d): return d["id"])

func add_dream(id: StringName) -> void:
	for d in _dreams:
		if d["id"] == id:
			return
	var def := Defs.dream(id)
	var b := PanelContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override(&"panel", UiTheme.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.0), 8, 8.0, 0))
	b.tooltip_text = "Click to look"
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var l := _label(def.text if def != null and def.text != "" else String(id).capitalize(), 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 250
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var pips := UiPips.new()
	pips.radius = 5.0
	v.add_child(pips)
	dreams_box.add_child(b)
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_pan_to_dream(id))
	_dreams.append({"id": id, "node": b, "pips": pips, "done_t": -1.0})
	while _dreams.size() > MAX_DREAMS:
		var old: Dictionary = _dreams.pop_front()
		(old["node"] as Node).queue_free()
	dreams_panel.visible = true
	_refresh_dreams()

func finish_dream(id: StringName) -> void:
	for d in _dreams:
		if d["id"] == id and d["done_t"] < 0.0:
			d["done_t"] = 4.0
			(d["node"] as Control).modulate = Color(0.75, 1.0, 0.7)
			var pips: UiPips = d["pips"]
			pips.filled = pips.total

## {x: met, y: needed} for a dream's checklist.
static func dream_progress(def: DreamDef) -> Vector2i:
	var got := 0
	var need := 0
	if def == null:
		return Vector2i.ZERO
	for b in def.needs_buildings:
		var n := int(def.needs_buildings[b])
		need += n
		got += mini(Village.count_buildings(b), n)
	for k in def.needs_stores:
		need += 1
		var have := Village.food() if k == &"food" else Village.store(k)
		if have >= int(def.needs_stores[k]):
			got += 1
	if def.needs_population > 0:
		need += 1
		if Village.population() >= def.needs_population:
			got += 1
	if def.needs_survive_winter:
		need += 1
		if int(Village.stats.get("winters_survived", 0)) > 0:
			got += 1
	return Vector2i(got, need)

func _refresh_dreams() -> void:
	for d in _dreams:
		if d["done_t"] >= 0.0:
			continue
		var pr := dream_progress(Defs.dream(d["id"]))
		var pips: UiPips = d["pips"]
		var total := mini(pr.y, 10)
		pips.setup(int(round(float(pr.x) * float(total) / float(maxi(pr.y, 1)))), total)

func _pan_to_dream(id: StringName) -> void:
	var def := Defs.dream(id)
	if def == null:
		return
	for b in def.needs_buildings:
		for s in Village.sites:
			if s is Site and is_instance_valid(s) and s.building != null and s.building.id == b:
				pan_to(s.global_position)
				return

# ---------------------------------------------------------------- alerts and toasts

func add_alert(text: String, at: Vector3 = Vector3.INF) -> void:
	var b := Notices.alert_card(text, at, pan_to.bind(at) if at.is_finite() else Callable())
	alerts_box.add_child(b)
	b.modulate.a = 0.0
	b.position.x += 40.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(b, "modulate:a", 1.0, 0.25)
	_alerts.append({"node": b, "t": ALERT_SECONDS})
	while _alerts.size() > MAX_ALERTS:
		var old: Dictionary = _alerts.pop_front()
		(old["node"] as Node).queue_free()

func add_toast(text: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override(&"panel", UiTheme.box(Color(0.16, 0.11, 0.08, 0.88), UiTheme.ACCENT, 12, 16.0))
	var l := _label(text, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	toast_box.add_child(p)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.append({"node": p, "t": TOAST_SECONDS})
	while _toasts.size() > 3:
		var old: Dictionary = _toasts.pop_front()
		(old["node"] as Node).queue_free()

func pan_to(p: Vector3) -> void:
	var cam := get_tree().get_first_node_in_group(&"camera_rig")
	if cam != null and cam.has_method(&"focus_on"):
		cam.focus_on(p)

# ---------------------------------------------------------------- powers

func rebuild_powers() -> void:
	for c in power_bar.get_children():
		c.queue_free()
	_power_buttons.clear()
	var ps: Array = Defs.powers.values().filter(func(d): return d.era <= Village.era)
	ps.sort_custom(func(a, b): return a.era < b.era or (a.era == b.era and a.cost < b.cost))
	for d in ps:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(86, 52)
		b.text = "%s\n%s" % [d.title, "gift" if d.free else str(int(d.cost))]
		b.add_theme_font_size_override(&"font_size", 14)
		b.pressed.connect(_on_power_pressed.bind(d.id))
		power_bar.add_child(b)
		_power_buttons[d.id] = b
	if ps.is_empty():
		power_bar.add_child(_label("(none yet)", 14, UiTheme.TEXT_DIM))
	_refresh_powers()

func power_state(id: StringName) -> StringName:
	if Faith.has(id): return &"owned"
	if Faith.can_buy(id): return &"affordable"
	return &"locked"

func _refresh_powers() -> void:
	var hand := get_tree().get_first_node_in_group(&"hand")
	var sel: StringName = hand.selected_power if hand != null and &"selected_power" in hand else &""
	var cheapest := 0.0
	var any_affordable := false
	for id in _power_buttons:
		var d := Defs.power(id)
		var b: Button = _power_buttons[id]
		var st := power_state(id)
		var tip := "%s  (%s)\n%s\nOpens: %s" % [d.title, "a gift opens this" if d.free else "%d faith" % int(d.cost), d.what_it_does, d.what_it_opens]
		match st:
			&"owned":
				b.modulate = Color(1, 1, 1)
				var sb := UiTheme.box(Color(0.3, 0.36, 0.18, 0.92), UiTheme.GOOD if id != sel else Color(1, 1, 0.8), 8, 8.0, 2 if id != sel else 3)
				b.add_theme_stylebox_override(&"normal", sb)
				tip += "\nOwned." + ("  Selected: hold E." if d.gesture and id == sel else ("  Click to select, then hold E." if d.gesture else ""))
			&"affordable":
				any_affordable = true
				b.modulate = Color(1, 1, 1)
				var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
				b.add_theme_stylebox_override(&"normal", UiTheme.box(Color(0.45, 0.3, 0.12, 0.95), Color(UiTheme.ACCENT, pulse), 8, 8.0, 2))
				tip += "\nClick to unlock."
			_:
				b.modulate = Color(1, 1, 1, 0.5)
				b.remove_theme_stylebox_override(&"normal")
				if not d.free and (cheapest == 0.0 or d.cost < cheapest):
					cheapest = d.cost
		b.tooltip_text = tip
	faith_ring.available = Faith.available()
	faith_ring.next_cost = cheapest
	faith_ring.affordable = any_affordable

func _on_power_pressed(id: StringName) -> void:
	var d := Defs.power(id)
	if d == null:
		return
	if Faith.can_buy(id):
		if Faith.buy(id):
			add_toast("%s: %s" % [d.title, d.what_it_opens if d.what_it_opens != "" else d.what_it_does])
		return
	if Faith.has(id):
		var hand := get_tree().get_first_node_in_group(&"hand")
		if d.gesture and hand != null and &"selected_power" in hand:
			hand.selected_power = id
			add_toast("%s selected. Hold E over the world." % d.title)
		return
	if d.free:
		add_toast("Your people will open this one.")
	elif d.era > Village.era:
		add_toast("Not yet. This belongs to a later age.")
	else:
		add_toast("%s needs %d faith." % [d.title, int(d.cost)])

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	_refresh_stores()
	_refresh_dreams()
	_refresh_powers()
	_refresh_time()

var _stores_sig: String = "~"

func _refresh_stores() -> void:
	var sig := "%d|%d|%d|%s" % [Village.era, Village.food(), Village.population(), str(Village.stores)]
	if sig == _stores_sig:
		return
	_stores_sig = sig
	for c in stores_box.get_children():
		stores_box.remove_child(c)
		c.queue_free()
	var food := Village.food()
	stores_box.add_child(_store_item(&"food", "Food", food))
	var kinds: Array = []
	for k in RELEVANT.get(clampi(Village.era, 1, 4), []):
		kinds.append(k)
	for k in Village.stores:
		if k in Village.FOOD_KINDS or kinds.has(k):
			continue
		if Village.store(k) > 0:
			kinds.append(k)
	for k in kinds:
		stores_box.add_child(_store_item(k, String(k).capitalize(), Village.store(k)))
	var pop := Village.population()
	var days := float(food) / maxf(float(pop) * FOOD_PER_PERSON_PER_DAY, 1.0)
	var nd := int(floor(days))
	var dl := _label(("%s day of food" if nd == 1 else "%s days of food") % (str(nd) if nd < 99 else "99+"), 15,
		UiTheme.WARN if days < 2.0 else UiTheme.TEXT_DIM)
	stores_box.add_child(dl)

func _store_item(kind: StringName, title: String, n: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	var dot := UiPips.new()
	dot.radius = 6.0
	dot.on_color = STORE_COLORS.get(kind, Color(0.85, 0.8, 0.7))
	dot.setup(1, 1)
	var cc := CenterContainer.new()
	cc.add_child(dot)
	h.add_child(cc)
	h.add_child(_label("%s %d" % [title, n], 17))
	return h

func _refresh_time() -> void:
	time_label.text = "Day %d · %s" % [Clock.day, SEASONS[clampi(Clock.season, 0, 3)]] + (" · night" if Clock.is_night else "")
	for i in speed_buttons.size():
		(speed_buttons[i] as Button).set_pressed_no_signal(i == Clock.speed_index)

func _process(_d: float) -> void:
	var dt := Clock.real_delta
	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_refresh_t = 0.25
		refresh()
	for a in _alerts.duplicate():
		a["t"] -= dt
		var n: Control = a["node"]
		if not is_instance_valid(n):
			_alerts.erase(a)
			continue
		n.modulate.a = clampf(a["t"], 0.0, 1.0)
		if a["t"] <= 0.0:
			_alerts.erase(a)
			n.queue_free()
	for t in _toasts.duplicate():
		t["t"] -= dt
		var n: Control = t["node"]
		if not is_instance_valid(n):
			_toasts.erase(t)
			continue
		n.modulate.a = clampf(t["t"] * 2.0, 0.0, 1.0)
		if t["t"] <= 0.0:
			_toasts.erase(t)
			n.queue_free()
	for d in _dreams.duplicate():
		if d["done_t"] >= 0.0:
			d["done_t"] -= dt
			if d["done_t"] <= 0.0:
				_dreams.erase(d)
				(d["node"] as Node).queue_free()
	_update_modal_state()
	dreams_panel.visible = not _dreams.is_empty() and not book.is_open()

## Esc: closes the topmost card or the book. Returns true if it closed something
## (the menu asks first, so Esc never opens the pause menu over the book).
func close_top_modal() -> bool:
	if not visible:
		return false
	if naming != null and naming.is_open():
		return true          # the names must be given; Esc does nothing here
	if era_card != null and era_card.is_open():
		era_card.keep_playing()
		return true
	if book != null and book.is_open():
		book.close_book()
		return true
	return false

## While the book or a card is open: the HUD panels step back (book only), and
## the hand rests so its hover card and clicks stay out of the way.
func _update_modal_state() -> void:
	var book_open := book != null and book.is_open()
	var m := book_open or modal_open()
	for c in _chrome:
		(c as Control).visible = not book_open
	alerts_box.visible = not book_open
	toast_box.visible = not book_open
	if m == _modal_was:
		return
	_modal_was = m
	var hand := get_tree().get_first_node_in_group(&"hand")
	if hand == null:
		return
	if m and hand.process_mode != Node.PROCESS_MODE_DISABLED:
		hand.process_mode = Node.PROCESS_MODE_DISABLED
		_hand_paused = true
		var hv := hand.get_node_or_null("Visual")
		if hv != null and hv.get(&"tip_panel") is Control:
			(hv.get(&"tip_panel") as Control).visible = false
	elif not m and _hand_paused:
		_hand_paused = false
		if visible:
			hand.process_mode = Node.PROCESS_MODE_INHERIT

func modal_open() -> bool:
	return (naming != null and naming.is_open()) or (era_card != null and era_card.is_open())

func _unhandled_input(e: InputEvent) -> void:
	if modal_open():
		return
	if e.is_action_pressed(&"labels"):
		labels.shown = not labels.shown
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed(&"book"):
		book.toggle()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed(&"menu") and book.is_open():
		book.close_book()
		get_viewport().set_input_as_handled()
