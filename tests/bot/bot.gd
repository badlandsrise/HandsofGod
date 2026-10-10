extends Node
## Headless test bot. Attached by the world when Game.flags has "test".
## Plays Era 1 the way a reasonable player would, through the game's own APIs
## (the hand's lift/scoop/place calls, Faith.buy, Events.hand_gesture), never
## through input events: lifts the storm branch, staffs work by need, prefers
## group jobs it can fill, scoops with Hand.scoop_lift once it has Grip II,
## buys powers as their prerequisites open, lifts the meadow logs, warms the
## cold in winter, blesses the festival dancers and the elk hunters, shoos
## wolves, and picks up gifts. Prints a report every in-game day and a
## timeline at the end, and FAILS if Era 1 completes faster than its pacing
## floor (EraDef.gate_min_minutes, 35 game minutes).
##
## Flags (after "--"):
##   --test                 attach the bot
##   --shot=a.png[,b.png]   screenshot path(s) (needs a renderer, not --headless)
##   --shot-at=15,90        game seconds for each screenshot
##   --quit-after-game=N    quit after N game seconds (default 240)
##   --until-era=2          quit shortly after this era begins (the gate is done)
##   --expect-gate          FAIL if Era 1 is not complete when the bot quits
##   --speed=N              Engine.time_scale (default 4 headless, 2 with shots)
##   --verbose              per-person lines in the daily report
##   --save-gate=path.json  write a save as soon as Era 2 begins (to start the bot there later)
##   --load=path.json       start from that save (e.g. tests/bot/era2_start.json) instead of the storm
##
## Era 2 play (tests/bot/bot_era2.gd): fields by what they need, the craft
## chains by their inputs, raising crews, rain on dry fields, the rockfall,
## the bear, flood evacuation and the blight. With --until-era=3 the bot plays
## through the Era 2 gate; each era FAILS if it completes under its
## gate_min_minutes, and deaths are reported by cause (old age vs anything else).
##
## Era 3 play (tests/bot/bot_era3.gd): the stone, iron, brass and book chains,
## crews of ten, the ship lifted onto the sea, Calm Waters for the voyages,
## the Guiding Light at night, rain and buckets on a fire, the sick carried to
## the clinic, people shielded in a storm. Start it from tests/bot/era3_start.json
## with --until-era=4; Era 3 FAILS under its gate_min_minutes too.

const THINK := 1.5               # game seconds between hand actions (a human pace)
const WOLF_REACT := 0.6          # chance per think to shoo a stalking wolf

var quit_after: float = 240.0
var until_era: int = 0
var shots: Array = []            # [[time, path], ...]
var _think_t: float = 0.0
var _last_day: int = -1
var _dreams: Dictionary = {}     # id -> game time done
var _dream_start: Dictionary = {}
var _regions: Dictionary = {}    # id -> game time opened
var _powers: Dictionary = {}     # id -> game time unlocked
var _beats: Dictionary = {}
var _deaths: int = 0
var _actions: int = 0
var _placed: int = 0
var _scoops: int = 0
var _scooped: int = 0
var _group_fills: int = 0
var _gestures: Dictionary = {}
var _bought: Array = []
var _gifts: int = 0
var _fps_sum: float = 0.0
var _fps_n: int = 0
var _fps_min: float = INF
var _day_fps: Array = [0.0, 0, 0.0, 0.0]   # today's fps sum, frames, process ms sum, physics ms sum
var _fps_by_era: Dictionary = {}          # era -> [fps sum, frames]
var _start_ms: int = 0
var _quitting: bool = false
var _era_done_t: float = -1.0
var _pop_log: Array = []         # [t, pop] each dawn
var _faith_at_gate: float = -1.0
var era2 = null                  # tests/bot/bot_era2.gd
var era3 = null                  # tests/bot/bot_era3.gd
var _era_start: Dictionary = {1: 0.0}   # era -> game time it began
var _era_done: Dictionary = {}   # era -> game time its gate completed
var _death_causes: Dictionary = {}
var _loaded_from: String = ""
var _threats: Array = []         # [t, id]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	_start_ms = Time.get_ticks_msec()
	var f: Dictionary = Game.flags
	if f.has("quit-after-game"):
		quit_after = float(f["quit-after-game"])
	if f.has("until-era"):
		until_era = int(f["until-era"])
		if not f.has("quit-after-game"):
			quit_after = 4800.0 if until_era <= 2 else 4800.0 + 4500.0 * (until_era - 2)
	var paths: Array = []
	if f.has("shot"):
		paths = str(f["shot"]).split(",", false)
	var times: Array = [15.0, 90.0]
	if f.has("shot-at"):
		times = Array(str(f["shot-at"]).split(",", false)).map(func(s): return float(s))
	if not paths.is_empty():
		for i in times.size():
			var p: String = paths[i] if i < paths.size() else str(paths[0]).get_basename() + "_%d.png" % i
			shots.append([times[i], p])
		quit_after = maxf(quit_after if f.has("quit-after-game") else 0.0, float(times.max()) + 2.0)
	var speed := 4.0 if DisplayServer.get_name() == "headless" else 2.0
	if f.has("speed"):
		speed = float(f["speed"])
	Engine.time_scale = speed
	era2 = load("res://tests/bot/bot_era2.gd").new(self)
	era3 = load("res://tests/bot/bot_era3.gd").new(self)
	Events.era_changed.connect(_on_era_changed)
	if f.has("load"):
		_load_save.call_deferred(str(f["load"]))
	Events.dream_started.connect(func(id): _dream_start[id] = Clock.total_t; print("BOT dream started: %s at %s" % [id, _mmss(Clock.total_t)]))
	Events.dream_done.connect(func(id): _dreams[id] = Clock.total_t; print("BOT dream done: %s at %s (pop %d, faith %.0f)" % [id, _mmss(Clock.total_t), Village.population(), Faith.total]))
	Events.region_opened.connect(func(id): _regions[id] = Clock.total_t; print("BOT region opened: %s at %s" % [id, _mmss(Clock.total_t)]))
	Events.person_died.connect(_on_died)
	Events.person_born.connect(func(p): print("BOT birth: %s at %s (pop %d)" % [p.given_name, _mmss(Clock.total_t), Village.population()]))
	Events.person_joined.connect(func(_p): pass)
	Events.day_started.connect(func(_d): _pop_log.append([Clock.total_t, Village.population()]); _report())
	Events.era_complete_shown.connect(_on_era_complete)
	Events.name_requested.connect(func(people, reason): print("BOT name requested (%s): %s" % [reason, ", ".join(people.map(func(p): return p.given_name))]))
	if Game.flags.has("verbose"):
		Events.night_started.connect(func(_d): _last_day = -1; _report())
	Events.power_unlocked.connect(func(id): _powers[id] = Clock.total_t; print("BOT power unlocked: %s at %s" % [id, _mmss(Clock.total_t)]))
	Events.threat_warned.connect(func(id, _at): _threats.append([Clock.total_t, id]); print("BOT threat warned: %s at %s" % [id, _mmss(Clock.total_t)]))
	Events.alert.connect(func(t, _at): print("BOT alert: %s" % t))
	print("BOT start: quit after %.0f game s, until era %d, speed %.1f, shots %s" % [quit_after, until_era, speed, str(shots)])

static func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

func _on_era_complete(era: int) -> void:
	var done_t := float(Village.stats.get("era_complete_t", Clock.total_t))
	_era_done[era] = done_t
	if era == 1:
		_era_done_t = done_t
		_faith_at_gate = Faith.total
	var began := float(_era_start.get(era, 0.0))
	print("BOT era %d complete at %s (%.1f game min total, %.1f min in the era)" % [era, _mmss(done_t), done_t / 60.0, (done_t - began) / 60.0])
	if until_era > 0 and Village.era >= until_era:
		quit_after = minf(quit_after, Clock.total_t + 20.0)

func _on_era_changed(e: int) -> void:
	_era_start[e] = Clock.total_t
	print("BOT era %d begins at %s" % [e, _mmss(Clock.total_t)])
	# the save is of the era the run is heading for (until-era), or the first new era
	if Game.flags.has("save-gate") and e >= 2 and (until_era <= 0 or e == until_era):
		_save_gate.call_deferred(str(Game.flags["save-gate"]))

func _abs(path: String) -> String:
	return path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)

func _save_gate(path: String) -> void:
	var f := FileAccess.open(_abs(path), FileAccess.WRITE)
	if f == null:
		print("BOT could not write %s" % path)
		return
	f.store_string(JSON.stringify(Save.snapshot(), " "))
	f.close()
	print("BOT saved the start of Era %d to %s" % [Village.era, path])

func _load_save(path: String) -> void:
	var txt := FileAccess.get_file_as_string(_abs(path))
	var d = JSON.parse_string(txt)
	if not (d is Dictionary):
		print("BOT FAIL could not read save %s" % path)
		get_tree().quit(1)
		return
	Save.apply(Save.migrate(d))
	Clock.running = true
	_loaded_from = path
	_era_start[Village.era] = float(Village.stats.get("era_started_t", Clock.total_t))
	var ec: Dictionary = Village.stats.get("era_summary", {})
	for k in ec:
		_era_done[int(k)] = float(Village.stats.get("era_complete_t", 0.0)) if int(k) == Village.era - 1 else 0.0
	print("BOT loaded %s: era %d, %s, pop %d, faith %.0f" % [path, Village.era, _mmss(Clock.total_t), Village.population(), Faith.total])

func _on_died(p) -> void:
	_deaths += 1
	var cause := "old age" if p.age >= p.death_age - 1.0 else "other"
	_death_causes[cause] = int(_death_causes.get(cause, 0)) + 1
	print("BOT death: %s (%s, age %.0f) at %s" % [p.given_name, cause, p.age, _mmss(Clock.total_t)])

func _process(_delta: float) -> void:
	if _quitting:
		return
	var fps := Engine.get_frames_per_second()
	_fps_sum += fps
	_fps_n += 1
	if _fps_n > 60 and fps > 0.0:
		_fps_min = minf(_fps_min, fps)
	_day_fps[0] += fps
	_day_fps[1] += 1
	_day_fps[2] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_day_fps[3] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if _fps_n > 60:
		var fe: Array = _fps_by_era.get(Village.era, [0.0, 0])
		fe[0] += fps
		fe[1] += 1
		_fps_by_era[Village.era] = fe
	if not Clock.running:
		return
	var t := Clock.total_t
	if not shots.is_empty() and t >= float(shots[0][0]):
		var s: Array = shots.pop_front()
		await _shot(str(s[1]))
	if t >= quit_after:
		_finish()
		return
	_think_t -= _delta
	if _think_t <= 0.0:
		_think_t = THINK
		_think()

# ---------------------------------------------------------------- play

func _hand() -> Node:
	var w = Game.world
	var h = w.get("hand") if w != null else null
	return h if h != null and is_instance_valid(h) and h.has_method("scoop_lift") else null

func _think() -> void:
	var w: Node = Game.world
	if w == null:
		return
	# 1. the storm branch
	if "storm" in w and w.storm != null and w.storm.active() and w.storm.state == StormOpening.S.STORM:
		var b: Liftable = w.branch
		if Faith.strength >= b.lift_weight() and Clock.total_t > 4.0:
			_move_object(b, b.global_position + Vector3(5.5, 0, 3.5))
		return
	# 2. powers as they become affordable (cheapest first)
	var ps: Array = Defs.powers.values()
	ps.sort_custom(func(a, b): return a.cost < b.cost)
	for p in ps:
		if Faith.can_buy(p.id) and Faith.buy(p.id):
			_bought.append(p.id)
			print("BOT bought %s for %.0f faith at %s" % [p.id, p.cost, _mmss(Clock.total_t)])
	# 3. gifts
	for g in get_tree().get_nodes_in_group("gift"):
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			_pick_gift(g)
			break
	# 4. threats: shoo stalking wolves; warm the cold
	_wolves()
	_warm()
	_bless()
	if era3.think():
		return
	if era2.think():
		return
	# 5. the meadow logs, once the hand is strong enough
	if not Village.regions.has(&"western_meadow") and "logs" in w:
		for i in w.logs.size():
			var lg: Liftable = w.logs[i]
			if Faith.strength >= lg.lift_weight() and Vector2(lg.global_position.x, lg.global_position.z).distance_to(Valley.WEST_GAP) < w.GAP_CLEAR:
				_move_object(lg, Vector3(Valley.WEST_GAP.x + 9.0, 0, Valley.WEST_GAP.y - 9.0 + i * 3.0))
				return
	# 6. staff work
	_staff()

func _move_object(o: Node3D, to: Vector3) -> void:
	var at := Vector3(to.x, Game.world.ground_y(to.x, to.z), to.z)
	var h := _hand()
	if h != null and h.try_lift_object(o):
		h.place_object(at)
	else:
		o.on_lifted()
		Events.hand_lifted_object.emit(o)
		o.on_placed(at)
		Events.hand_placed_object.emit(o, at)
	_actions += 1
	print("BOT moved %s to (%.0f, %.0f) at %s" % [o.name, at.x, at.z, _mmss(Clock.total_t)])

func _pick_gift(g: Node) -> void:
	var h := _hand()
	if h != null and h.has_method("collect_gift"):
		if h.collect_gift(g):
			_gifts += 1
			print("BOT picked up a gift at %s" % _mmss(Clock.total_t))

func _gesture(id: StringName, at: Vector3, pulses: int = 3) -> void:
	for i in pulses:
		Events.hand_gesture.emit(id, at)
	_gestures[id] = int(_gestures.get(id, 0)) + 1

func _wolves() -> void:
	for wolf in get_tree().get_nodes_in_group("wolves"):
		if not is_instance_valid(wolf) or wolf.get("state") != Wolf.S.STALK:
			continue
		var tgt = wolf.get("target")
		if tgt != null and is_instance_valid(tgt) and tgt.global_position.distance_to(wolf.global_position) < 10.0 and Game.rng.randf() < WOLF_REACT:
			var n: int = Game.world.scare_threats(wolf.global_position, 7.0)
			if n > 0:
				_gestures[&"flick"] = int(_gestures.get(&"flick", 0)) + 1

var _warm_cd: float = 0.0
func _warm() -> void:
	_warm_cd -= THINK
	if not Faith.has(&"warmth") or _warm_cd > 0.0:
		return
	var coldest: Person = null
	for p in Village.alive():
		if p.visible and p.needs[&"warmth"] < 0.35 and (coldest == null or p.needs[&"warmth"] < coldest.needs[&"warmth"]):
			coldest = p
	if coldest != null:
		_warm_cd = 3.0
		_gesture(&"warmth", coldest.global_position)

func _bless() -> void:
	if not Faith.has(&"blessing"):
		return
	for s in Village.sites:
		if not is_instance_valid(s) or s.job == null or not s.job.needs_blessed:
			continue
		var present := 0
		var unblessed := 0
		for p in s.workers:
			if is_instance_valid(p) and p.is_present_at(s, 1.6):
				present += 1
				if not p.is_blessed():
					unblessed += 1
		if present >= s.job.min_people and unblessed > 0:
			_gesture(&"blessing", s.global_position)

## Adults the hand could move now: not asleep, eating or fleeing, and not
## already in a group job or raising a building.
func _movable() -> Array:
	var out: Array = []
	for p in Village.alive():
		if not is_instance_valid(p) or not p.pickable():
			continue
		if p.stage != Person.Stage.ADULT and p.stage != Person.Stage.ELDER:
			continue
		if p.state in [Person.S.SHELTER, Person.S.SLEEP, Person.S.EAT, Person.S.FLEE, Person.S.FALL, Person.S.HELD]:
			continue
		if p._offering != null and p.state == Person.S.WALK:
			continue                      # on the way to the shrine with a gift: let them go
		var js = p.job_site
		if js != null and is_instance_valid(js) and (js.is_group() or (js.is_plot() and js.state == Site.State.BUILDING)):
			continue
		out.append(p)
	return out

## Movable people with nothing useful to do (no job, or a wasted one).
func _idle_people() -> Array:
	return _movable().filter(func(p): return p.job_site == null or not is_instance_valid(p.job_site) or p.state == Person.S.IDLE or _wasted(p.job_site, p))

## How much the bot values the work a person is doing now (low = easy to pull off).
func _job_value(p: Person) -> float:
	var js = p.job_site
	if js == null or not is_instance_valid(js):
		return 0.0
	if _wasted(js, p):
		return 0.1
	# gathering what an open plot is waiting for is as good as building it
	var j: JobDef = js.job
	if j != null and not js.is_plot() and j.kind == JobDef.Kind.GATHER:
		for k in j.outputs:
			if (k == &"stone" or k == &"wood") and Village.store(k) < _need(k):
				return _score(js, 0) + 1.0
	return _score(js, 0) * 0.8

## How much of `k` the open plots still need, plus a working buffer.
func _need(k: StringName) -> int:
	var n := 0
	for s in Village.sites:
		if is_instance_valid(s) and s.state == Site.State.PLOT and s.building != null:
			n += maxi(s.remaining(k), 0)
	return n

func _food_target() -> int:
	var pop := maxi(Village.population(), 1)
	var k := 7 if Clock.season == Clock.Season.AUTUMN else 5
	# a town eats from full stores: past one full store of food, build instead
	return mini(pop * k, int(Village.store_cap * (1.0 if Village.era >= 3 else 1.5)))

## A person on this job would do more good elsewhere.
func _wasted(s, p = null) -> bool:
	var j: JobDef = s.get("job")
	var e3: int = era3.wasted(s, p)
	if e3 >= 0:
		return e3 == 1
	var e2: int = era2.wasted(s, p)
	if e2 >= 0:
		return e2 == 1
	if s.is_plot():
		return s.state == Site.State.PLOT and not _plot_can_progress(s)
	if j == null:
		return false
	if j.kind == JobDef.Kind.GROUP:
		return false
	if j.kind == JobDef.Kind.DEVOTION:
		return p != null and s.workers.find(p) >= _prayers_wanted()
	if j.kind == JobDef.Kind.TEND:
		return not s.fire_wants_fuel() and Village.store(&"wood") < 2
	if not s.can_work_now() and s.get("regrow_t") != null:
		return true
	for k in j.outputs:
		match k:
			&"wood", &"stone":
				return Village.store(k) >= mini(_need(k) + 8, Village.store_cap - 1)
			&"water":
				return Village.store(k) >= mini(Village.population() * 4, Village.store_cap - 1)
			_:
				return Village.food() >= _food_target() + 10 or Village.store(k) >= Village.store_cap - 1
	return false

## A plot still waiting for materials has something it needs in the store.
func _plot_can_progress(s) -> bool:
	if s.state != Site.State.PLOT:
		return true
	# enough in the store to make a real dent (not one stick at a time)
	var have := 0
	var left := 0
	for k in s.building.cost:
		var r: int = maxi(s.remaining(k), 0)
		left += r
		have += mini(r, Village.store(k))
	if left == 0:
		return true           # everything is on its way: the builders are busy
	return have > 0 and have >= mini(left, 3)

func _prayers_wanted() -> int:
	return 1 if Village.population() < 10 else 2

func _site_ok(s) -> bool:
	if not is_instance_valid(s) or s.is_queued_for_deletion():
		return false
	if not s.can_accept(1):
		return false
	var w = Game.world
	var at: Vector3 = s.slot_position(0) if s.building != null and s.building.id == &"bridge" else s.global_position
	if w.has_method("is_region_open") and not w.is_region_open(w.region_at(at)):
		return false
	if s.job != null and not s.is_plot() and not s.is_group() and s.job.kind == JobDef.Kind.GATHER and not s.can_work_now():
		return false
	if era2.site_blocked(s) or era3.site_blocked(s):
		return false
	return true

func _score(s, idle_n: int) -> float:
	var j: JobDef = s.job
	var pop := maxi(Village.population(), 1)
	if s.is_plot():
		var b: BuildingDef = s.building
		var ready: bool = _plot_can_progress(s)
		var dream := false
		var d := Dreams.active_dream()
		if d != null and d.needs_buildings.has(b.id):
			dream = true
		var key: float = era3.plot_score(b)
		if key > 0.0 and ready:
			return key            # the workshop a waiting chain needs (the forge for iron, ...)
		var home := (b.id == &"hut" or b.id == &"cottage") and b.shelter > 0
		# in Era 2 the village feeds itself from the fields: building outranks foraging
		var other := 5.5
		if Village.era >= 2:
			other = 7.0 if b.id == &"field" else 6.2     # a field is next season's bread
		return (8.0 if dream else (7.2 if home else other)) if ready else 0.5
	if j == null:
		return 0.0
	var e3: float = era3.score(s, idle_n)
	if e3 >= 0.0:
		return e3
	var e2: float = era2.score(s, idle_n)
	if e2 >= 0.0:
		return e2
	var food_low := Village.food() < _food_target()
	var sc := 1.0
	match j.id:
		&"gather_berries", &"rich_berries", &"fish_by_hand":
			sc = 6.0 if food_low else 1.2
			if Village.food() < pop or (Clock.season == Clock.Season.WINTER and Village.food() < pop * 2):
				sc = 8.6          # nearly out of food: before any building
		&"tend_fire":
			var cold := Clock.is_night or Clock.phase_t > Clock.day_seconds * 0.6 or Clock.season == Clock.Season.WINTER
			sc = (6.5 if cold else 2.0) if s.fire_wants_fuel() and Village.store(&"wood") > 0 else 0.3
		&"collect_sticks", &"fell_tree":
			sc = 4.5 if Village.store(&"wood") < _need(&"wood") + 6 else 0.6
			if Village.store(&"wood") < _need(&"wood"):
				sc = 6.5          # a plot is waiting on wood
			if j.id == &"fell_tree":
				sc += 0.3
		&"knap_flint":
			sc = 4.8 if Village.store(&"stone") < _need(&"stone") + 4 else 0.4
			if Village.store(&"stone") < _need(&"stone"):
				sc = 6.4          # a plot is waiting on stone
			if not Flags.has(&"stone_tools"):
				sc = maxf(sc, 4.0)
		&"fetch_water":
			sc = 8.6 if Village.store(&"water") < pop else (3.0 if Village.store(&"water") < pop * 3 else 0.5)
		&"pray":
			sc = 3.0 if s.workers.size() < _prayers_wanted() else 0.0
	if j.kind == JobDef.Kind.GROUP:
		var waiting := 0
		for p in s.workers:
			if is_instance_valid(p):
				waiting += 1
		var need := maxi(j.min_people - waiting, 0)
		if need > idle_n:
			return 0.0                    # can't fill it now: don't strand people waiting
		match j.id:
			&"haul_log", &"carry_log": sc = 9.5
			&"festival", &"great_elk_hunt": sc = 9.0
			&"hunt":
				# four hunters out of five leave nobody for the village
				if pop < 6:
					return 0.0
				sc = 7.5 if Village.food() < pop * 3 else (4.0 if food_low or Village.store(&"hide") < 3 else 2.5)
			_: sc = 7.0
		if waiting > 0:
			sc += 1.0                     # finish filling a group already waiting
	return sc

func _staff() -> void:
	var movable := _movable()
	var idle := movable.filter(func(p): return p.job_site == null or not is_instance_valid(p.job_site) or _wasted(p.job_site, p))
	var best: Site = null
	var best_sc := 0.0
	for s in Village.sites:
		if not _site_ok(s):
			continue
		# a group job can pull people off lesser work, so count everyone movable
		var sc := _score(s, movable.size() if s.is_group() else idle.size())
		if not s.is_group() and idle.is_empty() and sc < 6.0:
			continue
		if sc > best_sc:
			best_sc = sc
			best = s
	if best == null:
		return
	var truly_idle := idle.filter(func(p): return p.job_site == null or not is_instance_valid(p.job_site))
	# people "wasted" on a job only move for something clearly better
	if truly_idle.is_empty() and best_sc < 3.0:
		return
	var pool: Array = truly_idle if not truly_idle.is_empty() else idle
	if pool.is_empty() and not best.is_group():
		# pull someone off clearly less valuable work (a dream plot over a sticks run)
		pool = movable.filter(func(p): return p.job_site != best and _job_value(p) < best_sc - 2.0)
		pool.sort_custom(func(a, b): return _job_value(a) < _job_value(b))
	if best.is_group():
		# the idle first, then whoever is doing the least valuable work
		var rest := movable.filter(func(p): return not idle.has(p) and p.job_site != best and _job_value(p) < best_sc)
		rest.sort_custom(func(a, b): return _job_value(a) < _job_value(b))
		pool = idle + rest
		if best.job.min_people - best.workers.size() > pool.size():
			return
	if pool.is_empty():
		return
	var want := 1
	if best.is_group():
		want = maxi(best.job.min_people - best.workers.size(), 1)
	elif best.is_plot():
		want = mini(2, best.free_slots())
	want = mini(want, best.free_slots())
	want = mini(want, pool.size())
	if want <= 0:
		return
	var h := _hand()
	if h == null:
		_place_direct(pool.slice(0, mini(want, Faith.grip)), best)
		return
	var got := 0
	if Faith.grip > 1 and want > 1 and h.can_scoop():
		got = _scoop_for(h, pool, want)
	while h.held.size() < mini(want, h.grip()):
		var next: Person = null
		for p in pool:
			if not h.held.has(p) and h.can_lift(p):
				next = p
				break
		if next == null or not h.try_lift(next):
			break
	if h.held.is_empty():
		return
	if Game.flags.has("verbose"):
		print("BOT   place %s -> %s (%.1f) at %s" % [", ".join(h.held.map(func(p): return p.given_name)), _site_name(best), best_sc, _mmss(Clock.total_t)])
	var n: int = h.place_on_site(best)
	_placed += n
	if best.is_group() and n > 1:
		_group_fills += 1
	if not h.held.is_empty():
		h.place_on_ground(Site.store_point(best.global_position) + Vector3(2, 0, 2))
	_actions += 1

## Scoop a cluster of idle people: the circle that holds the most of `pool`
## and the fewest busy people. Returns how many were lifted.
func _scoop_for(h: Node, pool: Array, want: int) -> int:
	var r: float = h.scoop_max_radius()
	var best_c := Vector3.INF
	var best_v := -INF
	for c in pool:
		var cp: Vector3 = c.global_position
		var v := 0.0
		for p in Village.alive():
			if not p.pickable():
				continue
			var d: Vector3 = p.global_position - cp
			d.y = 0.0
			if d.length() > r:
				continue
			v += 1.0 if pool.has(p) else -2.0
		if v > best_v:
			best_v = v
			best_c = cp
	if best_v < 2.0:
		return 0
	# a scoop lifts the nearest people inside the circle, up to the free grip
	var radius := r
	while radius > 1.0:
		var inside: Array = h.people_in_circle(best_c, radius)
		var busy := inside.filter(func(p): return not pool.has(p)).size()
		if busy == 0 or inside.size() <= want:
			break
		radius -= 0.75
	var was: Dictionary = {}
	for p in h.people_in_circle(best_c, radius):
		was[p] = p.job_site
	var n: int = h.scoop_lift(best_c, radius)
	if n > 0:
		_scoops += 1
		_scooped += n
	# anyone scooped who was busy goes straight back to their work
	for p in h.held.duplicate():
		if not pool.has(p):
			h.held.erase(p)
			var back = was.get(p)
			p.on_placed(p.global_position, back if back != null and is_instance_valid(back) else null)
	return n

func _site_name(s) -> String:
	if s.job != null:
		return str(s.job.id)
	return "plot " + str(s.building.id) if s.building != null else "?"

func _place_direct(batch: Array, best: Site) -> void:
	for p in batch:
		p.on_lifted()
	Events.hand_lifted.emit(batch)
	for i in batch.size():
		var p = batch[i]
		if is_instance_valid(p):
			p.on_placed(best.slot_position(best.workers.size() + i), best)
			_placed += 1
	Events.hand_placed.emit(batch, best)
	_actions += 1

# ---------------------------------------------------------------- report

func _stores_text() -> String:
	var parts: Array = []
	for k in Village.stores:
		parts.append("%s=%d" % [k, Village.stores[k]])
	return ", ".join(parts) if not parts.is_empty() else "none"

func _report() -> void:
	if Clock.day == _last_day:
		return
	_last_day = Clock.day
	var fps := _fps_sum / maxf(_fps_n, 1)
	var dn: float = maxf(float(_day_fps[1]), 1.0)
	print("BOT day %d %s %s y%d | pop %d | stores %s | faith %.0f (avail %.0f) | dream %s | deaths %d | fps %.0f (today %.0f, process %.1f ms, physics %.1f ms) | actions %d" % [
		Clock.day, _mmss(Clock.total_t), ["spring", "summer", "autumn", "winter"][Clock.season], Clock.year, Village.population(), _stores_text(),
		Faith.total, Faith.available(), str(Village.stats.get("dream_active", "")), _deaths, fps, _day_fps[0] / dn, _day_fps[2] / dn, _day_fps[3] / dn, _actions])
	_day_fps = [0.0, 0, 0.0, 0.0]
	var nv = Game.world.nav if Game.world != null else null
	if nv != null and nv.navigation_mesh != null:
		print("BOT   nav: %d bakes, last %d ms, %d polygons" % [nv.bake_count, nv.last_bake_ms, nv.navigation_mesh.get_polygon_count()])
	if Village.era >= 2:
		var plots: Array = []
		for s in Village.sites:
			if is_instance_valid(s) and s.building != null and s.state != Site.State.FINISHED:
				plots.append("%s:%s%s w%d" % [s.building.id, "raise" if s.awaiting_raise() else Site.State.keys()[s.state].to_lower(), "" if s.awaiting_raise() else " %d%%" % int(100.0 * (s._materials_fraction() if s.state == Site.State.PLOT else s.build_progress())), s.workers.size()])
		var built: Array = []
		for id in [&"cottage", &"townhouse", &"field", &"granary", &"mill", &"bakery", &"kiln", &"smelter", &"smithy", &"weaver", &"market", &"barn", &"bridge", &"temple", &"camp",
				&"mason", &"forge", &"school", &"printing_house", &"watermill", &"windmill", &"fire_station", &"clinic", &"market_hall", &"great_hall", &"harbour", &"lighthouse", &"clocktower", &"laboratory", &"aqueduct", &"observatory"]:
			var n := Village.count_buildings(id)
			if n > 0:
				built.append("%s %d" % [id, n])
		print("BOT   built: %s | plots: %s" % [", ".join(built), ", ".join(plots)])
		# --save-day=DAY:path saves a mid-run snapshot (for profiling or a quick look)
		var sd := str(Game.flags.get("save-day", ""))
		if sd.contains(":") and Clock.day == int(sd.get_slice(":", 0)):
			_save_gate(sd.substr(sd.find(":") + 1))
		var jobs := {}
		for p in Village.alive():
			var js = p.job_site
			var k: String = "-"
			if js != null and is_instance_valid(js):
				k = str(js.job.id) if js.job != null else "build:" + str(js.building.id if js.building else "")
			jobs[k] = int(jobs.get(k, 0)) + 1
		var jl: Array = []
		for k in jobs:
			jl.append("%s %d" % [k, jobs[k]])
		print("BOT   jobs: %s" % ", ".join(jl))
	if Game.flags.has("verbose"):
		for p in Village.alive():
			var js = p.job_site
			print("BOT   %s: %s at %s -> %s job %s | %s" % [p.given_name, Person.STATE_NAMES[p.state], str(p.global_position.snapped(Vector3.ONE * 0.1)), str(p._target), 
				js.job.id if js != null and is_instance_valid(js) and js.job else ("plot" if js != null and is_instance_valid(js) else "-"), p.status_text()])
		var pairs := 0
		var homed := 0
		var moods: Array = []
		var blocked := {}
		for p in Village.alive():
			if p.home != null and is_instance_valid(p.home):
				homed += 1
			moods.append(snappedf(p.mood(), 0.01))
			if p.partner != 0 and p.sex == "f":
				pairs += 1
				var b = Births.find(p.partner)
				if b != null:
					var why := "ok" if Births.can_have_child(p, b) else "no"
					blocked[p.given_name] = why
		print("BOT   births: pairs %d %s | homed %d | surplus_days %d | moods %s | food %d" % [pairs, str(blocked), homed, int(Village.stats.get("surplus_days", 0)), str(moods), Village.food()])
		for s in Village.sites:
			if is_instance_valid(s) and s.building != null and s.state != Site.State.FINISHED:
				print("BOT   plot %s %s at %s | workers %d | ok %s score %.1f | delivered %s incoming %s progress %.2f" % [s.building.id, Site.State.keys()[s.state], str(s.global_position.snapped(Vector3.ONE)), s.workers.size(), str(_site_ok(s)), _score(s, 1), str(s.delivered), str(s.incoming), s.progress])
				_why(s)
			elif Village.era >= 2 and is_instance_valid(s) and s.job != null and s.job.era >= 2 and s.job.id != &"farm_field":
				print("BOT   site %s at %s | workers %d | ok %s score %.1f" % [s.job.id, str(s.global_position.snapped(Vector3.ONE)), s.workers.size(), str(_site_ok(s)), _score(s, 1)])
				_why(s)

## Verbose: why _site_ok refuses a site.
func _why(s) -> void:
	if _site_ok(s):
		return
	var w = Game.world
	var at: Vector3 = s.slot_position(0) if s.building != null and s.building.id == &"bridge" else s.global_position
	print("BOT     why: accept %s (slots %d/%d) region %s open %s work_now %s blocked %s" % [str(s.can_accept(1)), s.slots_filled(), s.max_slots(), str(w.region_at(at)), str(w.is_region_open(w.region_at(at))), str(s.can_work_now()), str(era2.site_blocked(s))])

func _shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("BOT shot skipped (headless): %s" % path)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var abs_path := path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	print("BOT shot %s at %.0fs (%s)" % [abs_path, Clock.total_t, "ok" if err == OK else "error %d" % err])

func _timeline() -> void:
	print("BOT ---- timeline (game time) ----")
	var bt: Dictionary = Village.stats.get("beat_times", {})
	for k in Onboarding.NAMES:
		if bt.has(k):
			print("BOT   %s  onboarding: %s" % [_mmss(float(bt[k])), k])
	var rows: Array = []
	for id in _dream_start:
		rows.append([_dream_start[id], "dream appears: %s" % id])
	for id in _dreams:
		rows.append([_dreams[id], "dream done: %s" % id])
	for id in _powers:
		rows.append([_powers[id], "power: %s" % id])
	for id in _regions:
		rows.append([_regions[id], "region: %s" % id])
	for e in _era_start:
		if e > 1:
			rows.append([_era_start[e], "ERA %d BEGINS" % e])
	for e in _era_done:
		rows.append([_era_done[e], "ERA %d COMPLETE (%.1f min in the era)" % [e, (_era_done[e] - float(_era_start.get(e, 0.0))) / 60.0]])
	for th in _threats:
		rows.append([th[0], "threat: %s" % th[1]])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for r in rows:
		print("BOT   %s  %s" % [_mmss(r[0]), r[1]])
	var pops: Array = []
	for i in range(0, _pop_log.size(), 3):
		pops.append("%s:%d" % [_mmss(_pop_log[i][0]), _pop_log[i][1]])
	print("BOT   population by dawn: %s" % ", ".join(pops))

func _finish() -> void:
	_quitting = true
	_report()
	_timeline()
	var real_s := (Time.get_ticks_msec() - _start_ms) / 1000.0
	var summary: Dictionary = (Village.stats.get("era_summary", {}) as Dictionary).get("1", {})
	print("BOT summary: game %s in %.0fs real | day %d | pop %d (births %d, joined %d) | deaths %d | faith %.0f (at gate %.0f) | powers %s | placed %d | scoops %d (%d people) | group fills %d | gestures %s | gifts %d | fps avg %.0f min %.0f" % [
		_mmss(Clock.total_t), real_s, Clock.day, Village.population(), int(Village.stats.get("births", 0)), int(Village.stats.get("joined", 0)),
		_deaths, Faith.total, _faith_at_gate, str(_bought), _placed, _scoops, _scooped, _group_fills, str(_gestures), _gifts,
		_fps_sum / maxf(_fps_n, 1), _fps_min if _fps_min < INF else 0.0])
	if not summary.is_empty():
		print("BOT era 1 card: %s" % str(summary))
	var s2: Dictionary = (Village.stats.get("era_summary", {}) as Dictionary).get("2", {})
	if not s2.is_empty():
		print("BOT era 2 card: %s" % str(s2))
	print("BOT deaths by cause: %s | era 2 play: %s | era 3 play: %s" % [str(_death_causes), era2.summary(), era3.summary()])
	var s3: Dictionary = (Village.stats.get("era_summary", {}) as Dictionary).get("3", {})
	if not s3.is_empty():
		print("BOT era 3 card: %s" % str(s3))
	print("BOT era 3 stats: fires %d (out %d, burned out %d, douses %d) | sick %d well %d | storm hurt %d | damaged %d | foreman joins %d | school joins %d | buildings moved %d | calm pulses %d | guide pulses %d | flags %s" % [
		int(Village.stats.get("threat_town_fire", 0)), int(Village.stats.get("fires_out", 0)), int(Village.stats.get("burned_out", 0)), int(Village.stats.get("fire_douses", 0)),
		int(Village.stats.get("fell_sick", 0)), int(Village.stats.get("got_well", 0)), int(Village.stats.get("storm_hurt", 0)), int(Village.stats.get("buildings_damaged", 0)),
		int(Village.stats.get("foreman_joins", 0)), int(Village.stats.get("school_joins", 0)), int(Village.stats.get("buildings_moved", 0)),
		int(Village.stats.get("calm_pulses", 0)), int(Village.stats.get("guide_pulses", 0)), str(Village.stats.get("flags", []))])
	var fe: Array = []
	for e in _fps_by_era:
		fe.append("era %d %.0f" % [e, _fps_by_era[e][0] / maxf(float(_fps_by_era[e][1]), 1.0)])
	print("BOT fps by era: %s" % ", ".join(fe))
	print("BOT era 2 stats: harvests %d grain %d crops lost %d | offerings %d | bear swipes %d raided %d | flood hurt %d | blights cured %d | trust avg %.2f (%s) | flags %s" % [
		int(Village.stats.get("harvests", 0)), int(Village.stats.get("grain_harvested", 0)), int(Village.stats.get("crops_lost", 0)),
		int(Village.stats.get("offerings", 0)), int(Village.stats.get("bear_swipes", 0)), int(Village.stats.get("bear_raided", 0)),
		int(Village.stats.get("flood_hurt", 0)), int(Village.stats.get("blights_cured", 0)), Trust.average(), Trust.stage_name(), str(Village.stats.get("flags", []))])
	print("BOT audio: set %s | layers on %s | stingers %s | voices %d" % [Audio._set, str(Audio.layer_seen.keys()), str(Audio.stinger_log), Audio.voice_count])
	var ok := Game.world != null and Village.population() >= 0
	var why := ""
	# Pacing regression: Era 1 must never finish under its floor (35 game minutes).
	var e1 := Defs.era(1)
	var floor_min: float = e1.gate_min_minutes if e1 else 35.0
	if _era_done_t >= 0.0 and _era_done_t / 60.0 < floor_min and _loaded_from == "":
		ok = false
		why = "pacing regression: Era 1 finished in %.1f min (< %.0f)" % [_era_done_t / 60.0, floor_min]
	var gate_era := maxi(until_era - 1, 1)
	if Game.flags.has("expect-gate") and not _era_done.has(gate_era):
		ok = false
		why = "Era %d not complete after %s" % [gate_era, _mmss(Clock.total_t)]
	if _era_done.has(2):
		var e2d := Defs.era(2)
		var m2: float = (float(_era_done[2]) - float(_era_start.get(2, 0.0))) / 60.0
		if m2 < (e2d.gate_min_minutes if e2d else 45.0):
			ok = false
			why = "pacing regression: Era 2 finished in %.1f min (< %.0f)" % [m2, e2d.gate_min_minutes if e2d else 45.0]
	if _era_done.has(3) and float(_era_done[3]) > 0.0:
		var e3d := Defs.era(3)
		var m3: float = (float(_era_done[3]) - float(_era_start.get(3, 0.0))) / 60.0
		if m3 < (e3d.gate_min_minutes if e3d else 55.0):
			ok = false
			why = "pacing regression: Era 3 finished in %.1f min (< %.0f)" % [m3, e3d.gate_min_minutes if e3d else 55.0]
	if int(_death_causes.get("other", 0)) > 0:
		ok = false
		why = "%d deaths not of old age" % int(_death_causes["other"])
	if _era_done_t >= 0.0 and Village.era < 2:
		ok = false
		why = "the gate is done but Village.era is still %d" % Village.era
	print("BOT %s%s" % ["PASS" if ok else "FAIL", (" (" + why + ")") if why != "" else ""])
	Engine.time_scale = 1.0
	get_tree().quit(0 if ok else 1)
