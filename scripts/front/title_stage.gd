class_name TitleStage extends Node3D
## The live backdrop behind the title menu: the valley at dawn (the current
## save's valley, else a fresh one) with the camera drifting slowly over the
## Clearing, and the white glove hovering above it, breathing and now and then
## making a small, patient gesture. Lives under the world while the title is
## up; the menu calls enter() / leave(). Owns no game state: every way out of
## the title (Continue, Load, New game) reloads or rebuilds the clock and
## weather it borrows here.

const HAND_SCENE := preload("res://scenes/hand/hand_model.tscn")
const DAWN_U := 0.065            # fraction of the day: just after sunrise

var world: Node = null
var hand: Node3D = null          # a HandModel
var active: bool = false
var t: float = 0.0
var _gesture_t: float = 6.0
var _gesture: int = 0            # 0 none, 1 beckon, 2 open wide
var _g_since: float = 99.0

func setup(w: Node) -> void:
	world = w
	name = "TitleStage"
	hand = HAND_SCENE.instantiate()
	hand.name = "TitleHand"
	hand.top_level = true
	add_child(hand)
	hand.visible = false

## Starts the dawn, the drift and the hand.
func enter() -> void:
	active = true
	t = 0.0
	visible = true
	hand.visible = true
	Clock.is_night = false
	Clock.phase_t = DAWN_U * Clock.day_seconds
	if world != null and world.get(&"look") != null:
		world.look.set_weather(0.0, false)
		world.look.update_now()
	if world != null and world.get(&"title_camera") != null:
		world.title_camera.current = true
	_set_hint(false)
	_drift(0.0)

func leave() -> void:
	active = false
	visible = false
	hand.visible = false
	_set_hint(true)

## The storm's hint glow on the branch is for play, not for the title.
func _set_hint(on: bool) -> void:
	var st = world.get(&"storm") if world != null else null
	var g = st.get(&"_glow") if st != null else null
	if g is Node3D and is_instance_valid(g):
		g.visible = on

func _process(delta: float) -> void:
	if not active:
		return
	var dt := minf(Clock.real_delta if Clock.real_delta > 0.0 else delta, 0.1)
	t += dt
	# the sun climbs a touch while you sit on the title
	Clock.phase_t = minf(Clock.phase_t + dt * 0.02, 0.12 * Clock.day_seconds)
	_drift(dt)

## The camera's slow drift over the Clearing, looking north to the cliff and
## the cave with the low sun from the east, and the hand placed in view.
func _drift(dt: float) -> void:
	if world == null or world.get(&"title_camera") == null:
		return
	var cam: Camera3D = world.title_camera
	cam.fov = 46.0
	var yaw := 0.42 + sin(t * 0.021) * 0.28
	var focus := Vector3(sin(t * 0.017) * 6.0 - 4.0, 0.0, -14.0 + cos(t * 0.013) * 5.0)
	focus.y = world.ground_y(focus.x, focus.z) + 2.0
	world.frame_camera(cam, focus, 66.0 + sin(t * 0.03) * 4.0, yaw, 24.0)
	_place_hand(cam, dt)

func _place_hand(cam: Camera3D, dt: float) -> void:
	# camera space: hovering high on the right, reaching down and in
	var bob := sin(t * 0.9) * 0.35
	var sway := sin(t * 0.43) * 0.6
	var wrist_cs := Vector3(13.0 + sway * 0.4, 8.6 + bob, -21.0)
	var fingers_cs := Vector3(-0.72, -0.56, -0.22).normalized()
	var back_cs := Vector3(-0.2, 0.45, 1.0).normalized()
	# the gesture: a slow tilt of the wrist
	var g := _gesture_amount(dt)
	fingers_cs = fingers_cs.rotated(Vector3.FORWARD, 0.06 * sin(t * 0.7) + (0.12 * g if _gesture == 2 else 0.0)).normalized()
	var cb := cam.global_transform.basis
	var wrist := cam.global_transform * wrist_cs
	place(hand, wrist, cb * fingers_cs, cb * back_cs, 8.5)
	# fingers breathe; a beckon curls the index and middle; open wide spreads all
	var br := 0.08 * sin(t * 1.3)
	var curl := PackedFloat32Array([0.1 + br, 0.0 + br, 0.05 + br, 0.12 + br, 0.18 + br])
	var spread := 0.6 + 0.2 * sin(t * 0.6)
	if _gesture == 1:
		curl[1] += 0.75 * g
		curl[2] += 0.6 * g
	elif _gesture == 2:
		for i in 5:
			curl[i] -= 0.45 * g
		spread += 0.9 * g
	hand.set_pose(curl, 0.0, 0.0, spread)
	hand.set_look(1.0, 1.0, 0.55 + 0.15 * sin(t * 1.1), Color(1.0, 0.72, 0.4))

## 0..1..0 over a gesture; a new one every ten seconds or so.
func _gesture_amount(dt: float) -> float:
	_g_since += dt
	_gesture_t -= dt
	if _gesture_t <= 0.0:
		_gesture_t = 10.0
		_g_since = 0.0
		_gesture = 2 if _gesture == 1 else 1
	if _g_since > 2.6:
		return 0.0
	var u := _g_since / 2.6
	return sin(u * PI) * sin(u * PI)

## Places a HandModel (hand units: wrist at the origin, fingers along -Z, the
## back of the hand +Y) at `wrist`, its fingers along `fingers`, the back of
## the hand toward `back`, `length` metres from wrist to fingertip.
static func place(model: Node3D, wrist: Vector3, fingers: Vector3, back: Vector3, length: float) -> void:
	var z := -fingers.normalized()
	var x := back.cross(z)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	model.global_transform = Transform3D(Basis(x * length, y * length, z * length), wrist)
