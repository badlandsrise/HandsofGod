extends RefCounted
## Cases for tests/ui/test_ui.gd.

var tree: SceneTree
var root: Window
var fails := 0
var passes := 0
var finished := false
var _given: Array = []
var _given_count := 0

func start(t: SceneTree) -> void:
	tree = t
	root = t.root
	_run()

func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)

func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame

func _reset() -> void:
	for p in Village.people.duplicate():
		if is_instance_valid(p):
			p.get_parent().remove_child(p)
			p.free()
	Village.people.clear()
	Village.load_state({"stats": {"births": 0, "deaths": 0, "joined": 0, "winters_survived": 0, "gifts": 0}})
	Clock.load_state({})
	Clock.set_speed(1)

func _spawn(name_s: String, sex: String, opts: Dictionary = {}) -> Person:
	var o := opts.duplicate()
	o["name"] = name_s
	o["sex"] = sex
	return Person.spawn(root, Vector3(randf() * 4.0, 0, randf() * 4.0), o)

func _run() -> void:
	test_words()
	test_tree_layout()
	await test_naming()
	await test_chronicle()
	await test_book()
	await test_era_card()
	test_options()
	test_alerts()
	# the clarity pass (playtest era 1 section 1, era 2 clarity)
	test_goal_checklist()
	await test_dream_card()
	test_power_locks()
	test_person_lines()
	test_wants()
	await test_guidance()
	await test_hud_idle()
	await test_stores_bar()
	test_playtest_end()
	await test_save_page_fits()
	print("UI tests: %d passed, %d failed" % [passes, fails])
	finished = true

# ---------------------------------------------------------------- words

func test_words() -> void:
	check(BookData.ordinal(1) == "first" and BookData.ordinal(12) == "twelfth", "ordinal: first, twelfth")
	check(BookData.ordinal(20) == "twentieth" and BookData.ordinal(45) == "forty-fifth", "ordinal: twentieth, forty-fifth")
	check(BookData.ordinal(101) == "101st" and BookData.ordinal(112) == "112th", "ordinal: 101st, 112th")
	check(BookData.cardinal(7) == "seven" and BookData.cardinal(23) == "twenty-three", "cardinal words")
	check(BookData.join_names(["Ona", "Pim", "Teo"]) == "Ona, Pim and Teo", "join names")
	check(BookData.on_day(12) == "On the twelfth day", "on the twelfth day")

# ---------------------------------------------------------------- family tree

static func mock(uid: int, name_s: String, sex: String, parents: Array = [], partner: int = 0, alive: bool = true, extra: Dictionary = {}) -> Dictionary:
	var r := {"uid": uid, "name": name_s, "sex": sex, "parents": parents, "partner": partner, "alive": alive, "children": []}
	r.merge(extra, true)
	return BookData.normalise(r)

func test_tree_layout() -> void:
	# Ona + Pim (the first two) -> Teo, Mira (dead) ; Teo + Asha (a wanderer) -> Kai, Lio ; Bo, a lone wanderer
	var recs := [
		mock(6, "Kai", "m", [3, 5]),
		mock(1, "Ona", "f", [], 2, true, {"first_two": true}),
		mock(2, "Pim", "m", [], 1, true, {"first_two": true}),
		mock(3, "Teo", "m", [1, 2], 5),
		mock(4, "Mira", "f", [1, 2], 0, false, {"died_day": 30}),
		mock(5, "Asha", "f", [], 3, true, {"wanderer": true}),
		mock(7, "Lio", "f", [3, 5]),
		mock(8, "Bo", "m", [], 0, true, {"wanderer": true}),
	]
	var L := BookData.tree_layout(recs)
	var g: Dictionary = L["gen"]
	var pos: Dictionary = L["pos"]
	check(g[1] == 0 and g[2] == 0 and g[8] == 0, "tree: the first two and a lone wanderer are generation 0")
	check(g[3] == 1 and g[4] == 1, "tree: their children are generation 1")
	check(g[5] == 1, "tree: a wanderer who pairs in takes the partner's generation")
	check(g[6] == 2 and g[7] == 2, "tree: grandchildren are generation 2")
	check(int(L["depth"]) == 2, "tree: depth 2")
	check(absf(pos[1].x - pos[2].x) == 1.0, "tree: the first two sit side by side")
	check(absf(pos[3].x - pos[5].x) == 1.0, "tree: partners sit side by side")
	var mid: float = (pos[3].x + pos[5].x) * 0.5
	var kids: float = (pos[6].x + pos[7].x) * 0.5
	check(absf(mid - kids) < 0.6, "tree: children are centred under their parents (%.2f vs %.2f)" % [mid, kids])
	check(absf(pos[6].x - pos[7].x) >= 1.0, "tree: siblings do not overlap")
	var row1: Array = [pos[3].x, pos[4].x, pos[5].x]
	row1.sort()
	check(row1[1] - row1[0] >= 1.0 and row1[2] - row1[1] >= 1.0, "tree: no two people share a slot")
	var couples: Array = L["couples"]
	check(couples.has([1, 2]) and couples.has([3, 5]), "tree: couples found")
	check((L["families"] as Array).size() == 2, "tree: two families")
	check(L["roots"] == [1, 2, 5, 8] or (L["roots"] as Array).has(1), "tree: roots include the first two")
	var line := BookData.line_to(recs, 6)
	check(line.size() == 3 and line[2] == 6 and (line[0] == 1 or line[0] == 2) and line[1] == 3, "tree: line of descent from the first two (%s)" % [line])
	check(BookData.line_to(recs, 8).is_empty(), "tree: a wanderer has no line to the first two")
	# order does not matter, and an empty tree is fine
	var L2 := BookData.tree_layout(recs.duplicate())
	check(L2["gen"] == g, "tree: stable")
	var E := BookData.tree_layout([])
	check(int(E["depth"]) == 0 and (E["pos"] as Dictionary).is_empty(), "tree: empty")

# ---------------------------------------------------------------- naming

func _on_names_given(people: Array) -> void:
	_given = people
	_given_count += 1

func test_naming() -> void:
	_reset()
	Clock.running = true
	var a := _spawn("Ona", "f")
	var b := _spawn("Pim", "m")
	await _frames(1)
	var card := NamingCard.new()
	root.add_child(card)
	Events.names_given.connect(_on_names_given)
	_given_count = 0
	Events.name_requested.emit([a, b], &"first_two")
	await _frames(2)
	check(card.is_open(), "naming: the card opens on name_requested")
	check(Clock.speed_index == 0, "naming: the game pauses softly")
	check(NamingCard.prompt([a, b], &"first_two") == "Two people shelter in the cave. What will you call them?", "naming: first_two prompt")
	check(card.field_text(0) == "Ona" and card.field_text(1) == "Pim", "naming: generated names prefilled")
	card._reroll(1)
	var rolled := card.field_text(1)
	check(rolled != "" and rolled != "Pim", "naming: the die rolls a new name (%s)" % rolled)
	card.set_name_field(0, "  zed  ")
	card.set_name_field(1, "Pim")
	card.accept()
	await _frames(1)
	check(_given_count == 1 and _given.size() == 2 and _given.has(a) and _given.has(b), "naming: names_given emitted with the people")
	check(a.given_name == "Zed", "naming: a typed name is cleaned and applied (%s)" % a.given_name)
	check(b.given_name == "Pim", "naming: a kept name stays")
	check(a.has_meta(&"named_by_hand") and bool(a.get_meta(&"named_by_hand")), "naming: a typed name gets the hand mark")
	check(not b.has_meta(&"named_by_hand"), "naming: a kept generated name has no hand mark")
	check(BookData.is_hand_named(a.uid) and not BookData.is_hand_named(b.uid), "naming: the journal remembers who the hand named")
	check(Clock.speed_index == 1, "naming: the speed is restored")
	check(not card.is_open(), "naming: the card closes")
	# the baby prayer
	a.partner = b.uid; b.partner = a.uid
	var baby := _spawn("Lio", "f", {"age": 0.0, "parents": [b.uid, a.uid]})
	await _frames(1)
	check(NamingCard.prompt([baby], &"baby_prayer") == "Zed and Pim kneel at the shrine and ask the hand to name their child.", "naming: baby prayer prompt names the mother first (%s)" % NamingCard.prompt([baby], &"baby_prayer"))
	Clock.set_speed(2)
	Events.name_requested.emit([baby], &"baby_prayer")
	await _frames(2)
	check(card.is_open() and Clock.speed_index == 0, "naming: baby prayer opens and pauses")
	card.accept()
	await _frames(1)
	check(_given_count == 2 and _given == [baby], "naming: baby names_given")
	check(baby.has_meta(&"named_by_hand") and BookData.is_hand_named(baby.uid), "naming: a baby the hand names carries the hand mark")
	check(Clock.speed_index == 2, "naming: speed 2 restored")
	# queued while the title is up (Clock not running), shown once play starts
	Clock.running = false
	Events.name_requested.emit([baby], &"baby_prayer")
	await _frames(2)
	check(not card.is_open(), "naming: waits while the clock is stopped (title)")
	Clock.running = true
	await _frames(2)
	check(card.is_open(), "naming: shows once play starts")
	card.set_name_field(0, "")
	card.accept()
	await _frames(1)
	check(baby.given_name == "Lio", "naming: an empty field keeps the name")
	check(NamingCard.clean_name("ama", "x") == "Ama" and NamingCard.clean_name("   ", "Bo") == "Bo", "naming: clean_name")
	Events.names_given.disconnect(_on_names_given)
	card.queue_free()

# ---------------------------------------------------------------- chronicle

func test_chronicle() -> void:
	_reset()
	Clock.running = true
	var chron := Chronicle.new()
	root.add_child(chron)
	var a := _spawn("Ona", "f")
	var b := _spawn("Pim", "m")
	a.partner = b.uid; b.partner = a.uid
	await _frames(1)
	a.set_meta(&"named_by_hand", true)
	Events.names_given.emit([a, b])
	var j := BookData.journal()
	check(BookData.has_first("names"), "chronicle: the first two's naming is a first")
	check(str(j["entries"][0]["text"]).contains("Ona and Pim") and str(j["entries"][0]["text"]).contains("The hand gave us our names."), "chronicle: first-night entry in the people's voice")
	check(bool(j["people"][str(a.uid)].get("first_two", false)), "chronicle: the first two are marked")
	Clock.day = 12
	var baby := _spawn("Kai", "m", {"age": 0.0, "parents": [a.uid, b.uid]})
	a.children.append(baby.uid); b.children.append(baby.uid)
	await _frames(1)
	Events.person_born.emit(baby)
	check(BookData.has_first("birth") and str(j["entries"][-1]["text"]) == "On the twelfth day Kai was born to Ona and Pim, the first child of the valley.", "chronicle: first birth (%s)" % j["entries"][-1]["text"])
	Clock.day = 14
	var other := _spawn("Wen", "f", {"wanderer": true})
	await _frames(1)
	Events.person_joined.emit(other)
	check(str(j["entries"][-1]["text"]).contains("Wen walked into the valley"), "chronicle: first wanderer")
	# a gift picked up
	var g := Node3D.new()
	g.add_to_group(&"gift")
	g.set_meta(&"x", 1)
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar kind := \"carved hand\"\nvar from_name := \"Ona\"\nvar uid := 991\n"
	gs.reload()
	g.set_script(gs)
	g.add_to_group(&"gift")
	root.add_child(g)
	Events.hand_lifted_object.emit(g)
	Events.hand_lifted_object.emit(g)
	check((j["gifts"] as Array).size() == 1 and j["gifts"][0]["kind"] == "carved hand" and j["gifts"][0]["from"] == "Ona", "chronicle: a gift is kept once")
	check(str(j["entries"][-1]["text"]).contains("Ona left a carved hand"), "chronicle: gift entry")
	g.queue_free()
	# a dream
	Events.dream_started.emit(&"shelter_of_our_own")
	Clock.day = 20
	Events.dream_done.emit(&"shelter_of_our_own")
	check(int(j["dreams"]["shelter_of_our_own"]["done"]) == 20 and int(j["dreams"]["shelter_of_our_own"]["start"]) == 14, "chronicle: dream days")
	# a death: the record outlives the node
	Clock.day = 30
	other.die("old age")
	var ouid := other.uid
	check(str(j["entries"][-1]["text"]).contains("Wen died of old age"), "chronicle: memorial entry (%s)" % j["entries"][-1]["text"])
	other.get_parent().remove_child(other)
	other.free()
	var recs := BookData.all_records()
	var by := BookData.by_uid(recs)
	check(by.has(ouid) and not by[ouid]["alive"] and int(by[ouid]["died_day"]) == 30, "chronicle: the dead stay in the book after they leave the scene")
	check(by.has(a.uid) and by[a.uid]["hand_named"], "chronicle: hand mark survives in the record")
	check(by.has(baby.uid) and int(by[baby.uid]["born_day"]) == 12, "chronicle: born day recorded")
	# the journal round-trips through JSON (as the save does)
	var copy = JSON.parse_string(JSON.stringify(Village.stats))
	Village.stats = copy
	var recs2 := BookData.all_records()
	check(BookData.by_uid(recs2).has(ouid) and BookData.is_hand_named(a.uid), "chronicle: journal survives a JSON round trip")
	var L := BookData.tree_layout(recs2)
	check(int(L["gen"][baby.uid]) == 1, "chronicle: tree from live and remembered people")
	chron.queue_free()

# ---------------------------------------------------------------- book

func test_book() -> void:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var book := VillageBook.new(null)
	host.add_child(book)
	await _frames(1)
	var ok := true
	for i in VillageBook.TABS.size():
		book.open_book(i)
		await _frames(1)
		ok = ok and book.is_open() and book.tab == i
	check(ok, "book: every tab opens")
	book.open_book(1)
	await _frames(2)
	check(book._tree != null and book._tree._by.size() == BookData.all_records().size(), "book: the tree shows everyone")
	var someone: int = BookData.all_records()[0]["uid"]
	book.select_person(someone)
	check(book.tab == 0 and book.selected_uid == someone, "book: a link opens the person's page")
	book.close_book()
	check(not book.is_open(), "book: closes")
	host.queue_free()

# ---------------------------------------------------------------- era card

func test_era_card() -> void:
	var card := EraCard.new()
	root.add_child(card)
	await _frames(1)
	Village.stats["dreams_done"] = ["shelter_of_our_own"]
	Village.stats["births"] = 3
	Village.stats["deaths"] = 1
	Clock.total_t = 2700.0
	var s := EraCard.summary(1)
	check(s["title"] == "Tribe" and s["born"] == 3 and s["lost"] == 1 and s["minutes"] == 45, "era card: summary numbers (%s)" % [s])
	check((s["dreams"] as Array).size() >= 1 and (s["gifts"] as Array).size() == 1, "era card: dreams and gifts listed")
	check(str(s["memory"]) != "", "era card: a memory line")
	Clock.set_speed(1)
	Events.era_complete_shown.emit(1)
	await _frames(1)
	check(card.is_open() and Clock.speed_index == 0, "era card: shows and pauses")
	Events.era_complete_shown.emit(1)
	card.keep_playing()
	await _frames(1)
	check(not card.is_open() and Clock.speed_index == 1 and Village.era == 1, "era card: keep playing stays in the era")
	card.show_era(1)
	card.continue_era()
	await _frames(1)
	check(Village.era == 2, "era card: continue moves to era 2")
	Village.era = 1
	card.queue_free()

# ---------------------------------------------------------------- options

func test_options() -> void:
	Options.path = "user://test_options.cfg"
	Options.load_options(false)
	check(Game.options.has("difficulty") and Game.options.has("voices") and Game.options.has("quality"), "options: defaults fill Game.options")
	Options.set_opt("difficulty", "harsh", false)
	Options.set_opt("music", 0.25, false)
	Options.set_opt("invert_rotate", true, false)
	Options.save_options()
	Game.options["difficulty"] = "normal"
	Game.options["music"] = 1.0
	Options.load_options()
	check(Game.options["difficulty"] == "harsh" and is_equal_approx(float(Game.options["music"]), 0.25) and Game.options["invert_rotate"] == true, "options: round trip through the file")
	check(absf(Audio.music_db - linear_to_db(0.25)) < 0.01, "options: music volume applied")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_options.cfg"))
	Options.path = Options.PATH

# ---------------------------------------------------------------- alerts

func test_alerts() -> void:
	_reset()
	var a := _spawn("Ama", "f")
	var b := _spawn("Bo", "m")
	a.global_position = Vector3(10, 0, 0)
	b.global_position = Vector3(-10, 0, 0)
	check(Notices.person_for_alert("A wolf bit Ama!", Vector3.INF) == a, "alerts: finds the person named")
	check(Notices.person_for_alert("Wolves at dusk", Vector3(-10.5, 0, 0)) == b, "alerts: else whoever stands there")
	check(Notices.person_for_alert("Winter is coming", Vector3.INF) == null, "alerts: none for a general alert")
	check(Notices.person_for_alert("Bob arrived", Vector3.INF) == null, "alerts: whole names only")
	var card := Notices.alert_card("Ama is hungry", a.global_position, Callable())
	check(card is Button and card.get_child_count() > 0, "alerts: card builds")
	card.free()
	_reset()

# ---------------------------------------------------------------- clarity: the goal

func test_goal_checklist() -> void:
	_reset()
	var era0 := Village.era
	Village.era = 1
	Village.stats["onboarding"] = Onboarding.Beat.DONE
	Village.stats["dreams_done"] = []
	Village.stats.erase("dream_active")
	var st := GoalPanel.state()
	check(st["mode"] == &"teaser" and str(st["hint"]) != "", "goal: before a dream appears, a teaser with a hint (%s)" % [st.get("hint", "")])
	Village.stats["dream_active"] = "shelter_of_our_own"
	st = GoalPanel.state()
	var keys: Array = (st.get("items", []) as Array).map(func(it): return it["key"])
	check(st["mode"] == &"dream" and keys.has("b:hut") and keys.has("b:fire_circle"), "goal: the dream's checklist (%s)" % [keys])
	Village.stats["dreams_done"] = ["shelter_of_our_own", "shrine_to_the_hand"]
	Village.stats["dream_active"] = "stone_circle"
	var sc: DreamDef = Defs.dream(&"stone_circle")
	var fest: Dictionary = {}
	for it in Dreams.checklist(sc):
		if it["key"] == "f:festival":
			fest = it
	check(str(fest.get("text", "")) == "The first festival: bless the dancers at the fire circle", "goal: the festival line says what to do")
	check(str(fest.get("hint", "")).contains("Blessing"), "goal: the festival hint names Blessing")
	# the checklist agrees with Dreams.met in every state set up here
	var agree := true
	for step in 4:
		match step:
			1: Flags.set_flag(&"festival")
			2: Village.stats["winters_survived"] = 2
			3: Village.stats["winters_survived"] = 0
		for e in [1, 2, 3]:
			var ed := Defs.era(e)
			if ed == null:
				continue
			for id in ed.dreams:
				var d: DreamDef = Defs.dream(id)
				if d != null and Dreams.checklist_met(d) != Dreams.met(d):
					agree = false
					print("  disagree: ", id, " step ", step)
	check(agree, "goal: checklist_met == met for every dream")
	var fest_done := false
	for it in Dreams.checklist(sc):
		if it["key"] == "f:festival":
			fest_done = it["done"]
	check(fest_done and Dreams.progress_text(sc) != "", "goal: a done line ticks")
	Village.stats["dreams_done"] = ["shelter_of_our_own", "shrine_to_the_hand", "stone_circle"]
	check(GoalPanel.state()["mode"] == &"age_done", "goal: the age's dreams all done")
	var panel := GoalPanel.new()
	root.add_child(panel)
	Village.stats["dreams_done"] = ["shelter_of_our_own", "shrine_to_the_hand"]
	panel.refresh()
	check(panel.mode == &"dream" and panel.dream_id == &"stone_circle", "goal: the panel builds the stone circle")
	panel.free()
	Village.era = era0
	_reset()

# ---------------------------------------------------------------- clarity: dream card

func test_dream_card() -> void:
	_reset()
	var card := DreamCard.new()
	root.add_child(card)
	await _frames(1)
	var c := DreamCard.content(Defs.dream(&"stone_circle"))
	check(c["kicker"] == "THE GREAT DREAM OF THIS AGE" and (c["rewards"] as Array).has("+15 faith"), "dream card: kicker and rewards (%s)" % [c["rewards"]])
	check((c["items"] as Array).size() >= 4 and str(c["voice"]) != "", "dream card: the voice and the checklist")
	Clock.set_speed(2)
	var closed: Array = []
	card.closed.connect(func(id): closed.append(id))
	card.show_dream(&"stone_circle")
	await _frames(1)
	check(card.is_open() and Clock.speed_index == 0, "dream card: shows and pauses until clicked")
	card.accept()
	await _frames(1)
	check(not card.is_open() and Clock.speed_index == 2 and closed == [&"stone_circle"], "dream card: accept restores the speed")
	card.free()
	Clock.set_speed(1)

# ---------------------------------------------------------------- clarity: power locks

func test_power_locks() -> void:
	_reset()
	var keep := Faith.save_state()
	var regions0: Dictionary = Village.regions.duplicate()
	Village.era = 1
	Faith.total = 13.0
	Faith.spent = 0.0
	Faith.unlocked = {&"grip_2": true}
	Village.stats["dreams_done"] = []
	Village.regions.erase(&"valley_floor")
	var d: PowerDef = Defs.power(&"strength_1")
	var reqs := PowerInfo.requirements(d)
	var cost: Dictionary = reqs.filter(func(r): return r["key"] == "cost")[0]
	check(cost["done"] and str(cost["text"]) == "10 faith (you have 13)", "powers: the cost is met with 13 faith (%s)" % [cost["text"]])
	var line := PowerInfo.locked_line(d)
	check(line.contains("Valley Floor") and line.contains("shelter") and not line.contains("needs 10 faith"), "powers: the lock says the real reasons (%s)" % line)
	check(PowerInfo.state(d) == &"locked", "powers: locked, not 'needs faith'")
	Village.regions[&"valley_floor"] = true
	Village.stats["dreams_done"] = ["shelter_of_our_own"]
	check(PowerInfo.state(d) == &"affordable" and PowerInfo.locked_line(d) == "", "powers: all met, ready to unlock")
	Faith.total = 5.0
	check(PowerInfo.state(d) == &"faith" and PowerInfo.locked_line(d).contains("You have 5"), "powers: only faith missing says so")
	var pc := PowerInfo.Card.new()
	root.add_child(pc)
	pc.show_power(&"strength_1")
	check(pc.visible and pc.power_id == &"strength_1", "powers: the hover card builds")
	pc.free()
	Faith.load_state(keep)
	Village.regions = regions0
	Village.stats["dreams_done"] = []

# ---------------------------------------------------------------- clarity: people

func test_person_lines() -> void:
	_reset()
	Village.era = 1
	Clock.is_night = false
	var kid := _spawn("Kai", "m", {"age": 8.5 * 60.0})
	var a := _spawn("Ama", "f", {"age": 25.0 * 60.0})
	var b := _spawn("Bo", "m", {"age": 26.0 * 60.0})
	check(PersonInfo.header(kid) == "Kai · child, 8", "people: the child badge (%s)" % PersonInfo.header(kid))
	check(PersonInfo.too_young(kid) and PersonInfo.too_young_line(kid) == "Kai is too young to work (age 8)", "people: too young to work, with the age")
	check(PersonInfo.idle_reason(a) == "idle: no work. Set them on a job", "people: an idle reason (%s)" % PersonInfo.idle_reason(a))
	Clock.is_night = true
	check(PersonInfo.idle_reason(a).contains("night"), "people: resting at night")
	Clock.is_night = false
	a.partner = b.uid
	b.partner = a.uid
	check(PersonInfo.home_wish_line("home") == "Ama and Bo want a home of their own", "people: the home wish names the pair (%s)" % PersonInfo.home_wish_line("home"))
	check(PersonInfo.discovery_line(&"stone_tools").contains("because"), "people: a discovery says why")
	check(PersonInfo.tooltip(a).begins_with("Ama\n"), "people: the tooltip leads with the name")
	_reset()

# ---------------------------------------------------------------- clarity: wants

func test_wants() -> void:
	_reset()
	Village.stats["onboarding"] = Onboarding.Beat.DONE
	var a := _spawn("Ama", "f", {"age": 25.0 * 60.0})
	var b := _spawn("Bo", "m", {"age": 26.0 * 60.0})
	a.wish = &"gather_berries"
	a.wish_t = 1.0
	a.set_meta(&"wish_why", "the food is running low")
	check(Wants.line(a) == "Ama would love to %s: the food is running low" % a._wish_title(), "wants: a line with the reason (%s)" % Wants.line(a))
	var trust0: float = a.trust_f
	Wants.sim(a, 2.0)
	check(a.wish == &"" and is_equal_approx(a.trust_f, trust0) and a.wish_t >= Wants.GAP.x, "wants: an unanswered want just fades, no blame")
	a.wish = &"gather_berries"
	var f0 := Faith.total
	Wants.grant(a)
	check(a.wish == &"" and Faith.total - f0 >= Wants.FAITH.x - 0.01 and Faith.total - f0 <= Wants.FAITH.y + 0.01, "wants: granted, bonus faith (%.1f)" % (Faith.total - f0))
	check(Wants.max_active() == 1, "wants: one at a time in a small village")
	a.wish = &"gather_berries"
	b.wish = &""
	b.wish_t = 0.0
	Wants.sim(b, 0.1)
	check(b.wish == &"", "wants: no second want past the cap")
	_reset()

# ---------------------------------------------------------------- clarity: guidance

func test_guidance() -> void:
	_reset()
	Clock.running = true
	var g := Guidance.new(null)
	root.add_child(g)
	await _frames(1)
	var a := _spawn("Ona", "f", {"age": 25.0 * 60.0})
	var baby := _spawn("Vek", "m", {"age": 0.0, "parents": [a.uid]})
	Events.person_born.emit(baby)
	await _frames(1)
	var bc := Beacon.on(baby)
	check(bc != null, "guidance: a newborn gets a beacon")
	check(Village.stats.get("guide_first_birth", false) and g.busy(), "guidance: the first birth is a camera beat")
	check(not g.beat(a, "again", "first_birth"), "guidance: a keyed beat runs once")
	a.bless(15.0)
	var old_world := Game.world
	var w3 := Node3D.new()
	root.add_child(w3)
	Game.world = w3
	g.scan()
	var ring: Node = null
	for r in tree.get_nodes_in_group(&"bless_ring"):
		if r.person == a:
			ring = r
	check(ring != null and absf(ring.fraction() - 0.5) < 0.05, "guidance: a blessed person gets a timer ring at half")
	a.blessed_t = 0.0
	await _frames(3)
	check(ring == null or not is_instance_valid(ring) or ring.ending(), "guidance: the ring fades when the blessing ends")
	var m := g.mark(a, 2.0)
	check(m != null and Beacon.on(a) == m, "guidance: the Book's find marks the person")
	# [polish] the first wanderer: a short, skippable mini-cutscene
	g._queue.clear()
	g._beat = {}
	Village.stats.erase("guide_first_wanderer")
	var wen := _spawn("Wen", "f", {"wanderer": true})
	wen.global_position = a.global_position + Vector3(20, 0, 0)
	Events.person_joined.emit(wen)
	await _frames(3)
	var sc: WandererScene = g.scene
	check(sc != null and is_instance_valid(sc) and not sc.done, "first wanderer: a mini-cutscene plays")
	check(sc != null and sc.line.contains("Wen"), "first wanderer: one line names them")
	if sc != null:
		sc.t = WandererScene.PULL_AT + 0.1
		await _frames(2)
		check(a.gazing(), "first wanderer: the tribe turns to look")
		sc.skip()
		var was_skipped := sc.skipped
		await _frames(2)
		check(was_skipped and not is_instance_valid(sc), "first wanderer: the scene can be skipped")
	g.free()
	for bb in tree.get_nodes_in_group(&"beacon"):
		bb.free()
	for r in tree.get_nodes_in_group(&"bless_ring"):
		r.free()
	Game.world = old_world
	w3.free()
	Clock.running = false
	_reset()

# ---------------------------------------------------------------- clarity: call idle

class IdleWorld extends Node3D:
	var called_at: Vector3 = Vector3.INF
	func call_idle(to: Vector3) -> int:
		called_at = to
		return 2

func test_hud_idle() -> void:
	_reset()
	var hud: Hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames(2)
	check(hud.call_idle() == 0, "idle: nobody idle, nothing to call")
	var a := _spawn("Ama", "f", {"age": 25.0 * 60.0})
	var b := _spawn("Bo", "m", {"age": 26.0 * 60.0})
	await _frames(1)
	check(PersonInfo.idle_people().size() == 2, "idle: two idle adults counted")
	var old_world := Game.world
	if Hud.idle_caller() == null:
		hud.call_idle()
		check(Beacon.on(a) != null or Beacon.on(b) != null, "idle: without call_idle, the camera finds one and marks them")
	var mock := IdleWorld.new()
	root.add_child(mock)
	Game.world = mock
	if Village.has_method(&"call_idle"):
		check(Hud.idle_caller() == Village, "idle: the village's call_idle is used")
	else:
		check(Hud.idle_caller() == mock and hud.call_idle() == 2 and mock.called_at.is_finite(), "idle: the world's call_idle is called with a point")
	Game.world = old_world
	mock.free()
	hud.free()
	for bb in tree.get_nodes_in_group(&"beacon"):
		bb.free()
	_reset()

# ---------------------------------------------------------------- the stores bar

## Austin, Era 3: "a lot of resources to monitor all at once". The bar shows
## food plus a handful of stores that matter now; the rest wait behind "+N more".
func test_stores_bar() -> void:
	_reset()
	var hud: Hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	Village.load_state({"era": 3, "stats": {}})
	for k in [&"wood", &"stone", &"blocks", &"iron", &"books", &"clay", &"ore", &"bronze", &"cloth", &"flour", &"grain", &"pots", &"wool", &"hide"]:
		Village.add_store(k, 12)
	Village.add_store(&"charcoal", Village.store_cap)
	hud.refresh()
	await _frames(2)
	var items := 0
	var more: Label = null
	for c in hud.stores_box.get_children():
		if c is HBoxContainer:
			items += 1
		elif c.name == "MoreStores":
			more = c
	check(items <= Hud.BAR_MAX + 1, "stores bar: food plus at most %d stores (%d shown)" % [Hud.BAR_MAX, items])
	check(more != null and more.tooltip_text.contains("Clay"), "stores bar: the rest are listed behind \"+N more\"")
	check(hud.watched_stores().has(&"charcoal"), "stores bar: a full store is watched")
	check(hud.watched_stores().slice(0, Hud.BAR_MAX).has(&"charcoal"), "stores bar: a full store makes the bar")
	hud.free()
	Village.load_state({"stats": {}})
	_reset()

## The playtest build stops at the last built era (EraDef.playable).
func test_playtest_end() -> void:
	Village.load_state({"era": 4, "stats": {}})
	check(not Defs.era(4).playable, "playtest end: Era 4 is not playable yet")
	check(GoalPanel.state()["mode"] == &"free", "playtest end: the goal panel says the playtest ends here")
	Village.load_state({"era": 3, "stats": {}})
	check(GoalPanel.state()["mode"] != &"free", "playtest end: Era 3 still has its dreams")
	Village.load_state({"stats": {}})

# ---------------------------------------------------------------- the Save page

## Era 2 playtest: the Save page sometimes showed see-through. Opening it a
## second time (after the menu had been closed) left its parchment the height
## of its title, with the slots drawn over the valley.
func test_save_page_fits() -> void:
	var menu: Node = load("res://scenes/world/title.tscn").instantiate()
	root.add_child(menu)
	await _frames(2)
	var ok := true
	for i in 3:
		menu.open_paused()
		await _frames(1)
		menu._show_save()
		await _frames(3)
		var sub: Control = menu._sub
		var need: Vector2 = sub.get_combined_minimum_size()
		ok = ok and sub.visible and sub.size.y >= need.y - 1.0 and need.y > 200.0
		if not ok:
			print("  save page %d: size %s, needs %s" % [i, sub.size, need])
		menu.close()
		await _frames(1)
	check(ok, "menu: the Save page's parchment covers its slots every time")
	menu.free()
	Clock.running = false
