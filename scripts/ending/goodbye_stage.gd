class_name GoodbyeStage extends RefCounted
## A generated Era 4 setup for previewing and testing the goodbye before the
## Era 4 gameplay exists (`--goodbye` on the command line, tests/ending/):
## the launch tower with the rocket on the flat of the Valley Floor, a little
## of the mid-century city round it, a Village Book written from the storm night
## to the launch (journal, firsts, gifts, the dream), and a people of about
## seventy whose family tree runs back six generations to the first two.
##
##   var site := GoodbyeStage.setup(world)      # then world.start_goodbye()

const SITE := Vector2(112.0, -4.0)       # flat ground on the Valley Floor (pad and crowd)
const DAY := 412

## The main line, oldest first: [name, sex, partner name, partner sex]. Each is
## the child of the couple above. The crew comes from its last rows.
const LINE := [
	["Ona", "f", "Tuk", "m"],
	["Pim", "m", "Asha", "f"],
	["Maren", "f", "Corin", "m"],
	["Clara", "f", "Florian", "m"],
	["Hedy", "f", "Otto", "m"],
]
## A cousin line from Ona and Tuk's daughter, for the other two crew.
const COUSINS := [
	["Sela", "f", "Kai", "m"],
	["Bram", "m", "Hilde", "f"],
	["Anselm", "m", "Viola", "f"],
	["Konrad", "m", "Margit", "f"],
]

static func setup(world: Node, seed_v: int = 7) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	Save.enabled = false          # a generated preview is never saved over a real valley
	world.clear_dynamic()
	if world.storm != null:
		world.storm.skip()
	# ---- the village has reached the Launch
	Village.era = 4
	Village.stats = {"births": 0, "deaths": 0, "joined": 0, "winters_survived": 26, "gifts": 0,
		"onboarding": Onboarding.Beat.DONE, "era_started_t": 0.0}
	var done: Array = []
	for e in [1, 2, 3, 4]:
		var ed: EraDef = Defs.era(e)
		if ed != null:
			for id in ed.dreams:
				done.append(str(id))
	Village.stats["dreams_done"] = done
	Village.stats["era_gate_done"] = 4
	# a city that has been doing fine: full enough stores for the morning after
	for k in [&"bread", &"fish", &"meat", &"steel", &"fuel", &"parts", &"wood", &"stone"]:
		Village.stores[k] = 0
		Village.add_store(k, 60 if k in [&"bread", &"fish"] else 24)
	Village.next_person_id = 1
	AssetCatalog.set_era(4)
	world.look.apply_era(4)
	Clock.apply_era(Defs.era(4))
	Clock.day = DAY
	Clock.year = 27
	Clock.season = Clock.Season.SUMMER
	Clock.season_t = 60.0
	Clock.total_t = 27.0 * 4.0 * Clock.season_seconds
	Clock.is_night = false
	Clock.phase_t = 0.6 * Clock.day_seconds
	for id in Valley.REGIONS:
		Village.regions[id] = true
		world._open_region_visual(id, true)
	world.regions.sync_instant()
	for id in Defs.powers:
		Faith.unlocked[id] = true
	Faith.grip = maxi(Faith.grip, 5)
	Faith.strength = maxf(Faith.strength, 4.0)
	world.look.set_weather(0.0, false)
	world.look.update_now()
	var site := _build_site(world)
	_dress_city(world, site, rng)
	_people(world, site, rng)
	_journal()
	world.nav.rebake()
	return site

static func _gy(world: Node, x: float, z: float) -> float:
	return world.ground_y(x, z)

static func _local(site: Node3D, x: float, z: float) -> Vector3:
	return site.global_transform * Vector3(x, 0, z)

## The launch tower, built where the shrine stood, with the rocket on its mount.
static func _build_site(world: Node) -> Node3D:
	var tower := AssetCatalog.instance(&"launch_tower")
	tower.name = "LaunchTower"
	tower.add_to_group(&"launch_site")
	world.dynamic.add_child(tower)
	tower.global_position = Vector3(SITE.x, _gy(world, SITE.x, SITE.y) - 0.05, SITE.y)
	var mount := tower.find_child("RocketMount", true, false) as Node3D
	if mount != null:
		var r := AssetCatalog.instance(&"rocket")
		r.name = "Rocket"
		mount.add_child(r)
	world.nav.set_box_obstacle("launch_tower", tower.global_position, Vector2(26, 22), 0.0)
	return tower

static func _put(world: Node, site: Node3D, id: String, x: float, z: float, yaw := 0.0, variant := 0) -> Node3D:
	var n := AssetCatalog.instance(StringName(id), variant)
	world.dynamic.add_child(n)
	var p := _local(site, x, z)
	n.global_position = Vector3(p.x, _gy(world, p.x, p.z), p.z)
	n.rotation_degrees.y = yaw
	n.add_to_group(&"goodbye_dressing")
	return n

## A little of the mid-century city: the plateau's flags and lamps, mission
## control and the dish, apartment blocks behind the crowd, traffic.
static func _dress_city(world: Node, site: Node3D, rng: RandomNumberGenerator) -> void:
	for k in 6:
		var a := deg_to_rad([222.0, 232.0, 242.0, 298.0, 308.0, 318.0][k])
		var p := Vector3(cos(a), 0, -sin(a)) * 31.0
		_put(world, site, "street_light" if k % 3 == 1 else "flag_mission", p.x, p.z, rad_to_deg(a) + 90.0)
	_put(world, site, "mission_control", 50.0, -26.0, -110)
	_put(world, site, "radio_telescope", -52.0, -46.0, 30)
	_put(world, site, "assembly_hall", -40.0, -40.0, 40)
	_put(world, site, "fuel_tanks", 18.0, -18.0, 20)
	_put(world, site, "truck", 24.0, -24.0, 20, 1)
	_put(world, site, "bus", -38.0, 26.0, 130)
	_put(world, site, "car", -32.0, 36.0, 40, 1)
	_put(world, site, "car", -42.0, 33.0, 60, 2)
	_put(world, site, "apartment", -44.0, 62.0, 90, 0)
	_put(world, site, "apartment", 44.0, 64.0, -90, 1)
	_put(world, site, "apartment", -40.0, 84.0, 90, 2)
	_put(world, site, "apartment", 42.0, 88.0, -90, 0)
	_put(world, site, "institute", 0.0, 100.0, 180)
	for z in [56.0, 70.0, 84.0]:
		_put(world, site, "street_light", -6.0, z, 90)
		_put(world, site, "street_light", 6.0, z + 7.0, -90)
	for z in range(50, 100, 4):
		_put(world, site, "road_asphalt", 0.0, float(z), 0)
	_put(world, site, "wind_turbine", 70.0, -60.0, 90)
	_put(world, site, "wind_turbine", 80.0, -36.0, 90)
	_put(world, site, "park", 26.0, 52.0, 0)
	_put(world, site, "bench_modern", 24.0, 49.0, 0)
	_put(world, site, "kiosk", -22.0, 50.0, 30)

# ---------------------------------------------------------------- the people

static var _rec: Dictionary = {}      # uid -> record (the remembered, gone before)

static func _remembered(name: String, sex: String, parents: Array, gen: int, wanderer := false, first := false) -> int:
	var uid := Village.new_person_id()
	var born := 1 if gen == 0 else 8 + gen * 64
	_rec[uid] = {"uid": uid, "name": name, "sex": sex, "stage": 3, "years": 58 + (uid % 9), "alive": false,
		"parents": parents.duplicate(), "children": [], "partner": 0,
		"look": {"skin": uid % 5, "hair": (uid * 3) % 5, "height": 1.0, "outfit": (uid % 4) * 2 + (1 if sex == "f" else 0)},
		"trust": mini(gen + 1, 5), "traits": [], "wanderer": wanderer, "hand_named": first,
		"born_day": born, "died_day": born + 70 + (uid % 11), "cause": "old age", "first_two": first}
	for pu in parents:
		if _rec.has(pu):
			_rec[pu]["children"].append(uid)
	return uid

static func _pair(a: int, b: int) -> void:
	if _rec.has(a): _rec[a]["partner"] = b
	if _rec.has(b): _rec[b]["partner"] = a

static func _spawn(world: Node, site: Node3D, rng: RandomNumberGenerator, name: String, sex: String, age: float,
		parents: Array, trust: float, wanderer := false) -> Person:
	var at := _local(site, rng.randf_range(-30.0, 30.0), rng.randf_range(30.0, 52.0))
	var opts := {"sex": sex, "age": age, "parents": parents, "trust_f": trust, "wanderer": wanderer, "death_age": 4300.0}
	if name != "":
		opts["name"] = name
	var p: Person = world.spawn_person(at, "", opts)
	for pu in parents:
		if _rec.has(pu):
			_rec[pu]["children"].append(p.uid)
		else:
			for q in Village.people:
				if is_instance_valid(q) and q.uid == pu and not q.children.has(p.uid):
					q.children.append(p.uid)
	return p

static func _people(world: Node, site: Node3D, rng: RandomNumberGenerator) -> void:
	_rec.clear()
	BookData.journal()
	# the gone-before: the first two and four generations after them
	var ona := _remembered(LINE[0][0], LINE[0][1], [], 0, false, true)
	var tuk := _remembered(LINE[0][2], LINE[0][3], [], 0, false, true)
	_pair(ona, tuk)
	var top := [ona, tuk]
	var main_couple := top
	var cousin_couple := top
	for g in range(1, 4):
		var m: Array = LINE[g]
		var c: Array = COUSINS[g - 1]
		var a := _remembered(m[0], m[1], main_couple, g)
		var ap := _remembered(m[2], m[3], [], g, true)
		_pair(a, ap)
		var b := _remembered(c[0], c[1], cousin_couple, g)
		var bp := _remembered(c[2], c[3], [], g, true)
		_pair(b, bp)
		# a sibling or two who stayed home
		for k in 1 + (g % 2):
			var sx := "f" if (g + k) % 2 == 0 else "m"
			_remembered(Names.pick(sx, mini(g, 3), rng, _names()), sx, main_couple if k == 0 else cousin_couple, g)
		main_couple = [a, ap]
		cousin_couple = [b, bp]
	# the elders alive today: Hedy and Otto, Konrad and Margit
	var hedy := _spawn(world, site, rng, LINE[4][0], LINE[4][1], 3150.0, main_couple, 4.2)
	var otto := _spawn(world, site, rng, LINE[4][2], LINE[4][3], 3220.0, [], 3.8, true)
	var konrad := _spawn(world, site, rng, COUSINS[3][0], COUSINS[3][1], 3100.0, cousin_couple, 4.0)
	var margit := _spawn(world, site, rng, COUSINS[3][2], COUSINS[3][3], 3080.0, [], 3.6, true)
	for pr in [[hedy, otto], [konrad, margit]]:
		pr[0].partner = pr[1].uid
		pr[1].partner = pr[0].uid
	# the crew-to-be and their cousins (the fifth generation after the first two)
	var gen5: Array = []
	var specs := [["Valentina", "f", [hedy, otto], 5.6, 1700.0], ["Neil", "m", [hedy, otto], 5.3, 1550.0],
		["Ada", "f", [konrad, margit], 4.9, 1640.0], ["Ilan", "m", [konrad, margit], 4.6, 1480.0],
		["Grace", "f", [hedy, otto], 3.9, 1900.0], ["Gene", "m", [konrad, margit], 3.4, 2000.0]]
	for s in specs:
		var par: Array = (s[2] as Array).map(func(q): return q.uid)
		var p := _spawn(world, site, rng, s[0], s[1], s[4], par, s[3])
		gen5.append(p)
	gen5[2].skills[&"engineering"] = 3.4
	gen5[1].skills[&"engineering"] = 2.6
	(gen5[0] as Person).traits.assign([&"brave", &"curious"])
	# Grace and Gene have families: their partners came from the city's other lines
	for gi in [4, 5]:
		var parent: Person = gen5[gi]
		var psex := "m" if parent.sex == "f" else "f"
		var mate := _spawn(world, site, rng, "", psex, parent.age + rng.randf_range(-80, 80), [], 3.5, true)
		mate.partner = parent.uid
		parent.partner = mate.uid
		for k in 3:
			var sx := "f" if rng.randf() < 0.5 else "m"
			var age: float = [700.0, 480.0, 150.0][k] + rng.randf_range(-40, 40)
			_spawn(world, site, rng, "", sx, age, [parent.uid, mate.uid], 3.6 + rng.randf() * 0.8)
	# the rest of the city: other families, all in the clothes of their trade
	for f in 12:
		var a := _spawn(world, site, rng, "", "f", rng.randf_range(1100, 2700), [], rng.randf_range(2.6, 4.6), f % 3 == 0)
		var b := _spawn(world, site, rng, "", "m", rng.randf_range(1100, 2700), [], rng.randf_range(2.6, 4.6), f % 3 == 1)
		a.partner = b.uid
		b.partner = a.uid
		for k in rng.randi_range(1, 3):
			var sx := "f" if rng.randf() < 0.5 else "m"
			var age := rng.randf_range(80.0, 1400.0) if k > 0 else rng.randf_range(380.0, 880.0)
			_spawn(world, site, rng, "", sx, age, [a.uid, b.uid], rng.randf_range(3.0, 4.8))
	for k in 6:
		_spawn(world, site, rng, "", "f" if k % 2 == 0 else "m", rng.randf_range(3000, 3300), [], rng.randf_range(2.8, 4.4))
	# give everyone a trade, so the crowd wears the colours of the city's work
	var trades := [&"engineering", &"metalwork", &"scholarship", &"building", &"crafting", &"farming", &"engineering", &"gathering"]
	var i := 0
	for p in Village.people:
		if is_instance_valid(p) and p.visual != null and int(p.stage) >= Person.Stage.ADULT:
			p.visual.set_job_colour(trades[(i * 5 + int(p.uid)) % trades.size()])
			i += 1
	# the Book remembers everyone
	for u in _rec:
		BookData.remember(_rec[u])
		for k in ["born_day", "died_day", "cause", "first_two"]:
			BookData.set_person_fact(u, k, _rec[u][k])
		if _rec[u]["first_two"]:
			BookData.mark_hand_named(u)
	for p in Village.people:
		if is_instance_valid(p):
			BookData.remember(BookData.record_of(p))
			BookData.set_person_fact(p.uid, "born_day", maxi(DAY - int(p.age / 105.0 * 1.0), 1))
	BookData.journal()["first_two_set"] = true
	Village.stats["births"] = Village.people.size() + _rec.size() - 2
	Village.stats["deaths"] = _rec.size()

static func _names() -> Array:
	var out: Array = []
	for u in _rec:
		out.append(_rec[u]["name"])
	return out

## The Book, from the storm night to the launch: firsts, gifts, memories, the dream.
static func _journal() -> void:
	var j := BookData.journal()
	var e: Array = j["entries"]
	var add := func(kind: String, day: int, era: int, text: String) -> void:
		e.append({"kind": kind, "day": day, "era": era, "text": text})
	add.call("first", 1, 1, "On the first night the storm drove two of us to the cave: Ona and Tuk. The hand gave us our names.")
	add.call("first", 1, 1, "On the first night the hand lifted the fallen branch from the cave mouth, and we ran in out of the rain.")
	add.call("first", 2, 1, "On the second day the hand lifted Ona for the first time. She did not fall.")
	add.call("first", 3, 1, "On the third day the hand brought us the log for our first fire.")
	add.call("first", 5, 1, "On the fifth day Tuk left a handprint stone at the fire for the hand, our first gift. The hand took it up, and we were glad.")
	add.call("first", 9, 1, "On the ninth day Pim was born to Ona and Tuk, the first child of the valley.")
	add.call("building", 14, 1, "On the fourteenth day we piled a cairn of stones for the hand.")
	add.call("first", 33, 1, "We lived through our first winter. Seven of us saw the spring.")
	add.call("gift", 40, 1, "On the fortieth day Ona left a carved hand for the hand.")
	add.call("era", 66, 2, "On the sixty-sixth day the Age of the Village began.")
	add.call("memory", 88, 2, "On the eighty-eighth day the river rose, and the hand lifted Maren and the children to the high ground.")
	add.call("gift", 102, 2, "On the 102nd day Corin left a painted pot for the hand.")
	add.call("era", 170, 3, "On the 170th day the Age of the Town began.")
	add.call("memory", 211, 3, "On the 211th day the bell rang for the fire in the lane, and the hand carried water until it was out.")
	add.call("gift", 240, 3, "On the 240th day Clara left a clockwork hand for the hand.")
	add.call("era", 301, 4, "On the 301st day the Age of the Launch began.")
	add.call("dream", 360, 4, "On the 360th day our dream came true: \"We will build a tower where the shrine stood.\"")
	add.call("gift", 371, 4, "On the 371st day Valentina left a model rocket for the hand.")
	add.call("dream", 410, 4, "On the 410th day our dream came true: \"To go where the hand comes from.\"")
	for k in ["names", "branch", "lifted", "fire", "gift", "birth", "hut", "winter", "building_cairn"]:
		j["firsts"][k] = 1
	j["gifts"] = [
		{"uid": 1, "kind": "handprint stone", "from": "Tuk", "day": 5, "era": 1},
		{"uid": 2, "kind": "carved hand", "from": "Ona", "day": 40, "era": 1},
		{"uid": 3, "kind": "painted pot", "from": "Corin", "day": 102, "era": 2},
		{"uid": 4, "kind": "clockwork hand", "from": "Clara", "day": 240, "era": 3},
		{"uid": 5, "kind": "model rocket", "from": "Valentina", "day": 371, "era": 4},
	]
	j["dreams"]["the_rocket"] = {"start": 380, "done": 410, "era": 4}
	Village.stats["gifts"] = 5
