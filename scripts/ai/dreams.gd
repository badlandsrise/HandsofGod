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
		Village.stats["dream_started_winters"] = int(Village.stats.get("winters_survived", 0))
		if d.needs_buildings.has(&"fire_circle") and Village.era == 1:
			Progression.ring_the_fire()       # before the world lays the dream's plots
		Events.dream_started.emit(d.id)
		# The dream card (and the Book) speak the voice; headless test runs
		# skip the card, so the line still reaches the log there.
		if d.voice != "" and Game.testing():
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
	if Dreams.winters_since_start(d) < d.winters_after_start:
		return false
	for r in d.needs_regions:
		if not Village.regions.has(r):
			return false
	return true

## Winters lived through since this dream appeared (0 if it is not the active one).
static func winters_since_start(d: DreamDef) -> int:
	if str(Village.stats.get("dream_active", "")) != str(d.id):
		return 0
	return int(Village.stats.get("winters_survived", 0)) - int(Village.stats.get("dream_started_winters", 0))

static func region_title(r: StringName) -> String:
	return {&"east_bank": "the East Bank", &"southern_plains": "the Southern Plains", &"hill_quarry": "the Hill Quarry", &"coast": "the Coast",
		&"valley_floor": "the Valley Floor", &"western_meadow": "the Western Meadow", &"northern_pass": "the Northern Pass",
		&"pass_road": "the Pass Road"}.get(r, "the " + str(r).replace("_", " ").capitalize())

static func flag_title(f: StringName) -> String:
	return {&"festival": "the first festival", &"harvest_festival": "a harvest festival", &"star_charts": "the star charts"}.get(f, str(f).replace("_", " "))

# ---------------------------------------------------------------- presentation
# The goal panel, the dream card and the Book read a dream as a checklist: one
# line per requirement, each with its own "done", so the player always sees
# what is left. checklist_met(d) == met(d) (tests/ui checks it).

## What each flag a dream needs means, said as the thing to do.
const FLAG_LINES := {
	&"festival": "The first festival: bless the dancers at the fire circle",
	&"harvest_festival": "A harvest festival at the fields",
	&"star_charts": "The star charts, drawn at the observatory",
}
const FLAG_HINTS := {
	&"festival": "Buy Blessing, hold E over six people to bless them, then set them down at the dance spot by the fire circle.",
	&"harvest_festival": "After good harvests and a granary, a festival spot appears by the fields: six or more dance there.",
	&"star_charts": "Astronomers chart the stars at night from the observatory. The Guiding Light helps.",
}
## How a closed region opens, when no power opens it.
const REGION_HINTS := {
	&"valley_floor": "Six people together can haul the fallen trunk off the path.",
	&"western_meadow": "Lift the fallen logs out of the meadow gap (Strength I).",
	&"hill_quarry": "Roll the rockfall boulders aside with the hand.",
}

## One line per requirement of `d`: {key, text, have, need, done, hint, at}.
## `at` is a place worth looking at (a plot to build on), else Vector3.INF.
static func checklist(d: DreamDef) -> Array:
	var out: Array = []
	if d == null:
		return out
	for b in d.needs_buildings:
		var bd: BuildingDef = Defs.building(b)
		var need := int(d.needs_buildings[b])
		var have := Village.count_buildings(b)
		var title: String = bd.title if bd != null else str(b).capitalize()
		var plot := _plot_of(b)
		var hint := ""
		if have < need:
			if plot != null:
				hint = "A plot is marked. Set people on it: they fetch the materials and build."
			else:
				hint = "They will mark a plot for it soon."
		out.append({"key": "b:" + str(b), "text": title, "have": mini(have, need), "need": need,
			"done": have >= need, "hint": hint, "at": plot.global_position if plot != null else Vector3.INF})
	for k in d.needs_stores:
		var have := Village.food() if k == &"food" else Village.store(k)
		var need := int(d.needs_stores[k])
		out.append({"key": "s:" + str(k), "text": "%s in the stores" % str(k).capitalize(), "have": mini(have, need), "need": need,
			"done": have >= need, "hint": "", "at": Vector3.INF})
	if d.needs_population > 0:
		var have := Village.population()
		out.append({"key": "people", "text": "People", "have": mini(have, d.needs_population), "need": d.needs_population,
			"done": have >= d.needs_population,
			"hint": "Bonded couples with a home and food to spare have children. Wanderers come when new places open.", "at": Vector3.INF})
	var wn := Dreams.winters_needed(d)
	if wn > 0:
		var have := int(Village.stats.get("winters_survived", 0))
		out.append({"key": "winters", "text": "Winters lived through" if wn > 1 else "Live through a winter", "have": mini(have, wn), "need": wn,
			"done": have >= wn, "hint": "Keep them fed and warm until spring: fire, huts, and the hand's Warmth.", "at": Vector3.INF})
	for f in d.needs_flags:
		out.append({"key": "f:" + str(f), "text": FLAG_LINES.get(f, Dreams.flag_title(f).capitalize()), "have": 1 if Flags.has(f) else 0, "need": 1,
			"done": Flags.has(f), "hint": FLAG_HINTS.get(f, ""), "at": _flag_spot(f)})
	if d.winters_after_start > 0:
		var have := Dreams.winters_since_start(d)
		out.append({"key": "winter_on_stores", "text": "A winter lived on the stores", "have": mini(have, d.winters_after_start), "need": d.winters_after_start,
			"done": have >= d.winters_after_start, "hint": "Fill the stores before the snow, and keep everyone alive until spring.", "at": Vector3.INF})
	for r in d.needs_regions:
		var open := Village.regions.has(r)
		out.append({"key": "r:" + str(r), "text": "%s opened" % Dreams.region_title(r).capitalize(), "have": 1 if open else 0, "need": 1,
			"done": open, "hint": Dreams.region_hint(r), "at": Vector3.INF})
	return out

static func checklist_met(d: DreamDef) -> bool:
	for it in Dreams.checklist(d):
		if not it["done"]:
			return false
	return true

## How a region opens: the power that opens it, else what the people must do.
static func region_hint(r: StringName) -> String:
	for pd in Defs.powers.values():
		if pd.opens_region == r:
			return "The hand's %s opens it (%d faith)." % [pd.title, int(pd.cost)] if not Faith.has(pd.id) else "Open with %s." % pd.title
	return REGION_HINTS.get(r, "")

static func _plot_of(bid: StringName) -> Node3D:
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == bid and s.is_plot():
			return s
	return null

static func _flag_spot(f: StringName) -> Vector3:
	var job: StringName = {&"festival": &"festival", &"harvest_festival": &"harvest_festival", &"star_charts": &"astronomy"}.get(f, &"")
	if job == &"":
		return Vector3.INF
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == job:
			return s.global_position
	return Vector3.INF

## The dream that comes next when none is active (null if the age is done).
static func next_dream() -> DreamDef:
	return Dreams.active_dream()

## True once the active dream has been announced to the people.
static func revealed(d: DreamDef) -> bool:
	return d != null and str(Village.stats.get("dream_active", "")) == str(d.id)

## 0..1 how close the next dream is to appearing (the quiet after the last).
static func stirring(d: DreamDef) -> float:
	if d == null:
		return 0.0
	if Flags.beat() < Onboarding.Beat.DREAM:
		return clampf(float(Flags.beat()) / float(Onboarding.Beat.DREAM), 0.0, 1.0)
	if d.quiet_before <= 0.0:
		return 1.0
	var since := Clock.total_t - float(Village.stats.get("last_dream_t", -INF))
	return clampf(since / d.quiet_before, 0.0, 1.0)

## A hint for the "The people are restless..." teaser shown before a dream appears.
static func teaser_hint(d: DreamDef) -> String:
	match Flags.beat():
		Onboarding.Beat.STORM: return "The storm. Lift the fallen branch from the cave mouth so they can get in."
		Onboarding.Beat.DAWN, Onboarding.Beat.BERRIES: return "They are hungry. Pick someone up and set them on the berry bushes."
		Onboarding.Beat.FIRE_LOG: return "A log for the fire. It takes two: carry one, then the other, to the log."
		Onboarding.Beat.FIRE_LIT: return "The fire is lit. Keep it fed and they will be glad of you."
		Onboarding.Beat.GIFT: return "They left something by the fire for you. Pick it up."
	if d == null:
		return ""
	match d.id:
		&"shrine_to_the_hand": return "They are settling in. Keep them fed and warm, and keep the fire burning."
		&"stone_circle": return "Something bigger stirs in them. Keep the village growing."
		&"great_bridge": return "They look across the Great River more and more."
		&"temple_of_the_hand": return "They talk of the hand at every fire."
	return "Keep them fed, warm and busy. A dream is stirring."

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
	if d.winters_after_start > 0:
		need += 1.0
		have += minf(float(Dreams.winters_since_start(d)) / float(d.winters_after_start), 1.0)
	for r in d.needs_regions:
		need += 1.0
		have += 1.0 if Village.regions.has(r) else 0.0
	return have / need if need > 0.0 else 1.0

## Line for the UI, e.g. "Hut 1/1, Fire circle 0/1, People 4/6".
static func progress_text(d: DreamDef) -> String:
	var parts: Array[String] = []
	for it in Dreams.checklist(d):
		if int(it["need"]) > 1:
			parts.append("%s %d/%d" % [it["text"], int(it["have"]), int(it["need"])])
		else:
			parts.append(str(it["text"]) + (" (done)" if it["done"] else ""))
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
