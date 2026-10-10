class_name Onboarding extends Node
## The first ten minutes (design doc 11.4), taught by situations, never by
## tutorial screens. Beats run in order; Village.stats["onboarding"] holds the
## current one (so it saves) and Village.stats["beat_times"] the game time each
## beat began (the onboarding test reads it).
##
##   STORM     storm night, two people huddled; lift the branch (storm_opening.gd)
##   DAWN      they run into the cave; at dawn the UI may name them
##   BERRIES   one of them points at the berry bushes; place them there
##   FIRE_LOG  a log for the fire needs two carriers (grip 1: one, then the other)
##   FIRE_LIT  they light their first fire
##   GIFT      a handprint stone by the fire: picking it up grants Grip II
##   DREAM     the first Village Dream appears and a wanderer walks in
##   DONE

enum Beat { STORM, DAWN, BERRIES, FIRE_LOG, FIRE_LIT, GIFT, DREAM, DONE }
const NAMES: Array[String] = ["storm", "dawn", "berries", "fire_log", "fire_lit", "gift", "dream", "done"]

const BERRIES_NEEDED := 2          # armfuls of berries carried to the store before the fire log appears
const BERRY_TIMEOUT := 240.0       # a patient player still gets the next beat
const GIFT_DELAY := 8.0            # seconds after the fire is lit
const GIFT_TIMEOUT := 240.0        # the dream comes even if the stone is left lying
const DREAM_DELAY := 20.0          # seconds after Grip II
const LOG_SPOT := Vector2(-10.0, -5.0)
## Earliest game time for some beats, so even a quick player gets the doc's
## minute marks (11.4): the log at minute 3, the first dream at minute 8.
const FIRE_LOG_AT := 170.0
const DREAM_AT := 470.0

var _t: float = 0.0                # game seconds in the current beat
var _log_site: Site = null

func _ready() -> void:
	name = "Onboarding"
	Events.sim_tick.connect(_on_tick)
	Events.job_completed.connect(_on_job_completed)
	Events.power_unlocked.connect(_on_power)

static func beat() -> int:
	return Flags.beat()

## Starts a new game's onboarding (World.new_game calls this through VillageAI).
static func reset() -> void:
	Village.stats["onboarding"] = Beat.STORM
	Village.stats["beat_times"] = {"storm": Clock.total_t}

func _set_beat(b: int) -> void:
	if b <= Onboarding.beat():
		return
	Village.stats["onboarding"] = b
	if not Village.stats.has("beat_times"):
		Village.stats["beat_times"] = {}
	Village.stats["beat_times"][NAMES[b]] = Clock.total_t
	_t = 0.0
	print("onboarding: %s at %.0fs" % [NAMES[b], Clock.total_t])
	_enter(b)

func first_two() -> Array:
	var out: Array = Village.alive().filter(func(p): return p.first_two)
	if out.size() < 2:
		out = Village.alive().slice(0, 2)
	return out

func _enter(b: int) -> void:
	var two := first_two()
	match b:
		Beat.DAWN:
			Events.name_requested.emit(two, &"first_two")
			for p in two:
				p.adjust_trust(0.4)       # they look up at the hand
			_set_beat.call_deferred(Beat.BERRIES)
		Beat.BERRIES:
			var bush := _nearest_bush(two[0].global_position if not two.is_empty() else Vector3.ZERO)
			if bush != null and not two.is_empty():
				two[0].point_at(bush)
				Events.alert.emit("%s points at the berry bushes" % two[0].given_name, bush.global_position)
		Beat.FIRE_LOG:
			_spawn_log()
		Beat.FIRE_LIT:
			Flags.set_flag(&"first_fire")
			Flags.remember("The hand brought us the log for our first fire.")
			var f := _fire()
			Events.alert.emit("They light their first fire", f.global_position if f else Vector3.ZERO)
		Beat.GIFT:
			var f2 := _fire()
			var giver: Person = two[0] if not two.is_empty() else null
			Village.stats["first_gift"] = true
			var g := Gifts.spawn_gift(giver, f2.global_position if f2 else Vector3.INF, &"grip_2", "handprint stone")
			if g != null:
				g.faith_value = 3.0
		Beat.DREAM:
			pass    # Dreams.update() starts the first dream now; the dream brings the wanderer
		Beat.DONE:
			pass

func _on_tick(dt: float) -> void:
	var b := Onboarding.beat()
	if b >= Beat.DONE:
		return
	_t += dt
	match b:
		Beat.STORM:
			var w = Game.world
			var storm_done: bool = w == null or not is_instance_valid(w) or w.storm == null or not w.storm.active()
			if storm_done and not Clock.is_night:
				_set_beat(Beat.DAWN)
		Beat.BERRIES:
			var picked := int(Village.stats.get("onboarding_berries", 0)) >= BERRIES_NEEDED
			if (picked and Clock.total_t >= FIRE_LOG_AT) or _t > BERRY_TIMEOUT:
				_set_beat(Beat.FIRE_LOG)
		Beat.FIRE_LOG:
			if (_log_site == null or not is_instance_valid(_log_site)) and _find_log() == null:
				_spawn_log()
		Beat.FIRE_LIT:
			if _t >= GIFT_DELAY:
				_set_beat(Beat.GIFT)
		Beat.GIFT:
			if Faith.has(&"grip_2") and _t >= 1.0:
				if _t >= DREAM_DELAY and Clock.total_t >= DREAM_AT:
					_set_beat(Beat.DREAM)
			elif _t > GIFT_TIMEOUT:
				_set_beat(Beat.DREAM)
		Beat.DREAM:
			if str(Village.stats.get("dream_active", "")) != "" or Dreams.is_done(&"shelter_of_our_own"):
				_set_beat(Beat.DONE)

func _on_job_completed(site) -> void:
	if Onboarding.beat() == Beat.BERRIES and site is Site and is_instance_valid(site) and site.job != null and site.job.id == &"gather_berries":
		Village.stats["onboarding_berries"] = int(Village.stats.get("onboarding_berries", 0)) + 1
	if Onboarding.beat() == Beat.FIRE_LOG and site is Site and is_instance_valid(site) and site.job != null and site.job.id == &"carry_log":
		_set_beat(Beat.FIRE_LIT)

func _on_power(id: StringName) -> void:
	if id == &"grip_2" and Onboarding.beat() == Beat.GIFT:
		_t = 0.0
		Flags.remember("The hand picked up our handprint stone, and its grip grew.")

func _fire() -> Site:
	var w = Game.world
	var at: Vector3 = w.fire_position() if w != null and is_instance_valid(w) else Vector3.ZERO
	return Site.nearest(at, 40.0, func(s): return s.is_fire())

func _nearest_bush(from: Vector3) -> Site:
	return Site.nearest(from, 60.0, func(s): return s.job != null and s.job.id == &"gather_berries" and s.can_accept(1) and s.can_work_now())

func _find_log() -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"carry_log" and not s.is_queued_for_deletion():
			return s
	return null

func _spawn_log() -> void:
	_log_site = _find_log()
	if _log_site != null:
		return
	var w = Game.world
	if w == null or not is_instance_valid(w) or not w.has_method("spawn_site"):
		return
	_log_site = w.spawn_site(&"carry_log", Vector3(LOG_SPOT.x, 0, LOG_SPOT.y))
	if _log_site != null:
		_log_site.rotation.y = 0.6
		var two := first_two()
		if two.size() > 1:
			two[1].point_at(_log_site)
		Events.alert.emit("A log for the fire. It takes two to carry it.", _log_site.global_position)
