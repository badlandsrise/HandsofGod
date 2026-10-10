extends RefCounted
## The cases for tests/ending/test_goodbye.gd (loaded once the autoloads exist).

const ALL := [&"evening", &"crew", &"boarding", &"countdown", &"liftoff", &"wave", &"words", &"light",
	&"lineage", &"rest", &"credits", &"dawn", &"done"]

var tree: SceneTree
var fails := 0
var finished := false

func start(t: SceneTree) -> void:
	tree = t
	_run()

func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		printerr("FAIL ", what)

func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame

func _until(cond: Callable, limit_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > limit_s:
			return false
		await tree.process_frame
	return true

func _run() -> void:
	Save.enabled = false
	CreditsRoll.seen_path = "user://test_goodbye_ending.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CreditsRoll.seen_path))
	Game.options.erase(CreditsRoll.SEEN_KEY)
	Game.flags["goodbye"] = true
	Game.flags["seed"] = "3"
	var w: Node = load("res://scenes/world/world.tscn").instantiate()
	tree.root.add_child(w)
	tree.current_scene = w
	var got := await _until(func(): return w.get(&"goodbye") != null and is_instance_valid(w.goodbye), 90.0)
	check(got, "--goodbye: the dev entry builds an Era 4 setup and starts the goodbye")
	if not got:
		finished = true
		return
	var seq: GoodbyeSequence = w.goodbye
	Game.flags.erase("goodbye")

	# ---- the cast
	var cast := seq.cast
	check(cast.first_names == ["Ona", "Tuk"], "cast: the first two are the ones the player named (%s)" % [cast.first_names])
	check(cast.crew.size() == 4, "cast: a crew of four")
	var all_desc := true
	for p in cast.crew:
		var l := cast.line_of(p.uid)
		all_desc = all_desc and l.size() >= 2 and cast.first_two.has(int(l[0])) and p.alive() and p.stage == Person.Stage.ADULT
	check(all_desc, "cast: every crew member is a living adult descendant of the first two")
	check(cast.commander == cast.crew[0] and str(cast.commander.given_name) == "Valentina", "cast: the commander is the most trusting descendant (%s)" % cast.commander.given_name)
	check(cast.relation(cast.commander).contains("granddaughter of Ona and Tuk"), "cast: the commander's relation reads back to the first two (%s)" % cast.relation(cast.commander))
	var lin := cast.lineage()
	check(int(lin["depth"]) >= 5 and (lin["edges"] as Array).size() >= 8, "cast: the lineage runs from the first two to the crew (%d generations)" % int(lin["depth"]))
	var words := cast.last_words()
	check(words.size() >= 5 and words.any(func(x): return str(x).contains("Ona and Tuk")), "words: the commander's last words come from the journal")
	check(words.any(func(x): return str(x).contains("handprint stone")), "words: they take the first gift with them")
	var mem := cast.memories(8)
	check(mem.size() >= 6 and not mem.any(func(x): return str(x).contains("died")), "credits: memories from the Book, none of them of death")
	var blocks := CreditsRoll.blocks(cast)
	var flat := " ".join(blocks.map(func(b): return str(b.get("t", ""))))
	check(flat.contains("Badlandsrise Game Studio") and flat.contains("Quaternius") and flat.contains("Valentina") and flat.contains("Among the Stars"),
		"credits: the studio, CREDITS.md, the people's names")

	# ---- every beat in order, with skips
	var pop0 := Village.population()
	var deaths0 := int(Village.stats.get("deaths", 0))
	var order_ok := true
	for i in ALL.size() - 1:
		if seq.beat_name() != ALL[i]:
			order_ok = false
			printerr("     expected %s, at %s" % [ALL[i], seq.beat_name()])
		match ALL[i]:
			&"evening":
				await _frames(10)
				check(Audio.cue_playing() == &"last_evening", "evening: the music thins to The Last Evening")
				check(seq.cam != null and seq.cam.current, "evening: the goodbye's own camera")
				check(w.hand.visible == false and w.hud.visible == false, "evening: the play hand and the HUD step aside")
			&"boarding":
				seq.fast_forward(1.5)
				seq._click = true
				seq.fast_forward(LIFT_TIME_PLUS)
				check(seq._boarded == 1 and not seq.crew[0].visible, "boarding: one click lifts the commander into the capsule")
			&"countdown":
				check(seq._rocket_ready and seq.rocket.get_meta("asset_id", "") == "rocket_ready", "countdown: the rocket is fuelled, the crew aboard")
				seq.fast_forward(4.0)
				check(seq._counting == 0.0 and seq._count_shown == 10, "countdown: nothing counts until the hand holds")
				seq.set_hold(true)
				seq.fast_forward(COUNT_HOLD)
				var c1: int = seq._count_shown
				check(c1 <= 9 and c1 >= 7, "countdown: holding counts down (%d)" % c1)
				check(Audio.cue_playing() == &"countdown", "countdown: the Countdown cue plays")
				seq.set_hold(false)
				seq.fast_forward(3.0)
				check(seq._count_shown == c1, "countdown: letting go pauses it")
				check(is_equal_approx(Audio._cue_level, 0.35), "countdown: ... gently, the music ducked with cue_level")
				check(not seq._ignited, "countdown: ... and nothing fails")
				seq.set_hold(true)
				seq.fast_forward(1.0)
				check(is_equal_approx(Audio._cue_level, 1.0), "countdown: holding again brings it back")
				seq.set_hold(false)
			&"credits":
				check(not seq.skip_beat(), "credits: not skippable on the first viewing")
				check(Audio.cue_playing() == &"credits", "credits: Among the Stars plays")
				check(seq.roll != null and seq.roll.visible, "credits: the roll is up")
				check(seq.skip_beat(true), "credits: (test) forced on")
				check(CreditsRoll.seen(), "credits: remembered as seen")
				continue
			&"dawn":
				seq.fast_forward(8.0)
				continue
		var ok := seq.skip_beat()
		if not ok:
			order_ok = false
			printerr("     could not skip %s" % ALL[i])
		await _frames(2)
	check(order_ok, "beats: evening, crew, boarding, countdown, liftoff, wave, words, light, lineage, rest, credits, dawn, in order")
	check(seq.beats_seen == ALL, "beats: all seen (%s)" % [seq.beats_seen])
	await _frames(5)
	# ---- free play at dawn
	check(seq.done, "the goodbye is over")
	check(Clock.running and not Clock.is_night, "free play: the clock runs, and it is morning")
	check(w.hand.visible and w.hand.process_mode == Node.PROCESS_MODE_INHERIT, "free play: the hand is back, whole")
	check(w.hud.visible, "free play: the HUD is back")
	check(w.camera_rig.camera.current, "free play: the play camera")
	check(Village.population() == pop0 - 4, "free play: four went up, everyone else is still here (%d -> %d)" % [pop0, Village.population()])
	check(int(Village.stats.get("deaths", 0)) == deaths0 and Village.alive().size() == Village.people.filter(func(p): return is_instance_valid(p)).size(), "free play: nobody died")
	var gb: Dictionary = Village.stats.get("goodbye", {})
	check((gb.get("crew", []) as Array).size() == 4 and gb.get("commander", "") == "Valentina", "free play: the Book remembers the crew")
	var rec: Dictionary = BookData.journal()["people"].get(str(cast.crew[0].uid if is_instance_valid(cast.crew[0]) else 0), {})
	var gone_ok := true
	for p in BookData.all_records():
		if str(p["name"]) in (gb.get("crew", []) as Array):
			gone_ok = gone_ok and bool(p["alive"])
	check(gone_ok, "free play: the crew are among the stars, not dead, in the Book")
	var last: Dictionary = BookData.journal()["entries"][-1]
	check(str(last.get("kind")) == "goodbye" and str(last.get("text")).contains("Valentina"), "free play: the journal tells it (%s)" % str(last.get("text")).left(60))
	check(Audio.cue_playing() == &"", "free play: the era's own music comes back")
	var seq_ref: WeakRef = weakref(seq)
	seq = null
	check(await _until(func(): return seq_ref.get_ref() == null, 5.0), "the sequence frees itself")

	# ---- the whole goodbye, played by the autopilot, sped up
	GoodbyeStage.setup(w, 11)
	var seq2: GoodbyeSequence = w.start_goodbye({"rate": 14.0, "autopilot": true})
	var reached := await _until(func(): return not is_instance_valid(seq2) or seq2.beat >= GoodbyeSequence.B.CREDITS, 120.0)
	check(reached and is_instance_valid(seq2), "autopilot: played from the evening to the credits")
	if is_instance_valid(seq2):
		check(seq2._counting >= 14.0 and seq2._ignited and seq2._waved and seq2._lowered, "autopilot: held the countdown, waved back, lowered the hand")
		check(seq2.child != null and seq2.child.global_position.distance_to(seq2._finger_point()) < 1.0, "autopilot: a child sits on the hand's finger")
		await _frames(20)
		check(seq2.skip_beat(), "credits: skippable on the second viewing")
		var over := await _until(func(): return not is_instance_valid(seq2) or seq2.done, 30.0)
		check(over, "autopilot: ends in free play")
	check(Clock.running and w.hand.visible, "autopilot: free play again")
	finished = true

const LIFT_TIME_PLUS := 4.2
const COUNT_HOLD := 3.6
