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
		return building.build_slots
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
	if _winter_stopped():
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
	Events.job_completed.emit(self)

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
	for k in building.cost:
		if int(delivered.get(k, 0)) + int(incoming.get(k, 0)) < int(building.cost[k]):
			return k
	return &""

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
	rebuild_visual()

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
	if state != State.BUILDING:
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

# --- visuals -------------------------------------------------------------------------

func _bar_height() -> float:
	if building != null:
		return 3.6
	return 2.4

func rebuild_visual() -> void:
	if not is_inside_tree():
		return
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
				var d: float = (n as Node3D).global_position.distance_squared_to(from)
				if d < bd:
					bd = d; best = (n as Node3D).global_position
	for s in Village.sites:
		if is_instance_valid(s) and s.is_finished_building(&"food_store"):
			var d2: float = s.global_position.distance_squared_to(from)
			if d2 < bd:
				bd = d2; best = s.global_position
	if best == Vector3.INF:
		best = Vector3(0, Site.ground(0, 0), 0)
	return best

## Nearest site matching `filter` (Callable(Site) -> bool) within `r`.
static func nearest(from: Vector3, r: float, filter: Callable) -> Site:
	var best: Site = null
	var bd := r * r
	for s in Village.sites:
		if not is_instance_valid(s) or s.is_queued_for_deletion():
			continue
		var d: float = s.global_position.distance_squared_to(from)
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
	}

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
	workers.clear(); inside.clear()
	if is_inside_tree():
		rebuild_visual()
