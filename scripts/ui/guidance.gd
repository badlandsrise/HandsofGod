class_name Guidance extends Node
## Guidance beats (playtest era 1, section 1): the game shows you what just
## happened and where, instead of leaving you to find it.
##  - Beats: a short camera pan to something new with a line under it, then
##    back to where you were (the first wanderer, the fire log, the first gift,
##    the festival dance spot when Blessing is bought, a baby the hand named).
##    One at a time, and never while a card, the Book or the menu is open.
##  - Beacons (Beacon): a glow, an arrow and sparkles on the fire log, every
##    gift waiting to be picked up, the dance spots, new babies and the first
##    wanderer.
##  - Blessing: a ring under each blessed person that empties with the time
##    left, a warm halo, and a clear fade when it wears off.
##  - Births get a portrait alert ("Mira had a baby: Kai") that looks at the
##    baby; hunts and other group work show what they brought ("+6 meat").
##  - First-time explanations: the first cold person (how warmth works), a
##    child set on work ("Too young to work (age 8)"), what Blessing does.
## The HUD owns one. State that must not repeat lives in Village.stats.

const BEAT_HOLD := 3.2          # seconds the camera rests on a beat
const BEAT_DIST := 22.0
const SCAN := 0.4               # seconds between looks for new things to mark
const GUIDED_JOBS := [&"carry_log", &"festival", &"harvest_festival"]

var hud: Node = null
var caption: Caption
var _queue: Array = []          # beats waiting: {at, node, line, hold, dist, key}
var _beat: Dictionary = {}
var _beat_t: float = 0.0
var _cam_back: Vector3 = Vector3.INF
var _cam_back_dist: float = -1.0
var _cam_set: Vector3 = Vector3.INF
var _scan_t: float = 0.0
var _rings: Dictionary = {}     # Person -> BlessRing
var _baby_prayers: Dictionary = {}   # uid -> true while the hand is asked to name them

func _init(h: Node = null) -> void:
	hud = h

func _ready() -> void:
	name = "Guidance"
	process_mode = Node.PROCESS_MODE_ALWAYS
	caption = Caption.new()
	if hud != null and hud.get(&"root") is Control:
		(hud.root as Control).add_child(caption)
	else:
		add_child(caption)
	Events.person_joined.connect(_on_joined)
	Events.person_born.connect(_on_born)
	Events.name_requested.connect(_on_name_requested)
	Events.names_given.connect(_on_names_given)
	Events.job_completed.connect(_on_job_completed)
	Events.person_need_low.connect(_on_need_low)
	Events.hand_placed.connect(_on_hand_placed)
	Events.power_unlocked.connect(_on_power)

# ---------------------------------------------------------------- beats

## Queues a beat: the camera glides to `what` (a Node3D, followed while it
## moves, or a Vector3), `line` shows under it, then the camera goes back.
## `key` (optional) makes it once per game.
func beat(what, line: String, key: String = "", hold: float = BEAT_HOLD, dist: float = BEAT_DIST) -> bool:
	if key != "":
		if Village.stats.get("guide_" + key, false):
			return false
		Village.stats["guide_" + key] = true
	var b := {"line": line, "hold": hold, "dist": dist, "key": key, "node": null, "at": Vector3.INF}
	if what is Node3D:
		b["node"] = what
	elif what is Vector3:
		b["at"] = what
	_queue.append(b)
	return true

func busy() -> bool:
	return not _beat.is_empty() or not _queue.is_empty()

## May a beat run now? Not under a card, the Book, the menu or the title.
func can_run() -> bool:
	if not Clock.running:
		return false
	if hud != null:
		if "visible" in hud and not hud.visible:
			return false
		if hud.has_method(&"modal_open") and hud.modal_open():
			return false
		if hud.get(&"book") != null and hud.book.is_open():
			return false
	return true

func _cam() -> Node:
	return get_tree().get_first_node_in_group(&"camera_rig")

## The village's heart: its fire, else the people's middle.
func _home() -> Vector3:
	for s in Village.sites:
		if is_instance_valid(s) and s.has_method(&"is_fire") and s.is_fire():
			return (s as Node3D).global_position
	var sum := Vector3.ZERO
	var n := 0
	for p in Village.alive():
		sum += (p as Node3D).global_position
		n += 1
	return sum / n if n > 0 else Vector3.INF

func _beat_pos(b: Dictionary) -> Vector3:
	var n = b.get("node")
	if n != null and is_instance_valid(n) and n is Node3D and (n as Node3D).is_inside_tree():
		var at := (n as Node3D).global_position
		# someone still out at the valley's edge: frame them from the open
		# side, not through the treeline
		var lean := float(b.get("lean", 0.0))
		if lean > 0.0:
			var home := _home()
			if home.is_finite():
				at = at.lerp(home, lean)
		return at
	return b.get("at", Vector3.INF)

func _start_beat(b: Dictionary) -> void:
	var p := _beat_pos(b)
	if not p.is_finite():
		return
	_beat = b
	_beat_t = float(b["hold"])
	var cam := _cam()
	if cam != null and &"target_focus" in cam:
		_cam_back = cam.target_focus
		_cam_back_dist = cam.target_dist
		cam.focus_on(p, minf(float(b["dist"]), cam.target_dist) if float(b["dist"]) > 0.0 else -1.0)
		_cam_set = cam.target_focus
	caption.say(str(b["line"]), float(b["hold"]) + 1.2)
	var n = b.get("node")
	if n != null and is_instance_valid(n) and n is Node3D and Beacon.on(n) == null:
		Beacon.attach(n, {"life": float(b["hold"]) + 6.0, "kind": &"beat"})

func _step_beat(dt: float) -> void:
	_beat_t -= dt
	var cam := _cam()
	var moved := false
	if cam != null and &"target_focus" in cam and _cam_set.is_finite():
		# the player took the camera: let them have it
		moved = (cam.target_focus as Vector3).distance_to(_cam_set) > 0.5
		if not moved:
			var p := _beat_pos(_beat)
			if p.is_finite():
				cam.focus_on(p)
				_cam_set = cam.target_focus
	if moved:
		_cam_back = Vector3.INF
	if _beat_t <= 0.0 or moved:
		if cam != null and _cam_back.is_finite():
			cam.focus_on(_cam_back, _cam_back_dist)
		_beat = {}
		_cam_back = Vector3.INF
		_cam_set = Vector3.INF

func _process(_d: float) -> void:
	var dt := Clock.real_delta
	if _beat.is_empty():
		if not _queue.is_empty() and can_run():
			_start_beat(_queue.pop_front())
	elif can_run():
		_step_beat(dt)
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = SCAN
		scan()

# ---------------------------------------------------------------- marking things

## Looks for things worth a beacon: the fire log, gifts, the dance spots, and
## blessed people (their rings).
func scan() -> void:
	if Game.world == null or not is_instance_valid(Game.world):
		return
	for s in Village.sites:
		if not is_instance_valid(s) or s.job == null or not s.is_inside_tree():
			continue
		var jid: StringName = s.job.id
		if not GUIDED_JOBS.has(jid) or Beacon.on(s) != null:
			continue
		match jid:
			&"carry_log":
				Beacon.attach(s, {"kind": &"fire_log", "radius": 1.8})
				beat(s, "A log for the fire. It takes two to carry it: lift one of them to it, then the other.", "fire_log", 3.6)
			&"festival":
				Beacon.attach(s, {"kind": &"dance_spot", "radius": 2.6, "until": func(): return Flags.has(&"festival"), "quiet_when": _has_workers.bind(s)})
				if Faith.has(&"blessing"):
					beat(s, "The dance spot by the fire circle. Bless six of them (Blessing: hold E over them), then set them down here.", "dance_spot", 4.4)
			&"harvest_festival":
				Beacon.attach(s, {"kind": &"dance_spot", "radius": 3.0, "until": func(): return Flags.has(&"harvest_festival"), "quiet_when": _has_workers.bind(s)})
				beat(s, "The harvest festival. Set six or more of them down at the fields to dance.", "harvest_spot", 4.0)
	for g in get_tree().get_nodes_in_group(&"gift"):
		if g is Node3D and g.is_inside_tree() and Beacon.on(g) == null:
			Beacon.attach(g, {"kind": &"gift", "radius": 0.9, "arrow_height": 2.2, "color": Color(1.0, 0.86, 0.5)})
			beat(g, "They left something for you. Pick it up with the hand.", "first_gift", 3.2)
	_scan_blessed()

## Dancers already on the spot: the beacon steps back so their rings read.
func _has_workers(s) -> bool:
	return is_instance_valid(s) and "workers" in s and not (s.workers as Array).is_empty()

func _scan_blessed() -> void:
	for p in Village.people:
		if not is_instance_valid(p) or not p.alive():
			continue
		if p.blessed_t > 0.0 and (not _rings.has(p) or not is_instance_valid(_rings[p]) or _rings[p].ending()):
			var r := Beacon.BlessRing.new()
			r.person = p
			r.full = maxf(30.0, p.blessed_t)
			Game.world.add_child(r)
			r.global_position = p.global_position
			_rings[p] = r
	for p in _rings.keys():
		if not is_instance_valid(_rings[p]):
			_rings.erase(p)

## Marks a person for a while (the Book's "find", births, the first wanderer).
func mark(p: Node3D, seconds: float = 8.0, kind: StringName = &"find") -> Beacon:
	if p == null or not is_instance_valid(p):
		return null
	var small: bool = p is Person and p.stage <= Person.Stage.CHILD
	return Beacon.attach(p, {"life": seconds, "kind": kind, "radius": 0.9 if small else 1.1, "arrow_height": 2.0 if small else 2.6})

# ---------------------------------------------------------------- events

func _on_joined(p) -> void:
	if not (p is Node3D) or not is_instance_valid(p):
		return
	if not Village.stats.get("guide_first_wanderer", false):
		Village.stats["guide_first_wanderer"] = true
		mark(p, 16.0, &"wanderer")
		var who := "%s, a wanderer, is walking into your valley. %s saw your fire." % [p.given_name, BookData.pronoun(p.sex, "she").capitalize()] if &"given_name" in p else "Someone is walking into your valley."
		if beat(p, who, "", 4.0, 30.0):
			(_queue.back() as Dictionary)["lean"] = 0.4

func _on_born(baby) -> void:
	if not (baby is Person) or not is_instance_valid(baby):
		return
	var mother := ""
	for u in baby.parents:
		var q := Births.find(int(u))
		if q != null and (mother == "" or q.sex == "f"):
			mother = q.given_name
	var line := "%s had a baby: %s" % [mother, baby.given_name] if mother != "" else "A baby was born: %s" % baby.given_name
	Events.alert.emit(line, baby.global_position)
	mark(baby, 25.0, &"baby")
	if not Village.stats.get("guide_first_birth", false):
		Village.stats["guide_first_birth"] = true
		beat(baby, "%s. The first child born in the valley." % line, "", 3.2, 18.0)

func _on_name_requested(people: Array, reason: StringName) -> void:
	if reason != &"baby_prayer":
		return
	for p in people:
		if is_instance_valid(p):
			_baby_prayers[int(p.uid)] = true

func _on_names_given(people: Array) -> void:
	for e in people:
		var p = e
		if e is Dictionary:
			p = e.get("person", null)
		elif e is Array and not e.is_empty():
			p = e[0]
		if not (p is Person) or not is_instance_valid(p) or not _baby_prayers.has(int(p.uid)):
			continue
		_baby_prayers.erase(int(p.uid))
		var par := ""
		for u in p.parents:
			var q := Births.find(int(u))
			if q != null and (par == "" or q.sex == "f"):
				par = q.given_name
		mark(p, 20.0, &"baby")
		beat(p, "This is %s, the child you named%s." % [p.given_name, ", with %s" % par if par != "" else ""], "", 3.4, 16.0)

func _on_job_completed(site) -> void:
	if not (site is Site) or not is_instance_valid(site) or site.job == null:
		return
	var jd: JobDef = site.job
	# who did the work (the discovery lines say who)
	if jd.id == &"knap_flint":
		if not Village.stats.has("work_by"):
			Village.stats["work_by"] = {}
		var by: Dictionary = Village.stats["work_by"].get("knap_flint", {})
		for w in site.workers:
			if is_instance_valid(w):
				by[str(w.uid)] = int(by.get(str(w.uid), 0)) + 1
		Village.stats["work_by"]["knap_flint"] = by
	# what a group's work brought home
	if jd.kind == JobDef.Kind.GROUP and not jd.outputs.is_empty() and site.is_inside_tree():
		pop_yield(site.global_position, PersonInfo.yield_text(jd))
		if jd.id == &"hunt" and not Village.stats.get("guide_first_hunt_yield", false):
			Village.stats["guide_first_hunt_yield"] = true
			var days := int(floor(float(Village.food()) / maxf(float(Village.population()), 1.0)))
			Events.alert.emit("The hunt brought back %s. The stores now hold %d %s of food." % [PersonInfo.outputs_text(jd), days, "day" if days == 1 else "days"], site.global_position)

## "+6 meat" rising over `at`.
func pop_yield(at: Vector3, text: String) -> void:
	if text == "" or Game.world == null or not is_instance_valid(Game.world):
		return
	var l := Beacon.YieldPop.new()
	l.text = text
	Game.world.add_child(l)
	l.global_position = at + Vector3(0, 2.4, 0)

func _on_need_low(p, need: StringName) -> void:
	if need != &"warmth" or not is_instance_valid(p) or Village.stats.get("hint_cold", false) or not Flags.onboarding_done():
		return
	Village.stats["hint_cold"] = true
	var warm := "a lit fire, a hut" + (", or the hand's Warmth (hold E)" if Faith.has(&"warmth") else "")
	Events.alert.emit("%s is cold. People warm up near %s." % [p.given_name, warm], p.global_position)
	caption.say("Cold people lose heart and fall ill. Set them by a lit fire, or let them into a hut.", 6.0)

func _on_hand_placed(people: Array, target) -> void:
	if not (target is Site) or not is_instance_valid(target):
		return
	for p in people:
		if p is Person and is_instance_valid(p) and PersonInfo.too_young(p, target):
			var hand := get_tree().get_first_node_in_group(&"hand")
			if hand != null and hand.has_method(&"show_hint"):
				hand.show_hint(PersonInfo.too_young_line(p), 3.0)
			if not Village.stats.get("hint_child", false):
				Village.stats["hint_child"] = true
				caption.say("%s %s" % [PersonInfo.too_young_line(p) + ".", PersonInfo.child_rule()], 6.0)
			return

func _on_power(id: StringName) -> void:
	if id == &"blessing" and not Village.stats.get("hint_blessing", false):
		Village.stats["hint_blessing"] = true
		caption.say("Blessing: hold E over people. Blessed people work twice as fast; the ring under them shows the time left.", 6.5)

## A line of guidance near the bottom of the screen, on parchment.
class Caption extends PanelContainer:
	var _label: Label
	var _t: float = 0.0
	var _a: float = 0.0
	var text: String = ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := InkBox.make(Color(UiTheme.PAPER, 0.95), Color(UiTheme.OCHRE, 0.9), 22.0, 10.0, 2.0)
		sb.double_line = true
		sb.shadow = Color(0, 0, 0, 0.3)
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		add_theme_stylebox_override(&"panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		var mark := HandMark.new()
		h.add_child(mark)
		_label = UiTheme.ink_label("", 20, &"semibold")
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = 560
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(_label)
		visible = false
		modulate.a = 0.0
	func say(t: String, seconds: float = 4.0) -> void:
		text = t
		_label.text = t
		_t = seconds
		visible = true
		reset_size()
		_place()
	func showing() -> bool:
		return visible and _t > 0.0
	func _place() -> void:
		var p := get_parent() as Control
		var vs: Vector2 = p.size if p != null and p.size.x > 10.0 else get_viewport_rect().size
		position = Vector2((vs.x - size.x) * 0.5, vs.y - size.y - 210.0)
	func _process(_d: float) -> void:
		var dt := Clock.real_delta
		_t -= dt
		_a = move_toward(_a, 1.0 if _t > 0.0 else 0.0, dt * 3.0)
		modulate.a = _a
		if _a <= 0.0 and _t <= 0.0:
			visible = false
		elif visible:
			_place()

class HandMark extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(36, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 16.0, Color(UiTheme.OCHRE, 0.16))
		draw_arc(c, 16.0, 0, TAU, 32, Color(UiTheme.OCHRE, 0.8), 1.6, true)
		PortraitFrame.draw_hand_mark(self, c + Vector2(0, 2), 12.0, UiTheme.OCHRE.darkened(0.1))
