class_name VillageEra2 extends Node
## Era 2 (Village) progression that is not a Village Dream (doc 4-8, 10):
##  - the people long for the far bank a few minutes in (flag far_bank_seen,
##    which lets the hand learn Reach);
##  - family wishes lay out plots one after another as the village grows into
##    its chains: fields and a well, mill then bakery, cottages when homes are
##    full, kiln once there is clay, charcoal and smelter once there is ore,
##    the smithy once there is bronze, sheep, loom and market, a barn when the
##    hand can lift eight, a watchtower once a bear has come;
##  - the raft: a crew of five launches it, and then two boats fish the river;
##  - the harvest festival (a group of 6+ at the fields after the harvests,
##    needed for the temple dream);
##  - discoveries: pottery (bigger stores), woven clothes (warmer winters),
##    bronze tools (+50% work);
##  - trust made visible: devoted people bring offerings to the shrine, and
##    once the village loves the hand it paints the hand on its doors.
## Everything is one-off and kept in Village.stats so it saves with Village.

const CHECK := 2.0
const FAR_BANK_AFTER := 200.0       # game seconds into the era
const MAX_COTTAGES := 14
const POTS_FOR_POTTERY := 4
const POTTERY_CAP := 30
const CLOTH_FOR_CLOTHES := 4
const TOOLS_FOR_BRONZE := 4
const FESTIVAL_FAITH := 20.0
const FESTIVAL_HARVESTS := 4
const OFFERING_RANGE := 80.0
const OFFERING_EVERY := 60.0
const MARKET_WANDERERS := 3

var _acc: float = 0.0
var _offer_t: float = 0.0

func _ready() -> void:
	name = "VillageEra2"
	Events.sim_tick.connect(_on_tick)
	Events.job_completed.connect(_on_job_completed)
	Events.building_finished.connect(_on_building_finished)
	Events.power_unlocked.connect(_on_power)
	Events.threat_started.connect(_on_threat)

func _on_tick(dt: float) -> void:
	if Village.era != 2:
		return
	_offer_t += dt
	_acc += dt
	if _acc < CHECK:
		return
	_acc = 0.0
	check_now()

func era_t() -> float:
	return Clock.total_t - float(Village.stats.get("era_started_t", 0.0))

func check_now() -> void:
	if Village.era != 2 or not Flags.onboarding_done():
		return
	_far_bank()
	_wishes()
	_bridge_yard()
	_low_river()
	_discoveries()
	_festival()
	_trust()

static func _w():
	var w = Game.world
	return w if w != null and is_instance_valid(w) else null

static func _wish(key: String, bid: StringName, line: String) -> Site:
	if Village.stats.get("wish_" + key, false):
		return null
	var w = VillageEra2._w()
	if w == null or not w.has_method("add_plot"):
		return null
	var s: Site = w.add_plot(bid)
	Village.stats["wish_" + key] = true
	if s != null and line != "":
		Events.alert.emit(line, s.global_position)
	return s

static func _count(bid: StringName, finished_only: bool = false) -> int:
	var n := 0
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == bid and (not finished_only or s.state == Site.State.FINISHED):
			n += 1
	return n

static func _has_plot(bid: StringName) -> bool:
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == bid and s.state != Site.State.FINISHED:
			return true
	return false

# ---------------------------------------------------------------- far bank

func _far_bank() -> void:
	if Flags.has(&"far_bank_seen") or era_t() < FAR_BANK_AFTER:
		return
	Flags.set_flag(&"far_bank_seen")
	Flags.remember("We stood on the river bank and looked across. Clay, and green stone in the rocks. We wanted the far bank.")
	var w = VillageEra2._w()
	var at: Vector3 = Vector3(150, 0, 112) if w == null else w._v3(Vector2(150, 112))
	Events.alert.emit("They gaze across the great river. They long for the far bank (Reach)", at)

## Once the bridge plot is laid, the builders pitch a yard on the near bank.
func _bridge_yard() -> void:
	if Village.stats.get("bridge_yard", false) or not _has_plot(&"bridge"):
		return
	var w = VillageEra2._w()
	if w == null:
		return
	Village.stats["bridge_yard"] = true
	var c: Vector2 = LayoutEra2.BRIDGE_YARD
	var yard: Site = w.spawn_plot(&"camp", Vector3(c.x, 0, c.y))
	if yard != null:
		yard._finish(true)
		Events.alert.emit("The builders pitch a camp by the river and stack wood and stone there for the bridge", yard.global_position)

## Winter: a raising that waits for its season says so once (the bridge piers).
func _low_river() -> void:
	var key := "season_told_%d_%d" % [Clock.year, Clock.season]
	if Village.stats.get(key, false):
		return
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.only_season == Clock.season and s.raise_parent != 0 and not s.group_running:
			Village.stats[key] = true
			Events.alert.emit("The river runs low. %d together can set the bridge piers now" % s.job.min_people, s.global_position)
			return

# ---------------------------------------------------------------- wishes

func _wishes() -> void:
	var t := era_t()
	_wish("fields", &"field", "The wild grain grows well here. They want to sow fields")
	if t > 20.0 and Village.stats.get("wish_fields", false):
		_wish("fields_2", &"field", "")
	if t > 150.0:
		_wish("well", &"well", "They want a well by the cottages")
	if int(Village.stats.get("harvests", 0)) >= 1 or t > 300.0:
		_wish("mill", &"mill", "Grain to grind. They want a mill")
	if _count(&"mill", true) > 0:
		_wish("bakery", &"bakery", "Flour and fire: they want an oven for bread")
		if t > 420.0:
			_wish("fields_3", &"field", "")
			_wish("fields_4", &"field", "")
	if Village.store(&"clay") >= 2 or (Village.stats.get("wish_kiln_force", false)):
		_wish("kiln", &"kiln", "Clay from the far bank. They want a kiln to fire pots")
	if Village.store(&"ore") >= 2:
		_wish("charcoal", &"charcoal_clamp", "They want a charcoal clamp: copper needs a hotter fire than wood")
		_wish("smelter", &"smelter", "Green stone from the far bank. They want a furnace to melt it")
	if Village.store(&"bronze") >= 2 or _count(&"smelter", true) > 0 and t > 900.0:
		_wish("smithy", &"smithy", "Bronze! They want a smithy to make tools")
	if t > 600.0:
		_wish("sheep", &"sheep_pen", "Wild sheep graze the Valley Floor. They want a pen for them")
	if _count(&"sheep_pen", true) > 0:
		_wish("weaver", &"weaver", "Wool to spin. They want a loom")
	if _count(&"weaver", true) > 0 and _count(&"kiln", true) > 0:
		_wish("market", &"market", "Pots and cloth to trade. They want a market")
	if Faith.has(&"grip_3"):
		_wish("barn", &"barn", "They want a great barn. It takes eight of them to raise it")
		_raft()
	if int(Village.stats.get("bears_seen", 0)) > 0 and Faith.has(&"reach"):
		_wish("watchtower", &"watchtower", "They want a watchtower on the far bank, to see the bears coming")
	_maybe_cottage()

## Another cottage when the homes are full (the Era 2 form of the Era 1 hut wish).
func _maybe_cottage() -> void:
	var room := 0
	var finished := 0
	for s in Village.sites:
		if not is_instance_valid(s) or s.building == null or s.building.id != &"cottage":
			continue
		if s.state != Site.State.FINISHED:
			return              # one cottage plot at a time
		finished += 1
		room += s.building.shelter
	if finished >= MAX_COTTAGES:
		return
	var homeless := 0
	var cramped := false
	for p in Village.alive():
		if p.home == null or not is_instance_valid(p.home) or (p.home.building != null and p.home.building.camp):
			homeless += 1
		if p.partner != 0 and p.sex == "f":
			var h = p.home
			if h == null or not is_instance_valid(h) or Births.home_residents(h) >= h.building.shelter:
				cramped = true
	if Village.population() + 2 <= room and not cramped and homeless == 0:
		return
	var w = VillageEra2._w()
	if w == null:
		return
	var s2: Site = w.add_plot(&"cottage")
	if s2 != null:
		Village.stats["cottage_wishes"] = int(Village.stats.get("cottage_wishes", 0)) + 1
		Events.alert.emit(PersonInfo.home_wish_line("cottage"), s2.global_position)   # [ui hook] names the pair

func _raft() -> void:
	if Village.stats.get("raft_site", false):
		return
	var w = VillageEra2._w()
	if w == null:
		return
	Village.stats["raft_site"] = true
	var s: Site = w.spawn_site(&"raft_launch", w._v3(LayoutEra2.RAFT))
	if s != null:
		Events.alert.emit("They have built a raft. Five of them can push it into the river", s.global_position)

func _on_job_completed(site) -> void:
	if not (site is Site) or not is_instance_valid(site) or site.job == null:
		return
	match site.job.id:
		&"raft_launch":
			if Flags.set_flag(&"raft"):
				var w = VillageEra2._w()
				if w != null:
					for b in LayoutEra2.BOATS:
						w.spawn_site(&"fish_boat", w._v3(b))
				Flags.remember("Five of us pushed the raft into the great river, and now we fish from boats.")
				Events.alert.emit("The raft is on the river! Now they fish from boats", site.global_position)
				site.remove_site.call_deferred()
		&"harvest_festival":
			if Flags.set_flag(&"harvest_festival"):
				Faith.add(FESTIVAL_FAITH, site.global_position)
				for p in Village.alive():
					p.needs[&"joy"] = 1.0
					p.adjust_trust(0.35)
				Flags.remember("The fields gave and gave. We danced among the sheaves at the harvest festival, and thanked the hand.")
				Events.alert.emit("The harvest festival! (+%d faith)" % int(FESTIVAL_FAITH), site.global_position)
				site.remove_site.call_deferred()

func _on_building_finished(site) -> void:
	if Village.era != 2 or not (site is Site) or not is_instance_valid(site) or site.building == null:
		return
	match site.building.id:
		&"granary":
			Flags.remember("We built a granary. The grain is safe from the damp and the mice.")
		&"market":
			if not Village.stats.get("market_wanderers", false):
				Village.stats["market_wanderers"] = true
				var ai = get_parent()
				if ai != null and "wanderers" in ai and ai.wanderers != null:
					ai.wanderers.arrive(MARKET_WANDERERS, &"")
			Flags.remember("Our first market day. Traders came down the valley, and some of them stayed.")
		&"bridge":
			Flags.remember("We raised the great bridge. Now the far bank is a walk away, and everyone sleeps at home.")
		&"temple":
			Flags.set_flag(&"hand_symbol")
			Flags.remember("We raised the Temple of the Hand where the old shrine stood, and painted the hand on its doors.")

## Onboarding for the new mechanics (doc 11): one line, once, at the moment it matters.
const POWER_HINTS := {
	&"reach": "Reach: the hand can carry people over the great river. Set a few down by the camp on the far bank",
	&"grip_3": "Grip III: drag across a crowd to scoop up five at once. Barns and the raft need big crews",
	&"rain": "Rain: select it, then hold E over a field. The Southern Plains are dry until the hand waters them",
	&"strength_2": "Strength II: the hand can lift a boulder. Clear the rockfall east of the Valley Floor",
}

static func hint(key: String, text: String, at: Vector3 = Vector3.INF) -> bool:
	if Village.stats.get("hint_" + key, false):
		return false
	Village.stats["hint_" + key] = true
	if at == Vector3.INF:
		Events.toast.emit(text)
	else:
		Events.alert.emit(text, at)
	return true

func _on_power(id: StringName) -> void:
	_acc = CHECK
	if POWER_HINTS.has(id):
		var w = VillageEra2._w()
		var at := Vector3.INF
		if w != null:
			match id:
				&"reach": at = w._v3(LayoutEra2.CAMPS[&"east_bank"])
				&"strength_2": at = w._v3(LayoutEra2.ROCKFALL)
				&"rain": at = w._v3(LayoutEra2.CAMPS[&"southern_plains"])
		VillageEra2.hint(str(id), POWER_HINTS[id], at)

func _on_threat(id: StringName, _at: Vector3) -> void:
	if id == &"bears":
		Village.stats["bears_seen"] = int(Village.stats.get("bears_seen", 0)) + 1

# ---------------------------------------------------------------- discoveries

func _discoveries() -> void:
	if not Flags.has(&"pottery") and Village.store(&"pots") >= POTS_FOR_POTTERY:
		Flags.set_flag(&"pottery")
		Village.store_cap += POTTERY_CAP
		Flags.remember("We fired pots in the kiln. Now we can keep more of everything.")
		Events.alert.emit("Pottery: sealed pots keep more in the stores (+%d each)" % POTTERY_CAP, Site.store_point(Vector3.ZERO))
	if not Flags.has(&"woven_clothes") and Village.store(&"cloth") >= CLOTH_FOR_CLOTHES:
		Village.take_store(&"cloth", CLOTH_FOR_CLOTHES)
		Flags.set_flag(&"woven_clothes")
		Flags.remember("We wove wool into cloth and made warm clothes. The winter bites less.")
		Events.alert.emit("They have woven wool clothes: the cold bites much less", Site.store_point(Vector3.ZERO))
	if not Flags.has(&"bronze_tools") and Village.store(&"tools") >= TOOLS_FOR_BRONZE:
		Village.take_store(&"tools", TOOLS_FOR_BRONZE)
		Flags.set_flag(&"bronze_tools")
		Flags.remember("The smith made bronze tools: sickles, hoes and axes. Everything goes faster.")
		Events.alert.emit("Bronze tools: gathering, crafting and farming are half again as fast", Site.store_point(Vector3.ZERO))

# ---------------------------------------------------------------- festival

func _festival() -> void:
	if Flags.has(&"harvest_festival") or Village.stats.get("harvest_festival_site", false):
		return
	if int(Village.stats.get("harvests", 0)) < FESTIVAL_HARVESTS or _count(&"granary", true) == 0:
		return
	var w = VillageEra2._w()
	if w == null:
		return
	Village.stats["harvest_festival_site"] = true
	var s: Site = w.spawn_site(&"harvest_festival", w._v3(LayoutEra2.FESTIVAL_SPOT))
	if s != null:
		Events.alert.emit("The granary is full. They want a harvest festival: six or more at the fields", s.global_position)

# ---------------------------------------------------------------- trust

func _trust() -> void:
	if not Flags.has(&"hand_symbol") and Trust.average() >= Trust.LOVE_AT:
		Flags.set_flag(&"hand_symbol")
		Flags.remember("We painted the hand over our doors, so it knows our houses.")
		Events.alert.emit("They have painted the hand over their doors", Site.store_point(Vector3.ZERO))
	if _offer_t >= OFFERING_EVERY:
		_offer_t = 0.0
		bring_offering()

## One devoted person (trust 4+) who is free walks to the shrine with a gift.
static func bring_offering() -> bool:
	var shrine := Site.nearest_shrine(Vector3.ZERO)
	if shrine == null or Clock.is_night:
		return false
	var best: Person = null
	var best_v := -INF
	for p in Village.alive():
		if p.trust < 4 or p.stage != Person.Stage.ADULT or not (p.state == Person.S.IDLE or p.state == Person.S.WORK):
			continue
		if p.state == Person.S.WORK and (p.job_site == null or not is_instance_valid(p.job_site) or p.job_site.is_group() or p.job_site.is_plot()):
			continue
		var d: float = p.global_position.distance_to(shrine.global_position)
		if d > OFFERING_RANGE:
			continue
		var v: float = p.trust_f - d / 30.0         # the devoted, and near enough to walk over
		if v > best_v:
			best_v = v
			best = p
	return best != null and best.bring_offering(shrine)
