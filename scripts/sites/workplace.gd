class_name Workplace extends RefCounted
## Workplaces (doc 4; Austin's ruling of 2026-10-10: "workplaces are the core
## model"). A workplace is a finished building the hand staffs by dropping
## people on it; its crew then handles every task in its radius on its own:
##
##   farmhouse (Era 2)       clears new field plots, sows, waters the dry ones,
##                           fights the blight in twos and brings the harvest in
##                           to its bin; the crew eats and sleeps there. Its
##                           carter (a slot beside it) hauls the bin to the
##                           granary or the nearest store.
##   hunting lodge (Era 1)   the hunters go out to the deer herds in a party of
##                           two or more and carry the meat and hides home.
##   woodcutters' camp (Era 1)  fells the trees around it.
##   [era3] Era 3 workplaces add a bench, fetching and paving:
##   mason's yard (Era 3)    quarries the ledges up the quarry face, dresses
##                           spare stone at its own bench, and two of its masons
##                           pave the busiest roads in the town (Paving).
##   forge (Era 3)           mines the iron seams up the slope into its bin and
##                           forges the ore into iron at its own bench.
##   watermill, windmill     the millers fetch grain straight from the bins of
##                           the farmhouses round them and grind it into flour.
##   A bench (BuildingDef.bench_job) takes its inputs from the bin first, then
##   the stores, and puts what it makes in the bin for the carter.
##
## Task sites (fields, herds) are never spots the hand drops people on
## (Site.hand_blocked); a tree near a woodcutters' camp is the camp's.
## The crew a workplace takes grows with the hand's grip (crew_cap), so grip
## still matters for staffing: one placement fills a farmhouse at Grip III.
## The Person side is step() and haul_step(); Site keeps `bin` and `claims`.

const HUNT_PARTY := 2          # hunters at a herd before the hunt can start
const CART_LOAD := 8           # a carter's load (twice that with carts, Era 3)
const FIELD_CREW := 2          # farmers on one field at once (the blight takes two)
const FIRST_FIELDS := 2        # field plots staked when a farmhouse is finished
const FIELD_RING := 13.0       # where fields go round a farmhouse with no authored spots near it
const FETCH_MIN := 4           # [era3] a farmhouse bin worth a miller's walk
const BENCH_STOCK := 60        # [era3] a bench stops when the stores hold this much of what it makes
const STONE_RESERVE := 10      # [era3] stone the mason's bench leaves in the stores beyond what the plots want

# ---------------------------------------------------------------- what is a task

static var _task_ids: Dictionary = {}

## True when some workplace kind works this job (fell_tree, hunt, farm_field).
static func task_job(id: StringName) -> bool:
	if _task_ids.is_empty():
		for b in Defs.buildings.values():
			if b.workplace:
				for j in b.work_jobs:
					_task_ids[j] = true
		_task_ids[&"_"] = true
	return _task_ids.has(id)

## Crew the workplace takes now: the hand's grip, between crew_min and crew_max.
static func crew_cap(w: Site) -> int:
	return clampi(Faith.grip, w.building.crew_min, w.building.crew_max)

## Is task site `t` one of workplace `w`'s (its kind, inside its radius)?
static func covers(w: Site, t: Site) -> bool:
	if w == t or not is_instance_valid(t) or t.is_queued_for_deletion() or not w.is_workplace():
		return false
	var b: BuildingDef = w.building
	if b.paves and t.job != null and t.job.id == Paving.JOB:
		return true                # [era3] the masons pave roads anywhere in the town
	var d := Vector2(t.global_position.x - w.global_position.x, t.global_position.z - w.global_position.z).length()
	if d > b.work_radius:
		return false
	if not b.fetch_from.is_empty() and t.is_workplace():
		return b.fetch_from.has(t.building.id)    # [era3] a mill empties the farmhouse bins near it
	if t.building != null and t.building.id == &"field":
		return b.work_jobs.has(&"farm_field") and (t.state == Site.State.BUILDING or t.is_field())
	return t.job != null and not t.is_plot() and b.work_jobs.has(t.job.id)

## The workplace whose radius takes in task site `t`, or null.
static func covering(t: Site) -> Site:
	for w in Village.sites:
		if is_instance_valid(w) and w.is_workplace() and covers(w, t):
			return w
	return null

## Every task site of workplace `w`.
static func tasks(w: Site) -> Array:
	var out: Array = []
	if not w.is_workplace():
		return out
	for t in Village.sites:
		if is_instance_valid(t) and covers(w, t):
			out.append(t)
	return out

## How much task `t` wants work now (0 = nothing to do there).
static func need(t: Site) -> float:
	if t.is_workplace():
		return 3.0 + float(bin_total(t)) * 0.05 if bin_total(t) >= FETCH_MIN else 0.0    # [era3] a full bin to fetch
	if t.job != null and t.job.id == Paving.JOB:
		return Paving.need(t)      # [era3]
	if t.is_plot():
		return 3.0 if t.state == Site.State.BUILDING else 0.0      # a new field to clear
	if t.is_field():
		match t.field_want():
			&"cure": return 6.0
			&"harvest": return 5.0
			&"sow": return 4.0
			&"water": return 2.0 if Village.store(&"water") > 1 else 0.0
		return 0.0
	if t.job != null and t.job.id == &"hunt" and not Site.has_drying_rack():
		return 0.0     # [polish] no hunting before the drying rack
	return 3.0 if t.can_work_now() and t.discovered() else 0.0

static func task_cap(t: Site) -> int:
	if t.is_workplace():
		return 1                   # [era3] one miller at a time fetches from a bin
	if t.building != null and t.building.id == &"field":
		return FIELD_CREW
	if t.job != null and t.job.id == &"hunt":
		return 6
	return maxi(t.job.max_people if t.job != null else 1, 1)

# ---------------------------------------------------------------- claims

static func _claimed(w: Site, t: Site) -> Array:
	var a: Array = w.claims.get(t.uid, [])
	a = a.filter(func(p): return is_instance_valid(p) and p.alive() and p.job_site == w and p.task_site == t)
	if a.is_empty():
		w.claims.erase(t.uid)
	else:
		w.claims[t.uid] = a
	return a

static func claim(w: Site, t: Site, p) -> void:
	var a := _claimed(w, t)
	if not a.has(p):
		a.append(p)
	w.claims[t.uid] = a

## Lets go of whatever task `p` held at workplace `w` (or anywhere, when `w`
## is a task site being left).
static func unclaim(w: Site, p) -> void:
	if w == null or not is_instance_valid(w) or w.claims.is_empty():
		return
	for k in w.claims.keys():
		var a: Array = w.claims[k]
		a.erase(p)
		if a.is_empty():
			w.claims.erase(k)

## The best task for `p` now: the most urgent, nearest, with room.
static func pick_task(w: Site, p) -> Site:
	var best: Site = null
	var best_v := 0.0
	for t in tasks(w):
		var n := need(t)
		if n <= 0.0:
			continue
		var c := _claimed(w, t)
		if c.size() >= task_cap(t) and not c.has(p):
			continue
		var v: float = n - t.global_position.distance_to(p.global_position) * 0.02
		if t.job != null and t.job.id == &"hunt" and c.size() > 0:
			v += 2.0               # hunters go out together
		elif t.is_blighted() and c.size() == 1:
			v += 2.0               # the blight takes two
		if v > best_v or best == null:
			best_v = v
			best = t
	# [era3] the workplace's own bench, when it has the inputs
	var bn := bench_need(w)
	if bn > 0.0 and (_claimed(w, w).size() < bench_cap(w) or _claimed(w, w).has(p)):
		var bv: float = bn - w.global_position.distance_to(p.global_position) * 0.02
		if best == null or bv > best_v:
			best = w
	return best

## Crew of `w` at task `t` and working there now.
static func crew_at(w: Site, t: Site) -> int:
	var n := 0
	for p in _claimed(w, t):
		if p.state == Person.S.WORK and p._phase == "work":
			n += 1
	return n

## Why the crew is sitting at the workplace (for "idle reasons").
static func idle_reason(w: Site) -> StringName:
	if w.building.bench_job != &"":
		return bench_missing(w)    # [era3]
	var ts := tasks(w)
	if w.building.work_jobs.has(&"farm_field"):
		if ts.is_empty():
			return &"no fields"
		return &"growing" if Site.sowing_season() else &"spring"
	if ts.is_empty():
		return &"nothing near"
	if w.building.work_jobs.has(&"hunt") and not Site.has_drying_rack():
		return &"a drying rack"     # [polish]
	return &"regrowth"

# ---------------------------------------------------------------- the bin

static func bin_total(w: Site) -> int:
	var n := 0
	for k in w.bin:
		n += int(w.bin[k])
	return n

static func bin_room(w: Site) -> int:
	if w.building == null or w.building.bin_cap <= 0:
		return 0
	return maxi(w.building.bin_cap - bin_total(w), 0)

## Puts what fits into the bin; returns how many went in.
static func bin_add(w: Site, k: StringName, n: int, ignore_cap: bool = false) -> int:
	var put := n if ignore_cap else mini(n, bin_room(w))
	if put <= 0:
		return 0
	w.bin[k] = int(w.bin.get(k, 0)) + put
	bin_visual(w)
	return put

## Takes up to `n` goods out of the bin.
static func bin_take(w: Site, n: int) -> Dictionary:
	var out := {}
	for k in w.bin.keys():
		if n <= 0:
			break
		var t := mini(int(w.bin[k]), n)
		if t <= 0:
			continue
		out[k] = t
		n -= t
		w.bin[k] = int(w.bin[k]) - t
		if int(w.bin[k]) <= 0:
			w.bin.erase(k)
	bin_visual(w)
	return out

static func bin_visual(w: Site) -> void:
	if w.visual != null and is_instance_valid(w.visual) and w.visual.has_method("set_fill") and w.building != null and w.building.bin_cap > 0:
		w.visual.call("set_fill", float(bin_total(w)) / float(w.building.bin_cap))

## Where carters take the goods: the granary (or barn) nearest, else any store.
static func granary_point(from: Vector3) -> Vector3:
	var g := Site.nearest(from, 400.0, func(s): return s.is_store() and s.building.store_bonus > 0 and not s.building.camp)
	return g.global_position if g != null else Site.store_point(from)

# ---------------------------------------------------------------- layout

## A workplace was just finished: its own task sites (a second deer herd, a
## stand of timber) and, for a farmhouse, its first field plots.
static func lay_out(s: Site) -> void:
	if s.building == null or not s.building.workplace:
		return
	var w = Game.world
	if w == null or not is_instance_valid(w) or not w.has_method("spawn_site"):
		return
	for row in s.building.spawns:
		var at: Vector3 = s.global_position + s.global_basis * Vector3(float(row[1]), 0, float(row[2]))
		var jid := StringName(str(row[0]))
		if Site.nearest(at, 4.0, func(o): return o.job != null and o.job.id == jid) != null:
			continue
		w.spawn_site(jid, Vector3(at.x, 0, at.z))
	if s.building.work_jobs.has(&"farm_field"):
		lay_fields(s, FIRST_FIELDS)

## Stakes up to `n` new field plots in a farmhouse's radius: the authored field
## spots first, then a ring round the farmhouse. Returns the plots laid.
static func lay_fields(farm: Site, n: int) -> int:
	var w = Game.world
	if w == null or not is_instance_valid(w) or not w.has_method("spawn_plot"):
		return 0
	var r: float = farm.building.work_radius - 3.0
	var cands: Array = []
	if w.has_method("plot_spots"):
		for spot in w.plot_spots(&"field"):
			cands.append(Vector3(spot.x, 0, spot.y))
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.4
		cands.append(farm.global_position + Vector3(cos(a), 0, sin(a)) * FIELD_RING)
	var laid := 0
	for at in cands:
		if laid >= n:
			break
		var flat := Vector2(at.x - farm.global_position.x, at.z - farm.global_position.z)
		if flat.length() > r or not _field_room(w, at, farm):
			continue
		var f: Site = w.spawn_plot(&"field", Vector3(at.x, 0, at.z))
		if f != null:
			if w.has_method("region_at") and w.region_at(f.global_position) == &"southern_plains":
				f.dry_land = true
			laid += 1
	return laid

static func _field_room(w, at: Vector3, farm: Site) -> bool:
	if w.has_method("is_water"):
		for d in [Vector3.ZERO, Vector3(4.5, 0, 3.5), Vector3(-4.5, 0, 3.5), Vector3(4.5, 0, -3.5), Vector3(-4.5, 0, -3.5)]:
			if w.is_water(at + d):
				return false
	if w.has_method("is_region_open") and w.has_method("region_at") and not w.is_region_open(w.region_at(at)):
		return false
	for o in Village.sites:
		if not is_instance_valid(o) or o.is_queued_for_deletion():
			continue
		var rr := 1.5
		if o.building != null:
			rr = maxf(o.building.footprint.x, o.building.footprint.y) * 0.5
		if Vector2(o.global_position.x - at.x, o.global_position.z - at.z).length() < rr + 5.0:
			return false
	return true

## Field plots and fields a farmhouse has (for wishes and the bot).
static func field_count(farm: Site) -> int:
	return tasks(farm).filter(func(t): return t.building != null and t.building.id == &"field").size()

# ---------------------------------------------------------------- hover

static func hover(s: Site) -> String:
	if s.is_workplace():
		var b := s.building
		var t := "%s  crew %d/%d" % [b.title, s.slots_filled(), s.max_slots()]
		if s.max_slots() < b.crew_max:
			t += " (a stronger grip staffs more)"
		if b.work_jobs.has(&"farm_field"):
			t += "  fields %d" % field_count(s)
		if b.bin_cap > 0:
			t += "  bin %d/%d" % [bin_total(s), b.bin_cap]
			var carters := 0
			for c in Village.sites:
				if is_instance_valid(c) and c.parent_uid == s.uid and c.job != null and c.job.id == &"cart_haul":
					carters += c.slots_filled()
			if carters == 0 and bin_total(s) > 0:
				t += "  (no carter: set someone on the cart)"
		# [era3] the bench, the bins it fetches, the roads it paves
		if b.bench_job != &"":
			var jd: JobDef = Defs.job(b.bench_job)
			var miss := bench_missing(s)
			t += "  bench: %s%s" % [jd.title.to_lower() if jd else str(b.bench_job), "" if miss == &"" else " (waits for %s)" % str(miss).replace("_", " ")]
		if not b.fetch_from.is_empty():
			var bins := tasks(s).filter(func(x): return x.is_workplace()).size()
			t += "  fetches grain from %d farmhouse%s" % [bins, "" if bins == 1 else "s"]
		if b.paves:
			t += "  roads paved %d" % int(Village.stats.get("roads_paved", 0))
		if not s.discovered():
			t += "  (needs stone tools)"
		elif b.work_jobs.has(&"hunt") and not Site.has_drying_rack():
			t += "  (%s)" % Site.NEEDS_RACK   # [polish]
		return t
	if s.job != null and s.job.id == &"cart_haul":
		var w := Site.by_uid(s.parent_uid)
		return "%s %d/%d  hauls the %s's bin (%d) to the stores" % [s.job.title, s.slots_filled(), s.max_slots(),
			w.building.title.to_lower() if w != null and w.building != null else "farmhouse", bin_total(w) if w != null else 0]
	if s.workplace_only() or (s.job != null and not s.is_plot() and task_job(s.job.id) and s.covering_workplace() != null):
		var w2 := s.covering_workplace()
		var what := s.title()
		var line := ""
		if s.is_field():
			what = "Field"
			line = "  " + s.field_text()
		elif s.is_plot():
			what = "New field"
			line = "  being cleared %d%%" % int(100.0 * s.build_progress())
		elif s.job != null and s.job.node_amount > 1 and s.amount >= 0:
			line = "  %d left" % s.amount
		if s.job != null and s.job.id == &"hunt" and not Site.has_drying_rack():
			line += "  (%s)" % Site.NEEDS_RACK   # [polish]
		if w2 != null:
			return "%s%s  (worked by the %s crew)" % [what, line, w2.building.title.to_lower()]
		var by := "farmhouse" if (s.is_field() or s.is_plot()) else ("hunting lodge" if s.job != null and s.job.id == &"hunt" else "workplace")
		return "%s%s  (a %s's crew works this: build one near it and staff it)" % [what, line, by]
	return ""

# ---------------------------------------------------------------- the crew at work

static func _task_ok(w: Site, t) -> bool:
	if t == w:
		return w.building.bench_job != &""     # [era3] the bench
	return t != null and is_instance_valid(t) and not t.is_queued_for_deletion() and covers(w, t)

## How much task `t` of workplace `w` wants work (the bench is `w` itself).
static func _need(w: Site, t: Site) -> float:
	return bench_need(w) if t == w else need(t)

static func _drop(p, w: Site) -> void:
	unclaim(w, p)
	p.task_site = null
	p._phase = "pick"
	p._timer = 0.0

## The person's work clip and tools follow the task (a field's sowing and
## reaping, a tree's axe, the hunt's spear), else the workplace's own.
static func _show_task(p, w: Site, t: Site) -> void:
	if p.visual == null:
		return
	var jd = t.job if t != null and t.job != null and not t.is_plot() else w.job
	if t == w and w.building.bench_job != &"":
		jd = Defs.job(w.building.bench_job)          # [era3] at the bench
	elif t != null and t != w and t.is_workplace():
		jd = Defs.job(&"cart_haul")                  # [era3] fetching a bin
	p.visual.set_task(jd)

## Where person `p` stands to work task `t`.
static func task_spot(w: Site, t: Site, p) -> Vector3:
	var i := maxi(_claimed(w, t).find(p), 0)
	if t == w:
		return w.slot_position(w.slot_of(p))     # [era3] at the bench
	if t.job != null and t.job.id == &"hunt":
		var a := TAU * float(i) / 5.0 + 0.3
		var q := t.global_position + Vector3(cos(a), 0, sin(a)) * 3.2
		q.y = Site.ground(q.x, q.z)
		return q
	return t.slot_position(i)

## One sim tick of a crew member `p` at workplace `w`.
static func step(p, w: Site, dt: float) -> void:
	if not w.discovered():
		p._waiting_for = w.job.needs_discovery
		p._target = w.slot_position(w.slot_of(p))
		return
	match p._phase:
		"to_task":
			if not is_instance_valid(p.task_site):
				_drop(p, w)          # [era3] its task was finished and freed (a paved stretch)
				return
			var t: Site = p.task_site
			if not _task_ok(w, t) or _need(w, t) <= 0.0:
				_drop(p, w)
				return
			p._target = task_spot(w, t, p)
			if p._arrived():
				p._phase = "work"
				p._timer = 0.0
		"work":
			if not is_instance_valid(p.task_site):
				_drop(p, w)
				return
			var t2: Site = p.task_site
			if not _task_ok(w, t2):
				_drop(p, w)
				return
			p._target = task_spot(w, t2, p)
			p._first_work(w)
			_work(p, w, t2, dt)
		"deliver":
			_deliver(p, w)
		_:
			if not p._cargo.is_empty():
				p._phase = "deliver"
				return
			var t3 := pick_task(w, p)
			if t3 == null:
				p.task_site = null
				p._waiting_for = idle_reason(w)
				p._target = w.slot_position(w.slot_of(p))
				p._phase = "wait"
				return
			p._waiting_for = &""
			claim(w, t3, p)
			p.task_site = t3
			_show_task(p, w, t3)
			p._phase = "to_task"
			p._go(task_spot(w, t3, p), Person.WALK_SPEED)

static func _work(p, w: Site, t: Site, dt: float) -> void:
	var r: float = dt * p.rate()
	# [era3] the bench, a bin to fetch, a road to pave
	if t == w:
		_bench(p, w, r)
		return
	if t.is_workplace():
		_fetch(p, w, t)
		return
	if t.job != null and t.job.id == Paving.JOB:
		Paving.work(p, w, t, r)
		return
	if t.is_plot():
		# clearing a new field
		p._waiting_for = &""
		t.add_build_work(r)
		p._gain_skill(&"building", 0.003 * dt)
		if not t.is_plot():
			_drop(p, w)
		return
	if t.is_field():
		if need(t) <= 0.0:
			_drop(p, w)
			return
		var was: int = t.field_stage
		if t.field_tend(r, true, crew_at(w, t)):
			p._gain_skill(&"farming", Person.SKILL_PER_CYCLE * 2.0)
			p._placement_faith()
			if was == Site.Field.RIPE and t.last_yield > 0:
				p._cargo[&"grain"] = int(p._cargo.get(&"grain", 0)) + t.last_yield
				t.last_yield = 0
				p._set_cargo_visual()
				unclaim(w, p)
				p.task_site = null
				p._phase = "deliver"
			else:
				_drop(p, w)
		elif t.is_blighted() and crew_at(w, t) < 2:
			p._waiting_for = &"a second farmer"
		else:
			p._waiting_for = &""
		return
	if t.job != null and t.job.id == &"hunt":
		_hunt(p, w, t, dt)
		return
	# a tree (or any gather node): an armful, then home with it
	if not t.can_work_now():
		_drop(p, w)
		return
	p._waiting_for = &""
	p._timer += r
	if p._timer >= t.job.work_time:
		p._timer = 0.0
		if t.take_one():
			for k in t.job.outputs:
				p._cargo[k] = int(p._cargo.get(k, 0)) + int(t.job.outputs[k])
			p._set_cargo_visual()
			p._armful += 1
			Events.job_completed.emit(t)
			if p._armful >= Person.ARMFUL or not t.can_work_now():
				p._armful = 0
				unclaim(w, p)
				p.task_site = null
				p._phase = "deliver"

## The hunt: once two hunters are at the herd they stalk it together; the
## kill is shared out and carried home.
static func _hunt(p, w: Site, t: Site, dt: float) -> void:
	if not t.can_work_now():
		_drop(p, w)
		return
	var party: Array = _claimed(w, t).filter(func(q): return q.state == Person.S.WORK and q._phase == "work")
	if party.size() < HUNT_PARTY:
		p._waiting_for = &"another hunter"
		return
	p._waiting_for = &""
	t.progress += dt * p.rate() / (t.job.work_time * float(HUNT_PARTY))
	if t.progress < 1.0:
		return
	t.progress = 0.0
	if not t.take_one():
		return
	var n := party.size()
	var i := 0
	for k in t.job.outputs:
		var total := int(t.job.outputs[k])
		for q in party:
			var share := total / n + (1 if i < total % n else 0)
			i += 1
			if share > 0:
				q._cargo[k] = int(q._cargo.get(k, 0)) + share
	for q in party:
		q._set_cargo_visual()
		q._gain_skill(&"gathering", Person.SKILL_PER_CYCLE * 2.0)
		q.needs[&"joy"] = minf(q.needs[&"joy"] + 0.1, 1.0)
		unclaim(w, q)
		q.task_site = null
		q._phase = "deliver"
	Village.stats["lodge_hunts"] = int(Village.stats.get("lodge_hunts", 0)) + 1
	Events.job_completed.emit(t)

## Home with the goods: into the bin (the farmhouse), or to the stores.
static func _deliver(p, w: Site) -> void:
	if p._cargo.is_empty():
		p._phase = "pick"
		return
	var to_bin: bool = w.building.bin_cap > 0 and bin_room(w) > 0 and not p.has_meta(&"bin_full") and not _fetched(w, p)
	var dest: Vector3 = w.slot_position(w.slot_of(p)) if to_bin or _fetched(w, p) else p._store_slot()
	if p._target.distance_to(dest) > 0.5:
		p._go(dest, Person.WALK_SPEED)
	if not p._arrived():
		return
	if to_bin:
		for k in p._cargo.keys():
			var put := bin_add(w, k, int(p._cargo[k]))
			p._cargo[k] = int(p._cargo[k]) - put
			if int(p._cargo[k]) <= 0:
				p._cargo.erase(k)
		if not p._cargo.is_empty():
			p.set_meta(&"bin_full", true)    # no room: on to the stores with the rest
			return
	else:
		for k in p._cargo:
			Village.add_store(k, int(p._cargo[k]))
		p._cargo.clear()
	if p.has_meta(&"bin_full"):
		p.remove_meta(&"bin_full")
	p._set_cargo_visual()
	p._gain_skill(w.job.skill, Person.SKILL_PER_CYCLE)
	p._placement_faith()
	Events.job_completed.emit(w)
	p._phase = "pick"

# ---------------------------------------------------------------- the carter

## One sim tick of a carter `p` on cart site `c` (beside its workplace).
static func haul_step(p, c: Site, dt: float) -> void:
	var w := Site.by_uid(c.parent_uid)
	if w == null or not w.is_workplace():
		p.go_idle()
		return
	match p._phase:
		"to_store":
			if not p._arrived():
				return
			for k in p._cargo.keys():
				var put := Village.add_store(k, int(p._cargo[k]))
				var left := int(p._cargo[k]) - put
				if left > 0:
					bin_add(w, k, left, true)    # the stores are full: back in the bin
			p._cargo.clear()
			p._set_cargo_visual()
			p._gain_skill(c.job.skill, Person.SKILL_PER_CYCLE)
			p._placement_faith()
			Village.stats["carted"] = int(Village.stats.get("carted", 0)) + 1
			Events.job_completed.emit(c)
			p._phase = "load"
			p._go(c.slot_position(c.slot_of(p)), Person.WALK_SPEED)
		_:
			p._target = c.slot_position(c.slot_of(p))
			if not p._arrived():
				return
			if bin_total(w) <= 0:
				p._waiting_for = &"the harvest"
				return
			var room := false
			for k in w.bin:
				if Village.store(k) < Village.store_cap:
					room = true
			if not room:
				p._waiting_for = &"room in the stores"
				return
			p._waiting_for = &""
			p._first_work(c)
			var load := CART_LOAD * (2 if Flags.has(&"carts") else 1)
			p._cargo = bin_take(w, load)
			p._set_cargo_visual()
			p._phase = "to_store"
			var g := granary_point(p.global_position)
			var a := float(p.uid) * 2.39996
			p._go(g + Vector3(cos(a), 0, sin(a)) * 2.4, Person.WALK_SPEED)

# ---------------------------------------------------------------- [era3] the bench

## What the open plots still wait on (so a bench never works it into
## something else). Looked up once a game second.
static var _wanted: Dictionary = {}
static var _wanted_t: float = -INF

static func plots_want(k: StringName) -> int:
	if absf(Clock.total_t - _wanted_t) >= 1.0:
		_wanted_t = Clock.total_t
		_wanted = {}
		for s in Village.sites:
			if is_instance_valid(s) and s.state == Site.State.PLOT and s.building != null:
				for c in s.building.cost:
					_wanted[c] = int(_wanted.get(c, 0)) + maxi(s.remaining(c), 0)
	return int(_wanted.get(k, 0))

## Of input `k`, what the bench may use: its own bin, then the stores beyond
## what the plots want (and, for stone, a reserve).
static func _usable(w: Site, k: StringName) -> int:
	var spare := Village.store(k) - plots_want(k) - (STONE_RESERVE if k == &"stone" else 0)
	return int(w.bin.get(k, 0)) + maxi(spare, 0)

## The first input the bench is short of (&"" when it can work).
static func bench_missing(w: Site) -> StringName:
	var jd: JobDef = Defs.job(w.building.bench_job)
	if jd == null:
		return &"nothing near"
	for k in jd.inputs:
		if _usable(w, k) < int(jd.inputs[k]):
			return k
	for k in jd.outputs:
		if Village.store(k) >= mini(BENCH_STOCK, Village.store_cap - 2):
			return &"room in the stores"
	return &""

## How much the bench wants work now (0 = it cannot, or nobody needs more).
static func bench_need(w: Site) -> float:
	if w.building == null or w.building.bench_job == &"" or not w.is_workplace():
		return 0.0
	return 3.5 if bench_missing(w) == &"" else 0.0

static func bench_cap(w: Site) -> int:
	var jd: JobDef = Defs.job(w.building.bench_job)
	return maxi(jd.max_people if jd != null else 1, 2)

## A cycle at the bench: inputs from the bin first, then the stores; what it
## makes goes in the bin (or the stores when there is no room).
static func _bench(p, w: Site, r: float) -> void:
	var jd: JobDef = Defs.job(w.building.bench_job)
	if not p.has_meta(&"bench_paid"):
		if bench_missing(w) != &"":
			_drop(p, w)
			return
		for k in jd.inputs:
			var n := int(jd.inputs[k])
			var from_bin := mini(int(w.bin.get(k, 0)), n)
			if from_bin > 0:
				w.bin[k] = int(w.bin[k]) - from_bin
				if int(w.bin[k]) <= 0:
					w.bin.erase(k)
			if n - from_bin > 0:
				Village.take_store(k, n - from_bin)
		bin_visual(w)
		p.set_meta(&"bench_paid", true)
		p._timer = 0.0
	p._waiting_for = &""
	p._timer += r
	if p._timer < jd.work_time:
		return
	p._timer = 0.0
	p.remove_meta(&"bench_paid")
	for k in jd.outputs:
		var n := int(jd.outputs[k])
		var put := bin_add(w, k, n) if w.building.bin_cap > 0 else 0
		if n - put > 0:
			Village.add_store(k, n - put)
	p._gain_skill(jd.skill, Person.SKILL_PER_CYCLE)
	p._placement_faith()
	Village.stats["bench_cycles"] = int(Village.stats.get("bench_cycles", 0)) + 1
	Events.job_completed.emit(w)
	_drop(p, w)

# ---------------------------------------------------------------- [era3] fetching

## A miller takes a load from a farmhouse bin (what the mill's bench grinds).
static func _fetch(p, w: Site, t: Site) -> void:
	var jd: JobDef = Defs.job(w.building.bench_job)
	var load := CART_LOAD * (2 if Flags.has(&"carts") else 1)
	var got := 0
	for k in t.bin.keys():
		if jd != null and not jd.inputs.has(k):
			continue
		var n := mini(int(t.bin[k]), load - got)
		if n <= 0:
			continue
		p._cargo[k] = int(p._cargo.get(k, 0)) + n
		t.bin[k] = int(t.bin[k]) - n
		if int(t.bin[k]) <= 0:
			t.bin.erase(k)
		got += n
	bin_visual(t)
	if got > 0:
		p._set_cargo_visual()
		p._gain_skill(&"gathering", Person.SKILL_PER_CYCLE)
		Village.stats["mill_fetches"] = int(Village.stats.get("mill_fetches", 0)) + 1
	unclaim(w, p)
	p.task_site = null
	p._phase = "deliver" if got > 0 else "pick"

## Is `p` carrying what the bench grinds (fetched from a bin)? It goes to the
## stores at the workplace, where the bench draws it.
static func _fetched(w: Site, p) -> bool:
	if w.building.fetch_from.is_empty() or p._cargo.is_empty():
		return false
	var jd: JobDef = Defs.job(w.building.bench_job)
	if jd == null:
		return false
	for k in p._cargo:
		if not jd.inputs.has(k):
			return false
	return true
