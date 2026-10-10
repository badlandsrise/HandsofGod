extends Node3D
## Turns a part of a prop around one of its local axes: windmill sails, a potter's wheel,
## a well's windlass. Cheap: one rotation per frame. Stop it with `spinning = false`
## (a mill with nobody working, a calm day).

@export var speed: float = 0.7          # radians per second
@export var axis: Vector3 = Vector3.FORWARD
@export var spinning: bool = true


func _process(delta: float) -> void:
	if spinning:
		rotate_object_local(axis.normalized(), speed * delta)
