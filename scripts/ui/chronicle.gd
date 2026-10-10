class_name Chronicle extends Node
## Listens to Events and writes the Village Book's journal in the people's voice:
## firsts (fire, hut, birth, winter...), gifts received, memorials, dreams,
## powers, regions and names. Everything goes into BookData.journal(), which
## lives in Village.stats and so saves with the village. The HUD owns one.

const RECENT_HAND := 25.0        # seconds: a fire lit this soon after the hand set a log down was the hand's doing

var _acc: float = 0.0
var _last_hand_object_t: float = -1000.0
var _last_hand_object: String = ""

func _ready() -> void:
	name = "Chronicle"
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.person_born.connect(_on_born)
	Events.person_joined.connect(_on_joined)
	Events.person_died.connect(_on_died)
	Events.building_finished.connect(_on_building)
	Events.dream_started.connect(_on_dream_started)
	Events.dream_done.connect(_on_dream_done)
	Events.power_unlocked.connect(_on_power)
	Events.region_opened.connect(_on_region)
	Events.season_changed.connect(_on_season)
	Events.era_changed.connect(_on_era)
	Events.names_given.connect(_on_names_given)
	Events.hand_lifted_object.connect(_on_hand_lifted_object)
	Events.hand_placed_object.connect(_on_hand_placed_object)
	Events.hand_lifted.connect(_on_hand_lifted)
	Events.sim_tick.connect(_on_tick)

# ---------------------------------------------------------------- people

func _rec(p) -> Dictionary:
	if p == null or not is_instance_valid(p) or not (&"given_name" in p):
		return {}
	return BookData.record_of(p)

func _name_of(uid: int) -> String:
	for p in Village.people:
		if is_instance_valid(p) and int(p.uid) == uid:
			return str(p.given_name)
	var r: Dictionary = BookData.journal()["people"].get(str(uid), {})
	return str(r.get("name", ""))

func _parents_text(r: Dictionary) -> String:
	var ns: Array = []
	for u in r.get("parents", []):
		var n := _name_of(int(u))
		if n != "":
			ns.append(n)
	return BookData.join_names(ns)

func _on_born(p) -> void:
	var r := _rec(p)
	if r.is_empty():
		return
	r["born_day"] = Clock.day
	BookData.remember(r)
	_mark_era()
	var par := _parents_text(r)
	if BookData.set_first("birth"):
		BookData.add_entry("first", "%s %s was born to %s, the first child of the valley." % [BookData.on_day(Clock.day), r["name"], par if par != "" else "us"])
	else:
		BookData.add_entry("birth", "%s %s was born to %s." % [BookData.on_day(Clock.day), r["name"], par if par != "" else "us"])

func _on_joined(p) -> void:
	var r := _rec(p)
	if r.is_empty():
		return
	r["joined_day"] = Clock.day
	r["wanderer"] = true
	BookData.remember(r)
	if BookData.set_first("wanderer"):
		BookData.add_entry("first", "%s %s walked into the valley and stayed with us. We were no longer alone." % [BookData.on_day(Clock.day), r["name"]])
	else:
		BookData.add_entry("joined", "%s %s came to live with us." % [BookData.on_day(Clock.day), r["name"]])

func _on_died(p) -> void:
	var r := _rec(p)
	if r.is_empty():
		return
	var cause := ""
	for m in get_tree().get_nodes_in_group(&"memorial"):
		if is_instance_valid(m) and int(m.get(&"person_uid")) == int(r["uid"]):
			cause = str(m.get(&"cause"))
	r["alive"] = false
	r["died_day"] = Clock.day
	r["cause"] = cause
	BookData.remember(r)
	var why := ""
	if cause != "":
		why = " of %s" % cause if cause in ["old age", "cold", "hunger", "thirst", "sickness", "the cold"] else " (%s)" % cause
	BookData.add_entry("memorial", "%s %s died%s. We carved %s name on the stones by the shrine." % [BookData.on_day(Clock.day), r["name"], why, BookData.pronoun(r["sex"], "her")])

func _on_names_given(people: Array) -> void:
	var named: Array = []
	var hand: Array = []
	for p in people:
		var r := _rec(p)
		if r.is_empty():
			continue
		if r["hand_named"]:
			BookData.mark_hand_named(r["uid"])
			hand.append(r)
		named.append(r)
		BookData.remember(r)
	if named.size() >= 2 and not BookData.has_first("names"):
		BookData.set_first("names")
		BookData.journal()["first_two_set"] = true
		for r in named:
			BookData.set_person_fact(r["uid"], "first_two", true)
		var who := BookData.join_names(named.map(func(r): return r["name"]))
		var by := "The hand gave us our names." if not hand.is_empty() else "The hand looked down and called us by our names."
		BookData.add_entry("first", "On the first night the storm drove two of us to the cave: %s. %s" % [who, by], 1)
	else:
		for r in hand:
			var par := _parents_text(r)
			BookData.add_entry("named", "%s %s knelt at the shrine, and the hand named their child %s." % [BookData.on_day(Clock.day), par if par != "" else "a family", r["name"]])

# ---------------------------------------------------------------- the hand

func _on_hand_lifted(people: Array) -> void:
	if people.is_empty() or BookData.has_first("lifted"):
		return
	var r := _rec(people[0])
	if r.is_empty():
		return
	BookData.set_first("lifted")
	BookData.add_entry("first", "%s the hand lifted %s for the first time. %s did not fall." % [BookData.on_day(Clock.day), r["name"], BookData.pronoun(r["sex"], "she").capitalize()])

static func object_title(obj: Node) -> String:
	if obj == null or not is_instance_valid(obj):
		return ""
	var t = obj.get(&"title")
	if t is String and t != "":
		return t
	if obj.has_method(&"title"):
		var s = obj.call(&"title")
		if s is String:
			return s
	return String(obj.name)

func _on_hand_lifted_object(obj: Node3D) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	if obj.is_in_group(&"gift"):
		_on_gift(obj)
		return
	var t := object_title(obj).to_lower()
	if t.contains("branch") and BookData.set_first("branch"):
		BookData.add_entry("first", "On the %s night the hand lifted the fallen branch from the cave mouth, and we ran in out of the rain." % BookData.ordinal(Clock.day))

func _on_hand_placed_object(obj: Node3D, _at: Vector3) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	_last_hand_object_t = Clock.total_t
	_last_hand_object = object_title(obj).to_lower()

func _on_gift(g: Node) -> void:
	var kind := str(g.get(&"kind")) if g.get(&"kind") != null else "gift"
	var from := str(g.get(&"from_name")) if g.get(&"from_name") != null else ""
	var gifts: Array = BookData.journal()["gifts"]
	var uid := int(g.get(&"uid")) if g.get(&"uid") != null else 0
	for e in gifts:
		if uid != 0 and int(e.get("uid", 0)) == uid:
			return
	gifts.append({"uid": uid, "kind": kind, "from": from, "day": Clock.day, "era": Village.era})
	var who := from if from != "" else "Someone"
	if BookData.set_first("gift"):
		BookData.add_entry("first", "%s %s left %s at the fire for the hand, our first gift. The hand took it up, and we were glad." % [BookData.on_day(Clock.day), who, BookData.a_or_an(kind)])
	else:
		BookData.add_entry("gift", "%s %s left %s for the hand." % [BookData.on_day(Clock.day), who, BookData.a_or_an(kind)])

# ---------------------------------------------------------------- the village

const BUILDING_LINES := {
	"hut": "we finished our first hut. That night we slept dry.",
	"fire_circle": "we set stones in a ring around the fire, and sat together inside it.",
	"cairn": "we piled a cairn of stones for the hand.",
	"shrine": "we raised a shrine to the hand, and knelt there.",
	"stone_circle": "the great stones stood in their circle at last.",
	"food_store": "we built a store for our food.",
	"drying_rack": "we built a rack to dry meat and berries.",
}

func _on_building(site) -> void:
	if site == null or not is_instance_valid(site) or site.get(&"building") == null:
		return
	var b = site.building
	var id := str(b.id)
	if not BookData.set_first("building_" + id):
		return
	if id == "hut":
		BookData.set_first("hut")
	var line: String = BUILDING_LINES.get(id, "we finished the %s." % str(b.title).to_lower())
	BookData.add_entry("first" if id == "hut" else "building", "%s %s" % [BookData.on_day(Clock.day), line])

func _on_dream_started(id: StringName) -> void:
	var d: Dictionary = BookData.journal()["dreams"]
	if d.has(str(id)) and d[str(id)].has("told"):
		return
	if not d.has(str(id)):
		d[str(id)] = {"start": Clock.day, "era": Village.era}
	d[str(id)]["told"] = true
	var def: DreamDef = Defs.dream(id)
	if def == null:
		return
	d[str(id)]["voice"] = def.voice
	BookData.add_entry("dreamt", "%s we dreamed of something new: \"%s\"" % [BookData.on_day(Clock.day), def.text])

func _on_dream_done(id: StringName) -> void:
	var d: Dictionary = BookData.journal()["dreams"]
	if not d.has(str(id)):
		d[str(id)] = {"start": Clock.day, "era": Village.era}
	if d[str(id)].has("done"):
		return
	d[str(id)]["done"] = Clock.day
	var def: DreamDef = Defs.dream(id)
	var text := def.text if def != null and def.text != "" else String(id).capitalize()
	BookData.add_entry("dream", "%s our dream came true: \"%s\"" % [BookData.on_day(Clock.day), text])

func _on_power(id: StringName) -> void:
	var p: PowerDef = Defs.power(id)
	if p == null:
		return
	BookData.add_entry("power", "%s the hand grew: %s. %s." % [BookData.on_day(Clock.day), p.title, p.what_it_does.trim_suffix(".")])

func _on_region(id: StringName) -> void:
	BookData.add_entry("region", "%s the way to the %s opened, and we went to look." % [BookData.on_day(Clock.day), BookData.region_title(id)])

func _on_season(season: int) -> void:
	if season != 0:   # spring
		return
	var w := int(Village.stats.get("winters_survived", 0))
	if w <= 0 and Clock.year <= 1:
		return
	if BookData.set_first("winter"):
		var n := Village.population()
		BookData.add_entry("first", "We lived through our first winter. %s of us saw the spring." % BookData.cap(BookData.cardinal(n)))

func _on_era(era: int) -> void:
	_mark_era(era)
	if era > 1:
		BookData.add_entry("era", "%s %s began." % [BookData.on_day(Clock.day), BookData.ERA_AGES.get(era, "a new age")])
		var prev: Dictionary = BookData.journal()["era_marks"].get(str(era - 1), {})
		var gen := EraCard.new_generation(int(prev.get("day", 1)))   # [polish] the new generation, by name
		if not gen.is_empty():
			BookData.add_entry("era", "Our new generation: %s." % BookData.join_names(gen))

## The root of the tree: the first two (the storm-night pair) even if nobody
## asked the hand to name them. They are the two lowest-uid people with no
## parents who did not wander in.
func _find_first_two() -> void:
	var j := BookData.journal()
	if j.get("first_two_set", false):
		return
	var cands: Array = []
	for p in Village.people:
		if is_instance_valid(p) and &"given_name" in p and p.parents.is_empty() and not p.wanderer:
			cands.append(p)
	if cands.size() < 2:
		return
	cands.sort_custom(func(a, b): return a.uid < b.uid)
	for p in cands.slice(0, 2):
		BookData.remember(BookData.record_of(p))
		BookData.set_person_fact(int(p.uid), "first_two", true)
	j["first_two_set"] = true

## Remembers where an era started (time, births, deaths) for the era card.
func _mark_era(era: int = -1) -> void:
	var e := Village.era if era < 0 else era
	var marks: Dictionary = BookData.journal()["era_marks"]
	if not marks.has(str(e)):
		var start_t := 0.0 if e <= 1 else Clock.total_t
		marks[str(e)] = {"t": start_t, "births": 0 if e <= 1 else int(Village.stats.get("births", 0)),
			"deaths": 0 if e <= 1 else int(Village.stats.get("deaths", 0)), "day": 1 if e <= 1 else Clock.day}

func _on_tick(dt: float) -> void:
	_acc += dt
	if _acc < 1.0:
		return
	_acc = 0.0
	_mark_era()
	var w := Game.world
	if w != null and is_instance_valid(w) and w.has_method(&"fire_lit") and not BookData.has_first("fire"):
		if w.fire_lit():
			BookData.set_first("fire")
			var by_hand := Clock.total_t - _last_hand_object_t < RECENT_HAND
			var text := "%s the hand brought us the log for our first fire." % BookData.on_day(Clock.day) if by_hand \
				else "%s we lit our first fire, and the hand watched over it." % BookData.on_day(Clock.day)
			BookData.add_entry("first", text)
	_find_first_two()
	# keep the remembered records fresh (names, stages, families)
	for p in Village.people:
		if is_instance_valid(p) and &"given_name" in p and p.alive():
			BookData.remember(BookData.record_of(p))
