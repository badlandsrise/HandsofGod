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

var _fails := 0
var _checks := 0


func _init() -> void:
	await process_frame
	var ids := AssetCatalog.ids()
	_check(ids.size() >= REQUIRED.size(), "catalog has %d ids" % ids.size())
	for r in REQUIRED + REQUIRED_ERA2:
		_check(AssetCatalog.has(StringName(r)), "required id '%s' present" % r)
	for b in ERA2_STAGED:
		for stage in ["", "_plot", "_frame"]:
			var sid := StringName(b + stage)
			_check(AssetCatalog.has(sid) and int(AssetCatalog.entry(sid).get("era", 1)) == 2,
				"era 2 building stage '%s' present" % sid)
	_check(AssetCatalog.variant_count(&"cottage") >= 2 and AssetCatalog.variant_count(&"market_stall") >= 3,
		"era 2 cottages and market stalls have variants")
	# the moving parts the gameplay may drive
	_check_part(&"mill", "Sails")
	_check_part(&"kiln", "Wheel")
	_check_part(&"well", "Windlass")
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
	var size_ok := box.size.y > 0.05 and box.size.y < 25.0 and box.size.x < 40.0 and box.size.z < 40.0
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
	v.set_era(1)
	_check(v.get_node("Model").find_child("Hat", true, false) == null, "era 1 villagers have no hats")
	await process_frame
	v.set_age_scale(1)
	var child_h := _aabb(v, Transform3D.IDENTITY).size.y
	v.set_age_scale(2)
	var adult_h := _aabb(v, Transform3D.IDENTITY).size.y
	_check(child_h < adult_h * 0.8, "child (%.2f) smaller than adult (%.2f)" % [child_h, adult_h])
	v.free()


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
	if n is VisualInstance3D and not n is Light3D:
		out = t * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out
