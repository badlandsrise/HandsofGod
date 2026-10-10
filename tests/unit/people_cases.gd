extends RefCounted
## Test cases for tests/unit/test_people.gd (loaded at runtime, after the
## autoloads exist, so this file and the game scripts can use them).

const PERSON_SCENE := "res://scenes/people/person.tscn"
const SITE_SCENE := "res://scenes/sites/site.tscn"

var tree: SceneTree
var root: Window
var V: Node
var D: Node
var F: Node
var E: Node
var fails := 0
var passes := 0
var counts: Dictionary = {}

func run(t: SceneTree) -> int:
	tree = t
	root = t.root
	V = Village; D = Defs; F = Faith; E = Events
	for sig in ["group_job_failed", "job_started", "job_completed", "building_finished", "person_aged", "person_died", "person_born", "person_joined", "dream_done"]:
		counts[sig] = 0
		E.connect(sig, _counter.bind(sig))
	test_data()
	test_stages()
	test_group_job()
	test_wander_off()
	test_eating()
	test_build()
	test_save_load()
	test_dreams_and_ai()
	test_warmth()
	test_idle_reasons()
	return fails

func get_nodes_in_group(g: String) -> Array:
	return tree.get_nodes_in_group(g)

func _counter(_a = null, _b = null, sig: String = "") -> void:
	# Signals have 1-2 args; bind() appends sig last.
	if sig == "" and _b is String:
		sig = _b
	elif sig == "" and _a is String:
		sig = _a
	counts[sig] = int(counts.get(sig, 0)) + 1

func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)

func step(seconds: float, dt: float = 0.1) -> void:
	var n := int(round(seconds / dt))
	for i in n:
		for p in V.people.duplicate():
			if is_instance_valid(p):
				p.sim(dt)
				p.motion(dt)
		for s in V.sites.duplicate():
			if is_instance_valid(s) and not s.is_queued_for_deletion():
				s.sim(dt)

func clear() -> void:
	for p in V.people.duplicate():
		if is_instance_valid(p): p.free()
	for s in V.sites.duplicate():
		if is_instance_valid(s): s.free()
	for g in get_nodes_in_group("gift") + get_nodes_in_group("memorial"):
		g.free()
	V.people.clear(); V.sites.clear(); V.stores.clear()

func person(at: Vector3, opts: Dictionary = {}) -> Person:
	return Person.spawn(root, at, opts)

func site(job_id: StringName, at: Vector3) -> Site:
	var s: Site = load(SITE_SCENE).instantiate()
	s.job = D.job(job_id)
	root.add_child(s)
	s.global_position = at
	return s

func plot(building_id: StringName, at: Vector3) -> Site:
	var s: Site = load(SITE_SCENE).instantiate()
	s.building = D.building(building_id)
	root.add_child(s)
	s.global_position = at
	return s

func place(p: Person, s: Site) -> void:
	p.on_lifted()
	p.held_follow(s.slot_position(s.slot_of(p)) + Vector3(0, 3, 0))
	p.on_placed(s.slot_position(s.workers.size()), s)

# --- tests ------------------------------------------------------------------------

func test_data() -> void:
	check(D.powers.size() == 16, "all 16 powers load (%d)" % D.powers.size())
	var g2: PowerDef = D.power(&"grip_2")
	check(g2 != null and g2.free and g2.grip == 3, "Grip II is free and grips 3")
	var grips: Array = []
	for id in [&"grip_2", &"grip_3", &"grip_4", &"grip_5"]:
		grips.append(D.power(id).grip)
	check(grips == [3, 5, 10, 20], "grip ladder 1, 3, 5, 10, 20")
	var st: Array = []
	for id in [&"strength_1", &"strength_2", &"lift_buildings", &"strength_3"]:
		st.append(D.power(id).strength)
	check(st == [4.0, 10.0, 40.0, 100.0], "strength 4, 10, 40, 100")
	check(D.power(&"reach") == null and D.power(&"strong_arms").opens_region == &"" and D.power(&"strength_1").opens_region == &"", "power regions match section 10 (Era 1 regions open by world blockers)")
	check(D.eras.size() == 4 and D.era(1).day_seconds == 75.0 and D.era(1).night_seconds == 30.0 and D.era(1).season_seconds == 300.0, "4 eras, Era 1 timing")
	var e1: EraDef = D.era(1)
	check(e1.dreams.size() == 3 and D.dream(e1.dreams[-1]).gate, "Era 1: three milestone dreams, the last is the gate")
	var era1_jobs := [&"gather_berries", &"fetch_water", &"collect_sticks", &"fell_tree", &"knap_flint", &"tend_fire", &"carry_log", &"haul_log", &"hunt", &"fish_by_hand", &"great_elk_hunt", &"festival", &"build", &"pray"]
	var missing: Array = era1_jobs.filter(func(j): return D.job(j) == null)
	check(missing.is_empty(), "Era 1 jobs load %s" % str(missing))
	check(D.job(&"haul_log").min_people == 3 and D.job(&"hunt").kind == JobDef.Kind.GATHER and D.job(&"work_lodge").kind == JobDef.Kind.WORKPLACE and D.job(&"carry_log").min_people == 2, "group sizes 2 and 3; the hunt is the lodge crew's")
	check(D.job(&"haul_log").needs_power == &"grip_2" and D.job(&"hunt").needs_power == &"grip_2" and D.job(&"fish_by_hand").needs_power == &"warmth"
		and D.job(&"festival").needs_power == &"blessing" and D.job(&"great_elk_hunt").needs_blessed, "Grip II, Warmth and Blessing open their jobs (doc 6)")
	check(D.job(&"fell_tree").needs_discovery == &"stone_tools" and D.job(&"gather_berries").winter_stops, "felling needs stone tools; winter stops the berries")
	var blds := [&"hut", &"fire_circle", &"food_store", &"cairn", &"shrine", &"stone_circle"]
	check(blds.all(func(b): return D.building(b) != null), "Era 1 buildings load")

func test_stages() -> void:
	clear()
	var p := person(Vector3(2, 0, 2), {"age": 0.0})
	check(p.stage == Person.Stage.BABY and not p.pickable(), "newborn is a baby and not pickable")
	var aged0: int = counts["person_aged"]
	p.age = Person.STAGE_START[Person.Stage.CHILD] - 0.05
	p.sim(0.1)
	check(p.stage == Person.Stage.CHILD, "baby becomes a child at 6 min")
	p.age = Person.STAGE_START[Person.Stage.ADULT] - 0.05
	p.sim(0.1)
	check(p.stage == Person.Stage.ADULT, "child becomes an adult at 15 min")
	p.age = Person.STAGE_START[Person.Stage.ELDER] - 0.05
	p.sim(0.1)
	check(p.stage == Person.Stage.ELDER, "adult becomes an elder at 50 min")
	check(int(counts["person_aged"]) - aged0 == 3, "person_aged emitted per stage")
	p.age = p.death_age - 0.05
	p.sim(0.1)
	check(not p.alive() and int(counts["person_died"]) == 1, "elder dies around 65 min")
	check(get_nodes_in_group("memorial").size() == 1, "a memorial stone carries the name")

func test_group_job() -> void:
	clear()
	var s := site(&"carry_log", Vector3(8, 0, 0))
	var a := person(Vector3(6, 0, 1))
	var b := person(Vector3(6, 0, -1))
	check(s.can_accept(2) and s.group_needs() == 2 and s.max_slots() == 2, "log takes 2, needs 2")
	var started0: int = counts["job_started"]
	place(a, s)
	step(3.0)
	check(a.state == Person.S.WAIT_GROUP and not s.group_running, "one carrier waits; the group has not started")
	check(s.group_needs() == 1 and s.hover_text().contains("1/2"), "hover shows 1/2")
	place(b, s)
	step(2.0)
	check(s.group_running and a.state == Person.S.WORK and b.state == Person.S.WORK, "group starts at min_people")
	check(int(counts["job_started"]) > started0, "job_started emitted")
	check(s.bar != null and s.bar.visible, "progress bar visible while the group works")
	var wood0: int = V.store(&"wood")
	step(30.0)
	check(V.store(&"wood") == wood0 + 2, "log delivered 2 wood (%d)" % V.store(&"wood"))
	check(not is_instance_valid(s) or s.is_queued_for_deletion(), "single-use log is gone")
	check(a.state != Person.S.WORK and a.job_site == null, "carriers are free again")
	# Power-gated group job.
	var h := site(&"haul_log", Vector3(-8, 0, 0))
	check(not h.can_accept(1), "haul log needs Grip II")
	F.grant(&"grip_2")
	check(h.can_accept(3), "haul log accepts 3 with Grip II")

func test_wander_off() -> void:
	clear()
	if not F.has(&"grip_2"):
		F.grant(&"grip_2")
	var s := site(&"haul_log", Vector3(0, 0, 10))
	var a := person(Vector3(0, 0, 8))
	var failed0: int = counts["group_job_failed"]
	place(a, s)
	step(19.0)
	check(a.job_site == s and a.state == Person.S.WAIT_GROUP, "still waiting at 19 s")
	step(2.0)
	check(a.job_site == null and a.state != Person.S.WAIT_GROUP, "wandered off after 20 s")
	check(int(counts["group_job_failed"]) == failed0 + 1, "group_job_failed emitted")
	check(s.workers.is_empty() and not s.group_running, "the log haul is empty again")

func test_eating() -> void:
	clear()
	V.stores[&"berries"] = 5
	V.stores[&"water"] = 3
	var p := person(Vector3(4, 0, 4))
	p.needs[&"food"] = 0.3
	p.needs[&"water"] = 0.2
	p.go_eat()
	check(p.state == Person.S.EAT, "goes to eat")
	step(8.0)
	check(V.store(&"berries") == 4 and V.store(&"water") == 2, "eating takes 1 food and 1 water (%d, %d)" % [V.store(&"berries"), V.store(&"water")])
	check(p.needs[&"food"] > 0.8 and p.needs[&"water"] > 0.8, "needs refilled")
	check(p.state != Person.S.EAT, "done eating")
	# Idle utility: a hungry idle person goes to eat on their own.
	p.needs[&"food"] = 0.1
	p._decide_t = 0.0
	step(8.0)
	check(V.store(&"berries") == 3, "hungry idle person eats by utility")
	# Gathering fills the stores.
	var bush := site(&"gather_berries", Vector3(6, 0, 0))
	place(p, bush)
	step(25.0)
	check(V.store(&"berries") > 3 and bush.amount < 8, "gatherer brings berries to the store")
	check((V.store(&"berries") - 3) % Person.ARMFUL == 0, "berries arrive by the armful (%d)" % (V.store(&"berries") - 3))
	# Placement faith: once per placement, at most once per PLACE_FAITH_GAP per person
	var f0 := Faith.total
	p._place_faith_t = -INF
	p.placed_by_hand = true
	p._placement_faith()
	p.placed_by_hand = true
	p._placement_faith()
	check(is_equal_approx(Faith.total - f0, Person.PLACE_FAITH), "placement faith is not farmed by shuffling (%.2f)" % (Faith.total - f0))
	check(p.status_text() != "", "status_text: " + p.status_text())

func test_build() -> void:
	clear()
	V.stores[&"wood"] = 10
	var s := plot(&"hut", Vector3(6, 0, 0))
	check(s.state == Site.State.PLOT and s.max_slots() == 2, "hut plot takes 2 builders")
	var a := person(Vector3(1, 0, 1))
	var b := person(Vector3(1, 0, -1))
	place(a, s)
	place(b, s)
	var fin0: int = counts["building_finished"]
	var t := 0.0
	while t < 150.0 and s.state != Site.State.FINISHED:
		step(1.0)
		t += 1.0
	check(s.state == Site.State.FINISHED, "hut built in %d s" % int(t))
	check(V.store(&"wood") == 4, "hut used 6 wood from the stores (%d left)" % V.store(&"wood"))
	check(int(counts["building_finished"]) == fin0 + 1 and V.count_buildings(&"hut") == 1, "building_finished, counted")
	check(s.is_shelter() and s.can_accept(1), "a finished hut shelters people")
	check(a.job_site == null and b.job_site == null, "builders go idle")
	# Shelter: placing someone in the hut puts them inside.
	place(a, s)
	step(3.0)
	check(a.state == Person.S.SHELTER and not a.visible and s.inside.has(a), "placed in hut: inside")
	# A fire circle hosts tend_fire and warms people.
	V.stores[&"wood"] = 5; V.stores[&"stone"] = 2
	var f := plot(&"fire_circle", Vector3(-6, 0, 0))
	place(b, f)
	t = 0.0
	while t < 120.0 and f.state != Site.State.FINISHED:
		step(1.0)
		t += 1.0
	check(f.state == Site.State.FINISHED and f.job != null and f.job.id == &"tend_fire" and f.lit(), "fire circle finished, lit, hosts tend_fire")
	check(Site.warmth_at(f.global_position + Vector3(1, 0, 0)) == f, "fire warms nearby")

func test_save_load() -> void:
	clear()
	var p := person(Vector3(3, 0, -2), {"name": "Ona", "sex": "f", "age": 1500.0, "parents": [7, 8], "trust_f": 3.4})
	p.partner = 42
	p.children.append(99)
	p.skills[&"woodcraft"] = 3.5
	p.traits.clear(); p.traits.append(&"devout"); p.traits.append(&"quick")
	p.wish = &"gather_berries"
	p.needs[&"joy"] = 0.33
	var d: Dictionary = JSON.parse_string(JSON.stringify(p.save_state()))
	check(d.get("scene", "") == PERSON_SCENE and int(d.get("uid", 0)) == p.uid, "save has scene and uid")
	var q: Person = load(PERSON_SCENE).instantiate()
	root.add_child(q)
	q.load_state(d)
	var ok := q.uid == p.uid and q.given_name == "Ona" and q.sex == "f" and is_equal_approx(q.age, 1500.0)
	ok = ok and q.parents == p.parents and q.children == p.children and q.partner == 42
	ok = ok and is_equal_approx(q.skills[&"woodcraft"], 3.5) and q.traits == p.traits and q.trust == 3
	ok = ok and q.wish == &"gather_berries" and is_equal_approx(q.needs[&"joy"], 0.33)
	ok = ok and int(q.look["skin"]) == int(p.look["skin"]) and int(q.look["hair"]) == int(p.look["hair"])
	ok = ok and absf(float(q.look["height"]) - float(p.look["height"])) < 0.001 and q.stage == Person.Stage.ADULT
	ok = ok and q.global_position.distance_to(p.global_position) < 0.01
	check(ok, "person save/load round trip keeps fields")
	var d2: Dictionary = JSON.parse_string(JSON.stringify(q.save_state()))
	check(JSON.stringify(d2) == JSON.stringify(d), "second round trip is identical")
	# Sites too.
	V.stores[&"wood"] = 3
	var s := plot(&"hut", Vector3(5, 0, 5))
	s.deliver(&"wood", 2)
	var sd: Dictionary = JSON.parse_string(JSON.stringify(s.save_state()))
	var s2: Site = load(SITE_SCENE).instantiate()
	root.add_child(s2)
	s2.load_state(sd)
	check(s2.uid == s.uid and s2.building == s.building and s2.state == Site.State.PLOT and int(s2.delivered[&"wood"]) == 2, "site save/load round trip")
	# Person links back to their site by uid after a load.
	place(p, s)
	step(1.0)
	var pd: Dictionary = JSON.parse_string(JSON.stringify(p.save_state()))
	var r: Person = load(PERSON_SCENE).instantiate()
	p.free()
	root.add_child(r)
	r.load_state(pd)
	step(0.2)
	check(r.job_site == s or r.job_site == s2, "loaded person rejoins their site by uid")

func test_dreams_and_ai() -> void:
	clear()
	V.era = 1
	V.stats["dreams_done"] = []
	check(Dreams.active_dream() != null and Dreams.active_dream().id == &"shelter_of_our_own", "first dream: a shelter of our own")
	var dn := Dreams.new()
	root.add_child(dn)
	var faith0: float = F.total
	dn.update()
	check(not Dreams.is_done(&"shelter_of_our_own"), "dream not done without a hut")
	var hut: Site = load(SITE_SCENE).instantiate()
	hut.building = D.building(&"hut")
	hut.start_finished = true
	root.add_child(hut)
	dn.update()
	check(not Dreams.is_done(&"shelter_of_our_own"), "a hut alone is not enough: the fire circle too")
	var circle: Site = load(SITE_SCENE).instantiate()
	circle.building = D.building(&"fire_circle")
	circle.start_finished = true
	root.add_child(circle)
	dn.update()
	check(Dreams.is_done(&"shelter_of_our_own") and F.total > faith0 and int(counts["dream_done"]) == 1, "dream done grants faith")
	check(Dreams.active_dream().id == &"shrine_to_the_hand", "next dream is milestone 2, the shrine")
	V.stats["last_dream_t"] = Clock.total_t
	V.stats["dream_active"] = ""
	dn.update()
	check(str(V.stats.get("dream_active", "")) == "", "a quiet stretch before the next dream appears")
	dn.free()
	# Births.
	V.stores[&"berries"] = 30
	V.stats["surplus_days"] = 2
	var a := person(Vector3(1, 0, 0), {"sex": "f"})
	var b := person(Vector3(-1, 0, 0), {"sex": "m"})
	a.partner = b.uid; b.partner = a.uid
	Births.assign_homes()
	check(a.home == hut and b.home == hut, "pair gets the hut as home")
	check(Births.can_have_child(a, b), "pair with home and surplus can have a child")
	var baby := Births.have_child(a, b)
	check(baby.stage == Person.Stage.BABY and baby.parents.has(a.uid) and a.children.has(baby.uid), "baby born with family links")
	step(0.5)
	check(baby.global_position.distance_to(a.global_position) < 1.5, "baby is carried by a parent")
	# Wanderers / safety net.
	var w := Wanderers.new()
	root.add_child(w)
	var pop0: int = V.population()
	w.arrive(2, &"")
	check(V.population() == pop0 + 2 and int(counts["person_joined"]) == 2, "wanderers arrive")
	w.free()
	# Gifts.
	var g := Gifts.spawn_gift(a)
	check(g != null and g.is_in_group("gift") and g.faith_value > 0.0, "gift spawns in group gift with faith_value")

# --- live smoke run (real frames, Clock running) -----------------------------------

var _ai: Node
var _smoke_people: Array = []

## [polish] Each warmth source visibly works (Austin: "people that want warmth
## dont seem to be able to get it from anything, the fire, my hand").
func test_warmth() -> void:
	clear()
	V.stores[&"berries"] = 20
	V.stores[&"water"] = 20
	var season0: int = Clock.season
	Clock.season = Clock.Season.WINTER
	# a lit fire
	var fire := site(&"tend_fire", Vector3(0, 0, 0))
	fire.fuel_t = 300.0
	check(fire.warmth_radius() > 0.0, "the fire is lit and gives warmth")
	var a := person(Vector3(1.5, 0, 0.5))
	a.needs[&"warmth"] = 0.2
	step(2.0)
	check(a.needs[&"warmth"] > 0.25, "by a lit fire a cold person warms up (%.2f)" % a.needs[&"warmth"])
	check(a.visual != null and a.visual._glow_want > 0.0, "and glows while warming")
	step(20.0)
	check(a.needs[&"warmth"] > 0.9 and a.visual._glow_want == 0.0, "warm again, the glow fades (%.2f)" % a.needs[&"warmth"])
	# the hand's Warmth
	var b := person(Vector3(40, 0, 0))
	b.needs[&"warmth"] = 0.1
	check(PersonInfo.idle_reason(b).begins_with("cold"), "a chilled person says they are cold")
	check(HandPowers.warm_at(b.global_position + Vector3(1.5, 0, 0)) == 1, "the hand's Warmth over the ground near them reaches them")
	check(b.needs[&"warmth"] >= 0.5 and not b.status_text().contains("cold") and not PersonInfo.idle_reason(b).begins_with("cold"), "one touch clears \"cold\" (%.2f)" % b.needs[&"warmth"])
	check(b.visual._glow_want >= 1.0, "and they glow warm")
	step(3.0)
	check(b.needs[&"warmth"] > 0.6, "and keep warming while the touch lasts (%.2f)" % b.needs[&"warmth"])
	# a hut: a cold idle person goes in and warms up inside
	var hut := plot(&"hut", Vector3(-40, 0, 6))
	hut._finish(true)
	var c := person(Vector3(-40, 0, 0))
	c.needs[&"warmth"] = 0.15
	c._decide_t = 0.0
	var inside := false
	for i in 30:
		step(1.0)
		if c.state == Person.S.SHELTER and c._phase == "inside":
			inside = true
	check(inside, "a cold idle person with no fire near goes into a hut")
	check(c.needs[&"warmth"] > 0.6, "and is warmed inside it (%.2f)" % c.needs[&"warmth"])
	Clock.season = season0

## [polish] People don't drop work they could keep doing, and say why when they do.
func test_idle_reasons() -> void:
	clear()
	V.stores[&"berries"] = 20
	V.stores[&"water"] = 20
	var a := site(&"gather_berries", Vector3(10, 0, 0))
	var b := site(&"gather_berries", Vector3(14, 0, 3))
	var p := person(Vector3(9, 0, 1))
	var others: Array = []
	while a.can_accept(1):
		var o := person(Vector3(11, 0, 1))
		o.join(a, false)
		others.append(o)
	p._rejoin(a)
	check(p.job_site == b and p.state == Person.S.WORK, "back from a meal to a full bush: they take the next bush instead of going idle")
	p.go_idle()
	for o in others:
		o.go_idle()
	b.free()
	var full: Array = []
	while a.can_accept(1):
		var o2 := person(Vector3(11, 0, 2))
		o2.join(a, false)
		full.append(o2)
	p._rejoin(a)
	check(p.state == Person.S.IDLE and PersonInfo.idle_reason(p).contains("taken"), "with nowhere to go they say why: " + PersonInfo.idle_reason(p))
	p.join(a if a.can_accept(1) else site(&"gather_berries", Vector3(-10, 0, 0)), false)
	check(p.idle_why == "", "a new job clears the reason")
	# a lone hauler gives up waiting for help, and says so
	var log := site(&"haul_log", Vector3(-20, 0, 0))
	var q := person(Vector3(-19, 0, 1))
	Faith.grant(&"grip_2")
	check(q.join(log, false), "one person waits at the log")
	step(log.job.wait_before_wander + 2.0)
	check(q.job_site == null and PersonInfo.idle_reason(q).contains("helpers"), "alone too long they give up and say why: " + PersonInfo.idle_reason(q))

func smoke_setup() -> void:
	clear()
	V.stores[&"berries"] = 20; V.stores[&"water"] = 10; V.stores[&"wood"] = 10
	_ai = VillageAI.new()
	root.add_child(_ai)
	var fire := site(&"tend_fire", Vector3(-3, 0, 0))
	fire.add_fuel(60.0)
	var hut: Site = load(SITE_SCENE).instantiate()
	hut.building = D.building(&"hut"); hut.start_finished = true
	root.add_child(hut)
	hut.global_position = Vector3(0, 0, 6)
	var bush := site(&"gather_berries", Vector3(5, 0, 0))
	for i in 4:
		_smoke_people.append(person(Vector3(i, 0, -2)))
	place(_smoke_people[0], bush)
	place(_smoke_people[1], fire)
	Clock.running = true
	Engine.time_scale = 3.0

func smoke_night() -> void:
	Clock.is_night = true
	Events.night_started.emit(Clock.day)

func smoke_day() -> void:
	Clock.is_night = false
	Events.day_started.emit(Clock.day + 1)

func smoke_finish() -> int:
	Clock.running = false
	Engine.time_scale = 1.0
	var ok := true
	for p in _smoke_people:
		if not is_instance_valid(p) or not p.alive():
			ok = false
			continue
		var pos: Vector3 = p.global_position
		if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
			ok = false
	check(ok, "live run: everyone alive with valid transforms")
	check(Village.alive().any(func(p): return p.status_text() != ""), "live run: status texts")
	print("RESULT: %d passed, %d failed" % [passes, fails])
	return fails
