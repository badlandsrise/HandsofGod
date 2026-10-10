class_name VillagerPoseModifier
extends SkeletonModifier3D
## Runs after the AnimationPlayer each frame:
##  - scales the head bone (babies and children get bigger heads, adults a slightly big
##    "diorama" head) and bends the spine for elders,
##  - layers procedural arm poses the animation library lacks (wave, cheer, hands over
##    head), aimed in skeleton space so they work on any base body.

enum Arms { NONE, WAVE, CHEER, COVER_HEAD }

@export var head_scale: float = 1.0
@export_range(0.0, 0.6) var stoop: float = 0.0
@export var arms: Arms = Arms.NONE:
	set(v):
		if v != arms and v != Arms.NONE:
			_arms_target = v
		arms = v

var _head := -1
var _spine := -1
var _b := {}
var _t := 0.0
var _w := 0.0               # blend weight of the arm layer
var _arms_target: Arms = Arms.NONE


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _head < 0:
		_head = sk.find_bone("Head")
		_spine = sk.find_bone("spine_02")
		for n in ["upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l"]:
			_b[n] = sk.find_bone(n)
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	_t += dt
	if _spine >= 0 and stoop > 0.0:
		var q := sk.get_bone_pose_rotation(_spine)
		sk.set_bone_pose_rotation(_spine, q * Quaternion(Vector3.RIGHT, stoop))
	if _head >= 0:
		sk.set_bone_pose_scale(_head, Vector3.ONE * head_scale)
	_w = move_toward(_w, 1.0 if arms != Arms.NONE else 0.0, dt * 5.0)
	if _w <= 0.0 or _b.get("upperarm_r", -1) < 0:
		return
	# skeleton space: the body faces +Z, its right hand is on -X
	match _arms_target:
		Arms.WAVE:
			var s := sin(_t * 9.0)
			_aim(sk, "upperarm_r", "lowerarm_r", Vector3(-0.75, 0.62, 0.2))
			_aim(sk, "lowerarm_r", "hand_r", Vector3(-0.25 + s * 0.45, 1.0, 0.15))
		Arms.CHEER:
			var s := sin(_t * 7.0) * 0.12
			_aim(sk, "upperarm_r", "lowerarm_r", Vector3(-0.45, 1.0, 0.1 + s))
			_aim(sk, "lowerarm_r", "hand_r", Vector3(-0.2, 1.0, 0.05))
			_aim(sk, "upperarm_l", "lowerarm_l", Vector3(0.45, 1.0, 0.1 - s))
			_aim(sk, "lowerarm_l", "hand_l", Vector3(0.2, 1.0, 0.05))
		Arms.COVER_HEAD:
			_aim(sk, "upperarm_r", "lowerarm_r", Vector3(-0.55, 0.55, 0.55))
			_aim(sk, "lowerarm_r", "hand_r", Vector3(0.75, 0.55, -0.2))
			_aim(sk, "upperarm_l", "lowerarm_l", Vector3(0.55, 0.55, 0.55))
			_aim(sk, "lowerarm_l", "hand_l", Vector3(-0.75, 0.55, -0.2))


## Rotate `bone` (in skeleton space) so the direction to `child` points along `dir`,
## blended by the layer weight.
func _aim(sk: Skeleton3D, bone: String, child: String, dir: Vector3) -> void:
	var bi: int = _b[bone]
	var ci: int = _b[child]
	if bi < 0 or ci < 0:
		return
	var gp := sk.get_bone_global_pose(bi)
	var cur := (gp.basis * sk.get_bone_rest(ci).origin).normalized()
	var want := dir.normalized()
	if cur.dot(want) > 0.9999:
		return
	var q := Quaternion(cur, want)
	q = Quaternion.IDENTITY.slerp(q, _w)
	gp.basis = Basis(q) * gp.basis
	sk.set_bone_global_pose(bi, gp)
