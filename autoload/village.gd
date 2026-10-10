extends Node
## The village's shared state: who lives here, what work exists, the stores,
## the era and the regions that are open. Nodes register themselves on
## _ready and unregister on _exit_tree, so lists here are always live.

var era: int = 1
var people: Array = []            # Person nodes, alive or dead-but-not-freed
var sites: Array = []             # Site nodes (jobs, plots, buildings)
var stores: Dictionary = {}       # StringName -> int
var store_cap: int = 40
var regions: Dictionary = {&"clearing": true}
var stats: Dictionary = {"births": 0, "deaths": 0, "joined": 0, "winters_survived": 0, "gifts": 0}
var next_person_id: int = 1

func register_person(p) -> void:
	if not people.has(p):
		people.append(p)

func unregister_person(p) -> void:
	people.erase(p)

func register_site(s) -> void:
	if not sites.has(s):
		sites.append(s)

func unregister_site(s) -> void:
	sites.erase(s)

func alive() -> Array:
	return people.filter(func(p): return is_instance_valid(p) and p.alive())

func population() -> int:
	var n := 0
	for p in people:
		if is_instance_valid(p) and p.alive():
			n += 1
	return n

func store(kind: StringName) -> int:
	return stores.get(kind, 0)

func add_store(kind: StringName, n: int) -> int:
	var before := store(kind)
	stores[kind] = clampi(before + n, 0, store_cap)
	Events.resource_changed.emit(kind, stores[kind])
	return stores[kind] - before

func take_store(kind: StringName, n: int) -> bool:
	if store(kind) < n:
		return false
	stores[kind] = store(kind) - n
	Events.resource_changed.emit(kind, stores[kind])
	return true

## Food is several kinds (berries, meat, fish, bread); this sums them.
const FOOD_KINDS: Array[StringName] = [&"berries", &"meat", &"fish", &"bread"]
func food() -> int:
	var t := 0
	for k in FOOD_KINDS:
		t += store(k)
	return t

func eat_one() -> bool:
	for k in FOOD_KINDS:
		if take_store(k, 1):
			return true
	return false

func count_buildings(id: StringName) -> int:
	var n := 0
	for s in sites:
		if is_instance_valid(s) and s.is_finished_building(id):
			n += 1
	return n

func open_region(id: StringName) -> void:
	if regions.has(id):
		return
	regions[id] = true
	Events.region_opened.emit(id)

## People with nothing to do: alive, past babyhood, on no job and not busy
## eating, sleeping, sheltering or running (the HUD counts them).
func idle_people() -> Array:
	return alive().filter(func(p): return p.stage != Person.Stage.BABY and p.pickable() \
		and (p.job_site == null or not is_instance_valid(p.job_site)) and p.state in [Person.S.IDLE, Person.S.WALK])

## The "Call" gesture (Austin's Era 2 notes): every idle person walks over to
## `to` (the hand's spot) and waits there a while, so the hand can scoop them
## up in one go. Returns how many answered. The hand binds it to C
## (Game.ACTIONS hand_call); the HUD's call button calls it too.
func call_idle(to: Vector3) -> int:
	var n := 0
	for p in idle_people():
		if p.answer_call(to):
			n += 1
	stats["calls"] = int(stats.get("calls", 0)) + 1
	if n > 0:
		Events.toast.emit("%d idle %s coming to the hand" % [n, "person is" if n == 1 else "people are"])
	else:
		Events.toast.emit("Nobody is idle")
	return n

func new_person_id() -> int:
	next_person_id += 1
	return next_person_id - 1

func save_state() -> Dictionary:
	var st := {}
	for k in stores:
		st[str(k)] = stores[k]
	return {"era": era, "stores": st, "store_cap": store_cap,
		"regions": regions.keys().map(func(k): return str(k)), "stats": stats,
		"next_person_id": next_person_id}

func load_state(d: Dictionary) -> void:
	era = d.get("era", 1)
	stores.clear()
	for k in d.get("stores", {}):
		stores[StringName(k)] = int(d["stores"][k])
	store_cap = d.get("store_cap", 40)
	regions.clear()
	for k in d.get("regions", ["clearing"]):
		regions[StringName(k)] = true
	stats = d.get("stats", stats)
	next_person_id = d.get("next_person_id", 1)
