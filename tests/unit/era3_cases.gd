extends Node
## Cases for tests/unit/test_era3.gd. Starts from tests/bot/era3_start.json,
## the bot's save of the moment Era 3 began (a real Era 2 village of 59).

signal done(fails: int)

var fails := 0
var w: Node3D
var warned: Array = []
var started: Array = []
var ended: Array = []

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func run() -> void:
	Save.enabled = false
	Events.threat_warned.connect(func(id, _at): warned.append(id))
	Events.threat_started.connect(func(id, _at): started.append(id))
	Events.threat_ended.connect(func(id): ended.append(id))
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await get_tree().process_frame
	Game.flags["test"] = true
	w.new_game()
	w.storm.skip()
	await _load_start()
	await _setup()
	await _school()
	await _coast()
	await _ship()
	await _aqueduct()
	await _foremen()
	await _lift()
	await _fire()
	await _sickness()
	await _storm()
	await _observatory()
	await _save_load()
	await _first_two()
	await _gate()
	w.queue_free()
	await get_tree().process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)

func _sites(bid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.building != null and s.building.id == bid)

func _jobs(jid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.job != null and s.job.id == jid and not s.is_plot())

func _e3() -> VillageEra3:
	return w.village_ai.era3

func _finish_plot(s: Site) -> void:
	for k in s.building.cost:
		s.delivered[k] = int(s.building.cost[k])
	s.state = Site.State.BUILDING
	if s.awaiting_raise():
		s._begin_raise()
		var r := s.raise_site()
		if r != null:
			r._complete_group([])
	else:
		s.add_build_work(9999.0)

## More people (the town grows: births and newcomers), up to `n`.
func _grow_to(n: int) -> void:
	var i := 0
	while Village.population() < n:
		w.spawn_person(w._v3(Vector2(90.0 + float(i % 10), 20.0 + float(i / 10))), "", {"age": Person.STAGE_START[Person.Stage.ADULT] + 50.0, "sex": "f" if i % 2 == 0 else "m"})
		i += 1

func _adults(n: int) -> Array:
	return Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT and p.state != Person.S.SLEEP).slice(0, n)

# ---------------------------------------------------------------- the start

func _load_start() -> void:
	var txt := FileAccess.get_file_as_string("res://tests/bot/era3_start.json")
	var d = JSON.parse_string(txt)
	check(d is Dictionary, "the Era 3 start save reads")
	Save.apply(Save.migrate(d))
	await get_tree().process_frame
	await get_tree().process_frame
	Clock.running = false
	check(Village.era == 3 and not Village.stats.get("free_mode", true), "the save is in Era 3, which is playable")
	check(Clock.day_seconds == 80.0 and Defs.era(3).gate_min_minutes >= 55.0, "Era 3 keeps long days and a 55-minute pacing floor")
	check(w.era3 != null and w.threats.era3 != null and w.village_ai.era3 != null, "the world, threats and village AI have their Era 3 parts")

func _setup() -> void:
	var cottages := _sites(&"cottage").size()
	_e3().setup()
	check(Village.stats.get("era3_setup", false), "the town is laid out once")
	var th := _sites(&"townhouse").size()
	check(th > 0 and _sites(&"cottage").size() == cottages - th, "cottages with room around them became townhouses (%d)" % th)
	check(_jobs(&"mine_iron").size() == 3, "iron is found in the hill quarry")
	var before := Village.sites.size()
	_e3().setup()
	check(Village.sites.size() == before, "laying out the town twice does nothing")
	for l in w.era3.lamps:
		if not l.visible:
			check(false, "the street lamps stand in Era 3")
			break
	Clock.is_night = true
	w.era3._update_lights()
	var light := w.era3.lamps[0].find_child("Light", true, false) as Light3D
	check(light != null and light.visible, "the street lamps are lit at night")
	Clock.is_night = false
	Clock.phase_t = 10.0
	w.era3._update_lights()
	check(not light.visible, "and dark by day")

# ---------------------------------------------------------------- the school (dream 1)

func _school() -> void:
	Village.stats["last_dream_t"] = -1000.0
	w.village_ai.dreams.update()
	check(str(Village.stats.get("dream_active", "")) == "school", "the first Era 3 dream is the school")
	check(_sites(&"school").size() == 1, "the dream lays out the school plot")
	_e3().check_now()
	check(_sites(&"mason").size() == 1, "the people want a mason's yard first")
	Faith.spent = 0.0
	Faith.total = 2000.0
	check(not Faith.can_buy(&"grip_4") and not Faith.can_buy(&"lift_buildings"), "Grip IV and Lift Buildings wait for the school")
	check(Defs.power(&"grip_4").locked_reason() != "", "the HUD says why")
	_finish_plot(_sites(&"school")[0])
	w.village_ai.dreams.update()
	check(Dreams.is_done(&"school"), "the school dream comes true")
	check(Faith.can_buy(&"grip_4") and Faith.buy(&"grip_4") and Faith.grip == 10, "Grip IV: ten in the hand")
	check(_jobs(&"attend_school").size() == 1, "the school takes pupils")
	await get_tree().process_frame

# ---------------------------------------------------------------- the coast

func _coast() -> void:
	check(not Faith.can_buy(&"calm_waters"), "Calm Waters waits until they long for the sea")
	Village.stats["era_started_t"] = Clock.total_t - VillageEra3.SEA_AFTER - 10.0
	_e3().check_now()
	check(Flags.has(&"sea_seen"), "a few minutes in they follow the river to the sea")
	check(not w.is_region_open(&"coast"), "the coast is closed until the hand calms the sea")
	check(Faith.buy(&"calm_waters"), "Calm Waters can be learned")
	await get_tree().process_frame
	check(w.is_region_open(&"coast"), "Calm Waters opens the Coast")
	var camp := Village.sites.filter(func(s): return is_instance_valid(s) and s.building != null and s.building.camp and s.global_position.distance_to(w._v3(LayoutEra3.CAMPS[&"coast"])) < 2.0)
	check(camp.size() == 1, "the Coast gets its camp")
	check(_sites(&"harbour").size() == 1, "they want a harbour on the beach")
	check(w.edge_point(&"coast").distance_to(w._v3(LayoutEra3.EDGES[&"coast"])) < 1.0, "newcomers can walk in along the coast")

# ---------------------------------------------------------------- the ship

func _ship() -> void:
	var hb: Site = _sites(&"harbour")[0]
	_finish_plot(hb)
	var ship: Liftable = w.era3.ship
	check(ship != null and ship.visible and ship.is_in_group(&"liftable"), "the finished harbour has a ship waiting on the beach")
	var fish: Site = _jobs(&"fish_ship")[0] if not _jobs(&"fish_ship").is_empty() else null
	check(fish != null and not fish.can_accept(1) and fish.hover_text().contains("ship must be on the sea"), "nobody fishes from the ship while it is on the beach")
	check(Faith.strength >= ship.lift_weight(), "the hand is strong enough to lift the ship")
	ship.on_lifted()
	ship.on_placed(w._v3(Vector2(330.0, 400.0)))
	check(not Flags.has(&"ship"), "set down on land, the ship does not float")
	ship.on_lifted()
	var sea := Vector3(LayoutEra3.SHIP_ANCHOR.x, Valley.SEA_LEVEL, LayoutEra3.SHIP_ANCHOR.y)
	ship.on_placed(sea)
	check(Flags.has(&"ship") and not ship.is_in_group(&"liftable"), "set on the sea, the ship floats")
	check(fish.can_accept(1), "now they can fish from it")
	var voyage: Site = _jobs(&"sail_islands")[0]
	check(not voyage.can_work_now() and voyage.hover_text().contains("calm sea"), "the voyage waits for a calm sea")
	check(HandPowers.calm_at(sea) == 1 and voyage.can_work_now(), "Calm Waters over the sea lets them sail")
	var tin := Village.store(&"tin")
	voyage._complete_group([])
	check(Village.store(&"tin") == tin + 6, "a voyage to the islands brings home tin")
	w.era3.calm_t = 0.0

# ---------------------------------------------------------------- the aqueduct (dream 2)

func _aqueduct() -> void:
	Village.stats["last_dream_t"] = -1000.0
	w.village_ai.dreams.update()
	check(str(Village.stats.get("dream_active", "")) == "aqueduct", "the second Era 3 dream is the aqueduct")
	var aq: Site = _sites(&"aqueduct")[0]
	check(aq.global_position.distance_to(w._v3(LayoutEra3.PLOT_SPOTS[&"aqueduct"][0])) < 0.5, "its plot is at the castellum spot")
	for k in aq.building.cost:
		aq.delivered[k] = int(aq.building.cost[k])
	aq.deliver(aq.building.cost.keys()[0], 0)
	var raise := aq.raise_site()
	check(aq.awaiting_raise() and raise != null and raise.job.min_people == 10, "with its stone in, the aqueduct waits for a crew of ten")
	check(raise.can_accept(1), "Grip IV opens the crew of ten")
	raise._complete_group([])
	check(aq.state == Site.State.FINISHED and Flags.has(&"clean_water"), "raised: clean water")
	_grow_to(75)
	check(w.era3.fountain != null and w.era3.fountain.visible, "a fountain runs in the square")
	var arches := aq.visual.get_children().filter(func(c): return str(c.name).begins_with("aqueduct") or (c is Node3D and c.scene_file_path.contains("aqueduct")))
	check(aq.visual.get_child_count() >= LayoutEra3.AQUEDUCT_SEGMENTS + 1, "the arches walk east from the castellum (%d parts)" % aq.visual.get_child_count())
	w.village_ai.dreams.update()
	check(Dreams.is_done(&"aqueduct"), "the aqueduct dream comes true")
	check(Faith.buy(&"guiding_light"), "the Guiding Light can be learned after the aqueduct")
	await get_tree().process_frame

# ---------------------------------------------------------------- foremen and school

func _foremen() -> void:
	var mason: Site = _sites(&"mason")[0]
	if mason.state != Site.State.FINISHED:
		_finish_plot(mason)
	var job: Site = mason
	var a := _adults(2)
	var master: Person = a[0]
	var helper: Person = a[1]
	master.skills[&"building"] = 3.5
	master.skills[Person._family(job.job.skill)] = 3.5
	master.on_lifted()
	master.on_placed(job.slot_position(0), job)
	master._land()
	check(master.job_site == job and master.placed_by_hand, "the hand sets a master mason to work")
	Village.add_store(&"stone", 10)
	helper.go_idle()
	helper.global_position = job.global_position + Vector3(6, 0, 0)
	VillageEra3._shops_t = -INF
	Clock.is_night = false
	check(VillageEra3.autonomy(helper) and helper.job_site == job, "an idle adult nearby joins the master on their own (a foreman)")
	var kid: Person = null
	for p in Village.alive():
		if p.stage == Person.Stage.CHILD:
			kid = p
			break
	if kid == null:
		kid = w.spawn_person(w._v3(Vector2(70, 30)), "", {"age": Person.STAGE_START[Person.Stage.CHILD] + 20.0})
	kid.go_idle()
	check(VillageEra3.autonomy(kid) and kid.job_site != null and kid.job_site.job.id == &"attend_school", "children go to school by day on their own")
	kid.go_idle()

# ---------------------------------------------------------------- lift buildings

func _lift() -> void:
	Faith.spent = 0.0
	check(Faith.buy(&"lift_buildings") and Faith.strength >= 40.0, "Lift Buildings can be learned (and is never required)")
	var th: Site = _sites(&"townhouse")[0]
	check(th.can_be_lifted(), "a townhouse is light enough to lift")
	check(not _sites(&"great_hall").is_empty() or not Defs.building(&"great_hall").weight <= Faith.strength, "the great hall is far too heavy")
	w.hand.selected_power = &"lift_buildings"
	w.era3._sync_lift_mode()
	check(th.is_in_group(&"liftable"), "with Lift Buildings selected, houses join the liftables")
	var from := th.global_position
	th.on_lifted()
	check(th.lift_held and not th.is_shelter(), "a house in the hand shelters nobody")
	th.on_placed(w._v3(Vector2(60.0, 112.0)))      # the river bank by the raft: water nearby
	var on_water: bool = th.global_position.distance_to(from) < 0.5
	th.on_lifted()
	th.on_placed(w._v3(Vector2(-60.0, 60.0)))
	check(th.global_position.distance_to(w._v3(Vector2(-60.0, 60.0))) < 0.5 and int(Village.stats.get("buildings_moved", 0)) >= 1, "set down on open ground, it stays there")
	th.on_lifted()
	th.on_placed(w._v3(Vector2(400.0, 500.0)))
	check(th.global_position.distance_to(w._v3(Vector2(-60.0, 60.0))) < 0.5, "set down in the sea, it goes back where it stood")
	th.on_lifted()
	th.on_placed(from)
	w.hand.selected_power = &""
	w.era3._sync_lift_mode()
	check(not th.is_in_group(&"liftable"), "put away, houses are not liftable")
	print("  (river-bank drop kept: %s)" % str(not on_water))

# ---------------------------------------------------------------- the town fire

func _fire() -> void:
	var t: Era3Threats = w.threats.era3
	t.reset()
	Village.stats["era_started_t"] = Clock.total_t - 30.0 * 60.0
	Clock.season = Clock.Season.SUMMER
	check(t.can(&"town_fire"), "a fire can come once the town stands")
	t.warn(&"town_fire")
	var target: Site = t.target
	check(target != null and warned.has(&"town_fire"), "smoke from a roof is the warning")
	t._start()
	check(target.burn > 0.0 and target.is_in_group(&"hazard") and target.is_in_group(&"burning"), "the building burns, and the hand keeps people out of it")
	check(not target.can_accept(1) and not target.is_shelter(), "nobody works or shelters in a burning building")
	var line: Site = target.ensure_child_job(&"fight_fire")
	check(line != null and line.job.id == &"fight_fire" and line.parent_uid == target.uid, "a bucket line appears beside it")
	Faith.grant(&"rain")
	var b0 := target.burn
	HandPowers.douse_at(target.global_position)
	check(target.burn < b0, "Rain held over the fire beats it down")
	Village.add_store(&"water", 50)
	var guard := 0
	while target.burn > 0.0 and guard < 40:
		line.on_cycle_done(null)
		guard += 1
	check(target.burn <= 0.0 and not target.is_in_group(&"hazard"), "the bucket line puts it out")
	t._tick(1.0)
	check(not t.active() and ended.has(&"town_fire"), "and the threat ends (with faith for the hand)")
	await get_tree().process_frame
	check(_jobs(&"fight_fire").filter(func(s): return s.parent_uid == target.uid).is_empty(), "the bucket line goes home")
	# left alone, a fire guts the building: a repair crew rebuilds it
	t.warn(&"town_fire")
	var t2: Site = t.target
	t._start()
	t._time_up()
	check(t2.burn <= 0.0 and t2.damage >= 0.99 and not t2.can_accept(1), "a fire left alone burns the building out (nobody is hurt)")
	var fix: Site = t2.ensure_child_job(&"repair_roof")
	Village.add_store(&"wood", 20)
	for i in 6:
		fix.on_cycle_done(null)
	check(t2.damage <= 0.0, "a repair crew rebuilds it")
	await get_tree().process_frame
	check(_jobs(&"repair_roof").filter(func(s): return s.parent_uid == t2.uid).is_empty(), "and goes home")

# ---------------------------------------------------------------- sickness

func _sickness() -> void:
	var t: Era3Threats = w.threats.era3
	var deaths := int(Village.stats.get("deaths", 0))
	t.warn(&"sickness")
	t._start()
	check(Era3Threats.count() == Era3Threats.SICK_START, "a sickness starts with a few people")
	var sick: Person = null
	for p in Village.alive():
		if p.is_sick():
			sick = p
			break
	var r_sick := sick.rate()
	sick.sick_t = 0.0
	var r_well := sick.rate()
	sick.fall_sick()
	check(r_sick < r_well * 0.6, "the sick work at half pace")
	var clinic: Site = w.add_plot(&"clinic") if _sites(&"clinic").is_empty() else _sites(&"clinic")[0]
	if clinic.state != Site.State.FINISHED:
		_finish_plot(clinic)
	check(clinic.job != null and clinic.job.id == &"rest_at_clinic", "the clinic takes the sick")
	sick._pending.clear()    # (a just-loaded person still holds their saved job)
	sick.on_lifted()
	sick.on_placed(clinic.slot_position(0), clinic)
	sick._land()
	sick.global_position = clinic.slot_position(clinic.slot_of(sick))
	check(sick.at_clinic(), "carried to the clinic, they rest there")
	var left := sick.sick_t
	print("  sick: state %s job %s present %s at_clinic %s left %.2f blessed %.1f" % [Person.STATE_NAMES[sick.state], sick.job_site.job.id if sick.job_site else "-", str(sick.is_present_at(clinic, 1.6)), str(sick.at_clinic()), sick.sick_t, sick.blessed_t])
	sick.sim(1.0)
	print("  after %.2f state %s" % [sick.sick_t, Person.STATE_NAMES[sick.state]])
	check(left - sick.sick_t >= Person.CLINIC_HEAL * 0.9, "and mend six times as fast")
	for p in Village.alive():
		p.sick_t = 0.0
	t._tick(1.0)
	check(not t.active() and ended.has(&"sickness") and int(Village.stats.get("deaths", 0)) == deaths, "everyone mends; nobody dies of it")

# ---------------------------------------------------------------- storms

func _storm() -> void:
	var t: Era3Threats = w.threats.era3
	t.warn(&"storms")
	t._start()
	check(t.storm_on() and w.look.storm, "a storm blows in off the sea")
	w.era3.calm_t = 30.0
	check(not Site.sea_calm(), "no ship sails in a storm, calm or not")
	var out: Array = _adults(4)
	for p in out:
		p.go_idle()
		p.warmed_t = 0.0
		p.blessed_t = 0.0
		p.hurt_t = 0.0
	out[0].warm(20.0)
	var old: float = Era3Threats.GUST_CHANCE
	for i in 30:
		t._gusts()
	check(out[0].hurt_t <= 0.0, "Warmth held over people shields them from the gusts")
	check(out.slice(1).any(func(p): return p.hurt_t > 0.0), "people caught out in the open are knocked about")
	check(Village.alive().all(func(p): return p.alive()), "but nobody dies")
	var damaged := Village.sites.filter(func(s): return is_instance_valid(s) and s.damage > 0.0).size()
	t._tear_roofs(2)
	check(Village.sites.filter(func(s): return is_instance_valid(s) and s.damage > 0.0).size() == damaged + 2, "the wind tears roofs off")
	t.t = 0.0
	Clock.running = true
	t._process(0.01)
	Clock.running = false
	check(not t.active() and ended.has(&"storms"), "and blows itself out")
	print("  (gust chance %.2f)" % old)
	for p in Village.alive():
		p.hurt_t = 0.0
	w.era3.calm_t = 0.0

# ---------------------------------------------------------------- the observatory (dream 3, the gate)

func _observatory() -> void:
	Village.stats["last_dream_t"] = -1000.0
	w.village_ai.dreams.update()
	check(str(Village.stats.get("dream_active", "")) == "observatory", "the last Era 3 dream is the observatory (the gate)")
	var ob: Site = _sites(&"observatory")[0]
	check(ob.global_position.distance_to(w._v3(LayoutEra3.PLOT_SPOTS[&"observatory"][0])) < 0.5 and w.region_at(ob.global_position) == &"hill_quarry", "it crowns the quarry hill")
	_finish_plot(ob)
	var astro: Site = _jobs(&"astronomy")[0]
	Clock.is_night = false
	check(not astro.can_work_now(), "the stars wait for night")
	Clock.is_night = true
	check(astro.can_work_now() and astro.can_accept(1), "at night the astronomers can work (the Guiding Light is learned)")
	var a: Person = _adults(1)[0]
	a.join(astro, false)
	check(HandPowers.guide_at(astro.global_position + Vector3(0, 30, 0)) >= 1 and w.era3.aurora.visible and a.is_blessed(), "the Guiding Light brings the northern lights and speeds the astronomers")
	a.go_idle()
	Village.add_store(&"star_charts", VillageEra3.CHARTS_FOR_GATE)
	_e3().check_now()
	check(Flags.has(&"star_charts"), "three star charts drawn")
	Clock.is_night = false
	ob.rebuild_visual()
	check(ob.find_children("HandSymbol", "", true, false).size() > 0, "the hand is in the observatory's coloured glass")
	for p in Village.alive():
		p.trust_f = 4.0
		p.adjust_trust(0.0)
	Trust._cache_t = -INF
	_e3()._trust()
	check(Flags.has(&"town_flag") and w.era3.flag != null and w.era3.flag.visible, "a town that loves the hand raises the hand's flag in the square")

# ---------------------------------------------------------------- save/load

func _save_load() -> void:
	var th: Site = _sites(&"townhouse")[0]
	th.set_damage(0.4, "")
	var p: Person = _adults(1)[0]
	p.fall_sick()
	var sick_left := p.sick_t
	var puid := p.uid
	var snap := Save.snapshot()
	var pop := Village.population()
	var n_sites := Village.sites.size()
	w.new_game()
	await get_tree().process_frame
	Save.apply(JSON.parse_string(JSON.stringify(snap)))
	await get_tree().process_frame
	await get_tree().process_frame
	Clock.running = false
	check(Village.era == 3 and Village.population() == pop and Village.sites.size() == n_sites, "the town comes back whole")
	check(w.is_region_open(&"coast") and Flags.has(&"ship") and w.era3.ship != null and w.era3.ship.visible, "the coast and the ship on the sea come back")
	check(w.era3.fountain != null and w.era3.fountain.visible and w.era3.flag != null and w.era3.flag.visible, "the fountain and the flag come back")
	var dmg := Village.sites.filter(func(s): return is_instance_valid(s) and s.damage > 0.0)
	check(not dmg.is_empty(), "torn roofs stay torn until mended")
	var p2: Person = null
	for q in Village.alive():
		if q.uid == puid:
			p2 = q
	check(p2 != null and absf(p2.sick_t - sick_left) < 1.0, "the sick are still sick")
	check(Village.stats.get("era3_setup", false) and Dreams.is_done(&"aqueduct"), "Era 3 progress saves with the village")
	for q in Village.alive():
		q.sick_t = 0.0

# ---------------------------------------------------------------- the first two

func _first_two() -> void:
	var ft: Array = EraCard.first_two()
	check(ft.size() == 2, "the book remembers the first two")
	var line := EraCard.first_two_line(ft)
	check(line.contains("first two") and (line.contains("remembered") or line.contains("still with us")), "the era card has a line for them: \"%s\"" % line)
	var s := EraTransition.summary(3)
	check((s["first_two"] as Array).size() == 2, "the era summary lists the first two, alive or remembered")
	check(LayoutEra1.FIRST_TWO_EXTRA_LIFE >= 1500.0, "the first two live longer, gentler lives")

# ---------------------------------------------------------------- the gate

func _gate() -> void:
	_grow_to(88)
	w.village_ai.dreams.update()
	check(Dreams.is_done(&"observatory") and int(Village.stats.get("era_gate_done", 0)) == 3, "the observatory dream is the Era 3 gate")
	check(EraTransition.enter_era(4) and Village.era == 4, "the gate leads on to Era 4")
	check(Defs.era(4) != null, "Era 4 is there to go on to")
