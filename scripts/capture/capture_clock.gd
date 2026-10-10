extends Node
## [capture] Runs straight after Clock (Clock.process_priority is lowered in
## capture mode) and replaces its wall-clock real_delta with this frame's
## engine step, so the hand, the camera rig, the HUD and the goodbye move by
## exactly 1/fps per frame under Movie Maker's --fixed-fps.

var director: Node = null

func _process(delta: float) -> void:
	if director != null and is_instance_valid(director):
		Clock.real_delta = director.unscaled(delta)
