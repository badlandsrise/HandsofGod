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
	# the catalog trunk lies along its x axis, about 9 m at scale 1: stretch it over the gap
	var art := AssetCatalog.instance(&"trunk_fallen")
	art.rotation.y = PI * 0.5
	art.scale = Vector3(length / 9.0, 1.15, 1.15)
	v.add_child(art)
	# a broken crown of branches at the far end
	var crown := AssetCatalog.instance(&"tree_dead", 1)
	crown.rotation = Vector3(PI * 0.5, 0.0, 0.3)
	crown.position = Vector3(0.6, 1.0, -length * 0.5 + 0.5)
	crown.scale = Vector3.ONE * 0.9
	v.add_child(crown)
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
