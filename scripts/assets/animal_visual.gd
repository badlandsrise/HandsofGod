extends Node3D
## Root script for rigged animal visuals (Quaternius Farm Animals): plays a loop on spawn
## and maps simple states onto whatever clips the model has.
##   play(&"idle" | &"walk" | &"run" | &"eat" | &"dead")
## Placeholder animals (deer, wolf, bear) have no rig; play() is then a no-op.

var _ap: AnimationPlayer


func _ready() -> void:
	var found := find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		_ap = found[0]
	play(&"idle")


func play(state: StringName) -> void:
	if _ap == null:
		return
	var want := {&"idle": ["Idle", "Eating"], &"walk": ["Walk"], &"run": ["Gallop", "Run", "Walk"],
		&"eat": ["Eating", "Idle"], &"dead": ["Death"]}
	for key in want.get(state, ["Idle"]):
		for a in _ap.get_animation_list():
			if String(a).ends_with(key):
				var anim := _ap.get_animation(a)
				anim.loop_mode = Animation.LOOP_NONE if key == "Death" else Animation.LOOP_LINEAR
				_ap.play(a)
				return
