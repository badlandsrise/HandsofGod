class_name VillageEra2 extends Node
## Era 2 (Village) progression that is not a Village Dream (doc 4-8, 10):
##  - the people long for the far bank a few minutes in (flag far_bank_seen,
##    which lets the hand learn Strong Arms); Strong Arms lays the footbridge
##    plot over the shallows by the bridge yard and two great timbers the hand
##    carries to it; a crew raises it from wood, and the East Bank (later the
##    Plains) is a walk away (world.add_crossing, world.drops.allow_region);
##  - suggestions: one suggested plot at a time (calmer than Era 1's rush), as
##    the village grows into its chains: the farmhouse (whose crew farms the
##    fields round it), a well, mill then bakery, kiln once there is clay,
##    charcoal and smelter once there is ore, the smithy once there is bronze,
##    sheep, loom and market, more fields, a barn when the hand can lift eight,
##    a farmhouse on the Plains once it rains there, a watchtower at the quarry
##    once the bears have come; cottages when homes are full (their own queue);
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
## The footbridge (Strong Arms): over the great river's shallows east of the
## bridge yard, landing on the East Bank by its camp (x > 140: the East Bank,
## not the Plains). Its timbers lie by the yard for the hand to carry over.
const FOOTBRIDGE := Vector2(164.0, 128.0)
const TIMBER_PILE: Array[Vector2] = [Vector2(156.0, 101.0), Vector2(160.0, 104.5)]
const CROSSING_ID := &"east_footbridge"
## Suggestions: one at a time, at least this far apart; a suggestion nobody has
## started stops holding up the next one after SUGGEST_HOLD.
const SUGGEST_GAP := 75.0
const SUGGEST_HOLD := 240.0
const FARMHOUSE_SPOTS: Array[Vector2] = [Vector2(-22.0, 67.0)]
const PLAINS_FARMHOUSE := Vector2(-18.0, 154.0)
const QUARRY_TOWER := Vector2(228.0, -88.0)
const MORE_FIELDS := 4             # fields a farmhouse grows to (2 at first)
## Suggestions a dream waits on skip the one-at-a-time queue (the great
## bridge needs bronze: the charcoal clamp and the smelter).
const URGENT: Array[String] = ["charcoal", "smelter"]

var _acc: float = 0.0
var _offer_t: float = 0.0
var _synced: bool = false

func _ready() -> void:
	name = "VillageEra2"
	Events.sim_tick.connect(_on_tick)
	Events.job_completed.connect(_on_job_completed)
	Events.building_finished.connect(_on_building_finished)
	Events.power_unlocked.connect(_on_power)
	Events.threat_started.connect(_on_threat)
	Events.region_opened.connect(_on_region)

func _on_tick(dt: float) -> void:
	if not _synced and Village.era >= 2:
		_synced = true
		sync_footbridge()
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
	_den_lures()
	_far_bank()
	_suggest()
	_maybe_cottage()
	if Faith.has(&"grip_3"):
		_raft()
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

# ---------------------------------------------------------------- the wolves' den

## Era 2 has no wolf raids: the wolves keep to their den in the far west of the
## Western Meadow (Wolves.may_come). Good timber and berries grow by it, so
## sending people there is a choice with a risk.
const DEN_LURES := [[&"fell_tree", -132.0, -28.0], [&"fell_tree", -138.0, -52.0], [&"rich_berries", -128.0, -44.0]]

func _den_lures() -> void:
	if Village.stats.get("den_lures", false):
		return
	var w = VillageEra2._w()
	if w == null or not w.has_method("spawn_site"):
		return
	Village.stats["den_lures"] = true
	for row in DEN_LURES:
		var s: Site = w.spawn_site(row[0], Vector3(float(row[1]), 0, float(row[2])))
		if s != null:
			s.set_meta("layout_tag", "wolf_den")

# ---------------------------------------------------------------- far bank

func _far_bank() -> void:
	if Flags.has(&"far_bank_seen") or era_t() < FAR_BANK_AFTER:
		return
	Flags.set_flag(&"far_bank_seen")
	Flags.remember("We stood on the river bank and looked across. Clay, and green stone in the rocks. We wanted the far bank.")
	var w = VillageEra2._w()
	var at: Vector3 = Vector3(150, 0, 112) if w == null else w._v3(Vector2(150, 112))
	Events.alert.emit("They gaze across the great river. They long for the far bank (Strong Arms)", at)

## Once the bridge plot is laid, the builders pitch a yard on the near bank.
func _bridge_yard() -> void:
	if Village.stats.get("bridge_yard", false) or not (_has_plot(&"bridge") or _has_plot(&"footbridge")):
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

# ---------------------------------------------------------------- suggestions

## Lays the next suggested plot, if the last one is under way (or has waited
## long enough) and SUGGEST_GAP has passed. Returns it (or null).
func _suggest() -> Site:
	var now := Clock.total_t
	# what the dream is waiting on (the bridge's bronze) jumps the queue
	for row in suggestions():
		if URGENT.has(row[0]):
			var u: Site = _lay(row)
			if u != null:
				return u
	if now - float(Village.stats.get("suggest_t", -1.0e9)) < SUGGEST_GAP:
		return null
	for s in Village.sites:
		if is_instance_valid(s) and s.has_meta(&"suggested") and s.state == Site.State.PLOT \
				and now - float(s.get_meta(&"suggested")) < SUGGEST_HOLD:
			return null
	for row in suggestions():
		var s2: Site = _lay(row)
		if s2 != null:
			return s2
	return null

## [key, building id, line] for every suggestion that is due now, in order.
func suggestions() -> Array:
	var t := era_t()
	var out: Array = []
	var harvests := int(Village.stats.get("harvests", 0))
	if t > 15.0:
		out.append(["farmhouse", &"farmhouse", "The wild grain grows well here. They want a farmhouse: its farmers will sow and reap the fields round it"])
	if t > 150.0:
		out.append(["well", &"well", "They want a well by the cottages"])
	if harvests >= 1 or t > 300.0:
		out.append(["mill", &"mill", "Grain to grind. They want a mill"])
	if _count(&"mill", true) > 0:
		out.append(["bakery", &"bakery", "Flour and fire: they want an oven for bread"])
	if Village.store(&"clay") >= 2 or Village.stats.get("wish_kiln_force", false):
		out.append(["kiln", &"kiln", "Clay from the far bank. They want a kiln to fire pots"])
	if Village.store(&"ore") >= 2 or (_has_plot(&"bridge") and Flags.has(&"footbridge")):
		out.append(["charcoal", &"charcoal_clamp", "They want a charcoal clamp: copper needs a hotter fire than wood"])
		out.append(["smelter", &"smelter", "Green stone from the far bank. They want a furnace to melt it"])
	if Village.store(&"bronze") >= 2 or _count(&"smelter", true) > 0 and t > 900.0:
		out.append(["smithy", &"smithy", "Bronze! They want a smithy to make tools"])
	var farm := VillageEra2._farm()
	if harvests >= 2 and farm != null and Workplace.field_count(farm) < MORE_FIELDS:
		out.append(["more_fields_%d" % Workplace.field_count(farm), &"field", "The farmers want another field by the farmhouse"])
	if t > 600.0:
		out.append(["sheep", &"sheep_pen", "Wild sheep graze the Valley Floor. They want a pen for them"])
	if _count(&"sheep_pen", true) > 0:
		out.append(["weaver", &"weaver", "Wool to spin. They want a loom"])
	if _count(&"weaver", true) > 0 and _count(&"kiln", true) > 0:
		out.append(["market", &"market", "Pots and cloth to trade. They want a market"])
	if Faith.has(&"grip_3"):
		out.append(["barn", &"barn", "They want a great barn. It takes eight of them to raise it"])
	var w = VillageEra2._w()
	if w != null and w.is_region_open(&"southern_plains"):
		out.append(["plains_farm", &"farmhouse", "Rain on the Plains! They want a farmhouse out there for the big fields"])
	if int(Village.stats.get("bears_seen", 0)) > 0 and w != null and w.is_region_open(&"hill_quarry"):
		out.append(["watchtower", &"watchtower", "They want a watchtower over the quarry, to see the bears coming"])
	return out

## Lays one suggestion (once per key); null when it is done or has no room.
func _lay(row: Array) -> Site:
	var key: String = row[0]
	if Village.stats.get("wish_" + key, false):
		return null
	var w = VillageEra2._w()
	if w == null or not w.has_method("add_plot"):
		return null
	var s: Site = null
	if key == "farmhouse":
		s = _plot_at(&"farmhouse", FARMHOUSE_SPOTS)
	elif key == "plains_farm":
		s = _plot_at(&"farmhouse", [PLAINS_FARMHOUSE], false)
	elif key == "watchtower":
		s = _plot_at(&"watchtower", [QUARRY_TOWER], false)
	elif key.begins_with("more_fields"):
		var farm := VillageEra2._farm()
		if farm == null or Workplace.lay_fields(farm, 1) <= 0:
			return null
		s = VillageEra2._newest(&"field")
	else:
		s = w.add_plot(row[1])
	Village.stats["wish_" + key] = true
	if s == null:
		return null
	s.set_meta(&"suggested", Clock.total_t)
	Village.stats["suggest_t"] = Clock.total_t
	Village.stats["suggestions"] = int(Village.stats.get("suggestions", 0)) + 1
	if str(row[2]) != "":
		Events.alert.emit(str(row[2]), s.global_position)
	return s

## A plot for `bid` at the world's authored spot for it (when it has one) or
## the first free spot of `spots`.
func _plot_at(bid: StringName, spots: Array, authored_first: bool = true) -> Site:
	var w = VillageEra2._w()
	var cands: Array = []
	if authored_first and w.has_method("plot_spots"):
		cands.append_array(w.plot_spots(bid))
	cands.append_array(spots)
	for c in cands:
		var at := Vector3(c.x, 0, c.y)
		if w.has_method("_spot_taken") and w._spot_taken(bid, at):
			continue
		return w.spawn_plot(bid, at)
	return null

## The first finished farmhouse.
static func _farm() -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and s.is_workplace() and s.building.id == &"farmhouse":
			return s
	return null

static func _newest(bid: StringName) -> Site:
	for i in range(Village.sites.size() - 1, -1, -1):
		var s = Village.sites[i]
		if is_instance_valid(s) and s.building != null and s.building.id == bid:
			return s
	return null

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
		Events.alert.emit("A family wants a cottage of their own", s2.global_position)

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
		&"footbridge":
			Flags.set_flag(&"footbridge")
			sync_footbridge()
			var w = VillageEra2._w()
			if w != null and not w.is_region_open(&"east_bank"):
				w.open_region(&"east_bank")
			Flags.remember("The hand carried two great timbers to the shallows, and we raised a footbridge on them. We walked to the far bank and back.")
			Events.alert.emit("The footbridge is up: the East Bank is a walk away", site.global_position)
		&"temple":
			Flags.set_flag(&"hand_symbol")
			Flags.remember("We raised the Temple of the Hand where the old shrine stood, and painted the hand on its doors.")

## Onboarding for the new mechanics (doc 11): one line, once, at the moment it matters.
const POWER_HINTS := {
	&"strong_arms": "Strong Arms: the hand can carry a bridge timber. Set both timbers on the footbridge plot by the bridge yard",
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
	if id == &"strong_arms":
		lay_footbridge()
	if POWER_HINTS.has(id):
		var w = VillageEra2._w()
		var at := Vector3.INF
		if w != null:
			match id:
				&"strong_arms": at = w._v3(FOOTBRIDGE)
				&"strength_2": at = w._v3(LayoutEra2.ROCKFALL)
				&"rain": at = w._v3(LayoutEra2.CAMPS[&"southern_plains"])
		VillageEra2.hint(str(id), POWER_HINTS[id], at)

func _on_threat(id: StringName, _at: Vector3) -> void:
	if id == &"bears":
		Village.stats["bears_seen"] = int(Village.stats.get("bears_seen", 0)) + 1

# ---------------------------------------------------------------- footbridge

## Strong Arms: the footbridge plot over the shallows and its two timbers by
## the bridge yard. Once.
func lay_footbridge() -> Site:
	if Village.stats.get("footbridge_laid", false):
		return null
	var w = VillageEra2._w()
	if w == null or not w.has_method("spawn_plot"):
		return null
	Village.stats["footbridge_laid"] = true
	var s: Site = w.spawn_plot(&"footbridge", Vector3(FOOTBRIDGE.x, 0, FOOTBRIDGE.y))
	if s != null:
		if "era2" in w and w.era2 != null and w.era2.has_method("bank_height"):
			s.position.y = w.era2.bank_height(FOOTBRIDGE)      # rests on the banks, over the water
		s.rebuild_visual()
	var a: Array = []
	for p in TIMBER_PILE:
		a.append([p.x, p.y, 0.3 + 0.2 * float(a.size())])
	Village.stats["timbers"] = a
	sync_timbers()
	if s != null:
		Events.alert.emit("They have marked out a footbridge over the shallows. Carry the two timbers from the bridge yard to it", s.global_position)
	return s

## (Re)makes the loose timbers from Village.stats["timbers"] (after a load).
func sync_timbers() -> void:
	for n in get_children():
		if n is Timber:
			remove_child(n)
			n.queue_free()
	var w = VillageEra2._w()
	var a: Array = Village.stats.get("timbers", [])
	for i in a.size():
		var row: Array = a[i]
		if row.size() < 2:
			continue
		var t := Timber.new()
		t.key = i
		t.name = "Timber%d" % i
		add_child(t)
		var x := float(row[0])
		var z := float(row[1])
		t.global_position = Vector3(x, w.ground_y(x, z) if w != null else 0.0, z)
		t.rotation.y = float(row[2]) if row.size() > 2 else 0.0

## Loose timbers lying about now.
func timbers() -> Array:
	return get_children().filter(func(n): return n is Timber and not n.is_queued_for_deletion())

## The footbridge's crossing (after it is raised, and again after a load): the
## people can walk to the far side, and the hand may set them down there.
func sync_footbridge() -> void:
	sync_timbers()
	var w = VillageEra2._w()
	if w == null:
		return
	var built := false
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == &"footbridge" and s.state == Site.State.FINISHED:
			built = true
	if not built:
		return
	VillageEra2.add_crossing(w)
	VillageEra2.allow(w, &"east_bank")
	if w.is_region_open(&"southern_plains"):
		VillageEra2.allow(w, &"southern_plains")

## world.add_crossing (worker D's API; its arity is checked, and a world
## without it is left alone).
static func add_crossing(w) -> void:
	if w.has_method("add_crossing"):
		if w.get_method_argument_count(&"add_crossing") >= 2:
			w.add_crossing(CROSSING_ID, FOOTBRIDGE)
		else:
			w.add_crossing(CROSSING_ID)
		return
	if "era2" in w and w.era2 != null and w.era2.has_method("add_crossing"):
		w.era2.add_crossing(CROSSING_ID, FOOTBRIDGE)
	if "drops" in w and w.drops != null and w.drops.has_method("add_crossing"):
		w.drops.add_crossing(CROSSING_ID)

static func allow(w, id: StringName) -> void:
	if "drops" in w and w.drops != null and w.drops.has_method("allow_region"):
		w.drops.allow_region(id)

func _on_region(id: StringName) -> void:
	var w = VillageEra2._w()
	if w == null:
		return
	match Valley.canon(id):
		&"southern_plains":
			if Flags.has(&"footbridge"):
				VillageEra2.allow(w, &"southern_plains")
		&"hill_quarry":
			if w.has_method("open_pass"):
				w.open_pass()          # the rockfall also blocked the Pass Road

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
