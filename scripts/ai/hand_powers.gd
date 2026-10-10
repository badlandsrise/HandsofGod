class_name HandPowers extends Node
## What the hold-over gestures do (doc 6). The hand emits
## Events.hand_gesture(power_id, at) about twice a second while E is held:
##   warmth   warms everyone near `at`; over a fire it also feeds the flame,
##            so everyone in its glow warms up (the cold snap's hand answer)
##   blessing people near `at` work 2x for 30 s (the festival and the great
##            elk hunt need blessed people). With Blessing selected on the HUD,
##            people the hand sets down are blessed as well.
##   rain     (Era 2) rain falls from the hand onto the fields near `at`:
##            they drink it up, the answer to a drought and the way the dry
##            Southern Plains are farmed. (Era 3) Over a burning building it
##            beats the fire down.
##   calm_waters  (Era 3) over the sea: the waves lie down for a while, so
##            the ship can sail to the islands (Era3World.calm)
##   guiding_light (Era 3) at night over the sky: the northern lights come
##            out, and astronomers at the observatory work twice as fast
## In a storm (Era 3) Warmth held over people also shields them from the gusts.

const RADIUS := 3.5
const FIRE_RADIUS := 7.0
const WARM_SECONDS := 12.0
const BLESS_SECONDS := 30.0
const FIRE_FUEL_PER_PULSE := 4.0
const RAIN_RADIUS := 7.0
const RAIN_PER_PULSE := 0.08
const RAIN_DOUSE := 0.05
const GUIDE_SECONDS := 20.0

var _rain_fx: CPUParticles3D = null
var _rain_t: float = 0.0

func _ready() -> void:
	name = "HandPowers"
	Events.hand_gesture.connect(on_gesture)
	Events.hand_placed.connect(_on_placed)

## Returns how many people the pulse touched.
func on_gesture(id: StringName, at: Vector3) -> int:
	match id:
		&"warmth":
			return warm_at(at)
		&"blessing":
			return bless_at(at)
		&"rain":
			_show_rain(at)
			return rain_at(at) + douse_at(at)
		&"calm_waters":
			return calm_at(at)
		&"guiding_light":
			return guide_at(at)
	return 0

## Rain on a burning building beats the fire down.
static func douse_at(at: Vector3) -> int:
	var n := 0
	for s in Village.sites:
		if not is_instance_valid(s) or s.burn <= 0.0:
			continue
		var d: Vector3 = s.global_position - at
		d.y = 0.0
		if d.length() <= s.pick_radius() + RAIN_RADIUS * 0.5:
			s.douse(RAIN_DOUSE)
			n += 1
	if n > 0:
		Village.stats["rain_on_fire"] = int(Village.stats.get("rain_on_fire", 0)) + 1
	return n

## Calm Waters over open water: the sea lies down for a while.
static func calm_at(at: Vector3) -> int:
	var w = Game.world
	if w == null or not is_instance_valid(w) or w.get("era3") == null:
		return 0
	w.era3.calm(at)
	return 1

## The Guiding Light at night: the northern lights, and the astronomers see far.
static func guide_at(at: Vector3) -> int:
	var w = Game.world
	if w == null or not is_instance_valid(w) or w.get("era3") == null:
		return 0
	if not Clock.is_night:
		return 0
	w.era3.northern_lights(GUIDE_SECONDS)
	Village.stats["guided_t"] = Clock.total_t + GUIDE_SECONDS
	var n := 0
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"astronomy" and not s.is_plot():
			for p in s.workers:
				if is_instance_valid(p):
					p.bless(GUIDE_SECONDS)
					n += 1
	Village.stats["guide_pulses"] = int(Village.stats.get("guide_pulses", 0)) + 1
	return maxi(n, 1)

## Waters every field within RAIN_RADIUS of `at`; returns how many.
static func rain_at(at: Vector3) -> int:
	var n := 0
	for s in Village.sites:
		if not is_instance_valid(s) or not s.is_field():
			continue
		var d: Vector3 = s.global_position - at
		d.y = 0.0
		if d.length() <= RAIN_RADIUS:
			s.rain_on(RAIN_PER_PULSE)
			n += 1
	if n > 0:
		Village.stats["rain_pulses"] = int(Village.stats.get("rain_pulses", 0)) + 1
	return n

## A short shower falling from under the hand.
func _show_rain(at: Vector3) -> void:
	var w = Game.world
	if w == null or not is_instance_valid(w) or DisplayServer.get_name() == "headless":
		return
	if _rain_fx == null or not is_instance_valid(_rain_fx):
		_rain_fx = CPUParticles3D.new()
		_rain_fx.name = "HandRain"
		_rain_fx.amount = 220
		_rain_fx.lifetime = 0.9
		_rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_rain_fx.emission_box_extents = Vector3(4.5, 0.4, 4.5)
		_rain_fx.direction = Vector3(0, -1, 0)
		_rain_fx.spread = 4.0
		_rain_fx.gravity = Vector3(0, -30, 0)
		_rain_fx.initial_velocity_min = 8.0
		_rain_fx.initial_velocity_max = 11.0
		var q := QuadMesh.new()
		q.size = Vector2(0.03, 0.5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		q.material = m
		_rain_fx.mesh = q
		w.add_child(_rain_fx)
	_rain_fx.global_position = at + Vector3(0, 9.0, 0)
	_rain_fx.emitting = true
	_rain_t = 0.8

func _process(delta: float) -> void:
	if _rain_t > 0.0:
		_rain_t -= delta
		if _rain_t <= 0.0 and _rain_fx != null and is_instance_valid(_rain_fx):
			_rain_fx.emitting = false

static func _people_near(at: Vector3, r: float) -> Array:
	var out: Array = []
	for p in Village.alive():
		var d: Vector3 = p.global_position - at
		d.y = 0.0
		if d.length() <= r:
			out.append(p)
	return out

static func warm_at(at: Vector3) -> int:
	var r := RADIUS
	var fire := Site.nearest(at, 3.0, func(s): return s.is_fire() or (s.building != null and s.building.warmth_radius > 0.0))
	if fire != null:
		fire.add_fuel(FIRE_FUEL_PER_PULSE)
		r = maxf(fire.warmth_radius(), FIRE_RADIUS)
		at = fire.global_position
	var n := 0
	for p in _people_near(at, r):
		p.warm(WARM_SECONDS)
		n += 1
	if n > 0:
		Village.stats["warmed"] = int(Village.stats.get("warmed", 0)) + n
	return n

static func bless_at(at: Vector3) -> int:
	var r := RADIUS
	var fire := Site.nearest(at, 3.0, func(s): return s.is_fire())
	if fire != null:
		r = FIRE_RADIUS
		at = fire.global_position
	var site := Site.nearest(at, 3.0, func(s): return s.job != null and s.job.needs_blessed)
	if site != null:
		r = maxf(r, site.pick_radius() + 2.0)
		at = site.global_position
	var n := 0
	for p in _people_near(at, r):
		if p.stage == Person.Stage.BABY:
			continue
		p.bless(BLESS_SECONDS)
		n += 1
	if n > 0:
		Village.stats["blessed"] = int(Village.stats.get("blessed", 0)) + n
	return n

func _on_placed(people: Array, _target) -> void:
	if not Faith.has(&"blessing"):
		return
	var w = Game.world
	var hand = w.get("hand") if w != null and is_instance_valid(w) else null
	if hand == null or not is_instance_valid(hand) or hand.get("selected_power") != &"blessing":
		return
	for p in people:
		if is_instance_valid(p) and p is Person:
			p.bless(BLESS_SECONDS)

func _exit_tree() -> void:
	if _rain_fx != null and is_instance_valid(_rain_fx):
		_rain_fx.queue_free()
