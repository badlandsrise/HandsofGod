extends Node
## Cases for tests/unit/test_onboarding.gd.

signal done(fails: int)

var fails := 0
var w: Node3D
var named: Array = []          # [people, reason] from Events.name_requested
var dreams_started: Array = []
var joined := 0

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

## Waits (real frames, sped-up game time) until `cond` holds or `real_s` passes.
func _until(cond: Callable, real_s: float = 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > real_s:
			return false
		await get_tree().process_frame
	return true

func _beat() -> int:
	return Flags.beat()

func run() -> void:
	Save.enabled = false
	Events.name_requested.connect(func(people, reason): named.append([people, reason]))
	Events.dream_started.connect(func(id): dreams_started.append(id))
	Events.person_joined.connect(func(_p): joined += 1)
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await get_tree().process_frame
	Game.flags["test"] = true      # after the world's _ready (no bot): the naming card auto-accepts instead of pausing
	w.new_game()
	w.start_play()
	Engine.time_scale = 10.0
	await _onboarding()
	Engine.time_scale = 1.0
	Clock.running = false
	await _rules()
	w.queue_free()
	await get_tree().process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)

# ---------------------------------------------------------------- the beats

func _onboarding() -> void:
	var hand = w.hand
	check(_beat() == Onboarding.Beat.STORM and w.storm.active(), "a new game opens on the storm beat")
	check(Village.population() == 2, "two people at the start")
	var two: Array = Village.alive()
	check(two.all(func(p): return p.first_two) and two[0].sex != two[1].sex and two.all(func(p): return p.given_name == LayoutEra1.NAMES_BY_SEX[p.sex]), "the first two are a pair, named to match")
	check(Village.sites.all(func(s): return s.job == null or s.job.id != &"carry_log"), "no fire log before the berries")
	await get_tree().create_timer(0.5).timeout
	check(_beat() == Onboarding.Beat.STORM, "the storm holds until the branch is lifted")
	# 0-1 min: lift the branch away
	check(hand.try_lift_object(w.branch), "the hand lifts the storm branch")
	hand.place_object(w.branch.global_position + Vector3(6, 0, 3))
	check(await _until(func(): return _beat() >= Onboarding.Beat.BERRIES, 30.0), "dawn comes after the branch is moved")
	check(not named.is_empty() and named[0][1] == &"first_two" and (named[0][0] as Array).size() == 2, "dawn asks the UI to name the first two")
	# names: one renamed, one kept
	var p0: Person = named[0][0][0]
	var p1: Person = named[0][0][1]
	var kept_name: String = p1.given_name
	Events.names_given.emit([{"person": p0, "name": "Asha"}, p1])
	check(p0.given_name == "Asha" and p0.named_by_hand, "names_given renames a person, with the hand mark")
	check(p1.given_name == kept_name and not p1.named_by_hand, "an unchanged name keeps the generated one")
	# 1-3 min: one of them points at the berries
	check(p0.wish == &"gather_berries", "%s points at the berry bushes" % p0.given_name)
	var bush: Site = Site.nearest(p0.global_position, 60.0, func(s): return s.job != null and s.job.id == &"gather_berries")
	await _until(func(): return p0.pickable(), 10.0)
	check(hand.try_lift(p0) and hand.place_on_site(bush) == 1, "the hand places them on the bush")
	check(await _until(func(): return _beat() >= Onboarding.Beat.FIRE_LOG, 90.0), "berries reach the store, then the fire log appears")
	# 3-5 min: a log for the fire needs two carriers, placed one after the other
	var log_site: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"carry_log":
			log_site = s
	check(log_site != null and log_site.job.min_people == 2 and Faith.grip == 1, "the fire log needs two carriers with a grip of 1")
	if log_site == null:
		return
	await _until(func(): return p0.pickable() and p1.pickable(), 10.0)
	check(hand.try_lift(p0) and not hand.try_lift(p1), "grip 1 lifts one at a time")
	hand.place_on_site(log_site)
	check(log_site.group_needs() >= 1 and not log_site.group_running, "one carrier waits for the second")
	await get_tree().create_timer(0.4).timeout
	check(hand.try_lift(p1) and hand.place_on_site(log_site) == 1, "then the second is placed within the wait")
	check(await _until(func(): return _beat() >= Onboarding.Beat.FIRE_LIT, 60.0), "the log reaches the fire")
	check(w.fire_lit(), "they light the fire")
	# 5-8 min: the first gift, Grip II and the scoop hint
	check(await _until(func(): return _beat() >= Onboarding.Beat.GIFT, 20.0), "then they leave a gift")
	var gifts := get_tree().get_nodes_in_group("gift")
	check(gifts.size() == 1 and gifts[0].grants_power == &"grip_2" and gifts[0].kind == "handprint stone", "the first gift is a handprint stone that grants Grip II")
	check(Village.stats.get("dream_active", "") == "" and dreams_started.is_empty(), "no dream before the gift")
	var hints: Array = []
	Events.toast.connect(func(t): hints.append(t))
	check(gifts.size() > 0 and hand.collect_gift(gifts[0]) and Faith.has(&"grip_2") and Faith.grip == 3 and Faith.total > 0.0, "picking it up gives faith and Grip II")
	check(hints.any(func(t): return str(t).to_lower().contains("scoop")), "with a one-time scoop hint")
	# 8-10 min: the first dream and a wanderer
	check(await _until(func(): return _beat() >= Onboarding.Beat.DONE, 120.0), "the onboarding finishes")
	check(dreams_started.size() >= 1 and dreams_started[0] == &"shelter_of_our_own", "the first dream: a shelter of our own")
	check(joined == 1 and Village.population() == 3, "a third person wanders in")
	var bt: Dictionary = Village.stats.get("beat_times", {})
	var order_ok := true
	var last := -1.0
	for k in Onboarding.NAMES:
		if not bt.has(k) or float(bt[k]) < last:
			order_ok = false
		last = float(bt.get(k, last))
	check(order_ok, "every beat happened, in order: %s" % str(bt))
	check(w.ensure_plots_for_dream(&"shelter_of_our_own") == 0 and Village.sites.any(func(s): return s.building != null and s.building.id == &"fire_circle"), "the dream laid out a hut and a fire circle")

# ---------------------------------------------------------------- era 1 rules

func _rules() -> void:
	# Power prerequisites: Strength I waits for the Valley Floor (doc 6 faith budget)
	Faith.total = 500.0
	check(not Faith.can_buy(&"strength_1"), "Strength I can't be bought before the Valley Floor opens")
	Village.open_region(&"valley_floor")
	check(not Faith.can_buy(&"strength_1"), "nor before the first shelter is built")
	Village.stats["dreams_done"] = ["shelter_of_our_own"]
	check(Faith.can_buy(&"strength_1"), "and can once both are done")
	check(not Faith.can_buy(&"blessing"), "Blessing waits for the shrine dream")
	# Dreams: winters and flags
	var sc := Defs.dream(&"stone_circle")
	check(sc.gate and sc.needs_population == 12 and Dreams.winters_needed(sc) == 2 and sc.needs_flags.has(&"festival"), "the Stone Circle gate needs 12 people, two winters and the festival")
	check(Defs.era(1).dreams.size() == 3 and Defs.era(2).playable and Defs.era(2).dreams.size() == 3, "three Era 1 milestones, three Era 2 dreams")
	# The evergreen safety net only works in a crisis
	var ever: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.evergreen:
			ever = s
	check(ever != null, "the cave bushes are evergreen")
	if ever != null:
		Clock.season = Clock.Season.WINTER
		Village.stores.clear()
		Village.stores[&"meat"] = 40
		check(not ever.can_work_now(), "with food in store, winter stops even the cave bushes")
		Village.stores.clear()
		ever.amount = 0
		check(ever.can_work_now() and ever.take_one(), "with no food they never run dry, even in winter")
		Clock.season = Clock.Season.SPRING
	# The great elk hunt: only blessed hunters make progress
	Faith.grant(&"warmth")
	Village.stats["dreams_done"] = ["shelter_of_our_own", "shrine_to_the_hand"]
	Faith.buy(&"blessing")
	var elk: Site = w.spawn_site(&"great_elk_hunt", Vector3(0, 0, 8))
	var hunters: Array = []
	for i in 5:
		var p: Person = w.spawn_person(elk.slot_position(i))
		hunters.append(p)
		p.join(elk, false)
		p.global_position = elk.slot_position(elk.slot_of(p))
	elk.sim(0.1)
	check(elk.group_running, "five hunters start the great elk hunt")
	elk.sim(3.0)
	check(elk.progress == 0.0, "unblessed hunters make no progress")
	var n := HandPowers.bless_at(elk.global_position)
	elk.sim(3.0)
	check(n >= 5 and elk.progress > 0.0, "blessed by the hand, they close in on the elk")
	# Warmth over the fire warms everyone near it and feeds it
	var cold: Person = hunters[0]
	cold.needs[&"warmth"] = 0.1
	check(HandPowers.warm_at(cold.global_position) >= 1 and cold.needs[&"warmth"] > 0.3, "the Warmth gesture warms people")
	# Homes: a bonded pair takes a hut's places before single adults
	for s2 in Village.sites:
		if is_instance_valid(s2) and s2.is_shelter():
			s2.queue_free()
	await get_tree().process_frame
	var hut: Site = w.spawn_plot(&"hut", Vector3(10, 0, -3.5))
	hut.start_finished = true
	hut._finish(false)
	for p in Village.alive():
		p.home = null
		p.partner = 0
	var fa: Person = hunters[0]
	var fb: Person = hunters[1]
	fa.sex = "f"; fb.sex = "m"
	for i in range(2, 5):
		hunters[i].home = hut
	fa.partner = fb.uid; fb.partner = fa.uid
	Births.assign_homes()
	check(fa.home == hut and fb.home == hut and Births.home_residents(hut) <= hut.building.shelter, "a bonded pair gets the hut before single adults")
	# Baby prayer: the first baby after the shrine prays for a name
	var shrine: Site = w.spawn_plot(&"shrine", Vector3(6.5, 0, -22.5))
	shrine.start_finished = true
	shrine._finish(true)
	var births: Births = w.village_ai.births
	var mum: Person = hunters[1]
	var baby: Person = w.spawn_person(mum.global_position, "", {"age": 0.0, "parents": [mum.uid]})
	named.clear()
	check(births.maybe_pray_for_name(baby, mum), "a new baby's parent goes to pray for a name")
	births._update_prayers(Births.PRAYER_WAIT + 1.0)
	check(named.size() == 1 and named[0][1] == &"baby_prayer" and named[0][0][0] == baby, "the prayer asks the UI to name the baby")
	# Era complete: Village.era changes only after the transition
	var shown: Array = []
	Events.era_complete_shown.connect(func(e): shown.append(e))
	Clock.running = true
	Village.stats["dream_active"] = "stone_circle"
	Dreams.complete(sc)
	check(Village.era == 1 and w.village_ai.era_transition.running, "the gate starts the era transition, still in Era 1")
	check(await _until(func(): return not shown.is_empty(), 15.0), "the transition ends with era_complete_shown")
	check(Village.era == 2 and shown == [1] and not Village.stats.get("free_mode", false), "then Village.era is 2, and it is playable")
	check(Clock.season == Clock.Season.SPRING, "Era 2 opens in spring")
	var summ: Dictionary = (Village.stats.get("era_summary", {}) as Dictionary).get("1", {})
	check(summ.has("population") and summ.has("faith_earned") and summ.has("minutes"), "the Era 1 card has its numbers")
	check(Dreams.active_dream() != null and Dreams.active_dream().id == &"granary", "the first Era 2 dream is the granary")
	var changes: Array = []
	Events.era_changed.connect(func(e): changes.append(e))
	w.begin_era(2)
	check(Village.era == 2 and changes.is_empty(), "the era card's Continue after the transition does not advance twice")
	# Difficulty scales cold, wolves and food
	Game.options["difficulty"] = "harsh"
	var harsh := [Flags.diff_k(&"cold"), Flags.diff_k(&"wolves"), Flags.diff_k(&"food")]
	Game.options["difficulty"] = "gentle"
	var gentle := [Flags.diff_k(&"cold"), Flags.diff_k(&"wolves"), Flags.diff_k(&"food")]
	Game.options["difficulty"] = "normal"
	check(harsh.all(func(k): return k > 1.0) and gentle.all(func(k): return k < 1.0) and Flags.diff_k(&"cold") == 1.0, "difficulty scales cold, wolves and hunger")
	var ln := LayoutEra1.NAMES_BY_SEX
	check(ln["f"] != ln["m"] and Names.LISTS[1]["f"].has(ln["f"]), "the first two's default names match their sex")
	Clock.running = false
