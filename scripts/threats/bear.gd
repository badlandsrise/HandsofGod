class_name Bear extends Liftable
## The East Bank bear (Era 2 threat). It lumbers out of its den towards the
## people working on the far bank, swipes anyone it reaches (hurt, never
## killed) and raids the camp's food. The hand answers it three ways:
##   a flick (a fast sweep of the hand) scares it back a way for a while;
##   with Strength II the hand lifts it (weight 9) and sets it down somewhere
##   else, and it lumbers off home;
##   a finished watchtower spots it coming: the horn turns it back.

enum S { PROWL, SCARED, HOME }

const SPEED := 3.0
const SWIPE_RANGE := 1.8
const SWIPE_COOLDOWN := 6.0
const RAID_RANGE := 4.0
const RAID_EVERY := 8.0
const TOWER_RANGE := 30.0
const SEEK := 70.0

var manager = null
var state: int = S.PROWL
var den: Vector3 = Vector3.ZERO
var home_region: StringName = &""      # the bear keeps to this region (the Hill Quarry)
var target: Node3D = null
var scared_t: float = 0.0
var swipes: int = 0
var raided: int = 0
var _swipe_cd: float = 0.0
var _raid_t: float = 0.0
var _retarget: float = 0.0
var _anim: float = 0.0
var _visual: Node3D = null

func _init() -> void:
	weight = 9.0
	kind = &"bear"
	label = "Bear"
	length = 2.4

func _ready() -> void:
	super._ready()
	add_to_group("threats")
	add_to_group("bears")
	_visual = AssetCatalog.instance(&"bear")
	_visual.name = "Visual"
	add_child(_visual)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.4, 2.4)
	cs.shape = box
	cs.position = Vector3(0, 0.7, 0)
	body.add_child(cs)
	add_child(body)

func hover_text() -> String:
	if Faith.strength < weight:
		return "Bear (flick the hand to scare it; Strength II lifts it)"
	return "Bear (lift it away)"

func on_lifted() -> void:
	super.on_lifted()
	state = S.SCARED
	target = null

func on_placed(at: Vector3) -> void:
	super.on_placed(at)
	# set down somewhere else: it has had enough and goes home
	go_home("The hand carried the bear off. It lumbers away home")

func scare(from: Vector3) -> void:
	if held or state == S.HOME:
		return
	state = S.SCARED
	scared_t = 7.0
	target = null
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		away = den - global_position
	rotation.y = atan2(away.x, away.z)
	Village.stats["bear_scares"] = int(Village.stats.get("bear_scares", 0)) + 1

func go_home(why: String = "") -> void:
	if state == S.HOME:
		return
	state = S.HOME
	target = null
	if why != "":
		Events.alert.emit(why, global_position)
	if manager != null and manager.has_method("on_bear_home"):
		manager.on_bear_home(self)

func _process(delta: float) -> void:
	if held or not Clock.running:
		return
	var dt := delta
	_anim += dt
	_swipe_cd = maxf(_swipe_cd - dt, 0.0)
	var w = Game.world
	if w == null or not is_instance_valid(w):
		return
	var goal := global_position
	var spd := SPEED
	match state:
		S.SCARED:
			scared_t -= dt
			var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
			goal = global_position + fwd * 4.0
			spd = SPEED * 1.5
			if scared_t <= 0.0:
				state = S.PROWL
		S.HOME:
			goal = den
			if Vector2(global_position.x - den.x, global_position.z - den.z).length() < 2.0:
				queue_free()
				return
		S.PROWL:
			if _tower_sees():
				go_home("The watchman's horn! The bear turns back to its den")
				return
			_retarget -= dt
			if _retarget <= 0.0 or target == null or not is_instance_valid(target):
				_retarget = 1.0
				target = _pick_target()
			if target != null and is_instance_valid(target):
				goal = target.global_position
				var d := goal - global_position
				d.y = 0.0
				if d.length() <= SWIPE_RANGE and _swipe_cd <= 0.0 and target is Person:
					_swipe(target)
				elif target is Site and d.length() <= RAID_RANGE:
					_raid_t += dt
					if _raid_t >= RAID_EVERY:
						_raid_t = 0.0
						_raid()
			else:
				goal = den
	var dv := goal - global_position
	dv.y = 0.0
	var moved := false
	if dv.length() > 1.0:
		var step := dv.normalized() * spd * dt
		var nxt := global_position + step
		if w.is_water(nxt):
			nxt = global_position      # bears do not swim the great river
		elif home_region != &"" and w.region_at(nxt) != home_region:
			nxt = global_position      # nor leave its own hills
		elif home_region == &"" and w.is_region_open(&"east_bank") and w.region_at(nxt) != &"east_bank" and w.region_at(nxt) != &"southern_plains":
			nxt = global_position      # nor walk the bridge
		global_position = nxt
		rotation.y = lerp_angle(rotation.y, atan2(dv.x, dv.z), minf(5.0 * dt, 1.0))
		moved = nxt != global_position or step.length() > 0.0
	global_position.y = w.ground_y(global_position.x, global_position.z)
	if _visual != null:
		_visual.position.y = absf(sin(_anim * 6.0)) * 0.06 if moved else 0.0

func _tower_sees() -> bool:
	for s in Village.sites:
		if is_instance_valid(s) and s.is_finished_building(&"watchtower") and s.global_position.distance_to(global_position) < TOWER_RANGE:
			return true
	return false

func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := SEEK
	for p in Village.alive():
		if not is_instance_valid(p) or not p.visible or not p.pickable():
			continue
		var dd: float = p.global_position.distance_to(global_position)
		if dd < best_d:
			best_d = dd
			best = p
	if best == null:
		var camp := Site.nearest(global_position, SEEK, func(s): return s.building != null and s.building.camp)
		return camp
	return best

func _swipe(p: Person) -> void:
	_swipe_cd = SWIPE_COOLDOWN
	swipes += 1
	Village.stats["bear_swipes"] = int(Village.stats.get("bear_swipes", 0)) + 1
	p.hurt(1.0, &"bear")
	Events.alert.emit("The bear swiped at %s!" % p.given_name, p.global_position)
	p.flee_from(global_position, 5.0)
	target = null

func _raid() -> void:
	var took := 0
	for k in [&"fish", &"berries", &"meat", &"bread"]:
		if took < 3 and Village.take_store(k, 1):
			took += 1
	if took > 0:
		raided += took
		Village.stats["bear_raided"] = int(Village.stats.get("bear_raided", 0)) + took
		Events.toast.emit("The bear is eating the camp's food")

func save_state() -> Dictionary:
	var d := super.save_state()
	d["state"] = state
	return d
