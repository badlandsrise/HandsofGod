class_name FirePit extends Node3D
## The Clearing's fire: stones, logs, a flame and a flickering OmniLight3D.
## Fuel comes from work (Events.job_completed at a tend_fire or log-haul Site)
## and burns down slowly. Wolves keep out of radius().

const BURN_PER_SEC := 1.0 / 200.0
const MAX_RADIUS := 11.0

var fuel: float = 0.0          # 0..1
var light: OmniLight3D
var flame: Node3D
var _t: float = 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	name = "FirePit"
	add_to_group("fires")
	var v := Node3D.new()
	v.name = "Visual"
	add_child(v)
	var stone := Color(0.42, 0.4, 0.38)
	for i in 9:
		var a := TAU * i / 9.0
		var s := Props.add_mesh(v, Props.ball(0.28, 6), stone.lerp(Color(0.3, 0.29, 0.28), float(i % 3) / 3.0), Vector3(cos(a) * 0.95, 0.12, sin(a) * 0.95))
		s.scale = Vector3(1.2, 0.7, 1.0)
	for i in 4:
		var lg := Props.add_mesh(v, Props.cyl(0.08, 0.1, 1.1, 6), Color(0.3, 0.2, 0.12), Vector3(0, 0.22, 0))
		lg.rotation = Vector3(0.0, TAU * i / 4.0, PI * 0.5 - 0.35)
	flame = Node3D.new()
	flame.name = "Flame"
	v.add_child(flame)
	Props.add_mesh(flame, Props.cyl(0.0, 0.4, 0.9, 6), Color(1.0, 0.5, 0.12), Vector3(0, 0.6, 0), 4.0)
	Props.add_mesh(flame, Props.cyl(0.0, 0.22, 0.6, 6), Color(1.0, 0.85, 0.4), Vector3(0, 0.55, 0), 5.0)
	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.6, 0.28)
	light.omni_range = MAX_RADIUS + 5.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.position = Vector3(0, 1.4, 0)
	add_child(light)
	_noise.frequency = 3.0
	_apply()

func is_lit() -> bool:
	return fuel > 0.0

func add_fuel(amount: float) -> void:
	var was := is_lit()
	fuel = clampf(fuel + amount, 0.0, 1.0)
	if not was and is_lit():
		Audio.sfx("res://assets/audio/sfx/fire_light.ogg", global_position)

## Wolves will not come within this distance.
func radius() -> float:
	return 0.0 if not is_lit() else lerpf(5.0, MAX_RADIUS, clampf(fuel * 1.5, 0.0, 1.0))

func _process(delta: float) -> void:
	_t += delta
	if fuel > 0.0:
		fuel = maxf(fuel - BURN_PER_SEC * delta, 0.0)
	_apply()

func _apply() -> void:
	var lit := is_lit()
	flame.visible = lit
	light.visible = lit
	if not lit:
		return
	var f := _noise.get_noise_1d(_t * 6.0) * 0.5 + _noise.get_noise_1d(_t * 17.0 + 40.0) * 0.25
	var strength := clampf(0.4 + fuel, 0.4, 1.0)
	light.light_energy = (2.2 + f * 0.9) * strength
	light.omni_range = (MAX_RADIUS + 5.0) * (0.7 + 0.3 * strength)
	flame.scale = Vector3(1.0 + f * 0.15, (1.0 + f * 0.35) * (0.6 + 0.4 * strength), 1.0 + f * 0.15)
	flame.rotation.y = _t * 1.7

func save_state() -> Dictionary:
	return {"fuel": fuel}

func load_state(d: Dictionary) -> void:
	fuel = d.get("fuel", 0.0)
	_apply()
