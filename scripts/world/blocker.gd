class_name Blocker extends Node3D
## A physical blocker in front of a locked region (section 10.1): the fallen
## trunk to the Valley Floor. Cleared by work, not by the hand: when the region
## opens it rolls aside and sinks away. Art lives under "Visual".

@export var region: StringName = &"valley_floor"
var cleared: bool = false
var _t: float = -1.0

func build_trunk(length: float) -> void:
	var v := Node3D.new()
	v.name = "Visual"
	add_child(v)
	var bark := Color(0.34, 0.23, 0.15)
	var trunk := Props.add_mesh(v, Props.cyl(0.75, 0.95, length, 9), bark, Vector3(0, 0.85, 0))
	trunk.rotation.x = PI * 0.5
	var cap := Props.add_mesh(v, Props.cyl(0.85, 0.85, 0.05, 9), Color(0.7, 0.55, 0.36), Vector3(0, 0.85, length * 0.5))
	cap.rotation.x = PI * 0.5
	# root plate at the far end, a few broken limbs
	var roots := Props.add_mesh(v, Props.cyl(1.9, 1.6, 0.6, 8), Color(0.3, 0.22, 0.15), Vector3(0, 1.3, -length * 0.5))
	roots.rotation.x = PI * 0.5
	Props.add_mesh(v, Props.ball(1.2, 6), Color(0.36, 0.29, 0.2), Vector3(0, 1.0, -length * 0.5 - 0.3)).scale = Vector3(1.6, 1.3, 0.6)
	for i in 4:
		var limb := Props.add_mesh(v, Props.cyl(0.12, 0.25, 2.4, 6), bark.lightened(0.05), Vector3(0, 1.4, -length * 0.3 + i * length * 0.2))
		limb.rotation = Vector3(0.3 * (i - 1.5), 0.0, 0.9 if i % 2 == 0 else -0.9)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.8, length)
	cs.shape = box
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)

## Animates the removal (about 1.5 s); instant when `now` is true (loading).
func clear(now: bool = false) -> void:
	if cleared:
		return
	cleared = true
	var body := get_node_or_null("Body")
	if body:
		body.queue_free()
	if now:
		visible = false
	else:
		_t = 0.0

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var k := clampf(_t / 1.5, 0.0, 1.0)
	position.x += delta * 3.0
	rotation.z = -k * 1.4
	scale = Vector3.ONE * (1.0 - k * 0.9)
	if k >= 1.0:
		visible = false
		_t = -1.0
