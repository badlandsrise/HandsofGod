extends Node
## Cases for tests/unit/test_era2.gd.

signal done(fails: int)

var fails := 0
var w: Node3D
var warned: Array = []
var ended: Array = []

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func run() -> void:
	Save.enabled = false
	Events.threat_warned.connect(func(id, _at): warned.append(id))
	Events.threat_ended.connect(func(id): ended.append(id))
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await get_tree().process_frame
	Game.flags["test"] = true
	w.new_game()
	w.storm.skip()
	Clock.running = false
	Village.stats["onboarding"] = Onboarding.Beat.DONE
	_era1_village()
	await _transition()
	await _fields()
	await _economy()
	await _raising()
	await _regions()
	await _chain()
	await _bridge()
	await _threats()
	await _trust()
	await _save_load()
	w.queue_free()
	await get_tree().process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)

# ---------------------------------------------------------------- setup

## The end of Era 1: three huts, a shrine, the three dreams done, 17 people.
func _era1_village() -> void:
	for i in 3:
		var spot: Vector2 = LayoutEra1.PLOT_SPOTS[&"hut"][i]
		var h: Site = w.spawn_plot(&"hut", Vector3(spot.x, 0, spot.y))
		h._finish(true)
	var sh: Site = w.spawn_plot(&"shrine", Vector3(6.5, 0, -22.5))
	sh._finish(true)
	Village.stats["dreams_done"] = ["shelter_of_our_own", "shrine_to_the_hand", "stone_circle"]
	Village.stats["era_gate_done"] = 1
	Village.open_region(&"valley_floor")
	Village.open_region(&"western_meadow")
	for i in 15:
		w.spawn_person(Vector3(-6 + i * 0.8, 0, 4), "", {"age": Person.STAGE_START[Person.Stage.ADULT] + 30.0 * i, "sex": "f" if i % 2 == 0 else "m", "trust_f": 2.0})
	Faith.grant(&"grip_2")
	Faith.grant(&"strength_1")
	Births.assign_homes()

func _sites(bid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and s.building != null and s.building.id == bid)

func _jobs(jid: StringName) -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and s.job != null and s.job.id == jid)

# ---------------------------------------------------------------- transition

func _transition() -> void:
	Clock.season = Clock.Season.AUTUMN
	Clock.season_t = 100.0
	var homes_before := Village.alive().filter(func(p): return p.home != null).size()
	var winters := int(Village.stats.get("winters_survived", 0))
	check(EraTransition.enter_era(2), "Era 1 -> Era 2")
	print("  winters %d -> %d" % [winters, int(Village.stats.get("winters_survived", 0))])
	check(Village.era == 2 and not Village.stats.get("free_mode", true), "Era 2 is playable, not free mode")
	check(Clock.season == Clock.Season.SPRING and Clock.day_seconds == 80.0, "Era 2 opens in spring, with its longer days")
	check(int(Village.stats.get("winters_survived", 0)) == winters + 1, "the winter skipped by the time-lapse counts as lived through")
	check(_sites(&"hut").is_empty() and _sites(&"cottage").size() == 3, "the huts became cottages where they stood")
	check(Village.alive().filter(func(p): return p.home != null).size() == homes_before, "every family kept its home")
	check(not EraTransition.enter_era(2), "entering Era 2 twice does nothing")
	Village.stats["last_dream_t"] = -1000.0
	w.village_ai.dreams.update()
	check(str(Village.stats.get("dream_active", "")) == "granary", "the first Era 2 dream is the granary")
	check(_sites(&"granary").size() == 1, "the dream lays out the granary plot")
	await get_tree().process_frame

# ---------------------------------------------------------------- fields

func _fields() -> void:
	var f: Site = w.add_plot(&"field")
	check(f != null and f.state == Site.State.BUILDING, "a field plot needs work, not materials")
	f.add_build_work(100.0)
	check(f.is_field() and f.field_stage == Site.Field.TILLED, "a finished field is tilled")
	check(f.field_want() == &"sow", "a tilled field in spring wants sowing")
	f.field_tend(100.0)
	check(f.field_stage == Site.Field.SPROUTS, "sown: sprouts")
	f.moisture = 1.0
	for i in 300:
		f._sim_field(1.0)
		f.moisture = 1.0
	check(f.field_stage == Site.Field.RIPE and f.field_want() == &"harvest", "with water the crop ripens")
	var g0 := Village.store(&"grain")
	f.field_tend(100.0)
	check(Village.store(&"grain") > g0 and int(Village.stats.get("harvests", 0)) == 1 and f.field_stage == Site.Field.STUBBLE, "the harvest brings in grain and leaves stubble")
	for i in 40:
		f._sim_field(1.0)
	check(f.field_stage == Site.Field.TILLED, "stubble rests and is tilled again")
	# drought: bone dry for long, the crop withers
	w.look.set_weather(0.0, false)
	f.field_tend(100.0)
	f.moisture = 0.0
	var lost := int(Village.stats.get("crops_lost", 0))
	for i in 60:
		f._sim_field(1.0)
		f.moisture = 0.0
	check(int(Village.stats.get("crops_lost", 0)) == lost + 1 and f.field_stage == Site.Field.STUBBLE, "a field left bone dry withers")
	# rain from the hand waters fields near it
	f._set_field_stage(Site.Field.TILLED)
	f.field_tend(100.0)
	f.moisture = 0.1
	check(HandPowers.rain_at(f.global_position) == 1 and f.moisture > 0.1, "Rain waters the field under the hand")
	# winter: no sowing late in the year, frost takes a growing crop
	Clock.season = Clock.Season.WINTER
	f._sim_field(1.0)
	check(f.field_stage == Site.Field.STUBBLE, "the frost takes a crop still in the ground")
	Clock.season = Clock.Season.SPRING
	await get_tree().process_frame

# ---------------------------------------------------------------- economy

func _economy() -> void:
	check(Village.FOOD_KINDS.has(&"bread"), "bread is food")
	var mill := Defs.job(&"mill_grain")
	var bake := Defs.job(&"bake_bread")
	check(mill.inputs.has(&"grain") and mill.outputs.has(&"flour") and bake.inputs.has(&"flour") and bake.outputs.has(&"bread"), "grain -> mill -> flour -> bakery -> bread")
	var smelt := Defs.job(&"smelt_bronze")
	var forge := Defs.job(&"forge_tools")
	check(smelt.inputs.has(&"ore") and smelt.inputs.has(&"charcoal") and forge.inputs.has(&"bronze") and forge.outputs.has(&"tools"), "ore + charcoal -> bronze -> tools")
	check(Defs.job(&"fire_kiln").inputs.has(&"clay") and Defs.job(&"weave_cloth").inputs.has(&"wool"), "clay -> pots, wool -> cloth")
	# the granary raises the store cap
	var cap := Village.store_cap
	var gr: Site = _sites(&"granary")[0]
	for k in gr.building.cost:
		gr.deliver(k, int(gr.building.cost[k]))
	gr.add_build_work(1000.0)
	check(gr.state == Site.State.FINISHED and Village.store_cap == cap + gr.building.store_bonus, "the granary keeps more")
	check(gr.is_store(), "the granary is a store people bring goods to")
	# discoveries
	var e2: VillageEra2 = w.village_ai.era2
	Village.add_store(&"pots", 6)
	Village.add_store(&"cloth", 5)
	Village.add_store(&"tools", 5)
	var cap2 := Village.store_cap
	e2._discoveries()
	check(Flags.has(&"pottery") and Village.store_cap == cap2 + VillageEra2.POTTERY_CAP, "pottery: the pots keep more")
	check(Flags.has(&"woven_clothes") and Flags.has(&"bronze_tools"), "woven clothes and bronze tools are discovered")
	# suggestions: one plot at a time (a calmer Era 2)
	Village.stats["era_started_t"] = Clock.total_t - 700.0
	Village.stats.erase("suggest_t")
	var fields0 := _sites(&"field").size()
	var s1: Site = e2._suggest()
	check(s1 != null and s1.has_meta(&"suggested") and s1.is_plot(), "the village suggests a plot")
	Village.stats["suggest_t"] = Clock.total_t - VillageEra2.SUGGEST_GAP - 1.0
	check(e2._suggest() == null, "one suggestion at a time: the next waits while this one waits for its materials")
	var laid: Array = [s1]
	for i in 12:
		for s in laid:
			if is_instance_valid(s):
				s.set_meta(&"suggested", Clock.total_t - VillageEra2.SUGGEST_HOLD - 1.0)
		Village.stats["suggest_t"] = Clock.total_t - VillageEra2.SUGGEST_GAP - 1.0
		var n: Site = e2._suggest()
		if n == null:
			break
		laid.append(n)
	check(laid.size() >= 4, "and the next come one by one (%d)" % laid.size())
	check(_sites(&"farmhouse").size() == 1 and _sites(&"well").size() == 1 and _sites(&"mill").size() == 1 and _sites(&"sheep_pen").size() == 1, "a farmhouse, a well, a mill and a sheep pen as it grows")
	check(_sites(&"field").size() == fields0, "no loose field wishes: the farmhouse lays its own fields")
	await get_tree().process_frame

# ---------------------------------------------------------------- raising

func _raising() -> void:
	var barn: Site = w.add_plot(&"barn")
	check(barn != null, "a barn plot")
	for k in barn.building.cost:
		barn.deliver(k, int(barn.building.cost[k]))
	check(barn.awaiting_raise() and barn.hand_ignores(), "the materials are in: the barn waits for its raising")
	var r: Site = barn.raise_site()
	check(r != null and r.job.id == &"barn_raising" and r.job.min_people == 8, "a barn raising needs eight at once")
	barn.add_build_work(1000.0)
	check(barn.state == Site.State.BUILDING, "builders alone cannot raise it")
	r._complete_group([])
	check(barn.state == Site.State.FINISHED, "the crew raises the barn")
	await get_tree().process_frame
	check(barn.raise_site() == null, "and the raising job is gone")
	# the temple's plot goes down where the shrine stands, over it
	check(w.ensure_plots_for_dream(&"temple_of_the_hand") == 1 and _sites(&"temple").size() == 1 and _sites(&"shrine").size() == 1, "the temple plot is laid over the shrine")
	for s in _sites(&"temple"):
		s.remove_site()
	await get_tree().process_frame

# ---------------------------------------------------------------- regions

func _regions() -> void:
	check(Defs.power(&"reach") == null and not Faith.can_buy(&"strong_arms"), "Strong Arms (it replaced Reach) waits until they long for the far bank")
	var e2: VillageEra2 = w.village_ai.era2
	Village.stats["era_started_t"] = Clock.total_t - VillageEra2.FAR_BANK_AFTER - 10.0
	e2._far_bank()
	Faith.total = 2000.0
	check(Flags.has(&"far_bank_seen") and Faith.can_buy(&"strong_arms"), "then the hand can learn Strong Arms")
	var joined_before := int(Village.stats.get("joined", 0))
	var tm0: Array = e2.timbers()
	check(tm0.is_empty(), "no timbers before Strong Arms")
	Faith.buy(&"strong_arms")
	await get_tree().process_frame
	var fbs := _sites(&"footbridge")
	check(fbs.size() == 1 and fbs[0].wants_timber() and Faith.strength >= Timber.WEIGHT, "Strong Arms lays the footbridge plot, and the hand can lift a timber")
	var fb: Site = fbs[0]
	check(Vector2(fb.global_position.x, fb.global_position.z).distance_to(VillageEra2.FOOTBRIDGE) < 0.5 and w.is_water(fb.global_position) and w.region_at(fb.global_position + Vector3(0, 0, 10)) == &"east_bank", "it spans the shallows to the East Bank")
	check(e2.timbers().size() == 2, "two timbers lie by the bridge yard")
	check(not w.is_region_open(&"east_bank"), "the East Bank waits for the bridge")
	check(w.site_drop_reason(fb) == "", "its builders are set down on the near bank ('%s')" % w.site_drop_reason(fb))
	var far_slot := false
	for i in fb.max_slots():
		if not w.drops.accessible(w.region_at(fb.slot_position(i))):
			far_slot = true
	check(not far_slot and w.drop_reason(fb.global_position + Vector3(0, 0, 10)) != "", "every builder's slot is on the near bank, and the far bank stays shut")
	for k in fb.building.cost:
		fb.deliver(k, int(fb.building.cost[k]))
	check(fb.state == Site.State.PLOT and fb.raise_site() == null, "wood alone is not enough: it waits for its timbers")
	var t0: Timber = e2.timbers()[0]
	t0.on_lifted()
	t0.on_placed(fb.global_position + Vector3(30, 0, -20))
	check(fb.timbers_in == 0 and not (Village.stats["timbers"][t0.key] as Array).is_empty(), "a timber set down far off stays where it lies")
	for t in e2.timbers():
		t.on_lifted()
		t.on_placed(fb.global_position + Vector3(0, 0, -6))
	await get_tree().process_frame
	check(fb.timbers_in == 2 and e2.timbers().is_empty() and int(Village.stats.get("timbers_set", 0)) == 2, "the hand sets both timbers on the plot")
	var fr: Site = fb.raise_site()
	check(fr != null and fr.job.id == &"footbridge_raising" and fr.job.min_people == 3 and not w.is_water(fr.global_position), "a crew of three raises it, from the near bank")
	check(fr != null and fr.global_position.z < fb.global_position.z, "the crew gathers on the village side")
	fr._complete_group([])
	await get_tree().process_frame
	check(fb.state == Site.State.FINISHED and Flags.has(&"footbridge"), "the footbridge is raised")
	check(w.is_region_open(&"east_bank"), "the footbridge opens the East Bank")
	if w.has_method("add_crossing") or ("drops" in w and w.drops != null):
		check(not ("drops" in w) or w.drops == null or w.drops.accessible(&"east_bank"), "the hand may set people down across the footbridge")
	check(_sites(&"camp").size() == 1 and _sites(&"camp")[0].is_store() and _sites(&"camp")[0].is_shelter(), "a camp on the far bank: a store and a shelter")
	check(_jobs(&"dig_clay").size() == 2 and _jobs(&"mine_ore").size() == 2, "clay pits and copper ore on the East Bank")
	check(int(Village.stats.get("joined", 0)) == joined_before + 3, "three wanderers come in on the East Bank")
	Births.assign_homes()
	check(Village.alive().all(func(p): return p.home == null or not p.home.building.camp), "nobody makes the camp their home")
	# the rockfall
	check(not w.is_region_open(&"hill_quarry"), "the rockfall closes the Hill Quarry")
	check(Faith.has(&"strength_2") or Dreams.region_hint(&"hill_quarry").contains("Strength II"), "the temple's checklist says the quarry needs Strength II ('%s')" % Dreams.region_hint(&"hill_quarry"))
	var b0: Liftable = w.era2.boulders[0]
	check(b0.lift_weight() > Faith.strength, "a boulder is too heavy before Strength II")
	for i in w.era2.boulders.size():
		var b: Liftable = w.era2.boulders[i]
		b.on_lifted()
		b.on_placed(Vector3(LayoutEra2.ROCKFALL.x - 14.0, 0, LayoutEra2.ROCKFALL.y + i * 4.0))
	check(w.is_region_open(&"hill_quarry") and _jobs(&"quarry_stone").size() == 3, "with the boulders moved the Hill Quarry opens, with quarry ledges")
	await get_tree().process_frame

# ---------------------------------------------------------------- bridge

## The bridge's bronze chain: the checklist names the missing workshop, the
## dream's workshops are laid at once, and a lost one is laid again.
func _chain() -> void:
	var e2: VillageEra2 = w.village_ai.era2
	var d: DreamDef = Defs.dream(&"great_bridge")
	var done0: Array = (Village.stats.get("dreams_done", []) as Array).duplicate()
	var act0: String = str(Village.stats.get("dream_active", ""))
	Village.stats["dreams_done"] = done0 + (["granary"] if not done0.has("granary") else [])
	Village.stats["dream_active"] = "great_bridge"
	if _sites(&"bridge").is_empty():
		w.ensure_plots_for_dream(&"great_bridge")
	for s in _sites(&"charcoal_clamp") + _sites(&"smelter"):
		s.remove_site()
	for k in ["wish_charcoal", "wish_smelter", "wish_uid_charcoal", "wish_uid_smelter"]:
		Village.stats.erase(k)
	for k in [&"bronze", &"charcoal", &"ore"]:
		Village.take_store(k, Village.store(k))
	Village.add_store(&"ore", 10)
	var line := _line(d, "m:bridge:bronze")
	check(not line.is_empty() and not line["done"] and str(line["hint"]).contains("charcoal clamp"), "the checklist names the bridge's missing link ('%s')" % line.get("hint", ""))
	check(str(_line(d, "b:bridge").get("hint", "")).begins_with("It waits for bronze"), "and the bridge's own line says what it waits for")
	var miss := Dreams.missing_workshops(d)
	check(miss.has(&"charcoal_clamp") and miss.has(&"smelter"), "the dream waits on a clamp and a smelter (%s)" % [miss])
	Village.stats["suggest_t"] = Clock.total_t       # the queue is busy: the dream's workshops jump it
	e2._suggest()
	e2._suggest()
	check(_sites(&"charcoal_clamp").size() == 1 and _sites(&"smelter").size() == 1, "the dream's workshops are laid at once")
	check(str(_line(d, "m:bridge:bronze").get("hint", "")).contains("plot is marked"), "then the line points at their plots")
	_sites(&"charcoal_clamp")[0].remove_site()
	await get_tree().process_frame
	check(_sites(&"charcoal_clamp").is_empty() and Dreams.missing_workshops(d).has(&"charcoal_clamp"), "a lost clamp plot shows as missing again")
	e2._suggest()
	check(_sites(&"charcoal_clamp").size() == 1, "and it is laid again")
	check(Dreams.checklist_met(d) == Dreams.met(d), "the checklist still agrees with the dream")
	Village.take_store(&"ore", Village.store(&"ore"))
	Village.stats["dreams_done"] = done0
	Village.stats["dream_active"] = act0
	await get_tree().process_frame

func _line(d: DreamDef, key: String) -> Dictionary:
	for it in Dreams.checklist(d):
		if it["key"] == key:
			return it
	return {}

func _bridge() -> void:
	var c: Vector2 = LayoutEra2.PLOT_SPOTS[&"bridge"][0]
	check(w.is_water(Vector3(c.x, 0, c.y)), "the bridge spot is over the river")
	check(w.era2.deck_y(c.x, c.y) == -INF, "no deck before it is built")
	if _sites(&"bridge").is_empty():
		w.ensure_plots_for_dream(&"great_bridge")
	var br: Site = _sites(&"bridge")[0]
	for k in br.building.cost:
		br.deliver(k, int(br.building.cost[k]))
	var r: Site = br.raise_site()
	check(r != null and r.job.id == &"bridge_building", "the bridge needs its crew")
	check(r != null and not w.is_water(r.global_position), "the crew gathers on the bank, not in the river")
	r._complete_group([])
	var y: float = w.ground_y(c.x, c.y)
	check(br.state == Site.State.FINISHED and y > w.valley.water_level(c.x, c.y) + 1.0, "the finished deck stands above the water")
	check(not w.nav.extra_faces.is_empty(), "the deck is in the navmesh")
	await get_tree().process_frame

# ---------------------------------------------------------------- threats

func _threats() -> void:
	var t: Era2Threats = w.threats.era2
	Village.stats["quiet_until"] = -1.0
	# blight: the field with the fewest farmers; one alone cannot fight it
	var f: Site = Village.sites.filter(func(s): return is_instance_valid(s) and s.is_field())[0]
	f._set_field_stage(Site.Field.TILLED)
	f.field_tend(100.0)
	check(t.can(&"crop_blight"), "the blight can come once a crop is growing")
	t.warn(&"crop_blight")
	check(warned.has(&"crop_blight") and t.active() and w.threats.major_active(), "the blight is telegraphed and counts as the one major threat")
	t._start()
	check(f.is_blighted() and f.field_want() == &"cure", "the field turns black")
	check(not f.field_tend(100.0) and f.field_cure == 0.0, "nobody there: no one fights it")
	check(not f.can_accept(1), "the hand cannot set people on a field: the farmhouse crew works it")
	check(not f.field_tend(100.0, true, 1) and f.is_blighted(), "one farmer alone cannot fight it")
	f.field_tend(100.0, true, 2)
	check(not f.is_blighted() and int(Village.stats.get("blights_cured", 0)) == 1, "two farmers at once save the field")
	t._tick(1.0)
	check(not t.active(), "and the threat ends")
	# flood: low fields lose their crop, grain rots without a granary (there is one)
	Village.add_store(&"grain", 20)
	var g := Village.store(&"grain")
	t.warn(&"flood")
	t._start()
	check(Village.store(&"grain") == g, "the granary keeps the grain dry in a flood")
	Clock.running = true
	t._process(1.0)
	t.t = 0.0
	t._process(0.1)
	check(t.phase == 3, "the flood recedes before it ends")
	t.t = 0.0
	t._process(0.1)
	check(not t.active() and ended.has(&"flood") and w.era2.flood_k == 0.0, "the water goes down")
	# the bear: a flick scares it, Strength II carries it off home
	t.warn(&"bears")
	t._start()
	var bear: Bear = t.bear
	check(bear != null and is_instance_valid(bear) and bear.is_in_group("liftable"), "a bear comes out of its den, and the hand can grab it")
	check(w.scare_threats(bear.global_position, 7.0) == 1 and bear.state == Bear.S.SCARED, "a flick scares the bear")
	Faith.grant(&"strength_2")
	check(Faith.strength >= bear.lift_weight(), "Strength II can lift the bear")
	bear.on_lifted()
	bear.on_placed(bear.den + Vector3(-4, 0, 0))
	check(bear.state == Bear.S.HOME and not t.active() and ended.has(&"bears"), "carried off, the bear goes home and the threat ends")
	# drought needs summer and something growing
	Clock.season = Clock.Season.SUMMER
	Village.stats["era_started_t"] = Clock.total_t - 30.0 * 60.0
	check(t.can(&"drought"), "a drought can come in summer")
	t.warn(&"drought")
	t._start()
	check(w.threats.drought_active() and f._drought_k() == 3.0, "in a drought fields dry three times as fast")
	t.t = 0.0
	t._process(0.1)
	check(not w.threats.drought_active(), "and it breaks")
	Clock.running = false
	Clock.season = Clock.Season.SPRING
	check(Era2Threats.seen().size() == 4, "every Era 2 threat is recorded as seen")
	await get_tree().process_frame

# ---------------------------------------------------------------- trust

func _trust() -> void:
	check(Trust.stage_name(0.2) == "afraid" and Trust.stage_name(4.5) == "devoted", "trust has named stages")
	for p in Village.alive():
		p.trust_f = 3.5
		p.adjust_trust(0.0)
	Trust._cache_t = -INF
	var e2: VillageEra2 = w.village_ai.era2
	e2._trust()
	check(Flags.has(&"hand_symbol") and Trust.village_loves_hand(), "once the village loves the hand it paints the hand on its doors")
	var cot: Site = _sites(&"cottage")[0]
	cot.rebuild_visual()
	check(cot.find_children("HandSymbol", "", true, false).size() > 0, "the hand symbol hangs over the cottage door")
	var devoted: Person = Village.alive()[0]
	devoted.trust_f = 4.5
	devoted.adjust_trust(0.0)
	devoted.go_idle()
	devoted.state = Person.S.IDLE
	devoted.global_position = w._v3(Vector2(0.0, -8.0))     # near enough to walk to the shrine
	Clock.is_night = false
	check(VillageEra2.bring_offering(), "a devoted person sets off with an offering")
	devoted.global_position = devoted._target
	devoted.state = Person.S.WALK
	devoted.sim(0.1)
	check(int(Village.stats.get("offerings", 0)) == 1, "and leaves it at the shrine")

# ---------------------------------------------------------------- save/load

func _save_load() -> void:
	var f: Site = Village.sites.filter(func(s): return is_instance_valid(s) and s.is_field())[0]
	f.moisture = 0.42
	var stage := f.field_stage
	var snap := Save.snapshot()
	var pop := Village.population()
	var n_sites := Village.sites.size()
	w.new_game()
	await get_tree().process_frame
	check(Village.era == 1, "a new game is back in Era 1")
	Save.apply(JSON.parse_string(JSON.stringify(snap)))
	await get_tree().process_frame
	await get_tree().process_frame
	check(Village.era == 2 and Clock.day_seconds == 80.0, "the save comes back in Era 2, with Era 2 days")
	check(Village.population() == pop and Village.sites.size() == n_sites, "people and sites come back")
	var f2: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.is_field() and s.global_position.distance_to(f.global_position if is_instance_valid(f) else Vector3.ZERO) < 0.5:
			f2 = s
	if f2 == null:
		f2 = Village.sites.filter(func(s): return is_instance_valid(s) and s.is_field())[0]
	check(f2.field_stage == stage and absf(f2.moisture - 0.42) < 0.01, "fields keep their stage and moisture")
	check(w.is_region_open(&"hill_quarry") and w.era2.rockfall_cleared(), "the rockfall stays cleared")
	check(w.era2.bridge_built() and w.ground_y(150.0, 130.0) > 2.0, "the bridge deck is walkable again after loading")
	check(Flags.has(&"hand_symbol") and Flags.has(&"pottery"), "Era 2 flags save with the village")
	for s in _sites(&"camp"):
		print("  camp %s state %d uid %d" % [str(s.global_position.snapped(Vector3.ONE)), s.state, s.uid])
	check(_sites(&"camp").size() == 2, "the two camps come back once each (not twice)")
