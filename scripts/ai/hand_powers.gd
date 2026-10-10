class_name HandPowers extends Node
## What the hold-over gestures do (doc 6). The hand emits
## Events.hand_gesture(power_id, at) about twice a second while E is held:
##   warmth   warms everyone near `at`; over a fire it also feeds the flame,
##            so everyone in its glow warms up (the cold snap's hand answer)
##   blessing people near `at` work 2x for 30 s (the festival and the great
##            elk hunt need blessed people). With Blessing selected on the HUD,
##            people the hand sets down are blessed as well.

const RADIUS := 3.5
const FIRE_RADIUS := 7.0
const WARM_SECONDS := 12.0
const BLESS_SECONDS := 30.0
const FIRE_FUEL_PER_PULSE := 4.0

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
	return 0

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
