extends CanvasLayer
## Title menu shown as an overlay on the world (main scene stays world.tscn).
## The valley pans slowly behind: Continue (latest autosave), New Valley,
## Load (3 slots + autosave), Options, Credits (res://CREDITS.md), Quit.
## Esc during play reopens it as a pause menu with Resume and Save.

const OPTIONS_PATH := "user://options.cfg"
const INK := Color(0.96, 0.9, 0.78)
const PANEL := Color(0.08, 0.07, 0.06, 0.72)
const ACCENT := Color(1.0, 0.62, 0.25)

var world: Node = null
var paused_mode: bool = false     # opened with Esc during play
var _root: Control
var _main: VBoxContainer
var _sub: PanelContainer
var _sub_box: VBoxContainer
var _continue_btn: Button
var _yaw: float = 0.4

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = get_parent()
	load_options()
	_build()
	_refresh()

# ---------------------------------------------------------------- ui

func _style(c: Color, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	return sb

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 46)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_stylebox_override("normal", _style(Color(0.12, 0.1, 0.08, 0.6)))
	b.add_theme_stylebox_override("hover", _style(Color(0.2, 0.15, 0.1, 0.8)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.28, 0.18, 0.1, 0.9)))
	b.add_theme_stylebox_override("focus", _style(Color(0.2, 0.15, 0.1, 0.8)))
	b.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.1, 0.1, 0.35)))
	b.pressed.connect(cb)
	return b

func _label(text: String, size: int, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _style(PANEL, 16))
	left.position = Vector2(70, 110)
	_root.add_child(left)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	left.add_child(_main)
	_main.add_child(_label("Hands of God", 52))
	_main.add_child(_label("a valley that grows in your palm", 18, Color(0.85, 0.78, 0.66)))
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 14)
	_main.add_child(gap)
	_continue_btn = _button("Continue", _on_continue)
	_main.add_child(_continue_btn)
	_main.add_child(_button("New Valley", _on_new))
	_main.add_child(_button("Load", _show_load))
	_main.add_child(_button("Options", _show_options))
	_main.add_child(_button("Credits", _show_credits))
	_main.add_child(_button("Quit", _on_quit))
	_sub = PanelContainer.new()
	_sub.add_theme_stylebox_override("panel", _style(PANEL, 16))
	_sub.position = Vector2(400, 110)
	_sub.custom_minimum_size = Vector2(520, 0)
	_sub.visible = false
	_root.add_child(_sub)
	_sub_box = VBoxContainer.new()
	_sub_box.add_theme_constant_override("separation", 10)
	_sub.add_child(_sub_box)

func _refresh() -> void:
	var latest := Save.latest_autosave()
	if paused_mode:
		_continue_btn.text = "Resume"
		_continue_btn.disabled = false
	else:
		_continue_btn.text = "Continue"
		_continue_btn.disabled = latest == ""

func _clear_sub(title_text: String) -> void:
	for c in _sub_box.get_children():
		c.queue_free()
	_sub_box.add_child(_label(title_text, 30))
	_sub.visible = true

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

func _show_load() -> void:
	_clear_sub("Load")
	var rows: Array = []
	for i in Save.MANUAL_SLOTS:
		rows.append([Save.manual_slot(i + 1), "Slot %d" % (i + 1)])
	var latest := Save.latest_autosave()
	if latest != "":
		rows.append([latest, "Latest autosave"])
	for r in rows:
		var info := Save.slot_info(r[0])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var desc := "%s: empty" % r[1]
		if not info.is_empty():
			desc = "%s: day %d, era %d, %d people  (%s)" % [r[1], int(info.get("day", 1)), int(info.get("era", 1)), int(info.get("population", 0)), str(info.get("saved_at", "")).replace("T", " ")]
		var l := _label(desc, 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		if paused_mode and str(r[0]).begins_with("slot_"):
			var slot_name: String = r[0]
			var sb := _button("Save", func(): Save.write(slot_name); _show_load())
			sb.custom_minimum_size = Vector2(90, 40)
			h.add_child(sb)
		var lb := _button("Load", func(): _load(r[0]))
		lb.custom_minimum_size = Vector2(90, 40)
		lb.disabled = info.is_empty()
		h.add_child(lb)
		_sub_box.add_child(h)
	_sub_box.add_child(_button("Back", func(): _sub.visible = false))

func _load(slot: String) -> void:
	if Save.load_slot(slot):
		close()

func _show_options() -> void:
	_clear_sub("Options")
	_sub_box.add_child(_slider("Music volume", db_to_linear(Audio.music_db), func(v): Audio.music_db = linear_to_db(maxf(v, 0.001)); save_options()))
	_sub_box.add_child(_slider("Sound volume", db_to_linear(Audio.sfx_db), func(v): Audio.sfx_db = linear_to_db(maxf(v, 0.001)); save_options()))
	var ui := _slider("UI scale", (float(Game.options.get("ui_scale", 1.0)) - 0.8) / 0.7, func(v): Game.options["ui_scale"] = snappedf(0.8 + v * 0.7, 0.05); _apply_ui_scale(); save_options())
	_sub_box.add_child(ui)
	_sub_box.add_child(_check("Edge pan", bool(Game.options.get("edge_pan", true)), func(on): Game.options["edge_pan"] = on; save_options()))
	_sub_box.add_child(_check("Fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, func(on): _set_fullscreen(on); save_options()))
	_sub_box.add_child(_button("Back", func(): _sub.visible = false))

func _slider(text: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := _label(text, 18)
	l.custom_minimum_size = Vector2(180, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0; s.max_value = 1.0; s.step = 0.01
	s.value = clampf(value, 0.0, 1.0)
	s.custom_minimum_size = Vector2(280, 30)
	s.value_changed.connect(cb)
	h.add_child(s)
	return h

func _check(text: String, on: bool, cb: Callable) -> Control:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 18)
	c.add_theme_color_override("font_color", INK)
	c.toggled.connect(cb)
	return c

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
			out.append("\n[font_size=20][b]%s[/b][/font_size]" % t.substr(3))
		elif t.begins_with("# "):
			out.append("[font_size=26][b]%s[/b][/font_size]" % t.substr(2))
		elif t.begins_with("- "):
			out.append("  • " + t.substr(2))
		else:
			out.append(line)
	return "\n".join(out)

func _show_credits() -> void:
	_clear_sub("Credits")
	var text := "Hands of God\n\nCredits are being written. Art and music will be CC0 packs (Quaternius, Kenney and others), credited here."
	if FileAccess.file_exists("res://CREDITS.md"):
		text = FileAccess.get_file_as_string("res://CREDITS.md")
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = md_to_bbcode(text)
	rt.custom_minimum_size = Vector2(640, 420)
	rt.scroll_active = true
	rt.add_theme_color_override("default_color", INK)
	rt.add_theme_font_size_override("normal_font_size", 16)
	_sub_box.add_child(rt)
	_sub_box.add_child(_button("Back", func(): _sub.visible = false))

# ---------------------------------------------------------------- options

func load_options() -> void:
	var cf := ConfigFile.new()
	if cf.load(OPTIONS_PATH) != OK:
		return
	Audio.music_db = cf.get_value("audio", "music_db", Audio.music_db)
	Audio.sfx_db = cf.get_value("audio", "sfx_db", Audio.sfx_db)
	Game.options["ui_scale"] = cf.get_value("ui", "scale", 1.0)
	Game.options["edge_pan"] = cf.get_value("ui", "edge_pan", true)
	_apply_ui_scale()
	if cf.get_value("video", "fullscreen", false) and not Game.testing():
		_set_fullscreen(true)

func save_options() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music_db", Audio.music_db)
	cf.set_value("audio", "sfx_db", Audio.sfx_db)
	cf.set_value("ui", "scale", Game.options.get("ui_scale", 1.0))
	cf.set_value("ui", "edge_pan", Game.options.get("edge_pan", true))
	cf.set_value("video", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cf.save(OPTIONS_PATH)

func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = clampf(float(Game.options.get("ui_scale", 1.0)), 0.8, 1.5)

func _set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

# ---------------------------------------------------------------- show/hide

func open_paused() -> void:
	paused_mode = true
	visible = true
	_sub.visible = false
	Clock.running = false
	_refresh()

func close() -> void:
	visible = false
	_sub.visible = false
	if world and world.has_method("start_play"):
		world.start_play()
	else:
		Clock.running = true

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"menu"):
		if visible and paused_mode:
			close()
		elif not visible:
			open_paused()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible or paused_mode or world == null or not ("title_camera" in world) or world.title_camera == null:
		return
	# the valley slowly panning behind the menu
	_yaw += Clock.real_delta * 0.035
	var focus := Vector3(sin(_yaw * 0.7) * 25.0, 4.0, -8.0 + cos(_yaw * 0.5) * 12.0)
	world.frame_camera(world.title_camera, focus, 75.0, _yaw, 32.0)
