class_name CameraRig extends Node3D
## High 3/4 camera. Pan with WASD/arrows, screen edges (toggle) or middle-drag,
## rotate with Q/R, smooth wheel zoom; the pitch eases from a low 3/4 when close
## to near top-down when far. Bounds come from Game.world.camera_bounds() when the
## world provides it, else a 60 m box. Runs on Clock.real_delta.

const DEFAULT_BOUNDS := AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))

@export var min_dist: float = 12.0
@export var max_dist: float = 75.0
@export var pitch_close_deg: float = 38.0
@export var pitch_far_deg: float = 64.0
@export var pan_speed: float = 0.9          # screen-heights per second
@export var rot_speed: float = 1.8          # radians per second
@export var edge_pan: bool = false
@export var edge_px: float = 10.0
@export var invert_rotate: bool = false

var camera: Camera3D
var focus: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var dist: float = 28.0
var target_focus: Vector3 = Vector3.ZERO
var target_yaw: float = 0.0
var target_dist: float = 28.0
var input_enabled: bool = true

var _drag: bool = false
var dof: CameraAttributesPractical
@export var tilt_shift: bool = true

func _ready() -> void:
	add_to_group(&"camera_rig")
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = get_node_or_null(^"Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.fov = 45.0
	# Mild tilt-shift: the far valley and anything right under the lens go soft, so the
	# Clearing reads as a diorama. Distances follow the zoom (see _apply).
	dof = CameraAttributesPractical.new()
	dof.dof_blur_far_enabled = true
	dof.dof_blur_near_enabled = true
	dof.dof_blur_amount = 0.06
	camera.attributes = dof
	camera.near = 0.3
	camera.far = 400.0
	camera.current = true
	target_focus = focus
	target_yaw = yaw
	target_dist = dist
	_apply()

func _process(_delta: float) -> void:
	step(Clock.real_delta)

## Glide to look at `p` (alerts, the Village Book, dreams).
func focus_on(p: Vector3, d: float = -1.0) -> void:
	if not p.is_finite():
		return
	target_focus = _clamp_focus(p)
	if d > 0.0:
		target_dist = clampf(d, min_dist, max_dist)

## Jump there with no glide.
func snap_to(p: Vector3, d: float = -1.0) -> void:
	focus_on(p, d)
	focus = target_focus
	dist = target_dist
	yaw = target_yaw
	_apply()

func bounds() -> AABB:
	var w := Game.world
	if w != null and w.has_method(&"camera_bounds"):
		var b = w.camera_bounds()
		if b is AABB and b.size.x > 0.0:
			return b
	return DEFAULT_BOUNDS

func pitch() -> float:
	var t := inverse_lerp(min_dist, max_dist, dist)
	t = clampf(t, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return deg_to_rad(lerpf(pitch_close_deg, pitch_far_deg, t))

func step(dt: float) -> void:
	if input_enabled:
		var pan := Vector2(
			Input.get_action_strength(&"cam_right") - Input.get_action_strength(&"cam_left"),
			Input.get_action_strength(&"cam_down") - Input.get_action_strength(&"cam_up"))
		if edge_pan and get_window().has_focus():
			var mp := get_viewport().get_mouse_position()
			var vs := get_viewport().get_visible_rect().size
			if mp.x <= edge_px: pan.x -= 1.0
			elif mp.x >= vs.x - edge_px: pan.x += 1.0
			if mp.y <= edge_px: pan.y -= 1.0
			elif mp.y >= vs.y - edge_px: pan.y += 1.0
		if pan.length() > 0.0 and not _text_focus():
			pan = pan.limit_length(1.0) * dist * pan_speed * dt
			target_focus += _right() * pan.x + _forward() * -pan.y
			target_focus = _clamp_focus(target_focus)
		var rot := Input.get_action_strength(&"cam_rot_left") - Input.get_action_strength(&"cam_rot_right")
		if invert_rotate:
			rot = -rot
		if rot != 0.0 and not _text_focus():
			target_yaw += rot * rot_speed * dt
	focus = focus.lerp(target_focus, minf(10.0 * dt, 1.0))
	yaw = lerpf(yaw, target_yaw, minf(10.0 * dt, 1.0))
	dist = lerpf(dist, target_dist, minf(8.0 * dt, 1.0))
	_apply()

func _apply() -> void:
	if camera == null:
		return
	var p := pitch()
	var off := Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * dist
	var f := focus
	var w := Game.world
	if w != null and w.has_method(&"ground_y"):
		f.y = w.ground_y(f.x, f.z)
	if not (f + off).is_finite():
		return
	camera.global_position = f + off
	camera.look_at(f, Vector3.UP)
	if dof:
		dof.dof_blur_far_enabled = tilt_shift
		dof.dof_blur_near_enabled = tilt_shift
		dof.dof_blur_far_distance = dist * 1.45
		dof.dof_blur_far_transition = dist * 1.6
		dof.dof_blur_near_distance = dist * 0.45
		dof.dof_blur_near_transition = dist * 0.3

func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_dist = clampf(target_dist * 0.88, min_dist, max_dist)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_dist = clampf(target_dist * 1.12, min_dist, max_dist)
	elif e is InputEventMouseMotion and _drag:
		var mm := e as InputEventMouseMotion
		var k := dist * 0.0021
		target_focus -= (_right() * mm.relative.x + _forward() * -mm.relative.y) * k
		target_focus = _clamp_focus(target_focus)
		focus = focus.lerp(target_focus, 0.6)

func _right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))

func _forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func _clamp_focus(p: Vector3) -> Vector3:
	var b := bounds()
	return Vector3(clampf(p.x, b.position.x, b.end.x), p.y, clampf(p.z, b.position.z, b.end.z))

func _text_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit
