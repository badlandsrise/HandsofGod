class_name Wolves extends Node3D
## Era 1 wolves at night. Telegraphed at dusk (howls, eyes in the treeline,
## Events.threat_warned + Events.alert), then a small pack comes in at night
## and leaves at dawn. The hand scares them: scare(at, radius). The hand
## worker calls Game.world.wolves.scare() when the hand moves fast near them;
## placing things near them (Events.hand_placed / hand_placed_object) and hold
## gestures also scare them.

const ID := &"wolves"
const WOLF_SCRIPT := preload("res://scripts/threats/wolf.gd")

var warned: bool = false
var active: bool = false
var planned: int = 0
var eyes: Array[Node3D] = []
var spawn_points: Array[Vector3] = []
var nights_with_wolves: int = 0

func _ready() -> void:
	name = "Wolves"
	Events.hand_placed.connect(_on_hand_placed)
	Events.hand_placed_object.connect(func(_o, at: Vector3): scare(at, 9.0))
	Events.hand_gesture.connect(func(_id, at: Vector3): scare(at, 10.0))

const FLICK_SPEED := 22.0        # m/s of hand motion that counts as a flick
const FLICK_RADIUS := 7.0
var _hand_last := Vector3.INF

## A fast hand sweep near a wolf scares it (the hand's flick).
func _process(_delta: float) -> void:
	var w: Node = Game.world
	var hand: Node = w.get("hand") if w != null else null
	if hand == null or not is_instance_valid(hand) or not (hand is Node3D) or get_child_count() == 0:
		_hand_last = Vector3.INF
		return
	var hp: Vector3 = hand.get("ground") if hand.get("ground") is Vector3 else (hand as Node3D).global_position
	var dt := maxf(Clock.real_delta, 0.001)
	if _hand_last.is_finite():
		var v := Vector2(hp.x - _hand_last.x, hp.z - _hand_last.z).length() / dt
		if v > FLICK_SPEED:
			scare(hp, FLICK_RADIUS)
	_hand_last = hp

func count() -> int:
	return get_tree().get_nodes_in_group("wolves").size() if is_inside_tree() else 0

## Scares every wolf within `radius` of `at`; returns how many fled.
func scare(at: Vector3, radius: float) -> int:
	var n := 0
	for w in get_children():
		if w is Wolf and is_instance_valid(w) and w.global_position.distance_to(at) <= radius:
			w.scare(at)
			n += 1
	return n

func _on_hand_placed(people: Array, _target) -> void:
	for p in people:
		if is_instance_valid(p) and p is Node3D:
			scare(p.global_position, 6.0)
			return

## Dusk warning. `n` wolves will come when night falls.
func warn(n: int) -> void:
	if warned:
		return
	warned = true
	planned = n
	_pick_spawns()
	var at: Vector3 = spawn_points[0] if not spawn_points.is_empty() else Vector3.ZERO
	Events.threat_warned.emit(ID, at)
	Events.alert.emit("Howls at dusk. Wolves are near the treeline.", at)
	Audio.sfx("res://assets/audio/sfx/wolf_howl.ogg", at)
	for sp in spawn_points:
		var e := Node3D.new()
		e.name = "Eyes"
		var v := Node3D.new()
		v.name = "Visual"
		e.add_child(v)
		for x in [-0.12, 0.12]:
			Props.add_mesh(v, Props.ball(0.06, 6), Color(1.0, 0.85, 0.25), Vector3(x, 1.0, 0), 4.0)
		add_child(e)
		e.global_position = sp
		var f: Vector3 = Game.world.fire_position() if Game.world else Vector3.ZERO
		f.y = sp.y
		if f.distance_to(sp) > 0.1:
			e.look_at(f, Vector3.UP, true)
		eyes.append(e)

func start() -> void:
	if not warned:
		warn(1)
	active = true
	nights_with_wolves += 1
	for e in eyes:
		if is_instance_valid(e):
			e.queue_free()
	eyes.clear()
	for i in planned:
		var w: Wolf = WOLF_SCRIPT.new()
		w.manager = self
		var sp: Vector3 = spawn_points[i % spawn_points.size()] if not spawn_points.is_empty() else Vector3(-50, 0, 0)
		w.home = sp
		add_child(w)
		w.global_position = sp + Vector3(Game.rng.randf_range(-2, 2), 0, Game.rng.randf_range(-2, 2))
	Events.threat_started.emit(ID, spawn_points[0] if not spawn_points.is_empty() else Vector3.ZERO)

## Dawn: any wolf still here slinks off.
func end() -> void:
	for w in get_children():
		if w is Wolf and is_instance_valid(w):
			w.scare(Game.world.fire_position() if Game.world else Vector3.ZERO)
	for e in eyes:
		if is_instance_valid(e):
			e.queue_free()
	eyes.clear()
	var was := active or warned
	active = false
	warned = false
	planned = 0
	if was:
		Events.threat_ended.emit(ID)

func on_wolf_gone(_w) -> void:
	pass

## Immediately removes everything (new game / load).
func clear_all() -> void:
	for c in get_children():
		c.queue_free()
	eyes.clear()
	active = false
	warned = false
	planned = 0

func _pick_spawns() -> void:
	spawn_points.clear()
	var w: Node = Game.world
	var den := Vector3(Valley.WOLF_DEN.x, 0, Valley.WOLF_DEN.y)
	var meadow_open := Village.regions.has(&"western_meadow")
	for i in maxi(planned, 1):
		var p: Vector3
		if meadow_open:
			p = den + Vector3(Game.rng.randf_range(-8, 8), 0, Game.rng.randf_range(-8, 8))
		else:
			# the treeline of the ridge around the Clearing, on the den's side
			var a := PI + Game.rng.randf_range(-0.9, 0.9)
			p = Vector3(cos(a) * 52.0, 0, 2.0 + sin(a) * 48.0)
		if w != null:
			p.y = w.ground_y(p.x, p.z)
		spawn_points.append(p)
