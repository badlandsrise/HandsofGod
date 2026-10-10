class_name PowerInfo extends RefCounted
## Why a power can or can't be bought, in full (playtest era 1, notes 17 and
## 21: "it said it takes 10 faith, I had 13"). Every requirement is listed,
## met or not: the powers before it, the regions and dreams it waits for, the
## people it needs, a village flag, its age, and its cost. The HUD's power
## buttons show these on hover and say the first missing one when clicked.

## [{text, done}] for every requirement of `d`, in the order a player meets them.
static func requirements(d: PowerDef) -> Array:
	var out: Array = []
	if d == null:
		return out
	if d.era > Village.era:
		var e := Defs.era(d.era)
		out.append({"key": "era", "text": "The %s age" % (e.title.to_lower() if e != null else "next"), "done": false})
	for r in d.requires:
		var rp: PowerDef = Defs.power(r)
		out.append({"key": "power:" + str(r), "text": "%s first" % (rp.title if rp != null else str(r).capitalize()), "done": Faith.has(r)})
	for r in d.requires_regions:
		out.append({"key": "region:" + str(r), "text": "%s opened" % BookData.cap(Dreams.region_title(r)), "done": Village.regions.has(r)})
	var done: Array = Village.stats.get("dreams_done", [])
	for dr in d.requires_dreams:
		var dd: DreamDef = Defs.dream(dr)
		out.append({"key": "dream:" + str(dr), "text": "The dream come true: “%s”" % (PowerInfo.short_dream(dd) if dd != null else str(dr)), "done": done.has(str(dr))})
	if d.min_population > 0:
		out.append({"key": "people", "text": "%d people (%d now)" % [d.min_population, Village.population()], "done": Village.population() >= d.min_population})
	for f in d.requires_flags:
		out.append({"key": "flag:" + str(f), "text": d.flag_hint if d.flag_hint != "" else Dreams.flag_title(f).capitalize(), "done": Flags.has(f)})
	if d.free:
		out.append({"key": "gift", "text": "A gift from the people opens it", "done": Faith.has(d.id)})
	else:
		var have := int(floor(Faith.available()))
		out.append({"key": "cost", "text": "%d faith (you have %d)" % [int(d.cost), have], "done": Faith.available() >= d.cost})
	return out

## The requirements still missing.
static func missing(d: PowerDef) -> Array:
	return PowerInfo.requirements(d).filter(func(r): return not r["done"])

## The dream's text cut to a few words for a button card.
static func short_dream(dd: DreamDef) -> String:
	var t := dd.text.trim_suffix(".")
	var cut := t.find(",")
	if cut > 12:
		t = t.substr(0, cut)
	return t

## A line for the toast when a locked power is clicked.
static func locked_line(d: PowerDef) -> String:
	if d == null:
		return ""
	var miss := PowerInfo.missing(d)
	if miss.is_empty():
		return ""
	if d.era > Village.era:
		return "%s belongs to a later age." % d.title
	if d.free:
		return "%s comes as a gift from the people." % d.title
	var bits: Array = miss.map(func(r): return str(r["text"]))
	if miss.size() == 1 and miss[0]["key"] == "cost":
		return "%s needs %d faith. You have %d." % [d.title, int(d.cost), int(floor(Faith.available()))]
	return "%s needs: %s." % [d.title, "; ".join(bits)]

## The face of a button: "ready", "owned", "faith" (only faith missing) or "locked".
static func state(d: PowerDef) -> StringName:
	if Faith.has(d.id):
		return &"owned"
	if Faith.can_buy(d.id):
		return &"affordable"
	var miss := PowerInfo.missing(d)
	if miss.size() == 1 and miss[0]["key"] == "cost":
		return &"faith"
	return &"locked"

## The card shown over the power bar while a button is hovered.
class Card extends PanelContainer:
	var power_id: StringName = &""
	var _v: VBoxContainer
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override(&"panel", UiTheme.box(Color(0.13, 0.09, 0.06, 0.96), UiTheme.ACCENT, 10, 14.0, 1))
		custom_minimum_size.x = 360
		_v = VBoxContainer.new()
		_v.add_theme_constant_override(&"separation", 3)
		_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_v)
		visible = false
	func show_power(id: StringName) -> void:
		var d: PowerDef = Defs.power(id)
		if d == null:
			visible = false
			return
		power_id = id
		for c in _v.get_children():
			_v.remove_child(c)
			c.queue_free()
		var st := PowerInfo.state(d)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_v.add_child(h)
		var t := Hud.make_label(d.title, 20, UiTheme.ACCENT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		var tag: String = {&"owned": "the hand has this", &"affordable": "ready to unlock", &"faith": "needs faith", &"locked": "locked"}[st]
		h.add_child(Hud.make_label(tag, 13, UiTheme.GOOD if st == &"owned" or st == &"affordable" else UiTheme.TEXT_DIM))
		_line(d.what_it_does, 15, UiTheme.TEXT)
		if d.what_it_opens != "":
			_line(("Opened: " if st == &"owned" else "Opens: ") + d.what_it_opens, 14, UiTheme.TEXT_DIM)
		if st != &"owned":
			var rule := ColorRect.new()
			rule.color = Color(1, 1, 1, 0.12)
			rule.custom_minimum_size = Vector2(0, 1)
			_v.add_child(rule)
			_v.add_child(Hud.make_label("NEEDS", 12, UiTheme.ACCENT))
			for r in PowerInfo.requirements(d):
				var row := HBoxContainer.new()
				row.add_theme_constant_override(&"separation", 8)
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var tk := GoalPanel.Tick.new()
				tk.done = r["done"]
				row.add_child(tk)
				var l := Hud.make_label(str(r["text"]), 15, UiTheme.TEXT_DIM if r["done"] else UiTheme.TEXT)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size.x = 280
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(l)
				_v.add_child(row)
			if st == &"affordable":
				_line("Click to unlock.", 14, UiTheme.GOOD)
		elif d.gesture:
			_line("Click to select it, then hold E over the world.", 14, UiTheme.GOOD)
		visible = true
		reset_size()
	func _line(text: String, fs: int, col: Color) -> void:
		var l := Hud.make_label(text, fs, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 310
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_v.add_child(l)
