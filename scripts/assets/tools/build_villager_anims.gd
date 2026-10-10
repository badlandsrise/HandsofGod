extends SceneTree
## Bakes the villager AnimationLibrary from the Quaternius Universal Animation Library.
##   godot --headless --path . -s res://scripts/assets/tools/build_villager_anims.gd
## Output: res://assets/models/characters/anims/villager_anims.res, with one animation per
## VillagerVisual state (idle, walk, ...). Position tracks other than the pelvis and all
## scale tracks are dropped, so the clips fit both base bodies and the head can be scaled.
## cheer adds a hop to the jump pose; the arm layers of wave / cheer / cower come from
## VillagerPoseModifier at runtime.

const UAL := "res://assets/models/characters/anims/UAL1_Standard.glb"
const OUT := "res://assets/models/characters/anims/villager_anims.res"
const SK := "Armature/Skeleton3D:"

var _src: AnimationLibrary


func _init() -> void:
	var n := (load(UAL) as PackedScene).instantiate()
	var ap := n.get_node("AnimationPlayer") as AnimationPlayer
	_src = ap.get_animation_library(&"")
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _clip("Idle", true))
	lib.add_animation(&"walk", _clip("Walk", true))
	lib.add_animation(&"run", _clip("Jog_Fwd", true))
	lib.add_animation(&"flee", _clip("Sprint", true))
	lib.add_animation(&"carry", _clip("Push", true))
	lib.add_animation(&"work", _clip("Fixing_Kneeling", true))
	lib.add_animation(&"chop", _clip("Sword_Attack", true))
	lib.add_animation(&"pickup", _clip("PickUp_Table", false))
	lib.add_animation(&"sit", _clip("Sitting_Idle", true))
	lib.add_animation(&"talk", _clip("Idle_Talking", true))
	lib.add_animation(&"dance", _clip("Dance", true))
	lib.add_animation(&"dead", _clip("Death01", false))
	# held: treading-water kicks read as dangling and flailing in the hand
	var held := _clip("Swim_Idle", true)
	_drop_track(held, "pelvis", Animation.TYPE_POSITION_3D)
	lib.add_animation(&"held", held)
	# fall: arms and legs flung out
	var fall := _clip("Jump", true)
	_drop_track(fall, "pelvis", Animation.TYPE_POSITION_3D)
	lib.add_animation(&"fall", fall)
	# cower, wave and cheer: base clips; VillagerPoseModifier layers the arms on top
	# (hands over head, a waving arm, both arms up), since the library has no such clips.
	lib.add_animation(&"cower", _clip("Crouch_Idle", true))
	lib.add_animation(&"wave", _clip("Idle", true))
	var cheer := _clip("Jump", true)
	_drop_track(cheer, "pelvis", Animation.TYPE_POSITION_3D)
	_bounce(cheer, "pelvis", 0.18)
	lib.add_animation(&"cheer", cheer)
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("villager anims: %d clips -> %s" % [lib.get_animation_list().size(), error_string(err)])
	n.free()
	quit()


func _clip(src_name: String, loop: bool) -> Animation:
	var a := (_src.get_animation(StringName(src_name)) as Animation).duplicate(true) as Animation
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for i in range(a.get_track_count() - 1, -1, -1):
		var t := a.track_get_type(i)
		var bone := String(a.track_get_path(i).get_concatenated_subnames())
		if t == Animation.TYPE_SCALE_3D or (t == Animation.TYPE_POSITION_3D and bone != "pelvis"):
			a.remove_track(i)
	return a


func _find(a: Animation, bone: String, type: int) -> int:
	return a.find_track(NodePath(SK + bone), type)


func _drop_track(a: Animation, bone: String, type: int) -> void:
	var i := _find(a, bone, type)
	if i >= 0:
		a.remove_track(i)


## Adds a vertical hop to a bone's position track (or makes one from its rest).
func _bounce(a: Animation, bone: String, height: float) -> void:
	var i := _find(a, bone, Animation.TYPE_POSITION_3D)
	var base := Vector3(0, 0.95, 0)
	var skel := ((load("res://assets/models/characters/Superhero_Male_FullBody.gltf") as PackedScene).instantiate())
	var sk := skel.get_node("Armature/Skeleton3D") as Skeleton3D
	base = sk.get_bone_rest(sk.find_bone(bone)).origin
	skel.free()
	if i >= 0:
		a.remove_track(i)
	i = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(i, NodePath(SK + bone))
	var steps := 12
	for k in steps + 1:
		var t := a.length * k / steps
		var hop := absf(sin(PI * 2.0 * k / steps)) * height
		a.position_track_insert_key(i, t, base + Vector3(0, hop, 0))
