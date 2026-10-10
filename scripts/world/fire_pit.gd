class_name FirePit extends Node3D
## The firelight of the Clearing: a flickering OmniLight3D at the fire pit.
## The fire itself (fuel, stones, flame) is the tend_fire Site; this node
## follows that Site's fuel, so the light and the wolves' keep-out radius
## match what the people actually keep burning. Without a Site (tests), it
## burns its own `fuel`.

const MAX_RADIUS := 11.0

var fuel: float = 0.0          # 0..1, used only when no tend_fire Site is near
var light: OmniLight3D
var site: Node = null
var _t: float = 0.0
var _find_t: float = 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	name = "FirePit"
	add_to_group("fire_light")
	var v := Node3D.new()
	v.name = "Visual"
	add_child(v)
	# a scorched patch under the Site's stones
	var ash := Props.add_mesh(v, Props.cyl(1.6, 1.8, 0.04, 10), Color(0.16, 0.13, 0.11), Vector3(0, 0.02, 0))
	ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.6, 0.28)
	light.omni_range = MAX_RADIUS + 5.0
	light.omni_attenuation = 1.1
	light.shadow_enabled = true
	light.position = Vector3(0, 1.6, 0)
	add_child(light)
	_noise.frequency = 3.0
	_apply()

func _find_site() -> void:
	site = null
	var best := 6.0
	for s in Village.sites:
		if is_instance_valid(s) and s.has_method("is_fire") and s.is_fire():
			var d: float = s.global_position.distance_to(global_position)
			if d < best:
				best = d
				site = s

## 0..1 how full the fire is.
func level() -> float:
	if site != null and is_instance_valid(site) and "fuel_t" in site:
		return clampf(site.fuel_t / Site.FIRE_MAX_FUEL, 0.0, 1.0)
	return fuel

func is_lit() -> bool:
	if site != null and is_instance_valid(site) and site.has_method("lit"):
		return site.lit()
	return fuel > 0.0

func add_fuel(amount: float) -> void:
	if site != null and is_instance_valid(site) and site.has_method("add_fuel"):
		site.add_fuel(amount * Site.FIRE_MAX_FUEL)
	else:
		fuel = clampf(fuel + amount, 0.0, 1.0)

## Wolves will not come within this distance.
func radius() -> float:
	return 0.0 if not is_lit() else lerpf(5.0, MAX_RADIUS, clampf(level() * 1.5, 0.0, 1.0))

func _process(delta: float) -> void:
	_t += delta
	_find_t -= delta
	if _find_t <= 0.0 or (site != null and not is_instance_valid(site)):
		_find_t = 1.0
		_find_site()
	if site == null and fuel > 0.0:
		fuel = maxf(fuel - delta / 200.0, 0.0)
	_apply()

func _apply() -> void:
	var lit := is_lit()
	light.visible = lit
	if not lit:
		return
	var f := _noise.get_noise_1d(_t * 6.0) * 0.5 + _noise.get_noise_1d(_t * 17.0 + 40.0) * 0.25
	var strength := clampf(0.45 + level(), 0.45, 1.0)
	light.light_energy = (2.4 + f * 1.0) * strength
	light.omni_range = (MAX_RADIUS + 5.0) * (0.7 + 0.3 * strength)

func save_state() -> Dictionary:
	return {"fuel": fuel}

func load_state(d: Dictionary) -> void:
	fuel = d.get("fuel", 0.0)
	_find_site()
	_apply()
