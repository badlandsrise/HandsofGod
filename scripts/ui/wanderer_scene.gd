class_name WandererScene extends CanvasLayer
## [polish] The first wanderer's arrival as a short, skippable mini-cutscene
## (Austin: "a cutscene or something"). Cinema bars come in, the camera finds
## the stranger stepping out of the trees and walks in with them, then pulls
## back to the tribe, who stop what they are doing and turn to look. One line
## of text. A key or a click skips it; the camera and the hand come back as
## they were. Guidance starts it like a beat (when no card or menu is open).

signal finished

const LENGTH := 7.5
const PULL_AT := 3.4            # when the camera pulls back to take in the tribe
const BAR_H := 70.0
const GAZE_RADIUS := 45.0       # the tribe within this of the wanderer turn to look

var wanderer: Node3D = null
var line: String = ""
var t: float = 0.0
var skipped := false
var done := false

var _cam: Node = null
var _cam_back := Vector3.INF
var _cam_back_dist := -1.0
var _cam_input := true
var _hand: Node = null
var _hand_input := true
var _top: ColorRect
var _bottom: ColorRect
var _skip: Label
var _caption: Label
var _gazed := false

static func play(p: Node3D, text: String, parent: Node) -> WandererScene:
	var s := WandererScene.new()
	s.wanderer = p
	s.line = text
	parent.add_child(s)
	return s

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_top = _bar(true)
	_bottom = _bar(false)
	_caption = Label.new()
	_caption.text = line
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -BAR_H
	_caption.offset_bottom = 0.0
	_caption.add_theme_font_override(&"font", UiTheme.font(&"title_italic"))
	_caption.add_theme_font_size_override(&"font_size", 26)
	_caption.add_theme_color_override(&"font_color", Color("#f4e6c8"))
	_caption.modulate.a = 0.0
	add_child(_caption)
	_skip = Label.new()
	_skip.text = "Space or click to skip"
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -240.0
	_skip.offset_right = -18.0
	_skip.offset_top = 22.0
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip.add_theme_font_size_override(&"font_size", 14)
	_skip.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.55))
	add_child(_skip)
	_cam = get_tree().get_first_node_in_group(&"camera_rig")
	if _cam != null and &"target_focus" in _cam:
		_cam_back = _cam.target_focus
		_cam_back_dist = _cam.target_dist
		_cam_input = bool(_cam.input_enabled)
		_cam.input_enabled = false
	_hand = get_tree().get_first_node_in_group(&"hand")
	if _hand != null and &"input_enabled" in _hand:
		_hand_input = bool(_hand.input_enabled)
		_hand.input_enabled = false
	_frame_wanderer(true)

func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		r.offset_bottom = 0.0
	else:
		r.offset_top = 0.0
	add_child(r)
	return r

func _input(e: InputEvent) -> void:
	if done:
		return
	var key: bool = e is InputEventKey and e.pressed and not e.echo
	var click: bool = e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT)
	if key or click:
		get_viewport().set_input_as_handled()
		skip()

func skip() -> void:
	if done:
		return
	skipped = true
	_finish()

func _process(_d: float) -> void:
	if done:
		return
	var dt := Clock.real_delta if Clock.real_delta > 0.0 else _d
	t += dt
	var bars := _ss(0.0, 0.6, t) * (1.0 - _ss(LENGTH - 0.6, LENGTH, t))
	_top.offset_bottom = BAR_H * bars
	_bottom.offset_top = -BAR_H * bars
	_caption.offset_top = -BAR_H * bars
	_caption.modulate.a = _ss(0.5, 1.2, t) * (1.0 - _ss(LENGTH - 0.9, LENGTH - 0.3, t))
	if wanderer == null or not is_instance_valid(wanderer):
		_finish()
		return
	if t < PULL_AT:
		_frame_wanderer(false)
	else:
		_frame_tribe()
	if t >= LENGTH:
		_finish()

func _frame_wanderer(snap: bool) -> void:
	if _cam == null or wanderer == null or not is_instance_valid(wanderer):
		return
	if snap and _cam.has_method(&"snap_to"):
		_cam.focus_on(wanderer.global_position, 15.0)
	else:
		_cam.focus_on(wanderer.global_position, 15.0)

## The tribe and the newcomer in one frame; the tribe turns to look.
func _frame_tribe() -> void:
	var at := wanderer.global_position
	var sum := at
	var n := 1
	var watchers := 0
	for p in Village.alive():
		if p == wanderer or not is_instance_valid(p) or not p.visible:
			continue
		var d: float = (p as Node3D).global_position.distance_to(at)
		if d > GAZE_RADIUS:
			continue
		if not _gazed and p.has_method(&"gaze"):
			p.gaze(wanderer, LENGTH - t + 1.5, watchers == 0)
			watchers += 1
		if d < 30.0:
			sum += (p as Node3D).global_position
			n += 1
	_gazed = true
	if _cam != null:
		var c := sum / float(n)
		_cam.focus_on(c.lerp(at, 0.35), clampf(14.0 + (c - at).length() * 0.9, 18.0, 34.0))

func _finish() -> void:
	if done:
		return
	done = true
	if _cam != null and is_instance_valid(_cam):
		_cam.input_enabled = _cam_input
		if _cam_back.is_finite():
			_cam.focus_on(_cam_back, _cam_back_dist)
	if _hand != null and is_instance_valid(_hand):
		_hand.input_enabled = _hand_input
	finished.emit()
	queue_free()

static func _ss(a: float, b: float, x: float) -> float:
	var k := clampf((x - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)
