class_name LayoutEra1 extends RefCounted
## The new-game layout of the Clearing (design doc 11.4) and the first
## regions' work. Sites are spawned by JobDef / BuildingDef id; an id that the
## data does not define yet is skipped with a warning.

## [job id, x, z, tag] ; tag "evergreen" = the safety-net bushes by the cave.
const JOBS := [
	[&"gather_berries", -9.5, -22.0, "evergreen"],
	[&"gather_berries", -12.5, -17.5, "evergreen"],
	[&"gather_berries", -7.0, -25.0, "evergreen"],
	[&"gather_berries", 9.0, 9.0, ""],
	[&"gather_berries", 6.0, 14.0, ""],
	[&"fetch_water", 12.0, -8.0, ""],
	[&"collect_sticks", -21.0, 5.0, ""],
	[&"collect_sticks", -27.0, -9.0, ""],
	[&"tend_fire", 0.0, -13.0, ""],
	[&"knap_flint", -17.0, -25.0, ""],      # flint in the scree by the cave mouth
	[&"fish_by_hand", 17.2, 22.0, ""],
	[&"haul_log", 44.0, 2.0, "trunk"],
	# Valley Floor
	[&"hunt", 60.0, 10.0, ""],
	[&"knap_flint", 54.0, -16.0, ""],
	[&"gather_berries", 66.0, 28.0, ""],
	# Western Meadow
	[&"rich_berries", -56.0, -14.0, ""],
	[&"rich_berries", -62.0, -4.0, ""],
	[&"knap_flint", -66.0, 24.0, ""],
	[&"knap_flint", -58.0, 32.0, ""],
	[&"fell_tree", -74.0, -30.0, ""],
	[&"fell_tree", 72.0, -30.0, ""],
]

## Authored build spots per BuildingDef id. Plots appear when a Village Dream
## asks for that building (World.ensure_plots_for_dream), so the Clearing is
## not littered with stakes before the people want something.
const PLOT_SPOTS := {
	&"hut": [Vector2(-11.0, -7.0), Vector2(10.0, -3.5), Vector2(-5.0, 3.0), Vector2(-17.0, -11.0), Vector2(6.0, 7.0), Vector2(-12.0, 9.0)],
	&"fire_circle": [Vector2(-1.5, -4.5)],
	&"shrine": [Vector2(6.5, -22.5)],
	&"cairn": [Vector2(6.5, -22.5)],
	&"stone_circle": [Vector2(-26.0, -16.0)],
	&"food_store": [Vector2(-5.0, -20.0)],
	&"drying_rack": [Vector2(4.0, -17.0)],
}

## The two people of the storm night, huddled outside the cave mouth.
const HUDDLE := [Vector2(-1.3, -24.6), Vector2(1.1, -24.0)]
const SEXES := ["f", "m"]
## Default names by sex, so a man is never "Ona" (the hand may rename them at dawn).
const NAMES_BY_SEX := {"f": "Ona", "m": "Tuk"}
## The first two live long: their deaths fall early in Era 2, the first
## generation passing (doc 3 life cycle, tuned so Era 1 keeps its founders).
const FIRST_TWO_EXTRA_LIFE := 900.0

static var warned: Dictionary = {}

static func warn_missing(kind: String, id: StringName) -> void:
	if warned.has(id):
		return
	warned[id] = true
	push_warning("[world] %s '%s' is not defined in Defs yet; skipped." % [kind, id])
	print("WARN world: %s '%s' not in Defs, skipped" % [kind, id])

static func spawn(world) -> Array:
	var people: Array = []
	for row in JOBS:
		var id: StringName = row[0]
		var at := Vector3(row[1], 0, row[2])
		var tag: String = row[3]
		var s = world.spawn_site(id, at)
		if s == null:
			continue
		if tag != "":
			s.set_meta("layout_tag", tag)
	for i in HUDDLE.size():
		var p = world.spawn_person(Vector3(HUDDLE[i].x, 0, HUDDLE[i].y), NAMES_BY_SEX[SEXES[i]], {
			"sex": SEXES[i], "first_two": true, "trust_f": 1.2,
			"age": Person.STAGE_START[Person.Stage.ADULT] + 90.0 + i * 60.0,
			"death_age": Person.DEATH_AGE + FIRST_TWO_EXTRA_LIFE})
		if p != null:
			p.rotation.y = PI     # facing out at the storm
			people.append(p)
	return people
