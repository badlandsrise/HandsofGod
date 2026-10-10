class_name EraCard extends Control
## The "Era complete" card, shown on Events.era_complete_shown(era) while the
## era_complete stinger plays: the age's title, time played, people now / born /
## lost, the dreams achieved, the gifts and a memory line, with "Continue to
## Era N+1" and "Keep playing". The game pauses softly underneath.
## If nothing emits era_complete_shown within FALLBACK_S of the gate dream
## coming true, the card emits it itself, so the era always gets its moment.

const FALLBACK_S := 8.0

var era: int = 0
var _open := false
var _prev_speed: int = 1
var _card: PanelContainer
var _shade: ColorRect
var _fallback_t: float = -1.0
var _fallback_era: int = 0
var data: Dictionary = {}       # what the card shows (tests read it)

func _ready() -> void:
	name = "EraCard"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.paper_theme()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.era_complete_shown.connect(show_era)
	Events.dream_done.connect(_on_dream_done)

func is_open() -> bool:
	return _open

func _shown(e: int) -> bool:
	for x in BookData.journal()["eras_shown"]:
		if int(x) == e:
			return true
	return false

func _on_dream_done(id: StringName) -> void:
	var d: DreamDef = Defs.dream(id)
	if d != null and d.gate and not _shown(d.era):
		_fallback_t = FALLBACK_S
		_fallback_era = d.era

func _process(_d: float) -> void:
	if _fallback_t > 0.0:
		_fallback_t -= Clock.real_delta
		if _fallback_t <= 0.0 and not _shown(_fallback_era) and not _open:
			Events.era_complete_shown.emit(_fallback_era)

## Everything the card says, from the journal and Village stats.
static func summary(e: int) -> Dictionary:
	var j := BookData.journal()
	var mark: Dictionary = j["era_marks"].get(str(e), {"t": 0.0, "births": 0, "deaths": 0, "day": 1})
	var ed: EraDef = Defs.era(e)
	var dreams: Array = []
	if ed != null:
		for id in ed.dreams:
			if Dreams.is_done(id):
				var dd: DreamDef = Defs.dream(id)
				dreams.append(dd.text if dd != null and dd.text != "" else String(id).capitalize())
	var gifts: Array = (j["gifts"] as Array).filter(func(g): return int(g.get("era", 1)) == e)
	var memory := ""
	var entries: Array = (j["entries"] as Array).filter(func(x): return int(x.get("era", 1)) == e and str(x.get("kind", "")) == "first")
	if not entries.is_empty():
		memory = str(entries[mini(1, entries.size() - 1)]["text"]) if entries.size() > 1 else str(entries[0]["text"])
		for x in entries:
			if str(x["text"]).contains("first fire"):
				memory = str(x["text"])
	var minutes := int(round(maxf(Clock.total_t - float(mark.get("t", 0.0)), 0.0) / 60.0))
	return {
		"era": e,
		"title": ed.title if ed != null else "Era %d" % e,
		"next_title": Defs.era(e + 1).title if Defs.era(e + 1) != null else "",
		"minutes": minutes,
		"days": maxi(Clock.day - int(mark.get("day", 1)) + 1, 1),
		"people": Village.population(),
		"born": maxi(int(Village.stats.get("births", 0)) - int(mark.get("births", 0)), 0),
		"lost": maxi(int(Village.stats.get("deaths", 0)) - int(mark.get("deaths", 0)), 0),
		"dreams": dreams,
		"gifts": gifts.map(func(g): return str(g.get("kind", "gift"))),
		"memory": memory,
	}

func show_era(e: int) -> void:
	if _open or e <= 0:
		return
	if not _shown(e):
		BookData.journal()["eras_shown"].append(e)
	era = e
	_fallback_t = -1.0
	data = summary(e)
	_open = true
	_prev_speed = Clock.speed_index
	if not Game.testing():
		Clock.set_speed(0)
	if Audio.stinger_log.is_empty() or Audio.stinger_log[-1] != &"era_complete":
		Audio.stinger(&"era_complete")
	_build()
	visible = true
	if Game.testing():
		get_tree().create_timer(2.0, true, false, true).timeout.connect(keep_playing)

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.04, 0.02, 0.01, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override(&"panel", UiTheme.paper_box(56.0, 1))
	_card.custom_minimum_size = Vector2(760, 0)
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	_card.add_child(v)
	var d := data
	var e := int(d["era"])
	var crest := Crest.new()
	var cc := CenterContainer.new()
	cc.add_child(crest)
	v.add_child(cc)
	var sm := UiTheme.ink_label("The %s Age is complete" % BookData.ERA_ORDINAL.get(e, str(e)), 20, &"title_italic", UiTheme.INK_RED)
	sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sm)
	var t := UiTheme.ink_label("Era %d: %s" % [e, d["title"]], 54, &"title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var tline := "%s %s in the valley" % [BookData.cap(BookData.cardinal(int(d["days"]))), "day" if d["days"] == 1 else "days"]
	if int(d["minutes"]) > 0:
		tline += "  ·  %d %s played" % [d["minutes"], "minute" if d["minutes"] == 1 else "minutes"]
	var tp := UiTheme.ink_label(tline, 18, &"italic", UiTheme.INK_SOFT)
	tp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tp)
	v.add_child(InkWidgets.Rule.new(420))
	# the three numbers
	var nums := HBoxContainer.new()
	nums.alignment = BoxContainer.ALIGNMENT_CENTER
	nums.add_theme_constant_override(&"separation", 70)
	v.add_child(nums)
	for pair in [[d["people"], "people now"], [d["born"], "born"], [d["lost"], "lost"]]:
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override(&"separation", -8)
		var n := UiTheme.ink_label(str(pair[0]), 48, &"title", UiTheme.INK if pair[1] != "lost" or int(pair[0]) == 0 else UiTheme.INK_SOFT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nv.add_child(n)
		var l := UiTheme.ink_label(pair[1], 16, &"semibold", UiTheme.INK_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nv.add_child(l)
		nums.add_child(nv)
	# dreams
	if not (d["dreams"] as Array).is_empty():
		var dh := UiTheme.ink_label("Dreams that came true", 22, &"title", UiTheme.INK_RED)
		dh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dh)
		for txt in d["dreams"]:
			var dl := UiTheme.wrap(UiTheme.ink_label("\"%s\"" % txt, 18, &"italic"))
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(dl)
	# gifts
	var gifts: Array = d["gifts"]
	if not gifts.is_empty():
		var gh := HBoxContainer.new()
		gh.alignment = BoxContainer.ALIGNMENT_CENTER
		gh.add_theme_constant_override(&"separation", 6)
		v.add_child(gh)
		var shown := {}
		for g in gifts:
			if shown.size() >= 8 or shown.has(g):
				continue
			shown[g] = true
			gh.add_child(InkWidgets.GiftIcon.new(g, 40.0))
		var gl := UiTheme.ink_label("%s %s left for the hand" % [BookData.cap(BookData.cardinal(gifts.size())), "gift" if gifts.size() == 1 else "gifts"], 16, &"italic", UiTheme.INK_SOFT)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(gl)
	if str(d["memory"]) != "":
		v.add_child(InkWidgets.Rule.new(260))
		var ml := UiTheme.wrap(UiTheme.ink_label(str(d["memory"]), 21, &"hand", UiTheme.INK))
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ml)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	v.add_child(gap)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override(&"separation", 20)
	v.add_child(bh)
	var keep := Button.new()
	keep.text = "Keep playing"
	keep.custom_minimum_size = Vector2(200, 50)
	keep.pressed.connect(keep_playing)
	bh.add_child(keep)
	if str(d["next_title"]) != "":
		var go := Button.new()
		go.text = "Continue to Era %d" % (e + 1)
		go.custom_minimum_size = Vector2(260, 50)
		go.add_theme_font_size_override(&"font_size", 21)
		var sb := InkBox.make(Color(UiTheme.OCHRE, 0.28), UiTheme.INK, 14.0, 8.0, 2.2)
		sb.double_line = true
		go.add_theme_stylebox_override(&"normal", sb)
		go.pressed.connect(continue_era)
		bh.add_child(go)
	_card.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(_shade, "color:a", 0.55, 0.8)
	tw.tween_property(_card, "modulate:a", 1.0, 0.9).set_delay(0.3)

func keep_playing() -> void:
	_close()

func continue_era() -> void:
	var e := era
	_close()
	EraCard.advance_era(e)

## Moves the village on to the next era. Prefers the world's own transition
## (begin_era / advance_era) and falls back to the bare state change.
static func advance_era(from_era: int) -> void:
	var next := from_era + 1
	if Defs.era(next) == null:
		return
	var w := Game.world
	if w != null and is_instance_valid(w):
		if w.has_method(&"begin_era"):
			w.call(&"begin_era", next)
			return
		if w.has_method(&"advance_era"):
			w.call(&"advance_era")
			return
	Village.era = next
	Clock.apply_era(Defs.era(next))
	Events.era_changed.emit(next)

func _close() -> void:
	if not _open:
		return
	_open = false
	if not Game.testing():
		Clock.set_speed(_prev_speed if _prev_speed > 0 else 1)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	if is_instance_valid(_card):
		tw.tween_property(_card, "modulate:a", 0.0, 0.3)
	if is_instance_valid(_shade):
		tw.tween_property(_shade, "color:a", 0.0, 0.4)
	tw.chain().tween_callback(func():
		if not _open:
			visible = false)

func _unhandled_input(e: InputEvent) -> void:
	if _open and e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		keep_playing()
		get_viewport().set_input_as_handled()

## A drawn crest: an open hand inside a laurel ring.
class Crest extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(110, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.52)
		var leaf := Color(UiTheme.LEAF, 0.85)
		for side in [-1.0, 1.0]:
			for i in 7:
				var a: float = PI * 0.5 + side * (0.35 + i * 0.32)
				var p := c + Vector2(cos(a), sin(a)) * 40.0
				var dir := Vector2(cos(a + side * PI * 0.5), sin(a + side * PI * 0.5))
				var pts := PackedVector2Array([p, p + dir * 9.0 + (p - c).normalized() * 4.0, p + dir * 14.0, p + dir * 9.0 - (p - c).normalized() * 4.0])
				draw_colored_polygon(pts, leaf)
		draw_circle(c, 28.0, Color(UiTheme.OCHRE, 0.16))
		draw_arc(c, 28.0, 0, TAU, 40, Color(UiTheme.OCHRE, 0.8), 2.0, true)
		PortraitFrame.draw_hand_mark(self, c + Vector2(0, 5), 22.0, UiTheme.OCHRE.darkened(0.1))
