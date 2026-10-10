class_name EndingSky extends Node3D
## The goodbye's sky, over the launch site: the clouds that roll in before the
## countdown and part under the hand (Part the Clouds), the stars, the ground
## billow at liftoff, and the light: the rocket far away, a small bright point
## that blinks twice. Everything here is set by GoodbyeSequence each frame:
##   roll_in 0..1   clouds drift in from the horizon over the plateau
##   part    0..1   the hole the hand holds open above the pad
##   clear   0..1   after liftoff the weather clears away for the night
##   stars   0..1   star visibility
## The node sits at the pad (top_level), so all positions are pad-relative.

const PUFF := "res://assets/textures/era4/puff.png"
const CLOUDS := 54
const STARS := 1100
const STAR_R := 1150.0
const GAP := 95.0

var roll_in: float = 0.0
var part: float = 0.0
var clear: float = 0.0
var stars: float = 0.0
var cloud_tint := Color(0.62, 0.6, 0.7)
var light_on: bool = false
var light_gain: float = 0.0     # extra brightness (the blinks)

var _clouds: Array = []         # [Sprite3D, angle, radius, height, size, phase]
var _stars: MeshInstance3D
var _star_mat: StandardMaterial3D
var _light: MeshInstance3D
var _light_mat: StandardMaterial3D
var _billow: Array = []         # [Sprite3D, dir, age, size]
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "EndingSky"
	top_level = true

func _ready() -> void:
	_rng.seed = 4242
	_build_clouds()
	_build_stars()
	_build_light()

func _puff_tex() -> Texture2D:
	return load(PUFF) if ResourceLoader.exists(PUFF) else null

func _build_clouds() -> void:
	var tex := _puff_tex()
	for i in CLOUDS:
		var s := Sprite3D.new()
		s.texture = tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.transparent = true
		s.double_sided = true
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 175.0 + 8.0
		var h := _rng.randf_range(62.0, 92.0)
		var sz := _rng.randf_range(0.45, 0.85)
		s.pixel_size = sz
		s.visible = false
		add_child(s)
		_clouds.append([s, a, r, h, sz, _rng.randf() * TAU])

func _build_stars() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STARS:
		# the upper sky, denser toward the horizon band like a real night
		var az := _rng.randf() * TAU
		var el := asin(pow(_rng.randf(), 1.35)) * 0.98 + 0.03
		var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
		var c := dir * STAR_R
		var size := _rng.randf_range(0.9, 2.4) * (2.0 if _rng.randf() < 0.05 else 1.0)
		var right := dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.98 else Vector3.RIGHT
		var up := right.cross(dir).normalized()
		var warmth := _rng.randf()
		var col := Color(1.0, 0.92, 0.8).lerp(Color(0.78, 0.86, 1.0), warmth)
		col.a = _rng.randf_range(0.35, 1.0)
		var q := [c - right * size - up * size, c + right * size - up * size, c + right * size + up * size, c - right * size + up * size]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.add_vertex(q[k])
	_stars = MeshInstance3D.new()
	_stars.name = "Stars"
	_stars.mesh = st.commit()
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.vertex_color_use_as_albedo = true
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_star_mat.disable_fog = true
	_star_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_star_mat.albedo_color = Color(1, 1, 1, 0)
	_stars.material_override = _star_mat
	_stars.extra_cull_margin = 4000.0
	add_child(_stars)

func _glow_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.12, Color(1, 0.97, 0.88, 0.95))
	g.add_point(0.35, Color(1, 0.85, 0.6, 0.28))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t

func _build_light() -> void:
	_light = MeshInstance3D.new()
	_light.name = "TheLight"
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	_light.mesh = q
	_light_mat = StandardMaterial3D.new()
	_light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_light_mat.fixed_size = true
	_light_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_light_mat.disable_fog = true
	_light_mat.no_depth_test = true
	_light_mat.albedo_texture = _glow_tex()
	_light_mat.albedo_color = Color(1.0, 0.92, 0.78, 1.0)
	_light.material_override = _light_mat
	_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light.extra_cull_margin = 4000.0
	_light.visible = false
	_light.top_level = true
	add_child(_light)

## Where the light is (world space), and how bright (1 = a bright star).
func set_light(at: Vector3, brightness: float) -> void:
	_light.visible = brightness > 0.01
	_light.global_position = at
	var b := clampf(brightness, 0.0, 4.0)
	(_light.mesh as QuadMesh).size = Vector2.ONE * (0.035 + 0.03 * b)
	_light_mat.albedo_color = Color(1.0, 0.92, 0.78, clampf(b, 0.0, 1.0))

func light_position() -> Vector3:
	return _light.global_position

## A ring of steam and smoke rolling out across the pad at ignition.
func billow(count: int = 22) -> void:
	var tex := _puff_tex()
	for i in count:
		var s := Sprite3D.new()
		s.texture = tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = true
		s.transparent = true
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.modulate = Color(0.95, 0.93, 0.9, 0.0)
		add_child(s)
		var a := TAU * float(i) / float(count) + _rng.randf_range(-0.12, 0.12)
		_billow.append([s, Vector3(cos(a), 0, sin(a)), -_rng.randf() * 0.6, _rng.randf_range(0.04, 0.065)])

func _process(delta: float) -> void:
	var dt := Clock.real_delta if Clock.real_delta > 0.0 else delta
	step(dt)

func step(dt: float) -> void:
	_t += dt
	# ---- clouds
	var vis := roll_in > 0.001 and clear < 0.999
	for c in _clouds:
		var s: Sprite3D = c[0]
		s.visible = vis
		if not vis:
			continue
		var a: float = c[1] + _t * 0.004
		var r: float = c[2]
		var h: float = c[3]
		# in from beyond the horizon, out to the edge as the hand parts them
		r += (1.0 - roll_in) * 320.0
		if part > 0.0:
			r += maxf(GAP + 25.0 - r, 0.0) * part + part * 18.0
		r += clear * 260.0
		var bob := sin(_t * 0.2 + c[5]) * 1.2
		s.position = Vector3(cos(a) * r, h + bob + clear * 20.0, sin(a) * r)
		var col := cloud_tint
		col.a = 0.92 * roll_in * (1.0 - clear)
		s.modulate = col
	# ---- stars
	_star_mat.albedo_color = Color(1, 1, 1, clampf(stars, 0.0, 1.0))
	_stars.visible = stars > 0.01
	# ---- the billow
	for i in range(_billow.size() - 1, -1, -1):
		var b: Array = _billow[i]
		b[2] += dt
		var s: Sprite3D = b[0]
		var age: float = b[2]
		if age < 0.0:
			continue
		var r := 4.0 + 20.0 * (1.0 - exp(-age * 0.45))
		s.position = b[1] * r + Vector3(0, 1.0 + age * 0.35, 0)
		s.pixel_size = b[3] * (1.0 + age * 0.12)
		var a := clampf(age * 2.0, 0.0, 1.0) * clampf(1.0 - (age - 3.5) / 5.0, 0.0, 1.0)
		s.modulate = Color(0.95, 0.93, 0.9, 0.8 * a)
		if age > 12.0:
			s.queue_free()
			_billow.remove_at(i)

func cloud_count_visible() -> int:
	var n := 0
	for c in _clouds:
		if (c[0] as Sprite3D).visible:
			n += 1
	return n
