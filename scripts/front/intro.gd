class_name IntroSequence extends Node
## The opening (about 62 s, skippable), played on New Game over the real
## valley before the storm night. The god's point of view, in its own voice:
##   0-24   the valley is quiet and wild at dusk; the camera glides down from
##          high over the forest while the storm gathers and night falls
##  24-35   close on the two of them, cowering in the rain under the cliff
##  35-45   the hand comes down out of the storm, glowing; they flinch, cower
##          and back away. The hand stops, and draws back
##  45-62   the hand waits, opens, then points at the fallen branch; the
##          camera rises into the play camera, and the storm night begins
## Lines are short, in IM Fell English, on cinema bars. Music is
## assets/audio/music/intro.ogg (tools/music/front.py), cued to these times.
## Esc skips at once; any other key or a click asks once ("again to skip").
## The world is left exactly as World.new_game() made it: storm night, rain,
## the two outside the cave, the branch glowing. Then `finished` is emitted
## and the menu calls World.start_play().

signal finished

const LENGTH := 62.0
const MUSIC := "res://assets/audio/music/intro.ogg"
const RAIN := "res://assets/audio/sfx/rain_loop.ogg"
const WIND := "res://assets/audio/sfx/wind_loop.ogg"
const HAND_SCENE := preload("res://scenes/hand/hand_model.tscn")
const HAND_LEN := 9.0
const BAR_H := 92.0
const CREAM := Color("#f4e6c8")
const WARM := Color(1.0, 0.72, 0.4)

## [from, to, text] in seconds. The god speaks: gentle, a little wry, humble.
const LINES := [
	[2.0, 7.4, "For a long age, my valley was only wild."],
	[8.2, 13.6, "Rivers, wolves and weather. It never needed me."],
	[17.2, 22.8, "Then, on a night of storm, I noticed them."],
	[26.0, 31.6, "Two of them. Small, soaked, and frightened."],
	[39.8, 44.2, "Mostly of me."],
	[45.8, 50.6, "I want only good things for them."],
	[51.2, 56.4, "But I am not all-powerful. I cannot carry their burdens for them."],
	[57.0, 61.8, "I can only show them the way."],
]

var world: Node = null
var t: float = 0.0
var playing: bool = false
var done: bool = false
var skipped: bool = false
var cam: Camera3D
var hand: Node3D
var light: OmniLight3D
var fill: OmniLight3D           # a faint cool fill so the close shots read at night
var people: Array = []
var _home: Array = []           # each person's starting position
var _mid: Vector3
var _branch: Vector3
var _end_xf: Transform3D        # the play camera, where the intro lands
var _end_fov: float = 45.0
var _dof: CameraAttributesPractical
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
var _hint: Label
var _dip: ColorRect
var _music: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _skip_armed: float = 0.0
var _flinched: bool = false
var _line_i: int = -1
var _shot: int = -1
var rate: float = 1.0           # tests run it faster

func _init() -> void:
	name = "Intro"
	process_mode = Node.PROCESS_MODE_ALWAYS

## Starts the intro over `w` (a world fresh from new_game()).
func begin(w: Node) -> void:
	world = w
	playing = true
	t = 0.0
	Clock.running = false
	people = []
	if w.storm != null:
		people = w.storm.people.filter(func(p): return p != null and is_instance_valid(p))
	if people.is_empty():
		people = Village.alive().slice(0, 2)
	_mid = Vector3.ZERO
	for p in people:
		_home.append(p.global_position)
		_mid += p.global_position
		p.set_physics_process(false)          # the intro poses them; their AI waits
	_mid = _mid / maxf(people.size(), 1) if not people.is_empty() else Vector3(0, w.ground_y(0, -24.3), -24.3)
	_branch = w.branch.global_position if w.get(&"branch") != null else _mid + Vector3(0, 0, -2.6)
	_find_end_camera()
	_build_camera()
	_build_hand()
	_build_overlay()
	_build_audio()
	# dusk before the storm: clear, late in the day
	Clock.is_night = false
	Clock.phase_t = 0.86 * Clock.day_seconds
	w.look.set_weather(0.0, false)
	w.look.update_now()
	_pose_people(&"sit", true)
	_set_hint(false)
	Audio.fade_title(2.5)
	_update(0.0)

func _find_end_camera() -> void:
	var rc: Camera3D = null
	var rig = world.get(&"camera_rig")
	if rig is Camera3D:
		rc = rig
	elif rig != null:
		rc = rig.get(&"camera") as Camera3D
	if rc != null:
		_end_xf = rc.global_transform
		_end_fov = rc.fov
	else:
		var c := Camera3D.new()
		world.add_child(c)
		world.frame_camera(c, Vector3(0, world.ground_y(0, -15), -15), 28.0, 0.0)
		_end_xf = c.global_transform
		c.queue_free()

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.name = "IntroCamera"
	cam.near = 0.2
	cam.far = 1500.0
	_dof = CameraAttributesPractical.new()
	_dof.dof_blur_amount = 0.0
	_dof.dof_blur_far_enabled = true
	_dof.dof_blur_near_enabled = true
	_dof.dof_blur_far_distance = 28.0 * 1.45
	_dof.dof_blur_far_transition = 28.0 * 1.6
	_dof.dof_blur_near_distance = 28.0 * 0.45
	_dof.dof_blur_near_transition = 28.0 * 0.3
	cam.attributes = _dof
	world.add_child(cam)
	cam.current = true

func _build_hand() -> void:
	hand = HAND_SCENE.instantiate()
	hand.name = "IntroHand"
	hand.top_level = true
	world.add_child(hand)
	hand.visible = false
	light = OmniLight3D.new()
	light.name = "IntroHandLight"
	light.light_color = WARM
	light.omni_range = 16.0
	light.light_energy = 0.0
	light.shadow_enabled = true
	world.add_child(light)
	fill = OmniLight3D.new()
	fill.name = "IntroFill"
	fill.light_color = Color(0.55, 0.65, 1.0)
	fill.omni_range = 14.0
	fill.light_energy = 0.0
	world.add_child(fill)

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 18
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_top = ColorRect.new()
	_top.color = Color(0.02, 0.015, 0.012)
	_top.anchor_right = 1.0
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top)
	_bottom = ColorRect.new()
	_bottom.color = _top.color
	_bottom.anchor_top = 1.0
	_bottom.anchor_right = 1.0
	_bottom.anchor_bottom = 1.0
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bottom)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.anchor_top = 1.0
	_caption.anchor_right = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -BAR_H - 70.0
	_caption.offset_bottom = -BAR_H * 0.5 + 20.0
	_caption.add_theme_font_override(&"font", UiTheme.font(&"title"))
	_caption.add_theme_font_size_override(&"font_size", 38)
	_caption.add_theme_color_override(&"font_color", CREAM)
	_caption.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.85))
	_caption.add_theme_constant_override(&"shadow_offset_x", 0)
	_caption.add_theme_constant_override(&"shadow_offset_y", 2)
	_caption.add_theme_constant_override(&"shadow_outline_size", 10)
	_caption.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.02, 0.6))
	_caption.add_theme_constant_override(&"outline_size", 4)
	_caption.modulate.a = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_caption)
	_hint = Label.new()
	_hint.text = "Press again to skip"
	_hint.anchor_left = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -320.0
	_hint.offset_right = -36.0
	_hint.offset_top = -BAR_H * 0.5 - 14.0
	_hint.offset_bottom = -BAR_H * 0.5 + 14.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_override(&"font", UiTheme.font(&"italic"))
	_hint.add_theme_font_size_override(&"font_size", 18)
	_hint.add_theme_color_override(&"font_color", Color(CREAM, 0.7))
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	_dip = ColorRect.new()
	_dip.color = Color(0, 0, 0, 1)
	_dip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dip)

func _build_audio() -> void:
	_music = _player(MUSIC, Audio.music_db)
	_rain = _player(RAIN, -80.0)
	_wind = _player(WIND, -80.0)
	for p in [_music, _rain, _wind]:
		if p.stream != null:
			p.play()

func _player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.stream = load(path) if ResourceLoader.exists(path) else null
	p.volume_db = db
	add_child(p)
	return p

# ---------------------------------------------------------------- the timeline

func _process(delta: float) -> void:
	if done or not playing:
		return
	# real time: the game speed (Engine.time_scale) must not stretch the intro
	var dt := Clock.real_delta if Clock.real_delta > 0.0 else delta
	t += dt * rate
	_skip_armed = maxf(_skip_armed - dt, 0.0)
	_hint.modulate.a = clampf(_skip_armed * 2.0, 0.0, 1.0)
	_update(dt)
	if t >= LENGTH:
		_finish()

static func ss(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)

static func bez(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float) -> Vector3:
	var v := 1.0 - u
	return a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u

func _gy(x: float, z: float) -> float:
	return world.ground_y(x, z)

func _update(delta: float) -> void:
	_sky(delta)
	_camera()
	_hand_and_people(delta)
	_people_react()
	_overlay()
	_sound()

## Dusk into a storm night: the day ends over 0-20 s, the rain comes at 12 s.
func _sky(_delta: float) -> void:
	if t < 20.0:
		Clock.is_night = false
		Clock.phase_t = lerpf(0.86, 0.997, ss(0.0, 20.0, t)) * Clock.day_seconds
	else:
		Clock.is_night = true
		Clock.phase_t = 0.0
	if t >= 12.0 and not world.look.storm:
		world.look.set_weather(1.0, true)

func _camera() -> void:
	var m := _mid
	var pos: Vector3
	var look: Vector3
	var fov := 50.0
	var shot := 0
	if t < 24.0:
		# the wild valley, then down toward the cliff as the storm comes
		var u := ss(0.0, 24.0, t)
		var a := Vector3(-150.0, _gy(-150.0, 170.0) + 95.0, 170.0)
		var b := Vector3(-70.0, _gy(-70.0, 110.0) + 70.0, 110.0)
		var c := Vector3(26.0, m.y + 34.0, 46.0)
		var d := m + Vector3(13.0, 9.0, 22.0)
		pos = bez(a, b, c, d, u)
		look = Vector3(-14.0, m.y - 6.0, -50.0).lerp(m + Vector3(0, 1.5, -2.0), ss(0.0, 24.0, t))
		fov = lerpf(55.0, 46.0, u)
	elif t < 35.0:
		# close on the two, huddled in the rain
		shot = 1
		var u := ss(24.0, 35.0, t)
		pos = (m + Vector3(2.6, 2.6, 7.8)).lerp(m + Vector3(1.4, 1.9, 5.0), u)
		look = (m + Vector3(0, 0.7, -0.6)).lerp(m + Vector3(0, 0.9, -0.8), u)
		fov = 40.0
	elif t < 45.0:
		# low, looking up past them at the hand coming down
		shot = 2
		var u := ss(35.0, 45.0, t)
		pos = (m + Vector3(4.8, 1.7, 9.8)).lerp(m + Vector3(4.2, 1.9, 10.6), u)
		look = (m + Vector3(0.0, 4.2, -2.8)).lerp(m + Vector3(0.0, 3.8, -2.4), u)
		fov = 58.0
	else:
		# up and back into the play camera
		shot = 3
		var u := ss(45.5, 60.5, t)
		var s0 := m + Vector3(4.2, 1.9, 10.6)
		var l0 := m + Vector3(0.0, 3.8, -2.4)
		var end_look := _end_xf.origin - _end_xf.basis.z * 28.0
		pos = bez(s0, s0 + Vector3(2.0, 6.0, 8.0), _end_xf.origin + Vector3(4.0, -4.0, 2.0), _end_xf.origin, u)
		look = l0.lerp(end_look, ss(45.5, 58.0, t))
		fov = lerpf(58.0, _end_fov, u)
	if shot != _shot:
		_shot = shot
	cam.fov = fov
	if t >= 60.5:
		cam.global_transform = _end_xf
		cam.fov = _end_fov
	else:
		cam.global_position = pos
		if pos.distance_to(look) > 0.01:
			cam.look_at(look, Vector3.UP)
	fill.global_position = cam.global_position.lerp(_mid, 0.4) + Vector3(0, 2.5, 0)
	fill.light_energy = 2.2 * ss(23.5, 24.5, t) * (1.0 - ss(34.0, 36.0, t))
	# the play camera's soft tilt-shift comes in as we arrive
	_dof.dof_blur_amount = 0.06 * ss(56.0, 61.0, t)

func _hand_and_people(_delta: float) -> void:
	var m := _mid
	var vis := t >= 34.0
	hand.visible = vis
	if not vis:
		light.light_energy = 0.0
		return
	var fingers := Vector3(0.0, -0.74, 0.67)
	var back := Vector3(0.0, 0.67, 0.74)
	var wrist: Vector3
	var curl := PackedFloat32Array([0.15, 0.1, 0.12, 0.18, 0.25])
	var spread := 0.5
	var point := 0.0
	var glow := 1.2
	var solid := 1.0
	var br := 0.06 * sin(t * 1.4)
	if t < 38.6:
		# out of the storm: down from high above the cliff
		var u := ss(34.0, 38.6, t)
		wrist = (m + Vector3(0.0, 44.0, -16.0)).lerp(m + Vector3(0.0, 10.2, -7.0), u)
		curl = PackedFloat32Array([-0.1, -0.3, -0.3, -0.25, -0.2])
		spread = 0.9
		glow = lerpf(2.4, 1.6, u)
	elif t < 39.6:
		# a reach toward them: too close, too bright
		var u := sin(clampf((t - 38.6) / 1.0, 0.0, 1.0) * PI)
		wrist = m + Vector3(0.0, 10.2, -7.0) + fingers * 1.6 * u
		curl = PackedFloat32Array([-0.1, -0.35, -0.35, -0.3, -0.2])
		spread = 1.0
		glow = 1.6 + 1.2 * u
	elif t < 45.0:
		# it stops, and draws back, fingers folding in a little
		var u := ss(39.6, 44.5, t)
		wrist = (m + Vector3(0.0, 10.2, -7.0)).lerp(m + Vector3(1.0, 12.5, -8.5), u)
		curl = PackedFloat32Array([0.2 + 0.3 * u, 0.15 + 0.35 * u, 0.2 + 0.35 * u, 0.25 + 0.35 * u, 0.3 + 0.35 * u])
		spread = lerpf(1.0, 0.2, u)
		glow = lerpf(1.6, 0.7, u)
	elif t < 55.5:
		# waits, then opens: gentle, palm toward them
		var u := ss(45.0, 52.0, t)
		wrist = m + Vector3(1.0, 12.5, -8.5) + Vector3(0, sin(t * 0.8) * 0.3, 0)
		var c := lerpf(0.5, 0.0, u)
		curl = PackedFloat32Array([c, c * 0.8, c, c, c + 0.05])
		spread = lerpf(0.2, 1.0, u)
		glow = lerpf(0.7, 1.1, u)
		fingers = fingers.slerp(Vector3(0.0, -0.45, 0.89), u)
		back = back.slerp(Vector3(0.0, 0.89, 0.45), u)
	else:
		# shows the way: points at the fallen branch across the cave mouth
		var u := ss(55.5, 58.5, t)
		var w0 := m + Vector3(1.0, 12.5, -8.5)
		var w1 := _branch + Vector3(3.2, 9.5, 2.0)
		wrist = w0.lerp(w1, u)
		var tip_goal := _branch + Vector3(0, 1.4, 0)
		var aim := (tip_goal - wrist).normalized()
		fingers = Vector3(0.0, -0.45, 0.89).slerp(aim, u).normalized()
		back = Vector3(0.0, 0.89, 0.45).slerp(Vector3.UP - aim * aim.y, u).normalized()
		point = u
		curl = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
		spread = lerpf(1.0, 0.0, u)
		glow = lerpf(1.1, 1.5, u) + 0.3 * sin(t * 4.0) * u
		solid = 1.0 - ss(60.6, 61.8, t)
	for i in 5:
		curl[i] += br
	TitleStage.place(hand, wrist, fingers, back, HAND_LEN)
	hand.set_pose(curl, 0.0, point, spread)
	hand.set_look(solid, solid, glow, WARM)
	var palm: Vector3 = hand.global_transform * Vector3(0, -0.15, -0.5)
	light.global_position = palm
	light.light_energy = clampf(glow, 0.0, 3.0) * 1.2 * solid

## They huddle; they stand and stare as the light comes; at the reach they
## flinch, cover their heads and back away; later they peek and creep back.
func _people_react() -> void:
	var hp := hand.global_position
	if t < 24.0:
		_pose_people(&"sit")
	elif t < 36.2:
		_pose_people(&"cower")          # huddled against the storm
	elif t < 38.6:
		_pose_people(&"idle", false, hp)
	elif t < 52.5:
		if not _flinched:
			_flinched = true
			_flinch()
		_pose_people(&"cower", false, hp)
	elif t < 57.5:
		_pose_people(&"walk", false, hp)
		var u := ss(52.5, 57.0, t)
		for i in people.size():
			var p = people[i]
			if is_instance_valid(p):
				var away: Vector3 = p.get_meta(&"intro_away", _home[i])
				p.global_position = away.lerp(_home[i], u)
	else:
		_pose_people(&"idle", false, hp)

func _flinch() -> void:
	var hp := hand.global_position
	for i in people.size():
		var p = people[i]
		if not is_instance_valid(p):
			continue
		var d: Vector3 = p.global_position - hp
		d.y = 0.0
		d = d.normalized() if d.length() > 0.01 else Vector3(0, 0, 1)
		d = (d + Vector3((i - 0.5) * 0.8, 0, 0)).normalized()
		var to: Vector3 = _home[i] + d * 1.3
		to.y = _gy(to.x, to.z)
		p.set_meta(&"intro_away", to)
		var tw: Tween = p.create_tween()
		tw.tween_property(p, "global_position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Audio.voice(p, &"worry")
	# a crack of lightning with the reach
	var lk = world.look
	if lk != null and &"_flash_t" in lk:
		# short and dim: a flicker at the edge of the storm, so the night holds
		lk.set(&"_flash_t", maxf(float(lk.get(&"_flash_t")), 0.1))

## Plays `state` on each person's villager and turns them toward `face`
## (or toward each other while they huddle).
func _pose_people(state: StringName, instant: bool = false, face: Vector3 = Vector3.INF) -> void:
	for i in people.size():
		var p = people[i]
		if not is_instance_valid(p) or p.get(&"visual") == null:
			continue
		var v = p.visual.get(&"villager")
		if v == null:
			continue
		v.play(state, 0.0 if instant else 0.25)
		var target := face
		if target == Vector3.INF:
			var other = people[1 - i] if people.size() > 1 else null
			target = other.global_position if other != null and is_instance_valid(other) else _mid + Vector3(0, 0, 3)
		var dir: Vector3 = target - p.global_position
		dir.y = 0.0
		if dir.length() < 0.01:
			continue
		var want: float = atan2(dir.x, dir.z) - p.global_rotation.y
		v.rotation.y = want if instant else lerp_angle(v.rotation.y, want, 0.2)

## The storm's hint glow on the branch waits until play starts.
func _set_hint(on: bool) -> void:
	var st = world.get(&"storm") if world != null else null
	var g = st.get(&"_glow") if st != null else null
	if g is Node3D and is_instance_valid(g):
		g.visible = on

func _overlay() -> void:
	# cinema bars in and out
	var bars := ss(0.0, 1.2, t) * (1.0 - ss(LENGTH - 1.6, LENGTH, t))
	var h := BAR_H * bars
	_top.offset_bottom = h
	_bottom.offset_top = -h
	# black: up from black at the start, a short dip on each cut
	var dip := 1.0 - ss(0.0, 1.6, t)
	for c in [24.0, 35.0]:
		dip = maxf(dip, 1.0 - clampf(absf(t - c) / 0.35, 0.0, 1.0))
	_dip.color.a = dip
	# the line for now
	var a := 0.0
	var text := ""
	for i in LINES.size():
		var l: Array = LINES[i]
		if t >= l[0] and t <= l[1]:
			text = l[2]
			a = ss(l[0], l[0] + 0.8, t) * (1.0 - ss(l[1] - 0.8, l[1], t))
			_line_i = i
	_caption.text = text
	_caption.modulate.a = a

func _sound() -> void:
	var r: float = world.look.rain_amount if world.look != null else 0.0
	var tail := 1.0 - ss(LENGTH - 2.0, LENGTH, t)
	if _rain.stream != null:
		_rain.volume_db = linear_to_db(maxf(r * tail, 0.0005)) + Audio.sfx_db - 8.0
	if _wind.stream != null:
		_wind.volume_db = linear_to_db(maxf(lerpf(0.15, 0.4, r) * tail, 0.0005)) + Audio.sfx_db - 8.0

# ---------------------------------------------------------------- skipping and the end

func _input(e: InputEvent) -> void:
	if done or not playing:
		return
	var key: bool = e is InputEventKey and e.pressed and not e.echo
	var click: bool = e is InputEventMouseButton and e.pressed
	var pad: bool = e is InputEventJoypadButton and e.pressed
	if not (key or click or pad):
		return
	get_viewport().set_input_as_handled()
	if t < 0.3:
		return
	if (key and (e as InputEventKey).physical_keycode == KEY_ESCAPE) or _skip_armed > 0.0:
		skip()
	else:
		_skip_armed = 3.0

## Jumps to the end: the storm night exactly as new_game() left it.
func skip() -> void:
	if done:
		return
	skipped = true
	for i in people.size():
		var p = people[i]
		if is_instance_valid(p):
			p.global_position = _home[i]
	world.look.set_weather(1.0, true)
	Clock.is_night = true
	Clock.phase_t = 0.0
	world.look.update_now()
	_finish()

func _finish() -> void:
	if done:
		return
	done = true
	playing = false
	Clock.is_night = true
	Clock.phase_t = 0.0
	world.look.set_weather(1.0, true)
	for i in people.size():
		var p = people[i]
		if is_instance_valid(p):
			if p.has_meta(&"intro_away"):
				p.remove_meta(&"intro_away")
			p.set_physics_process(true)
			if p.get(&"visual") != null and p.visual.get(&"villager") != null:
				p.visual.villager.rotation.y = 0.0
	_set_hint(true)
	hand.queue_free()
	light.queue_free()
	fill.queue_free()
	cam.current = false
	cam.queue_free()
	# the bars, music and rain ease out over the start of play
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_top, "offset_bottom", 0.0, 0.8)
	tw.tween_property(_bottom, "offset_top", 0.0, 0.8)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.3)
	tw.tween_property(_dip, "color:a", 0.0, 0.5)
	for p in [_music, _rain, _wind]:
		tw.tween_property(p, "volume_db", -60.0, 2.0 if p == _music else 1.2)
	tw.chain().tween_callback(queue_free)
	finished.emit()
