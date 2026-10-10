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
## [polish] Warmth you can see (Austin: warmth "doesn't seem to come from
## anything"): a soft orange glow and rising sparks while someone warms up by a
## fire, coming out of a hut, or under the hand's Warmth; a frosty tint while cold.
var _glow: MeshInstance3D = null
var _glow_mat: StandardMaterial3D = null
var _sparks: CPUParticles3D = null
var _glow_k := 0.0
var _glow_want := 0.0
var _temp := 0              # -1 cold, 0 neither, 1 warming

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
	_push_tint()

func _push_tint() -> void:
	if villager == null:
		return
	var c := Color.WHITE.lerp(Color(1.0, 0.62, 0.55), _hurt)
	if _temp < 0:
		c *= Color(0.82, 0.9, 1.08)          # frosty
	elif _temp > 0:
		c *= Color(1.08, 0.97, 0.88)         # warm cheeks
	villager.set_tint(c)

## [polish] `warming` 0..1: how strongly they are being warmed right now (0 = not);
## `cold`: chilled (warmth low in the cold).
func set_warmth_cue(warming: float, cold: bool) -> void:
	_glow_want = clampf(warming, 0.0, 1.0)
	var t := 1 if warming > 0.05 else (-1 if cold else 0)
	if t != _temp:
		_temp = t
		_push_tint()

func warmth_glow() -> float:
	return _glow_k

func _build_glow() -> void:
	_glow = MeshInstance3D.new()
	_glow.name = "WarmGlow"
	var qm := QuadMesh.new()
	qm.size = Vector2(1.7, 2.4)
	_glow.mesh = qm
	_glow.position = Vector3(0, 1.0, 0)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.62, 0.22, 0.9))
	g.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	_glow_mat.albedo_texture = gt
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.visible = false
	add_child(_glow)
	_sparks = CPUParticles3D.new()
	_sparks.name = "WarmSparks"
	_sparks.amount = 10
	_sparks.lifetime = 1.4
	_sparks.emitting = false
	_sparks.position = Vector3(0, 0.6, 0)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.45
	_sparks.direction = Vector3.UP
	_sparks.spread = 15.0
	_sparks.gravity = Vector3(0, 0.6, 0)
	_sparks.initial_velocity_min = 0.4
	_sparks.initial_velocity_max = 0.8
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.045; sm.height = 0.09; sm.radial_segments = 6; sm.rings = 3
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.albedo_color = Color(1.0, 0.72, 0.3)
	spm.vertex_color_use_as_albedo = true
	spm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = spm
	_sparks.mesh = sm
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.85, 0.5, 1))
	ramp.set_color(1, Color(1, 0.4, 0.1, 0))
	_sparks.color_ramp = ramp
	add_child(_sparks)

func _animate_glow(delta: float) -> void:
	if _glow == null:
		if _glow_want <= 0.0:
			return
		_build_glow()
	_glow_k = move_toward(_glow_k, _glow_want, delta * 2.5)
	_glow.visible = _glow_k > 0.01
	if _glow.visible:
		_glow_mat.albedo_color = Color(1, 1, 1, _glow_k * (0.75 + 0.25 * sin(_t * 5.0)))
	_sparks.emitting = _glow_k > 0.3

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
	_animate_glow(delta)   # [polish]
	if _temp < 0 and not moving:
		villager.position.x = sin(_t * 47.0) * 0.012   # a shiver
	elif villager.position.x != 0.0:
		villager.position.x = 0.0

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
