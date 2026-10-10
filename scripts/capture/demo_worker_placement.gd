extends RefCounted
## [capture] Demo "worker_placement": the hand plays like a skilled player,
## through the real Hand API on the real people and jobs. It glides to a
## villager and lifts them (Hand.try_lift), sweeps a scoop over the people
## standing near (Hand.scoop_lift, or one more try_lift each when nobody is
## close enough), carries them over the valley and sets them down on a job
## (Hand.place_on_site); then the camera stays while they start work.
##
## Every motion is eased and timed on the capture clock (no wall-clock time),
## so a run is the same frame for frame under Movie Maker's --fixed-fps.
## The length is fixed (default 30 s); the beats scale down for short runs.

const BEATS := {        # nominal seconds; scaled when the demo is short
	"settle": 1.6, "reach": 2.4, "lift": 0.7, "sweep": 1.9, "pick": 1.5, "carry": 4.6, "hover": 0.8,
}

var director: Node
var world: Node
var hand: Node
var length: float = 30.0
var t: float = 0.0
var done: bool = false
var events: Array = []              # [t, name, detail] for tests and the log

var group: Array = []               # the people to lift, the first one by hand
var site: Site = null
var anchor: Person = null
var _plan: Array = []               # [beat, seconds]
var _beat: String = ""
var _bt: float = 0.0
var _blen: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _aim: Vector3 = Vector3.ZERO
var _rest: Vector3 = Vector3.ZERO
var _scoop_c: Vector3 = Vector3.ZERO
var _sweep_r: float = 0.0
var _scoop_need: float = 1.0
var _yaw: float = 0.0
var _cam_focus: Vector3 = Vector3.INF
var _cam_dist: float = 30.0
var _k: float = 1.0
var _placed: int = 0
var lifted: int = 0
var placed_list: Array = []         # who place_on_site set down on the job

func _init(d: Node, len_s: float) -> void:
	director = d
	world = d.world
	hand = world.get(&"hand")
	length = maxf(len_s, 4.0)

func log_event(n: String, detail: String = "") -> void:
	events.append([t, n, detail])
	print("capture demo worker_placement %5.2f s: %s %s" % [t, n, detail])

func has_event(n: String) -> bool:
	return events.any(func(e): return e[1] == n)

# ---------------------------------------------------------------- choosing

func begin() -> bool:
	if hand == null or not is_instance_valid(hand) or not hand.has_method(&"try_lift"):
		log_event("no_hand")
		done = true
		return false
	hand.release_all()
	hand.input_enabled = false
	var want := clampi(hand.grip(), 2, 4)
	if not _choose(want):
		log_event("no_cast", "nobody to lift or no job to fill")
		done = true
		_end()
		return false
	# the carry crosses the screen from side to side: the camera looks along
	# the perpendicular, from the southern side like the player's camera
	var d := site.global_position - anchor.global_position
	d.y = 0.0
	var perp := Vector3(-d.z, 0.0, d.x).normalized()
	if perp.z < 0.0:
		perp = -perp
	_yaw = atan2(perp.x, perp.z)
	_rest = _ground(anchor.global_position - d.normalized() * 7.0 + perp * 3.0)
	_aim = _rest
	hand.aim_override = _aim
	_plan = [["settle", BEATS.settle], ["reach", BEATS.reach], ["lift", BEATS.lift]]
	var others := group.size() - 1
	if others > 0 and _scoopable() >= others:
		_plan.append(["sweep", BEATS.sweep])
	else:
		for i in others:
			_plan.append(["pick", BEATS.pick])
	_plan.append_array([["carry", BEATS.carry], ["hover", BEATS.hover], ["place", 0.0], ["watch", 0.0]])
	var action := 0.0
	for b in _plan:
		action += float(b[1])
	# the beats fill at most 60 % of the run, the rest is watching them work
	_k = minf(1.0, length * 0.6 / action)
	_cam_dist = 28.0
	log_event("begin", "lift %d onto %s (%d free), %d m away" % [group.size(), site.title(), site.free_slots(), int(d.length())])
	_next()
	return true

func _score_person(p: Person) -> float:
	var s := 0.0
	match p.state:
		Person.S.IDLE: s += 3.0
		Person.S.WALK: s += 1.5
		Person.S.WORK: s += 0.5
		Person.S.WAIT_GROUP: s -= 2.0
		Person.S.SLEEP, Person.S.SHELTER, Person.S.EAT: s -= 3.0
	if p.job_site != null and is_instance_valid(p.job_site) and p.job_site.is_group():
		s -= 2.0
	return s

func _candidates() -> Array:
	var out: Array = []
	for p in Village.alive():
		if p is Person and p.pickable() and p.stage != Person.Stage.BABY and p.weight() <= Faith.strength:
			if _score_person(p) > -2.5:
				out.append(p)
	out.sort_custom(func(a, b): return a.uid < b.uid)
	return out

func _choose(want: int) -> bool:
	var cands := _candidates()
	if cands.size() < 2:
		return false
	var r := minf(hand.scoop_max_radius(), 6.5)
	var center := _village_center()
	var best_a: Person = null
	var best_s := -INF
	for a in cands:
		var near := 0
		for b in cands:
			if b != a and _flat(a.global_position, b.global_position) <= r:
				near += 1
		var s := float(mini(near, want - 1)) * 10.0 + _score_person(a) - _flat(a.global_position, center) * 0.05
		if s > best_s:
			best_s = s
			best_a = a
	anchor = best_a
	# the job: a real site that takes them all, a good stretch of valley away
	var best_site: Site = null
	var best_v := -INF
	for s in Village.sites:
		if not (s is Site) or not is_instance_valid(s) or s.is_queued_for_deletion() or s.hand_ignores():
			continue
		if s.job == null or s.is_plot() or s.is_shelter() or s.is_store():
			continue
		var n := mini(want, s.free_slots())
		if n < 2 or not s.can_accept(n) or not s.can_work_now():
			continue
		var dist := _flat(s.global_position, anchor.global_position)
		var v := float(n) * 7.0
		match s.job.kind:
			JobDef.Kind.DEVOTION, JobDef.Kind.LEAD: v -= 9.0     # praying reads as standing still
			JobDef.Kind.GATHER, JobDef.Kind.CRAFT, JobDef.Kind.TEND: v += 2.0
		if s.job.id in [&"fetch_water", &"draw_water", &"tend_fire"]:
			v -= 4.0
		if s.is_group():
			v += 6.0 if s.group_needs() <= n else 1.0
		v -= absf(dist - 34.0) * 0.12
		if dist < 12.0 or dist > 90.0:
			v -= 20.0
		v -= _flat(s.global_position, center) * 0.02
		if v > best_v:
			best_v = v
			best_site = s
	if best_site == null:
		return false
	site = best_site
	var n_take := mini(want, site.free_slots())
	group = [anchor]
	var rest := cands.filter(func(p): return p != anchor)
	rest.sort_custom(func(a, b): return _flat(a.global_position, anchor.global_position) < _flat(b.global_position, anchor.global_position))
	for p in rest:
		if group.size() >= n_take:
			break
		group.append(p)
	return group.size() >= 2

func _village_center() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for p in Village.alive():
		if p is Node3D and _flat(p.global_position, world.fire_position()) < 70.0:
			sum += p.global_position
			n += 1
	return sum / float(n) if n > 0 else world.fire_position()

## The chosen people not in the hand yet (alive and pickable).
func _not_held() -> Array:
	return group.filter(func(p): return is_instance_valid(p) and not hand.held.has(p) and p.pickable())

static func _centroid(ps: Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ps:
		c += p.global_position
	return c / float(maxi(ps.size(), 1))

## How many of the rest stand within a scoop of the first one, now.
func _scoopable() -> int:
	if not hand.can_scoop():
		return 0
	var r := minf(hand.scoop_max_radius(), 6.5)
	var n := 0
	for i in range(1, group.size()):
		if is_instance_valid(group[i]) and _flat(group[i].global_position, anchor.global_position) <= r:
			n += 1
	return n

# ---------------------------------------------------------------- the beats

func _next() -> void:
	if _plan.is_empty():
		return
	var b: Array = _plan.pop_front()
	_beat = b[0]
	_blen = float(b[1]) * _k
	_bt = 0.0
	_from = _aim
	match _beat:
		"sweep":
			var rest := _not_held()
			_scoop_c = _ground(_centroid(rest) if not rest.is_empty() else _aim)
			_scoop_need = 1.0
			for p in rest:
				_scoop_need = maxf(_scoop_need, _flat(p.global_position, _scoop_c) + 0.9)
			if _scoop_need > hand.scoop_max_radius():
				# they have wandered apart: pick each one up by hand instead
				for i in rest.size():
					_plan.push_front(["pick", BEATS.pick])
				_next()
				return
			_sweep_r = 0.0
			hand.scooping = true
			hand.scoop_center = _scoop_c
			hand.scoop_radius = 0.0
		"place":
			_place()
			_next()
		"watch":
			_from = _aim

func step(dt: float) -> void:
	if done:
		return
	t += dt
	_bt += dt
	var u := clampf(_bt / maxf(_blen, 0.001), 0.0, 1.0)
	var e := _ease(u)
	match _beat:
		"settle":
			_aim = _rest + Vector3(sin(t * 1.3) * 0.25, 0, cos(t * 1.1) * 0.25)
		"reach":
			_aim = _arc(_from, _target_of(anchor), e, 1.2)
		"lift":
			_aim = _target_of(anchor) if anchor != null and not hand.held.has(anchor) else _aim
			if _bt >= _blen * 0.25 and not hand.held.has(anchor) and is_instance_valid(anchor):
				if hand.try_lift(anchor):
					lifted += 1
					log_event("lift", anchor.given_name)
				else:
					log_event("lift_refused", anchor.given_name)
		"sweep":
			# a quick drag out from the middle of them and round, like a player's scoop
			var ang := lerpf(-0.6, 2.4, e)
			_sweep_r = _scoop_need * Valley.ss(0.0, 0.55, u)
			_aim = _ground(_scoop_c + Vector3(cos(ang + _yaw), 0, sin(ang + _yaw)) * _sweep_r)
			hand.scoop_radius = minf(_flat(_aim, _scoop_c), hand.scoop_max_radius())
			hand.scoop_center = _scoop_c
		"pick":
			var rest := _not_held()
			if not rest.is_empty():
				var p: Person = rest[0]
				_aim = _arc(_from, _target_of(p), e, 0.6)
				if u >= 1.0 and hand.try_lift(p):
					lifted += 1
					log_event("pick", p.given_name)
		"carry":
			_aim = _arc(_from, _site_point(), e, 4.0)
		"hover":
			_aim = _site_point() + Vector3(sin(_bt * 3.0) * 0.15, 0, 0)
		"watch":
			# the hand eases up and away, out of the workers' light
			var away := Vector3(sin(_yaw), 0, cos(_yaw)) * 9.0 + Vector3(cos(_yaw), 0, -sin(_yaw)) * 6.0
			_aim = _arc(_from, _ground(_from + away), Valley.ss(0.0, 1.0, minf(_bt / 4.0, 1.0)), 1.0)
	hand.aim_override = _ground(_aim)
	if _beat != "watch" and _bt >= _blen:
		_end_beat()
		_next()
	_camera(dt)
	if t >= length:
		_end()

func _end_beat() -> void:
	match _beat:
		"sweep":
			hand.scooping = false
			var got: int = hand.scoop_lift(_scoop_c, maxf(_sweep_r, 1.0))
			lifted += got
			log_event("scoop", "%d more" % got)
			hand.scoop_radius = 0.0
			# whoever walked out of reach is picked up by hand
			for p in _not_held():
				_plan.push_front(["pick", BEATS.pick])

func _place() -> void:
	if not is_instance_valid(site) or hand.held.is_empty():
		log_event("place_skipped")
		return
	var before: Array = hand.held.duplicate()
	var n: int = hand.place_on_site(site)
	_placed = n
	placed_list = before.slice(0, n)
	log_event("place", "%d on %s" % [n, site.title()])
	if not hand.held.is_empty():
		hand.place_on_ground(hand.idle_ground(_site_point()))
		log_event("place_rest")

## The demo is over (or stopped): the hand is the player's again.
func _end() -> void:
	if hand != null and is_instance_valid(hand):
		if hand.scooping:
			hand.scooping = false
		hand.release_all()
		hand.aim_override = Vector3.INF
		hand.input_enabled = true
	if not done:
		log_event("end", "%d lifted, %d placed" % [lifted, _placed])
	done = true

func stop() -> void:
	_end()

## [tests] the people the hand set on the job who are still with it.
func placed_people() -> Array:
	if site == null or not is_instance_valid(site):
		return []
	return placed_list.filter(func(p): return is_instance_valid(p) and p.job_site == site)

# ---------------------------------------------------------------- motion

func _camera(dt: float) -> void:
	var target: Vector3
	match _beat:
		"settle", "reach", "lift", "sweep", "pick":
			target = anchor.global_position.lerp(site.global_position, 0.18) if is_instance_valid(anchor) else _aim
		"carry", "hover":
			target = _aim.lerp(site.global_position, 0.35)
		_:
			target = site.global_position.lerp(_aim, 0.15) if is_instance_valid(site) else _aim
	var want_dist := 34.0 if _beat in ["carry", "hover"] else (26.0 if _beat == "watch" else 28.0)
	if not _cam_focus.is_finite():
		_cam_focus = target
	var k := 1.0 - exp(-2.2 * dt)
	_cam_focus = _cam_focus.lerp(target, k)
	_cam_dist = lerpf(_cam_dist, want_dist, 1.0 - exp(-0.9 * dt))
	director.cam.drive({"focus": [_cam_focus.x, _cam_focus.z], "dist": _cam_dist, "yaw_deg": rad_to_deg(_yaw),
		"pitch_deg": 44.0, "fov": 45.0, "tilt_shift": true})

func _target_of(p) -> Vector3:
	return _ground(p.global_position) if p != null and is_instance_valid(p) else _aim

func _site_point() -> Vector3:
	return _ground(site.global_position) if is_instance_valid(site) else _aim

## From a to b, bowed sideways by `bow` metres (a hand never moves on a ruler).
func _arc(a: Vector3, b: Vector3, u: float, bow: float) -> Vector3:
	var d := b - a
	d.y = 0.0
	var side := Vector3(-d.z, 0, d.x).normalized() if d.length() > 0.01 else Vector3.ZERO
	return _ground(a.lerp(b, u) + side * sin(PI * u) * bow)

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, world.ground_y(p.x, p.z), p.z)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
