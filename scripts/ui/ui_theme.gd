class_name UiTheme extends RefCounted
## The game's warm, readable UI theme, built in code (default Godot font, no
## external assets): dark warm-brown glass panels, cream text, amber accents.

const BG := Color(0.16, 0.11, 0.08, 0.84)
const BG_SOFT := Color(0.22, 0.16, 0.11, 0.78)
const BORDER := Color(1.0, 0.8, 0.5, 0.35)
const TEXT := Color(0.99, 0.94, 0.84)
const TEXT_DIM := Color(0.86, 0.78, 0.66)
const ACCENT := Color(1.0, 0.74, 0.32)
const GOOD := Color(0.62, 0.86, 0.5)
const WARN := Color(1.0, 0.55, 0.4)
const NIGHT := Color(0.42, 0.52, 0.85)

static var _cached: Theme = null

static func get_theme() -> Theme:
	if _cached == null:
		_cached = make()
	return _cached

static func box(bg: Color, border: Color = BORDER, radius: int = 10, pad: float = 10.0, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	sb.anti_aliasing = true
	return sb

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_stylebox(&"panel", &"PanelContainer", box(BG))
	t.set_stylebox(&"panel", &"Panel", box(BG))
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0.35))
	t.set_constant(&"shadow_offset_x", &"Label", 1)
	t.set_constant(&"shadow_offset_y", &"Label", 1)
	# buttons
	t.set_stylebox(&"normal", &"Button", box(BG_SOFT, BORDER, 8, 10.0))
	t.set_stylebox(&"hover", &"Button", box(Color(0.33, 0.23, 0.14, 0.9), Color(1.0, 0.82, 0.5, 0.7), 8, 10.0))
	t.set_stylebox(&"pressed", &"Button", box(Color(0.55, 0.36, 0.16, 0.95), ACCENT, 8, 10.0, 2))
	t.set_stylebox(&"disabled", &"Button", box(Color(0.14, 0.11, 0.09, 0.6), Color(1, 1, 1, 0.08), 8, 10.0))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_hover_color", &"Button", Color(1, 1, 1))
	t.set_color(&"font_pressed_color", &"Button", Color(1, 0.97, 0.88))
	t.set_color(&"font_disabled_color", &"Button", Color(0.6, 0.55, 0.5))
	# tooltips
	t.set_stylebox(&"panel", &"TooltipPanel", box(Color(0.13, 0.09, 0.06, 0.95), ACCENT, 8, 10.0))
	t.set_color(&"font_color", &"TooltipLabel", TEXT)
	t.set_font_size(&"font_size", &"TooltipLabel", 16)
	# tabs (Village Book)
	t.set_stylebox(&"panel", &"TabContainer", box(Color(0.95, 0.88, 0.74, 0.97), Color(0.55, 0.38, 0.2, 0.8), 10, 14.0, 2))
	t.set_stylebox(&"tab_selected", &"TabContainer", box(Color(0.95, 0.88, 0.74, 1.0), Color(0.55, 0.38, 0.2, 0.8), 8, 12.0))
	t.set_stylebox(&"tab_unselected", &"TabContainer", box(Color(0.5, 0.36, 0.22, 0.9), Color(0.3, 0.2, 0.1, 0.6), 8, 12.0))
	t.set_stylebox(&"tab_hovered", &"TabContainer", box(Color(0.62, 0.46, 0.28, 0.95), Color(0.3, 0.2, 0.1, 0.6), 8, 12.0))
	t.set_color(&"font_selected_color", &"TabContainer", Color(0.25, 0.15, 0.07))
	t.set_color(&"font_unselected_color", &"TabContainer", Color(0.96, 0.9, 0.8))
	t.set_color(&"font_hovered_color", &"TabContainer", Color(1, 1, 1))
	# scroll bars
	t.set_stylebox(&"scroll", &"VScrollBar", box(Color(0, 0, 0, 0.1), Color(0, 0, 0, 0), 4, 2.0, 0))
	t.set_stylebox(&"grabber", &"VScrollBar", box(Color(0.55, 0.38, 0.2, 0.7), Color(0, 0, 0, 0), 4, 2.0, 0))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", box(Color(0.65, 0.45, 0.25, 0.9), Color(0, 0, 0, 0), 4, 2.0, 0))
	return t
