class_name BookData extends RefCounted
## The Village Book's data model, kept apart from the drawing so it can be
## tested headless: person records, the family tree layout, the people's-voice
## phrasing (ordinal days, pronouns) and the book's saved journal, which lives in
## Village.stats["book"] so it saves and loads with the village.
##
## A person record is a plain Dictionary:
##   uid, name, sex, stage, years, alive, parents[], children[], partner, look{},
##   trust, skills{}, traits[], wish, status, born_day, died_day, cause,
##   hand_named, wanderer, first_two

const STAGES := ["Baby", "Child", "Adult", "Elder"]
const TRUST_NAMES := ["Afraid of the hand", "Wary of the hand", "Curious about the hand", "Fond of the hand", "Devoted to the hand", "Friend of the hand"]
const TRAIT_TEXT := {
	"strong": "Strong: carries more",
	"quick": "Quick: walks and works fast",
	"curious": "Curious: learns fast",
	"devout": "Devout: prays more, loves the hand",
	"timid": "Timid: scared of the hand and the dark",
	"brave": "Brave: faces fire and wolves",
	"sociable": "Sociable: makes friends fast",
	"stubborn": "Stubborn: does things their own way",
}
const SKILL_TITLES := {
	"gathering": "Gathering", "woodcraft": "Woodcraft", "building": "Building", "farming": "Farming",
	"crafting": "Crafting", "metalwork": "Metalwork", "scholarship": "Scholarship", "engineering": "Engineering",
}
const ERA_AGES := {1: "the Age of the Tribe", 2: "the Age of the Village", 3: "the Age of the Town", 4: "the Age of the Launch"}
const ERA_ORDINAL := {1: "First", 2: "Second", 3: "Third", 4: "Fourth"}

# ---------------------------------------------------------------- words

const _ONES := ["", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
	"tenth", "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth",
	"eighteenth", "nineteenth"]
const _TENS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
const _TENS_ORD := ["", "", "twentieth", "thirtieth", "fortieth", "fiftieth", "sixtieth", "seventieth", "eightieth", "ninetieth"]
const _CARD := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
	"eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]

## 12 -> "twelfth", 45 -> "forty-fifth", 100+ -> "103rd".
static func ordinal(n: int) -> String:
	if n <= 0:
		return "first"
	if n < 20:
		return _ONES[n]
	if n < 100:
		var t := n / 10
		var o := n % 10
		return _TENS_ORD[t] if o == 0 else "%s-%s" % [_TENS[t], _ONES[o]]
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		suf = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
	return "%d%s" % [n, suf]

## 12 -> "twelve" (words up to 99, digits after).
static func cardinal(n: int) -> String:
	if n < 20:
		return _CARD[maxi(n, 0)]
	if n < 100:
		var t := n / 10
		var o := n % 10
		return _TENS[t] if o == 0 else "%s-%s" % [_TENS[t], _CARD[o]]
	return str(n)

static func on_day(day: int) -> String:
	return "On the %s day" % ordinal(day)

static func pronoun(sex: String, kind: String = "her") -> String:
	var f := sex == "f"
	match kind:
		"she": return "she" if f else "he"
		"her": return "her" if f else "his"
		"herobj": return "her" if f else "him"
	return "their"

static func a_or_an(word: String) -> String:
	return ("an " if word.length() > 0 and "aeiou".contains(word[0].to_lower()) else "a ") + word

static func join_names(names: Array) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return str(names[0])
	return ", ".join(names.slice(0, names.size() - 1).map(func(x): return str(x))) + " and " + str(names[-1])

## "the age of the tribe" -> "The age of the tribe" (unlike String.capitalize, keeps the rest).
static func cap(s: String) -> String:
	return s if s == "" else s[0].to_upper() + s.substr(1)

static func region_title(id: StringName) -> String:
	return String(id).replace("_", " ")

# ---------------------------------------------------------------- the saved journal

## Village.stats["book"], created on first use.
static func journal() -> Dictionary:
	if not Village.stats.has("book") or not (Village.stats["book"] is Dictionary):
		Village.stats["book"] = {}
	var b: Dictionary = Village.stats["book"]
	for k in ["entries", "gifts", "hand_named", "eras_shown"]:
		if not b.has(k) or not (b[k] is Array):
			b[k] = []
	for k in ["firsts", "people", "dreams", "era_marks"]:
		if not b.has(k) or not (b[k] is Dictionary):
			b[k] = {}
	return b

static func add_entry(kind: String, text: String, day: int = -1) -> Dictionary:
	var e := {"kind": kind, "day": Clock.day if day < 0 else day, "era": Village.era, "text": text}
	journal()["entries"].append(e)
	return e

static func has_first(key: String) -> bool:
	return journal()["firsts"].has(key)

static func set_first(key: String, day: int = -1) -> bool:
	var f: Dictionary = journal()["firsts"]
	if f.has(key):
		return false
	f[key] = Clock.day if day < 0 else day
	return true

static func is_hand_named(uid: int) -> bool:
	for u in journal()["hand_named"]:
		if int(u) == uid:
			return true
	return false

static func mark_hand_named(uid: int) -> void:
	if not is_hand_named(uid):
		journal()["hand_named"].append(uid)

# ---------------------------------------------------------------- records

## A record of a live (or dead-but-present) Person node.
static func record_of(p) -> Dictionary:
	var r := {
		"uid": int(p.uid), "name": str(p.given_name), "sex": str(p.sex), "stage": int(p.stage),
		"years": int(float(p.age) / 60.0), "alive": bool(p.alive()),
		"parents": Array(p.parents).map(func(u): return int(u)),
		"children": Array(p.children).map(func(u): return int(u)),
		"partner": int(p.partner), "look": (p.look as Dictionary).duplicate(),
		"trust": int(p.trust), "traits": Array(p.traits).map(func(t): return str(t)),
		"wanderer": bool(p.wanderer),
	}
	var sk := {}
	for k in p.skills:
		sk[str(k)] = float(p.skills[k])
	r["skills"] = sk
	r["wish"] = str(p.wish)
	r["status"] = p.status_text() if p.has_method(&"status_text") else ""
	var hn: bool = p.has_meta(&"named_by_hand") and bool(p.get_meta(&"named_by_hand"))
	r["hand_named"] = hn or is_hand_named(r["uid"])
	var saved: Dictionary = journal()["people"].get(str(r["uid"]), {})
	r["born_day"] = int(saved.get("born_day", 0))
	r["died_day"] = int(saved.get("died_day", 0))
	r["cause"] = str(saved.get("cause", ""))
	r["first_two"] = bool(saved.get("first_two", false))
	r["joined_day"] = int(saved.get("joined_day", 0))
	return r

## Keeps the parts of a record that outlive the Person node (dead people leave
## the scene; the tree and memorial still need them).
static func remember(r: Dictionary) -> void:
	var people: Dictionary = journal()["people"]
	var key := str(r["uid"])
	var old: Dictionary = people.get(key, {})
	var keep := {}
	for k in ["uid", "name", "sex", "stage", "years", "alive", "parents", "children", "partner", "look",
			"traits", "wanderer", "hand_named", "trust"]:
		if r.has(k):
			keep[k] = r[k]
	for k in ["born_day", "died_day", "cause", "first_two", "joined_day"]:
		if r.has(k) and r[k] != null and str(r[k]) != "" and str(r[k]) != "0" and str(r[k]) != "false":
			keep[k] = r[k]
		elif old.has(k):
			keep[k] = old[k]
	people[key] = keep

static func set_person_fact(uid: int, key: String, value) -> void:
	var people: Dictionary = journal()["people"]
	var k := str(uid)
	if not people.has(k):
		people[k] = {"uid": uid}
	people[k][key] = value

## Everyone the book knows: live people from Village.people, then remembered
## people who are no longer in the scene. Ordered by uid.
static func all_records() -> Array:
	var out: Array = []
	var seen := {}
	for p in Village.people:
		if not is_instance_valid(p) or not (&"given_name" in p):
			continue
		var r := record_of(p)
		out.append(r)
		seen[r["uid"]] = true
	for k in journal()["people"]:
		var r: Dictionary = journal()["people"][k]
		var u := int(r.get("uid", int(k)))
		if seen.has(u) or str(r.get("name", "")) == "":
			continue
		var rr := normalise(r)
		rr["alive"] = false if int(rr.get("died_day", 0)) > 0 else bool(rr.get("alive", false))
		out.append(rr)
	out.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	return out

## Fills defaults and fixes JSON-loaded number types.
static func normalise(r: Dictionary) -> Dictionary:
	var o := r.duplicate(true)
	o["uid"] = int(o.get("uid", 0))
	o["name"] = str(o.get("name", "?"))
	o["sex"] = str(o.get("sex", "f"))
	o["stage"] = int(o.get("stage", 2))
	o["years"] = int(o.get("years", 0))
	o["alive"] = bool(o.get("alive", true))
	o["parents"] = Array(o.get("parents", [])).map(func(u): return int(u))
	o["children"] = Array(o.get("children", [])).map(func(u): return int(u))
	o["partner"] = int(o.get("partner", 0))
	o["look"] = o.get("look", {})
	o["trust"] = int(o.get("trust", 1))
	o["skills"] = o.get("skills", {})
	o["traits"] = o.get("traits", [])
	o["wish"] = str(o.get("wish", ""))
	o["status"] = str(o.get("status", ""))
	o["born_day"] = int(o.get("born_day", 0))
	o["died_day"] = int(o.get("died_day", 0))
	o["cause"] = str(o.get("cause", ""))
	o["hand_named"] = bool(o.get("hand_named", false))
	o["wanderer"] = bool(o.get("wanderer", false))
	o["first_two"] = bool(o.get("first_two", false))
	o["joined_day"] = int(o.get("joined_day", 0))
	return o

static func by_uid(records: Array) -> Dictionary:
	var m := {}
	for r in records:
		m[int(r["uid"])] = r
	return m

static func age_line(r: Dictionary) -> String:
	var st: String = STAGES[clampi(int(r["stage"]), 0, 3)]
	var who := "girl" if r["sex"] == "f" else "boy"
	if int(r["stage"]) >= 2:
		who = "woman" if r["sex"] == "f" else "man"
	if int(r["stage"]) == 0:
		who = "baby " + ("girl" if r["sex"] == "f" else "boy")
		return "A %s" % who
	var yrs := int(r["years"])
	return "%s %s, %d %s" % [st, who, yrs, "year" if yrs == 1 else "years"]

## The one line under a name, in the people's voice.
static func origin_line(r: Dictionary, names: Dictionary) -> String:
	var them := pronoun(r["sex"], "she").capitalize()
	if r.get("first_two", false):
		return "One of the first two. %s came to the cave with the storm." % them
	if not (r["parents"] as Array).is_empty():
		var ps: Array = []
		for u in r["parents"]:
			if names.has(int(u)):
				ps.append(names[int(u)]["name"])
		var born := "Born" + (" on the %s day" % ordinal(int(r["born_day"])) if int(r["born_day"]) > 0 else "")
		return "%s to %s." % [born, join_names(ps)] if not ps.is_empty() else born + "."
	if r.get("wanderer", false):
		var d := int(r.get("joined_day", 0))
		return "A wanderer who came to stay%s." % (" on the %s day" % ordinal(d) if d > 0 else "")
	return "One of the people of the valley."

static func wish_line(r: Dictionary) -> String:
	var w := str(r.get("wish", ""))
	var them := pronoun(r["sex"], "she").capitalize()
	if w == "":
		return "%s wishes for nothing just now." % them
	if w == "warmth":
		return "%s is cold and wishes to be warm." % them
	var jd: JobDef = Defs.job(StringName(w)) if Defs.has_method(&"job") else null
	if jd != null and jd.title != "":
		return "%s wishes to %s." % [them, jd.title.to_lower()]
	return "%s wishes to %s." % [them, w.replace("_", " ")]

# ---------------------------------------------------------------- family tree

## Lays out a family tree from records (see top of file). Returns
##   {pos: {uid: Vector2 (x in slots, y = generation)}, gen: {uid: int},
##    couples: [[a, b]], families: [{parents: [..], children: [..]}],
##    roots: [uid], width: float, depth: int}
## Generation 0 is everyone with no known parents (the first two, wanderers);
## a wanderer who pairs with someone takes their generation. Children sit under
## their parents' midpoint; partners sit side by side.
static func tree_layout(records: Array) -> Dictionary:
	var m := by_uid(records)
	var gen := {}
	# generations: parents first (records may be in any order)
	var changed := true
	for u in m:
		gen[u] = 0
	var guard := 0
	while changed and guard < 64:
		changed = false
		guard += 1
		for u in m:
			var g := 0
			for pu in m[u]["parents"]:
				if m.has(int(pu)):
					g = maxi(g, int(gen[int(pu)]) + 1)
			var pt := int(m[u].get("partner", 0))
			if pt != 0 and m.has(pt) and (m[u]["parents"] as Array).filter(func(x): return m.has(int(x))).is_empty():
				g = maxi(g, int(gen[pt]))
			if g != int(gen[u]):
				gen[u] = g
				changed = true
	var depth := 0
	for u in gen:
		depth = maxi(depth, int(gen[u]))
	var pos := {}
	var rows: Array = []
	for g in depth + 1:
		rows.append([])
	for u in m:
		rows[int(gen[u])].append(u)
	var width := 0.0
	for g in depth + 1:
		var row: Array = rows[g]
		# desired x: parents' midpoint (or partner's, or order of arrival)
		var want := {}
		for u in row:
			var xs: Array = []
			for pu in m[u]["parents"]:
				if pos.has(int(pu)):
					xs.append(float(pos[int(pu)].x))
			if not xs.is_empty():
				var s := 0.0
				for x in xs: s += x
				want[u] = s / xs.size()
		for u in row:
			if not want.has(u):
				var pt := int(m[u].get("partner", 0))
				want[u] = float(want[pt]) + 0.01 if want.has(pt) and pt != u else float(u) * 0.001 + (0.0 if g == 0 else 1000.0)
		row.sort_custom(func(a, b): return float(want[a]) < float(want[b]) or (float(want[a]) == float(want[b]) and int(a) < int(b)))
		# units: partners together (the one with parents in the tree first)
		var units: Array = []
		var used := {}
		for u in row:
			if used.has(u):
				continue
			used[u] = true
			var unit := [u]
			var pt := int(m[u].get("partner", 0))
			if pt != 0 and row.has(pt) and not used.has(pt):
				used[pt] = true
				unit.append(pt)
			units.append(unit)
		# place left to right, pushing apart, then re-centre on the wanted positions
		var placed: Array = []
		var cursor := -INF
		var sum_want := 0.0
		var sum_x := 0.0
		for unit in units:
			var w := 0.0
			for u in unit:
				w += float(want[u])
			w /= unit.size()
			if w > 999.0:
				w = cursor + 1.2 if cursor > -INF else 0.0
			var start: float = w - (unit.size() - 1) * 0.5
			if cursor > -INF:
				start = maxf(start, cursor + 1.2)
			for i in unit.size():
				placed.append([unit[i], start + i])
			cursor = start + unit.size() - 1
			sum_want += w * unit.size()
			sum_x += (start + (unit.size() - 1) * 0.5) * unit.size()
		var shift := (sum_want - sum_x) / maxf(placed.size(), 1.0) if g > 0 else 0.0
		# never shift left past the previous unit spacing: shifting the whole row keeps spacing
		for it in placed:
			pos[it[0]] = Vector2(float(it[1]) + shift, g)
	# normalise so the tree starts at x = 0
	var minx := INF
	var maxx := -INF
	for u in pos:
		minx = minf(minx, pos[u].x)
		maxx = maxf(maxx, pos[u].x)
	if minx == INF:
		minx = 0.0; maxx = 0.0
	for u in pos:
		pos[u] = Vector2(pos[u].x - minx, pos[u].y)
	width = maxx - minx
	# couples and families
	var couples: Array = []
	var seen := {}
	for u in m:
		var pt := int(m[u].get("partner", 0))
		if pt != 0 and m.has(pt) and not seen.has(u):
			seen[u] = true; seen[pt] = true
			couples.append([mini(u, pt), maxi(u, pt)])
	var fam := {}
	for u in m:
		var ps: Array = (m[u]["parents"] as Array).filter(func(x): return m.has(int(x))).map(func(x): return int(x))
		if ps.is_empty():
			continue
		ps.sort()
		var key := str(ps)
		if not fam.has(key):
			fam[key] = {"parents": ps, "children": []}
		fam[key]["children"].append(u)
	var roots: Array = []
	for u in m:
		if int(gen[u]) == 0 and (m[u]["parents"] as Array).filter(func(x): return m.has(int(x))).is_empty():
			roots.append(u)
	roots.sort()
	return {"pos": pos, "gen": gen, "couples": couples, "families": fam.values(), "roots": roots,
		"width": width, "depth": depth}

## The line of descent from the first two to `uid` (uids, oldest first), or [].
static func line_to(records: Array, uid: int) -> Array:
	return _line(by_uid(records), uid, 0)

static func _line(m: Dictionary, uid: int, depth: int) -> Array:
	if not m.has(uid) or depth > 64:
		return []
	if m[uid].get("first_two", false):
		return [uid]
	for pu in m[uid]["parents"]:
		var up := _line(m, int(pu), depth + 1)
		if not up.is_empty():
			up.append(uid)
			return up
	return []
