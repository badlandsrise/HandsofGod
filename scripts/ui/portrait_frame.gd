class_name PortraitFrame extends Control
## A round, ink-ringed portrait of one person. Shows the rendered portrait from
## Portraits when there is one, else a silhouette tinted with their skin, hair
## and clothes. Dead people are drawn in grey with a small memorial stone; a
## name the hand gave gets a little hand mark.

const DESAT := "shader_type canvas_item;\nuniform float grey = 0.0;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; float l = dot(c.rgb, vec3(0.3,0.59,0.11)); COLOR = vec4(mix(c.rgb, vec3(l) * vec3(1.0,0.97,0.92), grey), c.a); }"

static var _shader: Shader = null

var rec: Dictionary = {}
var ring: Color = UiTheme.INK_SOFT
var ring_width: float = 2.0
var backdrop: Color = Color("#e7cf9f")
var show_marks: bool = true
var _tex: Texture2D = null
var _key: String = ""

static func make(r: Dictionary, size_px: float) -> PortraitFrame:
	var f := PortraitFrame.new()
	f.custom_minimum_size = Vector2(size_px, size_px)
	f.set_record(r)
	return f

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := Portraits.get_inst()
	if p != null and not p.portrait_ready.is_connected(_on_ready_portrait):
		p.portrait_ready.connect(_on_ready_portrait)
	_fetch()

func set_record(r: Dictionary) -> void:
	rec = r
	_key = Portraits.key_for(r)
	if is_inside_tree():
		_fetch()
	queue_redraw()

func _fetch() -> void:
	var p := Portraits.get_inst()
	_tex = p.request(rec) if p != null and not rec.is_empty() else null
	queue_redraw()

func _on_ready_portrait(key: String) -> void:
	if key == _key:
		_fetch()

static func _skin(rec_look: Dictionary) -> Color:
	return PersonVisual.SKIN[posmod(int(rec_look.get("skin", 0)), PersonVisual.SKIN.size())]

static func _hair(rec_look: Dictionary) -> Color:
	return PersonVisual.HAIR[posmod(int(rec_look.get("hair", 0)), PersonVisual.HAIR.size())]

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5 - ring_width
	var dead := not bool(rec.get("alive", true))
	var g := 0.85 if dead else 0.0
	# backdrop
	var bd := backdrop.lerp(Color(0.78, 0.76, 0.72), g)
	draw_circle(c, r, bd)
	draw_circle(c + Vector2(0, r * 0.25), r * 0.8, bd.darkened(0.06))
	if _tex != null:
		_draw_tex_circle(c, r, g)
	else:
		_draw_silhouette(c, r, g)
	# ring
	draw_arc(c, r + ring_width * 0.5, 0, TAU, 48, Color(ring, 0.9 if not dead else 0.5), ring_width, true)
	draw_arc(c, r - 2.0, 0, TAU, 48, Color(1, 1, 1, 0.18), 1.0, true)
	if not show_marks:
		return
	if dead:
		_draw_stone(c + Vector2(r * 0.66, r * 0.62), maxf(s * 0.15, 7.0))
	if bool(rec.get("hand_named", false)):
		draw_hand_mark(self, c + Vector2(-r * 0.7, r * 0.66), maxf(s * 0.14, 7.0), UiTheme.OCHRE)

func _draw_tex_circle(c: Vector2, r: float, g: float) -> void:
	# a textured circle polygon so the portrait is clipped round
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := 40
	var zoom := 1.0
	for i in n:
		var a := TAU * i / n
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + d * 0.5 * zoom)
	var col := Color(1, 1, 1)
	if g > 0.0:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = DESAT
		if material == null:
			var m := ShaderMaterial.new()
			m.shader = _shader
			material = m
		(material as ShaderMaterial).set_shader_parameter(&"grey", g)
		col = Color(0.92, 0.92, 0.92)
	elif material != null:
		(material as ShaderMaterial).set_shader_parameter(&"grey", 0.0)
	draw_colored_polygon(pts, col, uvs, _tex)

func _draw_silhouette(c: Vector2, r: float, g: float) -> void:
	var lk: Dictionary = rec.get("look", {})
	var grey := Color(0.6, 0.58, 0.55)
	var skin := _skin(lk).lerp(grey, g)
	var hair := _hair(lk).lerp(grey.darkened(0.3), g)
	var cloth := PersonVisual.CLOTH_IDLE.lerp(grey.darkened(0.15), g)
	var stage := int(rec.get("stage", 2))
	var head_r := r * (0.36 if stage >= 2 else 0.42)
	var head := c + Vector2(0, -r * 0.1)
	# shoulders: a wide rounded body, clipped to the round frame
	var body := PackedVector2Array()
	var bc := Vector2(c.x, head.y + head_r * 1.0 + r * 0.62)
	for i in 32:
		var a := TAU * i / 32.0
		body.append(bc + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.62))
	var disc := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		disc.append(c + Vector2(cos(a), sin(a)) * (r - 0.5))
	for poly in Geometry2D.intersect_polygons(body, disc):
		if poly.size() >= 3:
			draw_colored_polygon(poly, cloth)
	draw_circle(head + Vector2(0, head_r * 0.85), head_r * 0.42, skin.darkened(0.08))
	draw_circle(head, head_r, skin)
	# hair: a cap on the upper half, longer for women
	var hp := PackedVector2Array()
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		hp.append(head + Vector2(cos(a), sin(a)) * head_r * 1.06)
	var long := str(rec.get("sex", "f")) == "f"
	hp.append(head + Vector2(head_r * 1.06, head_r * (0.9 if long else 0.1)))
	hp.append(head + Vector2(head_r * 0.7, head_r * (0.95 if long else -0.05)))
	hp.append(head + Vector2(head_r * 0.6, -head_r * 0.25))
	hp.append(head + Vector2(-head_r * 0.6, -head_r * 0.25))
	hp.append(head + Vector2(-head_r * 0.7, head_r * (0.95 if long else -0.05)))
	hp.append(head + Vector2(-head_r * 1.06, head_r * (0.9 if long else 0.1)))
	draw_colored_polygon(hp, hair)
	# eyes
	var eye := Color(0.15, 0.1, 0.07, 0.85)
	draw_circle(head + Vector2(-head_r * 0.32, head_r * 0.12), maxf(head_r * 0.07, 1.0), eye)
	draw_circle(head + Vector2(head_r * 0.32, head_r * 0.12), maxf(head_r * 0.07, 1.0), eye)

func _draw_stone(at: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var a := PI + PI * float(i) / 10.0
		pts.append(at + Vector2(cos(a) * s * 0.55, sin(a) * s * 0.55 - s * 0.1))
	pts.append(at + Vector2(s * 0.55, s * 0.6))
	pts.append(at + Vector2(-s * 0.55, s * 0.6))
	draw_colored_polygon(pts, Color(0.62, 0.6, 0.58))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, UiTheme.INK_SOFT, 1.2, true)
	draw_line(at + Vector2(-s * 0.22, -s * 0.12), at + Vector2(s * 0.22, -s * 0.12), UiTheme.INK_SOFT, 1.0, true)
	draw_line(at + Vector2(0, -s * 0.34), at + Vector2(0, s * 0.18), UiTheme.INK_SOFT, 1.0, true)

## The hand's mark: a tiny open hand (palm, four fingers and a thumb).
static func draw_hand_mark(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var w := maxf(s * 0.19, 1.3)
	ci.draw_circle(at + Vector2(0, s * 0.16), s * 0.4, col)
	ci.draw_rect(Rect2(at + Vector2(-s * 0.38, -s * 0.14), Vector2(s * 0.76, s * 0.34)), col)
	var fingers := [[-0.27, -0.74], [-0.06, -0.86], [0.15, -0.8], [0.34, -0.6]]
	for f in fingers:
		var base := at + Vector2(f[0] * s, -s * 0.05)
		var tip := at + Vector2(f[0] * s * 1.12, f[1] * s)
		ci.draw_line(base, tip, col, w, true)
		ci.draw_circle(tip, w * 0.5, col)
	var tb := at + Vector2(-s * 0.32, s * 0.2)
	var tt := at + Vector2(-s * 0.72, -s * 0.12)
	ci.draw_line(tb, tt, col, w * 1.05, true)
	ci.draw_circle(tt, w * 0.52, col)
