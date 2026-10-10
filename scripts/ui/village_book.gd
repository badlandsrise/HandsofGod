class_name VillageBook extends PanelContainer
## F1: the Village Book. The People tab lists everyone (name, age stage, trust
## stars, wish, status); click a row to pan there. Other tabs are M1 placeholders
## (Dreams and Powers show a simple list).

signal person_clicked(p: Person)

const STAGES := ["Baby", "Child", "Adult", "Elder"]

var tabs: TabContainer
var people_list: VBoxContainer
var dreams_list: VBoxContainer
var powers_list: VBoxContainer
var _hud: Node = null

func _init(hud: Node = null) -> void:
	_hud = hud

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UiTheme.box(Color(0.3, 0.2, 0.12, 0.96), Color(0.75, 0.55, 0.3, 0.9), 14, 12.0, 2))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(820, 540)
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "The Village Book"
	title.add_theme_font_size_override(&"font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Close (F1)"
	close.pressed.connect(close_book)
	head.add_child(close)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	people_list = _page("People")
	_placeholder(_page("Family Tree"), "The family tree grows from the first two. (Coming soon.)")
	dreams_list = _page("Dreams")
	_placeholder(_page("Memories"), "Gifts, firsts and memorials will be written here. (Coming soon.)")
	powers_list = _page("Powers")

func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 4)
	sc.add_child(list)
	return list

func _placeholder(list: VBoxContainer, text: String) -> void:
	list.add_child(_ink(text, 17))

func _ink(text: String, fs: int = 16, w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", Color(0.25, 0.15, 0.07))
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_font_size_override(&"font_size", fs)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w == 0.0 else TextServer.AUTOWRAP_OFF
	l.clip_text = w > 0.0
	if w > 0.0:
		l.custom_minimum_size.x = w
	return l

func is_open() -> bool:
	return visible

func toggle() -> void:
	if visible: close_book()
	else: open_book()

func open_book() -> void:
	refresh()
	visible = true
	position = (get_parent_area_size() - size) * 0.5

func close_book() -> void:
	visible = false

func refresh() -> void:
	_fill_people()
	_fill_dreams()
	_fill_powers()

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _fill_people() -> void:
	_clear(people_list)
	var head := HBoxContainer.new()
	for pair in [["Name", 150.0], ["Age", 110.0], ["Trust", 90.0], ["Wish", 170.0], ["Status", 0.0]]:
		var l := _ink(pair[0], 15, pair[1] if pair[1] > 0.0 else 1.0)
		l.add_theme_color_override(&"font_color", Color(0.45, 0.3, 0.15))
		if pair[1] == 0.0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
	people_list.add_child(head)
	var n := 0
	for p in Village.people:
		if not (p is Person) or not is_instance_valid(p):
			continue
		n += 1
		people_list.add_child(_person_row(p))
	if n == 0:
		people_list.add_child(_ink("Nobody lives here yet.", 16))

func _person_row(p: Person) -> Button:
	var b := Button.new()
	b.flat = false
	b.custom_minimum_size.y = 34
	var clear := UiTheme.box(Color(1, 1, 1, 0.0), Color(0, 0, 0, 0), 6, 4.0, 0)
	b.add_theme_stylebox_override(&"normal", clear)
	b.add_theme_stylebox_override(&"hover", UiTheme.box(Color(0.55, 0.38, 0.2, 0.18), Color(0, 0, 0, 0), 6, 4.0, 0))
	b.add_theme_stylebox_override(&"pressed", UiTheme.box(Color(0.55, 0.38, 0.2, 0.3), Color(0, 0, 0, 0), 6, 4.0, 0))
	b.tooltip_text = "Click to look at %s" % p.given_name
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	b.add_child(row)
	var age := STAGES[clampi(p.stage, 0, 3)] as String
	if &"age" in p:
		age += ", %d" % int(float(p.get(&"age")) / 60.0)   # a game minute is a year (doc section 3)
	var wish := ""
	if &"wish" in p:
		wish = str(p.get(&"wish"))
	for pair in [[p.given_name, 150.0], [age, 110.0]]:
		var l := _ink(pair[0], 16, pair[1])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
	var stars := UiPips.new()
	stars.stars = true
	stars.radius = 7.0
	stars.on_color = Color(0.85, 0.55, 0.12)
	stars.off_color = Color(0.4, 0.3, 0.2, 0.3)
	stars.setup(clampi(p.trust, 0, 5), 5)
	var holder := CenterContainer.new()
	holder.custom_minimum_size.x = 90
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stars)
	row.add_child(holder)
	var wl := _ink(wish if wish != "" else "-", 16, 170.0)
	wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wl)
	var sl := _ink(p.status_text(), 16, 1.0)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sl)
	b.pressed.connect(func():
		if is_instance_valid(p):
			person_clicked.emit(p))
	return b

func _fill_dreams() -> void:
	_clear(dreams_list)
	var ids: Array = _hud.dream_ids() if _hud != null and _hud.has_method(&"dream_ids") else []
	if ids.is_empty():
		dreams_list.add_child(_ink("No dreams yet. They will come.", 16))
	for id in ids:
		var d := Defs.dream(id)
		dreams_list.add_child(_ink("- " + (d.text if d != null and d.text != "" else String(id).capitalize()), 17))

func _fill_powers() -> void:
	_clear(powers_list)
	var ps: Array = Defs.powers.values()
	ps.sort_custom(func(a, b): return a.era < b.era or (a.era == b.era and a.cost < b.cost))
	if ps.is_empty():
		powers_list.add_child(_ink("The hand has no powers yet.", 16))
	for d in ps:
		var state := "owned" if Faith.has(d.id) else ("ready" if Faith.can_buy(d.id) else "era %d, %d faith" % [d.era, int(d.cost)])
		powers_list.add_child(_ink("%s  (%s)  %s  Opens: %s" % [d.title, state, d.what_it_does, d.what_it_opens], 16))
