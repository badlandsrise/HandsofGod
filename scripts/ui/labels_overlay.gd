class_name LabelsOverlay extends Control
## Tab: every person's name and every site's label, drawn over the world.

var shown: bool = false:
	set(v): shown = v; visible = v; queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

func _process(_d: float) -> void:
	if shown:
		queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := get_theme_default_font()
	var inv := get_global_transform_with_canvas().affine_inverse()
	for s in Village.sites:
		if s is Site and is_instance_valid(s) and s.is_visible_in_tree():
			_tag(cam, inv, f, s.global_position + Vector3(0, 2.0, 0), s.hover_text(), 14, Color(0.95, 0.9, 0.75))
	for p in Village.people:
		if p is Person and is_instance_valid(p) and p.is_visible_in_tree():
			_tag(cam, inv, f, p.global_position + Vector3(0, 1.75, 0), p.given_name, 15, UiTheme.TEXT)

func _tag(cam: Camera3D, inv: Transform2D, f: Font, wp: Vector3, text: String, fs: int, col: Color) -> void:
	if text == "" or cam.is_position_behind(wp):
		return
	var sp: Vector2 = inv * cam.unproject_position(wp)
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2(sp - Vector2(sz.x * 0.5 + 6, sz.y * 0.5 + 2), sz + Vector2(12, 4))
	draw_style_box(UiTheme.box(Color(0.12, 0.08, 0.05, 0.72), Color(0, 0, 0, 0), 6, 0.0, 0), r)
	draw_string(f, Vector2(r.position.x + 6, r.position.y + 2 + f.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
