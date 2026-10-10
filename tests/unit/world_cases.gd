extends Node
## Cases for tests/unit/test_world.gd.

signal done(fails: int)

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _wait_bake(w) -> void:
	# A bake requested this frame may start on the next; then wait until the
	# new mesh is live on the map (regions sync on a background thread), with
	# a wall-clock bound: under a loaded CPU the bake thread is slower than frames.
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while (not w.nav.synced() or not w.nav.ready_for_paths()) and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame      # the map syncs on the next physics step

func _path(w, a: Vector3, b: Vector3) -> PackedVector3Array:
	var map: RID = w.get_world_3d().navigation_map
	return Nav.find_path(map, a, b)

func _path_ok(w, a: Vector3, b: Vector3) -> bool:
	var p := _path(w, a, b)
	return p.size() > 1 and p[p.size() - 1].distance_to(b) < 1.5

func run() -> void:
	Save.enabled = false
	Save.dir = "user://test_world_saves"
	var w: Node3D = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(w)
	await get_tree().process_frame
	w.new_game()
	Clock.running = false
	await get_tree().process_frame
	print("world build ms: %d" % w.build_ms)
	# ---- the hand, camera and HUD exist exactly once, even after a second new_game
	w.new_game()
	await get_tree().process_frame
	for sp in ["res://scripts/hand/hand.gd", "res://scripts/world/camera_rig.gd", "res://scripts/ui/hud.gd"]:
		var n := 0
		for node in get_tree().root.find_children("*", "", true, false):
			if node.get_script() != null and node.get_script().resource_path == sp:
				n += 1
		check(n == 1, "%s instanced exactly once (%d)" % [sp.get_file(), n])
	# ---- heightmap
	var y: float = w.ground_y(0, -13)
	check(y > 2.0 and y < 7.0, "Clearing floor height is sane (%.2f)" % y)
	check(w.ground_y(0, -60) > y + 8.0, "rock shelf rises north of the cave")
	check(w.ground_y(0, -400) > 40.0, "mountains frame the north")
	check(w.is_water(Vector3(0, 0, Valley.river_z(0))), "the river runs south of the Clearing")
	check(w.is_water(Vector3(560, 0, 560)), "the sea lies south-east")
	check(w.is_water(Vector3(Valley.stream_x(0), 0, 0)), "the stream flows through the Clearing")
	var hit: Vector3 = w.ray_ground(Vector3(0, 80, 40), Vector3(0, -80, -53).normalized())
	check(hit.is_finite() and absf(hit.y - w.ground_y(hit.x, hit.z)) < 0.05, "ray_ground hits the terrain")
	# ---- regions
	check(w.region_at(Vector3(0, 0, 0)) == &"clearing", "origin is the Clearing")
	check(w.region_at(Vector3(110, 0, 15)) == &"valley_floor", "east is the Valley Floor")
	check(w.region_at(Vector3(-110, 0, 5)) == &"western_meadow", "west is the Western Meadow")
	var b0: AABB = w.camera_bounds()
	check(b0.size.x < 150.0, "camera starts bounded to the Clearing (%.0f m)" % b0.size.x)
	# ---- sites from data
	var ids := {}
	for s in Village.sites:
		if s.job: ids[s.job.id] = true
		if s.building: ids[s.building.id] = true
	for id in [&"gather_berries", &"fetch_water", &"collect_sticks", &"tend_fire", &"haul_log", &"hunt", &"fish_by_hand", &"knap_flint", &"fell_tree"]:
		check(ids.has(id), "layout has %s" % id)
	var n_plots: int = w.ensure_plots_for_dream(&"shelter_of_our_own") + Village.sites.filter(func(s): return s.building != null and s.building.id == &"hut").size()
	check(n_plots >= 1, "a hut plot exists for the first dream")
	check(w.ensure_plots_for_dream(&"shrine_to_the_hand") == 1, "the shrine dream adds a shrine plot")
	check(w.ensure_plots_for_dream(&"shrine_to_the_hand") == 0, "and does not add it twice")
	var ever := Village.sites.filter(func(s): return s.has_meta("evergreen"))
	check(ever.size() == 3 and ever.all(func(s): return s.evergreen), "3 evergreen bushes by the cave (the safety net)")
	check(not Village.sites.any(func(s): return s.job != null and s.job.id == &"carry_log"), "the fire log waits for its onboarding beat")
	check(w.site_near(Vector3(0, 0, -13), 2.0, func(s): return s.is_fire()) != null, "site_near finds the fire")
	# ---- storm opening
	check(w.storm.active() and Clock.is_night and w.look.raining(), "a new game opens on the storm night")
	check(Village.population() == 2, "two people huddle outside the cave")
	# ---- navmesh
	await _wait_bake(w)
	check(w.nav.ready_for_paths(), "navmesh baked (%d polygons, %d ms)" % [w.nav.navigation_mesh.get_polygon_count(), w.nav.last_bake_ms])
	var fire: Vector3 = w.fire_position()
	var bush := Vector3(-9.5, w.ground_y(-9.5, -22), -22)
	check(_path_ok(w, fire, bush), "path from the fire to the cave bushes")
	var stash: Vector3 = w.stash.global_position
	print("  stash at %s, path %s" % [stash, _path(w, bush, stash)])
	check(_path_ok(w, bush, w.walkable_point(stash)), "path from the bushes to the stash")
	var meadow := Vector3(-100, w.ground_y(-100, 0), 0)
	check(not _path_ok(w, fire, meadow), "no path into the locked Western Meadow")
	# lift the branch, then the logs
	w.branch.on_lifted(); w.branch.on_placed(w.branch.global_position + Vector3(6, 0, 3))
	check(w.storm.state != StormOpening.S.STORM, "moving the branch ends the storm hold")
	var lg: Liftable = w.logs[0]
	check(lg.is_in_group("liftable") and lg.lift_weight() == 4.0, "meadow logs are liftable with weight 4")
	check(w.branch.lift_weight() == 2.0, "the storm branch has weight 2")
	for i in w.logs.size():
		w.logs[i].on_lifted(); w.logs[i].on_placed(Vector3(-40 + i * 3, 0, -12))
		if i < w.logs.size() - 1:
			check(not w.is_region_open(&"western_meadow"), "meadow stays shut with %d log(s) still in the gap" % (w.logs.size() - 1 - i))
	check(w.is_region_open(&"western_meadow"), "the meadow opens once every log is off the gap")
	check(w.camera_bounds().size.x > b0.size.x + 100.0, "camera bounds widen with the meadow")
	await get_tree().create_timer(2.6).timeout
	await _wait_bake(w)
	check(w.regions.light[2] > 0.99, "the meadow has lightened")
	check(_path_ok(w, fire, meadow), "a path into the Western Meadow after it opens")
	# the trunk group job opens the Valley Floor
	var ts: Site = w.trunk_site
	check(ts != null and ts.job.min_people == 3, "the fallen trunk is a group job for 3")
	Events.job_completed.emit(ts)
	check(w.is_region_open(&"valley_floor") and w.trunk.cleared, "hauling the trunk opens the Valley Floor")
	# ---- threats
	var wolves: Wolves = w.wolves
	var warned := []
	Events.threat_warned.connect(func(id, _at): warned.append(id))
	for i in 3:
		w.spawn_person(Vector3(i * 2, 0, 5))
	wolves.warn(2)
	check(warned.has(&"wolves"), "wolves are telegraphed with threat_warned")
	wolves.start()
	await get_tree().process_frame
	check(wolves.count() == 2, "two wolves came")
	var n: int = wolves.scare(w.fire_position(), 500.0)
	check(n == 2, "scare() sends wolves running")
	w.threats.start_cold_warning()
	check(warned.has(&"cold_snap"), "a cold snap is telegraphed")
	wolves.clear_all()
	await _locked_cases(w)
	await _pass_cases(w)
	await _crossing_cases(w)
	_paths_cases(w)
	_layout_cases(w)
	w.queue_free()
	await get_tree().process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)

func _plen(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in p.size() - 1:
		l += p[i].distance_to(p[i + 1])
	return l

## A fresh valley, past the storm, for the cases below.
func _fresh(w) -> void:
	w.new_game()
	Clock.running = false
	w.storm.skip()
	await _wait_bake(w)

# ---------------------------------------------------------------- locked regions
func _locked_cases(w) -> void:
	await _fresh(w)
	var fire: Vector3 = w.fire_position()
	var meadow := Vector3(-70, w.ground_y(-70, 2), 2)
	check(w.drop_reason(fire + Vector3(3, 0, 3)) == "", "people may be set down on the green")
	check(w.drop_reason(meadow) != "", "but not in the locked Western Meadow ('%s')" % w.drop_reason(meadow))
	check(w.drop_reason(Vector3(0, 0, 70)) != "", "nor over the southern ridge in the locked Valley Floor")
	# the hand refuses, keeps them, and says why
	var p: Person = w.spawn_person(fire + Vector3(2, 0, 2), "Dropme")
	var hand = w.hand
	hand.aim_override = p.global_position
	await get_tree().process_frame
	check(hand.try_lift(p), "the hand lifts someone")
	hand.aim_override = meadow
	hand.step_hover_now()
	check(hand.aim_drop_reason() == Drops.CANT_GET_BACK or hand.aim_drop_reason() == Drops.NOT_YET, "aiming at locked land shows the reason ('%s')" % hand.aim_drop_reason())
	check(hand.tooltip_text().contains(hand.aim_drop_reason()), "and the tooltip says it")
	hand.place_on_ground(meadow)
	check(hand.held.has(p), "the hand will not set them down there")
	hand.aim_override = fire + Vector3(4, 0, 4)
	hand.step_hover_now()
	hand.place_on_ground(hand.ground)
	check(not hand.held.has(p) and p.global_position.distance_to(fire + Vector3(4, 0, 4)) < 4.0, "it sets them down on open ground (held %s, %.1f m off, reason '%s')" % [hand.held.has(p), p.global_position.distance_to(fire + Vector3(4, 0, 4)), hand.aim_drop_reason()])
	hand.aim_override = Vector3.INF
	# the camera: may look a little past the edge, never deep into locked land
	check(w.regions.camera_ok(0, -5) and not w.regions.camera_ok(-100, 0), "the camera may roam the Clearing but not the locked meadow")
	var c: Vector3 = w.camera_clamp(Vector3(-30, 0, 0), Vector3(-90, 0, 0))
	check(c.x > -46.0 - Regions.CAMERA_MARGIN - 1.0, "a pan toward the meadow stops at its edge (x %.1f)" % c.x)
	var rig = w.camera_rig
	rig.snap_to(Vector3(0, 0, 0), 30.0)
	rig.target_focus = rig._clamp_focus(Vector3(-140, 0, 0), rig.target_focus)
	check(rig.target_focus.x > -62.0, "the camera rig clamps a drag past the locked meadow (x %.1f)" % rig.target_focus.x)
	Clock.set_speed(0)
	check(rig._paused(), "the camera knows the game is paused (no edge scrolling)")
	Clock.set_speed(1)
	# barriers: the gaps are closed shoulder to shoulder
	check(w.get_node_or_null("Props/GapShoulders") != null and w.get_node("Props/GapShoulders").get_child_count() >= 16, "rock and deadfall close both ends of each gap")
	# animals keep off cliffs
	var at := Vector3(0, w.ground_y(0, -27.5), -27.5)
	var up: Vector3 = w.animal_step(at, at + Vector3(0, 0, -1.5))
	check(w.ground_y(up.x, up.z) - at.y < 1.2, "a wolf cannot run up the cave cliff")
	var flat := Vector3(-5, w.ground_y(-5, 0), 0)
	check(w.animal_step(flat, flat + Vector3(1, 0, 0)).distance_to(flat + Vector3(1, 0, 0)) < 0.01, "but runs on level ground")
	# just after a load (or a region opening) the live mesh is the old one
	# until the new bake is in: land it doesn't cover yet is not refused on it
	check(w.drop_reason(Vector3(0, 0, 70)) != "", "the Valley Floor is shut")
	w.open_region(&"valley_floor")
	var rx := 60.0
	var river := Vector3(rx, 0, Valley.river_z(rx))
	check(not w.nav.synced() and w.drop_reason(Vector3(0, 0, 70)) == "", "while the new mesh bakes, newly opened land is not refused on the old one ('%s')" % w.drop_reason(Vector3(0, 0, 70)))
	check(not w.is_water(river) or w.drop_reason(river) != "", "but never into the river")
	await _wait_bake(w)

# ---------------------------------------------------------------- the Pass Road
func _pass_cases(w) -> void:
	w.open_region(&"valley_floor")
	await get_tree().process_frame
	await _wait_bake(w)
	var fire: Vector3 = w.fire_position()
	var flats := Vector3(-11, w.ground_y(-11, 76), 76)
	check(not w.pass_open() and w.nav.obstacles.has("pass_scree"), "the Pass Road starts choked with scree")
	check(w.ground_y(-7, 52) < w.ground_y(-20, 50) - 4.0, "the road cuts through the southern ridge")
	var before := _path(w, fire, flats)
	check(_path_ok(w, fire, flats), "the river flats are reachable the long way round")
	var gorge := Vector3(Valley.stream_x(50), 0, 50)
	var gq := NavigationServer3D.map_get_closest_point(w.get_world_3d().navigation_map, Vector3(gorge.x, w.ground_y(gorge.x, gorge.z), gorge.z))
	check(Vector2(gq.x - gorge.x, gq.z - gorge.z).length() > 2.0, "nobody wades the stream's gorge")
	check(w.open_pass(), "world.open_pass() opens the road")
	check(not w.open_pass(), "and only once")
	await _wait_bake(w)
	var after := _path(w, fire, flats)
	print("  pass path before %.0f m, after %.0f m" % [_plen(before), _plen(after)])
	check(_path_ok(w, fire, flats) and _plen(after) < _plen(before) * 0.75, "the Pass Road is the short way south (%.0f m vs %.0f m)" % [_plen(after), _plen(before)])
	var st: Dictionary = w.save_state()
	check(bool(st["pass"]["open"]), "the open pass is saved")

# ---------------------------------------------------------------- the far bank
func _crossing_cases(w) -> void:
	var bank := Vector3(170, 0, 152)
	bank.y = w.ground_y(bank.x, bank.z)
	Village.regions[&"east_bank"] = true      # as the footbridge's completion does, before the crossing exists
	w.regions.refresh_access()
	check(not w.drops.accessible(&"east_bank") and w.drop_reason(bank) != "", "the East Bank stays shut until there is a crossing")
	check(not w.regions.camera_ok(200, 180), "and the camera keeps to the near bank")
	w.add_crossing(&"east_footbridge")
	w.drops.allow_region(&"east_bank")
	await _wait_bake(w)
	check(w.has_crossing() and w.drops.accessible(&"east_bank"), "a crossing opens the far bank")
	var fb: Vector2 = LayoutEra2.FOOTBRIDGE
	check(w.ground_y(fb.x, fb.y) > Valley.river_level(fb.x) + 0.3, "the footbridge deck stands over the water")
	check(w.drop_reason(bank) == "", "people may be set down on the East Bank once they can walk back ('%s')" % w.drop_reason(bank))
	check(w.drop_reason(Vector3(fb.x + 12.0, 0, fb.y)) != "", "but never in the river")
	check(_path_ok(w, w.fire_position(), w.walkable_point(bank)), "a path runs from the fire over the footbridge")
	var st: Dictionary = w.save_state()
	check((st["drops"]["crossings"] as Array).has("east_footbridge"), "the crossing is saved")

# ---------------------------------------------------------------- desire paths
func _paths_cases(w) -> void:
	var paths: Paths = w.paths
	paths.clear()
	var a := Vector3(-20, 0, 20)
	check(paths.level_at(a.x, a.z) == 0 and is_equal_approx(paths.speed_mult(a), 1.0), "untrodden grass is just grass")
	for i in 600:
		var x := -20.0 + float(i % 30) * 0.5
		paths.step(Vector3(x, 0, 20.3 + (0.6 if i % 3 == 0 else 0.0)), 0.5, Vector3(1, 0, 0))
	check(paths.level_at(-15, 20.5) >= 1, "footsteps wear the grass (level %d, wear %.1f)" % [paths.level_at(-15, 20.5), paths.wear_at(-15, 20.5)])
	for i in 3000:
		paths.step(Vector3(-20.0 + float(i % 30) * 0.5, 0, 20.4), 0.5, Vector3(1, 0, 0))
	check(paths.level_at(-15, 20.5) == 3, "steady traffic beats a dirt road")
	check(paths.wear_at(-15, 22.5) < Paths.WORN, "and the road stays narrow (2 m off it: %.1f)" % paths.wear_at(-15, 22.5))
	var sm: float = paths.speed_mult(Vector3(-15, 0, 20.5))
	check(sm > 1.15 and sm <= 1.21, "people walk ~20%% faster on a road (x%.2f)" % sm)
	# the route-finder leans onto the road
	var raw := PackedVector3Array([Vector3(-24, w.ground_y(-24, 22.5), 22.5), Vector3(-2, w.ground_y(-2, 22.5), 22.5)])
	var bent: PackedVector3Array = paths.refine(raw)
	var on_road := 0
	for q in bent:
		if paths.level_at(q.x, q.z) >= 2:
			on_road += 1
	check(bent.size() > 2 and on_road >= 2, "refine() bends a path onto worn ground (%d of %d points)" % [on_road, bent.size()])
	# saved and loaded
	var d: Dictionary = paths.save_state()
	var before := paths.wear_at(-15, 20.5)
	paths.clear()
	paths.load_state(JSON.parse_string(JSON.stringify(d)))
	check(absf(paths.wear_at(-15, 20.5) - before) < 0.5, "the wear map survives save and load (%.1f vs %.1f)" % [paths.wear_at(-15, 20.5), before])
	# nothing wears under a building or field
	paths.block_rect(Vector3(-12, 0, 20.5), Vector2(4, 4))
	check(paths.wear_at(-12, 20.5) == 0.0, "a building's footprint clears the wear")
	paths.step(Vector3(-12, 0, 20.5), 5.0)
	check(paths.wear_at(-12, 20.5) == 0.0, "and nothing wears there")
	# the Era 3 hook
	var segs: Array = paths.busiest_segments(3)
	check(not segs.is_empty() and segs[0]["wear"] > 0.0 and segs[0].has("a") and segs[0].has("b"), "busiest_segments lists the busiest road stretches")
	var n: int = paths.pave(segs[0])
	check(n > 0 and paths.level_at(segs[0]["center"].x, segs[0]["center"].z) == 4 or paths.paved_count() >= n, "pave() lays a segment in stone (%d cells)" % n)
	# unused wear fades
	var w0 := paths.wear_at(-17, 20.5)
	paths.fade_all(2400.0)
	check(paths.wear_at(-17, 20.5) < w0 * 0.5 or paths.level_at(-17, 20.5) == 4, "unused paths fade slowly")
	paths.clear()

# ---------------------------------------------------------------- layout
func _layout_cases(w) -> void:
	var lots: Array = LayoutEra1.PLOT_SPOTS[&"hut"] + LayoutEra2.PLOT_SPOTS[&"cottage"]
	var worst := INF
	for i in lots.size():
		for j in range(i + 1, lots.size()):
			var a: Vector2 = lots[i]
			var b: Vector2 = lots[j]
			var gap := maxf(absf(a.x - b.x) - 7.0, absf(a.y - b.y) - 5.5)
			worst = minf(worst, gap)
	check(worst >= 4.0, "home lots leave at least 4 m between cottages (closest %.1f m)" % worst)
	var near_water := INF
	for l in lots:
		var p: Vector2 = l
		near_water = minf(near_water, absf(p.x - Valley.stream_x(p.y)) - 3.5)
		near_water = minf(near_water, absf(p.y - Valley.river_z(p.x)) - 2.75)
	check(near_water >= 6.0, "every home stands well back from the water (%.1f m)" % near_water)
	var green_clear := LayoutEra1.PLOT_SPOTS[&"hut"].all(func(l): return (l as Vector2).distance_to(Valley.FIRE) > 15.0)
	check(green_clear, "the green round the fire is left open")
	check(LayoutEra2.PLOT_SPOTS[&"cottage"].all(func(l): return w.region_at(Vector3(l.x, 0, l.y)) != &"clearing"), "new cottages grow outward into West End")
	var field: Vector2 = LayoutEra2.PLOT_SPOTS[&"field"][0]
	check(w.valley.flatness(field, Vector2(8, 6)) < 0.35, "fields sit on levelled ground (%.2f m across)" % w.valley.flatness(field, Vector2(8, 6)))
