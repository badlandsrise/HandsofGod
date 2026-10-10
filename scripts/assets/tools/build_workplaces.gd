extends "res://scripts/assets/tools/build_era2.gd"
## Builds the art for the workplaces and the people's footbridge (scenes/props/work/):
##   hunting_lodge (+ _plot, _frame)   Era 1: a hide-covered pole lodge, antlers over the
##                                     door, hides on stretching frames, meat on a smoke rack
##   woodcutter_camp (+ _plot, _frame) Era 1-2: a bark-roofed lean-to, a cordwood stack,
##                                     a chopping block with the axe in it, a log on trestles
##   footbridge (+ _plot, _frame)      Era 2: three 6 m spans of squared timber on two
##                                     log trestles, split-plank deck, pole handrails
##   bridge_timber                     the squared beam the hand carries to the footbridge
## Re-run after changing this file:
##   godot --headless --path . -s res://scripts/assets/tools/build_workplaces.gd [-- --only=lodge,camp,footbridge,timber]
##
## Same conventions and helpers as build_era2.gd (origin on the ground at the footprint
## centre, +Z the front, metres). Kit pieces: Kenney Survival Kit (axe, logs, wood, bucket),
## Quaternius nature (rocks, stumps, logs).
##
## The footbridge runs along X (the site turns it north-south). Its scene origin is the
## height the people's crossing deck is reckoned from (Era2World.add_crossing: `base`), so
## the plank tops sit on the walkable deck: y = 0.3 + 0.4 * (1 - (x / 9)^2) for |x| <= 9.
## SiteVisual lowers it onto that base and stretches it to the water's width.

const OUTW := "res://scenes/props/work/"
const SURV := {"hog_pull": 0.5, "hog_sat": 0.45, "hog_tint": Color("#e0c4a8")}   # Survival Kit wood

const FB_HALF := 9.0         # deck half length over the water (scene units)
const FB_HALF_W := 1.25      # deck half width (Era2World.CROSSING_HALF_W)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTW))
	var jobs := {"lodge": _lodge_all, "camp": _camp_all, "footbridge": _footbridge_all, "timber": _bridge_timber}
	for k in jobs:
		if _only.is_empty() or k in _only:
			(jobs[k] as Callable).call()
	print("build_workplaces: %d scenes" % _count)
	quit()


func _save(scene_name: String) -> void:
	_flush(_root, "Geometry")
	var ps := PackedScene.new()
	var err := ps.pack(_root)
	if err == OK:
		err = ResourceSaver.save(ps, OUTW + scene_name + ".scn", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		print("  %s -> %s" % [scene_name, error_string(err)])
	_count += 1
	_root.free()


func _rock(p: Vector3, s: float, rot_y := 0.0) -> void:
	_model(N + "Rock_2.fbx", p, Vector3(0, rot_y, 0), s)


# ================================================================== the hunting lodge

## Lodge body: a ridge-pole tent of hides, 3.4 m long (x) by 3.2 m wide, ridge 2.6 m.
const LODGE_L := 3.4
const LODGE_W := 3.2
const LODGE_H := 2.6


func _lodge_all() -> void:
	_begin("hunting_lodge")
	_lodge_poles(true)
	_lodge_hides()
	_lodge_antlers(Vector3(0, LODGE_H + 0.05, LODGE_L * 0.5 + 0.35))
	_hide_frame(Vector3(-2.55, 0, 0.9), 70.0, "hide")
	_hide_frame(Vector3(-2.35, 0, -0.9), 105.0, "deer_light")
	_smoke_rack(Vector3(2.5, 0, 0.2))
	_spears(Vector3(1.05, 0, LODGE_L * 0.5 + 0.25))
	_bone_pile(Vector3(-1.2, 0, LODGE_L * 0.5 + 0.9))
	_save("hunting_lodge")

	_begin("hunting_lodge_frame")
	_box("dirt", Vector3(0, 0.02, 0), Vector3(LODGE_W + 0.8, 0.04, LODGE_L + 1.0))
	_lodge_poles(false)
	_hide_roll(Vector3(2.3, 0, 0.6), 10.0)
	_hide_roll(Vector3(2.4, 0, -0.2), -15.0)
	_hide_roll(Vector3(2.35, 0.3, 0.2), 5.0)
	_hide_frame(Vector3(-2.5, 0, 0.6), 75.0, "hide")
	_save("hunting_lodge_frame")

	_begin("hunting_lodge_plot")
	_box("dirt", Vector3(0, 0.02, 0), Vector3(LODGE_W + 0.8, 0.04, LODGE_L + 1.0))
	var hw := LODGE_W * 0.5
	var hl := LODGE_L * 0.5
	for c in [Vector3(hw, 0, hl), Vector3(-hw, 0, hl), Vector3(hw, 0, -hl), Vector3(-hw, 0, -hl)]:
		_rod("wood", c, c + Vector3(0, 0.8, 0), 0.04, 5, 0.03)
	for i in 7:   # the first stones of the hearth ring, by the door
		var a := TAU * i / 7.0
		_rock(Vector3(cos(a) * 0.5, 0, sin(a) * 0.5 + 0.2), 0.22, i * 50.0)
	for i in 5:   # a bundle of lodge poles
		_rod("wood", Vector3(2.0 + (i % 3) * 0.14, 0.06 + (i / 3) * 0.12, -1.6), Vector3(2.2 + (i % 3) * 0.14, 0.06 + (i / 3) * 0.12, 1.6), 0.06, 5)
	_hide_roll(Vector3(-2.2, 0, 0.4), 20.0)
	_save("hunting_lodge_plot")


## Two A-frames of crossed poles at the ends, a ridge pole, side poles down to the ground.
func _lodge_poles(finished: bool) -> void:
	var hl := LODGE_L * 0.5
	var hw := LODGE_W * 0.5
	var top := LODGE_H
	for z in [-hl, hl]:
		# the crossed pair, their tips poking past the ridge
		_rod("wood", Vector3(-hw, 0, z), Vector3(0.35, top + 0.55, z), 0.06, 5, 0.035)
		_rod("wood", Vector3(hw, 0, z), Vector3(-0.35, top + 0.55, z), 0.06, 5, 0.035)
	_rod("wood_dark", Vector3(0, top, -hl - 0.35), Vector3(0, top, hl + 0.35), 0.07, 6)
	if not finished:
		for i in 4:   # side poles leaning on the ridge
			var z := -hl + LODGE_L * (i + 0.5) / 4.0
			_rod("wood", Vector3(-hw - 0.05, 0, z), Vector3(-0.05, top + 0.05, z), 0.045, 5, 0.03)
			_rod("wood", Vector3(hw + 0.05, 0, z), Vector3(0.05, top + 0.05, z), 0.045, 5, 0.03)
		_ladder(Vector3(1.4, 0, hl + 1.0), Vector3(0.4, top - 0.1, hl + 0.05), 0.45)
	for z in [-hl, hl]:
		_rod("rope", Vector3(0, top - 0.05, z), Vector3(0, top + 0.05, z), 0.1, 6)   # lashing


## The hide cover: patched panels over the two long slopes, a back wall, a door flap.
func _lodge_hides() -> void:
	var hl := LODGE_L * 0.5
	var hw := LODGE_W * 0.5
	var top := LODGE_H - 0.04
	var tones := ["hide", "deer_light", "leather", "hide", "deer_light", "deer"]
	var n := 5
	for side in [-1.0, 1.0]:
		for i in n:
			var z0 := -hl - 0.15 + (LODGE_L + 0.3) * i / n
			var z1 := -hl - 0.15 + (LODGE_L + 0.3) * (i + 1) / n + 0.05
			var sag := 0.06 if i % 2 == 0 else 0.0
			var m: String = tones[(i + (1 if side > 0 else 0)) % tones.size()]
			var a := Vector3(side * (hw + 0.12), 0.0, z0)
			var b := Vector3(side * (hw + 0.12), 0.0, z1)
			var c := Vector3(side * 0.02, top + 0.06, z1)
			var d := Vector3(side * 0.02, top + 0.06, z0)
			var mid := (a + b + c + d) * 0.25 - Vector3(side * sag, 0, 0)
			var out := Vector3(side * top, hw, 0)
			_tri(m, a, b, mid, out)
			_tri(m, b, c, mid, out)
			_tri(m, c, d, mid, out)
			_tri(m, d, a, mid, out)
			# stitching along each panel seam
			_beam("leather", a.lerp(d, 0.02) + Vector3(side * 0.03, 0, 0), d + Vector3(side * 0.02, 0.01, 0), 0.03)
	# weight poles over the hides, tied at the ridge, and a fur trim along the hem
	for side in [-1.0, 1.0]:
		for z in [-hl + 0.35, 0.0, hl - 0.35]:
			_rod("wood", Vector3(side * (hw + 0.3), 0.05, z), Vector3(side * 0.25, top + 0.25, z), 0.035, 5)
		_rod("deer_light", Vector3(side * (hw + 0.1), 0.18, -hl - 0.1), Vector3(side * (hw + 0.1), 0.18, hl + 0.1), 0.07, 5)
	# back gable closed with hide
	_tri("hide", Vector3(-hw, 0, -hl - 0.05), Vector3(hw, 0, -hl - 0.05), Vector3(0, top, -hl - 0.05), Vector3.BACK)
	_tri("hide", Vector3(-hw, 0, -hl - 0.05), Vector3(hw, 0, -hl - 0.05), Vector3(0, top, -hl - 0.05), Vector3.FORWARD)
	# front gable: hide either side of a dark doorway, one flap tied back
	var f := hl + 0.05
	_tri("leather", Vector3(-hw, 0, f), Vector3(-0.45, 0, f), Vector3(0, top, f), Vector3.BACK)
	_tri("leather", Vector3(hw, 0, f), Vector3(0.45, 0, f), Vector3(0, top, f), Vector3.BACK)
	_tri("cave_dark", Vector3(-0.45, 0, f - 0.02), Vector3(0.45, 0, f - 0.02), Vector3(0, top * 0.72, f - 0.02), Vector3.BACK)
	_tri("hide", Vector3(0.45, 0.05, f + 0.02), Vector3(0.95, 0.05, f + 0.32), Vector3(0.12, top * 0.66, f + 0.04), Vector3(0.3, 0, 1))
	_rod("rope", Vector3(0.8, 0.5, f + 0.25), Vector3(1.0, 0.55, f + 0.1), 0.02, 4)
	# stones holding the hem down
	for i in 12:
		var z := -hl + LODGE_L * (i % 6 + 0.5) / 6.0
		var side := -1.0 if i < 6 else 1.0
		_rock(Vector3(side * (hw + 0.22), 0, z), 0.26, i * 37.0)
	# a smoke hole: dark tuft at the ridge's front end
	_ball("charcoal", Vector3(0, top + 0.02, hl - 0.25), 0.16, 6, 3, Vector3(1, 0.4, 1.4))


## A stag's antlers on a skull, lashed over the door.
func _lodge_antlers(c: Vector3) -> void:
	_ball("bone", c, 0.13, 6, 3, Vector3(0.9, 0.8, 1.3))
	_ball("bone", c + Vector3(0, -0.08, 0.16), 0.08, 6, 3, Vector3(0.8, 0.7, 1.4))
	for s in [-1.0, 1.0]:
		var base := c + Vector3(s * 0.08, 0.08, -0.02)
		var p1 := base + Vector3(s * 0.25, 0.22, -0.05)
		var p2 := p1 + Vector3(s * 0.22, 0.28, 0.02)
		var p3 := p2 + Vector3(s * 0.05, 0.26, 0.0)
		_rod("antler", base, p1, 0.035, 5, 0.03)
		_rod("antler", p1, p2, 0.03, 5, 0.025)
		_rod("antler", p2, p3, 0.025, 5, 0.012)
		_rod("antler", p1, p1 + Vector3(s * -0.02, 0.2, 0.1), 0.022, 4, 0.01)   # brow tines
		_rod("antler", p2, p2 + Vector3(s * 0.2, 0.12, 0.02), 0.02, 4, 0.01)
		_rod("antler", base, base + Vector3(s * 0.05, 0.12, 0.17), 0.022, 4, 0.01)


## A hide laced into a square pole frame, leaning on a prop.
func _hide_frame(c: Vector3, rot_y: float, m: String) -> void:
	_push(_xf(c, rot_y))
	var w := 1.5
	var h := 1.5
	var lean := 0.35
	var bl := Vector3(-w * 0.5, 0, 0)
	var br := Vector3(w * 0.5, 0, 0)
	var tl := Vector3(-w * 0.5, h, -lean)
	var tr := Vector3(w * 0.5, h, -lean)
	for pair in [[bl + Vector3(-0.1, 0, 0), tl + Vector3(-0.1, 0.15, 0)], [br + Vector3(0.1, 0, 0), tr + Vector3(0.1, 0.15, 0)],
			[bl + Vector3(-0.25, 0.15, 0), br + Vector3(0.25, 0.15, 0)], [tl + Vector3(-0.25, -0.05, 0), tr + Vector3(0.25, -0.05, 0)]]:
		_rod("wood", pair[0], pair[1], 0.035, 5)
	_rod("wood", Vector3(0, 0, -lean - 0.7), Vector3(0, h * 0.85, -lean * 0.9), 0.03, 5)   # the prop
	# the hide: an irregular stretched skin, a little inside the frame
	var k := 0.18
	var pts := [bl.lerp(tl, 0.12) + Vector3(k, k, 0), br.lerp(tr, 0.15) + Vector3(-k, k * 0.8, 0),
		tr + Vector3(-k * 1.2, -k, 0), tl + Vector3(k * 0.9, -k * 1.2, 0)]
	var cen: Vector3 = (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25 + Vector3(0, 0, 0.02)
	var nrm := Vector3(0, lean, h)
	for i in 4:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 4]
		var e: Vector3 = (a + b) * 0.5 + (((a + b) * 0.5) - cen).normalized() * 0.1   # a leg or neck lobe
		_tri(m, a, b, cen, nrm)
		_tri(m, a, e, b, nrm)
		_tri(m, a, b, cen, -nrm)
		_tri(m, a, e, b, -nrm)
		# lacing to the frame
		_rod("rope", a, a + (a - cen).normalized() * 0.2, 0.012, 3)
	_pop()


## A smoke rack: two forked posts and a cross pole hung with strips of meat over a
## smouldering hearth.
func _smoke_rack(c: Vector3) -> void:
	_push(_xf(c, 90.0))
	var h := 1.55
	for x in [-0.85, 0.85]:
		_rod("wood", Vector3(x, 0, 0), Vector3(x, h, 0), 0.05, 5, 0.04)
		_rod("wood", Vector3(x, h - 0.15, 0), Vector3(x - 0.12 * signf(x), h + 0.12, 0), 0.03, 4)
		_rod("wood", Vector3(x, h - 0.15, 0), Vector3(x + 0.1 * signf(x), h + 0.1, 0.05), 0.03, 4)
	_rod("wood_dark", Vector3(-1.05, h - 0.06, 0), Vector3(1.05, h - 0.06, 0), 0.035, 5)
	_rod("wood_dark", Vector3(-1.0, h - 0.5, 0.25), Vector3(1.0, h - 0.5, 0.25), 0.03, 5)
	for i in 7:
		var x := -0.65 + 0.21 * i
		var l := _rng.randf_range(0.45, 0.7)
		var m: String = "red_ochre" if i % 3 != 1 else "leather"
		_box(m, Vector3(x, h - 0.08 - l * 0.5, 0), Vector3(0.13, l, 0.04), Vector3(0, _rng.randf_range(-20, 20), _rng.randf_range(-4, 4)))
	for i in 5:
		var x := -0.6 + 0.3 * i
		_box("red_ochre", Vector3(x, h - 0.75, 0.25), Vector3(0.11, 0.42, 0.035), Vector3(0, 10, 0))
	# the smoke hearth: a ring of stones, charred wood, a little ash
	for i in 8:
		var a := TAU * i / 8.0
		_rock(Vector3(cos(a) * 0.45, 0, sin(a) * 0.45 + 0.1), 0.2, i * 40.0)
	_cyl("charcoal", Vector3(0, 0, 0.1), 0.38, 0.3, 0.06, 8)
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		_rod("wood_dark", Vector3(cos(a) * 0.35, 0.06, sin(a) * 0.35 + 0.1), Vector3(cos(a) * 0.05, 0.16, sin(a) * 0.05 + 0.1), 0.04, 5)
	_ball("smoke", Vector3(0, 0.45, 0.1), 0.22, 6, 3, Vector3(1, 1.6, 1))
	_pop()


## Three flint-tipped spears leaning by the door.
func _spears(c: Vector3) -> void:
	for i in 3:
		var foot := c + Vector3(i * 0.16, 0, 0.05 * i)
		var top := c + Vector3(-0.25 + i * 0.12, 2.0 + i * 0.08, -0.45)
		_rod("wood", foot, top, 0.025, 4)
		var d := (top - foot).normalized()
		_rod("flint", top, top + d * 0.22, 0.04, 3, 0.0)
		_rod("leather", top - d * 0.05, top + d * 0.03, 0.035, 4)


func _bone_pile(c: Vector3) -> void:
	_ball("bone", c + Vector3(0, 0.1, 0), 0.12, 6, 3, Vector3(1, 0.8, 1.4), Vector3(0, 30, 0))
	for i in 5:
		var a := i * 1.3
		var p := c + Vector3(cos(a) * 0.3, 0.04, sin(a) * 0.25)
		_rod("bone", p, p + Vector3(cos(a + 1.4) * 0.4, 0.02, sin(a + 1.4) * 0.4), 0.025, 4)
	_rod("antler", c + Vector3(0.3, 0.04, -0.1), c + Vector3(0.6, 0.25, -0.2), 0.03, 4, 0.015)
	_rod("antler", c + Vector3(0.45, 0.12, -0.15), c + Vector3(0.55, 0.3, 0.0), 0.02, 4, 0.01)


func _hide_roll(c: Vector3, rot_y: float) -> void:
	_push(_xf(c, rot_y))
	_rod("hide", Vector3(-0.5, 0.16, 0), Vector3(0.5, 0.16, 0), 0.16, 7)
	_rod("rope", Vector3(-0.25, 0.16, 0), Vector3(-0.2, 0.16, 0), 0.17, 6)
	_rod("rope", Vector3(0.2, 0.16, 0), Vector3(0.25, 0.16, 0), 0.17, 6)
	_pop()


# ================================================================== the woodcutters' camp

## A bark-roofed lean-to (open to +Z) against a log back wall, 3.6 x 2.4 m.
const CAMP_W := 3.6
const CAMP_D := 2.4


func _camp_all() -> void:
	_begin("woodcutter_camp")
	_box("dirt", Vector3(0, 0.02, 0.3), Vector3(CAMP_W + 0.6, 0.04, CAMP_D + 1.4))
	_leanto(true)
	_cordwood(Vector3(2.55, 0, -0.3), 90.0, 2.2, 1.1)
	_chop_block(Vector3(0.9, 0, 1.75))
	_log_trestle(Vector3(-0.9, 0, 2.15), 10.0)
	_chips(Vector3(0.6, 0, 1.6), 1.2, 16)
	_model(K + "bucket.glb", Vector3(-1.4, 0.0, -0.3), Vector3.ZERO, 3.5, null, SURV)
	_save("woodcutter_camp")

	_begin("woodcutter_camp_frame")
	_box("dirt", Vector3(0, 0.02, 0.3), Vector3(CAMP_W + 0.6, 0.04, CAMP_D + 1.4))
	_leanto(false)
	_model(K + "tree-log.glb", Vector3(2.4, 0, 0.6), Vector3(0, 80, 0), 2.6, null, SURV)
	_model(K + "tree-log.glb", Vector3(2.5, 0.3, 0.2), Vector3(0, 95, 0), 2.6, null, SURV)
	_model(K + "tool-axe.glb", Vector3(0.4, 0, 1.7), Vector3(0, 30, 75), 3.5, null, KEN)
	_save("woodcutter_camp_frame")

	_begin("woodcutter_camp_plot")
	_box("dirt", Vector3(0, 0.02, 0.3), Vector3(CAMP_W + 0.6, 0.04, CAMP_D + 1.4))
	var hw := CAMP_W * 0.5
	var hd := CAMP_D * 0.5
	for c in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd)]:
		_rod("wood", c, c + Vector3(0, 0.75, 0), 0.04, 5, 0.03)
	for i in 4:
		_beam("rope", [Vector3(hw, 0.6, hd), Vector3(-hw, 0.6, hd), Vector3(-hw, 0.6, -hd), Vector3(hw, 0.6, -hd)][i],
			[Vector3(-hw, 0.6, hd), Vector3(-hw, 0.6, -hd), Vector3(hw, 0.6, -hd), Vector3(hw, 0.6, hd)][i], 0.02)
	_model(N + "TreeStump.fbx", Vector3(0.9, 0, 1.7), Vector3(0, 40, 0), 0.6)
	_model(K + "tree-log.glb", Vector3(2.4, 0, 0.2), Vector3(0, 80, 0), 2.6, null, SURV)
	_save("woodcutter_camp_plot")


func _leanto(finished: bool) -> void:
	var hw := CAMP_W * 0.5
	var hd := CAMP_D * 0.5
	var front_h := 2.1
	var back_h := 1.25
	for x in [-hw, 0.0, hw]:
		_rod("wood", Vector3(x, 0, hd), Vector3(x, front_h, hd), 0.08, 6, 0.07)
		_rod("wood", Vector3(x, 0, -hd), Vector3(x, back_h, -hd), 0.08, 6, 0.07)
		_rod("wood", Vector3(x, front_h + 0.06, hd + 0.35), Vector3(x, back_h + 0.06, -hd - 0.3), 0.06, 5)   # rafters
	_rod("wood_dark", Vector3(-hw - 0.3, front_h, hd), Vector3(hw + 0.3, front_h, hd), 0.08, 6)
	_rod("wood_dark", Vector3(-hw - 0.3, back_h, -hd), Vector3(hw + 0.3, back_h, -hd), 0.08, 6)
	# the back wall: logs laid between the posts, notched over each other
	var y := 0.12
	var i := 0
	while y < back_h - 0.1:
		_rod("wood" if i % 2 == 0 else "wood_dark", Vector3(-hw - 0.15, y, -hd - 0.12), Vector3(hw + 0.15, y, -hd - 0.12), 0.12, 7)
		y += 0.22
		i += 1
	# the side walls: half-height wattle of split poles
	for s in [-1.0, 1.0]:
		for k in 7:
			var z := -hd + CAMP_D * (k + 0.5) / 7.0
			var top := lerpf(back_h, front_h, (z + hd) / CAMP_D) * 0.55
			_rod("wood", Vector3(s * (hw + 0.05), 0, z), Vector3(s * (hw + 0.05), top, z), 0.04, 4)
	if finished:
		# bark slabs, overlapping courses running down the slope
		var n := 9
		for k in n:
			var x0 := -hw - 0.35 + (CAMP_W + 0.7) * k / n
			var x1 := -hw - 0.35 + (CAMP_W + 0.7) * (k + 1) / n + 0.06
			var lift := 0.04 if k % 2 == 0 else 0.08
			_slab("wood_dark" if k % 3 != 1 else "wood", [Vector3(x0, front_h + 0.12 + lift, hd + 0.45), Vector3(x1, front_h + 0.12 + lift, hd + 0.45),
				Vector3(x1, back_h + 0.12 + lift, -hd - 0.4), Vector3(x0, back_h + 0.12 + lift, -hd - 0.4)], 0.06, Vector3(0, 1, 0.4))
		for x in [-hw * 0.5, hw * 0.5]:   # weight poles on the roof
			_rod("wood", Vector3(x, front_h + 0.26, hd + 0.4), Vector3(x, back_h + 0.26, -hd - 0.35), 0.05, 5)
		# tools and the sleeping skins inside
		_model(K + "tool-axe.glb", Vector3(-0.8, 0.45, -hd + 0.05), Vector3(-80, 0, 0), 3.5, null, KEN)
		_model(K + "bedroll.glb", Vector3(0.4, 0, -0.3), Vector3(0, 90, 0), 3.4, null, SURV)
		_box("hide", Vector3(-0.6, 0.03, 0.1), Vector3(1.1, 0.05, 0.8), Vector3(0, 12, 0))
	else:
		_ladder(Vector3(hw * 0.4, 0, hd + 1.1), Vector3(hw * 0.4, front_h + 0.1, hd + 0.1), 0.45)


## Split cordwood stacked between end posts.
func _cordwood(c: Vector3, rot_y: float, l: float, h: float) -> void:
	_push(_xf(c, rot_y))
	for s in [-1.0, 1.0]:
		_rod("wood", Vector3(s * (l * 0.5 + 0.1), 0, -0.2), Vector3(s * (l * 0.5 + 0.1), h + 0.15, -0.2), 0.05, 5)
		_rod("wood", Vector3(s * (l * 0.5 + 0.1), 0, 0.25), Vector3(s * (l * 0.5 + 0.1), h + 0.15, 0.25), 0.05, 5)
	var r := 0.1
	var y := r
	var row := 0
	while y < h:
		var x := -l * 0.5 + r + (r * 0.5 if row % 2 == 1 else 0.0)
		while x < l * 0.5 - r * 0.5:
			var j := _rng.randf_range(-0.05, 0.05)
			_cyl("wood" if _rng.randf() < 0.7 else "wood_dark", Vector3(x, y, -0.25 + j), r, r * 0.95, 0.5, 5, Vector3(90, 0, 0))
			_cyl("bone", Vector3(x, y, 0.25 + j + 0.005), r * 0.8, r * 0.8, 0.005, 5, Vector3(90, 0, 0))   # cut faces
			x += r * 2.0
		y += r * 1.75
		row += 1
	_pop()


## A chopping block (a stump) with the axe sunk in it, split billets round it.
func _chop_block(c: Vector3) -> void:
	_cyl("wood_dark", c, 0.34, 0.3, 0.55, 8)
	_cyl("bone", c + Vector3(0, 0.55, 0), 0.3, 0.29, 0.01, 8)
	_model(K + "tool-axe.glb", c + Vector3(0.05, 0.55, 0.0), Vector3(0, 20, -28), 3.6, null, KEN)
	for i in 4:
		var a := 0.6 + i * 1.2
		var p := c + Vector3(cos(a) * 0.65, 0.07, sin(a) * 0.55)
		_box("wood", p, Vector3(0.12, 0.12, 0.45), Vector3(0, rad_to_deg(a) + 30.0, 85))


## A trunk on two cross-legged trestles, part sawn into lengths.
func _log_trestle(c: Vector3, rot_y: float) -> void:
	_push(_xf(c, rot_y))
	for x in [-0.8, 0.8]:
		_rod("wood", Vector3(x, 0, -0.35), Vector3(x, 0.75, 0.25), 0.04, 4)
		_rod("wood", Vector3(x, 0, 0.35), Vector3(x, 0.75, -0.25), 0.04, 4)
	_model(K + "tree-log.glb", Vector3(0, 0.62, 0), Vector3(0, 90, 0), Vector3(3.0, 2.6, 2.6), null, SURV)
	_pop()


func _chips(c: Vector3, r: float, n: int) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		_box("wood" if i % 3 else "bone", c + Vector3(cos(a) * d, 0.02, sin(a) * d), Vector3(0.12, 0.02, 0.06), Vector3(0, _rng.randf() * 360.0, 0))


# ================================================================== the footbridge

func _fb_y(x: float) -> float:
	return 0.3 + 0.4 * (1.0 - pow(clampf(x / FB_HALF, -1.0, 1.0), 2.0))


func _footbridge_all() -> void:
	_begin("footbridge")
	_fb_ends(true)
	_fb_trestles(true)
	_fb_stringers(3)
	_fb_deck(1.0)
	_fb_rails()
	_save("footbridge")

	_begin("footbridge_frame")
	_fb_ends(true)
	_fb_trestles(false)
	_fb_stringers(3)
	_fb_deck(0.22)
	_model(K + "resource-planks.glb", Vector3(FB_HALF + 0.8, 0.3, 0.6), Vector3(0, 90, 0), 4.0, null, KEN)
	_save("footbridge_frame")

	_begin("footbridge_plot")
	_fb_ends(false)
	for sx in [-1.0, 1.0]:   # pegs and string across, bank to bank
		for sz in [-1.0, 1.0]:
			_rod("wood", Vector3(sx * FB_HALF, -0.1, sz * FB_HALF_W), Vector3(sx * FB_HALF, 0.75, sz * FB_HALF_W), 0.04, 5, 0.03)
		_beam("rope", Vector3(sx * FB_HALF, 0.6, -FB_HALF_W), Vector3(sx * FB_HALF, 0.6, FB_HALF_W), 0.02)
	for sz in [-1.0, 1.0]:
		_beam("rope", Vector3(-FB_HALF, 0.62, sz * FB_HALF_W), Vector3(FB_HALF, 0.62, sz * FB_HALF_W), 0.015)
	# the first trestle posts waiting on the near bank (+X, the village side)
	for i in 4:
		_rod("wood", Vector3(FB_HALF + 0.6, 0.1 + (i / 2) * 0.2, -1.2 + (i % 2) * 0.22 + (i / 2) * 0.1),
			Vector3(FB_HALF + 0.6, 0.1 + (i / 2) * 0.2, 1.4 + (i % 2) * 0.22 + (i / 2) * 0.1), 0.1, 6)
	_save("footbridge_plot")


## The bank seats: a log sill on a bed of stones at each end, under the deck.
func _fb_ends(finished: bool) -> void:
	for sx in [-1.0, 1.0]:
		var x: float = sx * (FB_HALF - 0.3)
		for k in 5:
			_stone(Vector3(x + sx * _rng.randf_range(-0.5, 0.3), -0.75, -1.4 + 0.7 * k), 0.5)
		if finished:
			_rod("wood_dark", Vector3(x, -0.3, -FB_HALF_W - 0.35), Vector3(x, -0.3, FB_HALF_W + 0.35), 0.2, 7)
			_rod("wood_dark", Vector3(x - sx * 0.45, -0.55, -FB_HALF_W - 0.25), Vector3(x - sx * 0.45, -0.55, FB_HALF_W + 0.25), 0.18, 7)


## Two trestle bents in the river at x = +-3, legs driven into the bed (~2.4 m down).
func _fb_trestles(finished: bool) -> void:
	var foot := -2.45
	for bx in [-3.0, 3.0]:
		var cap := _fb_y(bx) - 0.47
		for z in [-1.05, -0.35, 0.35, 1.05]:
			var splay := 0.18 * signf(z) if absf(z) > 0.5 else 0.0
			_rod("wood", Vector3(bx, foot, z + splay), Vector3(bx, cap, z), 0.11, 6, 0.1)
		_beam("timber", Vector3(bx, cap + 0.06, -1.45), Vector3(bx, cap + 0.06, 1.45), 0.26, 0.22)   # cap beam
		if finished:
			_beam("wood_dark", Vector3(bx + 0.13, foot + 0.6, -1.1), Vector3(bx + 0.13, cap - 0.15, 1.05), 0.08)
			_beam("wood_dark", Vector3(bx - 0.13, foot + 0.6, 1.1), Vector3(bx - 0.13, cap - 0.15, -1.05), 0.08)
			_beam("wood_dark", Vector3(bx + 0.13, -0.35, -1.25), Vector3(bx + 0.13, -0.35, 1.25), 0.08)   # walings at the waterline
			_beam("wood_dark", Vector3(bx - 0.13, -0.35, -1.25), Vector3(bx - 0.13, -0.35, 1.25), 0.08)
			for z in [-1.05, 1.05]:
				_rod("rope", Vector3(bx, cap - 0.1, z), Vector3(bx, cap + 0.02, z), 0.13, 6)
		else:
			# a temporary raking shore while the crew sets the stringers
			_rod("wood", Vector3(bx + 1.6, foot, 0.0), Vector3(bx, cap - 0.3, 0.0), 0.06, 5)
		# a few stones heaped round the feet against the current
		for k in 4:
			_stone(Vector3(bx + _rng.randf_range(-0.4, 0.4), foot + 0.05, -1.2 + 0.8 * k), 0.55)


## Squared timber stringers under each deck edge: three 6 m lengths end to end
## (bank to trestle, trestle to trestle, trestle to bank), following the deck's camber.
func _fb_stringers(spans: int) -> void:
	var xs := [-FB_HALF, -3.0, 3.0, FB_HALF]
	for z in [-0.8, 0.8]:
		for i in mini(spans, 3):
			var x0: float = xs[i] + (-0.25 if i == 0 else 0.15)
			var x1: float = xs[i + 1] + (0.25 if i == 2 else -0.15)
			var steps := 4
			for k in steps:
				var a := lerpf(x0, x1, float(k) / steps)
				var b := lerpf(x0, x1, float(k + 1) / steps)
				_beam("timber", Vector3(a, _fb_y(a) - 0.29, z), Vector3(b, _fb_y(b) - 0.29, z), 0.3, 0.36)


## Split-plank deck laid across the stringers, from the near (+X) bank; `frac` of it laid.
func _fb_deck(frac: float) -> void:
	var w := 0.34
	var n := int(FB_HALF * 2.0 / w)
	var laid := int(ceil(n * frac))
	for i in laid:
		var x := FB_HALF - w * (i + 0.5)
		var y := _fb_y(x) - 0.055
		var jl := _rng.randf_range(-0.12, 0.12)
		var m: String = "wood" if i % 4 != 2 else "wood_dark"
		var slope := rad_to_deg(atan(-0.8 * x / (FB_HALF * FB_HALF)))
		_box(m, Vector3(x, y, jl * 0.5), Vector3(w - 0.03, 0.1, FB_HALF_W * 2.0 + jl), Vector3(0, _rng.randf_range(-1.5, 1.5), slope))
	# the deck runs a little onto each bank
	if frac >= 1.0:
		for sx in [-1.0, 1.0]:
			for k in 3:
				var x: float = sx * (FB_HALF + 0.17 + 0.33 * k)
				_box("wood_dark", Vector3(x, 0.24 - 0.04 * k, 0), Vector3(0.3, 0.1, FB_HALF_W * 2.0 - 0.1), Vector3(0, _rng.randf_range(-2, 2), 0))


## Pole handrails both sides: a post at each trestle and bank end, a rail lashed on top.
func _fb_rails() -> void:
	var px := [-FB_HALF + 0.2, -6.0, -3.0, 0.0, 3.0, 6.0, FB_HALF - 0.2]
	for z in [-FB_HALF_W + 0.05, FB_HALF_W - 0.05]:
		for x in px:
			var y := _fb_y(x)
			_rod("wood", Vector3(x, y - 0.35, z), Vector3(x, y + 1.05, z), 0.06, 5, 0.05)
			_rod("rope", Vector3(x, y + 0.92, z), Vector3(x, y + 1.0, z), 0.075, 5)
		for i in px.size() - 1:
			var a: float = px[i]
			var b: float = px[i + 1]
			_rod("wood", Vector3(a, _fb_y(a) + 0.97, z), Vector3(b, _fb_y(b) + 0.97, z), 0.045, 5)
			_rod("wood_dark", Vector3(a, _fb_y(a) + 0.5, z), Vector3(b, _fb_y(b) + 0.5, z), 0.03, 4)
		# raking braces from the end posts down into the banks
		for sx in [-1.0, 1.0]:
			var x: float = sx * (FB_HALF - 0.2)
			_rod("wood", Vector3(x, _fb_y(x) + 0.7, z), Vector3(x + sx * 1.0, -0.1, z * 1.15), 0.045, 5)


# ================================================================== the bridge timber

## A squared beam, 6 m along X, adzed faces, the bark left on its edges, rope slings at
## each end (how the hand lifts it). Lies on the ground, centred.
func _bridge_timber() -> void:
	_begin("bridge_timber")
	var l := 6.0
	var s := 0.46
	var segs := 6
	for i in segs:
		var x0 := -l * 0.5 + l * i / segs
		var x1 := -l * 0.5 + l * (i + 1) / segs
		var wob := _rng.randf_range(-0.015, 0.015)
		_box("wood" if i % 2 == 0 else "timber", Vector3((x0 + x1) * 0.5, s * 0.5 + wob, 0), Vector3(x1 - x0 + 0.002, s, s - 0.02 + wob))
	# bark along the four arrises
	for y in [0.02, s - 0.02]:
		for z in [-s * 0.5 + 0.02, s * 0.5 - 0.02]:
			_rod("wood_dark", Vector3(-l * 0.5 + 0.1, y, z), Vector3(l * 0.5 - 0.1, y, z), 0.05, 5)
	# fresh-cut ends
	for sx in [-1.0, 1.0]:
		_box("bone", Vector3(sx * (l * 0.5 + 0.004), s * 0.5, 0), Vector3(0.01, s - 0.04, s - 0.04))
		# rope sling round each end
		var x: float = sx * (l * 0.5 - 0.6)
		_box("rope", Vector3(x, s * 0.5, 0), Vector3(0.07, s + 0.04, s + 0.04))
		_box("rope", Vector3(x + 0.1, s * 0.5, 0), Vector3(0.05, s + 0.03, s + 0.03))
	# adze marks: shallow darker scallops on the top face
	for i in 10:
		var x := -l * 0.5 + 0.4 + i * 0.52
		_box("wood_dark", Vector3(x, s + 0.002, _rng.randf_range(-0.1, 0.1)), Vector3(0.18, 0.004, 0.08), Vector3(0, _rng.randf_range(-30, 30), 0))
	_save("bridge_timber")
