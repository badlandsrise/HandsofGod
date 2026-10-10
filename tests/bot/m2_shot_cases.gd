extends Node
## Staging for tests/bot/m2_shots.gd.

const ALL := ["plots", "held", "winter", "festival", "era"]
const OUT := "res://tests/bot/shots"

var w: Node3D
var want: Array = ALL

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

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
	await _wait(1.0)
	_skip_onboarding()
	await _wait(0.5)
	if "plots" in want: await _plots()
	if "held" in want: await _held()
	if "festival" in want: await _festival()
	if "winter" in want: await _winter()
	if "era" in want: await _era()
	print("M2 SHOTS done")
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
	Clock.phase_t = 25.0
	Village.stats["onboarding"] = Onboarding.Beat.DONE
	Faith.grant(&"grip_2")
	for s in Village.sites:
		if is_instance_valid(s) and s.is_fire():
			s.add_fuel(Site.FIRE_MAX_FUEL)
	var names := ["Ama", "Bo", "Kesi", "Rin", "Tavi", "Lok", "Mira"]
	for i in names.size():
		w.spawn_person(Vector3(-6.0 + i * 1.8, 0, -9.0), names[i])
	w.look.update_now()

func _site_for(bid: StringName, at: Vector2) -> Site:
	return w.spawn_plot(bid, Vector3(at.x, 0, at.y))

## A hut at each build stage, left to right: staked plot with its ghost,
## materials coming in, the pole frame, walls and roof rising, finished.
func _plots() -> void:
	var spots := [Vector2(-14, 2), Vector2(-8, 2), Vector2(-2, 2), Vector2(4, 2), Vector2(10, 2)]
	var stages: Array = []
	for i in spots.size():
		stages.append(_site_for(&"hut", spots[i]))
	await _frames(2)
	stages[1].deliver(&"wood", 3)
	for s in [stages[2], stages[3], stages[4]]:
		s.deliver(&"wood", 6)
	stages[2].add_build_work(5.0)
	stages[3].add_build_work(14.0)
	stages[4].add_build_work(100.0)
	var shrine: Site = _site_for(&"shrine", Vector2(-4, -6))
	shrine.deliver(&"stone", 3)
	await _frames(4)
	for s in [stages[2], stages[3]]:
		s.rebuild_visual()
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(Vector3(-2, w.ground_y(-2, 0), 0.0), 24.0)
	w.hand.aim_override = Vector3(16, w.ground_y(16, -6), -6)
	await _frames(10)
	await _shot("m2_plots.png")

## Three people dangling under the hand (Grip II), over the Clearing.
func _held() -> void:
	var hand = w.hand
	var people: Array = Village.alive().slice(2, 5)
	var at := Vector3(-2.0, 0, -6.0)
	at.y = w.ground_y(at.x, at.z)
	w.camera_rig.target_yaw = -0.6
	w.camera_rig.snap_to(at + Vector3(0, 0, 0), 18.0)
	hand.aim_override = at
	await _frames(3)
	hand.lift_many(people)
	await _frames(2)
	hand.air_pos = hand.ground + Vector3(0, Hand.HOVER_H_HOLD, 0)
	await _frames(8)
	await _shot("m2_held.png")
	hand.place_on_ground(at)
	hand.aim_override = Vector3.INF
	await _frames(20)

## The first festival: blessed dancers at the fire circle at dusk.
func _festival() -> void:
	var circle: Site = w.spawn_plot(&"fire_circle", Vector3(-1.5, 0, -4.5))
	circle.start_finished = true
	circle._finish(false)
	circle.add_fuel(Site.FIRE_MAX_FUEL)
	Faith.grant(&"warmth")
	Faith.grant(&"blessing")
	var fest: Site = w.spawn_site(&"festival", circle.global_position + Vector3(0, 0, 4.5))
	var i := 0
	for p in Village.alive():
		if i >= 7:
			break
		p.on_lifted()
		p.on_placed(fest.slot_position(i), fest)
		i += 1
	Clock.phase_t = Clock.day_seconds - 6.0
	w.look.update_now()
	await _wait(2.5)
	HandPowers.bless_at(fest.global_position)
	w.camera_rig.target_yaw = 0.3
	w.camera_rig.snap_to(fest.global_position + Vector3(0, 0, 1.0), 20.0)
	w.hand.aim_override = fest.global_position + Vector3(0, 0, -1.0)
	await _frames(12)
	await _shot("m2_festival.png")
	w.hand.aim_override = Vector3.INF

## Winter: snow on the ground, people by the fire.
func _winter() -> void:
	Clock.season = Clock.Season.WINTER
	Clock.season_t = Clock.season_seconds * 0.5
	Clock.year = 1
	Clock.phase_t = 30.0
	Clock.is_night = false
	Events.season_changed.emit(Clock.season)
	w.look.update_now()
	await _wait(1.0)
	w.camera_rig.target_yaw = 0.0
	w.camera_rig.snap_to(Vector3(0, w.ground_y(0, -8), -8.0), 34.0)
	w.hand.aim_override = Vector3(8, w.ground_y(8, -16), -16)
	await _frames(12)
	await _shot("m2_winter.png")

## Era 1 complete: the gate dream done, the camera pulls back.
func _era() -> void:
	Clock.season = Clock.Season.SUMMER
	Events.season_changed.emit(Clock.season)
	w.look.update_now()
	var sc: Site = w.spawn_plot(&"stone_circle", Vector3(-26, 0, -16))
	sc.start_finished = true
	sc._finish(false)
	Village.stats["dream_active"] = "stone_circle"
	Dreams.complete(Defs.dream(&"stone_circle"))
	await _wait(2.6)
	await _shot("m2_era_complete.png")

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("SHOT %s %s" % [path, "ok" if err == OK else "error %d" % err])
