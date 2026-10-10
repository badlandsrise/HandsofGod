extends "res://scripts/assets/tools/build_era3.gd"
## Builds the Era 4 (Launch) art kit: every scene in scenes/props/era4/ plus the Era 4
## library materials. Re-run after changing this file:
##   godot --headless --path . -s res://scripts/assets/tools/build_era4.gd [-- --only=rocket,launch_tower]
##
## Reuses build_era2.gd's and build_era3.gd's helpers (same conventions: origin on the ground
## at the footprint centre, +Z is the front, metres; hand-made geometry merged into one mesh
## per material). Pack pieces: Kenney City Kit Industrial (storage tanks, the water tower,
## shipping containers), City Kit Commercial (awnings, café parasols, the far skyline) and
## Space Kit (dishes, generators, barrels, desks); Quaternius MegaKit brick for the works.
## Everything else is modelled here: the apartment blocks, the powerhouse, the works, the
## institute, mission control, the radio telescope, the rail line, the launch tower and
## the rocket.
##
## The look is mid-century and hopeful, not grim: warm-white concrete and red brick (the
## Era 3 brick, carried on), steel picked out in signal orange, night-blue trim, enamel
## panels in turquoise, mint, mustard and coral, curtain-wall glass, boomerang canopies,
## TV aerials and round portholes. The rocket is the centrepiece: a friendly finned rocket
## in warm white and signal orange with the open hand on its side.
##
## Buildings come in three stages like Eras 2 and 3: <id>_plot (surveyed, staked out with
## orange tape, first steel and bricks on site), <id>_frame (steel frame and concrete floors
## going up, a tower crane or derrick), <id>.
##
## Night: windows that light up at dusk are a hidden "NightGlow" mesh, lamps are hidden
## lights (street_light/Light, launch_tower/Floods/*), as in Era 3.

const OUT4 := "res://scenes/props/era4/"
const IND := "res://assets/models/industry/"
const CITY := "res://assets/models/city/"
const SPACE := "res://assets/models/space/"
const KIND := {"hog_pull": 0.2, "hog_sat": 0.85}                                 # Kenney city kits
const KSPACE := {"hog_pull": 0.15, "hog_sat": 0.9, "hog_tint": Color("#e9e4da")}  # Kenney space kit
const R0 := 1.55       # the rocket's body radius
const PAD_H := 1.6     # launch pad deck height
const MOUNT_Y := 2.0   # the rocket's foot (fin tips) on the pad's hold-down pedestals

var _jobs4: Dictionary = {}
var _night: Array = []   # lit-window quads in scene space: [a, b, c, d, out]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT4))
	_build_materials4()
	_jobs4 = {
		"apartment": _apartments, "powerhouse": _powerhouse, "coal_mine": _coal_mine, "foundry": _foundry,
		"refinery": _refinery, "factory": _factory, "assembly_hall": _assembly_hall, "institute": _institute,
		"mission_control": _mission_control, "radio_telescope": _radio_telescope, "training_centre": _training_centre,
		"rail_station": _rail_station, "test_stand": _test_stand, "wind_turbine": _wind_turbine,
		"launch_tower": _launch_tower, "rocket": _rockets,
		"roads4": _roads4, "rail": _rail, "street4": _street4, "vehicles": _vehicles, "trains": _trains,
		"piles4": _piles4, "nodes4": _nodes4, "tools4": _tools4, "gifts4": _gifts4,
	}
	for k in _jobs4:
		if _only.is_empty() or k in _only:
			(_jobs4[k] as Callable).call()
	print("build_era4: %d scenes" % _count)
	quit()


func _begin(scene_name: String) -> Node3D:
	_night = []
	return super(scene_name)


func _save(scene_name: String) -> void:
	if not _night.is_empty():   # lit windows: one hidden mesh gameplay shows at dusk
		var saved := _parts
		var saved_t := _t
		_parts = {}
		_t = Transform3D.IDENTITY
		for q in _night:
			_quad("window_lit", q[0], q[1], q[2], q[3], q[4])
		var g := _group("NightGlow")
		_flush(g, "Mesh")
		g.visible = false
		_parts = saved
		_t = saved_t
		_night = []
	_flush(_root, "Geometry")
	var ps := PackedScene.new()
	var err := ps.pack(_root)
	if err == OK:
		err = ResourceSaver.save(ps, OUT4 + scene_name + ".scn", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		print("  %s -> %s" % [scene_name, error_string(err)])
	_count += 1
	_root.free()


# ================================================================== materials

func _build_materials4() -> void:
	var era4 := false
	for mat_name in ArtPalette.NAMED:
		era4 = era4 or mat_name == "concrete_flat"   # everything from "concrete_flat" on is Era 4's
		if era4:
			_save_material(mat_name, ArtPalette.NAMED[mat_name], "res://assets/models/materials/%s.tres" % mat_name)
	for mat_name in ["concrete", "asphalt", "curtain_wall", "mission_patch", "flag_mission", "poster_launch"]:
		_save_material(mat_name, ArtPalette.NAMED_TEXTURED[mat_name], "res://assets/models/materials/%s.tres" % mat_name)
	# glowing, unshaded: lit windows (hidden by day), aviation lamps, molten steel, screens
	for spec in [["window_lit", Color("#ffd98a")], ["signal_lamp", Color("#ff4a2a")], ["molten", Color("#ffb43c")],
			["screen_glow", Color("#9fe8d0")], ["porthole_lit", Color("#ffe2a0")]]:
		var m := StandardMaterial3D.new()
		m.resource_name = "hog_" + spec[0]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = spec[1]
		ResourceSaver.save(m, "res://assets/models/materials/%s.tres" % spec[0])
	# particle materials: steam and smoke puffs (soft alpha, lit by nothing so they read at
	# dusk under the floodlights), and the exhaust flame (additive)
	for spec in [["steam", Color(1, 1, 1, 0.9), false], ["smoke", Color(0.62, 0.62, 0.64, 0.75), false], ["exhaust", Color(1.0, 0.72, 0.36, 1.0), true]]:
		var m := StandardMaterial3D.new()
		m.resource_name = "hog_" + spec[0]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if spec[2]:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = spec[1]
		m.albedo_texture = load("res://assets/textures/era4/puff.png")
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_receive_shadows = true
		ResourceSaver.save(m, "res://assets/models/materials/%s.tres" % spec[0])


# ================================================================== shared Era 4 parts

## Geometry drawn by `body` in a flat frame (x across, y up, z out of the surface, z = 0 on
## it) is bent round a vertical cylinder of radius r: x becomes arc length. at = the angle
## of the frame's centre line (0 = +Z, PI/2 = +X). For badges, stripes and portholes on the
## rocket, tanks and towers.
func _wrap(r: float, at: float, body: Callable) -> void:
	var saved_parts := _parts
	var saved_t := _t
	_parts = {}
	_t = Transform3D.IDENTITY
	body.call()
	var bent := _parts
	_parts = saved_parts
	_t = saved_t
	for m in bent:
		var src: Array = bent[m]
		if not _parts.has(m):
			_parts[m] = [[], [], []]
		var dst: Array = _parts[m]
		var vs: Array = src[0]
		var ns: Array = src[1]
		for i in vs.size():
			var v: Vector3 = vs[i]
			var a := at + v.x / r
			var w := Vector3(sin(a) * (r + v.z), v.y, cos(a) * (r + v.z))
			var n: Vector3 = Basis(Vector3.UP, a) * (ns[i] as Vector3)
			(dst[0] as Array).append(_t * w)
			(dst[1] as Array).append((_t.basis * n).normalized())
			(dst[2] as Array).append(src[2][i])


## A lit window for the night: a quad just proud of the glass, recorded in scene space.
## c = centre in the current local frame, w x h, facing local +Z.
func _night_pane(c: Vector3, w: float, h: float, chance := 0.55) -> void:
	if _rng.randf() > chance:
		return
	var hw := w * 0.5
	var hh := h * 0.5
	var z := c.z + 0.05
	_night.append([_t * Vector3(c.x - hw, c.y - hh, z), _t * Vector3(c.x + hw, c.y - hh, z), _t * Vector3(c.x + hw, c.y + hh, z),
		_t * Vector3(c.x - hw, c.y + hh, z), _t.basis * Vector3.BACK])


## A row of glazed windows on a wall whose outer face is local z = 0 (facing +Z): n bays
## across [x0, x1] at sill height y, h tall. Slim steel frames, a mullion per bay, a concrete
## sill; frame_m picks the frame colour.
func _windows(x0: float, x1: float, y: float, h: float, n: int, frame_m := "warm_white", gap := 0.35, lit := 0.55) -> void:
	var bay := (x1 - x0) / n
	for i in n:
		var cx := x0 + bay * (i + 0.5)
		var w := bay - gap
		_box("glass_blue", Vector3(cx, y + h * 0.5, 0.012), Vector3(w, h, 0.02))
		_box(frame_m, Vector3(cx, y + h + 0.03, 0.05), Vector3(w + 0.1, 0.07, 0.08))
		_box(frame_m, Vector3(cx - w * 0.5, y + h * 0.5, 0.05), Vector3(0.07, h, 0.08))
		_box(frame_m, Vector3(cx + w * 0.5, y + h * 0.5, 0.05), Vector3(0.07, h, 0.08))
		_box(frame_m, Vector3(cx, y + h * 0.5, 0.04), Vector3(0.05, h, 0.06))
		_box(frame_m, Vector3(cx, y + h * 0.62, 0.04), Vector3(w, 0.05, 0.06))
		_box("concrete_flat", Vector3(cx, y - 0.04, 0.1), Vector3(w + 0.18, 0.08, 0.2))
		_night_pane(Vector3(cx, y + h * 0.5, 0.0), w - 0.1, h - 0.1, lit)


## Ribbon window: one long glazed band with thin mullions every `bay` metres.
func _ribbon(x0: float, x1: float, y: float, h: float, bay := 1.2, frame_m := "steel_dark", lit := 0.5) -> void:
	_box("glass_blue", Vector3((x0 + x1) * 0.5, y + h * 0.5, 0.012), Vector3(x1 - x0, h, 0.02))
	var n := maxi(1, int(round((x1 - x0) / bay)))
	for i in n + 1:
		var x := x0 + (x1 - x0) * i / n
		_box(frame_m, Vector3(x, y + h * 0.5, 0.04), Vector3(0.06, h, 0.06))
		if i < n:
			_night_pane(Vector3(x + (x1 - x0) / n * 0.5, y + h * 0.5, 0.0), (x1 - x0) / n - 0.1, h - 0.1, lit)
	_box(frame_m, Vector3((x0 + x1) * 0.5, y + h, 0.04), Vector3(x1 - x0, 0.06, 0.06))
	_box(frame_m, Vector3((x0 + x1) * 0.5, y, 0.04), Vector3(x1 - x0, 0.06, 0.06))


## A wall face: walls of a w x d box are drawn by the caller; this runs `body` in each face's
## frame (local z = 0 on the face, +Z out, x across from the face's left). side: "front",
## "back", "left", "right".
func _on_face(w: float, d: float, side: String, body: Callable) -> void:
	var specs := {"front": [0.0, Vector3(0, 0, d * 0.5)], "back": [180.0, Vector3(0, 0, -d * 0.5)],
		"left": [-90.0, Vector3(-w * 0.5, 0, 0)], "right": [90.0, Vector3(w * 0.5, 0, 0)]}
	var s: Array = specs[side]
	_push(_xf(s[1], s[0]))
	body.call()
	_pop()


## Flat roof on a w x d box whose top is at y: a concrete deck, a parapet with a metal
## coping, and roof clutter (vents, a stair house, a water tank, TV aerials) by `kit`.
func _flat_roof(w: float, d: float, y: float, kit := "vents", parapet := "warm_white") -> void:
	_box("concrete_dark", Vector3(0, y + 0.05, 0), Vector3(w - 0.1, 0.1, d - 0.1))
	for s in [-1.0, 1.0]:
		_box(parapet, Vector3(0, y + 0.35, s * (d * 0.5 - 0.1)), Vector3(w + 0.1, 0.7, 0.3))
		_box(parapet, Vector3(s * (w * 0.5 - 0.1), y + 0.35, 0), Vector3(0.3, 0.7, d))
		_box("steel", Vector3(0, y + 0.72, s * (d * 0.5 - 0.1)), Vector3(w + 0.16, 0.06, 0.36))
		_box("steel", Vector3(s * (w * 0.5 - 0.1), y + 0.72, 0), Vector3(0.36, 0.06, d + 0.06))
	if kit.contains("vents"):
		for k in 3:
			var p := Vector3(_rng.randf_range(-w * 0.3, w * 0.3), y + 0.1, _rng.randf_range(-d * 0.3, d * 0.3))
			_box("steel", p + Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.8))
			_cyl("steel_dark", p + Vector3(0, 0.7, 0), 0.3, 0.3, 0.15, 8)
	if kit.contains("stair"):
		_box(parapet, Vector3(-w * 0.25, y + 1.3, -d * 0.2), Vector3(2.4, 2.6, 2.4))
		_box("concrete_dark", Vector3(-w * 0.25, y + 2.65, -d * 0.2), Vector3(2.7, 0.12, 2.7))
		_box("signal_orange", Vector3(-w * 0.25, y + 1.1, -d * 0.2 + 1.21), Vector3(0.9, 2.0, 0.04))
	if kit.contains("tank"):
		_water_tank(Vector3(w * 0.28, y + 0.1, -d * 0.18), 1.0)
	if kit.contains("aerial"):
		for k in 2:
			_aerial(Vector3(-w * 0.1 + k * w * 0.32, y + 0.1, d * 0.15 - k * d * 0.3))


## Mid-century rooftop TV aerial: a mast with a fishbone of rods.
func _aerial(p: Vector3) -> void:
	_rod("steel", p, p + Vector3(0, 2.6, 0), 0.03, 4)
	_rod("steel", p + Vector3(0, 2.2, -0.6), p + Vector3(0, 2.2, 0.6), 0.015, 3)
	for k in 5:
		var z := -0.5 + k * 0.25
		_rod("steel", p + Vector3(-0.35 + k * 0.04, 2.2, z), p + Vector3(0.35 - k * 0.04, 2.2, z), 0.012, 3)
	for sx in [-1.0, 1.0]:
		_rod("steel", p + Vector3(0, 1.6, 0), p + Vector3(sx * 0.9, 0.0, 0.4), 0.008, 3)


## A riveted water tank on short legs (rooftops) or a tall stand.
func _water_tank(p: Vector3, s: float, legs := 0.6) -> void:
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_beam("steel_dark", p + Vector3(c.x * 0.6, 0, c.y * 0.6) * s, p + Vector3(c.x * 0.5, legs, c.y * 0.5) * s, 0.08 * s)
	_lathe("steel", p + Vector3(0, legs * s, 0), [Vector2(0.95, 0), Vector2(0.95, 1.4), Vector2(0.75, 1.75), Vector2(0.0, 1.85)], 12, Vector3.ZERO, Vector3.ONE * s)
	_box("signal_orange", p + Vector3(0, (legs + 0.7) * s, 0), Vector3(1.94, 0.16, 1.94) * s, Vector3(0, 0, 0))


## I-section steel column or beam from a to b (flanges across `side`).
func _ibeam(m: String, a: Vector3, b: Vector3, w: float, side := Vector3.RIGHT) -> void:
	var d := (b - a).normalized()
	var s := (side - d * side.dot(d)).normalized() * w * 0.42
	_beam(m, a + s, b + s, w * 0.16, w)
	_beam(m, a - s, b - s, w * 0.16, w)
	_beam(m, a, b, w * 0.1, w * 0.8)


## A square lattice tower w across from base (feet) up h: four corner legs, girts every
## `bay`, X-bracing on every face.
func _lattice_tower(base: Vector3, w: float, h: float, m := "signal_orange", bay := 2.4, leg := 0.22) -> void:
	var hw := w * 0.5
	var cs := [Vector3(-hw, 0, -hw), Vector3(hw, 0, -hw), Vector3(hw, 0, hw), Vector3(-hw, 0, hw)]
	for c in cs:
		_box(m, base + c + Vector3(0, h * 0.5, 0), Vector3(leg, h, leg))
	var n := maxi(1, int(round(h / bay)))
	for k in n + 1:
		var y := h * k / n
		for i in 4:
			_beam(m, base + cs[i] + Vector3(0, y, 0), base + cs[(i + 1) % 4] + Vector3(0, y, 0), leg * 0.55)
	for k in n:
		var y0 := h * k / n
		var y1 := h * (k + 1) / n
		for i in 4:
			var a: Vector3 = base + cs[i]
			var b: Vector3 = base + cs[(i + 1) % 4]
			_beam(m, a + Vector3(0, y0, 0), b + Vector3(0, y1, 0), leg * 0.35)
			_beam(m, b + Vector3(0, y0, 0), a + Vector3(0, y1, 0), leg * 0.35)


## A flat truss from a to b (a crane jib, a bridge girder, a gantry arm): top and bottom
## chords `depth` apart along `up`, with zig-zag web members.
func _truss(m: String, a: Vector3, b: Vector3, depth: float, up := Vector3.UP, chord := 0.16, n := 0) -> void:
	var u := up.normalized() * depth
	var l := a.distance_to(b)
	var segs := n if n > 0 else maxi(2, int(l / depth))
	_beam(m, a, b, chord)
	_beam(m, a + u, b + u, chord)
	for i in segs:
		var p0 := a.lerp(b, float(i) / segs)
		var p1 := a.lerp(b, float(i + 1) / segs)
		_beam(m, p0, p1 + u, chord * 0.6)
		_beam(m, p0 + u, p0, chord * 0.6)
	_beam(m, b, b + u, chord * 0.6)


## A brick or concrete factory stack: tapering, with a signal-orange and warm-white band
## at the top, a red aviation lamp, iron rungs.
func _smokestack(p: Vector3, r0: float, r1: float, h: float, m := "brick") -> void:
	_lathe(m, p, [Vector2(r0, 0), Vector2(r1, h - 1.6), Vector2(r1, h - 1.6), Vector2(r1 * 1.12, h - 1.5), Vector2(r1 * 1.12, h), Vector2(r1 * 0.85, h)], 12, Vector3.ZERO, Vector3.ONE, 0.0, false)
	_lathe("signal_orange", p + Vector3(0, h - 3.2, 0), [Vector2(lerpf(r0, r1, (h - 3.2) / (h - 1.6)) + 0.02, 0), Vector2(r1 + 0.03, 0.8)], 12, Vector3.ZERO, Vector3.ONE, 0.0, false)
	_lathe("warm_white", p + Vector3(0, h - 2.4, 0), [Vector2(r1 + 0.03, 0), Vector2(r1 + 0.03, 0.8)], 12, Vector3.ZERO, Vector3.ONE, 0.0, false)
	_lathe("cave_dark", p + Vector3(0, h - 0.05, 0), [Vector2(r1 * 0.85, 0), Vector2(0, 0)], 12)
	_ball("signal_lamp", p + Vector3(r1 * 1.12, h - 0.4, 0), 0.12, 6, 3)
	for k in int((h - 2.0) / 0.5):
		var y := 0.6 + k * 0.5
		var r := lerpf(r0, r1, y / (h - 1.6)) + 0.04
		_beam("iron", p + Vector3(-0.2, y, r), p + Vector3(0.2, y, r), 0.03)


## Puffs of steam or smoke rising from p: GPU particles under a named node.
## dir = initial direction, spread degrees, life seconds, size = puff size in metres.
func _puffs(node_name: String, p: Vector3, dir: Vector3, mat := "steam", amount := 24, life := 4.0, size := 1.6,
		speed := 1.5, spread := 18.0, emitting := true, parent: Node3D = null) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = node_name
	gp.position = _t * p
	gp.amount = amount
	gp.lifetime = life
	gp.preprocess = life
	gp.emitting = emitting
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = (_t.basis * dir).normalized()
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.7
	pm.initial_velocity_max = speed * 1.3
	pm.gravity = Vector3(0.25, 0.35, 0.0)   # rises and drifts on the breeze
	pm.damping_min = speed * 0.15
	pm.damping_max = speed * 0.3
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(0.4, 0.85))
	sc.add_point(Vector2(1, 1.4))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.12, Color(1, 1, 1, 0.95))
	g.add_point(0.6, Color(1, 1, 1, 0.6))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = load("res://assets/models/materials/%s.tres" % mat)
	gp.draw_pass_1 = q
	var reach := speed * life + size * 2.0
	gp.visibility_aabb = AABB(Vector3(-reach, -size, -reach), Vector3(reach * 2.0, reach * 1.5 + size, reach * 2.0))
	(parent if parent else _root).add_child(gp)
	gp.owner = _root
	return gp


## A hidden spot or omni light (switched on by gameplay at dusk), parented to `parent`.
func _hidden_light(node_name: String, p: Vector3, col: Color, energy: float, rng_m: float, spot_target := Vector3.INF,
		angle := 25.0, parent: Node3D = null) -> Light3D:
	var l: Light3D
	if spot_target != Vector3.INF:
		var s := SpotLight3D.new()
		s.spot_range = rng_m
		s.spot_angle = angle
		s.spot_attenuation = 0.6
		l = s
	else:
		var o := OmniLight3D.new()
		o.omni_range = rng_m
		l = o
	l.name = node_name
	l.light_color = col
	l.light_energy = energy
	l.visible = false
	(parent if parent else _root).add_child(l)
	l.owner = _root
	l.position = _t * p if parent == null else p
	if spot_target != Vector3.INF:
		l.look_at_from_position(l.position, spot_target, Vector3.UP)
	return l


## A flag on a staff top `top` in material m (flag_mission), w x h, gently waving.
func _flag4(top: Vector3, w: float, h: float, m := "flag_mission") -> void:
	var n := 6
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var z0 := sin(u0 * 3.0) * 0.14 * u0
		var z1 := sin(u1 * 3.0) * 0.14 * u1
		_quad(m, top + Vector3(u0 * w, 0, z0), top + Vector3(u1 * w, 0, z1), top + Vector3(u1 * w, -h, z1), top + Vector3(u0 * w, -h, z0),
			Vector3(0, 0, 1), [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])


func _flagpole(p: Vector3, h: float, m := "flag_mission", fw := 2.0, fh := 1.25) -> void:
	_cyl("concrete_flat", p, 0.35, 0.3, 0.3, 8)
	_lathe("chrome", p + Vector3(0, 0.3, 0), [Vector2(0.07, 0), Vector2(0.045, h), Vector2(0, h)], 8)
	_ball("chrome", p + Vector3(0, h + 0.1, 0), 0.1, 6, 3)
	_flag4(p + Vector3(0.05, h - 0.15, 0), fw, fh, m)


## A boomerang canopy: a thin slab on two raked steel legs, upswept at both ends.
func _boomerang(c: Vector3, w: float, d: float, m := "warm_white", legs := "signal_orange") -> void:
	var y := c.y
	var hw := w * 0.5
	var pts := [Vector3(-hw, y + 0.5, 0), Vector3(-hw * 0.35, y, 0), Vector3(hw * 0.35, y, 0), Vector3(hw, y + 0.5, 0)]
	for i in 3:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		_slab(m, [Vector3(a.x, a.y, d * 0.5) + Vector3(c.x, 0, c.z), Vector3(b.x, b.y, d * 0.5) + Vector3(c.x, 0, c.z),
			Vector3(b.x, b.y, -d * 0.5) + Vector3(c.x, 0, c.z), Vector3(a.x, a.y, -d * 0.5) + Vector3(c.x, 0, c.z)], 0.12, Vector3.UP)
	for sx in [-1.0, 1.0]:
		_beam(legs, Vector3(c.x + sx * hw * 0.35, 0, c.z - d * 0.2), Vector3(c.x + sx * hw * 0.25, y - 0.1, c.z), 0.12)


## The open hand as a two-tone badge on a surface facing local +Z at c (palm centre): a
## night-blue outline behind a signal-orange (or `m`) hand. Drawn as flat plates with the
## same silhouette as the painted hand of gen_era3/gen_era4_textures (palm ellipse, four
## rounded fingers, the thumb out to the left), which reads better than the relief at
## the size of a rocket's flank.
func _hand_badge(c: Vector3, size: float, m := "signal_orange", rim := "night_blue") -> void:
	if rim != "":
		_hand_plate(rim, c, size, 0.03, size * 0.06)
	_hand_plate(m, c, size, 0.07, 0.0)


func _hand_plate(m: String, c: Vector3, s: float, depth: float, grow: float) -> void:
	var z := c.z + depth * 0.5
	var palm := []
	for k in 18:
		var a := TAU * k / 18.0
		palm.append(Vector2(c.x + cos(a) * (0.42 * s + grow), c.y + sin(a) * (0.47 * s + grow)))
	_plate(m, palm, z, depth)
	for f in [[-0.27, 0.95, 0.15], [-0.09, 1.07, 0.16], [0.09, 1.05, 0.16], [0.26, 0.9, 0.14]]:
		_capsule_plate(m, Vector2(c.x + f[0] * s, c.y + 0.1 * s), Vector2(c.x + f[0] * s, c.y + (f[1] - f[2] * 0.5) * s), f[2] * s * 0.5 + grow, z, depth)
	_capsule_plate(m, Vector2(c.x - 0.3 * s, c.y - 0.12 * s), Vector2(c.x - 0.66 * s, c.y + 0.28 * s), 0.085 * s + grow, z, depth)


## A flat stadium (a rounded bar) from a to b, radius r, in the local XY plane.
func _capsule_plate(m: String, a: Vector2, b: Vector2, r: float, z: float, depth: float) -> void:
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	var pts := []
	for k in 7:
		var t := PI * k / 6.0
		pts.append(b + (nrm * cos(t) + d * sin(t)) * r)
	for k in 7:
		var t := PI * k / 6.0
		pts.append(a - (nrm * cos(t) + d * sin(t)) * r)
	_plate(m, pts, z, depth)


## A round porthole facing +Z at c: chrome rim, dark (or lit) glass.
func _porthole(c: Vector3, r: float, glass := "glass_dark") -> void:
	_lathe(glass, c, [Vector2(r, 0.02), Vector2(0, 0.02)], 14, Vector3(90, 0, 0))
	_lathe("chrome", c, [Vector2(r + 0.12, 0), Vector2(r + 0.1, 0.07), Vector2(r, 0.07), Vector2(r, 0.0)], 14, Vector3(90, 0, 0), Vector3.ONE, 0.0, false)


# ================================================================== plot and frame (Era 4)

## Era 4 plot: graded earth, survey stakes with orange tape, a theodolite on its tripod,
## the first steel beams and a pallet of bricks, a cement mixer.
func _plot4(w: float, d: float, round_plot := false) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	if round_plot:
		_cyl("dirt", Vector3.ZERO, hw + 0.5, hw + 0.45, 0.05, 18)
	else:
		_box("dirt", Vector3(0, 0.025, 0), Vector3(w + 0.8, 0.05, d + 0.8))
	var cs := [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd)]
	for c in cs:
		_box("wood", c + Vector3(0, 0.4, 0), Vector3(0.07, 0.8, 0.07))
		_box("signal_orange", c + Vector3(0, 0.75, 0), Vector3(0.09, 0.12, 0.09))
	for i in 4:
		_beam("canvas_orange", (cs[i] as Vector3) + Vector3(0, 0.6, 0), (cs[(i + 1) % 4] as Vector3) + Vector3(0, 0.6, 0), 0.04, 0.12)
	# foundation trench along the front with the first concrete poured
	_box("soil_dark", Vector3(0, 0.055, hd - 0.2), Vector3(w - 0.4, 0.02, 0.7))
	_box("concrete", Vector3(-hw * 0.4, 0.12, hd - 0.2), Vector3(w * 0.5, 0.2, 0.6))
	_steel_pile(Vector3(hw + 1.4, 0, hd * 0.3), 90.0)
	_model(V + "Prop_Brick2.gltf", Vector3(hw + 1.2, 0, -hd * 0.5), Vector3(0, 80, 0), 1.0, null, MK)
	_mixer(Vector3(-hw - 1.4, 0, hd * 0.4), 30.0)
	_theodolite(Vector3(-hw - 0.9, 0, -hd * 0.6))


## Stacked I-beams on timber bearers.
func _steel_pile(c: Vector3, rot_y := 0.0, l := 4.0) -> void:
	_push(_xf(c, rot_y))
	for x in [-l * 0.35, l * 0.35]:
		_box("wood", Vector3(x, 0.06, 0), Vector3(0.14, 0.12, 1.2))
	for layer in 3:
		for i in 3 - layer:
			var z := (i - (2 - layer) * 0.5) * 0.36
			_ibeam("steel_dark" if layer % 2 == 0 else "steel", Vector3(-l * 0.5, 0.27 + layer * 0.3, z), Vector3(l * 0.5, 0.27 + layer * 0.3, z), 0.28, Vector3.UP)
	_pop()


## A small cement mixer: tilted drum on a wheeled frame.
func _mixer(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	_box("signal_orange", Vector3(0, 0.45, 0), Vector3(0.9, 0.12, 0.5))
	for sx in [-1.0, 1.0]:
		_cyl("rubber", Vector3(sx * 0.42, 0.25, 0), 0.25, 0.25, 0.12, 10, Vector3(0, 0, 90))
	_beam("steel_dark", Vector3(-0.2, 0.45, 0), Vector3(-0.2, 1.0, 0), 0.08)
	_lathe("signal_orange", Vector3(0.1, 0.8, 0), [Vector2(0.15, 0), Vector2(0.4, 0.3), Vector2(0.4, 0.5), Vector2(0.22, 0.85), Vector2(0.18, 0.85)], 10, Vector3(0, 0, -50))
	_beam("steel_dark", Vector3(-0.45, 0.45, 0), Vector3(-0.95, 0.75, 0), 0.04)
	_pop()


func _theodolite(p: Vector3) -> void:
	for k in 3:
		var a := TAU * k / 3.0
		_rod("wood", p + Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), p + Vector3(0, 1.25, 0), 0.025, 4)
	_box("enamel_mustard", p + Vector3(0, 1.38, 0), Vector3(0.18, 0.22, 0.14))
	_rod("night_blue", p + Vector3(0, 1.45, -0.12), p + Vector3(0, 1.45, 0.16), 0.045, 6)


## Era 4 frame: concrete floor slabs on a steel frame going up, the ground floor's brick
## infill started, a stair of scaffold, a tower crane (big plots) or a derrick.
## floors = storeys of `fh` metres; done = how many are framed.
func _frame4(w: float, d: float, floors: int, fh := 3.0, done := 2, crane := true) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	_box("dirt", Vector3(0, 0.025, 0), Vector3(w + 2.0, 0.05, d + 2.0))
	_box("concrete", Vector3(0, 0.15, 0), Vector3(w, 0.3, d))
	var nx := maxi(2, int(round(w / 4.0)))
	var nz := maxi(2, int(round(d / 4.0)))
	for k in done:
		var y0 := 0.3 + k * fh
		for i in nx + 1:
			for j in nz + 1:
				var p := Vector3(-hw + 0.2 + (w - 0.4) * i / nx, y0, -hd + 0.2 + (d - 0.4) * j / nz)
				if k == done - 1 and (i + j) % 3 == 0:
					continue   # the top storey's columns still going up
				_ibeam("signal_orange", p, p + Vector3(0, fh, 0), 0.3)
		if k < done - 1:
			_box("concrete", Vector3(0, y0 + fh, 0), Vector3(w, 0.25, d))
		else:
			for j in nz + 1:   # beams waiting for the next slab
				_ibeam("steel", Vector3(-hw, y0 + fh, -hd + 0.2 + (d - 0.4) * j / nz), Vector3(hw, y0 + fh, -hd + 0.2 + (d - 0.4) * j / nz), 0.3, Vector3.UP)
	# ground floor infill started on the front, in brick
	_box("brick", Vector3(-hw * 0.35, 0.3 + fh * 0.3, hd - 0.15), Vector3(w * 0.6, fh * 0.6, 0.25))
	# scaffold stair tower on the right side
	var sx := hw + 1.0
	var top := 0.3 + done * fh
	for c in [Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(-0.6, 0.8), Vector2(0.6, 0.8)]:
		_rod("steel", Vector3(sx + c.x, 0, c.y), Vector3(sx + c.x, top + 1.0, c.y), 0.04, 4)
	var y := 0.0
	var k := 0
	while y < top:
		_box("planks", Vector3(sx, y + fh, 0), Vector3(1.3, 0.06, 1.7))
		_beam("wood", Vector3(sx - 0.3, y, -0.6 if k % 2 == 0 else 0.6), Vector3(sx - 0.3, y + fh, 0.6 if k % 2 == 0 else -0.6), 0.5, 0.06)
		y += fh
		k += 1
	_steel_pile(Vector3(-hw - 2.0, 0, -hd * 0.3), 90.0)
	_mixer(Vector3(hw * 0.4, 0, hd + 1.4), 200.0)
	if crane:
		_tower_crane(Vector3(-hw - 1.6, 0, -hd - 1.6), top + 6.0, 14.0, 35.0)
	else:
		_derrick(Vector3(-hw - 1.2, 0, hd + 0.8), top + 3.0)


## A tower crane: lattice mast, slewing cab, jib with trolley and hook, counter-jib with
## concrete counterweights. Signal orange, a mid-century crane.
func _tower_crane(p: Vector3, h: float, jib: float, rot_y := 0.0) -> void:
	_box("concrete", p + Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 2.2))
	_lattice_tower(p + Vector3(0, 0.6, 0), 1.4, h - 0.6, "enamel_mustard", 1.4, 0.14)
	_push(_xf(p + Vector3(0, h, 0), rot_y))
	_cyl("steel_dark", Vector3(0, 0, 0), 0.8, 0.8, 0.3, 10)
	_box("warm_white", Vector3(0.9, -0.3, 0.3), Vector3(1.2, 1.3, 1.1))
	_box("glass_blue", Vector3(1.51, -0.2, 0.3), Vector3(0.02, 0.7, 0.9))
	_lathe("enamel_mustard", Vector3(0, 0.3, 0), [Vector2(0.6, 0), Vector2(0.0, 3.0)], 4, Vector3(0, 45, 0))
	_truss("enamel_mustard", Vector3(0, 0.3, -0.5), Vector3(jib, 0.3, -0.5), 1.0, Vector3.UP, 0.1)
	_truss("enamel_mustard", Vector3(0, 0.3, 0.5), Vector3(jib, 0.3, 0.5), 1.0, Vector3.UP, 0.1)
	for i in int(jib / 1.4):
		_beam("enamel_mustard", Vector3(i * 1.4, 0.3, -0.5), Vector3(i * 1.4, 0.3, 0.5), 0.08)
	_beam("steel", Vector3(0, 3.2, 0), Vector3(jib * 0.75, 1.3, 0), 0.03)
	_beam("steel", Vector3(0, 3.2, 0), Vector3(-jib * 0.3, 1.3, 0), 0.03)
	_truss("enamel_mustard", Vector3(0, 0.3, 0), Vector3(-jib * 0.32, 0.3, 0), 0.6, Vector3.UP, 0.12)
	_box("concrete_dark", Vector3(-jib * 0.28, -0.4, 0), Vector3(1.4, 1.4, 1.2))
	var tx := jib * 0.62
	_box("steel_dark", Vector3(tx, 0.15, 0), Vector3(0.6, 0.3, 1.0))
	_rod("steel_dark", Vector3(tx, 0.0, 0), Vector3(tx, -h * 0.55, 0), 0.02, 3)
	_box("signal_orange", Vector3(tx, -h * 0.55 - 0.2, 0), Vector3(0.3, 0.4, 0.3))
	_ibeam("steel", Vector3(tx - 1.6, -h * 0.55 - 0.6, 0), Vector3(tx + 1.6, -h * 0.55 - 0.6, 0), 0.3, Vector3.UP)
	_ball("signal_lamp", Vector3(jib, 1.4, 0), 0.1, 5, 3)
	_pop()


## A guyed timber-and-steel derrick for smaller plots.
func _derrick(p: Vector3, h: float) -> void:
	_rod("steel", p, p + Vector3(0, h, 0), 0.12, 6)
	_beam("signal_orange", p + Vector3(0, 0.8, 0), p + Vector3(3.6, h * 0.8, 0.2), 0.16)
	_rod("steel_dark", p + Vector3(0, h, 0), p + Vector3(3.6, h * 0.8, 0.2), 0.02, 3)
	_rod("steel_dark", p + Vector3(3.6, h * 0.8, 0.2), p + Vector3(3.6, h * 0.35, 0.2), 0.02, 3)
	_ibeam("steel", p + Vector3(2.4, h * 0.33, 0.2), p + Vector3(4.8, h * 0.33, 0.2), 0.24, Vector3.UP)
	for a in [0.4, 2.5, 4.6]:
		_rod("steel_dark", p + Vector3(0, h, 0), p + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0), 0.012, 3)


# ================================================================== the rocket (Era 4 milestone 3, DESIGN 9)
# A friendly retro rocket, 23 m from its fin feet to the tip of the spike: warm white with
# signal-orange fins, skirt and nose, a night-blue roll pattern, round portholes in the crew
# cabin, the open hand on both faces of the booster and on the cabin hatch (the crew touch
# it before they board), the mission patch on the tank stage. Built in three segments that
# stack: 0 booster (fins, engines) 0..9.0 m, 1 tank stage 9.0..14.4 m, 2 cabin and nose
# 14.4..23 m. The hatch faces -X, toward the launch tower's access arm.

const SEG_Y := [0.0, 9.0, 14.4, 23.0]


func _rocket_seg(k: int, y_off: float, ready := false) -> void:
	_push(_xf(Vector3(0, -y_off, 0)))
	match k:
		0:
			# five engine bells under a flared orange skirt
			for e in 5:
				var p := Vector3.ZERO if e == 0 else Vector3(cos(TAU * e / 4.0 + PI / 4.0), 0, sin(TAU * e / 4.0 + PI / 4.0)) * 0.82
				_lathe("steel_dark", p + Vector3(0, 0.35, 0), [Vector2(0.44, 0), Vector2(0.38, 0.35), Vector2(0.24, 0.8), Vector2(0.16, 1.1)], 12, Vector3.ZERO, Vector3.ONE, 0.0, false)
				_lathe("cave_dark", p + Vector3(0, 0.36, 0), [Vector2(0.4, 0), Vector2(0, 0.3)], 12)
				_cyl("chrome", p + Vector3(0, 1.05, 0), 0.2, 0.24, 0.3, 10)
			_lathe("steel", Vector3(0, 1.3, 0), [Vector2(1.6, 0), Vector2(0, 0)], 24)
			_lathe("signal_orange", Vector3(0, 1.3, 0), [Vector2(1.6, 0), Vector2(1.86, 0.1), Vector2(1.86, 0.3), Vector2(1.58, 1.2), Vector2(R0, 1.3)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("chrome", Vector3(0, 1.38, 0), [Vector2(1.88, 0), Vector2(1.88, 0.14)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("warm_white", Vector3(0, 2.6, 0), [Vector2(R0, 0), Vector2(R0, 6.4)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("night_blue", Vector3(0, 3.0, 0), [Vector2(R0 + 0.01, 0), Vector2(R0 + 0.01, 0.12)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_checker(8.0, 0.9, R0, 8, 2)
			# the open hand on both faces, between the fins
			for at in [0.0, PI]:
				_wrap(R0, at, func() -> void: _hand_badge(Vector3(0, 5.75, 0), 1.85))
			# four swept fins with teardrop pods at the tips (the rocket stands on them)
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				var rad := Vector3(sin(a), 0, cos(a))
				_push(Transform3D(Basis(rad, Vector3.UP, rad.cross(Vector3.UP)), Vector3.ZERO))
				_plate("signal_orange", [Vector2(1.4, 5.7), Vector2(2.1, 3.9), Vector2(3.4, 1.9), Vector2(3.5, 0.55), Vector2(2.6, 1.15), Vector2(1.4, 2.0)], 0.0, 0.24)
				_plate("night_blue", [Vector2(1.75, 4.85), Vector2(2.14, 3.95), Vector2(3.42, 1.95), Vector2(3.3, 1.55), Vector2(2.0, 3.75), Vector2(1.6, 4.9)], 0.0, 0.27)
				_lathe("signal_orange", Vector3(3.5, 0.0, 0), [Vector2(0.0, 0.0), Vector2(0.16, 0.12), Vector2(0.26, 0.5), Vector2(0.26, 1.4), Vector2(0.18, 2.3), Vector2(0.0, 2.7)], 10)
				_lathe("chrome", Vector3(3.5, 0.02, 0), [Vector2(0.17, 0.0), Vector2(0.23, 0.22)], 10, Vector3.ZERO, Vector3.ONE, 0.0, false)
				_pop()
			if ready:   # frost from the cold fuel at the top of the booster tank
				_lathe("frost", Vector3(0, 6.6, 0), [Vector2(R0 + 0.025, 0), Vector2(R0 + 0.025, 1.2)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
		1:
			_lathe("chrome", Vector3(0, 9.0, 0), [Vector2(R0 + 0.03, 0), Vector2(R0 + 0.03, 0.12)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("night_blue", Vector3(0, 9.12, 0), [Vector2(R0, 0), Vector2(R0, 0.6)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			for v in 8:   # interstage vents
				_wrap(R0, TAU * v / 8.0 + PI / 8.0, func() -> void:
					for s in 3:
						_box("steel_dark", Vector3(0, 9.26 + s * 0.12, 0.01), Vector3(0.36, 0.05, 0.03)))
			_lathe("warm_white", Vector3(0, 9.72, 0), [Vector2(R0, 0), Vector2(R0, 4.08)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("signal_orange", Vector3(0, 13.7, 0), [Vector2(R0 + 0.01, 0), Vector2(R0 + 0.01, 0.7)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("warm_white", Vector3(0, 13.8, 0), [Vector2(R0, 0), Vector2(R0, 0.6)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			for at in [PI * 0.5, -PI * 0.5]:
				_wrap(R0, at, func() -> void:
					_face_disc("mission_patch", Vector3(0, 11.6, 0.03), 0.85, 20)
					_lathe("chrome", Vector3(0, 11.6, 0.0), [Vector2(0.92, 0), Vector2(0.92, 0.04), Vector2(0.85, 0.04)], 20, Vector3(90, 0, 0), Vector3.ONE, 0.0, false))
			for at in [0.0, PI]:   # a slim navy pinstripe down the faces
				_wrap(R0, at, func() -> void: _box("night_blue", Vector3(0, 11.7, 0.005), Vector3(0.14, 3.6, 0.02)))
			_cyl("steel", Vector3(-R0 - 0.05, 13.3, 0), 0.08, 0.08, 0.3, 6, Vector3(0, 0, 90))   # fuel vent
			if ready:
				_lathe("frost", Vector3(0, 10.0, 0), [Vector2(R0 + 0.025, 0), Vector2(R0 + 0.025, 2.6)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
		2:
			_lathe("chrome", Vector3(0, 14.4, 0), [Vector2(R0 + 0.03, 0), Vector2(R0 + 0.03, 0.14), Vector2(R0, 0.14)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("warm_white", Vector3(0, 14.54, 0), [Vector2(R0, 0), Vector2(1.32, 0.5), Vector2(1.32, 2.9)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			# the crew cabin: a ring of portholes, the hatch toward the tower with the hand
			for i in 6:
				var a := TAU * i / 6.0
				if absf(wrapf(a + PI * 0.5, -PI, PI)) < 0.6:
					continue
				_wrap(1.32, a, func() -> void: _porthole(Vector3(0, 16.25, 0), 0.32, "porthole_lit" if ready else "glass_dark"))
			_wrap(1.32, -PI * 0.5, func() -> void:
				_box("warm_white", Vector3(0, 16.2, 0.02), Vector3(0.95, 1.35, 0.04))
				_box("chrome", Vector3(0, 16.2, 0.01), Vector3(1.05, 1.45, 0.02))
				_box("steel_dark", Vector3(0.32, 16.1, 0.05), Vector3(0.08, 0.3, 0.04))
				_porthole(Vector3(0, 16.5, 0.03), 0.17, "porthole_lit" if ready else "glass_dark")
				_hand_badge(Vector3(0, 17.3, 0.0), 0.5, "signal_orange", ""))
			_lathe("night_blue", Vector3(0, 17.36, 0), [Vector2(1.33, 0), Vector2(1.33, 0.1)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			# the ogive nose, orange tipped, with a chrome spike
			var prof := []
			for j in 11:
				var t := j / 10.0
				prof.append(Vector2(1.32 * pow(cos(t * PI * 0.5), 0.8) if j < 10 else 0.0, t * 4.6))
			var white := prof.slice(0, 7)
			var tip := prof.slice(6)
			_lathe("warm_white", Vector3(0, 17.46, 0), white, 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_lathe("signal_orange", Vector3(0, 17.46, 0), tip, 24)
			_lathe("night_blue", Vector3(0, 17.46 + (white[6] as Vector2).y - 0.05, 0), [Vector2((white[6] as Vector2).x + 0.01, 0), Vector2((white[6] as Vector2).x - 0.02, 0.14)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_rod("chrome", Vector3(0, 21.9, 0), Vector3(0, 23.0, 0), 0.06, 6, 0.02)
			_ball("chrome", Vector3(0, 22.3, 0), 0.1, 6, 3)
	_pop()


## A band of roll-pattern squares (night blue / warm white) on a cylinder of radius r.
func _checker(y0: float, h: float, r: float, around: int, rows: int) -> void:
	var seg := 24
	for row in rows:
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var cell := int(j * around / seg)
			var m := "night_blue" if (cell + row) % 2 == 0 else "warm_white"
			var ya := y0 + h * row / rows
			var yb := y0 + h * (row + 1) / rows
			var c0 := Vector3(sin(a0), 0, cos(a0)) * (r + 0.012)
			var c1 := Vector3(sin(a1), 0, cos(a1)) * (r + 0.012)
			_quad(m, c0 + Vector3(0, ya, 0), c1 + Vector3(0, ya, 0), c1 + Vector3(0, yb, 0), c0 + Vector3(0, yb, 0), (c0 + c1) * 0.5)


func _rockets() -> void:
	# the stack as it is built on the pad: booster, + tank stage, + cabin and nose
	_begin("rocket_stage_1")
	_rocket_seg(0, 0.0)
	_save("rocket_stage_1")
	_begin("rocket_stage_2")
	_rocket_seg(0, 0.0)
	_rocket_seg(1, 0.0)
	_save("rocket_stage_2")
	_begin("rocket")
	for k in 3:
		_rocket_seg(k, 0.0)
	_save("rocket")
	# liftoff-ready: fuelled (frost bands, lit portholes, the crew aboard), venting steam
	# from the base and the fuel vent; the exhaust waits on ExhaustHook for ignition
	_begin("rocket_ready")
	for k in 3:
		_rocket_seg(k, 0.0, true)
	_puffs("Steam", Vector3(0, 0.6, 0), Vector3(1, 0.15, 0.3), "steam", 40, 5.0, 2.4, 2.6, 75.0)
	_puffs("VentSteam", Vector3(-R0 - 0.2, 13.3, 0), Vector3(-1, -0.3, 0.2), "steam", 18, 3.5, 1.2, 1.6, 12.0)
	var hook := _group("ExhaustHook", Vector3(0, 0.35, 0))
	_puffs("Exhaust", Vector3.ZERO, Vector3.DOWN, "exhaust", 60, 0.9, 2.2, 14.0, 6.0, false, hook)
	_puffs("ExhaustSmoke", Vector3(0, -0.4, 0), Vector3(0.3, -0.2, 0), "smoke", 70, 6.0, 4.0, 7.0, 80.0, false, hook)
	_hidden_light("ExhaustLight", Vector3(0, -1.0, 0), Color("#ffb060"), 8.0, 40.0, Vector3.INF, 25.0, hook)
	_save("rocket_ready")
	# the segments on their own, standing, for the hand to carry and stack (Strength III)
	for spec in [["rocket_segment_booster", 0], ["rocket_segment_tank", 1], ["rocket_segment_upper", 2]]:
		_begin(spec[0])
		_rocket_seg(spec[1], SEG_Y[spec[1]])
		_save(spec[0])


# ================================================================== the launch tower (Era 4 shrine stage, milestone 2)
# DESIGN 7: "The shrine grows with them ... launch tower (Era 4)", built where the great hall
# stood; DESIGN 9: "The shrine has become the base of the launch tower". The octagonal pad
# with its flame pit is centred on the origin (the rocket stands at RocketMount); the
# gantry rises from a massive ashlar plinth (the great hall's warm stone, carried on) on
# the -X side, crowned by the gilded open hand like every shrine before it. Beside the
# plinth, the old shrine stone of the first tribe sits on its dais in a railed garden, the
# hand in gold above it on the plinth wall, and the curved crew bench faces it (Seat1-4).
# AccessArm swings on its pivot (rotate it about Y to retract it); Floods are hidden.

const TOWER_X := -5.8
const TOWER_W := 3.6
const TOWER_TOP := 28.0
const ARM_Y := MOUNT_Y + 15.55


func _launch_tower() -> void:
	_begin("launch_tower")
	_pad(true)
	_tower_plinth()
	_lattice_tower(Vector3(TOWER_X, PAD_H + 1.2, 0), TOWER_W, TOWER_TOP - PAD_H - 1.2, "signal_orange", 2.4, 0.28)
	# service platforms, the lift and its cage
	for k in 5:
		var y := PAD_H + 1.2 + 4.8 * (k + 1)
		_box("steel_dark", Vector3(TOWER_X, y, 0), Vector3(TOWER_W + 1.4, 0.12, TOWER_W + 1.4))
		_railing_box(Vector3(TOWER_X, y, 0), TOWER_W + 1.4, 1.0)
	_box("warm_white", Vector3(TOWER_X, PAD_H + 7.4, -0.6), Vector3(1.5, 2.4, 1.5))
	_box("glass_blue", Vector3(TOWER_X + 0.76, PAD_H + 7.7, -0.6), Vector3(0.02, 0.9, 0.9))
	_box("signal_orange", Vector3(TOWER_X, PAD_H + 8.66, -0.6), Vector3(1.6, 0.12, 1.6))
	# umbilical arms to the booster and tank stage, with fuel lines dropping to the rocket
	for y in [MOUNT_Y + 8.4, MOUNT_Y + 12.9]:
		var x0 := TOWER_X + TOWER_W * 0.5
		var x1 := -R0 - 0.7
		_truss("steel", Vector3(x0, y, -0.5), Vector3(x1, y, -0.5), 0.9, Vector3.UP, 0.12)
		_truss("steel", Vector3(x0, y, 0.5), Vector3(x1, y, 0.5), 0.9, Vector3.UP, 0.12)
		_box("steel_dark", Vector3((x0 + x1) * 0.5, y, 0), Vector3(x1 - x0, 0.08, 1.1))
		for z in [-0.25, 0.25]:
			_rod("enamel_mustard", Vector3(x1, y, z), Vector3(-R0 - 0.06, y - 0.8, z * 0.5), 0.09, 6)
			_rod("enamel_mustard", Vector3(x0, y + 0.1, z), Vector3(x1, y, z), 0.08, 6)
	# the crew access arm with its white room, on a pivot at the tower face
	var arm := _part("AccessArm", Vector3(TOWER_X + TOWER_W * 0.5, ARM_Y, 0), _access_arm)
	arm.set_meta("retract_degrees", 90.0)   # rotate about Y by this to swing it clear
	# the hammerhead crane on top and the gilded hand finial: the spire of every shrine
	var top := Vector3(TOWER_X, TOWER_TOP, 0)
	_box("steel_dark", top + Vector3(0, 0.1, 0), Vector3(TOWER_W + 0.6, 0.2, TOWER_W + 0.6))
	_truss("signal_orange", top + Vector3(-2.6, 0.2, -0.45), top + Vector3(7.0, 0.2, -0.45), 1.1, Vector3.UP, 0.14)
	_truss("signal_orange", top + Vector3(-2.6, 0.2, 0.45), top + Vector3(7.0, 0.2, 0.45), 1.1, Vector3.UP, 0.14)
	for i in 8:
		_beam("signal_orange", top + Vector3(-2.6 + i * 1.37, 0.2, -0.45), top + Vector3(-2.6 + i * 1.37, 0.2, 0.45), 0.1)
	_box("concrete_dark", top + Vector3(-2.2, 0.9, 0), Vector3(1.0, 1.2, 1.0))
	_box("warm_white", top + Vector3(0.6, -0.6, 1.0), Vector3(1.2, 1.2, 1.0))
	_rod("steel_dark", top + Vector3(5.8, 0.2, 0), top + Vector3(5.8, -1.6, 0), 0.03, 3)
	_box("signal_orange", top + Vector3(5.8, -1.8, 0), Vector3(0.36, 0.4, 0.36))
	_rod("chrome", top + Vector3(0, 1.3, 0), top + Vector3(0, 2.6, 0), 0.08, 6)
	_ball("hand_gold", top + Vector3(0, 2.0, 0), 0.22, 8, 4)
	_hand_symbol("hand_gold", top + Vector3(0, 3.5, 0.03), Vector3(0, 0, 1), Vector3.UP, 1.5, 0.08)
	_hand_symbol("hand_gold", top + Vector3(0, 3.5, -0.03), Vector3(0, 0, -1), Vector3.UP, 1.5, 0.08)
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_ball("signal_lamp", top + Vector3(c.x * TOWER_W * 0.5, 0.3, c.y * TOWER_W * 0.5), 0.12, 5, 3)
	_ball("signal_lamp", top + Vector3(7.0, 1.4, 0), 0.12, 5, 3)
	_shrine_garden(true)
	_flood_masts()
	var mount := _group("RocketMount", Vector3(0, MOUNT_Y, 0))
	mount.set_meta("rocket_ids", ["rocket_stage_1", "rocket_stage_2", "rocket", "rocket_ready"])
	_save("launch_tower")

	_begin("launch_tower_plot")
	_box("dirt", Vector3(0, 0.025, 0), Vector3(19.0, 0.05, 19.0))
	for k in 8:   # the outline of the pad staked out in orange
		var a0 := TAU * k / 8.0 + PI / 8.0
		var a1 := TAU * (k + 1) / 8.0 + PI / 8.0
		var p0 := Vector3(cos(a0), 0, sin(a0)) * 8.6
		var p1 := Vector3(cos(a1), 0, sin(a1)) * 8.6
		_box("wood", p0 + Vector3(0, 0.4, 0), Vector3(0.08, 0.8, 0.08))
		_box("signal_orange", p0 + Vector3(0, 0.75, 0), Vector3(0.1, 0.12, 0.1))
		_beam("canvas_orange", p0 + Vector3(0, 0.6, 0), p1 + Vector3(0, 0.6, 0), 0.04, 0.12)
	_box("soil_dark", Vector3(0, 0.06, 0), Vector3(4.0, 0.02, 4.0))   # the flame pit marked out
	_steel_pile(Vector3(4.0, 0, 6.0), 20.0, 5.0)
	_steel_pile(Vector3(-2.0, 0, 7.0), -10.0, 5.0)
	_mixer(Vector3(5.2, 0, -4.0), 120.0)
	_theodolite(Vector3(2.6, 0, 3.0))
	_shrine_garden(false)
	_save("launch_tower_plot")

	_begin("launch_tower_frame")
	_pad(false)
	_tower_plinth()
	_lattice_tower(Vector3(TOWER_X, PAD_H + 1.2, 0), TOWER_W, 12.0, "signal_orange", 2.4, 0.28)
	_box("steel_dark", Vector3(TOWER_X, PAD_H + 1.2 + 9.6, 0), Vector3(TOWER_W + 1.4, 0.12, TOWER_W + 1.4))
	for k in 3:   # the next lengths of leg waiting to be lifted
		_ibeam("signal_orange", Vector3(5.0, 0.3 + k * 0.32, -6.4 + k * 0.4), Vector3(5.0, 0.3 + k * 0.32, -1.4 + k * 0.4), 0.3, Vector3.UP)
	_tower_crane(Vector3(TOWER_X - 2.0, 0, -6.0), 24.0, 16.0, 20.0)
	_steel_pile(Vector3(4.6, 0, 6.4), 20.0, 5.0)
	_shrine_garden(true)
	_save("launch_tower_frame")


## The crew access arm, built in its pivot's frame (x toward the rocket).
func _access_arm() -> void:
	var l := -R0 * 0.85 - (TOWER_X + TOWER_W * 0.5) - 0.2
	_box("steel_dark", Vector3(l * 0.5, 0, 0), Vector3(l, 0.14, 1.5))
	_truss("signal_orange", Vector3(0, -1.0, -0.75), Vector3(l, -1.0, -0.75), 1.0, Vector3.UP, 0.1)
	_truss("signal_orange", Vector3(0, -1.0, 0.75), Vector3(l, -1.0, 0.75), 1.0, Vector3.UP, 0.1)
	_box("warm_white", Vector3(l * 0.4, 1.25, 0.76), Vector3(l * 0.8, 2.4, 0.06))
	_box("warm_white", Vector3(l * 0.4, 1.25, -0.76), Vector3(l * 0.8, 2.4, 0.06))
	_box("warm_white", Vector3(l * 0.4, 2.48, 0), Vector3(l * 0.8, 0.1, 1.58))
	for x in [0.6, 1.5]:
		_box("glass_blue", Vector3(x, 1.5, 0.8), Vector3(0.6, 0.5, 0.02))
	_box("warm_white", Vector3(l - 0.45, 1.3, 0), Vector3(0.9, 2.6, 2.2))   # the white room
	_box("night_blue", Vector3(l - 0.45, 2.62, 0), Vector3(1.0, 0.08, 2.3))
	_hand_symbol("signal_orange", Vector3(l - 0.45, 1.7, 1.11), Vector3.BACK, Vector3.UP, 0.7, 0.03)
	_box("glass_blue", Vector3(l - 0.45, 1.6, -1.11), Vector3(0.5, 0.6, 0.02))


## The launch pad: an octagonal concrete deck PAD_H high, a ramp up from +Z, the flame pit
## at the centre with its trench running out under the +X side, the four hold-down
## pedestals the fins stand on, a railing round the edge.
func _pad(done: bool) -> void:
	_lathe("concrete", Vector3.ZERO, [Vector2(8.8, 0), Vector2(8.5, PAD_H), Vector2(0, PAD_H)], 8, Vector3.ZERO, Vector3.ONE, PI / 8.0)
	_lathe("concrete_dark", Vector3(0, PAD_H, 0), [Vector2(8.45, 0.01), Vector2(7.6, 0.01)], 8, Vector3.ZERO, Vector3.ONE, PI / 8.0, false)
	_box("cave_dark", Vector3(0, PAD_H + 0.012, 0), Vector3(3.4, 0.01, 3.4))
	_box("steel_dark", Vector3(0, PAD_H + 0.02, 0), Vector3(3.8, 0.02, 0.2))
	_box("steel_dark", Vector3(0, PAD_H + 0.02, 0), Vector3(0.2, 0.02, 3.8))
	_box("cave_dark", Vector3(8.0, PAD_H * 0.45, 0), Vector3(1.2, PAD_H * 0.8, 3.0))   # trench mouth
	_box("concrete_dark", Vector3(9.3, 0.04, 0), Vector3(3.0, 0.08, 4.6))
	# the ramp up from the road
	_slab("concrete", [Vector3(-2.0, PAD_H, 7.4), Vector3(2.0, PAD_H, 7.4), Vector3(2.0, 0.02, 13.0), Vector3(-2.0, 0.02, 13.0)], PAD_H, Vector3.UP)
	if not done:
		return
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var p := Vector3(sin(a), 0, cos(a)) * 3.5
		_box("concrete_flat", p + Vector3(0, PAD_H + 0.2, 0), Vector3(0.9, 0.4, 0.9), Vector3(0, rad_to_deg(a), 0))
		_box("signal_orange", p + Vector3(0, PAD_H + 0.42, 0), Vector3(0.6, 0.06, 0.6), Vector3(0, rad_to_deg(a), 0))
	var ring := []
	for k in 9:
		var a := TAU * k / 8.0 + PI / 8.0
		ring.append(Vector3(cos(a), 0, sin(a)) * 8.35 + Vector3(0, PAD_H, 0))
	for k in 8:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[k + 1]
		if (a + b).z > 13.0:
			continue   # leave the ramp open
		_beam("signal_orange", a + Vector3(0, 1.0, 0), b + Vector3(0, 1.0, 0), 0.06)
		_beam("steel", a + Vector3(0, 0.5, 0), b + Vector3(0, 0.5, 0), 0.04)
		for j in 4:
			var p := a.lerp(b, j / 4.0)
			_beam("steel", p, p + Vector3(0, 1.0, 0), 0.05)


## The ashlar plinth the gantry stands on (the great hall's stone), its west face carrying
## the gilded hand over the old shrine stone.
func _tower_plinth() -> void:
	var c := Vector3(TOWER_X, 0, 0)
	var h := PAD_H + 1.2
	_box("ashlar_warm", c + Vector3(0, h * 0.5, 0), Vector3(TOWER_W + 1.4, h, TOWER_W + 1.4))
	_box("limestone", c + Vector3(0, h + 0.06, 0), Vector3(TOWER_W + 1.6, 0.12, TOWER_W + 1.6))
	_box("ashlar_warm", c + Vector3(-0.3, 0.4, 0), Vector3(TOWER_W + 2.4, 0.8, TOWER_W + 2.0))
	_hand_symbol("hand_gold", c + Vector3(-(TOWER_W + 1.4) * 0.5 - 0.01, h * 0.55, 0), Vector3.LEFT, Vector3.UP, 1.6, 0.08)
	_box("brass", c + Vector3(0, h * 0.55, (TOWER_W + 1.4) * 0.5 + 0.01), Vector3(1.4, 0.7, 0.03))   # foundation plaque


## The old shrine stone on its dais in a railed garden west of the plinth, and the crew
## bench facing it (DESIGN 9.2 beat 2: four seats, CrewBench/Seat1..Seat4).
func _shrine_garden(bench: bool) -> void:
	var sp := Vector3(TOWER_X - 4.6, 0, 0.0)
	_lathe("limestone", sp, [Vector2(2.6, 0), Vector2(2.6, 0.2), Vector2(0, 0.2)], 12)
	_lathe("turf", sp + Vector3(0, 0.2, 0), [Vector2(2.4, 0.005), Vector2(0, 0.005)], 12)
	_lathe("limestone", sp + Vector3(0, 0.2, 0), [Vector2(1.0, 0), Vector2(1.0, 0.3), Vector2(0, 0.3)], 10)
	_shrine_stone(sp + Vector3(0, 0.5, 0), 90.0)
	var ring := []
	for k in 13:
		var a := PI * 0.5 + PI * k / 12.0
		ring.append(sp + Vector3(cos(a) * 2.5, 0.2, -sin(a) * 2.5))
	_railing(ring, 0.6, false)
	for k in 7:
		var a := PI * 0.6 + k * 0.3
		_ball("leaf", sp + Vector3(cos(a) * 1.7, 0.4, sin(a) * 1.7), 0.22, 5, 3)
		_ball(["enamel_coral", "enamel_mustard", "warm_white"][k % 3], sp + Vector3(cos(a) * 1.7, 0.6, sin(a) * 1.7), 0.09, 5, 3)
	if not bench:
		return
	var g := _group("CrewBench", sp)
	for k in 4:
		var a := PI - 0.5 + k * (1.0 / 3.0)
		var p := Vector3(cos(a), 0, sin(a)) * 3.3
		var rot := rad_to_deg(atan2(-p.x, -p.z))
		_push(_xf(sp + p, rot))
		_box("warm_white", Vector3(0, 0.42, 0), Vector3(1.0, 0.1, 0.55))
		_box("signal_orange", Vector3(0, 0.5, 0.0), Vector3(0.9, 0.08, 0.48))
		_box("warm_white", Vector3(0, 0.8, -0.27), Vector3(1.0, 0.7, 0.08), Vector3(-10, 0, 0))
		_box("steel", Vector3(0, 0.2, 0), Vector3(0.12, 0.4, 0.4))
		_pop()
		var seat := Node3D.new()
		seat.name = "Seat%d" % (k + 1)
		seat.position = p + Vector3(0, 0.5, 0)
		seat.rotation.y = deg_to_rad(rot)
		g.add_child(seat)
		seat.owner = _root


## Four floodlight masts round the pad, their lamp banks aimed at the rocket; the lights
## (Floods/Flood1..4) ship switched off, the lamp faces glow in NightGlow.
func _flood_masts() -> void:
	var floods := _group("Floods")
	var i := 0
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var p := Vector3(c.x * 9.6, 0, c.y * 9.6)
		_box("concrete", p + Vector3(0, 0.2, 0), Vector3(1.4, 0.4, 1.4))
		_lattice_tower(p + Vector3(0, 0.4, 0), 0.8, 13.0, "steel", 1.6, 0.12)
		var head := p + Vector3(0, 13.6, 0)
		var to := (Vector3(0, 12.0, 0) - head).normalized()
		var yaw := rad_to_deg(atan2(to.x, to.z))
		_push(_xf(head, yaw))
		_box("steel_dark", Vector3(0, 0, -0.1), Vector3(2.6, 1.4, 0.2))
		for r in 2:
			for k in 4:
				var lp := Vector3(-0.96 + k * 0.64, -0.3 + r * 0.62, 0.0)
				_lathe("chrome", lp, [Vector2(0.26, 0), Vector2(0.28, 0.18), Vector2(0.24, 0.18)], 8, Vector3(90, 0, 0), Vector3.ONE, 0.0, false)
				_night.append([_t * (lp + Vector3(-0.2, -0.2, 0.12)), _t * (lp + Vector3(0.2, -0.2, 0.12)), _t * (lp + Vector3(0.2, 0.2, 0.12)),
					_t * (lp + Vector3(-0.2, 0.2, 0.12)), _t.basis * Vector3.BACK])
		_pop()
		i += 1
		var l := _hidden_light("Flood%d" % i, head + to * 0.6, Color("#fff0d4"), 2.6, 50.0, Vector3(0, 10.0, 0), 32.0, floods)
		l.shadow_enabled = true


## A railing round a square platform of side w centred on c (deck at c.y).
func _railing_box(c: Vector3, w: float, h: float) -> void:
	var hw := w * 0.5
	var cs := [Vector3(-hw, 0, -hw), Vector3(hw, 0, -hw), Vector3(hw, 0, hw), Vector3(-hw, 0, hw)]
	for i in 4:
		var a: Vector3 = c + cs[i]
		var b: Vector3 = c + cs[(i + 1) % 4]
		_beam("warm_white", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.05)
		_beam("steel", a + Vector3(0, h * 0.5, 0), b + Vector3(0, h * 0.5, 0), 0.03)
		_beam("steel", a, a + Vector3(0, h, 0), 0.05)


# ================================================================== homes: apartment blocks

const ENAMELS := ["enamel_turquoise", "enamel_mustard", "enamel_coral", "enamel_mint", "enamel_sky"]


func _apartments() -> void:
	_begin("apartment_a")
	_apt_brick()
	_save("apartment_a")
	_begin("apartment_b")
	_apt_streamline()
	_save("apartment_b")
	_begin("apartment_c")
	_apt_tower()
	_save("apartment_c")
	_begin("apartment_plot")
	_plot4(14.0, 10.0)
	_save("apartment_plot")
	_begin("apartment_frame")
	_frame4(14.0, 9.0, 4, 3.0, 2, true)
	_save("apartment_frame")


## A: a four-storey red-brick slab (the Era 3 brick, carried on) with warm-white floor
## bands, enamel-panelled balconies, shops with awnings on the ground floor, and a roof of
## TV aerials, a stair house and a water tank.
func _apt_brick() -> void:
	var w := 14.0
	var d := 9.0
	var fh := 3.0
	_box("concrete_flat", Vector3(0, 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3))
	_box("brick", Vector3(0, 0.3 + 6.0, 0), Vector3(w, 12.0, d))
	for k in 5:
		_box("warm_white", Vector3(0, 0.3 + k * fh + (0.0 if k > 0 else 0.1), 0), Vector3(w + 0.24, 0.22, d + 0.24))
	_box("warm_white", Vector3(0, 0.3 + 1.5, d * 0.5 + 0.02), Vector3(w, 3.0, 0.05))   # shop fronts rendered white
	_on_face(w, d, "front", func() -> void:
		# ground floor: two shops either side of the stair door
		for sx in [-1.0, 1.0]:
			_ribbon(sx * 1.6 if sx > 0 else -6.6, 6.6 if sx > 0 else -1.6, 0.6, 2.0, 1.25, "night_blue", 0.8)
			_model(CITY + "detail-awning-wide.glb", Vector3(sx * 4.1, 2.6, 0.1), Vector3.ZERO, Vector3(2.4, 1.6, 1.6), null, KIND)
		_box("night_blue", Vector3(0, 1.25, 0.06), Vector3(1.3, 2.3, 0.08))
		_box("glass_blue", Vector3(0, 1.45, 0.11), Vector3(0.9, 1.6, 0.02))
		_box("warm_white", Vector3(0, 2.8, 0.7), Vector3(2.2, 0.12, 1.4))
		for i in 3:
			_box("concrete_flat", Vector3(0, 0.1 + i * 0.1, 0.5 - i * 0.25), Vector3(1.8, 0.1, 0.5))
		# upper floors: five bays, balconies on the second and fourth
		for k in range(1, 4):
			var y := 0.3 + k * fh
			_windows(-7.0, 7.0, y + 0.8, 1.6, 5, "warm_white")
			for b in [1, 3]:
				var cx: float = -7.0 + 2.8 * (b + 0.5)
				_box("warm_white", Vector3(cx, y + 0.1, 0.6), Vector3(2.5, 0.14, 1.2))
				_box(ENAMELS[(b + k) % ENAMELS.size()], Vector3(cx, y + 0.6, 1.17), Vector3(2.5, 0.9, 0.06))
				for sx in [-1.0, 1.0]:
					_box("steel", Vector3(cx + sx * 1.22, y + 0.6, 0.62), Vector3(0.05, 0.9, 1.1))
				_beam("steel", Vector3(cx - 1.25, y + 1.1, 1.17), Vector3(cx + 1.25, y + 1.1, 1.17), 0.05))
	_on_face(w, d, "back", func() -> void:
		for k in 4:
			_windows(-7.0, 7.0, 0.3 + k * fh + 0.8, 1.6, 6, "warm_white"))
	for side in ["left", "right"]:
		_on_face(w, d, side, func() -> void:
			for k in 4:
				_windows(-3.0, 3.0, 0.3 + k * fh + 0.8, 1.6, 2, "warm_white"))
	_flat_roof(w, d, 12.3, "vents,stair,tank,aerial")


## B: a five-storey streamline block in warm-white render: ribbon windows over night-blue
## bands wrapping the front and the right side, a glazed round stair tower on the corner
## running up past the roof with the mission flag, speed-line pinstripes at the parapet.
func _apt_streamline() -> void:
	var w := 12.0
	var d := 10.0
	var fh := 3.0
	var top := 0.3 + 5 * fh
	_box("concrete_flat", Vector3(0, 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3))
	_box("warm_white", Vector3(0, 0.3 + top * 0.5 - 0.15, 0), Vector3(w, top - 0.3, d))
	for side in ["front", "right"]:
		var span := w if side == "front" else d
		_on_face(w, d, side, func() -> void:
			for k in 5:
				var y := 0.3 + k * fh
				_box("night_blue", Vector3(0, y + 0.45, 0.02), Vector3(span, 0.5, 0.05))
				if k == 0 and side == "front":
					_ribbon(-span * 0.5 + 3.0, span * 0.5 - 0.6, 0.9, 2.0, 1.5, "chrome", 0.8)
					continue
				_ribbon(-span * 0.5 + (2.6 if side == "front" else 0.6), span * 0.5 - 0.6, y + 0.85, 1.5, 1.2, "chrome")
			for k in 3:
				_box("night_blue" if k != 1 else "signal_orange", Vector3(0, top - 0.6 + k * 0.18, 0.03), Vector3(span, 0.08, 0.05)))
	for side in ["back", "left"]:
		var span2 := w if side == "back" else d
		_on_face(w, d, side, func() -> void:
			for k in 5:
				_windows(-span2 * 0.5 + 1.0, span2 * 0.5 - 1.0, 0.3 + k * fh + 0.85, 1.5, 4 if side == "back" else 3, "chrome"))
	# the glazed stair drum on the front-left corner
	var sc := Vector3(-w * 0.5 + 1.2, 0, d * 0.5 - 1.2)
	_cyl("concrete_flat", sc, 2.1, 2.1, 0.3, 20)
	for k in 6:
		var y := 0.3 + k * fh
		_lathe("glass_blue", sc + Vector3(0, y, 0), [Vector2(1.9, 0), Vector2(1.9, fh - 0.4)], 20, Vector3.ZERO, Vector3.ONE, 0.0, false)
		_lathe("warm_white", sc + Vector3(0, y + fh - 0.4, 0), [Vector2(1.96, 0), Vector2(1.96, 0.4)], 20, Vector3.ZERO, Vector3.ONE, 0.0, false)
	for k in 10:
		var a := TAU * k / 10.0
		_beam("chrome", sc + Vector3(cos(a) * 1.92, 0.3, sin(a) * 1.92), sc + Vector3(cos(a) * 1.92, top + fh - 0.4, sin(a) * 1.92), 0.06)
	_lathe("warm_white", sc + Vector3(0, top + fh - 0.4, 0), [Vector2(2.2, 0), Vector2(2.2, 0.3), Vector2(0, 0.3)], 20)
	_flagpole(sc + Vector3(0, top + fh - 0.1, 0), 3.5, "flag_mission", 1.6, 1.0)
	_push(_xf(Vector3(0, 0, d * 0.5)))
	_box("night_blue", Vector3(1.2, 1.2, 0.06), Vector3(1.4, 2.4, 0.06))
	_boomerang(Vector3(1.2, 2.9, 0.9), 3.6, 1.8, "warm_white", "signal_orange")
	_pop()
	_flat_roof(w, d, top, "vents,tank,aerial")


## C: a six-storey tower block on a concrete frame, its bays filled with windows over enamel
## panels in turquoise, mustard, coral, mint and sky; the town's sign on the roof, the
## open hand in a ring.
func _apt_tower() -> void:
	var w := 9.0
	var fh := 3.0
	var floors := 6
	var top := 0.3 + floors * fh
	_box("concrete_flat", Vector3(0, 0.15, 0), Vector3(w + 0.4, 0.3, w + 0.4))
	_box("warm_white", Vector3(0, 0.3 + top * 0.5 - 0.15, 0), Vector3(w - 0.2, top - 0.3, w - 0.2))
	for side in ["front", "back", "left", "right"]:
		_on_face(w, w, side, func() -> void:
			for k in floors:
				var y := 0.3 + k * fh
				for b in 3:
					var cx := -3.0 + b * 3.0
					if k == 0:
						if side == "front" and b == 1:
							_box("night_blue", Vector3(cx, 1.25, 0.0), Vector3(1.6, 2.4, 0.08))
							_box("glass_blue", Vector3(cx, 1.4, 0.05), Vector3(1.3, 2.0, 0.02))
						else:
							_windows(cx - 1.3, cx + 1.3, 0.8, 1.9, 1, "steel_dark", 0.2)
						continue
					var pm: String = ENAMELS[(k * 2 + b + side.length()) % ENAMELS.size()]
					_box(pm, Vector3(cx, y + 0.5, 0.01), Vector3(2.7, 0.9, 0.06))
					_windows(cx - 1.35, cx + 1.35, y + 1.0, 1.6, 1, "warm_white", 0.15)
			# the concrete frame: columns and floor beams standing proud
			for b in 4:
				_box("concrete", Vector3(-4.5 + b * 3.0, top * 0.5, 0.12), Vector3(0.36, top, 0.3))
			for k in floors + 1:
				_box("concrete", Vector3(0, 0.3 + k * fh, 0.12), Vector3(w + 0.36, 0.3, 0.3)))
	_flat_roof(w, w, top, "vents,tank")
	# the roof sign: a ring with the open hand, on a steel frame facing the street
	var sy := top + 0.8
	for sx in [-1.2, 1.2]:
		_ibeam("steel_dark", Vector3(sx, top, 1.2), Vector3(sx, sy + 3.2, 1.2), 0.2)
	_push(_xf(Vector3(0, sy + 2.2, 1.35)))
	_lathe("warm_white", Vector3.ZERO, [Vector2(2.0, 0), Vector2(2.0, 0.14), Vector2(0, 0.14)], 24, Vector3(90, 0, 0))
	_lathe("signal_orange", Vector3(0, 0, 0.14), [Vector2(2.0, 0), Vector2(2.0, 0.04), Vector2(1.75, 0.04), Vector2(1.75, 0)], 24, Vector3(90, 0, 0), Vector3.ONE, 0.0, false)
	_hand_badge(Vector3(0, -0.2, 0.14), 1.7)
	for k in 12:   # bulbs round the ring that light up at night
		var a := TAU * k / 12.0
		var p := Vector3(cos(a) * 1.87, sin(a) * 1.87, 0.2)
		_ball("chrome", p, 0.07, 5, 3)
		_night.append([_t * (p + Vector3(-0.08, -0.08, 0.06)), _t * (p + Vector3(0.08, -0.08, 0.06)), _t * (p + Vector3(0.08, 0.08, 0.06)),
			_t * (p + Vector3(-0.08, 0.08, 0.06)), _t.basis * Vector3.BACK])
	_pop()


# ================================================================== the powerhouse (Era 4 milestone 1)
# "The valley lights up at night": a brick turbine hall with tall steel windows between
# warm-white pilasters, a taller boiler house behind it with two banded stacks, a coal
# bunker and its conveyor, and a switchyard of steel gantries and insulators. Smoke rises
# from the stacks (Smoke1/Smoke2, emitting; gameplay can thin it when filters are fitted).

func _powerhouse() -> void:
	_begin("powerhouse")
	_power_body(true)
	_save("powerhouse")
	_begin("powerhouse_plot")
	_plot4(26.0, 18.0)
	_save("powerhouse_plot")
	_begin("powerhouse_frame")
	_push(_xf(Vector3(-3.0, 0, 0)))
	_frame4(20.0, 18.0, 4, 3.6, 2, true)
	_pop()
	_smokestack_frame(Vector3(-10.0, 0, -5.5), 1.5, 9.0)
	_save("powerhouse_frame")


func _power_body(done: bool) -> void:
	var hx := -3.0
	var hw := 20.0
	# turbine hall: z -1..9
	var hc := Vector3(hx, 0, 4.0)
	_box("concrete_flat", hc + Vector3(0, 0.2, 0), Vector3(hw + 0.4, 0.4, 10.4))
	_box("brick", hc + Vector3(0, 5.6, 0), Vector3(hw, 10.4, 10.0))
	_push(_xf(hc))
	_on_face(hw, 10.0, "front", func() -> void:
		for i in 6:
			var x := -hw * 0.5 + 1.4 + i * (hw - 2.8) / 5.0
			_box("warm_white", Vector3(x, 5.6, 0.12), Vector3(0.8, 10.4, 0.24))
			if i < 5:
				var cx := x + (hw - 2.8) / 10.0
				_windows(cx - 1.25, cx + 1.25, 1.6, 7.4, 1, "steel_dark", 0.2, 0.9)
				for k in 5:
					_box("steel_dark", Vector3(cx, 2.8 + k * 1.3, 0.05), Vector3(2.4, 0.06, 0.06))
		_box("warm_white", Vector3(0, 10.4, 0.15), Vector3(hw + 0.3, 1.0, 0.3))
		# the emblem: a lightning bolt in a ring over the door
		_push(_xf(Vector3(0, 8.6, 0.3)))
		_lathe("warm_white", Vector3.ZERO, [Vector2(1.3, 0), Vector2(1.3, 0.12), Vector2(0, 0.12)], 20, Vector3(90, 0, 0))
		_lathe("signal_orange", Vector3(0, 0, 0.12), [Vector2(1.3, 0), Vector2(1.3, 0.04), Vector2(1.12, 0.04), Vector2(1.12, 0)], 20, Vector3(90, 0, 0), Vector3.ONE, 0.0, false)
		_plate("signal_orange", [Vector2(0.25, 0.85), Vector2(-0.35, -0.05), Vector2(0.0, -0.05)], 0.16, 0.06)
		_plate("signal_orange", [Vector2(0.0, 0.1), Vector2(0.35, 0.1), Vector2(-0.25, -0.85)], 0.16, 0.06)
		_pop()
		_box("night_blue", Vector3(0, 1.6, 0.08), Vector3(3.0, 3.2, 0.1))
		_boomerang(Vector3(0, 3.6, 1.0), 4.4, 2.0, "warm_white", "signal_orange"))
	_on_face(hw, 10.0, "right", func() -> void:
		_windows(-3.5, 3.5, 2.0, 6.5, 2, "steel_dark", 0.4, 0.9))
	_on_face(hw, 10.0, "left", func() -> void:
		_windows(-3.5, 3.5, 2.0, 6.5, 2, "steel_dark", 0.4, 0.9))
	# a long roof lantern
	_box("concrete_dark", Vector3(0, 10.85, 0), Vector3(hw - 0.4, 0.1, 9.6))
	_box("glass_blue", Vector3(0, 11.5, 0), Vector3(hw - 4.0, 1.2, 2.4))
	_box("steel_dark", Vector3(0, 12.15, 0), Vector3(hw - 3.6, 0.12, 2.8))
	_pop()
	# boiler house behind: z -9..-1, taller
	var bc := Vector3(hx, 0, -5.0)
	_box("brick", bc + Vector3(0, 7.5, 0), Vector3(hw - 2.0, 15.0, 8.0))
	_box("warm_white", bc + Vector3(0, 15.1, 0), Vector3(hw - 1.8, 0.4, 8.2))
	_push(_xf(bc))
	for side in ["left", "right", "back"]:
		_on_face(hw - 2.0, 8.0, side, func() -> void:
			for k in 2:
				_ribbon(-2.6 if side != "back" else -7.0, 2.6 if side != "back" else 7.0, 4.0 + k * 5.0, 2.4, 1.3, "steel_dark", 0.6))
	_pop()
	# the two stacks, banded orange and white, with aviation lamps
	for sx in [-7.0, 7.0]:
		_smokestack(bc + Vector3(sx, 15.0, 0), 1.3, 1.0, 9.0, "brick")
		_box("brick", bc + Vector3(sx, 15.2, 0), Vector3(3.0, 0.4, 3.0))
	if done:
		var i := 1
		for sx in [-7.0, 7.0]:
			_puffs("Smoke%d" % i, bc + Vector3(sx, 24.2, 0), Vector3(0.3, 1, 0), "smoke", 14, 6.0, 2.6, 1.2, 10.0)
			i += 1
	# coal bunker and the conveyor up to the boiler house roof
	var bk := Vector3(10.5, 0, -7.5)
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_ibeam("steel_dark", bk + Vector3(c.x * 1.4, 0, c.y * 1.4), bk + Vector3(c.x * 1.4, 4.0, c.y * 1.4), 0.24)
	_lathe("steel", bk + Vector3(0, 2.6, 0), [Vector2(0.4, 0), Vector2(1.8, 1.6), Vector2(1.8, 4.4), Vector2(0, 4.4)], 4, Vector3(0, 45, 0))
	_truss("steel", bk + Vector3(-1.5, 6.6, 0.0), bc + Vector3(hw * 0.5 - 1.0 - hx, 14.0, -1.0), 1.0, Vector3.UP, 0.12)
	_box("steel", (bk + Vector3(-1.5, 7.2, 0.0) + bc + Vector3(hw * 0.5 - 1.0 - hx, 14.6, -1.0)) * 0.5, Vector3(0.1, 0.1, 0.1))
	_coal_heap(bk + Vector3(1.6, 0, 3.0), 1.4)
	# switchyard: steel gantries, insulators and transformers on the east side
	var sy := Vector3(10.5, 0, 4.0)
	_box("concrete_dark", sy + Vector3(0, 0.05, 0), Vector3(5.0, 0.1, 9.0))
	for z in [-3.0, 0.0, 3.0]:
		_box("steel_dark", sy + Vector3(-0.6, 0.9, z), Vector3(1.6, 1.8, 1.2))
		for k in 4:
			_box("steel", sy + Vector3(-0.6, 0.3 + k * 0.38, z + 0.62), Vector3(1.4, 0.24, 0.06))
		for b in 3:
			_insulator(sy + Vector3(-1.1 + b * 0.5, 1.8, z))
	for x in [-2.2, 2.2]:
		_lattice_tower(sy + Vector3(x, 0.1, -4.0), 0.6, 7.0, "steel", 1.4, 0.1)
		_lattice_tower(sy + Vector3(x, 0.1, 4.0), 0.6, 7.0, "steel", 1.4, 0.1)
	for z in [-4.0, 4.0]:
		_truss("steel", sy + Vector3(-2.2, 6.4, z), sy + Vector3(2.2, 6.4, z), 0.6, Vector3.UP, 0.08)
	for k in 3:
		_rod("steel_dark", sy + Vector3(-1.2 + k * 1.2, 6.3, -4.0), sy + Vector3(-1.2 + k * 1.2, 6.0, 4.0), 0.025, 3)
		_insulator(sy + Vector3(-1.2 + k * 1.2, 5.6, -4.0))
		_insulator(sy + Vector3(-1.2 + k * 1.2, 5.6, 4.0))


## Ceramic insulator stack (cream discs on a steel pin).
func _insulator(p: Vector3) -> void:
	_rod("steel_dark", p, p + Vector3(0, 0.8, 0), 0.03, 4)
	for k in 4:
		_cyl("warm_white", p + Vector3(0, 0.12 + k * 0.17, 0), 0.14, 0.1, 0.08, 8)


## A stack still going up inside its scaffold cage.
func _smokestack_frame(p: Vector3, r: float, h: float) -> void:
	_lathe("brick", p, [Vector2(r, 0), Vector2(r * 0.94, h)], 12, Vector3.ZERO, Vector3.ONE, 0.0, false)
	for k in 6:
		var a := TAU * k / 6.0
		_rod("wood", p + Vector3(cos(a), 0, sin(a)) * (r + 0.7), p + Vector3(cos(a), 0, sin(a)) * (r + 0.7) + Vector3(0, h + 2.0, 0), 0.06, 4)
	for y in [h * 0.5, h]:
		_lathe("planks", p + Vector3(0, y, 0), [Vector2(r + 0.9, 0), Vector2(r + 0.9, 0.06), Vector2(r + 0.1, 0.06), Vector2(r + 0.1, 0)], 12)


## A heap of coal lumps.
func _coal_heap(c: Vector3, s: float) -> void:
	_lathe("coal", c, [Vector2(1.6 * s, 0), Vector2(1.1 * s, 0.5 * s), Vector2(0.4 * s, 0.95 * s), Vector2(0, 1.05 * s)], 9)
	for i in 16:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * 1.5 * s
		_ball("coal", c + Vector3(cos(a) * d, (1.0 - d / (1.6 * s)) * 1.0 * s, sin(a) * d), _rng.randf_range(0.12, 0.22) * s, 4, 2,
			Vector3(1, 0.8, 1), Vector3(_rng.randf() * 40, _rng.randf() * 90, 0))


# ================================================================== the coal mine

func _coal_mine() -> void:
	_begin("coal_mine")
	_mine_body(true)
	_save("coal_mine")
	_begin("coal_mine_plot")
	_plot4(14.0, 12.0)
	_save("coal_mine_plot")
	_begin("coal_mine_frame")
	_mine_body(false)
	_save("coal_mine_frame")


## The pit head: a steel headframe over the shaft with two winding wheels (Wheels, turning
## while the cage runs), the brick winding house its ropes run to, the screening shed on
## legs with a chute, a coal heap and a tub on a short track.
func _mine_body(done: bool) -> void:
	var sh := Vector3(-2.0, 0, 1.0)
	_box("concrete", sh + Vector3(0, 0.3, 0), Vector3(4.4, 0.6, 4.4))
	_box("cave_dark", sh + Vector3(0, 0.61, 0), Vector3(2.4, 0.01, 2.4))
	var h := 14.0 if done else 7.0
	_lattice_tower(sh + Vector3(0, 0.6, 0), 3.0, h - 0.6, "signal_orange", 2.2, 0.26)
	if done:
		# back legs raking to the winding house, the wheel platform and the two wheels
		for sx in [-1.2, 1.2]:
			_ibeam("signal_orange", sh + Vector3(sx, 0.6, -6.0), sh + Vector3(sx * 0.8, h - 0.6, -1.0), 0.36)
		_box("steel_dark", sh + Vector3(0, h + 0.05, 0), Vector3(3.6, 0.14, 3.6))
		var wheels := _part("Wheels", sh + Vector3(0, h + 1.6, 0), func() -> void:
			for sx in [-0.7, 0.7]:
				_wheel4(Vector3(sx, 0, 0), 1.4)
			_rod("steel_dark", Vector3(-1.1, 0, 0), Vector3(1.1, 0, 0), 0.1, 6))
		wheels.set_script(SPINNER)
		wheels.set("speed", 1.6)
		wheels.set("axis", Vector3.RIGHT)
		for sx in [-0.85, 0.55]:
			_box("steel", sh + Vector3(sx, h + 0.8, 0), Vector3(0.12, 1.6, 0.3))
			_rod("steel_dark", sh + Vector3(sx + 0.15, h + 1.6 + 1.35, -0.3), sh + Vector3(sx * 0.6, 3.6, -8.4), 0.025, 3)
			_rod("steel_dark", sh + Vector3(sx + 0.15, h + 1.6, 1.35), sh + Vector3(sx + 0.15, 1.6, 1.35), 0.025, 3)
		_box("warm_white", sh + Vector3(0, 1.6, 0.9), Vector3(1.4, 2.0, 1.2))   # the cage
		_box("night_blue", sh + Vector3(0, 2.66, 0.9), Vector3(1.5, 0.12, 1.3))
		_ball("signal_lamp", sh + Vector3(0, h + 3.2, 0), 0.12, 5, 3)
	# winding house
	var wh := Vector3(-2.0, 0, -8.0)
	_box("brick", wh + Vector3(0, 2.6, 0), Vector3(6.0, 5.2, 5.0))
	_box("warm_white", wh + Vector3(0, 5.25, 0), Vector3(6.2, 0.2, 5.2))
	_roof3("slate", 6.0, 5.0, 5.2, 1.6, 0.3, 0.0, "brick", 0)
	_push(_xf(wh))
	_on_face(6.0, 5.0, "front", func() -> void:
		_windows(-2.6, 2.6, 1.6, 2.4, 3, "warm_white", 0.4, 0.8))
	_on_face(6.0, 5.0, "right", func() -> void:
		_box("night_blue", Vector3(0, 1.2, 0.05), Vector3(1.3, 2.4, 0.1)))
	_pop()
	_smokestack(wh + Vector3(2.2, 0, -2.0), 0.6, 0.45, 9.0, "brick")
	# screening shed on legs with its chute, a coal heap under it
	var ss := Vector3(4.8, 0, 1.0)
	if done:
		for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_ibeam("steel_dark", ss + Vector3(c.x * 1.6, 0, c.y * 1.6), ss + Vector3(c.x * 1.6, 4.0, c.y * 1.6), 0.24)
		_box("enamel_mustard", ss + Vector3(0, 5.2, 0), Vector3(3.8, 2.4, 3.8))
		_roof3("slate", 3.8, 3.8, 6.4, 1.0, 0.3, 0.0, "enamel_mustard", 90)
		_box("steel", ss + Vector3(0, 3.8, 0), Vector3(1.4, 0.4, 1.4))
		_slab("steel", [Vector3(0.6, 3.7, 0.5), Vector3(0.6, 3.7, -0.5), Vector3(2.4, 2.0, -0.5), Vector3(2.4, 2.0, 0.5)].map(func(v: Vector3) -> Vector3: return v + ss), 0.06, Vector3(0.6, 1, 0))
		_truss("steel", sh + Vector3(1.6, 3.0, 0), ss + Vector3(-1.9, 5.0, 0), 0.8, Vector3.UP, 0.1)
		_coal_heap(ss + Vector3(2.6, 0, 0.6), 1.2)
		_coal_heap(ss + Vector3(0.6, 0, 3.4), 0.8)
	# a tub on a short track
	for x in [-0.36, 0.36]:
		_beam("steel", Vector3(x, 0.08, 3.8), Vector3(x, 0.08, 7.4), 0.08)
	for k in 7:
		_box("wood_dark", Vector3(0, 0.03, 4.0 + k * 0.55), Vector3(1.1, 0.06, 0.2))
	_mine_tub(Vector3(0, 0.12, 6.0), done)


func _mine_tub(p: Vector3, full: bool) -> void:
	_lathe("signal_orange", p + Vector3(0, 0.25, 0), [Vector2(0.45, 0), Vector2(0.62, 0.55), Vector2(0.58, 0.55), Vector2(0.4, 0.02)], 4, Vector3(0, 45, 0), Vector3(1.0, 1, 1.5), 0.0, false)
	_box("steel_dark", p + Vector3(0, 0.25, 0), Vector3(0.62, 0.06, 0.9))
	for z in [-0.35, 0.35]:
		for x in [-0.36, 0.36]:
			_cyl("steel_dark", p + Vector3(x, 0.12, z), 0.12, 0.12, 0.06, 8, Vector3(0, 0, 90))
	if full:
		_ball("coal", p + Vector3(0, 0.78, 0), 0.5, 6, 3, Vector3(0.95, 0.4, 1.35))


## A spoked winding wheel in the local YZ plane (axle along X) at c.
func _wheel4(c: Vector3, r: float) -> void:
	_push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), c))
	_lathe("signal_orange", Vector3(0, -0.06, 0), [Vector2(r, 0), Vector2(r, 0.12), Vector2(r - 0.12, 0.12), Vector2(r - 0.12, 0.0)], 16)
	_cyl("steel_dark", Vector3(0, -0.12, 0), 0.16, 0.16, 0.24, 8)
	for k in 8:
		var a := TAU * k / 8.0
		_beam("signal_orange", Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * (r - 0.08), 0.06)
	_pop()


# ================================================================== the foundry (steel)

func _foundry() -> void:
	_begin("foundry")
	_foundry_body(true)
	_save("foundry")
	_begin("foundry_plot")
	_plot4(22.0, 14.0)
	_save("foundry_plot")
	_begin("foundry_frame")
	_push(_xf(Vector3(-3.0, 0, 0)))
	_frame4(15.0, 12.0, 3, 4.0, 2, true)
	_pop()
	_save("foundry_frame")


## The steelworks: a tall steel-clad casting shed with a glazed monitor roof, its open
## front glowing with the converter and a pouring ladle; beside it the blast furnace with
## its bustle pipe and downcomers, three hot-blast stoves and the skip incline; a stack.
func _foundry_body(done: bool) -> void:
	var sc := Vector3(-3.0, 0, 0)
	var w := 15.0
	var d := 12.0
	var h := 10.0
	_box("concrete_flat", sc + Vector3(0, 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3))
	for side in [-1.0, 1.0]:
		_box("steel", sc + Vector3(side * (w * 0.5 - 0.15), h * 0.5, 0), Vector3(0.3, h, d))
	_box("steel", sc + Vector3(0, h * 0.5, -d * 0.5 + 0.15), Vector3(w, h, 0.3))
	_box("cave_dark", sc + Vector3(0, h * 0.5, -d * 0.5 + 0.32), Vector3(w - 0.6, h - 0.2, 0.05))   # the shadowed interior
	for side in [-1.0, 1.0]:
		_box("steel_dark", sc + Vector3(side * (w * 0.5 - 0.32), h * 0.5, 0), Vector3(0.05, h - 0.2, d - 0.6))
	_box("concrete_dark", sc + Vector3(0, 0.31, 0), Vector3(w - 0.6, 0.02, d - 0.4))
	_box("steel_dark", sc + Vector3(0, h - 0.12, 0), Vector3(w - 0.6, 0.05, d - 0.6))
	_box("steel", sc + Vector3(0, h - 1.5, d * 0.5 - 0.15), Vector3(w, 3.0, 0.3))
	for i in 11:   # vertical cladding ribs
		var x := -w * 0.5 + 0.7 + i * (w - 1.4) / 10.0
		for z in [d * 0.5 + 0.02, -d * 0.5 - 0.02]:
			_box("steel_dark", sc + Vector3(x, h * 0.5 if z < 0 else h - 1.5, z), Vector3(0.12, h if z < 0 else 3.0, 0.08))
	for side in [-1.0, 1.0]:
		_push(_xf(sc + Vector3(side * w * 0.5, 0, 0), 90.0 * side))
		_ribbon(-5.0, 5.0, h - 3.0, 1.8, 1.2, "steel_dark", 0.8)
		_pop()
	# roof with a glazed monitor along the ridge
	_box("steel_dark", sc + Vector3(0, h + 0.1, 0), Vector3(w + 0.4, 0.2, d + 0.4))
	_box("glass_blue", sc + Vector3(0, h + 0.9, 0), Vector3(w - 1.0, 1.4, 3.0))
	_box("steel_dark", sc + Vector3(0, h + 1.65, 0), Vector3(w - 0.6, 0.12, 3.6))
	# the glow inside: the converter tilted to pour, a ladle, sparks
	var cv := sc + Vector3(-2.0, 0, 1.0)
	_lathe("steel_dark", cv + Vector3(0, 2.6, 0), [Vector2(0.9, 0), Vector2(1.6, 0.8), Vector2(1.6, 2.4), Vector2(0.8, 3.2), Vector2(0.6, 3.2)], 12, Vector3(0, 0, -35))
	_cyl("steel_dark", cv + Vector3(0, 3.6, 0), 0.3, 0.3, 4.0, 8, Vector3(90, 0, 0))
	if done:
		_glow(cv + Vector3(1.95, 5.15, 0), 0.5, Vector3(1, 0.7, 0))
		_lathe("molten", cv + Vector3(2.6, 1.0, 0), [Vector2(0.02, 0), Vector2(0.12, 0.5), Vector2(0.06, 4.0)], 6)
		_lathe("steel_dark", cv + Vector3(3.0, 0.3, 0), [Vector2(0.7, 0), Vector2(1.1, 1.4), Vector2(1.0, 1.4), Vector2(0.6, 0.1)], 12, Vector3.ZERO, Vector3.ONE, 0.0, false)
		_lathe("molten", cv + Vector3(3.0, 1.55, 0), [Vector2(1.0, 0), Vector2(0, 0)], 12)
		_hidden_light("Glow", sc + Vector3(0, 3.0, 2.0), Color("#ff9a3c"), 3.0, 14.0)
		(_root.get_node("Glow") as Light3D).visible = true
	# an overhead crane girder across the open front
	_truss("signal_orange", sc + Vector3(-w * 0.5, h - 2.0, d * 0.5 - 1.0), sc + Vector3(w * 0.5, h - 2.0, d * 0.5 - 1.0), 0.8, Vector3.UP, 0.12)
	# blast furnace and stoves east of the shed
	var bf := Vector3(9.0, 0, -1.0)
	var bh := 15.0 if done else 7.0
	_box("concrete", bf + Vector3(0, 0.4, 0), Vector3(6.0, 0.8, 6.0))
	_lathe("brick", bf + Vector3(0, 0.8, 0), [Vector2(2.2, 0), Vector2(2.4, 3.0), Vector2(2.6, 5.0), Vector2(2.0, bh - 3.0), Vector2(1.4, bh - 0.8)], 14, Vector3.ZERO, Vector3.ONE, 0.0, false)
	for k in int((bh - 1.0) / 1.6):
		var y := 1.4 + k * 1.6
		_lathe("steel_dark", bf + Vector3(0, y, 0), [Vector2(2.3 + clampf((y - 2.0) * 0.1, 0.0, 0.3) - (maxf(0.0, y - 6.0) * 0.07), 0), Vector2(2.3 + clampf((y - 2.0) * 0.1, 0.0, 0.3) - (maxf(0.0, y - 6.0) * 0.07) + 0.04, 0.18)], 14, Vector3.ZERO, Vector3.ONE, 0.0, false)
	if done:
		_lathe("steel", bf + Vector3(0, bh - 0.8, 0), [Vector2(1.5, 0), Vector2(1.5, 1.2), Vector2(0.8, 2.0), Vector2(0, 2.0)], 12)
		_lathe("signal_orange", bf + Vector3(0, 4.6, 0), [Vector2(3.0, 0), Vector2(3.0, 0.5), Vector2(2.7, 0.5), Vector2(2.7, 0)], 14)   # bustle pipe
		for a in [0.8, 2.4, 4.0]:
			_rod("steel", bf + Vector3(cos(a) * 1.0, bh + 0.6, sin(a) * 1.0), bf + Vector3(cos(a) * 2.6, bh + 2.6, sin(a) * 2.6), 0.28, 6)
		_rod("steel", bf + Vector3(1.6, bh + 2.6, -1.4), bf + Vector3(4.2, 3.0, -3.8), 0.4, 8)
		for k in 3:
			var st := bf + Vector3(-1.5 + k * 2.2, 0, -5.4)
			_lathe("steel", st, [Vector2(1.0, 0), Vector2(1.0, 10.0), Vector2(0.5, 10.8), Vector2(0, 11.0)], 12)
			_lathe("signal_orange", st + Vector3(0, 8.4, 0), [Vector2(1.03, 0), Vector2(1.03, 0.5)], 12, Vector3.ZERO, Vector3.ONE, 0.0, false)
			_rod("steel", st + Vector3(0, 4.0, 0.9), bf + Vector3(0, 4.8, -2.8), 0.24, 6)
		_truss("steel", bf + Vector3(1.0, 0.8, 6.0), bf + Vector3(0.6, bh, 1.4), 0.9, Vector3(0, 0.3, -1).normalized(), 0.12)   # skip incline
		_smokestack(bf + Vector3(3.6, 0, 3.6), 0.8, 0.6, 18.0, "brick")
		_puffs("Smoke", bf + Vector3(3.6, 18.2, 3.6), Vector3(0.3, 1, 0), "smoke", 12, 6.0, 2.4, 1.1, 10.0)
	_box("night_blue", sc + Vector3(w * 0.5 + 0.02, 1.2, 3.5), Vector3(0.1, 2.4, 1.3))


# ================================================================== the refinery (chemistry: rocket fuel)

func _refinery() -> void:
	_begin("refinery")
	_refinery_body(true)
	_save("refinery")
	_begin("refinery_plot")
	_plot4(20.0, 16.0)
	_save("refinery_plot")
	_begin("refinery_frame")
	_refinery_body(false)
	_save("refinery_frame")


## Two distillation columns with ringed platforms and caged ladders, white fuel spheres on
## legs banded in signal orange, round storage tanks, a pipe rack joining them, a control
## house and the flare stack burning at the top.
func _refinery_body(done: bool) -> void:
	_box("concrete_dark", Vector3(0, 0.05, 0), Vector3(20.0, 0.1, 16.0))
	for spec in [[Vector3(-6.0, 0, -3.0), 0.95, 17.0], [Vector3(-3.4, 0, -4.2), 0.7, 13.0]]:
		var p: Vector3 = spec[0]
		var r: float = spec[1]
		var h: float = spec[2] if done else spec[2] * 0.45
		_box("concrete", p + Vector3(0, 0.3, 0), Vector3(r * 2.6, 0.6, r * 2.6))
		_lathe("warm_white", p + Vector3(0, 0.6, 0), [Vector2(r, 0), Vector2(r, h), Vector2(r * 0.6, h + r * 0.5), Vector2(0, h + r * 0.6)], 14)
		var k := 0
		var y := 3.0
		while y < h:
			_lathe("signal_orange", p + Vector3(0, y + 0.6, 0), [Vector2(r + 0.9, 0), Vector2(r + 0.9, 0.08), Vector2(r, 0.08), Vector2(r, 0)], 14)
			_lathe("steel", p + Vector3(0, y + 1.6, 0), [Vector2(r + 0.88, 0), Vector2(r + 0.88, 0.05)], 14, Vector3.ZERO, Vector3.ONE, 0.0, false)
			y += 3.6
			k += 1
		_ladder4(p + Vector3(0, 0.6, r + 0.12), p + Vector3(0, h + 0.6, r + 0.12))
		if not done:
			_tower_crane(p + Vector3(-3.0, 0, 3.0), 16.0, 10.0, 60.0)
	# fuel spheres
	for spec in [[Vector3(3.6, 0, -4.0), 2.4], [Vector3(8.4, 0, -4.4), 2.0]]:
		var p: Vector3 = spec[0]
		var r: float = spec[1]
		if not done:
			_box("concrete", p + Vector3(0, 0.15, 0), Vector3(r * 2.2, 0.3, r * 2.2))
			continue
		for k in 6:
			var a := TAU * k / 6.0
			_ibeam("steel", p + Vector3(cos(a) * r * 0.95, 0, sin(a) * r * 0.95), p + Vector3(cos(a) * r * 0.98, r + 1.2, sin(a) * r * 0.98), 0.22)
		_ball("warm_white", p + Vector3(0, r + 1.4, 0), r, 18, 10)
		_lathe("signal_orange", p + Vector3(0, r + 1.25, 0), [Vector2(r + 0.03, 0), Vector2(r + 0.03, 0.3)], 18, Vector3.ZERO, Vector3.ONE, 0.0, false)
		_wrap(r, 0.0, func() -> void: _hand_badge(Vector3(0, r + 1.9, 0), r * 0.42, "signal_orange", ""))
		_ladder4(p + Vector3(r * 0.4, 0, r + 0.2), p + Vector3(r * 0.3, r * 2.0 + 1.0, 0.4))
	# storage tanks (Kenney City Kit), a control house
	if done:
		_model(IND + "detail-tank-large.glb", Vector3(6.0, 0.1, 4.0), Vector3(0, 30, 0), 3.0, null, KIND)
		_model(IND + "detail-tank.glb", Vector3(1.6, 0.1, 5.0), Vector3(0, -60, 0), 3.0, null, KIND)
	_box("warm_white", Vector3(-6.0, 1.6, 5.0), Vector3(6.0, 3.2, 4.0))
	_box("signal_orange", Vector3(-6.0, 3.3, 5.0), Vector3(6.3, 0.2, 4.3))
	_push(_xf(Vector3(-6.0, 0, 7.0)))
	_ribbon(-2.6, 1.2, 1.2, 1.4, 1.2, "steel_dark", 0.8)
	_box("night_blue", Vector3(2.0, 1.1, 0.05), Vector3(1.1, 2.2, 0.1))
	_pop()
	# the pipe rack
	for x in [-4.0, -1.0, 2.0, 5.0]:
		_ibeam("steel_dark", Vector3(x, 0.1, 0.0), Vector3(x, 4.0, 0.0), 0.24)
		_beam("steel_dark", Vector3(x, 4.0, -0.8), Vector3(x, 4.0, 0.8), 0.18)
	for k in 4:
		var z := -0.6 + k * 0.4
		_rod(["steel", "signal_orange", "warm_white", "enamel_mustard"][k], Vector3(-6.0, 4.3, z), Vector3(8.0, 4.3, z), 0.14, 6)
	if done:
		_rod("steel", Vector3(-6.0, 4.3, -0.6), Vector3(-6.0, 4.3, -2.0), 0.14, 6)
		_rod("signal_orange", Vector3(8.0, 4.3, -0.2), Vector3(8.4, 4.3, -2.4), 0.14, 6)
		# the flare stack and its flame
		var fl := Vector3(8.6, 0, 5.6)
		_lattice_tower(fl + Vector3(0, 0, 0), 1.0, 14.0, "steel", 1.6, 0.12)
		_rod("steel_dark", fl + Vector3(0, 0, 0), fl + Vector3(0, 15.0, 0), 0.22, 8)
		_cyl("signal_orange", fl + Vector3(0, 14.6, 0), 0.3, 0.3, 0.5, 8)
		_flames_node(_root, fl + Vector3(0, 15.1, 0), 2.2, true)


## A caged steel ladder from foot to top.
func _ladder4(foot: Vector3, top: Vector3) -> void:
	var side := (top - foot).cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized() * 0.25
	_beam("steel", foot + side, top + side, 0.05)
	_beam("steel", foot - side, top - side, 0.05)
	var n := int((top - foot).length() / 0.6)
	for i in range(1, n):
		var p := foot.lerp(top, float(i) / n)
		_beam("steel", p + side, p - side, 0.03)


# ================================================================== the factory and the assembly hall

func _factory() -> void:
	_begin("factory")
	_factory_body()
	_save("factory")
	_begin("factory_plot")
	_plot4(18.0, 14.0)
	_save("factory_plot")
	_begin("factory_frame")
	_frame4(18.0, 14.0, 2, 3.4, 2, false)
	_save("factory_frame")


## The parts works: a brick shed under a north-light sawtooth roof, an office block of
## warm white with ribbon windows on the front corner, two orange roller doors at the
## loading dock, a stack, and the day's crates waiting.
func _factory_body() -> void:
	var w := 18.0
	var d := 14.0
	var h := 6.0
	_box("concrete_flat", Vector3(0, 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3))
	_box("brick", Vector3(0, 0.3 + h * 0.5, 0), Vector3(w, h, d))
	_box("warm_white", Vector3(0, 0.3 + h + 0.12, 0), Vector3(w + 0.2, 0.24, d + 0.2))
	# sawtooth roof: four teeth along z, glazing facing north (-Z)
	var teeth := 4
	var tz := d / teeth
	for t in teeth:
		var z0 := d * 0.5 - t * tz
		var z1 := z0 - tz
		var y0 := 0.3 + h + 0.24
		var y1 := y0 + 2.4
		_slab("slate", [Vector3(-w * 0.5, y0, z0), Vector3(w * 0.5, y0, z0), Vector3(w * 0.5, y1, z1), Vector3(-w * 0.5, y1, z1)], 0.12, Vector3(0, tz, 2.4))
		_box("glass_blue", Vector3(0, (y0 + y1) * 0.5, z1 + 0.05), Vector3(w - 0.2, 2.3, 0.06))
		for i in 13:
			_box("steel_dark", Vector3(-w * 0.5 + 0.1 + i * (w - 0.2) / 12.0, (y0 + y1) * 0.5, z1 + 0.09), Vector3(0.06, 2.3, 0.04))
		for sx in [-1.0, 1.0]:
			_tri("brick", Vector3(sx * w * 0.5, y0, z0), Vector3(sx * w * 0.5, y1, z1), Vector3(sx * w * 0.5, y0, z1), Vector3(sx, 0, 0))
	_on_face(w, d, "front", func() -> void:
		for sx in [-1.0, 1.0]:
			var x: float = sx * 3.0 + 1.5
			_box("signal_orange", Vector3(x, 0.3 + 1.9, 0.05), Vector3(3.6, 3.8, 0.1))
			for k in 12:
				_box("steel_dark", Vector3(x, 0.4 + k * 0.32, 0.11), Vector3(3.6, 0.03, 0.02))
		_box("concrete", Vector3(1.5, 0.6, 1.2), Vector3(11.0, 0.6, 2.2))
		_slab("warm_white", [Vector3(-4.5, 4.6, 0), Vector3(7.5, 4.6, 0), Vector3(7.5, 4.3, 2.6), Vector3(-4.5, 4.3, 2.6)], 0.14, Vector3(0, 1, 0.1))
		for x in [-4.0, 7.0]:
			_beam("steel", Vector3(x, 4.3, 2.4), Vector3(x, 4.6, 0.05), 0.08))
	for side in ["back", "left", "right"]:
		var span := w if side == "back" else d
		_on_face(w, d, side, func() -> void:
			_windows(-span * 0.5 + 1.0, span * 0.5 - 1.0, 2.2, 2.6, int(span / 3.0), "steel_dark", 0.5, 0.6))
	# the office block on the front-left corner
	var oc := Vector3(-w * 0.5 + 2.6, 0, d * 0.5 + 0.6)
	_box("warm_white", oc + Vector3(0, 0.3 + 3.5, 0), Vector3(5.2, 7.0, 3.6))
	_push(_xf(oc + Vector3(0, 0, 1.8)))
	_ribbon(-2.4, 2.4, 1.0, 1.6, 1.2, "chrome", 0.7)
	_ribbon(-2.4, 2.4, 4.4, 1.6, 1.2, "chrome", 0.7)
	_box("enamel_turquoise", Vector3(0, 3.3, 0.03), Vector3(5.2, 0.6, 0.06))
	_pop()
	_box("night_blue", oc + Vector3(0, 7.4, 0), Vector3(5.4, 0.3, 3.8))
	_smokestack(Vector3(w * 0.5 - 2.0, 0, -d * 0.5 - 1.2), 0.8, 0.6, 15.0, "brick")
	_puffs("Smoke", Vector3(w * 0.5 - 2.0, 15.2, -d * 0.5 - 1.2), Vector3(0.3, 1, 0), "smoke", 10, 6.0, 2.0, 1.0, 10.0)
	_parts_crates(Vector3(5.4, 0.9, d * 0.5 + 1.2), 0.0)
	_model(IND + "shipping-container-a.glb", Vector3(-w * 0.5 - 2.0, 0, -2.0), Vector3(0, 90, 0), 6.5, null, KIND)


## The vehicle assembly hall, where the rocket's segments are built (DESIGN 4: the factory
## builds rocket parts): a tall hall of board-marked concrete with ribs, the great striped
## door on the front, the open hand painted huge on the east wall, the mission patch over
## the door, an office annex of ribbon windows on the west side, flags out front.
func _assembly_hall() -> void:
	_begin("assembly_hall")
	_assembly_body(true)
	_save("assembly_hall")
	_begin("assembly_hall_plot")
	_plot4(16.0, 18.0)
	_save("assembly_hall_plot")
	_begin("assembly_hall_frame")
	_assembly_body(false)
	_save("assembly_hall_frame")


func _assembly_body(done: bool) -> void:
	var w := 16.0
	var d := 18.0
	var h := 19.0 if done else 9.0
	_box("concrete_flat", Vector3(0, 0.15, 0), Vector3(w + 0.4, 0.3, d + 0.4))
	if not done:
		_frame4(w, d, 3, 3.0, 3, true)
		return
	_box("concrete", Vector3(0, 0.3 + h * 0.5, 0), Vector3(w, h, d))
	for side in ["left", "right", "back"]:
		var span := d if side != "back" else w
		_on_face(w, d, side, func() -> void:
			var n := int(span / 2.0)
			for i in n + 1:
				_box("warm_white", Vector3(-span * 0.5 + span * i / n, 0.3 + h * 0.5, 0.12), Vector3(0.4, h, 0.24))
			_ribbon(-span * 0.5 + 0.4, span * 0.5 - 0.4, h - 2.6, 1.6, span / n, "steel_dark", 0.4))
	_on_face(w, d, "right", func() -> void:
		_hand_badge(Vector3(0, 8.6, 0.26), 7.0))
	_on_face(w, d, "front", func() -> void:
		# the great door: night-blue frame, striped leaves, an orange head band
		_box("night_blue", Vector3(0, 0.3 + 8.5, 0.1), Vector3(9.0, 17.0, 0.2))
		for k in 16:
			_box("warm_white" if k % 2 == 0 else "steel", Vector3(0, 0.6 + k * 1.0 + 0.5, 0.22), Vector3(8.2, 0.9, 0.06))
		_box("steel_dark", Vector3(0, 0.3 + 8.5, 0.26), Vector3(0.12, 16.6, 0.04))
		_box("signal_orange", Vector3(0, 0.3 + 17.4, 0.22), Vector3(9.0, 0.6, 0.1))
		for sx in [-1.0, 1.0]:
			_box("warm_white", Vector3(sx * 6.0, 0.3 + h * 0.5, 0.12), Vector3(0.6, h, 0.24))
		_face_disc("mission_patch", Vector3(0, 0.3 + h - 0.6, 0.3), 1.0, 24)
		_lathe("chrome", Vector3(0, 0.3 + h - 0.6, 0.26), [Vector2(1.1, 0), Vector2(1.1, 0.05), Vector2(1.0, 0.05)], 24, Vector3(90, 0, 0), Vector3.ONE, 0.0, false))
	_flat_roof(w, d, 0.3 + h, "vents", "warm_white")
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_ball("signal_lamp", Vector3(c.x * w * 0.5, 0.3 + h + 0.9, c.y * d * 0.5), 0.12, 5, 3)
	# the office annex on the west side
	var an := Vector3(-w * 0.5 - 2.6, 0, 3.0)
	_box("warm_white", an + Vector3(0, 0.3 + 4.8, 0), Vector3(5.2, 9.6, 10.0))
	_push(_xf(an + Vector3(-2.6, 0, 0), -90.0))
	for k in 3:
		_ribbon(-4.6, 4.6, 0.3 + k * 3.2 + 0.9, 1.6, 1.15, "chrome", 0.6)
		_box("enamel_turquoise", Vector3(0, 0.3 + k * 3.2 + 0.4, 0.03), Vector3(10.0, 0.4, 0.06))
	_pop()
	_push(_xf(an + Vector3(0, 0, 5.0)))
	_box("night_blue", Vector3(0, 1.2, 0.05), Vector3(1.4, 2.4, 0.1))
	_boomerang(Vector3(0, 2.9, 0.9), 3.6, 1.8)
	_pop()
	_box("night_blue", an + Vector3(0, 0.3 + 9.75, 0), Vector3(5.4, 0.3, 10.2))
	for x in [-3.0, 0.0, 3.0]:
		_flagpole(Vector3(x, 0, d * 0.5 + 3.0), 7.0)
	# rails run in through the door
	for x in [-0.72, 0.72]:
		_box("steel", Vector3(x, 0.36, d * 0.5 + 1.0), Vector3(0.1, 0.12, 2.0))


# ================================================================== science: institute, mission control, telescope, training

## A curtain-wall face from x0 to x1, y0 up h, facing local +Z at z = 0 (the texture is
## 4 bays x 2 storeys per 8 x 6 m).
func _curtain(x0: float, x1: float, y0: float, h: float, lit := 0.45) -> void:
	_quad("curtain_wall", Vector3(x0, y0, 0.02), Vector3(x1, y0, 0.02), Vector3(x1, y0 + h, 0.02), Vector3(x0, y0 + h, 0.02), Vector3.BACK,
		[Vector2(x0 / 8.0, -y0 / 6.0), Vector2(x1 / 8.0, -y0 / 6.0), Vector2(x1 / 8.0, -(y0 + h) / 6.0), Vector2(x0 / 8.0, -(y0 + h) / 6.0)])
	var bays := int((x1 - x0) / 2.0)
	var storeys := int(h / 3.0)
	for s in storeys:
		for b in bays:
			_night_pane(Vector3(x0 + 2.0 * (b + 0.5), y0 + s * 3.0 + 1.8, 0.0), 1.7, 2.0, lit)


## Curved curtain wall: an arc of radius r round c from angle a0 to a1 (0 = +Z), h tall.
func _curtain_arc(c: Vector3, r: float, a0: float, a1: float, h: float, seg := 12) -> void:
	for k in seg:
		var t0 := lerpf(a0, a1, float(k) / seg)
		var t1 := lerpf(a0, a1, float(k + 1) / seg)
		var p0 := c + Vector3(sin(t0), 0, cos(t0)) * r
		var p1 := c + Vector3(sin(t1), 0, cos(t1)) * r
		var u0 := r * t0 / 8.0
		var u1 := r * t1 / 8.0
		_quad("curtain_wall", p0, p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), (p0 + p1) * 0.5 - c,
			[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, -h / 6.0), Vector2(u0, -h / 6.0)])


func _institute() -> void:
	_begin("institute")
	_institute_body()
	_save("institute")
	_begin("institute_plot")
	_plot4(30.0, 14.0)
	_save("institute_plot")
	_begin("institute_frame")
	_push(_xf(Vector3(-5.0, 0, 0)))
	_frame4(22.0, 9.0, 3, 3.4, 2, true)
	_pop()
	_lathe("concrete", Vector3(11.0, 0, 0), [Vector2(5.6, 0), Vector2(5.6, 2.4), Vector2(5.2, 2.4), Vector2(5.2, 0.3)], 18, Vector3.ZERO, Vector3.ONE, 0.0, false)
	for k in 8:
		var a := TAU * k / 8.0
		_beam("steel", Vector3(11.0, 2.4, 0) + Vector3(cos(a), 0, sin(a)) * 5.3, Vector3(11.0, 6.2, 0) + Vector3(cos(a), 0, sin(a)) * 3.4, 0.14)
	_save("institute_frame")


## The university and science institute: a three-storey slab of curtain wall raised on
## pilotis over a glazed lobby, a mosaic of the open hand on its end wall, and beside it the
## white planetarium dome on a drum ringed with portholes; a boomerang canopy, the Era 3
## statue of the hand on the forecourt, three flags.
func _institute_body() -> void:
	var sc := Vector3(-5.0, 0, 0)
	var w := 22.0
	var d := 9.0
	_box("concrete_dark", Vector3(0, 0.05, 1.0), Vector3(34.0, 0.1, 15.0))
	_box("concrete_flat", sc + Vector3(0, 0.2, 0), Vector3(w + 0.4, 0.4, d + 0.4))
	# lobby: recessed glass under the slab, pilotis in a row
	_box("warm_white", sc + Vector3(0, 0.4 + 1.6, -0.8), Vector3(w - 4.0, 3.2, d - 3.0))
	_push(_xf(sc + Vector3(0, 0, d * 0.5 - 1.5)))
	_ribbon(-w * 0.5 + 2.0, w * 0.5 - 2.0, 0.5, 2.9, 1.8, "chrome", 0.8)
	_pop()
	for i in 8:
		var x := -w * 0.5 + 1.0 + i * (w - 2.0) / 7.0
		for z in [-d * 0.5 + 0.6, d * 0.5 - 0.6]:
			_lathe("concrete_flat", sc + Vector3(x, 0.4, z), [Vector2(0.28, 0), Vector2(0.22, 3.2)], 8)
	# the slab: three floors of curtain wall front and back, concrete end walls
	var y0 := 3.6
	var hh := 9.0
	_box("concrete_flat", sc + Vector3(0, y0 + hh * 0.5, 0), Vector3(w, hh, d))
	_on_face(w, d, "front", func() -> void: pass)
	_push(_xf(sc + Vector3(0, 0, d * 0.5)))
	_curtain(-w * 0.5 + 0.3, w * 0.5 - 0.3, y0, hh)
	_pop()
	_push(_xf(sc + Vector3(0, 0, -d * 0.5), 180.0))
	_curtain(-w * 0.5 + 0.3, w * 0.5 - 0.3, y0, hh)
	_pop()
	_box("warm_white", sc + Vector3(0, y0 + hh + 0.4, 0), Vector3(w + 0.4, 0.8, d + 0.4))
	_box("concrete_dark", sc + Vector3(0, y0, 0), Vector3(w + 0.3, 0.3, d + 0.3))
	for sx in [-1.0, 1.0]:   # end walls with the hand in mosaic on the west
		_box("concrete", sc + Vector3(sx * (w * 0.5 + 0.15), y0 + hh * 0.5, 0), Vector3(0.3, hh + 0.6, d + 0.3))
	_push(_xf(sc + Vector3(-w * 0.5 - 0.3, 0, 0), -90.0))
	_box("enamel_turquoise", Vector3(0, y0 + hh * 0.5, 0.0), Vector3(6.4, 7.6, 0.06))
	_hand_badge(Vector3(0, y0 + hh * 0.5 - 0.4, 0.04), 4.2, "enamel_mustard", "warm_white")
	_pop()
	_flat_roof(w, d, y0 + hh + 0.8, "vents,aerial", "warm_white")
	# entrance canopy and steps, the statue of the hand, flags
	_boomerang(sc + Vector3(0, 3.4, d * 0.5 + 1.6), 7.0, 3.0)
	for i in 3:
		_box("concrete_flat", sc + Vector3(0, 0.06 + i * 0.1, d * 0.5 + 3.4 - i * 0.4), Vector3(7.0, 0.12, 0.5))
	_model("res://scenes/props/era3/statue_hand.scn", Vector3(-1.0, 0.1, 6.8), Vector3(0, 10, 0), 1.0)
	for x in [-12.0, -9.0]:
		_flagpole(Vector3(x, 0.1, 6.8), 7.0)
	_flagpole(Vector3(4.6, 0.1, 6.8), 7.0, "flag_hand")
	# the planetarium: a drum with portholes under a white dome, a copper spire with a star
	var pc := Vector3(11.0, 0.1, 0.0)
	_lathe("warm_white", pc, [Vector2(5.6, 0), Vector2(5.6, 3.6), Vector2(0, 3.6)], 24)
	_lathe("night_blue", pc + Vector3(0, 3.2, 0), [Vector2(5.64, 0), Vector2(5.64, 0.4)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
	for k in 10:
		var a := TAU * k / 10.0 + 0.3
		_wrap(5.6, a, func() -> void: _porthole(Vector3(0, 1.9, 0), 0.45, "glass_blue"))
	var dome := []
	for j in 9:
		var t := j / 8.0 * PI * 0.5
		dome.append(Vector2(5.3 * cos(t), 3.6 + 4.6 * sin(t)))
	_lathe("dish_white", pc, dome, 24)
	for k in 12:
		var a := TAU * k / 12.0
		var prof := []
		for j in 9:
			var t := j / 8.0 * PI * 0.5
			prof.append(pc + Vector3(cos(a) * 5.32 * cos(t), 3.6 + 4.62 * sin(t), sin(a) * 5.32 * cos(t)))
		for j in 8:
			_beam("steel", prof[j], prof[j + 1], 0.06)
	_rod("chrome", pc + Vector3(0, 8.1, 0), pc + Vector3(0, 9.6, 0), 0.06, 6)
	_ball("enamel_mustard", pc + Vector3(0, 9.7, 0), 0.2, 8, 4)
	_push(_xf(pc + Vector3(0, 0, 5.6)))
	_box("night_blue", Vector3(0, 1.2, 0.02), Vector3(1.6, 2.4, 0.1))
	_pop()


func _mission_control() -> void:
	_begin("mission_control")
	_mission_body()
	_save("mission_control")
	_begin("mission_control_plot")
	_plot4(20.0, 14.0)
	_save("mission_control_plot")
	_begin("mission_control_frame")
	_frame4(20.0, 12.0, 2, 3.4, 2, false)
	_save("mission_control_frame")


## Mission control: a low two-storey block of board-marked concrete with ribbon windows,
## the curved glass control room bulging from the front, the mission patch over it, a
## rooftop of dishes (Kenney Space Kit) and the turning radar (Radar), the mission flags.
func _mission_body() -> void:
	var w := 20.0
	var d := 12.0
	var h := 7.4
	_box("concrete_flat", Vector3(0, 0.15, 0), Vector3(w + 0.4, 0.3, d + 0.4))
	_box("concrete", Vector3(0, 0.3 + h * 0.5, 0), Vector3(w, h, d))
	for side in ["front", "back", "left", "right"]:
		var span := w if side in ["front", "back"] else d
		_on_face(w, d, side, func() -> void:
			for k in 2:
				var y := 0.3 + k * 3.6
				_box("warm_white", Vector3(0, y + 0.5, 0.03), Vector3(span, 0.4, 0.06))
				if side == "front":
					_ribbon(-span * 0.5 + 0.6, -4.6, y + 1.0, 1.8, 1.3, "chrome", 0.7)
					_ribbon(4.6, span * 0.5 - 0.6, y + 1.0, 1.8, 1.3, "chrome", 0.7)
				else:
					_ribbon(-span * 0.5 + 0.6, span * 0.5 - 0.6, y + 1.0, 1.8, 1.3, "chrome", 0.7))
	_box("warm_white", Vector3(0, 0.3 + h + 0.3, 0), Vector3(w + 0.4, 0.6, d + 0.4))
	# the control room: a glazed half drum on the front, its screens glowing
	var cc := Vector3(0, 0.3, d * 0.5 - 0.6)
	_lathe("concrete_flat", cc, [Vector2(4.6, 0), Vector2(4.6, 0.3), Vector2(0, 0.3)], 20)
	_curtain_arc(cc + Vector3(0, 0.3, 0), 4.3, -PI * 0.5, PI * 0.5, 6.0)
	_lathe("warm_white", cc + Vector3(0, 6.3, 0), [Vector2(4.8, 0), Vector2(4.8, 0.5), Vector2(0, 0.5)], 20)
	for k in 9:
		var a := -PI * 0.5 + PI * k / 8.0
		_beam("chrome", cc + Vector3(sin(a) * 4.32, 0.3, cos(a) * 4.32), cc + Vector3(sin(a) * 4.32, 6.3, cos(a) * 4.32), 0.08)
	for k in 5:   # screens inside the glass
		var a := -0.9 + k * 0.45
		_push(_xf(cc + Vector3(sin(a) * 3.4, 3.9, cos(a) * 3.4), rad_to_deg(a) + 180.0))
		_box("screen_glow", Vector3(0, 0, 0), Vector3(1.0, 0.7, 0.05))
		_pop()
	_push(_xf(Vector3(0, 0.3 + h + 0.6, d * 0.5 + 0.21)))
	_face_disc("mission_patch", Vector3(0, 1.6, 0.0), 1.5, 24)
	_lathe("chrome", Vector3(0, 1.6, -0.02), [Vector2(1.62, 0), Vector2(1.62, 0.06), Vector2(1.5, 0.06)], 24, Vector3(90, 0, 0), Vector3.ONE, 0.0, false)
	_box("concrete_flat", Vector3(0, 1.0, -0.2), Vector3(0.6, 2.0, 0.3))
	_pop()
	_flat_roof(w, d, 0.3 + h + 0.6, "vents", "warm_white")
	# rooftop: dishes, the radar, the mast
	var ry := 0.3 + h + 0.7
	_model(SPACE + "satelliteDish_large.glb", Vector3(-6.5, ry, -2.5), Vector3(0, 150, 0), 2.6, null, KSPACE)
	_model(SPACE + "satelliteDish_detailed.glb", Vector3(-3.0, ry, -3.5), Vector3(0, 200, 0), 2.4, null, KSPACE)
	_lattice_tower(Vector3(6.5, ry, -2.5), 1.0, 7.0, "signal_orange", 1.4, 0.12)
	_ball("signal_lamp", Vector3(6.5, ry + 7.3, -2.5), 0.14, 6, 3)
	_rod("chrome", Vector3(6.5, ry + 7.0, -2.5), Vector3(6.5, ry + 9.0, -2.5), 0.04, 4)
	_cyl("steel_dark", Vector3(2.5, ry, -3.0), 0.5, 0.4, 2.2, 8)
	var radar := _part("Radar", Vector3(2.5, ry + 2.4, -3.0), func() -> void:
		_box("warm_white", Vector3(0, 0.6, 0), Vector3(3.6, 1.2, 0.12), Vector3(-15, 0, 0))
		for k in 6:
			_box("steel", Vector3(-1.5 + k * 0.6, 0.6, 0.08), Vector3(0.04, 1.2, 0.04), Vector3(-15, 0, 0))
		_beam("steel_dark", Vector3(0, -0.2, 0), Vector3(0, 0.3, 0.6), 0.1)
		_cyl("steel_dark", Vector3(0, -0.2, 0), 0.25, 0.25, 0.3, 8))
	radar.set_script(SPINNER)
	radar.set("speed", 0.8)
	radar.set("axis", Vector3.UP)
	# the way in, flags
	_push(_xf(Vector3(7.5, 0, d * 0.5)))
	_box("night_blue", Vector3(0, 1.3, 0.05), Vector3(1.6, 2.6, 0.1))
	_boomerang(Vector3(0, 3.0, 1.0), 4.0, 2.0)
	_pop()
	for x in [-7.0, -5.0]:
		_flagpole(Vector3(x, 0.1, d * 0.5 + 2.6), 6.5)


func _radio_telescope() -> void:
	_begin("radio_telescope")
	_telescope(true)
	_save("radio_telescope")
	_begin("radio_telescope_plot")
	_plot4(14.0, 14.0, true)
	_save("radio_telescope_plot")
	_begin("radio_telescope_frame")
	_telescope(false)
	_save("radio_telescope_frame")


## The radio telescope (Research by night, DESIGN 4/5): a white dish 13 m across on an
## alt-azimuth yoke that turns on a ring track (Mount, a slow spinner), the feed horn on a
## tripod at the focus, a lattice of ribs behind; the control hut beside it.
func _telescope(done: bool) -> void:
	_lathe("concrete", Vector3.ZERO, [Vector2(6.2, 0), Vector2(6.2, 0.5), Vector2(5.4, 0.5), Vector2(5.4, 0.3), Vector2(1.6, 0.3), Vector2(1.6, 0.9), Vector2(0, 0.9)], 24)
	_lathe("steel_dark", Vector3(0, 0.5, 0), [Vector2(5.9, 0), Vector2(5.9, 0.12), Vector2(5.7, 0.12), Vector2(5.7, 0)], 24, Vector3.ZERO, Vector3.ONE, 0.0, false)
	# control hut
	_box("warm_white", Vector3(-5.6, 1.4, 6.2), Vector3(3.6, 2.8, 2.8))
	_box("signal_orange", Vector3(-5.6, 2.9, 6.2), Vector3(3.9, 0.2, 3.1))
	_push(_xf(Vector3(-5.6, 0, 7.6)))
	_ribbon(-1.4, 0.4, 1.0, 1.0, 0.9, "steel_dark", 0.8)
	_box("night_blue", Vector3(1.0, 1.0, 0.05), Vector3(0.9, 2.0, 0.08))
	_pop()
	var mount := _part("Mount", Vector3(0, 0.9, 0), func() -> void: _telescope_mount(done))
	if done:
		mount.set_script(SPINNER)
		mount.set("speed", 0.05)
		mount.set("axis", Vector3.UP)


func _telescope_mount(done: bool) -> void:
	_cyl("steel_dark", Vector3.ZERO, 2.2, 2.2, 0.6, 16)
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_cyl("rubber", Vector3(c.x * 4.0, -0.3, c.y * 1.2), 0.35, 0.35, 0.3, 10, Vector3(90, 0, 0))
	_box("steel", Vector3(0, 0.75, 0), Vector3(8.6, 0.3, 3.0))
	for sx in [-1.0, 1.0]:   # the yoke's two A-frames
		_ibeam("warm_white", Vector3(sx * 4.0, 0.9, -1.3), Vector3(sx * 3.7, 7.6, 0), 0.4, Vector3.FORWARD)
		_ibeam("warm_white", Vector3(sx * 4.0, 0.9, 1.3), Vector3(sx * 3.7, 7.6, 0), 0.4, Vector3.FORWARD)
		_beam("warm_white", Vector3(sx * 3.9, 4.0, -0.7), Vector3(sx * 3.9, 4.0, 0.7), 0.2)
		_cyl("steel_dark", Vector3(sx * 3.7, 7.6, 0), 0.45, 0.45, 0.5, 10, Vector3(0, 0, 90))
	_box("concrete_dark", Vector3(0, 1.6, -1.6), Vector3(2.2, 1.6, 1.0))   # counterweight
	if not done:
		_box("steel", Vector3(0, 7.6, 0), Vector3(7.0, 0.5, 0.5))
		for k in 5:
			var a := TAU * k / 10.0
			_beam("steel", Vector3(0, 7.6, 0), Vector3(cos(a) * 5.0, 7.6 + sin(a) * 3.0, 1.6), 0.12)
		return
	# the dish, tilted up toward the sky in the +Z direction
	_push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-50.0)), Vector3(0, 7.6, 0)))
	_rod("steel_dark", Vector3(-3.7, 0, 0), Vector3(3.7, 0, 0), 0.25, 8)
	var r := 6.5
	var depth := 1.6
	var prof := []
	for j in 9:
		var t := j / 8.0
		prof.append(Vector2(r * t, 1.2 + depth * t * t))
	_lathe("dish_white", Vector3.ZERO, prof, 28, Vector3.ZERO, Vector3.ONE, 0.0, false)
	_lathe("steel", Vector3(0, 1.2 + depth, 0), [Vector2(r + 0.08, -0.1), Vector2(r + 0.08, 0.06), Vector2(r - 0.1, 0.06)], 28, Vector3.ZERO, Vector3.ONE, 0.0, false)
	for k in 12:   # ribs behind the surface
		var a := TAU * k / 12.0
		var dir := Vector3(cos(a), 0, sin(a))
		_beam("steel", Vector3(0, 0.6, 0) + dir * 0.6, dir * r * 0.98 + Vector3(0, 1.2 + depth * 0.95 - 0.12, 0), 0.1)
		_beam("steel", Vector3(0, 0.6, 0), dir * r * 0.5 + Vector3(0, 1.2 + depth * 0.25 - 0.1, 0), 0.08)
	_cyl("steel_dark", Vector3(0, 0.2, 0), 1.2, 1.0, 1.0, 12)
	var focus := Vector3(0, 1.2 + 5.2, 0)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		_rod("warm_white", Vector3(cos(a) * r * 0.62, 1.2 + depth * 0.4, sin(a) * r * 0.62), focus, 0.07, 5)
	_lathe("signal_orange", focus - Vector3(0, 0.3, 0), [Vector2(0.25, 0), Vector2(0.45, 0.7), Vector2(0.35, 0.9), Vector2(0, 0.9)], 10)
	_pop()


func _training_centre() -> void:
	_begin("training_centre")
	_training_body(true)
	_save("training_centre")
	_begin("training_centre_plot")
	_plot4(24.0, 12.0)
	_save("training_centre_plot")
	_begin("training_centre_frame")
	_training_body(false)
	_save("training_centre_frame")


## Crew training (DESIGN 4): a low warm-white hall under a butterfly roof with turquoise
## fascias, and beside it the centrifuge in its round open pit: a hub, an orange arm and
## the capsule gondola (Centrifuge, a spinner, stopped until crew are training).
func _training_body(done: bool) -> void:
	var hc := Vector3(-6.0, 0, 0)
	var w := 13.0
	var d := 10.0
	_box("concrete_flat", hc + Vector3(0, 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3))
	if done:
		_box("warm_white", hc + Vector3(0, 0.3 + 2.4, 0), Vector3(w, 4.8, d))
		_push(_xf(hc))
		_on_face(w, d, "front", func() -> void:
			_ribbon(-w * 0.5 + 0.5, w * 0.5 - 3.0, 1.2, 2.6, 1.4, "chrome", 0.7)
			_box("night_blue", Vector3(w * 0.5 - 1.6, 1.4, 0.05), Vector3(1.5, 2.6, 0.1))
			_box("enamel_turquoise", Vector3(0, 4.3, 0.03), Vector3(w, 0.5, 0.06)))
		_on_face(w, d, "back", func() -> void:
			_ribbon(-w * 0.5 + 0.5, w * 0.5 - 0.5, 1.6, 2.0, 1.4, "chrome", 0.5))
		_pop()
		# butterfly roof: two slabs dipping to a central valley
		for s in [-1.0, 1.0]:
			_slab("warm_white", [hc + Vector3(-w * 0.5 - 0.6, 5.0, 0), hc + Vector3(w * 0.5 + 0.6, 5.0, 0),
				hc + Vector3(w * 0.5 + 0.6, 6.0, s * (d * 0.5 + 0.8)), hc + Vector3(-w * 0.5 - 0.6, 6.0, s * (d * 0.5 + 0.8))], 0.18, Vector3(0, 1, -s * 0.2))
			_box("enamel_turquoise", hc + Vector3(0, 5.95, s * (d * 0.5 + 0.8)), Vector3(w + 1.3, 0.3, 0.08))
		for sx in [-1.0, 1.0]:
			_tri("warm_white", hc + Vector3(sx * w * 0.5, 4.8, -d * 0.5), hc + Vector3(sx * w * 0.5, 4.8, d * 0.5), hc + Vector3(sx * w * 0.5, 5.0, 0), Vector3(sx, 0, 0))
		_flagpole(hc + Vector3(-w * 0.5 + 1.0, 0.3, d * 0.5 + 2.0), 6.5)
		_flagpole(hc + Vector3(-w * 0.5 + 3.0, 0.3, d * 0.5 + 2.0), 6.5, "flag_hand")
	else:
		_push(_xf(hc))
		_frame4(w, d, 1, 4.8, 1, false)
		_pop()
	# the centrifuge
	var cc := Vector3(7.0, 0, 0)
	_lathe("concrete", cc, [Vector2(6.2, 0), Vector2(6.2, 1.0), Vector2(5.9, 1.0), Vector2(5.9, 0.15), Vector2(0, 0.15)], 24)
	_lathe("enamel_mint", cc + Vector3(0, 0.16, 0), [Vector2(5.88, 0), Vector2(0, 0)], 24)
	var ring := []
	for k in 25:
		var a := TAU * k / 24.0
		ring.append(cc + Vector3(cos(a) * 6.1, 1.0, sin(a) * 6.1))
	_railing(ring, 0.8, false)
	_cyl("steel_dark", cc, 1.0, 0.8, 1.6, 12)
	if not done:
		return
	var arm := _part("Centrifuge", cc + Vector3(0, 1.6, 0), func() -> void:
		_cyl("signal_orange", Vector3.ZERO, 0.8, 0.8, 0.5, 12)
		_truss("signal_orange", Vector3(0.6, 0.0, 0), Vector3(4.6, 0.0, 0), 0.6, Vector3.UP, 0.12)
		_box("concrete_dark", Vector3(-1.4, 0.3, 0), Vector3(1.4, 1.0, 1.0))
		_ball("warm_white", Vector3(5.0, 0.4, 0), 1.0, 14, 8, Vector3(1.1, 0.95, 1.0))
		_lathe("signal_orange", Vector3(5.0, 0.3, 0), [Vector2(1.08, 0), Vector2(1.08, 0.18)], 14, Vector3.ZERO, Vector3.ONE, 0.0, false)
		_push(_xf(Vector3(5.0, 0.55, 0), 0.0))
		_wrap(1.0, 0.0, func() -> void: _porthole(Vector3(0, 0, 0.0), 0.3, "glass_dark"))
		_pop())
	arm.set_script(SPINNER)
	arm.set("speed", 1.2)
	arm.set("axis", Vector3.UP)
	arm.set("spinning", false)


# ================================================================== transport, testing, wind

func _rail_station() -> void:
	_begin("rail_station")
	_station_body()
	_save("rail_station")
	_begin("rail_station_plot")
	_plot4(24.0, 8.0)
	_save("rail_station_plot")
	_begin("rail_station_frame")
	_box("concrete", Vector3(0, 0.45, -1.0), Vector3(24.0, 0.9, 5.0))
	_frame4(8.0, 5.0, 1, 3.8, 1, false)
	for x in [-9.0, -4.5, 4.5, 9.0]:
		_ibeam("signal_orange", Vector3(x, 0.9, -1.0), Vector3(x, 4.4, -1.0), 0.3)
	_save("rail_station_frame")


## The station: a long platform (its edge at z = -3.5 faces the line, track centre at
## z = -5.2 along X), a butterfly canopy on Y-shaped steel columns with an orange fascia,
## the brick booking hall behind with the Era 3 clock face in its slim tower, benches, lamps.
func _station_body() -> void:
	_box("concrete", Vector3(0, 0.45, -1.0), Vector3(24.0, 0.9, 5.0))
	_box("road_yellow", Vector3(0, 0.905, -3.2), Vector3(24.0, 0.01, 0.25))
	_box("concrete_flat", Vector3(0, 0.82, -3.45), Vector3(24.0, 0.16, 0.2))
	for i in 5:
		var x := -10.0 + i * 5.0
		_ibeam("steel_dark", Vector3(x, 0.9, -1.0), Vector3(x, 3.6, -1.0), 0.28)
		_beam("steel_dark", Vector3(x, 3.6, -1.0), Vector3(x, 4.3, -3.0), 0.18)
		_beam("steel_dark", Vector3(x, 3.6, -1.0), Vector3(x, 4.3, 1.0), 0.18)
	for s in [-1.0, 1.0]:
		_slab("warm_white", [Vector3(-12.2, 3.75, -1.0), Vector3(12.2, 3.75, -1.0), Vector3(12.2, 4.4, -1.0 + s * 2.6), Vector3(-12.2, 4.4, -1.0 + s * 2.6)], 0.14, Vector3(0, 1, -s * 0.2))
		_box("signal_orange", Vector3(0, 4.38, -1.0 + s * 2.6), Vector3(24.4, 0.32, 0.08))
	for i in 4:
		var x := -7.5 + i * 5.0
		_bench4(Vector3(x, 0.9, 0.2), 0.0)
		_lamp_post(Vector3(x + 2.5, 0.9, -2.6), 3.4)
	# booking hall and clock tower
	var bh := Vector3(3.0, 0, 3.4)
	_box("brick", bh + Vector3(0, 2.2, 0), Vector3(9.0, 4.4, 4.2))
	_box("warm_white", bh + Vector3(0, 4.5, 0), Vector3(9.4, 0.3, 4.6))
	_push(_xf(bh + Vector3(0, 0, 2.1)))
	_ribbon(-4.0, 1.2, 1.2, 2.2, 1.3, "chrome", 0.8)
	_box("night_blue", Vector3(2.6, 1.3, 0.05), Vector3(1.8, 2.6, 0.1))
	_boomerang(Vector3(2.6, 3.0, 1.0), 3.6, 1.8)
	_pop()
	var ct := bh + Vector3(-5.6, 0, 0.0)
	_box("warm_white", ct + Vector3(0, 4.6, 0), Vector3(1.6, 9.2, 1.6))
	for k in 4:
		var ry := k * 90.0
		var b := Basis(Vector3.UP, deg_to_rad(ry))
		_push(Transform3D(b, ct + b * Vector3(0, 0, 0.81)))
		_face_disc("clock_face", Vector3(0, 7.9, 0.01), 0.65, 20)
		_clock_hands(Vector3(0, 7.9, 0.04), 0.65)
		_pop()
	_box("signal_orange", ct + Vector3(0, 9.3, 0), Vector3(1.9, 0.2, 1.9))
	_rod("chrome", ct + Vector3(0, 9.4, 0), ct + Vector3(0, 10.8, 0), 0.04, 4)
	_poster_board(Vector3(-9.0, 0.9, 1.3), 0.0)


## Steel test stand for the engines (the build answer to a launch scrub, DESIGN 8): a
## concrete tower with a steel frame holding an engine bell over the flame bucket, the
## curved deflector throwing the exhaust sideways, a low bunker with slit windows.
func _test_stand() -> void:
	_begin("test_stand")
	_stand_body(true)
	_save("test_stand")
	_begin("test_stand_plot")
	_plot4(14.0, 10.0)
	_save("test_stand_plot")
	_begin("test_stand_frame")
	_stand_body(false)
	_save("test_stand_frame")


func _stand_body(done: bool) -> void:
	var h := 11.0 if done else 5.0
	_box("concrete", Vector3(-2.0, h * 0.5, 0), Vector3(5.0, h, 6.0))
	_box("concrete_dark", Vector3(-2.0, h + 0.1, 0), Vector3(5.2, 0.2, 6.2))
	# the flame bucket and deflector
	_box("concrete", Vector3(2.4, 1.0, 0), Vector3(4.0, 2.0, 6.0))
	_slab("concrete_dark", [Vector3(0.6, 2.0, 2.6), Vector3(0.6, 2.0, -2.6), Vector3(4.4, 0.7, -2.6), Vector3(4.4, 0.7, 2.6)], 0.1, Vector3(0.3, 1, 0))
	_box("soil_dark", Vector3(7.0, 0.02, 0), Vector3(6.0, 0.02, 6.0))
	if not done:
		_derrick(Vector3(-5.6, 0, 3.6), 9.0)
		return
	for z in [-2.4, 2.4]:   # the cantilevered frame
		_truss("signal_orange", Vector3(0.5, h - 2.0, z), Vector3(4.2, h - 2.0, z), 1.8, Vector3.UP, 0.18)
	_box("steel_dark", Vector3(2.4, h - 0.2, 0), Vector3(4.0, 0.2, 5.2))
	_cyl("warm_white", Vector3(2.4, h - 4.0, 0), 1.1, 1.1, 3.8, 14)
	_lathe("steel_dark", Vector3(2.4, h - 7.2, 0), [Vector2(1.0, 0), Vector2(0.85, 1.4), Vector2(0.5, 2.6), Vector2(0.4, 3.2)], 14, Vector3.ZERO, Vector3.ONE, 0.0, false)
	_lathe("cave_dark", Vector3(2.4, h - 7.15, 0), [Vector2(0.95, 0), Vector2(0, 1.0)], 14)
	for z in [-0.6, 0.6]:
		_rod("enamel_mustard", Vector3(-0.2, h - 3.0, z), Vector3(1.4, h - 2.4, z * 0.4), 0.1, 6)
	_ladder4(Vector3(-4.6, 0, 3.05), Vector3(-4.6, h, 3.05))
	_ball("signal_lamp", Vector3(-2.0, h + 0.4, 0), 0.14, 6, 3)
	for k in 5:   # hazard chequer round the top of the tower
		for sz in [-1.0, 1.0]:
			_box("signal_orange" if k % 2 == 0 else "warm_white", Vector3(-4.0 + k * 1.0, h - 0.6, sz * 3.01), Vector3(1.0, 0.8, 0.04))
	_hand_badge(Vector3(-2.0, h - 3.6, 3.04), 2.2)
	_box("night_blue", Vector3(-2.0, 1.2, 3.02), Vector3(1.4, 2.4, 0.06))
	# the propellant sphere on its legs and the feed line to the engine
	var ft := Vector3(-7.6, 0, -1.6)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		_ibeam("signal_orange", ft + Vector3(cos(a) * 1.5, 0, sin(a) * 1.5), ft + Vector3(cos(a) * 1.25, 3.0, sin(a) * 1.25), 0.2)
	_ball("warm_white", ft + Vector3(0, 3.6, 0), 1.7, 14, 7)
	_lathe("signal_orange", ft + Vector3(0, 3.5, 0), [Vector2(1.72, 0), Vector2(1.72, 0.3)], 14, Vector3.ZERO, Vector3.ONE, 0.0, false)
	_rod("chrome", ft + Vector3(1.4, 2.6, 0), Vector3(-4.5, 2.6, -1.6), 0.12, 6)
	_rod("chrome", Vector3(-4.5, 2.6, -1.6), Vector3(-4.5, h - 3.0, -1.6), 0.12, 6)
	# the bunker
	var bk := Vector3(-3.5, 0, 6.6)
	_lathe("concrete", bk, [Vector2(2.4, 0), Vector2(2.2, 1.8), Vector2(1.4, 2.4), Vector2(0, 2.5)], 10, Vector3.ZERO, Vector3(1.3, 1, 0.9))
	for k in 3:
		_push(_xf(bk + Vector3(-1.0 + k * 1.0, 1.6, -1.95), 180.0))
		_box("glass_dark", Vector3(0, 0, 0), Vector3(0.6, 0.2, 0.1))
		_pop()
	_box("night_blue", bk + Vector3(2.8, 0.9, 0), Vector3(0.1, 1.8, 0.9))


func _wind_turbine() -> void:
	_begin("wind_turbine")
	_turbine(true)
	_save("wind_turbine")
	_begin("wind_turbine_plot")
	_plot4(4.0, 4.0, true)
	_save("wind_turbine_plot")
	_begin("wind_turbine_frame")
	_turbine(false)
	_save("wind_turbine_frame")


## Clean power on the ridge (DESIGN 8, smog's build answer): a slim white tower, a rounded
## nacelle banded in signal orange, three long blades (Rotor, a spinner facing +Z).
func _turbine(done: bool) -> void:
	_cyl("concrete", Vector3.ZERO, 1.6, 1.5, 0.4, 12)
	var h := 16.0 if done else 7.0
	_lathe("warm_white", Vector3(0, 0.4, 0), [Vector2(0.75, 0), Vector2(0.42, h - 0.4), Vector2(0, h - 0.4)], 14)
	_box("night_blue", Vector3(0, 1.4, 0.68), Vector3(0.6, 1.6, 0.1))
	if not done:
		_derrick(Vector3(-2.4, 0, 1.6), 10.0)
		for k in 2:
			_lathe("warm_white", Vector3(2.6 + k * 1.6, 0.3, -1.0), [Vector2(0.55, 0), Vector2(0.45, 4.0), Vector2(0, 4.0)], 12, Vector3(0, 0, 90))
		return
	_lathe("warm_white", Vector3(0, h - 0.6, -0.6), [Vector2(0.0, 0.0), Vector2(0.55, 0.3), Vector2(0.6, 2.2), Vector2(0.5, 2.8), Vector2(0, 3.0)], 12, Vector3(90, 0, 0))
	_lathe("signal_orange", Vector3(0, h - 0.6, 0.6), [Vector2(0.61, 0), Vector2(0.61, 0.3)], 12, Vector3(90, 0, 0), Vector3.ONE, 0.0, false)
	var rotor := _part("Rotor", Vector3(0, h - 0.6, 2.4), func() -> void:
		_lathe("signal_orange", Vector3(0, 0, 0), [Vector2(0.5, 0), Vector2(0.4, 0.6), Vector2(0, 0.9)], 12, Vector3(90, 0, 0))
		for k in 3:
			var a := TAU * k / 3.0
			_push(Transform3D(Basis(Vector3.BACK, a), Vector3.ZERO))
			_plate("warm_white", [Vector2(-0.18, 0.4), Vector2(0.22, 0.4), Vector2(0.4, 1.8), Vector2(0.12, 6.6), Vector2(-0.05, 6.6), Vector2(-0.2, 1.8)], 0.0, 0.1)
			_plate("signal_orange", [Vector2(-0.05, 5.6), Vector2(0.15, 5.6), Vector2(0.12, 6.62), Vector2(-0.06, 6.62)], 0.0, 0.12)
			_pop())
	rotor.set_script(SPINNER)
	rotor.set("speed", 0.9)
	rotor.set("axis", Vector3.FORWARD)
	_ball("signal_lamp", Vector3(0, h + 0.1, -1.6), 0.1, 5, 3)


# ================================================================== roads and the rail line

## Two-lane asphalt street, 4 m long along Z, with concrete kerbs and pavements: 7.4 wide.
func _roads4() -> void:
	_begin("road_asphalt")
	_road_strip(4.0)
	_save("road_asphalt")
	_begin("road_asphalt_cross")   # a crossroads with zebra crossings on all four arms
	_box("asphalt", Vector3(0, 0.04, 0), Vector3(7.4, 0.08, 7.4))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_box("concrete_flat", Vector3(c.x * 3.2, 0.08, c.y * 3.2), Vector3(1.0, 0.16, 1.0))
		_cyl("concrete_flat", Vector3(c.x * 2.7, 0.0, c.y * 2.7), 0.5, 0.5, 0.16, 10)
	for k in 4:
		var b := Basis(Vector3.UP, k * PI * 0.5)
		for i in 6:
			var x := -2.1 + i * 0.84
			_box_b("road_paint", b * Vector3(x, 0.083, 2.75), Vector3(0.45, 0.01, 0.9), b)
	_save("road_asphalt_cross")
	_begin("road_asphalt_end")   # the street gives out into gravel: the edge of town
	_box("asphalt", Vector3(0, 0.04, -0.9), Vector3(5.0, 0.08, 2.2))
	for sx in [-1.0, 1.0]:
		_box("concrete_flat", Vector3(sx * 2.6, 0.08, -0.9), Vector3(0.2, 0.16, 2.2))
		_box("concrete", Vector3(sx * 3.2, 0.06, -0.9), Vector3(1.0, 0.12, 2.2))
	for i in 34:
		var p := Vector3(_rng.randf_range(-2.4, 2.4), 0.025, _rng.randf_range(0.2, 2.0))
		if _rng.randf() < (p.z - 0.1) / 1.9:
			continue
		_box("asphalt", p, Vector3(0.3, 0.05, 0.24), Vector3(0, _rng.randf_range(-30, 30), 0))
	_save("road_asphalt_end")


func _road_strip(l: float) -> void:
	_box("asphalt", Vector3(0, 0.04, 0), Vector3(5.0, 0.08, l))
	for sx in [-1.0, 1.0]:
		_box("concrete_flat", Vector3(sx * 2.6, 0.08, 0), Vector3(0.2, 0.16, l))
		_box("concrete", Vector3(sx * 3.2, 0.07, 0), Vector3(1.0, 0.14, l))
		_box("road_paint", Vector3(sx * 2.2, 0.083, 0), Vector3(0.1, 0.01, l))
	for k in int(l / 2.0):
		_box("road_paint", Vector3(0, 0.083, -l * 0.5 + 1.0 + k * 2.0), Vector3(0.12, 0.01, 1.0))


## The railway: standard gauge track 8 m along Z on sleepers and ballast, a buffer stop,
## a level crossing with striped barriers, and a steel truss bridge.
func _rail() -> void:
	_begin("rail_track")
	_track(8.0)
	_save("rail_track")
	_begin("rail_buffer")
	_track(4.0)
	for sx in [-1.0, 1.0]:
		_ibeam("signal_orange", Vector3(sx * 0.72, 0.3, -1.2), Vector3(sx * 0.72, 1.1, -1.8), 0.2)
		_ibeam("signal_orange", Vector3(sx * 0.72, 0.3, -2.0), Vector3(sx * 0.72, 1.1, -1.8), 0.2)
		_cyl("chrome", Vector3(sx * 0.72, 1.0, -1.75), 0.16, 0.16, 0.35, 8, Vector3(90, 0, 0))
	_box("night_blue", Vector3(0, 1.0, -1.85), Vector3(1.9, 0.35, 0.25))
	for i in 4:
		_box("warm_white" if i % 2 == 0 else "signal_orange", Vector3(-0.71 + i * 0.475, 1.0, -1.72), Vector3(0.475, 0.35, 0.02))
	_save("rail_buffer")
	_begin("rail_crossing")   # level crossing: the road (along X) over the line (along Z)
	_track(8.0)
	_box("asphalt", Vector3(0, 0.25, 0), Vector3(7.4, 0.06, 5.0))
	for sz in [-1.0, 1.0]:
		var p := Vector3(-3.4 * sz, 0, 2.9 * sz)
		_cyl("concrete_flat", p, 0.22, 0.2, 0.3, 8)
		_rod("steel_dark", p, p + Vector3(0, 1.3, 0), 0.07, 6)
		_box("night_blue", p + Vector3(0, 1.0, 0.0), Vector3(0.3, 0.4, 0.3))
		for i in 6:
			var a := p + Vector3(sz * (0.2 + i * 0.5), 1.15, 0)
			_box("signal_orange" if i % 2 == 0 else "warm_white", a + Vector3(sz * 0.25, 0, 0), Vector3(0.5, 0.12, 0.06))
		_rod("steel_dark", p + Vector3(0, 1.3, 0), p + Vector3(0, 2.5, 0), 0.05, 6)
		for sx in [-0.25, 0.25]:
			_cyl("night_blue", p + Vector3(sx, 2.3, 0.0), 0.16, 0.16, 0.08, 10, Vector3(90, 0, 0))
			_cyl("signal_lamp", p + Vector3(sx, 2.3, sz * 0.05), 0.11, 0.11, 0.02, 10, Vector3(90, 0, 0))
		# St Andrew's cross
		_beam("warm_white", p + Vector3(-0.45, 1.6, 0.05), p + Vector3(0.45, 2.0, 0.05), 0.12, 0.03)
		_beam("warm_white", p + Vector3(-0.45, 2.0, 0.05), p + Vector3(0.45, 1.6, 0.05), 0.12, 0.03)
	_save("rail_crossing")
	_begin("rail_bridge")   # 16 m Warren truss over a river or road, track on top
	for sx in [-1.0, 1.0]:
		_box("concrete", Vector3(0, 1.5, sx * 8.6), Vector3(4.2, 3.0, 1.4))
	_push(_xf(Vector3(0, 3.0, 0)))
	_track(16.0, false)
	_pop()
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.7
		_ibeam("night_blue", Vector3(x, 2.85, -8.0), Vector3(x, 2.85, 8.0), 0.3)
		_ibeam("night_blue", Vector3(x, 6.0, -6.4), Vector3(x, 6.0, 6.4), 0.24)
		for i in 5:
			var z0 := -8.0 + i * 3.2
			var z1 := z0 + 1.6
			var z2 := z0 + 3.2
			_beam("signal_orange", Vector3(x, 2.9, z0), Vector3(x, 6.0, minf(maxf(z1, -6.4), 6.4)), 0.2)
			_beam("signal_orange", Vector3(x, 6.0, minf(maxf(z1, -6.4), 6.4)), Vector3(x, 2.9, z2), 0.2)
	for i in 5:
		var z := -6.4 + i * 3.2
		_beam("night_blue", Vector3(-1.7, 6.0, z), Vector3(1.7, 6.0, z), 0.14)
		_beam("night_blue", Vector3(-1.7, 2.9, z), Vector3(1.7, 2.9, z), 0.18)
	_save("rail_bridge")


## Track l long along Z: rails at x = +-0.72 on concrete sleepers over a ballast bed.
func _track(l: float, ballast := true) -> void:
	if ballast:
		_box("concrete_dark", Vector3(0, 0.06, 0), Vector3(3.2, 0.12, l))
		_box("stone_dark", Vector3(0, 0.15, 0), Vector3(2.6, 0.12, l))
	var n := int(l / 0.65)
	for i in n:
		_box("concrete_flat", Vector3(0, 0.26, -l * 0.5 + 0.32 + i * 0.65), Vector3(2.3, 0.12, 0.26))
	for sx in [-1.0, 1.0]:
		_box("steel_dark", Vector3(sx * 0.72, 0.36, 0), Vector3(0.12, 0.08, l))
		_box("steel", Vector3(sx * 0.72, 0.42, 0), Vector3(0.08, 0.05, l))


# ================================================================== street furniture

func _street4() -> void:
	_begin("street_light")   # the mid-century swan-neck lamp: a tapered concrete mast and an orange hood
	_lamp_post(Vector3.ZERO, 6.0)
	_hidden_light("Light", Vector3(0, 5.6, 0.95), Color("#ffd28a"), 1.8, 11.0, Vector3(0, 0, 3.0), 55.0)
	_save("street_light")

	_begin("bus_stop")   # a boomerang shelter with a bench and a route sign
	_box("concrete", Vector3(0, 0.05, 0), Vector3(3.6, 0.1, 1.8))
	_boomerang(Vector3(0, 2.5, 0), 3.4, 1.6)
	_box("glass_blue", Vector3(0, 1.3, -0.7), Vector3(3.0, 1.8, 0.04))
	_box("chrome", Vector3(0, 2.2, -0.7), Vector3(3.0, 0.05, 0.06))
	_box("glass_blue", Vector3(-1.5, 1.3, -0.2), Vector3(0.04, 1.8, 1.0))
	_bench4(Vector3(0.2, 0.1, -0.35), 0.0)
	_rod("chrome", Vector3(1.9, 0.1, 0.6), Vector3(1.9, 2.8, 0.6), 0.04, 6)
	_cyl("signal_orange", Vector3(1.9, 2.8, 0.6), 0.32, 0.32, 0.06, 14, Vector3(90, 0, 0))
	_cyl("warm_white", Vector3(1.9, 2.8, 0.66), 0.25, 0.25, 0.02, 14, Vector3(90, 0, 0))
	_box("night_blue", Vector3(1.9, 2.8, 0.68), Vector3(0.3, 0.07, 0.01))
	_save("bus_stop")

	_begin("phone_box")   # a glazed kiosk in signal orange with a hand on the crown
	_box("concrete_flat", Vector3(0, 0.05, 0), Vector3(1.2, 0.1, 1.2))
	for k in 4:
		var ry := k * 90.0
		var b := Basis(Vector3.UP, deg_to_rad(ry))
		for sx in [-1.0, 1.0]:
			_box_b("signal_orange", b * Vector3(sx * 0.46, 1.25, 0.46), Vector3(0.1, 2.3, 0.1), b)
		_box_b("glass_blue", b * Vector3(0, 1.2, 0.47), Vector3(0.82, 1.9, 0.02), b)
		for i in 3:
			_box_b("signal_orange", b * Vector3(0, 0.65 + i * 0.55, 0.48), Vector3(0.82, 0.04, 0.03), b)
		_box_b("warm_white", b * Vector3(0, 2.25, 0.5), Vector3(0.8, 0.18, 0.02), b)
	_box("signal_orange", Vector3(0, 2.45, 0), Vector3(1.08, 0.12, 1.08))
	_lathe("signal_orange", Vector3(0, 2.5, 0), [Vector2(0.54, 0), Vector2(0.4, 0.18), Vector2(0, 0.24)], 4, Vector3.ZERO, Vector3.ONE, PI * 0.25)
	_hand_badge(Vector3(0, 2.3, 0.52), 0.22, "warm_white", "")
	_box("night_blue", Vector3(0, 1.2, -0.38), Vector3(0.36, 0.5, 0.14))
	_save("phone_box")

	_begin("kiosk")   # a round news and snack kiosk with a striped canopy
	_cyl("concrete_flat", Vector3.ZERO, 1.25, 1.25, 0.15, 16)
	_cyl("enamel_mint", Vector3(0, 0.15, 0), 1.0, 1.0, 1.0, 16)
	_cyl("warm_white", Vector3(0, 1.15, 0), 1.04, 1.04, 0.08, 16)
	_cyl("glass_blue", Vector3(0, 1.23, 0), 0.98, 0.98, 0.9, 16)
	for k in 8:
		var a := TAU * k / 8.0
		_rod("chrome", Vector3(cos(a), 1.2, sin(a)) * Vector3(0.99, 1, 0.99), Vector3(cos(a) * 0.99, 2.15, sin(a) * 0.99), 0.03, 4)
	for k in 12:
		var a0 := TAU * k / 12.0
		var a1 := TAU * (k + 1) / 12.0
		var m := "signal_orange" if k % 2 == 0 else "warm_white"
		_tri(m, Vector3(0, 2.95, 0), Vector3(cos(a0) * 1.55, 2.15, sin(a0) * 1.55), Vector3(cos(a1) * 1.55, 2.15, sin(a1) * 1.55), Vector3.UP)
		_tri(m, Vector3(0, 2.94, 0), Vector3(cos(a1) * 1.55, 2.14, sin(a1) * 1.55), Vector3(cos(a0) * 1.55, 2.14, sin(a0) * 1.55), Vector3.DOWN)
	_rod("chrome", Vector3(0, 2.95, 0), Vector3(0, 3.4, 0), 0.03, 4)
	_ball("signal_orange", Vector3(0, 3.45, 0), 0.09, 6, 3)
	for k in 5:   # papers and magazines on the counter
		_box(["paper", "enamel_coral", "paper", "enamel_sky", "enamel_mustard"][k], Vector3(-0.5 + k * 0.25, 1.21, 0.95), Vector3(0.2, 0.02, 0.28), Vector3(0, 0, 0))
	_save("kiosk")

	_begin("bench_modern")
	_bench4(Vector3.ZERO, 0.0)
	_save("bench_modern")

	_begin("planter_modern")   # a round concrete planter with a clipped tree and flowers
	_lathe("concrete_flat", Vector3.ZERO, [Vector2(0.55, 0), Vector2(0.75, 0.6), Vector2(0.8, 0.62), Vector2(0.72, 0.62), Vector2(0.72, 0.55), Vector2(0, 0.55)], 14)
	_cyl("soil", Vector3(0, 0.55, 0), 0.7, 0.7, 0.02, 14)
	_rod("wood_dark", Vector3(0, 0.55, 0), Vector3(0, 1.8, 0), 0.05, 6, 0.04)
	_ball("hedge", Vector3(0, 2.15, 0), 0.6, 9, 5)
	for k in 10:
		var a := TAU * k / 10.0
		_ball("leaf", Vector3(cos(a) * 0.5, 0.65, sin(a) * 0.5), 0.12, 5, 3)
		_ball(["enamel_coral", "enamel_mustard", "warm_white", "enamel_red"][k % 4], Vector3(cos(a) * 0.52, 0.78, sin(a) * 0.52), 0.06, 5, 3)
	_save("planter_modern")

	_begin("fire_hydrant")
	_lathe("enamel_red", Vector3.ZERO, [Vector2(0.18, 0), Vector2(0.18, 0.06), Vector2(0.13, 0.08), Vector2(0.13, 0.55), Vector2(0.16, 0.6), Vector2(0.15, 0.66), Vector2(0.1, 0.75), Vector2(0, 0.78)], 10)
	for sx in [-1.0, 1.0]:
		_cyl("chrome", Vector3(sx * 0.12, 0.45, 0), 0.06, 0.06, 0.1, 8, Vector3(0, 0, -sx * 90))
	_cyl("chrome", Vector3(0, 0.4, 0.12), 0.07, 0.07, 0.1, 8, Vector3(90, 0, 0))
	_save("fire_hydrant")

	_begin("poster_board")
	_poster_board(Vector3.ZERO, 0.0)
	_save("poster_board")

	_begin("flag_mission")   # the mission flag: the rocket rising from the open hand
	_flagpole(Vector3.ZERO, 8.0, "flag_mission", 2.4, 1.5)
	_save("flag_mission")

	_begin("power_pylon")   # a lattice pylon carrying the lines from the powerhouse
	_lattice_tower(Vector3.ZERO, 3.2, 14.0, "steel", 2.8, 0.14)
	for y in [10.5, 13.0]:
		var hw := 3.8 if y < 12.0 else 2.6
		_truss("steel", Vector3(-hw, y, 0), Vector3(hw, y, 0), 0.7, Vector3.UP, 0.1, 6)
		for sx in [-1.0, 1.0]:
			_insulator(Vector3(sx * (hw - 0.2), y - 0.05, 0))
	_rod("steel", Vector3(0, 14.0, 0), Vector3(0, 15.5, 0), 0.06, 4)
	_box("signal_orange", Vector3(0, 4.0, 0), Vector3(1.9, 0.3, 1.9))
	_save("power_pylon")

	_begin("park")   # 10 x 10 lawn with paths, a pond, trees and benches: the city's green
	_box("turf", Vector3(0, 0.03, 0), Vector3(10.0, 0.06, 10.0))
	for sx in [-1.0, 1.0]:
		_box("concrete", Vector3(0, 0.07, 0), Vector3(10.0, 0.04, 1.2))
		_box("concrete", Vector3(0, 0.071, 0), Vector3(1.2, 0.04, 10.0))
	_lathe("concrete_flat", Vector3(0, 0, 0), [Vector2(1.9, 0), Vector2(1.9, 0.35), Vector2(1.7, 0.35), Vector2(1.7, 0.2), Vector2(0, 0.2)], 18)
	_cyl("water", Vector3(0, 0.25, 0), 1.72, 1.72, 0.02, 18)
	_hand_badge(Vector3(0, 0.95, 0), 0.6, "chrome", "")
	_cyl("concrete_flat", Vector3(0, 0.2, 0), 0.18, 0.12, 0.4, 8)
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var p := Vector3(c.x * 3.3, 0.06, c.y * 3.3)
		_rod("wood_dark", p, p + Vector3(0, 2.0, 0), 0.12, 6, 0.08)
		_ball("leaf", p + Vector3(0, 3.0, 0), 1.4, 9, 5, Vector3(1, 0.9, 1))
		_ball("hedge", p + Vector3(0.5 * c.x, 3.6, 0.3 * c.y), 0.8, 8, 4)
		_bench4(Vector3(c.x * 1.6, 0.06, c.y * 3.2), 0.0 if c.y > 0 else 180.0)
		for k in 6:
			var q := Vector3(c.x * (1.2 + k * 0.6), 0.1, c.y * 1.0)
			_ball(["enamel_coral", "enamel_mustard", "warm_white"][k % 3], q, 0.12, 5, 3)
	_save("park")

	_begin("water_tower")   # Kenney City Kit Industrial water tower, recoloured warm
	_model(IND + "water-tower.glb", Vector3.ZERO, Vector3.ZERO, 4.5, null, KIND)
	_save("water_tower")

	_begin("cafe_parasol")
	var cols := ["enamel_turquoise", "signal_orange"]
	for pi in 2:
		var p: Vector3 = [Vector3(-1.4, 0, 0), Vector3(1.4, 0, 0.3)][pi]
		_rod("chrome", p, p + Vector3(0, 2.5, 0), 0.025, 5)
		for k in 10:   # the striped canopy
			var a0 := TAU * k / 10.0
			var a1 := TAU * (k + 1) / 10.0
			var m: String = cols[pi] if k % 2 == 0 else "warm_white"
			_tri(m, p + Vector3(0, 2.55, 0), p + Vector3(cos(a0) * 1.25, 2.1, sin(a0) * 1.25), p + Vector3(cos(a1) * 1.25, 2.1, sin(a1) * 1.25), Vector3.UP)
			_tri(m, p + Vector3(0, 2.54, 0), p + Vector3(cos(a1) * 1.25, 2.09, sin(a1) * 1.25), p + Vector3(cos(a0) * 1.25, 2.09, sin(a0) * 1.25), Vector3.DOWN)
		_cyl("chrome", p + Vector3(0, 0.0, 0), 0.25, 0.2, 0.05, 10)
		_cyl("warm_white", p + Vector3(0, 0.72, 0), 0.45, 0.45, 0.04, 14)
		for k in 2:
			var a := TAU * k / 2.0 + 0.5
			_cafe_chair(p + Vector3(cos(a) * 0.75, 0, sin(a) * 0.75), rad_to_deg(-a) - 90.0)
	_save("cafe_parasol")

	var far := ["low-detail-building-a", "low-detail-building-b", "low-detail-building-c", "low-detail-building-wide-a", "low-detail-building-wide-b"]
	for i in far.size():   # the far skyline: Kenney low-detail blocks for the distant city
		var nm := "city_block_far_%s" % ["a", "b", "c", "d", "e"][i]
		_begin(nm)
		var tint: Color = [Color("#e8dccb"), Color("#d9e4e2"), Color("#ecd9c4"), Color("#dfe0e8"), Color("#e9e2d2")][i]
		_model(CITY + far[i] + ".glb", Vector3.ZERO, Vector3.ZERO, 10.0, null, {"hog_pull": 0.25, "hog_sat": 0.8, "hog_tint": tint})
		var b := _aabb_of(_root)
		_box("signal_orange" if i % 2 == 0 else "enamel_turquoise", Vector3(0, b.end.y - 0.3, 0), Vector3(b.size.x + 0.1, 0.35, b.size.z + 0.1))
		_save(nm)


## The station and park bench: concrete ends, warm timber slats.
func _bench4(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	for sx in [-0.75, 0.75]:
		_box("concrete_flat", Vector3(sx, 0.22, 0), Vector3(0.12, 0.44, 0.5))
		_beam("steel_dark", Vector3(sx, 0.44, -0.2), Vector3(sx, 0.85, -0.3), 0.05)
	for k in 3:
		_box("wood", Vector3(0, 0.46, 0.16 - k * 0.15), Vector3(1.8, 0.04, 0.12))
	for k in 2:
		_box("wood", Vector3(0, 0.62 + k * 0.17, -0.27 - k * 0.02), Vector3(1.8, 0.12, 0.03), Vector3(-10, 0, 0))
	_pop()


## Swan-neck street lamp, h tall: tapered mast, orange hood leaning out over +Z.
func _lamp_post(p: Vector3, h: float) -> void:
	_push(_xf(p))
	_cyl("concrete_flat", Vector3.ZERO, 0.2, 0.18, 0.4, 8)
	_lathe("steel", Vector3(0, 0.4, 0), [Vector2(0.11, 0), Vector2(0.06, h - 0.8), Vector2(0, h - 0.8)], 8)
	var top := Vector3(0, h - 0.4, 0)
	var arc := [top + Vector3(0, -0.5, 0), top + Vector3(0, -0.1, 0.1), top + Vector3(0, 0.15, 0.4), top + Vector3(0, 0.2, 0.75)]
	for i in 3:
		_rod("steel", arc[i], arc[i + 1], 0.055, 6)
	var hood := top + Vector3(0, 0.15, 0.95)
	_lathe("signal_orange", hood, [Vector2(0.0, 0.12), Vector2(0.22, 0.08), Vector2(0.34, -0.06), Vector2(0.34, -0.1)], 12, Vector3(8, 0, 0), Vector3(1, 1, 1.4))
	_cyl("porthole_lit", hood + Vector3(0, -0.13, 0), 0.28, 0.28, 0.03, 12, Vector3(8, 0, 0), Vector3(1, 1, 1.4))
	_pop()


## A street poster board on two legs: the launch poster, lit at night.
func _poster_board(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	for sx in [-0.65, 0.65]:
		_rod("steel_dark", Vector3(sx, 0, 0), Vector3(sx, 2.4, 0), 0.04, 6)
	_box("night_blue", Vector3(0, 1.55, 0), Vector3(1.5, 1.7, 0.08))
	_quad("poster_launch", Vector3(-0.66, 2.32, 0.045), Vector3(0.66, 2.32, 0.045), Vector3(0.66, 0.78, 0.045), Vector3(-0.66, 0.78, 0.045), Vector3.BACK,
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_quad("poster_launch", Vector3(0.66, 2.32, -0.045), Vector3(-0.66, 2.32, -0.045), Vector3(-0.66, 0.78, -0.045), Vector3(0.66, 0.78, -0.045), Vector3.FORWARD,
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_box("signal_orange", Vector3(0, 2.44, 0), Vector3(1.6, 0.08, 0.2))
	_pop()


func _cafe_chair(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_rod("chrome", Vector3(c.x * 0.17, 0, c.y * 0.17), Vector3(c.x * 0.15, 0.44, c.y * 0.15), 0.015, 4)
	_box("enamel_coral", Vector3(0, 0.46, 0), Vector3(0.38, 0.04, 0.38))
	_box("enamel_coral", Vector3(0, 0.72, -0.18), Vector3(0.36, 0.3, 0.03), Vector3(-6, 0, 0))
	_pop()


# ================================================================== vehicles

func _vehicles() -> void:
	for spec in [["car", "enamel_turquoise"], ["car_coral", "enamel_coral"], ["car_mustard", "enamel_mustard"]]:
		_begin(spec[0])
		_car(spec[1])
		_save(spec[0])
	_begin("bus")
	_bus()
	_save("bus")
	_begin("truck")
	_truck(false)
	_save("truck")
	_begin("truck_tanker")
	_truck(true)
	_save("truck_tanker")


## Side profile (length along local X, front at -X) extruded `w` across: the friendly
## rounded shapes of mid-century vehicles. Front of the vehicle faces +Z.
func _profile(m: String, pts: Array, w: float) -> void:
	_push(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	_plate(m, pts, 0.0, w)
	_pop()


func _wheel4v(c: Vector3, r: float, w: float) -> void:
	_cyl("rubber", c + Vector3(-w * 0.5, 0, 0), r, r, w, 12, Vector3(0, 0, -90))
	var sx := signf(c.x)
	_cyl("chrome", c + Vector3(sx * w * 0.5, 0, 0), r * 0.55, r * 0.4, 0.03, 10, Vector3(0, 0, -90 * sx))
	_cyl("warm_white", c + Vector3(sx * (w * 0.5 - 0.005), 0, 0), r * 0.78, r * 0.78, 0.01, 12, Vector3(0, 0, -90 * sx))


## A rounded two-tone family saloon, 4.4 x 1.8, enamel body with a warm-white roof.
func _car(body: String) -> void:
	_profile(body, [Vector2(-2.2, 0.32), Vector2(-2.25, 0.62), Vector2(-2.05, 0.86), Vector2(-1.1, 0.95), Vector2(1.2, 0.95), Vector2(2.05, 0.88), Vector2(2.2, 0.6), Vector2(2.15, 0.32)], 1.76)
	_profile("glass_blue", [Vector2(-1.05, 0.94), Vector2(-0.6, 1.42), Vector2(0.75, 1.42), Vector2(1.25, 0.94)], 1.56)
	_profile("warm_white", [Vector2(-0.7, 1.4), Vector2(-0.6, 1.47), Vector2(0.78, 1.47), Vector2(0.85, 1.4)], 1.6)
	for sx in [-1.0, 1.0]:   # pillars and a chrome waistline
		_box("warm_white", Vector3(sx * 0.77, 1.18, 0.07), Vector3(0.04, 0.48, 0.1))
		_box("chrome", Vector3(sx * 0.885, 0.78, 0), Vector3(0.02, 0.04, 4.0))
		_box("warm_white", Vector3(sx * 0.885, 0.55, 0), Vector3(0.015, 0.12, 2.6))
	for sz in [-1.0, 1.0]:
		_box("chrome", Vector3(0, 0.38, sz * 2.22), Vector3(1.8, 0.12, 0.1))
		for sx in [-0.6, 0.6]:
			_cyl("porthole_lit" if sz > 0 else "signal_lamp", Vector3(sx, 0.68, sz * 2.2), 0.11, 0.11, 0.05, 10, Vector3(90 * sz, 0, 0))
	_box("chrome", Vector3(0, 0.6, 2.22), Vector3(0.7, 0.18, 0.04))
	for c in [Vector2(1, 1.35), Vector2(-1, 1.35), Vector2(1, -1.35), Vector2(-1, -1.35)]:
		_wheel4v(Vector3(c.x * 0.8, 0.34, c.y), 0.34, 0.24)


## The city bus: long, round-nosed, cream over turquoise with a ribbon of windows.
func _bus() -> void:
	_profile("enamel_turquoise", [Vector2(-5.0, 0.4), Vector2(-5.1, 1.2), Vector2(5.1, 1.2), Vector2(5.0, 0.4)], 2.4)
	_profile("warm_white", [Vector2(-5.1, 1.19), Vector2(-5.05, 2.75), Vector2(-4.7, 3.05), Vector2(4.8, 3.05), Vector2(5.1, 2.8), Vector2(5.1, 1.19)], 2.38)
	_box("glass_blue", Vector3(0, 2.15, 0), Vector3(2.42, 0.9, 9.4))
	_box("glass_blue", Vector3(0, 2.1, 5.05), Vector3(2.1, 1.1, 0.06))
	for i in 9:
		var z := -4.2 + i * 1.05
		for sx in [-1.0, 1.0]:
			_box("warm_white", Vector3(sx * 1.215, 2.15, z), Vector3(0.02, 0.92, 0.1))
	_box("signal_orange", Vector3(0, 1.25, 0), Vector3(2.44, 0.1, 10.2))
	_box("chrome", Vector3(0, 0.5, 5.15), Vector3(2.3, 0.18, 0.12))
	_box("night_blue", Vector3(0, 2.85, 5.1), Vector3(1.5, 0.26, 0.04))
	_box("glass_dark", Vector3(1.215, 1.6, 3.7), Vector3(0.03, 1.9, 1.0))   # door
	for sx in [-0.85, 0.85]:
		_cyl("porthole_lit", Vector3(sx, 0.85, 5.1), 0.13, 0.13, 0.05, 10, Vector3(90, 0, 0))
	_hand_badge(Vector3(1.22, 0.8, -0.5), 0.5, "warm_white", "")
	_hand_badge(Vector3(-1.22, 0.8, -0.5), 0.5, "warm_white", "")
	for c in [Vector2(1, 3.4), Vector2(-1, 3.4), Vector2(1, -3.2), Vector2(-1, -3.2)]:
		_wheel4v(Vector3(c.x * 1.05, 0.5, c.y), 0.5, 0.32)


## A round-cabbed lorry: flatbed with steel, or the tanker carrying rocket fuel.
func _truck(tanker: bool) -> void:
	_profile("signal_orange", [Vector2(-3.3, 0.5), Vector2(-3.35, 1.3), Vector2(-3.1, 1.6), Vector2(-2.3, 1.75), Vector2(-1.6, 2.6), Vector2(-0.9, 2.65), Vector2(-0.9, 0.5)], 2.2)
	_profile("glass_blue", [Vector2(-2.25, 1.76), Vector2(-1.65, 2.52), Vector2(-1.0, 2.52), Vector2(-1.0, 1.76)], 2.22)
	_box("chrome", Vector3(0, 0.6, 3.38), Vector3(2.1, 0.2, 0.1))
	for sx in [-0.8, 0.8]:
		_cyl("porthole_lit", Vector3(sx, 1.2, 3.33), 0.13, 0.13, 0.05, 10, Vector3(90, 0, 0))
	_box("steel_dark", Vector3(0, 0.75, -1.4), Vector3(1.6, 0.3, 5.4))
	if tanker:
		_cyl("chrome", Vector3(0, 1.85, -3.9), 1.0, 1.0, 4.6, 16, Vector3(90, 0, 0), Vector3(1, 1, 0.92))
		for z in [-3.85, 0.65]:
			_ball("chrome", Vector3(0, 1.85, z), 1.0, 14, 5, Vector3(1, 0.92, 0.25))
		_box("signal_orange", Vector3(0, 1.85, -1.6), Vector3(2.04, 0.4, 0.3))
		_hand_badge(Vector3(1.0, 1.85, -2.6), 0.6, "signal_orange", "night_blue")
		_hand_badge(Vector3(-1.0, 1.85, -2.6), 0.6, "signal_orange", "night_blue")
		_beam("steel_dark", Vector3(-0.3, 2.85, -3.4), Vector3(-0.3, 2.85, -0.3), 0.06)
	else:
		_box("planks", Vector3(0, 1.0, -1.6), Vector3(2.3, 0.12, 5.4))
		for sx in [-1.0, 1.0]:
			for z in [-3.8, -2.0, -0.2, 0.9]:
				_rod("steel_dark", Vector3(sx * 1.1, 1.05, z), Vector3(sx * 1.1, 1.6, z), 0.04, 4)
		_steel_pile(Vector3(0, 1.06, -1.6), 90.0, 4.6)
	for c in [Vector2(1, 2.1), Vector2(-1, 2.1), Vector2(1, -2.9), Vector2(-1, -2.9), Vector2(1, -1.8), Vector2(-1, -1.8)]:
		_wheel4v(Vector3(c.x * 0.98, 0.5, c.y), 0.5, 0.34)


# ================================================================== trains

func _trains() -> void:
	_begin("locomotive")
	_locomotive()
	_save("locomotive")
	for spec in [["rail_wagon", "coal"], ["rail_wagon_steel", "steel"], ["rail_wagon_tank", "tank"], ["rail_wagon_rocket", "rocket"]]:
		_begin(spec[0])
		_wagon(spec[1])
		_save(spec[0])
	_begin("passenger_coach")
	_coach()
	_save("passenger_coach")


## Bogies under a rail vehicle of length l (along Z), wheels on the 1.44 m gauge.
func _bogies(l: float) -> void:
	for sz in [-1.0, 1.0]:
		var z: float = sz * (l * 0.5 - 1.8)
		_box("steel_dark", Vector3(0, 0.75, z), Vector3(1.8, 0.3, 2.6))
		for dz in [-0.8, 0.8]:
			for sx in [-1.0, 1.0]:
				_cyl("steel_dark", Vector3(sx * 0.72 - 0.06, 0.88, z + dz), 0.45, 0.45, 0.12, 12, Vector3(0, 0, -90))
				_cyl("signal_orange", Vector3(sx * 0.72 + sx * 0.06, 0.88, z + dz), 0.2, 0.2, 0.02, 8, Vector3(0, 0, -90 * sx))
	for sz in [-1.0, 1.0]:
		_box("steel_dark", Vector3(0, 1.25, sz * l * 0.5), Vector3(0.4, 0.25, 0.4))


## The streamlined diesel: a rounded nose in signal orange with a warm-white stripe and
## the hand on its face, a long hood, louvres. 14 m along Z, the nose to +Z.
func _locomotive() -> void:
	var l := 14.0
	_bogies(l)
	_box("night_blue", Vector3(0, 1.35, 0), Vector3(2.8, 0.25, l))
	_push(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO))
	_plate("signal_orange", [Vector2(-7.0, 1.45), Vector2(-7.0, 4.2), Vector2(4.6, 4.2), Vector2(5.8, 3.9), Vector2(6.6, 3.1), Vector2(7.0, 2.2), Vector2(7.0, 1.45)], 0.0, 2.8)
	_plate("glass_blue", [Vector2(4.8, 3.2), Vector2(4.7, 4.0), Vector2(5.75, 3.82), Vector2(6.4, 3.15)], 0.0, 2.82)
	_pop()
	_lathe("signal_orange", Vector3(0, 4.2, -7.0), [Vector2(1.4, 0), Vector2(1.4, 11.6), Vector2(0, 11.6)], 12, Vector3(90, 0, 0), Vector3(1, 0.25, 1))
	for sx in [-1.0, 1.0]:
		_box("warm_white", Vector3(sx * 1.41, 2.35, 0), Vector3(0.02, 0.35, l))
		_box("chrome", Vector3(sx * 1.41, 2.6, 0), Vector3(0.02, 0.06, l))
		for i in 8:   # louvres
			_box("steel_dark", Vector3(sx * 1.41, 3.5, -5.6 + i * 1.2), Vector3(0.02, 0.6, 0.8))
		_porthole(Vector3(sx * 1.41, 3.3, 3.8), 0.32, "glass_blue")
	_hand_badge(Vector3(0, 2.25, 7.04), 0.9, "warm_white", "night_blue")
	_box("warm_white", Vector3(0, 2.35, 7.02), Vector3(2.4, 0.35, 0.02))
	for sx in [-0.85, 0.85]:
		_cyl("porthole_lit", Vector3(sx, 1.85, 7.0), 0.16, 0.16, 0.06, 10, Vector3(90, 0, 0))
	_box("chrome", Vector3(0, 1.4, 7.1), Vector3(2.6, 0.3, 0.2))
	_rod("chrome", Vector3(0.6, 4.45, 1.0), Vector3(0.6, 4.9, 1.0), 0.08, 6)
	_smokestack(Vector3(-0.4, 4.4, -3.0), 0.25, 0.22, 0.4, "steel_dark")


## Wagons, 10 m: coal hopper, flat with steel beams, fuel tank, and the well wagon
## carrying a rocket segment from the factory to the pad.
func _wagon(load_kind: String) -> void:
	var l := 10.0
	_bogies(l)
	_box("night_blue", Vector3(0, 1.35, 0), Vector3(2.7, 0.25, l))
	match load_kind:
		"coal":
			_box("steel_dark", Vector3(0, 2.5, 0), Vector3(2.8, 2.1, l - 0.4))
			_box("coal", Vector3(0, 3.5, 0), Vector3(2.7, 0.12, l - 0.5))
			for i in 6:
				_box("steel", Vector3(1.41, 2.5, -4.2 + i * 1.7), Vector3(0.04, 2.1, 0.12))
				_box("steel", Vector3(-1.41, 2.5, -4.2 + i * 1.7), Vector3(0.04, 2.1, 0.12))
			for i in 30:
				_ball("coal", Vector3(_rng.randf_range(-1.1, 1.1), 3.5, _rng.randf_range(-4.4, 4.4)), _rng.randf_range(0.3, 0.5), 5, 3, Vector3(1, 0.6, 1))
		"steel":
			_box("planks", Vector3(0, 1.52, 0), Vector3(2.7, 0.1, l))
			for sz in [-3.0, 3.0]:
				_steel_pile(Vector3(0, 1.57, sz), 90.0, 3.8)
			for z in [-4.6, -1.5, 1.5, 4.6]:
				for sx in [-1.0, 1.0]:
					_rod("signal_orange", Vector3(sx * 1.3, 1.5, z), Vector3(sx * 1.3, 2.4, z), 0.05, 4)
		"tank":
			_cyl("warm_white", Vector3(0, 2.6, -4.3), 1.25, 1.25, 8.6, 16, Vector3(90, 0, 0))
			for z in [-4.3, 4.3]:
				_ball("warm_white", Vector3(0, 2.6, z), 1.25, 16, 5, Vector3(1, 1, 0.25))
			_box("signal_orange", Vector3(0, 2.6, 0), Vector3(2.54, 2.54, 0.6))
			_cyl("steel_dark", Vector3(0, 3.8, 0), 0.4, 0.4, 0.35, 10)
			_box("frost", Vector3(0, 2.6, -2.5), Vector3(2.52, 0.4, 2.0))
		"rocket":
			_box("steel_dark", Vector3(0, 1.0, 0), Vector3(2.7, 0.4, l - 2.0))
			for z in [-3.0, 3.0]:
				_slab("signal_orange", [Vector3(-1.4, 1.5, z - 0.3), Vector3(1.4, 1.5, z - 0.3), Vector3(1.4, 1.5, z + 0.3), Vector3(-1.4, 1.5, z + 0.3)], 0.25, Vector3.UP)
				for sx in [-1.0, 1.0]:
					_beam("signal_orange", Vector3(sx * 1.35, 1.5, z), Vector3(sx * 1.0, 2.7, z), 0.18)
			# the tank segment lying on its side, wrapped against the weather by a band
			_push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 3.1, 0)))
			_rocket_seg(1, SEG_Y[1] + 2.7, false)
			_pop()
			_cyl("night_blue", Vector3(0, 3.1, -2.68), 1.5, 1.5, 5.36, 16, Vector3(90, 0, 0))
			for z in [-1.0, 1.4]:
				_rod("rubber", Vector3(-1.6, 1.5, z), Vector3(1.6, 1.5, z), 0.04, 4)
	for sz in [-1.0, 1.0]:
		_box("chrome", Vector3(0, 1.35, sz * (l * 0.5 + 0.15)), Vector3(0.5, 0.2, 0.3))


## A passenger coach in the line's livery: cream over turquoise, a long window ribbon.
func _coach() -> void:
	var l := 16.0
	_bogies(l)
	_box("enamel_turquoise", Vector3(0, 2.0, 0), Vector3(2.8, 1.3, l))
	_box("warm_white", Vector3(0, 3.35, 0), Vector3(2.8, 1.4, l))
	_lathe("steel", Vector3(0, 4.05, -l * 0.5), [Vector2(1.4, 0), Vector2(1.4, l), Vector2(0, l)], 12, Vector3(90, 0, 0), Vector3(1, 0.22, 1))
	_box("signal_orange", Vector3(0, 2.68, 0), Vector3(2.82, 0.08, l))
	for sx in [-1.0, 1.0]:
		_push(Transform3D(Basis(Vector3.UP, PI * 0.5 * sx), Vector3(sx * 1.4, 0, 0)))
		_ribbon(-l * 0.5 + 1.6, l * 0.5 - 1.6, 2.85, 1.0, 1.3, "chrome", 0.7)
		for sz in [-1.0, 1.0]:
			_box("glass_dark", Vector3(sz * (l * 0.5 - 0.8), 2.45, 0.02), Vector3(0.9, 2.1, 0.04))
		_pop()
	for sz in [-1.0, 1.0]:
		_box("night_blue", Vector3(0, 2.6, sz * l * 0.5), Vector3(1.6, 2.6, 0.12))


# ================================================================== resource piles

func _piles4() -> void:
	_begin("steel_beams")
	_steel_pile(Vector3.ZERO, 0.0, 4.0)
	_save("steel_beams")
	_begin("parts_crates")
	_parts_crates(Vector3.ZERO, 0.0)
	_save("parts_crates")
	_begin("fuel_tanks")   # pressure bottles for the rocket's fuel: warm white, frost-banded, on a cradle
	for i in 3:
		var p := Vector3(-1.1 + i * 1.1, 0, 0)
		_box("steel_dark", p + Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 2.6))
		_cyl("warm_white", p + Vector3(0, 0.75, -1.2), 0.45, 0.45, 2.4, 12, Vector3(90, 0, 0))
		for z in [-1.2, 1.2]:
			_ball("warm_white", p + Vector3(0, 0.75, z), 0.45, 12, 4, Vector3(1, 1, 0.35))
		_box("signal_orange", p + Vector3(0, 0.75, 0.0), Vector3(0.92, 0.92, 0.18))
		_cyl("chrome", p + Vector3(0, 0.75, 1.32), 0.08, 0.06, 0.18, 6, Vector3(90, 0, 0))
	_cyl("warm_white", Vector3(-0.55, 1.3, -1.2), 0.42, 0.42, 2.4, 12, Vector3(90, 0, 0))
	_box("signal_orange", Vector3(-0.55, 1.3, 0.0), Vector3(0.86, 0.86, 0.18))
	_save("fuel_tanks")
	_begin("coal_pile")
	_coal_heap(Vector3.ZERO, 1.0)
	_save("coal_pile")
	_begin("oil_drums")
	_box("planks", Vector3(0, 0.07, 0), Vector3(1.4, 0.14, 1.4))
	var dm := ["enamel_turquoise", "signal_orange", "enamel_turquoise", "night_blue"]
	for k in 4:
		_oil_drum(Vector3(-0.33 + (k % 2) * 0.66, 0.14, -0.33 + (k / 2) * 0.66), dm[k])
	_oil_drum(Vector3(0.0, 1.03, 0.0), "signal_orange")
	_oil_drum(Vector3(1.3, 0, 0.5), "night_blue")
	_push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, 0.4), Vector3(-1.4, 0.3, 0.5)))
	_oil_drum(Vector3(0, -0.44, 0), "enamel_turquoise")
	_pop()
	_save("oil_drums")
	_begin("cable_drum")
	_push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.85, 0)))
	_lathe("wood", Vector3(0, -0.55, 0), [Vector2(0, 0), Vector2(0.85, 0), Vector2(0.85, 0.08), Vector2(0.5, 0.08), Vector2(0.5, 1.02), Vector2(0.85, 1.02), Vector2(0.85, 1.1), Vector2(0, 1.1)], 14)
	_cyl("cloth_navy", Vector3(0, -0.47, 0), 0.68, 0.68, 0.94, 14)
	_cyl("steel_dark", Vector3(0, -0.6, 0), 0.12, 0.12, 1.2, 8)
	_pop()
	_rod("cloth_navy", Vector3(0.3, 1.4, 0.2), Vector3(1.3, 0.05, 0.6), 0.05, 5)
	_save("cable_drum")
	for spec in [["shipping_container", "a"], ["shipping_container_b", "b"], ["shipping_container_c", "c"]]:
		_begin(spec[0])
		_model(IND + "shipping-container-%s.glb" % spec[1], Vector3.ZERO, Vector3.ZERO, 7.0, null, KIND)
		_save(spec[0])


## Crates of machined parts from the works: stencilled boxes on a pallet, a canvas cover.
func _parts_crates(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	_box("planks", Vector3(0, 0.08, 0), Vector3(2.2, 0.16, 1.4))
	var spots := [[Vector3(-0.55, 0.16, 0), Vector3(1.0, 0.8, 1.2), "wood"], [Vector3(0.55, 0.16, 0.05), Vector3(1.0, 0.7, 1.2), "wood"],
		[Vector3(-0.4, 0.96, 0.0), Vector3(0.8, 0.6, 1.0), "enamel_mint"]]
	for s in spots:
		var c: Vector3 = s[0]
		var sz: Vector3 = s[1]
		_box(s[2], c + Vector3(0, sz.y * 0.5, 0), sz)
		_box("steel_dark", c + Vector3(0, sz.y * 0.5, 0), sz + Vector3(0.02, -sz.y * 0.75, 0.02))
		_box("signal_orange", c + Vector3(0, sz.y * 0.5, sz.z * 0.5 + 0.01), Vector3(sz.x * 0.5, sz.y * 0.3, 0.01))
	_cyl("chrome", Vector3(0.45, 0.86, 0.1), 0.18, 0.18, 0.35, 10)
	_cyl("chrome", Vector3(0.8, 0.86, -0.3), 0.12, 0.12, 0.5, 10)
	_slab("canvas_orange", [Vector3(0.05, 1.12, -0.6), Vector3(1.1, 0.9, -0.6), Vector3(1.1, 0.9, 0.6), Vector3(0.05, 1.12, 0.6)], 0.02, Vector3.UP)
	_pop()


func _oil_drum(p: Vector3, m: String) -> void:
	_cyl(m, p, 0.29, 0.29, 0.88, 12)
	for y in [0.3, 0.6]:
		_cyl("steel_dark", p + Vector3(0, y, 0), 0.3, 0.3, 0.03, 12)
	_cyl("chrome", p + Vector3(0.12, 0.88, 0), 0.04, 0.04, 0.02, 6)


# ================================================================== resource nodes

func _nodes4() -> void:
	# a coal seam: a dark band showing in a cut bank with a few lumps at its foot
	_begin("coal_seam")
	var tint := {"hog_pull": 0.2, "hog_tint": Color("#bfb3a0")}
	_model(N + "Rock_6.fbx", Vector3(-2.7, 0, -0.5), Vector3(0, 30, 0), Vector3(1.1, 1.2, 1.0), null, tint)
	_model(N + "Rock_4.fbx", Vector3(2.9, 0, -0.3), Vector3(0, 110, 0), Vector3(0.9, 1.0, 0.9), null, tint)
	# the cut bank: earth, the seam showing as a dark band, turf on top
	_box("soil", Vector3(0.1, 0.8, -0.7), Vector3(4.8, 1.6, 1.4), Vector3(0, 0, 2))
	_box("coal", Vector3(0.1, 0.85, -0.68), Vector3(4.84, 0.45, 1.44), Vector3(0, 0, 2))
	_box("soil_dark", Vector3(0.1, 0.35, -0.67), Vector3(4.86, 0.12, 1.46), Vector3(0, 0, 2))
	_box("turf", Vector3(0.1, 1.63, -0.7), Vector3(4.9, 0.08, 1.5), Vector3(0, 0, 2))
	_slab("soil", [Vector3(-2.3, 0.0, 0.0), Vector3(2.5, 0.0, 0.0), Vector3(2.5, 0.0, 0.9), Vector3(-2.3, 0.0, 0.9)], 0.02, Vector3.UP)
	for i in 14:
		_ball("coal", Vector3(_rng.randf_range(-1.6, 1.8), 0.1, _rng.randf_range(0.6, 1.6)), _rng.randf_range(0.12, 0.26), 5, 3, Vector3(1, 0.7, 1),
			Vector3(_rng.randf() * 40, _rng.randf() * 90, 0))
	_save("coal_seam")
	# an oil seep: a dark pool welling up among rocks, a slick sheen, a survey stake
	_begin("oil_seep")
	_model(N + "Rock_3.fbx", Vector3(-1.3, 0, -0.4), Vector3(0, 60, 0), 1.0, null, tint)
	_model(N + "Rock_2.fbx", Vector3(1.2, 0, -0.7), Vector3(0, 10, 0), 0.8, null, tint)
	_cyl("soil_dark", Vector3(0, 0.0, 0), 1.6, 1.4, 0.06, 14)
	_cyl("coal", Vector3(0.1, 0.06, 0.1), 1.0, 1.0, 0.015, 14, Vector3.ZERO, Vector3(1.0, 1, 0.7))
	_cyl("glass_blue", Vector3(0.3, 0.075, 0.0), 0.35, 0.35, 0.005, 10, Vector3.ZERO, Vector3(1.4, 1, 0.6))
	_rod("wood", Vector3(1.4, 0, 0.8), Vector3(1.4, 1.2, 0.8), 0.04, 4)
	_box("signal_orange", Vector3(1.4, 1.05, 0.8), Vector3(0.1, 0.2, 0.1))
	_save("oil_seep")


# ================================================================== tools (steel)

func _tools4() -> void:
	_begin("tool_wrench")   # the open-ended spanner, chrome with an orange grip
	_beam("chrome", Vector3(0, 0, 0), Vector3(0, 0.42, 0), 0.04, 0.015)
	_box("signal_orange", Vector3(0, 0.12, 0), Vector3(0.05, 0.22, 0.025))
	_plate("chrome", [Vector2(-0.05, 0.42), Vector2(0.05, 0.42), Vector2(0.06, 0.48), Vector2(0.02, 0.5), Vector2(0.015, 0.46), Vector2(-0.015, 0.46), Vector2(-0.02, 0.5), Vector2(-0.06, 0.48)], 0.0, 0.016)
	_save("tool_wrench")
	_begin("tool_toolbox")
	_box("signal_orange", Vector3(0, 0.12, 0), Vector3(0.5, 0.24, 0.22))
	_slab("signal_orange", [Vector3(-0.25, 0.24, -0.11), Vector3(0.25, 0.24, -0.11), Vector3(0.25, 0.24, 0.11), Vector3(-0.25, 0.24, 0.11)], 0.04, Vector3.UP)
	for sx in [-0.12, 0.12]:
		_rod("chrome", Vector3(sx, 0.28, 0), Vector3(sx, 0.36, 0), 0.008, 4)
	_rod("chrome", Vector3(-0.12, 0.36, 0), Vector3(0.12, 0.36, 0), 0.012, 5)
	_box("chrome", Vector3(0, 0.22, 0.112), Vector3(0.05, 0.04, 0.01))
	_save("tool_toolbox")
	_begin("tool_clipboard")   # the engineer's and flight controller's clipboard
	_box("wood", Vector3(0, 0.18, 0), Vector3(0.24, 0.34, 0.012))
	_box("paper", Vector3(0, 0.17, 0.008), Vector3(0.21, 0.29, 0.004))
	_box("chrome", Vector3(0, 0.34, 0.012), Vector3(0.09, 0.03, 0.012))
	for k in 6:
		_box("night_blue", Vector3(-0.01, 0.28 - k * 0.04, 0.011), Vector3(0.15 - (k % 2) * 0.04, 0.006, 0.002))
	_save("tool_clipboard")
	_begin("tool_welder")   # a welding torch with its hose, and the mask
	_rod("chrome", Vector3(0, 0, 0), Vector3(0, 0.28, 0), 0.018, 6)
	_rod("chrome", Vector3(0, 0.28, 0), Vector3(0, 0.36, 0.05), 0.01, 5)
	_cyl("signal_orange", Vector3(0, 0.05, 0), 0.022, 0.022, 0.12, 6)
	_rod("rubber", Vector3(0, 0, 0), Vector3(0.1, -0.02, -0.15), 0.015, 4)
	_save("tool_welder")


# ================================================================== gifts (DESIGN 7: Era 4 gifts)

func _gifts4() -> void:
	_begin("gift_model_rocket")   # a child's tin model of the rocket on a little stand
	_push(_xf(Vector3(0, 0.03, 0), 0.0, 0.025))
	_rocket_seg(0, 0.0, false)
	_rocket_seg(1, 0.0, false)
	_rocket_seg(2, 0.0, false)
	_pop()
	_cyl("wood_dark", Vector3.ZERO, 0.12, 0.12, 0.03, 12)
	_save("gift_model_rocket")
	_begin("gift_photograph")   # a framed photograph of the village propped on its stand
	_box("wood_dark", Vector3(0, 0.13, 0), Vector3(0.24, 0.19, 0.015), Vector3(-12, 0, 0))
	_box("paper", Vector3(0, 0.13, 0.009), Vector3(0.2, 0.15, 0.004), Vector3(-12, 0, 0))
	_box("concrete_dark", Vector3(0, 0.13, 0.011), Vector3(0.18, 0.13, 0.002), Vector3(-12, 0, 0))
	_box("warm_white", Vector3(0, 0.1, 0.013), Vector3(0.18, 0.06, 0.002), Vector3(-12, 0, 0))
	_box("wood_dark", Vector3(0, 0.08, -0.06), Vector3(0.03, 0.16, 0.01), Vector3(25, 0, 0))
	_save("gift_photograph")


## The merged AABB of the meshes under n so far (pack models only: geometry not yet flushed).
func _aabb_of(n: Node, xf := Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is VisualInstance3D:
		out = t * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb_of(c, t)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out
