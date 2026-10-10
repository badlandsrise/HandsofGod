extends Node
## Staging for tests/ui/fb_shots.gd: the clarity pass, shot over the real
## world. Each case builds on the one before (an Era 1 run, sped through).

const ALL := ["card", "locks", "goal", "festival", "bless", "birth", "save"]
const OUT := "res://tests/shots"

var w: Node3D
var hud: Hud
var want: Array = ALL

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _shot(file: String) -> void:
	# software rendering runs at ~1 fps here: settle the eased faith number
	if hud != null and is_instance_valid(hud.faith_ring):
		hud.faith_ring._shown = hud.faith_ring.available
		await _frames(1)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])

func run() -> void:
	Save.enabled = false
	if Game.flags.get("only") is String:
		want = str(Game.flags["only"]).split(",", false)
	w = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await _frames(3)
	if Clock.running == false:
		w.new_game()
		w.start_play()
	hud = w.hud
	if w.camera_rig != null and &"edge_pan" in w.camera_rig:
		w.camera_rig.edge_pan = false
	await _wait(1.0)
	_skip_onboarding()
	await _close_naming()
	await _wait(0.5)
	await _card()
	if "locks" in want: await _locks()
	await _goal()
	if "festival" in want or "bless" in want: await _festival()
	if "bless" in want: await _bless()
	if "birth" in want: await _birth()
	if "save" in want: await _save()
	print("FB UI SHOTS done")
	OS.kill(OS.get_process_id())

func _skip_onboarding() -> void:
	if w.storm.active():
		w.branch.on_lifted()
		w.branch.on_placed(w.cave_position() + Vector3(7.0, 0, 6.0))
	w.storm.skip()
	w.storm.set_process(false)
	w.look.set_weather(0.0, false)
	Clock.is_night = false
	Clock.day = 3
	Clock.phase_t = 22.0
	Faith.grant(&"grip_2")
	for s in Village.sites:
		if is_instance_valid(s) and s.is_fire():
			s.add_fuel(Site.FIRE_MAX_FUEL)
	w.look.update_now()

func _close_naming() -> void:
	for i in 10:
		await _frames(2)
		if hud.naming.is_open():
			hud.naming.accept()

## Waits (up to secs) for the dream card to come up; true when it did.
func _await_card(secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if hud.dream_card.is_open():
			return true
		await _frames(1)
		t += get_process_delta_time() if Engine.time_scale > 0.0 else 0.016
	return hud.dream_card.is_open()

func _accept_cards() -> void:
	while hud.dream_card.pending():
		if await _await_card(3.0):
			hud.dream_card.accept()
			await _wait(0.3)
		else:
			break

## Lets the dream-came-true banners go (the forced completions stack them).
func _clear_notices() -> void:
	for it in hud.notices._items:
		it["t"] = minf(float(it["t"]), 0.0)

## The hand off to the side, so it does not sit on the subject.
func _hand_aside() -> void:
	Input.warp_mouse(Vector2(1570, 540))

func _camera(at: Vector3, d: float, yaw: float = 0.0) -> void:
	w.camera_rig.target_yaw = yaw
	at.y = w.ground_y(at.x, at.z)
	w.camera_rig.snap_to(at, d)

## The first dream arrives: the card waits for a click.
func _card() -> void:
	Village.stats["onboarding"] = Onboarding.Beat.DONE
	Village.stats["last_dream_t"] = -1000.0
	_camera(Vector3(-2, 0, -12), 26.0)
	# Dreams.update announces "a shelter of our own"; the card pauses play.
	if await _await_card(6.0):
		await _frames(30)
		if "card" in want:
			await _shot("fb_ui_dream_card.png")
	await _accept_cards()
	await _wait(2.0)          # the first wanderer's beat runs

## Austin's case: 13 faith, Strength I still locked by the Valley Floor and
## the first dream.
func _locks() -> void:
	Faith.total = 13.0
	Faith.spent = 0.0
	Events.faith_changed.emit(Faith.total)
	hud.refresh()
	hud.show_power_card(&"strength_1")
	await _wait(1.5)
	await _shot("fb_ui_power_locks.png")
	hud.hide_power_card()

func _finish(bid: StringName) -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == bid and s.state != Site.State.FINISHED:
			for k in s.building.cost:
				s.delivered[k] = int(s.building.cost[k])
			s._finish(false)
			return s
	var spots: Array = w.plot_spots(bid)
	if spots.is_empty():
		return null
	var s2: Site = w.spawn_plot(bid, Vector3(spots[0].x, 0, spots[0].y))
	for k in s2.building.cost:
		s2.delivered[k] = int(s2.building.cost[k])
	s2._finish(false)
	return s2

## The great dream of the age, mid-way: people 9/12, a winter of two, the
## festival still to come, the stone circle's plot half supplied.
func _goal() -> void:
	_finish(&"hut")
	_finish(&"fire_circle")
	await _wait(1.5)          # Dreams.update completes the first dream
	await _accept_cards()
	Dreams.complete(Defs.dream(&"shelter_of_our_own"))
	Dreams.complete(Defs.dream(&"shrine_to_the_hand"))
	_finish(&"shrine")
	var names := ["Ama", "Bo", "Kesi", "Rin", "Tavi", "Lok", "Mira"]
	var i := 0
	while Village.population() < 9:
		w.spawn_person(Vector3(-6.0 + i * 1.8, 0, -9.0), names[i % names.size()])
		i += 1
	Village.stats["winters_survived"] = 1
	Village.stats["last_dream_t"] = -1000.0
	await _wait(1.5)          # Dreams.update announces the stone circle
	await _await_card(4.0)
	await _accept_cards()
	w.ensure_plots_for_dream(&"stone_circle")
	for s in Village.sites:
		if is_instance_valid(s) and s.building != null and s.building.id == &"stone_circle" and s.is_plot():
			s.deliver(&"stone", 6)
	Faith.total = 54.0
	Faith.spent = 10.0
	_camera(Vector3(-2, 0, -8), 30.0, 0.2)
	await _wait(1.0)
	_clear_notices()
	_hand_aside()
	await _wait(1.5)
	if "goal" in want:
		await _shot("fb_ui_goal_checklist.png")

## Blessing bought: the camera finds the dance spot by the fire circle.
func _festival() -> void:
	Faith.grant(&"warmth")
	_camera(Vector3(-2, 0, -20), 30.0, 0.2)
	await _wait(0.6)
	Faith.grant(&"blessing")
	w.village_ai.progression.check_now()
	_clear_notices()
	_hand_aside()
	var t := 0.0
	while t < 10.0 and str(hud.guidance._beat.get("key", "")) != "dance_spot":
		await _wait(0.2)
		t += 0.2
	await _wait(5.0)          # ~1 fps under software rendering: let the beacon fade in
	if "festival" in want:
		await _shot("fb_ui_festival_guidance.png")
	await _wait(3.5)

## Blessed dancers at the spot: rings that empty with the time left.
func _bless() -> void:
	var fest: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"festival":
			fest = s
	if fest == null:
		return
	var i := 0
	for p in Village.alive():
		if i >= 5 or p.stage != Person.Stage.ADULT:
			continue
		p.on_lifted()
		p.on_placed(fest.slot_position(i), fest)
		i += 1
	_clear_notices()
	_hand_aside()
	for b in get_tree().get_nodes_in_group(&"beacon"):
		if b is Beacon and b.kind != &"dance_spot":
			b.dismiss()       # the wanderer's mark (long-lived at ~1 fps)
	_camera(fest.global_position + Vector3(0, 0, 1.0), 13.0, 0.3)
	await _wait(6.0)          # ~1 fps here: the dance-spot beacon steps back
	var left := [29.0, 24.0, 16.0, 9.0, 5.0]
	var k := 0
	for p in fest.workers:
		if is_instance_valid(p):
			p.bless(left[k % left.size()])
			k += 1
	# hold game time still (the blessings would drain at ~1 fps) while the
	# rings, which run on real time, come up
	Clock.set_speed(0)
	hud.guidance.caption._t = 0.0
	await _wait(10.0)
	await _shot("fb_ui_blessing_ring.png")
	Clock.set_speed(1)

## A baby is born: a portrait alert, a beacon, the camera looks.
func _birth() -> void:
	var adults: Array = Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT)
	var mom: Person = null
	var dad: Person = null
	for p in adults:
		if p.sex == "f" and mom == null:
			mom = p
		elif p.sex == "m" and dad == null:
			dad = p
	if mom == null or dad == null:
		return
	mom.partner = dad.uid
	dad.partner = mom.uid
	_camera(Vector3(-2, 0, -14), 30.0, 0.0)
	await _wait(0.5)
	_clear_notices()
	_hand_aside()
	var baby := Births.have_child(mom, dad)
	await _wait(2.4)
	await _shot("fb_ui_birth_alert.png")
	await _wait(2.0)
	if baby != null:
		hud.guidance.mark(baby, 6.0)

## The pause menu's Save page over the running valley (it used to show
## see-through when opened over the HUD's paused state).
func _save() -> void:
	await _accept_cards()
	Clock.set_speed(1)
	await _wait(0.3)
	var title: Node = w.title if w.title != null else load("res://scenes/world/title.tscn").instantiate()
	if title.get_parent() == null:
		w.add_child(title)
		w.title = title
		var t := 0.0          # a fresh title fades up from black
		while t < 20.0 and title._fade.color.a > 0.02:
			await _wait(0.5)
			t += 0.5
	title.open_paused()
	await _wait(0.5)
	title._show_save()
	await _wait(1.0)
	await _shot("fb_ui_save_menu.png")
	title.close()
