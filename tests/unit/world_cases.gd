extends Node
## Cases for tests/unit/test_world.gd.

signal done(fails: int)

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _wait_bake(w) -> void:
	var t := 0
	while (w.nav.baking_now() or not w.nav.ready_for_paths()) and t < 600:
		await get_tree().process_frame
		t += 1

func _path(w, a: Vector3, b: Vector3) -> PackedVector3Array:
	var map: RID = w.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, a, b, true)

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
	for id in [&"gather_berries", &"fetch_water", &"collect_sticks", &"tend_fire", &"carry_log", &"haul_log", &"hunt"]:
		check(ids.has(id), "layout has %s" % id)
	var n_plots: int = w.ensure_plots_for_dream(&"shelter_of_our_own") + Village.sites.filter(func(s): return s.building != null and s.building.id == &"hut").size()
	check(n_plots >= 1, "a hut plot exists for the first dream")
	check(w.ensure_plots_for_dream(&"shrine_to_the_hand") == 1, "the shrine dream adds a shrine plot")
	check(w.ensure_plots_for_dream(&"shrine_to_the_hand") == 0, "and does not add it twice")
	var ever := Village.sites.filter(func(s): return s.has_meta("evergreen"))
	check(ever.size() == 3 and ever.all(func(s): return s.amount == -1 and not s.job.winter_stops), "3 evergreen bushes by the cave never run dry")
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
	w.queue_free()
	await get_tree().process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done.emit(fails)
