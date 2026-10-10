class_name Wants extends RefCounted
## Wants are optional bonuses, not chores (playtest era 1, note 29: "having to
## switch their jobs seemingly at random"). Now and then someone would love to
## do something else, for a reason they can say ("Pim would love to tend the
## fire: he's cold"). Granting it (setting them on that work) brings joy,
## trust and bonus faith; ignoring it costs nothing, it simply fades.
## They are rare: a long gap per person, and only a few at once in the village.
## Person keeps the state (wish, wish_t, saved); Person._sim_wish and
## Person._grant_wish call in here. The reason lives in the "wish_why" meta
## and is worked out again if missing (after a load).

const LIFETIME := 120.0                       # seconds a want stays before it fades
const GAP := Vector2(1100.0, 1900.0)          # game seconds between one want and the next, per person
const FIRST_GAP := Vector2(300.0, 900.0)      # before a person's first want after the onboarding
const PEOPLE_PER_WANT := 5                    # at most one active want per this many people (at least one)
const FAITH := Vector2(4.0, 6.0)              # bonus faith for a granted want
const GIFT_CHANCE := 0.12                     # a granted want sometimes leaves a gift as well

static func active_count() -> int:
	var n := 0
	for p in Village.people:
		if is_instance_valid(p) and p.alive() and p.wish != &"":
			n += 1
	return n

static func max_active() -> int:
	return maxi(1, Village.population() / PEOPLE_PER_WANT)

static func sim(p: Person, dt: float) -> void:
	if p.stage == Person.Stage.BABY:
		return
	if not Flags.onboarding_done() and p.wish == &"":
		return             # the first minutes teach one want at a time (onboarding.gd)
	p.wish_t -= dt
	if p.wish != &"":
		if p.wish == &"warmth" and p.needs[&"warmth"] > 0.6:
			Wants.fade(p)                         # warm again: nothing to ask for
		elif p.wish_t <= 0.0:
			Wants.fade(p)
		return
	if p.wish_t > 0.0 or p.stage == Person.Stage.CHILD:
		return
	if Wants.active_count() >= Wants.max_active():
		p.wish_t = Game.rng.randf_range(60.0, 180.0)
		return
	var pick := Wants.choose(p)
	if pick.is_empty():
		p.wish_t = 60.0
		return
	p.wish = pick["id"]
	p.wish_t = LIFETIME
	p.set_meta(&"wish_why", pick["why"])
	p._show_wish()

## A want that passed unanswered: no blame, it just goes.
static func fade(p: Person) -> void:
	p.wish = &""
	p.wish_t = Game.rng.randf_range(GAP.x, GAP.y)
	if p.has_meta(&"wish_why"):
		p.remove_meta(&"wish_why")
	p._show_wish()

## What they would love to do, and why: {id, why}, or {} for nothing.
static func choose(p: Person) -> Dictionary:
	if p.needs[&"warmth"] < 0.3 and Faith.has(&"warmth"):
		return {"id": &"warmth", "why": "%s is cold" % Wants._they(p)}
	var mine := p._job_def()
	var opts: Array = []          # [id, why, weight]
	var seen := {}
	for s in Village.sites:
		if not is_instance_valid(s) or s.is_plot() or s.job == null or not s.can_accept(1) or not p.can_do(s):
			continue
		var id: StringName = s.job.id
		if (mine != null and id == mine.id) or seen.has(id) or s.job.needs_blessed or s.job.once:
			continue
		seen[id] = true
		var why := Wants.reason_for(p, s.job)
		opts.append([id, why, 2 if p.stars(Person._family(s.job.skill)) >= 2 or why.contains("cold") else 1])
	if opts.is_empty():
		return {}
	var total := 0
	for o in opts:
		total += int(o[2])
	var r := Game.rng.randi() % total
	for o in opts:
		r -= int(o[2])
		if r < 0:
			return {"id": o[0], "why": o[1]}
	return {"id": opts[0][0], "why": opts[0][1]}

## Why `p` would like the work `jd`, in a few plain words.
static func reason_for(p: Person, jd: JobDef) -> String:
	var they := Wants._they(p)
	if jd.id == &"tend_fire" and p.needs[&"warmth"] < 0.5:
		return "%s is cold" % they
	if jd.id in [&"gather_berries", &"rich_berries", &"hunt", &"fish_by_hand", &"fish_boat"] and Village.food() < Village.population() * 2:
		return "the food is running low"
	if jd.id in [&"fetch_water", &"draw_water"] and Village.store(&"water") < Village.population():
		return "the water jars are nearly empty"
	if p.stars(Person._family(jd.skill)) >= 2:
		return "%s is good at it" % they
	if jd.kind == JobDef.Kind.GROUP or jd.kind == JobDef.Kind.DEVOTION:
		return "%s would like the company" % they
	if p.has_trait(&"curious"):
		return "%s is curious about it" % they
	return "%s fancies a change" % they

## The reason for the current want (kept as meta, worked out again if missing).
static func why(p: Person) -> String:
	if p.wish == &"":
		return ""
	if p.has_meta(&"wish_why"):
		return str(p.get_meta(&"wish_why"))
	if p.wish == &"warmth":
		return "%s is cold" % Wants._they(p)
	var jd := Defs.job(p.wish)
	return Wants.reason_for(p, jd) if jd != null else ""

## The want in a line: "Pim would love to tend the fire: he's cold."
static func line(p: Person) -> String:
	if p.wish == &"":
		return ""
	var what := "be warmed by the hand (Warmth)" if p.wish == &"warmth" else p._wish_title()
	var w := Wants.why(p)
	return "%s would love to %s%s" % [p.given_name, what, (": " + w) if w != "" else ""]

static func grant(p: Person) -> void:
	var first := Flags.onboarding_done()
	var why := Wants.why(p)
	p.wish = &""
	p.wish_t = Game.rng.randf_range(GAP.x, GAP.y)
	if p.has_meta(&"wish_why"):
		p.remove_meta(&"wish_why")
	p.adjust_trust(1.0)
	p.needs[&"joy"] = minf(p.needs[&"joy"] + 0.3, 1.0)
	var f := Game.rng.randf_range(FAITH.x, FAITH.y) if first else 2.0
	Faith.add(f, p.global_position)
	if first:
		Events.toast.emit("%s got what %s wanted (+%d faith)" % [p.given_name, BookData.pronoun(p.sex, "she"), int(round(f))])
	if Game.rng.randf() < GIFT_CHANCE and first:
		Gifts.spawn_gift(p)
	p._show_wish()

static func _they(p: Person) -> String:
	return BookData.pronoun(p.sex, "she")
