class_name Progression extends Node
## The rest of Era 1's progression that is not a Village Dream (doc 4-8):
##  - discoveries: stone tools after the first knapped stone (+25% gathering,
##    felling trees), hide clothes after the first hunts (less cold in winter);
##  - family wishes that lay out plots: another hut when homes are full, a food
##    store before the first winter, a drying rack after the first hunt;
##  - what Blessing opens: the first festival at the fire circle (+15 faith)
##    and the great elk hunt in the Valley Floor (only the blessed can win it);
##  - faith for a night or season survived with no losses (+5);
##  - names the hand gives (Events.names_given).

const CHECK := 2.0
const STONE_FOR_TOOLS := 4
const HIDES_FOR_CLOTHES := 3
const MAX_HUTS := 6
const FESTIVAL_FAITH := 15.0
const SURVIVED_FAITH := 5.0
const FESTIVAL_SPOT_OFFSET := Vector3(0, 0, 4.5)
const ELK_SPOT := Vector2(78.0, -6.0)

var _acc: float = 0.0
var _threat_deaths: Dictionary = {}     # threat id -> deaths + bites when it began

func _ready() -> void:
	name = "Progression"
	Events.sim_tick.connect(_on_tick)
	Events.job_completed.connect(_on_job_completed)
	Events.power_unlocked.connect(_on_power)
	Events.building_finished.connect(func(_s): _acc = CHECK)
	Events.threat_started.connect(_on_threat_started)
	Events.threat_warned.connect(_on_threat_started)
	Events.threat_ended.connect(_on_threat_ended)
	Events.names_given.connect(apply_names)
	Events.name_requested.connect(_on_name_requested)

## Remembers each person's generated name, so a UI that writes given_name
## directly still lets us tell "renamed" from "kept the generated name".
func _on_name_requested(people: Array, _reason: StringName) -> void:
	for p in people:
		if is_instance_valid(p) and p is Person:
			p.set_meta("generated_name", p.given_name)

func _on_tick(dt: float) -> void:
	_acc += dt
	if _acc < CHECK:
		return
	_acc = 0.0
	check_now()

func check_now() -> void:
	if not Flags.onboarding_done():
		return
	_discoveries()
	_family_plots()
	_blessing_sites()

# ---------------------------------------------------------------- discoveries

func _discoveries() -> void:
	if not Flags.has(&"stone_tools") and int(Village.stats.get("stone_knapped", 0)) >= STONE_FOR_TOOLS:
		Flags.set_flag(&"stone_tools")
		Flags.remember("We learned to make stone tools. Now we gather faster, and we can fell trees.")
		Events.alert.emit(PersonInfo.discovery_line(&"stone_tools"), _at_stash())   # [ui hook] says who and why
	if not Flags.has(&"hide_clothes") and Village.store(&"hide") >= HIDES_FOR_CLOTHES:
		Village.take_store(&"hide", HIDES_FOR_CLOTHES)
		Flags.set_flag(&"hide_clothes")
		Flags.remember("We sewed clothes from the hides of the hunt, and the winter bit less.")
		Events.alert.emit(PersonInfo.discovery_line(&"hide_clothes"), _at_stash())   # [ui hook]

func _on_job_completed(site) -> void:
	if not (site is Site) or not is_instance_valid(site) or site.job == null:
		return
	match site.job.id:
		&"knap_flint":
			Village.stats["stone_knapped"] = int(Village.stats.get("stone_knapped", 0)) + 1
		&"hunt":
			if Flags.set_flag(&"first_hunt"):
				Flags.remember("Four of us hunted together for the first time, and the hand carried us there.")
		&"festival":
			if Flags.set_flag(&"festival"):
				Faith.add(FESTIVAL_FAITH, site.global_position)
				for p in Village.alive():
					p.needs[&"joy"] = 1.0
					p.adjust_trust(0.3)
				Flags.remember("The hand blessed us and we danced at the fire all night. Our first festival.")
				Events.alert.emit("The first festival! The people dance at the fire (+%d faith)" % int(FESTIVAL_FAITH), site.global_position)
		&"great_elk_hunt":
			if Flags.set_flag(&"great_elk"):
				Flags.remember("Blessed by the hand, our hunters brought down the great elk.")
				Events.alert.emit("The blessed hunters brought down the great elk", site.global_position)

# ---------------------------------------------------------------- plots

## Family wishes: plots appear when the people want them (doc 4, Build).
func _family_plots() -> void:
	if Dreams.is_done(&"shelter_of_our_own") or str(Village.stats.get("dream_active", "")) != "":
		_maybe_hut()
	# Stores and racks are family wishes for after the first shelter: they must
	# not take the wood the first dream needs.
	if not Dreams.is_done(&"shelter_of_our_own"):
		return
	if not Village.stats.get("wish_food_store", false) and _dreaming_started():
		var autumn := Clock.season == Clock.Season.AUTUMN or Clock.year > 1
		if autumn or Village.food() >= Village.store_cap - 4:
			Village.stats["wish_food_store"] = true
			var s := _add_plot(&"food_store")
			if s != null:
				Events.alert.emit("Winter is coming. They want a store to keep food in", s.global_position)
	if not Village.stats.get("wish_drying_rack", false) and Flags.has(&"first_hunt"):
		Village.stats["wish_drying_rack"] = true
		var r := _add_plot(&"drying_rack")
		if r != null:
			Events.alert.emit("They want a rack to dry the meat for winter", r.global_position)

func _dreaming_started() -> bool:
	return Dreams.done_list().size() > 0 or str(Village.stats.get("dream_active", "")) != ""

## Another hut when the homes are full: a family wish ("We need a bigger home").
func _maybe_hut() -> void:
	var finished := 0
	var room := 0
	for s in Village.sites:
		if not is_instance_valid(s) or s.building == null or s.building.id != &"hut":
			continue
		if s.is_plot():
			return            # one hut plot at a time
		finished += 1
		room += s.building.shelter
	if finished == 0 or finished >= MAX_HUTS:
		return
	# a bonded pair with no room of its own wants a home too
	var cramped := false
	for p in Village.alive():
		if p.partner != 0 and p.sex == "f":
			var h = p.home
			if h == null or not is_instance_valid(h) or Births.home_residents(h) >= h.building.shelter:
				cramped = true
	if Village.population() + 1 <= room and not cramped:
		return
	var s2 := _add_plot(&"hut")
	if s2 != null:
		Events.alert.emit(PersonInfo.home_wish_line("home"), s2.global_position)   # [ui hook] names the pair

func _add_plot(bid: StringName) -> Site:
	var w = Game.world
	if w == null or not is_instance_valid(w) or not w.has_method("add_plot"):
		return null
	return w.add_plot(bid)

# ---------------------------------------------------------------- blessing

func _on_power(id: StringName) -> void:
	if id == &"blessing":
		_acc = CHECK
		Flags.remember("The hand learned to bless us.")

func _blessing_sites() -> void:
	if not Faith.has(&"blessing"):
		return
	var w = Game.world
	if w == null or not is_instance_valid(w) or not w.has_method("spawn_site"):
		return
	if not Flags.has(&"festival") and not Village.stats.get("festival_site", false):
		var circle := _finished(&"fire_circle")
		if circle != null:
			Village.stats["festival_site"] = true
			var s: Site = w.spawn_site(&"festival", circle.global_position + FESTIVAL_SPOT_OFFSET)
			if s != null:
				Events.alert.emit("They want to dance at the fire. Bless the dancers with the hand", s.global_position)
	if not Flags.has(&"great_elk") and not Village.stats.get("elk_site", false) and w.is_region_open(&"valley_floor"):
		Village.stats["elk_site"] = true
		var e: Site = w.spawn_site(&"great_elk_hunt", Vector3(ELK_SPOT.x, 0, ELK_SPOT.y))
		if e != null:
			Events.alert.emit("A great elk in the Valley Floor. Only blessed hunters can bring it down", e.global_position)

func _finished(bid: StringName) -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and s.is_finished_building(bid):
			return s
	return null

# ---------------------------------------------------------------- survived

func _losses() -> int:
	return int(Village.stats.get("deaths", 0)) * 10 + int(Village.stats.get("wolf_bites", 0)) \
		+ int(Village.stats.get("bear_swipes", 0)) + int(Village.stats.get("flood_hurt", 0)) + int(Village.stats.get("crops_lost", 0))

func _on_threat_started(id: StringName, _at: Vector3) -> void:
	if not _threat_deaths.has(id):
		_threat_deaths[id] = _losses()

func _on_threat_ended(id: StringName) -> void:
	if not _threat_deaths.has(id):
		return
	var before := int(_threat_deaths[id])
	_threat_deaths.erase(id)
	if _losses() == before and Village.population() > 0:
		Faith.add(SURVIVED_FAITH, _at_stash())
		var what: String = {&"wolves": "the wolves' night", &"cold_snap": "the cold snap", &"first_winter": "the winter",
			&"drought": "the drought", &"crop_blight": "the blight", &"bears": "the bear", &"flood": "the flood"}.get(id, "it")
		Events.toast.emit("Everyone came through %s (+%d faith)" % [what, int(SURVIVED_FAITH)])

# ---------------------------------------------------------------- names

## Events.names_given: each entry is a Person whose given_name the UI already
## set, a {"person": p, "name": s} dictionary, or [p, name]. An empty name keeps
## the generated one ("keep generated names").
func apply_names(entries: Array) -> void:
	for e in entries:
		var p = null
		var n := ""
		if e is Person:
			p = e
			n = e.given_name
		elif e is Dictionary:
			p = e.get("person", e.get("p", null))
			n = str(e.get("name", ""))
		elif e is Array and e.size() >= 2:
			p = e[0]
			n = str(e[1])
		if p == null or not is_instance_valid(p) or not (p is Person):
			continue
		var before: String = p.get_meta("generated_name", p.given_name)
		if n.strip_edges() == "" or n.strip_edges() == before:
			p.given_name = before       # keep the generated name
			if p.stage == Person.Stage.BABY and p.get_meta(&"named_by_hand", false):
				p.named_by_hand = true  # a prayed-for name is the hand's, even if kept
				Flags.remember("We prayed and the hand named our baby %s." % p.given_name)
			continue
		p.set_name_from_hand(n)
		if p.first_two:
			Flags.remember("The hand named us on the first night: %s." % p.given_name)
		elif p.stage == Person.Stage.BABY:
			Flags.remember("We prayed and the hand named our baby %s." % p.given_name)
		if before != p.given_name:
			print("names: %s is now %s" % [before, p.given_name])

func _at_stash() -> Vector3:
	return Site.store_point(Vector3.ZERO)
