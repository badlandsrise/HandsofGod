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
	[&"tend_fire", 0.0, -13.0, ""],
	[&"carry_log", -14.0, 3.5, ""],
	[&"haul_log", 44.0, 2.0, "trunk"],
	# Valley Floor
	[&"hunt", 112.0, 12.0, ""],
	[&"knap_flint", 92.0, -22.0, ""],
	[&"gather_berries", 125.0, 35.0, ""],
	# Western Meadow
	[&"gather_berries", -100.0, -14.0, "rich"],
	[&"gather_berries", -108.0, -6.0, "rich"],
	[&"knap_flint", -128.0, 26.0, ""],
	[&"fell_tree", -140.0, -30.0, ""],
	[&"fell_tree", 130.0, -30.0, ""],
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
const NAMES := ["Ona", "Tuk"]

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
		var p = world.spawn_person(Vector3(HUDDLE[i].x, 0, HUDDLE[i].y), NAMES[i])
		if p != null:
			p.rotation.y = PI     # facing out at the storm
			people.append(p)
	return people
