class_name Beacon extends Node3D
## A guidance marker in the world (playtest era 1, section 1): a soft golden
## ring glowing on the ground, a bobbing arrow above it and sparkles rising,
## following a target node (the fire log, a gift, the festival dance spot, a
## new baby, the first wanderer). It fades in, and fades out when its time is
## up, when the target is gone, or when `until` returns true. Drawn over the
## terrain (no depth test) so it can't hide in a dip or behind a bush.
## Beacon.attach() keeps one beacon per target.

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.8, 0.32, 1.0);
uniform float inner = 0.7;
uniform float frac = 1.0;
uniform float alpha = 1.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float band = smoothstep(inner - 0.06, inner, r) * (1.0 - smoothstep(0.9, 0.98, r));
	float edge = smoothstep(inner - 0.12, inner - 0.06, r) * (1.0 - smoothstep(inner - 0.06, inner - 0.02, r))
		+ smoothstep(0.96, 0.98, r) * (1.0 - smoothstep(0.98, 1.0, r));
	float a = atan(p.x, -p.y) / 6.2831853 + 0.5;
	float arc = step(a, frac);
	float wave = 0.5 + 0.5 * sin(TIME * 3.0 - r * 9.0);
	float fill = (1.0 - smoothstep(0.0, inner, r)) * (0.10 + 0.10 * wave * pulse);
	vec3 c = mix(col.rgb, vec3(0.25, 0.14, 0.04), edge);
	float v = band * mix(0.12, 1.0, arc) + edge * 0.6 * arc + fill;
	ALBEDO = mix(c, col.rgb * 1.3, fill * 2.0);
	ALPHA = clamp(v * alpha, 0.0, 1.0);
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float alpha = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float g = exp(-r * r * 3.5) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = col.rgb;
	ALPHA = clamp(g * alpha * 0.55, 0.0, 1.0);
}
"""

static var _ring_shader: Shader = null
static var _glow_shader: Shader = null

var target: Node3D = null
var life: float = -1.0              # seconds left (-1: until the target is gone or `until`)
var until: Callable = Callable()    # returns true when the beacon is no longer needed
var radius: float = 1.6
var arrow_height: float = 3.2
var arrow: bool = true
var sparkle: bool = true
var color: Color = Color(1.0, 0.8, 0.32)
var kind: StringName = &""          # what it marks (tests and Guidance read it)
var quiet_when: Callable = Callable()  # true: fade to a faint ring, no arrow (the job is under way)

var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial
var _arrow: Node3D
var _arrow_mat: StandardMaterial3D
var _sparks: CPUParticles3D
var _a: float = 0.0
var _q: float = 1.0                 # 1 = full, eases toward 0.3 while quiet
var _t: float = 0.0
var _leaving := false

## Puts a beacon on `t` (or returns the one already there).
static func attach(t: Node3D, opts: Dictionary = {}) -> Beacon:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return null
	for b in t.get_tree().get_nodes_in_group(&"beacon"):
		if b is Beacon and b.target == t and not b._leaving:
			if opts.has("life"):
				b.life = maxf(b.life, float(opts["life"])) if b.life >= 0.0 else b.life
			return b
	var b := Beacon.new()
	b.target = t
	for k in opts:
		b.set(k, opts[k])
	var parent: Node = Game.world if Game.world != null and is_instance_valid(Game.world) else t.get_parent()
	parent.add_child(b)
	b.global_position = t.global_position
	return b

## A beacon at a fixed place (no target).
static func at_point(parent: Node, p: Vector3, opts: Dictionary = {}) -> Beacon:
	var b := Beacon.new()
	for k in opts:
		b.set(k, opts[k])
	parent.add_child(b)
	b.global_position = p
	return b

static func on(t: Node) -> Beacon:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return null
	for b in t.get_tree().get_nodes_in_group(&"beacon"):
		if b is Beacon and b.target == t and not b._leaving:
			return b
	return null

static func ring_material(c: Color) -> ShaderMaterial:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = RING_SHADER
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	m.set_shader_parameter(&"col", c)
	m.render_priority = 2
	return m

static func glow_material(c: Color) -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	m.set_shader_parameter(&"col", c)
	return m

static func sparkles(c: Color, r: float, amount: int = 14) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.amount = amount
	s.lifetime = 1.6
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	s.emission_ring_radius = r
	s.emission_ring_inner_radius = r * 0.6
	s.emission_ring_height = 0.1
	s.emission_ring_axis = Vector3.UP
	s.direction = Vector3.UP
	s.spread = 12.0
	s.gravity = Vector3(0, 0.6, 0)
	s.initial_velocity_min = 0.6
	s.initial_velocity_max = 1.4
	s.scale_amount_min = 0.5
	s.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(1, 0))
	s.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c.lightened(0.3)
	m.albedo_texture = UiTheme.dot_texture(8, Color(1, 1, 1))
	q.material = m
	s.mesh = q
	return s

func _ready() -> void:
	add_to_group(&"beacon")
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	_ring = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	_ring.mesh = pm
	_ring_mat = Beacon.ring_material(color)
	_ring_mat.set_shader_parameter(&"pulse", 1.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.08
	add_child(_ring)
	if arrow:
		_arrow = Node3D.new()
		add_child(_arrow)
		_arrow_mat = StandardMaterial3D.new()
		_arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_arrow_mat.albedo_color = color
		_arrow_mat.no_depth_test = true
		_arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_arrow_mat.render_priority = 3
		var outline := StandardMaterial3D.new()
		outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.albedo_color = Color(0.25, 0.14, 0.05)
		outline.no_depth_test = true
		outline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		outline.render_priority = 2
		outline.cull_mode = BaseMaterial3D.CULL_FRONT
		var head := CylinderMesh.new()
		head.top_radius = 0.42
		head.bottom_radius = 0.0
		head.height = 0.6
		head.radial_segments = 16
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.15
		shaft.bottom_radius = 0.15
		shaft.height = 0.55
		shaft.radial_segments = 12
		for pair in [[head, 0.0], [shaft, 0.55]]:
			var mi := MeshInstance3D.new()
			mi.mesh = pair[0]
			mi.material_override = _arrow_mat
			mi.position.y = pair[1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_arrow.add_child(mi)
			var ol := MeshInstance3D.new()
			ol.mesh = pair[0]
			ol.material_override = outline
			ol.position.y = pair[1]
			ol.scale = Vector3.ONE * 1.18
			ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_arrow.add_child(ol)
		_arrow.set_meta(&"outline", outline)
	if sparkle:
		_sparks = Beacon.sparkles(color, radius * 0.75)
		add_child(_sparks)
	_follow()

func _follow() -> void:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		var p := target.global_position
		if Game.world != null and is_instance_valid(Game.world) and Game.world.has_method(&"ground_y"):
			p.y = Game.world.ground_y(p.x, p.z)
		global_position = p

## Starts the fade out (the beacon frees itself after).
func dismiss() -> void:
	_leaving = true

func _process(_d: float) -> void:
	var dt := Clock.real_delta
	_t += dt
	if not _leaving:
		if target != null and (not is_instance_valid(target) or not target.is_inside_tree() or not target.visible):
			_leaving = true
		elif until.is_valid() and bool(until.call()):
			_leaving = true
		elif life >= 0.0:
			life -= dt
			if life <= 0.0:
				_leaving = true
	_a = move_toward(_a, 0.0 if _leaving else 1.0, dt * (1.5 if _leaving else 2.5))
	if _leaving and _a <= 0.0:
		queue_free()
		return
	_follow()
	var quiet := quiet_when.is_valid() and bool(quiet_when.call())
	_q = move_toward(_q, 0.3 if quiet else 1.0, dt * 2.0)
	_ring_mat.set_shader_parameter(&"alpha", _a * _q)
	var s := 1.0 + 0.06 * sin(_t * 3.0)
	_ring.scale = Vector3(s, 1, s)
	if _arrow != null:
		var aa := _a * clampf((_q - 0.3) / 0.7, 0.0, 1.0)
		_arrow.visible = aa > 0.01
		_arrow.position.y = arrow_height + 0.35 * sin(_t * 3.2)
		_arrow.rotation.y = _t * 1.2
		_arrow_mat.albedo_color.a = aa
		(_arrow.get_meta(&"outline") as StandardMaterial3D).albedo_color.a = aa * 0.9
	if _sparks != null:
		_sparks.emitting = _a > 0.3 and _q > 0.9 and not _leaving

## A ring on a blessed person that empties as the blessing runs out, a warm
## halo behind them, and a clear fade (the ring opens out and goes) when it
## wears off (playtest era 1, note 35).
class BlessRing extends Node3D:
	var person: Node3D = null
	var full: float = 30.0
	var _ring: MeshInstance3D
	var _mat: ShaderMaterial
	var _halo: MeshInstance3D
	var _halo_mat: ShaderMaterial
	var _sparks: CPUParticles3D
	var _ending: float = -1.0
	var _a: float = 0.0
	var _t: float = 0.0
	func _ready() -> void:
		add_to_group(&"bless_ring")
		process_mode = Node.PROCESS_MODE_ALWAYS
		top_level = true
		_ring = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.5, 1.5)
		_ring.mesh = pm
		_mat = Beacon.ring_material(Color(1.0, 0.86, 0.42))
		_mat.set_shader_parameter(&"inner", 0.74)
		_ring.material_override = _mat
		_ring.position.y = 0.06
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)
		_halo = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.9, 2.6)
		_halo.mesh = q
		_halo_mat = Beacon.glow_material(Color(1.0, 0.82, 0.45))
		_halo.material_override = _halo_mat
		_halo.position.y = 0.95
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_halo)
		_sparks = Beacon.sparkles(Color(1.0, 0.85, 0.4), 0.45, 8)
		_sparks.lifetime = 1.2
		add_child(_sparks)
	## 0..1 of the blessing left.
	func fraction() -> float:
		if person == null or not is_instance_valid(person):
			return 0.0
		return clampf(float(person.get(&"blessed_t")) / maxf(full, 0.01), 0.0, 1.0)
	func ending() -> bool:
		return _ending >= 0.0
	func _process(_d: float) -> void:
		var dt := Clock.real_delta
		_t += dt
		var alive: bool = person != null and is_instance_valid(person) and person.is_inside_tree() and person.visible
		if alive:
			global_position = person.global_position
			full = maxf(full, float(person.get(&"blessed_t")))
		var f := fraction()
		if _ending < 0.0 and (f <= 0.0 or not alive):
			_ending = 0.0
			_sparks.emitting = false
			if alive:
				var puff := Beacon.sparkles(Color(1.0, 0.9, 0.6), 0.6, 18)
				puff.one_shot = true
				puff.explosiveness = 0.9
				puff.initial_velocity_min = 1.2
				puff.initial_velocity_max = 2.4
				add_child(puff)
				puff.emitting = true
		if _ending >= 0.0:
			_ending += dt
			var k := clampf(_ending / 0.9, 0.0, 1.0)
			_ring.scale = Vector3.ONE * (1.0 + k * 0.9)
			_mat.set_shader_parameter(&"alpha", (1.0 - k) * _a)
			_mat.set_shader_parameter(&"frac", 1.0)
			_halo_mat.set_shader_parameter(&"alpha", (1.0 - k) * _a)
			if _ending >= 1.4:
				queue_free()
			return
		_a = move_toward(_a, 1.0, dt * 3.0)
		_mat.set_shader_parameter(&"frac", f)
		_mat.set_shader_parameter(&"alpha", _a)
		# the halo breathes, and flickers in the last seconds as a warning
		var warn := 1.0 if f > 0.2 else 0.55 + 0.45 * absf(sin(_t * 9.0))
		_halo_mat.set_shader_parameter(&"alpha", _a * (0.8 + 0.2 * sin(_t * 2.5)) * warn)

## "+6 meat  +1 hide" rising from where the work paid out.
class YieldPop extends Label3D:
	var _t: float = 0.0
	const LIFE := 2.6
	func _init() -> void:
		billboard = BaseMaterial3D.BILLBOARD_ENABLED
		no_depth_test = true
		fixed_size = true
		pixel_size = 0.0011
		font_size = 30
		outline_size = 10
		modulate = Color(1.0, 0.93, 0.7)
		outline_modulate = Color(0.22, 0.12, 0.04, 0.9)
		font = UiTheme.font(&"bold")
		render_priority = 4
		outline_render_priority = 3
	func _ready() -> void:
		add_to_group(&"yield_pop")
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_d: float) -> void:
		_t += Clock.real_delta
		position.y += Clock.real_delta * 0.6
		var a := clampf(_t * 4.0, 0.0, 1.0) * (1.0 - clampf((_t - LIFE + 0.8) / 0.8, 0.0, 1.0))
		modulate.a = a
		outline_modulate.a = a * 0.9
		if _t >= LIFE:
			queue_free()
