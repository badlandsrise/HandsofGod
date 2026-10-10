class_name UiTheme extends RefCounted
## The game's UI look. Two themes, both built in code:
##  - get_theme(): the in-play HUD (warm dark glass panels, cream text, amber accents).
##  - paper_theme(): parchment pages for the Village Book, naming card, era card and
##    menus (ink text, hand-drawn InkBox frames, a bookish serif, a handwriting face).
## Fonts (assets/fonts, SIL OFL): Alegreya (body), IM Fell English (titles), Caveat (handwriting).

const BG := Color(0.16, 0.11, 0.08, 0.84)
const BG_SOFT := Color(0.22, 0.16, 0.11, 0.78)
const BORDER := Color(1.0, 0.8, 0.5, 0.35)
const TEXT := Color(0.99, 0.94, 0.84)
const TEXT_DIM := Color(0.86, 0.78, 0.66)
const ACCENT := Color(1.0, 0.74, 0.32)
const GOOD := Color(0.62, 0.86, 0.5)
const WARN := Color(1.0, 0.55, 0.4)
const NIGHT := Color(0.42, 0.52, 0.85)

# parchment and ink
const PAPER := Color("#f1e4c6")
const PAPER_DARK := Color("#dcc59b")
const PAPER_SHADE := Color(0.55, 0.38, 0.18, 0.16)
const INK := Color("#3b2614")
const INK_SOFT := Color("#6a4a2c")
const INK_FADED := Color(0.42, 0.31, 0.2, 0.62)
const INK_RED := Color("#8e2f1c")
const OCHRE := Color("#b8661f")
const GOLD := Color("#c8902e")
const LEAF := Color("#51692f")
const LEATHER := Color("#5b3a22")
const LEATHER_DARK := Color("#331e10")

const FONT_FILES := {
	&"body": "res://assets/fonts/Alegreya.ttf",
	&"italic": "res://assets/fonts/Alegreya-Italic.ttf",
	&"title": "res://assets/fonts/IMFellEnglish-Regular.ttf",
	&"title_italic": "res://assets/fonts/IMFellEnglish-Italic.ttf",
	&"hand": "res://assets/fonts/Caveat.ttf",
}

static var _cached: Theme = null
static var _paper_theme: Theme = null
static var _fonts: Dictionary = {}
static var _textures: Dictionary = {}

# ---------------------------------------------------------------- fonts

## &"body", &"bold", &"italic", &"title", &"title_italic", &"hand", &"hand_bold".
static func font(kind: StringName) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font = null
	match kind:
		&"bold":
			f = _weighted(&"body", 700)
		&"semibold":
			f = _weighted(&"body", 560)
		&"hand_bold":
			f = _weighted(&"hand", 700)
		&"hand":
			f = _weighted(&"hand", 520)
		_:
			var path: String = FONT_FILES.get(kind, FONT_FILES[&"body"])
			if ResourceLoader.exists(path):
				f = load(path)
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f

static func _weighted(base: StringName, wght: int) -> Font:
	var path: String = FONT_FILES[base]
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = load(path)
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
	return fv

# ---------------------------------------------------------------- boxes

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

static func ink_box(fill: Color, ink: Color = INK_SOFT, pad: float = 10.0, radius: float = 7.0, width: float = 1.6) -> InkBox:
	return InkBox.make(fill, ink, pad, radius, width)

## A parchment page with deckled edges (StyleBoxTexture over a generated texture).
static func paper_box(pad: float = 28.0, variant: int = 0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = paper_texture(variant)
	sb.set_texture_margin_all(46.0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.85
	sb.content_margin_bottom = pad * 0.85
	return sb

## Procedural parchment: warm base, soft blotches, fine grain, fibres, darker
## foxed edges and a torn (deckled) border. variant 0 = page, 1 = card, 2 = leather.
static func paper_texture(variant: int = 0) -> Texture2D:
	if _textures.has(variant):
		return _textures[variant]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var blotch := FastNoiseLite.new()
	blotch.seed = 11 + variant * 31
	blotch.frequency = 0.012
	blotch.fractal_octaves = 3
	var grain := FastNoiseLite.new()
	grain.seed = 5 + variant
	grain.frequency = 0.35
	grain.fractal_octaves = 1
	var edge := FastNoiseLite.new()
	edge.seed = 77 + variant
	edge.frequency = 0.09
	var base := PAPER if variant != 2 else LEATHER
	var dark := Color("#c9a874") if variant != 2 else LEATHER_DARK
	var deckle := variant != 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + variant
	for y in n:
		for x in n:
			var b := blotch.get_noise_2d(x, y) * 0.5 + 0.5
			var g := grain.get_noise_2d(x, y)
			var c := base.lerp(dark, clampf(b * 0.55 - 0.08, 0.0, 1.0))
			c = c.darkened(g * 0.035 + 0.01) if variant != 2 else c.darkened(g * 0.09)
			var d := float(mini(mini(x, y), mini(n - 1 - x, n - 1 - y)))
			var e := edge.get_noise_2d(x * 1.0, y * 1.0) * 0.5 + 0.5
			var fox := 1.0 - clampf((d - 2.0) / (30.0 + e * 16.0), 0.0, 1.0)
			c = c.lerp(dark.darkened(0.25), fox * (0.55 if variant != 2 else 0.4))
			var a := 1.0
			if deckle:
				var lim := 2.0 + e * 7.0
				a = clampf((d - lim) / 1.6, 0.0, 1.0)
			c.a = a
			img.set_pixel(x, y, c)
	# fibres
	if variant != 2:
		for i in 90:
			var p := Vector2(rng.randf_range(16, n - 16), rng.randf_range(16, n - 16))
			var ang := rng.randf() * TAU
			var l := rng.randf_range(4.0, 14.0)
			for k in int(l):
				var q := p + Vector2(cos(ang), sin(ang)) * k
				var px := img.get_pixelv(Vector2i(q))
				img.set_pixelv(Vector2i(q), px.darkened(0.06))
	var tex := ImageTexture.create_from_image(img)
	_textures[variant] = tex
	return tex

## A small soft dot texture (slider grabbers etc.).
static func dot_texture(r: int, c: Color, ring: Color = Color(0, 0, 0, 0)) -> Texture2D:
	var key := "dot%d%s%s" % [r, c.to_html(), ring.to_html()]
	if _textures.has(key):
		return _textures[key]
	var s := r * 2 + 2
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var ctr := Vector2(s, s) * 0.5
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(ctr)
			var a := clampf(float(r) - d + 0.5, 0.0, 1.0)
			var col := c
			if ring.a > 0.0 and d > r - 2.2:
				col = ring
			col.a *= a
			img.set_pixel(x, y, col)
	var t := ImageTexture.create_from_image(img)
	_textures[key] = t
	return t

# ---------------------------------------------------------------- HUD theme

static func make() -> Theme:
	var t := Theme.new()
	t.default_font = font(&"body")
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
	# scroll bars
	_scrollbars(t, Color(0.55, 0.38, 0.2, 0.7))
	return t

static func _scrollbars(t: Theme, grab: Color) -> void:
	for sb in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", sb, box(Color(0, 0, 0, 0.06), Color(0, 0, 0, 0), 4, 2.0, 0))
		t.set_stylebox(&"grabber", sb, box(grab, Color(0, 0, 0, 0), 4, 2.0, 0))
		t.set_stylebox(&"grabber_highlight", sb, box(grab.lightened(0.15), Color(0, 0, 0, 0), 4, 2.0, 0))
		t.set_stylebox(&"grabber_pressed", sb, box(grab.darkened(0.1), Color(0, 0, 0, 0), 4, 2.0, 0))

# ---------------------------------------------------------------- paper theme

static func paper_theme() -> Theme:
	if _paper_theme != null:
		return _paper_theme
	var t := Theme.new()
	t.default_font = font(&"body")
	t.default_font_size = 18
	t.set_color(&"font_color", &"Label", INK)
	t.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))
	t.set_constant(&"shadow_offset_x", &"Label", 0)
	t.set_constant(&"shadow_offset_y", &"Label", 0)
	t.set_constant(&"line_spacing", &"Label", 1)
	t.set_color(&"default_color", &"RichTextLabel", INK)
	t.set_font(&"normal_font", &"RichTextLabel", font(&"body"))
	t.set_font(&"bold_font", &"RichTextLabel", font(&"bold"))
	t.set_font(&"italics_font", &"RichTextLabel", font(&"italic"))
	t.set_font_size(&"normal_font_size", &"RichTextLabel", 18)
	t.set_font_size(&"bold_font_size", &"RichTextLabel", 18)
	t.set_font_size(&"italics_font_size", &"RichTextLabel", 18)
	t.set_stylebox(&"panel", &"PanelContainer", paper_box())
	# buttons: ink frames on parchment
	var normal := ink_box(Color(PAPER_DARK, 0.45), Color(INK_SOFT, 0.8), 14.0, 8.0, 1.6)
	var hover := ink_box(Color(PAPER_DARK, 0.85), INK, 14.0, 8.0, 2.0)
	var pressed := ink_box(Color(OCHRE, 0.35), INK, 14.0, 8.0, 2.2)
	var disabled := ink_box(Color(PAPER_DARK, 0.2), Color(INK_SOFT, 0.3), 14.0, 8.0, 1.2)
	for k in [[&"normal", normal], [&"hover", hover], [&"pressed", pressed], [&"disabled", disabled],
			[&"hover_pressed", pressed], [&"focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(k[0], &"Button", k[1])
	t.set_color(&"font_color", &"Button", INK)
	t.set_color(&"font_hover_color", &"Button", INK)
	t.set_color(&"font_pressed_color", &"Button", INK)
	t.set_color(&"font_hover_pressed_color", &"Button", INK)
	t.set_color(&"font_focus_color", &"Button", INK)
	t.set_color(&"font_disabled_color", &"Button", Color(INK_SOFT, 0.45))
	t.set_font(&"font", &"Button", font(&"semibold"))
	t.set_font_size(&"font_size", &"Button", 18)
	# text fields: a handwritten line
	var le := InkBox.new()
	le.underline_only = true
	le.ink = INK_SOFT
	le.width = 1.8
	le.fill = Color(1, 1, 1, 0.18)
	le.content_margin_left = 8; le.content_margin_right = 8
	le.content_margin_top = 2; le.content_margin_bottom = 4
	var le_focus := le.duplicate() as InkBox
	le_focus.ink = OCHRE
	le_focus.width = 2.4
	t.set_stylebox(&"normal", &"LineEdit", le)
	t.set_stylebox(&"focus", &"LineEdit", le_focus)
	t.set_stylebox(&"read_only", &"LineEdit", le)
	t.set_color(&"font_color", &"LineEdit", INK)
	t.set_color(&"caret_color", &"LineEdit", INK_RED)
	t.set_color(&"selection_color", &"LineEdit", Color(OCHRE, 0.35))
	t.set_color(&"font_placeholder_color", &"LineEdit", INK_FADED)
	t.set_font(&"font", &"LineEdit", font(&"hand_bold"))
	t.set_font_size(&"font_size", &"LineEdit", 36)
	t.set_constant(&"caret_width", &"LineEdit", 2)
	# sliders
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK_SOFT, 0.35)
	track.content_margin_top = 2; track.content_margin_bottom = 2
	track.set_corner_radius_all(2)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(OCHRE, 0.9)
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_icon(&"grabber", &"HSlider", dot_texture(9, PAPER, INK))
	t.set_icon(&"grabber_highlight", &"HSlider", dot_texture(10, Color("#fff4dc"), OCHRE))
	t.set_stylebox(&"focus", &"HSlider", StyleBoxEmpty.new())
	# tooltips and scrollbars
	t.set_stylebox(&"panel", &"TooltipPanel", ink_box(PAPER, INK_SOFT, 10.0, 6.0, 1.4))
	t.set_color(&"font_color", &"TooltipLabel", INK)
	t.set_font(&"font", &"TooltipLabel", font(&"body"))
	t.set_font_size(&"font_size", &"TooltipLabel", 16)
	_scrollbars(t, Color(INK_SOFT, 0.45))
	_paper_theme = t
	return t

# ---------------------------------------------------------------- helpers

## An ink label for paper contexts. kind picks the font.
static func ink_label(text: String, size: int = 18, kind: StringName = &"body", col: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font(kind))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	return l

static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 40
	return l
