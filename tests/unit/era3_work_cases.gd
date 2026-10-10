extends Node
## [era3] Cases for tests/unit/test_era3_work.gd. Starts from
## tests/bot/era3_start.json, the bot's save of the moment Era 3 began.

signal done(fails: int)

var fails := 0
var w: Node3D

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func run() -> void:
	Save.enabled = false
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await get_tree().process_frame
	Game.flags["test"] = true
	Game.flags["no-threats"] = true
	w.new_game()
	w.storm.skip()
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://tests/bot/era3_start.json"))
	Save.apply(Save.migrate(d))
	await get_tree().process_frame
	await get_tree().process_frame
	Clock.running = false
	Clock.is_night = false
	Clock.phase_t = 5.0
	if w.threats != null:
		w.threats.enabled = false
	_e3().setup()
	_feed()
	await _suggestions()
	await _mason()
	await _forge()
	await _mill()
	await _master()
	await _paving()
	await _migrate()
	_calm()
	w.queue_free()
	await get_tree().process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)

# ---------------------------------------------------------------- helpers

func _e3() -> VillageEra3:
	return w.village_ai.era3

func _sites(bid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.building != null and s.building.id == bid)

func _jobs(jid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.job != null and s.job.id == jid and not s.is_plot())

func _feed() -> void:
	for k in [&"bread", &"water", &"fish"]:
		Village.stores[k] = 120

## Runs only the people given (and every site) by hand: the clock is stopped.
func step(people: Array, seconds: float, dt: float = 0.2) -> void:
	for i in int(round(seconds / dt)):
		Clock.total_t += dt
		for p in people:
			if is_instance_valid(p):
				for k in [&"food", &"water", &"warmth"]:
					p.needs[k] = 1.0
				p.sim(dt)
				p.motion(dt)
		for s in Village.sites.duplicate():
			if is_instance_valid(s) and not s.is_queued_for_deletion():
				s.sim(dt)

func _finish(s: Site) -> void:
	for k in s.building.cost:
		s.delivered[k] = int(s.building.cost[k])
	s.state = Site.State.BUILDING
	s.add_build_work(9999.0)

func _adult(at: Vector3, i: int) -> Person:
	var p: Person = w.spawn_person(at, "", {"age": Person.STAGE_START[Person.Stage.ADULT] + 30.0 + i, "sex": "f" if i % 2 == 0 else "m"})
	return p

## The hand sets `p` down at `s`.
func _place(p: Person, s: Site) -> void:
	p.on_lifted()
	p.on_placed(s.slot_position(s.slots_filled()), s)
	p._land()

func _carter(s: Site) -> Site:
	for c in Village.sites:
		if is_instance_valid(c) and c.parent_uid == s.uid and c.job != null and c.job.id == &"cart_haul":
			return c
	return null

# ---------------------------------------------------------------- suggestions

func _suggestions() -> void:
	var e3 := _e3()
	Village.stats["era_started_t"] = Clock.total_t - 2000.0     # everything is due
	var before := Village.sites.filter(func(s): return is_instance_valid(s) and s.has_meta(&"suggested")).size()
	e3.check_now()
	var after := Village.sites.filter(func(s): return is_instance_valid(s) and s.has_meta(&"suggested")).size()
	check(_sites(&"mason").size() == 1, "the mason's yard is suggested first")
	check(after - before == 1, "one suggested plot at a time (%d new)" % (after - before))
	e3.check_now()
	after = Village.sites.filter(func(s): return is_instance_valid(s) and s.has_meta(&"suggested")).size()
	check(after - before == 1, "the next waits its turn")
	var m: Site = _sites(&"mason")[0]
	check(w.region_at(m.global_position) == &"hill_quarry", "the mason's yard is marked on the quarry floor")
	Village.stats["era_started_t"] = Clock.total_t

# ---------------------------------------------------------------- the mason's yard

func _mason() -> void:
	var m: Site = _sites(&"mason")[0]
	_finish(m)
	check(m.is_workplace() and m.job.id == &"work_mason", "the mason's yard is a workplace")
	check(_carter(m) != null, "with a carter's cart beside it")
	var ledges := Workplace.tasks(m).filter(func(t): return t.job != null and t.job.id == &"quarry_stone")
	check(ledges.size() == 3, "its crew works the three quarry ledges (%d)" % ledges.size())
	check(not ledges.is_empty() and not ledges[0].can_accept(1), "a ledge is the yard's: the hand sets people on the yard")
	check(m.max_slots() >= 2 and m.max_slots() <= m.building.crew_max, "the crew grows with the grip (%d)" % m.max_slots())
	var p := _adult(m.global_position + Vector3(2, 0, 3), 0)
	_place(p, m)
	check(p.job_site == m, "a mason is set down at the yard")
	var b0 := Village.store(&"blocks") + Workplace.bin_total(m)
	Village.stores[&"stone"] = 0         # nothing spare for the bench: the ledges it is
	for i in 40:
		step([p], 5.0)
		if Village.store(&"blocks") + Workplace.bin_total(m) > b0:
			break
	check(Village.store(&"blocks") + Workplace.bin_total(m) > b0, "the mason quarries blocks from a ledge and brings them to the yard")
	# the bench: spare stone is dressed into blocks
	Workplace._wanted_t = -INF
	Village.stores[&"stone"] = 60
	check(Workplace.bench_need(m) > 0.0, "spare stone in the stores: the yard's bench can work")
	var s0 := Village.store(&"stone")
	p._cargo.clear()
	Workplace._drop(p, m)
	for i in 30:
		step([p], 3.0)
		if Village.store(&"stone") < s0:
			break
	check(Village.store(&"stone") < s0, "the mason dresses spare stone at the bench")
	Village.stores[&"stone"] = Workplace.plots_want(&"stone") + 3
	Workplace._wanted_t = -INF
	check(Workplace.bench_need(m) == 0.0, "the bench never takes the stone the plots wait on")
	check(Workplace.hover(m).contains("crew"), "the yard's tooltip shows its crew: \"%s\"" % Workplace.hover(m))
	p.go_idle()

# ---------------------------------------------------------------- the forge

func _forge() -> void:
	var f: Site = w.spawn_plot(&"forge", Vector3(LayoutEra3.PLOT_SPOTS[&"forge"][0].x, 0, LayoutEra3.PLOT_SPOTS[&"forge"][0].y))
	_finish(f)
	check(f.is_workplace() and f.job.id == &"work_forge", "the forge is a workplace")
	var seams := Workplace.tasks(f).filter(func(t): return t.job != null and t.job.id == &"mine_iron")
	check(seams.size() == 3, "its crew works the iron seams up the slope (%d)" % seams.size())
	check(not _jobs(&"cast_brass").is_empty(), "with the brass bench beside it")
	var p := _adult(f.global_position + Vector3(2, 0, 3), 1)
	_place(p, f)
	Village.stores[&"charcoal"] = 0
	var o0 := Village.store(&"iron_ore") + int(f.bin.get(&"iron_ore", 0))
	for i in 50:
		step([p], 5.0)
		if Village.store(&"iron_ore") + int(f.bin.get(&"iron_ore", 0)) > o0:
			break
	check(Village.store(&"iron_ore") + int(f.bin.get(&"iron_ore", 0)) > o0, "the smith mines iron ore and brings it to the forge")
	check(Workplace.idle_reason(f) == &"charcoal", "no charcoal: the forge says so (%s)" % Workplace.idle_reason(f))
	f.bin[&"iron_ore"] = 4
	Village.stores[&"charcoal"] = 4
	var i0 := Village.store(&"iron") + int(f.bin.get(&"iron", 0))
	p._cargo.clear()
	Workplace._drop(p, f)
	for i in 30:
		step([p], 3.0)
		if Village.store(&"iron") + int(f.bin.get(&"iron", 0)) > i0:
			break
	check(Village.store(&"iron") + int(f.bin.get(&"iron", 0)) > i0, "with charcoal the smith forges the ore from the bin into iron")
	check(Village.store(&"charcoal") < 4, "the charcoal comes from the stores")
	# the carter takes the bin to the stores
	var c := _carter(f)
	var q := _adult(c.global_position + Vector3(1, 0, 1), 2)
	_place(q, c)
	f.bin[&"iron"] = 6
	var in_stores := Village.store(&"iron")
	for i in 60:
		step([q], 4.0)
		if Village.store(&"iron") > in_stores:
			break
	check(Village.store(&"iron") > in_stores, "the forge's carter hauls the iron to the stores")
	p.go_idle()
	q.go_idle()

# ---------------------------------------------------------------- the mills

func _mill() -> void:
	var at: Vector2 = LayoutEra3.PLOT_SPOTS[&"watermill"][0]
	var m: Site = w.spawn_plot(&"watermill", Vector3(at.x, 0, at.y))
	_finish(m)
	check(m.is_workplace() and m.job.id == &"work_mill", "the watermill is a workplace")
	var farms := Workplace.tasks(m).filter(func(t): return t.is_workplace() and t.building.id == &"farmhouse")
	check(not farms.is_empty(), "the farmhouses round it are its millers' (%d)" % farms.size())
	if farms.is_empty():
		return
	var fh: Site = farms[0]
	check(fh.can_accept(1) or fh.slots_filled() >= fh.max_slots(), "the hand can still staff the farmhouse itself")
	Village.stores[&"grain"] = 0
	Village.stores[&"flour"] = 0
	fh.bin[&"grain"] = 12
	var p := _adult(m.global_position + Vector3(2, 0, 3), 3)
	_place(p, m)
	var fl0 := Village.store(&"flour") + int(m.bin.get(&"flour", 0))
	for i in 60:
		step([p], 4.0)
		if Village.store(&"flour") + int(m.bin.get(&"flour", 0)) > fl0:
			break
	check(int(Village.stats.get("mill_fetches", 0)) > 0, "a miller fetches grain from the farmhouse bin (%d left, %s)" % [int(fh.bin.get(&"grain", 0)), str(p._waiting_for)])
	check(Village.store(&"flour") + int(m.bin.get(&"flour", 0)) > fl0, "and grinds it into flour at the mill")
	p.go_idle()

# ---------------------------------------------------------------- a master's call

func _master() -> void:
	var m: Site = _sites(&"mason")[0]
	for q in m.workers.duplicate():
		if is_instance_valid(q):
			q.go_idle()
	var master := _adult(m.global_position + Vector3(1, 0, 2), 4)
	master.skills[Person._family(m.job.skill)] = 3.6
	_place(master, m)
	check(master.placed_by_hand and VillageEra3._has_master(m), "the hand sets a master mason at the yard")
	Village.stores[&"stone"] = 0
	var helper := _adult(w._v3(Vector2(120.0, -20.0)), 5)    # in the town, far from the quarry
	helper.go_idle()
	VillageEra3._shops_t = -INF
	check(VillageEra3.autonomy(helper) and helper.job_site == m, "an idle adult across the town answers the master's call")
	var far := _adult(w._v3(Vector2(-120.0, 60.0)), 6)
	far.go_idle()
	VillageEra3._shops_t = -INF
	check(not VillageEra3.autonomy(far) or far.job_site != m, "but not from the far end of the valley")
	for q in [master, helper, far]:
		q.go_idle()

# ---------------------------------------------------------------- paving

func _paving() -> void:
	var paths = w.paths
	var m: Site = _sites(&"mason")[0]
	# a busy road through the town
	paths.stamp_line([Vector2(70.0, 0.0), Vector2(150.0, 0.0)], 60.0, 1.2)
	var segs: Array = paths.busiest_segments(3)
	check(not segs.is_empty() and float(segs[0]["wear"]) >= Paving.MIN_WEAR, "the street through the town is a busy road (%s)" % (str(segs[0]["wear"]) if not segs.is_empty() else "none"))
	check(Paving.plan(true) == null, "nothing is staked while nobody works the yard")
	var p := _adult(m.global_position + Vector3(2, 0, 3), 7)
	_place(p, m)
	Village.stores[&"blocks"] = Workplace.plots_want(&"blocks") + Paving.BLOCK_RESERVE + 6
	Workplace._wanted_t = -INF
	var site: Site = Paving.plan(true)
	check(site != null and site.job.id == Paving.JOB, "with blocks spare the masons stake the busiest stretch for paving")
	if site == null:
		return
	check(not site.can_accept(1) and site.covering_workplace() == m, "the stretch is the yard's to pave, wherever it is")
	check(Paving.plan(true) == null, "one stretch at a time")
	var paved0: int = paths.paved_count()
	var blocks0 := Village.store(&"blocks")
	Village.stores[&"stone"] = 0
	Workplace._drop(p, m)
	for i in 80:
		step([p], 4.0)
		if paths.paved_count() > paved0:
			break
	check(paths.paved_count() > paved0, "a mason walks to the road and lays it in stone (%d cells)" % (paths.paved_count() - paved0))
	check(Village.store(&"blocks") <= blocks0 - Paving.PAVE_BLOCKS + 1, "paving takes dressed blocks from the stores")
	check(not is_instance_valid(site) or site.is_queued_for_deletion(), "the stakes are cleared when it is done")
	check(paths.level_at(segs[0]["center"].x, segs[0]["center"].z) == 4, "the stretch reads as paving")
	check(paths.speed_mult(segs[0]["center"]) > 1.25, "and people walk faster on it")
	check(int(Village.stats.get("roads_paved", 0)) == 1, "the town counts its paved roads")
	p.go_idle()

# ---------------------------------------------------------------- old saves

func _migrate() -> void:
	var at: Vector2 = LayoutEra3.PLOT_SPOTS[&"windmill"][0]
	var m: Site = w.spawn_plot(&"windmill", Vector3(at.x, 0, at.y))
	_finish(m)
	var c := _carter(m)
	if c != null:
		c.queue_free()
	await get_tree().process_frame
	m.job = Defs.job(&"mill_grain")        # as an old save had it
	_e3()._migrated = false
	_e3()._migrate_workplaces()
	check(m.job.id == &"work_mill" and _carter(m) != null, "an old save's mill becomes a workplace with its carter")

# ---------------------------------------------------------------- calmer threats

func _calm() -> void:
	var t: Era3Threats = w.threats.era3
	var picks := {}
	for i in 12:
		var f := t._fire_target()
		if f != null:
			picks[f.building.id] = true
	var only_fire_work := picks.keys().all(func(k): return Era3Threats.FIRE_WORK.has(k))
	check(not picks.is_empty() and only_fire_work, "a town fire starts where fire is worked (%s)" % str(picks.keys()))
	var pop := Village.population()
	check(pop >= Era3Threats.SICK_POP or not t.can(&"sickness"), "sickness waits for a crowded town (%d people)" % pop)
	Village.stats["threat_storms"] = Era3Threats.MAX_EACH
	if not Era3Threats.seen().has("storms"):
		Era3Threats.seen().append("storms")
	Village.stats["quiet_until"] = -1.0
	var rolled := 0
	var others := 0
	w.threats.enabled = true
	Village.stats["era_started_t"] = Clock.total_t - 3000.0
	for i in 200:
		t.reset()
		t._on_dawn(0)
		if t.current == &"storms":
			rolled += 1
		elif t.current != &"":
			others += 1
	t.reset()
	w.threats.enabled = false
	check(others > 0, "the other threats still come (%d of 200 dawns)" % others)
	check(rolled == 0, "a threat that has come twice this era does not come again")
	check(Era3Threats.QUIET_AFTER >= 300.0 and Era3Threats.SICK_START <= 2 and Era3Threats.GUST_CAP <= 4, "after a threat, five minutes of peace; small outbreaks; few hurt by a storm")
