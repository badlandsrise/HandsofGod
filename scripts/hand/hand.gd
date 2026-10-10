class_name Hand extends Node3D
## The player's only verb: lift and place. Reads Faith.grip and Faith.strength,
## emits Events.hand_* signals, and talks to people and sites only through the
## [hand] functions of the Person and Site contracts.
##
## Everything runs on Clock.real_delta, so the hand works while paused and at 3x.
## All visuals live under the child "Visual" (scripts/hand/hand_visual.gd); a
## replacement Visual only needs `sync(hand, dt)` and may add `strain()`,
## `sparkle(at)` and `dip()`.
##
## The hand can never harm: every release goes through Person.on_placed at a
## safe ground point (snapped to the ground, pushed out of hazards).
## Liftable world objects (logs, boulders, buildings) implement:
##   func lift_weight() -> float ; func on_lifted() ; func on_placed(at: Vector3)
## and are in group "liftable". Gifts are in group "gift" with `faith_value`.

signal hover_changed(target: Node3D)
signal hint_shown(text: String)

const SFX := "res://assets/audio/sfx/%s.ogg"
# Heights of the hand's anchor (fingertips when empty, the cupped palm when
# holding) above the ground. The anchor rides the camera ray through the aimed
# ground point, so on screen it always sits exactly on the cursor. It floats
# high and out of the way when empty, leans in over what it can lift, and lowers
# gently to set people down.
const HOVER_H := 6.0            # empty
const HOVER_H_NEAR := 3.2       # leaning in over something liftable (fingertips at head height)
const HOVER_H_HOLD := 3.7       # carrying: held people dangle with their feet clear
const SCOOP_H := 2.2            # sweeping low across the ground
const HOLD_DEPTH := 1.8         # anchor to feet of a held person (an adult is 1.7)
const PLACE_DIP := 1.3          # how far the hand lowers when it sets down
const LIFT_EASE := 0.28         # seconds for a lifted person to rise into the hand
const PICK_PX := 46.0           # forgiving screen-space pick radius at the reference distance
const PICK_REF_DIST := 30.0
const SCOOP_DRAG_PX := 14.0
const GESTURE_CHARGE := 0.6     # seconds of holding E before the first pulse
const GESTURE_INTERVAL := 0.5   # seconds between pulses while held
const HEAVY_WEIGHT := 4.0
## Which gesture powers fit what is under the hand, in order of preference.
const GESTURE_TARGETS := {
	&"person": [&"warmth", &"blessing"],
	&"fire": [&"warmth", &"blessing"],
	&"field": [&"rain"],
	&"burning": [&"rain"],
	&"sea": [&"calm_waters"],
	&"sky": [&"guiding_light", &"part_the_clouds"],
}

var held: Array = []                    # Person nodes
var held_object: Node3D = null          # a liftable (log, boulder, building) when not holding people

## When not INF the hand aims here instead of at the mouse (tests, screenshots, cutscenes).
var aim_override: Vector3 = Vector3.INF
## Off for tests and cutscenes: the hand ignores mouse and keys.
var input_enabled: bool = true
## The last power button the player selected (HUD sets it).
var selected_power: StringName = &""

var ground: Vector3 = Vector3.ZERO      # the ground point the hand aims at
var air_pos: Vector3 = Vector3(0, HOVER_H, 0)
var mouse_on_ground: bool = true
var hover_person: Person = null
var hover_site: Site = null
var hover_thing: Node3D = null          # a gift or a liftable

var scooping: bool = false
var scoop_center: Vector3 = Vector3.ZERO
var scoop_radius: float = 0.0

var gesture_held: bool = false
var gesture_power: StringName = &""
var gesture_charge: float = 0.0         # seconds charged
var gesture_at: Vector3 = Vector3.INF

var hint: String = ""
var hint_t: float = 0.0
var strain_t: float = 0.0
var dip_t: float = 0.0
var time: float = 0.0

var _press_active: bool = false
var _press_screen: Vector2 = Vector2.ZERO
var _press_ground: Vector3 = Vector3.ZERO
var _press_shift: bool = false
var _gesture_cd: float = 0.0
var _scoop_hint_done: bool = false
var _last_hover: Node3D = null
var _rise: Dictionary = {}              # Person -> [start position, t]
var _cursor_hidden: bool = false

func is_holding() -> bool: return not held.is_empty() or held_object != null

func _ready() -> void:
	add_to_group(&"hand")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.power_unlocked.connect(_on_power_unlocked)

func _exit_tree() -> void:
	release_all()
	_set_cursor_hidden(false)

func _process(_delta: float) -> void:
	step(Clock.real_delta)

# ---------------------------------------------------------------- limits

func grip() -> int:
	return maxi(Faith.grip, 1)

func free_grip() -> int:
	return maxi(grip() - held.size(), 0) if held_object == null else 0

func can_scoop() -> bool:
	return Faith.grip > 1 and held_object == null

func scoop_max_radius() -> float:
	return clampf(2.5 + 1.2 * float(grip()), 3.0, 14.0)

func can_lift(p: Person) -> bool:
	if not is_instance_valid(p) or p.is_queued_for_deletion():
		return false
	if held_object != null or held.has(p) or held.size() >= grip():
		return false
	return p.pickable() and p.weight() <= Faith.strength

# ---------------------------------------------------------------- lifting

## Lift one person. Returns true if they are now in the hand.
func try_lift(p: Person) -> bool:
	if not can_lift(p):
		if is_instance_valid(p) and held.size() >= grip() and not held.has(p):
			show_hint("Hand is full (%d)" % grip())
		return false
	_take(p)
	Events.hand_lifted.emit([p])
	_sfx(&"lift", 1.0 + 0.1 * float(held.size() - 1))
	_lift_fx([p])
	return true

## Lift several at once (scoop). Returns who was lifted.
func lift_many(people: Array) -> Array:
	var got: Array = []
	for p in people:
		if p is Person and can_lift(p):
			_take(p)
			got.append(p)
	if not got.is_empty():
		Events.hand_lifted.emit(got)
		_sfx(&"scoop", 1.0 + 0.05 * float(got.size()))
		_lift_fx(got)
	return got

func _take(p: Person) -> void:
	held.append(p)
	_rise[p] = [p.global_position, 0.0]
	p.on_lifted()

func _lift_fx(people: Array) -> void:
	var pts: Array = []
	for p in people:
		if is_instance_valid(p):
			pts.append(_on_ground((p as Node3D).global_position))
	var vis := _visual()
	if vis and vis.has_method(&"lifted"):
		vis.lifted(pts)

## Scoop everyone within `radius` of `center`, nearest first, up to the free grip.
## Needs Grip II. Returns the number lifted.
func scoop_lift(center: Vector3, radius: float) -> int:
	if not can_scoop():
		return 0
	var r := minf(radius, scoop_max_radius())
	var inside: Array = people_in_circle(center, r)
	inside.sort_custom(func(a, b): return _flat_dist(a.global_position, center) < _flat_dist(b.global_position, center))
	return lift_many(inside.slice(0, free_grip())).size()

func people_in_circle(center: Vector3, radius: float) -> Array:
	var out: Array = []
	for p in Village.people:
		if p is Person and is_instance_valid(p) and not held.has(p) and p.pickable():
			if _flat_dist(p.global_position, center) <= radius:
				out.append(p)
	return out

## Lift a world object (log, boulder, building). Refused, with a strain wobble,
## if it's heavier than Faith.strength.
func try_lift_object(o: Node3D) -> bool:
	if not is_instance_valid(o) or not o.is_in_group(&"liftable") or not held.is_empty() or held_object != null:
		return false
	var w: float = o.lift_weight() if o.has_method(&"lift_weight") else 1.0
	if w > Faith.strength:
		strain()
		show_hint("Too heavy")
		_sfx(&"too_heavy")
		return false
	held_object = o
	if o.has_method(&"on_lifted"):
		o.on_lifted()
	Events.hand_lifted_object.emit(o)
	_sfx(&"heavy" if w >= HEAVY_WEIGHT else &"lift", 0.8)
	return true

## Click a gift: faith, a sparkle and a chime.
func collect_gift(g: Node3D) -> bool:
	if not is_instance_valid(g) or not g.is_in_group(&"gift") or g.is_queued_for_deletion():
		return false
	var v: float = float(g.get(&"faith_value")) if &"faith_value" in g else 3.0
	var at := g.global_position
	Faith.add(v, at)
	var gp = g.get(&"grants_power") if &"grants_power" in g else &""
	if gp != null and StringName(str(gp)) != &"":
		Faith.grant(StringName(str(gp)))
	Village.stats["gifts"] = int(Village.stats.get("gifts", 0)) + 1
	var vis := _visual()
	if vis and vis.has_method(&"sparkle"):
		vis.sparkle(at)
	_sfx(&"gift")
	show_hint("+%d faith" % int(round(v)))
	if g.has_method(&"collect"):
		g.collect()
	else:
		g.queue_free()
	return true

# ---------------------------------------------------------------- placing

## Place as many held people as `s` can take, each at its slot; the rest stay
## in the hand. Returns how many were placed.
func place_on_site(s: Site) -> int:
	_prune_held()
	if held.is_empty() or not is_instance_valid(s):
		return 0
	var n := mini(held.size(), s.free_slots())
	while n > 0 and not s.can_accept(n):
		n -= 1
	if n <= 0:
		show_hint("No room here")
		return 0
	var spots := site_spots(s, n)
	var placed: Array = held.slice(0, n)
	held = held.slice(n)
	for i in n:
		_release_person(placed[i], spots[i], s)
	Events.hand_placed.emit(placed, s)
	_after_place(spots)
	return n

## Where the next `n` people placed on `s` would land (also used for the ghosts).
## slot_position is indexed from the site's current fill.
func site_spots(s: Site, n: int) -> Array:
	var out: Array = []
	var base := site_filled(s)
	for i in n:
		out.append(s.slot_position(base + i))
	return out

## Set everyone in the hand down around `at`, with no job.
func place_on_ground(at: Vector3) -> void:
	_prune_held()
	if held_object != null:
		place_object(at)
		return
	if held.is_empty():
		return
	var placed: Array = held.duplicate()
	held.clear()
	var spots := ground_spots(at, placed.size())
	for i in placed.size():
		_release_person(placed[i], spots[i], null)
	Events.hand_placed.emit(placed, null)
	_after_place(spots)

## Right click: set down on the nearest idle ground (not on top of a job).
func place_idle() -> void:
	place_on_ground(idle_ground(ground))

func place_object(at: Vector3) -> void:
	var o := held_object
	held_object = null
	if not is_instance_valid(o):
		return
	var spot := safe_point(at)
	if o.has_method(&"on_placed"):
		o.on_placed(spot)
	else:
		o.global_position = spot
	Events.hand_placed_object.emit(o, spot)
	_sfx(&"heavy", 0.9)
	_after_place([spot])

## Put down everything, safely, right below the hand. Used when the hand is
## freed or disabled, so a release always reaches on_placed.
func release_all() -> void:
	if held_object != null:
		place_object(ground)
	if not held.is_empty():
		place_on_ground(ground)

func _release_person(p: Person, at: Vector3, s: Site) -> void:
	if not is_instance_valid(p):
		return
	var spot := safe_point(at) if s == null else _on_ground(at)
	_rise.erase(p)
	p.rotation.x = 0.0
	p.rotation.z = 0.0
	p.on_placed(spot, s if is_instance_valid(s) else null)

func _after_place(spots: Array = []) -> void:
	dip_t = 0.35
	var vis := _visual()
	if vis and vis.has_method(&"dip"):
		vis.dip()
	if vis and vis.has_method(&"placed"):
		var pts: Array = []
		for p in spots:
			if p is Vector3:
				pts.append(_on_ground(p))
		vis.placed(pts)
	_sfx(&"place")

## Little circle of drop spots so people don't land on each other.
func ground_spots(at: Vector3, n: int) -> Array:
	var out: Array = []
	if n == 1:
		out.append(at)
		return out
	var ring := 0
	while out.size() < n:
		var count := 1 if ring == 0 else ring * 6
		var r := 0.75 * float(ring)
		for k in count:
			if out.size() >= n:
				break
			var a := TAU * float(k) / float(count) + 0.4 * float(ring)
			out.append(at + Vector3(cos(a), 0, sin(a)) * r)
		ring += 1
	return out

## The nearest point to `at` that is not inside a site, so idle people don't stand on jobs.
func idle_ground(at: Vector3) -> Vector3:
	var p := at
	for _i in 3:
		var s := _world_site_near(p, 4.0)
		if s == null:
			break
		var r := s.pick_radius() + 1.2
		var d := Vector3(p.x - s.global_position.x, 0, p.z - s.global_position.z)
		if d.length() >= r:
			break
		if d.length() < 0.05:
			d = Vector3(1, 0, 0)
		p = s.global_position + d.normalized() * r
	return p

## Snap to the ground, push out of anything in group "hazard" (hazard_radius()),
## and keep inside the world bounds. The hand can never set someone down in danger.
func safe_point(at: Vector3) -> Vector3:
	var p := at
	if not p.is_finite():
		p = ground if ground.is_finite() else Vector3.ZERO
	for _i in 3:
		var moved := false
		for h in get_tree().get_nodes_in_group(&"hazard"):
			if not (h is Node3D) or not is_instance_valid(h):
				continue
			var hr: float = h.hazard_radius() if h.has_method(&"hazard_radius") else 2.0
			var d := Vector3(p.x - h.global_position.x, 0, p.z - h.global_position.z)
			if d.length() < hr + 0.5:
				if d.length() < 0.05:
					d = Vector3(1, 0, 0)
				p = h.global_position + d.normalized() * (hr + 0.8)
				moved = true
		if not moved:
			break
	var w := Game.world
	if w != null and w.has_method(&"camera_bounds"):
		var b: AABB = w.camera_bounds()
		p.x = clampf(p.x, b.position.x, b.end.x)
		p.z = clampf(p.z, b.position.z, b.end.z)
	return _on_ground(p)

func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _ground_y(p.x, p.z), p.z)

# ---------------------------------------------------------------- gestures

func is_gesture_unlocked(id: StringName) -> bool:
	if id == &"" or not Faith.has(id):
		return false
	var d := Defs.power(id)
	return d != null and d.gesture

## {kind, at}: what the hand is over, for picking a gesture power.
func gesture_target() -> Dictionary:
	if is_instance_valid(hover_person):
		return {"kind": &"person", "at": hover_person.global_position}
	if not mouse_on_ground:
		return {"kind": &"sky", "at": air_pos}
	for kind in [&"burning", &"fire", &"field", &"sea"]:
		var n := _group_near(kind, ground)
		if n != null:
			return {"kind": kind, "at": n.global_position}
	if is_instance_valid(hover_site) and hover_site.job != null:
		var jid := String(hover_site.job.id)
		if jid.contains("fire"):
			return {"kind": &"fire", "at": hover_site.global_position}
		if jid.contains("field") or jid.contains("farm") or jid.contains("crop"):
			return {"kind": &"field", "at": hover_site.global_position}
	var w := Game.world
	if w != null and w.has_method(&"is_water") and w.is_water(ground):
		return {"kind": &"sea", "at": ground}
	return {"kind": &"sky", "at": ground}

## The unlocked gesture power for a target kind, preferring the selected power.
func gesture_power_for(kind: StringName) -> StringName:
	var cands: Array = GESTURE_TARGETS.get(kind, [])
	if selected_power in cands and is_gesture_unlocked(selected_power):
		return selected_power
	for id in cands:
		if is_gesture_unlocked(id):
			return id
	if is_gesture_unlocked(selected_power):
		return selected_power
	return &""

## Called each frame with whether E is held. Charges, then emits
## Events.hand_gesture repeatedly while held.
func update_gesture(active: bool, dt: float) -> void:
	if not active:
		gesture_charge = maxf(gesture_charge - dt * 3.0, 0.0)
		if gesture_charge <= 0.0:
			gesture_power = &""
		_gesture_cd = 0.0
		return
	var t := gesture_target()
	var id := gesture_power_for(t["kind"])
	if id == &"":
		gesture_charge = maxf(gesture_charge - dt * 3.0, 0.0)
		gesture_power = &""
		if hint_t <= 0.0:
			show_hint("Nothing to do here")
		return
	if id != gesture_power:
		gesture_power = id
		gesture_charge = 0.0
		_gesture_cd = 0.0
	gesture_at = t["at"]
	gesture_charge += dt
	if gesture_charge >= GESTURE_CHARGE:
		_gesture_cd -= dt
		if _gesture_cd <= 0.0:
			_gesture_cd = GESTURE_INTERVAL
			Events.hand_gesture.emit(id, gesture_at)

func gesture_level() -> float:
	return clampf(gesture_charge / GESTURE_CHARGE, 0.0, 1.0)

# ---------------------------------------------------------------- frame

var _hover_t: float = 0.0

func step(dt: float) -> void:
	time += dt
	hint_t = maxf(hint_t - dt, 0.0)
	strain_t = maxf(strain_t - dt, 0.0)
	dip_t = maxf(dip_t - dt, 0.0)
	_update_aim()
	# what is under the hand, 30 times a second (a town is a lot to look through)
	_hover_t -= dt
	if _hover_t <= 0.0:
		_hover_t = 1.0 / 30.0
		_update_hover()
	if input_enabled:
		gesture_held = Input.is_action_pressed(&"hand_gesture") and not _ui_has_focus()
	update_gesture(gesture_held, dt)
	_prune_held()
	_update_air(dt)
	_follow_held(dt)
	if ground.is_finite():
		global_position = ground      # people react to where the hand points
	_update_cursor()
	var vis := _visual()
	if vis and vis.has_method(&"sync"):
		vis.sync(self, dt)

func _update_aim() -> void:
	if aim_override.is_finite():
		ground = aim_override
		mouse_on_ground = true
		return
	var g := Vector3.INF
	var w := Game.world
	if w != null and w.has_method(&"mouse_ground"):
		g = w.mouse_ground()
	if not g.is_finite():
		g = _plane_ground()
	mouse_on_ground = g.is_finite()
	if mouse_on_ground:
		ground = g

func _plane_ground() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return Vector3.INF
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	var t := -o.y / d.y
	return o + d * t if t > 0.0 else Vector3.INF

## Screen position the hand points at.
func aim_screen() -> Vector2:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if aim_override.is_finite() or not input_enabled:
		if cam and not cam.is_position_behind(ground):
			return cam.unproject_position(ground)
	return get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO

func _update_hover() -> void:
	hover_person = null
	hover_thing = null
	hover_site = null
	if scooping:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and held_object == null:
		var cands: Array = []
		for p in Village.people:
			if p is Person and is_instance_valid(p) and not held.has(p) and p.pickable():
				cands.append(p)
		hover_person = _screen_pick(cam, cands, 0.9, PICK_PX) as Person
	if cam != null and held.is_empty() and held_object == null:
		var things: Array = get_tree().get_nodes_in_group(&"gift")
		things.append_array(get_tree().get_nodes_in_group(&"liftable"))
		hover_thing = _screen_pick(cam, things, 0.5, PICK_PX * 1.2)
	hover_site = _site_at(ground, cam)
	var now: Node3D = primary_target()
	if now != _last_hover:
		_last_hover = now
		hover_changed.emit(now)

## What a left click would act on now.
func primary_target() -> Node3D:
	if held.is_empty() and held_object == null:
		if hover_person: return hover_person
		if hover_thing: return hover_thing
		return hover_site
	if held_object != null:
		return null
	if is_instance_valid(hover_site) and hover_site.can_accept(1):
		return hover_site
	return hover_person

func _screen_pick(cam: Camera3D, nodes: Array, lift: float, px: float) -> Node3D:
	var mp := aim_screen()
	var best: Node3D = null
	var dist := maxf(cam.global_position.distance_to(ground), 1.0)
	var bd := px * clampf(PICK_REF_DIST / dist, 0.5, 2.0)
	for n in nodes:
		var nd := n as Node3D
		if nd == null or not is_instance_valid(nd) or not nd.is_visible_in_tree() or nd.is_queued_for_deletion():
			continue
		var wp := nd.global_position + Vector3(0, lift, 0)
		if cam.is_position_behind(wp):
			continue
		var d := cam.unproject_position(wp).distance_to(mp)
		if d < bd:
			bd = d
			best = nd
	return best

func _site_at(p: Vector3, cam: Camera3D) -> Site:
	var best: Site = null
	var bd := INF
	for s in Village.sites:
		if not (s is Site) or not is_instance_valid(s) or not s.is_visible_in_tree() or s.hand_ignores():
			continue
		var d := _flat_dist(s.global_position, p)
		if d <= s.pick_radius() + 0.4 and d < bd:
			bd = d
			best = s
	if best == null and cam != null:
		# forgiving screen-space fallback for small or distant sites
		var mp := aim_screen()
		var bpx := PICK_PX * 1.3
		for s in Village.sites:
			if not (s is Site) or not is_instance_valid(s) or not s.is_visible_in_tree() or s.hand_ignores():
				continue
			if cam.is_position_behind(s.global_position):
				continue
			var dpx := cam.unproject_position(s.global_position).distance_to(mp)
			if dpx < bpx:
				bpx = dpx
				best = s
	return best

## The anchor height the hand wants right now.
func hover_height() -> float:
	var h := HOVER_H
	if is_holding():
		h = HOVER_H_HOLD
	elif scooping:
		h = SCOOP_H
	elif hover_person != null or (hover_thing != null and hover_thing.is_in_group(&"liftable")):
		h = HOVER_H_NEAR
	if dip_t > 0.0:
		h -= PLACE_DIP * sin(dip_t / 0.35 * PI)
	if is_instance_valid(hover_site) and not held.is_empty() and hover_site.can_accept(1):
		h -= 1.3      # lower over a job it can fill, ready to set them down
	return h

## The anchor rides the camera ray through the ground point at `h` above the
## ground, so it is always drawn exactly over the cursor.
func anchor_for(g: Vector3, h: float) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return g + Vector3(0, h, 0)
	var up := cam.global_position - g
	if up.length() < 0.01:
		return g + Vector3(0, h, 0)
	up = up.normalized()
	if up.y < 0.25:
		return g + Vector3(0, h, 0)
	return g + up * (h / up.y)

func _update_air(dt: float) -> void:
	var g := ground if ground.is_finite() else Vector3.ZERO
	var target := anchor_for(g, hover_height() + sin(time * 2.0) * 0.1)
	if not air_pos.is_finite():
		air_pos = target
	# the sideways glide is quick so the hand stays on the cursor; height eases
	var k := minf(16.0 * dt, 1.0)
	var ky := minf((12.0 if absf(target.y - air_pos.y) < 0.8 else 6.0) * dt, 1.0)
	air_pos = Vector3(lerpf(air_pos.x, target.x, k), lerpf(air_pos.y, target.y, ky), lerpf(air_pos.z, target.z, k))

## Below the cupped palm, where held people dangle (their feet).
func hold_point() -> Vector3:
	return air_pos - Vector3(0, HOLD_DEPTH, 0)

func _follow_held(dt: float = 0.0) -> void:
	var n := held.size()
	var hp := hold_point()
	for i in n:
		var p: Person = held[i]
		var off := Vector3.ZERO
		if n > 1:
			var a := TAU * float(i) / float(n) + time * 0.4
			off = Vector3(cos(a), 0, sin(a)) * (0.2 + 0.1 * sqrt(float(n)))
		off.y = sin(time * 3.0 + float(i) * 1.7) * 0.04 - 0.05 * float(i % 3)
		var want := hp + off
		# rise smoothly from where they stood into the hand
		var r: Array = _rise.get(p, [])
		if not r.is_empty():
			r[1] = float(r[1]) + dt
			var u := clampf(float(r[1]) / LIFT_EASE, 0.0, 1.0)
			if u >= 1.0:
				_rise.erase(p)
			else:
				var e := 1.0 - pow(1.0 - u, 3.0)
				want = (r[0] as Vector3).lerp(want, e) + Vector3(0, sin(u * PI) * 0.3, 0)
		p.held_follow(want)
		_sway(p, i, dt)
	if is_instance_valid(held_object):
		var target := hp + Vector3(0, 0.6, 0)
		if held_object.has_method(&"held_follow"):
			held_object.held_follow(target)
		else:
			held_object.global_position = target
	elif held_object != null:
		held_object = null

## Dangling: a pendulum swing, plus a wriggle by trust: frightened people
## (trust 0-1) tremble and kick, friends (3+) swing happily.
func _sway(p: Person, i: int, dt: float) -> void:
	var tr: int = int(p.get(&"trust")) if &"trust" in p else 2
	var ph := float(i) * 1.9 + float(p.get_instance_id() % 97) * 0.13
	var rx := 0.0
	var rz := 0.0
	if tr <= 1:
		rx = sin(time * 17.0 + ph) * 0.07
		rz = sin(time * 13.0 + ph * 1.3) * 0.06
	elif tr >= 3:
		rx = sin(time * 2.6 + ph) * 0.16
		rz = sin(time * 2.1 + ph * 0.7) * 0.12
	else:
		rx = sin(time * 4.0 + ph) * 0.06
		rz = sin(time * 3.3 + ph) * 0.05
	var k := minf(6.0 * maxf(dt, 0.001), 1.0)
	p.rotation.x = lerpf(p.rotation.x, rx, k)
	p.rotation.z = lerpf(p.rotation.z, rz, k)

## Drop freed or dead people from the hand. A dead person cannot be harmed further,
## a freed one cannot be called.
func _prune_held() -> void:
	var keep: Array = []
	for p in held:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.alive():
			keep.append(p)
	held = keep

# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_press(mb.position, mb.shift_pressed)
			else:
				_left_release()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if is_holding():
				place_idle()
	elif e is InputEventMouseMotion and _press_active:
		var mm := e as InputEventMouseMotion
		if not scooping and mm.position.distance_to(_press_screen) > SCOOP_DRAG_PX:
			if can_scoop() and free_grip() > 0 and (held.is_empty() or _press_shift):
				scooping = true
				scoop_center = _press_ground
		if scooping:
			scoop_radius = minf(_flat_dist(ground, scoop_center), scoop_max_radius())

func _left_press(pos: Vector2, shift: bool) -> void:
	step_hover_now()
	if held_object != null:
		place_object(ground)
		return
	if held.is_empty():
		if hover_person != null:
			try_lift(hover_person)
			return
		if hover_thing != null:
			if hover_thing.is_in_group(&"gift"):
				collect_gift(hover_thing)
			else:
				try_lift_object(hover_thing)
			return
		_begin_press(pos, shift)
		return
	if shift and hover_person != null:
		try_lift(hover_person)
		return
	if is_instance_valid(hover_site) and hover_site.can_accept(1):
		place_on_site(hover_site)
		return
	_begin_press(pos, shift)

func _begin_press(pos: Vector2, shift: bool) -> void:
	_press_active = true
	_press_screen = pos
	_press_ground = ground
	_press_shift = shift
	scooping = false
	scoop_radius = 0.0

func _left_release() -> void:
	if not _press_active:
		return
	_press_active = false
	if scooping:
		scooping = false
		var got := scoop_lift(scoop_center, scoop_radius)
		scoop_radius = 0.0
		if got == 0:
			show_hint("Nobody there")
		return
	if not held.is_empty() and not _press_shift:
		place_on_ground(ground)

## Refresh aim and hover immediately (input can arrive between frames).
func step_hover_now() -> void:
	_update_aim()
	_update_hover()

## The hand is the cursor over the world: the OS pointer hides there and comes
## back over the HUD, menus and whenever the hand is not taking input.
func _update_cursor() -> void:
	var hide := false
	if input_enabled and is_inside_tree() and DisplayServer.get_name() != "headless":
		var vp := get_viewport()
		var over_ui := vp.gui_get_hovered_control() != null
		var inside := vp.get_visible_rect().has_point(vp.get_mouse_position())
		hide = inside and not over_ui and mouse_on_ground and not aim_override.is_finite()
	_set_cursor_hidden(hide)

func _set_cursor_hidden(h: bool) -> void:
	if h == _cursor_hidden:
		return
	_cursor_hidden = h
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if h else Input.MOUSE_MODE_VISIBLE

func _ui_has_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f is LineEdit or f is TextEdit

# ---------------------------------------------------------------- feedback

func show_hint(text: String, seconds: float = 1.6) -> void:
	hint = text
	hint_t = seconds
	hint_shown.emit(text)

func strain() -> void:
	strain_t = 0.6
	var vis := _visual()
	if vis and vis.has_method(&"strain"):
		vis.strain()

## What the tooltip next to the hand says, e.g. "3 people · Haul log 2/3".
func tooltip_text() -> String:
	if hint_t > 0.0 and hint != "":
		return hint
	if gesture_power != &"" and gesture_charge > 0.0:
		var d := Defs.power(gesture_power)
		return d.title if d != null and d.title != "" else String(gesture_power).capitalize()
	if scooping:
		var n := mini(people_in_circle(scoop_center, scoop_radius).size(), free_grip())
		return "Scoop %d" % n
	if held_object != null:
		return "%s · set down" % _thing_name(held_object)
	if not held.is_empty():
		var who := ("1 person" if held.size() == 1 else "%d people" % held.size())
		if is_instance_valid(hover_site):
			var t := hover_site.hover_text()
			if not hover_site.can_accept(1):
				t += " (full)"
			var line := "%s · %s" % [who, t] if t != "" else who
			var young := PersonInfo.held_note(held, hover_site)      # [ui hook] a child over work
			return line + ("\n" + young if young != "" else "")
		return who
	if hover_person != null:
		return PersonInfo.tooltip(hover_person)                  # [ui hook] who, why idle, wants
	if hover_thing != null:
		if hover_thing.is_in_group(&"gift"):
			return "A gift"
		var w: float = hover_thing.lift_weight() if hover_thing.has_method(&"lift_weight") else 1.0
		return ("%s · too heavy" if w > Faith.strength else "%s") % _thing_name(hover_thing)
	if is_instance_valid(hover_site):
		var note := PersonInfo.site_note(hover_site)             # [ui hook] what it is for
		return hover_site.hover_text() + ("\n" + note if note != "" else "")
	return ""

func _thing_name(n: Node) -> String:
	if &"title" in n and str(n.get(&"title")) != "":
		return str(n.get(&"title"))
	return String(n.name).capitalize()

func _on_power_unlocked(_id: StringName) -> void:
	if Faith.grip > 1 and not _scoop_hint_done:
		_scoop_hint_done = true
		Events.toast.emit("Drag across people to scoop them.")

func _sfx(n: StringName, pitch: float = 1.0) -> void:
	Audio.sfx(SFX % n, Vector3.INF, pitch)

# ---------------------------------------------------------------- helpers

func _visual() -> Node:
	return get_node_or_null(^"Visual")

func site_filled(s: Site) -> int:
	if s.has_method(&"slots_filled"):
		return s.slots_filled()
	return s.workers.size()

func site_max(s: Site) -> int:
	if s.has_method(&"max_slots"):
		return s.max_slots()
	return site_filled(s) + s.free_slots()

func _ground_y(x: float, z: float) -> float:
	var w := Game.world
	if w != null and w.has_method(&"ground_y"):
		return w.ground_y(x, z)
	return 0.0

func _world_site_near(p: Vector3, r: float) -> Site:
	var w := Game.world
	if w != null and w.has_method(&"site_near"):
		var s = w.site_near(p, r)
		if s is Site and is_instance_valid(s):
			return s
		return null
	var best: Site = null
	var bd := r
	for s in Village.sites:
		if s is Site and is_instance_valid(s):
			var d := _flat_dist(s.global_position, p)
			if d < bd:
				bd = d
				best = s
	return best

func _group_near(group: StringName, p: Vector3) -> Node3D:
	for n in get_tree().get_nodes_in_group(group):
		if n is Node3D and is_instance_valid(n):
			var r: float = n.pick_radius() if n.has_method(&"pick_radius") else 3.0
			if _flat_dist(n.global_position, p) <= r:
				return n
	return null

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
