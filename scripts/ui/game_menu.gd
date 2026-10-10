extends CanvasLayer
## The title menu and the Esc pause menu (DESIGN 11.5), on parchment.
## Title: the valley pans slowly behind; Continue (latest autosave), New Valley,
## Load, Options, Credits, Quit. Pause: Resume, Save (3 slots, plus the
## autosaves to load from), Load, Options, Quit to title, Quit.
## Instanced by the world from scenes/world/title.tscn; the world calls
## open_paused() / close() through _unhandled_input here.

const MENU_W := 380.0

var world: Node = null
var paused_mode: bool = false
var _root: Control
var _shade: ColorRect
var _strip: PanelContainer
var _main: VBoxContainer
var _info: Label
var _sub: PanelContainer
var _sub_box: VBoxContainer
var _continue_btn: Button
var _title_box: VBoxContainer
var _yaw: float = 0.4
var _confirm: String = ""

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_menu")
	world = get_parent()
	Options.load_options()
	_build()
	_refresh()

# ---------------------------------------------------------------- building

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UiTheme.paper_theme()
	add_child(_root)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	# a soft vignette on the left so the strip reads over any scene
	var vig := Vignette.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(vig)
	_strip = PanelContainer.new()
	_strip.add_theme_stylebox_override(&"panel", UiTheme.paper_box(40.0, 1))
	_strip.position = Vector2(64, 70)
	_strip.custom_minimum_size = Vector2(MENU_W, 0)
	_root.add_child(_strip)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override(&"separation", 4)
	_strip.add_child(_main)
	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override(&"separation", -6)
	_main.add_child(_title_box)
	_main.add_child(InkWidgets.Rule.new())
	_continue_btn = _menu_button("Continue", _on_continue)
	_main.add_child(_continue_btn)
	_info = UiTheme.ink_label("", 15, &"italic", UiTheme.INK_SOFT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(_info)
	_sub = PanelContainer.new()
	_sub.add_theme_stylebox_override(&"panel", UiTheme.paper_box(44.0, 0))
	_sub.position = Vector2(64 + MENU_W + 36, 70)
	_sub.visible = false
	_root.add_child(_sub)
	_sub_box = VBoxContainer.new()
	_sub_box.add_theme_constant_override(&"separation", 10)
	_sub.add_child(_sub_box)
	_rebuild_buttons()

func _rebuild_buttons() -> void:
	for c in _title_box.get_children():
		_title_box.remove_child(c)
		c.queue_free()
	var t := UiTheme.ink_label("Hands of God", 62 if not paused_mode else 50, &"title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t)
	var tag := UiTheme.ink_label("a valley that grows in your palm" if not paused_mode else "The valley waits for you.", 19, &"italic", UiTheme.INK_SOFT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(tag)
	# everything after the continue button and info line is rebuilt
	var keep := [_title_box, _main.get_child(1), _continue_btn, _info]
	for c in _main.get_children():
		if not keep.has(c):
			_main.remove_child(c)
			c.queue_free()
	var rows: Array = []
	if paused_mode:
		rows = [["Save", _show_save], ["Load", _show_load], ["Options", _show_options], ["Quit to title", _on_quit_to_title], ["Quit", _on_quit]]
	else:
		rows = [["New Valley", _on_new], ["Load", _show_load], ["Options", _show_options], ["Credits", _show_credits], ["Quit", _on_quit]]
	for r in rows:
		_main.add_child(_menu_button(r[0], r[1]))

func _menu_button(text: String, cb: Callable) -> Button:
	var b := MenuWord.new()
	b.text = text
	b.custom_minimum_size = Vector2(MENU_W - 80, 50)
	b.pressed.connect(func():
		Audio.sfx("res://assets/audio/sfx/ui_click.ogg", Vector3.INF, 1.0, -6.0)
		cb.call())
	return b

func _refresh() -> void:
	var latest := Save.latest_autosave()
	if paused_mode:
		_continue_btn.text = "Resume"
		_continue_btn.disabled = false
		_info.text = "Day %d, %s" % [Clock.day, ["spring", "summer", "autumn", "winter"][clampi(Clock.season, 0, 3)]]
		_shade.color = Color(0.03, 0.02, 0.01, 0.45)
	else:
		_continue_btn.text = "Continue"
		_continue_btn.disabled = latest == ""
		var info := Save.slot_info(latest) if latest != "" else {}
		_info.text = "" if info.is_empty() else "Day %d, Era %d, %d people" % [int(info.get("day", 1)), int(info.get("era", 1)), int(info.get("population", 0))]
		_shade.color = Color(0, 0, 0, 0.0)
	_info.visible = _info.text != ""
	_rebuild_buttons()

func _clear_sub(title_text: String, min_w: float = 600.0) -> void:
	for c in _sub_box.get_children():
		_sub_box.remove_child(c)
		c.queue_free()
	_sub.custom_minimum_size = Vector2(min_w, 0)
	_sub.size = Vector2(min_w, 0)
	_sub_box.add_child(UiTheme.ink_label(title_text, 40, &"title"))
	_sub_box.add_child(InkWidgets.Rule.new())
	_sub.visible = true
	_confirm = ""

func _back_row() -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	_sub_box.add_child(gap)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	_sub_box.add_child(h)
	var b := Button.new()
	b.text = "Back"
	b.custom_minimum_size = Vector2(120, 42)
	b.pressed.connect(func(): _sub.visible = false)
	h.add_child(b)

# ---------------------------------------------------------------- actions

func _on_continue() -> void:
	if paused_mode:
		close()
		return
	var latest := Save.latest_autosave()
	if latest != "":
		Save.load_slot(latest)
	close()

func _on_new() -> void:
	if world and world.has_method("new_game"):
		world.new_game()
	close()

func _on_quit() -> void:
	if paused_mode and Save.enabled:
		Save.autosave()
	get_tree().quit()

func _on_quit_to_title() -> void:
	if Save.enabled:
		Save.autosave()
	paused_mode = false
	_sub.visible = false
	if world and world.has_method("show_title"):
		world.show_title()
	visible = true
	_refresh()

func _slot_desc(slot: String, label: String) -> String:
	var info := Save.slot_info(slot)
	if info.is_empty():
		return "%s: empty" % label
	var when := str(info.get("saved_at", "")).replace("T", " ")
	if when.length() > 16:
		when = when.substr(0, 16)
	return "%s: day %d, era %d, %d people\n%s" % [label, int(info.get("day", 1)), int(info.get("era", 1)), int(info.get("population", 0)), when]

func _slot_row(slot: String, label: String, can_save: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	var info := Save.slot_info(slot)
	var l := UiTheme.ink_label(_slot_desc(slot, label), 18, &"body", UiTheme.INK if not info.is_empty() else UiTheme.INK_FADED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if can_save:
		var sb := Button.new()
		sb.text = "Save" if info.is_empty() else "Overwrite"
		sb.custom_minimum_size = Vector2(120, 42)
		sb.pressed.connect(func():
			if not info.is_empty() and _confirm != slot:
				_confirm = slot
				sb.text = "Sure?"
				return
			Save.write(slot)
			_show_save(label + " saved."))
		h.add_child(sb)
	var lb := Button.new()
	lb.text = "Load"
	lb.custom_minimum_size = Vector2(96, 42)
	lb.disabled = info.is_empty()
	lb.pressed.connect(func(): _load(slot))
	h.add_child(lb)
	return h

func _autosave_rows(can_save: bool) -> void:
	var autos: Array = []
	for i in Save.AUTOSAVES:
		var slot := "autosave_%d" % i
		if Save.exists(slot):
			autos.append([slot, float(Save.read(slot).get("saved_unix", 0.0))])
	autos.sort_custom(func(a, b): return a[1] > b[1])
	_sub_box.add_child(UiTheme.ink_label("Autosaves, each dawn", 22, &"title", UiTheme.INK_RED))
	if autos.is_empty():
		_sub_box.add_child(UiTheme.ink_label("None yet. The game saves itself at every dawn.", 17, &"italic", UiTheme.INK_SOFT))
	for i in autos.size():
		_sub_box.add_child(_slot_row(autos[i][0], "Latest" if i == 0 else "Earlier", false))

func _show_save(note: String = "") -> void:
	_clear_sub("Save", 640)
	for i in Save.MANUAL_SLOTS:
		_sub_box.add_child(_slot_row(Save.manual_slot(i + 1), "Slot %d" % (i + 1), true))
	_autosave_rows(false)
	if note != "":
		_sub_box.add_child(UiTheme.ink_label(note, 17, &"italic", UiTheme.LEAF.darkened(0.2)))
	_back_row()

func _show_load() -> void:
	_clear_sub("Load", 640)
	for i in Save.MANUAL_SLOTS:
		_sub_box.add_child(_slot_row(Save.manual_slot(i + 1), "Slot %d" % (i + 1), false))
	_autosave_rows(false)
	_back_row()

func _load(slot: String) -> void:
	if Save.load_slot(slot):
		close()

# ---------------------------------------------------------------- options

const DIFF_TEXT := [
	"Gentle: threats warn early, no one dies (injuries instead), help comes at 3 people.",
	"Normal: the valley as it was made.",
	"Harsh: shorter warnings, longer winters. Still winnable.",
]

func _show_options() -> void:
	_clear_sub("Options", 920)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 40)
	_sub_box.add_child(cols)
	var a := VBoxContainer.new()
	a.add_theme_constant_override(&"separation", 6)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(a)
	var b := VBoxContainer.new()
	b.add_theme_constant_override(&"separation", 6)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(b)
	_opt_head(a, "Sound")
	for pair in [["Master", "master"], ["Music", "music"], ["Effects", "sfx"], ["Voices", "voices"]]:
		a.add_child(_slider(pair[0], pair[1], 0.0, 1.0, func(v): return "%d%%" % int(round(v * 100.0))))
	_opt_head(a, "Display")
	a.add_child(_slider("UI scale", "ui_scale", 0.8, 1.5, func(v): return "%d%%" % int(round(v * 100.0)), 0.05))
	a.add_child(_check("Fullscreen", "fullscreen"))
	a.add_child(_check("Vertical sync", "vsync"))
	var qh := HBoxContainer.new()
	var ql := UiTheme.ink_label("Quality", 18)
	ql.custom_minimum_size.x = 120
	qh.add_child(ql)
	qh.add_child(InkWidgets.segmented(["Low", "Medium", "High"], Options.QUALITIES.find(str(Options.get_opt("quality"))), func(i): _set_opt("quality", Options.QUALITIES[i]), 92.0))
	a.add_child(qh)
	_opt_head(b, "Camera")
	b.add_child(_check("Edge pan (move the mouse to the screen edge)", "edge_pan"))
	b.add_child(_check("Invert rotate (Q and R)", "invert_rotate"))
	b.add_child(_slider("Camera speed", "camera_speed", 0.5, 2.0, func(v): return "%.1fx" % v, 0.1))
	_opt_head(b, "Game")
	var dl := UiTheme.wrap(UiTheme.ink_label(DIFF_TEXT[Options.DIFFICULTIES.find(str(Options.get_opt("difficulty")))], 16, &"italic", UiTheme.INK_SOFT))
	b.add_child(InkWidgets.segmented(["Gentle", "Normal", "Harsh"], Options.DIFFICULTIES.find(str(Options.get_opt("difficulty"))), func(i):
		_set_opt("difficulty", Options.DIFFICULTIES[i])
		dl.text = DIFF_TEXT[i]))
	b.add_child(dl)
	b.add_child(_check("Subtitles", "subtitles"))
	b.add_child(_check("Screen shake", "screen_shake"))
	_back_row()

func _opt_head(box: VBoxContainer, t: String) -> void:
	box.add_child(UiTheme.ink_label(t, 24, &"title", UiTheme.INK_RED))

func _set_opt(key: String, v) -> void:
	Options.set_opt(key, v)
	Options.save_options()

func _slider(text: String, key: String, lo: float, hi: float, fmt: Callable, step: float = 0.01) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	var l := UiTheme.ink_label(text, 18)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = step
	s.value = clampf(float(Options.get_opt(key)), lo, hi)
	s.custom_minimum_size = Vector2(190, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var vl := UiTheme.ink_label(fmt.call(s.value), 16, &"semibold", UiTheme.INK_SOFT)
	vl.custom_minimum_size.x = 50
	h.add_child(vl)
	s.value_changed.connect(func(v):
		vl.text = fmt.call(v)
		_set_opt(key, v))
	return h

func _check(text: String, key: String) -> Control:
	var c := InkWidgets.Check.new(text, bool(Options.get_opt(key)))
	c.add_theme_font_size_override(&"font_size", 18)
	c.toggled.connect(func(on): _set_opt(key, on))
	return c

# ---------------------------------------------------------------- credits

## A small Markdown to BBCode pass for CREDITS.md: headings, bold, code, lists and
## tables (rows become "a · b · c" lines); HTML comments are dropped.
static func md_to_bbcode(md: String) -> String:
	var out := PackedStringArray()
	var in_comment := false
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var code := RegEx.create_from_string("`([^`]+)`")
	var ital := RegEx.create_from_string("(?<![\\w*])_(.+?)_(?![\\w*])")
	for raw in md.split("\n"):
		var line: String = raw
		if in_comment:
			if line.contains("-->"):
				in_comment = false
			continue
		if line.strip_edges().begins_with("<!--"):
			in_comment = not line.contains("-->")
			continue
		line = line.replace("[", "[lb]")
		line = bold.sub(line, "[b]$1[/b]", true)
		line = code.sub(line, "[code]$1[/code]", true)
		line = ital.sub(line, "[i]$1[/i]", true)
		var t := line.strip_edges()
		if t.begins_with("|"):
			if t.replace("|", "").replace("-", "").replace(" ", "") == "":
				continue
			var cells := PackedStringArray()
			for c in t.trim_prefix("|").trim_suffix("|").split("|"):
				cells.append(c.strip_edges())
			out.append("  " + " · ".join(cells))
		elif t.begins_with("### "):
			out.append("[b]%s[/b]" % t.substr(4))
		elif t.begins_with("## "):
			out.append("\n[font_size=22][b]%s[/b][/font_size]" % t.substr(3))
		elif t.begins_with("# "):
			out.append("[font_size=28][b]%s[/b][/font_size]" % t.substr(2))
		elif t.begins_with("- "):
			out.append("  • " + t.substr(2))
		else:
			out.append(line)
	return "\n".join(out)

func _show_credits() -> void:
	_clear_sub("Credits", 760)
	var text := "Hands of God"
	if FileAccess.file_exists("res://CREDITS.md"):
		text = FileAccess.get_file_as_string("res://CREDITS.md")
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = md_to_bbcode(text)
	rt.custom_minimum_size = Vector2(680, 460)
	rt.scroll_active = true
	_sub_box.add_child(rt)
	_back_row()

# ---------------------------------------------------------------- show / hide

func open_paused() -> void:
	paused_mode = true
	visible = true
	_sub.visible = false
	Clock.running = false
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and "visible" in hud:
		hud.visible = false      # start_play() shows it again
	_refresh()

func close() -> void:
	visible = false
	_sub.visible = false
	if world and world.has_method("start_play"):
		world.start_play()
	else:
		Clock.running = true
	Options.apply()

func _hud_modal_close() -> bool:
	var hud := get_tree().get_first_node_in_group(&"hud")
	return hud != null and hud.has_method(&"close_top_modal") and bool(hud.call(&"close_top_modal"))

func _unhandled_input(e: InputEvent) -> void:
	if not e.is_action_pressed(&"menu"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		if _hud_modal_close():
			return
		open_paused()
	elif _sub.visible:
		_sub.visible = false
	elif paused_mode:
		close()

func _process(_delta: float) -> void:
	if visible:
		_hide_hand_tip()
	if not visible or paused_mode or world == null or not ("title_camera" in world) or world.title_camera == null:
		return
	# the valley slowly panning behind the menu
	_yaw += Clock.real_delta * 0.035
	var focus := Vector3(sin(_yaw * 0.7) * 25.0, 4.0, -8.0 + cos(_yaw * 0.5) * 12.0)
	world.frame_camera(world.title_camera, focus, 75.0, _yaw, 32.0)

func _hide_hand_tip() -> void:
	var hand := get_tree().get_first_node_in_group(&"hand")
	var hv := hand.get_node_or_null("Visual") if hand != null else null
	if hv != null and hv.get(&"tip_panel") is Control:
		(hv.get(&"tip_panel") as Control).visible = false

## A menu word: large ink text; on hover an ochre hand points at it.
class MenuWord extends Button:
	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		var e := StyleBoxEmpty.new()
		for k in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(k, e)
		add_theme_font_override(&"font", UiTheme.font(&"title"))
		add_theme_font_size_override(&"font_size", 30)
		add_theme_color_override(&"font_color", UiTheme.INK)
		add_theme_color_override(&"font_hover_color", UiTheme.INK_RED)
		add_theme_color_override(&"font_pressed_color", UiTheme.OCHRE)
		add_theme_color_override(&"font_disabled_color", Color(UiTheme.INK_SOFT, 0.35))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		if not is_hovered() or disabled:
			return
		var f := get_theme_font(&"font")
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var x0 := (size.x - w) * 0.5
		PortraitFrame.draw_hand_mark(self, Vector2(x0 - 24, size.y * 0.55), 13.0, UiTheme.OCHRE)
		var line := InkBox.new()
		line.underline_only = true
		line.ink = Color(UiTheme.OCHRE, 0.8)
		line.width = 1.8
		line.draw(get_canvas_item(), Rect2(Vector2(x0, size.y - 12), Vector2(w, 4)))

class Vignette extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := 720.0
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)])
		var c0 := Color(0.05, 0.03, 0.02, 0.5)
		var c1 := Color(0.05, 0.03, 0.02, 0.0)
		draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))
