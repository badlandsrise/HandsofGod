extends SceneTree
## Headless check of the art catalog: every id (and every variant / season) instances to a
## non-null visual with a sane bounding box, scene files exist, unknown ids fall back to a
## placeholder, and the villager visual answers its API.
##   godot --headless --path . -s res://tests/assets/test_catalog.gd
## Prints PASS/FAIL per check and exits 1 on any failure.

const REQUIRED := ["tree_pine", "tree_broad", "tree_dead", "bush", "berry_bush", "rock_small",
	"rock_large", "cliff", "grass_clump", "flowers", "log_fallen", "trunk_fallen", "stump",
	"campfire", "firewood_pile", "flint_node", "hut", "hut_plot", "food_store", "cairn", "shrine",
	"stone_circle", "cave_mouth", "deer", "wolf", "sheep", "horse", "villager"]
## Era 2 (Village) kit: buildings come as done / _plot / _frame (see ERA2_STAGED).
const REQUIRED_ERA2 := ["market_stall", "market_stall_frame", "charcoal_clamp", "jetty", "raft",
	"raft_frame", "rowboat", "fishing_boat", "field", "field_tilled", "field_sprouts",
	"field_growing", "field_ripe", "field_stubble", "field_blighted", "field_parched",
	"garden_plot", "sheaves", "haystack", "scarecrow", "grain_sacks", "flour_sacks",
	"bread_basket", "pots", "pots_unfired", "clay_pile", "planks_pile", "charcoal_pile",
	"ore_pile", "bronze_ingots", "wool_bales", "cloth_bolts", "barrels", "water_trough",
	"clay_pit", "copper_ore", "rockfall", "fence_wattle", "fence_wattle_gate", "handcart",
	"hay_wagon", "tool_axe_bronze", "tool_hoe", "tool_hammer", "tool_shovel",
	"tool_pickaxe_bronze", "tool_sickle", "tool_pitchfork", "cow", "pig", "crop_wheat",
	"era2_cottage"]
const ERA2_STAGED := ["cottage", "granary", "mill", "bakery", "kiln", "smelter", "smithy",
	"weaver", "workshop", "barn", "temple", "bridge", "well", "watchtower", "sheep_pen"]
## Era 3 (Town) kit: the same three stages for every building (ERA3_STAGED).
const REQUIRED_ERA3 := ["aqueduct_end", "road_paved", "road_paved_cross", "road_paved_end", "plaza",
	"street_lamp", "fountain", "town_flag", "banner_pole", "bench_iron", "planter", "pump",
	"notice_board", "statue_hand", "cart", "caravan_wagon", "fire_cart", "ship_small",
	"ship_merchant", "stone_blocks", "bricks_pile", "iron_ore_pile", "iron_bars", "books_pile",
	"paper_stack", "crates", "glassware", "fire_buckets", "quarry", "iron_ore", "tool_axe_iron",
	"tool_pickaxe_iron", "tool_mallet", "tool_chisel", "tool_saw", "tool_trowel"]
const ERA3_STAGED := ["townhouse", "great_hall", "market_hall", "clocktower", "school",
	"printing_house", "laboratory", "clinic", "fire_station", "forge", "mason", "windmill",
	"watermill", "observatory", "harbour", "lighthouse", "aqueduct"]
## Era 4 (Launch) kit: staged buildings (ERA4_STAGED; launch_tower is the shrine's last
## stage), the rocket in its build stages and segments, the city's streets, rail and works.
const REQUIRED_ERA4 := ["rocket_stage_1", "rocket_stage_2", "rocket", "rocket_ready",
	"rocket_segment_booster", "rocket_segment_tank", "rocket_segment_upper", "road_asphalt",
	"road_asphalt_cross", "road_asphalt_end", "rail_track", "rail_buffer", "rail_crossing",
	"rail_bridge", "street_light", "bus_stop", "phone_box", "kiosk", "bench_modern",
	"planter_modern", "fire_hydrant", "poster_board", "flag_mission", "power_pylon", "park",
	"water_tower", "cafe_parasol", "city_block_far", "car", "bus", "truck", "locomotive",
	"rail_wagon", "passenger_coach", "gift_model_rocket", "gift_photograph", "steel_beams",
	"parts_crates", "fuel_tanks", "coal_pile", "oil_drums", "cable_drum", "shipping_container",
	"coal_seam", "oil_seep", "tool_wrench", "tool_toolbox", "tool_clipboard", "tool_welder"]
const ERA4_STAGED := ["apartment", "powerhouse", "coal_mine", "foundry", "refinery", "factory",
	"assembly_hall", "institute", "mission_control", "radio_telescope", "training_centre",
	"rail_station", "test_stand", "wind_turbine", "launch_tower"]
## ids allowed to stand taller than 25 m: the launch tower and its gantry crane
const TALL := [&"launch_tower", &"launch_tower_frame"]

var _fails := 0
var _checks := 0


func _init() -> void:
	await process_frame
	var ids := AssetCatalog.ids()
	_check(ids.size() >= REQUIRED.size(), "catalog has %d ids" % ids.size())
	for r in REQUIRED + REQUIRED_ERA2 + REQUIRED_ERA3 + REQUIRED_ERA4:
		_check(AssetCatalog.has(StringName(r)), "required id '%s' present" % r)
	for b in ERA2_STAGED:
		for stage in ["", "_plot", "_frame"]:
			var sid := StringName(b + stage)
			_check(AssetCatalog.has(sid) and int(AssetCatalog.entry(sid).get("era", 1)) == 2,
				"era 2 building stage '%s' present" % sid)
	for b in ERA3_STAGED:
		for stage in ["", "_plot", "_frame"]:
			var sid := StringName(b + stage)
			_check(AssetCatalog.has(sid) and int(AssetCatalog.entry(sid).get("era", 1)) == 3,
				"era 3 building stage '%s' present" % sid)
	for r in REQUIRED_ERA3:
		_check(int(AssetCatalog.entry(StringName(r)).get("era", 1)) == 3, "era 3 id '%s' tagged era 3" % r)
	for b in ERA4_STAGED:
		for stage in ["", "_plot", "_frame"]:
			var sid := StringName(b + stage)
			_check(AssetCatalog.has(sid) and int(AssetCatalog.entry(sid).get("era", 1)) == 4,
				"era 4 building stage '%s' present" % sid)
	for r in REQUIRED_ERA4:
		_check(int(AssetCatalog.entry(StringName(r)).get("era", 1)) == 4, "era 4 id '%s' tagged era 4" % r)
	_check(AssetCatalog.variant_count(&"apartment") >= 3 and AssetCatalog.variant_count(&"car") >= 3
		and AssetCatalog.variant_count(&"rail_wagon") >= 4, "era 4 apartments, cars and wagons have variants")
	_check(AssetCatalog.variant_count(&"townhouse") >= 3 and AssetCatalog.variant_count(&"cart") >= 2,
		"era 3 townhouses and carts have variants")
	_check(AssetCatalog.variant_count(&"cottage") >= 2 and AssetCatalog.variant_count(&"market_stall") >= 3,
		"era 2 cottages and market stalls have variants")
	# the moving parts the gameplay may drive
	_check_part(&"mill", "Sails")
	_check_part(&"kiln", "Wheel")
	_check_part(&"well", "Windlass")
	for pair in [[&"windmill", "Sails"], [&"watermill", "Wheel"], [&"mason", "Wheel"], [&"clocktower", "Hands"],
			[&"observatory", "Dome"], [&"harbour", "Jib"], [&"lighthouse", "Beam"], [&"school", "Bell"],
			[&"fire_station", "Bell"], [&"coal_mine", "Wheels"], [&"mission_control", "Radar"],
			[&"radio_telescope", "Mount"], [&"training_centre", "Centrifuge"], [&"wind_turbine", "Rotor"]]:
		_check_part(pair[0], pair[1])
	_check_launch()
	# lights the gameplay switches on at dusk ship switched off
	for pair in [[&"street_lamp", "Light"], [&"lighthouse", "BeamLight"], [&"street_light", "Light"],
			[&"launch_tower", "Flood1"], [&"rocket_ready", "ExhaustLight"]]:
		var n := AssetCatalog.instance(pair[0])
		var l := n.find_child(pair[1], true, false) as Light3D
		_check(l != null and not l.visible, "%s has a hidden '%s' light" % pair)
		n.free()
	for lit in [&"apartment", &"institute", &"mission_control"]:   # lit windows wait for dusk
		var n := AssetCatalog.instance(lit)
		var g := n.find_child("NightGlow", true, false) as Node3D
		_check(g != null and not g.visible, "%s has a hidden NightGlow" % lit)
		n.free()
	for id in ids:
		var e := AssetCatalog.entry(StringName(id))
		var seasons: Dictionary = e.get("seasons", {})
		var sets := [["", e.get("variants", [])]]
		for s in seasons:
			sets.append([s, seasons[s]])
		for pair in sets:
			for v in (pair[1] as Array).size():
				_check_instance(StringName(id), v, StringName(pair[0]))
	# fallbacks
	var ph := AssetCatalog.instance(&"no_such_thing")
	_check(ph != null and ph.get_child_count() == 1 and String(ph.get_child(0).name).begins_with("Placeholder"),
		"unknown id gives a placeholder")
	ph.free()
	# era regrade does not break anything
	AssetCatalog.set_era(2)
	AssetCatalog.set_era(3)
	AssetCatalog.set_era(4)
	AssetCatalog.set_era(1)
	_check(ArtPalette.current_era() == 1, "era switch round-trips")
	await _check_villager()
	print("RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	quit(1 if _fails > 0 else 0)


func _check_instance(id: StringName, variant: int, season: StringName) -> void:
	var label := "%s[%d]%s" % [id, variant, ("/" + season) if season != &"" else ""]
	var path := AssetCatalog.scene_path(id, variant, season)
	_check(ResourceLoader.exists(path), "%s scene exists (%s)" % [label, path])
	var n := AssetCatalog.instance(id, variant, season)
	if n == null:
		_check(false, "%s instances" % label)
		return
	root.add_child(n)
	var placeholder := n.get_child_count() > 0 and String(n.get_child(0).name).begins_with("Placeholder")
	_check(not placeholder, "%s is real art, not a placeholder box" % label)
	var box := _aabb(n, Transform3D.IDENTITY)
	var fp := AssetCatalog.footprint(id)
	var size_ok := box.size.y > 0.05 and box.size.y < (36.0 if id in TALL else 25.0) and box.size.x < 40.0 and box.size.z < 40.0
	var ground_ok := box.position.y > -2.5 and box.position.y < 1.5
	var fp_ok := maxf(box.size.x, box.size.z) < maxf(fp.x, fp.y) * 3.0 + 2.0
	if id == &"villager":
		size_ok = size_ok and absf(box.size.y - 1.75) < 0.5   # ~1.7 m person (T-pose bounds)
	_check(size_ok and ground_ok and fp_ok, "%s AABB sane: size %s at %s (footprint %s)" % [label, _v(box.size), _v(box.position), fp])
	n.free()


func _check_villager() -> void:
	var v := (load("res://scenes/people/villager_visual.tscn") as PackedScene).instantiate() as VillagerVisual
	root.add_child(v)
	await process_frame
	for s in [&"idle", &"walk", &"run", &"carry", &"work", &"sit", &"wave", &"cheer", &"cower", &"held", &"fall", &"dead"]:
		v.play(s)
		_check(v.current_state() == s, "villager plays '%s'" % s)
	v.play(&"nonsense")
	_check(v.current_state() == &"idle", "villager falls back to idle")
	for o in 8:
		v.set_look(Color.BISQUE, Color.SADDLE_BROWN, Color("#7a5236"), o)
	for st in 4:
		v.set_age_scale(st)
	# Era 2 tailoring: woven clothes, hats on some outfits, back to hides for era 1
	v.set_era(2)
	var hats := 0
	for o in 8:
		v.set_look(Color.BISQUE, Color.SADDLE_BROWN, Color("#6b7f3a"), o)
		var model := v.get_node("Model")
		if model.find_child("Hat", true, false) != null:
			hats += 1
		var style: Variant = null
		for c in model.get_node("Armature/Skeleton3D").get_children():
			if c is MeshInstance3D and not c.has_meta("hair_piece") and String(c.name) not in ["Eyes", "Eyebrows"]:
				style = (c as MeshInstance3D).get_instance_shader_parameter(&"outfit_style")
		_check(style is Vector4 and (style as Vector4).x > 0.5, "era 2 outfit %d is woven (style %s)" % [o, style])
	_check(hats >= 3, "era 2 outfits include hats (%d of 8)" % hats)
	# Era 3 tailoring: town clothes (coats, bodices, aprons) and more hats
	v.set_era(3)
	hats = 0
	for o in 8:
		v.set_look(Color.BISQUE, Color.SADDLE_BROWN, Color("#3e5a78"), o)
		var model := v.get_node("Model")
		if model.find_child("Hat", true, false) != null:
			hats += 1
		var style: Variant = null
		for c in model.get_node("Armature/Skeleton3D").get_children():
			if c is MeshInstance3D and not c.has_meta("hair_piece") and String(c.name) not in ["Eyes", "Eyebrows"]:
				style = (c as MeshInstance3D).get_instance_shader_parameter(&"outfit_style")
		_check(style is Vector4 and (style as Vector4).x > 1.5, "era 3 outfit %d is tailored (style %s)" % [o, style])
	_check(hats >= 3, "era 3 outfits include hats (%d of 8)" % hats)
	# Era 4 tailoring: overalls, lab coats, suits and dresses; the crew's flight suits
	v.set_era(4)
	hats = 0
	for o in 8:
		v.set_look(Color.BISQUE, Color.SADDLE_BROWN, Color("#2f6f9a"), o)
		var model := v.get_node("Model")
		if model.find_child("Hat", true, false) != null:
			hats += 1
		var style: Variant = _outfit_style(v)
		_check(style is Vector4 and (style as Vector4).x > 2.5, "era 4 outfit %d is in Era 4 clothes (style %s)" % [o, style])
	_check(hats >= 3, "era 4 outfits include hats (%d of 8)" % hats)
	for o in 2:
		v.set_look(Color.BISQUE, Color.SADDLE_BROWN, Color("#2f6f9a"), o)
		v.set_crew(true)
		var style: Variant = _outfit_style(v)
		_check(style is Vector4 and absf((style as Vector4).y - 3.0) < 0.1 and v.get_node("Model").find_child("Hat", true, false) != null,
			"crew member %d wears the flight suit and helmet (style %s)" % [o, style])
		v.set_crew(false)
		_check(absf((_outfit_style(v) as Vector4).y - 3.0) > 0.1, "crew member %d back in their own clothes" % o)
	v.set_era(1)
	_check(v.get_node("Model").find_child("Hat", true, false) == null, "era 1 villagers have no hats")
	await process_frame
	v.set_age_scale(1)
	var child_h := _aabb(v, Transform3D.IDENTITY).size.y
	v.set_age_scale(2)
	var adult_h := _aabb(v, Transform3D.IDENTITY).size.y
	_check(child_h < adult_h * 0.8, "child (%.2f) smaller than adult (%.2f)" % [child_h, adult_h])
	v.free()


func _outfit_style(v: VillagerVisual) -> Variant:
	var style: Variant = null
	for c in v.get_node("Model/Armature/Skeleton3D").get_children():
		if c is MeshInstance3D and not c.has_meta("hair_piece") and String(c.name) not in ["Eyes", "Eyebrows"]:
			style = (c as MeshInstance3D).get_instance_shader_parameter(&"outfit_style")
	return style


## The launch hooks gameplay drives (DESIGN 9.2): the rocket's mount and the access arm
## on the tower, the crew bench seats, the floods; the steam and exhaust on rocket_ready.
func _check_launch() -> void:
	var t := AssetCatalog.instance(&"launch_tower")
	for part in ["RocketMount", "AccessArm", "Seat1", "Seat4", "Floods"]:
		_check(t.find_child(part, true, false) != null, "launch_tower has '%s'" % part)
	var m := t.find_child("RocketMount", true, false) as Node3D
	_check(m != null and m.position.y > 1.0, "launch_tower RocketMount sits on the pad")
	t.free()
	var r := AssetCatalog.instance(&"rocket_ready")
	var steam := r.find_child("Steam", true, false) as GPUParticles3D
	var exhaust := r.find_child("Exhaust", true, false) as GPUParticles3D
	_check(steam != null and steam.emitting, "rocket_ready vents steam")
	_check(exhaust != null and not exhaust.emitting and exhaust.get_parent().name == &"ExhaustHook",
		"rocket_ready exhaust waits on ExhaustHook")
	r.free()


func _check_part(id: StringName, part: String) -> void:
	var n := AssetCatalog.instance(id)
	var p := n.find_child(part, true, false) if n else null
	_check(p != null and p.get("spinning") != null, "%s has a '%s' spinner" % [id, part])
	if n:
		n.free()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _v(v: Vector3) -> String:
	return "(%.1f,%.1f,%.1f)" % [v.x, v.y, v.z]


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is VisualInstance3D and not n is Light3D and not n is GPUParticles3D:   # particles: visibility_aabb is generous
		out = t * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out
