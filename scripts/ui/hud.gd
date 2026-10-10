class_name Hud extends CanvasLayer
## The HUD (design doc 11.1): Dreams top-left, Stores top-centre, Faith ring and
## power buttons bottom-left, Time top-right, Alerts on the right edge, Toasts
## bottom-centre; Tab shows all labels, F1 opens the Village Book. The hand's
## own tooltip is drawn by the hand (scripts/hand/hand_visual.gd).
## Everything is built in code with UiTheme; set_ui_scale() scales it all (0.8..1.5).
## M2: alerts are parchment cards with the portrait of the person they are about;
## the HUD also owns the Chronicle (the Book's journal), Portraits, Notices (dream
## and region banners), the naming card and the era card.
## Playtest pass: the goal panel (GoalPanel: the dream and its live checklist,
## or "The people are restless..."), the dream card that waits for a click
## (DreamCard), power buttons that list every missing requirement on hover
## (PowerInfo), store tooltips, the idle counter with its Call button, and the
## Guidance beats (camera pans, beacons, blessing rings, first-time hints).

const FOOD_PER_PERSON_PER_DAY := 1.0
## Materials that matter in each era even at zero (food is always shown).
const RELEVANT := {
	1: [&"wood", &"stone"],
	2: [&"wood", &"stone", &"grain", &"flour", &"water"],
	3: [&"wood", &"blocks", &"iron", &"books"],
	4: [&"steel", &"fuel", &"parts"],
}
const STORE_COLORS := {
	&"food": Color(0.92, 0.42, 0.45), &"wood": Color(0.72, 0.5, 0.3), &"stone": Color(0.7, 0.72, 0.75),
	&"clay": Color(0.8, 0.5, 0.35), &"grain": Color(0.95, 0.82, 0.4), &"iron": Color(0.55, 0.6, 0.68),
	&"flour": Color(0.96, 0.93, 0.85), &"water": Color(0.45, 0.65, 0.9), &"pots": Color(0.78, 0.45, 0.3),
	&"ore": Color(0.4, 0.62, 0.55), &"charcoal": Color(0.25, 0.24, 0.24), &"bronze": Color(0.8, 0.6, 0.3),
	&"tools": Color(0.7, 0.55, 0.35), &"wool": Color(0.95, 0.95, 0.9), &"cloth": Color(0.6, 0.45, 0.7),
	&"blocks": Color(0.78, 0.76, 0.7),
}
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const ALERT_SECONDS := 10.0
const TOAST_SECONDS := 4.0
const MAX_ALERTS := 5

var ui_scale: float = 1.0
var root: Control
var dreams_panel: GoalPanel
var stores_panel: PanelContainer
var stores_box: HBoxContainer
var time_panel: PanelContainer
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
var dream_card: DreamCard
var guidance: Guidance
var power_card: PowerInfo.Card
var idle_panel: PanelContainer
var idle_label: Label
var idle_button: Button

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
	_build_idle()
	notices = Notices.new()
	root.add_child(notices)
	book = VillageBook.new(self)
	root.add_child(book)
	era_card = EraCard.new()
	root.add_child(era_card)
	naming = NamingCard.new()
	root.add_child(naming)
	dream_card = DreamCard.new()
	root.add_child(dream_card)
	guidance = Guidance.new(self)
	add_child(guidance)
	book.person_clicked.connect(func(p: Person):
		pan_to(p.global_position)
		guidance.mark(p, 8.0)
		book.close_book())
	get_viewport().size_changed.connect(_fit)
	_fit()
	Events.dream_started.connect(func(_id): dreams_panel.refresh())
	Events.dream_done.connect(func(_id): dreams_panel.refresh())
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
	return Hud.make_label(text, fs, col)

static func make_label(text: String, fs: int = 17, col: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", fs)
	l.add_theme_color_override(&"font_color", col)
	return l

func _build_dreams() -> void:
	dreams_panel = GoalPanel.new()
	root.add_child(dreams_panel)
	dreams_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	dreams_panel.look_at.connect(pan_to)

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
	time_panel = p
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
	power_card = PowerInfo.Card.new()
	root.add_child(power_card)

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

## Bottom right: how many people stand idle, and a button that calls them
## to the hand (Village.call_idle, when the village has it) or else looks at
## each idle person in turn.
func _build_idle() -> void:
	idle_panel = _panel(Control.PRESET_BOTTOM_RIGHT)
	idle_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	idle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	idle_panel.add_child(h)
	idle_label = _label("0 idle", 16, UiTheme.TEXT_DIM)
	idle_label.mouse_filter = Control.MOUSE_FILTER_PASS
	idle_label.tooltip_text = "People with no work. Hover one to see why."
	h.add_child(idle_label)
	idle_button = Button.new()
	idle_button.focus_mode = Control.FOCUS_NONE
	idle_button.custom_minimum_size = Vector2(76, 32)
	idle_button.add_theme_font_size_override(&"font_size", 15)
	idle_button.pressed.connect(call_idle)
	h.add_child(idle_button)
	idle_panel.visible = false

var _idle_i: int = -1

## The thing that can call the idle to a spot: Village.call_idle(at) or the
## world's (worker C's gesture), else null.
static func idle_caller() -> Object:
	if Village.has_method(&"call_idle"):
		return Village
	if Game.world != null and is_instance_valid(Game.world) and Game.world.has_method(&"call_idle"):
		return Game.world
	return null

## Calls every idle person to where the hand is (or the camera looks), or, if
## the village can't call them, looks at the next idle person.
func call_idle() -> int:
	var idle := PersonInfo.idle_people()
	if idle.is_empty():
		add_toast("Everyone is busy.")
		return 0
	var caller := Hud.idle_caller()
	if caller != null:
		var r = caller.call(&"call_idle", _call_point())
		var n: int = int(r) if (r is int or r is float) else idle.size()
		add_toast("%s coming to the hand." % ("1 idle person is" if n == 1 else "%d idle people are" % n))
		return n
	_idle_i = (_idle_i + 1) % idle.size()
	var p: Person = idle[_idle_i]
	pan_to(p.global_position)
	guidance.mark(p, 5.0)
	add_toast("%s: %s" % [p.given_name, PersonInfo.idle_reason(p)])
	return 0

func _call_point() -> Vector3:
	var hand := get_tree().get_first_node_in_group(&"hand")
	if hand != null and &"ground" in hand and (hand.ground as Vector3).is_finite():
		return hand.ground
	var cam := get_tree().get_first_node_in_group(&"camera_rig")
	if cam != null and &"target_focus" in cam:
		return cam.target_focus
	return Vector3.ZERO

func _refresh_idle() -> void:
	var on := Flags.onboarding_done() and Village.population() > 0
	idle_panel.visible = on and not book.is_open()
	if not on:
		return
	var n := PersonInfo.idle_people().size()
	idle_label.text = "%d idle" % n
	idle_label.add_theme_color_override(&"font_color", UiTheme.ACCENT if n > 0 else UiTheme.TEXT_DIM)
	var can_call := Hud.idle_caller() != null
	idle_button.text = "Call" if can_call else "Find"
	idle_button.disabled = n == 0
	idle_button.tooltip_text = "Call every idle person to the hand." if can_call else "Look at the next idle person."

func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	root.add_child(toast_box)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 130)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---------------------------------------------------------------- dreams

## The id of the dream the goal panel shows (the active one, or the next).
func dream_ids() -> Array:
	return [dreams_panel.dream_id] if dreams_panel != null and dreams_panel.dream_id != &"" else []

## {x: met, y: needed} for a dream's checklist (one per line of it).
static func dream_progress(def: DreamDef) -> Vector2i:
	var items := Dreams.checklist(def)
	var got := 0
	for it in items:
		if it["done"]:
			got += 1
	return Vector2i(got, items.size())

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
		var b := PowerButton.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(86, 52)
		b.text = "%s\n%s" % [d.title, "gift" if d.free else str(int(d.cost))]
		b.add_theme_font_size_override(&"font_size", 14)
		b.pressed.connect(_on_power_pressed.bind(d.id))
		b.mouse_entered.connect(show_power_card.bind(d.id))
		b.mouse_exited.connect(hide_power_card)
		power_bar.add_child(b)
		_power_buttons[d.id] = b
	if ps.is_empty():
		power_bar.add_child(_label("(none yet)", 14, UiTheme.TEXT_DIM))
	_refresh_powers()

func power_state(id: StringName) -> StringName:
	var d := Defs.power(id)
	return PowerInfo.state(d) if d != null else &"locked"

## The requirements card over the power bar (hover, or tests and screenshots).
func show_power_card(id: StringName) -> void:
	power_card.show_power(id)
	await get_tree().process_frame
	place_power_card()

func place_power_card() -> void:
	if not is_instance_valid(power_card) or not power_card.visible:
		return
	var b: Control = _power_buttons.get(power_card.power_id)
	power_card.reset_size()
	var bx := b.get_global_rect() if b != null and is_instance_valid(b) else Rect2(Vector2(20, root.size.y - 140), Vector2(80, 50))
	var inv := root.get_global_transform().affine_inverse()
	var top: Vector2 = inv * bx.position
	power_card.position = Vector2(clampf(top.x, 10.0, root.size.x - power_card.size.x - 10.0), top.y - power_card.size.y - 40.0)

func hide_power_card() -> void:
	power_card.visible = false

func _refresh_powers() -> void:
	var hand := get_tree().get_first_node_in_group(&"hand")
	var sel: StringName = hand.selected_power if hand != null and &"selected_power" in hand else &""
	var cheapest := 0.0
	var any_affordable := false
	for id in _power_buttons:
		var d := Defs.power(id)
		var b: PowerButton = _power_buttons[id]
		var st := power_state(id)
		b.lock = st == &"locked"
		b.tooltip_text = ""
		match st:
			&"owned":
				b.modulate = Color(1, 1, 1)
				var sb := UiTheme.box(Color(0.3, 0.36, 0.18, 0.92), UiTheme.GOOD if id != sel else Color(1, 1, 0.8), 8, 8.0, 2 if id != sel else 3)
				b.add_theme_stylebox_override(&"normal", sb)
			&"affordable":
				any_affordable = true
				b.modulate = Color(1, 1, 1)
				var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
				b.add_theme_stylebox_override(&"normal", UiTheme.box(Color(0.45, 0.3, 0.12, 0.95), Color(UiTheme.ACCENT, pulse), 8, 8.0, 2))
			_:
				b.modulate = Color(1, 1, 1, 0.55 if st == &"locked" else 0.75)
				b.remove_theme_stylebox_override(&"normal")
				if not d.free and st == &"faith" and (cheapest == 0.0 or d.cost < cheapest):
					cheapest = d.cost
	faith_ring.available = Faith.available()
	faith_ring.next_cost = cheapest
	faith_ring.affordable = any_affordable
	if power_card.visible and not _power_buttons.has(power_card.power_id):
		power_card.visible = false

func _on_power_pressed(id: StringName) -> void:
	var d := Defs.power(id)
	if d == null:
		return
	if Faith.can_buy(id):
		if Faith.buy(id):
			add_toast("%s: %s" % [d.title, d.what_it_opens if d.what_it_opens != "" else d.what_it_does])
			if power_card.visible and power_card.power_id == id:
				show_power_card(id)
		return
	if Faith.has(id):
		var hand := get_tree().get_first_node_in_group(&"hand")
		if d.gesture and hand != null and &"selected_power" in hand:
			hand.selected_power = id
			add_toast("%s selected. Hold E over the world." % d.title)
		elif id == &"lift_buildings" and hand != null and &"selected_power" in hand:
			# a mode, not a gesture: houses can be picked up while it is selected
			if hand.selected_power == id:
				hand.selected_power = &""
				add_toast("Lift Buildings put away.")
			else:
				hand.selected_power = id
				add_toast("Lift Buildings: click a house to pick it up, click again to set it down. Press again to stop.")
			_refresh_powers()
		return
	add_toast(PowerInfo.locked_line(d))

## A power button that draws a small padlock while requirements other than
## faith are missing.
class PowerButton extends Button:
	var lock := false:
		set(v):
			if v != lock:
				lock = v
				queue_redraw()
	func _draw() -> void:
		if not lock:
			return
		var c := Vector2(size.x - 13.0, size.y - 13.0)
		var col := Color(1.0, 0.85, 0.6, 0.95)
		draw_arc(c + Vector2(0, -1.5), 3.4, PI, TAU, 10, col, 1.6, true)
		draw_rect(Rect2(c + Vector2(-4.5, -1.5), Vector2(9, 7)), col, true)
		draw_circle(c + Vector2(0, 1.8), 1.1, Color(0.2, 0.12, 0.05))

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	_refresh_stores()
	dreams_panel.refresh()
	_refresh_powers()
	_refresh_time()
	_refresh_idle()

var _stores_sig: String = "~"

## How many stores the bar shows besides food; the rest wait behind "+N more".
const BAR_MAX := 6
const LOW_AT := 5
var _bar_cap: int = BAR_MAX     # fewer on a narrow screen (_fit_stores)
var _bar_vw: float = 0.0

## The stores worth watching right now, most pressing first: what the current
## dream asks for, what open plots are still short of, anything full or nearly
## out, then the era's staples. A town keeps a dozen stores; the player should
## only have to read a handful (Austin's Era 3 note).
func watched_stores() -> Array:
	var out: Array = []
	var d: DreamDef = Defs.dream(dreams_panel.dream_id) if dreams_panel != null and dreams_panel.dream_id != &"" else null
	if d != null:
		for k in d.needs_stores:
			if k != &"food" and Village.store(k) < int(d.needs_stores[k]):
				_add_once(out, k)
	var short_plots: Array = []
	for st in Village.sites:
		if not is_instance_valid(st) or st.building == null or not st.is_plot():
			continue
		var for_dream: bool = d != null and d.needs_buildings.has(st.building.id)
		for k in st.building.cost:
			if k in Village.FOOD_KINDS or st.remaining(k) <= 0:
				continue
			if for_dream:
				_add_once(out, k)
			elif not short_plots.has(k):
				short_plots.append(k)
	for k in short_plots:
		if Village.store(k) < LOW_AT:
			_add_once(out, k)
	for k in Village.stores:
		if k in Village.FOOD_KINDS:
			continue
		if Village.store(k) >= Village.store_cap:
			_add_once(out, k)
	for k in RELEVANT.get(clampi(Village.era, 1, 4), []):
		_add_once(out, k)
	for k in short_plots:
		_add_once(out, k)
	return out

static func _add_once(a: Array, k) -> void:
	if not a.has(k):
		a.append(k)

func _refresh_stores() -> void:
	var watched := watched_stores()
	var sig := "%d|%d|%d|%s|%s" % [Village.era, Village.food(), Village.population(), str(Village.stores), str(watched)]
	if sig == _stores_sig:
		return
	_stores_sig = sig
	for c in stores_box.get_children():
		stores_box.remove_child(c)
		c.queue_free()
	var food := Village.food()
	stores_box.add_child(_store_item(&"food", "Food", food))
	var shown := watched.slice(0, _bar_cap)
	for k in shown:
		stores_box.add_child(_store_item(k, String(k).capitalize(), Village.store(k)))
	var rest: Array = []
	for k in Village.stores:
		if k in Village.FOOD_KINDS or shown.has(k) or Village.store(k) <= 0:
			continue
		rest.append(k)
	for k in watched:
		if not shown.has(k) and not rest.has(k):
			rest.append(k)
	if not rest.is_empty():
		rest.sort_custom(func(x, y): return String(x) < String(y))
		var lines: Array = ["Also in the stores:"]
		for k in rest:
			lines.append("%s %d" % [String(k).capitalize(), Village.store(k)])
		var more := _label("+%d more" % rest.size(), 15, UiTheme.TEXT_DIM)
		more.mouse_filter = Control.MOUSE_FILTER_PASS
		more.tooltip_text = "\n".join(lines)
		more.name = "MoreStores"
		stores_box.add_child(more)
	var pop := Village.population()
	var days := float(food) / maxf(float(pop) * food_per_person_per_day(), 0.5)
	var nd := int(floor(days))
	var dl := _label(("%s day of food" if nd == 1 else "%s days of food") % (str(nd) if nd < 99 else "99+"), 15,
		UiTheme.WARN if days < 2.0 else UiTheme.TEXT_DIM)
	stores_box.add_child(dl)
	_fit_stores.call_deferred()

## Keep the bar clear of the clock, and the goal panel clear of the bar.
func _fit_stores() -> void:
	if stores_box == null or not is_instance_valid(stores_box):
		return
	var vw := get_viewport().get_visible_rect().size.x
	var side := (time_panel.get_combined_minimum_size().x if time_panel != null else 280.0) + 28.0
	if not is_equal_approx(vw, _bar_vw):
		_bar_vw = vw
		if _bar_cap != BAR_MAX:
			_bar_cap = BAR_MAX
			_stores_sig = "~"
			_refresh_stores()
			return
	var room := vw - 2.0 * side
	stores_box.add_theme_constant_override(&"separation", 18)
	if stores_box.get_combined_minimum_size().x > room:
		stores_box.add_theme_constant_override(&"separation", 10)
	if stores_panel.get_combined_minimum_size().x > room and _bar_cap > 2:
		_bar_cap -= 1
		_stores_sig = "~"
		_refresh_stores()
		return
	stores_panel.reset_size()
	var w := stores_panel.get_combined_minimum_size().x
	stores_panel.offset_left = -w * 0.5
	stores_panel.offset_right = w * 0.5
	if dreams_panel == null:
		return
	var top := 14.0
	var sw := stores_panel.get_combined_minimum_size()
	var sr := Rect2(Vector2((vw - sw.x) * 0.5, 0.0), sw)
	var dr := Rect2(Vector2(14.0, 14.0), dreams_panel.get_combined_minimum_size())
	if sr.intersects(dr):
		top = sr.end.y + 8.0
	if not is_equal_approx(dreams_panel.offset_top, top):
		var hgt := dreams_panel.offset_bottom - dreams_panel.offset_top
		dreams_panel.offset_top = top
		dreams_panel.offset_bottom = top + hgt

## [polish] What one person really eats in a day and a night: the food need
## drains (Person.DECAY, slower in Era 1) and each meal refills 0.6.
static func food_per_person_per_day() -> float:
	var k := Person.ERA1_NEEDS if Village.era == 1 else 1.0
	var per_s: float = float(Person.DECAY[&"food"]) * k * Flags.diff_k(&"food")
	return maxf(per_s * (Clock.day_seconds + Clock.night_seconds) / 0.6, 0.1)

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
	var full := kind != &"food" and n >= Village.store_cap   # [polish] the stores are full
	h.add_child(_label(("%s %d/%d full" % [title, n, Village.store_cap]) if full else "%s %d" % [title, n], 17, UiTheme.WARN if full else UiTheme.TEXT))
	var note := PersonInfo.store_note(kind)
	if full:
		note = ("The stores hold no more %s: build a food store or a granary, or use some up. " % String(kind)) + note
	if note != "":
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		h.tooltip_text = note
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
	_update_modal_state()

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
	if dream_card != null and dream_card.is_open():
		dream_card.accept()
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
	if book_open and power_card.visible:
		power_card.visible = false
	dreams_panel.visible = not book_open and dreams_panel.mode != &"none"
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
	return (naming != null and naming.is_open()) or (era_card != null and era_card.is_open()) or (dream_card != null and dream_card.is_open())

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
