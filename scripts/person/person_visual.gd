class_name PersonVisual extends Node3D
## Placeholder chunky low-poly villager, built from primitives. Lives under the
## Person as the child named "Visual" so a rigged model can replace it wholesale.
## The Person calls apply_look() once and animate() every frame.

enum Pose { IDLE, WALK, WORK, HELD, WAVE, COWER, WATCH, POINT, REACH, PRAY, SLEEP, DEAD, CARRY, SIT }

const SKIN: Array[Color] = [Color(0.96, 0.8, 0.65), Color(0.85, 0.65, 0.48), Color(0.66, 0.46, 0.32), Color(0.45, 0.3, 0.2)]
const HAIR: Array[Color] = [Color(0.12, 0.08, 0.05), Color(0.35, 0.2, 0.1), Color(0.6, 0.4, 0.15), Color(0.82, 0.72, 0.5), Color(0.5, 0.15, 0.1)]
const CLOTH_IDLE := Color(0.55, 0.42, 0.28)
## Body colour by job skill family, so a glance shows who does what.
const JOB_COLOURS: Dictionary = {
	&"gathering": Color(0.75, 0.25, 0.3), &"woodcraft": Color(0.45, 0.3, 0.15),
	&"building": Color(0.85, 0.55, 0.2), &"farming": Color(0.5, 0.65, 0.25),
	&"crafting": Color(0.55, 0.55, 0.6), &"metalwork": Color(0.35, 0.35, 0.4),
	&"scholarship": Color(0.92, 0.88, 0.75), &"engineering": Color(0.25, 0.4, 0.6),
}

var body: Node3D
var torso: MeshInstance3D
var head: Node3D
var hair: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var cargo: MeshInstance3D
var bubble: Node3D
var bubble_icon: MeshInstance3D
var _skin_mat: StandardMaterial3D
var _cloth_mat: StandardMaterial3D
var _hair_mat: StandardMaterial3D
var _t: float = 0.0
var _squash: float = 0.0
var _built := false

func _ready() -> void:
	_build()

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _box(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _limb(pos: Vector3, size: Vector3, m: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	body.add_child(pivot)
	_box(pivot, size, m, Vector3(0, -size.y * 0.5, 0))
	return pivot

func _build() -> void:
	if _built:
		return
	_built = true
	_skin_mat = _mat(SKIN[0])
	_cloth_mat = _mat(CLOTH_IDLE)
	_hair_mat = _mat(HAIR[0])
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	leg_l = _limb(Vector3(-0.13, 0.42, 0), Vector3(0.16, 0.42, 0.18), _skin_mat)
	leg_r = _limb(Vector3(0.13, 0.42, 0), Vector3(0.16, 0.42, 0.18), _skin_mat)
	torso = _box(body, Vector3(0.52, 0.55, 0.36), _cloth_mat, Vector3(0, 0.7, 0))
	arm_l = _limb(Vector3(-0.34, 0.95, 0), Vector3(0.13, 0.46, 0.14), _skin_mat)
	arm_r = _limb(Vector3(0.34, 0.95, 0), Vector3(0.13, 0.46, 0.14), _skin_mat)
	head = Node3D.new()
	head.position = Vector3(0, 1.22, 0)
	body.add_child(head)
	# A big blocky head reads well from the god camera.
	_box(head, Vector3(0.5, 0.48, 0.46), _skin_mat, Vector3(0, 0.2, 0))
	hair = _box(head, Vector3(0.54, 0.18, 0.5), _hair_mat, Vector3(0, 0.46, -0.02))
	_box(head, Vector3(0.54, 0.3, 0.12), _hair_mat, Vector3(0, 0.3, -0.22))
	var eye := _mat(Color(0.05, 0.05, 0.05))
	_box(head, Vector3(0.07, 0.08, 0.02), eye, Vector3(-0.11, 0.24, 0.235))
	_box(head, Vector3(0.07, 0.08, 0.02), eye, Vector3(0.11, 0.24, 0.235))
	cargo = _box(body, Vector3(0.34, 0.26, 0.3), _mat(Color.WHITE), Vector3(0, 1.95, 0))
	cargo.visible = false
	bubble = Node3D.new()
	bubble.position = Vector3(0, 2.55, 0)
	add_child(bubble)
	var bm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28; sm.height = 0.5; sm.radial_segments = 8; sm.rings = 4
	bm.mesh = sm
	var white := _mat(Color(1, 1, 0.95))
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material_override = white
	bubble.add_child(bm)
	bubble_icon = _box(bubble, Vector3(0.22, 0.22, 0.22), _mat(Color.RED), Vector3(0, 0, 0.12))
	bubble.visible = false

func apply_look(skin_i: int, hair_i: int, height: float, elder: bool) -> void:
	_build()
	_skin_mat.albedo_color = SKIN[clampi(skin_i, 0, SKIN.size() - 1)]
	var hc: Color = HAIR[clampi(hair_i, 0, HAIR.size() - 1)]
	_hair_mat.albedo_color = hc.lerp(Color(0.85, 0.85, 0.85), 0.75) if elder else hc
	body.scale = Vector3.ONE * height

func set_job_colour(skill: StringName) -> void:
	_build()
	_cloth_mat.albedo_color = JOB_COLOURS.get(skill, CLOTH_IDLE)

func set_cargo(c: Variant) -> void:
	if c == null:
		cargo.visible = false
	else:
		cargo.visible = true
		(cargo.material_override as StandardMaterial3D).albedo_color = c

func set_wish(c: Variant) -> void:
	if c == null:
		bubble.visible = false
	else:
		bubble.visible = true
		(bubble_icon.material_override as StandardMaterial3D).albedo_color = c

func land_squash() -> void:
	_squash = 1.0

## Procedural animation. `look_at_world` is the hand position (or INF).
func animate(delta: float, pose: int, moving: bool, look_at_world: Vector3) -> void:
	if not _built:
		return
	_t += delta
	var k := minf(10.0 * delta, 1.0)
	var t := _t
	var la := 0.0; var ra := 0.0; var laz := 0.0; var raz := 0.0
	var ll := 0.0; var lr := 0.0
	var lean := 0.0; var bob := 0.0; var roll := 0.0
	var head_x := 0.0
	if moving or pose == Pose.WALK:
		var sw := sin(t * 11.0) * 0.65
		ll = sw; lr = -sw; la = -sw * 0.8; ra = sw * 0.8
		bob = absf(sin(t * 11.0)) * 0.07
	match pose:
		Pose.WORK:
			var c := sin(t * 8.0)
			ra = -1.3 + c * 0.9; la = -1.1 + c * 0.7
			lean = 0.25 + c * 0.08
		Pose.CARRY:
			la = -PI; ra = -PI
		Pose.HELD:
			var w := sin(t * 14.0) * 0.7
			ll = w; lr = -w
			laz = -2.4 + sin(t * 10.0) * 0.4; raz = 2.4 - sin(t * 10.0) * 0.4
			head_x = -0.4
		Pose.COWER:
			la = -2.3; ra = -2.3; laz = 0.4; raz = -0.4
			lean = 0.5; bob = -0.18
			head_x = 0.4
		Pose.WAVE:
			raz = 2.6 + sin(t * 12.0) * 0.45
			head_x = -0.5
		Pose.WATCH:
			head_x = -0.6
		Pose.POINT:
			ra = -2.6; head_x = -0.6
		Pose.REACH:
			laz = -2.8 + sin(t * 6.0) * 0.15; raz = 2.8 - sin(t * 6.0) * 0.15
			head_x = -0.7; bob = absf(sin(t * 6.0)) * 0.1
		Pose.PRAY:
			la = -2.6; ra = -2.6
			lean = 0.3 + sin(t * 2.0) * 0.06
		Pose.SLEEP:
			roll = PI * 0.5; bob = 0.1
		Pose.DEAD:
			roll = PI * 0.5; bob = 0.05
		Pose.SIT:
			ll = -1.4; lr = -1.4; bob = -0.35
	arm_l.rotation.x = lerpf(arm_l.rotation.x, la, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, ra, k)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, laz, k)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, raz, k)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, ll, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, lr, k)
	body.rotation.x = lerpf(body.rotation.x, lean, k)
	body.rotation.z = lerpf(body.rotation.z, roll, minf(6.0 * delta, 1.0))
	body.position.y = lerpf(body.position.y, bob, k)
	# Head: look up at the hand when it is near, otherwise forward.
	var yaw := 0.0
	if look_at_world != Vector3.INF and pose != Pose.SLEEP and pose != Pose.DEAD:
		var lp := to_local(look_at_world)
		yaw = clampf(atan2(lp.x, lp.z), -1.1, 1.1)
	head.rotation.y = lerp_angle(head.rotation.y, yaw, minf(6.0 * delta, 1.0))
	head.rotation.x = lerpf(head.rotation.x, head_x, minf(6.0 * delta, 1.0))
	# Landing squash.
	_squash = maxf(_squash - delta * 4.0, 0.0)
	scale = Vector3(1.0 + _squash * 0.2, 1.0 - _squash * 0.3, 1.0 + _squash * 0.2)
	if bubble.visible:
		bubble.position.y = 2.55 + sin(t * 3.0) * 0.08
