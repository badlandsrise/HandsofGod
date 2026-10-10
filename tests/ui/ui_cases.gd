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
