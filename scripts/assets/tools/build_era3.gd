extends "res://scripts/assets/tools/build_era2.gd"
## Builds the Era 3 (Town) art kit: every scene in scenes/props/era3/ plus the Era 3
## library materials. Re-run after changing this file:
##   godot --headless --path . -s res://scripts/assets/tools/build_era3.gd [-- --only=townhouse,harbour]
##
## Reuses build_era2.gd's geometry helpers (same conventions: origin on the ground at the
## footprint centre, +Z is the front, metres; hand-made geometry merged into one mesh per
## material). Pack pieces: Quaternius MegaKit stone walls, glazed windows, balconies and
## iron railings; Kenney Pirate Kit sailing ships, crates and flags; Kenney Survival Kit
## tools and workbenches. Everything else (plaster upper floors, slate and tile roofs,
## the great hall, the clock tower, the observatory dome, the aqueduct...) is modelled here.
##
## The look moves on from Era 2's timber, daub and thatch to stone ground floors, painted
## plaster, red tile and blue slate roofs, iron and glass, with jewel-toned paintwork,
## flower boxes and banners: the same warm palette family, more refined and more colourful.
##
## Buildings come in three stages like Era 2: <id>_plot (pegged out, footing trench and the
## first cut stone), <id>_frame (masonry walls half up inside a timber scaffold with a
## hoist), <id>.

const OUT3 := "res://scenes/props/era3/"
const BOATS := "res://assets/models/boats/"
const SHIP := {"hog_pull": 0.12, "hog_sat": 0.35, "hog_tint": Color("#d8c8b0")}   # Kenney ships
const GLASS := {"hog_pull": 0.0}

var _jobs3: Dictionary = {}


func _init() -> void:
	if (get_script() as Script).resource_path != "res://scripts/assets/tools/build_era3.gd":
		return   # a subclass (build_era4.gd) reuses the helpers and runs its own jobs
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT3))
	_build_materials3()
	_jobs3 = {
		"townhouse": _townhouses, "great_hall": _great_hall, "forge": _forge, "mason": _mason,
		"printing_house": _printing_house, "school": _school, "clocktower": _clocktower,
		"harbour": _harbour, "lighthouse": _lighthouse, "windmill": _windmill, "watermill": _watermill,
		"observatory": _observatory, "aqueduct": _aqueduct, "laboratory": _laboratory,
		"market_hall": _market_hall, "clinic": _clinic, "fire_station": _fire_station,
		"roads": _roads, "street": _street_props, "carts3": _carts3, "ships": _ships,
		"piles3": _piles3, "nodes3": _nodes3, "tools3": _tools3,
	}
	for k in _jobs3:
		if _only.is_empty() or k in _only:
			(_jobs3[k] as Callable).call()
	print("build_era3: %d scenes" % _count)
	quit()


func _save(scene_name: String) -> void:
	_flush(_root, "Geometry")
	var ps := PackedScene.new()
	var err := ps.pack(_root)
	if err == OK:
		err = ResourceSaver.save(ps, OUT3 + scene_name + ".scn", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		print("  %s -> %s" % [scene_name, error_string(err)])
	_count += 1
	_root.free()


# ================================================================== materials

func _build_materials3() -> void:
	var era3 := false
	for mat_name in ArtPalette.NAMED:
		era3 = era3 or mat_name == "limestone"   # everything from "limestone" on is Era 3's
		if era3:
			_save_material(mat_name, ArtPalette.NAMED[mat_name], "res://assets/models/materials/%s.tres" % mat_name)
	for mat_name in ArtPalette.NAMED_TEXTURED:
		_save_material(mat_name, ArtPalette.NAMED_TEXTURED[mat_name], "res://assets/models/materials/%s.tres" % mat_name)
	# stained glass and lamp glass glow (unshaded, like the flames): jewel tones by day too
	for spec in [["glass_rose", "res://assets/textures/era3/glass_rose.png", Color(1, 1, 1)],
			["glass_lancet", "res://assets/textures/era3/glass_lancet.png", Color(1, 1, 1)],
			["lamp_glow", "", Color("#ffd27a")], ["beacon", "", Color("#fff1c4")]]:
		var m := StandardMaterial3D.new()
		m.resource_name = "hog_" + spec[0]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = spec[2]
		if spec[1] != "":
			m.albedo_texture = load(spec[1])
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		ResourceSaver.save(m, "res://assets/models/materials/%s.tres" % spec[0])


# ================================================================== shared Era 3 parts

## Stone ground floor from MegaKit modules (like _mk_walls), but glazed: every window hole
## gets its glass frame and painted shutters, every door hole a painted panelled door.
## sides: module names per side as in _mk_walls; paint = door and shutter colour.
func _stone_walls(nx: int, nz: int, sy: float, sides: Dictionary, paint := "paint_teal", corner := "Corner_Exterior_Brick") -> void:
	var hw := float(nx)
	var hd := float(nz)
	var specs := []
	var front: Array = sides.get("front", [])
	for i in front.size():
		specs.append([front[i], Vector3(-hw + 1 + 2 * i, 0, hd), 0.0])
	var back: Array = sides.get("back", [])
	for i in back.size():
		specs.append([back[i], Vector3(hw - 1 - 2 * i, 0, -hd), 180.0])
	var left: Array = sides.get("left", [])
	for i in left.size():
		specs.append([left[i], Vector3(-hw, 0, -hd + 1 + 2 * i), -90.0])
	var right: Array = sides.get("right", [])
	for i in right.size():
		specs.append([right[i], Vector3(hw, 0, hd - 1 - 2 * i), 90.0])
	for s in specs:
		var mod: String = s[0]
		var pos: Vector3 = s[1]
		var ry: float = s[2]
		_model(V + mod + ".gltf", pos, Vector3(0, ry, 0), Vector3(1, sy, 1), null, MK)
		_push(_xf(pos, ry, Vector3(1, sy, 1)))
		if mod.contains("Window_Wide_Round"):
			_model(V + "Window_Wide_Round1.gltf", Vector3.ZERO, Vector3.ZERO, 1.0, null, MK)
			_shutters(Vector3(0, 1.0, 0.1), 0.66, 1.62, paint, true)
		elif mod.contains("Window_Thin_Round"):
			_model(V + "Window_Thin_Round1.gltf", Vector3.ZERO, Vector3.ZERO, 1.0, null, MK)
		elif mod.contains("Window_Wide_Flat"):
			_model(V + "Window_Wide_Flat1.gltf", Vector3.ZERO, Vector3.ZERO, 1.0, null, MK)
			_shutters(Vector3(0, 0.98, 0.12), 0.78, 1.52, paint, false)
		elif mod.contains("Door_Round"):
			_door(Vector3(0, 0, -0.06), 1.06, 2.34, paint, true)
		elif mod.contains("Door_Flat"):
			_door(Vector3(0, 0, -0.06), 1.06, 2.12, paint, false)
		_pop()
	for c in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd)]:
		_model(V + corner + ".gltf", c, Vector3(0, _corner_rot(c), 0), Vector3(1, sy, 1), null, MK)
	_box("cave_dark", Vector3(0, 3.12 * sy * 0.5, 0), Vector3(hw * 2 - 0.7, 3.12 * sy - 0.1, hd * 2 - 0.7))


func _corner_rot(c: Vector3) -> float:
	if c.x > 0.0 and c.z > 0.0:
		return 0.0
	if c.x > 0.0:
		return 90.0
	if c.z < 0.0:
		return 180.0
	return -90.0


## Painted panelled door with brass ring; arched doors get a fanlight of glass above.
## c = bottom centre of the doorway in the wall's local frame (+Z out).
func _door(c: Vector3, w: float, h: float, m: String, arched: bool) -> void:
	var leaf_h := h - (w * 0.5 if arched else 0.0)
	_box(m, c + Vector3(0, leaf_h * 0.5, 0), Vector3(w, leaf_h, 0.08))
	for k in 2:   # raised panels
		_box(m, c + Vector3(0, leaf_h * (0.3 + 0.42 * k), 0.05), Vector3(w * 0.7, leaf_h * 0.3, 0.03))
	_ball("brass", c + Vector3(w * 0.3, leaf_h * 0.5, 0.08), 0.045, 6, 3)
	if arched:
		_push(_xf(c + Vector3(0, leaf_h, 0)))
		for k in 6:
			var a0 := PI * k / 6.0
			var a1 := PI * (k + 1) / 6.0
			_tri("glass_dark", Vector3.ZERO, Vector3(cos(a0), sin(a0), 0) * w * 0.5, Vector3(cos(a1), sin(a1), 0) * w * 0.5, Vector3.BACK)
			_beam(m, Vector3.ZERO, Vector3(cos(a0), sin(a0), 0) * w * 0.48, 0.035)
		_beam(m, Vector3(-w * 0.5, 0.02, 0.02), Vector3(w * 0.5, 0.02, 0.02), 0.06)
		_pop()


## A pair of open painted shutters either side of a window; c = bottom centre of the opening.
func _shutters(c: Vector3, half_w: float, h: float, m: String, arched: bool) -> void:
	for sx in [-1.0, 1.0]:
		var hinge := c + Vector3(sx * half_w, 0, 0)
		var leaf := 0.55 * (half_w / 0.66)
		var mid := hinge + Vector3(sx * (leaf * 0.5 + 0.03), h * 0.5, 0.06)
		_box(m, mid, Vector3(leaf, h, 0.05))
		for k in 3:   # louvre slats suggested by thin dark bars
			_box("iron", mid + Vector3(0, h * (k - 1) * 0.28, 0.03), Vector3(leaf * 0.8, 0.03, 0.01))
		if arched:
			pass


## Plaster upper floor shell on a w x d plan (centred), from y0 for h metres, jettied `out`
## beyond the walls below. wins: per side, one char per 2 m module: "W" wide window,
## "T" tall thin window, "B" window with a flower box, "-" blank. Limestone quoins at the
## corners and a string course at the floor line.
func _upper_floor(w: float, d: float, y0: float, h: float, m: String, wins: Dictionary, paint := "paint_teal", out := 0.15) -> void:
	var hw := w * 0.5 + out
	var hd := d * 0.5 + out
	var t := 0.24
	_box(m, Vector3(0, y0 + h * 0.5, hd - t * 0.5), Vector3(hw * 2, h, t))
	_box(m, Vector3(0, y0 + h * 0.5, -hd + t * 0.5), Vector3(hw * 2, h, t))
	_box(m, Vector3(hw - t * 0.5, y0 + h * 0.5, 0), Vector3(t, h, hd * 2 - 2 * t))
	_box(m, Vector3(-hw + t * 0.5, y0 + h * 0.5, 0), Vector3(t, h, hd * 2 - 2 * t))
	_box("cave_dark", Vector3(0, y0 + h * 0.5, 0), Vector3(hw * 2 - 0.3, h - 0.05, hd * 2 - 0.3))
	# string course and the jetty's underside
	_box("limestone", Vector3(0, y0 + 0.07, hd + 0.02), Vector3(hw * 2 + 0.12, 0.16, 0.12))
	_box("limestone", Vector3(0, y0 + 0.07, -hd - 0.02), Vector3(hw * 2 + 0.12, 0.16, 0.12))
	_box("limestone", Vector3(hw + 0.02, y0 + 0.07, 0), Vector3(0.12, 0.16, hd * 2 + 0.12))
	_box("limestone", Vector3(-hw - 0.02, y0 + 0.07, 0), Vector3(0.12, 0.16, hd * 2 + 0.12))
	# quoins
	for c in [Vector2(hw, hd), Vector2(-hw, hd), Vector2(hw, -hd), Vector2(-hw, -hd)]:
		var k := 0
		var y := y0 + 0.2
		while y < y0 + h - 0.2:
			var long := k % 2 == 0
			var sx := signf(c.x)
			var sz := signf(c.y)
			_box("limestone", Vector3(c.x - sx * (0.25 if long else 0.15), y + 0.15, c.y + sz * 0.015), Vector3(0.5 if long else 0.3, 0.28, 0.06))
			_box("limestone", Vector3(c.x + sx * 0.015, y + 0.15, c.y - sz * (0.15 if long else 0.25)), Vector3(0.06, 0.28, 0.3 if long else 0.5))
			y += 0.32
			k += 1
	# windows
	var sides := {"front": [0.0, hw * 2, hd], "back": [180.0, hw * 2, hd], "left": [-90.0, hd * 2, hw], "right": [90.0, hd * 2, hw]}
	for side in wins:
		var spec: String = wins[side]
		var sd: Array = sides[side]
		var ry: float = sd[0]
		var span: float = sd[1]
		var face: float = sd[2]
		var n := spec.length()
		for i in n:
			var ch := spec[i]
			if ch == "-":
				continue
			var x := -span * 0.5 + span * (i + 0.5) / n
			_push(_xf(Basis(Vector3.UP, deg_to_rad(ry)) * Vector3(x, 0, face), ry))
			var room := span * 0.5 - absf(x) - (0.42 if ch == "T" else 0.8)
			_window3(Vector3(0, y0 + maxf(0.0, (h - 3.0) * 0.5) - 0.2, 0.01), ch, paint, room > 0.62)
			_pop()


## One glazed window on a flat wall whose outer face is at local z = c.z (the pack's
## glass plane); shutters only where there is room for them beside the window.
func _window3(c: Vector3, kind: String, paint: String, shutters := true) -> void:
	var tall := kind == "T"
	_model(V + ("Window_Thin_Flat1.gltf" if tall else "Window_Wide_Flat1.gltf"), c, Vector3.ZERO, 1.0, null, MK)
	var hw := 0.42 if tall else 0.8
	_box("limestone", c + Vector3(0, 0.9, 0.16), Vector3(hw * 2 + 0.2, 0.08, 0.2))   # sill
	_box("limestone", c + Vector3(0, 2.58, 0.13), Vector3(hw * 2 + 0.16, 0.14, 0.12))   # lintel
	if shutters:
		_shutters(c + Vector3(0, 0.97, 0.12), hw + 0.02, 1.52, paint, false)
	if kind == "B":
		_flower_box(c + Vector3(0, 0.78, 0.32), hw * 2 - 0.1)


func _flower_box(c: Vector3, l: float) -> void:
	_box("wood_dark", c, Vector3(l, 0.2, 0.26))
	var cols := ["cloth_red", "plaster_rose", "cloth_gold", "cloth_plum", "linen"]
	var n := int(l / 0.16)
	for i in n:
		var p := c + Vector3(-l * 0.5 + l * (i + 0.5) / n, 0.12, _rng.randf_range(-0.06, 0.06))
		_ball("leaf", p, 0.1, 5, 3, Vector3(1, 0.8, 1))
		if i % 2 == 0:
			_ball(cols[(i / 2 + int(c.x * 3.0)) % cols.size()], p + Vector3(0, 0.09, 0.04), 0.06, 5, 3)


## Gable wall triangle at x (ridge along local x), plaster with a limestone coping.
func _gable3(m: String, x: float, half_d: float, y0: float, peak: float, thick := 0.24) -> void:
	var s := signf(x)
	var A := Vector3(x, y0, half_d)
	var B := Vector3(x, y0, -half_d)
	var C := Vector3(x, y0 + peak, 0)
	var o := Vector3(thick * 0.5 * s, 0, 0)
	_tri(m, A + o, B + o, C + o, Vector3(s, 0, 0))
	_tri(m, A - o, B - o, C - o, Vector3(-s, 0, 0))
	_quad(m, A + o, B + o, B - o, A - o, Vector3.DOWN)


## A brick chimney stack with a limestone cap and two pots.
func _chimney(base: Vector3, h: float, w := 0.7) -> void:
	_box("brick", base + Vector3(0, h * 0.5, 0), Vector3(w, h, w * 0.75))
	_box("limestone", base + Vector3(0, h + 0.06, 0), Vector3(w + 0.14, 0.12, w * 0.75 + 0.14))
	for sx in [-0.16, 0.16]:
		_cyl("terracotta", base + Vector3(sx * w / 0.7, h + 0.12, 0), 0.09, 0.08, 0.32, 7)


## Roof over a w x d plan, ridge along x (rot_y 90 turns it front-to-back), with gable walls
## of plaster m when hip = 0. Returns the ridge height.
func _roof3(roof_m: String, w: float, d: float, wall_top: float, pitch_h: float, over: float, hip: float, gable_m := "", rot_y := 0.0) -> float:
	_push(_xf(Vector3.ZERO, rot_y))
	var e := _eave(d, over, pitch_h, wall_top)
	_roof(roof_m, w + (0.4 if hip < 0.01 else 0.0), d, e, pitch_h, over, hip, 0.16, "terracotta" if roof_m == "roof_tiles" else "slate_flat", false)
	var ridge_y := e + pitch_h
	# a rolled ridge
	var r := clampf(hip, 0.0, 1.0) * (d * 0.5 + over)
	var rx := w * 0.5 + over + (0.2 if hip < 0.01 else 0.0) - r
	_rod("terracotta" if roof_m == "roof_tiles" else "slate_flat", Vector3(-rx - 0.05, ridge_y - 0.04, 0), Vector3(rx + 0.05, ridge_y - 0.04, 0), 0.1, 6)
	if hip < 0.01 and gable_m != "":
		var peak := ridge_y - wall_top - 0.22
		_gable3(gable_m, w * 0.5, d * 0.5, wall_top, peak)
		_gable3(gable_m, -w * 0.5, d * 0.5, wall_top, peak)
	_pop()
	return ridge_y


## Hanging shop sign on an iron bracket; sym picks the painted symbol.
func _shop_sign(p: Vector3, rot_y: float, m: String, sym: String) -> void:
	_push(_xf(p, rot_y))
	_beam("iron", Vector3(0, 0, 0), Vector3(0, 0, 0.95), 0.05)
	_beam("iron", Vector3(0, -0.35, 0), Vector3(0, -0.02, 0.6), 0.03)
	for z in [0.3, 0.75]:
		_beam("iron", Vector3(0, 0, z), Vector3(0, -0.12, z), 0.02)
	_box(m, Vector3(0, -0.45, 0.52), Vector3(0.06, 0.62, 0.62))
	_box("brass", Vector3(0, -0.45, 0.52), Vector3(0.07, 0.66, 0.05))
	match sym:
		"bread":
			for sx in [-1.0, 1.0]:
				_ball("bread", Vector3(sx * 0.05, -0.45, 0.52), 0.14, 6, 3, Vector3(0.5, 0.6, 1.0))
		"book":
			for sx in [-1.0, 1.0]:
				_box("paper", Vector3(sx * 0.045, -0.45, 0.52), Vector3(0.03, 0.34, 0.42))
		"hand":
			for sx in [-1.0, 1.0]:
				_hand_symbol("hand_gold", Vector3(sx * 0.035, -0.47, 0.52), Vector3(sx, 0, 0), Vector3.UP, 0.32, 0.01)
		"mortar":
			for sx in [-1.0, 1.0]:
				_lathe("brass", Vector3(sx * 0.05, -0.62, 0.52), [Vector2(0.1, 0), Vector2(0.16, 0.18), Vector2(0.0, 0.18)], 7, Vector3(0, 0, 0), Vector3(0.3, 1, 1))
		"anvil":
			for sx in [-1.0, 1.0]:
				_box("iron", Vector3(sx * 0.045, -0.48, 0.52), Vector3(0.03, 0.14, 0.4))
				_box("iron", Vector3(sx * 0.045, -0.6, 0.52), Vector3(0.03, 0.16, 0.18))
	_pop()


## Wall lantern / street lamp head: iron cage round a warm glowing glass.
func _lantern(p: Vector3, s := 1.0) -> void:
	_box("lamp_glow", p + Vector3(0, 0.0, 0), Vector3(0.22, 0.3, 0.22) * s)
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_beam("iron", p + Vector3(c.x * 0.12, -0.17, c.y * 0.12) * s, p + Vector3(c.x * 0.12, 0.17, c.y * 0.12) * s, 0.025 * s)
	_lathe("iron", p + Vector3(0, 0.16, 0) * s, [Vector2(0.2, 0), Vector2(0.03, 0.18), Vector2(0.0, 0.2)], 4, Vector3(0, 45, 0), Vector3.ONE * s)
	_box("iron", p + Vector3(0, -0.18, 0) * s, Vector3(0.28, 0.04, 0.28) * s)


## Banner hanging from a wall bracket or pole: jewel cloth, gold fringe, the hand in gold.
func _banner(top: Vector3, rot_y: float, m: String, h := 1.6, w := 0.7) -> void:
	_push(_xf(top, rot_y))
	_beam("iron", Vector3(-w * 0.6, 0, 0.05), Vector3(w * 0.6, 0, 0.05), 0.04)
	_quad(m, Vector3(-w * 0.5, 0, 0.08), Vector3(w * 0.5, 0, 0.08), Vector3(w * 0.5, -h, 0.08), Vector3(-w * 0.5, -h, 0.08), Vector3(0, 0, 1))
	_tri(m, Vector3(-w * 0.5, -h, 0.08), Vector3(w * 0.5, -h, 0.08), Vector3(0, -h - w * 0.4, 0.08), Vector3(0, 0, 1))
	_box("cloth_gold", Vector3(0, -0.06, 0.09), Vector3(w, 0.08, 0.01))
	_hand_symbol("hand_gold", Vector3(0, -h * 0.5, 0.1), Vector3(0, 0, 1), Vector3.UP, w * 0.55, 0.012)
	_pop()


## Era 3 plot: tamped earth, pegs and string, a footing trench started, cut stone and bricks.
func _plot3(w: float, d: float, round_plot := false) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	if round_plot:
		_cyl("dirt", Vector3.ZERO, hw + 0.4, hw + 0.35, 0.05, 16)
	else:
		_box("dirt", Vector3(0, 0.025, 0), Vector3(w + 0.6, 0.05, d + 0.6))
	var cs := [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd)]
	for c in cs:
		_box("wood", c + Vector3(0, 0.32, 0), Vector3(0.08, 0.64, 0.08), Vector3(0, 20, 0))
	for i in 4:
		_beam("rope", (cs[i] as Vector3) + Vector3(0, 0.5, 0), (cs[(i + 1) % 4] as Vector3) + Vector3(0, 0.5, 0), 0.025)
	# a dug footing trench along the front, the first course of dressed stone along one side
	_box("soil_dark", Vector3(0, 0.055, hd), Vector3(w, 0.02, 0.5))
	var x := -hw + 0.3
	while x < hw * 0.2:
		_box("ashlar", Vector3(x, 0.17, hd), Vector3(0.58, 0.3, 0.42))
		x += 0.62
	_stone_pile(Vector3(hw + 1.1, 0, hd * 0.4), 1.0)
	_model(V + "Prop_Brick1.gltf", Vector3(hw + 1.0, 0, -hd * 0.5), Vector3(0, 80, 0), 1.0, null, MK)
	_model(K + "resource-planks.glb", Vector3(-hw - 1.0, 0, -hd * 0.3), Vector3(0, 90, 0), 5.0, null, KEN)
	_model(K + "tool-shovel.glb", Vector3(-hw - 0.4, 0, hd + 0.2), Vector3(0, 30, 75), 3.5, null, KEN)


## Neat stack of dressed stone blocks.
func _stone_pile(c: Vector3, s := 1.0) -> void:
	for layer in 3:
		for i in 3 - layer:
			_box("ashlar", c + Vector3((i - (2 - layer) * 0.5) * 0.62, 0.17 + layer * 0.34, (layer % 2) * 0.05) * s, Vector3(0.58, 0.32, 0.44) * s,
				Vector3(0, _rng.randf_range(-4, 4), 0))


## Era 3 frame: walls half built in stone, a timber scaffold with putlogs and plank decks,
## a ladder, a gin-pole hoist lifting a block, stone and mortar waiting.
func _frame3(w: float, d: float, wall_h: float, built := 0.45, stone := "town_stone") -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	_box("dirt", Vector3(0, 0.025, 0), Vector3(w + 1.4, 0.05, d + 1.4))
	var h := wall_h * built
	var t := 0.4
	# ragged tops: each wall in a few steps
	for side in 4:
		var horiz := side < 2
		var len := w if horiz else d - t * 2
		var steps := maxi(2, int(len / 1.5))
		for k in steps:
			var sh := h * (1.0 - 0.25 * float((k + side) % 3) / 2.0)
			var u := -len * 0.5 + len * (k + 0.5) / steps
			var c := Vector3(u, sh * 0.5, hd - t * 0.5) if side == 0 else Vector3(u, sh * 0.5, -hd + t * 0.5)
			if side == 2:
				c = Vector3(hw - t * 0.5, sh * 0.5, u)
			elif side == 3:
				c = Vector3(-hw + t * 0.5, sh * 0.5, u)
			_box(stone, c, Vector3(len / steps + 0.01, sh, t) if horiz else Vector3(t, sh, len / steps + 0.01))
	_box("soil_dark", Vector3(0, 0.06, 0), Vector3(w - t * 2, 0.04, d - t * 2))
	# scaffold along the front and one side: standards, ledgers, putlogs and plank decks
	var sx := hw + 0.9
	var sz := hd + 0.9
	var top := minf(wall_h + 0.5, h + 2.6)
	var xs := []
	var n := maxi(2, int(w / 2.0))
	for i in n + 1:
		xs.append(-hw - 0.5 + (w + 1.0) * i / n)
	for x in xs:
		for z in [hd + 0.35, sz]:
			_rod("wood", Vector3(x, 0, z), Vector3(x, top, z), 0.06, 5)
	for y in [h * 0.5 + 0.3, h + 0.3]:
		for z in [hd + 0.35, sz]:
			_beam("wood", Vector3(-hw - 0.6, y, z), Vector3(hw + 0.6, y, z), 0.08)
		for x in xs:
			_beam("wood_dark", Vector3(x, y + 0.05, hd - 0.1), Vector3(x, y + 0.05, sz + 0.1), 0.06)
		_box("planks", Vector3(0, y + 0.12, (hd + 0.35 + sz) * 0.5), Vector3(w + 1.0, 0.06, sz - hd - 0.3))
	for i in n:   # diagonal braces
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		_beam("wood", Vector3(x0, 0.1, sz + 0.06), Vector3(x1, h + 0.3, sz + 0.06), 0.05)
	_ladder(Vector3(hw + 0.4, 0, sz + 1.4), Vector3(hw + 0.4, h + 0.4, sz + 0.1), 0.5)
	# gin pole hoist on the far corner lifting a block
	var gp := Vector3(-hw - 1.2, 0, -hd * 0.3)
	_rod("wood", gp, gp + Vector3(0.6, top + 1.2, 0), 0.1, 6)
	_beam("wood", gp + Vector3(0.5, top + 1.0, 0), gp + Vector3(1.6, top + 0.9, 0), 0.08)
	_rod("rope", gp + Vector3(1.55, top + 0.9, 0), gp + Vector3(1.55, h + 0.6, 0), 0.02, 4)
	_box("ashlar", gp + Vector3(1.55, h + 0.4, 0), Vector3(0.55, 0.32, 0.4))
	_cyl("wood_dark", gp + Vector3(0.3, 0.6, -0.3), 0.18, 0.18, 0.5, 8, Vector3(90, 0, 0))   # windlass drum
	_stone_pile(Vector3(hw + 1.6, 0, -hd * 0.4), 1.0)
	_lathe("wood_dark", Vector3(-hw - 0.9, 0, hd + 1.0), [Vector2(0.4, 0), Vector2(0.45, 0.3), Vector2(0.4, 0.3), Vector2(0.35, 0.05)], 9)   # mortar tub
	_lathe("stone_light", Vector3(-hw - 0.9, 0.06, hd + 1.0), [Vector2(0.37, 0.18), Vector2(0, 0.18)], 9)


# ================================================================== townhouses

func _townhouses() -> void:
	# A: merchant's house, gable to the street: stone shop floor, two ochre plaster floors,
	# tile roof, teal shutters, flower boxes, a shop sign and a lamp.
	_begin("townhouse_a")
	_stone_walls(2, 3, 1.0, {
		"front": ["Wall_UnevenBrick_Window_Wide_Round", "Wall_UnevenBrick_Door_Round"],
		"back": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Door_Flat"],
		"left": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Straight"],
		"right": ["Wall_UnevenBrick_Window_Wide_Flat", "Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round"]}, "paint_teal")
	var y1 := 3.12
	_upper_floor(4.0, 6.0, y1, 2.8, "plaster_ochre", {"front": "BB", "back": "W-", "left": "-W-", "right": "W-W"}, "paint_teal")
	_upper_floor(4.0, 6.0, y1 + 2.8, 2.6, "plaster_ochre", {"front": "WW", "back": "-W", "left": "-T-", "right": "-T-"}, "paint_teal", 0.15)
	var wall_top := y1 + 5.4
	_roof3("roof_tiles", 6.3, 4.3, wall_top, 3.0, 0.45, 0.0, "plaster_ochre", 90)
	_push(_xf(Vector3(0, wall_top, 3.16)))
	_model(V + "Window_Thin_Flat1.gltf", Vector3(0, -0.9, -0.09), Vector3.ZERO, Vector3(0.8, 0.8, 1), null, MK)
	_pop()
	_chimney(Vector3(1.2, wall_top + 0.6, -1.6), 2.6)
	_shop_sign(Vector3(1.6, 2.95, 3.15), 0, "paint_teal", "bread")
	_lantern(Vector3(-1.0, 2.55, 3.45))
	_beam("iron", Vector3(-1.0, 2.75, 3.1), Vector3(-1.0, 2.75, 3.45), 0.04)
	_bench(Vector3(-1.2, 0, 3.9), 0, 1.2, 0.45, 0.4)
	_model(K + "barrel.glb", Vector3(2.45, 0, 2.6), Vector3.ZERO, 3.2, null, KEN)
	_save("townhouse_a")

	# B: wide house with the ridge along the street: stone ground floor, a rose plaster upper
	# floor with an iron balcony, a blue slate hipped roof with a dormer and a brick chimney.
	_begin("townhouse_b")
	_stone_walls(3, 2, 1.0, {
		"front": ["Wall_UnevenBrick_Window_Wide_Flat", "Wall_UnevenBrick_Door_Round", "Wall_UnevenBrick_Window_Wide_Flat"],
		"back": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Straight"],
		"left": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round"],
		"right": ["Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Straight"]}, "paint_blue")
	_upper_floor(6.0, 4.0, y1, 2.9, "plaster_rose", {"front": "WTW", "back": "W-W", "left": "-W", "right": "W-"}, "paint_blue", 0.1)
	_model(V + "Balcony_Cross_Straight.gltf", Vector3(0, y1 + 0.06, 1.15), Vector3.ZERO, Vector3(1.0, 1.0, 1.0), null, MK)
	wall_top = y1 + 2.9
	_roof3("slate", 6.2, 4.2, wall_top, 2.6, 0.4, 0.55)
	_push(_xf(Vector3(1.6, wall_top - 0.15, 0.6)))
	_model(V + "Roof_Dormer_RoundTile.gltf", Vector3.ZERO, Vector3(0, -90, 0), Vector3(0.8, 0.8, 0.8), null, MK)
	_pop()
	_chimney(Vector3(-2.0, wall_top + 0.5, -0.6), 2.8, 0.8)
	_chimney(Vector3(2.0, wall_top + 0.5, -0.6), 2.4, 0.7)
	_flower_box(Vector3(-2.0, 0.95, 2.35), 1.4)
	_flower_box(Vector3(2.0, 0.95, 2.35), 1.4)
	_lantern(Vector3(-0.85, 2.55, 2.45))
	_beam("iron", Vector3(-0.85, 2.75, 2.1), Vector3(-0.85, 2.75, 2.45), 0.04)
	_save("townhouse_b")

	# C: tall narrow corner house: three sky-blue floors on a stone base, a steep tile roof
	# hipped at the back, a carved bay window, a banner with the hand.
	_begin("townhouse_c")
	_stone_walls(2, 2, 1.0, {
		"front": ["Wall_UnevenBrick_Door_Round", "Wall_UnevenBrick_Window_Wide_Round"],
		"back": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Straight"],
		"left": ["Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Straight"],
		"right": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Wide_Round"]}, "paint_red")
	_upper_floor(4.0, 4.0, y1, 2.7, "plaster_sky", {"front": "BW", "back": "-W", "left": "W-", "right": "-B"}, "paint_red")
	_upper_floor(4.0, 4.0, y1 + 2.7, 2.6, "plaster_sky", {"front": "TT", "back": "W-", "left": "-W", "right": "W-"}, "paint_red", 0.2)
	wall_top = y1 + 5.3
	_roof3("roof_tiles", 4.5, 4.5, wall_top, 3.4, 0.4, 0.0, "plaster_sky")
	_chimney(Vector3(-1.4, wall_top + 0.4, -1.4), 3.2)
	_banner(Vector3(2.45, y1 + 2.4, 1.2), 90, "cloth_plum", 1.8, 0.7)
	_model(K + "barrel.glb", Vector3(2.55, 0, 1.7), Vector3.ZERO, 3.0, null, KEN)
	_model(BOATS + "crate.glb", Vector3(-2.6, 0, 1.6), Vector3(0, 20, 0), 0.9, null, SHIP)
	_save("townhouse_c")

	_begin("townhouse_plot")
	_plot3(6.0, 6.0)
	_save("townhouse_plot")
	_begin("townhouse_frame")
	_frame3(6.0, 6.0, 5.5, 0.5)
	_save("townhouse_frame")



# ================================================================== stone, glass and spires

## A pointed (lancet) window facing +Z with its base centre at c: stained glass (glass_lancet)
## in a limestone surround. w wide, h tall to the point.
func _lancet(c: Vector3, w: float, h: float, glass := "glass_lancet") -> void:
	var hw := w * 0.5
	var rect_h := h - w * 0.75
	var z := c.z + 0.02
	_quad(glass, Vector3(c.x - hw, c.y, z), Vector3(c.x + hw, c.y, z), Vector3(c.x + hw, c.y + rect_h, z), Vector3(c.x - hw, c.y + rect_h, z),
		Vector3.BACK, [Vector2(0, 1), Vector2(1, 1), Vector2(1, w * 0.75 / h), Vector2(0, w * 0.75 / h)])
	# pointed head: two arcs meeting at the apex, fanned from the springing line centre
	var pts := []
	for k in 5:
		var t := float(k) / 4.0
		var a := t * PI / 3.0   # arc of radius w centred on the far springing point
		pts.append(Vector2(-hw + w - w * cos(a), w * sin(a)))
	var right := []
	for k in range(4, -1, -1):
		var p: Vector2 = pts[k]
		right.append(Vector2(-p.x, p.y))
	var outline: Array = pts + right.slice(1)
	var top := w * sin(PI / 3.0)
	for i in outline.size() - 1:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[i + 1]
		var A := Vector3(c.x + a.x, c.y + rect_h + a.y * (w * 0.75 / top), z)
		var B := Vector3(c.x + b.x, c.y + rect_h + b.y * (w * 0.75 / top), z)
		var C := Vector3(c.x, c.y + rect_h, z)
		_tri(glass, C, A, B, Vector3.BACK, _lan_uv(C, c, w, h), _lan_uv(A, c, w, h), _lan_uv(B, c, w, h))
		_beam("limestone", A + Vector3(0, 0, 0.03), B + Vector3(0, 0, 0.03), 0.14)
	for sx in [-1.0, 1.0]:
		_beam("limestone", Vector3(c.x + sx * (hw + 0.04), c.y - 0.05, z + 0.03), Vector3(c.x + sx * (hw + 0.04), c.y + rect_h, z + 0.03), 0.14)
	_box("limestone", Vector3(c.x, c.y - 0.08, z + 0.06), Vector3(w + 0.36, 0.12, 0.22))


func _lan_uv(p: Vector3, c: Vector3, w: float, h: float) -> Vector2:
	return Vector2((p.x - c.x) / w + 0.5, 1.0 - (p.y - c.y) / h)


## Round stained-glass window (the hand at its centre) facing +Z, centre c, radius r.
func _rose(c: Vector3, r: float) -> void:
	var seg := 20
	_face_disc("glass_rose", c, r, seg)
	_lathe("limestone", c, [Vector2(r + 0.3, 0), Vector2(r + 0.3, 0.2), Vector2(r - 0.02, 0.2), Vector2(r - 0.02, 0.0)], seg, Vector3(90, 0, 0))


## A textured disc facing +Z (the texture's circle fills it): rose windows, clock faces.
func _face_disc(m: String, c: Vector3, r: float, seg := 20) -> void:
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var A := c + Vector3(cos(a0), sin(a0), 0) * r
		var B := c + Vector3(cos(a1), sin(a1), 0) * r
		_tri(m, c, A, B, Vector3.BACK, Vector2(0.5, 0.5), Vector2(0.5 + cos(a0) * 0.5, 0.5 - sin(a0) * 0.5),
			Vector2(0.5 + cos(a1) * 0.5, 0.5 - sin(a1) * 0.5))


## Stepped buttress against a wall: foot at p, standing out along `out`, h tall.
func _buttress(p: Vector3, out: Vector3, h: float, m := "ashlar_warm") -> void:
	var o := out.normalized()
	var side := o.cross(Vector3.UP)
	var b := Basis(side, Vector3.UP, o)
	_box_b(m, p + o * 0.45 + Vector3(0, h * 0.3, 0), Vector3(0.7, h * 0.6, 0.9), b)
	_box_b(m, p + o * 0.3 + Vector3(0, h * 0.75, 0), Vector3(0.6, h * 0.32, 0.6), b)
	_box_b("limestone", p + o * 0.72 + Vector3(0, h * 0.6 + 0.05, 0), Vector3(0.74, 0.1, 0.45), b * Basis(Vector3.RIGHT, 0.5))
	_lathe("slate_flat", p + o * 0.3 + Vector3(0, h * 0.91, 0), [Vector2(0.3, 0), Vector2(0.0, 1.1)], 4, Vector3(0, 45, 0))
	_ball("brass", p + o * 0.3 + Vector3(0, h * 0.91 + 1.12, 0), 0.07, 5, 3)


## Square spire / pyramid roof of material m on a w square at height y, apex at y + h,
## crowned by the gilded open hand.
func _spire(c: Vector3, w: float, h: float, m := "slate", hand := true) -> void:
	var hw := w * 0.5
	var apex := c + Vector3(0, h, 0)
	var corners := [Vector3(-hw, 0, hw), Vector3(hw, 0, hw), Vector3(hw, 0, -hw), Vector3(-hw, 0, -hw)]
	for i in 4:
		var a: Vector3 = c + corners[i]
		var b: Vector3 = c + corners[(i + 1) % 4]
		var mid := (a + b) * 0.5 - c
		var out := mid.normalized() * h + Vector3(0, hw, 0)
		var sl := sqrt(h * h + hw * hw)
		_tri(m, a, b, apex, out, Vector2(-hw * 0.5, 0), Vector2(hw * 0.5, 0), Vector2(0, -sl / 1.6))
	_rod("brass", apex - Vector3(0, 0.4, 0), apex + Vector3(0, 0.9, 0), 0.05, 6)
	_ball("brass", apex + Vector3(0, 0.15, 0), 0.14, 7, 4)
	if hand:
		_hand_symbol("hand_gold", apex + Vector3(0, 1.3, 0), Vector3(0, 0, 1), Vector3.UP, 0.9, 0.06)
		_hand_symbol("hand_gold", apex + Vector3(0, 1.3, -0.06), Vector3(0, 0, -1), Vector3.UP, 0.9, 0.06)


## Low iron railing along a path of points (posts, two rails, finials).
func _railing(pts: Array, h := 0.9, closed := false) -> void:
	var n := pts.size()
	for i in (n if closed else n - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		_beam("iron", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.04)
		_beam("iron", a + Vector3(0, 0.12, 0), b + Vector3(0, 0.12, 0), 0.035)
		var l := a.distance_to(b)
		var k := int(l / 0.16)
		for j in k + 1:
			var p := a.lerp(b, float(j) / maxf(k, 1))
			_beam("iron", p, p + Vector3(0, h + 0.1, 0), 0.02)
			if j % 4 == 0:
				_lathe("brass", p + Vector3(0, h + 0.1, 0), [Vector2(0.035, 0), Vector2(0.0, 0.1)], 4)


## The Era 1 shrine stone, carried through every era (DESIGN 7).
func _shrine_stone(p: Vector3, rot_y := 15.0) -> void:
	_model(N + "Rock_1.fbx", p, Vector3(0, rot_y, 0), Vector3(1.6, 1.7, 1.2), null, {"hog_pull": 0.3})
	_hand_symbol("red_ochre", p + Vector3(0, 1.25, 0.62), Vector3(0, 0.15, 1), Vector3.UP, 0.42, 0.03)


# ================================================================== the Great Hall of the Hand (Era 3 shrine stage)

func _great_hall() -> void:
	_begin("great_hall")
	_hall_plinth()
	var py := 0.6
	var wall_h := 8.0
	_push(_xf(Vector3(0, py, -2.0)))
	# nave: warm ashlar walls, four lancets a side between stepped buttresses
	for sx in [-1.0, 1.0]:
		_box("ashlar_warm", Vector3(sx * 3.7, wall_h * 0.5, 0), Vector3(0.6, wall_h, 14.0))
		for k in 4:
			var z := -5.25 + k * 3.5
			_push(_xf(Vector3(sx * 4.0, 0, z), 90.0 * sx))
			_lancet(Vector3(0, 2.0, 0), 1.3, 4.6)
			_pop()
		for k in 5:
			_buttress(Vector3(sx * 4.0, 0, -7.0 + k * 3.5), Vector3(sx, 0, 0), wall_h - 0.4)
	_box("ashlar_warm", Vector3(0, wall_h * 0.5, -7.0), Vector3(8.0, wall_h, 0.6))
	_box("cave_dark", Vector3(0, wall_h * 0.5, 0), Vector3(6.9, wall_h - 0.2, 13.6))
	_box("limestone", Vector3(-3.95, wall_h - 0.1, 0), Vector3(0.3, 0.2, 14.2))
	_box("limestone", Vector3(3.95, wall_h - 0.1, 0), Vector3(0.3, 0.2, 14.2))
	_roof3("slate", 14.0, 8.0, wall_h, 5.6, 0.5, 0.0, "ashlar_warm", 90)
	# apse: a half-octagon behind, with three lancets and its own conical slate roof
	var ac := Vector3(0, 0, -7.0)
	_lathe("ashlar_warm", ac, [Vector2(4.0, 0), Vector2(4.0, wall_h), Vector2(0.0, wall_h)], 8, Vector3(0, 22.5, 0))
	for k in 3:
		var a := PI * 0.5 + (k - 1) * PI / 4.0
		var dir := Vector3(cos(a), 0, -sin(a))
		_push(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), ac + dir * 3.72))
		_lancet(Vector3(0, 2.3, 0.0), 1.1, 4.2)
		_pop()
		_buttress(ac + Vector3(cos(a + PI / 8.0), 0, -sin(a + PI / 8.0)) * 3.75, Vector3(cos(a + PI / 8.0), 0, -sin(a + PI / 8.0)), wall_h - 0.6)
	_lathe("slate", ac + Vector3(0, wall_h, 0), [Vector2(4.5, -0.1), Vector2(0.0, 4.6)], 8, Vector3(0, 22.5, 0), Vector3.ONE, 0.0, true, 1.0)
	_pop()
	# west tower: square, buttressed, a belfry and a tall slate spire with the hand on top
	var tz := 7.0
	var tw := 5.4
	var th := 13.6
	_box("ashlar_warm", Vector3(0, py + th * 0.5, tz), Vector3(tw, th, tw))
	for k in 3:   # string courses
		_box("limestone", Vector3(0, py + 4.6 + k * 4.2, tz), Vector3(tw + 0.16, 0.18, tw + 0.16))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var corner := Vector3(c.x * tw * 0.5, py, tz + c.y * tw * 0.5)
		_buttress(corner - Vector3(0, 0, c.y * 0.45), Vector3(c.x, 0, 0), 10.0)
		_buttress(corner - Vector3(c.x * 0.45, 0, 0), Vector3(0, 0, c.y), 10.0)
	for side in 4:   # belfry openings
		var ry := side * 90.0
		var b := Basis(Vector3.UP, deg_to_rad(ry))
		_push(Transform3D(b, Vector3(0, py, tz) + b * Vector3(0, 0, tw * 0.5 + 0.01)))
		for sx in [-0.7, 0.7]:
			_lancet(Vector3(sx, 9.4, 0), 1.0, 3.0, "cave_dark")
		_pop()
	_spire(Vector3(0, py + th, tz), tw + 0.5, 7.8)
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:   # corner pinnacles
		_lathe("slate", Vector3(c.x * (tw * 0.5 - 0.2), py + th, tz + c.y * (tw * 0.5 - 0.2)), [Vector2(0.4, 0), Vector2(0.0, 2.4)], 4, Vector3(0, 45, 0))
		_ball("brass", Vector3(c.x * (tw * 0.5 - 0.2), py + th + 2.45, tz + c.y * (tw * 0.5 - 0.2)), 0.1, 5, 3)
	# the west front: great door, the rose window with the hand above it, banners
	var fz := tz + tw * 0.5 + 0.02
	_box("limestone", Vector3(0, py + 2.0, fz + 0.12), Vector3(3.2, 4.0, 0.25))
	_push(_xf(Vector3(0, py, fz + 0.26)))
	_door(Vector3(-0.62, 0, 0), 1.2, 3.4, "paint_plum", false)
	_door(Vector3(0.62, 0, 0), 1.2, 3.4, "paint_plum", false)
	for k in 7:   # a pointed arch of voussoirs over the doors
		var a := PI * (k + 0.5) / 7.0
		_box("limestone", Vector3(cos(a) * 1.45, 3.5 + sin(a) * 1.0, 0.02), Vector3(0.5, 0.3, 0.3), Vector3(0, 0, rad_to_deg(a) - 90))
	_hand_symbol("hand_gold", Vector3(0, 3.95, 0.12), Vector3(0, 0, 1), Vector3.UP, 0.8, 0.04)
	_pop()
	_rose(Vector3(0, py + 6.9, fz + 0.04), 1.55)
	for sx in [-1.0, 1.0]:
		_banner(Vector3(sx * 2.05, py + 9.2, fz + 0.05), 0, "cloth_jewel", 2.8, 0.9)
	# the steps, two lanterns on posts, and the old shrine stone in its railed garden
	for i in 4:
		_box("limestone", Vector3(0, i * 0.15 + 0.075, fz + 2.3 - i * 0.4), Vector3(5.0 - i * 0.3, 0.15 + i * 0.0, 0.42))
	for sx in [-1.0, 1.0]:
		_rod("iron", Vector3(sx * 2.9, 0, fz + 2.0), Vector3(sx * 2.9, 2.6, fz + 2.0), 0.06, 6)
		_lantern(Vector3(sx * 2.9, 2.8, fz + 2.0), 1.3)
	var sp := Vector3(4.6, 0, fz + 1.8)
	_lathe("limestone", sp, [Vector2(1.3, 0), Vector2(1.3, 0.35), Vector2(0, 0.35)], 10)
	_shrine_stone(sp + Vector3(0, 0.35, 0), -20)
	var ring := []
	for k in 10:
		var a := TAU * k / 10.0
		ring.append(sp + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6))
	_railing(ring, 0.7, true)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		_ball("leaf", sp + Vector3(cos(a) * 1.15, 0.45, sin(a) * 1.15), 0.18, 5, 3)
		_ball(["cloth_red", "cloth_gold", "plaster_rose"][k % 3], sp + Vector3(cos(a) * 1.15, 0.6, sin(a) * 1.15), 0.08, 5, 3)
	_save("great_hall")

	_begin("great_hall_plot")
	_plot3(9.0, 22.0)
	_shrine_stone(Vector3(4.6, 0, 11.5), -20)
	_save("great_hall_plot")
	_begin("great_hall_frame")
	_hall_plinth()
	_push(_xf(Vector3(0, 0.6, -2.0)))
	_frame3(8.0, 14.0, 8.0, 0.4, "ashlar_warm")
	_pop()
	_box("ashlar_warm", Vector3(0, 0.6 + 2.0, 7.0), Vector3(5.4, 4.0, 5.4))
	for k in 5:   # timber centering waiting to carry the tower arch
		var a := PI * k / 4.0
		_beam("wood", Vector3(cos(a) * 1.2, 4.6 + sin(a) * 1.0, 9.8), Vector3(cos(a + PI / 4.0) * 1.2, 4.6 + sin(a + PI / 4.0) * 1.0, 9.8), 0.12)
	_shrine_stone(Vector3(4.6, 0, 11.5), -20)
	_save("great_hall_frame")


func _hall_plinth() -> void:
	_box("ashlar", Vector3(0, 0.3, -1.0), Vector3(9.6, 0.6, 22.6))
	_box("limestone", Vector3(0, 0.62, -1.0), Vector3(9.8, 0.06, 22.8))


# ================================================================== civic buildings

func _clocktower() -> void:
	# Stone base, brick shaft, four clock faces (front Hands spin), an open belfry with a
	# bell, a copper (verdigris) roof with the town flag above.
	_begin("clocktower")
	_clock_shaft(true)
	_save("clocktower")
	_begin("clocktower_plot")
	_plot3(4.6, 4.6)
	_save("clocktower_plot")
	_begin("clocktower_frame")
	_clock_shaft(false)
	_save("clocktower_frame")


func _clock_shaft(done: bool) -> void:
	var w := 4.2
	_box("town_stone", Vector3(0, 2.0, 0), Vector3(w + 0.4, 4.0, w + 0.4))
	_box("limestone", Vector3(0, 4.05, 0), Vector3(w + 0.55, 0.2, w + 0.55))
	_push(_xf(Vector3(0, 0, (w + 0.4) * 0.5)))
	_door(Vector3(0, 0, 0.02), 1.3, 2.7, "paint_blue", true)
	_pop()
	if not done:
		_box("brick", Vector3(0, 5.2, 0), Vector3(w, 2.2, w))
		_frame3(w + 0.4, w + 0.4, 6.0, 0.0)
		return
	var top := 13.0
	_box("brick", Vector3(0, 4.0 + (top - 4.0) * 0.5, 0), Vector3(w, top - 4.0, w))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_box("limestone", Vector3(c.x * w * 0.5, 4.0 + (top - 4.0) * 0.5, c.y * w * 0.5), Vector3(0.36, top - 4.0, 0.36))
	for side in 4:
		var b := Basis(Vector3.UP, deg_to_rad(side * 90.0))
		_push(Transform3D(b, b * Vector3(0, 0, w * 0.5 + 0.02)))
		_box("limestone", Vector3(0, 10.4, 0.02), Vector3(3.2, 3.2, 0.12))
		_face_disc("clock_face", Vector3(0, 10.4, 0.1), 1.35, 24)
		_lancet(Vector3(0, 5.4, 0.0), 0.8, 2.6, "glass_dark")
		if side != 0:
			_clock_hands(Vector3(0, 10.4, 0.14), 0.6 + side * 0.4)
		_pop()
	var hands := _part("Hands", Vector3(0, 10.4, w * 0.5 + 0.17), func() -> void: _clock_hands(Vector3.ZERO, 0.0))
	hands.set_script(SPINNER)
	hands.set("speed", 0.05)
	hands.set("axis", Vector3(0, 0, -1))
	_box("limestone", Vector3(0, top + 0.1, 0), Vector3(w + 0.5, 0.2, w + 0.5))
	# belfry: four corner piers, the bell, a balustrade
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_box("limestone", Vector3(c.x * (w * 0.5 - 0.25), top + 1.6, c.y * (w * 0.5 - 0.25)), Vector3(0.5, 3.0, 0.5))
	_box("limestone", Vector3(0, top + 3.2, 0), Vector3(w + 0.3, 0.25, w + 0.3))
	_beam("wood_dark", Vector3(-1.5, top + 2.7, 0), Vector3(1.5, top + 2.7, 0), 0.18)
	_lathe("bronze", Vector3(0, top + 1.3, 0), [Vector2(0.75, 0), Vector2(0.7, 0.12), Vector2(0.45, 0.5), Vector2(0.4, 1.0), Vector2(0.2, 1.3), Vector2(0.0, 1.35)], 12)
	var rail := [Vector3(-w * 0.5, top + 0.2, w * 0.5), Vector3(w * 0.5, top + 0.2, w * 0.5), Vector3(w * 0.5, top + 0.2, -w * 0.5), Vector3(-w * 0.5, top + 0.2, -w * 0.5)]
	_railing(rail, 0.8, true)
	# copper roof: a bell curve to a lantern and the flag
	_lathe("verdigris", Vector3(0, top + 3.3, 0), [Vector2(w * 0.72, 0), Vector2(w * 0.55, 0.9), Vector2(0.9, 2.6), Vector2(0.6, 3.6), Vector2(0.0, 4.0)], 4, Vector3(0, 45, 0), Vector3.ONE, 0.0, true, 1.0)
	_rod("iron", Vector3(0, top + 7.0, 0), Vector3(0, top + 9.6, 0), 0.05, 6)
	_ball("brass", Vector3(0, top + 7.3, 0), 0.18, 7, 4)
	_flag(Vector3(0, top + 9.5, 0), 1.6, 1.0)


func _clock_hands(c: Vector3, a: float) -> void:
	_push(Transform3D(Basis(Vector3.BACK, a), c))
	_box("iron", Vector3(0, 0.38, 0), Vector3(0.09, 0.8, 0.03))
	_box("iron", Vector3(0.28, 0, 0.03), Vector3(0.62, 0.1, 0.03), Vector3(0, 0, 0))
	_ball("brass", Vector3(0, 0, 0.04), 0.08, 6, 3)
	_pop()


## A flag on a staff top `top`: the town flag (the hand on jewel blue), w x h, gently waving.
func _flag(top: Vector3, w: float, h: float) -> void:
	var n := 6
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var z0 := sin(u0 * 3.0) * 0.12 * u0
		var z1 := sin(u1 * 3.0) * 0.12 * u1
		_quad("flag_hand", top + Vector3(u0 * w, 0, z0), top + Vector3(u1 * w, 0, z1), top + Vector3(u1 * w, -h, z1), top + Vector3(u0 * w, -h, z0),
			Vector3(0, 0, 1), [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])


func _school() -> void:
	# Milestone 1: a single-storey schoolhouse, tall windows, a bell cote on the gable, a slate
	# roof, a railed yard with a hopscotch, a slate board, a bench and the town flag.
	_begin("school")
	_school_body(true)
	_save("school")
	_begin("school_plot")
	_plot3(9.0, 6.0)
	_save("school_plot")
	_begin("school_frame")
	_frame3(8.0, 6.0, 4.2, 0.55, "ashlar")
	_save("school_frame")


func _school_body(done: bool) -> void:
	var w := 8.0
	var d := 6.0
	var wh := 4.2
	_box("ashlar", Vector3(0, 0.3, 0), Vector3(w + 0.3, 0.6, d + 0.3))
	_box("plaster_ochre", Vector3(0, wh * 0.5, 0), Vector3(w, wh, d))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_box("ashlar", Vector3(c.x * w * 0.5, wh * 0.5, c.y * d * 0.5), Vector3(0.45, wh, 0.45))
	_box("limestone", Vector3(0, wh - 0.1, 0), Vector3(w + 0.2, 0.2, d + 0.2))
	for sz in [-1.0, 1.0]:
		_push(_xf(Vector3(0, 0, sz * d * 0.5), 0.0 if sz > 0 else 180.0))
		for k in 4:
			var x := -3.0 + k * 2.0
			if sz > 0 and k == 1:
				continue
			_push(_xf(Vector3(x, 0.15, 0.01)))
			_model(V + "Window_Thin_Flat1.gltf", Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 1.25, 1), null, MK)
			_box("limestone", Vector3(0, 1.15, 0.1), Vector3(1.0, 0.1, 0.2))
			_box("limestone", Vector3(0, 3.35, 0.08), Vector3(1.0, 0.16, 0.14))
			_pop()
		_pop()
	_push(_xf(Vector3(-1.0, 0, d * 0.5 + 0.02)))
	_box("limestone", Vector3(0, 1.4, 0.06), Vector3(1.7, 2.9, 0.12))
	_door(Vector3(0, 0.6, 0.14), 1.1, 2.3, "paint_green", true)
	for i in 3:
		_box("limestone", Vector3(0, 0.1 + i * 0.2, 0.45 - i * 0.2), Vector3(1.8, 0.2, 0.4))
	_box("slate_flat", Vector3(0, 3.1, 0.12), Vector3(1.4, 0.45, 0.05))   # name board
	_box("paper", Vector3(0, 3.1, 0.15), Vector3(1.1, 0.06, 0.02))
	_pop()
	var ridge := _roof3("slate", w, d, wh, 2.8, 0.45, 0.0, "plaster_ochre")
	# bell cote on the right gable with the school bell (Bell swings on X when rung)
	var bx := w * 0.5 - 0.1
	for sz in [-0.45, 0.45]:
		_box("ashlar", Vector3(bx, ridge + 0.6, sz), Vector3(0.35, 1.6, 0.25))
	_box("ashlar", Vector3(bx, ridge + 1.5, 0), Vector3(0.45, 0.25, 1.25))
	_lathe("slate_flat", Vector3(bx, ridge + 1.6, 0), [Vector2(0.75, 0), Vector2(0.0, 0.7)], 4, Vector3(0, 45, 0))
	var bell := _part("Bell", Vector3(bx, ridge + 1.35, 0), func() -> void:
		_lathe("bronze", Vector3(0, -0.55, 0), [Vector2(0.28, 0), Vector2(0.25, 0.08), Vector2(0.16, 0.3), Vector2(0.14, 0.5), Vector2(0.0, 0.55)], 10))
	bell.set_script(SPINNER)
	bell.set("spinning", false)
	bell.set("axis", Vector3.RIGHT)
	_chimney(Vector3(-2.4, wh + 1.2, -1.0), 2.6)
	if not done:
		return
	# the yard: railing, slate board on an easel, a bench, a hoop, hopscotch chalked on flags
	_box("cobbles", Vector3(0, 0.02, d * 0.5 + 2.0), Vector3(w + 1.0, 0.04, 3.6))
	var yz := d * 0.5 + 3.8
	_railing([Vector3(-w * 0.5 - 0.5, 0, yz), Vector3(-1.4, 0, yz)], 0.8)
	_railing([Vector3(-0.2, 0, yz), Vector3(w * 0.5 + 0.5, 0, yz)], 0.8)
	_bench(Vector3(2.4, 0, d * 0.5 + 1.0), 0, 1.6, 0.45, 0.4)
	_push(_xf(Vector3(-3.2, 0, d * 0.5 + 1.5), 20))
	for sx in [-0.4, 0.4]:
		_beam("wood", Vector3(sx, 0, 0.25), Vector3(sx * 0.8, 1.6, 0), 0.05)
	_beam("wood", Vector3(0, 0, -0.35), Vector3(0, 1.5, 0), 0.05)
	_box("slate_flat", Vector3(0, 1.1, 0.12), Vector3(1.0, 0.7, 0.04), Vector3(-10, 0, 0))
	for k in 3:
		_box("paper", Vector3(-0.25 + k * 0.22, 1.15, 0.16), Vector3(0.14, 0.03, 0.01), Vector3(-10, 0, 20))
	_pop()
	for k in 6:
		var z := d * 0.5 + 0.9 + k * 0.42
		_box("paper", Vector3(0.6, 0.045, z), Vector3(0.38, 0.01, 0.38))
		_box("ashlar", Vector3(0.6, 0.04, z), Vector3(0.34, 0.012, 0.34))
	_lathe("wood", Vector3(1.6, 0.42, d * 0.5 + 2.3), [Vector2(0.42, 0), Vector2(0.42, 0.03), Vector2(0.38, 0.03), Vector2(0.38, 0.0)], 14, Vector3(80, 0, 10))
	_rod("iron", Vector3(w * 0.5 + 0.2, 0, d * 0.5 + 3.3), Vector3(w * 0.5 + 0.2, 6.0, d * 0.5 + 3.3), 0.05, 6)
	_ball("brass", Vector3(w * 0.5 + 0.2, 6.05, d * 0.5 + 3.3), 0.1, 5, 3)
	_flag(Vector3(w * 0.5 + 0.22, 5.9, d * 0.5 + 3.3), 1.4, 0.88)


func _market_hall() -> void:
	# Caravans trade here: an open arcade of stone columns under a plaster upper chamber,
	# a tile roof with a little cupola, goods and stall awnings under the arches.
	_begin("market_hall")
	_market_body(true)
	_save("market_hall")
	_begin("market_hall_plot")
	_plot3(10.0, 6.0)
	_save("market_hall_plot")
	_begin("market_hall_frame")
	_market_body(false)
	_save("market_hall_frame")


func _market_body(done: bool) -> void:
	var w := 10.0
	var d := 6.0
	_box("cobbles", Vector3(0, 0.05, 0), Vector3(w + 0.6, 0.1, d + 0.6))
	var col_h := 3.2
	for ix in 6:
		for iz in 3:
			if iz == 1 and ix > 0 and ix < 5:
				continue
			var p := Vector3(-w * 0.5 + ix * 2.0, 0.1, -d * 0.5 + iz * 3.0)
			_box("ashlar", p + Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.6))
			_cyl("limestone", p + Vector3(0, 0.4, 0), 0.24, 0.21, col_h - 0.75, 10)
			_box("ashlar", p + Vector3(0, col_h - 0.2, 0), Vector3(0.55, 0.3, 0.55))
	if not done:
		for x in [-5.0, 5.0]:
			for z in [-3.0, 3.0]:
				_rod("wood", Vector3(x * 1.1, 0, z * 1.25), Vector3(x * 1.1, 7.0, z * 1.25), 0.07, 5)
		_frame3(w, d, 0.1, 0.0)
		_beam("wood", Vector3(-5.5, 3.0, 3.3), Vector3(5.5, 3.0, 3.3), 0.14)
		_beam("wood", Vector3(-5.5, 3.0, -3.3), Vector3(5.5, 3.0, -3.3), 0.14)
		return
	# arches: segmental arcs between the columns on the long sides
	for sz in [-1.0, 1.0]:
		for ix in 5:
			var x0 := -w * 0.5 + ix * 2.0
			for k in 6:
				var a0 := PI * k / 6.0
				var a1 := PI * (k + 1) / 6.0
				var p0 := Vector3(x0 + 1.0 - cos(a0) * 0.85, col_h - 0.35 + sin(a0) * 0.45, sz * d * 0.5)
				var p1 := Vector3(x0 + 1.0 - cos(a1) * 0.85, col_h - 0.35 + sin(a1) * 0.45, sz * d * 0.5)
				_beam("ashlar", p0, p1, 0.3, 0.5)
	_box("ashlar", Vector3(0, col_h + 0.35, 0), Vector3(w + 0.6, 0.5, d + 0.6))
	_box("ashlar", Vector3(0, col_h + 0.1, 0), Vector3(w + 0.4, 0.4, d + 0.4))
	_box("limestone", Vector3(0, col_h + 0.62, 0), Vector3(w + 0.8, 0.12, d + 0.8))
	_upper_floor(w + 0.4, d + 0.4, col_h + 0.68, 2.8, "plaster_sage", {"front": "TBBT", "back": "W-W", "left": "T-T", "right": "T-T"}, "paint_plum", 0.05)
	var wt := col_h + 0.68 + 2.8
	var ridge := _roof3("roof_tiles", w + 0.5, d + 0.5, wt, 3.0, 0.55, 0.42)
	# cupola with a bell-shaped copper cap and a flag
	var cy := ridge - 0.3
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_beam("limestone", Vector3(c.x * 0.55, cy, c.y * 0.55), Vector3(c.x * 0.55, cy + 1.3, c.y * 0.55), 0.14)
	_box("ashlar", Vector3(0, cy - 0.1, 0), Vector3(1.5, 0.4, 1.5))
	_lathe("verdigris", Vector3(0, cy + 1.3, 0), [Vector2(0.95, 0), Vector2(0.7, 0.5), Vector2(0.25, 1.1), Vector2(0, 1.4)], 8, Vector3(0, 22.5, 0))
	_rod("iron", Vector3(0, cy + 1.4, 0), Vector3(0, cy + 3.8, 0), 0.04, 5)
	_flag(Vector3(0, cy + 3.75, 0), 1.2, 0.75)
	# under the arcade: a weighing beam, sacks, crates, bolts of cloth on trestles
	_push(_xf(Vector3(-2.0, 0.1, 0)))
	for sx in [-0.8, 0.8]:
		_beam("wood_dark", Vector3(sx, 0, 0), Vector3(sx, 2.2, 0), 0.12)
	_beam("wood_dark", Vector3(-0.9, 2.2, 0), Vector3(0.9, 2.2, 0), 0.12)
	_beam("iron", Vector3(-0.6, 1.9, 0), Vector3(0.6, 1.9, 0), 0.05)
	for sx in [-0.55, 0.55]:
		_rod("iron", Vector3(sx, 1.9, 0), Vector3(sx, 1.2, 0), 0.01, 3)
		_lathe("brass", Vector3(sx, 1.1, 0), [Vector2(0.25, 0), Vector2(0.25, 0.06), Vector2(0, 0.06)], 9)
	_pop()
	for i in 3:
		_sack(Vector3(-3.5 + i * 0.5, 0.1, 1.6 - (i % 2) * 0.4), "linen", 0.9)
	_model(BOATS + "crate.glb", Vector3(3.6, 0.1, 1.5), Vector3(0, 10, 0), 1.0, null, SHIP)
	_model(BOATS + "crate-bottles.glb", Vector3(3.5, 0.1, 0.3), Vector3(0, -15, 0), 1.0, null, SHIP)
	_bench(Vector3(1.4, 0.1, -1.2), 0, 2.2, 0.8, 0.7)
	var cm := ["cloth_teal", "cloth_plum", "cloth_jewel", "cloth_gold", "linen"]
	for i in 5:
		_rod(cm[i], Vector3(0.6 + i * 0.4, 1.02, -0.9), Vector3(0.6 + i * 0.4, 1.02, -1.5), 0.15, 8)
	# two striped awnings over the front arches, lanterns on the corner columns
	for ax in [-3.0, 3.0]:
		for i in 6:
			var x0: float = ax - 0.9 + 1.8 * i / 6.0
			var x1: float = ax - 0.9 + 1.8 * (i + 1) / 6.0
			_quad("cloth_teal" if i % 2 == 0 else "linen", Vector3(x0, 2.55, d * 0.5 + 0.2), Vector3(x1, 2.55, d * 0.5 + 0.2),
				Vector3(x1, 2.1, d * 0.5 + 1.3), Vector3(x0, 2.1, d * 0.5 + 1.3), Vector3(0, 1, 0.4))
	for sx in [-1.0, 1.0]:
		_lantern(Vector3(sx * (w * 0.5 + 0.35), 2.4, d * 0.5 + 0.35))
		_beam("iron", Vector3(sx * w * 0.5, 2.6, d * 0.5), Vector3(sx * (w * 0.5 + 0.35), 2.6, d * 0.5 + 0.35), 0.04)


func _observatory() -> void:
	# The Era 3 gate (DESIGN 5, 10): an ashlar drum on the quarry hilltop with stained-glass
	# lancets (the hand in the glass, DESIGN 7), a portico, a copper dome on a ring that turns
	# (Dome) with its shutter open and the great telescope looking out.
	_begin("observatory")
	_obs_drum(true)
	_save("observatory")
	_begin("observatory_plot")
	_plot3(11.0, 11.0, true)
	_save("observatory_plot")
	_begin("observatory_frame")
	_obs_drum(false)
	_save("observatory_frame")


func _obs_drum(done: bool) -> void:
	var r := 5.0
	var h := 6.5
	_lathe("ashlar", Vector3.ZERO, [Vector2(r + 0.8, 0), Vector2(r + 0.8, 0.6), Vector2(0, 0.6)], 16)
	_lathe("limestone", Vector3(0, 0.6, 0), [Vector2(r + 0.85, 0), Vector2(r + 0.85, 0.06), Vector2(0, 0.06)], 16)
	if not done:
		_lathe("ashlar_warm", Vector3(0, 0.6, 0), [Vector2(r, 0), Vector2(r, 2.6), Vector2(r - 0.6, 2.6), Vector2(r - 0.6, 0.0)], 16)
		for k in 8:
			var a := TAU * k / 8.0
			_rod("wood", Vector3(cos(a) * (r + 0.7), 0.6, sin(a) * (r + 0.7)), Vector3(cos(a) * (r + 0.7), 5.5, sin(a) * (r + 0.7)), 0.07, 5)
		for y in [2.0, 3.8]:
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				_beam("wood", Vector3(cos(a0) * (r + 0.7), y, sin(a0) * (r + 0.7)), Vector3(cos(a1) * (r + 0.7), y, sin(a1) * (r + 0.7)), 0.07)
				_box("planks", Vector3(cos((a0 + a1) * 0.5) * (r + 0.4), y + 0.08, sin((a0 + a1) * 0.5) * (r + 0.4)), Vector3(0.5, 0.06, 3.6), Vector3(0, -rad_to_deg((a0 + a1) * 0.5), 0))
		for k in 4:   # the dome's curved iron ribs, stacked on blocks, waiting
			var rr := 2.4 + k * 0.05
			var y := 0.2 + k * 0.13
			for q in 6:
				var a0 := PI * 0.5 * q / 6.0
				var a1 := PI * 0.5 * (q + 1) / 6.0
				_beam("iron", Vector3(-1.2 + cos(a0) * rr, y, r + 0.9 + sin(a0) * rr), Vector3(-1.2 + cos(a1) * rr, y, r + 0.9 + sin(a1) * rr), 0.12, 0.1)
		for b in [Vector3(1.0, 0.07, r + 1.4), Vector3(-0.6, 0.07, r + 3.2)]:
			_box("wood_dark", b, Vector3(0.9, 0.14, 0.3))
		_stone_pile(Vector3(-r - 2.5, 0, 2.0), 1.0)
		_ladder(Vector3(r + 1.6, 0, 1.0), Vector3(r + 0.75, 3.9, 1.0), 0.5)
		return
	_lathe("ashlar_warm", Vector3(0, 0.6, 0), [Vector2(r, 0), Vector2(r, h), Vector2(0.0, h)], 16)
	_lathe("limestone", Vector3(0, 0.6 + h, 0), [Vector2(r + 0.25, 0), Vector2(r + 0.25, 0.3), Vector2(0, 0.3)], 16)
	for k in 16:   # pilasters and stained lancets round the drum
		var a := TAU * (k + 0.5) / 16.0
		var dir := Vector3(cos(a), 0, sin(a))
		_box_b("limestone", dir * (r + 0.05) + Vector3(0, 0.6 + h * 0.5, 0), Vector3(0.3, h, 0.2), Basis(Vector3.UP, -a + PI * 0.5))
		var b := TAU * (k + 1.0) / 16.0
		var bd := Vector3(cos(b), 0, sin(b))
		if k % 2 == 1 and absf(b - PI * 0.5) > 0.3:
			_push(Transform3D(Basis(Vector3.UP, atan2(bd.x, bd.z)), bd * (r - 0.02)))
			_lancet(Vector3(0, 2.0, 0), 0.9, 3.6)
			_pop()
	# portico on the front: four columns, a pediment with a rose window and the hand
	var pz := r + 1.2
	_box("limestone", Vector3(0, 0.75, pz), Vector3(5.0, 0.3, 2.4))
	for x in [-1.8, -0.6, 0.6, 1.8]:
		_cyl("limestone", Vector3(x, 0.9, pz + 0.8), 0.25, 0.22, 4.2, 10)
		_box("limestone", Vector3(x, 5.15, pz + 0.8), Vector3(0.6, 0.2, 0.6))
	_box("limestone", Vector3(0, 5.45, pz), Vector3(5.2, 0.45, 2.6))
	_push(_xf(Vector3(0, 5.67, pz + 1.3)))
	_tri("ashlar_warm", Vector3(-2.6, 0, 0), Vector3(2.6, 0, 0), Vector3(0, 1.5, 0), Vector3.BACK)
	_pop()
	_slab("slate", [Vector3(-2.8, 5.65, pz + 1.45), Vector3(0, 7.25, pz + 1.45), Vector3(0, 7.25, pz - 1.3), Vector3(-2.8, 5.65, pz - 1.3)], 0.12, Vector3(-1.6, 2.8, 0))
	_slab("slate", [Vector3(0, 7.25, pz + 1.45), Vector3(2.8, 5.65, pz + 1.45), Vector3(2.8, 5.65, pz - 1.3), Vector3(0, 7.25, pz - 1.3)], 0.12, Vector3(1.6, 2.8, 0))
	_rose(Vector3(0, 6.25, pz + 1.33), 0.5)
	_push(_xf(Vector3(0, 0.6, r - 0.02)))
	_door(Vector3(0, 0, 0.05), 1.6, 3.2, "paint_blue", true)
	_pop()
	for i in 3:
		_box("limestone", Vector3(0, 0.1 + i * 0.2, pz + 1.4 + (2 - i) * 0.35), Vector3(3.6, 0.2, 0.36))
	# the dome turns on its ring: copper gores, the shutter slit, the telescope
	var dy := 0.6 + h + 0.3
	var dome := _part("Dome", Vector3(0, dy, 0), _obs_dome.bind(r))
	dome.set_script(SPINNER)
	dome.set("spinning", false)
	dome.set("speed", 0.08)
	dome.set("axis", Vector3.UP)
	# instruments in the forecourt: an armillary sphere and a sundial
	_armillary(Vector3(-r - 1.4, 0.6, 2.6), 1.0)
	_lathe("limestone", Vector3(r + 1.3, 0.6, 2.8), [Vector2(0.3, 0), Vector2(0.22, 1.0), Vector2(0.45, 1.0), Vector2(0.45, 1.1), Vector2(0, 1.1)], 8)
	_tri("brass", Vector3(r + 1.3, 1.7, 2.6), Vector3(r + 1.3, 1.7, 3.1), Vector3(r + 1.3, 2.0, 2.6), Vector3.RIGHT)


func _obs_dome(r: float) -> void:
	var seg := 16
	var rings := 6
	var slit := 0.55
	for i in rings:
		var b0 := PI * 0.5 * i / rings
		var b1 := PI * 0.5 * (i + 1) / rings
		for j in seg:
			var a0 := TAU * j / seg + PI * 0.5
			var a1 := TAU * (j + 1) / seg + PI * 0.5
			var mid := (a0 + a1) * 0.5
			if absf(wrapf(mid - PI * 0.5, -PI, PI)) < slit * 0.5 + 0.05 and i < rings - 1:
				continue   # the open shutter faces +Z
			var P := func(a: float, b: float) -> Vector3: return Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b)) * r
			# weathered copper sheets, the lowest ring still bright where the rain runs off
			_quad("copper" if i == 0 else "verdigris", P.call(a0, b0), P.call(a1, b0), P.call(a1, b1), P.call(a0, b1), P.call(mid, (b0 + b1) * 0.5))
			_quad("cave_dark", P.call(a0, b1) * 0.98, P.call(a1, b1) * 0.98, P.call(a1, b0) * 0.98, P.call(a0, b0) * 0.98, -P.call(mid, (b0 + b1) * 0.5))
	for j in seg:   # brass ribs
		var a := TAU * j / seg + PI * 0.5
		for i in rings:
			var b0 := PI * 0.5 * i / rings
			var b1 := PI * 0.5 * (i + 1) / rings
			_beam("brass", Vector3(cos(a) * cos(b0), sin(b0), sin(a) * cos(b0)) * (r + 0.02), Vector3(cos(a) * cos(b1), sin(b1), sin(a) * cos(b1)) * (r + 0.02), 0.06)
	_lathe("cave_dark", Vector3.ZERO, [Vector2(r - 0.05, 0), Vector2(0.0, 0.0)], 16)
	_lathe("iron_light", Vector3(0, -0.1, 0), [Vector2(r + 0.2, 0), Vector2(r + 0.2, 0.2), Vector2(r - 0.1, 0.2), Vector2(r - 0.1, 0)], 16)
	# the open shutter leaf folded back over the top
	_box("copper", Vector3(0, r * 0.98, -0.6), Vector3(r * slit * 1.2, 0.08, 1.8), Vector3(20, 0, 0))
	# the great telescope, angled up out of the slit
	_push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-38)), Vector3(0, 1.6, 0.4)))
	_cyl("brass", Vector3(0, 0, 0), 0.35, 0.42, 5.2, 10, Vector3(90, 0, 0))
	_cyl("paint_blue", Vector3(0, 0, 1.0), 0.37, 0.44, 2.8, 10, Vector3(90, 0, 0))
	_cyl("iron", Vector3(0, 0, 5.1), 0.48, 0.48, 0.3, 10, Vector3(90, 0, 0))
	_pop()
	_hand_symbol("hand_gold", Vector3(0, r + 0.9, 0), Vector3(0, 0, 1), Vector3.UP, 1.0, 0.06)
	_rod("brass", Vector3(0, r - 0.1, 0), Vector3(0, r + 0.5, 0), 0.06, 6)


## Brass armillary sphere on a stone pedestal (science made visible).
func _armillary(p: Vector3, s: float) -> void:
	_lathe("limestone", p, [Vector2(0.35, 0), Vector2(0.25, 0.9), Vector2(0.4, 0.95), Vector2(0, 1.0)], 8, Vector3.ZERO, Vector3.ONE * s)
	var c := p + Vector3(0, 1.6, 0) * s
	for rot in [Vector3(0, 0, 0), Vector3(90, 0, 0), Vector3(90, 60, 0), Vector3(23, 0, 0)]:
		_lathe("brass", c, [Vector2(0.55, -0.02), Vector2(0.55, 0.02), Vector2(0.5, 0.02), Vector2(0.5, -0.02)], 18, rot, Vector3.ONE * s, 0.0, false)
	_rod("iron", c - Vector3(0, 0.7, 0) * s, c + Vector3(0.25, 0.7, 0) * s, 0.025 * s, 5)
	_ball("cloth_gold", c, 0.12 * s, 7, 4)


# ================================================================== workplaces

func _forge() -> void:
	# Iron and steel (DESIGN 4): a brick bloomery stack in the yard makes the bloom, the smith
	# works it at the forge inside an open-fronted stone smithy with a tile roof.
	_begin("forge")
	_forge_body(true)
	_save("forge")
	_begin("forge_plot")
	_plot3(8.0, 5.0)
	_save("forge_plot")
	_begin("forge_frame")
	_forge_body(false)
	_save("forge_frame")


func _forge_body(done: bool) -> void:
	var w := 6.0
	var d := 4.6
	var wh := 3.2
	_box("cobbles", Vector3(0.6, 0.02, 0.4), Vector3(w + 2.6, 0.04, d + 2.0))
	_box("town_stone", Vector3(0, wh * 0.5, -d * 0.5 + 0.25), Vector3(w, wh, 0.5))
	for sx in [-1.0, 1.0]:
		_box("town_stone", Vector3(sx * (w * 0.5 - 0.25), wh * 0.5, 0), Vector3(0.5, wh, d))
		_box("ashlar", Vector3(sx * (w * 0.5 - 0.25), wh * 0.5, d * 0.5 - 0.1), Vector3(0.62, wh, 0.5))
	_box("ashlar", Vector3(0, wh - 0.2, d * 0.5 - 0.1), Vector3(w + 0.1, 0.45, 0.5))   # stone lintel
	if not done:
		_frame3(w, d, wh, 0.0)
		_bloomery(Vector3(w * 0.5 + 1.0, 0, 0.6), false)
		return
	_box("cave_dark", Vector3(0, 0.02, 0), Vector3(w - 1.0, 0.02, d - 0.8))
	_roof3("roof_tiles", w + 0.2, d + 0.2, wh + 0.05, 2.2, 0.45, 0.0, "town_stone")
	# hearth with hood, chimney through the roof, glowing coals
	_box("brick", Vector3(-1.5, 0.45, -1.4), Vector3(1.6, 0.9, 1.2))
	_box("charcoal", Vector3(-1.5, 0.92, -1.35), Vector3(1.1, 0.06, 0.8))
	_flames_node(_root, Vector3(-1.5, 0.92, -1.3), 0.4, true)
	_lathe("brick", Vector3(-1.5, 1.9, -1.45), [Vector2(1.0, 0), Vector2(0.4, 0.9), Vector2(0.4, 3.9), Vector2(0.0, 3.9)], 4, Vector3(0, 45, 0))
	_box("limestone", Vector3(-1.5, 5.85, -1.45), Vector3(0.75, 0.12, 0.75))
	_model(K + "workbench-anvil.glb", Vector3(-0.3, 0, -0.1), Vector3(0, -15, 0), 4.0, null, KEN)
	_trough(Vector3(1.4, 0, -1.3), 0)
	_beam("wood_dark", Vector3(0.4, 1.9, -1.98), Vector3(2.6, 1.9, -1.98), 0.08)
	for i in 4:
		var tx := 0.6 + i * 0.55
		_beam("iron", Vector3(tx, 1.85, -1.95), Vector3(tx, 1.2, -1.95), 0.04)
		_box("iron", Vector3(tx, 1.15, -1.95), Vector3(0.14 if i % 2 == 0 else 0.08, 0.14, 0.05))
	_iron_bars(Vector3(2.1, 0, 0.6))
	_shop_sign(Vector3(w * 0.5 + 0.05, 2.8, d * 0.5 - 0.3), 90, "paint_red", "anvil")
	# the bloomery stack and its bellows, with a cooling bloom on a stone
	_bloomery(Vector3(w * 0.5 + 1.4, 0, 0.6), true)
	_lathe("coal", Vector3(-w * 0.5 - 1.0, 0, 1.4), [Vector2(0.9, 0), Vector2(0.5, 0.5), Vector2(0.0, 0.6)], 9)
	_charcoal_lumps(Vector3(-w * 0.5 - 1.0, 0.1, 1.4), 0.7, 10)


## A tall brick bloomery: tapered stack, an arched glowing tap hole, leather bellows.
func _bloomery(c: Vector3, done: bool) -> void:
	_lathe("brick", c, [Vector2(1.1, 0), Vector2(1.05, 0.5), Vector2(0.75, 2.6 if done else 1.2), Vector2(0.6, 3.6 if done else 1.2),
		Vector2(0.45, 3.6 if done else 1.2), Vector2(0.4, 3.3 if done else 1.0)], 10)
	_lathe("iron", c + Vector3(0, 1.4, 0), [Vector2(0.97, 0), Vector2(0.97, 0.12), Vector2(0.9, 0.12)], 10, Vector3.ZERO, Vector3.ONE, 0.0, false)
	if not done:
		return
	_lathe("cave_dark", c + Vector3(0, 3.55, 0), [Vector2(0.42, 0), Vector2(0, 0)], 8)
	_flames_node(_root, c + Vector3(0, 3.5, 0), 0.3)
	_box("cave_dark", c + Vector3(0, 0.45, 0.98), Vector3(0.45, 0.5, 0.1))
	_glow(c + Vector3(0, 0.42, 1.04), 0.16, Vector3(0, 0, 1))
	for sz in [-0.25, 0.25]:
		_slab("leather", [Vector3(-1.0, 0.55, sz + 0.15), Vector3(-1.9, 0.45, sz + 0.2), Vector3(-1.9, 0.45, sz - 0.2), Vector3(-1.0, 0.55, sz - 0.15)], 0.28, Vector3.UP)
	_rod("clay", Vector3(-1.0, 0.4, 0), Vector3(-0.85, 0.5, 0), 0.08, 6)
	_lathe("stone", c + Vector3(0.4, 0, 1.6), [Vector2(0.4, 0), Vector2(0.4, 0.4), Vector2(0, 0.4)], 7)
	_ball("rust", c + Vector3(0.4, 0.55, 1.6), 0.22, 6, 3, Vector3(1, 0.7, 1))
	_glow(c + Vector3(0.4, 0.66, 1.6), 0.1, Vector3(0.3, 1, 0.4))


func _iron_bars(c: Vector3) -> void:
	_box("wood_dark", c + Vector3(-0.5, 0.06, 0), Vector3(0.12, 0.12, 0.9))
	_box("wood_dark", c + Vector3(0.5, 0.06, 0), Vector3(0.12, 0.12, 0.9))
	for layer in 3:
		for i in 5 - layer:
			_box("iron_light" if (i + layer) % 3 == 0 else "iron", c + Vector3(0, 0.17 + layer * 0.09, (i - (4 - layer) * 0.5) * 0.15), Vector3(1.4, 0.08, 0.11))


func _mason() -> void:
	# Masonry (DESIGN 4): the mason's yard under the quarry blocks. A tile-roofed lean-to,
	# bankers with blocks being dressed, a treadwheel crane (Wheel) hoisting a block, and
	# the town's gift in progress: a great stone open hand being carved.
	_begin("mason")
	_mason_body(true)
	_save("mason")
	_begin("mason_plot")
	_plot3(8.0, 6.0)
	_save("mason_plot")
	_begin("mason_frame")
	_mason_body(false)
	_save("mason_frame")


func _mason_body(done: bool) -> void:
	_yard(8.0, 6.5)
	for i in 30:   # stone chips
		_box("limestone", Vector3(_rng.randf_range(-3.5, 3.0), 0.04, _rng.randf_range(-1.0, 2.8)), Vector3(0.08, 0.04, 0.06), Vector3(0, _rng.randf() * 90, 0))
	# the lean-to: stone back wall, timber posts, tile roof
	_box("town_stone", Vector3(-0.5, 1.5, -2.6), Vector3(6.0, 3.0, 0.5))
	for x in [-3.3, -0.5, 2.3]:
		_beam("timber", Vector3(x, 0, -1.0), Vector3(x, 2.3, -1.0), 0.18)
	_beam("timber", Vector3(-3.5, 2.3, -1.0), Vector3(2.5, 2.3, -1.0), 0.18)
	if done:
		_slab("roof_tiles", [Vector3(-3.8, 2.45, -0.4), Vector3(2.8, 2.45, -0.4), Vector3(2.8, 3.3, -2.95), Vector3(-3.8, 3.3, -2.95)], 0.14,
			Vector3(0, 1, 0.33), [Vector3.RIGHT, Vector3.FORWARD, 1.6])
	else:
		for x in [-3.3, -1.8, -0.3, 1.2, 2.5]:
			_beam("wood", Vector3(x, 2.45, -0.4), Vector3(x, 3.3, -2.95), 0.08)
	_stone_pile(Vector3(-2.2, 0, -1.8), 1.0)
	_stone_pile(Vector3(0.6, 0, -1.8), 1.0)
	# bankers: stone benches with a block on each, one half dressed
	for bx in [-2.6, -0.8]:
		_box("ashlar", Vector3(bx, 0.35, 0.6), Vector3(0.9, 0.7, 0.7))
		_box("ashlar_warm", Vector3(bx, 0.88, 0.6), Vector3(0.7, 0.36, 0.5), Vector3(0, 15, 0))
	_model(K + "tool-hammer.glb", Vector3(-2.3, 1.06, 0.7), Vector3(0, 30, 90), 2.5, null, KEN)
	# a column drum and capital waiting for the great hall
	_cyl("limestone", Vector3(-3.5, 0, 2.2), 0.42, 0.42, 0.9, 10)
	_box("limestone", Vector3(-2.3, 0.2, 2.6), Vector3(0.9, 0.4, 0.9))
	# the stone hand on its banker: palm and fingers roughed out of a block
	_box("ashlar", Vector3(1.0, 0.4, 1.9), Vector3(1.2, 0.8, 1.0))
	_push(_xf(Vector3(1.0, 0.8, 1.9)))
	_box("limestone", Vector3(0, 0.25, 0), Vector3(1.0, 0.5, 0.7))
	_hand_symbol("limestone", Vector3(0, 1.3, 0.0), Vector3(0, 0, 1), Vector3.UP, 1.4, 0.32)
	_pop()
	_ladder(Vector3(1.9, 0, 2.6), Vector3(1.6, 2.0, 2.0), 0.4)
	# treadwheel crane: an A-frame, the jib, the man-powered wheel and the rope to a block
	var cx := 2.9
	for sz in [-0.9, 0.9]:
		_beam("timber", Vector3(cx - 0.9, 0, sz), Vector3(cx, 4.2, 0), 0.18)
		_beam("timber", Vector3(cx + 0.9, 0, sz), Vector3(cx, 4.2, 0), 0.18)
	_beam("timber", Vector3(cx, 4.0, 0), Vector3(cx - 0.6, 6.0, 1.8), 0.16)
	var hook := Vector3(cx - 0.6, 6.0, 1.8)
	if done:
		var wheel := _part("Wheel", Vector3(cx, 1.6, 0), func() -> void:
			for sx in [-0.45, 0.45]:
				_lathe("wood", Vector3(sx, 0, 0), [Vector2(1.55, -0.05), Vector2(1.55, 0.05), Vector2(1.42, 0.05), Vector2(1.42, -0.05)], 16, Vector3(0, 0, 90))
				for k in 8:
					var a := TAU * k / 8.0
					_beam("wood_dark", Vector3(sx, 0, 0), Vector3(sx, sin(a), cos(a)) * 1.0 * Vector3(1, 1.45, 1.45) + Vector3(0, 0, 0), 0.06)
			for k in 16:
				var a := TAU * k / 16.0
				_beam("planks", Vector3(-0.5, sin(a) * 1.47, cos(a) * 1.47), Vector3(0.5, sin(a) * 1.47, cos(a) * 1.47), 0.1, 0.04)
			_rod("wood_dark", Vector3(-0.7, 0, 0), Vector3(0.7, 0, 0), 0.1, 6))
		wheel.set_script(SPINNER)
		wheel.set("spinning", false)
		wheel.set("speed", 0.4)
		wheel.set("axis", Vector3.RIGHT)
		_rod("rope", hook, hook - Vector3(0, 3.6, 0), 0.025, 4)
		_box("ashlar_warm", hook - Vector3(0, 3.9, 0), Vector3(0.7, 0.4, 0.5), Vector3(0, 20, 0))
		_rod("rope", Vector3(cx, 1.6, 0), Vector3(cx, 4.0, 0), 0.025, 4)
		_rod("rope", Vector3(cx, 4.0, 0), hook, 0.025, 4)


func _printing_house() -> void:
	# Learning (DESIGN 4 school chain): a brick printing house and lending library: the press
	# stands under the porch, printed sheets dry on lines, books go out in bundles.
	_begin("printing_house")
	_printing_body(true)
	_save("printing_house")
	_begin("printing_house_plot")
	_plot3(6.0, 6.0)
	_save("printing_house_plot")
	_begin("printing_house_frame")
	_frame3(6.0, 6.0, 6.0, 0.45, "brick")
	_save("printing_house_frame")


func _printing_body(done: bool) -> void:
	var w := 6.0
	var d := 6.0
	_upper_floor(w, d, 0.0, 3.1, "brick", {"front": "W-W", "back": "W-W", "left": "T-T", "right": "-W-"}, "paint_green", 0.0)
	_push(_xf(Vector3(0, 0, d * 0.5 + 0.02)))
	_box("limestone", Vector3(0, 1.3, 0.04), Vector3(1.6, 2.7, 0.1))
	_door(Vector3(0, 0, 0.09), 1.1, 2.4, "paint_green", true)
	_pop()
	_upper_floor(w, d, 3.1, 2.8, "plaster", {"front": "BTB", "back": "W-W", "left": "-W-", "right": "W-W"}, "paint_green", 0.1)
	var wt := 5.9
	_roof3("slate", w + 0.2, d + 0.2, wt, 2.6, 0.4, 0.0, "plaster", 90)
	_chimney(Vector3(-2.0, wt + 0.3, -1.6), 2.6)
	_push(_xf(Vector3(0, wt, 3.2)))
	_rose(Vector3(0, 0.95, 0.0), 0.45)
	_pop()
	_shop_sign(Vector3(w * 0.5 - 0.3, 2.9, d * 0.5 + 0.02), 0, "paint_green", "book")
	# the porch on the right side with the press
	_push(_xf(Vector3(w * 0.5 + 1.3, 0, 0.3)))
	for c in [Vector2(1.1, 1.5), Vector2(1.1, -1.5)]:
		_beam("timber", Vector3(c.x, 0, c.y), Vector3(c.x, 2.6, c.y), 0.16)
	_slab("roof_tiles", [Vector3(-1.4, 2.95, 1.9), Vector3(1.5, 2.6, 1.9), Vector3(1.5, 2.6, -1.9), Vector3(-1.4, 2.95, -1.9)], 0.12,
		Vector3(0.12, 1, 0), [Vector3.BACK, Vector3.RIGHT, 1.6])
	_beam("timber", Vector3(1.1, 2.6, -1.6), Vector3(1.1, 2.6, 1.6), 0.16)
	_box("cobbles", Vector3(0, 0.02, 0), Vector3(2.8, 0.04, 3.6))
	_press(Vector3(0.0, 0, -0.5))
	_bench(Vector3(0.2, 0, 1.0), 90, 1.2, 0.85, 0.6)
	for i in 3:
		_box("paper", Vector3(0.2, 0.9 + i * 0.03, 0.8 + (i % 2) * 0.05), Vector3(0.45, 0.025, 0.35), Vector3(0, i * 7, 0))
	_pop()
	# drying lines with sheets out in the yard
	for z in [-1.2, 1.2]:
		var a := Vector3(w * 0.5 + 3.4, 0, z - 1.0)
		var b := Vector3(w * 0.5 + 3.4, 0, z + 1.0)
		_beam("wood", a, a + Vector3(0, 2.0, 0), 0.06)
		_beam("wood", b, b + Vector3(0, 2.0, 0), 0.06)
		_rod("rope", a + Vector3(0, 1.9, 0), b + Vector3(0, 1.9, 0), 0.012, 3)
		for k in 4:
			var p := a.lerp(b, (k + 0.6) / 4.6) + Vector3(0, 1.9, 0)
			_box("paper", p - Vector3(0, 0.25, 0), Vector3(0.02, 0.48, 0.34))
	_books(Vector3(-w * 0.5 - 0.7, 0, 2.0))
	_model(BOATS + "crate.glb", Vector3(-w * 0.5 - 0.9, 0, 0.6), Vector3(0, 15, 0), 0.9, null, SHIP)


## A wooden hand press: two cheeks, a head with the brass screw and bar, the bed and tympan.
func _press(c: Vector3) -> void:
	_push(_xf(c))
	for sx in [-0.45, 0.45]:
		_box("wood_dark", Vector3(sx, 1.0, 0), Vector3(0.16, 2.0, 0.3))
	_box("wood_dark", Vector3(0, 1.95, 0), Vector3(1.1, 0.22, 0.34))
	_box("wood_dark", Vector3(0, 1.25, 0), Vector3(1.0, 0.16, 0.3))
	_rod("brass", Vector3(0, 1.95, 0), Vector3(0, 1.25, 0), 0.05, 6)
	_beam("iron", Vector3(0, 1.55, 0), Vector3(0.5, 1.55, 0.55), 0.035)
	_box("wood", Vector3(0, 0.8, 0.4), Vector3(0.8, 0.1, 1.4))
	_box("wood_dark", Vector3(0, 0.4, 0.4), Vector3(0.7, 0.8, 0.12))
	_box("paper", Vector3(0, 0.88, 0.75), Vector3(0.55, 0.02, 0.45))
	_box("iron", Vector3(0, 0.88, 0.05), Vector3(0.6, 0.04, 0.45))
	_pop()


func _books(c: Vector3) -> void:
	var cols := ["paint_plum", "paint_blue", "paint_green", "paint_red", "leather", "cloth_gold"]
	for stack in 3:
		var y := 0.0
		for i in 5 + stack:
			var sz := Vector3(0.5 + _rng.randf_range(-0.06, 0.06), 0.09, 0.36)
			var p := c + Vector3((stack - 1) * 0.62, y + 0.045, _rng.randf_range(-0.03, 0.03))
			_box(cols[(i + stack * 2) % cols.size()], p, sz, Vector3(0, _rng.randf_range(-8, 8), 0))
			_box("paper", p + Vector3(0.0, 0, 0.005), Vector3(sz.x - 0.06, sz.y - 0.02, sz.z + 0.004))
			y += 0.09
		if stack == 1:
			_beam("rope", c + Vector3(0, 0, 0.19), c + Vector3(0, y + 0.01, 0.19), 0.012)


func _laboratory() -> void:
	# Early science: a small brick laboratory with a tall furnace chimney and a glass lantern
	# roof; outside, the athanor glowing, a bench of glassware and the armillary sphere.
	_begin("laboratory")
	_lab_body(true)
	_save("laboratory")
	_begin("laboratory_plot")
	_plot3(6.0, 5.0)
	_save("laboratory_plot")
	_begin("laboratory_frame")
	_frame3(5.0, 5.0, 3.6, 0.5, "brick")
	_save("laboratory_frame")


func _lab_body(done: bool) -> void:
	var w := 5.0
	var d := 5.0
	_upper_floor(w, d, 0.0, 3.6, "brick", {"front": "T-T", "back": "T-T", "left": "-T-", "right": "-T-"}, "paint_plum", 0.0)
	_push(_xf(Vector3(0, 0, d * 0.5 + 0.02)))
	_door(Vector3(0, 0, 0.06), 1.0, 2.3, "paint_plum", true)
	_pop()
	var ridge := _roof3("slate", w + 0.1, d + 0.1, 3.6, 2.0, 0.35, 1.0)
	# glass lantern on the ridge: brass frame, dark glazing
	_box("glass_dark", Vector3(0, ridge + 0.35, 0), Vector3(1.4, 0.7, 1.4))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_beam("brass", Vector3(c.x * 0.71, ridge, c.y * 0.71), Vector3(c.x * 0.71, ridge + 0.72, c.y * 0.71), 0.05)
	_lathe("verdigris", Vector3(0, ridge + 0.7, 0), [Vector2(1.0, 0), Vector2(0.0, 0.6)], 4, Vector3(0, 45, 0))
	_rod("iron", Vector3(0, ridge + 1.3, 0), Vector3(0, ridge + 2.0, 0), 0.03, 5)
	_ball("brass", Vector3(0, ridge + 2.0, 0), 0.09, 5, 3)
	_chimney(Vector3(-w * 0.5 + 0.5, 0, -d * 0.5 + 0.5), 7.6, 0.9)
	# the athanor: a brick tower furnace with a domed top and a glowing door
	var ac := Vector3(w * 0.5 + 1.4, 0, -0.8)
	_box("brick", ac + Vector3(0, 0.9, 0), Vector3(1.2, 1.8, 1.2))
	_lathe("brick", ac + Vector3(0, 1.8, 0), [Vector2(0.75, 0), Vector2(0.55, 0.45), Vector2(0.2, 0.7), Vector2(0.18, 1.4), Vector2(0, 1.4)], 8)
	_box("iron", ac + Vector3(0, 0.6, 0.61), Vector3(0.5, 0.45, 0.04))
	_glow(ac + Vector3(0, 0.6, 0.64), 0.14, Vector3(0, 0, 1))
	# bench of glassware
	_bench(Vector3(w * 0.5 + 1.4, 0, 1.4), 90, 1.6, 0.85, 0.6)
	_glassware(Vector3(w * 0.5 + 1.4, 0.89, 1.4))
	_armillary(Vector3(-w * 0.5 - 1.2, 0, 1.6), 0.8)
	_shop_sign(Vector3(-w * 0.5 + 0.3, 2.7, d * 0.5 + 0.02), 0, "paint_plum", "mortar")


## Flasks, a retort and an alembic in jewel-tinted glass.
func _glassware(c: Vector3) -> void:
	var cols := ["paint_teal", "glass_dark", "paint_blue", "cloth_plum", "verdigris"]
	for i in 5:
		var p := c + Vector3(0, 0, -0.6 + i * 0.3)
		match i % 3:
			0:
				_lathe(cols[i], p, [Vector2(0.03, 0), Vector2(0.11, 0.04), Vector2(0.12, 0.12), Vector2(0.04, 0.22), Vector2(0.03, 0.34), Vector2(0, 0.34)], 8)
			1:
				_ball(cols[i], p + Vector3(0, 0.1, 0), 0.1, 8, 4)
				_rod(cols[i], p + Vector3(0, 0.16, 0), p + Vector3(0.0, 0.26, 0.22), 0.025, 5, 0.012)
			2:
				_lathe(cols[i], p, [Vector2(0.06, 0), Vector2(0.06, 0.22), Vector2(0.04, 0.24), Vector2(0, 0.24)], 7)
	_box("iron", c + Vector3(0, 0.02, 0.75), Vector3(0.2, 0.04, 0.2))
	_glow(c + Vector3(0, 0.05, 0.75), 0.06, Vector3.UP)


func _clinic() -> void:
	# The sickness answer (DESIGN 8.2): a whitewashed infirmary with sky-blue shutters, a herb
	# garden, a porch bench, clean linen drying, a pump for clean water.
	_begin("clinic")
	_clinic_body()
	_save("clinic")
	_begin("clinic_plot")
	_plot3(8.0, 6.0)
	_save("clinic_plot")
	_begin("clinic_frame")
	_frame3(8.0, 5.0, 5.5, 0.45, "town_stone")
	_save("clinic_frame")


func _clinic_body() -> void:
	_stone_walls(4, 2, 0.95, {
		"front": ["Wall_UnevenBrick_Window_Wide_Flat", "Wall_UnevenBrick_Door_Flat", "Wall_UnevenBrick_Window_Wide_Flat", "Wall_UnevenBrick_Window_Wide_Flat"],
		"back": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Wide_Flat", "Wall_UnevenBrick_Window_Wide_Flat", "Wall_UnevenBrick_Straight"],
		"left": ["Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Straight"],
		"right": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round"]}, "paint_blue")
	var y1 := 3.12 * 0.95
	_upper_floor(8.0, 4.0, y1, 2.7, "daub", {"front": "WWWW", "back": "W-W-", "left": "-W", "right": "W-"}, "paint_blue", 0.1)
	var wt := y1 + 2.7
	_roof3("roof_tiles", 8.2, 4.2, wt, 2.3, 0.45, 0.0, "daub")
	_chimney(Vector3(2.2, wt + 0.5, -0.8), 2.4)
	_shop_sign(Vector3(-2.0, 2.6, 2.1), 0, "paint_blue", "mortar")
	# porch over the door
	_push(_xf(Vector3(-1.0, 0, 2.1)))
	for sx in [-0.9, 0.9]:
		_beam("timber", Vector3(sx, 0, 1.3), Vector3(sx, 2.5, 1.3), 0.12)
	_slab("roof_tiles", [Vector3(-1.2, 2.6, 1.6), Vector3(1.2, 2.6, 1.6), Vector3(1.2, 2.95, 0.0), Vector3(-1.2, 2.95, 0.0)], 0.1,
		Vector3(0, 1, 0.2), [Vector3.RIGHT, Vector3.FORWARD, 1.6])
	_pop()
	_bench(Vector3(1.5, 0, 2.7), 0, 1.6, 0.45, 0.4)
	# herb garden beds before the house
	for bx in [-3.0, 3.0]:
		_box("limestone", Vector3(bx, 0.15, 4.0), Vector3(1.8, 0.3, 1.4))
		_box("soil", Vector3(bx, 0.31, 4.0), Vector3(1.6, 0.04, 1.2))
		for i in 8:
			var p := Vector3(bx - 0.6 + (i % 4) * 0.4, 0.33, 3.7 + (i / 4) * 0.6)
			_ball("leaf" if i % 3 else "crop_young", p + Vector3(0, 0.1, 0), 0.15, 5, 3, Vector3(1, 0.8, 1))
			if i % 2 == 0:
				_ball(["plaster_sky", "cloth_plum", "linen"][i % 3], p + Vector3(0, 0.25, 0), 0.06, 5, 3)
	# clean linen on a line
	var a := Vector3(-4.6, 0, -1.6)
	var b := Vector3(-4.6, 0, 1.6)
	_beam("wood", a, a + Vector3(0, 2.0, 0), 0.06)
	_beam("wood", b, b + Vector3(0, 2.0, 0), 0.06)
	_rod("rope", a + Vector3(0, 1.9, 0), b + Vector3(0, 1.9, 0), 0.012, 3)
	for k in 3:
		var p := a.lerp(b, (k + 0.5) / 3.0) + Vector3(0, 1.9, 0)
		_box("linen", p - Vector3(0, 0.5, 0), Vector3(0.02, 1.0, 0.85))
	_pump(Vector3(4.8, 0, 1.6), -90)


## Cast-iron hand pump on a stone trough.
func _pump(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	_box("ashlar", Vector3(0, 0.3, 0.55), Vector3(1.2, 0.6, 0.6))
	_box("water", Vector3(0, 0.58, 0.55), Vector3(1.0, 0.03, 0.42))
	_lathe("paint_blue", Vector3(0, 0, 0), [Vector2(0.16, 0), Vector2(0.12, 0.2), Vector2(0.1, 1.3), Vector2(0.13, 1.35), Vector2(0.0, 1.45)], 8)
	_ball("brass", Vector3(0, 1.5, 0), 0.07, 5, 3)
	_rod("paint_blue", Vector3(0, 0.95, 0.06), Vector3(0, 0.85, 0.45), 0.04, 5, 0.03)
	_beam("iron", Vector3(0, 1.3, 0), Vector3(0, 1.55, -0.55), 0.04)
	_pop()


func _fire_station() -> void:
	# The town fire answer: a stone engine house with red doors, an open bell turret (Bell),
	# leather buckets on a rack, ladders on the wall and the hand-pumped fire engine outside.
	_begin("fire_station")
	_fire_body()
	_save("fire_station")
	_begin("fire_station_plot")
	_plot3(6.0, 6.0)
	_save("fire_station_plot")
	_begin("fire_station_frame")
	_frame3(6.0, 6.0, 4.2, 0.5, "town_stone")
	_save("fire_station_frame")


func _fire_body() -> void:
	var w := 6.0
	var d := 6.0
	var wh := 4.2
	_upper_floor(w, d, 0.0, wh, "town_stone", {"front": "---", "back": "-W-", "left": "-T-", "right": "W-W"}, "paint_red", 0.0)
	_push(_xf(Vector3(0, 0, d * 0.5 + 0.02)))
	_box("ashlar", Vector3(0, 1.75, 0.04), Vector3(3.6, 3.5, 0.12))
	for sx in [-0.8, 0.8]:
		_box("paint_red", Vector3(sx, 1.5, 0.12), Vector3(1.55, 3.0, 0.1))
		for k in 3:
			_box("iron", Vector3(sx, 0.4 + k * 1.1, 0.18), Vector3(1.4, 0.06, 0.02))
	_beam("brass", Vector3(0, 0.1, 0.2), Vector3(0, 2.95, 0.2), 0.04)
	_box("slate_flat", Vector3(0, 3.75, 0.12), Vector3(2.4, 0.4, 0.05))
	_box("cloth_gold", Vector3(0, 3.75, 0.15), Vector3(1.8, 0.06, 0.02))
	_pop()
	var ridge := _roof3("roof_tiles", w + 0.2, d + 0.2, wh, 2.2, 0.4, 0.0, "town_stone", 90)
	# bell turret astride the ridge
	var tz := 1.0
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_beam("timber", Vector3(c.x * 0.6, ridge - 0.6, tz + c.y * 0.6), Vector3(c.x * 0.6, ridge + 1.4, tz + c.y * 0.6), 0.14)
	_lathe("roof_tiles", Vector3(0, ridge + 1.4, tz), [Vector2(1.1, 0), Vector2(0.0, 1.1)], 4, Vector3(0, 45, 0))
	_rod("iron", Vector3(0, ridge + 2.4, tz), Vector3(0, ridge + 3.0, tz), 0.03, 5)
	var bell := _part("Bell", Vector3(0, ridge + 1.25, tz), func() -> void:
		_lathe("bronze", Vector3(0, -0.6, 0), [Vector2(0.32, 0), Vector2(0.28, 0.08), Vector2(0.18, 0.32), Vector2(0.16, 0.55), Vector2(0.0, 0.6)], 10))
	bell.set_script(SPINNER)
	bell.set("spinning", false)
	bell.set("axis", Vector3.RIGHT)
	# ladders on the right wall, the bucket rack on the left
	for k in 2:
		_ladder(Vector3(w * 0.5 + 0.12, 0.3 + k * 1.3, -2.4), Vector3(w * 0.5 + 0.12, 0.3 + k * 1.3, 2.4), 0.45)
	_fire_buckets(Vector3(-w * 0.5 - 0.35, 0, 0.5), 90)
	_fire_cart(Vector3(1.6, 0, d * 0.5 + 2.4), -20)
	_lantern(Vector3(-2.3, 3.0, d * 0.5 + 0.35))
	_beam("iron", Vector3(-2.3, 3.2, d * 0.5), Vector3(-2.3, 3.2, d * 0.5 + 0.35), 0.04)


func _fire_buckets(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	for sx in [-1.0, 1.0]:
		_beam("wood_dark", Vector3(sx * 1.0, 0, 0), Vector3(sx * 1.0, 1.7, 0), 0.08)
	_beam("wood_dark", Vector3(-1.1, 1.6, 0), Vector3(1.1, 1.6, 0), 0.08)
	_beam("wood_dark", Vector3(-1.1, 0.85, 0), Vector3(1.1, 0.85, 0), 0.08)
	for row in 2:
		for i in 4:
			var b := Vector3(-0.75 + i * 0.5, 1.2 - row * 0.75, 0.12)
			_lathe("leather", b - Vector3(0, 0.32, 0), [Vector2(0.1, 0), Vector2(0.15, 0.32), Vector2(0.13, 0.32), Vector2(0.08, 0.03)], 8)
			_box("cloth_gold", b - Vector3(0, 0.18, -0.13), Vector3(0.1, 0.08, 0.01))
	_pop()


func _fire_cart(p: Vector3, rot_y: float) -> void:
	_push(_xf(p, rot_y))
	_box("paint_red", Vector3(0, 0.85, 0), Vector3(1.1, 0.6, 1.8))
	_box("brass", Vector3(0, 1.17, 0), Vector3(1.15, 0.05, 1.85))
	_box("brass", Vector3(0, 0.85, 0.91), Vector3(0.7, 0.3, 0.02))
	_lathe("brass", Vector3(0, 1.15, 0), [Vector2(0.16, 0), Vector2(0.14, 0.6), Vector2(0.2, 0.62), Vector2(0, 0.7)], 8)
	_beam("wood", Vector3(-0.75, 1.75, -0.9), Vector3(-0.75, 1.75, 0.9), 0.06)
	_beam("wood", Vector3(0.75, 1.75, -0.9), Vector3(0.75, 1.75, 0.9), 0.06)
	for sz in [-0.9, 0.9]:
		_beam("iron", Vector3(-0.75, 1.75, sz), Vector3(0.75, 1.75, sz), 0.05)
	_beam("iron", Vector3(0, 1.2, 0), Vector3(0, 1.75, 0), 0.05)
	_lathe("leather", Vector3(0.5, 0.0, 1.1), [Vector2(0.28, 0.6), Vector2(0.28, 0.68), Vector2(0.18, 0.68), Vector2(0.18, 0.6)], 10)
	for sz in [-0.55, 0.55]:
		for sx in [-1.0, 1.0]:
			_wheel(Vector3(sx * 0.68, 0.48, sz), 0.48)
	_beam("wood", Vector3(0, 0.6, 0.9), Vector3(0, 0.55, 2.1), 0.08)
	_beam("wood", Vector3(-0.35, 0.55, 2.1), Vector3(0.35, 0.55, 2.1), 0.06)
	_pop()


# ================================================================== mills

func _windmill() -> void:
	# The tower mill (upgrade of the Era 2 post mill): a tapered stone tower, a reefing stage,
	# a boat-shaped cap, and four great sails that turn (Sails).
	_begin("windmill")
	_windmill_body(true)
	_save("windmill")
	_begin("windmill_plot")
	_plot3(6.0, 6.0, true)
	_save("windmill_plot")
	_begin("windmill_frame")
	_windmill_body(false)
	_save("windmill_frame")


func _windmill_body(done: bool) -> void:
	var r0 := 3.0
	var r1 := 2.2
	var h := 9.0 if done else 4.0
	_cyl("ashlar", Vector3.ZERO, r0 + 0.2, r0 + 0.2, 0.4, 14)
	_lathe("plaster", Vector3(0, 0.4, 0), [Vector2(r0, 0), Vector2(lerpf(r0, r1, h / 9.0), h), Vector2(0, h)], 14)
	for k in 3:   # limestone bands
		var y := 0.4 + 2.6 + k * 2.4
		if y < h:
			var r := lerpf(r0, r1, (y - 0.4) / 9.0)
			_lathe("limestone", Vector3(0, y, 0), [Vector2(r + 0.06, 0), Vector2(r + 0.06, 0.18), Vector2(0, 0.18)], 14)
	_push(_xf(Vector3(0, 0.4, r0 - 0.02)))
	_door(Vector3(0, 0, 0.0), 1.1, 2.3, "paint_teal", true)
	_pop()
	for k in 4:
		var a := TAU * k / 4.0 + 0.6
		var y := 1.6 + k * 1.6
		if y + 1.0 > h:
			continue
		var r := lerpf(r0, r1, y / 9.0)
		_push(Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * (r - 0.02)))
		_lancet(Vector3(0, y, 0), 0.6, 1.1, "glass_dark")
		_pop()
	if not done:
		for k in 8:
			var a := TAU * k / 8.0
			_rod("wood", Vector3(cos(a) * (r0 + 0.6), 0, sin(a) * (r0 + 0.6)), Vector3(cos(a) * (r0 + 0.4), 6.0, sin(a) * (r0 + 0.4)), 0.07, 5)
		_lathe("planks", Vector3(0, 4.2, 0), [Vector2(r0 + 0.8, 0), Vector2(r0 + 0.8, 0.06), Vector2(r0 - 0.4, 0.06), Vector2(r0 - 0.4, 0)], 12)
		_stone_pile(Vector3(-r0 - 1.6, 0, 1.0), 1.0)
		_rod("wood", Vector3(-1.5, 0.2, r0 + 2.0), Vector3(3.5, 0.2, r0 + 1.5), 0.12, 6)   # a sail stock waiting
		return
	# reefing stage at 3.6 m
	var sy := 3.6
	var rs := lerpf(r0, r1, sy / 9.0)
	_lathe("planks", Vector3(0, sy, 0), [Vector2(rs + 1.2, 0), Vector2(rs + 1.2, 0.1), Vector2(rs - 0.1, 0.1), Vector2(rs - 0.1, 0)], 16)
	for k in 16:
		var a := TAU * k / 16.0
		_beam("timber", Vector3(cos(a) * (rs - 0.05), sy - 0.9, sin(a) * (rs - 0.05)), Vector3(cos(a) * (rs + 1.1), sy, sin(a) * (rs + 1.1)), 0.08)
	var ring := []
	for k in 16:
		var a := TAU * k / 16.0
		ring.append(Vector3(cos(a) * (rs + 1.15), sy + 0.1, sin(a) * (rs + 1.15)))
	_railing(ring, 0.8, true)
	# cap: a boat-shaped hood of slate over a curb, the windshaft out the front
	var cy := 0.4 + 9.0
	_lathe("wood_dark", Vector3(0, cy, 0), [Vector2(r1 + 0.25, 0), Vector2(r1 + 0.25, 0.3), Vector2(0, 0.3)], 14)
	_lathe("slate", Vector3(0, cy + 0.3, 0), [Vector2(r1 + 0.3, 0), Vector2(r1 + 0.1, 0.9), Vector2(r1 * 0.6, 1.8), Vector2(0.0, 2.2)], 10,
		Vector3.ZERO, Vector3(0.9, 1, 1.25), 0.0, true, 1.0)
	_ball("brass", Vector3(0, cy + 2.55, 0), 0.14, 6, 3)
	var hub := Vector3(0, cy + 1.0, r1 * 1.25 + 0.6)
	_rod("timber", hub - Vector3(0, 0, 1.2), hub, 0.22, 8)
	var sails := _part("Sails", hub, func() -> void:
		for i in 4:
			var a := TAU * i / 4.0 + 0.3
			var dir := Vector3(cos(a), sin(a), 0)
			var side := Vector3(-sin(a), cos(a), 0)
			_beam("timber", dir * 0.2, dir * 6.6, 0.16)
			var y0 := 1.3
			for sgn in [1.0, -0.55]:
				_beam("wood", dir * y0 + side * 1.0 * sgn, dir * 6.5 + side * 1.0 * sgn, 0.06)
			for k in 9:
				var t := y0 + k * (6.5 - y0) / 8.0
				_beam("wood", dir * t - side * 0.55, dir * t + side * 1.0, 0.05)
			var c0 := dir * (y0 + 0.1) + side * 0.08 + Vector3(0, 0, 0.04)
			var c1 := dir * 6.4 + side * 0.08 + Vector3(0, 0, 0.04)
			_quad("linen", c0, c1, c1 + side * 0.88, c0 + side * 0.88, Vector3(0, 0, 1))
		_cyl("timber", Vector3(0, 0, -0.05), 0.42, 0.36, 0.35, 8, Vector3(90, 0, 0))
		_ball("brass", Vector3(0, 0, 0.35), 0.12, 6, 3))
	sails.set_script(SPINNER)
	sails.set("speed", 0.5)
	sails.set("axis", Vector3(0, 0, 1))
	# tail pole and fantail-less winch at the back, sacks at the door
	_beam("timber", Vector3(0, cy + 0.2, -r1 - 0.2), Vector3(0, 1.2, -r1 - 4.0), 0.16)
	_lathe("wood_dark", Vector3(0, 0.0, -r1 - 4.2), [Vector2(0.3, 0), Vector2(0.3, 1.2), Vector2(0, 1.2)], 7)
	for i in 3:
		_sack(Vector3(1.6 + i * 0.5, 0, r0 + 0.6 - (i % 2) * 0.4), "linen", 0.95)
	_model(V + "Prop_Wagon.gltf", Vector3(-3.4, 0, 3.0), Vector3(0, 60, 0), 0.9, null, MK)


func _watermill() -> void:
	# The water-driven mill on a stream: a stone mill house with a tile roof and an undershot
	# wheel turning in a stone mill race (Wheel). Self-contained: the race carries its water.
	_begin("watermill")
	_watermill_body(true)
	_save("watermill")
	_begin("watermill_plot")
	_plot3(6.0, 5.0)
	_save("watermill_plot")
	_begin("watermill_frame")
	_watermill_body(false)
	_save("watermill_frame")


func _watermill_body(done: bool) -> void:
	# the race runs along z on the +X side
	var rx := 4.3
	_box("ashlar", Vector3(rx - 1.0, 0.6, 0), Vector3(0.4, 1.2, 8.0))
	_box("ashlar", Vector3(rx + 1.0, 0.6, 0), Vector3(0.4, 1.2, 8.0))
	_box("stone_dark", Vector3(rx, 0.05, 0), Vector3(1.6, 0.1, 8.0))
	_box("water", Vector3(rx, 0.7, 0), Vector3(1.62, 0.04, 8.0))
	if not done:
		_frame3(6.0, 5.0, 4.0, 0.5)
		for k in 6:
			var a := TAU * k / 6.0
			_beam("wood", Vector3(rx + 1.3, 1.8 + sin(a) * 1.4, cos(a) * 1.4), Vector3(rx + 1.3, 1.8, 0), 0.08)
		return
	_stone_walls(3, 2, 1.0, {
		"front": ["Wall_UnevenBrick_Window_Wide_Flat", "Wall_UnevenBrick_Door_Round", "Wall_UnevenBrick_Straight"],
		"back": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Straight"],
		"left": ["Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Straight"],
		"right": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Window_Thin_Round"]}, "paint_green")
	_upper_floor(6.0, 4.0, 3.12, 1.6, "plaster", {"front": "-W-", "back": "-W-"}, "paint_green", 0.05)
	_roof3("roof_tiles", 6.2, 4.2, 4.72, 2.4, 0.45, 0.0, "plaster")
	_chimney(Vector3(-2.2, 5.0, -0.8), 2.2)
	_rod("wood_dark", Vector3(3.0, 1.8, 0), Vector3(rx + 0.9, 1.8, 0), 0.14, 8)   # axle into the house
	var wheel := _part("Wheel", Vector3(rx, 1.8, 0), func() -> void:
		var r := 1.75
		for sx in [-0.42, 0.42]:
			_lathe("wood", Vector3(sx, 0, 0), [Vector2(r, -0.05), Vector2(r, 0.05), Vector2(r - 0.15, 0.05), Vector2(r - 0.15, -0.05)], 18, Vector3(0, 0, 90))
			for k in 6:
				var a := TAU * k / 6.0
				_beam("wood_dark", Vector3(sx, 0, 0), Vector3(sx, sin(a) * (r - 0.1), cos(a) * (r - 0.1)), 0.08)
		for k in 18:
			var a := TAU * k / 18.0
			var p := Vector3(0, sin(a), cos(a))
			_box_b("planks", p * (r - 0.05), Vector3(0.95, 0.06, 0.4), Basis(Vector3.RIGHT, a + PI * 0.5) * Basis.IDENTITY)
		_cyl("wood_dark", Vector3(-0.5, 0, 0), 0.22, 0.22, 1.0, 8, Vector3(0, 0, 90)))
	wheel.set_script(SPINNER)
	wheel.set("speed", 0.6)
	wheel.set("axis", Vector3(-1, 0, 0))
	# sluice gate upstream, sacks and a millstone leaning by the door
	_box("wood_dark", Vector3(rx, 1.3, -3.4), Vector3(1.9, 0.14, 0.14))
	_box("planks", Vector3(rx, 1.0, -3.3), Vector3(1.5, 0.7, 0.06))
	_lathe("stone_light", Vector3(-1.6, 0.7, 2.6), [Vector2(0.7, -0.12), Vector2(0.7, 0.12), Vector2(0.12, 0.12), Vector2(0.12, -0.12)], 12, Vector3(80, 0, 0))
	for i in 3:
		_sack(Vector3(0.9 + i * 0.5, 0, 2.7 - (i % 2) * 0.3), "linen", 0.95)


# ================================================================== the coast

func _harbour() -> void:
	# Coast and Islands (DESIGN 10.1): a stone quay built out over the water (deck along X,
	# the sea side at -Z; piles and the quay face reach 2.2 m below ground), bollards, steps
	# down to the water, a jib crane that slews (Jib), cargo and lamps.
	_begin("harbour")
	_quay(true)
	_save("harbour")
	_begin("harbour_plot")
	_plot3(14.0, 4.0)
	_box("ashlar", Vector3(-5.0, -0.6, -3.6), Vector3(4.0, 1.2, 1.2))
	_save("harbour_plot")
	_begin("harbour_frame")
	_quay(false)
	_save("harbour_frame")


func _quay(done: bool) -> void:
	var l := 16.0
	var top := 0.5
	var front := -4.5
	var x1 := l * 0.5 if done else 0.0
	# the quay block: ashlar face down into the water, cobbled top
	_box("ashlar", Vector3((-l * 0.5 + x1) * 0.5, (top - 2.2) * 0.5, front * 0.5 + 1.0), Vector3(x1 + l * 0.5, top + 2.2, -front + 2.0))
	_box("limestone", Vector3((-l * 0.5 + x1) * 0.5, top + 0.05, front + 0.2), Vector3(x1 + l * 0.5, 0.12, 0.5))
	if done:
		_box("cobbles", Vector3(0, top + 0.06, front * 0.5 + 1.2), Vector3(l - 0.2, 0.02, -front + 1.4))
	else:
		_frame3(6.0, 3.0, 1.0, 0.0)
		for k in 5:
			_cyl("timber", Vector3(1.0 + k * 1.6, -2.2, front + 0.4), 0.14, 0.14, 2.9, 7)
		_stone_pile(Vector3(-3.0, top, 1.0), 1.0)
		return
	# steps down the face to the water at the left end
	for i in 6:
		_box("limestone", Vector3(-l * 0.5 + 1.6, top - 0.4 * i, front - 0.3 - 0.0), Vector3(2.0, 0.4, 0.6 + 0.0), Vector3.ZERO)
		_box("ashlar", Vector3(-l * 0.5 + 1.6, top - 0.4 * i - 0.2, front - 0.3 - i * 0.35), Vector3(2.0, 0.4, 0.4))
	# bollards, rope, mooring rings
	for x in [-4.0, 0.5, 5.0]:
		_lathe("iron", Vector3(x, top + 0.07, front + 0.35), [Vector2(0.18, 0), Vector2(0.14, 0.4), Vector2(0.22, 0.48), Vector2(0.22, 0.56), Vector2(0, 0.58)], 9)
	_lathe("rope", Vector3(0.5, top + 0.12, front + 0.35), [Vector2(0.24, 0.1), Vector2(0.24, 0.2), Vector2(0.16, 0.2), Vector2(0.16, 0.1)], 10)
	_lathe("rope", Vector3(2.2, top + 0.07, front + 1.3), [Vector2(0.4, 0), Vector2(0.4, 0.12), Vector2(0.16, 0.12), Vector2(0.16, 0)], 10)
	# jib crane: a stone base, a mast that slews with its jib and a hanging crate
	var cp := Vector3(3.2, top, front + 1.5)
	_cyl("ashlar", cp, 0.9, 0.85, 0.6, 10)
	var jib := _part("Jib", cp + Vector3(0, 0.6, 0), func() -> void:
		_beam("timber", Vector3.ZERO, Vector3(0, 5.2, 0), 0.3)
		_beam("timber", Vector3(0, 1.2, 0), Vector3(0, 4.9, -3.4), 0.2)
		_beam("timber", Vector3(0, 5.0, 0), Vector3(0, 4.9, -3.4), 0.14)
		_rod("rope", Vector3(0, 4.8, -3.3), Vector3(0, 2.0, -3.3), 0.025, 4)
		_beam("iron", Vector3(0, 2.0, -3.3), Vector3(0, 1.85, -3.3), 0.06)
		_box("wood_dark", Vector3(0, 1.45, -3.3), Vector3(0.7, 0.7, 0.7))
		_cyl("wood_dark", Vector3(0.25, 0.8, 0), 0.3, 0.3, 0.4, 9, Vector3(0, 0, 90)))
	jib.set_script(SPINNER)
	jib.set("spinning", false)
	jib.set("speed", 0.3)
	jib.set("axis", Vector3.UP)
	# cargo landed on the quay
	for p in [Vector3(-2.0, top, 0.6), Vector3(-1.2, top, 1.0), Vector3(-1.6, top + 0.8, 0.8)]:
		_model(BOATS + "crate.glb", p, Vector3(0, _rng.randf_range(-20, 20), 0), 0.9, null, SHIP)
	_model(BOATS + "crate-bottles.glb", Vector3(-3.2, top, 1.4), Vector3(0, 30, 0), 0.9, null, SHIP)
	for i in 3:
		_model(K + "barrel.glb", Vector3(5.6 + (i % 2) * 0.6, top, 0.5 + i * 0.55), Vector3.ZERO, 3.2, null, KEN)
	_sack(Vector3(-5.2, top, 1.2), "linen", 1.0)
	_sack(Vector3(-4.7, top, 1.5), "rope", 0.9)
	for x in [-6.6, 6.6]:
		_rod("iron", Vector3(x, top, 1.4), Vector3(x, top + 3.0, 1.4), 0.06, 6)
		_lantern(Vector3(x, top + 3.2, 1.4), 1.2)
	# piles beneath the outer edge, seen at low water
	for k in 9:
		_cyl("timber", Vector3(-7.0 + k * 1.75, -2.2, front - 0.15), 0.16, 0.16, 2.5, 7)


func _lighthouse() -> void:
	# A white-and-red banded tower on a rock, a railed gallery, the glazed lantern room with
	# the turning lens (Beam: its SpotLight3D is off until gameplay lights it at night).
	_begin("lighthouse")
	_light_tower(true)
	_save("lighthouse")
	_begin("lighthouse_plot")
	_rocks_base()
	_plot3(5.0, 5.0, true)
	_save("lighthouse_plot")
	_begin("lighthouse_frame")
	_light_tower(false)
	_save("lighthouse_frame")


func _rocks_base() -> void:
	for r in [["Rock_6.fbx", Vector3(-2.6, -0.4, 0.8), 30.0, Vector3(2.2, 1.4, 2.0)], ["Rock_4.fbx", Vector3(2.4, -0.4, -1.0), 110.0, Vector3(2.0, 1.2, 1.8)],
			["Rock_7.fbx", Vector3(0.4, -0.5, 2.6), 200.0, Vector3(1.8, 1.0, 1.6)], ["Rock_2.fbx", Vector3(-1.4, -0.3, -2.6), 60.0, Vector3(1.4, 1.0, 1.4)]]:
		_model(N + r[0], r[1], Vector3(0, r[2], 0), r[3], null, {"hog_pull": 0.25})


func _light_tower(done: bool) -> void:
	_rocks_base()
	_cyl("ashlar", Vector3(0, -0.2, 0), 3.0, 2.8, 1.0, 14)
	var r0 := 2.1
	var r1 := 1.45
	var h := 12.0 if done else 4.5
	var y0 := 0.8
	var bands := 6
	for k in bands:
		var a := float(k) / bands
		var b := float(k + 1) / bands
		if a * 12.0 >= h:
			break
		var yb := y0 + minf(b * 12.0, h)
		_lathe("paint_red" if k % 2 == 1 else "plaster", Vector3(0, y0 + a * 12.0, 0),
			[Vector2(lerpf(r0, r1, a), 0), Vector2(lerpf(r0, r1, (yb - y0) / 12.0), yb - y0 - a * 12.0), Vector2(0, yb - y0 - a * 12.0)], 14)
	_push(_xf(Vector3(0, y0, r0 - 0.04)))
	_door(Vector3(0, 0, 0.0), 0.9, 2.1, "paint_teal", true)
	_pop()
	for k in 3:
		var y := 3.5 + k * 3.0
		if y + 1.0 > h:
			continue
		var r := lerpf(r0, r1, y / 12.0)
		var a := 0.8 + k * 2.0
		_push(Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * (r - 0.03)))
		_lancet(Vector3(0, y0 + y, 0), 0.5, 0.95, "glass_dark")
		_pop()
	if not done:
		for k in 6:
			var a := TAU * k / 6.0
			_rod("wood", Vector3(cos(a) * (r0 + 0.6), 0.8, sin(a) * (r0 + 0.6)), Vector3(cos(a) * (r0 + 0.5), 7.0, sin(a) * (r0 + 0.5)), 0.07, 5)
		_lathe("planks", Vector3(0, 4.6, 0), [Vector2(r0 + 0.8, 0), Vector2(r0 + 0.8, 0.06), Vector2(r0 - 0.2, 0.06), Vector2(r0 - 0.2, 0)], 12)
		_stone_pile(Vector3(-3.2, 0.5, 2.6), 0.8)
		return
	var gy := y0 + 12.0
	_lathe("limestone", Vector3(0, gy, 0), [Vector2(r1 + 0.75, 0), Vector2(r1 + 0.75, 0.25), Vector2(0, 0.25)], 14)
	for k in 14:
		var a := TAU * k / 14.0
		_beam("limestone", Vector3(cos(a) * (r1 - 0.05), gy - 0.8, sin(a) * (r1 - 0.05)), Vector3(cos(a) * (r1 + 0.6), gy, sin(a) * (r1 + 0.6)), 0.14)
	var ring := []
	for k in 14:
		var a := TAU * k / 14.0
		ring.append(Vector3(cos(a) * (r1 + 0.7), gy + 0.25, sin(a) * (r1 + 0.7)))
	_railing(ring, 0.85, true)
	# lantern room: iron mullions round the glass, copper dome, ball and vane
	var ly := gy + 0.25
	_lathe("iron", Vector3(0, ly, 0), [Vector2(1.05, 0), Vector2(1.05, 0.5), Vector2(0, 0.5)], 8)
	_lathe("glass_dark", Vector3(0, ly + 0.5, 0), [Vector2(0.98, 0), Vector2(0.98, 1.5), Vector2(0, 1.5)], 8)
	for k in 8:
		var a := TAU * k / 8.0
		_beam("iron", Vector3(cos(a), ly + 0.5, sin(a)), Vector3(cos(a), ly + 2.0, sin(a)), 0.06)
	_lathe("verdigris", Vector3(0, ly + 2.0, 0), [Vector2(1.25, 0), Vector2(1.1, 0.25), Vector2(0.6, 0.8), Vector2(0.2, 1.1), Vector2(0, 1.15)], 8)
	_ball("brass", Vector3(0, ly + 3.25, 0), 0.16, 7, 4)
	_rod("iron", Vector3(0, ly + 3.3, 0), Vector3(0, ly + 4.0, 0), 0.03, 5)
	var beam := _part("Beam", Vector3(0, ly + 1.25, 0), func() -> void:
		_cyl("brass", Vector3(0, -0.55, 0), 0.25, 0.25, 0.15, 8)
		for sz in [-1.0, 1.0]:
			_lathe("beacon", Vector3(0, 0, sz * 0.32), [Vector2(0.38, 0), Vector2(0.0, 0.12)], 10, Vector3(90 * sz, 0, 0))
			_lathe("brass", Vector3(0, 0, sz * 0.32), [Vector2(0.42, -0.04), Vector2(0.42, 0.04), Vector2(0.36, 0.04), Vector2(0.36, -0.04)], 10, Vector3(90, 0, 0), Vector3.ONE, 0.0, false)
		_box("lamp_glow", Vector3.ZERO, Vector3(0.4, 0.5, 0.4)))
	beam.set_script(SPINNER)
	beam.set("speed", 0.9)
	beam.set("axis", Vector3.UP)
	var spot := SpotLight3D.new()
	spot.name = "BeamLight"
	spot.light_color = Color("#fff0c8")
	spot.light_energy = 6.0
	spot.spot_range = 80.0
	spot.spot_angle = 9.0
	spot.visible = false
	spot.rotation_degrees = Vector3(-4, 0, 0)
	beam.add_child(spot)
	spot.owner = _root


## The Kenney Pirate Kit ships, rebuilt in the Era 3 palette: the pack's geometry
## is read face by face and each face is given a town material by the colour it
## sampled from the pack's colour map (warm wood, dark tarred wales, iron, brass),
## the sails plain undyed linen and the pennants the town's plum. The hull is made
## a little longer and slimmer, and the masts a touch taller, so it reads less
## like a toy.
func _ships() -> void:
	_begin("ship_small")
	_ship(BOATS + "ship-small.glb", 1.2)
	_save("ship_small")
	_begin("ship_merchant")
	_ship(BOATS + "ship-medium.glb", 1.25)
	_save("ship_merchant")


const SHIP_SHAPE := Vector3(0.84, 1.08, 1.16)   # slimmer, taller, longer

func _ship(path: String, s: float) -> void:
	var src := (load(path) as PackedScene).instantiate() as Node3D
	var cmap: Image = (load(BOATS + "Textures/colormap.png") as Texture2D).get_image()
	if cmap.is_compressed():
		cmap.decompress()
	var stack: Array = [[src, Transform3D.IDENTITY]]
	var shape := Basis.from_scale(SHIP_SHAPE * s)
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var xf: Transform3D = it[1]
		if n is Node3D and n != src:
			xf = xf * (n as Node3D).transform
		for c in n.get_children():
			stack.append([c, xf])
		if not (n is MeshInstance3D):
			continue
		var mesh := (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		var part := String(n.name)
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			for t in range(0, idx.size() - 2, 3):
				var a := idx[t]
				var b := idx[t + 1]
				var c := idx[t + 2]
				var col := Color(0.6, 0.45, 0.3)
				if not uv.is_empty():
					var u := (uv[a] + uv[b] + uv[c]) / 3.0
					col = cmap.get_pixel(clampi(int(u.x * cmap.get_width()), 0, cmap.get_width() - 1),
						clampi(int(u.y * cmap.get_height()), 0, cmap.get_height() - 1))
				var m := _ship_material(part, col)
				var pa := shape * (xf * v[a])
				var pb := shape * (xf * v[b])
				var pc := shape * (xf * v[c])
				var out := shape.inverse().transposed() * (xf.basis * (nr[a] + nr[b] + nr[c]))
				_tri(m, pa, pb, pc, out, _auto_uv(pa, out), _auto_uv(pb, out), _auto_uv(pc, out))
	src.free()


## Which town material a face of the pack's ship becomes.
func _ship_material(part: String, col: Color) -> String:
	if part.begins_with("sail"):
		return "linen"
	if part.begins_with("flag"):
		return "cloth_plum"
	var l := col.get_luminance()
	if col.s < 0.2:
		if l > 0.8:
			return "linen"       # rigging, trims
		return "iron" if l < 0.35 else "iron_light"
	if col.h > 0.1 and col.h < 0.2 and col.s > 0.5:
		return "brass"
	if col.h > 0.5 and col.h < 0.8:
		return "paint_blue" if l < 0.6 else "linen"
	if col.h > 0.25 and col.h <= 0.5:
		return "paint_green"
	# the warm range: the pack's salmon and brown woods
	if l > 0.62:
		return "wood"
	if l > 0.42:
		return "timber"
	return "wood_dark"


# ================================================================== the aqueduct (milestone 2)

const AQ_L := 12.0     # one segment along X; segments chain end to end
const AQ_SPRING := 5.6
const AQ_R := 1.45
const AQ_TOP := 8.4


func _aqueduct() -> void:
	# A giant group build: one 12 m segment of arches carrying the water channel. Piers stand
	# every 4 m (x = -4, 0, 4), so the segment ends mid-span and segments chain seamlessly.
	_begin("aqueduct")
	_aq_segment(true)
	_save("aqueduct")
	_begin("aqueduct_plot")
	_plot3(AQ_L, 2.4)
	_save("aqueduct_plot")
	_begin("aqueduct_frame")
	_aq_segment(false)
	_save("aqueduct_frame")
	# the end of the line: a castellum (distribution tank) pouring into a basin
	_begin("aqueduct_end")
	_box("ashlar_warm", Vector3(0, AQ_TOP * 0.5, 0), Vector3(3.2, AQ_TOP, 3.2))
	_box("limestone", Vector3(0, AQ_TOP + 0.1, 0), Vector3(3.5, 0.25, 3.5))
	for k in 3:
		_box("limestone", Vector3(0, 2.2 + k * 2.2, 0), Vector3(3.3, 0.14, 3.3))
	_box("ashlar_warm", Vector3(-2.0, AQ_TOP - 0.6, 0), Vector3(1.0, 1.2, 1.8))   # channel inlet from -X
	_box("water", Vector3(-2.0, AQ_TOP - 0.05, 0), Vector3(1.0, 0.04, 1.0))
	_push(_xf(Vector3(0, 0, 1.6)))
	_rose(Vector3(0, 5.0, 0.02), 0.7)
	for sx in [-0.8, 0.0, 0.8]:
		_box("limestone", Vector3(sx, 2.6, 0.2), Vector3(0.24, 0.24, 0.5))
		_rod("water", Vector3(sx, 2.6, 0.45), Vector3(sx, 0.55, 1.6), 0.07, 6, 0.1)
	_pop()
	_lathe("ashlar", Vector3(0, 0, 2.8), [Vector2(2.2, 0), Vector2(2.2, 0.6), Vector2(1.9, 0.6), Vector2(1.9, 0.15)], 14)
	_lathe("water", Vector3(0, 0.5, 2.8), [Vector2(1.9, 0), Vector2(0, 0)], 14)
	_save("aqueduct_end")


func _aq_segment(done: bool) -> void:
	var hd := 1.2
	for px in [-4.0, 0.0, 4.0]:
		var ph := AQ_SPRING if done else 3.2
		_box("ashlar_warm", Vector3(px, ph * 0.5, 0), Vector3(1.1, ph, hd * 2))
		_box("ashlar", Vector3(px, 0.3, 0), Vector3(1.5, 0.6, hd * 2 + 0.4))
		if done:
			_box("limestone", Vector3(px, AQ_SPRING - 0.1, 0), Vector3(1.3, 0.2, hd * 2 + 0.16))
			for sz in [-1.0, 1.0]:   # cutwater-like pilasters
				_box("ashlar_warm", Vector3(px, AQ_SPRING * 0.45, sz * (hd + 0.15)), Vector3(0.7, AQ_SPRING * 0.9, 0.3))
	if not done:
		# timber centering on two spans, a scaffold and the first voussoirs
		for cx in [-2.0, 2.0]:
			for sz in [-0.6, 0.6]:
				for k in 6:
					var a0 := PI * k / 6.0
					var a1 := PI * (k + 1) / 6.0
					_beam("wood", Vector3(cx + cos(a0) * AQ_R, 3.2 + sin(a0) * AQ_R, sz), Vector3(cx + cos(a1) * AQ_R, 3.2 + sin(a1) * AQ_R, sz), 0.12)
				_beam("wood", Vector3(cx - AQ_R, 3.2, sz), Vector3(cx + AQ_R, 3.2, sz), 0.12)
				_beam("wood", Vector3(cx, 3.2, sz), Vector3(cx, 3.2 + AQ_R, sz), 0.1)
			for k in 4:
				var a := PI * (k + 0.5) / 7.0
				_box("ashlar_warm", Vector3(cx - cos(a) * (AQ_R + 0.25), 3.2 + sin(a) * (AQ_R + 0.25), 0), Vector3(0.5, 0.4, hd * 2), Vector3(0, 0, rad_to_deg(a) - 90))
		for x in [-5.5, 5.5]:
			for z in [-1.8, 1.8]:
				_rod("wood", Vector3(x, 0, z), Vector3(x, 5.0, z), 0.07, 5)
			_box("planks", Vector3(x, 3.2, 0), Vector3(1.0, 0.06, 3.8))
		_stone_pile(Vector3(-2.0, 0, 2.6), 1.0)
		_ladder(Vector3(-5.0, 0, 2.6), Vector3(-5.0, 3.25, 1.6), 0.5)
		return
	# arches and spandrels, both faces; soffits under the arches
	for cx in [-6.0, -2.0, 2.0, 6.0]:
		var seg := 10
		for k in seg:
			var a0 := PI * k / seg
			var a1 := PI * (k + 1) / seg
			var p0 := Vector2(cx + cos(a0) * AQ_R, AQ_SPRING + sin(a0) * AQ_R)
			var p1 := Vector2(cx + cos(a1) * AQ_R, AQ_SPRING + sin(a1) * AQ_R)
			if maxf(p0.x, p1.x) > AQ_L * 0.5 + 0.01 or minf(p0.x, p1.x) < -AQ_L * 0.5 - 0.01:
				continue
			var top := AQ_TOP - 1.0
			for sz in [-1.0, 1.0]:
				var z: float = sz * hd
				_quad("ashlar_warm", Vector3(p0.x, p0.y, z), Vector3(p1.x, p1.y, z), Vector3(p1.x, top, z), Vector3(p0.x, top, z), Vector3(0, 0, sz))
				_beam("limestone", Vector3(p0.x, p0.y, z + sz * 0.05), Vector3(p1.x, p1.y, z + sz * 0.05), 0.24, 0.12)
			_quad("ashlar_warm", Vector3(p0.x, p0.y, hd), Vector3(p1.x, p1.y, hd), Vector3(p1.x, p1.y, -hd), Vector3(p0.x, p0.y, -hd),
				Vector3(-(p0.x + p1.x) * 0.5 + cx, AQ_SPRING - (p0.y + p1.y) * 0.5, 0))
	for px in [-4.0, 0.0, 4.0]:   # the spandrel wall above each pier, between two arches
		_box("ashlar_warm", Vector3(px, (AQ_SPRING + AQ_TOP - 1.0) * 0.5, 0), Vector3(1.1, AQ_TOP - 1.0 - AQ_SPRING, hd * 2))
	# the channel: a string course, side walls and the running water
	_box("limestone", Vector3(0, AQ_TOP - 1.0, 0), Vector3(AQ_L, 0.2, hd * 2 + 0.2))
	for sz in [-1.0, 1.0]:
		_box("ashlar_warm", Vector3(0, AQ_TOP - 0.45, sz * (hd - 0.25)), Vector3(AQ_L, 0.9, 0.5))
		_box("limestone", Vector3(0, AQ_TOP + 0.04, sz * (hd - 0.25)), Vector3(AQ_L, 0.1, 0.56))
	_box("ashlar", Vector3(0, AQ_TOP - 0.9, 0), Vector3(AQ_L, 0.1, 1.4))
	_box("water", Vector3(0, AQ_TOP - 0.25, 0), Vector3(AQ_L, 0.04, 1.4))


# ================================================================== streets and squares

## Paved road pieces, 4 x 4 m, laid along Z (DESIGN 10.3: desire lines become dirt paths,
## then roads, then streets). The surface sits 0.08 m proud of the ground.
func _roads() -> void:
	_begin("road_paved")
	_box("cobbles", Vector3(0, 0.04, 0), Vector3(3.0, 0.08, 4.0))
	for sx in [-1.0, 1.0]:
		_box("limestone", Vector3(sx * 1.65, 0.07, 0), Vector3(0.3, 0.14, 4.0))
		_box("stone_dark", Vector3(sx * 1.38, 0.083, 0), Vector3(0.22, 0.01, 4.0))   # gutter
	_save("road_paved")
	_begin("road_paved_cross")
	_box("cobbles", Vector3(0, 0.04, 0), Vector3(4.0, 0.08, 4.0))
	_lathe("limestone", Vector3(0, 0.081, 0), [Vector2(1.2, 0), Vector2(1.2, 0.01), Vector2(1.0, 0.01), Vector2(1.0, 0)], 16)
	_lathe("ashlar", Vector3(0, 0.08, 0), [Vector2(0.45, 0), Vector2(0.45, 0.012), Vector2(0, 0.012)], 12)
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_box("limestone", Vector3(c.x * 1.85, 0.07, c.y * 1.85), Vector3(0.3, 0.14, 0.3))
	_save("road_paved_cross")
	_begin("road_paved_end")   # where the street meets a dirt path: setts give out
	_box("cobbles", Vector3(0, 0.04, -0.8), Vector3(3.0, 0.08, 2.4))
	for sx in [-1.0, 1.0]:
		_box("limestone", Vector3(sx * 1.65, 0.07, -0.8), Vector3(0.3, 0.14, 2.4))
	for i in 26:
		var p := Vector3(_rng.randf_range(-1.4, 1.4), 0.03, _rng.randf_range(0.45, 2.0))
		if _rng.randf() < (p.z - 0.4) / 1.8:
			continue
		_box("ashlar", p, Vector3(0.22, 0.06, 0.18), Vector3(0, _rng.randf_range(-20, 20), 0))
	_save("road_paved_end")
	_begin("plaza")   # 6 x 6 flagstones with a limestone border, for squares and forecourts
	_box("ashlar_warm", Vector3(0, 0.04, 0), Vector3(5.6, 0.08, 5.6))
	for sx in [-1.0, 1.0]:
		_box("limestone", Vector3(sx * 2.9, 0.05, 0), Vector3(0.2, 0.1, 6.0))
		_box("limestone", Vector3(0, 0.05, sx * 2.9), Vector3(5.6, 0.1, 0.2))
	_save("plaza")


func _street_props() -> void:
	_begin("street_lamp")
	_cyl("ashlar", Vector3.ZERO, 0.22, 0.2, 0.3, 8)
	_lathe("iron", Vector3(0, 0.3, 0), [Vector2(0.12, 0), Vector2(0.07, 0.3), Vector2(0.05, 2.8), Vector2(0.09, 2.9), Vector2(0, 2.95)], 8)
	_beam("iron", Vector3(-0.3, 2.6, 0), Vector3(0.3, 2.6, 0), 0.03)
	_lantern(Vector3(0, 3.15, 0), 1.2)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.position = Vector3(0, 3.1, 0)
	l.light_color = Color("#ffc878")
	l.light_energy = 1.4
	l.omni_range = 7.0
	l.visible = false   # gameplay lights the lamps at dusk
	_root.add_child(l)
	l.owner = _root
	_save("street_lamp")

	_begin("fountain")   # the square's fountain: the open hand raised over the basin, pouring water
	_lathe("ashlar", Vector3.ZERO, [Vector2(2.6, 0), Vector2(2.6, 0.55), Vector2(2.75, 0.6), Vector2(2.75, 0.72), Vector2(2.35, 0.72), Vector2(2.35, 0.2), Vector2(0, 0.2)], 16)
	_lathe("water", Vector3(0, 0.6, 0), [Vector2(2.36, 0), Vector2(0, 0)], 16)
	_lathe("limestone", Vector3(0, 0.2, 0), [Vector2(0.55, 0), Vector2(0.4, 0.5), Vector2(0.3, 1.6), Vector2(1.0, 1.75), Vector2(1.05, 1.9), Vector2(0.9, 1.9), Vector2(0.3, 1.8), Vector2(0.3, 2.4), Vector2(0, 2.4)], 12)
	_lathe("water", Vector3(0, 2.05, 0), [Vector2(0.92, 0), Vector2(0, 0)], 12)
	_hand_symbol("hand_gold", Vector3(0, 3.2, 0), Vector3(0, 0, 1), Vector3.UP, 1.2, 0.18)
	_hand_symbol("hand_gold", Vector3(0, 3.2, -0.12), Vector3(0, 0, -1), Vector3.UP, 1.2, 0.06)
	for k in 6:
		var a := TAU * k / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		_rod("water", d * 0.95 + Vector3(0, 1.9, 0), d * 1.6 + Vector3(0, 0.62, 0), 0.05, 5, 0.09)
	_save("fountain")

	_begin("town_flag")   # DESIGN 7: the hand on the town flag
	_lathe("ashlar", Vector3.ZERO, [Vector2(0.6, 0), Vector2(0.6, 0.4), Vector2(0.4, 0.5), Vector2(0, 0.5)], 8)
	_lathe("iron", Vector3(0, 0.5, 0), [Vector2(0.09, 0), Vector2(0.05, 8.5), Vector2(0, 8.5)], 8)
	_ball("brass", Vector3(0, 9.0, 0), 0.14, 7, 4)
	_flag(Vector3(0.06, 8.8, 0), 2.4, 1.5)
	_save("town_flag")

	_begin("banner_pole")
	_lathe("iron", Vector3.ZERO, [Vector2(0.15, 0), Vector2(0.06, 0.2), Vector2(0.05, 3.6), Vector2(0, 3.6)], 8)
	_lathe("brass", Vector3(0, 3.6, 0), [Vector2(0.06, 0), Vector2(0.0, 0.3)], 6)
	_banner(Vector3(0, 3.3, 0.0), 0, "cloth_plum", 2.0, 0.8)
	_save("banner_pole")

	_begin("bench_iron")
	for sx in [-0.7, 0.7]:
		_beam("iron", Vector3(sx, 0, 0.2), Vector3(sx, 0.45, 0.15), 0.05)
		_beam("iron", Vector3(sx, 0, -0.2), Vector3(sx, 0.9, -0.28), 0.05)
		_beam("iron", Vector3(sx, 0.45, 0.22), Vector3(sx, 0.45, -0.24), 0.05)
	for k in 4:
		_box("wood", Vector3(0, 0.47, 0.17 - k * 0.12), Vector3(1.7, 0.04, 0.09))
	for k in 3:
		_box("wood", Vector3(0, 0.6 + k * 0.11, -0.27 - k * 0.01), Vector3(1.7, 0.08, 0.03), Vector3(-8, 0, 0))
	_save("bench_iron")

	_begin("planter")
	_box("ashlar", Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 1.2))
	_box("limestone", Vector3(0, 0.63, 0), Vector3(1.3, 0.08, 1.3))
	_box("soil", Vector3(0, 0.66, 0), Vector3(1.0, 0.02, 1.0))
	_rod("wood", Vector3(0, 0.6, 0), Vector3(0.05, 2.0, 0), 0.06, 6, 0.04)
	_ball("leaf", Vector3(0.05, 2.2, 0), 0.6, 8, 5, Vector3(1, 0.85, 1))
	_ball("crop_green", Vector3(0.25, 2.45, 0.15), 0.35, 7, 4)
	for k in 8:
		var a := TAU * k / 8.0
		_ball("leaf", Vector3(cos(a) * 0.4, 0.75, sin(a) * 0.4), 0.13, 5, 3)
		_ball(["cloth_red", "cloth_gold", "plaster_rose", "cloth_plum"][k % 4], Vector3(cos(a) * 0.42, 0.88, sin(a) * 0.42), 0.07, 5, 3)
	_save("planter")

	_begin("pump")
	_pump(Vector3.ZERO, 0)
	_save("pump")

	_begin("notice_board")   # wishes in words from Era 3 (DESIGN 7): the town's notices
	for sx in [-0.8, 0.8]:
		_beam("timber", Vector3(sx, 0, 0), Vector3(sx, 2.3, 0), 0.12)
	_box("planks", Vector3(0, 1.5, 0), Vector3(1.7, 1.1, 0.08))
	_slab("roof_tiles", [Vector3(-1.05, 2.3, 0.35), Vector3(1.05, 2.3, 0.35), Vector3(1.05, 2.55, -0.25), Vector3(-1.05, 2.55, -0.25)], 0.06,
		Vector3(0, 1, 0.4), [Vector3.RIGHT, Vector3.FORWARD, 1.6])
	for k in 6:
		var p := Vector3(-0.55 + (k % 3) * 0.55, 1.75 - (k / 3) * 0.5, 0.05)
		_box("paper", p, Vector3(0.36 + (k % 2) * 0.06, 0.4 - (k % 2) * 0.08, 0.01), Vector3(0, 0, _rng.randf_range(-6, 6)))
		_ball("paint_red", p + Vector3(0, 0.17, 0.01), 0.025, 4, 2)
	_save("notice_board")

	_begin("statue_hand")   # the open hand in stone on a plinth: squares and gardens
	_box("ashlar", Vector3(0, 0.35, 0), Vector3(1.8, 0.7, 1.8))
	_box("limestone", Vector3(0, 1.4, 0), Vector3(1.2, 1.4, 1.2))
	_box("limestone", Vector3(0, 2.15, 0), Vector3(1.45, 0.12, 1.45))
	_box("brass", Vector3(0, 1.4, 0.61), Vector3(0.7, 0.35, 0.02))
	_rod("limestone", Vector3(0, 2.2, 0), Vector3(0, 2.9, 0), 0.32, 8, 0.25)
	_hand_symbol("limestone", Vector3(0, 3.6, 0.0), Vector3(0, 0, 1), Vector3.UP, 1.6, 0.4)
	_save("statue_hand")


# ================================================================== carts and wagons

func _carts3() -> void:
	# Haulers carry 10 (DESIGN 4): a two-wheeled horse cart with shafts, empty and loaded.
	for v in 2:
		var nm := "cart" if v == 0 else "cart_loaded"
		_begin(nm)
		_box("planks", Vector3(0, 0.95, -0.3), Vector3(1.5, 0.08, 2.4))
		for sx in [-1.0, 1.0]:
			_box("paint_blue", Vector3(sx * 0.73, 1.2, -0.3), Vector3(0.06, 0.45, 2.4))
			_beam("timber", Vector3(sx * 0.55, 0.9, 0.8), Vector3(sx * 0.5, 0.95, 2.8), 0.08)
		_box("paint_blue", Vector3(0, 1.2, -1.48), Vector3(1.5, 0.45, 0.06))
		_box("paint_blue", Vector3(0, 1.2, 0.88), Vector3(1.5, 0.45, 0.06))
		_beam("wood_dark", Vector3(-0.95, 0.6, -0.4), Vector3(0.95, 0.6, -0.4), 0.09)
		for sx in [-1.0, 1.0]:
			_wheel(Vector3(sx * 0.9, 0.6, -0.4), 0.6)
		_beam("wood_dark", Vector3(0, 0, 2.2), Vector3(0, 0.9, 2.4), 0.06)   # prop leg
		if v == 1:
			for p in [Vector3(-0.35, 0.99, -0.9), Vector3(0.35, 0.99, -0.9), Vector3(0.0, 1.69, -0.9)]:
				_model(BOATS + "crate.glb", p, Vector3(0, _rng.randf_range(-10, 10), 0), 0.75, null, SHIP)
			_sack(Vector3(-0.35, 0.99, 0.3), "linen", 0.85, 70)
			_sack(Vector3(0.35, 0.99, 0.35), "rope", 0.85, -70)
			_model(K + "barrel.glb", Vector3(0, 0.99, -0.1), Vector3(90, 0, 0), 2.6, null, KEN)
		_save(nm)

	# caravans arrive to trade (DESIGN 4 market): a covered four-wheeled wagon, striped tilt
	_begin("caravan_wagon")
	_box("planks", Vector3(0, 1.05, 0), Vector3(1.8, 0.1, 4.0))
	for sx in [-1.0, 1.0]:
		_box("paint_red", Vector3(sx * 0.88, 1.35, 0), Vector3(0.08, 0.5, 4.0))
		_wheel(Vector3(sx * 1.02, 0.6, 1.3), 0.6)
		_wheel(Vector3(sx * 1.02, 0.7, -1.3), 0.7)
	_beam("wood_dark", Vector3(-1.1, 0.6, 1.3), Vector3(1.1, 0.6, 1.3), 0.09)
	_beam("wood_dark", Vector3(-1.1, 0.7, -1.3), Vector3(1.1, 0.7, -1.3), 0.09)
	_beam("timber", Vector3(0, 0.75, 2.0), Vector3(0, 0.7, 3.8), 0.1)
	_beam("timber", Vector3(-0.4, 0.72, 3.8), Vector3(0.4, 0.72, 3.8), 0.07)
	var hoops := 6
	for k in hoops:
		var z := -1.8 + 3.6 * k / (hoops - 1)
		for j in 8:
			var a0 := PI * j / 8.0
			var a1 := PI * (j + 1) / 8.0
			_beam("wood_dark", Vector3(cos(a0) * 0.92, 1.6 + sin(a0) * 1.1, z), Vector3(cos(a1) * 0.92, 1.6 + sin(a1) * 1.1, z), 0.05)
	for j in 8:   # the tilt: canvas panels, with a teal stripe
		var a0 := PI * j / 8.0
		var a1 := PI * (j + 1) / 8.0
		var m := "cloth_teal" if j == 3 or j == 4 else "linen"
		var A := Vector3(cos(a0) * 0.95, 1.6 + sin(a0) * 1.12, 1.9)
		var B := Vector3(cos(a1) * 0.95, 1.6 + sin(a1) * 1.12, 1.9)
		_quad(m, A, B, B - Vector3(0, 0, 3.8), A - Vector3(0, 0, 3.8), Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0))
		_box("linen", Vector3(0, 1.6, -1.95) + Vector3(cos((a0 + a1) * 0.5) * 0.47, sin((a0 + a1) * 0.5) * 0.56, 0), Vector3(0.6, 0.6, 0.02), Vector3(0, 0, rad_to_deg((a0 + a1) * 0.5)))
	_box("linen", Vector3(-0.7, 1.35, 1.9), Vector3(0.1, 0.5, 0.02))
	_box("linen", Vector3(0.7, 1.35, 1.9), Vector3(0.1, 0.5, 0.02))
	_model(BOATS + "crate-bottles.glb", Vector3(0.1, 1.1, 1.4), Vector3(0, 10, 0), 0.7, null, SHIP)
	_rod("cloth_plum", Vector3(-0.5, 1.25, 1.2), Vector3(-0.5, 1.25, 0.6), 0.13, 8)
	_lantern(Vector3(0.95, 2.4, 1.95), 0.8)
	_save("caravan_wagon")

	_begin("fire_cart")
	_fire_cart(Vector3.ZERO, 0)
	_save("fire_cart")


# ================================================================== resources and nodes

func _piles3() -> void:
	_begin("stone_blocks")
	_stone_pile(Vector3.ZERO, 1.0)
	_save("stone_blocks")
	_begin("bricks_pile")
	_model(V + "Prop_Brick2.gltf", Vector3(-0.3, 0, 0), Vector3(0, 10, 0), 1.0, null, MK)
	_model(V + "Prop_Brick3.gltf", Vector3(0.6, 0, 0.2), Vector3(0, -20, 0), 1.0, null, MK)
	_save("bricks_pile")
	_begin("iron_ore_pile")
	for i in 14:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * 0.6
		_ball("rust" if i % 3 == 0 else "stone_dark", Vector3(cos(a) * d, (1.0 - d / 0.6) * 0.3, sin(a) * d), _rng.randf_range(0.12, 0.2), 4, 2,
			Vector3(1, 0.8, 1), Vector3(_rng.randf() * 40, _rng.randf() * 90, 0))
	_save("iron_ore_pile")
	_begin("iron_bars")
	_iron_bars(Vector3.ZERO)
	_save("iron_bars")
	_begin("books_pile")
	_books(Vector3.ZERO)
	_save("books_pile")
	_begin("paper_stack")
	_box("planks", Vector3(0, 0.05, 0), Vector3(1.0, 0.1, 0.7))
	for i in 3:
		for k in 2:
			var p := Vector3(-0.24 + k * 0.48, 0.1 + i * 0.16, 0)
			_box("paper", p + Vector3(0, 0.075, 0), Vector3(0.42, 0.15, 0.6), Vector3(0, _rng.randf_range(-5, 5), 0))
			_box("rope", p + Vector3(0, 0.075, 0), Vector3(0.43, 0.155, 0.04))
	_save("paper_stack")
	_begin("crates")
	_model(BOATS + "crate.glb", Vector3(-0.45, 0, 0), Vector3(0, 8, 0), 0.9, null, SHIP)
	_model(BOATS + "crate.glb", Vector3(0.45, 0, 0.05), Vector3(0, -12, 0), 0.9, null, SHIP)
	_model(BOATS + "crate-bottles.glb", Vector3(0.0, 0.85, 0.0), Vector3(0, 30, 0), 0.9, null, SHIP)
	_save("crates")
	_begin("glassware")
	_box("planks", Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 1.7))
	_glassware(Vector3(0, 0.3, 0.0))
	_save("glassware")
	_begin("fire_buckets")
	_fire_buckets(Vector3.ZERO, 0)
	_save("fire_buckets")


func _nodes3() -> void:
	# Hill Quarry (DESIGN 10.1): a cut face with benches of dressed stone, ledges, a ramp
	# and a hoist; and an iron outcrop with rust bloom.
	_begin("quarry")
	var tint := {"hog_pull": 0.2, "hog_tint": Color("#d8cdb8")}
	_model(N + "Rock_6.fbx", Vector3(-3.0, 0, -2.2), Vector3(0, 20, 0), Vector3(3.2, 3.0, 2.4), null, tint)
	_model(N + "Rock_4.fbx", Vector3(3.2, 0, -2.4), Vector3(0, 70, 0), Vector3(3.0, 3.6, 2.2), null, tint)
	for k in 3:   # benches stepping down from the face
		var y := 2.6 - k * 0.9
		_box("ashlar_warm", Vector3(0, y * 0.5, -1.8 + k * 1.0), Vector3(5.0 - k * 0.6, y, 1.2))
		for i in 4 - k:
			_box("limestone", Vector3(-1.6 + i * 1.1 + k * 0.3, y + 0.05, -1.8 + k * 1.0), Vector3(1.0, 0.02, 0.02))   # saw lines
	_stone_pile(Vector3(1.8, 0, 2.0), 1.0)
	_box("ashlar_warm", Vector3(-1.2, 0.2, 2.2), Vector3(0.7, 0.4, 0.5), Vector3(0, 25, 0))
	_slab("planks", [Vector3(-2.8, 0.05, 2.6), Vector3(-2.0, 0.05, 2.6), Vector3(-2.0, 1.8, -0.2), Vector3(-2.8, 1.8, -0.2)], 0.08, Vector3(0, 1, 0.6))
	for sx in [-1.0, 1.0]:
		_beam("timber", Vector3(0.6 + sx * 0.7, 0, 0.9), Vector3(0.6, 4.0, 0.4), 0.14)
	_rod("rope", Vector3(0.6, 3.9, 0.4), Vector3(0.6, 1.6, 0.4), 0.02, 4)
	_box("ashlar_warm", Vector3(0.6, 1.35, 0.4), Vector3(0.6, 0.4, 0.45))
	_model(K + "tool-pickaxe.glb", Vector3(-0.6, 0.0, 2.6), Vector3(0, 40, 80), 3.5, null, KEN)
	_save("quarry")
	_begin("iron_ore")
	var itint := {"hog_pull": 0.15, "hog_tint": Color("#9a8478")}
	_model(N + "Rock_3.fbx", Vector3(0, 0.1, 0), Vector3(0, 40, 0), 1.6, null, itint)
	_model(N + "Rock_5.fbx", Vector3(0.9, 0.0, 0.4), Vector3(0, 130, 0), 0.9, null, itint)
	_model(N + "Rock_2.fbx", Vector3(-0.9, 0.0, 0.6), Vector3(0, 10, 0), 0.8, null, itint)
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		var r := 0.7 + (i % 3) * 0.12
		_ball("rust" if i % 3 != 0 else "iron_light", Vector3(cos(a) * r, 0.25 + (i % 4) * 0.22, sin(a) * r), 0.13, 4, 2,
			Vector3(1, 0.7, 1), Vector3(_rng.randf() * 50, _rng.randf() * 90, 0))
	_save("iron_ore")


# ================================================================== tools (iron)

func _tools3() -> void:
	_begin("tool_axe_iron")
	_rod("wood", Vector3.ZERO, Vector3(0, 0.85, 0), 0.019, 6, 0.017)
	_cyl("leather", Vector3(0, 0.04, 0), 0.023, 0.023, 0.14, 6)
	_plate("iron_light", [Vector2(0.02, 0.66), Vector2(0.1, 0.64), Vector2(0.21, 0.58), Vector2(0.24, 0.71),
		Vector2(0.21, 0.85), Vector2(0.1, 0.78), Vector2(0.02, 0.775)], 0.0, 0.026)
	_plate("iron", [Vector2(-0.03, 0.68), Vector2(-0.07, 0.69), Vector2(-0.07, 0.77), Vector2(-0.03, 0.78)], 0.0, 0.045)
	_save("tool_axe_iron")
	_begin("tool_pickaxe_iron")
	_rod("wood", Vector3.ZERO, Vector3(0, 0.88, 0), 0.02, 6, 0.018)
	var arc := [Vector3(-0.34, 0.74, 0), Vector3(-0.18, 0.83, 0), Vector3(0, 0.86, 0), Vector3(0.18, 0.83, 0), Vector3(0.34, 0.74, 0)]
	var wid := [0.01, 0.035, 0.05, 0.035, 0.01]
	for i in 4:
		_rod("iron_light", arc[i], arc[i + 1], float(wid[i]) * 0.75, 6, float(wid[i + 1]) * 0.75)
	_save("tool_pickaxe_iron")
	_begin("tool_mallet")   # the mason's mallet
	_rod("wood", Vector3.ZERO, Vector3(0, 0.36, 0), 0.018, 6, 0.016)
	_lathe("wood_dark", Vector3(0, 0.33, 0), [Vector2(0.07, 0), Vector2(0.09, 0.08), Vector2(0.085, 0.16), Vector2(0, 0.17)], 8)
	_save("tool_mallet")
	_begin("tool_chisel")
	_rod("iron_light", Vector3.ZERO, Vector3(0, 0.26, 0), 0.006, 4, 0.014)
	_cyl("iron", Vector3(0, 0.24, 0), 0.016, 0.016, 0.06, 6)
	_save("tool_chisel")
	_begin("tool_saw")
	_plate("iron_light", [Vector2(-0.04, 0.12), Vector2(0.04, 0.12), Vector2(0.03, 0.72), Vector2(-0.01, 0.72)], 0.0, 0.006)
	_box("wood", Vector3(0, 0.07, 0), Vector3(0.12, 0.14, 0.04))
	_save("tool_saw")
	_begin("tool_trowel")
	_rod("wood", Vector3.ZERO, Vector3(0, 0.13, 0), 0.02, 6, 0.016)
	_beam("iron", Vector3(0, 0.13, 0), Vector3(0, 0.17, 0.04), 0.012)
	_plate("iron_light", [Vector2(-0.06, 0.18), Vector2(0.06, 0.18), Vector2(0.0, 0.34)], 0.04, 0.006)
	_save("tool_trowel")
