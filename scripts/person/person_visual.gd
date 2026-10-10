class_name PersonVisual extends Node3D
## The look of a Person: wraps the rigged VillagerVisual (scenes/people/villager_visual.tscn)
## and maps the Person's poses onto its animation states. Lives under the Person as the
## child named "Visual". The Person calls apply_look() when its look or stage changes,
## set_task() when it takes or leaves a job, set_cargo() with what it carries and
## animate() every frame.
## Working, a person plays their job's own clip with its tools in hand (TaskAnims: berry
## picking, knapping, tending the fire, praying, ...); carrying, they hold a real armful of
## the resource (PropKit); idle, they shift between a few idle stances.

enum Pose { IDLE, WALK, WORK, HELD, WAVE, COWER, WATCH, POINT, REACH, PRAY, SLEEP, DEAD, CARRY, SIT, RUN, CHOP }

const VILLAGER_SCENE := preload("res://scenes/people/villager_visual.tscn")
const SKIN: Array[Color] = [Color("#e9c4a0"), Color("#d4a27a"), Color("#a8714c"), Color("#7a4e33"), Color("#5c3a26")]
const HAIR: Array[Color] = [Color("#1f1712"), Color("#3b2a1e"), Color("#6b4426"), Color("#a5763f"), Color("#7a2f1c")]
const CLOTH_IDLE := Color("#8a5a3b")
## Garment colour by job skill family, so a glance shows who does what (DESIGN 12.1).
const JOB_COLOURS: Dictionary = {
	&"gathering": Color("#9e3b26"), &"woodcraft": Color("#5b4a2a"),
	&"building": Color("#c8902e"), &"farming": Color("#6b7f3a"),
	&"crafting": Color("#7d7a72"), &"metalwork": Color("#4a4744"),
	&"scholarship": Color("#e6d5b0"), &"engineering": Color("#3e5a78"),
	&"haul": Color("#b07a3a"), &"devotion": Color("#d8c39e"),
}
const STATE_FOR_POSE := {
	Pose.IDLE: &"idle", Pose.WALK: &"walk", Pose.WORK: &"work", Pose.HELD: &"held",
	Pose.WAVE: &"wave", Pose.COWER: &"cower", Pose.WATCH: &"idle", Pose.POINT: &"talk",
	Pose.REACH: &"cheer", Pose.PRAY: &"pray", Pose.SLEEP: &"dead", Pose.DEAD: &"dead",
	Pose.CARRY: &"carry", Pose.SIT: &"sit", Pose.RUN: &"run", Pose.CHOP: &"chop",
}
## Idle stances a standing adult drifts between (weights by repetition).
const IDLE_VARIANTS: Array[StringName] = [&"idle", &"idle", &"idle", &"idle_fold", &"idle_hips"]
## Seconds a person keeps the walking clip after a stop (stop-go steps read as one walk).
const MOVE_HOLD := 0.3

## Kept for callers that scale the figure (height); the villager lives under it.
var body: Node3D
var villager: VillagerVisual
var bubble: Node3D
var bubble_icon: MeshInstance3D
var _skin := SKIN[0]
var _hair := HAIR[0]
var _cloth := CLOTH_IDLE
var _outfit := 0
var _stage := 2
var _elder := false
var _skill: StringName = &""
var _t: float = 0.0
var _squash: float = 0.0
var _hurt := 0.0
var _built := false
var _plan: Dictionary = {}            # TaskAnims.for_job() of the current job ({} = none)
var _has_plan := false                # set_task() was called (else the skill decides)
var _cargo_kind: StringName = &""
var _move_hold := 0.0
var _idle_pick: StringName = &"idle"
var _idle_t := 0.0

func _ready() -> void:
	_build()

func _build() -> void:
	if _built:
		return
	_built = true
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	villager = VILLAGER_SCENE.instantiate() as VillagerVisual
	villager.name = "Villager"
	body.add_child(villager)
	_push_look()
	bubble = Node3D.new()
	bubble.position = Vector3(0, 2.45, 0)
	add_child(bubble)
	var bmi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28; sm.height = 0.5; sm.radial_segments = 10; sm.rings = 5
	bmi.mesh = sm
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(1, 0.98, 0.92)
	bmi.material_override = white
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.add_child(bmi)
	bubble_icon = MeshInstance3D.new()
	var im := SphereMesh.new()
	im.radius = 0.13; im.height = 0.26; im.radial_segments = 8; im.rings = 4
	bubble_icon.mesh = im
	var icm := StandardMaterial3D.new()
	icm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_icon.material_override = icm
	bubble_icon.position = Vector3(0, 0, 0.2)
	bubble_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.add_child(bubble_icon)
	bubble.visible = false

## skin_i / hair_i index SKIN / HAIR (wrapping); outfit picks body, hair style and cut
## (even = male body, odd = female body); stage is Person.Stage.
func apply_look(skin_i: int, hair_i: int, height: float, elder: bool, stage: int = -1, outfit: int = -1) -> void:
	_build()
	_skin = SKIN[posmod(skin_i, SKIN.size())]
	_hair = HAIR[posmod(hair_i, HAIR.size())]
	_elder = elder
	if outfit >= 0:
		_outfit = outfit
	if stage >= 0:
		_stage = stage
	elif elder:
		_stage = 3
	body.scale = Vector3.ONE * height
	_push_look()

## Era clothes: hides in Era 1, wool and linen in Era 2 (VillagerVisual.set_era).
func set_era(e: int) -> void:
	_build()
	if villager != null:
		villager.set_era(e)
		_push_look()

func set_job_colour(skill: StringName) -> void:
	_build()
	_skill = skill
	_cloth = JOB_COLOURS.get(skill, CLOTH_IDLE)
	_push_look()

func _push_look() -> void:
	if villager == null:
		return
	var hair := _hair.lerp(Color(0.82, 0.8, 0.76), 0.7) if _elder else _hair
	villager.set_look(_skin, hair, _cloth, _outfit)
	villager.set_age_scale(_stage)

## The job whose clip and tools this person works with (a JobDef, or null for none).
func set_task(jd: Resource) -> void:
	_has_plan = true
	_plan = TaskAnims.for_job(jd)

## What they carry: a resource kind (StringName, e.g. &"berries"), or null / &"" for
## nothing. (A Color, from older callers, shows a plain crate.)
func set_cargo(c: Variant) -> void:
	var kind: StringName = &""
	if c is StringName or c is String:
		kind = StringName(c)
	elif c is Color:
		kind = &"crate"
	_cargo_kind = kind
	if villager:
		villager.hold_cargo(kind)

func cargo_kind() -> StringName:
	return _cargo_kind

func set_wish(c: Variant) -> void:
	if bubble == null:
		return
	if c == null:
		bubble.visible = false
	else:
		bubble.visible = true
		(bubble_icon.material_override as StandardMaterial3D).albedo_color = c

## Red tint that fades as an injury heals (0..1).
func set_hurt(amount: float) -> void:
	_hurt = clampf(amount, 0.0, 1.0)
	if villager:
		villager.set_tint(Color.WHITE.lerp(Color(1.0, 0.62, 0.55), _hurt))

func land_squash() -> void:
	_squash = 1.0

func current_state() -> StringName:
	return villager.current_state() if villager else &""

## Picks the animation for `pose`. `look_at_world` is the hand position (or INF):
## the figure turns a little toward it when idle.
func animate(delta: float, pose: int, moving: bool, look_at_world: Vector3) -> void:
	if not _built or villager == null:
		return
	_t += delta
	# stop-go stepping (catching up with a slot) reads as one steady walk
	if moving:
		_move_hold = MOVE_HOLD
	else:
		_move_hold = maxf(_move_hold - delta, 0.0)
	var walking := moving or (_move_hold > 0.0 and pose in [Pose.IDLE, Pose.WATCH, Pose.WORK, Pose.CARRY, Pose.CHOP])
	var p := pose
	if walking and p in [Pose.IDLE, Pose.WATCH, Pose.WORK, Pose.WAVE, Pose.POINT, Pose.REACH, Pose.CHOP]:
		p = Pose.WALK
	var st := _clip_for(p, walking, delta)
	var hands: Array = TaskAnims.props(_task_plan(), st)
	if villager.current_state() != st or villager.held_props() != hands:
		villager.play_task(st, hands[0], hands[1], 0.25)
		# Greeting the hand: a short hum (Audio rate-limits per person and overall).
		if st == &"wave" or st == &"cheer":
			Audio.voice(get_parent(), &"happy" if st == &"wave" else &"cheer")
	# Idle people turn their whole body a little toward the hand.
	var yaw := 0.0
	if look_at_world != Vector3.INF and not moving and p in [Pose.WATCH, Pose.WAVE, Pose.POINT, Pose.REACH, Pose.COWER]:
		var lp := to_local(look_at_world)
		yaw = clampf(atan2(lp.x, lp.z), -1.2, 1.2)
	villager.rotation.y = lerp_angle(villager.rotation.y, yaw, minf(5.0 * delta, 1.0))
	# Landing squash.
	_squash = maxf(_squash - delta * 4.0, 0.0)
	villager.scale = Vector3(1.0 + _squash * 0.2, 1.0 - _squash * 0.3, 1.0 + _squash * 0.2)
	if bubble.visible:
		bubble.position.y = 2.45 + sin(_t * 3.0) * 0.08

## The animation plan in use: the job's (set_task), else one from the skill colour.
func _task_plan() -> Dictionary:
	return _plan if _has_plan else TaskAnims.for_skill(_skill)

func _who() -> int:
	var par := get_parent()
	return int(par.get(&"uid")) if par != null and par.get(&"uid") != null else get_instance_id()

## The villager clip for a pose (see the header).
func _clip_for(p: int, walking: bool, delta: float) -> StringName:
	var plan := _task_plan()
	match p:
		Pose.WORK, Pose.CHOP:
			return TaskAnims.work_clip(plan, _who()) if not plan.is_empty() else &"work"
		Pose.WALK:
			var mv: StringName = plan.get("move", &"")
			return mv if mv != &"" else &"walk"
		Pose.CARRY:
			if _cargo_kind == &"" and plan.has("carry"):
				return plan["carry"] if walking else plan.get("carry_idle", plan["carry"])
			return &"carry_walk" if walking else &"carry"
		Pose.SIT:
			return &"baby_sit" if _stage == 0 else &"sit"
		Pose.IDLE:
			if _stage != 2:
				return &"idle"
			# drift between stances every so often, each person on their own clock
			_idle_t -= delta
			if _idle_t <= 0.0:
				var k := absi(hash(_who() * 7919 + int(_t / 9.0)))
				_idle_pick = IDLE_VARIANTS[k % IDLE_VARIANTS.size()]
				_idle_t = 9.0 + float(k % 7)
			return _idle_pick
	return STATE_FOR_POSE.get(p, &"idle")
