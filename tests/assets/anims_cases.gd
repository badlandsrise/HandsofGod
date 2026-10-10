extends RefCounted
## Cases for tests/assets/test_anims.gd (loaded at runtime, after the autoloads exist).

const ANIMS := preload("res://assets/models/characters/anims/villager_anims.res")
const VILLAGER_SCENE := "res://scenes/people/villager_visual.tscn"
const LOCOMOTION := [&"walk", &"run", &"flee", &"carry_walk", &"push", &"carry_log", &"spear_walk"]

var tree: SceneTree
var root: Window
var fails := 0
var passes := 0
var _animals: Array = []


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("PASS ", what)
	else:
		fails += 1
		printerr("FAIL ", what)


func run(t: SceneTree) -> void:
	tree = t
	root = t.root
	test_library()
	test_jobs()
	test_props()
	test_cargo_and_gifts()
	test_villager()
	test_speed_scaling()
	test_person_visual()
	test_animals()
	test_log_carry()
	test_scoop()


## After a few real frames: the animals have run their gait modifier.
func late() -> void:
	for a in _animals:
		var sk := a.get(&"_skeleton") as Skeleton3D
		check(sk != null and sk.is_inside_tree(), "%s skeleton alive after frames" % a.species)
	var w := AssetCatalog.instance(&"wolf")
	root.add_child(w)
	var found := w.has_method(&"play") or w.find_children("*", "", true, false).any(func(n): return n.has_method(&"play"))
	check(found, "catalog wolf carries a playable WildAnimalVisual")
	w.queue_free()


func finish() -> int:
	print("RESULT %d passed, %d failed" % [passes, fails])
	return fails


# ------------------------------------------------------------------ the clips

func test_library() -> void:
	var need := {}
	for c in TaskAnims.TASK_CLIPS:
		need[c] = "TASK_CLIPS"
	for c in TaskAnims.CLIP_PROPS:
		need[c] = "CLIP_PROPS"
	for k in TaskAnims.BY_KIND:
		need[TaskAnims.BY_KIND[k]] = "BY_KIND"
	for k in TaskAnims.BY_SKILL:
		need[TaskAnims.BY_SKILL[k]] = "BY_SKILL"
	for id in TaskAnims.JOBS:
		var e: Dictionary = TaskAnims.JOBS[id]
		for c in e.get("work", []):
			need[c] = "JOBS.%s" % id
		for key in ["move", "carry", "carry_idle"]:
			if e.has(key):
				need[e[key]] = "JOBS.%s.%s" % [id, key]
	for c in PersonVisual.IDLE_VARIANTS:
		need[c] = "IDLE_VARIANTS"
	for p in PersonVisual.STATE_FOR_POSE:
		need[PersonVisual.STATE_FOR_POSE[p]] = "STATE_FOR_POSE"
	var missing: Array = []
	for c in need:
		if not ANIMS.has_animation(c):
			missing.append("%s (%s)" % [c, need[c]])
	check(missing.is_empty(), "every clip a task or pose names is baked %s" % [missing])
	for c in LOCOMOTION:
		var a := ANIMS.get_animation(c) if ANIMS.has_animation(c) else null
		check(a != null and a.has_meta(&"ground_speed") and float(a.get_meta(&"ground_speed")) > 0.1,
			"%s carries its ground speed" % c)
	var looped := true
	for c in TaskAnims.TASK_CLIPS:
		if ANIMS.has_animation(c) and ANIMS.get_animation(c).loop_mode == Animation.LOOP_NONE:
			looped = false
	check(looped, "task clips loop")


func test_jobs() -> void:
	var bad: Array = []
	var badprops: Array = []
	for id in Defs.jobs:
		var jd: JobDef = Defs.jobs[id]
		var plan := TaskAnims.for_job(jd)
		var clips: Array = plan.get("work", []).duplicate()
		for key in ["move", "carry", "carry_idle"]:
			if plan.get(key, &"") != &"":
				clips.append(plan[key])
		if clips.is_empty():
			bad.append(id)
		for c in clips:
			if not ANIMS.has_animation(c):
				bad.append("%s:%s" % [id, c])
			for p in TaskAnims.props(plan, c):
				if p != &"" and not PropKit.has(p):
					badprops.append("%s:%s" % [id, p])
	check(bad.is_empty(), "every job has baked work clips %s" % [bad])
	check(badprops.is_empty(), "every job's props exist %s" % [badprops])
	var named := JobDef.new()
	named.id = &"no_such_job"
	named.anim = &"dance"
	check(TaskAnims.for_job(named)["work"] == [&"dance"], "JobDef.anim names the clip")
	named.anim = &""
	named.kind = JobDef.Kind.DEVOTION
	check(TaskAnims.for_job(named)["work"] == [&"pray"], "a job with no entry falls back by kind")
	check(TaskAnims.work_clip(TaskAnims.for_job(Defs.job(&"gather_berries")), 3) == &"pick", "berries are picked")
	check(TaskAnims.work_clip(TaskAnims.for_job(Defs.job(&"knap_flint")), 3) == &"knap", "flint is knapped")
	check(TaskAnims.work_clip(TaskAnims.for_job(Defs.job(&"tend_fire")), 3) == &"tend", "the fire is tended")
	check(TaskAnims.props(TaskAnims.for_job(Defs.job(&"fell_tree")), &"chop")[0] == &"stone_axe", "era 1 fells with a stone axe")
	check(TaskAnims.props(TaskAnims.for_job(Defs.job(&"hunt")), &"spear_walk")[0] == &"spear", "hunters walk with spears")


# ------------------------------------------------------------------ props

func test_props() -> void:
	var bad: Array = []
	for id in PropKit.all_ids():
		var n := PropKit.make(id)
		if n == null:
			bad.append("%s: null" % id)
			continue
		var b := _aabb(n, Transform3D.IDENTITY)
		var big := maxf(b.size.x, maxf(b.size.y, b.size.z))
		if big < 0.03 or big > 3.0:
			bad.append("%s: %.2f m" % [id, big])
		n.free()
	check(bad.is_empty(), "every prop builds at a sane size %s" % [bad])
	check(PropKit.mount(&"axe") == &"grip" and PropKit.mount(&"basket") == &"palm" and PropKit.mount(&"cargo_sticks") == &"cargo",
		"props know how they are held")


func test_cargo_and_gifts() -> void:
	var kinds := {}
	for id in Defs.jobs:
		var jd: JobDef = Defs.jobs[id]
		for k in jd.inputs:
			kinds[StringName(k)] = true
		for k in jd.outputs:
			kinds[StringName(k)] = true
	for id in Defs.buildings:
		for k in (Defs.buildings[id] as BuildingDef).cost:
			kinds[StringName(k)] = true
	var missing: Array = []
	for k in kinds:
		if not PropKit.CARGO.has(k):
			missing.append(k)
	check(missing.is_empty(), "every resource kind has its own carried prop %s" % [missing])
	var gifts: Array = []
	var Gift := load("res://scripts/ai/gift.gd")
	for era in Gift.KINDS:
		for kind in Gift.KINDS[era]:
			if not PropKit.GIFT_FOR_KIND.has(kind):
				gifts.append(kind)
	check(gifts.is_empty(), "every gift kind is a real object %s" % [gifts])
	for kind in ["carved hand", "flowers", "handprint stone", "bead necklace"]:
		var g := PropKit.gift_visual(kind)
		var lights := g.find_children("*", "OmniLight3D", true, false)
		check(g.get(&"object") != null and lights.size() == 1, "gift '%s' is an object with a glow" % kind)
		g.free()


# ------------------------------------------------------------------ the villager

func _villager() -> VillagerVisual:
	var v := (load(VILLAGER_SCENE) as PackedScene).instantiate() as VillagerVisual
	root.add_child(v)
	return v


func _hand_prop(v: VillagerVisual, att: String) -> StringName:
	var sk := v.get(&"_skeleton") as Skeleton3D
	var a := sk.get_node_or_null(att) if sk else null
	if a == null or a.get_child_count() == 0:
		return &""
	return a.get_child(0).get_meta(&"prop_id", &"")


func test_villager() -> void:
	var v := _villager()
	v.play_task(&"chop")
	check(v.current_state() == &"chop" and _hand_prop(v, "HandR") == &"axe", "chopping holds an axe in the right hand")
	v.play_task(&"pick")
	check(_hand_prop(v, "HandL") == &"basket" and _hand_prop(v, "HandR") == &"", "picking holds a basket, the axe put away")
	v.play_task(&"knap")
	check(_hand_prop(v, "HandR") == &"hammerstone" and _hand_prop(v, "HandL") == &"flint_core", "knapping: hammerstone on a flint core")
	v.play_task(&"chop", &"stone_axe", &"")
	check(_hand_prop(v, "HandR") == &"stone_axe", "a job's own tool replaces the clip's")
	v.play(&"sit")
	check(v.has_seat(), "a sitting villager sits on something")
	v.set_seat_provided(true)
	check(not v.has_seat(), "... and on the world's own seat when there is one")
	v.set_seat_provided(false)
	v.play(&"idle")
	check(not v.has_seat(), "the seat goes when they stand")
	v.hold_cargo(&"berries")
	v.play(&"carry_walk")
	var cargo := v.get_node_or_null("Cargo") as Node3D
	check(cargo != null and cargo.visible and cargo.get_meta(&"prop_id", &"") == &"cargo_berries", "carrying berries shows a basket of berries")
	v.play(&"idle")
	check(cargo != null and not cargo.visible, "the armful hides when not carrying")
	v.hold_cargo(&"wood")
	cargo = v.get_node_or_null("Cargo") as Node3D
	check(v.cargo_kind() == &"wood" and cargo != null and cargo.get_meta(&"prop_id", &"") == &"cargo_sticks", "wood is a bundle of sticks")
	v.hold_cargo(&"")
	var sh := v.shoulder_point(&"r")
	check(sh.y > 1.2 and sh.y < 1.7, "the right shoulder is at shoulder height (%.2f)" % sh.y)
	v.queue_free()


func test_speed_scaling() -> void:
	var v := _villager()
	v.play(&"walk", 0.0)
	var size: float = (v.get(&"_model") as Node3D).global_basis.x.length()
	var gs: float = ANIMS.get_animation(&"walk").get_meta(&"ground_speed")
	for i in 30:
		v.global_position += Vector3(0, 0, 1.2 * 0.05)
		v._process(0.05)
	var want := 1.2 / (gs * size)
	check(absf(v.play_rate() - want) < 0.08, "walking at 1.2 m/s plays the walk at %.2f (want %.2f)" % [v.play_rate(), want])
	for i in 30:
		v.global_position += Vector3(0, 0, 0.3 * 0.05)
		v._process(0.05)
	check(v.play_rate() < 0.5 and v.play_rate() >= VillagerVisual.RATE_MIN - 0.001, "a slow shuffle slows the stride (%.2f)" % v.play_rate())
	for i in 30:
		v._process(0.05)
	check(is_equal_approx(v.play_rate(), 1.0), "standing in a walk: natural pace")
	v.play(&"pray")
	check(is_equal_approx(v.play_rate(), 1.0), "non-locomotion clips play as authored")
	v.queue_free()


func test_person_visual() -> void:
	var pv := PersonVisual.new()
	root.add_child(pv)
	pv.set_task(Defs.job(&"gather_berries"))
	pv.animate(0.1, PersonVisual.Pose.WORK, false, Vector3.INF)
	check(pv.current_state() == &"pick" and pv.villager.held_props()[1] == &"basket", "berry gatherers pick into a basket")
	pv.set_task(Defs.job(&"fell_tree"))
	pv.animate(0.1, PersonVisual.Pose.CHOP, false, Vector3.INF)
	check(pv.current_state() == &"chop" and pv.villager.held_props()[0] == &"stone_axe", "fellers chop with a stone axe")
	pv.set_task(Defs.job(&"hunt"))
	pv.animate(0.1, PersonVisual.Pose.WALK, true, Vector3.INF)
	check(pv.current_state() == &"spear_walk" and pv.villager.held_props()[0] == &"spear", "hunters walk spear in hand")
	pv.set_task(Defs.job(&"carry_log"))
	pv.animate(0.1, PersonVisual.Pose.CARRY, true, Vector3.INF)
	check(pv.current_state() == &"carry_log", "log carriers walk with the log on the shoulder")
	pv.set_task(null)
	pv.set_cargo(&"stone")
	pv.animate(0.5, PersonVisual.Pose.CARRY, false, Vector3.INF)
	check(pv.current_state() == &"carry" and pv.villager.cargo_kind() == &"stone", "carrying stone holds stones")
	pv.set_cargo(null)
	pv.animate(0.1, PersonVisual.Pose.PRAY, false, Vector3.INF)
	check(pv.current_state() == &"pray", "praying kneels in prayer")
	pv.animate(0.1, PersonVisual.Pose.SIT, false, Vector3.INF)
	check(pv.current_state() == &"sit" and pv.villager.has_seat(), "sitting adults sit on a seat")
	pv.apply_look(0, 0, 1.0, false, 0)
	pv.animate(0.1, PersonVisual.Pose.SIT, false, Vector3.INF)
	check(pv.current_state() == &"baby_sit", "babies sit on the ground")
	pv.queue_free()


# ------------------------------------------------------------------ animals

func test_animals() -> void:
	for sp in [&"wolf", &"deer", &"bear"]:
		var a := (load("res://scenes/props/%s.tscn" % sp) as PackedScene).instantiate()
		root.add_child(a)
		_animals.append(a)
		var gait = a.get(&"gait")
		check(gait != null and gait.legs.size() == 4, "%s is rigged with four legs" % sp)
		var cfg: Dictionary = WildAnimalVisual.SPECIES[sp]
		var box: AABB = a._mesh_box()
		check(absf(box.size.y - float(cfg["height"])) < 0.15 * float(cfg["height"]) and absf(box.position.y) < 0.05,
			"%s stands %.2f m tall on the ground" % [sp, box.size.y])
		check(a.find_children("*", "AnimationPlayer", true, false).all(func(n): return n.is_queued_for_deletion()),
			"%s's imported clips are not played" % sp)
		# its own speed picks the gait
		a.play(&"auto")
		for i in 30:
			a.position += Vector3(0, 0, 1.0 * 0.05)
			a._process(0.05)
		check(a.current_gait() == &"walk", "%s walks at 1 m/s" % sp)
		for i in 30:
			a.position += Vector3(0, 0, 6.0 * 0.05)
			a._process(0.05)
		check(a.current_gait() == &"run", "%s runs at 6 m/s" % sp)
		for i in 40:
			a._process(0.05)
		check(a.current_gait() == &"idle", "%s stands when it stops" % sp)
		a.play(&"flee")
		a._process(0.05)
		check(gait.flee, "%s can flee" % sp)
		a.play(&"attack")
		a._process(0.05)
		check(gait.attack > 0.0, "%s can lunge" % sp)
		a.play(&"auto")
		for st in [&"idle", &"walk", &"run", &"attack", &"flee", &"graze", &"held", &"dead"]:
			a.freeze(st, 0.3)
		a.set_process(true)


# ------------------------------------------------------------------ log carry and scoop

func test_log_carry() -> void:
	var s := Node3D.new()
	root.add_child(s)
	s.global_position = Vector3(4, 0, 2)
	var h := LogCarry.heading(s)
	check(is_equal_approx(h.length(), 1.0) and absf(h.y) < 0.001, "the log has a flat heading")
	var a := LogCarry.slot(s, 0)
	var b := LogCarry.slot(s, 1)
	check(absf((a - b).dot(h)) > 1.6 and absf((a - b).dot(h)) < LogCarry.LENGTH, "the two carriers stand at the log's ends")
	var right := h.cross(Vector3.UP)
	check((a - s.global_position).dot(right) < 0.0 and (b - s.global_position).dot(right) < 0.0,
		"both stand left of the log so it rides their right shoulders")
	var lc := LogCarry.make(s, 7)
	s.add_child(lc)
	var box := LogCarry._aabb(lc, Transform3D.IDENTITY)
	check(box.size.x > 2.0 or box.size.z > 2.0, "the log is long enough for two")
	s.queue_free()


func test_scoop() -> void:
	var sweep := Vector3(1, 0, 0)
	var away := Vector3(0, 0, -1)
	var b := HandScoop.basis(sweep, away)
	check(absf(b.determinant() - 1.0) < 0.01, "the scoop basis is a rotation")
	check((-b.y).dot(sweep) > 0.6, "the palm faces the sweep")
	check((-b.z).dot(away) > 0.6 and (-b.z).y < -0.1, "the fingers reach away and dip to the ground")
	check(absf(b.x.y) > 0.6, "the hand stands on its edge")
	var lift := HandScoop.lift(b, Vector3.ZERO, 0.0)
	var low := INF
	for p in HandScoop.EDGE:
		low = minf(low, (Vector3(0, lift, 0) + b * p).y)
	check(absf(low) < 0.001, "the lowest edge rests on the ground")


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
		var cb := _aabb(c, t)
		if cb.size == Vector3.ZERO and cb.position == Vector3.ZERO:
			continue
		out = cb if first else out.merge(cb)
		first = false
	return out
