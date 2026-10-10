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
	&"western_meadow": "Lift the fallen logs out of the meadow gap.",
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
		var goods: Array = Dreams.made_goods_lines(bd, plot) if have < need and bd != null else []
		if have < need:
			if plot != null:
				hint = "A plot is marked. Set people on it: they fetch the materials and build."
			else:
				hint = "They will mark a plot for it soon."
			for g in goods:
				if not g["done"]:
					hint = "It waits for %s. %s" % [str(g["good"]), g["hint"]]   # the missing link of its chain
					break
		out.append({"key": "b:" + str(b), "text": title, "have": mini(have, need), "need": need,
			"done": have >= need, "hint": hint, "at": plot.global_position if plot != null else Vector3.INF})
		out.append_array(goods)
	for k in d.needs_stores:
		var have := Village.food() if k == &"food" else Village.store(k)
		var need := int(d.needs_stores[k])
		out.append({"key": "s:" + str(k), "text": "%s in the stores" % str(k).capitalize(), "have": mini(have, need), "need": need,
			"done": have >= need, "hint": "", "at": Vector3.INF})
	if d.needs_population > 0:
		var have := Village.population()
		var hint := "Bonded couples with a home and food to spare have children. Wanderers come when new places open."
		if have < d.needs_population and Dreams.beds() <= have:
			hint = "Every home is full: build the homes they ask for, and couples will have children."
		out.append({"key": "people", "text": "People", "have": mini(have, d.needs_population), "need": d.needs_population,
			"done": have >= d.needs_population, "hint": hint, "at": Vector3.INF})
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

# ---------------------------------------------------------------- production chains
# A dream building made of goods the village makes (the bridge's bronze: copper
# ore and charcoal to the smelter) gets a checklist line per good, whose hint
# names the most stuck link of the chain: a workshop with no plot yet, then a
# plot nobody builds, land not open, a workshop nobody works.

static var _producers: Dictionary = {}

## The workshop (or dig) that makes `good`, from Era 2 up to this era (the
## newest one when there are several): {kind: &"building"|&"job", id, job},
## or {} for the basics (wood, stone, food: Era 1 work) and anything nobody makes.
static func producer(good: StringName) -> Dictionary:
	var key := "%s:%d" % [good, Village.era]
	if not _producers.has(key):
		_producers[key] = Dreams._find_producer(good)
	return _producers[key]

static func _find_producer(good: StringName) -> Dictionary:
	var era := Village.era
	var best: Dictionary = {}
	if era < 2:
		return best
	for b: BuildingDef in Defs.buildings.values():
		if b.era < 2 or b.era > era or (not best.is_empty() and b.era <= int(best["era"])):
			continue
		for jid in b.jobs + b.work_jobs:
			var j: JobDef = Defs.job(jid)
			if j != null and j.outputs.has(good):
				best = {"kind": &"building", "id": b.id, "job": j, "era": b.era}
				break
	if not best.is_empty():
		return best
	for j: JobDef in Defs.jobs.values():
		if j.era >= 2 and j.era <= era and j.kind == JobDef.Kind.GATHER and j.outputs.has(good):
			return {"kind": &"job", "id": j.id, "job": j, "era": j.era}
	return {}

## The links behind `n` more of `good`, inputs first: [{good, need, kind, id,
## title, state, at}], state one of &"missing" (no workshop or plot), &"plot"
## (marked, not built), &"idle" (nobody works it), &"closed" (it lies in land
## not open to the people), &"working". Goods already in the stores stop it.
static func chain(good: StringName, n: int, depth: int = 0) -> Array:
	var out: Array = []
	var p := Dreams.producer(good)
	var short := n - Village.store(good)
	if p.is_empty() or short <= 0 or depth > 4:
		return out
	var j: JobDef = p["job"]
	var runs := ceili(float(short) / float(maxi(int(j.outputs[good]), 1)))
	for k in j.inputs:
		out.append_array(Dreams.chain(k, runs * int(j.inputs[k]), depth + 1))
	var row := Dreams.link_state(p)
	row["good"] = good
	row["need"] = short
	out.append(row)
	return out

## Where a link stands now: {kind, id, title, state, at}.
static func link_state(p: Dictionary) -> Dictionary:
	var j: JobDef = p["job"]
	var row := {"kind": p["kind"], "id": p["id"], "job": j.id, "state": &"missing", "at": Vector3.INF}
	var w = Game.world if Game.world != null and is_instance_valid(Game.world) else null
	if p["kind"] == &"building":
		var bd: BuildingDef = Defs.building(p["id"])
		row["title"] = bd.title.to_lower() if bd != null else str(p["id"])
		var plot := _plot_of(p["id"])
		if plot != null:
			row["state"] = &"plot"
			row["at"] = plot.global_position
		for s in Village.sites:
			if is_instance_valid(s) and s.is_finished_building(p["id"]):
				row["at"] = s.global_position
				if row["state"] != &"working":
					row["state"] = &"working" if Dreams._worked(s) else &"idle"
		return row
	row["title"] = j.title.to_lower()
	for s in Village.sites:
		if not is_instance_valid(s) or s.job == null or s.job.id != j.id or s.is_plot():
			continue
		var open: bool = w == null or not w.has_method("region_at") or w.drops == null or w.drops.accessible(w.region_at(s.global_position))
		if not open:
			if row["state"] == &"missing":
				row["state"] = &"closed"
			continue
		if row["state"] != &"working":
			row["state"] = &"working" if Dreams._worked(s) else &"idle"
			row["at"] = s.global_position
	if row["state"] == &"missing":
		row["state"] = &"closed"       # its dig sites come with the land they lie in
	return row

static func _worked(s) -> bool:
	if s.slots_filled() > 0:
		return true
	for c in Village.sites:     # a workplace's crew works its task sites
		if is_instance_valid(c) and c.parent_uid == s.uid and s.uid != 0 and c.slots_filled() > 0:
			return true
	return false

const LINK_RANK := {&"missing": 4, &"plot": 3, &"closed": 2, &"idle": 1}

## What to do about a link that is not working.
static func link_hint(row: Dictionary) -> String:
	match row["state"]:
		&"missing": return "No %s yet: they will mark a plot for one soon." % row["title"]
		&"plot": return "The %s plot is marked: set people on it to build it." % row["title"]
		&"idle": return "Nobody works the %s: set someone on it (%s)." % [row["title"], Defs.job(row["job"]).title.to_lower()]
		&"closed": return "%s: the land where it lies is not open to them yet." % Defs.job(row["job"]).title
	return ""

## Checklist lines for the made goods a dream building needs (bronze, pots,
## cloth...), each naming the first link of its chain that is not running.
static func made_goods_lines(bd: BuildingDef, plot: Node3D) -> Array:
	var out: Array = []
	for k in bd.cost:
		if Dreams.producer(k).is_empty():
			continue
		var need := int(bd.cost[k])
		var got: int = int(plot.delivered.get(k, 0)) if plot != null and "delivered" in plot else 0
		var have := got + Village.store(k)
		var hint := ""
		var at := Vector3.INF
		var worst := 0
		for row in Dreams.chain(k, need - got):
			var rank: int = LINK_RANK.get(row["state"], 0)
			if rank > worst:       # the most stuck link: no workshop, then an unbuilt plot, ...
				worst = rank
				hint = Dreams.link_hint(row)
				at = row["at"]
		if hint == "" and have < need:
			hint = "They are making it: keep the workshops staffed."
		out.append({"key": "m:%s:%s" % [bd.id, k], "good": str(k), "text": "%s for the %s" % [str(k).capitalize(), bd.title.to_lower().trim_prefix("the ")],
			"have": mini(have, need), "need": need, "done": have >= need, "hint": hint if have < need else "", "at": at})
	return out

## The workshops the active dream is waiting on that have no plot yet
## (VillageEra2 lays them first).
static func missing_workshops(d: DreamDef) -> Array:
	var out: Array = []
	if d == null:
		return out
	for b in d.needs_buildings:
		var bd: BuildingDef = Defs.building(b)
		if bd == null or Village.count_buildings(b) >= int(d.needs_buildings[b]):
			continue
		var plot := _plot_of(b)
		for k in bd.cost:
			var got: int = int(plot.delivered.get(k, 0)) if plot != null else 0
			for row in Dreams.chain(k, int(bd.cost[k]) - got):
				if row["kind"] == &"building" and row["state"] == &"missing" and not out.has(row["id"]):
					out.append(row["id"])
	return out

## Beds in the village's homes (finished shelters that are not far-bank camps).
static func beds() -> int:
	var n := 0
	for s in Village.sites:
		if is_instance_valid(s) and s.state == Site.State.FINISHED and s.building != null and s.building.shelter > 0 and not s.building.camp:
			n += s.building.shelter
	return n

static func checklist_met(d: DreamDef) -> bool:
	for it in Dreams.checklist(d):
		if not it["done"]:
			return false
	return true

## How a region opens: the power that opens it, else what the people must do.
static func region_hint(r: StringName) -> String:
	var pd := Dreams.region_power(r)
	if pd != null and pd.opens_region == r:
		return "The hand's %s opens it (%d faith)." % [pd.title, int(pd.cost)] if not Faith.has(pd.id) else "Open with %s." % pd.title
	var how: String = REGION_HINTS.get(r, "")
	if pd != null and not Faith.has(pd.id):
		how += " The hand needs %s for that (%d faith)." % [pd.title, int(pd.cost)]
	return how.strip_edges()

## Regions the hand opens by lifting something heavy: the power that lets it.
const REGION_LIFT_POWERS := {&"western_meadow": &"strength_1", &"hill_quarry": &"strength_2"}

## The power a region waits on (it opens it, or lets the hand clear its way), or null.
static func region_power(r: StringName) -> PowerDef:
	for pd in Defs.powers.values():
		if pd.opens_region == r:
			return pd
	return Defs.power(REGION_LIFT_POWERS.get(r, &""))

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
