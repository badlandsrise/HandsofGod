extends CanvasLayer
## [capture] The controls card, shown only while F1 is held in capture mode
## (so it never lands in a recording by accident). Lists the keys and the
## presets of the current era (or of the spoiler), and what is running now.

var director: Node = null
var _panel: PanelContainer
var _label: Label

func _init() -> void:
	name = "CaptureOverlay"
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.04, 0.88)
	sb.border_color = Color(1.0, 0.8, 0.5, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 14; sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override(&"panel", sb)
	_panel.position = Vector2(24, 24)
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.86))
	_label.add_theme_font_size_override(&"font_size", 16)
	_panel.add_child(_label)

## Shown while F1 is held; the text is rebuilt each time it opens.
func set_held(on: bool) -> void:
	if on and not visible:
		_label.text = text()
	visible = on

func text() -> String:
	var d := director
	var lines: Array[String] = ["CAPTURE MODE (developer only)  -  docs/CAPTURE.md", ""]
	if d != null:
		lines.append("Now: %s  |  camera %s %s  |  %s%s%s" % [
			("SPOILER goodbye, beat %s" % d.spoiler_beat()) if d.spoiler != "" else "Era %d" % d.era,
			d.cam.mode, d.cam.current, "paused" if d.paused else "running",
			"  |  demo %s %.1f/%.0f s" % [d.demo_id, d.demo.t, d.demo.length] if d.demo != null else "",
			"  |  UI hidden%s" % (" (hand visible)" if d.clean.hand_visible else "") if d.clean.on else ""])
		lines.append("")
		var tab: Dictionary = d.cam.spoiler_presets() if d.spoiler != "" else d.cam.presets()
		var all: Array = []
		for n in tab:
			all.append([int(tab[n].get("key", 0)), n, str(tab[n].get("label", ""))])
		if d.spoiler == "":
			for n in d.cam.moves():
				all.append([int(d.cam.moves()[n].get("key", 0)), n, str(d.cam.moves()[n].get("label", ""))])
		all.sort_custom(func(a, b): return a[0] < b[0])
		for r in all:
			lines.append("  %d   %-14s %s" % [r[0], r[1], r[2]])
		lines.append("  0   free camera (the game's rig: WASD, Q, wheel, middle-drag)")
	lines.append_array(["",
		"  H   hide / show all UI, cursor and the ghost hand      G   keep the hand in shot while hidden",
		"  P   pause / resume (Space too)                           R   reset to the start state",
		"  [ ]  time of day back / forward                           N   next season",
		"  K   worker-placement demo     V   village-life demo     Shift+1/2/3   same shot in Era 1/2/3",
		"  F1  hold for this card                                   Esc   the game menu (quit)"])
	return "\n".join(lines)
