class_name HomeRebuild extends Node
## The Era 1 -> Era 2 rebuild, on screen (world.rebuild_homes_on_screen): while
## the camera hangs pulled back over the village and the season turns, each
## family's hut comes down in a puff of dust and its cottage rises in its
## place, one home after another. The data change is EraTransition.convert_hut,
## made the moment each hut comes down, so a save mid-show is consistent.

const DOWN := 0.55        # seconds for a hut to sink away
const UP := 0.8           # seconds for the cottage to rise

var _jobs: Array = []     # [site, start time, phase]
var _t := 0.0
var converted := 0

func begin(sites: Array, duration: float) -> void:
	name = "HomeRebuild"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var n := sites.size()
	var span := maxf(duration - DOWN - UP, 0.5)
	for i in n:
		_jobs.append([sites[i], span * float(i) / maxf(n - 1, 1) if n > 1 else 0.0, 0])

func running() -> bool:
	return not _jobs.is_empty()

func _process(delta: float) -> void:
	_t += Clock.real_delta if Clock.real_delta > 0.0 else delta
	var left: Array = []
	for j in _jobs:
		var s = j[0]
		if not is_instance_valid(s):
			continue
		var k: float = _t - float(j[1])
		if k < 0.0:
			left.append(j)
			continue
		var vis: Node3D = s.get_node_or_null("Visual") as Node3D
		if j[2] == 0:
			if vis != null:
				var d := clampf(k / DOWN, 0.0, 1.0)
				vis.scale = Vector3(1.0 + d * 0.15, maxf(1.0 - d * d, 0.02), 1.0 + d * 0.15)
			if k >= DOWN:
				_dust(s.global_position)
				if EraTransition.convert_hut(s):
					_count()
				j[2] = 1
				vis = s.get_node_or_null("Visual") as Node3D
				if vis != null:
					vis.scale = Vector3(0.6, 0.02, 0.6)
			left.append(j)
		else:
			var u := clampf((k - DOWN) / UP, 0.0, 1.0)
			# rise with a little overshoot, like a barn raising seen from the sky
			var e := 1.0 + 0.12 * sin(u * PI) * (1.0 - u)
			var g := 1.0 - pow(1.0 - u, 3.0)
			if vis != null:
				vis.scale = Vector3(lerpf(0.6, 1.0, g), g * e, lerpf(0.6, 1.0, g)).max(Vector3(0.02, 0.02, 0.02))
			if u >= 1.0:
				if vis != null:
					vis.scale = Vector3.ONE
				continue
			left.append(j)
	_jobs = left
	if _jobs.is_empty():
		queue_free()

## Finishes at once (the transition was skipped, or a test).
func finish_now() -> void:
	for j in _jobs:
		var s = j[0]
		if not is_instance_valid(s):
			continue
		if j[2] == 0 and EraTransition.convert_hut(s):
			_count()
		var vis: Node3D = s.get_node_or_null("Visual") as Node3D
		if vis != null:
			vis.scale = Vector3.ONE
	_jobs.clear()
	queue_free()

func _count() -> void:
	converted += 1
	Village.stats["cottages_rebuilt"] = int(Village.stats.get("cottages_rebuilt", 0)) + 1

func _dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 28
	p.lifetime = 1.6
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.4
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -0.6, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 1.3))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.68, 0.52, 0.75))
	grad.set_color(1, Color(0.78, 0.7, 0.58, 0.0))
	p.color_ramp = grad
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	sm.material = mat
	p.mesh = sm
	p.position = at + Vector3(0, 0.6, 0)
	if Game.world != null:
		Game.world.add_child(p)
		p.emitting = true
		var t := get_tree().create_timer(2.5, true, false, true)
		t.timeout.connect(p.queue_free)
