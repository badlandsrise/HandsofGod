class_name StudioSplash extends Control
## The "Badlandsrise Game Studio" splash: a round emblem of layered badlands
## mesas with the sun rising behind them (one canvas shader, animated by
## `t`), the wordmark set in heavy, widely spaced Alegreya, and the studio
## sting (assets/audio/music/studio_sting.ogg, tools/music/front.py).
## About 3.6 s. Any key or click skips it. Emits `finished` once.

signal finished

const LENGTH := 3.6
const STING := "res://assets/audio/music/studio_sting.ogg"
const BG := Color("#120c0b")
const CREAM := Color("#f4e6c8")
const OCHRE := Color("#d9893a")

const SHADER := """
shader_type canvas_item;
uniform float t = 0.0;          // seconds into the splash
uniform float aspect = 2.0;     // rect width / height
uniform vec4 bg : source_color = vec4(0.07, 0.047, 0.043, 1.0);

float ease_out(float x) { x = clamp(x, 0.0, 1.0); return 1.0 - pow(1.0 - x, 3.0); }
float trap(float x, float x0, float x1, float top, float slope) {
	return top * clamp(min((x - x0) / slope, (x1 - x) / slope) + 1.0, 0.0, 1.0);
}
float n1(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float vnoise(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(n1(i), n1(i + 1.0), f); }

void fragment() {
	// emblem space: the circle has radius 1, centred; y up
	vec2 p = (UV - vec2(0.5, 0.5)) * vec2(aspect, 1.0) * 2.0 * 1.12;
	p.y = -p.y;
	float aa = fwidth(p.x) * 1.2;
	float rise = ease_out((t - 0.25) / 1.15);          // the sun's climb
	float glow_k = smoothstep(0.9, 1.6, t);
	float r = length(p);
	// sky: night violet to a dawn of rose and gold, warming as the sun climbs
	vec3 night_top = vec3(0.10, 0.08, 0.17);
	vec3 night_low = vec3(0.24, 0.12, 0.17);
	vec3 dawn_top = vec3(0.36, 0.22, 0.33);
	vec3 dawn_low = vec3(0.98, 0.58, 0.26);
	float h = clamp(p.y * 0.8 + 0.4, 0.0, 1.0);
	vec3 sky = mix(mix(night_low, night_top, h), mix(dawn_low, dawn_top, h), rise);
	// the sun, behind everything, with a soft halo and slow rays
	vec2 sc = vec2(0.0, mix(-0.75, 0.02, rise));
	float sd = length(p - sc);
	float sun_r = 0.27;
	vec3 sun_col = mix(vec3(1.0, 0.55, 0.22), vec3(1.0, 0.86, 0.52), rise);
	float halo = exp(-max(sd - sun_r, 0.0) * 3.2) * (0.35 + 0.4 * rise);
	float ang = atan(p.y - sc.y, p.x - sc.x);
	float rays = pow(0.5 + 0.5 * sin(ang * 14.0 + t * 0.35), 6.0) * smoothstep(sun_r, sun_r + 0.08, sd) * exp(-(sd - sun_r) * 1.8) * 0.55 * rise;
	sky += sun_col * (halo + rays);
	sky = mix(sky, sun_col, 1.0 - smoothstep(sun_r - aa, sun_r + aa, sd));
	// sun bands: the classic split sun, cut by horizontal gaps near its foot
	float band = step(0.5, fract((p.y - sc.y) * 11.0)) * step(p.y, sc.y - 0.06) * (1.0 - smoothstep(sun_r - aa, sun_r + aa, sd));
	sky = mix(sky, mix(night_low, dawn_low, rise) * 0.9, band * 0.85);
	vec3 col = sky;
	// back ridge: long and low, dusty mauve
	float back = -0.12 + 0.05 * vnoise(p.x * 3.0 + 2.0) + 0.03 * vnoise(p.x * 9.0) + trap(p.x, -0.95, -0.35, 0.12, 0.16);
	vec3 back_col = mix(vec3(0.20, 0.12, 0.17), vec3(0.62, 0.34, 0.33), rise);
	col = mix(col, back_col, 1.0 - smoothstep(back - aa, back + aa, p.y));
	// middle: a flat-topped butte left of centre, rust
	float mid = -0.3 + trap(p.x, -0.62, -0.08, 0.42, 0.1) + trap(p.x, 0.3, 0.95, 0.18, 0.2) + 0.015 * vnoise(p.x * 30.0);
	vec3 mid_col = mix(vec3(0.17, 0.08, 0.09), vec3(0.66, 0.27, 0.16), rise);
	float mid_m = 1.0 - smoothstep(mid - aa, mid + aa, p.y);
	// strata: thin lighter bands along the butte
	float strata = smoothstep(0.42, 0.5, abs(fract(p.y * 14.0 + 0.15 * vnoise(p.x * 6.0)) - 0.5)) * 0.18 * rise;
	col = mix(col, mid_col * (1.0 + strata), mid_m);
	// front: a big mesa to the right and a hoodoo spire on the left, near-black
	float front = -0.5 + trap(p.x, 0.02, 1.2, 0.32, 0.06) + 0.012 * vnoise(p.x * 40.0);
	front = max(front, -0.5 + trap(p.x, -0.78, -0.66, 0.42, 0.025));      // the spire
	front = max(front, -0.5 + trap(p.x, -0.86, -0.58, 0.16, 0.08));       // its plinth
	vec3 front_col = mix(vec3(0.08, 0.045, 0.05), vec3(0.32, 0.12, 0.08), rise * 0.7);
	float fm = 1.0 - smoothstep(front - aa, front + aa, p.y);
	float fstrata = smoothstep(0.44, 0.5, abs(fract(p.y * 9.0) - 0.5)) * 0.25 * rise;
	col = mix(col, front_col * (1.0 + fstrata), fm);
	// rim light on the mesa tops facing the sun
	float rim = smoothstep(0.02, 0.0, abs(p.y - front)) * fm * glow_k * 0.5;
	col += vec3(1.0, 0.6, 0.3) * rim;
	// the circle: mask and a cream ring
	float inside = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);
	float ring = smoothstep(0.022 + aa, 0.022, abs(r - 1.045));
	// the horizon line runs out past the circle and fades
	float hz = smoothstep(0.006 + aa, 0.006, abs(p.y + 0.5)) * step(1.06, abs(p.x)) * smoothstep(2.1, 1.1, abs(p.x));
	vec3 outc = bg.rgb;
	vec3 cream = vec3(0.957, 0.902, 0.784);
	vec3 o = mix(outc, col, inside);
	o = mix(o, cream, (ring + hz) * smoothstep(0.1, 0.8, t));
	COLOR = vec4(o, 1.0);
}
"""

var t: float = 0.0
var done: bool = false
var _emblem: ColorRect
var _mat: ShaderMaterial
var _word: Label
var _sub: Label
var _rules: Control
var _fade: ColorRect
var _sting: AudioStreamPlayer
var _ready_t: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_emblem = ColorRect.new()
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter(&"bg", BG)
	_emblem.material = _mat
	add_child(_emblem)
	_word = Label.new()
	_word.text = "BADLANDSRISE"
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.add_theme_font_override(&"font", _heavy(860, 14))
	_word.add_theme_font_size_override(&"font_size", 70)
	_word.add_theme_color_override(&"font_color", CREAM)
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_word)
	_sub = Label.new()
	_sub.text = "GAME STUDIO"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_override(&"font", _heavy(640, 13))
	_sub.add_theme_font_size_override(&"font_size", 22)
	_sub.add_theme_color_override(&"font_color", OCHRE)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)
	_rules = Rules.new()
	add_child(_rules)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	resized.connect(_layout)
	_layout()
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Master"
	_sting.stream = load(STING) if ResourceLoader.exists(STING) else null
	_sting.volume_db = Audio.music_db + 4.0
	add_child(_sting)
	if _sting.stream != null:
		_sting.play()
	_apply()

static func _heavy(weight: int, spacing: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load(UiTheme.FONT_FILES[&"body"])
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	fv.spacing_glyph = spacing
	return fv

func _layout() -> void:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	var k := minf(s.x / 1600.0, s.y / 900.0)
	var esz := Vector2(980, 420) * k
	_emblem.size = esz
	_emblem.position = Vector2((s.x - esz.x) * 0.5, s.y * 0.42 - esz.y * 0.5)
	_mat.set_shader_parameter(&"aspect", esz.x / esz.y)
	_word.add_theme_font_size_override(&"font_size", int(70 * k))
	_sub.add_theme_font_size_override(&"font_size", int(22 * k))
	_word.size = Vector2(s.x, 90 * k)
	_word.position = Vector2(0, _emblem.position.y + esz.y + 20 * k)
	_sub.size = Vector2(s.x, 34 * k)
	_sub.position = Vector2(0, _word.position.y + 92 * k)
	_rules.position = _sub.position
	_rules.size = _sub.size
	_rules.set(&"gap", 178.0 * k)
	_rules.set(&"len", 120.0 * k)
	_rules.queue_redraw()

func _process(delta: float) -> void:
	if done:
		return
	_ready_t += delta
	t += delta
	_apply()
	if t >= LENGTH:
		_finish()

func _apply() -> void:
	_mat.set_shader_parameter(&"t", t)
	# fade in from black, out to black at the end
	var a := 1.0 - clampf(t / 0.45, 0.0, 1.0)
	a = maxf(a, clampf((t - (LENGTH - 0.55)) / 0.5, 0.0, 1.0))
	_fade.color.a = a
	# the wordmark rises into place as the sun clears the ridge
	var w := clampf((t - 1.15) / 0.6, 0.0, 1.0)
	w = 1.0 - pow(1.0 - w, 3.0)
	_word.modulate.a = w
	_word.pivot_offset = _word.size * 0.5
	_word.position.y = _emblem.position.y + _emblem.size.y + 20.0 * _k() + (1.0 - w) * 18.0 * _k()
	var s2 := clampf((t - 1.7) / 0.5, 0.0, 1.0)
	_sub.modulate.a = s2
	_rules.modulate.a = s2

func _k() -> float:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	return minf(s.x / 1600.0, s.y / 900.0)

## Ends the splash now (a key or click).
func skip() -> void:
	_finish()

func _finish() -> void:
	if done:
		return
	done = true
	if _sting != null and _sting.playing:
		var tw := create_tween()
		tw.tween_property(_sting, "volume_db", -40.0, 0.4)
	_fade.color.a = 1.0
	finished.emit()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		accept_event()
		_try_skip()

func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventJoypadButton and e.pressed):
		get_viewport().set_input_as_handled()
		_try_skip()

func _try_skip() -> void:
	if _ready_t > 0.15:      # ignore the click or key that launched the game
		skip()

## Two thin ochre rules either side of "GAME STUDIO".
class Rules extends Control:
	var gap: float = 150.0
	var len: float = 120.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Color(StudioSplash.OCHRE, 0.85)
		var y := size.y * 0.55
		var m := size.x * 0.5
		draw_line(Vector2(m - gap - len, y), Vector2(m - gap, y), c, 1.6, true)
		draw_line(Vector2(m + gap, y), Vector2(m + gap + len, y), c, 1.6, true)
		draw_circle(Vector2(m - gap + 6, y), 2.2, c)
		draw_circle(Vector2(m + gap - 6, y), 2.2, c)
