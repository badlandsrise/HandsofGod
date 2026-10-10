class_name SiteFire extends Node3D
## Flames and smoke over a burning building (Era 3 town fire). Grows with the
## fire's strength (0..1). Built only when there is a screen to draw it on.

var flames: CPUParticles3D
var smoke: CPUParticles3D
var glow: OmniLight3D

static func make(fp: Vector2) -> SiteFire:
	var f := SiteFire.new()
	f.name = "Fire"
	f._build(fp)
	return f

func _build(fp: Vector2) -> void:
	var ext := Vector3(fp.x * 0.35, 0.6, fp.y * 0.35)
	flames = _particles(90, 1.1, ext, Color(1.0, 0.55, 0.15, 0.85), Vector2(0.9, 1.3), 3.5, 5.5)
	flames.position = Vector3(0, 2.2, 0)
	smoke = _particles(40, 4.5, ext, Color(0.42, 0.4, 0.38, 0.4), Vector2(2.2, 2.2), 2.0, 3.2)
	smoke.position = Vector3(0, 4.0, 0)
	smoke.scale_amount_max = 2.5
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.omni_range = maxf(fp.x, fp.y) + 6.0
	glow.position = Vector3(0, 3.0, 0)
	add_child(glow)

func _particles(n: int, life: float, ext: Vector3, col: Color, size: Vector2, v0: float, v1: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.6, 0.0, 0.0)
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	add_child(p)
	return p

func set_strength(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	# CPU particles keep their count: a small fire has small, low flames
	flames.scale_amount_min = lerpf(0.35, 1.0, k)
	flames.scale_amount_max = lerpf(0.5, 1.3, k)
	flames.initial_velocity_min = lerpf(1.5, 3.5, k)
	flames.initial_velocity_max = lerpf(2.5, 5.5, k)
	smoke.scale_amount_min = lerpf(0.4, 1.0, k)
	smoke.scale_amount_max = lerpf(1.0, 2.5, k)
	glow.light_energy = lerpf(0.8, 3.0, k)
