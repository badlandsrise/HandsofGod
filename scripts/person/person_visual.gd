class_name PersonVisual extends Node3D
## The look of a Person: wraps the rigged VillagerVisual (scenes/people/villager_visual.tscn)
## and maps the Person's poses onto its animation states. Lives under the Person as the
## child named "Visual". The Person calls apply_look() when its look or stage changes and
## animate() every frame.

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
	Pose.REACH: &"cheer", Pose.PRAY: &"sit", Pose.SLEEP: &"dead", Pose.DEAD: &"dead",
	Pose.CARRY: &"carry", Pose.SIT: &"sit", Pose.RUN: &"run", Pose.CHOP: &"chop",
}

## Kept for callers that scale the figure (height); the villager lives under it.
var body: Node3D
var villager: VillagerVisual
var cargo: MeshInstance3D
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
	cargo = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.26, 0.3)
	cargo.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.roughness = 0.9
	cargo.material_override = cm
	cargo.position = Vector3(0, 1.02, 0.34)
	body.add_child(cargo)
	cargo.visible = false
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

func set_cargo(c: Variant) -> void:
	if cargo == null:
		return
	if c == null:
		cargo.visible = false
	else:
		cargo.visible = true
		(cargo.material_override as StandardMaterial3D).albedo_color = c

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
	var p := pose
	if moving and p in [Pose.IDLE, Pose.WATCH, Pose.WORK, Pose.WAVE, Pose.POINT, Pose.REACH, Pose.CHOP]:
		p = Pose.WALK
	if p == Pose.WORK and _skill == &"woodcraft":
		p = Pose.CHOP
	var st: StringName = STATE_FOR_POSE.get(p, &"idle")
	if p == Pose.CARRY and not moving:
		st = &"carry"
	if villager.current_state() != st:
		villager.play(st, 0.25)
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
