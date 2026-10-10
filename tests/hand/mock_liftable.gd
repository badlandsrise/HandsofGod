extends Node3D
## Test double for a liftable world object (a fallen trunk or a boulder).

@export var weight: float = 4.0
var title: String = "Fallen trunk"
var lifted: int = 0
var placed_at: Vector3 = Vector3.INF

func _ready() -> void: add_to_group(&"liftable")
func lift_weight() -> float: return weight
func on_lifted() -> void: lifted += 1
func on_placed(at: Vector3) -> void:
	placed_at = at
	global_position = at
