class_name PersonInfo extends RefCounted
## Words for the hand's tooltip and the Book that explain what people and
## things are doing and why (playtest era 1, section 1):
##  - who someone is ("Kai · child, 8"), and why they are idle ("resting for
##    the night", "cold: looking for a fire", "no work: set them on a job");
##  - "Too young to work (age 8)" when a child is held over work;
##  - what the drying rack, hides, knapping and the hunt are for;
##  - discovery lines that say why ("Teo learned to make stone tools because
##    you kept her knapping");
##  - "Mira and Teo want a home of their own" (the pair, by name).
## Pure functions over the live village, so tests can call them directly.

## A tuning number from Progression, read softly so a rename there does not
## break the tooltips.
static func tune(key: StringName, fallback: int) -> int:
	var m: Dictionary = (Progression as Script).get_script_constant_map()
	return int(m.get(key, m.get(String(key), fallback)))

## One year of a person's life is one game minute (Person.STAGE_START).
static func years(p) -> int:
	return int(float(p.age) / 60.0)

## "Kai · child, 8", "Ona", "Bo · elder".
static func header(p: Person) -> String:
	match p.stage:
		Person.Stage.BABY: return "%s · baby" % p.given_name
		Person.Stage.CHILD: return "%s · child, %d" % [p.given_name, PersonInfo.years(p)]
		Person.Stage.ELDER: return "%s · elder" % p.given_name
	return p.given_name

## Can this child (or anyone) do any work in this age? Children help with
## light work from the Village age (Person.can_do).
static func too_young(p: Person, s: Site = null) -> bool:
	if p.stage == Person.Stage.BABY:
		return true
	if p.stage != Person.Stage.CHILD:
		return false
	if s != null and is_instance_valid(s):
		return not p.can_do(s)
	return Village.era < 2

static func too_young_line(p: Person) -> String:
	return "%s is too young to work (age %d)" % [p.given_name, PersonInfo.years(p)]

## What the child can do instead, said once.
static func child_rule() -> String:
	if Village.era < 2:
		return "Children cannot work yet. They grow up at 15, and from the Village age they help with light work."
	return "Children only do light work: berries, water, sheep, and later school."

## Why an idle person is idle.
static func idle_reason(p: Person) -> String:
	if p.stage == Person.Stage.BABY:
		return "a baby, kept close by the family"
	if p.stage == Person.Stage.CHILD and Village.era < 2:
		return "playing (too young to work)"
	if p.has_method(&"is_sick") and p.is_sick():
		return "sick: carry them to the clinic"
	if p.needs[&"warmth"] < 0.3 and p._is_cold():
		return "cold: looking for a fire"
	if p.needs[&"food"] < 0.3 and Village.food() <= 0:
		return "hungry, and the stores are empty"
	if p.needs[&"water"] < 0.3 and Village.store(&"water") <= 0 and Village.era >= 2:
		return "thirsty, and the water jars are empty"
	if Clock.is_night:
		return "resting for the night"
	if p.stage == Person.Stage.CHILD:
		return "playing (set them on light work: berries or water)"
	return "idle: no work. Set them on a job"

static func is_idle(p) -> bool:
	if not is_instance_valid(p) or not p.alive() or not p.visible or p.stage == Person.Stage.BABY:
		return false
	if p.job_site != null and is_instance_valid(p.job_site):
		return false
	if p.stage == Person.Stage.CHILD and Village.era < 2:
		return false
	return p.state == Person.S.IDLE or (p.state == Person.S.WALK and p._offering == null)

static func idle_people() -> Array:
	return Village.people.filter(func(p): return PersonInfo.is_idle(p))

## The activity line: Person.status_text with the idle reason and the want
## said plainly.
static func status(p: Person) -> String:
	var parts: Array = []
	for part in p.status_text().split(" · ", false):
		if part.begins_with("wants: "):
			continue
		parts.append(part)
	if parts.is_empty():
		parts.append("idle")
	if parts[0] == "idle" or (p.state == Person.S.WALK and p.job_site == null and p._offering == null and parts[0] == "idle"):
		parts[0] = PersonInfo.idle_reason(p)
	if p.is_blessed():
		var i := parts.find("blessed")
		var t := "blessed, %d s left" % ceili(p.blessed_t)
		if i >= 0:
			parts[i] = t
		else:
			parts.append(t)
	return " · ".join(parts)

## The hand's tooltip over a person.
static func tooltip(p: Person) -> String:
	var lines: Array = [PersonInfo.header(p), PersonInfo.status(p)]
	var w := Wants.line(p)
	if w != "":
		lines.append(w + " (bonus faith)")
	return "\n".join(lines)

## A note added when the hand holds people over a site, e.g. a child over work.
static func held_note(held: Array, s: Site) -> String:
	if s == null or not is_instance_valid(s):
		return ""
	for p in held:
		if is_instance_valid(p) and p is Person and PersonInfo.too_young(p, s) and (s.job != null or s.is_plot()):
			return PersonInfo.too_young_line(p)
	return ""

# ---------------------------------------------------------------- things

## What a building or a job is for (added under the hand's tooltip).
static func site_note(s: Site) -> String:
	if s == null or not is_instance_valid(s):
		return ""
	var bid: StringName = s.building.id if s.building != null else &""
	var jid: StringName = s.job.id if s.job != null else &""
	match bid:
		&"drying_rack":
			return "Dries meat and berries so they keep: the stores hold more food for the winter."
		&"food_store":
			return "A store: the village can keep more food."
		&"hut", &"cottage", &"townhouse":
			return "A home. Inside, people stay warm, and couples with room have children."
		&"fire_circle":
			return "Everyone near a lit fire stays warm."
		&"shrine":
			return "People who pray here give the hand faith."
	match jid:
		&"knap_flint":
			if Flags.has(&"stone_tools"):
				return "Knapped stone. They know stone tools: gathering is quicker, and trees can be felled."
			return "Knapped stone. %d of %d knapped and they will learn to make stone tools." % [mini(int(Village.stats.get("stone_knapped", 0)), PersonInfo.tune(&"STONE_FOR_TOOLS", 4)), PersonInfo.tune(&"STONE_FOR_TOOLS", 4)]
		&"hunt":
			var out := PersonInfo.outputs_text(s.job)
			var h := "Four or more hunt together. Each hunt brings %s." % out if out != "" else "Four or more hunt together."
			if not Flags.has(&"hide_clothes"):
				h += " Hides become warm clothes."
			return h
		&"tend_fire":
			return "Keep it fed with wood: a lit fire warms everyone near it."
		&"festival":
			return "Only blessed people can dance: hold E with Blessing over them, then set them here."
		&"great_elk_hunt":
			return "Only blessed hunters can bring it down."
		&"carry_log":
			return "It takes two: carry one person, then the other."
	return ""

## What a store is for (the stores strip tooltips).
static func store_note(kind: StringName) -> String:
	match kind:
		&"food": return "Food: berries, meat, fish and bread. Each person eats about one a day."
		&"hide":
			if Flags.has(&"hide_clothes"):
				return "Hides from the hunt. They already wear hide clothes."
			return "Hides from the hunt. At %d they sew warm clothes, and the cold bites less." % PersonInfo.tune(&"HIDES_FOR_CLOTHES", 3)
		&"wood": return "Wood: for building and for the fire."
		&"stone": return "Stone: knapped at the stone pile, for building."
		&"water": return "Water: drawn at the well. Everyone drinks."
		&"grain": return "Grain from the fields, milled into flour."
		&"flour": return "Flour, baked into bread."
	return ""

## "6 meat and a hide" for a job's outputs.
static func outputs_text(jd: JobDef) -> String:
	if jd == null:
		return ""
	var parts: Array = []
	for k in jd.outputs:
		var n := int(jd.outputs[k])
		parts.append(("a %s" % str(k)) if n == 1 else "%d %s" % [n, str(k)])
	return BookData.join_names(parts)

## "+6 meat  +1 hide"
static func yield_text(jd: JobDef) -> String:
	if jd == null:
		return ""
	var parts: Array = []
	for k in jd.outputs:
		parts.append("+%d %s" % [int(jd.outputs[k]), str(k)])
	return "  ".join(parts)

# ---------------------------------------------------------------- lines for the progression

## Who did the most of a kind of work (Guidance counts it in Village.stats["work_by"]).
static func best_worker(job: StringName) -> Person:
	var by: Dictionary = Village.stats.get("work_by", {}).get(str(job), {})
	var best: Person = null
	var most := 0
	for p in Village.alive():
		var n := int(by.get(str(p.uid), 0))
		if n > most:
			most = n
			best = p
	return best

## A discovery, said with why it happened.
static func discovery_line(flag: StringName) -> String:
	match flag:
		&"stone_tools":
			var who := PersonInfo.best_worker(&"knap_flint")
			var why := "%s learned to make stone tools, because you kept %s knapping flint" % [who.given_name, BookData.pronoun(who.sex, "herobj")] if who != null \
				else "They learned to make stone tools, because you kept them knapping flint"
			return why + ". Gathering is quicker, and trees can be felled."
		&"hide_clothes":
			return "The hides from your hunts became warm clothes. The cold bites less now."
	return ""

## "Mira and Teo want a home of their own": the bonded pair with no room,
## else whoever has no home. `kind` is "home" or "cottage".
static func home_wish_line(kind: String = "home") -> String:
	var pair: Array = []
	for p in Village.alive():
		if p.partner == 0 or p.sex != "f" or p.stage != Person.Stage.ADULT:
			continue
		var h = p.home
		var cramped: bool = h == null or not is_instance_valid(h) or (h.building != null and h.building.camp) or Births.home_residents(h) >= h.building.shelter
		if cramped:
			var q := Births.find(p.partner)
			if q != null and q.alive():
				pair = [p, q]
				break
	var what := "a cottage of their own" if kind == "cottage" else "a home of their own"
	if pair.size() == 2:
		return "%s and %s want %s" % [pair[0].given_name, pair[1].given_name, what]
	# no home, or still sleeping in the cave (a camp, not a home)
	var homeless: Array = Village.alive().filter(func(p): return p.stage >= Person.Stage.ADULT and (p.home == null or not is_instance_valid(p.home) or (p.home.building != null and p.home.building.camp)))
	if homeless.size() == 1:
		return "%s wants %s" % [homeless[0].given_name, "a cottage" if kind == "cottage" else "a home"]
	if homeless.size() >= 2:
		var many := "homes of their own" if kind == "home" else "cottages of their own"
		if homeless.size() == 2:
			return "%s and %s want %s" % [homeless[0].given_name, homeless[1].given_name, many]
		return "%s, %s and %d more want %s" % [homeless[0].given_name, homeless[1].given_name, homeless.size() - 2, many]
	# everyone has a bed, but the homes are full: say whose, so the growing
	# family is a family the player knows
	for p in Village.alive():
		if p.partner != 0 and p.sex == "f" and p.stage == Person.Stage.ADULT and p.home != null and is_instance_valid(p.home) and p.home.building != null:
			var q := Births.find(p.partner)
			if q != null and q.alive():
				return "%s and %s's %s is full: the next family wants %s" % [p.given_name, q.given_name, p.home.building.title.to_lower(), what]
	return "A family wants %s" % what
