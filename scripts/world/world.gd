extends Node3D
## The valley: terrain, water, foliage, light, navmesh, regions and their
## blockers, the Clearing's fixed props, the threats, and the dynamic nodes
## (people and sites, under "Dynamic"). Spawns the camera rig, hand and HUD
## from the other workers' scenes when they exist. Owns save/load of dynamic
## nodes. Sets Game.world = self.

signal region_visual_opened(id: StringName)

const PERSON_SCENE := "res://scenes/people/person.tscn"
const SITE_SCENE := "res://scenes/sites/site.tscn"
const PERSON_SCRIPT := "res://scripts/person/person.gd"
const SITE_SCRIPT := "res://scripts/sites/site.gd"
const CAMERA_CANDIDATES := ["res://scenes/hand/camera_rig.tscn", "res://scenes/world/camera_rig.tscn", "res://scenes/camera/camera_rig.tscn", "res://scripts/world/camera_rig.gd"]
const HAND_CANDIDATES := ["res://scenes/hand/hand.tscn"]
const HUD_CANDIDATES := ["res://scenes/ui/hud.tscn"]
const TITLE_SCENE := "res://scenes/world/title.tscn"
const BOT_SCRIPT := "res://tests/bot/bot.gd"
const LOG_COUNT := 3
const LOG_WEIGHT := 4.0
const BRANCH_WEIGHT := 2.0
const GAP_CLEAR := 7.0            # a meadow log counts as moved once this far from the gap

var valley: Valley
var terrain: Terrain
var foliage: Foliage
var look: Look
var regions: Regions
var nav: Nav
var threats: Threats
var wolves: Wolves
var fire: FirePit
var storm: StormOpening
var dynamic: Node3D
var trunk: Blocker
var branch: Liftable
var logs: Array[Liftable] = []
var camera_rig: Node = null
var fallback_camera: Camera3D = null
var title_camera: Camera3D = null
var hand: Node = null
var hud: Node = null
var title: Node = null
var built: bool = false
var build_ms: int = 0
var opened_at: Dictionary = {}    # region id -> Clock.total_t when it opened

func _enter_tree() -> void:
	Game.world = self
	Look.register_globals()

func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null

func _ready() -> void:
	build()
	if Game.testing():
		new_game()
		Clock.running = true
		if ResourceLoader.exists(BOT_SCRIPT):
			var bot: Node = load(BOT_SCRIPT).new()
			bot.name = "Bot"
			add_child(bot)
	elif Game.flags.has("no-title"):
		new_game()
		Clock.running = true
	else:
		show_title()

# ================================================================ build

func build() -> void:
	if built:
		return
	var t0 := Time.get_ticks_msec()
	valley = Valley.new()
	valley.generate()
	look = Look.new()
	look.name = "Look"
	add_child(look)
	regions = Regions.new()
	add_child(regions)
	regions.setup(valley)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(valley)
	foliage = Foliage.new()
	add_child(foliage)
	foliage.build(valley, terrain, _keep_out_zones())
	_build_props()
	nav = Nav.new()
	add_child(nav)
	nav.setup(valley, foliage.tree_points)
	dynamic = Node3D.new()
	dynamic.name = "Dynamic"
	add_child(dynamic)
	threats = Threats.new()
	add_child(threats)
	wolves = threats.wolves
	storm = StormOpening.new()
	storm.name = "StormOpening"
	add_child(storm)
	_spawn_player_scenes()
	Events.region_opened.connect(_on_region_opened)
	Events.job_completed.connect(_on_job_completed)
	Events.building_finished.connect(_on_building_finished)
	built = true
	build_ms = Time.get_ticks_msec() - t0
	print("world: built in %d ms" % build_ms)

func _keep_out_zones() -> Array:
	var z: Array = [[Valley.FIRE, 8.0], [Valley.CAVE_MOUTH, 6.0], [Valley.EAST_GAP, 9.0], [Valley.WEST_GAP, 10.0]]
	for row in LayoutEra1.JOBS:
		z.append([Vector2(row[1], row[2]), 3.0])
	for row in LayoutEra1.PLOTS:
		z.append([Vector2(row[1], row[2]), 4.0])
	return z

func _v3(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, valley.ground_y(p.x, p.y) + lift, p.y)

func _build_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	# ---- the cave in the cliff
	var cave := Node3D.new()
	cave.name = "Cave"
	props.add_child(cave)
	cave.position = _v3(Valley.CAVE_MOUTH)
	var cv := Node3D.new()
	cv.name = "Visual"
	cave.add_child(cv)
	var rock := Color(0.4, 0.38, 0.36)
	Props.add_mesh(cv, Props.box(Vector3(6.0, 4.5, 0.6)), Color(0.04, 0.035, 0.035), Vector3(0, 2.0, -8.6))
	for sx in [-1.0, 1.0]:
		var pillar := Props.add_mesh(cv, Props.ball(2.0, 7), rock.darkened(0.1), Vector3(sx * 3.9, 2.0, -3.0))
		pillar.scale = Vector3(0.9, 1.6, 1.6)
	var lintel := Props.add_mesh(cv, Props.ball(2.4, 7), rock, Vector3(0, 6.6, -3.6))
	lintel.scale = Vector3(2.4, 0.8, 1.4)
	var roof := Props.add_mesh(cv, Props.box(Vector3(7.0, 1.2, 7.0)), rock.darkened(0.2), Vector3(0, 6.4, -6.5))
	roof.rotation.x = 0.05
	# ---- the fire pit
	fire = FirePit.new()
	props.add_child(fire)
	fire.position = _v3(Valley.FIRE)
	# ---- the firewood pile by the trees
	var wood := Node3D.new()
	wood.name = "Firewood"
	props.add_child(wood)
	wood.position = _v3(Vector2(-23.5, 6.5))
	var wv := Node3D.new()
	wv.name = "Visual"
	wood.add_child(wv)
	for i in 6:
		var lg := Props.add_mesh(wv, Props.cyl(0.12, 0.14, 1.6, 6), Color(0.42, 0.29, 0.17), Vector3((i % 3) * 0.3 - 0.3, 0.14 + (i / 3) * 0.24, 0))
		lg.rotation.x = PI * 0.5
	# ---- the fallen trunk to the Valley Floor
	trunk = Blocker.new()
	trunk.name = "FallenTrunk"
	trunk.region = &"valley_floor"
	props.add_child(trunk)
	trunk.build_trunk(15.0)
	trunk.position = _v3(Valley.EAST_GAP, -0.3)
	trunk.rotation.y = 0.12
	# ---- the fallen logs to the Western Meadow
	for i in LOG_COUNT:
		var lg := Liftable.new()
		lg.name = "MeadowLog%d" % (i + 1)
		lg.kind = &"meadow_log"
		lg.label = "Fallen log"
		lg.weight = LOG_WEIGHT
		lg.build_log_visual(6.5, 0.45, false)
		props.add_child(lg)
		lg.placed.connect(_on_log_placed)
		logs.append(lg)
	# ---- the storm branch across the cave mouth
	branch = Liftable.new()
	branch.name = "StormBranch"
	branch.kind = &"storm_branch"
	branch.label = "Fallen branch"
	branch.weight = BRANCH_WEIGHT
	branch.build_log_visual(5.0, 0.22, true)
	props.add_child(branch)
	# ---- landmark: a giant tree in the Western Meadow, seen from anywhere
	var giant := Node3D.new()
	giant.name = "GiantTree"
	props.add_child(giant)
	giant.position = _v3(Vector2(-132.0, -22.0), -0.5)
	var gv := MeshInstance3D.new()
	gv.name = "Visual"
	gv.mesh = Props.broadleaf_mesh()
	var gm := ShaderMaterial.new()
	gm.shader = load("res://scenes/world/shaders/foliage.gdshader")
	gv.material_override = gm
	gv.scale = Vector3.ONE * 4.5
	giant.add_child(gv)
	_reset_props()

## Puts the fixed props back to their new-game state.
func _reset_props() -> void:
	for i in logs.size():
		var lg := logs[i]
		var p := Valley.WEST_GAP + Vector2(0.0, (i - 1) * 2.6)
		lg.position = _v3(p, 0.0) + Vector3(0, i * 0.15, 0)
		lg.rotation = Vector3(0, PI * 0.5 + (i - 1) * 0.25, 0)
		lg.moved_count = 0
		lg.held = false
		nav_obstacle_for(lg, "meadow_log_%d" % i)
	branch.position = _v3(Valley.CAVE_MOUTH, 0.0)
	branch.rotation = Vector3(0, 0.08, 0)
	branch.moved_count = 0
	branch.held = false
	if nav:
		nav.set_box_obstacle("storm_branch", branch.position, Vector2(5.0, 1.0), branch.rotation.y)
	trunk.cleared = false
	trunk.visible = true
	trunk.scale = Vector3.ONE
	trunk.rotation = Vector3(0, 0.12, 0)
	trunk.position = _v3(Valley.EAST_GAP, -0.3)
	if trunk.get_node_or_null("Body") == null:
		pass    # body only matters for physics; navmesh uses the obstacle below
	if nav:
		nav.set_box_obstacle("trunk", trunk.position, Vector2(2.5, 15.0), trunk.rotation.y)
	fire.fuel = 0.0

func nav_obstacle_for(lg: Liftable, key: String) -> void:
	if nav:
		nav.set_box_obstacle(key, lg.position, Vector2(6.5, 1.2), lg.rotation.y + PI * 0.5)

func _spawn_player_scenes() -> void:
	camera_rig = _instance_first(CAMERA_CANDIDATES, "CameraRig")
	if camera_rig == null:
		fallback_camera = Camera3D.new()
		fallback_camera.name = "FallbackCamera"
		fallback_camera.fov = 45.0
		fallback_camera.far = 1500.0
		add_child(fallback_camera)
		frame_camera(fallback_camera, Vector3(0, 4, -8), 42.0, 0.0)
	hand = _instance_first(HAND_CANDIDATES, "Hand")
	hud = _instance_first(HUD_CANDIDATES, "HUD")
	title_camera = Camera3D.new()
	title_camera.name = "TitleCamera"
	title_camera.fov = 50.0
	title_camera.far = 1500.0
	add_child(title_camera)

func _instance_first(paths: Array, node_name: String) -> Node:
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		var n: Node = null
		if res is PackedScene:
			n = res.instantiate()
		elif res is Script and res.can_instantiate():
			n = res.new()
		if n != null:
			n.name = node_name
			add_child(n)
			return n
	return null

## Points a camera at `focus` from `dist` metres, pitched down ~50 degrees.
func frame_camera(cam: Camera3D, focus: Vector3, dist: float, yaw: float, pitch_deg: float = 52.0) -> void:
	var pitch := deg_to_rad(pitch_deg)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.global_position = focus + off
	cam.look_at(focus, Vector3.UP)

# ================================================================ title

func show_title() -> void:
	Clock.running = false
	# The valley behind the title is the current save's, else a fresh one.
	var latest := Save.latest_autosave()
	if latest == "" or not Save.load_slot(latest):
		new_game()
	if title == null and ResourceLoader.exists(TITLE_SCENE):
		title = load(TITLE_SCENE).instantiate()
		add_child(title)
	set_title_mode(true)

func set_title_mode(on: bool) -> void:
	if title_camera:
		title_camera.current = on
	if not on:
		_activate_play_camera()
	if camera_rig:
		camera_rig.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if hand:
		hand.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
		if hand is Node3D:
			hand.visible = not on
	if hud and "visible" in hud:
		hud.visible = not on

func _activate_play_camera() -> void:
	var cam: Camera3D = null
	if camera_rig is Camera3D:
		cam = camera_rig
	elif camera_rig != null:
		cam = camera_rig.find_children("*", "Camera3D", true, false).front() if not camera_rig.find_children("*", "Camera3D", true, false).is_empty() else null
	if cam == null:
		cam = fallback_camera
	if cam:
		cam.current = true

## Starts play from the title (New Valley or Continue/Load).
func start_play() -> void:
	set_title_mode(false)
	Clock.running = true

# ================================================================ API

## Ground height at x,z (terrain is a heightmap). People and the hand use this.
func ground_y(x: float, z: float) -> float:
	return valley.ground_y(x, z) if valley else 0.0

## Ground normal at x,z.
func ground_normal(x: float, z: float) -> Vector3:
	return valley.normal_at(x, z) if valley else Vector3.UP

## Point on the ground under the mouse, or Vector3.INF.
func mouse_ground() -> Vector3:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	if cam == null:
		return Vector3.INF
	var mp := vp.get_mouse_position()
	return ray_ground(cam.project_ray_origin(mp), cam.project_ray_normal(mp))

## Marches a ray against the heightmap; Vector3.INF if it misses.
func ray_ground(origin: Vector3, dir: Vector3, max_dist: float = 2500.0) -> Vector3:
	if valley == null or dir.length_squared() < 0.0001:
		return Vector3.INF
	dir = dir.normalized()
	var t := 0.0
	var prev_t := 0.0
	var p := origin
	var above := p.y - ground_y(p.x, p.z)
	if above < 0.0:
		return Vector3(p.x, ground_y(p.x, p.z), p.z)
	while t < max_dist:
		var step := clampf(above * 0.5, 0.5, 20.0)
		prev_t = t
		t += step
		p = origin + dir * t
		if absf(p.x) > Valley.HALF + 50.0 or absf(p.z) > Valley.HALF + 50.0:
			if dir.y >= 0.0:
				return Vector3.INF
		above = p.y - ground_y(p.x, p.z)
		if above <= 0.0:
			var lo := prev_t
			var hi := t
			for i in 12:
				var mid := (lo + hi) * 0.5
				var q := origin + dir * mid
				if q.y - ground_y(q.x, q.z) > 0.0:
					lo = mid
				else:
					hi = mid
			var hit := origin + dir * hi
			return Vector3(hit.x, ground_y(hit.x, hit.z), hit.z)
	return Vector3.INF

## Nearest Site within `r` of `p` matching `filter` (Callable(site)->bool), or null.
func site_near(p: Vector3, r: float, filter: Callable = Callable()) -> Site:
	var best: Site = null
	var best_d := r
	for s in Village.sites:
		if not is_instance_valid(s) or s.is_queued_for_deletion() or not (s is Node3D):
			continue
		var sp: Vector3 = s.global_position
		var d := Vector2(sp.x - p.x, sp.z - p.z).length()
		if d > best_d:
			continue
		if filter.is_valid() and not filter.call(s):
			continue
		best = s
		best_d = d
	return best

func spawn_person(at: Vector3, name_hint: String = "") -> Person:
	var p: Node = _new_from(PERSON_SCENE, PERSON_SCRIPT)
	if p == null:
		return null
	if name_hint != "" and "given_name" in p:
		p.given_name = name_hint
	if p is Node3D:
		p.position = Vector3(at.x, ground_y(at.x, at.z), at.z)
	dynamic.add_child(p)
	return p as Person

## A work Site for JobDef `job_id` at `at`, or null (with a warning) when the
## data has no such job. haul_trunk falls back to a code-made group JobDef.
func spawn_site(job_id: StringName, at: Vector3) -> Site:
	var j: JobDef = Defs.job(job_id)
	if j == null and job_id == &"haul_trunk":
		j = _placeholder_trunk_job()
	if j == null:
		LayoutEra1.warn_missing("job", job_id)
		return null
	var s: Node = _new_from(SITE_SCENE, SITE_SCRIPT)
	if s == null:
		return null
	s.job = j
	s.state = Site.State.JOB
	if s is Node3D:
		s.position = Vector3(at.x, ground_y(at.x, at.z), at.z)
	dynamic.add_child(s)
	return s as Site

## A build plot for BuildingDef `building_id` at `at`, or null.
func spawn_plot(building_id: StringName, at: Vector3) -> Site:
	var b: BuildingDef = Defs.building(building_id)
	if b == null:
		LayoutEra1.warn_missing("building", building_id)
		return null
	var s: Node = _new_from(SITE_SCENE, SITE_SCRIPT)
	if s == null:
		return null
	s.building = b
	s.job = null
	s.state = Site.State.PLOT
	if s is Node3D:
		s.position = Vector3(at.x, ground_y(at.x, at.z), at.z)
	dynamic.add_child(s)
	return s as Site

func _placeholder_trunk_job() -> JobDef:
	# Not in the data yet: a group job for three, BuildingDef-free.
	var j := JobDef.new()
	j.id = &"haul_trunk"
	j.title = "Haul the fallen trunk"
	j.kind = JobDef.Kind.GROUP
	j.skill = &"haul"
	j.min_people = 3
	j.max_people = 4
	j.work_time = 12.0
	j.node_amount = 1
	return j

func _new_from(scene_path: String, script_path: String) -> Node:
	if ResourceLoader.exists(scene_path):
		var ps = load(scene_path)
		if ps is PackedScene:
			return ps.instantiate()
	if ResourceLoader.exists(script_path):
		return load(script_path).new()
	return null

## The camera rig may roam this box; it grows with each open region.
func camera_bounds() -> AABB:
	return regions.camera_bounds() if regions else AABB(Vector3(-50, -5, -45), Vector3(100, 140, 90))

func is_region_open(id: StringName) -> bool:
	return Village.regions.has(Valley.canon(id))

func region_at(p: Vector3) -> StringName:
	return valley.region_at(p.x, p.z)

## Where people shelter from a storm (inside the cave).
func cave_position() -> Vector3:
	return _v3(Valley.CAVE)

func fire_position() -> Vector3:
	return fire.global_position if fire and fire.is_inside_tree() else _v3(Valley.FIRE)

## Wolves keep out of this radius around the fire (0 when it is out).
func fire_radius() -> float:
	return fire.radius() if fire else 0.0

func fire_lit() -> bool:
	return fire != null and fire.is_lit()

## Scares threats (wolves) near `at`. The hand calls this on a fast flick.
func scare_threats(at: Vector3, radius: float) -> int:
	return wolves.scare(at, radius) if wolves else 0

## Nearest point people can walk to (navmesh), or `p` before the first bake.
func walkable_point(p: Vector3) -> Vector3:
	return nav.closest(p) if nav else p

# ================================================================ regions

## Opens a region: removes its blocker, widens the camera bounds, lightens it
## over 2 s, and tells Village (which emits Events.region_opened).
func open_region(id: StringName) -> void:
	id = Valley.canon(id)
	if Valley.REGIONS.find(id) < 0:
		push_warning("world: unknown region %s" % id)
	Village.open_region(id)       # emits region_opened -> _on_region_opened
	_open_region_visual(id, false)

func _on_region_opened(id: StringName) -> void:
	var c := Valley.canon(id)
	if c != id and not Village.regions.has(c):
		Village.regions[c] = true
	_open_region_visual(c, false)

func _open_region_visual(id: StringName, instant: bool) -> void:
	if not opened_at.has(id):
		opened_at[id] = Clock.total_t
	if id == &"valley_floor" and not trunk.cleared:
		trunk.clear(instant)
		nav.remove_obstacle("trunk")
	if id == &"western_meadow":
		for i in logs.size():
			nav.remove_obstacle("meadow_log_%d" % i)
	if instant:
		return
	regions.lighten(id)
	nav.rebake()
	Audio.sfx("res://assets/audio/sfx/region_open.ogg")
	region_visual_opened.emit(id)

func _logs_clear() -> bool:
	for lg in logs:
		if lg.held:
			return false
		var p := Vector2(lg.global_position.x, lg.global_position.z)
		if p.distance_to(Valley.WEST_GAP) < GAP_CLEAR:
			return false
	return true

func _on_log_placed(_at: Vector3) -> void:
	if not is_region_open(&"western_meadow") and _logs_clear():
		open_region(&"western_meadow")

func _on_job_completed(site) -> void:
	if not is_instance_valid(site) or not ("job" in site) or site.job == null:
		return
	match site.job.id:
		&"haul_trunk":
			if not is_region_open(&"valley_floor"):
				open_region(&"valley_floor")
		&"haul_log_small":
			fire.add_fuel(1.0)      # the 2-carrier log lights the first fire
		&"tend_fire", &"gather_firewood":
			if site.job.id == &"tend_fire" or fire.is_lit():
				fire.add_fuel(0.35)

func _on_building_finished(site) -> void:
	if not is_instance_valid(site) or not (site is Node3D):
		return
	var size := Vector2(3, 3)
	if "building" in site and site.building != null:
		size = site.building.footprint
	nav.set_box_obstacle("bld_%d" % site.get_instance_id(), site.global_position, size * 0.9, site.global_rotation.y)
	nav.rebake()

## Safety net (section 8): the evergreen bushes by the cave never run dry.
func apply_safety_net() -> void:
	var cave := Vector2(Valley.CAVE_MOUTH.x, Valley.CAVE_MOUTH.y)
	for s in Village.sites:
		if not is_instance_valid(s) or not ("job" in s) or s.job == null or s.job.id != &"gather_berries":
			continue
		var sp: Vector3 = s.global_position
		if Vector2(sp.x, sp.z).distance_to(cave) > 14.0:
			continue
		if s.job.node_amount >= 0 or s.job.winter_stops:
			var j: JobDef = s.job.duplicate()
			j.node_amount = -1
			j.winter_stops = false
			s.job = j
		s.set_meta("evergreen", true)
		if "evergreen" in s:
			s.evergreen = true
		if s.has_method("set_evergreen"):
			s.set_evergreen(true)

# ================================================================ game state

## Clears the dynamic nodes (people, sites, anything persisted) right away.
func clear_dynamic() -> void:
	var doomed: Array = []
	for n in get_tree().get_nodes_in_group("persist"):
		if is_instance_valid(n) and is_ancestor_of(n):
			doomed.append(n)
	for c in dynamic.get_children():
		if not doomed.has(c):
			doomed.append(c)
	for n in doomed:
		if is_instance_valid(n) and n.get_parent():
			n.get_parent().remove_child(n)   # _exit_tree unregisters from Village now
			n.queue_free()
	if threats:
		threats.reset()

## A fresh valley: the storm-night opening of section 11.4.
func new_game() -> void:
	clear_dynamic()
	Clock.load_state({})
	Faith.load_state({})
	Village.load_state({"stats": {"births": 0, "deaths": 0, "joined": 0, "winters_survived": 0, "gifts": 0}})
	Clock.set_speed(1)
	opened_at = {&"clearing": 0.0}
	_reset_props()
	regions.sync_instant()
	var huddled := LayoutEra1.spawn(self)
	apply_safety_net()
	storm.begin(branch, huddled)
	look.update_now()
	nav.rebake()

func save_state() -> Dictionary:
	var lg: Array = []
	for l in logs:
		lg.append(l.save_state())
	return {
		"logs": lg,
		"branch": branch.save_state(),
		"trunk_cleared": trunk.cleared,
		"fire": fire.save_state(),
		"storm": storm.state,
		"weather": [look.rain_target, look.storm],
		"threats": threats.save_state(),
		"opened_at": opened_at.keys().map(func(k): return [str(k), opened_at[k]]),
	}

## Clears the dynamic nodes, restores the fixed props, then re-instances each
## saved node from its "scene" and calls load_state (sites first, so people
## can find their job site by uid).
func load_state(d: Dictionary, nodes: Array) -> void:
	clear_dynamic()
	_reset_props()
	var lg: Array = d.get("logs", [])
	for i in mini(lg.size(), logs.size()):
		logs[i].load_state(lg[i])
		nav_obstacle_for(logs[i], "meadow_log_%d" % i)
	branch.load_state(d.get("branch", {}))
	fire.load_state(d.get("fire", {}))
	opened_at.clear()
	for pair in d.get("opened_at", []):
		opened_at[StringName(pair[0])] = float(pair[1])
	for id in Village.regions.keys():
		_open_region_visual(Valley.canon(id), true)
	if d.get("trunk_cleared", false):
		trunk.clear(true)
		nav.remove_obstacle("trunk")
	regions.sync_instant()
	var w: Array = d.get("weather", [0.0, false])
	look.set_weather(float(w[0]) if w.size() > 0 else 0.0, bool(w[1]) if w.size() > 1 else false)
	Save.restore_nodes(dynamic, nodes)
	threats.load_state(d.get("threats", {}))
	apply_safety_net()
	var st := int(d.get("storm", StormOpening.S.DONE))
	if st == StormOpening.S.STORM and branch.global_position.distance_to(_v3(Valley.CAVE_MOUTH)) < StormOpening.CLEAR_DIST:
		var huddled := Village.alive().slice(0, 2)
		storm.begin(branch, huddled)
		Clock.load_state(Save.last_applied.get("clock", {}))   # begin() rewinds the clock
	else:
		storm.skip()
		nav.remove_obstacle("storm_branch")
	look.update_now()
	nav.rebake()
