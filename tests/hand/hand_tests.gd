extends Node
## The hand tests themselves; tests/hand/test_hand.gd runs them headless.

const MockPerson := preload("res://tests/hand/mock_person.gd")
const MockSite := preload("res://tests/hand/mock_site.gd")
const MockLiftable := preload("res://tests/hand/mock_liftable.gd")
const MockGift := preload("res://tests/hand/mock_gift.gd")
const MockWorld := preload("res://tests/hand/mock_world.gd")
const HandScene := preload("res://scenes/hand/hand.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")
const RigScene := preload("res://scenes/world/camera_rig.tscn")

var fails: int = 0
var passes: int = 0
var world: Node3D
var hand: Hand
var people: Array = []

var root: Node:
	get: return get_tree().root

func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)

func run() -> void:
	world = MockWorld.new()
	root.add_child(world)
	var rig: CameraRig = RigScene.instantiate()
	world.add_child(rig)
	rig.input_enabled = false
	rig.snap_to(Vector3.ZERO, 30.0)
	hand = HandScene.instantiate()
	hand.input_enabled = false
	world.add_child(hand)
	world.add_child(HudScene.instantiate())
	for i in 6:
		var p: Person = MockPerson.new()
		p.given_name = "P%d" % i
		world.add_child(p)
		p.global_position = Vector3(-6.0 + float(i) * 1.2, 0, 4.0)
		people.append(p)
	await get_tree().process_frame
	_add_powers()

	test_grip_limits()
	test_scoop()
	test_site_overflow()
	test_too_heavy()
	test_release_calls_on_placed()
	test_safe_drop()
	test_gesture_unlock()
	test_gift()
	test_hover_and_tooltip()
	test_input()
	test_camera()
	test_visual_placement()
	test_visual_pose_and_look()
	test_held_dangle()
	test_wave_back()
	await test_freed_hand_releases()
	await get_tree().process_frame

	print("%d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _add_powers() -> void:
	for spec in [[&"grip2", 2, 0.0, false], [&"grip3", 5, 0.0, false], [&"strength1", 0, 4.0, false],
			[&"warmth", 0, 0.0, true], [&"rain", 0, 0.0, true]]:
		var d := PowerDef.new()
		d.id = spec[0]
		d.title = String(spec[0]).capitalize()
		d.grip = spec[1]
		d.strength = spec[2]
		d.gesture = spec[3]
		Defs.powers[d.id] = d

func _reset() -> void:
	hand.release_all()
	hand.selected_power = &""
	hand.hint_t = 0.0
	hand.aim_override = Vector3(0, 0, 20)
	for i in people.size():
		var p: Person = people[i]
		if p.job_site != null:
			p.job_site.release(p)
			p.job_site = null
		p.global_position = Vector3(-6.0 + float(i) * 1.2, 0, 4.0)
		p.placed.clear()
	Faith.grip = 1
	Faith.strength = 2.0
	Faith.unlocked.clear()

func test_grip_limits() -> void:
	_reset()
	check(hand.try_lift(people[0]), "grip 1: lifts the first person")
	check(not hand.try_lift(people[1]), "grip 1: refuses a second person")
	check(hand.held.size() == 1, "grip 1: holds exactly one")
	Faith.grip = 2
	check(hand.try_lift(people[1]), "grip 2: shift-adds a second")
	check(not hand.try_lift(people[2]), "grip 2: refuses a third")
	check(not hand.try_lift(people[0]), "can't lift someone already held")

func test_scoop() -> void:
	_reset()
	check(not hand.can_scoop(), "scoop unavailable at grip 1")
	check(hand.scoop_lift(Vector3(-4.8, 0, 4), 3.0) == 0 and hand.held.is_empty(), "scoop at grip 1 lifts nobody")
	Faith.grip = 2
	check(hand.can_scoop(), "scoop available at grip 2")
	var lifted := [0]
	var cb := func(a: Array): lifted[0] += a.size()
	Events.hand_lifted.connect(cb)
	var n := hand.scoop_lift(Vector3(-4.8, 0, 4), 3.0)
	Events.hand_lifted.disconnect(cb)
	check(n == 2 and hand.held.size() == 2, "scoop at grip 2 lifts 2 of the people inside (got %d)" % n)
	check(lifted[0] == 2, "scoop emits hand_lifted with the scooped people")

func test_site_overflow() -> void:
	_reset()
	var s: Site = MockSite.new()
	world.add_child(s)
	s.global_position = Vector3(8, 0, -6)
	Faith.grip = 5
	for i in 5:
		hand.try_lift(people[i])
	check(hand.held.size() == 5, "grip 5 holds five")
	var spots := hand.site_spots(s, 3)
	var got: Array = []
	var cb := func(a: Array, t): got.append([a.size(), t])
	Events.hand_placed.connect(cb)
	var placed := hand.place_on_site(s)
	Events.hand_placed.disconnect(cb)
	check(placed == 3, "3-slot site with 5 held places 3 (placed %d)" % placed)
	check(hand.held.size() == 2, "the other 2 stay in the hand")
	check(s.workers.size() == 3, "site now has 3 workers")
	check(got.size() == 1 and got[0][0] == 3 and got[0][1] == s, "hand_placed emitted with the 3 and the site")
	var at_slots := true
	for i in 3:
		var p: Person = people[i]
		if p.placed.is_empty() or (p.placed[-1][0] as Vector3).distance_to(spots[i]) > 0.01 or p.placed[-1][1] != s:
			at_slots = false
	check(at_slots, "each placed person lands at its slot_position")
	check(hand.place_on_site(s) == 0 and hand.held.size() == 2, "a full site takes nobody")
	s.queue_free()

func test_too_heavy() -> void:
	_reset()
	var lg: Node3D = MockLiftable.new()
	lg.weight = 4.0
	world.add_child(lg)
	lg.global_position = Vector3(3, 0, 3)
	check(not hand.try_lift_object(lg), "weight 4 refused at strength 2")
	check(hand.held_object == null and lg.lifted == 0, "refused object is not lifted")
	check(hand.strain_t > 0.0 and hand.tooltip_text() == "Too heavy", "refusal shows strain and 'Too heavy'")
	hand.hint_t = 0.0
	Faith.strength = 4.0
	check(hand.try_lift_object(lg), "weight 4 lifted at strength 4")
	check(not hand.try_lift(people[0]), "can't lift people while holding an object")
	hand.place_on_ground(Vector3(5, 3, 5))
	check(hand.held_object == null and lg.placed_at.is_equal_approx(Vector3(5, 0, 5)), "object set down on the ground")
	lg.queue_free()

func test_release_calls_on_placed() -> void:
	_reset()
	Faith.grip = 3
	for i in 3:
		hand.try_lift(people[i])
	hand.place_on_ground(Vector3(2, 6, 2))
	var ok := true
	for i in 3:
		var p: Person = people[i]
		if p.placed.size() != 1 or p.placed[0][1] != null or absf((p.placed[0][0] as Vector3).y) > 0.001:
			ok = false
	check(ok and hand.held.is_empty(), "ground release calls on_placed for each, at ground height")
	hand.try_lift(people[3])
	hand.ground = Vector3(1, 0, 1)
	hand.place_idle()
	check(people[3].placed.size() == 1 and people[3].placed[0][1] == null, "right-click release calls on_placed(at, null)")
	hand.try_lift(people[4])
	hand.release_all()
	check(people[4].placed.size() == 1, "release_all calls on_placed")
	# idle ground avoids sites
	var s: Site = MockSite.new()
	world.add_child(s)
	s.global_position = Vector3(10, 0, 10)
	var p := hand.idle_ground(Vector3(10.2, 0, 10))
	check(Vector2(p.x - 10, p.z - 10).length() >= s.pick_radius(), "idle ground is pushed off the job")
	s.queue_free()

func test_safe_drop() -> void:
	_reset()
	var hz := Node3D.new()
	hz.add_to_group(&"hazard")
	world.add_child(hz)
	hz.global_position = Vector3(-10, 0, -10)
	hand.try_lift(people[0])
	hand.place_on_ground(Vector3(-10, 8, -10))
	var at: Vector3 = people[0].placed[0][0]
	check(Vector2(at.x + 10, at.z + 10).length() >= 2.0 and absf(at.y) < 0.001, "drop into a hazard is moved to safe ground")
	hz.queue_free()
	hand.try_lift(people[1])
	hand.place_on_ground(Vector3(500, 0, 0))
	check((people[1].placed[0][0] as Vector3).x <= 30.0, "drop is kept inside the world bounds")

func test_gesture_unlock() -> void:
	_reset()
	var emitted: Array = []
	var cb := func(id: StringName, at: Vector3): emitted.append(id)
	Events.hand_gesture.connect(cb)
	hand.aim_override = people[2].global_position
	hand.gesture_held = true
	for i in 25:
		hand.step(0.1)
	check(hand.hover_person == people[2], "hand hovers the person under it")
	check(emitted.is_empty(), "gesture does not emit while Warmth is locked")
	Faith.grant(&"warmth")
	for i in 25:
		hand.step(0.1)
	check(emitted.size() >= 3 and emitted.all(func(x): return x == &"warmth"), "unlocked Warmth emits repeatedly while held (%d)" % emitted.size())
	var n := emitted.size()
	hand.gesture_held = false
	for i in 10:
		hand.step(0.1)
	check(emitted.size() == n, "gesture stops when E is released")
	# non-gesture power is never emitted
	Faith.grant(&"strength1")
	hand.selected_power = &"strength1"
	check(not hand.is_gesture_unlocked(&"strength1"), "a non-gesture power is not a gesture")
	# rain only over a field
	Faith.grant(&"rain")
	hand.selected_power = &"rain"
	check(hand.gesture_power_for(&"person") == &"warmth", "over a person the person-gesture wins")
	check(hand.gesture_power_for(&"field") == &"rain", "over a field Rain is chosen")
	Events.hand_gesture.disconnect(cb)
	hand.gesture_held = false
	hand.step(0.1)

func test_gift() -> void:
	_reset()
	var g: Node3D = MockGift.new()
	world.add_child(g)
	var before := Faith.total
	check(hand.collect_gift(g), "a gift can be collected")
	check(is_equal_approx(Faith.total - before, 3.0), "gift adds its faith_value")
	check(g.is_queued_for_deletion(), "collected gift is removed")

func test_hover_and_tooltip() -> void:
	_reset()
	var s: Site = MockSite.new()
	world.add_child(s)
	s.global_position = Vector3(6, 0, -2)
	Faith.grip = 3
	hand.try_lift(people[0])
	hand.try_lift(people[1])
	hand.aim_override = s.global_position
	hand.step(0.1)
	check(hand.hover_site == s, "hovering a site while holding finds it")
	check(hand.tooltip_text() == "2 people · Haul log 0/3", "tooltip reads '2 people · Haul log 0/3' (got '%s')" % hand.tooltip_text())
	var vis: HandVisual = hand.get_node("Visual")
	var ghosts := vis.ghosts.filter(func(g): return g.visible).size()
	check(ghosts == 2, "two ghost previews over the site (got %d)" % ghosts)
	check(vis.pips.filter(func(q): return q.visible).size() == 3 and vis.badge.visible and vis.badge.text == "needs 3", "3 slot pips and a 'needs 3' badge")
	hand.release_all()
	s.queue_free()

func _mouse(button: int, pressed: bool, pos: Vector2, shift: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.shift_pressed = shift
	hand._unhandled_input(e)

func test_input() -> void:
	_reset()
	hand.input_enabled = true
	Faith.grip = 3
	# click a person: lift
	hand.aim_override = people[0].global_position
	_mouse(MOUSE_BUTTON_LEFT, true, Vector2(100, 100))
	_mouse(MOUSE_BUTTON_LEFT, false, Vector2(100, 100))
	check(hand.held == [people[0]], "left click lifts the person under the hand")
	# shift-click another: add
	hand.aim_override = people[1].global_position
	_mouse(MOUSE_BUTTON_LEFT, true, Vector2(100, 100), true)
	_mouse(MOUSE_BUTTON_LEFT, false, Vector2(100, 100), true)
	check(hand.held.size() == 2, "shift+click adds one more")
	# click empty ground: set down there
	hand.aim_override = Vector3(10, 0, -10)
	_mouse(MOUSE_BUTTON_LEFT, true, Vector2(300, 300))
	_mouse(MOUSE_BUTTON_LEFT, false, Vector2(300, 300))
	check(hand.held.is_empty() and people[0].placed.size() == 1, "clicking the ground sets them down")
	# drag on the ground: scoop
	for i in 3:
		people[i].global_position = Vector3(-10.0 + float(i) * 0.8, 0, -10)
	hand.aim_override = Vector3(-9.2, 0, -10)
	_mouse(MOUSE_BUTTON_LEFT, true, Vector2(400, 400))
	hand.aim_override = Vector3(-9.2, 0, -12.5)
	hand.step_hover_now()
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(400, 460)
	hand._unhandled_input(mm)
	check(hand.scooping and hand.scoop_radius > 2.0, "left-drag on the ground draws a scoop circle")
	for k in 4:
		hand.aim_override = Vector3(-9.2 + float(k), 0, -12.5)
		hand.step(0.05)
	var vis: HandVisual = hand.get_node("Visual")
	check((vis.trail.mesh as ImmediateMesh).get_surface_count() > 0 and vis.scoop_ring.visible, "the scoop draws its circle and a sweep trail")
	_mouse(MOUSE_BUTTON_LEFT, false, Vector2(400, 460))
	check(hand.held.size() == 3 and not hand.scooping, "releasing the scoop lifts everyone inside up to the grip")
	# right click: idle ground
	_mouse(MOUSE_BUTTON_RIGHT, true, Vector2(400, 460))
	check(hand.held.is_empty(), "right click sets them down")
	hand.input_enabled = false

func test_camera() -> void:
	var rig: CameraRig = get_tree().get_first_node_in_group(&"camera_rig")
	rig.dist = rig.min_dist
	var close := rig.pitch()
	rig.dist = rig.max_dist
	var far := rig.pitch()
	check(far > close, "camera pitch eases higher as it zooms out")
	rig.focus_on(Vector3(500, 0, -500))
	check(rig.target_focus.x <= 30.0 and rig.target_focus.z >= -30.0, "camera focus is clamped to camera_bounds()")
	for i in 60:
		rig.step(0.05)
	check(rig.camera.global_position.is_finite() and rig.focus.distance_to(rig.target_focus) < 0.5, "camera glides to its target")

func _steps(n: int, dt: float = 0.1) -> void:
	for i in n:
		hand.step(dt)

func test_visual_placement() -> void:
	_reset()
	var rig: CameraRig = get_tree().get_first_node_in_group(&"camera_rig")
	rig.snap_to(Vector3.ZERO, 28.0)
	hand.aim_override = Vector3(3, 0, -2)
	_steps(30)
	var cam := get_viewport().get_camera_3d()
	var a := cam.unproject_position(hand.air_pos)
	var g := cam.unproject_position(hand.ground)
	check(a.distance_to(g) < 2.0, "the hand's anchor is drawn exactly over the cursor (%.1f px)" % a.distance_to(g))
	check(absf(hand.air_pos.y - Hand.HOVER_H) < 0.4, "empty, the anchor floats at HOVER_H (%.2f)" % hand.air_pos.y)
	check(hand.global_position.distance_to(hand.ground) < 0.01, "the Hand node follows the aimed ground point (people react to it)")
	var vis: HandVisual = hand.get_node("Visual")
	var wrist := cam.unproject_position(vis.model.global_transform * Vector3.ZERO)
	check(wrist.y < a.y - 20.0, "the wrist trails up and away from the cursor, beside the target")
	var vh := 2.0 * tan(deg_to_rad(cam.fov) * 0.5) * cam.global_position.distance_to(hand.air_pos)
	check(vis.hand_len / vh > 0.2 and vis.hand_len / vh < 0.4, "the hand is about a third of the screen tall (%.2f)" % (vis.hand_len / vh))
	check(vis.model.cuff != null and vis.model.glove.mesh.get_surface_count() == 2, "the glove has its stitches and a cap closing the cuff")

func test_visual_pose_and_look() -> void:
	_reset()
	var vis: HandVisual = hand.get_node("Visual")
	hand.aim_override = Vector3(10, 0, -10)
	_steps(30)
	check(vis.solidity < 0.05 and not vis.model.solid, "empty: the glove is a ghost")
	check(vis.curl[1] < 0.0 and vis.curl[2] < 0.0, "empty: fingers relaxed open")
	Faith.grip = 5
	hand.try_lift(people[0])
	_steps(30)
	var closed := 0
	for i in 5:
		if vis.curl[i] > 0.7:
			closed += 1
	check(closed == 1, "holding 1 of 5: one finger curls (got %d)" % closed)
	check(vis.solidity > 0.99 and vis.model.solid, "holding: the glove is solid")
	for i in range(1, 5):
		hand.try_lift(people[i])
	_steps(30)
	check(vis.curl[0] > 0.9 and vis.curl[4] > 0.9 and vis.cup > 0.9, "full grip: a fist")
	hand.release_all()

func test_held_dangle() -> void:
	_reset()
	Faith.grip = 3
	hand.aim_override = people[0].global_position
	_steps(10)
	var start: Vector3 = people[0].global_position
	hand.try_lift(people[0])
	hand.step(0.05)
	var target := hand.hold_point()
	check(people[0].global_position.distance_to(target) > 0.3, "a lifted person rises into the hand instead of snapping")
	_steps(20)
	var p: Vector3 = people[0].global_position
	check(absf(p.y - (hand.air_pos.y - Hand.HOLD_DEPTH)) < 0.25, "held people dangle just below the cupped palm")
	check(absf(people[0].rotation.x) > 0.0 or absf(people[0].rotation.z) > 0.0, "held people sway")
	hand.place_on_ground(start)
	check(people[0].rotation.x == 0.0 and people[0].rotation.z == 0.0, "setting down straightens them")

func test_wave_back() -> void:
	_reset()
	var vis: HandVisual = hand.get_node("Visual")
	var p: Person = people[2]
	var old := p.trust
	p.trust = 4
	hand.aim_override = p.global_position
	_steps(5, 0.1)
	check(vis.waving <= 0.0, "no wave at first glance")
	_steps(6, 0.1)
	check(hand.hover_person == p and vis.waving > 0.0, "lingering over a friend waves back")
	p.trust = old
	_steps(25)

func test_freed_hand_releases() -> void:
	_reset()
	hand.try_lift(people[5])
	hand.queue_free()
	await get_tree().process_frame
	check(people[5].placed.size() == 1, "freeing the hand still sets its people down")
