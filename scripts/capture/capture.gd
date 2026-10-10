extends Node
## [capture] Developer-only MARKETING CAPTURE MODE (docs/CAPTURE.md).
## Attached by the world only when the command line has `-- --capture`; in
## normal play this file is never loaded and nothing of it shows.
##
##   --capture                 skip the splash, title and intro; open a bundled start state
##   --era=1|2|3               which start state (data/capture/era*_*.json); default 1
##   --seed=N                  RNG seed (default 1): the same seed is the same footage
##   --cam=<preset|move>       a camera preset or move from data/capture/cameras.json
##   --hide-ui                 start with clean frames      --hand-visible   keep the glove in shot
##   --demo=worker_placement|village_life   run a scripted demonstration
##   --demo-length=S           its fixed length in seconds (default 30)
##   --quit-after[=S]          quit when the demo ends (or after S capture seconds)
##   --weather=clear|rain|storm  weather (default clear)
##   --paused                  start paused                 --threats        allow threats (off by default)
##   --tod=0..1                time of day (0 dawn, 0.5 late afternoon)   --season=spring|summer|autumn|winter
##   --spoiler=goodbye         SPOILER: the goodbye (the `--goodbye` dev entry) with capture controls
##
## Keys: 1-9 presets/moves, 0 free camera, H hide UI, G hand visible, P pause,
## R reset, [ ] time of day, N next season, K / V demos, Shift+1-3 switch era,
## F1 (held) the controls card.
##
## Determinism: Clock.real_delta (wall-clock) drives the hand, the camera rig,
## the HUD and the goodbye. In capture mode a node that runs straight after
## Clock replaces it with the engine's frame step, so under Movie Maker
## (--write-movie, which forces --fixed-fps) every frame is the same each run.
## Saves are switched off: capture never writes over the player's valley.

const STARTS := {1: "res://data/capture/era1_mid.json", 2: "res://data/capture/era2_start.json", 3: "res://data/capture/era3_start.json"}
const DEMOS := {"worker_placement": "res://scripts/capture/demo_worker_placement.gd", "village_life": "res://scripts/capture/demo_village_life.gd"}
const CAMERA := preload("res://scripts/capture/capture_camera.gd")
const CLEAN := preload("res://scripts/capture/capture_clean.gd")
const OVERLAY := preload("res://scripts/capture/capture_overlay.gd")
const CLOCK_FIX := preload("res://scripts/capture/capture_clock.gd")
const LATE := preload("res://scripts/capture/capture_late.gd")
const INPUT := preload("res://scripts/capture/capture_input.gd")
const DEFAULT_DEMO_LENGTH := 30.0
const SETTLE := 1.5           # seconds after a (re)load before a demo starts
const SEASONS := ["spring", "summer", "autumn", "winter"]
## Keys the game binds that capture mode takes over (game.gd ACTIONS).
const TAKEN := {&"speed_1": KEY_1, &"speed_2": KEY_2, &"speed_3": KEY_3, &"cam_rot_right": KEY_R,
	&"book": KEY_F1, &"quicksave": KEY_F5, &"quickload": KEY_F9}

signal state_loaded(era: int)

var world: Node = null
var era: int = 1
var seed_v: int = 1
var spoiler: String = ""
var cam: Node = null
var clean: Node = null
var overlay: CanvasLayer = null
var demo = null                     # the running demo (RefCounted), or null
var demo_id: String = ""
var demo_length: float = DEFAULT_DEMO_LENGTH
var start_state: Dictionary = {}
var loaded: bool = false
var paused: bool = false
var t: float = 0.0                  # capture seconds since start (game time, frame-exact)
var quit_at: float = -1.0
var quit_on_demo_end: bool = false
var log: Array = []                 # [t, line]

var _pending_demo: String = ""
var _pending_t: float = 0.0
var _last_unscaled: float = 1.0 / 30.0
var _time_fix: Node = null
var _late: Node = null
var _input: Node = null

func _init() -> void:
	name = "Capture"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -50

func _ready() -> void:
	world = get_parent()
	var f: Dictionary = Game.flags
	era = clampi(int(f.get("era", 1)), 1, 3)
	seed_v = int(f.get("seed", 1))
	spoiler = str(f.get("spoiler", "")) if f.has("spoiler") else ""
	if spoiler == "true":
		spoiler = "goodbye"
	demo_length = float(f.get("demo-length", DEFAULT_DEMO_LENGTH))
	if f.has("quit-after"):
		var q := str(f["quit-after"])
		if q == "true" or q == "":
			quit_on_demo_end = true
		else:
			quit_at = float(q)
	Save.enabled = false
	_take_keys()
	_install_clock()
	cam = CAMERA.new()
	cam.world = world
	cam.load_data()
	add_child(cam)
	clean = CLEAN.new()
	clean.world = world
	add_child(clean)
	overlay = OVERLAY.new()
	overlay.director = self
	add_child(overlay)
	clean.keep.append(overlay)
	_late = _helper(LATE, "CaptureLate", 900)
	add_child(_late)
	# key input reaches the last child of the root first (before the HUD and the goodbye)
	_input = _helper(INPUT, "CaptureInput", 0)
	get_tree().root.add_child.call_deferred(_input)
	_say("capture mode: era %d, seed %d%s" % [era, seed_v, (", SPOILER " + spoiler) if spoiler != "" else ""])
	_begin.call_deferred()

func _exit_tree() -> void:
	if _input != null and is_instance_valid(_input):
		_input.queue_free()

func _say(s: String) -> void:
	log.append([t, s])
	print(s)

# ---------------------------------------------------------------- setup

## Capture mode owns these keys; the game's bindings for them are lifted (this
## session only) so a number key never also changes the game speed.
func _take_keys() -> void:
	for act in TAKEN:
		if not InputMap.has_action(act):
			continue
		for ev in InputMap.action_get_events(act):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == TAKEN[act]:
				InputMap.action_erase_event(act, ev)

## A node that runs right after Clock and replaces its wall-clock real_delta
## with this frame's engine step (exact under --fixed-fps).
func _install_clock() -> void:
	Clock.process_priority = -100
	_time_fix = _helper(CLOCK_FIX, "CaptureClock", -99)
	add_child(_time_fix)

func _helper(script: Script, n: String, prio: int) -> Node:
	var h: Node = script.new()
	h.name = n
	h.process_priority = prio
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	h.set(&"director", self)
	return h

func unscaled(delta: float) -> float:
	if Engine.time_scale > 0.0001:
		_last_unscaled = minf(delta / Engine.time_scale, 0.1)
	return _last_unscaled

func _begin() -> void:
	if spoiler != "":
		_begin_spoiler()
		return
	load_era(era, false)
	var c := str(Game.flags.get("cam", ""))
	if c != "" and c != "true":
		if not cam.go(c, era):
			push_warning("capture: no camera preset or move '%s'" % c)
	if Game.flags.has("hide-ui"):
		clean.set_on(true)
	if Game.flags.has("hand-visible"):
		clean.set_hand_visible(true)
	if Game.flags.has("paused"):
		set_paused(true)
	var d := str(Game.flags.get("demo", ""))
	if d != "" and d != "true":
		queue_demo(d)

## Loads the bundled start state of era `n` (the same every time), resets the
## clock, the seeds and the threats. Keeps the camera where it is when `keep_cam`.
func load_era(n: int, keep_cam: bool = true) -> bool:
	stop_demo()
	era = clampi(n, 1, 3)
	var path: String = STARTS[era]
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	_reseed()
	if not loaded:
		world.new_game()       # the same path the bot takes before it loads a save
	if d is Dictionary:
		start_state = d
		Save.apply(Save.migrate((d as Dictionary).duplicate(true)))
	else:
		push_warning("capture: missing start state %s; a new valley instead" % path)
		start_state = {}
		world.new_game()
	world.set_title_mode(false)
	Clock.running = true
	set_paused(false)
	if world.get(&"threats") != null:
		world.threats.enabled = Game.flags.has("threats")
	_apply_time_flags()
	Audio.play_set(Audio.era_set(Village.era))
	loaded = true
	if not keep_cam or cam.mode == &"free" or cam.mode == &"demo":
		_frame_default()
	elif cam.current != "":
		cam.go(cam.current, era)       # the same preset, this era's version
	_say("capture: loaded era %d (%s): pop %d, day %d" % [era, path.get_file(), Village.population(), Clock.day])
	state_loaded.emit(era)
	return d is Dictionary

func _reseed() -> void:
	seed(seed_v)
	Game.rng.seed = seed_v
	Game.flags["seed"] = str(seed_v)

func _frame_default() -> void:
	cam.release()
	var rig = world.get(&"camera_rig")
	if rig != null and rig.has_method(&"snap_to"):
		var p: Dictionary = cam.preset_spec(str(cam.data.get("default", "village_close")), era)
		var f: Array = p.get("focus", [0, -6])
		if "target_yaw" in rig:
			rig.target_yaw = deg_to_rad(float(p.get("yaw_deg", 0.0)))
			rig.yaw = rig.target_yaw
		rig.snap_to(Vector3(float(f[0]), 0, float(f[1])), float(p.get("dist", 40.0)))

func _apply_time_flags() -> void:
	if Game.flags.has("season"):
		var s := SEASONS.find(str(Game.flags["season"]).to_lower())
		if s >= 0:
			set_season(s)
	if Game.flags.has("tod"):
		set_day_fraction(float(Game.flags["tod"]))
	var wx := str(Game.flags.get("weather", "clear")).to_lower()
	world.look.set_weather({"clear": 0.0, "rain": 0.6, "storm": 1.0}.get(wx, 0.0), wx == "storm")

## Back to the start state: the same valley, seeds, clock and camera, and the
## demo from its first frame if one was running.
func reset() -> void:
	if spoiler != "":
		_reset_spoiler()
		return
	var was := demo_id if demo != null else _pending_demo
	var shot: String = cam.current if cam.mode in [&"preset", &"move"] else ""
	load_era(era, false)
	if shot != "":
		cam.go(shot, era)
	if was != "":
		queue_demo(was)
	_say("capture: reset")

# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	var dt := delta          # game seconds: 0 while paused, frame-exact under --fixed-fps
	t += unscaled(delta) if not paused else 0.0
	if spoiler != "":
		_spoiler_frame()
	if paused:
		dt = 0.0
	if _pending_demo != "" and loaded:
		_pending_t -= dt
		if _pending_t <= 0.0:
			var id := _pending_demo
			_pending_demo = ""
			start_demo(id)
	if demo != null:
		demo.step(dt)
		if demo.done:
			_say("capture: demo %s done at %.2f s, state hash %d" % [demo_id, demo.t, state_hash()])
			var ended := demo_id
			demo = null
			demo_id = ""
			cam.release()
			if quit_on_demo_end:
				_quit("demo %s done" % ended)
	cam.step(dt)
	if cam.move_done():
		pass        # a move holds its last frame until another key
	if quit_at > 0.0 and t >= quit_at:
		_quit("--quit-after=%s" % str(quit_at))
	_keep_flowing()

## Late in the frame (after the rig, the hand and the goodbye): pose the camera.
func late() -> void:
	cam.apply()

## Footage must not stall on a modal card: a naming request takes the names
## the game rolled (the real accept path), an era card keeps playing.
func _keep_flowing() -> void:
	var hud = world.get(&"hud")
	if hud == null or not is_instance_valid(hud):
		return
	for n in hud.find_children("*", "", true, false):
		if n.has_method(&"is_open") and n.call(&"is_open"):
			if n.has_method(&"accept"):
				n.call(&"accept")
			elif n.has_method(&"keep_playing"):
				n.call(&"keep_playing")

## A fingerprint of the valley now (people, hand, camera, clock): two runs
## of the same demo under --fixed-fps print the same number.
func state_hash() -> int:
	var parts: Array = [snappedf(Clock.total_t, 0.001)]
	var ps: Array = Village.people.filter(func(p): return is_instance_valid(p))
	ps.sort_custom(func(a, b): return a.uid < b.uid)
	for p in ps:
		parts.append([p.uid, p.state, (p.global_position as Vector3).snapped(Vector3.ONE * 0.01)])
	var h = world.get(&"hand")
	if h != null and is_instance_valid(h):
		parts.append((h.air_pos as Vector3).snapped(Vector3.ONE * 0.01))
	var c := get_viewport().get_camera_3d()
	if c != null:
		parts.append(c.global_position.snapped(Vector3.ONE * 0.01))
	return hash(str(parts))

var _quitting := false
func _quit(why: String) -> void:
	if _quitting:
		return
	_quitting = true
	_say("capture: quitting (%s)" % why)
	get_tree().quit()

# ---------------------------------------------------------------- controls

func set_paused(on: bool) -> void:
	paused = on
	Clock.set_speed(0 if on else 1)

func toggle_pause() -> void:
	set_paused(not paused)

func shot_key(k: int) -> void:
	var n: String = cam.name_for_key(k, spoiler != "")
	if n == "":
		return
	if spoiler != "":
		spoiler_preset(n)
		return
	if demo != null:
		stop_demo()
	cam.go(n, era)
	_say("capture: camera %s" % n)

## Time of day as 0..1 of the whole day and night (0 = dawn).
func set_day_fraction(f: float) -> void:
	f = fposmod(f, 1.0)
	var full := Clock.day_seconds + Clock.night_seconds
	var at := f * full
	var was_night := Clock.is_night
	if at < Clock.day_seconds:
		Clock.is_night = false
		Clock.phase_t = at
	else:
		Clock.is_night = true
		Clock.phase_t = at - Clock.day_seconds
	if Clock.is_night and not was_night:
		Events.night_started.emit(Clock.day)       # people head home, lamps and fires
	elif was_night and not Clock.is_night:
		Events.day_started.emit(Clock.day)
	if world.get(&"look") != null:
		world.look.update_now()

func nudge_time(step: float) -> void:
	set_day_fraction(Clock.day_fraction() + step)

func set_season(s: int) -> void:
	Clock.season = clampi(s, 0, 3)
	Clock.season_t = Clock.season_seconds * 0.4       # past the thaw, before the turn
	Events.season_changed.emit(Clock.season)
	if world.get(&"look") != null:
		world.look.update_now()

func next_season() -> void:
	set_season((Clock.season + 1) % 4)
	_say("capture: season %s" % SEASONS[Clock.season])

# ---------------------------------------------------------------- demos

func queue_demo(id: String) -> void:
	if not DEMOS.has(id):
		push_warning("capture: no demo '%s' (worker_placement, village_life)" % id)
		return
	_pending_demo = id
	_pending_t = SETTLE

func start_demo(id: String) -> bool:
	stop_demo()
	if not DEMOS.has(id):
		return false
	demo = load(DEMOS[id]).new(self, demo_length)
	demo_id = id
	_say("capture: demo %s (%.0f s)" % [id, demo_length])
	if not demo.begin():
		_say("capture: demo %s could not start" % id)
		var d = demo
		demo = null
		demo_id = ""
		if quit_on_demo_end:
			_quit("demo %s could not start" % id)
		return false
	return true

func stop_demo() -> void:
	if demo != null:
		demo.stop()
	demo = null
	demo_id = ""

# ---------------------------------------------------------------- SPOILER: the goodbye

func _begin_spoiler() -> void:
	if spoiler != "goodbye":
		push_warning("capture: unknown spoiler '%s' (goodbye)" % spoiler)
		spoiler = "goodbye"
	_say("capture: SPOILER footage: the goodbye")
	_reseed()
	world.call(&"_dev_goodbye")          # the existing --goodbye dev entry
	_spoiler_setup()
	loaded = true
	if Game.flags.has("hide-ui"):
		clean.set_on(true)
	if Game.flags.has("paused"):
		set_paused(true)
	var c := str(Game.flags.get("cam", ""))
	if c != "" and c != "true":
		spoiler_preset(c)
	state_loaded.emit(4)

func _spoiler_setup() -> void:
	var seq = goodbye()
	if seq == null:
		return
	if not Game.flags.has("manual"):
		seq.autopilot = true                       # it plays the player's part
		seq.mouse_override = Vector2(0.5, 0.5)     # no mouse sway: frame-exact
	if Game.flags.has("threats") == false and world.get(&"threats") != null:
		world.threats.enabled = false

func goodbye():
	var g = world.get(&"goodbye")
	return g if g != null and is_instance_valid(g) else null

func spoiler_beat() -> String:
	var g = goodbye()
	return str(g.beat_name()) if g != null else "-"

func _spoiler_frame() -> void:
	var g = goodbye()
	if g != null:
		g.rate = 0.0 if paused else 1.0

## Jumps to a beat (rebuilding the goodbye first when the beat is behind),
## or pins a camera in the launch site's frame.
func spoiler_preset(n: String) -> bool:
	var p: Dictionary = cam.spoiler_presets().get(n, {})
	var g = goodbye()
	if p.is_empty() or g == null:
		push_warning("capture: no spoiler preset '%s'" % n)
		return false
	if p.has("beat"):
		var b: int = GoodbyeSequence.BEAT_NAMES.find(StringName(str(p["beat"])))
		if b < 0:
			return false
		if g.beat > b or (g.beat == b and g.bt > float(p.get("at", 0.0))):
			_reset_spoiler()
			g = goodbye()
		g.jump_to(b, float(p.get("at", 0.0)))
		cam.release()
	else:
		var pos: Array = p.get("pos", [20, 6, 40])
		var look: Array = p.get("look", [0, 10, 0])
		cam.pin(g.L(Vector3(pos[0], pos[1], pos[2])), g.L(Vector3(look[0], look[1], look[2])), float(p.get("fov", 45.0)), n)
	_say("capture: SPOILER preset %s (beat %s)" % [n, g.beat_name()])
	return true

func _reset_spoiler() -> void:
	var g = goodbye()
	if g != null:
		g.playing = false
		g._restore()
		g.done = true
		world.remove_child(g)
		g.queue_free()
		world.goodbye = null
	cam.release()
	_reseed()
	world.call(&"_dev_goodbye")
	_spoiler_setup()
	_say("capture: SPOILER reset")

# ---------------------------------------------------------------- keys

func handle_key(k: InputEventKey) -> bool:
	if k.physical_keycode == KEY_F1:
		overlay.set_held(k.pressed)
		return true
	if not k.pressed or k.echo:
		return k.physical_keycode in [KEY_H, KEY_G, KEY_P, KEY_R, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_N, KEY_K, KEY_V,
			KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_F5, KEY_F9]
	var kc := k.physical_keycode
	if kc >= KEY_1 and kc <= KEY_9:
		if k.shift_pressed and spoiler == "" and kc <= KEY_3:
			load_era(kc - KEY_0, true)
		else:
			shot_key(kc - KEY_0)
		return true
	match kc:
		KEY_0:
			stop_demo()
			cam.release()
		KEY_H:
			clean.set_on(not clean.on)
		KEY_G:
			clean.set_hand_visible(not clean.hand_visible)
		KEY_P:
			toggle_pause()
		KEY_R:
			reset()
		KEY_BRACKETLEFT:
			nudge_time(-1.0 / 24.0)
		KEY_BRACKETRIGHT:
			nudge_time(1.0 / 24.0)
		KEY_N:
			next_season()
		KEY_K:
			if spoiler == "":
				start_demo("worker_placement")
		KEY_V:
			if spoiler == "":
				start_demo("village_life")
		KEY_F5, KEY_F9:
			pass                     # no saving or loading in capture mode
		KEY_SPACE:
			if spoiler != "":
				return false         # the goodbye's own hold
			toggle_pause()
		_:
			return false
	return true
