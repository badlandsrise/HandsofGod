extends Node
## Cases for tests/unit/test_work.gd.

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
	w.new_game()
	w.storm.skip()
	Clock.running = false
	Village.stats["onboarding"] = Onboarding.Beat.DONE
	_balance()
	await _fire()
	await _blessing()
	await _lodge()
	await _woodcutter()
	await _call_idle()
	await _farmhouse()
	await _threats()
	await _save_load()
	w.queue_free()
	await get_tree().process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)

# ---------------------------------------------------------------- helpers

## Runs the people and sites by hand (the clock is stopped in tests).
func step(seconds: float, dt: float = 0.1) -> void:
	for i in int(round(seconds / dt)):
		Clock.total_t += dt
		for p in Village.people.duplicate():
			if is_instance_valid(p):
				p.sim(dt)
				p.motion(dt)
		for s in Village.sites.duplicate():
			if is_instance_valid(s) and not s.is_queued_for_deletion():
				s.sim(dt)

func adult(at: Vector3, i: int = 0) -> Person:
	return w.spawn_person(at, "", {"age": Person.STAGE_START[Person.Stage.ADULT] + 20.0 + i, "sex": "f" if i % 2 == 0 else "m", "trust_f": 2.0})

func _sites(bid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.building != null and s.building.id == bid)

func _jobs(jid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.job != null and s.job.id == jid and not s.is_plot())

func _feed() -> void:
	Village.stores[&"berries"] = 40
	Village.stores[&"water"] = 40

# ---------------------------------------------------------------- balance

func _balance() -> void:
	check(Person.ERA1_NEEDS < 0.8, "Era 1 hunger and thirst come more slowly (x%.2f)" % Person.ERA1_NEEDS)
	check(Flags.DIFFICULTY["gentle"][&"food"] < 1.0 and Flags.DIFFICULTY["gentle"][&"water"] < 1.0, "Gentle is kinder still to food and water")
	var p := adult(Vector3(4, 0, 4))
	p.traits.clear()  # a devout person trusts faster
	p.trust_f = 1.0
	p.adjust_trust(1.0)
	check(absf(p.trust_f - (1.0 + Person.ERA1_TRUST_GAIN)) < 0.01, "Era 1 trust grows more slowly (+%.2f for +1)" % (p.trust_f - 1.0))
	p.adjust_trust(-0.5)
	check(absf(p.trust_f - (0.5 + Person.ERA1_TRUST_GAIN)) < 0.01, "fear is not slowed")
	check(Defs.job(&"haul_log").work_time >= 24.0 and Defs.job(&"carry_log").work_time >= 15.0, "moving a log is heavier work (haul %.0f s, carry %.0f s)" % [Defs.job(&"haul_log").work_time, Defs.job(&"carry_log").work_time])
	check(Site.heave(0.0) == 0.0 and Site.heave(1.0) == 1.0 and Site.heave(0.2) < 0.2 and Site.heave(0.8) > 0.8, "a log starts slowly, then moves (heave)")

# ---------------------------------------------------------------- the fire

func _fire() -> void:
	var fire: Site = Site.nearest(Vector3(Valley.FIRE.x, Site.ground(Valley.FIRE.x, Valley.FIRE.y), Valley.FIRE.y), 3.0, func(s): return s.is_fire())
	check(fire != null and fire.building == null, "the first fire is a bare fire")
	fire.fuel_t = 30.0
	var lit_before: bool = fire.lit()
	var ringed: Site = Progression.ring_the_fire()
	check(ringed == fire and fire.is_plot() and fire.building.id == &"fire_circle" and fire.is_fire(), "the first dream rings the fire that is already there")
	check(fire.lit() == lit_before and fire.fuel_t >= 200.0, "and it keeps burning while the stones are set")
	check(w.ensure_plots_for_dream(&"shelter_of_our_own") == 1 and _sites(&"fire_circle").size() == 1, "the dream lays no second fire, only the hut")
	check(Progression.ring_the_fire() == null, "it is ringed once")
	for k in fire.building.cost:
		fire.deliver(k, int(fire.building.cost[k]))
	fire.add_build_work(100.0)
	check(fire.is_finished_building(&"fire_circle") and fire.is_fire() and fire.job.id == &"tend_fire", "the fire circle is built round it, and is still the fire")
	check(Vector2(fire.global_position.x, fire.global_position.z).distance_to(Valley.FIRE) < 0.5, "where the fire always was")
	# a second fire circle only for a bigger village
	var prog: Progression = w.village_ai.progression
	Village.stats["dreams_done"] = ["shelter_of_our_own"]
	for i in 3:
		var spot: Vector2 = LayoutEra1.PLOT_SPOTS[&"hut"][i]
		var h: Site = Site.nearest(Vector3(spot.x, Site.ground(spot.x, spot.y), spot.y), 1.0, func(s): return s.building != null and s.building.id == &"hut")
		if h == null:
			h = w.spawn_plot(&"hut", Vector3(spot.x, 0, spot.y))
		h._finish(true)
	while Village.population() < 6:
		adult(Vector3(-4 + Village.population(), 0, 6), Village.population())
	prog._family_plots()
	check(_sites(&"fire_circle").size() == 1, "six people share the one fire")
	while Village.population() < Progression.SECOND_FIRE_POP:
		adult(Vector3(-4 + Village.population(), 0, 6), Village.population())
	prog._family_plots()
	check(_sites(&"fire_circle").size() == 2, "eight people in three huts want a second fire circle")
	await get_tree().process_frame

# ---------------------------------------------------------------- blessing

func _blessing() -> void:
	var prog: Progression = w.village_ai.progression
	w.open_region(&"valley_floor")
	prog._blessing_sites()
	check(_jobs(&"festival").is_empty() and _jobs(&"great_elk_hunt").is_empty(), "no festival and no elk before Blessing")
	check(Defs.job(&"festival").needs_power == &"blessing" and Defs.job(&"festival").needs_blessed, "the festival needs Blessing and blessed dancers")
	Faith.grant(&"blessing")
	prog._blessing_sites()
	check(_jobs(&"festival").size() == 1, "with Blessing they want a festival at the fire circle")
	check(_jobs(&"great_elk_hunt").is_empty(), "the great elk waits until after the festival")
	Flags.set_flag(&"festival")
	prog._blessing_sites()
	check(_jobs(&"great_elk_hunt").size() == 1, "after the festival the great elk comes")
	await get_tree().process_frame

# ---------------------------------------------------------------- the hunting lodge

func _lodge() -> void:
	_feed()
	var herd: Site = _jobs(&"hunt")[0] if not _jobs(&"hunt").is_empty() else null
	check(herd != null and not herd.can_accept(1) and herd.workplace_only(), "the hand cannot set hunters on the deer")
	check(herd != null and herd.hover_text().contains("lodge"), "the herd says a lodge's crew hunts it")
	var prog: Progression = w.village_ai.progression
	Faith.grant(&"grip_2")
	prog._family_plots()
	# [polish] the drying rack comes first
	var racks := _sites(&"drying_rack")
	check(_sites(&"hunting_lodge").is_empty() and racks.size() == 1, "with the deer in reach they first want a drying rack, not yet a lodge")
	check(herd != null and herd.hover_text().contains("drying rack"), "the herd says the hunt needs a drying rack first")
	if not racks.is_empty():
		var rack: Site = racks[0]
		for k in rack.building.cost:
			rack.deliver(k, int(rack.building.cost[k]))
		rack.add_build_work(1000.0)
	check(Site.has_drying_rack(), "the rack stands")
	prog._family_plots()
	var plots := _sites(&"hunting_lodge")
	check(plots.size() == 1 and plots[0].is_plot(), "with the rack built, the Valley Floor open and Grip II they want a hunting lodge")
	var lodge: Site = plots[0]
	check(Vector2(lodge.global_position.x, lodge.global_position.z).distance_to(Progression.LODGE_SPOT) < 0.5, "at its spot by the deer")
	var herds := _jobs(&"hunt").size()
	for k in lodge.building.cost:
		lodge.deliver(k, int(lodge.building.cost[k]))
	lodge.add_build_work(1000.0)
	check(lodge.is_workplace() and _jobs(&"hunt").size() == herds + 1, "the lodge is built, and a second herd grazes near it")
	check(lodge.max_slots() == clampi(Faith.grip, 2, 4), "its crew grows with the grip (%d at grip %d)" % [lodge.max_slots(), Faith.grip])
	var a := adult(lodge.global_position + Vector3(2, 0, 2), 1)
	var b := adult(lodge.global_position + Vector3(-2, 0, 2), 2)
	check(a.join(lodge) and b.join(lodge) and lodge.slots_filled() == 2, "two hunters are set down at the lodge")
	check(not adult(lodge.global_position, 3).join(lodge) or Faith.grip > 2, "a full lodge takes no more")
	Village.stores[&"meat"] = 0
	var hunts0 := int(Village.stats.get("lodge_hunts", 0))
	var seen_out := false
	for i in 30:
		step(5.0)
		if a.task_site != null and a.global_position.distance_to(lodge.global_position) > 6.0:
			seen_out = true
		if Village.store(&"meat") > 0:
			break
	check(seen_out, "the hunters go out to a herd on their own")
	check(int(Village.stats.get("lodge_hunts", 0)) > hunts0 and Village.store(&"meat") > 0, "and bring the meat home (%d)" % Village.store(&"meat"))
	check(Flags.has(&"first_hunt"), "the first hunt is remembered")
	for p in [a, b]:
		p.go_idle()
	await get_tree().process_frame

# ---------------------------------------------------------------- the woodcutters' camp

func _woodcutter() -> void:
	_feed()
	var prog: Progression = w.village_ai.progression
	prog._family_plots()
	check(_sites(&"woodcutter_camp").is_empty(), "no woodcutters' camp before stone tools")
	Flags.set_flag(&"stone_tools")
	prog._family_plots()
	var c: Site = _sites(&"woodcutter_camp")[0] if not _sites(&"woodcutter_camp").is_empty() else null
	check(c != null, "with stone tools they want a woodcutters' camp")
	var trees := _jobs(&"fell_tree").size()
	for k in c.building.cost:
		c.deliver(k, int(c.building.cost[k]))
	c.add_build_work(1000.0)
	check(_jobs(&"fell_tree").size() == trees + 2, "a stand of timber round the camp")
	var tree: Site = Workplace.tasks(c).filter(func(t): return t.job.id == &"fell_tree")[0]
	check(not tree.can_accept(1), "a tree in the camp's radius is the camp's")
	var p := adult(c.global_position + Vector3(1, 0, 2), 4)
	check(p.join(c), "a woodcutter is set down at the camp")
	var wood0 := Village.store(&"wood")
	for i in 30:
		step(5.0)
		if Village.store(&"wood") > wood0:
			break
	check(Village.store(&"wood") > wood0, "the camp's woodcutter fells and brings wood (%d)" % (Village.store(&"wood") - wood0))
	p.go_idle()
	await get_tree().process_frame

# ---------------------------------------------------------------- call

func _call_idle() -> void:
	for p in Village.alive():
		p.go_idle()
	step(0.5)
	var idle: Array = Village.idle_people()
	check(idle.size() >= 3, "some people are idle (%d)" % idle.size())
	var to := Vector3(12.0, 0, 16.0)
	to.y = w.ground_y(to.x, to.z)
	var calls0 := int(Village.stats.get("calls", 0))
	var n: int = Village.call_idle(to)
	check(n == idle.size() and int(Village.stats.get("calls", 0)) == calls0 + 1, "Call: every idle person answers (%d)" % n)
	check(Game.ACTIONS.has(&"hand_call"), "the hand has a Call key (%s)" % str(Game.ACTIONS.get(&"hand_call", [])))
	step(22.0)
	var near := 0
	for p in idle:
		if is_instance_valid(p) and Vector2(p.global_position.x - to.x, p.global_position.z - to.z).length() < 5.0:
			near += 1
	# one may break off to eat or sleep: most must be there
	check(near >= idle.size() - 1, "they gather round the hand (%d/%d)" % [near, idle.size()])
	var gathered := near
	step(2.0)
	near = 0
	for p in idle:
		if is_instance_valid(p) and Vector2(p.global_position.x - to.x, p.global_position.z - to.z).length() < 5.0:
			near += 1
	check(near >= gathered - 1, "and wait there to be picked up (%d)" % near)
	await get_tree().process_frame

# ---------------------------------------------------------------- the farmhouse

func _farmhouse() -> void:
	_feed()
	Village.era = 2
	Clock.season = Clock.Season.SPRING
	Clock.season_t = 0.0
	var e2: VillageEra2 = w.village_ai.era2
	Village.stats["era_started_t"] = Clock.total_t - 60.0
	Village.stats.erase("suggest_t")
	var fh: Site = e2._suggest()
	check(fh != null and fh.building.id == &"farmhouse", "Era 2's first suggestion is a farmhouse")
	check(e2._suggest() == null, "and the next suggestion waits")
	for k in fh.building.cost:
		fh.deliver(k, int(fh.building.cost[k]))
	fh.add_build_work(1000.0)
	await get_tree().process_frame
	check(fh.is_workplace() and fh.building.rest_here and fh.building.bin_cap > 0, "the farmhouse is a workplace with a bin, where its crew rests")
	var fields := Workplace.tasks(fh).filter(func(t): return t.building != null and t.building.id == &"field")
	check(fields.size() == Workplace.FIRST_FIELDS, "it stakes its first fields (%d)" % fields.size())
	check(fields.all(func(f): return not f.can_accept(1)), "the hand cannot set people on a field")
	var cart: Array = Village.sites.filter(func(s): return is_instance_valid(s) and s.parent_uid == fh.uid and s.job != null and s.job.id == &"cart_haul")
	check(cart.size() == 1, "and has a cart beside it")
	check(fh.max_slots() == clampi(Faith.grip, 2, 6), "its crew grows with the grip")
	Faith.grant(&"grip_3")
	var crew: Array = []
	for i in fh.max_slots():
		var p := adult(fh.global_position + Vector3(i - 2.0, 0, 4.0), 10 + i)
		if p.join(fh):
			crew.append(p)
	check(crew.size() >= 2, "farmers are set down at the farmhouse (%d)" % crew.size())
	# clearing, sowing, growing on their own, harvest into the bin
	for i in 40:
		step(5.0)
		if fields.all(func(f): return is_instance_valid(f) and f.is_field()):
			break
	check(fields.all(func(f): return is_instance_valid(f) and f.is_field()), "the crew clears the new fields")
	for i in 30:
		step(5.0)
		if fields.all(func(f): return f.field_stage != Site.Field.TILLED):
			break
	check(fields.all(func(f): return f.field_stage != Site.Field.TILLED), "and sows them")
	var f0: Site = fields[0]
	f0.moisture = 1.0
	var stage := f0.field_stage
	for i in 100:
		f0._sim_field(1.0)
	check(f0.field_stage > stage or f0.field_stage == Site.Field.RIPE, "a sown field grows on its own (no tending step)")
	for f in fields:
		f._set_field_stage(Site.Field.RIPE)
	var g0 := Village.store(&"grain")
	for i in 30:
		step(5.0)
		if Workplace.bin_total(fh) > 0:
			break
	check(Workplace.bin_total(fh) > 0 and Village.store(&"grain") == g0, "the harvest goes into the farmhouse bin, not straight to the stores (%d)" % Workplace.bin_total(fh))
	check(fh.hover_text().contains("bin"), "the farmhouse shows its bin")
	var carter := adult(cart[0].global_position + Vector3(1, 0, 1), 30)
	check(carter.join(cart[0]), "a carter is set on the cart")
	for i in 40:
		step(5.0)
		if Village.store(&"grain") > g0:
			break
	check(Village.store(&"grain") > g0 and int(Village.stats.get("carted", 0)) > 0, "the carter hauls the grain to the stores (%d)" % (Village.store(&"grain") - g0))
	# rest at the farmhouse
	var tired: Person = crew[0]
	tired.needs[&"rest"] = 0.05 if tired.needs.has(&"rest") else 0.0
	tired.needs[&"food"] = 0.1
	step(6.0)
	check(tired.job_site == fh, "a hungry farmer eats and stays on the farm crew")
	# more fields come one at a time
	Village.stats["harvests"] = 3
	Village.stats["suggest_t"] = -1.0e9
	for s in Village.sites:
		if is_instance_valid(s) and s.has_meta(&"suggested"):
			s.set_meta(&"suggested", Clock.total_t - VillageEra2.SUGGEST_HOLD - 1.0)
	var before := Workplace.field_count(fh)
	var rows: Array = e2.suggestions().filter(func(r): return str(r[0]).begins_with("more_fields"))
	check(not rows.is_empty(), "after the harvests the farmers want more fields")
	e2._lay(rows[0])
	check(Workplace.field_count(fh) == before + 1, "one more field is staked by the farmhouse")
	for p in crew + [carter]:
		p.go_idle()
	await get_tree().process_frame

# ---------------------------------------------------------------- Era 2 threats

func _threats() -> void:
	# no wolf raids: the wolves only come for people working by their den
	for p in Village.alive():
		p.go_idle()
		p.global_position = Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	check(Village.era == 2 and not Wolves.may_come(), "Era 2: no wolves while nobody works by the den")
	var lures := Village.sites.filter(func(s): return is_instance_valid(s) and str(s.get_meta("layout_tag", "")) == "wolf_den")
	w.village_ai.era2._den_lures()
	lures = Village.sites.filter(func(s): return is_instance_valid(s) and str(s.get_meta("layout_tag", "")) == "wolf_den")
	check(lures.size() == 3 and lures[0].hover_text().contains("den"), "timber and berries grow by the den, and say so")
	var p: Person = Village.alive()[0]
	p.global_position = lures[0].global_position
	check(Wolves.may_come() and Wolves.den_workers() == 1, "someone working by the den draws the wolves")
	var wolves: Wolves = w.wolves
	wolves.warn(1)
	wolves.start()
	var wolf: Wolf = wolves.get_children().filter(func(n): return n is Wolf)[0]
	check(wolf.leash > 0.0 and wolf.home.distance_to(Wolves.den()) < 1.0, "den wolves are leashed to the den")
	var far: Person = Village.alive()[1]
	far.global_position = Vector3(2, 0, 2)
	check(wolf._pick_target(Vector3(9999, 0, 9999), 0.0) != far, "a den wolf never goes for the village")
	wolves.clear_all()
	# bears at the quarry
	var bd: ThreatDef = Defs.threats.get(&"bears")
	check(bd.needs_region == &"hill_quarry", "the bears are the quarry's")
	var t: Era2Threats = w.threats.era2
	check(t._where(&"bears").distance_to(w._v3(Era2Threats.QUARRY_DEN)) < 1.0, "their den is above the quarry")
	await get_tree().process_frame

# ---------------------------------------------------------------- save / load

func _save_load() -> void:
	var fh: Site = _sites(&"farmhouse")[0]
	Workplace.bin_add(fh, &"grain", 5)
	var bin := Workplace.bin_total(fh)
	var d: Dictionary = fh.save_state()
	var s2: Site = load("res://scenes/sites/site.tscn").instantiate()
	s2.load_state(d)
	check(Workplace.bin_total(s2) == bin, "the farmhouse bin is saved")
	s2.free()
	check(Faith.RENAMED.get("reach", "") == "strong_arms", "an old save's Reach becomes Strong Arms")
	await get_tree().process_frame
