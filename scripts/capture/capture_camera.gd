extends Node
## [capture] The marketing capture camera: named presets and timed moves from
## data/capture/cameras.json (see docs/CAPTURE.md). While a preset, a move or a
## demo holds the camera, the play camera rig is paused and this node poses
## the active Camera3D directly, late in the frame, on the capture clock (so a
## move is frame-exact under Movie Maker's --fixed-fps). Key 0 gives the
## camera back to the rig, framed where this one was looking.
##
## A spec: {focus: [x, z], focus_h, dist, yaw_deg, pitch_deg, fov, tilt_shift, far}.

const PATH := "res://data/capture/cameras.json"

var data: Dictionary = {}
var world: Node = null
var mode: StringName = &"free"      # free | preset | move | demo | pinned
var current: String = ""            # preset or move name
var spec: Dictionary = {}           # the spec being shown (preset, or the move's pose now)
var move_from: Dictionary = {}
var move_to: Dictionary = {}
var move_t: float = 0.0
var move_len: float = 1.0
var pinned_pos: Vector3 = Vector3.INF     # spoiler: a pinned camera in world space
var pinned_look: Vector3 = Vector3.ZERO
var pinned_fov: float = 45.0
var _saved_far: float = -1.0
var _held_rig: bool = false

func _init() -> void:
	name = "CaptureCamera"

func load_data() -> bool:
	if not FileAccess.file_exists(PATH):
		push_warning("capture: no %s" % PATH)
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (d is Dictionary):
		push_warning("capture: %s is not valid JSON" % PATH)
		return false
	data = d
	return true

# ---------------------------------------------------------------- lookups

func presets() -> Dictionary:
	return data.get("presets", {})

func moves() -> Dictionary:
	return data.get("moves", {})

func spoiler_presets() -> Dictionary:
	return data.get("spoiler", {}).get("presets", {})

func has_shot(n: String) -> bool:
	return presets().has(n) or moves().has(n)

## The preset or move name bound to number key `k` (1-9), or "".
func name_for_key(k: int, spoiler: bool = false) -> String:
	var tables: Array = [spoiler_presets()] if spoiler else [presets(), moves()]
	for t in tables:
		for n in t:
			if int((t[n] as Dictionary).get("key", -1)) == k:
				return n
	return ""

## A preset's spec for `era`, with the era's overrides merged in.
func preset_spec(n: String, era: int) -> Dictionary:
	var p: Dictionary = presets().get(n, {})
	if p.is_empty():
		return {}
	var out := p.duplicate(true)
	out.erase("eras")
	var ov: Dictionary = p.get("eras", {}).get(str(era), {})
	for k in ov:
		out[k] = ov[k]
	return out

func _resolve(v, era: int) -> Dictionary:
	if v is String:
		return preset_spec(v, era)
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}

# ---------------------------------------------------------------- the pose

## [position, look-at point] for a spec, in world space.
func pose_of(s: Dictionary) -> Array:
	var f: Array = s.get("focus", [0, 0])
	var fx := float(f[0])
	var fz := float(f[1])
	var fy := _ground(fx, fz) + float(s.get("focus_h", 0.0))
	var focus := Vector3(fx, fy, fz)
	var yaw := deg_to_rad(float(s.get("yaw_deg", 0.0)))
	var pitch := deg_to_rad(float(s.get("pitch_deg", 40.0)))
	var dist := float(s.get("dist", 30.0))
	var pos := focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	# never under the ground (low hero angles over a ridge)
	pos.y = maxf(pos.y, _ground(pos.x, pos.z) + 1.2)
	return [pos, focus]

## Terrain height without the buildings, so a framing matches in every era.
func _ground(x: float, z: float) -> float:
	if world != null and world.get(&"valley") != null:
		return world.valley.ground_y(x, z)
	if world != null and world.has_method(&"ground_y"):
		return world.ground_y(x, z)
	return 0.0

static func lerp_spec(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := b.duplicate(true)
	var fa: Array = a.get("focus", [0, 0])
	var fb: Array = b.get("focus", fa)
	out["focus"] = [lerpf(float(fa[0]), float(fb[0]), u), lerpf(float(fa[1]), float(fb[1]), u)]
	for k in ["dist", "yaw_deg", "pitch_deg", "fov", "focus_h", "far"]:
		if a.has(k) or b.has(k):
			var dflt: float = {"dist": 30.0, "yaw_deg": 0.0, "pitch_deg": 40.0, "fov": 45.0, "focus_h": 0.0, "far": 400.0}[k]
			out[k] = lerpf(float(a.get(k, b.get(k, dflt))), float(b.get(k, a.get(k, dflt))), u)
	out["tilt_shift"] = bool(b.get("tilt_shift", a.get("tilt_shift", true))) if u > 0.5 else bool(a.get("tilt_shift", b.get("tilt_shift", true)))
	return out

## Ease in and out (smootherstep): moves start and land without a jolt.
static func ease_io(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)

# ---------------------------------------------------------------- control

## Shows preset (or move) `n`. Returns false when there is no such shot.
func go(n: String, era: int) -> bool:
	if presets().has(n):
		spec = preset_spec(n, era)
		mode = &"preset"
		current = n
		_hold_rig()
		return true
	if moves().has(n):
		var m: Dictionary = moves()[n]
		move_from = _resolve(m.get("from", {}), era)
		move_to = _resolve(m.get("to", {}), era)
		move_len = maxf(float(m.get("duration", 10.0)), 0.1)
		move_t = 0.0
		spec = move_from.duplicate(true)
		mode = &"move"
		current = n
		_hold_rig()
		return true
	return false

## A demo drives the camera with a spec every frame.
func drive(s: Dictionary) -> void:
	spec = s
	if mode != &"demo":
		mode = &"demo"
		current = "demo"
		_hold_rig()

## Spoiler: a camera pinned at world `pos` looking at `look`.
func pin(pos: Vector3, look: Vector3, fov: float, label: String) -> void:
	pinned_pos = pos
	pinned_look = look
	pinned_fov = fov
	mode = &"pinned"
	current = label

## Back to the player's camera rig, framed where this camera was looking.
func release() -> void:
	var was := mode
	mode = &"free"
	current = ""
	pinned_pos = Vector3.INF
	var rig = world.get(&"camera_rig") if world != null else null
	if rig == null or not is_instance_valid(rig):
		return
	if _held_rig:
		rig.process_mode = Node.PROCESS_MODE_INHERIT
		_held_rig = false
	var cam := rig_camera()
	if cam != null and _saved_far > 0.0:
		cam.far = _saved_far
		_saved_far = -1.0
	if was in [&"preset", &"move", &"demo"] and not spec.is_empty() and rig.has_method(&"snap_to"):
		var f: Array = spec.get("focus", [0, 0])
		var y := deg_to_rad(float(spec.get("yaw_deg", 0.0)))
		if "target_yaw" in rig:
			rig.target_yaw = y
			rig.yaw = y
		rig.snap_to(Vector3(float(f[0]), 0.0, float(f[1])), float(spec.get("dist", 30.0)))

func rig_camera() -> Camera3D:
	var rig = world.get(&"camera_rig") if world != null else null
	if rig != null and is_instance_valid(rig):
		if rig is Camera3D:
			return rig
		var c = rig.get(&"camera")
		if c is Camera3D:
			return c
	return world.get(&"fallback_camera") if world != null else null

func _hold_rig() -> void:
	var rig = world.get(&"camera_rig") if world != null else null
	if rig != null and is_instance_valid(rig) and not _held_rig:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
		_held_rig = true

## Steps a move by `dt` (the capture clock; 0 while paused).
func step(dt: float) -> void:
	if mode == &"move":
		move_t = minf(move_t + dt, move_len)
		spec = lerp_spec(move_from, move_to, ease_io(move_t / move_len))

func move_done() -> bool:
	return mode == &"move" and move_t >= move_len

## Poses the camera; called late in the frame, after the rig and the goodbye.
func apply() -> void:
	if mode == &"free":
		return
	var vp := get_viewport()
	if vp == null:
		return
	if mode == &"pinned":
		var pc := vp.get_camera_3d()
		if pc != null and pinned_pos.is_finite():
			pc.global_position = pinned_pos
			if pinned_pos.distance_to(pinned_look) > 0.01:
				pc.look_at(pinned_look, Vector3.UP)
			pc.fov = pinned_fov
		return
	if spec.is_empty():
		return
	var cam := rig_camera()
	if cam == null:
		return
	if not cam.current:
		cam.current = true
	var pose := pose_of(spec)
	var pos: Vector3 = pose[0]
	var look: Vector3 = pose[1]
	if not pos.is_finite():
		return
	cam.global_position = pos
	if pos.distance_to(look) > 0.01:
		cam.look_at(look, Vector3.UP)
	cam.fov = float(spec.get("fov", 45.0))
	var far := float(spec.get("far", 400.0))
	if _saved_far < 0.0:
		_saved_far = cam.far
	cam.far = maxf(far, 400.0)
	var dof := cam.attributes as CameraAttributesPractical
	if dof != null:
		var ts := bool(spec.get("tilt_shift", true))
		var d := pos.distance_to(look)
		dof.dof_blur_far_enabled = ts
		dof.dof_blur_near_enabled = ts
		dof.dof_blur_far_distance = d * 1.45
		dof.dof_blur_far_transition = d * 1.6
		dof.dof_blur_near_distance = d * 0.45
		dof.dof_blur_near_transition = d * 0.3
