extends Node
## Screenshots of the M2 UI over the real world: the naming card, each Village
## Book tab, the era card, alerts and banners, the pause menu, options and title.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . res://tests/ui/ui_shots.tscn
## Optional: -- --ui-shots=naming,book,era,alerts,menu,title (default all)
## Writes tests/shots/ui_*.png, then quits.

const OUT := "res://tests/shots"
const ALL := ["naming", "book", "era", "alerts", "menu", "title"]

var w: Node = null
var want: Array = ALL

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	Game.flags["no-title"] = true
	if Game.flags.get("ui-shots") is String:
		want = str(Game.flags["ui-shots"]).split(",", false)
	w = load("res://scenes/world/world.tscn").instantiate()
	add_child(w)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])

func _portraits_done(limit_frames: int = 400) -> void:
	var p := Portraits.get_inst()
	for i in limit_frames:
		if p == null or (p._queue.is_empty() and not p._busy):
			return
		await get_tree().process_frame

func _run() -> void:
	await _wait(1.0)
	var cam = w.camera_rig
	if cam != null and &"edge_pan" in cam:
		cam.edge_pan = false
	var t0 := Time.get_ticks_msec()
	var first: Array = Village.alive().slice(0, 2)
	if "naming" in want:
		cam.snap_to(w.cave_position() + Vector3(0, 0, 10.0), 26.0)
		Events.name_requested.emit(first, &"first_two")
		await _frames(4)
		var card: NamingCard = w.hud.naming
		for p in first:
			Portraits.get_inst().request(BookData.record_of(p).merged({"hand_named": false}, true))
		await _portraits_done()
		card.set_name_field(0 if first[0].sex == "f" else 1, "Ona")
		card.set_name_field(1 if first[0].sex == "f" else 0, "Pim")
		await _wait(0.8)
		await _shot("ui_naming.png")
		card.accept()
	else:
		Events.names_given.emit(first)
	await _to_day()
	await _populate()
	if "alerts" in want:
		await _alerts()
	if "book" in want:
		await _book()
	if "era" in want:
		Events.era_complete_shown.emit(1)
		await _wait(1.6)
		await _shot("ui_era_card.png")
		w.hud.era_card.keep_playing()
		await _wait(0.6)
	if "menu" in want:
		await _menu()
	if "title" in want:
		var menu: Node = w.title if w.title != null else load("res://scenes/world/title.tscn").instantiate()
		if menu.get_parent() == null:
			w.add_child(menu)
			w.title = menu
		menu.open_paused()
		menu._on_quit_to_title()
		await _wait(2.0)
		await _shot("ui_title.png")
	print("UI SHOTS done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	OS.kill(OS.get_process_id())

## Past the storm: a sunny morning.
func _to_day() -> void:
	if w.storm.active():
		w.branch.on_lifted()
		Events.hand_lifted_object.emit(w.branch)
		w.branch.on_placed(w.cave_position() + Vector3(7.0, 0, 6.0))
	w.storm.skip()
	w.storm.set_process(false)
	await _wait(0.4)
	w.look.set_weather(0.0, false)
	Clock.is_night = false
	Clock.day = 3
	Clock.phase_t = 22.0
	w.look.update_now()
	Clock.running = true

## A village with a history: families, a wanderer, gifts, dreams, a death.
func _populate() -> void:
	var ona: Person = Village.alive()[0]
	var pim: Person = Village.alive()[1]
	if ona.sex != "f":
		var t := ona; ona = pim; pim = t
	ona.partner = pim.uid; pim.partner = ona.uid
	ona.trust_f = 4.4; ona.trust = 4
	pim.trust_f = 3.2; pim.trust = 3
	ona.skills[&"gathering"] = 3.4
	pim.skills[&"woodcraft"] = 4.1
	Clock.day = 3
	Events.hand_lifted.emit([ona])
	Clock.day = 4
	Events.hand_placed_object.emit(w.branch, Vector3.ZERO)
	var fire_site: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.has_method(&"is_fire") and s.is_fire():
			fire_site = s
	if fire_site != null:
		fire_site.add_fuel(Site.FIRE_MAX_FUEL)
	await _wait(1.3)
	Clock.day = 5
	Faith.grant(&"grip_2")
	_gift(ona, "handprint stone")
	Clock.day = 7
	var asha: Person = w.spawn_person(Vector3(-6, 0, -6), "Asha")
	asha.wanderer = true
	var bo: Person = w.spawn_person(Vector3(-4, 0, -7), "Bo")
	bo.wanderer = true
	await _frames(1)
	Events.person_joined.emit(asha)
	Events.person_joined.emit(bo)
	Clock.day = 9
	Events.dream_started.emit(&"shelter_of_our_own")
	Clock.day = 12
	var kids: Array = []
	for pair in [["Teo", "m"], ["Mira", "f"], ["Lun", "m"]]:
		var k := Person.spawn(w.dynamic, ona.global_position + Vector3(randf() * 3, 0, 2), {"name": pair[0], "sex": pair[1], "age": 1000.0 + randf() * 300.0, "parents": [ona.uid, pim.uid], "trust_f": 3.5})
		ona.children.append(k.uid); pim.children.append(k.uid)
		kids.append(k)
		await _frames(1)
		Events.person_born.emit(k)
		Clock.day += 2
	_gift(kids[1], "flowers")
	Dreams.complete(Defs.dream(&"shelter_of_our_own"))
	Clock.day = 21
	var teo: Person = kids[0]
	teo.partner = asha.uid; asha.partner = teo.uid
	Faith.add(40.0)
	Faith.buy(&"strength_1")
	Clock.day = 24
	var kai := Person.spawn(w.dynamic, teo.global_position + Vector3(1, 0, 1), {"name": "Kai", "sex": "m", "age": 380.0, "parents": [asha.uid, teo.uid], "trust_f": 3.4})
	teo.children.append(kai.uid); asha.children.append(kai.uid)
	await _frames(1)
	Events.person_born.emit(kai)
	Events.name_requested.emit([kai], &"baby_prayer")
	await _frames(3)
	w.hud.naming.set_name_field(0, "Kai")
	w.hud.naming.accept()
	Clock.day = 26
	_gift(asha, "carved hand")
	Village.stats["winters_survived"] = 1
	Clock.year = 2
	Events.season_changed.emit(0)
	Clock.day = 31
	var lun: Person = kids[2]
	lun.die("a wolf")
	Clock.day = 34
	Events.dream_started.emit(&"hut_and_fire")
	Village.stats["births"] = 4
	Faith.add(23.0)
	await _wait(1.2)
	for p in Village.people:
		if is_instance_valid(p):
			Portraits.get_inst().request(BookData.record_of(p))

func _gift(from: Person, kind: String) -> void:
	var g := Gift.new()
	g.kind = kind
	g.from_name = from.given_name
	g.from_uid = from.uid
	w.add_child(g)
	g.global_position = from.global_position
	Events.hand_lifted_object.emit(g)
	g.queue_free()

func _alerts() -> void:
	var cam = w.camera_rig
	cam.snap_to(Vector3(-2.0, w.ground_y(-2, -12), -12.0), 30.0)
	var a: Person = Village.alive()[0]
	Events.alert.emit("A wolf bit %s!" % a.given_name, a.global_position)
	Events.alert.emit("Howls at dusk. Wolves are near the treeline.", Vector3(30, 0, 30))
	Events.alert.emit("2 wanderers arrived", Village.alive()[3].global_position)
	Village.open_region(&"western_meadow")
	await _wait(0.4)
	Events.dream_done.emit(&"hut_and_fire")
	await _portraits_done()
	await _wait(0.9)
	await _shot("ui_alerts.png")
	await _wait(4.0)

func _book() -> void:
	var book: VillageBook = w.hud.book
	var names := ["people", "tree", "dreams", "memories", "powers"]
	for i in names.size():
		book.open_book(i)
		if i == 0:
			book.select_person(Village.alive()[0].uid)
		await _portraits_done()
		await _wait(0.6)
		await _shot("ui_book_%s.png" % names[i])
	book.close_book()

func _menu() -> void:
	var title: Node = load("res://scenes/world/title.tscn").instantiate()
	w.add_child(title)
	w.title = title
	title.open_paused()
	await _wait(0.6)
	await _shot("ui_pause.png")
	title._show_options()
	await _wait(0.6)
	await _shot("ui_options.png")
	title._show_save()
	await _wait(0.5)
	await _shot("ui_save.png")
	title.close()
