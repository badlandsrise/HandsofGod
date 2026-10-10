extends SceneTree
## Bakes the villager AnimationLibrary from the Quaternius Universal Animation Library
## (UAL1 and UAL2, the same 65-bone skeleton as the base bodies).
##   godot --headless --path . -s res://scripts/assets/tools/build_villager_anims.gd
## Output: res://assets/models/characters/anims/villager_anims.res, with one animation per
## VillagerVisual state (idle, walk, the task clips, ...). Position tracks other than the
## pelvis and all scale tracks are dropped, so the clips fit both base bodies and the head
## can be scaled.
##
## Many task clips are authored here: a base clip (or a blend of two, legs from one and
## arms from another) is posed frame by frame on the male body, then arms are placed with
## two-bone IK, hands turned and fingers closed, the spine and head bent and legs knelt,
## and the result is baked back into plain rotation keys at 30 fps. Targets are in
## skeleton space (metres): the body faces +Z, up is +Y, its right hand is on -X.
## TaskAnims (scripts/assets/task_anims.gd) says which clip and props each job uses.

const UAL1 := "res://assets/models/characters/anims/UAL1_Standard.glb"
const UAL2 := "res://assets/models/characters/anims/UAL2_Standard.glb"
const BODY := "res://assets/models/characters/Superhero_Male_FullBody.gltf"
const OUT := "res://assets/models/characters/anims/villager_anims.res"
const SK := "Armature/Skeleton3D:"
const FPS := 30.0
const FINGERS := ["index", "middle", "ring", "pinky", "thumb"]
## Ground speed (m/s, on the 1.81 m male body) each locomotion clip is authored for, from
## the root motion of the UAL "_RM" exports. Stored on the clip as meta "ground_speed";
## VillagerVisual scales playback to the villager's real speed so feet do not slide.
const GROUND_SPEED := {&"walk": 0.975, &"run": 5.357, &"flee": 8.25, &"carry_walk": 0.65,
	&"push": 0.3, &"carry_log": 0.975, &"spear_walk": 0.975}

var _src: Dictionary = {}          # clip name -> Animation (UAL1, then UAL2)
var _body: Node3D
var sk: Skeleton3D
var B: Dictionary = {}             # bone name -> index
var _fist: Dictionary = {}         # finger bone index -> closed-fist local rotation
var _rest: Dictionary = {}         # bone index -> rest local rotation
var _feet: Dictionary = {}         # side -> foot global pose of the base layers this frame
var _thigh_len := 0.43
var _calf_len := 0.456


func _init() -> void:
	for path in [UAL1, UAL2]:
		var n := (load(path) as PackedScene).instantiate()
		var ap := n.get_node("AnimationPlayer") as AnimationPlayer
		var lib := ap.get_animation_library(&"")
		for a in lib.get_animation_list():
			if not _src.has(String(a)):
				_src[String(a)] = lib.get_animation(a)
		n.free()
	_body = (load(BODY) as PackedScene).instantiate() as Node3D
	root.add_child(_body)
	sk = _body.get_node("Armature/Skeleton3D") as Skeleton3D
	for i in sk.get_bone_count():
		B[sk.get_bone_name(i)] = i
		_rest[i] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	await process_frame
	_thigh_len = sk.get_bone_rest(B["calf_r"]).origin.length()
	_calf_len = sk.get_bone_rest(B["foot_r"]).origin.length()
	_capture_fist()
	var lib := AnimationLibrary.new()
	_add_basics(lib)
	_add_tasks(lib)
	for clip in GROUND_SPEED:
		lib.get_animation(clip).set_meta(&"ground_speed", GROUND_SPEED[clip])
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("villager anims: %d clips -> %s" % [lib.get_animation_list().size(), error_string(err)])
	_body.free()
	quit()


# ------------------------------------------------------------------ the library

func _add_basics(lib: AnimationLibrary) -> void:
	lib.add_animation(&"idle", _clip("Idle", true))
	lib.add_animation(&"idle_fold", _clip("Idle_FoldArms", true))
	lib.add_animation(&"walk", _clip("Walk", true))
	lib.add_animation(&"run", _clip("Jog_Fwd", true))
	lib.add_animation(&"flee", _clip("Sprint", true))
	lib.add_animation(&"push", _clip("Push", true))
	lib.add_animation(&"work", _clip("Fixing_Kneeling", true))
	lib.add_animation(&"build_kneel", _clip("Fixing_Kneeling", true))
	lib.add_animation(&"chop", _clip("TreeChopping", true))
	lib.add_animation(&"pickup", _clip("PickUp_Table", false))
	lib.add_animation(&"sit", _clip("Sitting_Idle", true))
	lib.add_animation(&"sit_talk", _clip("Sitting_Talking", true))
	lib.add_animation(&"talk", _clip("Idle_Talking", true))
	lib.add_animation(&"dance", _clip("Dance", true))
	lib.add_animation(&"dead", _clip("Death01", false))
	lib.add_animation(&"eat", _clip("Consume", true))
	lib.add_animation(&"gather", _clip("Farm_Harvest", true))
	lib.add_animation(&"harvest", _clip("Farm_Harvest", true))
	lib.add_animation(&"sow", _clip("Farm_PlantSeed", true))
	lib.add_animation(&"water", _clip("Farm_Watering", true))
	lib.add_animation(&"carry_walk", _clip("Walk_Carry", true))
	lib.add_animation(&"nod", _clip("Yes", true))
	# held: treading-water kicks read as dangling and flailing in the hand
	var held := _clip("Swim_Idle", true)
	_drop_track(held, "pelvis", Animation.TYPE_POSITION_3D)
	lib.add_animation(&"held", held)
	# fall: arms and legs flung out
	var fall := _clip("Jump", true)
	_drop_track(fall, "pelvis", Animation.TYPE_POSITION_3D)
	lib.add_animation(&"fall", fall)
	# cower and wave: base clips; VillagerPoseModifier layers the arms on top
	lib.add_animation(&"cower", _clip("Crouch_Idle", true))
	lib.add_animation(&"wave", _clip("Idle", true))
	# cheer: bouncing on the knees with both arms flung up and pumping
	lib.add_animation(&"cheer", _bake(1.0, [["Idle"]], _cheer))


func _add_tasks(lib: AnimationLibrary) -> void:
	# standing still with an armful: the arms of the carrying walk over the idle legs
	lib.add_animation(&"carry", _bake(2.0, [["Idle"], ["Walk_Carry", 0.6, _arm_bones()]], _carry_hold))
	# the two-person log carry: the log rides on the right shoulder, the right hand on top
	lib.add_animation(&"carry_log", _bake(_src["Walk"].length, [["Walk"]], _shoulder_log))
	lib.add_animation(&"carry_log_idle", _bake(2.5, [["Idle"]], _shoulder_log))
	lib.add_animation(&"pick", _bake(2.6, [["Idle"]], _pick))
	lib.add_animation(&"knap", _bake(1.8, [["Idle"]], _knap))
	lib.add_animation(&"tend", _bake(3.2, [["Idle"]], _tend))
	lib.add_animation(&"pray", _bake(4.0, [["Idle"]], _pray))
	lib.add_animation(&"hammer", _bake(1.1, [["Idle"]], _hammer))
	lib.add_animation(&"craft", _bake(1.6, [["Idle"]], _craft))
	lib.add_animation(&"dig", _bake(1.3, [["Idle"]], _dig))
	lib.add_animation(&"rope", _bake(1.6, [["Idle"]], _rope))
	lib.add_animation(&"fish", _bake(2.8, [["Idle"]], _fish))
	lib.add_animation(&"read", _bake(3.0, [["Idle"]], _read))
	lib.add_animation(&"lookout", _bake(5.0, [["Idle"]], _lookout))
	lib.add_animation(&"idle_hips", _bake(5.0, [["Idle"]], _hips))
	lib.add_animation(&"spear_walk", _bake(_src["Walk"].length, [["Walk"]], _spear_carry))
	lib.add_animation(&"spear_ready", _bake(2.4, [["Idle"]], _spear_ready))
	lib.add_animation(&"baby_sit", _bake(3.0, [["Sitting_Idle"]], _baby_sit))


# ------------------------------------------------------------------ authored poses
# Each runs once per baked frame with the time t and the loop phase u (0..1), after the
# base layers are applied.

func _cheer(_t: float, u: float) -> void:
	var s := sin(u * TAU * 2.0) * 0.06
	_pelvis(Vector3(0, -0.09 * (1.0 - absf(sin(u * TAU * 2.0))), 0.0))
	_plant()
	_ik_rel("r", Vector3(-0.2, 0.52 + s, 0.08))
	_ik_rel("l", Vector3(0.2, 0.52 - s, 0.08))
	_hand("r", Vector3(-0.2, 1, 0.1), Vector3(0, 0.2, 1))
	_hand("l", Vector3(0.2, 1, 0.1), Vector3(0, 0.2, 1))
	_open("r", 0.6)
	_open("l", 0.6)
	_head(-0.25, 0.0)


func _carry_hold(_t: float, _u: float) -> void:
	_grip("r", 0.35)
	_grip("l", 0.35)


func _shoulder_log(_t: float, u: float) -> void:
	_head(0.05, 0.12)
	var bob := sin(u * TAU * 2.0) * 0.01
	_ik_rel("r", Vector3(0.02, 0.2 + bob, 0.06), Vector3(-1, -0.4, -0.3))
	_hand("r", Vector3(0.6, 0.1, 0.8), Vector3(0, -1, 0))
	_grip("r", 0.6)


## Crouched before a bush: the left hand holds a basket at the knee, the right hand
## reaches in, plucks and drops the berry in the basket; twice a loop.
func _pick(_t: float, u: float) -> void:
	_squat(0.9)
	_spine(0.5)
	var basket := Vector3(0.24, 0.52, 0.28)
	_ik("l", basket + Vector3(0.0, 0.1, 0.0), Vector3(1, -0.2, -0.4))
	_hand("l", Vector3(-0.2, -0.6, 1), Vector3(-0.3, 1, 0))
	_grip("l", 0.75)
	var h := fmod(u * 2.0, 1.0)
	var reach := Vector3(-0.2, 0.86, 0.62) if u < 0.5 else Vector3(-0.02, 0.7, 0.64)
	var drop := basket + Vector3(-0.04, 0.16, 0.02)
	var p: Vector3
	if h < 0.35:
		p = drop.lerp(reach, _ease(h / 0.35))
	elif h < 0.55:
		var k := (h - 0.35) / 0.2
		p = reach + Vector3(0, -0.03 * sin(k * PI), -0.06 * sin(k * PI))   # pluck
	elif h < 0.85:
		p = reach.lerp(drop, _ease((h - 0.55) / 0.3))
	else:
		p = drop
	_ik("r", p, Vector3(-1, -0.6, -0.2))
	var to_reach := h < 0.6
	_hand("r", Vector3(0.0, 0.1, 1) if to_reach else Vector3(0.5, -0.7, 0.3), Vector3(0.3, -1, 0.1))
	_grip("r", 0.25 if h < 0.35 else 0.75)
	_head(0.15 if to_reach else 0.4, 0.05 if to_reach else -0.3)


## Knelt back on the heels, a flint core held on the ground in the left hand, the
## right hand raising a hammerstone and striking: two blows a loop.
func _knap(_t: float, u: float) -> void:
	_kneel(0.1)
	_spine(0.62)
	_head(0.4, 0.0)
	var core := Vector3(0.03, 0.2, 0.42)
	_ik("l", core + Vector3(0.08, 0.05, -0.02), Vector3(1, 0, -0.6))
	_hand("l", Vector3(-0.4, -0.3, 1), Vector3(0, 1, 0.2))
	_grip("l", 0.8)
	var h := fmod(u * 2.0, 1.0)
	var up := Vector3(-0.2, 0.86, 0.34)
	var hit := core + Vector3(-0.07, 0.08, 0.0)
	var p: Vector3
	if h < 0.55:
		p = hit.lerp(up, _ease_out(h / 0.55))
	elif h < 0.68:
		p = up.lerp(hit, pow((h - 0.55) / 0.13, 2.0))
	else:
		p = hit + Vector3(0, 0.03 * sin((h - 0.68) / 0.32 * PI), 0)
	_ik("r", p, Vector3(-1, 0.2, -0.6))
	_hand("r", Vector3(0.3, -0.4, 1), Vector3(0.3, -1, 0))
	_grip("r", 0.9)


## Crouched at the fire, feeding a stick in and poking the embers; the left hand on the knee.
func _tend(_t: float, u: float) -> void:
	_squat(0.95)
	_spine(0.62)
	_ik("l", Vector3(0.2, 0.6, 0.4), Vector3(1, 0, -0.5))
	_hand("l", Vector3(-0.2, -0.7, 1), Vector3(0, 1, 0))
	_grip("l", 0.3)
	var rest := Vector3(-0.22, 0.6, 0.38)
	var fire := Vector3(-0.08, 0.26, 0.8)
	var p: Vector3
	if u < 0.3:
		p = rest.lerp(fire, _ease(u / 0.3))
	elif u < 0.7:
		p = fire + Vector3(0, 0.03, -0.1) * absf(sin((u - 0.3) / 0.4 * PI * 2.0))
	else:
		p = fire.lerp(rest, _ease((u - 0.7) / 0.3))
	_ik("r", p, Vector3(-1, -0.3, -0.3))
	_hand("r", Vector3(0.1, -0.5, 1), Vector3(0.6, -0.3, -0.4))
	_grip("r", 0.9)
	_head(0.35, 0.0)


## Knelt upright, both hands raised to the sky, rising and falling with each breath, then
## a slow bow.
func _pray(_t: float, u: float) -> void:
	var bow := _smooth_pulse(u, 0.55, 0.92)
	_kneel(1.0 - bow * 0.6)
	_spine(-0.1 + bow * 0.75)
	var lift := sin(u * TAU) * 0.025
	var up_r := _shoulder("r") + Vector3(0.04, 0.24 + lift, 0.3)
	var up_l := _shoulder("l") + Vector3(-0.04, 0.24 + lift, 0.3)
	var down_r := Vector3(-0.14, 0.12, 0.62)
	var down_l := Vector3(0.14, 0.12, 0.62)
	_ik("r", up_r.lerp(down_r, bow), Vector3(-1, -0.8, 0))
	_ik("l", up_l.lerp(down_l, bow), Vector3(1, -0.8, 0))
	_hand("r", Vector3(0.05, 1, 0.25).lerp(Vector3(0, -0.1, 1), bow), Vector3(0.2, 0.0, 1).lerp(Vector3(0, -1, 0), bow))
	_hand("l", Vector3(-0.05, 1, 0.25).lerp(Vector3(0, -0.1, 1), bow), Vector3(-0.2, 0.0, 1).lerp(Vector3(0, -1, 0), bow))
	_open("r", 0.85)
	_open("l", 0.85)
	_head(-0.4 + bow * 0.9, 0.0)


## Standing at the work, a mallet in the right hand striking down on a peg the left hand holds.
func _hammer(_t: float, u: float) -> void:
	_pelvis(Vector3(0, -0.04, 0))
	_plant()
	_spine(0.22)
	_head(0.4, 0.0)
	var peg := Vector3(0.0, 0.8, 0.5)
	_ik("l", peg + Vector3(0.09, 0.02, -0.02), Vector3(1, -0.3, -0.6))
	_hand("l", Vector3(-0.5, -0.3, 1), Vector3(0, 0.2, 0.2))
	_grip("l", 0.8)
	var up := Vector3(-0.26, 1.62, 0.12)
	var hit := peg + Vector3(-0.08, 0.1, -0.02)
	var p: Vector3
	if u < 0.5:
		p = hit.lerp(up, _ease_out(u / 0.5))
	elif u < 0.62:
		p = up.lerp(hit, pow((u - 0.5) / 0.12, 2.0))
	else:
		p = hit + Vector3(0, 0.04 * sin((u - 0.62) / 0.38 * PI), 0)
	_ik("r", p, Vector3(-1, -0.2, -0.5))
	_hand("r", Vector3(0, -0.2, 1).lerp(Vector3(0, 0.6, 1), clampf((p.y - hit.y) / (up.y - hit.y), 0, 1)), Vector3(0.6, 0, -0.2))
	_grip("r", 0.9)


## Working at a bench at hip height: both hands busy, kneading, shaping, whittling.
func _craft(_t: float, u: float) -> void:
	_spine(0.18)
	_head(0.5, -0.05)
	var a := u * TAU
	var r := Vector3(-0.13, 0.98, 0.42) + Vector3(cos(a) * 0.05, sin(a * 2.0) * 0.025, sin(a) * 0.05)
	var l := Vector3(0.12, 0.97, 0.4) + Vector3(-cos(a + 1.4) * 0.04, sin(a * 2.0 + 1.0) * 0.02, sin(a + 1.4) * 0.04)
	_ik("r", r, Vector3(-1, -0.4, -0.3))
	_ik("l", l, Vector3(1, -0.4, -0.3))
	_hand("r", Vector3(0.3, -0.5, 1), Vector3(0.1, -1, 0))
	_hand("l", Vector3(-0.3, -0.5, 1), Vector3(-0.1, -1, 0))
	_grip("r", 0.55 + sin(a) * 0.2)
	_grip("l", 0.45)


## A pick or spade swung overhead and driven down into the ground.
func _dig(_t: float, u: float) -> void:
	var down := 0.0
	var p: Vector3
	var up := Vector3(-0.12, 1.75, 0.08)
	var hit := Vector3(-0.06, 0.62, 0.62)
	if u < 0.5:
		p = hit.lerp(up, _ease_out(u / 0.5))
		down = 1.0 - _ease_out(u / 0.5)
	elif u < 0.64:
		var k := pow((u - 0.5) / 0.14, 2.0)
		p = up.lerp(hit, k)
		down = k
	else:
		p = hit
		down = 1.0
	_pelvis(Vector3(0, -0.05 * down, 0))
	_plant()
	_spine(-0.05 + 0.45 * down)
	_head(0.15 + 0.3 * down, 0.0)
	_ik("r", p, Vector3(-1, -0.3, -0.4))
	_hand("r", Vector3(0, 0.3, 1).lerp(Vector3(0, -0.6, 0.6), down), Vector3(0.9, 0.0, 0.2))
	_grip("r", 0.95)
	var axis := _hand_thumb("r")
	_ik("l", p + axis * 0.22 + Vector3(0.05, 0, 0), Vector3(1, -0.3, -0.4))
	_hand("l", Vector3(0, 0.3, 1).lerp(Vector3(0, -0.6, 0.6), down), Vector3(0.9, 0.0, 0.2))
	_grip("l", 0.95)


## Hand over hand on a rope (raising a roof, a bridge timber; drawing up the well bucket).
func _rope(_t: float, u: float) -> void:
	_pelvis(Vector3(0, -0.06, -0.04))
	_plant()
	_spine(-0.15)
	_head(-0.2, 0.0)
	var a := u * TAU
	var hr := 0.5 + 0.5 * sin(a)
	var hl := 0.5 + 0.5 * sin(a + PI)
	_ik("r", Vector3(-0.04, lerpf(1.0, 1.55, hr), lerpf(0.3, 0.42, hr)), Vector3(-1, -0.5, -0.4))
	_ik("l", Vector3(0.04, lerpf(1.0, 1.55, hl), lerpf(0.3, 0.42, hl)), Vector3(1, -0.5, -0.4))
	_hand("r", Vector3(0.1, 1, 0.3), Vector3(0, 0, 1))
	_hand("l", Vector3(-0.1, 1, 0.3), Vector3(0, 0, 1))
	_grip("r", 0.95)
	_grip("l", 0.95)


## Crouched at the water's edge, hands in the stream, a sudden grab now and then.
func _fish(_t: float, u: float) -> void:
	_squat(1.0)
	_spine(0.75)
	_head(0.4, 0.0)
	var grab := _smooth_pulse(u, 0.55, 0.85)
	var r := Vector3(-0.12, 0.1, 0.62).lerp(Vector3(-0.08, 0.6, 0.45), grab)
	var l := Vector3(0.12, 0.1, 0.62).lerp(Vector3(0.08, 0.6, 0.45), grab)
	r.x += sin(u * TAU * 3.0) * 0.03 * (1.0 - grab)
	_ik("r", r, Vector3(-1, 0, -0.4))
	_ik("l", l, Vector3(1, 0, -0.4))
	_hand("r", Vector3(0.1, -1, 0.5).lerp(Vector3(0.4, 0.4, 0.6), grab), Vector3(0.8, 0, 0))
	_hand("l", Vector3(-0.1, -1, 0.5).lerp(Vector3(-0.4, 0.4, 0.6), grab), Vector3(-0.8, 0, 0))
	_grip("r", 0.2 + 0.7 * grab)
	_grip("l", 0.2 + 0.7 * grab)


## Standing with an open book (or a chart) in both hands; a page turns now and then.
func _read(_t: float, u: float) -> void:
	_head(0.55, 0.0)
	_spine(0.05)
	var turn := _smooth_pulse(u, 0.7, 0.95)
	var l := Vector3(0.09, 1.08, 0.33)
	var r := Vector3(-0.1, 1.08, 0.33).lerp(Vector3(0.04, 1.14, 0.35), turn)
	_ik("l", l, Vector3(1, -0.7, -0.2))
	_ik("r", r, Vector3(-1, -0.7, -0.2))
	_hand("l", Vector3(0.2, 0.3, 1), Vector3(-0.5, 0.8, 0))
	_hand("r", Vector3(-0.2, 0.3, 1), Vector3(0.5, 0.8, 0))
	_grip("l", 0.35)
	_grip("r", 0.35)


## Keeping watch: a hand shading the eyes, looking slowly from side to side.
func _lookout(_t: float, u: float) -> void:
	var yaw := sin(u * TAU) * 0.55
	_head(-0.08, yaw)
	var hd := sk.get_bone_global_pose(B["Head"])
	var target := hd * Vector3(-0.02, 0.1, 0.14)
	_ik("r", target, Vector3(-1, -0.2, 0))
	_hand("r", hd.basis * Vector3(0.9, 0.0, 0.4), hd.basis * Vector3(0, -0.5, -1))
	_open("r", 0.7)
	var hip := Vector3(0.2, 0.98, -0.02)
	_ik("l", hip, Vector3(1, 0.2, -1))
	_hand("l", Vector3(-0.2, -1, 0.3), Vector3(-1, 0, 0))
	_grip("l", 0.5)


## Hands on hips, looking about.
func _hips(_t: float, u: float) -> void:
	_head(0.0, sin(u * TAU) * 0.4)
	_ik("r", Vector3(-0.27, 1.12, -0.04), Vector3(-1, 0, -0.4))
	_ik("l", Vector3(0.27, 1.12, -0.04), Vector3(1, 0, -0.4))
	_hand("r", Vector3(0.25, -0.7, 0.6), Vector3(1, 0, 0))
	_hand("l", Vector3(-0.25, -0.7, 0.6), Vector3(-1, 0, 0))
	_grip("r", 0.5)
	_grip("l", 0.5)


## Walking with a spear held up by the ear, point forward.
## Walking out to hunt: the spear held upright at the side, leaning forward, the fist
## thumb-up round the shaft (a held prop's handle runs out of the thumb side of the fist).
func _spear_carry(_t: float, u: float) -> void:
	var bob := sin(u * TAU * 2.0) * 0.02
	_ik_rel("r", Vector3(-0.1, -0.43 + bob, 0.16), Vector3(-0.4, -0.6, -1))
	_hand("r", Vector3(0, -0.25, 1), Vector3(1, 0, 0))
	_grip("r", 0.95)


## The hunter's stance: low, leaning in, the spear levelled forward from the right hip,
## the left hand further up the shaft.
func _spear_ready(_t: float, u: float) -> void:
	var s := sin(u * TAU) * 0.02
	_pelvis(Vector3(0, -0.12 + s, -0.04))
	_plant()
	_spine(0.22)
	_head(-0.2, 0.0)
	var fr := Vector3(0, -1, 0.3).normalized()
	_ik_rel("r", Vector3(-0.06, -0.42 + s, 0.12), Vector3(-1, -0.5, -0.6))
	_hand("r", fr, Vector3(1, 0, 0))
	_grip("r", 0.95)
	# along the shaft: out of the right fist's thumb side
	var rh := sk.get_bone_global_pose(B["hand_r"]).origin
	var shaft := Vector3(0, 0.3, 1).normalized()
	var on_shaft := rh + fr * 0.085 + Vector3(1, 0, 0) * 0.035 + shaft * 0.42
	var fl := Vector3(0, -1, 0.3).normalized()
	_ik("l", on_shaft - fl * 0.085 - Vector3(-1, 0, 0) * 0.035, Vector3(1, -0.8, -0.3))
	_hand("l", fl, Vector3(-1, 0, 0))
	_grip("l", 0.95)


## A baby sat on the ground, legs out in front, rocking a little.
func _baby_sit(_t: float, u: float) -> void:
	var rock := sin(u * TAU) * 0.06
	_pelvis_to(Vector3(0, 0.15, -0.1))
	_spine(-0.15 + rock)
	_leg("r", Vector3(-0.08, 0, 1), Vector3(-0.02, -0.05, 1), Vector3(0, 1, 0.3))
	_leg("l", Vector3(0.08, 0, 1), Vector3(0.02, -0.05, 1), Vector3(0, 1, 0.3))
	_ik("r", Vector3(-0.18, 0.1, 0.3), Vector3(-1, 0, -0.3))
	_ik("l", Vector3(0.18, 0.1, 0.3), Vector3(1, 0, -0.3))
	_hand("r", Vector3(-0.1, -0.5, 1), Vector3(0, 1, 0))
	_hand("l", Vector3(0.1, -0.5, 1), Vector3(0, 1, 0))
	_head(0.1, rock * 2.0)


# ------------------------------------------------------------------ baking

## Bakes a clip of `length` seconds: each frame applies the layers ([clip, speed?,
## bones?] in order: later layers override the listed bones), runs `fn(t, u)`, and
## records every bone's local rotation and the pelvis position.
func _bake(length: float, layers: Array, fn: Callable, loop := true) -> Animation:
	var out := Animation.new()
	out.length = length
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var rot_tracks := {}
	for name in B:
		if String(name) == "root":
			continue
		var ti := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(ti, NodePath(SK + String(name)))
		rot_tracks[B[name]] = ti
	var pos_ti := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(pos_ti, NodePath(SK + "pelvis"))
	var n := maxi(int(round(length * FPS)), 1)
	for k in n + 1:
		var t := length * float(k) / float(n)
		var u := float(k) / float(n)
		if k == n and loop:
			t = 0.0
			u = 0.0
		_apply_layers(layers, t)
		if fn.is_valid():
			fn.call(t, u)
		var key_t := length * float(k) / float(n)
		for bi in rot_tracks:
			out.rotation_track_insert_key(rot_tracks[bi], key_t, sk.get_bone_pose_rotation(bi))
		out.position_track_insert_key(pos_ti, key_t, sk.get_bone_pose_position(B["pelvis"]))
	return out


func _apply_layers(layers: Array, t: float) -> void:
	sk.reset_bone_poses()
	for layer in layers:
		var a: Animation = _src[layer[0]]
		var speed: float = layer[1] if layer.size() > 1 else 1.0
		var only: Array = layer[2] if layer.size() > 2 else []
		var lt := fmod(t * speed, a.length)
		for i in a.get_track_count():
			var bone := String(a.track_get_path(i).get_concatenated_subnames())
			if not B.has(bone):
				continue
			if not only.is_empty() and not (bone in only):
				continue
			var bi: int = B[bone]
			match a.track_get_type(i):
				Animation.TYPE_ROTATION_3D:
					sk.set_bone_pose_rotation(bi, a.rotation_track_interpolate(i, lt))
				Animation.TYPE_POSITION_3D:
					if bone == "pelvis":
						sk.set_bone_pose_position(bi, a.position_track_interpolate(i, lt))
	sk.force_update_all_bone_transforms()
	for side in ["r", "l"]:
		_feet[side] = sk.get_bone_global_pose(B["foot_" + side])


func _arm_bones() -> Array:
	var out: Array = []
	for side in ["l", "r"]:
		for b in ["clavicle", "upperarm", "lowerarm", "hand"]:
			out.append("%s_%s" % [b, side])
		for f in FINGERS:
			for j in range(1, 5):
				out.append("%s_0%d_%s" % [f, j, side])
	return out


func _capture_fist() -> void:
	var a: Animation = _src["TreeChopping"]
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(i).get_concatenated_subnames())
		for f in FINGERS:
			if bone.begins_with(f + "_") and bone.ends_with("_r"):
				_fist[B[bone]] = a.rotation_track_interpolate(i, 0.3)
				# the left hand mirrors the right (the rig's left bones are mirrored)
				var lb := bone.substr(0, bone.length() - 1) + "l"
				if B.has(lb):
					var q: Quaternion = _fist[B[bone]]
					var r: Quaternion = _rest[B[bone]]
					var lq: Quaternion = _rest[B[lb]]
					_fist[B[lb]] = lq * (r.inverse() * q)


# ------------------------------------------------------------------ posing helpers

func _shoulder(side: String) -> Vector3:
	return sk.get_bone_global_pose(B["upperarm_" + side]).origin


func _pelvis(offset: Vector3) -> void:
	var bi: int = B["pelvis"]
	var gp := sk.get_bone_global_pose(bi)
	gp.origin += offset
	sk.set_bone_global_pose(bi, gp)
	sk.force_update_all_bone_transforms()


func _pelvis_to(pos: Vector3) -> void:
	var bi: int = B["pelvis"]
	var gp := sk.get_bone_global_pose(bi)
	gp.origin = pos
	sk.set_bone_global_pose(bi, gp)
	sk.force_update_all_bone_transforms()


## Bends the spine forward (+) or back (-), spread over the three spine bones.
func _spine(pitch: float) -> void:
	for n in ["spine_01", "spine_02", "spine_03"]:
		_rotg(B[n], Vector3.RIGHT, pitch / 3.0)


## Tilts the head down (+ pitch) and turns it (+ yaw = toward its left).
func _head(pitch: float, yaw: float) -> void:
	_rotg(B["neck_01"], Vector3.UP, yaw * 0.4)
	_rotg(B["neck_01"], Vector3.RIGHT, pitch * 0.4)
	_rotg(B["Head"], Vector3.UP, yaw * 0.6)
	_rotg(B["Head"], Vector3.RIGHT, pitch * 0.6)


func _rotg(bi: int, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.00001:
		return
	var gp := sk.get_bone_global_pose(bi)
	gp.basis = Basis(axis.normalized(), angle) * gp.basis
	sk.set_bone_global_pose(bi, gp)
	sk.force_update_all_bone_transforms()


## Turns `bone` so the direction to its child points along `dir` (skeleton space).
func _aim(bone: String, child: String, dir: Vector3) -> void:
	var bi: int = B[bone]
	var ci: int = B[child]
	var gp := sk.get_bone_global_pose(bi)
	var cur := (gp.basis * sk.get_bone_rest(ci).origin).normalized()
	var want := dir.normalized()
	if cur.dot(want) > 0.99999:
		return
	var axis := cur.cross(want)
	if axis.length() < 0.00001:
		axis = Vector3.UP
	gp.basis = Basis(axis.normalized(), cur.angle_to(want)) * gp.basis
	sk.set_bone_global_pose(bi, gp)
	sk.force_update_all_bone_transforms()


## Two-bone IK: puts the wrist of `side` ("r"/"l") at `target`, the elbow bending
## toward `pole`.
func _ik(side: String, target: Vector3, pole: Vector3 = Vector3.ZERO) -> void:
	var ua := "upperarm_" + side
	var la := "lowerarm_" + side
	var hd := "hand_" + side
	if pole == Vector3.ZERO:
		pole = Vector3(-1 if side == "r" else 1, -0.5, -0.5)
	var s := sk.get_bone_global_pose(B[ua]).origin
	var l1 := sk.get_bone_rest(B[la]).origin.length()
	var l2 := sk.get_bone_rest(B[hd]).origin.length()
	var d := target - s
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	var dn := d.normalized()
	var a := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pd := pole.normalized() - dn * pole.normalized().dot(dn)
	if pd.length() < 0.001:
		pd = Vector3.DOWN
	var elbow := s + dn * a + pd.normalized() * h
	_aim(ua, la, elbow - s)
	var e := sk.get_bone_global_pose(B[la]).origin
	_aim(la, hd, s + dn * dist - e)


## IK with the target given relative to the shoulder.
func _ik_rel(side: String, offset: Vector3, pole: Vector3 = Vector3.ZERO) -> void:
	_ik(side, _shoulder(side) + offset, pole)


## Turns the hand so the fingers point along `fwd` and the palm faces `palm`.
func _hand(side: String, fwd: Vector3, palm: Vector3) -> void:
	var hb: int = B["hand_" + side]
	var gp := sk.get_bone_global_pose(hb)
	var f := (gp.basis * sk.get_bone_rest(B["middle_01_" + side]).origin).normalized()
	var thumb_now := _hand_thumb(side)
	var want_f := fwd.normalized()
	var p := palm.normalized()
	# thumb direction for a palm normal: right hand fwd x palm, left hand palm x fwd
	var want_t := (want_f.cross(p) if side == "r" else p.cross(want_f))
	if want_t.length() < 0.001:
		return
	want_t = want_t.normalized()
	var cur := Basis(f, thumb_now, f.cross(thumb_now).normalized()).orthonormalized()
	var want := Basis(want_f, want_t, want_f.cross(want_t).normalized()).orthonormalized()
	gp.basis = (want * cur.inverse()).orthonormalized() * gp.basis
	sk.set_bone_global_pose(hb, gp)
	sk.force_update_all_bone_transforms()


## Unit vector across the palm toward the thumb side (index knuckle minus little knuckle).
func _hand_thumb(side: String) -> Vector3:
	var hb: int = B["hand_" + side]
	var gp := sk.get_bone_global_pose(hb)
	var f := (gp.basis * sk.get_bone_rest(B["middle_01_" + side]).origin).normalized()
	var t := gp.basis * (sk.get_bone_rest(B["index_01_" + side]).origin - sk.get_bone_rest(B["pinky_01_" + side]).origin)
	return (t - f * t.dot(f)).normalized()


## Closes the fingers of a hand toward a fist (amount 0..1).
func _grip(side: String, amount: float) -> void:
	for f in FINGERS:
		for j in range(1, 4):
			var bn := "%s_0%d_%s" % [f, j, side]
			if not B.has(bn):
				continue
			var bi: int = B[bn]
			if not _fist.has(bi):
				continue
			var q := sk.get_bone_pose_rotation(bi)
			sk.set_bone_pose_rotation(bi, q.slerp(_fist[bi], clampf(amount, 0.0, 1.0)))
	sk.force_update_all_bone_transforms()


## Opens the fingers of a hand toward straight (amount 0..1).
func _open(side: String, amount: float) -> void:
	for f in FINGERS:
		for j in range(1, 4):
			var bn := "%s_0%d_%s" % [f, j, side]
			if not B.has(bn):
				continue
			var bi: int = B[bn]
			var q := sk.get_bone_pose_rotation(bi)
			sk.set_bone_pose_rotation(bi, q.slerp(_rest[bi], clampf(amount, 0.0, 1.0)))
	sk.force_update_all_bone_transforms()


## Kneels on both knees: upright 1 = upright on the knees, 0 = sat back on the heels.
func _kneel(upright: float) -> void:
	var th := deg_to_rad(lerpf(24.0, 86.0, upright))       # thigh angle below horizontal
	var hip_lift := sk.get_bone_global_pose(B["thigh_r"]).origin.y - sk.get_bone_global_pose(B["pelvis"]).origin.y
	var knee_y := 0.075
	var hip_y := knee_y + _thigh_len * sin(th)
	var pp := sk.get_bone_global_pose(B["pelvis"]).origin
	_pelvis_to(Vector3(pp.x, hip_y - hip_lift, lerpf(-0.18, -0.02, upright)))
	for side in ["r", "l"]:
		var sx := -1.0 if side == "r" else 1.0
		_leg(side, Vector3(sx * 0.12, -sin(th), cos(th)), Vector3(sx * 0.02, -0.03, -1), Vector3(0, -0.15, -1))


## Two-bone IK for a leg: the ankle to `ankle`, the knee bending toward `pole`.
func _leg_ik(side: String, ankle: Vector3, pole: Vector3) -> void:
	var th := "thigh_" + side
	var ca := "calf_" + side
	var fo := "foot_" + side
	var keep := sk.get_bone_global_pose(B[fo]).basis
	var h := sk.get_bone_global_pose(B[th]).origin
	var l1 := _thigh_len
	var l2 := _calf_len
	var d := ankle - h
	var dist := clampf(d.length(), 0.05, l1 + l2 - 0.002)
	var dn := d.normalized()
	var a := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * dist)
	var hh := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pd := pole.normalized() - dn * pole.normalized().dot(dn)
	if pd.length() < 0.001:
		pd = Vector3.FORWARD
	var knee := h + dn * a + pd.normalized() * hh
	_aim(th, ca, knee - h)
	var k := sk.get_bone_global_pose(B[ca]).origin
	_aim(ca, fo, h + dn * dist - k)
	# the foot keeps the orientation it had (flat on the ground)
	var gp := sk.get_bone_global_pose(B[fo])
	gp.basis = keep
	sk.set_bone_global_pose(B[fo], gp)
	sk.force_update_all_bone_transforms()


## Puts both feet back where the base layers had them (after the pelvis moved).
func _plant() -> void:
	for side in ["r", "l"]:
		var sx := -1.0 if side == "r" else 1.0
		var f: Transform3D = _feet[side]
		_leg_ik(side, f.origin, Vector3(sx * 0.3, 0, 1))
		var gp := sk.get_bone_global_pose(B["foot_" + side])
		gp.basis = f.basis
		sk.set_bone_global_pose(B["foot_" + side], gp)
	sk.force_update_all_bone_transforms()


## A deep, even squat (heels down, knees forward and out); depth 0..1.
func _squat(depth: float) -> void:
	var pp := sk.get_bone_global_pose(B["pelvis"]).origin
	_pelvis_to(Vector3(0, lerpf(0.86, 0.5, depth), lerpf(pp.z, -0.16, depth)))
	for side in ["r", "l"]:
		var sx := -1.0 if side == "r" else 1.0
		var f: Transform3D = _feet[side]
		var at := Vector3(sx * 0.17, f.origin.y, 0.02)
		_leg_ik(side, at, Vector3(sx * 0.45, 0, 1))
		var gp := sk.get_bone_global_pose(B["foot_" + side])
		gp.basis = f.basis.rotated(Vector3.UP, -sx * 0.25)
		sk.set_bone_global_pose(B["foot_" + side], gp)
	sk.force_update_all_bone_transforms()


## Points the thigh, calf and foot of a leg along the given directions.
func _leg(side: String, thigh: Vector3, calf: Vector3, foot: Vector3) -> void:
	_aim("thigh_" + side, "calf_" + side, thigh)
	_aim("calf_" + side, "foot_" + side, calf)
	_aim("foot_" + side, "ball_" + side, foot)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


## 0 outside [a, b], rising and falling smoothly to 1 in the middle of it.
func _smooth_pulse(u: float, a: float, b: float) -> float:
	if u <= a or u >= b:
		return 0.0
	return sin((u - a) / (b - a) * PI)


# ------------------------------------------------------------------ source clips

func _clip(src_name: String, loop: bool) -> Animation:
	var a := (_src[src_name] as Animation).duplicate(true) as Animation
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
