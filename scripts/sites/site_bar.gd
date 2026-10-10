class_name SiteBar extends Node3D
## A small billboard progress bar over a site (group jobs, build plots).

var _bg: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
const W := 1.6
const H := 0.16

func _ready() -> void:
	_bg = _quad(Color(0.1, 0.08, 0.06, 0.75), Vector2(W + 0.08, H + 0.08), 0)
	_fill = _quad(Color(1, 0.85, 0.3), Vector2(W, H), 1)
	_fill_mat = _fill.material_override
	visible = false

func _quad(c: Color, size: Vector2, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = prio
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func show_value(v: float, c: Color) -> void:
	if _fill == null:
		return
	visible = true
	v = clampf(v, 0.0, 1.0)
	_fill_mat.albedo_color = c
	# Shrink the fill quad's mesh width; billboards ignore local offsets, so
	# the bar shrinks toward the centre, which reads fine at this size.
	(_fill.mesh as QuadMesh).size = Vector2(maxf(W * v, 0.001), H)

func hide_bar() -> void:
	visible = false
