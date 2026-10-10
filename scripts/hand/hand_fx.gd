class_name HandFx extends RefCounted
## One-shot effects for the hand: dust puffs on lift and landing, gift
## sparkles, a ground flash ring. Each spawns a self-freeing node under `parent`.

static var _dust_mesh: QuadMesh
static var _spark_mesh: QuadMesh
static var _soft_tex: GradientTexture2D
static var _star_tex: ImageTexture

static func _soft() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(0.5, 0.0)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex

## A four-pointed twinkle, drawn once.
static func _star() -> ImageTexture:
	if _star_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
				var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
				var r := sqrt(u * u + v * v)
				var arms := maxf(1.0 - absf(u) * 9.0, 0.0) * (1.0 - absf(v)) + maxf(1.0 - absf(v) * 9.0, 0.0) * (1.0 - absf(u))
				var core := clampf(1.0 - r * 2.6, 0.0, 1.0)
				var a := clampf(arms * 0.9 + core, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_star_tex = ImageTexture.create_from_image(img)
	return _star_tex

static func _material(tex: Texture2D, unshaded: bool, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

static func _spawn(parent: Node, p: CPUParticles3D, at: Vector3, life: float) -> CPUParticles3D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		p.free()
		return null
	p.top_level = true
	p.one_shot = true
	p.emitting = false
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(life + 0.5, true, false, true).timeout.connect(p.queue_free)
	return p

## A soft ring of dust kicked up from the ground (lifting, landing).
static func dust(parent: Node, at: Vector3, size: float = 1.0, color: Color = Color(0.82, 0.72, 0.56)) -> CPUParticles3D:
	if _dust_mesh == null:
		_dust_mesh = QuadMesh.new()
		_dust_mesh.size = Vector2(0.7, 0.7)
		_dust_mesh.material = _material(_soft(), false, false)
	var p := CPUParticles3D.new()
	p.mesh = _dust_mesh
	p.amount = int(10 + 6 * size)
	p.lifetime = 0.75
	p.explosiveness = 0.95
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 90.0
	p.flatness = 0.75
	p.initial_velocity_min = 1.6 * size
	p.initial_velocity_max = 3.2 * size
	p.damping_min = 4.0
	p.damping_max = 6.0
	p.gravity = Vector3(0, 0.4, 0)
	p.scale_amount_min = 0.6 * size
	p.scale_amount_max = 1.4 * size
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1.0, 1.3))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.55), Color(color, 0.0)])
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.35 * size
	p.emission_ring_inner_radius = 0.1
	p.emission_ring_height = 0.05
	return _spawn(parent, p, at + Vector3(0, 0.15, 0), p.lifetime)

## Golden twinkles bursting up and drifting toward `toward` (the hand).
static func sparkle(parent: Node, at: Vector3, glow: Color, toward: Vector3 = Vector3.INF) -> CPUParticles3D:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(0.55, 0.55)
		_spark_mesh.material = _material(_star(), true, true)
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.amount = 36
	p.lifetime = 1.2
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, -1.5, 0)
	if toward.is_finite():
		var d := toward - at
		p.gravity = d.normalized() * 4.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	var hot := Color(1.0, 0.95, 0.7)
	g.colors = PackedColorArray([Color(hot, 1.0), Color(glow.lerp(hot, 0.5), 1.0), Color(glow, 0.7), Color(glow, 0.0)])
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	return _spawn(parent, p, at + Vector3(0, 0.4, 0), p.lifetime)
