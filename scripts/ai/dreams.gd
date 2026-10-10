class_name Dreams extends Node
## Village Dreams: the active era's DreamDefs, one at a time in EraDef order
## (the last is the gate). Checks conditions on sim_tick (once a second),
## emits Events.dream_started / dream_done, and grants reward_faith and
## unlocks_powers. Progress lives in Village.stats so it saves with Village:
##   stats["dreams_done"]: Array[String], stats["dream_active"]: String,
##   stats["era_gate_done"]: int (the era whose gate dream is done).

var _acc: float = 0.0

func _ready() -> void:
	Events.sim_tick.connect(_on_tick)
	Events.era_changed.connect(func(_e): _acc = 1.0)

func _on_tick(dt: float) -> void:
	_acc += dt
	if _acc < 1.0:
		return
	_acc = 0.0
	update()

## Runs one check: announces the active dream, completes it when met.
func update() -> void:
	var d := active_dream()
	if d == null:
		return
	if str(Village.stats.get("dream_active", "")) != str(d.id):
		Village.stats["dream_active"] = str(d.id)
		Events.dream_started.emit(d.id)
	if Dreams.met(d):
		complete(d)

static func done_list() -> Array:
	if not Village.stats.has("dreams_done"):
		Village.stats["dreams_done"] = []
	return Village.stats["dreams_done"]

static func is_done(id: StringName) -> bool:
	return done_list().has(str(id))

## The first not-done dream of the current era, or null.
static func active_dream() -> DreamDef:
	var e := Defs.era(Village.era)
	if e == null:
		return null
	for id in e.dreams:
		if not is_done(id):
			return Defs.dream(id)
	return null

static func met(d: DreamDef) -> bool:
	for b in d.needs_buildings:
		if Village.count_buildings(b) < int(d.needs_buildings[b]):
			return false
	for k in d.needs_stores:
		var have := Village.food() if k == &"food" else Village.store(k)
		if have < int(d.needs_stores[k]):
			return false
	if d.needs_population > 0 and Village.population() < d.needs_population:
		return false
	if d.needs_survive_winter and int(Village.stats.get("winters_survived", 0)) < 1:
		return false
	return true

## Line for the UI, e.g. "Hut 1/2, Fire circle 0/1".
static func progress_text(d: DreamDef) -> String:
	var parts: Array[String] = []
	for b in d.needs_buildings:
		var bd := Defs.building(b)
		parts.append("%s %d/%d" % [bd.title if bd else str(b), mini(Village.count_buildings(b), int(d.needs_buildings[b])), int(d.needs_buildings[b])])
	for k in d.needs_stores:
		var have := Village.food() if k == &"food" else Village.store(k)
		parts.append("%s %d/%d" % [k, mini(have, int(d.needs_stores[k])), int(d.needs_stores[k])])
	if d.needs_population > 0:
		parts.append("people %d/%d" % [mini(Village.population(), d.needs_population), d.needs_population])
	if d.needs_survive_winter:
		parts.append("survive a winter")
	return ", ".join(parts)

static func complete(d: DreamDef) -> void:
	if is_done(d.id):
		return
	done_list().append(str(d.id))
	Village.stats["dream_active"] = ""
	Faith.add(d.reward_faith)
	for p in d.unlocks_powers:
		Faith.grant(p)
	if d.gate:
		Village.stats["era_gate_done"] = d.era
	Events.dream_done.emit(d.id)
