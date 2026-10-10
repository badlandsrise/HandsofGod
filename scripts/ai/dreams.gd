class_name Dreams extends Node
## Village Dreams: the active era's DreamDefs, one at a time in EraDef order
## (the last is the gate). Checks conditions on sim_tick (once a second),
## emits Events.dream_started / dream_done, and grants reward_faith and
## unlocks_powers. Progress lives in Village.stats so it saves with Village:
##   stats["dreams_done"]: Array[String], stats["dream_active"]: String,
##   stats["dream_times"]: {id: game seconds done}, stats["last_dream_t"],
##   stats["era_gate_done"]: int (the era whose gate dream is done).
## Nothing is dreamt before the onboarding reaches its DREAM beat, and each
## dream waits out its quiet_before after the last one (doc 5 pacing rules).

const QUIET_AFTER_MILESTONE := 150.0   # no new threat for this long after a dream is done

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
	if Flags.beat() < Onboarding.Beat.DREAM:
		return
	var d := active_dream()
	if d == null:
		return
	if str(Village.stats.get("dream_active", "")) != str(d.id):
		if Clock.total_t < float(Village.stats.get("last_dream_t", -INF)) + d.quiet_before:
			return
		Village.stats["dream_active"] = str(d.id)
		Village.stats["dream_started_t"] = Clock.total_t
		Events.dream_started.emit(d.id)
		if d.voice != "":
			Events.toast.emit(d.voice)
	if Dreams.met(d):
		complete(d)

static func done_list() -> Array:
	if not Village.stats.has("dreams_done"):
		Village.stats["dreams_done"] = []
	return Village.stats["dreams_done"]

static func is_done(id: StringName) -> bool:
	return done_list().has(str(id))

## The first not-done dream of the current era, or null (also null in a
## placeholder era, which is free play).
static func active_dream() -> DreamDef:
	var e := Defs.era(Village.era)
	if e == null or not e.playable:
		return null
	for id in e.dreams:
		if not is_done(id):
			return Defs.dream(id)
	return null

static func winters_needed(d: DreamDef) -> int:
	return maxi(d.needs_winters, 1 if d.needs_survive_winter else 0)

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
	if int(Village.stats.get("winters_survived", 0)) < Dreams.winters_needed(d):
		return false
	for f in d.needs_flags:
		if not Flags.has(f):
			return false
	return true

## 0..1 how far along the dream is (pips for the HUD).
static func progress(d: DreamDef) -> float:
	var have := 0.0
	var need := 0.0
	for b in d.needs_buildings:
		need += 1.0
		have += minf(float(Village.count_buildings(b)) / float(maxi(int(d.needs_buildings[b]), 1)), 1.0)
	if d.needs_population > 0:
		need += 1.0
		have += minf(float(Village.population()) / float(d.needs_population), 1.0)
	var wn := Dreams.winters_needed(d)
	if wn > 0:
		need += 1.0
		have += minf(float(Village.stats.get("winters_survived", 0)) / float(wn), 1.0)
	for f in d.needs_flags:
		need += 1.0
		have += 1.0 if Flags.has(f) else 0.0
	return have / need if need > 0.0 else 1.0

## Line for the UI, e.g. "Hut 1/1, Fire circle 0/1, people 4/6".
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
	var wn := Dreams.winters_needed(d)
	if wn == 1:
		parts.append("survive a winter" + (" (done)" if int(Village.stats.get("winters_survived", 0)) >= 1 else ""))
	elif wn > 1:
		parts.append("winters %d/%d" % [mini(int(Village.stats.get("winters_survived", 0)), wn), wn])
	for f in d.needs_flags:
		parts.append(("the first festival" if f == &"festival" else str(f).replace("_", " ")) + (" (done)" if Flags.has(f) else ""))
	return ", ".join(parts)

static func complete(d: DreamDef) -> void:
	if is_done(d.id):
		return
	done_list().append(str(d.id))
	Village.stats["dream_active"] = ""
	Village.stats["last_dream_t"] = Clock.total_t
	Village.stats["quiet_until"] = Clock.total_t + QUIET_AFTER_MILESTONE
	if not Village.stats.has("dream_times"):
		Village.stats["dream_times"] = {}
	Village.stats["dream_times"][str(d.id)] = Clock.total_t
	Faith.add(d.reward_faith)
	for p in d.unlocks_powers:
		Faith.grant(p)
	if d.gate:
		Village.stats["era_gate_done"] = d.era
	Flags.remember("With the hand's help we made our dream come true: %s" % d.text.to_lower().trim_suffix("."))
	Events.dream_done.emit(d.id)
