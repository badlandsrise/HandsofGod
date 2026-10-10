class_name Site extends Node3D
## A place where work happens: a gather node (berry bush), a job at a building
## (fire tending), a group job (log haul), or a build plot that becomes a
## building. The hand only ever talks to Sites through the functions marked [hand].
##
## Set `job` for a work site, or `building` for a plot (state PLOT). Set
## `start_finished` with `building` for a building that already stands
## (the layout's starting fire pit or cave).

enum State { JOB, PLOT, BUILDING, FINISHED }

const DEFAULT_SCENE := "res://scenes/sites/site.tscn"
const FIRE_MAX_FUEL := 150.0        # seconds of burn a fire can hold
const FIRE_FUEL_PER_WOOD := 75.0
const FIRE_PIT_RADIUS := 5.0        # warmth of a bare fire pit (a tend_fire site with no building)
const STORE_CAP_PER_STORE := 20

@export var job: JobDef                 # the work done here (null for an unfinished plot)
@export var building: BuildingDef       # set for plots/buildings
@export var start_finished: bool = false
@export var start_fuel: float = 0.0     # fires: seconds of fuel at the start
var state: int = State.JOB
var uid: int = 0
var workers: Array = []                 # Person nodes assigned here (working or waiting)

var amount: int = -1                    # GATHER/GROUP nodes: units left (-1 infinite)
var regrow_t: float = 0.0
var progress: float = 0.0               # group job progress 0..1
var group_running: bool = false
var delivered: Dictionary = {}          # build plot: material -> delivered
var incoming: Dictionary = {}           # build plot: material -> reserved by a builder
var build_done: float = 0.0             # person-seconds of building done
var fuel_t: float = 0.0                 # fires: seconds of burn left
var inside: Array = []                  # Person nodes sheltering inside
var parent_uid: int = 0                 # extra job sites spawned by a finished building
var children_spawned: bool = false
var origin: Vector3 = Vector3.INF       # moving group jobs (log hauls) start here
var evergreen: bool = false             # safety net (doc 8.1): in a food crisis this bush never runs dry or sleeps
var raise_parent: int = 0               # a raising group job (barn, bridge, temple): the plot it finishes

# --- fields (Era 2 farming: sow, water and weed, harvest before the frost) ----------
enum Field { TILLED, SPROUTS, GROWING, RIPE, STUBBLE }
const FIELD_STAGE_NAMES: Array[String] = ["tilled", "sprouts", "growing", "ripe", "stubble"]
const FIELD_SOW_WORK := 14.0            # person-seconds to sow a tilled field
const FIELD_HARVEST_WORK := 16.0        # person-seconds to bring the harvest in
const FIELD_CURE_WORK := 18.0           # person-seconds of work on a blighted field to save it
const FIELD_GROW_TIME := 120.0          # seconds from sowing to ripe, watered
const FIELD_REST := 25.0                # stubble is ploughed back to tilled after this long (not in winter)
const FIELD_WATER_EVERY := 8.0          # tending uses one water from the stores this often (person-seconds)
var field_stage: int = Field.TILLED
var field_grow: float = 0.0             # 0..1 sprouts to ripe
var field_work: float = 0.0             # sow / harvest progress, person-seconds
var field_cure: float = 0.0             # cure progress on a blighted field
var field_quality: float = 1.0          # running average of moisture while growing (sets the yield)
var moisture: float = 0.7               # 0 dry .. 1 soaked
var blight_t: float = -1.0              # >= 0 while blighted: seconds since it began
var dry_land: bool = false
var _dry_t: float = 0.0
const FIELD_WITHER := 40.0
const HARVEST_FAITH := 2.0              # the Southern Plains: dries twice as fast
var _field_rest: float = 0.0
var _field_water_acc: float = 0.0
var _tended: float = 0.0                # seconds of tending left (people present recently)
var _raise_check: float = 0.0
var _vis_key: String = ""

var visual: Node3D
var bar: SiteBar
var _loaded := false
var _defs_ready := false

func _ready() -> void:
	add_to_group("persist"); add_to_group("sites")
	Village.register_site(self)
	if uid == 0:
		uid = Village.new_person_id()
	if not _loaded:
		_init_from_defs()
	if origin == Vector3.INF:
		origin = global_position
	bar = SiteBar.new()
	bar.name = "Bar"
	bar.position = Vector3(0, _bar_height(), 0)
	add_child(bar)
	rebuild_visual()
	if not Events.sim_tick.is_connected(sim):
		Events.sim_tick.connect(sim)

func _exit_tree() -> void:
	Village.unregister_site(self)

func _init_from_defs() -> void:
	if _defs_ready:
		return
	_defs_ready = true
	if building != null and job == null and not start_finished:
		state = State.PLOT
		for k in building.cost:
			delivered[k] = 0
			incoming[k] = 0
		if building.cost.is_empty():
			state = State.BUILDING      # a field to clear: work, no materials
	elif building != null and start_finished:
		_finish(true)
	else:
		state = State.JOB
	if job != null:
		amount = job.node_amount
	if fuel_t <= 0.0:
		fuel_t = start_fuel

# --- what kind of site --------------------------------------------------------

func is_plot() -> bool:
	return state == State.PLOT or state == State.BUILDING

func is_group() -> bool:
	return not is_plot() and job != null and job.kind == JobDef.Kind.GROUP

func is_shelter() -> bool:
	return state == State.FINISHED and building != null and building.shelter > 0

func is_fire() -> bool:
	return job != null and job.id == &"tend_fire"

## A farmed field (Era 2): a TEND job with crop stages.
func is_field() -> bool:
	return job != null and job.id == &"farm_field" and not is_plot()

## A plot whose materials are in and that now waits for its group raising
## (barn, bridge, temple): people go to the raising job beside it instead.
func awaiting_raise() -> bool:
	return state == State.BUILDING and building != null and building.raise_job != &""

## The hand looks past this site (a plot waiting for its raising crew).
func hand_ignores() -> bool:
	return awaiting_raise()

## A camp, granary, barn or food store: people bring goods here and eat here.
func is_store() -> bool:
	if state != State.FINISHED or building == null:
		return false
	return building.id == &"food_store" or building.store_bonus > 0 or building.camp

## The JobDef a person placed here does (the generic build job on plots).
func work_job() -> JobDef:
	if is_plot():
		return Defs.job(&"build")
	return job

## Group hauls (single-use logs) travel to the store (or the fire) while the group works.
func moves_to_store() -> bool:
	return is_group() and job.node_amount == 1 and (job.outputs.size() > 0 or job.carry_to == &"fire") and not job.needs_blessed

## Where a moving group job is heading.
func carry_target() -> Vector3:
	if job != null and job.carry_to == &"fire":
		var f := Site.nearest(origin, 120.0, func(o): return o != self and o.is_fire())
		if f != null:
			var away := origin - f.global_position
			away.y = 0.0
			return f.global_position + away.normalized() * 2.4
	return Site.store_point(origin)

func is_finished_building(id: StringName) -> bool:
	return state == State.FINISHED and building != null and building.id == id

func title() -> String:
	if is_plot():
		return "%s plot" % building.title
	if job != null:
		return job.title
	if building != null:
		return building.title
	return "Site"

# --- [hand] API -------------------------------------------------------------------

## [hand] slots in total (people who can work, or shelter, here).
func max_slots() -> int:
	if is_plot():
		return 0 if awaiting_raise() else building.build_slots
	if job != null:
		return job.max_people
	if is_shelter():
		return building.shelter
	return 0

## [hand] slots taken.
func slots_filled() -> int:
	if job == null and is_shelter():
		return inside.size()
	return _valid_workers().size()

## [hand] true if `n` more people can be placed here right now.
func can_accept(n: int = 1) -> bool:
	if is_queued_for_deletion():
		return false
	if job != null and not is_plot():
		if job.needs_power != &"" and not Faith.has(job.needs_power):
			return false
		if not discovered():
			return false
		if amount == 0 and job.regrow_time <= 0.0 and not (evergreen and Site.food_crisis()):
			return false
	return free_slots() >= n

## [hand] free slots.
func free_slots() -> int:
	return maxi(max_slots() - slots_filled(), 0)

## [hand] slots needed before a group job starts (0 for non-group work).
func group_needs() -> int:
	if not is_group() or group_running:
		return 0
	return maxi(job.min_people - _valid_workers().size(), 0)

## [hand] where the i-th placed person should land (world position).
func slot_position(i: int) -> Vector3:
	if building != null and building.id == &"field":
		# farmers spread along the furrows inside the field
		var fp := building.footprint
		var col := float(i % 3) - 1.0
		var row := 0.5 - float((i / 3) % 2)
		var p0 := global_position + global_basis * Vector3(col * fp.x * 0.28, 0.0, row * fp.y * 0.36)
		p0.y = Site.ground(p0.x, p0.z)
		return p0
	if building != null and building.id == &"bridge" and state != State.FINISHED:
		# the bridge is built from its near bank: the builders stand on the shore
		var along := global_basis * Vector3(1, 0, 0)
		if (global_position + along).z < (global_position - along).z:
			along = -along
		var end := global_position - along * (building.footprint.x * 0.5 + 1.6)
		var side := Vector3(-along.z, 0.0, along.x)
		var pb := end - along * float(i / 3) * 1.4 + side * (float(i % 3) - 1.0) * 1.3
		pb.y = Site.ground(pb.x, pb.z)
		return pb
	var n := maxi(max_slots(), 1)
	var r := pick_radius() + 0.35
	var a := TAU * float(i) / float(n) + 0.5
	var p := global_position + Vector3(cos(a), 0.0, sin(a)) * r
	p.y = Site.ground(p.x, p.z)
	return p

## Index of a person's slot (their position in the workers list).
func slot_of(p) -> int:
	var i := workers.find(p)
	return i if i >= 0 else workers.size()

## [hand] short label for the hover tooltip, e.g. "Haul a log 2/3".
func hover_text() -> String:
	if awaiting_raise():
		return "%s  ready to raise: place %d people on the crew at once" % [title(), _raise_need()]
	if is_plot():
		var parts: Array = []
		for k in building.cost:
			parts.append("%s %d/%d" % [k, int(delivered.get(k, 0)), int(building.cost[k])])
		var line := ", ".join(parts) if state == State.PLOT else "building %d%%" % int(100.0 * build_progress())
		return "%s  %s  [%d/%d]" % [title(), line, slots_filled(), max_slots()]
	if job == null and is_shelter():
		return "%s (%d/%d inside)" % [building.title, inside.size(), building.shelter]
	if job == null:
		return title()
	if is_field():
		return "%s %d/%d  %s" % [job.title, slots_filled(), max_slots(), field_text()]
	var t := "%s %d/%d" % [job.title, slots_filled(), max_slots()]
	if is_group():
		if group_running:
			t += "  working %d%%" % int(progress * 100.0)
		else:
			t += "  needs %d at once" % job.min_people
	if job.needs_power != &"" and not Faith.has(job.needs_power):
		var pd := Defs.power(job.needs_power)
		t += "  (needs %s)" % (pd.title if pd else str(job.needs_power))
	elif not discovered():
		t += "  (needs stone tools)"
	if job.needs_blessed and _blessed_present() < job.min_people:
		t += "  (only the blessed can do this)"
	if amount >= 0 and job.node_amount > 1:
		t += "  %d left" % amount
	if not can_work_now():
		t += "  (resting for winter)" if _winter_stopped() else "  (regrowing)"
	if is_fire():
		t += "  lit" if lit() else "  out"
	return t

## [hand] radius used for picking this site with the mouse.
func pick_radius() -> float:
	if building != null:
		return maxf(building.footprint.x, building.footprint.y) * 0.5 + 0.2
	if job != null:
		match job.id:
			&"fetch_water", &"fish_by_hand": return 2.0
			&"hunt", &"great_elk_hunt": return 2.2
			&"festival": return 2.4
			&"haul_log", &"carry_log": return 1.4
			&"raft_launch": return 2.2
			&"harvest_festival": return 3.0
	if raise_parent != 0:
		return float(get_meta("raise_r", 2.5))
	return 1.2

# --- people --------------------------------------------------------------------------

## Called by Person when it is assigned here.
func claim(p) -> void:
	if not workers.has(p):
		workers.append(p)

## Called by Person when it leaves.
func release(p) -> void:
	workers.erase(p)
	inside.erase(p)
	if group_running and _present().size() < job.min_people:
		_stop_group()

func enter_shelter(p) -> bool:
	if not is_shelter():
		return false
	if inside.has(p):
		return true
	if inside.size() >= building.shelter:
		return false
	inside.append(p)
	return true

func leave_shelter(p) -> void:
	inside.erase(p)

func shelter_room() -> int:
	if not is_shelter():
		return 0
	inside = inside.filter(func(x): return is_instance_valid(x))
	return building.shelter - inside.size()

func _valid_workers() -> Array:
	workers = workers.filter(func(x): return is_instance_valid(x) and x.alive())
	return workers

func _blessed_present() -> int:
	var n := 0
	for p in _present():
		if p.is_blessed():
			n += 1
	return n

func _present() -> Array:
	var out: Array = []
	for p in _valid_workers():
		if p.is_present_at(self, 1.6 if group_running else 0.9):
			out.append(p)
	return out

# --- gather / work ------------------------------------------------------------------

func _winter_stopped() -> bool:
	if evergreen and Site.food_crisis():
		return false
	return job != null and job.winter_stops and Clock.season == Clock.Season.WINTER

## False while this job waits for its season (the bridge piers: winter, when the river is low).
func in_season() -> bool:
	return job == null or job.only_season < 0 or Clock.season == job.only_season

## Food is nearly gone: the evergreen bushes by the cave keep giving (doc 8.1).
static func food_crisis() -> bool:
	return Village.food() < maxi(Village.population(), 2)

func set_evergreen(on: bool) -> void:
	evergreen = on

## True when this job's discovery (stone tools for felling) has been made.
func discovered() -> bool:
	if job == null or job.needs_discovery == &"":
		return true
	return Flags.has(job.needs_discovery)

## Whether work can happen here right now (not depleted, not stopped by winter).
func can_work_now() -> bool:
	if job == null:
		return false
	if _winter_stopped() or not in_season():
		return false
	return amount != 0 or (evergreen and Site.food_crisis())

## Takes one unit from a gather node. False when depleted.
func take_one() -> bool:
	if amount < 0:
		return true
	if evergreen and Site.food_crisis():
		return true                      # the evergreen bushes never run dry when food is gone
	if amount == 0:
		return false
	amount -= 1
	_on_amount_changed()
	return true

func lit() -> bool:
	return fuel_t > 0.0

func add_fuel(seconds: float) -> void:
	fuel_t = minf(fuel_t + seconds, FIRE_MAX_FUEL)

## A fire wants wood when it holds less than this.
func fire_wants_fuel() -> bool:
	return fuel_t < FIRE_MAX_FUEL - FIRE_FUEL_PER_WOOD

## A worker finished one cycle here (TEND/CRAFT). Fires gain fuel.
func on_cycle_done(_p) -> void:
	if is_fire():
		add_fuel(FIRE_FUEL_PER_WOOD)
	elif job != null and job.id == &"keep_market":
		_market_day()
	Events.job_completed.emit(self)

## A market stall's round: everyone near the market is cheered (doc 3, joy).
func _market_day() -> void:
	var r := maxf(joy_radius(), 12.0)
	for p in Village.alive():
		if p.global_position.distance_squared_to(global_position) <= r * r:
			p.needs[&"joy"] = minf(float(p.needs[&"joy"]) + 0.12, 1.0)

func warmth_radius() -> float:
	if state == State.FINISHED and building != null and building.warmth_radius > 0.0:
		if building.jobs.has(&"tend_fire"):
			return building.warmth_radius if lit() else 0.0
		return building.warmth_radius
	if is_fire() and building == null:
		return FIRE_PIT_RADIUS if lit() else 0.0
	return 0.0

func joy_radius() -> float:
	if state == State.FINISHED and building != null and building.joy_radius > 0.0:
		if building.jobs.has(&"tend_fire"):
			return building.joy_radius if lit() else 0.0
		return building.joy_radius
	if is_fire() and building == null and lit():
		return FIRE_PIT_RADIUS
	return 0.0

# --- build plots -------------------------------------------------------------------

## The next material a builder should fetch, or &"" when everything is on its way.
func next_material() -> StringName:
	if state != State.PLOT:
		return &""
	# what the store has first, so a builder never waits on stone with wood to hand
	var first: StringName = &""
	for k in building.cost:
		if int(delivered.get(k, 0)) + int(incoming.get(k, 0)) < int(building.cost[k]):
			if Village.store(k) > 0:
				return k
			if first == &"":
				first = k
	return first

func remaining(k: StringName) -> int:
	return int(building.cost.get(k, 0)) - int(delivered.get(k, 0)) - int(incoming.get(k, 0))

func reserve(k: StringName, n: int = 1) -> void:
	incoming[k] = int(incoming.get(k, 0)) + n

func unreserve(k: StringName, n: int = 1) -> void:
	incoming[k] = maxi(int(incoming.get(k, 0)) - n, 0)

func deliver(k: StringName, n: int = 1) -> void:
	unreserve(k, n)
	delivered[k] = int(delivered.get(k, 0)) + n
	if state == State.PLOT and materials_done():
		state = State.BUILDING
		if awaiting_raise():
			_begin_raise()
	rebuild_visual()

## Sites of the ids this building replaces, under its footprint, are taken
## down (the temple over the shrine and the drying rack).
func take_down_replaced() -> void:
	if building == null or building.replaces.is_empty():
		return
	var r := maxf(building.footprint.x, building.footprint.y) * 0.5 + 1.0
	for s in Village.sites.duplicate():
		if s == self or not is_instance_valid(s) or s.building == null or not building.replaces.has(s.building.id):
			continue
		if s.global_position.distance_to(global_position) > r:
			continue
		if s.building.id == &"drying_rack" and s.state == State.FINISHED:
			Village.store_cap -= STORE_CAP_PER_STORE / 2
		s.remove_site()

## Takes this site out of the world, sending its workers off and removing its
## extra job sites (the shrine's prayer spot).
func remove_site() -> void:
	for p in _valid_workers().duplicate():
		p.go_idle()
	for p in inside.duplicate():
		if is_instance_valid(p) and p.has_method("wake"):
			p.wake()
	workers.clear()
	inside.clear()
	for c in Village.sites.duplicate():
		if is_instance_valid(c) and c != self and c.parent_uid == uid and uid != 0:
			c.remove_site()
	Village.unregister_site(self)
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()

func materials_done() -> bool:
	if building == null:
		return true
	for k in building.cost:
		if int(delivered.get(k, 0)) < int(building.cost[k]):
			return false
	return true

func build_progress() -> float:
	if building == null or building.build_work <= 0.0:
		return 1.0
	return clampf(build_done / building.build_work, 0.0, 1.0)

func add_build_work(w: float) -> void:
	if state != State.BUILDING or awaiting_raise():
		return
	build_done += w
	if build_done >= building.build_work:
		_finish(false)

func _finish(silent: bool) -> void:
	var builders := workers.duplicate()
	workers.clear()
	state = State.FINISHED
	build_done = building.build_work
	if building.jobs.size() > 0:
		job = Defs.job(building.jobs[0])
		amount = job.node_amount if job else -1
	if is_fire():
		fuel_t = maxf(fuel_t, 60.0)     # they light it as soon as it is built
	if building.id == &"food_store":
		Village.store_cap += STORE_CAP_PER_STORE
	elif building.id == &"drying_rack":
		Village.store_cap += STORE_CAP_PER_STORE / 2
	if building.store_bonus > 0 and not silent:
		Village.store_cap += building.store_bonus
	if not silent:
		take_down_replaced()
	if is_field():
		field_stage = Field.TILLED
		moisture = 0.25 if dry_land else 0.7
	for p in builders:
		if is_instance_valid(p) and p.has_method("go_idle"):
			p.go_idle()
	if is_inside_tree():
		_spawn_extra_job_sites()
		rebuild_visual()
	if not silent:
		Events.building_finished.emit(self)

func _spawn_extra_job_sites() -> void:
	if children_spawned or building == null:
		return
	children_spawned = true
	for i in range(1, building.jobs.size()):
		var jd := Defs.job(building.jobs[i])
		if jd == null:
			continue
		var s: Site = load(DEFAULT_SCENE).instantiate()
		s.job = jd
		s.parent_uid = uid
		get_parent().add_child(s)
		var a := TAU * float(i) / float(building.jobs.size())
		s.global_position = global_position + Vector3(cos(a), 0, sin(a)) * (pick_radius() + 1.5)

# --- sim -------------------------------------------------------------------------

func sim(dt: float) -> void:
	if is_queued_for_deletion():
		return
	if job != null and not is_plot():
		_sim_regrow(dt)
		if is_group():
			_sim_group(dt)
		if is_field():
			_sim_field(dt)
	if awaiting_raise():
		_raise_check -= dt
		if _raise_check <= 0.0:
			_raise_check = 2.0
			if raise_site() == null:
				_begin_raise()
	if fuel_t > 0.0:
		fuel_t = maxf(fuel_t - dt, 0.0)
	if bar:
		if is_group() and (group_running or progress > 0.0):
			bar.show_value(progress, Color(1.0, 0.85, 0.3))
		elif state == State.BUILDING:
			bar.show_value(build_progress(), Color(0.5, 0.9, 0.4))
		elif state == State.PLOT and _materials_fraction() > 0.0:
			bar.show_value(_materials_fraction(), Color(0.7, 0.55, 0.35))
		else:
			bar.hide_bar()

func _materials_fraction() -> float:
	var need := 0; var got := 0
	for k in building.cost:
		need += int(building.cost[k]); got += int(delivered.get(k, 0))
	return float(got) / float(maxi(need, 1))

func _sim_regrow(dt: float) -> void:
	if job.regrow_time <= 0.0 or amount < 0 or amount >= job.node_amount or _winter_stopped():
		return
	regrow_t += dt
	if regrow_t >= job.regrow_time:
		regrow_t = 0.0
		amount += 1
		_on_amount_changed()

func _sim_group(dt: float) -> void:
	var present := _present()
	if not group_running:
		if present.size() >= job.min_people and can_work_now():
			group_running = true
			if moves_to_store() and progress <= 0.0:
				origin = global_position
			for p in present:
				p.begin_group_work(self)
			Events.job_started.emit(self, present.duplicate())
		return
	if present.size() < job.min_people or not can_work_now():
		_stop_group()
		return
	var rate := 0.0
	for p in present:
		if job.needs_blessed and not p.is_blessed():
			continue      # only blessed people can win the great elk hunt, or dance the festival
		rate += p.rate()
	rate /= float(present.size())
	var bonus := 1.0 + job.group_bonus * float(present.size() - job.min_people)
	progress += dt * rate * bonus / maxf(job.work_time, 0.1)
	if moves_to_store():
		var to := carry_target()
		var p3 := origin.lerp(to, minf(progress, 1.0) * (1.0 if job.carry_to == &"fire" else 0.85))
		p3.y = Site.ground(p3.x, p3.z)
		global_position = p3
	if progress >= 1.0:
		_complete_group(present)

func _stop_group() -> void:
	group_running = false
	for p in _valid_workers():
		p.back_to_waiting()

func _complete_group(present: Array) -> void:
	progress = 0.0
	group_running = false
	for k in job.outputs:
		Village.add_store(k, int(job.outputs[k]))
	if job.carry_to == &"fire":
		var f := Site.nearest(global_position, 30.0, func(o): return o != self and o.is_fire())
		if f != null:
			f.add_fuel(FIRE_MAX_FUEL)
	for p in present:
		p.on_group_done(self)
	Events.job_completed.emit(self)
	if raise_parent != 0:
		var plot := Site.by_uid(raise_parent)
		if plot != null and plot.awaiting_raise():
			plot._finish(false)
	if amount > 0:
		amount -= 1
		_on_amount_changed()
	if amount == 0 and job.regrow_time <= 0.0:
		for p in _valid_workers().duplicate():
			p.go_idle()
		workers.clear()
		Village.unregister_site(self)
		queue_free()
	else:
		for p in _valid_workers():
			p.back_to_waiting()

func _on_amount_changed() -> void:
	if visual and visual.has_method("set_fill") and job != null and job.node_amount > 0:
		visual.call("set_fill", float(amount) / float(job.node_amount))

# --- raising (group builds) ---------------------------------------------------------

func _raise_need() -> int:
	var j := Defs.job(building.raise_job) if building != null else null
	return j.min_people if j != null else 0

## The group job raising this plot, if it exists.
func raise_site() -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and not s.is_queued_for_deletion() and s.raise_parent == uid and uid != 0:
			return s
	return null

## The materials are in: the builders step back and a group job appears that
## raises the building (barn raising for 8, the bridge for 6, the temple for 8).
func _begin_raise() -> void:
	if not is_inside_tree() or raise_site() != null:
		return
	var j := Defs.job(building.raise_job)
	if j == null:
		_finish(false)
		return
	for p in _valid_workers().duplicate():
		p.go_idle()
	workers.clear()
	take_down_replaced()
	var s: Site = load(DEFAULT_SCENE).instantiate()
	s.job = j
	s.raise_parent = uid
	var fp := building.footprint
	var at := global_position
	var r := clampf(maxf(fp.x, fp.y) * 0.5 + 0.8, 2.5, 8.0)
	var w = Game.world
	if w != null and is_instance_valid(w) and w.has_method("is_water") and w.is_water(global_position):
		# the bridge: the crew gathers at its near end, on the bank
		var along := global_basis * Vector3(1, 0, 0) * (fp.x * 0.5 + 2.0)
		at = global_position - along if (global_position - along).z < (global_position + along).z else global_position + along
		r = 2.6
	s.set_meta("raise_r", r)
	if j.only_season >= 0 and Clock.season != j.only_season and j.season_note != "":
		Events.alert.emit(j.season_note, global_position)
	get_parent().add_child(s)
	s.global_position = Vector3(at.x, Site.ground(at.x, at.z), at.z)
	Events.alert.emit("The %s is ready to raise: it needs %d people at once" % [building.title.to_lower(), j.min_people], s.global_position)

# --- fields -------------------------------------------------------------------------

func is_blighted() -> bool:
	return blight_t >= 0.0

## Too late in the year to sow: the crop would not ripen before the frost.
static func sowing_season() -> bool:
	if Clock.season == Clock.Season.WINTER:
		return false
	return not (Clock.season == Clock.Season.AUTUMN and Clock.season_fraction() > 0.45)

## What the field needs now, for the hover card and the bot.
func field_want() -> StringName:
	if is_blighted():
		return &"cure"
	match field_stage:
		Field.TILLED:
			return &"sow" if Site.sowing_season() else &""
		Field.SPROUTS, Field.GROWING:
			return &"water" if moisture < 0.35 else &""
		Field.RIPE:
			return &"harvest"
	return &""

func field_text() -> String:
	if is_blighted():
		return "blight! %d%% saved" % int(100.0 * field_cure / FIELD_CURE_WORK)
	match field_stage:
		Field.TILLED:
			if not Site.sowing_season():
				return "fallow until spring"
			return "ready to sow %d%%" % int(100.0 * field_work / FIELD_SOW_WORK)
		Field.SPROUTS, Field.GROWING:
			return "growing %d%%%s" % [int(100.0 * field_grow), "  (dry: water it)" if moisture < 0.35 else ""]
		Field.RIPE:
			return "ripe: harvest %d%%" % int(100.0 * field_work / FIELD_HARVEST_WORK)
		Field.STUBBLE:
			return "stubble"
	return ""

func _drought_k() -> float:
	var w = Game.world
	if w != null and is_instance_valid(w) and w.get("threats") != null and w.threats.has_method("drought_active") and w.threats.drought_active():
		return 3.0
	return 1.0

func _raining_here() -> bool:
	var w = Game.world
	return w != null and is_instance_valid(w) and w.get("look") != null and w.look.raining()

func _sim_field(dt: float) -> void:
	_tended = maxf(_tended - dt, 0.0)
	var winter := Clock.season == Clock.Season.WINTER
	# moisture: dries in the sun (faster in summer, on the plains, in a drought)
	var dry := 0.0035 * (1.6 if Clock.season == Clock.Season.SUMMER else 1.0) * (1.8 if dry_land else 1.0) * _drought_k()
	if _raining_here():
		moisture = minf(moisture + 0.02 * dt, 1.0)
	elif not winter:
		moisture = maxf(moisture - dry * dt, 0.0)
	if is_blighted():
		blight_t += dt
		return
	match field_stage:
		Field.SPROUTS, Field.GROWING:
			if winter:
				_lose_crop("The frost took a crop that was still growing")
				return
			# bone dry for long (a drought nobody answered): the crop withers
			if moisture <= 0.01:
				_dry_t += dt
				if _dry_t >= FIELD_WITHER:
					_dry_t = 0.0
					_lose_crop("The drought withered a field. Rain, or water from the well, would have saved it")
					return
			else:
				_dry_t = 0.0
			var k := (0.3 + 0.7 * moisture) * (1.25 if _tended > 0.0 else 1.0)
			field_grow = minf(field_grow + dt * k / FIELD_GROW_TIME, 1.0)
			field_quality = lerpf(field_quality, moisture, minf(dt / 60.0, 1.0))
			var st := Field.SPROUTS if field_grow < 0.4 else Field.GROWING
			if field_grow >= 1.0:
				st = Field.RIPE
				field_work = 0.0
				if _valid_workers().is_empty():
					Events.alert.emit("The grain is ripe. Bring the harvest in before the frost", global_position)
			_set_field_stage(st)
		Field.RIPE:
			if winter:
				_lose_crop("The frost took a ripe crop nobody harvested")
		Field.STUBBLE:
			if not winter:
				_field_rest += dt
				if _field_rest >= FIELD_REST:
					_field_rest = 0.0
					field_work = 0.0
					_set_field_stage(Field.TILLED)

func _set_field_stage(st: int) -> void:
	if st == field_stage:
		return
	field_stage = st
	rebuild_visual()

func _lose_crop(why: String) -> void:
	field_grow = 0.0
	field_work = 0.0
	field_cure = 0.0
	blight_t = -1.0
	_field_rest = 0.0
	Village.stats["crops_lost"] = int(Village.stats.get("crops_lost", 0)) + 1
	Events.alert.emit(why, global_position)
	field_stage = -1
	_set_field_stage(Field.STUBBLE)

## A farmer present at the field does `w` person-seconds of work on what it
## needs now: sow, water and weed, harvest, or fight the blight. Returns true
## when a harvest came in (the farmer's cycle is done).
func field_tend(w: float) -> bool:
	if is_blighted():
		if _present().size() < 2:
			return false       # one alone cannot keep up with it: it takes two
		field_cure += w
		if field_cure >= FIELD_CURE_WORK:
			blight_t = -1.0
			field_cure = 0.0
			Village.stats["blights_cured"] = int(Village.stats.get("blights_cured", 0)) + 1
			Events.alert.emit("They saved the field from the blight", global_position)
			Events.threat_ended.emit(&"crop_blight")
			rebuild_visual()
			return true
		return false
	match field_stage:
		Field.TILLED:
			if not Site.sowing_season():
				return false
			field_work += w
			if field_work >= FIELD_SOW_WORK:
				field_work = 0.0
				field_grow = 0.0
				field_quality = moisture
				_set_field_stage(Field.SPROUTS)
				return true
		Field.SPROUTS, Field.GROWING:
			_tended = 2.0
			_field_water_acc += w
			var gain := 0.012
			if _field_water_acc >= FIELD_WATER_EVERY:
				_field_water_acc = 0.0
				if not Village.take_store(&"water", 1):
					gain = 0.004       # no water carried: they can only weed
			moisture = minf(moisture + gain * w, 1.0)
		Field.RIPE:
			field_work += w
			if field_work >= FIELD_HARVEST_WORK:
				field_work = 0.0
				var yield_n := roundi(float(job.outputs.get(&"grain", 10)) * lerpf(0.6, 1.2, clampf(field_quality, 0.0, 1.0)))
				Village.add_store(&"grain", yield_n)
				Village.stats["harvests"] = int(Village.stats.get("harvests", 0)) + 1
				Village.stats["grain_harvested"] = int(Village.stats.get("grain_harvested", 0)) + yield_n
				Faith.add(HARVEST_FAITH, global_position)     # they thank the hand for the harvest
				Events.job_completed.emit(self)
				_set_field_stage(Field.STUBBLE)
				return true
	return false

## The blight lands on this field (Era 2 threat).
func start_blight() -> bool:
	if not is_field() or is_blighted() or not (field_stage in [Field.SPROUTS, Field.GROWING, Field.RIPE]):
		return false
	blight_t = 0.0
	field_cure = 0.0
	rebuild_visual()
	return true

## Flood: the crop on a low field is washed out.
func flood_field() -> void:
	if is_field() and field_stage in [Field.SPROUTS, Field.GROWING, Field.RIPE]:
		_lose_crop("The flood washed out a field")

## Rain power: the hand waters this field.
func rain_on(amount: float = 0.35) -> void:
	moisture = minf(moisture + amount, 1.0)

## True while someone is at work here (spinners turn, smoke rises).
func busy() -> bool:
	for p in _valid_workers():
		if p.state == Person.S.WORK and p.is_present_at(self, 1.6):
			return true
	return false

# --- visuals -------------------------------------------------------------------------

func _bar_height() -> float:
	if building != null:
		return 3.6
	return 2.4

func rebuild_visual() -> void:
	if not is_inside_tree():
		return
	if is_field() and not is_in_group(&"field"):
		add_to_group(&"field")     # the hand's Rain gesture looks for fields
	var old := get_node_or_null("Visual")
	if old:
		remove_child(old)
		old.queue_free()
	visual = SiteVisual.make(self)
	visual.name = "Visual"
	add_child(visual)
	_on_amount_changed()

# --- static helpers -------------------------------------------------------------------

static func ground(x: float, z: float) -> float:
	if Game.world != null and is_instance_valid(Game.world) and Game.world.has_method("ground_y"):
		return Game.world.ground_y(x, z)
	return 0.0

static func by_uid(id: int) -> Site:
	if id == 0:
		return null
	for s in Village.sites:
		if is_instance_valid(s) and s.uid == id:
			return s
	return null

## Where gatherers drop goods: nearest node in group "stockpile" (the world's
## cave/stash) or finished food store; the world origin if there is none.
static func store_point(from: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		for n in tree.get_nodes_in_group("stockpile"):
			if n is Node3D and is_instance_valid(n):
				var d: float = bank_dist((n as Node3D).global_position, from)
				if d < bd:
					bd = d; best = (n as Node3D).global_position
	for s in Village.sites:
		if is_instance_valid(s) and s.is_store():
			var d2: float = bank_dist(s.global_position, from)
			if d2 < bd:
				bd = d2; best = s.global_position
	if best == Vector3.INF:
		best = Vector3(0, Site.ground(0, 0), 0)
	return best

## True when `a` and `b` lie on the same side of the river.
static func same_bank(a: Vector3, b: Vector3) -> bool:
	return (a.z > Valley.river_z(a.x)) == (b.z > Valley.river_z(b.x))

## Distance with the river counted as a long way round, so people eat,
## sleep and warm up on their own bank instead of wading across to a camp.
const CROSS_RIVER := 200.0
static func bank_dist(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b) + (0.0 if same_bank(a, b) else CROSS_RIVER)

## Nearest site matching `filter` (Callable(Site) -> bool) within `r`
## (a site across the river counts as CROSS_RIVER further away).
static func nearest(from: Vector3, r: float, filter: Callable) -> Site:
	var best: Site = null
	var bd := r
	for s in Village.sites:
		if not is_instance_valid(s) or s.is_queued_for_deletion():
			continue
		var d: float = bank_dist(s.global_position, from)
		if d <= bd and (not filter.is_valid() or filter.call(s)):
			bd = d; best = s
	return best

## A lit fire or warm building whose radius covers `p`, or null.
static func warmth_at(p: Vector3) -> Site:
	for s in Village.sites:
		if is_instance_valid(s):
			var r: float = s.warmth_radius()
			if r > 0.0 and s.global_position.distance_squared_to(p) <= r * r:
				return s
	return null

static func joy_at(p: Vector3) -> bool:
	for s in Village.sites:
		if is_instance_valid(s):
			var r: float = s.joy_radius()
			if r > 0.0 and s.global_position.distance_squared_to(p) <= r * r:
				return true
	return false

## Nearest lit fire (or warm building) anywhere, for cold people.
static func nearest_warmth(from: Vector3) -> Site:
	return Site.nearest(from, 60.0, func(s): return s.warmth_radius() > 0.0)

## Nearest shrine-like site (hosts prayer), for gifts and memorials.
static func nearest_shrine(from: Vector3) -> Site:
	return Site.nearest(from, 500.0, func(s): return s.job != null and s.job.kind == JobDef.Kind.DEVOTION and not s.is_plot())

# --- save ---------------------------------------------------------------------------

func save_state() -> Dictionary:
	var dl := {}
	for k in delivered: dl[str(k)] = delivered[k]
	var p := global_position if is_inside_tree() else position
	return {
		"scene": scene_file_path if scene_file_path != "" else DEFAULT_SCENE,
		"uid": uid,
		"job": str(job.id) if job else "",
		"building": str(building.id) if building else "",
		"state": state,
		"pos": [p.x, p.y, p.z],
		"rot_y": rotation.y,
		"amount": amount,
		"regrow_t": regrow_t,
		"progress": progress,
		"delivered": dl,
		"build_done": build_done,
		"fuel_t": fuel_t,
		"parent_uid": parent_uid,
		"evergreen": evergreen,
		"children_spawned": children_spawned,
		"origin": [origin.x, origin.y, origin.z] if origin != Vector3.INF else [],
		"raise_parent": raise_parent,
		"field": [field_stage, field_grow, field_work, field_cure, field_quality, moisture, blight_t, dry_land, _field_rest] if is_field() else [],
		"meta": _saved_meta(),
	}

const SAVED_META: Array[StringName] = [&"raise_r", &"layout_tag", &"evergreen"]

func _saved_meta() -> Dictionary:
	var m := {}
	for k in SAVED_META:
		if has_meta(k):
			m[str(k)] = get_meta(k)
	return m

func load_state(d: Dictionary) -> void:
	_loaded = true
	_defs_ready = true
	uid = int(d.get("uid", uid))
	var jid := str(d.get("job", ""))
	job = Defs.job(StringName(jid)) if jid != "" else null
	var bid := str(d.get("building", ""))
	building = Defs.building(StringName(bid)) if bid != "" else null
	state = int(d.get("state", State.JOB))
	var pa: Array = d.get("pos", [0, 0, 0])
	var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	if is_inside_tree():
		global_position = pos
	else:
		position = pos
	rotation.y = float(d.get("rot_y", 0.0))
	amount = int(d.get("amount", -1))
	regrow_t = float(d.get("regrow_t", 0.0))
	progress = float(d.get("progress", 0.0))
	group_running = false
	delivered.clear(); incoming.clear()
	var dl: Dictionary = d.get("delivered", {})
	for k in dl:
		delivered[StringName(k)] = int(dl[k])
	if building:
		for k in building.cost:
			incoming[k] = 0
			if not delivered.has(k):
				delivered[k] = 0
	build_done = float(d.get("build_done", 0.0))
	fuel_t = float(d.get("fuel_t", 0.0))
	parent_uid = int(d.get("parent_uid", 0))
	evergreen = bool(d.get("evergreen", false))
	children_spawned = bool(d.get("children_spawned", false))
	var o: Array = d.get("origin", [])
	origin = Vector3(float(o[0]), float(o[1]), float(o[2])) if o.size() == 3 else pos
	raise_parent = int(d.get("raise_parent", 0))
	var fd: Array = d.get("field", [])
	if fd.size() >= 9:
		field_stage = int(fd[0]); field_grow = float(fd[1]); field_work = float(fd[2]); field_cure = float(fd[3])
		field_quality = float(fd[4]); moisture = float(fd[5]); blight_t = float(fd[6]); dry_land = bool(fd[7]); _field_rest = float(fd[8])
	var md: Dictionary = d.get("meta", {})
	for k in md:
		set_meta(StringName(k), md[k])
	workers.clear(); inside.clear()
	if is_inside_tree():
		rebuild_visual()
