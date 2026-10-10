class_name Era3Threats extends Node3D
## Era 3 threat director (doc 8): the town fire, sickness and storms. One at a
## time (and never with a cold snap: Threats asks major_active()), never in the
## quiet stretch after a milestone, each telegraphed first (Events.threat_warned
## + an alert naming the hand's answer). Each comes at least once in the era:
## if the dice have not brought it by its due minute, it comes at the next
## dawn it can. Era 3 hazards hurt, cost work and damage buildings; they never
## kill (doc 8: the god is benevolent, the hand is there to help).
##
##   town_fire   a building catches; it burns hotter and can spread to a
##               neighbour. A bucket line beside it (people the hand places,
##               with water from the stores), Rain held over it, and a staffed
##               fire station put it out. Left alone it burns out: the
##               building stands gutted until a repair crew rebuilds it.
##   sickness    a cough goes round: the sick work at half pace and pass it on
##               to people near them. Carried to the clinic they mend quickly
##               and stop spreading it; the aqueduct's clean water halves it.
##   storms      wind and rain off the sea: people caught outdoors are knocked
##               about (hurt) unless the hand shields them (Warmth held over
##               them) or carries them indoors; roofs are torn (a repair job),
##               and the ship stays in harbour. A staffed lighthouse sees the
##               storm coming twice as early and spares a roof.

const IDS: Array[StringName] = [&"town_fire", &"sickness", &"storms"]
## Era minute by which each threat has come at least once (if it can).
const DUE := {&"town_fire": 13.0, &"sickness": 24.0, &"storms": 33.0}
const FIRE_GROW := 1.0 / 70.0       # burn per second, left alone
const FIRE_STATION_DOUSE := 0.006   # per second per fire watcher on duty
const FIRE_SPREAD_AT := 0.65
const FIRE_SPREAD_R := 14.0
const SICK_START := 4
const SICK_SPREAD_R := 3.0
const SICK_CHANCE := 0.06           # per second, per sick person near someone well
const GUST_EVERY := 4.0
const GUST_CHANCE := 0.06
const ROOFS := 2

var current: StringName = &""
var phase: int = 0                 # 0 none, 1 warned, 2 active
var t: float = 0.0
var at: Vector3 = Vector3.ZERO
var target: Site = null            # the building that will burn
var spread_n: int = 0
var _acc: float = 0.0
var _gust: float = 0.0
var _roofs_done: bool = false

func _ready() -> void:
	name = "Era3Threats"
	Events.day_started.connect(_on_dawn)

func _def(id: StringName) -> ThreatDef:
	return Defs.threats.get(id) if "threats" in Defs else null

func active() -> bool:
	return phase > 0

func storm_on() -> bool:
	return current == &"storms" and phase == 2

static func era_minutes() -> float:
	return (Clock.total_t - float(Village.stats.get("era_started_t", 0.0))) / 60.0

static func seen() -> Array:
	if not Village.stats.has("era3_threats_seen"):
		Village.stats["era3_threats_seen"] = []
	return Village.stats["era3_threats_seen"]

func _w():
	var w = Game.world
	return w if w != null and is_instance_valid(w) else null

# ---------------------------------------------------------------- director

func _on_dawn(_d: int) -> void:
	var th = get_parent()
	if Village.era != 3 or phase > 0 or th == null or not th.enabled:
		return
	if th.quiet() or th.major_active():
		return
	var due: Array = []
	var maybe: Array = []
	for id in IDS:
		if not can(id):
			continue
		if not seen().has(str(id)) and era_minutes() >= float(DUE[id]):
			due.append(id)
		maybe.append(id)
	if Game.flags.has("threat"):
		var forced := StringName(str(Game.flags.get("threat", "")))
		if forced in IDS and can(forced):
			due = [forced]
	if not due.is_empty():
		warn(due[0])
		return
	maybe.shuffle()
	for id in maybe:
		var d := _def(id)
		var chance := (d.chance_per_day if d else 0.1) * Flags.diff_k(&"wolves")
		if Game.rng.randf() < chance:
			warn(id)
			return

func can(id: StringName) -> bool:
	var d := _def(id)
	if d != null:
		if Village.population() < d.min_population:
			return false
		if d.needs_region != &"" and not Village.regions.has(d.needs_region):
			return false
		if d.season >= 0 and Clock.season != d.season:
			return false
	# give the new town a little time to stand before its troubles come
	match id:
		&"town_fire":
			return era_minutes() > 8.0 and _fire_target() != null and Clock.season != Clock.Season.WINTER
		&"sickness":
			return era_minutes() > 16.0 or Village.count_buildings(&"clinic") > 0
		&"storms":
			return era_minutes() > 20.0 and Clock.season != Clock.Season.WINTER
	return true

func warn(id: StringName) -> void:
	current = id
	phase = 1
	var d := _def(id)
	t = d.warning_seconds if d else 30.0
	if id == &"storms" and _lighthouse_kept():
		t *= 2.0
	target = _fire_target() if id == &"town_fire" else null
	at = _where(id)
	if not seen().has(str(id)):
		seen().append(str(id))
	Village.stats["threat_" + str(id)] = int(Village.stats.get("threat_" + str(id), 0)) + 1
	Events.threat_warned.emit(id, at)
	var text := d.warning_text if d and d.warning_text != "" else "Trouble is coming"
	if id == &"town_fire" and target != null:
		text = "Smoke from the roof of the %s! A fire is catching" % target.building.title.to_lower().trim_prefix("the ")
	elif id == &"storms" and _lighthouse_kept():
		text += " The lighthouse keeper saw it early."
	Events.alert.emit(text, at)
	print("threat: %s warned at %.1f min (era %.1f)" % [id, Clock.total_t / 60.0, era_minutes()])

func _where(id: StringName) -> Vector3:
	var w = _w()
	match id:
		&"town_fire":
			return target.global_position if target != null else Site.store_point(Vector3.ZERO)
		&"storms":
			return w._v3(Vector2(330.0, 420.0)) if w and w.is_region_open(&"coast") else Site.store_point(Vector3.ZERO)
	return Site.store_point(Vector3.ZERO)

func _start() -> void:
	phase = 2
	var d := _def(current)
	t = d.duration_seconds if d else 90.0
	var w = _w()
	match current:
		&"town_fire":
			if target == null or not is_instance_valid(target) or target.state != Site.State.FINISHED:
				target = _fire_target()
			if target == null or not target.start_burning(0.1 if _fire_watch() > 0 else 0.2):
				_close()
				return
			spread_n = 0
			at = target.global_position
		&"sickness":
			var n := 0
			var c := Site.store_point(Vector3.ZERO)
			var folk := Village.alive().filter(func(p): return p.stage != Person.Stage.BABY and not p.is_sick())
			folk.sort_custom(func(a, b): return a.global_position.distance_squared_to(c) < b.global_position.distance_squared_to(c))
			for p in folk:
				if n >= SICK_START:
					break
				p.fall_sick()
				n += 1
			if n == 0:
				_close()
				return
			at = folk[0].global_position
		&"storms":
			_gust = GUST_EVERY
			_roofs_done = false
			if w and w.look:
				w.look.set_weather(1.0, true)
	Events.threat_started.emit(current, at)
	Events.alert.emit(d.start_text if d and d.start_text != "" else "It has begun", at)

func _close() -> void:
	var id := current
	current = &""
	phase = 0
	target = null
	var w = _w()
	if id == &"storms" and w and w.look:
		w.look.set_weather(0.25, false)
		Events.alert.emit("The storm has blown itself out", Site.store_point(Vector3.ZERO))
	Village.stats["quiet_until"] = maxf(float(Village.stats.get("quiet_until", -1.0)), Clock.total_t + 90.0)
	if id != &"":
		Events.threat_ended.emit(id)

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if phase == 0 or not Clock.running:
		return
	t -= delta
	match phase:
		1:
			if t <= 0.0:
				_start()
		2:
			_acc += delta
			if _acc >= 1.0:
				_tick(_acc)
				_acc = 0.0
			if phase == 2 and t <= 0.0:
				_time_up()

func _tick(dt: float) -> void:
	match current:
		&"town_fire":
			var burning := burning_sites()
			if burning.is_empty():
				Faith.add(6.0, at)
				Events.alert.emit("The fire is out! (+6 faith)", at)
				Flags.remember("A fire took hold in the town, and we put it out together, with the hand's help.")
				_close()
				return
			var watch := _fire_watch()
			for s in burning:
				s.burn_tick(dt, FIRE_GROW * (0.5 if watch > 0 else 1.0), FIRE_STATION_DOUSE * float(watch))
				if s.burn >= FIRE_SPREAD_AT and spread_n < 2 and Game.rng.randf() < 0.04 * dt:
					var n := _neighbour(s)
					if n != null and n.start_burning(0.1):
						spread_n += 1
						Events.alert.emit("The fire has jumped to the %s!" % n.building.title.to_lower().trim_prefix("the "), n.global_position)
		&"sickness":
			_spread_sickness(dt)
			if Era3Threats.count() == 0:
				Faith.add(6.0, at)
				Events.alert.emit("Everyone is well again (+6 faith)", Site.store_point(Vector3.ZERO))
				Flags.remember("A sickness went round the town. We tended the sick at the clinic, and nobody was lost.")
				_close()
		&"storms":
			_gust -= dt
			if _gust <= 0.0:
				_gust = GUST_EVERY
				_gusts()
			var d := _def(current)
			var total := d.duration_seconds if d else 80.0
			if not _roofs_done and t < total * 0.6:
				_roofs_done = true
				_tear_roofs(ROOFS - (1 if _lighthouse_kept() else 0))

func _time_up() -> void:
	match current:
		&"town_fire":
			# a fire left alone burns out what it holds; the threat ends when it is out
			for s in burning_sites():
				s.burn_out()
			Events.alert.emit("The fire has burned out. A repair crew can rebuild what it gutted", at)
		&"sickness":
			pass      # nobody new catches it; the sick mend by themselves
	_close()

# ---------------------------------------------------------------- fire

## Buildings that can catch: finished, not stone works (aqueduct, harbour,
## lighthouse, great hall), not fields or camps; the town's wooden heart first.
func _fire_target() -> Site:
	var best: Site = null
	var best_v := -INF
	for s in Village.sites:
		if not Era3Threats.flammable(s):
			continue
		var v: float = Game.rng.randf() + (1.0 if s.building.era >= 3 else 0.0) + (0.5 if s.building.shelter > 0 else 0.0)
		if v > best_v:
			best_v = v
			best = s
	return best

func _neighbour(s: Site) -> Site:
	var best: Site = null
	var bd := FIRE_SPREAD_R
	for o in Village.sites:
		if o == s or not Era3Threats.flammable(o):
			continue
		var d: float = o.global_position.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = o
	return best

## Buildings that burn (and lose roofs in storms).
const STONE_WORKS: Array[StringName] = [&"aqueduct", &"harbour", &"lighthouse", &"great_hall", &"observatory", &"bridge", &"field", &"well", &"fire_circle", &"stone_circle", &"cairn"]

static func flammable(s) -> bool:
	return is_instance_valid(s) and not s.is_queued_for_deletion() and s.building != null and s.state == Site.State.FINISHED \
		and not s.building.camp and not STONE_WORKS.has(s.building.id) and s.burn <= 0.0 and not s.lift_held

static func count() -> int:
	var n := 0
	for p in Village.alive():
		if p.is_sick():
			n += 1
	return n

static func burning_sites() -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and s.burn > 0.0)

## Watchers on duty at a fire station.
static func _fire_watch() -> int:
	var n := 0
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"fire_watch" and not s.is_plot():
			n += s.workers.filter(func(p): return is_instance_valid(p) and p.is_present_at(s, 1.6)).size()
	return n

static func _lighthouse_kept() -> bool:
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"keep_light" and not s.is_plot() and s.workers.size() > 0:
			return true
	return false

# ---------------------------------------------------------------- sickness

func _spread_sickness(dt: float) -> void:
	var k := SICK_CHANCE * dt * (0.5 if Flags.has(&"clean_water") else 1.0)
	var people := Village.alive()
	var well: Array = people.filter(func(p): return not p.is_sick() and p.stage != Person.Stage.BABY and p.visible)
	for p in people:
		if not p.is_sick() or p.at_clinic() or not p.visible:
			continue
		for q in well:
			if q.is_sick():
				continue
			if q.global_position.distance_squared_to(p.global_position) <= SICK_SPREAD_R * SICK_SPREAD_R and Game.rng.randf() < k:
				q.fall_sick()
				break

# ---------------------------------------------------------------- storms

## Gusts knock about people caught in the open (never fatal). Indoors, at a
## workshop bench, or shielded by the hand (warmed or blessed) they are safe.
func _gusts() -> void:
	for p in Village.alive():
		if not p.visible or p.stage == Person.Stage.BABY:
			continue
		if p.state in [Person.S.SHELTER, Person.S.SLEEP, Person.S.HELD, Person.S.FALL, Person.S.DEAD]:
			continue
		if p.warmed_t > 0.0 or p.is_blessed():
			continue
		if p.state == Person.S.WORK and p.job_site != null and is_instance_valid(p.job_site) and p.job_site.building != null and not p.job_site.is_plot():
			continue          # at a workshop bench, under a roof
		if Game.rng.randf() < GUST_CHANCE:
			p.hurt(0.35, &"storm")
			Village.stats["storm_hurt"] = int(Village.stats.get("storm_hurt", 0)) + 1

func _tear_roofs(n: int) -> void:
	var cands := Village.sites.filter(func(s): return Era3Threats.flammable(s) and s.damage <= 0.0)
	cands.shuffle()
	for s in cands.slice(0, maxi(n, 0)):
		s.set_damage(0.4, "The storm tore the roof off the %s. A repair crew can mend it" % s.building.title.to_lower().trim_prefix("the "))

# ---------------------------------------------------------------- state

func reset() -> void:
	current = &""
	phase = 0
	t = 0.0
	target = null
	spread_n = 0

func save_state() -> Dictionary:
	return {"current": str(current), "phase": phase, "t": t, "target": target.uid if target != null and is_instance_valid(target) else 0}

## A threat in progress comes back as its warning (a fire already burning and
## the sick come back by themselves: they are saved on the sites and people).
func load_state(d: Dictionary) -> void:
	reset()
	var id := StringName(str(d.get("current", "")))
	if not (id in IDS) or int(d.get("phase", 0)) <= 0:
		return
	current = id
	if int(d.get("phase", 0)) == 2 and (id == &"town_fire" and not burning_sites().is_empty() or id == &"sickness" and Era3Threats.count() > 0):
		phase = 2
		t = float(d.get("t", 30.0))
		at = Site.store_point(Vector3.ZERO)
		return
	phase = 1
	target = Site.by_uid(int(d.get("target", 0)))
	var td := _def(id)
	t = minf(float(d.get("t", 20.0)), td.warning_seconds if td else 20.0) if int(d.get("phase", 0)) == 1 else 15.0
	at = _where(id)
