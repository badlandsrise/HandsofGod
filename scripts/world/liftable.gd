class_name Liftable extends Node3D
## A world object the hand can lift (the storm branch, the meadow logs, later
## boulders). Implements the contract from scripts/hand/hand.gd:
##   lift_weight() -> float ; on_lifted() ; on_placed(at: Vector3)
## The hand moves it with held_follow() while held. Art lives under "Visual".

signal lifted
signal placed(at: Vector3)

@export var weight: float = 2.0
@export var kind: StringName = &"log"
@export var label: String = "Fallen log"
var held: bool = false
var length: float = 4.0
var moved_count: int = 0

func _ready() -> void:
	add_to_group("liftable")

func lift_weight() -> float:
	return weight

func pick_radius() -> float:
	return maxf(1.2, length * 0.5)

func hover_text() -> String:
	return "%s (weight %d)" % [label, int(weight)]

func is_held() -> bool:
	return held

func on_lifted() -> void:
	held = true
	lifted.emit()

## While held: follow the hand, swinging gently.
func held_follow(world_pos: Vector3) -> void:
	global_position = world_pos

func on_placed(at: Vector3) -> void:
	held = false
	var y := at.y
	if Game.world != null and Game.world.has_method("ground_y"):
		y = Game.world.ground_y(at.x, at.z)
	global_position = Vector3(at.x, y, at.z)
	moved_count += 1
	placed.emit(global_position)

## Builds a placeholder log (or branch) along local x.
func build_log_visual(len_m: float, radius: float, branchy: bool) -> void:
	length = len_m
	var v := Node3D.new()
	v.name = "Visual"
	add_child(v)
	var bark := Color(0.38, 0.26, 0.16)
	var log_mesh := Props.cyl(radius * 0.9, radius, len_m, 8)
	var mi := Props.add_mesh(v, log_mesh, bark, Vector3(0, radius, 0))
	mi.rotation.z = PI * 0.5
	var cap := Props.cyl(radius * 0.85, radius * 0.85, 0.02, 8)
	for sx in [-1.0, 1.0]:
		var c := Props.add_mesh(v, cap, Color(0.72, 0.58, 0.38), Vector3(sx * len_m * 0.5, radius, 0))
		c.rotation.z = PI * 0.5
	if branchy:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(len_m * 100.0)
		for i in 5:
			var twig := Props.add_mesh(v, Props.cyl(radius * 0.2, radius * 0.4, len_m * 0.35, 5), bark.lightened(0.05),
				Vector3(rng.randf_range(-len_m * 0.4, len_m * 0.4), radius + 0.2, rng.randf_range(-0.2, 0.2)))
			twig.rotation = Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, rng.randf_range(0.5, 1.2))
			var leaves := Props.add_mesh(v, Props.ball(0.45, 6), Color(0.24, 0.4, 0.2), twig.position + twig.basis.y * len_m * 0.18)
			leaves.scale = Vector3(1.2, 0.8, 1.0)
	# a body for physics picking (layer 2 = liftables) that also blocks walkers
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(len_m, radius * 2.0, radius * 2.2)
	cs.shape = box
	cs.position = Vector3(0, radius, 0)
	body.add_child(cs)
	add_child(body)

func save_state() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y, "moved": moved_count}

func load_state(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	rotation.y = d.get("yaw", rotation.y)
	moved_count = d.get("moved", 0)
	held = false
