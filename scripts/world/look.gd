class_name Look extends Node
## Light, sky, weather and the shared shader globals.
## Sun and moon follow Clock.day_fraction(); the season tints grass and leaves
## and winter whitens upward-facing ground; rain and lightning for storms;
## the era palette is fed to global shader parameters (hog_pal_0..3).

const MAX_SUN_ELEV := deg_to_rad(48.0)     # low sun, long shadows (section 12.2)
const MIN_SUN_ELEV := deg_to_rad(5.0)

## Era 1 palette (section 12.2): ochre, moss green, charcoal, firelight orange.
const ERA1_PALETTE := [Color(0.8, 0.58, 0.27), Color(0.38, 0.48, 0.22), Color(0.2, 0.19, 0.18), Color(1.0, 0.55, 0.2)]
const PALETTE_KEYS := [["ochre", "primary", "0"], ["moss", "moss_green", "secondary", "1"], ["charcoal", "dark", "2"], ["firelight", "fire", "light", "3"]]

const GRASS := [Color(0.36, 0.55, 0.23), Color(0.55, 0.55, 0.25), Color(0.6, 0.44, 0.2), Color(0.42, 0.43, 0.35)]
const LEAF := [Color(0.38, 0.62, 0.26), Color(0.3, 0.47, 0.2), Color(0.86, 0.45, 0.14), Color(0.4, 0.33, 0.26)]

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var flash: DirectionalLight3D
var rain: GPUParticles3D
var rain_mat: ParticleProcessMaterial
var rain_draw: StandardMaterial3D

var rain_target: float = 0.0       # 0..1, set by set_weather
var rain_amount: float = 0.0
var storm: bool = false
var frost_target: float = 0.0      # set by the cold snap
var frost: float = 0.0
var _flash_t: float = 0.0
var _next_bolt: float = 3.0
var _snow: float = 0.0
var _wet: float = 0.0
var _snowfall: bool = false

static var _registered := false

## Adds the hog_* global shader parameters once per run (unless the project
## settings already declare them).
static func register_globals() -> void:
	if _registered:
		return
	_registered = true
	var add := func(n: StringName, t: int, v) -> void:
		if not ProjectSettings.has_setting("shader_globals/" + str(n)):
			RenderingServer.global_shader_parameter_add(n, t, v)
	for i in 4:
		add.call(StringName("hog_pal_%d" % i), RenderingServer.GLOBAL_VAR_TYPE_COLOR, ERA1_PALETTE[i])
	add.call(&"hog_grass", RenderingServer.GLOBAL_VAR_TYPE_COLOR, GRASS[0])
	add.call(&"hog_leaf", RenderingServer.GLOBAL_VAR_TYPE_COLOR, LEAF[0])
	add.call(&"hog_snow", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	add.call(&"hog_frost", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	add.call(&"hog_wet", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	add.call(&"hog_wind", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.6)
	add.call(&"hog_map_rect", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(-Valley.HALF, -Valley.HALF, Valley.HALF * 2.0, Valley.HALF * 2.0))
	if not ProjectSettings.has_setting("shader_globals/hog_region_mask"):
		var img := Image.create(4, 4, false, Image.FORMAT_L8)
		img.fill(Color.WHITE)
		RenderingServer.global_shader_parameter_add(&"hog_region_mask", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, ImageTexture.create_from_image(img))

static func set_global(n: StringName, v) -> void:
	RenderingServer.global_shader_parameter_set(n, v)

func _ready() -> void:
	register_globals()
	_build_env()
	_build_lights()
	_build_rain()
	apply_era(Village.era)
	Events.era_changed.connect(apply_era)
	update_now()

func _build_env() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.16, 0.15, 0.13)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_blur = 1.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.shadow_enabled = false
	add_child(moon)
	flash = DirectionalLight3D.new()
	flash.name = "Lightning"
	flash.light_color = Color(0.8, 0.85, 1.0)
	flash.light_energy = 0.0
	flash.rotation_degrees = Vector3(-70, 20, 0)
	add_child(flash)

func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 2400
	rain.lifetime = 1.1
	rain.preprocess = 1.0
	rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 60, 80))
	rain_mat = ParticleProcessMaterial.new()
	rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_mat.emission_box_extents = Vector3(38, 1, 38)
	rain_mat.direction = Vector3(0.12, -1, 0.05)
	rain_mat.spread = 2.0
	rain_mat.initial_velocity_min = 26.0
	rain_mat.initial_velocity_max = 32.0
	rain_mat.gravity = Vector3(0, -12, 0)
	rain.process_material = rain_mat
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.9)
	rain_draw = StandardMaterial3D.new()
	rain_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_draw.albedo_color = Color(0.75, 0.82, 0.95, 0.35)
	rain_draw.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rain_draw.billboard_keep_scale = true
	q.material = rain_draw
	rain.draw_pass_1 = q
	rain.emitting = false
	add_child(rain)

## Weather: 0 = clear, 1 = downpour. A storm adds wind, dark sky and lightning.
func set_weather(rain_level: float, is_storm: bool = false) -> void:
	rain_target = clampf(rain_level, 0.0, 1.0)
	storm = is_storm

func raining() -> bool:
	return rain_target > 0.05

func apply_era(era_n: int) -> void:
	var e: EraDef = Defs.era(era_n)
	var pal: Array = ERA1_PALETTE.duplicate()
	if e != null and not e.palette.is_empty():
		var vals := e.palette.values()
		for i in 4:
			var found := false
			for key in PALETTE_KEYS[i]:
				if e.palette.has(key) or e.palette.has(StringName(key)):
					pal[i] = e.palette.get(key, e.palette.get(StringName(key)))
					found = true
					break
			if not found and i < vals.size() and vals[i] is Color:
				pal[i] = vals[i]
	for i in 4:
		set_global(StringName("hog_pal_%d" % i), pal[i])

func _process(delta: float) -> void:
	_update(delta)

## Applies the current time and season immediately (no easing). Used after load.
func update_now() -> void:
	rain_amount = rain_target
	frost = frost_target
	_wet = rain_target
	_update(0.0, true)

func _update(delta: float, snap: bool = false) -> void:
	var k := 1.0 if snap else minf(0.6 * delta, 1.0)
	rain_amount = lerpf(rain_amount, rain_target, k)
	frost = lerpf(frost, frost_target, 1.0 if snap else minf(0.15 * delta, 1.0))
	_wet = lerpf(_wet, rain_target, 1.0 if snap else minf((0.4 if rain_target > _wet else 0.05) * delta, 1.0))
	# ---- sun and moon
	var full := Clock.day_seconds + Clock.night_seconds
	var day_part := Clock.day_seconds / full
	var f := Clock.day_fraction()
	var light := 0.0         # 0 night .. 1 noon
	var warm := 0.0          # 1 at dawn/dusk
	if f < day_part:
		var u := f / day_part
		var s := sin(PI * u)
		var elev := lerpf(MIN_SUN_ELEV, MAX_SUN_ELEV, s)
		_aim(sun, u, elev, 0.55)
		light = Valley.ss(0.0, 0.22, s)
		warm = 1.0 - Valley.ss(0.15, 0.6, s)
		sun.light_energy = lerpf(0.0, 1.35, light)
		sun.light_color = Color(1.0, 0.6, 0.36).lerp(Color(1.0, 0.9, 0.76), 1.0 - warm)
		sun.visible = true
		moon.light_energy = lerpf(0.22, 0.0, Valley.ss(0.0, 0.2, s))
		_aim(moon, 1.0 - u, deg_to_rad(30.0), -0.4)
	else:
		var v := (f - day_part) / (1.0 - day_part)
		sun.light_energy = 0.0
		sun.visible = false
		_aim(moon, v, lerpf(deg_to_rad(15.0), deg_to_rad(55.0), sin(PI * v)), -0.4)
		moon.light_energy = 0.3 * (0.7 if storm else 1.0)
	var stormy := clampf(rain_amount * (1.3 if storm else 0.7), 0.0, 1.0)
	sun.light_energy *= 1.0 - stormy * 0.6
	# ---- sky, ambient and fog
	var night_top := Color(0.02, 0.035, 0.08)
	var night_hor := Color(0.07, 0.09, 0.16)
	var day_top := Color(0.33, 0.53, 0.8)
	var day_hor := Color(0.76, 0.8, 0.84)
	var dusk_hor := Color(0.98, 0.62, 0.4)
	var top := night_top.lerp(day_top, light)
	var hor := night_hor.lerp(day_hor.lerp(dusk_hor, warm), light)
	var grey := Color(0.36, 0.38, 0.42).lerp(Color(0.05, 0.06, 0.08), 1.0 - light)
	top = top.lerp(grey * 0.8, stormy)
	hor = hor.lerp(grey, stormy)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.15)
	sky_mat.ground_bottom_color = top.darkened(0.6)
	sky_mat.sun_curve = 0.08
	env.ambient_light_color = Color(0.2, 0.26, 0.42).lerp(Color(0.72, 0.74, 0.8).lerp(Color(0.9, 0.72, 0.6), warm * 0.5), light)
	env.ambient_light_energy = lerpf(0.55, 0.55, light) * (1.0 - stormy * 0.25)
	env.fog_light_color = hor
	env.fog_density = lerpf(0.0006, 0.0035, stormy) + (0.0005 if light < 0.2 else 0.0)
	env.fog_light_energy = lerpf(0.35, 1.0, light)
	env.background_energy_multiplier = lerpf(0.6, 1.0, light)
	# ---- lightning
	_flash_t = maxf(_flash_t - delta, 0.0)
	if storm and rain_amount > 0.4 and not snap:
		_next_bolt -= delta
		if _next_bolt <= 0.0:
			_next_bolt = Game.rng.randf_range(3.5, 9.0)
			_flash_t = 0.35
			Audio.sfx("res://assets/audio/sfx/thunder.ogg", Vector3.INF, Game.rng.randf_range(0.85, 1.1))
	var fl := 0.0
	if _flash_t > 0.0:
		fl = (_flash_t / 0.35) * (0.6 + 0.4 * sin(_flash_t * 90.0))
	flash.light_energy = fl * 2.2
	env.ambient_light_energy += fl * 0.8
	# ---- rain follows the camera
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	rain.emitting = rain_amount > 0.05
	rain.amount_ratio = clampf(rain_amount, 0.05, 1.0)
	if cam != null:
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		var at := cam.global_position + fwd.normalized() * 18.0
		var gy: float = Game.world.ground_y(at.x, at.z) if Game.world != null and Game.world.has_method("ground_y") else 0.0
		rain.global_position = Vector3(at.x, maxf(gy + 22.0, cam.global_position.y - 6.0), at.z)
	# ---- season
	var season := Clock.season
	var sf := clampf(Clock.season_fraction(), 0.0, 1.0)
	var t := Valley.ss(0.8, 1.0, sf)
	var nxt := (season + 1) % 4
	set_global(&"hog_grass", (GRASS[season] as Color).lerp(GRASS[nxt], t))
	set_global(&"hog_leaf", (LEAF[season] as Color).lerp(LEAF[nxt], t))
	var snow := 0.0
	if season == Clock.Season.WINTER:
		snow = Valley.ss(0.0, 0.25, sf) * 0.9
	elif season == Clock.Season.SPRING and Clock.year > 1:   # meltwater after a winter
		snow = (1.0 - Valley.ss(0.0, 0.2, sf)) * 0.9
	_snow = snow
	set_global(&"hog_snow", snow)
	set_global(&"hog_frost", frost)
	set_global(&"hog_wet", _wet)
	set_global(&"hog_wind", lerpf(0.6, 2.2, stormy))
	# winter rain falls as snow
	var winter := season == Clock.Season.WINTER
	if winter != _snowfall:
		_snowfall = winter
		rain_draw.albedo_color = Color(0.95, 0.97, 1.0, 0.8) if winter else Color(0.75, 0.82, 0.95, 0.35)
		rain_mat.initial_velocity_min = 3.0 if winter else 26.0
		rain_mat.initial_velocity_max = 5.0 if winter else 32.0
		rain_mat.gravity = Vector3(0, -2.5 if winter else -12.0, 0)
		rain.lifetime = 6.0 if winter else 1.1

func _aim(light_node: DirectionalLight3D, u: float, elev: float, south: float) -> void:
	# u: 0 = east horizon, 1 = west horizon; passes south (+z) when south > 0.
	var a := PI * u
	var s := Vector3(cos(a) * cos(elev), sin(elev), sin(a) * south * cos(elev)).normalized()
	light_node.basis = Basis.looking_at(-s, Vector3.UP)

func snow_cover() -> float:
	return _snow

## 0 at night .. 1 in full day, for other systems (wolves, people).
func daylight() -> float:
	return sun.light_energy / 1.35 if sun.visible else 0.0
