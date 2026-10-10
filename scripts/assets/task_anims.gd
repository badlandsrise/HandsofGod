class_name TaskAnims
extends RefCounted
## Which villager animation (and which props in the hands) each kind of work uses.
## Data only: VillagerVisual plays the clips (baked by build_villager_anims.gd) and
## PropKit builds the props. A job picks its clip, in order:
##   1. JobDef.anim, when set (a new job just names a clip there),
##   2. JOBS[job id] below,
##   3. BY_KIND[job kind].
## for_job() returns a Dictionary:
##   work: Array[StringName]  clips while working (one per person, picked by their id)
##   move: StringName         clip while walking to and about the work ("" = walk)
##   carry: StringName        clip while the group carries the work along (log carries)
##   carry_idle: StringName   ... and while it stands still with it
##   r, l: StringName         props in the right and left hand while working ("" = none)
##   move_r, move_l           props while walking about the work

## Props each clip holds by default: [right hand, left hand].
const CLIP_PROPS := {
	&"chop": [&"axe", &""],
	&"knap": [&"hammerstone", &"flint_core"],
	&"tend": [&"firestick", &""],
	&"pick": [&"", &"basket"],
	&"hammer": [&"mallet", &"peg"],
	&"build_kneel": [&"mallet", &""],
	&"dig": [&"pick", &""],
	&"harvest": [&"sickle", &""],
	&"sow": [&"", &"seed_bag"],
	&"water": [&"", &"bucket"],
	&"read": [&"", &"book"],
	&"spear_walk": [&"spear", &""],
	&"spear_ready": [&"spear", &""],
	&"fish": [&"", &""],
	&"craft": [&"knife", &""],
	&"rope": [&"", &""],
	&"lookout": [&"", &""],
}

## Every clip a task can name (the tests check each is in the baked library).
const TASK_CLIPS: Array[StringName] = [
	&"pick", &"gather", &"chop", &"knap", &"tend", &"pray", &"sit", &"carry", &"carry_walk",
	&"carry_log", &"carry_log_idle", &"push", &"sow", &"harvest", &"water", &"hammer",
	&"build_kneel", &"craft", &"dig", &"rope", &"fish", &"read", &"lookout", &"talk",
	&"spear_walk", &"spear_ready", &"dance", &"cheer", &"wave", &"idle", &"idle_fold",
	&"idle_hips", &"nod", &"eat", &"baby_sit", &"sit_talk",
]

const JOBS := {
	# Era 1
	&"gather_berries": {"work": [&"pick"]},
	&"rich_berries": {"work": [&"pick"]},
	&"collect_sticks": {"work": [&"gather"]},
	&"fell_tree": {"work": [&"chop"], "r": &"stone_axe"},
	&"knap_flint": {"work": [&"knap"]},
	&"tend_fire": {"work": [&"tend"]},
	&"fetch_water": {"work": [&"fish"], "l": &"waterskin"},
	&"fish_by_hand": {"work": [&"fish"]},
	&"carry_log": {"work": [&"carry_log_idle"], "carry": &"carry_log", "carry_idle": &"carry_log_idle"},
	&"haul_log": {"work": [&"push"], "carry": &"push", "carry_idle": &"push"},
	&"hunt": {"work": [&"spear_ready"], "move": &"spear_walk", "move_r": &"spear"},
	&"great_elk_hunt": {"work": [&"spear_ready"], "move": &"spear_walk", "move_r": &"spear"},
	&"pray": {"work": [&"pray"]},
	&"festival": {"work": [&"dance", &"cheer", &"dance"]},
	&"build": {"work": [&"hammer", &"build_kneel"]},
	# Era 2
	&"farm_field": {"work": [&"sow", &"harvest", &"water"]},
	&"herd_sheep": {"work": [&"idle_hips", &"lookout"], "l": &"crook"},
	&"draw_water": {"work": [&"rope"]},
	&"dig_clay": {"work": [&"dig"], "r": &"spade"},
	&"mine_ore": {"work": [&"dig"]},
	&"quarry_stone": {"work": [&"dig"]},
	&"burn_charcoal": {"work": [&"tend"]},
	&"bake_bread": {"work": [&"craft"], "r": &""},
	&"fire_kiln": {"work": [&"tend"]},
	&"mill_grain": {"work": [&"craft"], "r": &""},
	&"weave_cloth": {"work": [&"craft"], "r": &""},
	&"smelt_bronze": {"work": [&"tend"], "r": &"tongs"},
	&"forge_tools": {"work": [&"hammer"], "r": &"hammer", "l": &"tongs"},
	&"keep_market": {"work": [&"talk", &"idle_hips"]},
	&"keep_watch": {"work": [&"lookout"], "l": &"spear"},
	&"pray_temple": {"work": [&"pray"]},
	&"harvest_festival": {"work": [&"dance", &"cheer", &"dance"]},
	&"barn_raising": {"work": [&"rope", &"hammer"]},
	&"bridge_building": {"work": [&"rope", &"hammer"]},
	&"temple_raising": {"work": [&"rope", &"hammer"]},
	&"raft_launch": {"work": [&"push"]},
	&"fish_boat": {"work": [&"fish"]},
	# Era 3
	&"mine_iron": {"work": [&"dig"]},
	&"quarry_blocks": {"work": [&"dig"]},
	&"dress_stone": {"work": [&"hammer"], "r": &"mallet", "l": &"chisel"},
	&"forge_iron": {"work": [&"hammer"], "r": &"hammer", "l": &"tongs"},
	&"cast_brass": {"work": [&"tend"], "r": &"tongs"},
	&"print_books": {"work": [&"craft"], "r": &""},
	&"experiment": {"work": [&"craft", &"read"], "r": &""},
	&"astronomy": {"work": [&"lookout", &"read"]},
	&"attend_school": {"work": [&"read"]},
	&"foreman": {"work": [&"talk", &"idle_hips"]},
	&"guild_master": {"work": [&"talk", &"idle_fold"]},
	&"keep_light": {"work": [&"tend", &"lookout"]},
	&"fire_watch": {"work": [&"lookout"]},
	&"fight_fire": {"work": [&"water"]},
	&"repair_roof": {"work": [&"hammer"], "r": &"hammer"},
	&"rest_at_clinic": {"work": [&"sit"]},
	&"pray_hall": {"work": [&"pray"]},
	&"great_hall_raising": {"work": [&"rope", &"hammer"]},
	&"aqueduct_crew": {"work": [&"hammer", &"rope"]},
	&"sail_islands": {"work": [&"rope"]},
	&"fish_ship": {"work": [&"fish", &"rope"]},
	&"cart_haul": {"work": [&"carry"]},
	# Era 4
	&"lay_rail": {"work": [&"hammer", &"dig"], "r": &"hammer"},
	&"mine_coal": {"work": [&"dig"]},
	&"assemble_parts": {"work": [&"craft", &"hammer"], "r": &"wrench"},
	&"refine_fuel": {"work": [&"craft"], "r": &"wrench"},
}

## JobDef.Kind -> clip, for jobs with no entry above.
const BY_KIND := {
	0: &"gather",        # GATHER
	1: &"craft",         # CRAFT
	2: &"hammer",        # BUILD
	3: &"rope",          # GROUP
	4: &"tend",          # TEND
	5: &"carry",         # HAUL
	6: &"talk",          # LEAD
	7: &"pray",          # DEVOTION
}

## Skill family -> clip, when only the skill is known (old saves, tests).
const BY_SKILL := {
	&"gathering": &"pick", &"woodcraft": &"chop", &"building": &"hammer", &"farming": &"harvest",
	&"crafting": &"craft", &"metalwork": &"hammer", &"scholarship": &"read",
	&"engineering": &"craft", &"haul": &"carry", &"devotion": &"pray",
}


## The animation plan for a job (see the header). `jd` may be null (no work: {}).
static func for_job(jd: Resource) -> Dictionary:
	if jd == null:
		return {}
	var id: StringName = jd.get(&"id") if jd.get(&"id") != null else &""
	var e: Dictionary = (JOBS.get(id, {}) as Dictionary).duplicate()
	var named = jd.get(&"anim")
	if named != null and StringName(named) != &"":
		e["work"] = [StringName(named)]
	if not e.has("work"):
		var k = jd.get(&"kind")
		e["work"] = [BY_KIND.get(int(k) if k != null else 1, &"craft")]
	return _fill(e)


## The plan for a bare skill family (no JobDef at hand).
static func for_skill(skill: StringName) -> Dictionary:
	if skill == &"":
		return {}
	return _fill({"work": [BY_SKILL.get(skill, &"craft")]})


## The working clip a given person uses (variants spread over people by their id).
static func work_clip(plan: Dictionary, who: int) -> StringName:
	var w: Array = plan.get("work", [])
	if w.is_empty():
		return &"idle"
	return w[posmod(who, w.size())]


## [right, left] props for `clip` under `plan` (the job's own choice wins over the clip's).
static func props(plan: Dictionary, clip: StringName) -> Array:
	var d: Array = CLIP_PROPS.get(clip, [&"", &""])
	var r: StringName = d[0]
	var l: StringName = d[1]
	if clip == plan.get("move", &"_"):
		r = plan.get("move_r", r)
		l = plan.get("move_l", l)
	elif clip in plan.get("work", []):
		r = plan.get("r", r)
		l = plan.get("l", l)
	return [r, l]


static func _fill(e: Dictionary) -> Dictionary:
	if not e.has("move"):
		e["move"] = &""
	return e
