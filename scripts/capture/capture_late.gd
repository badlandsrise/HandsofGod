extends Node
## [capture] Late in the frame (after the camera rig, the hand and the
## goodbye's own camera): the capture camera poses the shot.

var director: Node = null

func _process(_delta: float) -> void:
	if director != null and is_instance_valid(director):
		director.late()
