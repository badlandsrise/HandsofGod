class_name StormOpening extends Node
## The first minute (design doc 11.4): storm night, two people huddled under
## the cliff, a fallen branch across the cave mouth. The night holds until the
## branch is lifted away; then the two run inside, the rain eases and dawn
## comes a few seconds later. No tutorial text: a hint glow on the branch.

signal finished

enum S { OFF, STORM, RUNNING_IN, DAWNING, DONE }

const CLEAR_DIST := 3.0          # branch must be moved this far off the mouth
const HOLD_LEFT := 6.0           # seconds of night kept in hand while the storm holds

var state: int = S.OFF
var branch: Liftable
var people: Array = []
var _t: float = 0.0
var _glow: MeshInstance3D
var _mouth: Vector3

func begin(b: Liftable, huddled: Array) -> void:
	branch = b
	people = huddled
	state = S.STORM
	_mouth = b.global_position
	Clock.is_night = true
	Clock.phase_t = 0.0
	Clock.day = 0                 # the first dawn is day 1
	var w = Game.world
	if w != null:
		w.look.set_weather(1.0, true)
		w.look.update_now()
		if w.threats:
			w.threats.enabled = false
	if not branch.placed.is_connected(_on_branch_placed):
		branch.placed.connect(_on_branch_placed)
	_make_glow()

func active() -> bool:
	return state != S.OFF and state != S.DONE

func _make_glow() -> void:
	if _glow != null and is_instance_valid(_glow):
		_glow.queue_free()
	_glow = MeshInstance3D.new()
	_glow.name = "HintGlow"
	var t := TorusMesh.new()
	t.inner_radius = 2.0
	t.outer_radius = 2.35
	t.rings = 24
	_glow.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.8, 0.4, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.75, 0.35)
	m.emission_energy_multiplier = 2.0
	_glow.material_override = m
	branch.add_child(_glow)
	_glow.position = Vector3(0, 0.3, 0)

func _on_branch_placed(at: Vector3) -> void:
	if state != S.STORM:
		return
	if Vector2(at.x - _mouth.x, at.z - _mouth.z).length() < CLEAR_DIST:
		return
	state = S.RUNNING_IN
	_t = 0.0
	if _glow and is_instance_valid(_glow):
		_glow.queue_free()
	var inside := Vector3(Valley.CAVE.x, 0, Valley.CAVE.y)
	var w = Game.world
	for i in people.size():
		var p = people[i]
		if not is_instance_valid(p):
			continue
		var dest := inside + Vector3((i - 0.5) * 1.4, 0, 0)
		if w != null:
			dest.y = w.ground_y(dest.x, dest.z)
		if p.has_method("run_to"):
			p.run_to(dest)
		elif p.has_method("walk_to"):
			p.walk_to(dest)
		elif p.has_method("go_to"):
			p.go_to(dest)
		elif p.has_method("_walk"):
			p._walk(dest)
		else:
			var tw: Tween = p.create_tween()
			tw.tween_property(p, "global_position", dest, 1.6).set_trans(Tween.TRANS_SINE)
	if w != null and w.nav:
		w.nav.remove_obstacle("storm_branch")
		w.nav.rebake()

func _process(delta: float) -> void:
	match state:
		S.STORM:
			# the storm holds: the night does not end before the branch moves
			if Clock.is_night and Clock.phase_t > Clock.night_seconds - HOLD_LEFT:
				Clock.phase_t = Clock.night_seconds - HOLD_LEFT
			if _glow and is_instance_valid(_glow):
				var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
				(_glow.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.45 * k
				_glow.scale = Vector3.ONE * (1.0 + 0.08 * k)
		S.RUNNING_IN:
			_t += delta
			if _t > 2.0:
				state = S.DAWNING
				# "They look up at the hand." Then the rain eases and dawn comes.
				if Game.world:
					Game.world.look.set_weather(0.15, false)
				if Clock.is_night:
					Clock.phase_t = maxf(Clock.phase_t, Clock.night_seconds - 3.0)
		S.DAWNING:
			if not Clock.is_night:
				_finish()

func _finish() -> void:
	state = S.DONE
	if Game.world:
		Game.world.look.set_weather(0.0, false)
		if Game.world.threats:
			Game.world.threats.enabled = true
	finished.emit()

## Skips straight to the end (loading a save made after the opening).
func skip() -> void:
	if _glow and is_instance_valid(_glow):
		_glow.queue_free()
	state = S.DONE
	if Game.world and Game.world.threats:
		Game.world.threats.enabled = true
