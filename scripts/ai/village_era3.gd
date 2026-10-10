class_name VillageEra3 extends Node
## Era 3 (Town) progression that is not a Village Dream (doc 4-8, 10):
##  - the town is laid out when the era begins: cottages with room around
##    them are rebuilt as townhouses, iron is found in the hill quarry, more
##    timber is marked, and the people want a mason's yard first;
##  - workplaces (Austin's 2026-10-10 ruling, as in Era 2): the mason's yard
##    on the quarry floor quarries the ledges, dresses spare stone and paves
##    the busiest roads (Paving); the forge beside it mines the iron seams and
##    forges the ore; the mills fetch the farmhouses' grain and grind it. One
##    drop staffs a crew; their carters haul the bins to the stores;
##  - suggestions, one plot at a time as in Era 2 (what the active dream waits
##    on jumps the queue), as the town grows into its chains: the
##    forge once there is iron ore, townhouses when homes are full, mills,
##    the printing house after the school, the market hall, the clinic and
##    the fire station (sooner once a sickness or a fire has come), the
##    harbour once the Coast is open, the lighthouse after the harbour, the
##    clocktower once there is brass, the laboratory once books pile up, and
##    the great hall of the hand over the temple once the hand has Grip IV;
##  - the people long for the sea (flag sea_seen, which lets the hand learn
##    Calm Waters) a few minutes in;
##  - foremen (doc 3, the Era 3 autonomy dial): an idle adult joins a
##    workshop near them whose hand-placed worker is a master (3 stars); a
##    master at a workplace sends for idle helpers from across the town until
##    the crew is full; children go to school by day on their own once there
##    is a school;
##  - discoveries: iron tools (+70% work), carts (builders carry twice as
##    much), printing (school teaches twice as fast), clean water (the
##    aqueduct: half the sickness, a fountain in the square), star charts (the
##    gate: three charts drawn at the observatory under the Guiding Light);
##  - trust made visible: offerings at the great hall, the hand in the
##    observatory's stained glass and, once the town loves the hand, the town
##    flag with the hand on it raised in the square.
## Everything is one-off and kept in Village.stats so it saves with Village.

const CHECK := 2.0
const SEA_AFTER := 540.0           # game seconds into the era before they long for the sea
const MAX_TOWNHOUSES := 14
const IRON_FOR_TOOLS := 4
const BOOKS_FOR_PRINTING := 4
const CHARTS_FOR_GATE := 6         # [era3] six nights of charting (pacing: Era 3 ran 48 min)
const OFFERING_EVERY := 60.0
const FOREMAN_STARS := 3
const FOREMAN_RANGE := 45.0
const FOREMAN_STOCK := 30          # a master only draws helpers while the stores want more
const FLAG_TRUST := 3.6
const SCHOOL_RANGE := 160.0
const WORKPLACE_CALL := 170.0      # a master at a workplace sends this far for helpers
## Suggestions: one at a time, at least this far apart; a suggestion nobody has
## started stops holding up the next one after SUGGEST_HOLD (as in Era 2).
const SUGGEST_GAP := 90.0
const SUGGEST_HOLD := 240.0
## The aqueduct takes away the water chore (doc 4): the castellum keeps the
## stores in water, WATER_PER_CHECK at a time, up to WATER_PER_HEAD a head.
const WATER_PER_CHECK := 6
const WATER_PER_HEAD := 2
## Caravans (doc 4, the market chain): once the market hall is kept, a wagon
## from down the valley calls every CARAVAN_EVERY game seconds and trades the
## town's biggest surplus for what it cannot make or is short of.
const CARAVAN_EVERY := 420.0
const CARAVAN_STAY := 50.0
const CARAVAN_SURPLUS := 40         # a good is surplus above this
const CARAVAN_TAKES := 12
const TRADE_GOODS: Array[StringName] = [&"bread", &"flour", &"grain", &"fish", &"pots", &"wool", &"blocks", &"stone"]
const CARAVAN_BRINGS := {&"tin": 3, &"iron": 2, &"cloth": 4, &"books": 2, &"charcoal": 6, &"clay": 6}

var _acc: float = 0.0
var _offer_t: float = 0.0

func _ready() -> void:
	name = "VillageEra3"
	Events.sim_tick.connect(_on_tick)
	Events.building_finished.connect(_on_building_finished)
	Events.power_unlocked.connect(_on_power)
	Events.threat_started.connect(_on_threat)
	Events.era_changed.connect(_on_era)
	Events.region_opened.connect(_on_region)
	if not Game.flags.has("no-autonomy"):
		Person.autonomy_hook = VillageEra3.autonomy

func _exit_tree() -> void:
	if Person.autonomy_hook == Callable(VillageEra3.autonomy):
		Person.autonomy_hook = Callable()

func _on_era(e: int) -> void:
	if e == 3:
		setup.call_deferred()

func _on_tick(dt: float) -> void:
	if Village.era != 3:
		return
	_offer_t += dt
	_acc += dt
	if _acc < CHECK:
		return
	_acc = 0.0
	if not Village.stats.get("era3_setup", false):
		setup()
	check_now()

func era_t() -> float:
	return Clock.total_t - float(Village.stats.get("era_started_t", 0.0))

func check_now() -> void:
	if Village.era != 3:
		return
	_migrate_workplaces()
	_sea()
	_wishes()
	Paving.plan()
	_water()
	_caravans()
	_discoveries()
	_trust()

static func _w():
	var w = Game.world
	return w if w != null and is_instance_valid(w) else null

static func _count(bid: StringName, finished_only: bool = false) -> int:
	return VillageEra2._count(bid, finished_only)

static func _wish(key: String, bid: StringName, line: String) -> Site:
	return VillageEra2._wish(key, bid, line)

# ---------------------------------------------------------------- setup

## The town is laid out (once; also for a save made the moment Era 3 began).
func setup() -> void:
	if Village.era != 3 or Village.stats.get("era3_setup", false):
		return
	var w = VillageEra3._w()
	if w == null:
		return
	Village.stats["era3_setup"] = true
	var n := VillageEra3.cottages_to_townhouses()
	for row in LayoutEra3.START_JOBS:
		w.spawn_site(row[0], Vector3(row[1], 0, row[2]))
	if w.era3 != null:
		w.era3.refresh()
	if n > 0:
		Flags.remember("We rebuilt our cottages as townhouses, two storeys of dressed stone, with room for the children")
	Events.alert.emit("Iron in the hill quarry! The village is becoming a town", w._v3(Vector2(262.0, -128.0)))

## Every finished cottage with room around it becomes a townhouse in place:
## same family, more room. Cottages hemmed in by their neighbours stay.
static func cottages_to_townhouses() -> int:
	var th := Defs.building(&"townhouse")
	if th == null:
		return 0
	var n := 0
	for s in Village.sites.duplicate():
		if not is_instance_valid(s) or s.building == null or s.building.id != &"cottage" or s.state != Site.State.FINISHED:
			continue
		if VillageEra3._crowded(s, th.footprint):
			continue
		s.building = th
		s.build_done = th.build_work
		s.delivered = th.cost.duplicate()
		s.rebuild_visual()
		n += 1
		var w = Game.world
		if w != null and is_instance_valid(w) and w.has_method("_on_building_finished"):
			w._on_building_finished(s)
	Village.stats["townhouses_from_cottages"] = n
	return n

static func _half(fp: Vector2, yaw: float) -> Vector2:
	var h := fp * 0.5
	return Vector2(h.y, h.x) if absf(sin(yaw)) > 0.7 else h

## Would a building of footprint `fp` at `s` overlap another building or work site?
static func _crowded(s: Site, fp: Vector2) -> bool:
	var a := Vector2(s.global_position.x, s.global_position.z)
	var ha := VillageEra3._half(fp, s.rotation.y)
	for o in Village.sites:
		if o == s or not is_instance_valid(o):
			continue
		var b := Vector2(o.global_position.x, o.global_position.z)
		var hb := Vector2(1.2, 1.2)
		if o.building != null:
			hb = VillageEra3._half(o.building.footprint, o.rotation.y)
		if absf(a.x - b.x) < ha.x + hb.x + 0.3 and absf(a.y - b.y) < ha.y + hb.y + 0.3:
			return true
	return false

# ---------------------------------------------------------------- water and caravans

func _water() -> void:
	if not Flags.has(&"clean_water"):
		return
	var want := mini(Village.population() * WATER_PER_HEAD, Village.store_cap - 4)
	var have := Village.store(&"water")
	if have < want:
		Village.add_store(&"water", mini(WATER_PER_CHECK, want - have))
		Village.stats["aqueduct_water"] = int(Village.stats.get("aqueduct_water", 0)) + mini(WATER_PER_CHECK, want - have)

var caravan: Node3D = null
var _caravan_t := 0.0

static func _market_hall() -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and s.is_finished_building(&"market_hall") and s.burn <= 0.0:
			return s
	return null

func _caravans() -> void:
	if caravan != null and is_instance_valid(caravan) and Clock.total_t - _caravan_t > CARAVAN_STAY:
		caravan.queue_free()
		caravan = null
	var hall := VillageEra3._market_hall()
	if hall == null or hall.workers.filter(func(p): return is_instance_valid(p)).is_empty():
		return
	var next := float(Village.stats.get("caravan_next", -1.0))
	if next < 0.0:
		Village.stats["caravan_next"] = Clock.total_t + 60.0       # the first comes soon after the hall is kept
		return
	if Clock.total_t < next:
		return
	Village.stats["caravan_next"] = Clock.total_t + CARAVAN_EVERY
	var line := VillageEra3.trade()
	if line == "":
		return
	_caravan_t = Clock.total_t
	if caravan == null or not is_instance_valid(caravan):
		if AssetCatalog.has(&"caravan_wagon"):
			caravan = AssetCatalog.instance(&"caravan_wagon")
			var w = VillageEra3._w()
			if w != null:
				w.add_child(caravan)
				var at: Vector3 = hall.global_position + hall.global_basis * Vector3(hall.building.footprint.x * 0.5 + 3.0, 0, 0)
				at.y = w.ground_y(at.x, at.z)
				caravan.global_position = at
				caravan.rotation.y = hall.rotation.y
	Events.alert.emit(line, hall.global_position)

## One caravan's trade: the biggest surplus for what the town wants most.
## Returns the alert line ("" when there was nothing to trade).
static func trade() -> String:
	var give: StringName = &""
	var most := CARAVAN_SURPLUS
	for k in TRADE_GOODS:
		if Village.store(k) > most:
			most = Village.store(k)
			give = k
	if give == &"":
		return ""
	var want_k: StringName = &"tin"
	var short := 0
	for k in CARAVAN_BRINGS:
		var gap := Workplace.plots_want(k) - Village.store(k)
		if gap > short:
			short = gap
			want_k = k
	var n := mini(CARAVAN_TAKES, Village.store(give) - CARAVAN_SURPLUS + CARAVAN_TAKES)
	Village.take_store(give, n)
	var got := Village.add_store(want_k, int(CARAVAN_BRINGS[want_k]))
	Village.stats["caravans"] = int(Village.stats.get("caravans", 0)) + 1
	if int(Village.stats["caravans"]) == 1:
		Flags.remember("A caravan came up the valley to our market hall, with things we cannot make. We traded our bread for them.")
	return "A caravan from down the valley trades %d %s for %d %s at the market hall" % [n, str(give), got, str(want_k)]

# ---------------------------------------------------------------- the sea

func _sea() -> void:
	if Flags.has(&"sea_seen") or era_t() < SEA_AFTER:
		return
	Flags.set_flag(&"sea_seen")
	Flags.remember("Our fishers followed the river down to where it meets the sea. Grey waves, and islands far out. We wanted the sea.")
	var w = VillageEra3._w()
	var at: Vector3 = Vector3(300, 0, 380) if w == null else w._v3(Vector2(300.0, 380.0))
	Events.alert.emit("They have followed the river to the sea, but the waves are too rough for boats (Calm Waters)", at)

func _on_region(id: StringName) -> void:
	if Valley.canon(id) != &"coast":
		return
	_wish("harbour", &"harbour", "They want a harbour on the beach, and a ship to sail to the islands")
	Flags.remember("The hand laid its palm on the sea and the waves lay down. We walked down to the beach.")

# ---------------------------------------------------------------- wishes

func _wishes() -> void:
	_suggest()
	_maybe_townhouse()

## Lays the next suggested plot, if the last one is under way (or has waited
## long enough) and SUGGEST_GAP has passed. What the active dream waits on
## (blocks, iron, books, brass) jumps the queue. Returns it (or null).
func _suggest() -> Site:
	var now := Clock.total_t
	var rows := suggestions()
	for row in rows:
		if row.size() > 3 and bool(row[3]):
			var u: Site = _lay(row)
			if u != null:
				return u
	if now - float(Village.stats.get("suggest3_t", -1.0e9)) < SUGGEST_GAP:
		return null
	for s in Village.sites:
		if is_instance_valid(s) and s.has_meta(&"suggested") and s.state == Site.State.PLOT \
				and now - float(s.get_meta(&"suggested")) < SUGGEST_HOLD:
			return null
	for row in rows:
		var s2: Site = _lay(row)
		if s2 != null:
			return s2
	return null

## The active dream waits on this good (its plot still needs it).
static func dream_wants(k: StringName) -> bool:
	var d: DreamDef = Dreams.active_dream()
	if d == null or not Dreams.revealed(d):
		return false
	for b in d.needs_buildings:
		var bd: BuildingDef = Defs.building(b)
		if bd != null and bd.cost.has(k) and Village.count_buildings(b) < int(d.needs_buildings[b]):
			return true
	return false

## [key, building id, line, urgent] for every suggestion that is due now, in order.
func suggestions() -> Array:
	var t := era_t()
	var out: Array = []
	out.append(["mason", &"mason", "They want a mason's yard on the quarry floor: its crew quarries the ledges, dresses stone and paves the roads", true])
	if Village.store(&"iron_ore") >= 2 or t > 400.0 or dream_wants(&"iron"):
		out.append(["forge", &"forge", "Iron in the hill quarry. They want a forge beside it: its crew mines the seams and forges the iron", dream_wants(&"iron")])
	if Dreams.is_done(&"school") or t > 900.0 or dream_wants(&"books"):
		out.append(["printing", &"printing_house", "The teachers want their words written down. They want a printing house", dream_wants(&"books")])
	if t > 600.0:
		out.append(["watermill", &"watermill", "They want a watermill on the stream: its millers fetch the farmhouses' grain and grind it", false])
	if Village.store(&"wood") < 10 and t > 300.0 or t > 1300.0:
		out.append(["town_wood", &"woodcutter_camp", "Timber for a town! They want a woodcutters' camp by the eastern woods", false])
	if t > 780.0 or int(Village.stats.get("threat_town_fire", 0)) > 0:
		out.append(["fire_station", &"fire_station", "They want a fire station with a bell, and a crew to watch for smoke", int(Village.stats.get("threat_town_fire", 0)) > 0])
	if t > 1080.0 or int(Village.stats.get("threat_sickness", 0)) > 0:
		out.append(["clinic", &"clinic", "They want a clinic, where the sick can rest and be tended", int(Village.stats.get("threat_sickness", 0)) > 0])
	if t > 1200.0 and _count(&"market", true) > 0:
		out.append(["market_hall", &"market_hall", "Traders from up and down the valley. They want a covered market hall", false])
	if t > 1500.0:
		out.append(["windmill", &"windmill", "They want a windmill by the fields", false])
	if Faith.has(&"grip_4") and Dreams.is_done(&"school"):
		out.append(["great_hall", &"great_hall", "They want a great hall of the hand where the temple stands. Ten at once can raise it", false])
	if _count(&"harbour", true) > 0 and (t > 1800.0 or int(Village.stats.get("threat_storms", 0)) > 0):
		out.append(["lighthouse", &"lighthouse", "They want a lighthouse on the point, to bring the ship home through storms", false])
	if Village.store(&"brass") >= 2:
		out.append(["clocktower", &"clocktower", "Brass from the island tin! They want a clocktower in the square", false])
	if Village.store(&"books") >= 6 or (Flags.has(&"printing") and t > 2400.0):
		out.append(["laboratory", &"laboratory", "So many books. The curious want a laboratory to test what they read", false])
	return out

## Lays one suggestion (once per key); null when it is done or has no room.
func _lay(row: Array) -> Site:
	var key: String = row[0]
	if Village.stats.get("wish_" + key, false):
		return null
	var w = VillageEra3._w()
	if w == null or not w.has_method("add_plot"):
		return null
	var s: Site = w.add_plot(row[1])
	Village.stats["wish_" + key] = true
	if s == null:
		return null
	s.set_meta(&"suggested", Clock.total_t)
	Village.stats["suggest3_t"] = Clock.total_t
	Village.stats["suggestions"] = int(Village.stats.get("suggestions", 0)) + 1
	if str(row[2]) != "":
		Events.alert.emit(str(row[2]), s.global_position)
	return s

## Saves from before the Era 3 workplaces: a finished mason's yard, forge or
## mill keeps its old bench job; it becomes its workplace job, and gets its
## carter (and the forge its brass bench) beside it. Once a session.
var _migrated := false
func _migrate_workplaces() -> void:
	if _migrated:
		return
	_migrated = true
	var w = VillageEra3._w()
	if w == null:
		return
	for s in Village.sites.duplicate():
		if not is_instance_valid(s) or not s.is_workplace() or s.building.jobs.is_empty() or s.job == null:
			continue
		if s.job.id == s.building.jobs[0]:
			continue
		s.job = Defs.job(s.building.jobs[0])
		for i in range(1, s.building.jobs.size()):
			var jid: StringName = s.building.jobs[i]
			var has := false
			for c in Village.sites:
				if is_instance_valid(c) and c.parent_uid == s.uid and c.job != null and c.job.id == jid:
					has = true
			if not has:
				var c2: Site = w.spawn_site(jid, s.global_position + Vector3(cos(TAU * i / 3.0), 0, sin(TAU * i / 3.0)) * (s.pick_radius() + 1.5))
				if c2 != null:
					c2.parent_uid = s.uid
		Village.stats["workplaces_migrated"] = int(Village.stats.get("workplaces_migrated", 0)) + 1

## Another townhouse when the homes are full (the Era 3 form of the cottage wish).
func _maybe_townhouse() -> void:
	var room := 0
	var finished := 0
	for s in Village.sites:
		if not is_instance_valid(s) or s.building == null or s.building.shelter <= 0 or s.building.camp:
			continue
		if s.building.id == &"townhouse":
			if s.state != Site.State.FINISHED:
				return              # one townhouse plot at a time
			finished += 1
		if s.state == Site.State.FINISHED:
			room += s.building.shelter
	if finished >= MAX_TOWNHOUSES:
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
	if Village.population() + 3 <= room and not cramped and homeless == 0:
		return
	var w = VillageEra3._w()
	if w == null:
		return
	var s2: Site = w.add_plot(&"townhouse")
	if s2 != null:
		Village.stats["townhouse_wishes"] = int(Village.stats.get("townhouse_wishes", 0)) + 1
		Events.alert.emit("A family wants a townhouse", s2.global_position)

func _on_building_finished(site) -> void:
	if Village.era != 3 or not (site is Site) or not is_instance_valid(site) or site.building == null:
		return
	var w = VillageEra3._w()
	match site.building.id:
		&"mason":
			Flags.remember("We built a mason's yard. Now our walls are of dressed stone.")
		&"school":
			Flags.remember("We built a school. The old teach the young what the hand taught us.")
			VillageEra3.hint("school", "The school is open: children go there by day on their own, and grow up with a head for books", site.global_position)
		&"harbour":
			if w != null and w.era3 != null:
				w.era3.ship_on_beach()
			Events.alert.emit("The harbour is built, and a ship waits on the beach. Lift it onto the sea", w._v3(LayoutEra3.SHIP_BEACH) if w else site.global_position)
			Flags.remember("We built a harbour where the river meets the sea, and a ship to sail in.")
		&"aqueduct":
			Flags.set_flag(&"clean_water")
			VillageEra3.hint("aqueduct_water", "Nobody needs to carry water any more: the aqueduct keeps the stores full", site.global_position)
			if w != null and w.era3 != null:
				w.era3.water_arrives()
				w.spawn_site(&"draw_water", w._v3(LayoutEra3.FOUNTAIN + Vector2(3.0, 2.0)))
			Flags.remember("Ten of us raised the last arch, and water walked to us on stone legs. Clean water in the square, and less sickness.")
			Events.alert.emit("The aqueduct runs! Clean water in the square: sickness spreads half as fast", w._v3(LayoutEra3.FOUNTAIN) if w else site.global_position)
		&"great_hall":
			Flags.set_flag(&"great_hall")
			Flags.remember("We raised the great hall of the hand where the temple stood. The whole town fits inside.")
		&"observatory":
			Flags.remember("We built an observatory on the quarry hill, with the hand in its coloured glass. Now we can watch the stars.")
			if not Faith.has(&"guiding_light"):
				VillageEra3.hint("observatory", "The observatory is built. Astronomers need the Guiding Light to chart the stars at night", site.global_position)
		&"lighthouse":
			Flags.remember("We lit a lighthouse on the point. Storms come with fair warning now, and the ship finds its way home.")
		&"clocktower":
			Flags.remember("A clock in the square! Now we all know the hour.")
		&"market_hall":
			if not Village.stats.get("market_hall_wanderers", false):
				Village.stats["market_hall_wanderers"] = true
				var ai = get_parent()
				if ai != null and "wanderers" in ai and ai.wanderers != null:
					ai.wanderers.arrive(3, &"")

## Onboarding for the new mechanics (doc 11): one line, once, at the moment it matters.
const POWER_HINTS := {
	&"grip_4": "Grip IV: lift ten at once. The aqueduct and the great hall need crews of ten",
	&"calm_waters": "Calm Waters: select it, then hold E over the sea. The coast opens; a calm sea lets the ship sail",
	&"lift_buildings": "Lift Buildings: select it, then click a house to pick it up and set it down somewhere better",
	&"guiding_light": "Guiding Light: at night, hold E over the sky by the observatory. The astronomers chart the stars by it",
}

static func hint(key: String, text: String, at: Vector3 = Vector3.INF) -> bool:
	return VillageEra2.hint(key, text, at)

func _on_power(id: StringName) -> void:
	_acc = CHECK
	if id == &"calm_waters":
		var w = VillageEra3._w()
		if w != null and not w.is_region_open(&"coast"):
			w.open_region(&"coast")
	if POWER_HINTS.has(id):
		var w2 = VillageEra3._w()
		var at := Vector3.INF
		if w2 != null:
			match id:
				&"calm_waters": at = w2._v3(LayoutEra3.CAMPS[&"coast"])
				&"guiding_light": at = w2._v3(LayoutEra3.PLOT_SPOTS[&"observatory"][0])
		VillageEra3.hint(str(id), POWER_HINTS[id], at)

func _on_threat(id: StringName, _at: Vector3) -> void:
	if id in [&"town_fire", &"sickness", &"storms"]:
		_acc = CHECK

# ---------------------------------------------------------------- discoveries

func _discoveries() -> void:
	var at := Site.store_point(Vector3.ZERO)
	if not Flags.has(&"iron_tools") and Village.store(&"iron") >= IRON_FOR_TOOLS + 2:
		Village.take_store(&"iron", IRON_FOR_TOOLS)
		Flags.set_flag(&"iron_tools")
		Flags.remember("The forge made iron tools: saws, chisels and ploughshares. Everything goes faster again.")
		Events.alert.emit("Iron tools: all work is faster still", at)
	if not Flags.has(&"carts") and Flags.has(&"iron_tools") and _count(&"market_hall", true) + _count(&"forge", true) >= 2 and Village.store(&"wood") >= 6:
		Village.take_store(&"wood", 6)
		Flags.set_flag(&"carts")
		Flags.remember("We built carts with iron-shod wheels. A builder carries a whole load at once.")
		Events.alert.emit("Carts: builders carry twice as much to a plot", at)
	if not Flags.has(&"printing") and Village.store(&"books") >= BOOKS_FOR_PRINTING:
		Flags.set_flag(&"printing")
		Flags.remember("We printed our first books. What one of us learns, all of us can read.")
		Events.alert.emit("Printing: the school teaches twice as fast", at)
	if not Flags.has(&"star_charts") and Village.store(&"star_charts") >= CHARTS_FOR_GATE:
		Flags.set_flag(&"star_charts")
		Flags.remember("We charted the stars from the observatory, by the hand's light. We know now how the sky turns.")
		var w = VillageEra3._w()
		Events.alert.emit("The star charts are drawn", w._v3(LayoutEra3.PLOT_SPOTS[&"observatory"][0]) if w else at)

# ---------------------------------------------------------------- trust

func _trust() -> void:
	if not Flags.has(&"town_flag") and Trust.average() >= FLAG_TRUST and Dreams.is_done(&"school") and era_t() > 900.0:
		Flags.set_flag(&"town_flag")
		var w = VillageEra3._w()
		if w != null and w.era3 != null:
			w.era3.raise_flag()
		Flags.remember("We sewed the hand onto a flag and raised it in the square, for everyone to see.")
		Events.alert.emit("They have raised a flag with the hand on it in the town square", w._v3(LayoutEra3.FLAG) if w else Vector3.ZERO)
	if _offer_t >= OFFERING_EVERY:
		_offer_t = 0.0
		VillageEra2.bring_offering()

# ---------------------------------------------------------------- foremen

## Person.autonomy_hook (Era 3): what an idle person does on their own before
## wandering. Children go to school by day; an idle adult joins a nearby
## workshop where a master works. True when they found something.
static func autonomy(p: Person) -> bool:
	if Village.era < 3 or Clock.is_night or not p.alive() or p.is_sick():
		return false
	if p.stage == Person.Stage.CHILD:
		return VillageEra3._go_to_school(p)
	if p.stage != Person.Stage.ADULT:
		return false
	var best: Site = null
	var best_v := INF
	for s in VillageEra3._workshops():
		if not is_instance_valid(s):
			continue
		var d: float = p.global_position.distance_to(s.global_position)
		var reach := WORKPLACE_CALL if s.is_workplace() else FOREMAN_RANGE
		if d >= reach or not s.can_accept(1):
			continue
		var v := d * (0.25 if s.is_workplace() else 1.0)     # a master's call reaches across the town
		if v >= best_v:
			continue
		best = s
		best_v = v
	if best == null:
		return false
	if p.join(best, false):
		Village.stats["foreman_joins"] = int(Village.stats.get("foreman_joins", 0)) + 1
		return true
	return false

## Workshops that would take a helper now: a master at work, a free bench,
## the inputs in the stores. Looked up once a game second for everyone.
static var _shops: Array = []
static var _shops_t: float = -INF

static func _workshops() -> Array:
	if absf(Clock.total_t - _shops_t) < 1.0:
		return _shops
	_shops_t = Clock.total_t
	_shops = []
	# what the open plots still wait on: a foreman never works it into something else
	var wanted := {}
	for s in Village.sites:
		if is_instance_valid(s) and s.state == Site.State.PLOT and s.building != null:
			for k in s.building.cost:
				wanted[k] = int(wanted.get(k, 0)) + maxi(s.remaining(k), 0)
	for s in Village.sites:
		if not is_instance_valid(s) or s.is_plot() or s.job == null or s.is_group() or s.building == null:
			continue
		if s.is_workplace():
			# [era3] a workplace whose master has work for more hands
			if s.can_accept(1) and s.discovered() and VillageEra3._has_master(s) and VillageEra3._workplace_busy(s):
				_shops.append(s)
			continue
		var j: JobDef = s.job
		if not (j.kind == JobDef.Kind.CRAFT or j.kind == JobDef.Kind.GATHER) or j.id == &"attend_school":
			continue
		if not s.can_accept(1) or not s.can_work_now():
			continue
		var ok := true
		for k in j.inputs:
			if Village.store(k) < int(j.inputs[k]) + int(wanted.get(k, 0)):
				ok = false
		for k in j.outputs:
			if Village.store(k) >= mini(FOREMAN_STOCK, Village.store_cap - 2):
				ok = false       # the stores are full of it: nobody needs more
		if ok and VillageEra3._has_master(s):
			_shops.append(s)
	return _shops

## A workplace with something for another pair of hands: a task wanting work
## (fields, ledges, seams, a full bin) or its bench ready.
static func _workplace_busy(s: Site) -> bool:
	if Workplace.bench_need(s) > 0.0:
		return true
	for t in Workplace.tasks(s):
		if Workplace.need(t) > 0.0:
			return true
	return false

## A worker the hand placed at `s` who has mastered its craft (3+ stars).
static func _has_master(s: Site) -> bool:
	var fam := Person._family(s.job.skill)
	for w in s.workers:
		if is_instance_valid(w) and w.placed_by_hand and w.stars(fam) >= FOREMAN_STARS:
			return true
	return false

static func _go_to_school(p: Person) -> bool:
	if p.job_site != null and is_instance_valid(p.job_site):
		return false
	var school := Site.nearest(p.global_position, SCHOOL_RANGE, func(s): return s.job != null and s.job.id == &"attend_school" and not s.is_plot() and s.can_accept(1))
	if school == null:
		return false
	if p.join(school, false):
		Village.stats["school_joins"] = int(Village.stats.get("school_joins", 0)) + 1
		return true
	return false
