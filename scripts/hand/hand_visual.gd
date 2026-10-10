class_name HandVisual extends Node3D
## Placeholder look of the hand, built from primitives: a soft translucent palm,
## four jointed fingers and a thumb, a fading forearm, with a warm fresnel rim
## glow whose colour follows the era. Also draws the ground shadow, the target
## ring, the scoop circle, ghost previews of where held people will land, slot
## pips over the hovered site, and the tooltip next to the cursor.
## The whole node is replaceable: Hand only calls sync(hand, dt), strain(),
## sparkle(at) and dip().

const HAND_SHADER := preload("res://assets/textures/shaders/hand_glow.gdshader")
const GROUND_SHADER := preload("res://assets/textures/shaders/ground_fx.gdshader")
const ERA_GLOW := {
	1: Color(1.0, 0.62, 0.26),   # amber
	2: Color(1.0, 0.82, 0.38),   # gold
	3: Color(1.0, 0.97, 0.92),   # white
	4: Color(0.62, 0.82, 1.0),   # pale blue
}
## [length, x offset, base z] for index, middle, ring, little
const FINGERS := [[0.84, -0.33, -0.42], [0.96, -0.11, -0.48], [0.9, 0.12, -0.46], [0.7, 0.34, -0.39]]
## The local point (under the middle of the fingers) that sits over the aim point,
## so the fingers, not the palm, are over what the player points at and the palm and
## wrist trail toward the camera without hiding it.
const AIM_LOCAL := Vector3(0.0, -0.15, -1.3)
const SEG_SPLIT := [0.42, 0.33, 0.25]
const MAX_GHOSTS := 20

## Wrist to fingertip is ~1.9 units: 8.5 makes it ~16 m, about ten people long
## (DESIGN 12.1 asks for ~12; a little less keeps the high camera clear).
@export var hand_scale: float = 10.5   # 1.9 units x 10.5 = 20 m, about 12 people

var model: Node3D
var mat: ShaderMaterial
var arm_mat: ShaderMaterial
var finger_joints: Array = []          # Array of Array[Node3D] (3 joints per finger)
var thumb_joints: Array = []
var shadow: MeshInstance3D
var ring: MeshInstance3D
var scoop_ring: MeshInstance3D
var ghosts: Array = []                 # Node3D ghost people
var pips_root: Node3D
var pips: Array = []
var badge: Label3D
var tip_layer: CanvasLayer
var tip_panel: PanelContainer
var tip_label: Label

var glow_color: Color = ERA_GLOW[1]
var _curl: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var _strain: float = 0.0
var _flash: float = 0.0
var _glow: float = 1.0
var _alpha: float = 0.62
var _shadow_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _scoop_mat: ShaderMaterial
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

func set_era(era: int) -> void:
	glow_color = ERA_GLOW.get(clampi(era, 1, 4), ERA_GLOW[1])
	if mat:
		mat.set_shader_parameter(&"glow_color", glow_color)
		arm_mat.set_shader_parameter(&"glow_color", glow_color)
		_ring_mat.set_shader_parameter(&"color", Color(glow_color, 0.85))
		_scoop_mat.set_shader_parameter(&"color", Color(glow_color, 0.9))

# ---------------------------------------------------------------- building

func _build_model() -> void:
	# An open right hand, palm down, fingers pointing away from the camera (local -Z),
	# about 1.9 units from wrist to fingertip; hand_scale makes it ~12 people long.
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	model.top_level = true
	mat = ShaderMaterial.new()
	mat.shader = HAND_SHADER
	arm_mat = ShaderMaterial.new()
	arm_mat.shader = HAND_SHADER
	arm_mat.set_shader_parameter(&"fade_from", -0.15)
	arm_mat.set_shader_parameter(&"fade_to", 0.55)
	# palm: a broad, flat pad, wider at the knuckles than at the heel
	var palm := _mesh(model, _sphere(0.5), Vector3(0, 0, 0.02), mat)
	palm.scale = Vector3(1.0, 0.34, 1.02)
	palm.name = "Palm"
	var heel := _mesh(model, _sphere(0.36), Vector3(0.06, -0.01, 0.36), mat)
	heel.scale = Vector3(1.15, 0.36, 0.8)
	var knuckles := _mesh(model, _capsule(0.15, 0.92), Vector3(0, 0.02, -0.36), mat)
	knuckles.rotation = Vector3(0, 0, PI / 2)
	knuckles.scale = Vector3(0.95, 1.0, 0.85)
	# the thumb's fleshy base on the inner side
	var mound := _mesh(model, _sphere(0.26), Vector3(-0.36, -0.03, 0.12), mat)
	mound.scale = Vector3(0.9, 0.55, 1.3)
	# wrist and forearm, fading out toward the camera
	var wrist := _mesh(model, _capsule(0.3, 1.5), Vector3(0.04, 0.16, 0.95), arm_mat)
	wrist.rotation = Vector3(deg_to_rad(70), 0, 0)
	wrist.scale = Vector3(1.15, 1.0, 0.72)
	wrist.name = "Forearm"
	for f in FINGERS:
		var joints: Array = []
		var parent: Node3D = model
		var base := Node3D.new()
		base.position = Vector3(f[1], 0.03, f[2])
		parent.add_child(base)
		parent = base
		for k in 3:
			var seg_len: float = f[0] * SEG_SPLIT[k]
			var j := parent if k == 0 else Node3D.new()
			if k > 0:
				j.position = Vector3(0, 0, -float(f[0]) * SEG_SPLIT[k - 1])
				parent.add_child(j)
			var r := 0.094 - 0.01 * float(k)
			var seg := _mesh(j, _capsule(r, seg_len + r * 1.7), Vector3(0, 0, -seg_len * 0.5), mat)
			seg.rotation = Vector3(-PI / 2, 0, 0)
			seg.scale = Vector3(1.0, 1.0, 0.85)   # fingers a little flatter than round
			joints.append(j)
			parent = j
		finger_joints.append(joints)
	# thumb: two segments angled out from the inner side of the palm, clearly apart
	var tb := Node3D.new()
	tb.position = Vector3(-0.44, -0.04, 0.14)
	tb.rotation = Vector3(0, 0.95, 0)
	model.add_child(tb)
	var t2 := Node3D.new()
	t2.position = Vector3(0, 0, -0.4)
	tb.add_child(t2)
	var s1 := _mesh(tb, _capsule(0.125, 0.52), Vector3(0, 0, -0.2), mat)
	s1.rotation = Vector3(-PI / 2, 0, 0)
	var s2 := _mesh(t2, _capsule(0.105, 0.44), Vector3(0, 0, -0.17), mat)
	s2.rotation = Vector3(-PI / 2, 0, 0)
	thumb_joints = [tb, t2]
	# the hand is lit by its own glow; the soft ground shadow is drawn separately
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_ground_fx() -> void:
	_shadow_mat = _gmat(Color(0.05, 0.03, 0.02, 0.38), 0.0)
	shadow = _plane(_shadow_mat, 1.0)
	shadow.name = "Shadow"
	_ring_mat = _gmat(Color(glow_color, 0.85), 0.78)
	_ring_mat.set_shader_parameter(&"ring_width", 0.07)
	ring = _plane(_ring_mat, 1.0)
	ring.name = "TargetRing"
	_scoop_mat = _gmat(Color(glow_color, 0.9), 0.95)
	_scoop_mat.set_shader_parameter(&"ring_width", 0.03)
	_scoop_mat.set_shader_parameter(&"dashes", 18.0)
	scoop_ring = _plane(_scoop_mat, 1.0)
	scoop_ring.name = "ScoopRing"
	scoop_ring.visible = false

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

func sync(hand: Hand, dt: float) -> void:
	_strain = maxf(_strain - dt, 0.0)
	_flash = maxf(_flash - dt, 0.0)
	var cam := get_viewport().get_camera_3d()
	# orientation: fingers point away from the camera, tipped down a little
	var fwd := Vector3(0, 0, -1)
	if cam:
		fwd = -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3(0, 0, -1)
	# The hand reaches in from the far side of the valley: fingers toward the camera,
	# palm and wrist beyond the aim point, so it never sits between the camera and
	# the people it is reaching for.
	var basis := Basis.looking_at(-fwd.normalized(), Vector3.UP)
	# fingers tip down toward the ground, more so while it reaches or sets down
	var tip_down := -16.0 - 10.0 * clampf(float(hand.hover_person != null or hand.hover_thing != null) + hand.dip_t * 3.0, 0.0, 1.0)
	basis = basis * Basis(Vector3.RIGHT, deg_to_rad(tip_down)) * Basis(Vector3.FORWARD, deg_to_rad(-6.0))
	# strain wobble, and a tremble under heavy loads
	var wob := 0.0
	if _strain > 0.0:
		wob = sin(hand.time * 48.0) * 0.12 * (_strain / 0.6)
	if is_instance_valid(hand.held_object):
		var w: float = hand.held_object.lift_weight() if hand.held_object.has_method(&"lift_weight") else 1.0
		var ld := clampf(w / maxf(Faith.strength, 0.01), 0.0, 1.0)
		wob += sin(hand.time * 31.0) * 0.025 * ld * ld
	basis = basis * Basis(Vector3.FORWARD, wob)
	var b := basis.scaled(Vector3.ONE * hand_scale)
	model.global_transform = Transform3D(b, hand.air_pos - b * AIM_LOCAL)
	# softer and more see-through when empty, solid when it carries someone
	var a := 0.62 if not hand.is_holding() else 0.86
	_alpha = lerpf(_alpha, a, minf(6.0 * dt, 1.0))
	mat.set_shader_parameter(&"alpha", _alpha)
	_pose_fingers(hand, dt)
	_update_glow(hand, dt)
	_update_ground(hand, dt)
	_update_ghosts(hand)
	_update_tooltip(hand)

func _pose_fingers(hand: Hand, dt: float) -> void:
	var g := hand.grip()
	var n := hand.held.size()
	var full := hand.held_object != null or (n > 0 and n >= g)
	var target: Array = [0.08, 0.08, 0.08, 0.08, 0.05]
	if full:
		target = [1.0, 1.0, 1.0, 1.0, 1.0]
	elif n > 0:
		var curled := n if g <= 5 else int(ceil(float(n) * 5.0 / float(g)))
		for i in mini(curled, 5):
			target[i] = 1.0
	elif hand.hover_person != null or hand.hover_thing != null:
		target = [0.38, 0.42, 0.42, 0.38, 0.25]   # reaching
	if hand.gesture_power != &"":
		target = [0.0, 0.0, 0.0, 0.0, 0.0]        # open palm for blessings
	var k := minf(12.0 * dt, 1.0)
	for i in 5:
		_curl[i] = lerpf(_curl[i], target[i], k)
	var bend := [deg_to_rad(-58.0), deg_to_rad(-72.0), deg_to_rad(-55.0)]
	for i in 4:
		var joints: Array = finger_joints[i]
		var spread: float = (float(i) - 1.5) * 0.06 * (1.0 - float(_curl[i]))
		for j in 3:
			var jn: Node3D = joints[j]
			jn.rotation = Vector3(bend[j] * _curl[i], spread if j == 0 else 0.0, 0)
	var tc: float = _curl[4]
	(thumb_joints[0] as Node3D).rotation = Vector3(deg_to_rad(-20.0) * tc, 0.75 - 0.75 * tc, 0)
	(thumb_joints[1] as Node3D).rotation = Vector3(deg_to_rad(-45.0) * tc, -0.3 * tc, 0)

func _update_glow(hand: Hand, dt: float) -> void:
	var g := 1.0
	var full := hand.held_object != null or (hand.held.size() > 0 and hand.held.size() >= hand.grip())
	if full:
		g = 1.7 + 0.25 * sin(hand.time * 4.0)            # fist glow at full grip
	g += hand.gesture_level() * (1.4 + 0.4 * sin(hand.time * 9.0))
	g += _flash * 2.0
	if _strain > 0.0:
		g *= 0.7
	_glow = lerpf(_glow, g, minf(10.0 * dt, 1.0))
	mat.set_shader_parameter(&"glow_strength", _glow)
	arm_mat.set_shader_parameter(&"glow_strength", _glow * 0.8)

func _update_ground(hand: Hand, _dt: float) -> void:
	var gp := hand.ground
	if not gp.is_finite():
		gp = Vector3.ZERO
	var height := maxf(hand.air_pos.y - gp.y, 0.5)
	var s := clampf(1.0 + height * 0.04, 1.0, 1.6) * hand_scale * 1.1
	var palm := model.global_position
	shadow.global_position = Vector3(lerpf(hand.air_pos.x, palm.x, 0.6), gp.y + 0.05, lerpf(hand.air_pos.z, palm.z, 0.6))
	shadow.scale = Vector3(s, 1, s * 1.3)
	shadow.rotation.y = model.global_rotation.y
	_shadow_mat.set_shader_parameter(&"color", Color(0.05, 0.03, 0.02, clampf(0.4 - height * 0.012, 0.14, 0.32)))
	var rr := 0.9 + 0.25 * float(hand.held.size()) if hand.held.size() > 1 else 0.9
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

func strain() -> void:
	_strain = 0.6

func dip() -> void:
	_flash = 0.25

func sparkle(at: Vector3) -> void:
	_flash = 0.6
	var p := CPUParticles3D.new()
	p.top_level = true
	add_child(p)
	p.global_position = at + Vector3(0, 0.5, 0)
	p.one_shot = true
	p.amount = 28
	p.lifetime = 1.1
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	m.radial_segments = 6
	m.rings = 3
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.9, 0.5)
	sm.emission_enabled = true
	sm.emission = glow_color
	sm.emission_energy_multiplier = 3.0
	m.material = sm
	p.mesh = m
	p.emitting = true
	get_tree().create_timer(1.6, true, false, true).timeout.connect(p.queue_free)

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
