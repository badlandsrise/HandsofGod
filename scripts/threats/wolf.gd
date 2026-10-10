class_name Wolf extends Node3D
## Placeholder Era 1 wolf. Slinks in from the treeline at night, stalks the
## nearest person outside the firelight, bites once and retreats. Flees from
## fire and from the hand (Wolves.scare). Art lives under "Visual".

enum S { APPROACH, STALK, FLEE }

const SPEED := 4.2
const BITE_RANGE := 1.2

var manager: Node = null
var state: int = S.APPROACH
var target: Node3D = null
var home: Vector3 = Vector3.ZERO
var flee_t: float = 0.0
var _retarget: float = 0.0
var _anim: float = 0.0
var _legs: Array[Node3D] = []
var _eyes: Array[MeshInstance3D] = []
var bites: int = 0

func _ready() -> void:
	add_to_group("wolves")
	add_to_group("threats")
	_build_visual()

func _build_visual() -> void:
	var v := Node3D.new()
	v.name = "Visual"
	add_child(v)
	var fur := Color(0.3, 0.3, 0.33)
	Props.add_mesh(v, Props.box(Vector3(0.55, 0.5, 1.3)), fur, Vector3(0, 0.75, 0))
	Props.add_mesh(v, Props.box(Vector3(0.42, 0.4, 0.5)), fur, Vector3(0, 0.95, 0.8))
	Props.add_mesh(v, Props.box(Vector3(0.22, 0.2, 0.35)), fur.darkened(0.2), Vector3(0, 0.85, 1.15))
	Props.add_mesh(v, Props.box(Vector3(0.1, 0.2, 0.1)), fur, Vector3(-0.13, 1.25, 0.75))
	Props.add_mesh(v, Props.box(Vector3(0.1, 0.2, 0.1)), fur, Vector3(0.13, 1.25, 0.75))
	var tail := Props.add_mesh(v, Props.box(Vector3(0.12, 0.12, 0.6)), fur, Vector3(0, 0.95, -0.85))
	tail.rotation.x = 0.5
	for x in [-0.18, 0.18]:
		for z in [-0.45, 0.45]:
			var leg := Node3D.new()
			leg.position = Vector3(x, 0.5, z)
			v.add_child(leg)
			Props.add_mesh(leg, Props.box(Vector3(0.12, 0.5, 0.12)), fur.darkened(0.15), Vector3(0, -0.25, 0))
			_legs.append(leg)
	for x in [-0.1, 0.1]:
		_eyes.append(Props.add_mesh(v, Props.ball(0.045, 6), Color(1.0, 0.85, 0.2), Vector3(x, 1.02, 1.06), 3.0))

func scare(from: Vector3) -> void:
	if state == S.FLEE:
		flee_t = maxf(flee_t, 4.0)
		return
	state = S.FLEE
	flee_t = 6.0
	target = null
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		away = global_position - home
	rotation.y = atan2(away.x, away.z)
	Audio.sfx("res://assets/audio/sfx/wolf_yelp.ogg", global_position)

func _process(delta: float) -> void:
	_anim += delta
	var w: Node = Game.world
	if w == null or not is_instance_valid(w):
		return
	var moved := false
	var fire_p: Vector3 = w.fire_position()
	var fire_r: float = w.fire_radius()
	match state:
		S.FLEE:
			flee_t -= delta
			var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
			global_position += fwd * SPEED * 1.6 * delta
			moved = true
			if flee_t <= 0.0:
				if manager != null and manager.has_method("on_wolf_gone"):
					manager.on_wolf_gone(self)
				queue_free()
				return
		_:
			_retarget -= delta
			if _retarget <= 0.0 or target == null or not is_instance_valid(target):
				_retarget = 0.6
				target = _pick_target(fire_p, fire_r)
			var goal: Vector3
			if target != null and is_instance_valid(target):
				state = S.STALK
				goal = target.global_position
			else:
				state = S.APPROACH
				# circle the firelight hungrily
				var to_fire := fire_p - global_position
				to_fire.y = 0.0
				var ring := fire_r + 5.0 if fire_r > 0.0 else 9.0
				var side := Vector3(-to_fire.z, 0, to_fire.x).normalized()
				goal = global_position + side * 3.0 + to_fire.normalized() * (to_fire.length() - ring)
			var d := goal - global_position
			d.y = 0.0
			var dist := d.length()
			# never step into the firelight
			var next := global_position + (d / maxf(dist, 0.001)) * SPEED * delta
			if fire_r > 0.0 and Vector2(next.x - fire_p.x, next.z - fire_p.z).length() < fire_r:
				var out := (global_position - fire_p)
				out.y = 0.0
				next = global_position + out.normalized() * SPEED * 0.5 * delta
				target = null
			if dist > BITE_RANGE * 0.8:
				global_position = next
				moved = true
				rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(8.0 * delta, 1.0))
			if state == S.STALK and dist <= BITE_RANGE:
				_bite(target)
	global_position.y = w.ground_y(global_position.x, global_position.z)
	var sw := sin(_anim * 14.0) * 0.7 if moved else 0.0
	for i in _legs.size():
		_legs[i].rotation.x = sw if i % 2 == 0 else -sw
	for e in _eyes:
		e.visible = Clock.is_night

func _pick_target(fire_p: Vector3, fire_r: float) -> Node3D:
	var best: Node3D = null
	var best_d := 28.0
	for p in Village.alive():
		if not is_instance_valid(p) or not (p is Node3D) or not p.visible:
			continue
		if p.has_method("pickable") and not p.pickable():
			continue    # held by the hand, or otherwise out of reach
		if p.has_method("is_sheltered") and p.is_sheltered():
			continue
		var pp: Vector3 = p.global_position
		if fire_r > 0.0 and Vector2(pp.x - fire_p.x, pp.z - fire_p.z).length() < fire_r + 0.5:
			continue
		var dd := pp.distance_to(global_position)
		if dd < best_d:
			best_d = dd
			best = p
	return best

func _bite(p: Node3D) -> void:
	bites += 1
	if is_instance_valid(p):
		if p.has_method("hurt"):
			p.hurt(1.0, &"wolf")
		Events.alert.emit("A wolf bit %s!" % str(p.get("given_name") if p.get("given_name") else "someone"), p.global_position)
	Audio.sfx("res://assets/audio/sfx/wolf_bite.ogg", global_position)
	# worst case is one person hurt: after a bite the wolf runs off
	scare(global_position + Vector3(sin(rotation.y), 0, cos(rotation.y)) * 2.0)
