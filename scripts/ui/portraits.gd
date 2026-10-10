class_name Portraits extends Node
## Renders head-and-shoulders portraits of villagers: each person's own rigged
## villager (PersonVisual, same skin, hair, outfit and age) is posed in a small
## off-screen SubViewport with its own warm light, captured once and cached by
## look. Renders run one per frame. Headless (tests) it renders nothing and
## PortraitFrame falls back to a tinted silhouette.

signal portrait_ready(key: String)

const SIZE := 192

static var _inst: Portraits = null

var enabled: bool = true
var cache: Dictionary = {}        # key -> Texture2D
var _queue: Array = []            # [{key, rec}]
var _queued: Dictionary = {}
var _busy := false
var _vp: SubViewport
var _cam: Camera3D
var _stage_root: Node3D
var _visual: PersonVisual

static func get_inst() -> Portraits:
	return _inst if _inst != null and is_instance_valid(_inst) else null

static func key_for(rec: Dictionary) -> String:
	var lk: Dictionary = rec.get("look", {})
	return "%d|%d|%d|%d|%.2f|%d|%s" % [int(rec.get("uid", 0)), int(lk.get("skin", 0)), int(lk.get("hair", 0)),
		int(lk.get("outfit", -1)), float(lk.get("height", 1.0)), int(rec.get("stage", 2)), str(rec.get("sex", "f"))]

func _ready() -> void:
	name = "Portraits"
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless" and not Game.flags.has("no-portraits")

func _exit_tree() -> void:
	if _inst == self:
		_inst = null

## The cached portrait for a record, or null (one is queued; portrait_ready fires).
func request(rec: Dictionary) -> Texture2D:
	var key := key_for(rec)
	if cache.has(key):
		return cache[key]
	if enabled and not _queued.has(key):
		_queued[key] = true
		_queue.append({"key": key, "rec": rec})
	return null

func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.name = "PortraitViewport"
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_stage_root = Node3D.new()
	_vp.add_child(_stage_root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.86, 0.7)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_stage_root.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.66)
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-28, 35, 0)
	_stage_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.7, 0.75, 1.0)
	rim.light_energy = 0.5
	rim.rotation_degrees = Vector3(-10, 200, 0)
	_stage_root.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 26.0
	_cam.current = true
	_stage_root.add_child(_cam)
	_visual = PersonVisual.new()
	_visual.name = "Sitter"
	_stage_root.add_child(_visual)

func _process(_d: float) -> void:
	if _busy or _queue.is_empty() or not enabled:
		return
	_render(_queue.pop_front())

func _render(job: Dictionary) -> void:
	_busy = true
	if _vp == null:
		_build_stage()
	var rec: Dictionary = job["rec"]
	var lk: Dictionary = rec.get("look", {})
	var stage := int(rec.get("stage", 2))
	var outfit := int(lk.get("outfit", -1))
	if outfit < 0:
		outfit = (posmod(int(lk.get("skin", 0)) + int(lk.get("hair", 0)) + int(rec.get("uid", 0)), 4)) * 2 + (1 if str(rec.get("sex", "f")) == "f" else 0)
	_visual.apply_look(int(lk.get("skin", 0)), int(lk.get("hair", 0)), float(lk.get("height", 1.0)), stage == 3, stage, outfit)
	_visual.set_job_colour(&"")
	if _visual.villager != null:
		_visual.villager.play(&"idle", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var top := _top_of(_visual)
	var head := top - clampf(top * 0.13, 0.12, 0.26)
	var dist := clampf(top * 0.95, 0.9, 2.4)
	_cam.position = Vector3(0.18 * dist, head + 0.02, dist)
	_cam.look_at(Vector3(0, head - top * 0.06, 0), Vector3.UP)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var img := _vp.get_texture().get_image()
	if img != null and not img.is_empty():
		cache[job["key"]] = ImageTexture.create_from_image(img)
		portrait_ready.emit(job["key"])
	_queued.erase(job["key"])
	_busy = false

## The top of the figure in metres (from its meshes' boxes).
static func _top_of(n: Node3D) -> float:
	var top := 0.0
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		if vi == null or not vi.is_visible_in_tree() or vi is Light3D:
			continue
		var bb := vi.global_transform * vi.get_aabb()
		top = maxf(top, bb.end.y)
	return top if top > 0.2 else 1.7
