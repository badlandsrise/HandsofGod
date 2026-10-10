extends RefCounted
## The cases for tests/front/test_front.gd (loaded after the autoloads exist).

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

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)

func _run() -> void:
	Save.enabled = false
	Save.dir = "user://test_front_saves"
	for f in DirAccess.get_files_at(Save.dir) if DirAccess.dir_exists_absolute(Save.dir) else PackedStringArray():
		DirAccess.remove_absolute(Save.dir.path_join(f))
	Options.path = "user://test_front_options.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Options.path))
	Options.loaded = false
	Game.options.erase("skip_intros")
	check(not Game.testing(), "runs without --test, like a real launch")

	# ---- splash
	var boot: Node = load("res://scenes/front/boot.tscn").instantiate()
	tree.root.add_child(boot)
	await _frames(20)
	check(boot.splash != null and is_instance_valid(boot.splash), "splash: shown on launch")
	_key(KEY_SPACE)
	var got_world := await _until(func(): return Game.world != null and is_instance_valid(Game.world) and Game.world.built, 60.0)
	check(got_world, "splash: a key skips it and the world loads")
	check(not is_instance_valid(boot), "splash: the boot scene is gone")
	var w = Game.world

	# ---- title
	var menu = await _wait_menu()
	check(menu != null and menu.visible and not menu.paused_mode, "title: the menu is up")
	if menu == null:
		finished = true
		return
	check(not menu._continue_btn.visible, "title: no Continue without a save")
	check(menu._logo.visible, "title: the logo is shown")
	check(menu._stage != null and menu._stage.active and menu._stage.hand.visible, "title: the stage runs with the hand")
	check(w.title_camera.current, "title: the title camera is live")
	check(not Clock.is_night, "title: the valley is at dawn")
	check(_button(menu, "New Game") != null, "title: New Game is offered")

	# ---- new game -> intro (skipped)
	_button(menu, "New Game").pressed.emit()
	await _frames(3)
	var intro = menu.intro
	check(intro != null and intro.playing, "new game: the intro plays")
	check(not menu.visible and not w.hud.visible and not Clock.running, "intro: menu and HUD hidden, the clock stopped")
	check(intro != null and intro.cam.current, "intro: its camera is live")
	await _until(func(): return intro.t > 0.6, 10.0)
	# [polish] Austin: "the two sit on nothing". Each sits on a log or rock.
	var seated := 0
	for p in intro.people:
		var v = p.visual.get(&"villager") if is_instance_valid(p) and p.get(&"visual") != null else null
		if v != null and v.has_seat():
			seated += 1
	check(intro.people.size() == 2 and seated == 2, "intro: the first two sit on a log or rock (%d of %d)" % [seated, intro.people.size()])
	_key(KEY_ENTER)              # arms the skip
	await _frames(8)
	check(intro.playing and intro._skip_armed > 0.0, "intro: one key only asks to skip")
	_key(KEY_ENTER)              # skips
	await _frames(8)
	check(intro.skipped and intro.done, "intro: a second key skips it")
	_check_storm_play(w, menu, "after skip")

	# ---- the storm night hands off to the naming card
	var card = w.hud.naming
	Clock.set_speed(3)
	w.branch.global_position += Vector3(6, 0, 4)
	w.branch.placed.emit(w.branch.global_position)
	var named := await _until(func(): return card.is_open(), 30.0)
	check(named, "storm night: lifting the branch away brings the naming card")
	if named:
		check(card._reason == &"first_two" and card._people.size() == 2, "naming: it names the first two")
		card.accept()
	await _frames(5)

	# ---- back to the title, New Game again: the intro runs to its end by itself
	menu._on_quit_to_title()
	await _frames(5)
	check(menu.visible and menu._stage.active, "quit to title: the title is back")
	_button(menu, "New Game").pressed.emit()
	await _frames(2)
	var intro2 = menu.intro
	if intro2 != null:
		intro2.rate = 12.0
	var ended := await _until(func(): return intro2 == null or not is_instance_valid(intro2) or intro2.done, 20.0)
	if intro2 != null and is_instance_valid(intro2):
		print("     intro2 t=%.1f playing=%s done=%s" % [intro2.t, intro2.playing, intro2.done])
	check(ended and intro2 != null and not intro2.skipped, "intro: plays through to its end unskipped")
	await _frames(3)
	_check_storm_play(w, menu, "after the full intro")

	# ---- skip intros: New Game goes straight to the storm night
	menu._on_quit_to_title()
	await _frames(5)
	Options.set_opt("skip_intros", true, false)
	_button(menu, "New Game").pressed.emit()
	await _frames(3)
	check(menu.intro == null, "skip intros: no intro on New Game")
	_check_storm_play(w, menu, "with skip intros")
	Options.set_opt("skip_intros", false, false)
	finished = true

func _check_storm_play(w, menu, tag: String) -> void:
	check(w.storm.state == StormOpening.S.STORM, "%s: the storm night is on" % tag)
	check(Clock.is_night and w.look.storm and w.look.rain_target >= 1.0, "%s: night, storm and rain" % tag)
	check(Clock.running and w.hud.visible and not menu.visible, "%s: playing (clock runs, HUD up, menu gone)" % tag)
	check(not w.title_camera.current and w.hand.visible, "%s: the play camera and the hand are back" % tag)
	var ok := true
	for p in w.storm.people:
		ok = ok and is_instance_valid(p) and p.is_physics_processing()
	check(ok, "%s: the two people are back under their own control" % tag)
	check(w.get_node_or_null("FirstNight") != null, "%s: the naming hand-off is waiting" % tag)

func _wait_menu():
	var ok := await _until(func(): return tree.get_first_node_in_group(&"game_menu") != null, 10.0)
	await _frames(5)
	return tree.get_first_node_in_group(&"game_menu") if ok else null

func _button(menu, text: String) -> Button:
	for b in menu._main.get_children():
		if b is Button and b.text == text and b.visible:
			return b
	return null
