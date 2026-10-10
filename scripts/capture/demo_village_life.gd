extends RefCounted
## [capture] Demo "village_life": a slow camera drift through the busy village
## while the real day turns to dusk. Nothing is staged: the people keep doing
## what the village AI has them doing (working, carrying, chatting, children
## playing); the demo only sets the clock to late afternoon so that dusk falls
## about 55 % of the way through, and tops up the village fires through the
## fire Site's own add_fuel (as a fire tender would), so they are lit when
## night comes. The hand is out of shot unless --hand-visible.
##
## Timed on the capture clock, so a run is frame-exact under --fixed-fps.

const DUSK_AT := 0.55        # fraction of the run where the day ends

var director: Node
var world: Node
var length: float = 30.0
var t: float = 0.0
var done: bool = false
var events: Array = []
var center: Vector3 = Vector3.ZERO
var from_spec: Dictionary = {}
var to_spec: Dictionary = {}
var _night_logged := false
var _hand_was_visible := true

func _init(d: Node, len_s: float) -> void:
	director = d
	world = d.world
	length = maxf(len_s, 4.0)

func log_event(n: String, detail: String = "") -> void:
	events.append([t, n, detail])
	print("capture demo village_life %5.2f s: %s %s" % [t, n, detail])

func has_event(n: String) -> bool:
	return events.any(func(e): return e[1] == n)

func begin() -> bool:
	center = _busy_center()
	# late afternoon, so the real day ends DUSK_AT of the way in
	Clock.is_night = false
	Clock.phase_t = clampf(Clock.day_seconds - length * DUSK_AT, 0.0, Clock.day_seconds - 0.5)
	if world.get(&"look") != null:
		world.look.update_now()
	var fires := 0
	for s in Village.sites:
		if s is Site and is_instance_valid(s) and s.is_fire() and s.has_method(&"add_fuel"):
			s.add_fuel(length + 60.0)
			fires += 1
	var hand = world.get(&"hand")
	if hand != null and is_instance_valid(hand):
		hand.release_all()
		hand.input_enabled = false
		hand.aim_override = Vector3(center.x, world.ground_y(center.x, center.z + 60.0), center.z + 60.0)
		_hand_was_visible = hand.visible
		if not director.clean.hand_visible:
			hand.visible = false
	var c2 := Vector2(center.x, center.z)
	from_spec = {"focus": [c2.x - 15.0, c2.y + 8.0], "dist": 36.0, "yaw_deg": -42.0, "pitch_deg": 31.0, "fov": 44.0, "tilt_shift": true}
	to_spec = {"focus": [c2.x + 11.0, c2.y - 5.0], "dist": 27.0, "yaw_deg": 22.0, "pitch_deg": 22.0, "fov": 44.0, "tilt_shift": true}
	log_event("begin", "centre (%d, %d), %d people, %d fires fed, dusk at %.0f s" % [int(center.x), int(center.z), Village.population(), fires, length * DUSK_AT])
	director.cam.drive(from_spec)
	return true

## The middle of where people are, near the old Clearing (the heart of every era).
func _busy_center() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	var core: Vector3 = world.fire_position()
	for p in Village.alive():
		if p is Node3D and Vector2(p.global_position.x - core.x, p.global_position.z - core.z).length() < 45.0:
			sum += p.global_position
			n += 1
	var c := sum / float(n) if n > 0 else core
	return c.lerp(core, 0.35)

func step(dt: float) -> void:
	if done:
		return
	t += dt
	var u: float = director.cam.ease_io(t / length)
	director.cam.drive(director.cam.lerp_spec(from_spec, to_spec, u))
	if Clock.is_night and not _night_logged:
		_night_logged = true
		log_event("dusk", "night falls, fires %s" % ("lit" if world.fire_lit() else "out"))
	if t >= length:
		_end()

func _end() -> void:
	var hand = world.get(&"hand")
	if hand != null and is_instance_valid(hand):
		hand.aim_override = Vector3.INF
		hand.input_enabled = true
		if not director.clean.on:
			hand.visible = _hand_was_visible
	if not done:
		log_event("end", "night %s, fire %s" % [Clock.is_night, world.fire_lit()])
	done = true

func stop() -> void:
	_end()
