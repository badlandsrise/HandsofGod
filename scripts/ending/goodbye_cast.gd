class_name GoodbyeCast extends RefCounted
## Who the goodbye is about, read from the Village Book (BookData): the first two
## the player named, the crew (four living descendants of the first two, the most
## trusting first, the commander a descendant of the first two), each crew
## member's line of descent back to the first two, and the words the ending says,
## written from the journal: the crew's lines at the shrine, the commander's last
## words from the sky, and the Book's memories woven into the credits.
## Plain data, no nodes of its own: GoodbyeSequence and the tests read it.

const CREW_SIZE := 4

var records: Array = []          # BookData.all_records()
var by: Dictionary = {}          # uid -> record
var first_two: Array = []        # the two uids of the storm night
var first_names: Array = []      # their names, as the player gave them
var crew: Array = []             # Person nodes, the commander first
var lines: Dictionary = {}       # crew uid -> [uid, ...] from a first-two root down to them
var commander: Person = null

## Reads the Book and picks the crew from `people` (Person nodes; Village.alive() by default).
static func gather(people: Array = []) -> GoodbyeCast:
	var c := GoodbyeCast.new()
	c.read_book()
	c.choose_crew(people if not people.is_empty() else Village.alive())
	return c

func read_book() -> void:
	records = BookData.all_records()
	by = BookData.by_uid(records)
	first_two.clear()
	for r in records:
		if bool(r.get("first_two", false)):
			first_two.append(int(r["uid"]))
	# a Person may carry the flag before the Book has caught up
	for p in Village.people:
		if is_instance_valid(p) and p.get(&"first_two") == true and not first_two.has(int(p.uid)):
			first_two.append(int(p.uid))
			if by.has(int(p.uid)):
				by[int(p.uid)]["first_two"] = true
	if first_two.size() < 2:
		# the two lowest-uid people with no parents who did not wander in
		for r in records:
			if first_two.size() >= 2:
				break
			if (r["parents"] as Array).is_empty() and not bool(r.get("wanderer", false)) and not first_two.has(int(r["uid"])):
				first_two.append(int(r["uid"]))
				r["first_two"] = true
	first_two.sort()
	first_two = first_two.slice(0, 2)
	first_names = first_two.map(func(u): return str(by[u]["name"]) if by.has(u) else "?")

## The line from a first-two root down to `uid` (oldest first), or [].
func line_of(uid: int) -> Array:
	return _line(uid, 0)

func _line(uid: int, depth: int) -> Array:
	if not by.has(uid) or depth > 64:
		return []
	if first_two.has(uid):
		return [uid]
	for pu in by[uid]["parents"]:
		var up := _line(int(pu), depth + 1)
		if not up.is_empty():
			up.append(uid)
			return up
	return []

## Picks four: living adults descended from the first two, most trusting first
## (trust 5 is ideal, not required), then the most able. Falls back to the most
## trusting adults when the line is short of four.
func choose_crew(people: Array) -> void:
	crew.clear()
	lines.clear()
	var adults: Array = people.filter(func(p): return is_instance_valid(p) and p.alive() and int(p.stage) == Person.Stage.ADULT)
	var desc: Array = []
	var others: Array = []
	for p in adults:
		var l := line_of(int(p.uid))
		if l.size() >= 2:
			desc.append(p)
			lines[int(p.uid)] = l
		else:
			others.append(p)
	desc.sort_custom(func(a, b): return _score(a) > _score(b))
	others.sort_custom(func(a, b): return _score(a) > _score(b))
	crew = desc.slice(0, CREW_SIZE)
	for p in others:
		if crew.size() >= CREW_SIZE:
			break
		crew.append(p)
	commander = crew[0] if not crew.is_empty() else null

func _score(p) -> float:
	var s := float(p.trust_f) * 10.0
	var sk: Dictionary = p.skills
	s += float(sk.get(&"engineering", 1.0)) + float(sk.get(&"scholarship", 1.0)) * 0.5
	if p.has_trait(&"brave"): s += 2.0
	if p.has_trait(&"timid"): s -= 3.0
	return s

func line_for(p) -> Array:
	return lines.get(int(p.uid), [])

func name_of(uid: int) -> String:
	return str(by[uid]["name"]) if by.has(uid) else "?"

func sex_of(uid: int) -> String:
	return str(by[uid]["sex"]) if by.has(uid) else "f"

## "Ona and Tuk"
func first_pair() -> String:
	return BookData.join_names(first_names) if not first_names.is_empty() else "the first two"

## "great-great-granddaughter of Ona and Tuk", "son of Ona and Tuk", or a
## plain "of the people of the valley" for someone outside the line.
func relation(p) -> String:
	var l := line_for(p)
	if l.size() < 2:
		return "of the people of the valley"
	return "%s of %s" % [descendant_word(l.size() - 1, str(p.sex)), first_pair()]

static func descendant_word(generations: int, sex: String) -> String:
	var child := "daughter" if sex == "f" else "son"
	if generations <= 1:
		return child
	if generations == 2:
		return "grand" + child
	if generations <= 5:
		return "great-".repeat(generations - 2) + "grand" + child
	return "descendant, %s generations on," % BookData.cardinal(generations)

## "Ona & Tuk  ·  Pim  ·  Maren  ·  Valentina"
func chain_text(p) -> String:
	var l := line_for(p)
	if l.is_empty():
		return str(p.given_name)
	var parts: Array = [" & ".join(first_names)]
	for u in l.slice(1):
		parts.append(name_of(int(u)))
	return "  ·  ".join(parts)

## The lineage drawing: {nodes: [{uid, name, depth, crew, commander}], edges: [[from, to]], depth}
## from the first two down to every crew member.
func lineage() -> Dictionary:
	var nodes := {}
	var edges: Array = []
	var maxd := 0
	for u in first_two:
		nodes[u] = {"uid": u, "name": name_of(u), "depth": 0, "crew": false, "commander": false}
	for p in crew:
		var l := line_for(p)
		if l.is_empty():
			continue
		for i in l.size():
			var u := int(l[i])
			if not nodes.has(u):
				nodes[u] = {"uid": u, "name": name_of(u), "depth": i, "crew": false, "commander": false}
			maxd = maxi(maxd, i)
			if i > 0:
				var e := [int(l[i - 1]), u]
				if not edges.has(e):
					edges.append(e)
		nodes[int(p.uid)]["crew"] = true
		nodes[int(p.uid)]["commander"] = p == commander
	# both of the first two lead down: draw the partner's line to the first child too
	if first_two.size() == 2:
		for e in edges.duplicate():
			if first_two.has(e[0]):
				var other: int = first_two[1] if e[0] == first_two[0] else first_two[0]
				if by.has(e[1]) and (by[e[1]]["parents"] as Array).has(other) and not edges.has([other, e[1]]):
					edges.append([other, e[1]])
	return {"nodes": nodes.values(), "edges": edges, "depth": maxd}

# ---------------------------------------------------------------- words

func _entries() -> Array:
	return BookData.journal()["entries"]

func _first_text(key_words: Array) -> String:
	for e in _entries():
		var t := str(e.get("text", ""))
		for k in key_words:
			if t.contains(k):
				return t
	return ""

## One line each, as they stand at the old shrine stone (DESIGN 9.2 beat 2:
## "I remember the stories of the cave").
func crew_line(i: int) -> String:
	if i >= crew.size():
		return ""
	var p = crew[i]
	var l := line_for(p)
	match i:
		0:
			return "I remember the stories of the cave."
		1:
			if l.size() >= 3:
				var g := int(l[l.size() - 3])
				return "My %s %s said the hand was gentle." % ["grandmother" if sex_of(g) == "f" else "grandfather", name_of(g)]
			return "My grandmother said the hand was gentle."
		2:
			if float(p.skills.get(&"engineering", 1.0)) >= 2.0 or p.has_trait(&"curious"):
				return "I helped build her. She'll fly."
			return "I've never been higher than the tower."
		_:
			return "Tell the little ones to wave."

## The commander's last words from the sky, written from the journal: the
## night of the storm, the first fire, the first gift, the dream. Short lines.
func last_words() -> Array:
	var w: Array = []
	var me := str(commander.given_name) if commander != null else "us"
	var a := str(first_names[0]) if first_names.size() > 0 else "they"
	var b := str(first_names[1]) if first_names.size() > 1 else ""
	var pair := "%s and %s" % [a, b] if b != "" else a
	w.append("Hand? It's %s. We can see the whole valley from up here." % me)
	var j := BookData.journal()
	var firsts: Dictionary = j["firsts"]
	if firsts.has("branch") or _first_text(["fallen branch"]) != "":
		w.append("The Book says you lifted a branch away, so %s could get out of the rain." % pair)
	else:
		var lifted := _lifted_name()
		if lifted != "":
			w.append("The Book says you lifted %s, once, and %s did not fall." % [lifted, "she" if _sex_by_name(lifted) == "f" else "he"])
	var fire := _first_text(["first fire"])
	if fire.contains("brought us the log"):
		w.append("That you brought them the log for their first fire.")
	elif fire != "":
		w.append("That you watched over their first fire.")
	w.append("They were afraid of you, that first night.")
	w.append("We never were." if commander == null or int(commander.trust) >= 3 else "We're not, now.")
	var gifts: Array = j["gifts"]
	if not gifts.is_empty():
		var g: Dictionary = gifts[0]
		var from := str(g.get("from", ""))
		w.append("We brought the %s %s left you. It's coming with us." % [str(g.get("kind", "gift")), from] if from != ""
			else "We brought the first gift we ever left you. It's coming with us.")
	w.append("We're going to find where you come from.")
	w.append("Look up. We'll say goodbye the old way.")
	return w

func _lifted_name() -> String:
	var t := _first_text(["the hand lifted "])
	var i := t.find("the hand lifted ")
	if i < 0:
		return ""
	var rest := t.substr(i + "the hand lifted ".length())
	var n := rest.get_slice(" ", 0).trim_suffix(".").trim_suffix(",")
	return n if n != "" and n != "the" else ""

func _sex_by_name(n: String) -> String:
	for r in records:
		if str(r["name"]) == n:
			return str(r["sex"])
	return "f"

## Journal lines for the credits, oldest first, in the people's own voice. No
## memorials: the ending never dwells on the dead (DESIGN 9.4).
func memories(n: int = 8) -> Array:
	var keep: Array = []
	for e in _entries():
		var k := str(e.get("kind", ""))
		if k in ["memorial", "power", "region", "joined"]:
			continue
		var t := str(e.get("text", ""))
		if t == "" or t.contains("died"):
			continue
		keep.append(t)
	if keep.size() <= n:
		return keep
	# spread the picks across the whole journal, keeping the first and the last
	var out: Array = []
	for i in n:
		var idx := roundi(float(i) * float(keep.size() - 1) / float(n - 1))
		if not out.has(keep[idx]):
			out.append(keep[idx])
	return out

## The kept gifts, by kind, oldest first: they go up with the crew.
func gift_kinds() -> Array:
	var out: Array = []
	for g in BookData.journal()["gifts"]:
		var k := str(g.get("kind", ""))
		if k != "" and not out.has(k):
			out.append(k)
	return out

## Everyone the Book knows, grouped by generation: [[title, [names]], ...].
func people_by_generation() -> Array:
	var lay := BookData.tree_layout(records)
	var gen: Dictionary = lay.get("gen", {})
	var rows := {}
	var maxg := 0
	for r in records:
		if first_two.has(int(r["uid"])):
			continue
		var g := int(gen.get(int(r["uid"]), 0))
		maxg = maxi(maxg, g)
		if not rows.has(g):
			rows[g] = []
		rows[g].append(str(r["name"]))
	var out: Array = [["The first two", first_names.duplicate()]]
	for g in maxg + 1:
		if not rows.has(g):
			continue
		var t: String = "Who came to stay" if g == 0 else "The %s generation" % BookData.ordinal(g + 1)
		out.append([t, rows[g]])
	return out
