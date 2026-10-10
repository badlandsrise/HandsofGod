class_name QuadrupedGait
extends SkeletonModifier3D
## Procedural four-legged motion for the wild animals (WildAnimalVisual): walk and gallop
## cycles, the attack lunge, grazing, looking about, a dangling struggle when the hand
## holds them, and lying dead. Runs after any AnimationPlayer; with `from_rest` it starts
## each frame from the rest pose (rigs with no clips of their own).
## Bones are given by index and moved in skeleton space; `fwd`, `up` and `side` (the
## animal's left) say which way the animal faces in that space.

enum Gait { IDLE, WALK, RUN }

## legs: [{upper, lower, foot (or -1), front: bool, left: bool, bend: 1.0 or -1.0 (which way
## the lower leg folds as it lifts)}]
var legs: Array = []
var spine: Array[int] = []      # hips first
var neck: Array[int] = []       # base first; the last one carries the head
var tail: Array[int] = []       # base first
var root_bone := -1             # moved for the body bob
var fwd := Vector3.BACK
var up := Vector3.UP
var side := Vector3.RIGHT
var size := 1.0                 # skeleton units per metre of animal height (bob, reach)
var from_rest := true

## how strongly each species swings (degrees) and bends
var swing_walk := 22.0
var swing_run := 42.0
var knee_walk := 30.0
var knee_run := 60.0

var gait: Gait = Gait.IDLE
var cycles := 1.0               # stride cycles per second
var flee := false
var graze := false
var held := false
var dead := false
var attack := 0.0               # 0 = none, else the lunge's progress 0..1 (set by the owner)

var _phase := 0.0
var _t := randf() * 50.0
var _w_walk := 0.0
var _w_run := 0.0
var _w_graze := 0.0
var _w_flee := 0.0
var _w_held := 0.0
var _w_dead := 0.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := get_process_delta_time() if is_inside_tree() else 0.016
	if from_rest:
		sk.reset_bone_poses()
	_t += dt
	_phase = fmod(_phase + dt * cycles, 1.0)
	var k := minf(dt * 6.0, 1.0)
	_w_walk = lerpf(_w_walk, 1.0 if gait == Gait.WALK else 0.0, k)
	_w_run = lerpf(_w_run, 1.0 if gait == Gait.RUN else 0.0, k)
	_w_graze = lerpf(_w_graze, 1.0 if graze and gait == Gait.IDLE else 0.0, minf(dt * 1.5, 1.0))
	_w_flee = lerpf(_w_flee, 1.0 if flee else 0.0, k)
	_w_held = lerpf(_w_held, 1.0 if held else 0.0, k)
	_w_dead = lerpf(_w_dead, 1.0 if dead else 0.0, minf(dt * 3.0, 1.0))
	var tau := TAU * _phase
	# ---- body: bob, the gallop's flex and the lunge
	var bob := (_w_walk * 0.012 * absf(sin(tau * 2.0)) + _w_run * 0.05 * sin(tau * 2.0 + 0.6)) * size
	var lunge := sin(clampf(attack, 0.0, 1.0) * PI)
	if root_bone >= 0:
		var gp := sk.get_bone_global_pose(root_bone)
		gp.origin += up * (bob - lunge * 0.06 * size) + fwd * lunge * 0.18 * size
		# lunge: the chest drops forward; dead: the body rolls onto its side
		gp.basis = Basis(side, deg_to_rad(10.0 * lunge)) * gp.basis
		sk.set_bone_global_pose(root_bone, gp)
	for i in spine.size():
		var flex := _w_run * deg_to_rad(5.0) * sin(tau + 0.8) * (1.0 if i == 0 else -0.6)
		_rot(sk, spine[i], side, flex)
	# ---- legs
	for leg in legs:
		var front: bool = leg["front"]
		var left: bool = leg["left"]
		var p_walk := (0.0 if not left else 0.5) + (0.25 if front else 0.0)        # 4-beat walk
		var p_run := (0.0 if left else 0.1) + (0.5 if front else 0.0)             # rotary gallop
		var a_walk := sin(tau + TAU * p_walk)
		var a_run := sin(tau + TAU * p_run)
		var swing := deg_to_rad(_w_walk * swing_walk * a_walk + _w_run * swing_run * a_run)
		# the leg lifts (bends) while it swings forward
		var lift_w := maxf(0.0, cos(tau + TAU * p_walk))
		var lift_r := maxf(0.0, cos(tau + TAU * p_run))
		var bend := deg_to_rad(_w_walk * knee_walk * lift_w + _w_run * knee_run * lift_r)
		# held by the hand: legs paddle slowly; dead: legs stiff and out
		swing += deg_to_rad(_w_held * 25.0 * sin(_t * 5.0 + (1.3 if left else 0.0) + (0.7 if front else 0.0)))
		bend += deg_to_rad(_w_held * 20.0)
		# lunging: forelegs reach out, hind legs drive back
		swing += deg_to_rad(lunge * (28.0 if front else -22.0))
		# the lower leg folds back as it lifts; the foot flicks forward again
		_rot(sk, leg["upper"], side, -swing)
		_rot(sk, leg["lower"], side, bend * float(leg.get("bend", 1.0)))
		if int(leg.get("foot", -1)) >= 0:
			_rot(sk, leg["foot"], side, -bend * float(leg.get("bend", 1.0)) * 0.6)
	# ---- neck and head: looking about, grazing, the flight and the snap of the bite
	if not neck.is_empty():
		var look := sin(_t * 0.37) * 0.5 + sin(_t * 0.91) * 0.25
		var idle_w := 1.0 - maxf(_w_walk, _w_run)
		var yaw := deg_to_rad(18.0 * look * idle_w * (1.0 - _w_graze))
		var pitch := deg_to_rad(_w_graze * 55.0 + _w_flee * 14.0 + lunge * 22.0 - _w_held * 10.0)
		pitch += deg_to_rad(_w_graze * 4.0 * sin(_t * 2.3))   # nibbling
		var n := float(neck.size())
		for b in neck:
			_rot(sk, b, up, yaw / n)
			_rot(sk, b, side, pitch / n)
	# ---- tail
	var tn := float(maxi(tail.size(), 1))
	for i in tail.size():
		var wag := sin(_t * (2.0 + 6.0 * _w_run) + i * 0.6) * deg_to_rad(10.0 + 8.0 * _w_run)
		_rot(sk, tail[i], up, wag / tn)
		_rot(sk, tail[i], side, -deg_to_rad(_w_flee * 25.0) / tn)   # tucked in flight
	# ---- dead: roll onto the side, legs out
	if _w_dead > 0.001 and root_bone >= 0:
		var gp := sk.get_bone_global_pose(root_bone)
		gp.basis = Basis(fwd, deg_to_rad(85.0 * _w_dead)) * gp.basis
		gp.origin -= up * 0.25 * size * _w_dead
		sk.set_bone_global_pose(root_bone, gp)


## Jump straight to the current gait and flags (no blending in): contact sheets, tests.
func settle(phase: float) -> void:
	_phase = phase
	_w_walk = 1.0 if gait == Gait.WALK else 0.0
	_w_run = 1.0 if gait == Gait.RUN else 0.0
	_w_graze = 1.0 if graze and gait == Gait.IDLE else 0.0
	_w_flee = 1.0 if flee else 0.0
	_w_held = 1.0 if held else 0.0
	_w_dead = 1.0 if dead else 0.0


## Rotate a bone about an axis through its own origin (skeleton space).
func _rot(sk: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.00001:
		return
	var gp := sk.get_bone_global_pose(bone)
	gp.basis = Basis(axis, angle) * gp.basis
	sk.set_bone_global_pose(bone, gp)
