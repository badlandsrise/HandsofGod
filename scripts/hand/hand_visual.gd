class_name HandVisual extends Node3D
## How the hand looks and feels. The body is a swappable HandModel scene (the
## white cartoon glove, scenes/hand/hand_model.tscn); this node poses, places,
## fades and juices it, and draws the ground shadow, the cursor dot and target
## ring, the scoop circle and sweep trail, ghost previews of where held people
## land, slot pips over the hovered site, and the tooltip next to the cursor.
##
## Placement: the hand floats on the camera ray through the aimed ground point,
## so its fingertips (empty) or cupped palm (holding) sit exactly over the cursor
## on screen, while the wrist trails up and away, beside the target rather than
## on it, and held people hang below the fingers in plain view. Its size follows the camera distance (about a third of the
## screen), so it never swamps the view when zoomed in.
##
## Hand calls sync(hand, dt) every frame, and the one-shots strain(), dip(),
## sparkle(at), lifted(points) and placed(points).

const GROUND_SHADER := preload("res://assets/textures/shaders/ground_fx.gdshader")
const ERA_GLOW := {
	1: Color(1.0, 0.62, 0.26),   # amber
	2: Color(1.0, 0.82, 0.38),   # gold
	3: Color(1.0, 0.97, 0.92),   # white
	4: Color(0.62, 0.82, 1.0),   # pale blue
}
const MAX_GHOSTS := 20
## Hand length as a fraction of the visible screen height at the hand's distance.
const SCREEN_FRAC := 0.3
const MIN_LEN := 2.6
const MAX_LEN := 26.0
## The hand reaches in from the far side of the view: fingers toward the camera
## (down-screen), turned this far to the left, the wrist trailing up and right.
## Held people then dangle below the fingers in plain sight, and the open cuff
## faces away from the camera.
const YAW_LEFT := -0.38
## Order fingers close as people are added: little, ring, middle, index, thumb.
const CLOSE_ORDER := [4, 3, 2, 1, 0]
const WAVE_AFTER := 0.8        # seconds hovering a friend before waving back
const WAVE_TIME := 1.9
const EDGE_PX := 90.0

@export var model_scene: PackedScene = preload("res://scenes/hand/hand_model.tscn")

var model: HandModel
var cursor_dot: MeshInstance3D
var shadow: MeshInstance3D
var ring: MeshInstance3D
var scoop_ring: MeshInstance3D
var trail: MeshInstance3D
var ghosts: Array = []                 # Node3D ghost people
var pips_root: Node3D
var pips: Array = []
var badge: Label3D
var tip_layer: CanvasLayer
var tip_panel: PanelContainer
var tip_label: Label

var glow_color: Color = ERA_GLOW[1]
## Smoothed pose and look, exposed for tests.
var curl := PackedFloat32Array([0, 0, 0, 0, 0])
var cup: float = 0.0
var point: float = 0.0
var spread: float = 0.8
var hold_blend: float = 0.0
var solidity: float = 0.0
var opacity: float = 1.0
var hand_len: float = 6.0
var waving: float = 0.0                # > 0 while waving back at a friend

var _tip_down: float = 26.0
var _roll: float = 10.0
var _strain: float = 0.0
var _flash: float = 0.0
var _glow: float = 1.0
var _squash: float = 0.0
var _push: float = 0.0
var _hover_t: float = 0.0
var _hover_who: Node = null
var _wave_cd: Dictionary = {}          # instance id -> time left before waving again
var _trail_pts: Array = []             # [Vector3, age]
var _hud_rects: Array = []
var _hud_t: float = 0.0
var _last_air := Vector3.INF
var _vel := Vector3.ZERO
var _scoop_w := 0.0                    # 0 = the usual pose .. 1 = the dustpan scoop
var _scoop_dir := Vector3.ZERO         # the sweep's direction (flat, smoothed)
var _shadow_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _scoop_mat: ShaderMaterial
var _trail_mat: StandardMaterial3D
var _dot_mat: StandardMaterial3D
var _ghost_mat: StandardMaterial3D
var _ghost_ring_mat: ShaderMaterial
var _pip_full: StandardMaterial3D
var _pip_new: StandardMaterial3D
var _pip_empty: StandardMaterial3D

func _ready() -> void:
	_build_model()
	_build_ground_fx()
	_build_ghosts()
	_build_tooltip()
	set_era(Village.era)
	Events.era_changed.connect(set_era)
	Events.region_opened.connect(_on_region_opened)

func set_era(era: int) -> void:
	glow_color = ERA_GLOW.get(clampi(era, 1, 4), ERA_GLOW[1])
	if _ring_mat:
		_ring_mat.set_shader_parameter(&"color", Color(glow_color, 0.85))
		_scoop_mat.set_shader_parameter(&"color", Color(glow_color, 0.9))
		_trail_mat.albedo_color = Color(glow_color.lerp(Color.WHITE, 0.25), 0.95)
		_dot_mat.albedo_color = glow_color.lerp(Color.WHITE, 0.55)

# ---------------------------------------------------------------- building

func _build_model() -> void:
	model = model_scene.instantiate() as HandModel
	model.name = "Model"
	add_child(model)
	model.top_level = true
	# the cursor point: a crisp glowing dot drawn over everything
	_dot_mat = StandardMaterial3D.new()
	_dot_mat.albedo_texture = HandFx._soft()
	_dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_dot_mat.no_depth_test = true
	_dot_mat.fixed_size = true
	_dot_mat.render_priority = 4
	_dot_mat.albedo_color = Color(1.0, 0.9, 0.7)
	cursor_dot = MeshInstance3D.new()
	cursor_dot.name = "CursorDot"
	var q := QuadMesh.new()
	q.size = Vector2(0.034, 0.034)
	cursor_dot.mesh = q
	cursor_dot.material_override = _dot_mat
	cursor_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor_dot.top_level = true
	add_child(cursor_dot)

func _build_ghosts() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.35)
	_ghost_mat.no_depth_test = false
	_ghost_ring_mat = _gmat(Color(1.0, 0.95, 0.75, 0.9), 0.7)
	_ghost_ring_mat.set_shader_parameter(&"ring_width", 0.12)
	var root := Node3D.new()
	root.name = "Ghosts"
	root.top_level = true
	add_child(root)
	for i in MAX_GHOSTS:
		var g := Node3D.new()
		root.add_child(g)
		var body := _mesh(g, _capsule(0.22, 0.75), Vector3(0, 0.42, 0), _ghost_mat)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var head := _mesh(g, _sphere(0.2), Vector3(0, 0.98, 0), _ghost_mat)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var gr := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.1, 1.1)
		gr.mesh = pm
		gr.material_override = _ghost_ring_mat
		gr.position.y = 0.05
		g.add_child(gr)
		g.visible = false
		ghosts.append(g)
	pips_root = Node3D.new()
	pips_root.name = "SitePips"
	pips_root.top_level = true
	add_child(pips_root)
	_pip_full = _pip_mat(Color(1.0, 0.86, 0.45), false)
	_pip_new = _pip_mat(Color(1.0, 0.98, 0.85, 0.85), false)
	_pip_empty = _pip_mat(Color(0.2, 0.15, 0.1, 0.65), true)
	for i in MAX_GHOSTS:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.42, 0.42)
		q.mesh = qm
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visible = false
		pips_root.add_child(q)
		pips.append(q)
	badge = Label3D.new()
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = true
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.fixed_size = true
	badge.pixel_size = 0.0011
	badge.font_size = 24
	badge.outline_size = 10
	badge.modulate = Color(1.0, 0.93, 0.78)
	badge.outline_modulate = Color(0.25, 0.12, 0.05, 0.95)
	badge.render_priority = 3
	badge.outline_render_priority = 2
	pips_root.add_child(badge)

func _build_tooltip() -> void:
	tip_layer = CanvasLayer.new()
	tip_layer.layer = 20
	tip_layer.name = "Tooltip"
	add_child(tip_layer)
	tip_panel = PanelContainer.new()
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.11, 0.07, 0.86)
	sb.border_color = Color(1.0, 0.78, 0.45, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 5; sb.content_margin_bottom = 5
	tip_panel.add_theme_stylebox_override(&"panel", sb)
	tip_label = Label.new()
	tip_label.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.85))
	tip_label.add_theme_font_size_override(&"font_size", 17)
	tip_panel.add_child(tip_label)
	tip_layer.add_child(tip_panel)
	tip_panel.visible = false

# ---------------------------------------------------------------- per frame


func _build_ground_fx() -> void:
	_shadow_mat = _gmat(Color(0.05, 0.03, 0.02, 0.3), 0.0)
	shadow = _plane(_shadow_mat, 1.0)
	shadow.name = "Shadow"
	_ring_mat = _gmat(Color(glow_color, 0.85), 0.8)
	_ring_mat.set_shader_parameter(&"ring_width", 0.09)
	ring = _plane(_ring_mat, 1.0)
	ring.name = "TargetRing"
	_scoop_mat = _gmat(Color(glow_color, 0.9), 0.95)
	_scoop_mat.set_shader_parameter(&"ring_width", 0.03)
	_scoop_mat.set_shader_parameter(&"dashes", 18.0)
	scoop_ring = _plane(_scoop_mat, 1.0)
	scoop_ring.name = "ScoopRing"
	scoop_ring.visible = false
	# the sweep arc: a glowing ribbon on the ground behind the scooping hand
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mat.albedo_color = Color(glow_color.lerp(Color.WHITE, 0.25), 0.95)
	trail = MeshInstance3D.new()
	trail.name = "SweepTrail"
	trail.mesh = ImmediateMesh.new()
	trail.material_override = _trail_mat
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.top_level = true
	add_child(trail)

# ---------------------------------------------------------------- per frame

func sync(hand: Hand, dt: float) -> void:
	_strain = maxf(_strain - dt, 0.0)
	_flash = maxf(_flash - dt, 0.0)
	_squash = maxf(_squash - dt * 3.5, 0.0)
	_push = maxf(_push - dt, 0.0)
	waving = maxf(waving - dt, 0.0)
	for k in _wave_cd.keys():
		_wave_cd[k] = float(_wave_cd[k]) - dt
		if float(_wave_cd[k]) <= 0.0:
			_wave_cd.erase(k)
	if _last_air.is_finite() and dt > 0.0:
		_vel = _vel.lerp((hand.air_pos - _last_air) / dt, minf(8.0 * dt, 1.0))
	_last_air = hand.air_pos
	_update_wave(hand, dt)
	_pose(hand, dt)
	_place(hand, dt)
	_look(hand, dt)
	_update_ground(hand, dt)
	_update_trail(hand, dt)
	_update_ghosts(hand)
	_update_tooltip(hand)

## Starts a wave back when the hand lingers over someone who waves at it.
func _update_wave(hand: Hand, dt: float) -> void:
	var p := hand.hover_person
	if p != _hover_who:
		_hover_who = p
		_hover_t = 0.0
	if p == null or not is_instance_valid(p) or hand.is_holding() or hand.scooping:
		_hover_t = 0.0
		return
	_hover_t += dt
	var friendly := int(p.get(&"trust")) >= 3 if &"trust" in p else false
	var id := p.get_instance_id()
	if friendly and _hover_t >= WAVE_AFTER and waving <= 0.0 and not _wave_cd.has(id):
		waving = WAVE_TIME
		_wave_cd[id] = 6.0

func _pose(hand: Hand, dt: float) -> void:
	var g := hand.grip()
	var n := hand.held.size()
	var full := hand.held_object != null or (n > 0 and n >= g)
	var reaching := hand.hover_person != null or hand.hover_thing != null
	var c := [0.0, -0.35, -0.35, -0.3, -0.2]   # relaxed open
	var t_cup := 0.0
	var t_point := 0.0
	var t_spread := 0.8 + 0.12 * sin(hand.time * 1.3)
	var t_hold := 0.0
	var t_tip := 26.0
	var t_roll := 12.0
	if full:
		c = [1.0, 1.0, 1.0, 1.0, 1.0]         # a fist around everyone
		t_cup = 1.0
		t_spread = 0.0
		t_hold = 1.0
		t_tip = 18.0
	elif n > 0:
		# cupped, with one finger closed per person held (scaled to the grip)
		c = [0.3, 0.35, 0.35, 0.35, 0.35]
		var closed := n if g <= 5 else int(ceil(float(n) * 5.0 / float(g)))
		for i in mini(closed, 5):
			c[CLOSE_ORDER[i]] = 0.9
		t_cup = 0.9
		t_spread = 0.0
		t_hold = 1.0
		t_tip = 18.0
	elif hand.scooping:
		c = HandScoop.CURL.duplicate()             # cupped, fingers together: a dustpan
		t_cup = HandScoop.CUP
		t_spread = HandScoop.SPREAD
		t_hold = 0.7
	elif reaching:
		c = [0.3, 0.3, 0.32, 0.35, 0.4]
		t_cup = 0.4
		t_spread = 0.45
		t_tip = 38.0
	if hand.gesture_power != &"" and hand.gesture_charge > 0.0:
		var kind: StringName = hand.gesture_target().get("kind", &"sky")
		if kind == &"sky":
			c = [0.0, 0.0, 0.0, 0.0, 0.0]
			t_point = 1.0                      # point at the sky
			t_tip = 10.0
		else:
			c = [-0.4, -0.8, -0.8, -0.8, -0.7]  # flat open palm, fingers fanned
			t_spread = 1.6
			t_tip = 14.0
	if waving > 0.0:
		c = [-0.2, -0.7, -0.7, -0.6, -0.5]
		t_spread = 1.3
		t_tip = 4.0
	if _strain > 0.0:
		var j := sin(hand.time * 40.0) * 0.15
		for i in 5:
			c[i] = clampf(float(c[i]) + 0.45 + j * (1.0 if i % 2 == 0 else -1.0), -1.0, 1.0)
	var k := minf(10.0 * dt, 1.0)
	for i in 5:
		curl[i] = lerpf(curl[i], float(c[i]), k)
	cup = lerpf(cup, t_cup, k)
	point = lerpf(point, t_point, k)
	spread = lerpf(spread, t_spread, k)
	hold_blend = lerpf(hold_blend, t_hold, minf(6.0 * dt, 1.0))
	_tip_down = lerpf(_tip_down, t_tip, minf(5.0 * dt, 1.0))
	_roll = lerpf(_roll, t_roll, minf(5.0 * dt, 1.0))
	model.set_pose(curl, cup, point, spread)

## Places the hand on the camera ray through its anchor: fingertips or cup over
## the cursor, wrist trailing up and away, sized to the screen.
func _place(hand: Hand, dt: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var anchor := hand.air_pos
	var fwd := Vector3(0, 0, -1)
	var dist := 30.0
	var fov := 45.0
	if cam:
		fwd = -cam.global_basis.z
		dist = maxf(cam.global_position.distance_to(anchor), 2.0)
		fov = cam.fov
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
	var target_len := clampf(SCREEN_FRAC * 2.0 * tan(deg_to_rad(fov) * 0.5) * dist, MIN_LEN, MAX_LEN)
	hand_len = target_len if hand_len <= 0.0 else lerpf(hand_len, target_len, minf(4.0 * dt, 1.0))
	var yaw_dir := (-fwd).rotated(Vector3.UP, YAW_LEFT)
	var b := Basis.looking_at(yaw_dir, Vector3.UP)          # -Z = fingers
	var tip := _tip_down
	# leaning with the motion: the hand trails a little as it moves
	var lv := b.inverse() * _vel
	tip += clampf(-lv.z * 0.6, -10.0, 10.0)
	var roll := _roll + clampf(lv.x * 0.8, -12.0, 12.0)
	if _push > 0.0:
		var u := 1.0 - _push / 0.9
		tip -= 30.0 * sin(u * PI)                            # heave: fingers lift
	b = b * Basis(Vector3.RIGHT, deg_to_rad(-tip)) * Basis(Vector3.FORWARD, deg_to_rad(-roll))
	var wob := 0.0
	if _strain > 0.0:
		wob = sin(hand.time * 48.0) * 0.12 * (_strain / 0.6)
	if is_instance_valid(hand.held_object):
		var w: float = hand.held_object.lift_weight() if hand.held_object.has_method(&"lift_weight") else 1.0
		var ld := clampf(w / maxf(Faith.strength, 0.01), 0.0, 1.0)
		wob += sin(hand.time * 31.0) * 0.03 * ld * ld
	b = b * Basis(Vector3.FORWARD, wob)
	# squash on lift and land: wider and flatter for a beat, then back
	var sq := sin(_squash * PI) * 0.16
	var scale_v := Vector3(1.0 + sq, 1.0 - sq * 1.2, 1.0 + sq * 0.5) * hand_len
	var bs := b.scaled(scale_v)
	var lift := Vector3.ZERO
	if _push > 0.0:
		lift.y = sin((1.0 - _push / 0.9) * PI) * hand_len * 0.15
	var xf := Transform3D(bs, anchor + lift - bs * model.anchor_local(hold_blend))
	# the scoop: turn the hand onto its edge, palm into the sweep, the edge on the ground
	_scoop_w = move_toward(_scoop_w, 1.0 if hand.scooping else 0.0, dt * 5.0)
	if _scoop_w > 0.0:
		var flat := Vector3(_vel.x, 0.0, _vel.z)
		if flat.length() > 1.0:
			_scoop_dir = _scoop_dir.lerp(flat.normalized(), minf(6.0 * dt, 1.0)) if _scoop_dir != Vector3.ZERO else flat.normalized()
		if _scoop_dir.length() < 0.1:
			_scoop_dir = fwd.cross(Vector3.UP).normalized()   # at rest: as if sweeping right to left
		var sb := HandScoop.basis(_scoop_dir.normalized(), fwd)
		var e := smoothstep(0.0, 1.0, _scoop_w)
		var nb := b.orthonormalized().slerp(sb, e).scaled(scale_v)
		var origin := anchor - nb * model.anchor_local(hold_blend)
		var ground_y: float = hand.ground.y if hand.ground.is_finite() else anchor.y - 2.2
		origin.y += lerpf(0.0, HandScoop.lift(nb, origin, ground_y + HandScoop.CLEAR * hand_len), e)
		xf = Transform3D(nb, origin)
	if waving > 0.0:
		# wave back: swing the hand side to side about the wrist
		var u := 1.0 - waving / WAVE_TIME
		var amp := sin(u * PI) * 0.42
		var pivot := xf.origin
		var r := Basis(b.y.normalized(), sin(u * TAU * 2.6) * amp)
		xf = Transform3D(r * xf.basis, pivot)
	model.global_transform = xf
	cursor_dot.global_position = anchor
	var pulse := 1.0 + 0.15 * sin(hand.time * 5.0)
	cursor_dot.scale = Vector3.ONE * pulse * (1.25 if hand.primary_target() != null else 1.0)

## Solid when holding or about to grab, a soft ghost when empty; fades under
## HUD panels and near the screen edges.
func _look(hand: Hand, dt: float) -> void:
	var reaching := hand.hover_person != null or hand.hover_thing != null
	var s := 0.0
	if hand.is_holding():
		s = 1.0
	elif hand.scooping:
		s = 0.85
	elif reaching or waving > 0.0:
		s = 0.8
	elif hand.gesture_power != &"" and hand.gesture_charge > 0.0:
		s = 0.7
	solidity = move_toward(solidity, s, dt * 3.0)
	var o := _screen_fade(hand)
	opacity = lerpf(opacity, o, minf(8.0 * dt, 1.0))
	var g := 1.0
	var full := hand.held_object != null or (hand.held.size() > 0 and hand.held.size() >= hand.grip())
	if full:
		g = 1.8 + 0.3 * sin(hand.time * 4.0)              # fist glow at full grip
	g += hand.gesture_level() * (1.4 + 0.4 * sin(hand.time * 9.0))
	g += _flash * 2.5 + (_push / 0.9) * 2.0
	if _strain > 0.0:
		g *= 0.7
	_glow = lerpf(_glow, g, minf(10.0 * dt, 1.0))
	model.set_look(solidity, opacity, _glow, glow_color)
	_dot_mat.albedo_color.a = clampf(0.95 * opacity + 0.05, 0.0, 1.0)
	cursor_dot.visible = hand.mouse_on_ground

## 1 normally; lower when the hand sits under a HUD panel or near a screen edge.
func _screen_fade(hand: Hand) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 1.0
	var vp := get_viewport().get_visible_rect().size
	var pts: Array = []
	for lp in [model.anchor_local(hold_blend), Vector3(0, 0, -0.45), Vector3(0, 0, 0)]:
		var wp: Vector3 = model.global_transform * lp
		if not cam.is_position_behind(wp):
			pts.append(cam.unproject_position(wp))
	_hud_t -= get_process_delta_time()
	if _hud_t <= 0.0:
		_hud_t = 0.5
		_hud_rects.clear()
		var hud := get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			for c in hud.find_children("*", "PanelContainer", true, false):
				var pc := c as PanelContainer
				if pc.is_visible_in_tree() and pc != tip_panel:
					_hud_rects.append(pc.get_global_rect().grow(24.0))
	var f := 1.0
	for i in pts.size():
		var sp: Vector2 = pts[i]
		for r in _hud_rects:
			if (r as Rect2).has_point(sp):
				f = minf(f, 0.3 if i == 0 else 0.5)
		if i == 0:
			var edge := minf(minf(sp.x, vp.x - sp.x), minf(sp.y, vp.y - sp.y))
			f = minf(f, lerpf(0.35, 1.0, clampf(edge / EDGE_PX, 0.0, 1.0)))
	return f

func _update_ground(hand: Hand, _dt: float) -> void:
	var gp := hand.ground
	if not gp.is_finite():
		gp = Vector3.ZERO
	# the soft shadow sits under the palm, wider the higher the hand floats
	var palm: Vector3 = model.global_transform * Vector3(0, 0, -0.45)
	var gy := hand._ground_y(palm.x, palm.z)
	var height := maxf(palm.y - gy, 0.5)
	var s := hand_len * clampf(0.75 + height * 0.03, 0.75, 1.3)
	shadow.global_position = Vector3(palm.x, gy + 0.05, palm.z)
	shadow.scale = Vector3(s * 0.7, 1, s)
	shadow.rotation.y = model.global_rotation.y
	_shadow_mat.set_shader_parameter(&"color", Color(0.05, 0.03, 0.02, clampf(0.36 - height * 0.012, 0.1, 0.3) * opacity))
	# the target ring: small and crisp under the cursor, the site's own size when placing
	var rr := 0.7
	if hand.held.size() > 1:
		rr = 0.6 + 0.22 * float(hand.held.size())
	if is_instance_valid(hand.hover_site) and hand.is_holding():
		rr = hand.hover_site.pick_radius()
		gp = hand.hover_site.global_position
	ring.global_position = Vector3(gp.x, gp.y + 0.06, gp.z)
	ring.scale = Vector3.ONE * rr * 2.2
	ring.visible = hand.mouse_on_ground
	_ring_mat.set_shader_parameter(&"pulse", 0.3 + 0.3 * sin(hand.time * 5.0) if hand.is_holding() else 0.0)
	scoop_ring.visible = hand.scooping and hand.scoop_radius > 0.2
	if scoop_ring.visible:
		var c := hand.scoop_center
		scoop_ring.global_position = Vector3(c.x, c.y + 0.07, c.z)
		scoop_ring.scale = Vector3.ONE * hand.scoop_radius * 2.0 / 0.95
		_scoop_mat.set_shader_parameter(&"spin", hand.time * 0.8)

## The sweep arc: the last second of where the scooping hand passed, as a
## glowing ribbon on the ground that fades from its tail.
func _update_trail(hand: Hand, dt: float) -> void:
	for p in _trail_pts:
		p[1] = float(p[1]) + dt
	while not _trail_pts.is_empty() and float(_trail_pts[0][1]) > 1.2:
		_trail_pts.pop_front()
	if hand.scooping and hand.ground.is_finite():
		var g := hand.ground
		if _trail_pts.is_empty() or (_trail_pts[-1][0] as Vector3).distance_to(g) > 0.25:
			_trail_pts.append([g, 0.0])
	var im := trail.mesh as ImmediateMesh
	im.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trail_pts.size()
	for i in n:
		var p: Vector3 = _trail_pts[i][0]
		var nxt: Vector3 = _trail_pts[mini(i + 1, n - 1)][0]
		var prv: Vector3 = _trail_pts[maxi(i - 1, 0)][0]
		var d := (nxt - prv)
		d.y = 0.0
		var side := Vector3(-d.z, 0, d.x).normalized() if d.length() > 0.001 else Vector3.RIGHT
		var f := float(i) / float(n - 1)
		var a := sqrt(f) * (1.0 - float(_trail_pts[i][1]) / 1.2)
		var w := 0.2 + 0.55 * f
		var y := hand._ground_y(p.x, p.z) + 0.09
		im.surface_set_color(Color(1, 1, 1, a))
		im.surface_add_vertex(Vector3(p.x, y, p.z) + side * w)
		im.surface_set_color(Color(1, 1, 1, a))
		im.surface_add_vertex(Vector3(p.x, y, p.z) - side * w)
	im.surface_end()

func _update_ghosts(hand: Hand) -> void:
	var spots: Array = []
	var s := hand.hover_site
	var show_pips := is_instance_valid(s) and not hand.held.is_empty()
	if show_pips:
		var n := mini(hand.held.size(), s.free_slots())
		while n > 0 and not s.can_accept(n):
			n -= 1
		spots = hand.site_spots(s, n)
	elif not hand.held.is_empty() and hand.mouse_on_ground and hand.held.size() > 1:
		spots = hand.ground_spots(hand.ground, hand.held.size())
	for i in ghosts.size():
		var g: Node3D = ghosts[i]
		g.visible = i < spots.size()
		if g.visible:
			var p: Vector3 = spots[i]
			g.global_position = Vector3(p.x, hand._ground_y(p.x, p.z), p.z)
	# slot pips over the site: filled, about to be filled, empty
	for q in pips:
		(q as MeshInstance3D).visible = false
	badge.visible = false
	if not show_pips:
		return
	var filled := hand.site_filled(s)
	var mx := mini(hand.site_max(s), MAX_GHOSTS)
	var adding := spots.size()
	# pips sit on the ground in front of the site (toward the camera) so the
	# hand above the site never hides them
	var cam := get_viewport().get_camera_3d()
	var right := cam.global_basis.x if cam else Vector3.RIGHT
	var toward := cam.global_basis.z if cam else Vector3.BACK
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.BACK
	var top := s.global_position + toward * (s.pick_radius() + 0.9) + Vector3(0, 0.45, 0)
	var gap := 0.5
	for i in mx:
		var q: MeshInstance3D = pips[i]
		q.visible = true
		q.global_position = top + right * (float(i) - float(mx - 1) * 0.5) * gap
		q.material_override = _pip_full if i < filled else (_pip_new if i < filled + adding else _pip_empty)
		var pulse := 1.0 + (0.18 * sin(hand.time * 8.0) if i >= filled and i < filled + adding else 0.0)
		q.scale = Vector3.ONE * pulse
	var needs := s.group_needs()
	if needs > 0 and filled < needs:
		badge.visible = true
		badge.text = "needs %d" % needs
		badge.global_position = top + right * (float(mx) * 0.5 * gap + 0.25)
		badge.modulate.a = 0.8 + 0.2 * sin(hand.time * 4.0)

func _update_tooltip(hand: Hand) -> void:
	var t := hand.tooltip_text()
	tip_panel.visible = t != ""
	if t == "":
		return
	tip_label.text = t
	var sp := hand.aim_screen()
	var sc := 1.0
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and &"ui_scale" in hud:
		sc = float(hud.get(&"ui_scale"))
	tip_panel.scale = Vector2(sc, sc)
	tip_panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	# Below the slot pips and the "needs N" badge when they show.
	var pos := sp + (Vector2(26, 62) if badge.visible else Vector2(26, 20))
	var sz := tip_panel.size * sc
	pos.x = minf(pos.x, vp.x - sz.x - 8)
	pos.y = minf(pos.y, vp.y - sz.y - 8)
	tip_panel.position = pos

# ---------------------------------------------------------------- one-shots


# ---------------------------------------------------------------- one-shots

func strain() -> void:
	_strain = 0.6

## Setting down: a soft glow pulse (the lowering ease lives in Hand.dip_t).
func dip() -> void:
	_flash = 0.25

## Lifting: a squash, and a dust puff where each person stood.
func lifted(points: Array) -> void:
	_squash = 1.0
	_flash = maxf(_flash, 0.2)
	for p in points:
		if p is Vector3 and (p as Vector3).is_finite():
			HandFx.dust(self, p, 0.8)

## Placing: a squash and a landing puff at each spot, timed to their touchdown.
func placed(points: Array) -> void:
	_squash = 0.7
	var pts := points.duplicate()
	if not is_inside_tree():
		return
	get_tree().create_timer(0.22, true, false, true).timeout.connect(func():
		if not is_instance_valid(self):
			return
		for p in pts:
			if p is Vector3 and (p as Vector3).is_finite():
				HandFx.dust(self, p, 0.6))

func sparkle(at: Vector3) -> void:
	_flash = 0.6
	HandFx.sparkle(self, at, glow_color, _last_air)

## A region opens: the hand heaves up with a burst of glow.
func _on_region_opened(_id: StringName) -> void:
	_push = 0.9
	_flash = 0.6

# ---------------------------------------------------------------- helpers

func _mesh(parent: Node, m: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 14
	c.rings = 4
	return c

func _gmat(c: Color, ring_inner: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter(&"color", c)
	m.set_shader_parameter(&"ring_inner", ring_inner)
	m.render_priority = 1
	return m

func _plane(m: Material, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	return mi

func _pip_mat(c: Color, hollow: bool) -> StandardMaterial3D:
	var grad := Gradient.new()
	if hollow:
		grad.offsets = PackedFloat32Array([0.0, 0.5, 0.56, 0.86, 0.92])
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.15), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	else:
		grad.offsets = PackedFloat32Array([0.0, 0.78, 0.92])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 2
	return m
