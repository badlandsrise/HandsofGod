class_name GoodbyeSequence extends Node
## The goodbye (DESIGN 9): the game's ending, played at the launch tower over the
## real world and the real people. Started by one call, World.start_goodbye()
## (or GoodbyeSequence.new() + begin(world)); it follows the beat sheet:
##
##   EVENING    the last evening: the city gathers on the plateau at dusk in the
##              clothes of their trade; the shrine is the base of the tower
##   CREW       the crew, chosen from the Book: four living descendants of the
##              first two, the commander the most trusting; each touches the old
##              shrine stone and says one line; the commander's line of descent
##              is shown back to the first two you named
##   BOARDING   the hand lifts each of them up to the capsule (click), the same
##              lift as the very first night
##   COUNTDOWN  clouds roll in; hold to part the clouds, the count only runs while
##              you hold; let go and it pauses gently (Audio.cue_level); at zero
##              the engines light and the crowd cheers: let go
##   LIFTOFF    the rocket rises through the gap you opened; the camera stays low
##   WAVE       the people turn and wave at the hand; wave back
##   WORDS      the commander's last words from the sky, written from the journal
##   LIGHT      the light blinks twice: the handprint from the cave wall
##   LINEAGE    the family line draws itself from the first two to the crew and
##              fades into the stars
##   REST       lower the hand to rest; a child climbs onto a finger
##   CREDITS    "Among the Stars" over the city at night (skippable after the
##              first viewing)
##   DAWN       free play at dawn: everyone else is still here, and so is the hand
##
## The music follows Audio's ending cues. Esc twice skips a moment. Nothing here
## kills anyone or takes the hand away (DESIGN 9.4); lines are single and short.
## Tests and shots: `rate` speeds it up, `autopilot` plays the player's part,
## skip_beat() / jump_to() move through it.

signal beat_changed(beat: StringName)
signal finished

enum B { EVENING, CREW, BOARDING, COUNTDOWN, LIFTOFF, WAVE, WORDS, LIGHT, LINEAGE, REST, CREDITS, DAWN, DONE }
const BEAT_NAMES: Array[StringName] = [&"evening", &"crew", &"boarding", &"countdown", &"liftoff", &"wave",
	&"words", &"light", &"lineage", &"rest", &"credits", &"dawn", &"done"]
const LEN := {B.EVENING: 34.0, B.CREW: 27.5, B.LIFTOFF: 22.0, B.WAVE: 18.0, B.LIGHT: 22.0, B.LINEAGE: 34.0, B.DAWN: 8.0}

const HAND_SCENE := "res://scenes/hand/hand_model.tscn"
const SFX := "res://assets/audio/sfx/%s.ogg"
const BAR_H := 92.0
const CREAM := Color("#f4e6c8")
const GOLD := Color(1.0, 0.8, 0.48)
const WARM := Color(1.0, 0.74, 0.42)
const COUNT_STEP := 1.45        # seconds of holding per count
const LIFT_TIME := 3.6          # one crew member, bench to capsule
const CREDITS_LEN := 205.0
## Local positions on the launch site (launch_tower's own frame: the pad at the
## origin, the tower on -X, the crowd's side +Z).
const STONE := Vector3(-10.4, 0.0, 0.0)
const WHITE_ROOM := Vector3(-2.6, 17.6, 0.0)
const REST_AT := Vector3(0.0, 0.0, 24.5)

var world: Node = null
var rate: float = 1.0
var autopilot: bool = false
var mouse_override: Vector2 = Vector2.INF   # 0..1 of the screen, for shots and tests
var beat: int = -1
var bt: float = 0.0                         # seconds into the current beat
var t_total: float = 0.0
var beats_seen: Array[StringName] = []
var playing: bool = false
var done: bool = false

var cast: GoodbyeCast
var crew: Array = []
var commander: Person = null
var crowd: Array = []
var site: Node3D
var xf: Transform3D
var mount: Node3D
var rocket: Node3D
var arm: Node3D
var _arm_rot0: float = 0.0
var _arm_retract: float = 0.0
var sky: EndingSky
var cam: Camera3D
var hand: Node3D
var hand_light: OmniLight3D
var child: Person = null                    # the child who climbs onto a finger

# overlay
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
var _speaker: Label
var _prompt: Label
var _prompt_sub: Label
var _count: Label
var _card: VBoxContainer
var _card_name: Label
var _card_role: Label
var _card_rel: Label
var _chain: Label
var _skip_hint: Label
var _dip: ColorRect
var lineage: LineageView
var marks: SkyMarks
var roll: CreditsRoll

# state
var _lines: Array = []                      # [from, to, text, speaker] in beat time
var _prompt_text: String = ""
var _prompt_small: String = ""
var _prompt_a: float = 0.0
var _hold_in: bool = false
var _auto_hold: bool = false
var _click: bool = false
var _wiggle: float = 0.0                    # mouse travel, for waving
var _skip_armed: float = 0.0
var _home: Dictionary = {}                  # Person -> crowd spot
var _babies: Array = []                     # [baby, carrier]
var _crew_spot: Array = []                  # standing spots by the bench
var _boarded: int = 0
var _lift_k: int = -1                       # the crew member in the hand
var _lift_t: float = 0.0
var _lift_from: Vector3
var _rocket_ready: bool = false
var _counting: float = 0.0                  # seconds of holding counted
var _count_shown: int = 11
var _ignited: bool = false
var _ignite_t: float = 0.0
var _released: bool = false
var _flight: float = 0.0                    # seconds since release
const LIFT_HOLD := 19.5                     # the liftoff camera stops following here
var _waving: float = 0.0                    # the hand waves while > 0
var _waved: bool = false
var _lowered: bool = false
var _lower_t: float = 0.0
var _blinks: Array = []                     # beat times of blinks still to come
var _blink_amt: float = 0.0
var _lit: Array = []                        # lights and NightGlow switched on here
var _react_t: float = 0.0
var _hw: Vector3 = Vector3.INF              # the hand: wrist, fingers, back, length, pose
var _hf: Vector3 = Vector3.FORWARD
var _hb: Vector3 = Vector3.UP
var _hl: float = 6.0
var _pose := {"curl": 0.2, "cup": 0.0, "point": 0.0, "spread": 0.5, "glow": 1.0}
var _cam_pos: Vector3 = Vector3.INF
var _cam_look: Vector3
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()
var _restored: bool = false
var _hud_was: bool = true

func _init() -> void:
	name = "Goodbye"
	process_mode = Node.PROCESS_MODE_ALWAYS

# ================================================================ start

## Starts the goodbye over `w`. opts: rate (float), autopilot (bool).
func begin(w: Node, opts: Dictionary = {}) -> void:
	world = w
	rate = float(opts.get("rate", 1.0))
	autopilot = bool(opts.get("autopilot", false))
	_rng.seed = 19
	Clock.running = false
	Clock.set_speed(1)
	_find_site()
	cast = GoodbyeCast.gather()
	crew = cast.crew
	commander = cast.commander
	crowd = Village.alive().filter(func(p): return not crew.has(p))
	_hide_play()
	_build_camera()
	_build_hand()
	_build_overlay()
	sky = EndingSky.new()
	world.add_child(sky)
	sky.global_transform = xf
	sky.set_process(false)
	_arrange_crowd()
	_place_crew()
	_pick_child()
	world.look.set_weather(0.0, false)
	_lights(true)
	playing = true
	_goto(B.EVENING)

## The launch tower: one tagged "launch_site", else the built Era 4 shrine, else
## one is raised on the spot the Era 4 layout would use.
func _find_site() -> void:
	site = null
	for n in get_tree().get_nodes_in_group(&"launch_site"):
		if n is Node3D and is_instance_valid(n) and world.is_ancestor_of(n):
			site = n
			break
	if site == null:
		site = _find_asset(world.dynamic if world.get(&"dynamic") != null else world, "launch_tower", 0)
	if site == null:
		var tower := AssetCatalog.instance(&"launch_tower")
		tower.name = "LaunchTower"
		tower.add_to_group(&"launch_site")
		var at := GoodbyeStage.SITE
		world.dynamic.add_child(tower)
		tower.global_position = Vector3(at.x, world.ground_y(at.x, at.y), at.y)
		site = tower
	xf = Transform3D(site.global_transform.basis.orthonormalized(), site.global_position)
	mount = site.find_child("RocketMount", true, false) as Node3D
	arm = site.find_child("AccessArm", true, false) as Node3D
	if arm != null:
		_arm_rot0 = arm.rotation.y
	if mount != null:
		for c in mount.get_children():
			c.queue_free()
		rocket = AssetCatalog.instance(&"rocket")
		rocket.name = "Rocket"
		mount.add_child(rocket)

func _find_asset(n: Node, id: String, depth: int) -> Node3D:
	if n is Node3D and str(n.get_meta("asset_id", "")) == id:
		return n
	if depth > 6:
		return null
	for c in n.get_children():
		var f := _find_asset(c, id, depth + 1)
		if f != null:
			return f
	return null

func _hide_play() -> void:
	var h = world.get(&"hand")
	if h != null and is_instance_valid(h):
		if h.has_method(&"release_all"):
			h.release_all()
		h.process_mode = Node.PROCESS_MODE_DISABLED
		if h is Node3D:
			h.visible = false
	var rig = world.get(&"camera_rig")
	if rig != null and is_instance_valid(rig):
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = world.get(&"hud")
	if hud != null and is_instance_valid(hud) and "visible" in hud:
		_hud_was = hud.visible
		hud.visible = false

# ---------------------------------------------------------------- the site frame

func L(v: Vector3) -> Vector3:
	return xf * v

## A point on the ground at local x, z, `h` metres up.
func G(x: float, z: float, h: float = 0.0) -> Vector3:
	var p := xf * Vector3(x, 0, z)
	p.y = world.ground_y(p.x, p.z) + h
	return p

func _dir(v: Vector3) -> Vector3:
	return (xf.basis * v).normalized()

# ================================================================ the cast on stage

func _arrange_crowd() -> void:
	_home.clear()
	_babies.clear()
	var list: Array = []
	for p in crowd:
		if p.stage == Person.Stage.BABY:
			var c = p._carrier()
			if c != null and crowd.has(c) and c.stage != Person.Stage.BABY:
				_babies.append([p, c])
				continue
		list.append(p)
	list.sort_custom(func(a, b): return _crowd_key(a) < _crowd_key(b))
	var i := 0
	var ring := 0
	while i < list.size() and ring < 80:
		var r := 30.0 + ring * 1.15
		var span := deg_to_rad(23.0 + ring * 0.8)
		var n := maxi(int(2.0 * span * r / 0.95), 1)
		for k in n:
			if i >= list.size():
				break
			var a := -span + (k + 0.5) * 2.0 * span / n + _rng.randf_range(-0.012, 0.012)
			var rr := r + _rng.randf_range(-0.3, 0.3)
			var p: Person = list[i]
			_stand(p, G(sin(a) * rr, cos(a) * rr), L(Vector3.ZERO))
			_home[p] = p.global_position
			i += 1
		ring += 1
	for b in _babies:
		var baby: Person = b[0]
		_freeze(baby)
	_pose_crowd(&"idle")
	for p in _home:
		var ap = p.visual.villager.get_node_or_null("AnimationPlayer") if p.visual != null and p.visual.villager != null else null
		if ap is AnimationPlayer and ap.is_playing():
			(ap as AnimationPlayer).advance(_rng.randf() * 2.0)

## Children to the front rows; the rest in a fixed shuffle.
func _crowd_key(p: Person) -> int:
	return (0 if p.stage <= Person.Stage.CHILD else 1) * 100000 + posmod(hash(p.uid * 7919), 9973)

func _freeze(p: Person) -> void:
	p.set_physics_process(false)
	p.visible = true
	if p.visual != null:
		p.visual.set_wish(null)
		p.visual.set_cargo(null)
		if p.visual.villager != null:
			p.visual.villager.rotation.y = 0.0
			p.visual.villager.scale = Vector3.ONE

func _stand(p: Person, at: Vector3, face: Vector3) -> void:
	_freeze(p)
	p.global_position = at
	var d := face - at
	d.y = 0.0
	if d.length() > 0.01:
		p.rotation = Vector3(0, atan2(d.x, d.z), 0)

func _play(p: Person, st: StringName, blend: float = 0.3) -> void:
	if p != null and is_instance_valid(p) and p.visual != null and p.visual.villager != null:
		p.visual.villager.play(st, blend)

## Sets the crowd's animation: `st` for a share `frac` of them (the rest idle),
## chosen the same way each time so the crowd does not flicker.
func _pose_crowd(st: StringName, frac: float = 1.0, other: StringName = &"idle") -> void:
	for p in _home:
		var pick := float(posmod(hash(p.uid * 31 + 7), 1000)) / 1000.0 < frac
		var s := st if pick else other
		if s == &"sit" and p.stage >= Person.Stage.ADULT:
			s = &"idle"
		_play(p, s)

func _place_crew() -> void:
	_crew_spot.clear()
	var bench := site.find_child("CrewBench", true, false) as Node3D
	var stone := L(STONE)
	for k in crew.size():
		var p: Person = crew[k]
		var spot: Vector3
		var seat: Node3D = null
		if bench != null:
			seat = bench.find_child("Seat%d" % (k + 1), true, false) as Node3D
		if seat != null:
			var sp := seat.global_position
			var out := Vector3(sp.x - stone.x, 0, sp.z - stone.z).normalized()
			spot = sp + out * 0.9
		else:
			spot = L(STONE + Vector3(-4.2, 0, (k - 1.5) * 1.2))
		spot.y = world.ground_y(spot.x, spot.z)
		_crew_spot.append(spot)
		_stand(p, spot, stone)
		if p.visual != null and p.visual.villager != null:
			p.visual.villager.set_crew(true)
		_play(p, &"idle", 0.0)

## A child near the front who will climb onto the hand at the end; a descendant
## of the first two if there is one.
func _pick_child() -> void:
	var best: Person = null
	var best_d := INF
	for p in _home:
		if p.stage != Person.Stage.CHILD:
			continue
		var d: float = (p.global_position - L(REST_AT)).length() - (6.0 if cast.line_of(int(p.uid)).size() > 1 else 0.0)
		if d < best_d:
			best_d = d
			best = p
	child = best

# ================================================================ beats

func beat_name() -> StringName:
	return BEAT_NAMES[clampi(beat, 0, BEAT_NAMES.size() - 1)]

func _goto(b: int) -> void:
	if beat >= 0 and beat < B.DONE:
		_switching = true
		_exit(beat)
		_switching = false
	beat = b
	bt = 0.0
	_lines.clear()
	_prompt_text = ""
	_skip_armed = 0.0
	_click = false
	beats_seen.append(beat_name())
	print("goodbye: %s" % beat_name())
	beat_changed.emit(beat_name())
	_enter(b)

func _enter(b: int) -> void:
	match b:
		B.EVENING:
			Audio.play_cue(&"last_evening")
			_dip.color.a = 1.0
			var dream: DreamDef = Defs.dream(&"the_rocket")
			var dt: String = dream.text if dream != null and dream.text != "" else "To go where the hand comes from."
			_lines = [[3.0, 8.6, "Once there were two of them, frightened of me in the rain."],
				[13.4, 18.4, "Look at them now."],
				[24.0, 28.8, "This was their shrine. Tonight it is where they leave from."],
				[29.4, 33.6, "Their own dream: “%s”" % dt]]
			_pose_crowd(&"talk", 0.3)
		B.CREW:
			for k in crew.size():
				var t0 := 2.0 + k * 6.0
				_lines.append([t0 + 1.4, t0 + 5.4, cast.crew_line(k), str(crew[k].given_name)])
			_pose_crowd(&"idle")
		B.BOARDING:
			_boarded = 0
			_lift_k = -1
		B.COUNTDOWN:
			Audio.play_cue(&"countdown")
			_counting = 0.0
			_count_shown = 11
			_pose_crowd(&"idle")
			_lines = [[0.8, 4.8, "Clouds. This, at least, I can help with."]]
		B.LIFTOFF:
			Audio.play_cue(&"liftoff", &"wave", 0.4)
			Audio.cue_level(1.0, 0.2)
			_flight = 0.0
			_pose_crowd(&"cheer")
		B.WAVE:
			_waving = 0.0
			_waved = false
			_pose_crowd(&"wave", 0.55, &"cheer")
		B.WORDS:
			var words := cast.last_words()
			for i in words.size():
				var t0 := 1.6 + i * 4.6
				_lines.append([t0, t0 + 4.1, words[i], "%s, from the sky" % (str(commander.given_name) if commander != null else "The crew")])
			_pose_crowd(&"idle")
		B.LIGHT:
			Audio.play_cue(&"goodbye", &"wave", 0.6)
			_blinks = [0.0, 1.43]
			_lines = [[9.0, 14.6, "The handprint from the cave wall. Their oldest word for me."],
				[15.4, 21.4, "I could never carry them. I could only show them the way."]]
		B.LINEAGE:
			lineage.set_data(cast.lineage())
			lineage.set_row_times(1.5, 18.0)
			lineage.t = 0.0
			lineage.dissolve = 0.0
			lineage.visible = true
			_lines = [[20.0, 25.6, "From the two in the rain, every one of them."]]
			_pose_crowd(&"idle")
		B.REST:
			_lowered = false
			_lower_t = 0.0
			_blinks = [6.9, 8.3]
		B.CREDITS:
			if Audio.cue_playing() != &"credits":
				Audio.play_cue(&"credits", &"", 3.0)
			roll = CreditsRoll.new()
			# under the letterbox bars, over the sky marks
			_top.get_parent().add_child(roll)
			_top.get_parent().move_child(roll, _top.get_index())
			roll.driven = true
			roll.start(CreditsRoll.blocks(cast), CREDITS_LEN)
			roll.finished.connect(_on_roll_finished)
			_pose_crowd(&"talk", 0.35, &"idle")
		B.DAWN:
			_lines = [[2.4, 7.6, "Morning came, the way it always had. Most of them are still here."]]
		B.DONE:
			_finish()

func _on_roll_finished() -> void:
	if beat == B.CREDITS and not _switching:
		_goto(B.DAWN)

## Leaves a beat with its outcome in place, so skipping never loses anything.
func _exit(b: int) -> void:
	match b:
		B.CREW:
			for k in crew.size():
				_stand(crew[k], _crew_spot[k], L(STONE))
				_play(crew[k], &"idle")
			_card.modulate.a = 0.0
			_chain.modulate.a = 0.0
		B.BOARDING:
			while _boarded < crew.size():
				_board(_boarded)
			_lift_k = -1
			_ready_rocket()
		B.COUNTDOWN:
			_arm_retract = 1.0
			_apply_arm()
			sky.roll_in = 1.0
			sky.part = 1.0
			if not _ignited:
				_ignite()
			_count.modulate.a = 0.0
			Audio.cue_level(1.0, 0.3)
		B.LIFTOFF:
			_flight = maxf(_flight, LEN[B.LIFTOFF])
			_fly()
			# the weather has cleared by now, even when the liftoff was skipped
			sky.roll_in = 0.0
			sky.clear = 1.0
			if rocket != null and is_instance_valid(rocket):
				rocket.visible = false
		B.WAVE:
			_waving = 0.0
		B.LIGHT:
			marks.amount = 0.0
		B.LINEAGE:
			lineage.visible = false
			lineage.t = -1.0
		B.REST:
			if not _lowered:
				_lowered = true
				_lower_t = 99.0
			_seat_child(1.0)
		B.CREDITS:
			if roll != null and is_instance_valid(roll):
				roll.finish()
				roll.queue_free()
			roll = null
			CreditsRoll.mark_seen()
		B.DAWN:
			_restore()

## Skips the current moment, keeping its outcome. The credits only skip once
## they have been seen to the end before (or with force).
func skip_beat(force: bool = false) -> bool:
	if not playing or done:
		return false
	if beat == B.CREDITS and not force and not CreditsRoll.seen():
		return false
	if beat == B.CREDITS and roll != null and not roll.done:
		roll.finish()          # its `finished` moves on to the dawn
		if beat == B.CREDITS:
			_goto(B.DAWN)
		return true
	_goto(beat + 1)
	return true

## Moves to beat `b` (skipping what lies between) and plays `seconds` of it.
func jump_to(b: int, seconds: float = 0.0) -> void:
	while beat < b and not done:
		skip_beat(true)
	fast_forward(seconds)

## Steps the timeline by `seconds` at once, in small steps.
func fast_forward(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not done:
		var s := minf(left, 1.0 / 30.0)
		_step(s)
		left -= s

# ================================================================ the frame

func _process(delta: float) -> void:
	if not playing or done:
		return
	var dt := Clock.real_delta if Clock.real_delta > 0.0 else delta
	_step(dt * rate)
	_skip_armed = maxf(_skip_armed - dt, 0.0)

func _step(dt: float) -> void:
	bt += dt
	t_total += dt
	if autopilot:
		_autopilot()
	match beat:
		B.EVENING: _evening(dt)
		B.CREW: _crew(dt)
		B.BOARDING: _boarding(dt)
		B.COUNTDOWN: _countdown(dt)
		B.LIFTOFF: _liftoff(dt)
		B.WAVE: _wave(dt)
		B.WORDS: _words(dt)
		B.LIGHT: _light(dt)
		B.LINEAGE: _lineage(dt)
		B.REST: _rest(dt)
		B.CREDITS: _credits(dt)
		B.DAWN: _dawn(dt)
	if done:
		return
	if not _restored:
		_babies_follow()
		_blink(dt)
		sky.step(dt)
		_update_hand(dt)
		_update_camera(dt)
	_overlay(dt)
	_wiggle = maxf(_wiggle - dt * 600.0, 0.0)
	_click = false
	if beat in LEN and bt >= float(LEN[beat]):
		_goto(beat + 1)

func _autopilot() -> void:
	match beat:
		B.BOARDING:
			if _lift_k < 0 and bt > 1.2 and fmod(bt, 1.0) < 0.05:
				_click = true
		B.COUNTDOWN:
			_auto_hold = bt > 3.5 and not (_ignited and bt - _ignite_t > 2.2)
		B.WAVE:
			if bt > 7.0 and bt < 15.0:
				_wiggle = 900.0
		B.REST:
			if bt > 3.0:
				_click = true
		_:
			_auto_hold = false

func holding() -> bool:
	return _hold_in or _auto_hold

# ---------------------------------------------------------------- sky and time

func _set_time(night: bool, f: float) -> void:
	Clock.is_night = night
	Clock.phase_t = f * (Clock.night_seconds if night else Clock.day_seconds)

func _evening(_dt: float) -> void:
	_set_time(false, lerpf(0.9, 0.955, bt / LEN[B.EVENING]))
	sky.stars = 0.0
	_crowd_react()

func _crew(dt: float) -> void:
	_set_time(false, lerpf(0.955, 0.975, bt / LEN[B.CREW]))
	for k in crew.size():
		var p: Person = crew[k]
		var t0 := 2.0 + k * 6.0
		var stone := L(STONE)
		var spot: Vector3 = _crew_spot[k]
		var near := spot.lerp(stone, 0.62)
		near.y = world.ground_y(near.x, near.z)
		var u := bt - t0
		if u < 0.0:
			continue
		# step up to the old stone, touch it, step back
		if u < 1.6:
			p.global_position = spot.lerp(near, Valley.ss(0.0, 1.6, u))
			_play(p, &"walk")
		elif u < 3.4:
			p.global_position = near
			_play(p, &"pickup" if u < 2.8 else &"idle")
		elif u < 5.0:
			p.global_position = near.lerp(spot, Valley.ss(3.4, 5.0, u))
			_play(p, &"walk")
		else:
			p.global_position = spot
			_play(p, &"idle")
		_face(p, stone)
		if u >= 1.4 and u - dt < 1.4:
			_voice(p, &"")
	# crew cards
	var card_k := -1
	for k in crew.size():
		var t0 := 2.0 + k * 6.0
		if bt >= t0 and bt < t0 + 5.6:
			card_k = k
	if card_k >= 0:
		var p: Person = crew[card_k]
		var t0 := 2.0 + card_k * 6.0
		_card_name.text = str(p.given_name)
		_card_role.text = "Commander" if card_k == 0 else "Crew"
		_card_rel.text = BookData.cap(cast.relation(p))
		_card.modulate.a = Valley.ss(t0, t0 + 0.7, bt) * (1.0 - Valley.ss(t0 + 4.9, t0 + 5.6, bt))
		if card_k == 0:
			_chain.text = cast.chain_text(p)
			_chain.modulate.a = Valley.ss(t0 + 1.0, t0 + 1.8, bt) * (1.0 - Valley.ss(t0 + 4.9, t0 + 5.6, bt))
		else:
			_chain.modulate.a = 0.0
	else:
		_card.modulate.a = 0.0
		_chain.modulate.a = 0.0

func _boarding(dt: float) -> void:
	_set_time(false, lerpf(0.955, 0.975, clampf(bt / 25.0, 0.0, 1.0)))
	_crowd_react()
	if _boarded >= crew.size():
		if _lift_k < 0:
			if not _rocket_ready and bt > _lift_t + 0.6:
				_ready_rocket()
				_pose_crowd(&"cheer", 0.6)
			if bt > _lift_t + 3.0 or crew.is_empty():
				_goto(B.COUNTDOWN)
		return
	if _lift_k < 0:
		var who: Person = crew[_boarded]
		_prompt_text = "Lift %s into the capsule" % who.given_name
		_prompt_small = "click"
		# a patient player is never stuck: after a long wait the hand goes on its own
		var waited := bt - (_lift_t if _boarded > 0 else 0.0)
		if _click or waited > 25.0:
			_lift_k = _boarded
			_lift_t = bt
			_lift_from = _hw if _hw.is_finite() else L(WHITE_ROOM + Vector3(4, 4, 6))
	else:
		_prompt_text = ""
		var u := bt - _lift_t
		var p: Person = crew[_lift_k]
		if u >= 0.9 and u - dt < 0.9:
			_sfx(&"lift")
			_voice(p, &"happy")
		if u >= 3.0 and u - dt < 3.0:
			_sfx(&"place")
		if u >= LIFT_TIME:
			_board(_lift_k)
			_lift_k = -1
			_lift_t = bt
			_pose_crowd(&"cheer", 0.35)

## The lift of crew member k, at u seconds: [anchor (cupped palm), person feet or INF].
func _lift_path(k: int, u: float) -> Array:
	var start: Vector3 = _crew_spot[k] + Vector3(0, 2.05, 0)
	var room := L(WHITE_ROOM) + Vector3(0, 1.9, 0)
	if u < 0.9:
		return [_lift_from.lerp(start + Vector3(0, 0.6, 0), Valley.ss(0.0, 0.9, u)), Vector3.INF]
	if u < 1.3:
		var a := (start + Vector3(0, 0.6, 0)).lerp(start, Valley.ss(0.9, 1.25, u))
		return [a, _crew_spot[k] if u < 1.15 else a - Vector3(0, 2.05, 0)]
	if u < 3.0:
		var s := Valley.ss(1.3, 3.0, u)
		var c1 := start + Vector3(0, 7.0, 0)
		var c2 := room + _dir(Vector3(4.0, 3.0, 5.0)) * 5.0
		var a := IntroSequence.bez(start, c1, c2, room, s)
		return [a, a - Vector3(0, 1.9, 0)]
	return [room + Vector3(0, Valley.ss(3.0, 3.6, u) * 1.2, 0), room - Vector3(0, 1.9, 0) if u < 3.35 else Vector3.INF]

func _board(k: int) -> void:
	var p: Person = crew[k]
	p.visible = false
	p.global_position = L(WHITE_ROOM)
	_boarded = maxi(_boarded, k + 1)

func _ready_rocket() -> void:
	if _rocket_ready or mount == null:
		return
	_rocket_ready = true
	if rocket != null and is_instance_valid(rocket):
		rocket.queue_free()
	rocket = AssetCatalog.instance(&"rocket_ready")
	rocket.name = "Rocket"
	mount.add_child(rocket)
	_lights_in(rocket)
	var light := rocket.find_child("ExhaustLight", true, false) as Node3D
	if light != null:
		light.visible = false
		_lit.erase(light)

func _countdown(dt: float) -> void:
	_set_time(false, lerpf(0.99, 0.999, clampf(bt / 20.0, 0.0, 1.0)))
	sky.roll_in = Valley.ss(0.0, 6.0, bt)
	sky.cloud_tint = Color(0.5, 0.48, 0.58)
	sky.stars = 0.15
	var hold := holding() and bt > 3.0
	if not _ignited:
		if hold:
			_counting += dt
			sky.part = move_toward(sky.part, 1.0, dt * 0.45)
			if Audio.cue_playing() == &"countdown" and Audio._cue_level < 1.0:
				Audio.cue_level(1.0, 0.8)
		else:
			sky.part = move_toward(sky.part, 0.2 if bt > 3.0 else 0.0, dt * 0.12)
			if bt > 3.0 and Audio.cue_playing() == &"countdown" and Audio._cue_level > 0.5:
				Audio.cue_level(0.35, 1.2)      # the count pauses, gently
		var c := 10 - int(_counting / COUNT_STEP)
		if c < _count_shown and bt > 3.0:
			_count_shown = c
			for i in 3:
				_voice(_home.keys()[_rng.randi() % maxi(_home.size(), 1)] if not _home.is_empty() else null, &"cheer")
			if c == 5:
				_arm_t0 = bt
			if c <= 0:
				_ignite()
		if bt > 3.0:
			_prompt_text = "Hold to part the clouds" if not hold else ""
			_prompt_small = "hold the mouse button (or Space)" if not hold else ""
		if _count_shown <= 5:
			_arm_retract = Valley.ss(_arm_t0, _arm_t0 + 4.0, bt)
	else:
		sky.part = 1.0
		_arm_retract = 1.0
		var since := bt - _ignite_t
		_shake = 0.18 * (1.0 - Valley.ss(0.0, 5.0, since))
		if since > 1.0:
			_prompt_text = "Let go"
			_prompt_small = "release, as they cheer"
		if (since > 1.0 and not holding()) or since > 7.0:
			_released = true
			_goto(B.LIFTOFF)
			return
	_apply_arm()
	_count.text = str(clampi(_count_shown, 0, 10)) if _count_shown <= 10 else ""
	var showing := bt > 3.0 and not _ignited and _count_shown <= 10
	_count.modulate.a = move_toward(_count.modulate.a, (1.0 if hold else 0.45) if showing else 0.0, dt * 2.5)

var _arm_t0: float = 0.0

func _apply_arm() -> void:
	if arm == null:
		return
	var deg := float(arm.get_meta("retract_degrees", 90.0))
	arm.rotation.y = _arm_rot0 + deg_to_rad(deg) * _arm_retract

func _ignite() -> void:
	if _ignited:
		return
	_ignited = true
	_ignite_t = bt
	_count_shown = 0
	if rocket != null and is_instance_valid(rocket):
		for n in ["Exhaust", "ExhaustSmoke"]:
			var ps := rocket.find_child(n, true, false) as GPUParticles3D
			if ps != null:
				ps.emitting = true
		var light := rocket.find_child("ExhaustLight", true, false) as Light3D
		if light != null:
			light.visible = true
	sky.billow()
	_sfx(&"heavy", 0.32)
	_pose_crowd(&"cheer")
	for i in 4:
		if not _home.is_empty():
			_voice(_home.keys()[_rng.randi() % _home.size()], &"cheer")

## The rocket's flight at `_flight` seconds after release: up, then pitching over
## away from the crowd, until it is only a light.
func _rocket_local(s: float) -> Vector3:
	var u := maxf(s - 0.8, 0.0)
	var alt := 0.35 * minf(s, 0.8) + 1.15 * u * u
	var down := pow(maxf(alt - 40.0, 0.0), 2.0) / 380.0
	return Vector3(0, alt, -down)

func _fly() -> void:
	if rocket == null or not is_instance_valid(rocket):
		return
	var p := _rocket_local(_flight)
	var q := _rocket_local(_flight + 0.05)
	rocket.position = p
	var v := q - p
	rocket.rotation = Vector3(-atan2(-v.z, maxf(v.y, 0.001)) if v.length() > 0.0001 else 0.0, 0, 0)
	var steam := rocket.find_child("Steam", true, false) as GPUParticles3D
	if steam != null:
		steam.emitting = _flight < 2.0

## Where the light is in the sky: the rocket's path, kept within the star dome.
func _light_world() -> Vector3:
	var lp := _rocket_local(minf(_flight, 22.0)) + Vector3(0, 1.0, 0)
	var origin := Vector3(0, 0, 36)
	var d := lp - origin
	var dist := minf(d.length(), 1000.0)
	dist = lerpf(dist, 1000.0, Valley.ss(22.0, 34.0, _flight))
	return L(origin + d.normalized() * dist)

func _liftoff(dt: float) -> void:
	_flight += dt
	_set_time(true, lerpf(0.0, 0.12, bt / LEN[B.LIFTOFF]))
	_fly()
	sky.part = 1.0
	sky.clear = Valley.ss(9.0, 22.0, bt)
	sky.stars = lerpf(0.2, 0.9, Valley.ss(0.0, 18.0, bt))
	_shake = 0.22 * (1.0 - Valley.ss(0.0, 7.0, bt))
	if bt > 1.0 and bt - dt <= 1.0:
		_sfx(&"heavy", 0.28, 2.0)
	if bt > 3.5 and bt - dt <= 3.5:
		_sfx(&"heavy", 0.24)
	if bt > 9.0 and bt - dt <= 9.0:
		_pose_crowd(&"wave", 0.5, &"cheer")
	var far := Valley.ss(12.0, 20.0, bt)
	# the light sits on the rocket's engines until the rocket is only that light
	var at := _light_world()
	if rocket != null and is_instance_valid(rocket):
		at = at.lerp(rocket.global_position, 1.0 - Valley.ss(19.0, 22.0, bt))
		var smoke := rocket.find_child("ExhaustSmoke", true, false) as GPUParticles3D
		if smoke != null:
			smoke.emitting = bt < 12.0
		rocket.visible = bt < 19.5
	sky.set_light(at, far * 1.4)
	var ex := rocket.find_child("ExhaustLight", true, false) as OmniLight3D if rocket != null else null
	if ex != null:
		ex.light_energy = lerpf(8.0, 2.0, far)

## After the liftoff the night is clear: no cloud is left in front of the
## light, the lineage or the credits.
func _clear_sky() -> void:
	sky.part = 1.0
	sky.clear = 1.0
	sky.roll_in = 0.0

func _wave(dt: float) -> void:
	_flight += dt
	_set_time(true, lerpf(0.12, 0.22, bt / LEN[B.WAVE]))
	sky.clear = 1.0
	sky.stars = lerpf(0.9, 0.95, bt / LEN[B.WAVE])
	sky.set_light(_light_world(), 1.2)
	if bt > 5.5:
		if not _waved:
			_prompt_text = "Wave back"
			_prompt_small = "move the hand from side to side"
		if _wiggle > 500.0 or (holding() and bt > 6.0):
			if not _waved:
				_waved = true
				_pose_crowd(&"wave", 0.85, &"cheer")
				for i in 3:
					if not _home.is_empty():
						_voice(_home.keys()[_rng.randi() % _home.size()], &"happy")
			_waving = 2.0
			_prompt_text = ""
	_waving = maxf(_waving - dt, 0.0)

func _words(dt: float) -> void:
	_clear_sky()
	_flight += dt
	_set_time(true, lerpf(0.22, 0.32, clampf(bt / 40.0, 0.0, 1.0)))
	sky.stars = 1.0
	sky.set_light(_light_world(), 1.0)
	for l in _lines:
		if bt >= float(l[0]) and bt - dt < float(l[0]):
			_voice(commander, &"")
	var end := float(_lines[-1][1]) + 1.2 if not _lines.is_empty() else 2.0
	if bt >= end:
		_goto(B.LIGHT)

func _light(dt: float) -> void:
	_clear_sky()
	_flight += dt * 0.5
	_set_time(true, 0.33)
	sky.stars = 1.0
	sky.set_light(_light_world(), 0.9 + _blink_amt * 3.0)
	# the handprint round the light, as the crowd recognises it
	var a := Valley.ss(2.4, 4.0, bt) * (1.0 - Valley.ss(7.5, 10.0, bt))
	marks.amount = a
	if cam != null and not cam.is_position_behind(_light_world()):
		marks.at = cam.unproject_position(_light_world())
	if bt > 2.6 and bt - dt <= 2.6:
		_pose_crowd(&"wave", 0.75)
		for i in 3:
			if not _home.is_empty():
				_voice(_home.keys()[_rng.randi() % _home.size()], &"happy")
	if bt > 10.0 and bt - dt <= 10.0:
		_pose_crowd(&"idle")

func _lineage(dt: float) -> void:
	_clear_sky()
	_flight += dt * 0.4
	_set_time(true, 0.34)
	sky.stars = 1.0
	sky.set_light(_light_world(), 0.8)
	lineage.t = bt
	lineage.dissolve = Valley.ss(26.0, 33.0, bt)

func _rest(dt: float) -> void:
	_clear_sky()
	_set_time(true, 0.36)
	sky.stars = 1.0
	sky.set_light(_light_world(), 0.7 + _blink_amt * 2.0)
	_crowd_react()
	if not _lowered:
		_prompt_text = "Lower the hand to rest" if bt > 1.5 else ""
		_prompt_small = "click, or bring it down" if bt > 1.5 else ""
		var low := _mouse_screen().y > _viewport_size().y * 0.78
		if (bt > 1.5 and (_click or low)) or bt > 18.0:
			_lowered = true
			_lower_t = 0.0
			_prompt_text = ""
			_lines = [[bt + 4.5, bt + 10.0, "Most of them are still here. So am I."]]
	else:
		_lower_t += dt
		_seat_child(Valley.ss(3.2, 7.2, _lower_t))
		if _lower_t > 12.0:
			_goto(B.CREDITS)

## The child walks up and climbs onto a finger of the resting hand (u 0..1).
func _seat_child(u: float) -> void:
	if child == null or not is_instance_valid(child) or not _home.has(child):
		return
	var home: Vector3 = _home[child]
	var finger := _finger_point()
	var foot := finger
	foot.y = world.ground_y(foot.x, foot.z)
	if u <= 0.0:
		return
	if u < 0.8:
		var s := Valley.ss(0.0, 0.8, u)
		var p := home.lerp(foot + (home - foot).normalized() * 0.6, s)
		p.y = world.ground_y(p.x, p.z)
		child.global_position = p
		_face(child, finger)
		_play(child, &"walk")
	else:
		var s := Valley.ss(0.8, 1.0, u)
		var from := foot + (home - foot).normalized() * 0.6
		child.global_position = from.lerp(finger, s) + Vector3(0, sin(s * PI) * 0.6, 0)
		_face(child, L(Vector3(0, 0, 40)))
		_play(child, &"sit" if s >= 1.0 else &"idle")

func _face(p: Person, at: Vector3) -> void:
	var d := at - p.global_position
	d.y = 0.0
	if d.length() > 0.01:
		p.rotation.y = atan2(d.x, d.z)

func _finger_point() -> Vector3:
	if hand == null:
		return L(REST_AT)
	return hand.global_transform * Vector3(-0.16, -0.16, -0.66)

func _credits(dt: float) -> void:
	_clear_sky()
	_set_time(true, 0.38)
	sky.stars = 1.0
	sky.set_light(_light_world(), 0.6)
	if roll != null:
		roll.advance(dt)
	_seat_child(1.0)

func _dawn(dt: float) -> void:
	# black, then up into the morning: free play
	if bt < 2.0:
		_dip.color.a = Valley.ss(0.0, 1.6, bt)
	elif not _restored:
		_restore()
	else:
		_dip.color.a = 1.0 - Valley.ss(2.2, 5.0, bt)
	if bt >= 7.6:
		_goto(B.DONE)

# ---------------------------------------------------------------- crowd

func _crowd_react() -> void:
	_react_t -= 1.0 / 30.0
	if _react_t > 0.0 or not _hw.is_finite():
		return
	_react_t = 0.25
	var tip := _hw + _hf * _hl
	for p in _home:
		if p == child and _lowered:
			continue
		var d := Vector2(p.global_position.x - tip.x, p.global_position.z - tip.z).length()
		if d < 7.0 and tip.y - p.global_position.y < 14.0:
			_play(p, &"wave" if p.trust >= 3 else (&"idle" if p.trust >= 1 else &"cower"))
			if _rng.randf() < 0.06:
				_voice(p, &"happy")
		elif p.visual != null and p.visual.villager != null and p.visual.villager.current_state() == &"wave" and beat in [B.EVENING, B.BOARDING, B.REST]:
			_play(p, &"idle")

func _babies_follow() -> void:
	var up := beat == B.WAVE and _waved or (beat == B.LIGHT and bt > 2.6 and bt < 10.0)
	for b in _babies:
		var baby: Person = b[0]
		var c: Person = b[1]
		if not is_instance_valid(baby) or not is_instance_valid(c):
			continue
		if up:
			baby.global_position = c.global_position + c.global_basis * Vector3(0.0, 2.0, 0.15)
		else:
			baby.global_position = c.global_position + c.global_basis * Vector3(0.05, 0.82, 0.3)
		baby.rotation.y = c.rotation.y
		_play(baby, &"cheer" if up else &"sit")

# ================================================================ the hand

func _build_hand() -> void:
	hand = (load(HAND_SCENE) as PackedScene).instantiate()
	hand.name = "GoodbyeHand"
	hand.top_level = true
	world.add_child(hand)
	hand_light = OmniLight3D.new()
	hand_light.name = "GoodbyeHandLight"
	hand_light.light_color = WARM
	hand_light.omni_range = 18.0
	hand_light.light_energy = 0.0
	world.add_child(hand_light)

func _mouse_screen() -> Vector2:
	var vs := _viewport_size()
	if mouse_override.is_finite():
		return Vector2(mouse_override.x * vs.x, mouse_override.y * vs.y)
	return get_viewport().get_mouse_position()

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

## The point under the mouse, `depth` metres in front of the camera.
func _mouse_point(depth: float) -> Vector3:
	var mp := _mouse_screen()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	var fwd := -cam.global_basis.z
	return o + d * (depth / maxf(d.dot(fwd), 0.25))

func _flat_fwd() -> Vector3:
	var f := -cam.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

func _update_hand(dt: float) -> void:
	if hand == null or cam == null:
		return
	var w: Vector3
	var f: Vector3
	var b: Vector3
	var l := 6.0
	var curl := 0.2
	var cup := 0.0
	var point := 0.0
	var spread := 0.55
	var glow := 1.0
	var mode := &"free"
	var depth := 34.0
	match beat:
		B.EVENING:
			depth = 30.0 if bt > 23.5 else (26.0 if bt > 12.5 else 60.0)
			l = 6.0 if bt > 12.5 else 11.0
		B.CREW:
			depth = 18.0
			l = 4.0
		B.BOARDING:
			depth = 30.0
			l = 4.0
			if _lift_k >= 0:
				mode = &"lift"
		B.COUNTDOWN, B.LIFTOFF:
			mode = &"sky"
		B.WAVE:
			mode = &"sky" if bt < 5.5 else &"wave"
		B.WORDS, B.LIGHT, B.LINEAGE:
			depth = 46.0
			l = 9.0
		B.REST:
			mode = &"rest" if _lowered else &"free"
			depth = 22.0
			l = 6.5
		B.CREDITS, B.DAWN:
			mode = &"rest"
			l = 6.5
	var fwd := _flat_fwd()
	var right := fwd.cross(Vector3.UP).normalized()
	match mode:
		&"free":
			var tip := _mouse_point(depth)
			var gy: float = world.ground_y(tip.x, tip.z)
			tip.y = maxf(tip.y, gy + 2.5)
			f = (fwd * 0.62 + Vector3.DOWN * 0.78).normalized()
			b = (Vector3.UP * 0.62 + fwd * 0.78).normalized()
			w = tip - f * l
			curl = 0.22 + 0.05 * sin(t_total * 1.3)
			spread = 0.55
			glow = 0.9
		&"lift":
			var path := _lift_path(_lift_k, bt - _lift_t)
			var anchor: Vector3 = path[0]
			f = (fwd * 0.86 + Vector3.DOWN * 0.5).normalized()
			b = (Vector3.UP * 0.86 + fwd * 0.5).normalized()
			l = 4.0
			w = anchor + b * 0.2 * l - f * 0.55 * l
			var u := bt - _lift_t
			cup = Valley.ss(0.85, 1.25, u) * (1.0 - Valley.ss(3.0, 3.4, u))
			curl = lerpf(0.15, 0.5, cup)
			spread = lerpf(0.6, 0.2, cup)
			glow = 1.2
			var p: Person = crew[_lift_k]
			var feet: Vector3 = path[1]
			if feet.is_finite():
				p.visible = true
				p.global_position = feet
				_play(p, &"held" if u > 1.1 and u < 3.2 else &"idle")
				if u > 1.1:
					_face(p, cam.global_position)
			else:
				p.visible = u < 3.0
		&"sky":
			var m := _mouse_screen() / _viewport_size()
			var h := holding() and beat == B.COUNTDOWN and not _ignited
			var lift_off := beat == B.LIFTOFF or beat == B.WAVE
			var base := L(Vector3((m.x - 0.5) * 26.0, 0, -6.0))
			var height := 36.0 + (6.0 if h or _ignited else 0.0)
			if lift_off:
				# released: the hand opens and drifts aside, still watching
				var s := Valley.ss(0.0, 6.0, bt) if beat == B.LIFTOFF else 1.0
				base = base.lerp(L(Vector3(30.0, 0, -18.0)), s)
				height = lerpf(42.0, 30.0, s)
			var center := Vector3(base.x, xf.origin.y + height, base.z)
			# reaching in from the right, palm down over the pad, fingers a
			# touch toward the people, so it reads as a hand and never a sleeve
			f = _dir(Vector3(-1.0, -0.14, 0.16))
			b = (Vector3.UP - f * f.dot(Vector3.UP)).normalized()
			l = 20.0
			w = center - f * l * 0.5
			var open := 1.0 if (h or _ignited or lift_off) else 0.0
			curl = lerpf(0.35, -0.25, open)
			spread = lerpf(0.4, 1.35, open)
			glow = lerpf(0.9, 1.8, open) + (0.4 * sin(t_total * 3.0) if h else 0.0)
		&"wave":
			var amt := clampf(_waving, 0.0, 1.0)
			var ang := sin(t_total * 6.5) * 0.38 * amt
			var toward := (cam.global_position - L(Vector3(0, 17, 4)))
			toward.y = 0.0
			toward = toward.normalized()
			f = Vector3.UP.rotated(toward, ang).normalized()
			b = -toward
			b = (b - f * f.dot(b)).normalized()
			l = 11.0
			var m := _mouse_screen() / _viewport_size()
			var c := L(Vector3((m.x - 0.5) * 10.0, 17.0, 4.0))
			w = c - f * l * 0.5
			curl = -0.15
			spread = 1.0
			glow = 1.3 + 0.3 * amt
		&"rest":
			var r := L(REST_AT)
			r.y = world.ground_y(r.x, r.z)
			# across the view, fingers toward the crowd's side, palm up
			var toward := _dir(Vector3(0.88, 0, 0.42))
			var u := Valley.ss(0.0, 3.0, _lower_t) if beat == B.REST else 1.0
			f = (toward + Vector3.UP * 0.08).normalized()
			b = (Vector3.DOWN - f * f.dot(Vector3.DOWN)).normalized()
			l = 6.5
			var rest_w := r - f * l * 0.45 + Vector3.UP * 0.2 * l
			var hover_w := r - f * l * 0.45 + Vector3(0, 9.0, 0)
			w = hover_w.lerp(rest_w, u)
			curl = 0.18
			spread = 0.45
			glow = lerpf(1.2, 0.7, u)
	if mode == &"free" or mode == &"lift":
		# never show the camera the open cuff: keep the fingers from pointing
		# away down the line of sight, so the glove is seen side-on at worst
		var to_cam := (cam.global_position - (w + f * l * 0.5)).normalized()
		var fd := f.dot(to_cam)
		if fd < 0.08:
			var keep := w + f * l * (1.0 if mode == &"free" else 0.55)   # the tip, or the cupped palm
			f = (f + to_cam * (0.08 - fd)).normalized()
			b = (b - f * f.dot(b)).normalized()
			w = keep - f * l * (1.0 if mode == &"free" else 0.55)
	# ease toward the target (cuts snap)
	var k := 1.0 - exp(-dt * (5.0 if mode != &"lift" else 14.0))
	if not _hw.is_finite() or _snap_hand:
		_hw = w; _hf = f; _hb = b; _hl = l
		_snap_hand = false
	else:
		_hw = _hw.lerp(w, k)
		_hf = _hf.slerp(f, k).normalized() if _hf.angle_to(f) > 0.001 else f
		_hb = _hb.slerp(b, k).normalized() if _hb.angle_to(b) > 0.001 else b
		_hl = lerpf(_hl, l, k)
	for key in ["curl", "cup", "point", "spread", "glow"]:
		var target: float = {"curl": curl, "cup": cup, "point": point, "spread": spread, "glow": glow}[key]
		_pose[key] = lerpf(float(_pose[key]), target, k)
	var c5 := float(_pose["curl"])
	TitleStage.place(hand, _hw, _hf, _hb, _hl)
	hand.set_pose(PackedFloat32Array([c5, c5 * 0.8, c5, c5 + 0.04, c5 + 0.08]), float(_pose["cup"]), float(_pose["point"]), float(_pose["spread"]))
	hand.set_look(1.0, 1.0, float(_pose["glow"]), WARM)
	hand.visible = beat != B.DONE
	hand_light.global_position = hand.global_transform * Vector3(0, -0.3, -0.5)
	hand_light.omni_range = _hl * 2.6
	hand_light.light_energy = clampf(float(_pose["glow"]), 0.0, 2.5) * (0.7 if Clock.is_night else 0.25)

var _snap_hand: bool = true
var _switching: bool = false
var _caption_voice: bool = false

# ================================================================ the camera

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.name = "GoodbyeCamera"
	cam.near = 0.25
	cam.far = 2400.0
	cam.fov = 48.0
	world.add_child(cam)
	cam.current = true

## [pos, look, fov] for the current beat at bt.
func _shot() -> Array:
	var pos: Vector3
	var look: Vector3
	var fov := 48.0
	match beat:
		B.EVENING:
			if bt < 12.25:
				var u := Valley.ss(0.0, 12.25, bt)
				pos = IntroSequence.bez(L(Vector3(80, 64, 160)), L(Vector3(46, 44, 112)), L(Vector3(24, 22, 82)), G(12, 62, 9.0), u)
				look = L(Vector3(0, 13, 0)).lerp(L(Vector3(0, 9, 8)), u)
				fov = lerpf(50.0, 46.0, u)
			elif bt < 23.25:
				var u := Valley.ss(12.25, 23.25, bt)
				pos = G(9.5, 47.0, 2.0).lerp(G(3.5, 43.0, 2.1), u)
				look = L(Vector3(0, 10, 0))
				fov = 48.0
			else:
				var u := Valley.ss(23.25, 34.0, bt)
				# round to the old stone, with the tower behind it
				pos = G(-34, 17, 4.5).lerp(G(-27, 12, 3.6), u)
				look = L(Vector3(-9, 5.5, 0))
				fov = 45.0
		B.CREW:
			var u := Valley.ss(0.0, LEN[B.CREW], bt)
			pos = G(-3.4, 9.6, 2.5).lerp(G(-5.0, 8.2, 2.2), u)
			look = L(Vector3(-12.8, 1.2, 0))
			fov = 42.0
		B.BOARDING:
			var u := clampf(bt / 30.0, 0.0, 1.0)
			pos = G(15.0, 32.0, 7.5).lerp(G(13.0, 30.0, 7.0), u)
			look = L(Vector3(-6, 10, 0))
			fov = 46.0
		B.COUNTDOWN:
			var u := clampf(bt / 24.0, 0.0, 1.0)
			pos = G(5.0, 44.0, 1.75).lerp(G(4.0, 42.5, 1.75), u)
			look = L(Vector3(0, 26, -10))
			fov = 56.0
		B.LIFTOFF:
			pos = G(6.0, 41.0, 1.7)
			var target := L(_rocket_local(_flight) + Vector3(0, 9, 0))
			look = target.lerp(L(Vector3(0, 30, -8)), 0.25)
			# first the camera stays low with the people: it tilts up, but
			# keeps the tower and the crowd's horizon in the frame
			var d := (look - pos).normalized()
			var maxel := deg_to_rad(34.0)
			if asin(clampf(d.y, -1.0, 1.0)) > maxel:
				var hz := Vector3(d.x, 0, d.z).normalized()
				d = hz * cos(maxel) + Vector3.UP * sin(maxel)
			# then, as it clears the tower, it tilts up and follows the rocket
			# until it is a bright point among the stars, and holds there
			var rk := L(_rocket_local(minf(_flight, LIFT_HOLD)) + Vector3(0, 4, 0))
			var follow := (rk - pos).normalized()
			d = d.slerp(follow, Valley.ss(4.0, 9.5, bt)).normalized()
			look = pos + d * 50.0
			fov = 54.0
		B.WAVE:
			if bt < 5.5:
				var u := Valley.ss(0.0, 5.5, bt)
				pos = G(3.0, 21.0, 3.2).lerp(G(2.0, 22.5, 3.0), u)
				look = G(0, 36, 4.6)
				fov = 45.0
			else:
				var u := Valley.ss(5.5, 18.0, bt)
				pos = G(2.0, 52.0, 2.6).lerp(G(1.0, 50.0, 2.8), u)
				look = L(Vector3(0, 15, 0))
				fov = 50.0
		B.WORDS, B.LIGHT:
			var u := clampf((bt + (0.0 if beat == B.WORDS else 40.0)) / 60.0, 0.0, 1.0)
			pos = G(3.0, 50.0, 1.75).lerp(G(2.0, 49.0, 2.2), u)
			look = pos + (_light_world() - pos).normalized().lerp(_dir(Vector3(0, 0, -1)), 0.45).normalized() * 50.0
			fov = 55.0
		B.LINEAGE:
			var u := Valley.ss(0.0, 34.0, bt)
			pos = G(2.0, 49.0, 2.2).lerp(G(1.5, 48.0, 2.6), u)
			var dir := (_light_world() - pos).normalized().lerp(_dir(Vector3(0, 0, -1)), 0.45).normalized()
			dir = dir.lerp(Vector3.UP, 0.32 * u).normalized()
			look = pos + dir * 50.0
			fov = 55.0
		B.REST:
			var u := clampf(bt / 20.0, 0.0, 1.0)
			pos = G(9.0, 15.5, 3.0).lerp(G(8.0, 16.5, 2.8), u)
			look = G(1.0, 26.5, 1.4)
			fov = 44.0
		B.CREDITS:
			var u := Valley.ss(0.0, CREDITS_LEN, bt)
			pos = IntroSequence.bez(G(8.0, 16.5, 2.8), G(8.0, 13.0, 7.0), G(6.0, 7.0, 15.0), G(4.0, 3.0, 24.0), u)
			look = G(1.0, 26.5, 1.4).lerp(G(0, 62, 3.0), Valley.ss(0.0, 90.0, bt))
			fov = lerpf(44.0, 50.0, u)
		_:
			pos = _cam_pos if _cam_pos.is_finite() else G(0, 40, 20)
			look = _cam_look
	return [pos, look, fov]

func _update_camera(dt: float) -> void:
	if cam == null or beat >= B.DONE:
		return
	if beat == B.DAWN:
		return
	var s := _shot()
	var pos: Vector3 = s[0]
	var look: Vector3 = s[1]
	# a little life from the mouse, never more than a step to the side
	var m := (_mouse_screen() / _viewport_size()) - Vector2(0.5, 0.5)
	if beat not in [B.CREDITS]:
		var right := cam.global_basis.x
		pos += right * m.x * 0.6 + Vector3.UP * -m.y * 0.25
	if _shake > 0.0 and bool(Options.get_opt("screen_shake")):
		pos += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake
	_cam_pos = pos
	_cam_look = look
	cam.global_position = pos
	if pos.distance_to(look) > 0.01:
		cam.look_at(look, Vector3.UP)
	cam.fov = float(s[2])

# ================================================================ overlay

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 18
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	marks = SkyMarks.new()
	root.add_child(marks)
	lineage = LineageView.new()
	lineage.visible = false
	root.add_child(lineage)
	_top = _bar(root, false)
	_bottom = _bar(root, true)
	_caption = _text(root, &"title", 36, CREAM)
	_caption.anchor_top = 1.0
	_caption.anchor_right = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = 120
	_caption.offset_right = -120
	_caption.offset_top = -BAR_H - 74.0
	_caption.offset_bottom = -BAR_H * 0.5 + 16.0
	_speaker = _text(root, &"title_italic", 22, GOLD)
	_speaker.anchor_top = 1.0
	_speaker.anchor_right = 1.0
	_speaker.anchor_bottom = 1.0
	_speaker.offset_top = -BAR_H - 104.0
	_speaker.offset_bottom = -BAR_H - 70.0
	_prompt = _text(root, &"title_italic", 34, GOLD)
	_prompt.anchor_top = 0.62
	_prompt.anchor_bottom = 0.62
	_prompt.anchor_right = 1.0
	_prompt.offset_top = -26
	_prompt.offset_bottom = 26
	_prompt_sub = _text(root, &"italic", 20, Color(CREAM, 0.8))
	_prompt_sub.anchor_top = 0.62
	_prompt_sub.anchor_bottom = 0.62
	_prompt_sub.anchor_right = 1.0
	_prompt_sub.offset_top = 24
	_prompt_sub.offset_bottom = 54
	_count = _text(root, &"title", 132, CREAM)
	_count.anchor_left = 0.04
	_count.anchor_top = 0.36
	_count.anchor_bottom = 0.36
	_count.anchor_right = 0.34
	_count.offset_top = -10
	_count.offset_bottom = 150
	_card = VBoxContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.anchor_top = 0.3
	_card.anchor_bottom = 0.3
	_card.offset_left = 110
	_card.offset_right = 760
	_card.offset_top = 0
	_card.offset_bottom = 200
	_card.add_theme_constant_override(&"separation", 0)
	_card.modulate.a = 0.0
	root.add_child(_card)
	_card_role = _text(_card, &"title_italic", 24, GOLD)
	_card_name = _text(_card, &"hand_bold", 76, CREAM)
	_card_rel = _text(_card, &"italic", 24, Color(CREAM, 0.9))
	for l in [_card_role, _card_name, _card_rel]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_chain = _text(root, &"hand", 32, Color(1.0, 0.9, 0.7))
	_chain.anchor_top = 1.0
	_chain.anchor_bottom = 1.0
	_chain.anchor_right = 1.0
	_chain.offset_top = -BAR_H - 150.0
	_chain.offset_bottom = -BAR_H - 108.0
	_chain.modulate.a = 0.0
	_skip_hint = _text(root, &"italic", 18, Color(CREAM, 0.7))
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left = -420
	_skip_hint.offset_right = -36
	_skip_hint.offset_top = -BAR_H * 0.5 - 14.0
	_skip_hint.offset_bottom = -BAR_H * 0.5 + 14.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.modulate.a = 0.0
	_dip = ColorRect.new()
	_dip.color = Color(0, 0, 0, 1)
	_dip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_dip)

func _bar(root: Control, bottom: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.015, 0.012)
	r.anchor_right = 1.0
	if bottom:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r

func _text(parent: Control, font: StringName, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override(&"font", UiTheme.font(font))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 2)
	l.add_theme_constant_override(&"shadow_outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _overlay(dt: float) -> void:
	# bars: in over the first seconds, out with the morning
	var bars := Valley.ss(0.0, 1.5, t_total)
	if beat == B.DAWN:
		bars *= 1.0 - Valley.ss(2.5, 5.0, bt)
	_top.offset_bottom = BAR_H * bars
	_bottom.offset_top = -BAR_H * bars
	# black: up from black at the start; short dips on the cuts
	if beat != B.DAWN:
		var dip := 0.0
		if beat == B.EVENING:
			dip = 1.0 - Valley.ss(0.3, 2.6, bt)
			for c in [12.25, 23.25]:
				dip = maxf(dip, 1.0 - clampf(absf(bt - c) / 0.35, 0.0, 1.0))
		elif beat == B.WAVE:
			dip = 1.0 - clampf(absf(bt - 5.5) / 0.35, 0.0, 1.0)
		elif bt < 0.4 and beat in [B.CREW, B.BOARDING, B.COUNTDOWN, B.WAVE, B.WORDS, B.REST]:
			dip = 1.0 - bt / 0.4
		_dip.color.a = dip
	# the line for now
	var text := ""
	var who := ""
	var a := 0.0
	for l in _lines:
		if bt >= float(l[0]) and bt <= float(l[1]):
			text = str(l[2])
			who = str(l[3]) if l.size() > 3 else ""
			a = Valley.ss(float(l[0]), float(l[0]) + 0.6, bt) * (1.0 - Valley.ss(float(l[1]) - 0.6, float(l[1]), bt))
	_caption.text = text
	_caption.modulate.a = a
	if (who != "") != _caption_voice:
		_caption_voice = who != ""
		_caption.add_theme_font_override(&"font", UiTheme.font(&"title_italic" if _caption_voice else &"title"))
	_speaker.text = who
	_speaker.modulate.a = a
	# the prompt
	_prompt_a = move_toward(_prompt_a, 1.0 if _prompt_text != "" else 0.0, dt * 2.5)
	if _prompt_text != "":
		_prompt.text = _prompt_text
		_prompt_sub.text = _prompt_small
	var pulse := 0.85 + 0.15 * sin(t_total * 3.0)
	_prompt.modulate.a = _prompt_a * pulse
	_prompt_sub.modulate.a = _prompt_a * 0.8
	_skip_hint.modulate.a = clampf(_skip_armed * 2.0, 0.0, 1.0)

# ================================================================ input

func _input(e: InputEvent) -> void:
	if done or not playing:
		return
	if e is InputEventMouseMotion:
		_wiggle += absf((e as InputEventMouseMotion).relative.x)
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_hold_in = mb.pressed
			if mb.pressed:
				_click = true
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey:
		var k := e as InputEventKey
		get_viewport().set_input_as_handled()
		if k.echo:
			return
		match k.physical_keycode:
			KEY_SPACE, KEY_E, KEY_ENTER, KEY_KP_ENTER:
				_hold_in = k.pressed
				if k.pressed:
					_click = true
			KEY_ESCAPE:
				if k.pressed:
					_on_escape()
	elif e is InputEventJoypadButton:
		var jb := e as InputEventJoypadButton
		_hold_in = jb.pressed
		if jb.pressed:
			_click = true
		get_viewport().set_input_as_handled()

func _on_escape() -> void:
	if beat == B.CREDITS and not CreditsRoll.seen():
		return      # the first time, the credits play to the end
	if _skip_armed > 0.0:
		_skip_armed = 0.0
		skip_beat()
		return
	_skip_armed = 3.0
	_skip_hint.text = "Esc again to skip the credits" if beat == B.CREDITS else "Esc again to skip this moment"

## [tests] the player's hold, as if the mouse button were down.
func set_hold(on: bool) -> void:
	_hold_in = on
	if on:
		_click = true

# ================================================================ lights, sound, voices

func _lights(on: bool) -> void:
	if on:
		_lights_in(site)
		if world.get(&"dynamic") != null:
			_lights_in(world.dynamic)
	else:
		for n in _lit:
			if is_instance_valid(n):
				n.visible = false
		_lit.clear()

func _lights_in(n: Node) -> void:
	if n == null:
		return
	if (n is Light3D or String(n.name) == "NightGlow") and not (n as Node3D).visible:
		(n as Node3D).visible = true
		_lit.append(n)
	if n is Person:
		return
	for c in n.get_children():
		_lights_in(c)

func _sfx(id: StringName, pitch: float = 1.0, db: float = 0.0) -> void:
	Audio.sfx(SFX % id, Vector3.INF, pitch, db)

func _voice(p, mood: StringName) -> void:
	if p == null or not is_instance_valid(p) or cam == null:
		return
	var was: Vector3 = p.global_position
	if not p.visible:
		p.global_position = cam.global_position - cam.global_basis.z * 2.0   # a voice from the sky: close to us
	Audio._voice_last.erase(p.get_instance_id())
	Audio.voice(p, mood)
	if not p.visible:
		p.global_position = was

## The light blinks: once at each time in _blinks.
func _blink(dt: float) -> void:
	_blink_amt = maxf(_blink_amt - dt * 2.2, 0.0)
	for i in range(_blinks.size() - 1, -1, -1):
		if bt >= float(_blinks[i]):
			_blink_amt = 1.0
			_blinks.remove_at(i)

# ================================================================ the end

## Back to play: the crew are gone (among the stars, never dead), everyone else
## is where the evening left them, the hand and the HUD come back, and it is dawn.
func _restore() -> void:
	if _restored:
		return
	_restored = true
	var names: Array = crew.map(func(p): return str(p.given_name))
	var day := Clock.day + 1
	for p in crew:
		if is_instance_valid(p):
			var r := BookData.record_of(p)
			r["alive"] = true
			BookData.remember(r)
			BookData.set_person_fact(int(p.uid), "went_to_stars", true)
			BookData.set_person_fact(int(p.uid), "status", "Among the stars")
			BookData.set_person_fact(int(p.uid), "left_day", day - 1)
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			p.queue_free()
	BookData.add_entry("goodbye", "On the %s day %s went up among the stars, to find where the hand comes from. Their light blinked twice, the old sign of the hand, and we waved back." % [BookData.ordinal(day - 1), BookData.join_names(names) if not names.is_empty() else "four of us"], day - 1)
	Village.stats["goodbye"] = {"day": day - 1, "crew": names, "commander": str(commander.given_name) if commander != null else ""}
	Village.stats["what_next"] = ["gardens", "monuments", "a museum of gifts"]
	for id in [&"powerhouse", &"launch_tower", &"the_rocket"]:
		if not Dreams.done_list().has(str(id)):
			Dreams.done_list().append(str(id))
	for p in _home:
		if is_instance_valid(p):
			p.set_physics_process(true)
			if p.visual != null and p.visual.villager != null:
				p.visual.villager.rotation.y = 0.0
	for b in _babies:
		if is_instance_valid(b[0]):
			(b[0] as Person).set_physics_process(true)
	if rocket != null and is_instance_valid(rocket):
		rocket.queue_free()
	_lights(false)
	if sky != null and is_instance_valid(sky):
		sky.queue_free()
	if hand != null and is_instance_valid(hand):
		hand.queue_free()
		hand = null
	if hand_light != null and is_instance_valid(hand_light):
		hand_light.queue_free()
	# the morning
	Clock.day = day
	Clock.is_night = false
	Clock.phase_t = 0.04 * Clock.day_seconds
	Clock.running = true
	Clock.set_speed(1)
	Events.day_started.emit(day)
	world.look.set_weather(0.0, false)
	world.look.update_now()
	var h = world.get(&"hand")
	if h != null and is_instance_valid(h):
		h.process_mode = Node.PROCESS_MODE_INHERIT
		if h is Node3D:
			h.visible = true
	var hud = world.get(&"hud")
	if hud != null and is_instance_valid(hud) and "visible" in hud:
		hud.visible = _hud_was
	var rig = world.get(&"camera_rig")
	if rig != null and is_instance_valid(rig):
		rig.process_mode = Node.PROCESS_MODE_INHERIT
		if rig.has_method(&"snap_to"):
			rig.snap_to(G(0, 30), 48.0)
	if cam != null and is_instance_valid(cam):
		cam.current = false
		cam.queue_free()
		cam = null
	if world.has_method(&"_activate_play_camera"):
		world._activate_play_camera()
	Audio.stop_cue(6.0)
	Audio.play_set(Audio.era_set(Village.era))

func _finish() -> void:
	if done:
		return
	_restore()
	done = true
	playing = false
	var tw := create_tween()
	tw.tween_property(_layer.get_child(0), "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
	finished.emit()
