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
	if branchy:
		# the storm branch: a dead limb lying on its side, crown and all
		var br := AssetCatalog.instance(&"tree_dead", 3)
		br.rotation = Vector3(0.0, 0.0, PI * 0.5)
		br.position = Vector3(len_m * 0.5, radius + 0.1, 0)
		br.scale = Vector3.ONE * (len_m / 5.1)
		v.add_child(br)
	else:
		# log_fallen lies along x, 3.5 m long at scale 1
		var lg := AssetCatalog.instance(&"log_fallen", int(len_m * 10.0))
		lg.scale = Vector3(len_m / 3.5, radius / 0.42, radius / 0.42)
		v.add_child(lg)
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
