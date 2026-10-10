class_name LayoutEra2 extends RefCounted
## Where Era 2 (Village) happens: the authored build spots of the village's new
## buildings, and what each new region holds when it opens (doc 10.1):
##   East Bank (Reach)          a camp, clay pits, copper ore, a bear's den
##   Southern Plains (Rain)     a camp and the big dry fields
##   Hill Quarry (Strength II)  a camp and quarry ledges behind the rockfall
## The great bridge crosses the river from the Valley Floor to the East Bank.
## Plots appear when the people want them (scripts/ai/village_era2.gd), never
## all at once.

## BuildingDef id -> spots (x, z). The first free spot is used.
const PLOT_SPOTS := {
	&"granary": [Vector2(22.0, -12.0)],
	&"field": [Vector2(-28.0, 78.0), Vector2(-16.0, 78.0), Vector2(-28.0, 89.0), Vector2(-16.0, 89.0)],
	&"mill": [Vector2(31.0, 3.0)],
	&"bakery": [Vector2(31.0, 15.0)],
	&"well": [Vector2(-21.0, -1.0)],
	&"kiln": [Vector2(-12.0, 30.0)],
	&"charcoal_clamp": [Vector2(74.0, -14.0)],
	&"smelter": [Vector2(58.0, -4.0)],
	&"smithy": [Vector2(66.0, -4.0)],
	&"weaver": [Vector2(-31.0, -3.0)],
	&"sheep_pen": [Vector2(95.0, 32.0)],
	&"market": [Vector2(-13.0, 19.0)],
	&"watchtower": [Vector2(178.0, 172.0)],
	&"barn": [Vector2(1.0, 89.0)],
	&"cottage": [Vector2(-30.0, 17.0), Vector2(-1.0, 26.0), Vector2(-31.0, 7.0), Vector2(27.0, 27.0), Vector2(-24.0, 29.0), Vector2(26.0, -24.0), Vector2(24.0, 38.0), Vector2(-36.0, -12.0)],
	&"temple": [Vector2(6.5, -21.0)],
	&"bridge": [Vector2(150.0, 130.0)],
}
## Fields on the Southern Plains (dry until the hand brings Rain).
const PLAINS_FIELDS: Array[Vector2] = [Vector2(-30.0, 166.0), Vector2(-18.0, 166.0), Vector2(-6.0, 166.0),
	Vector2(-30.0, 177.0), Vector2(-18.0, 177.0), Vector2(-6.0, 177.0)]

## [job id, x, z] spawned when a region opens.
const REGION_JOBS := {
	&"east_bank": [[&"dig_clay", 184.0, 160.0], [&"dig_clay", 193.0, 168.0], [&"mine_ore", 214.0, 186.0], [&"mine_ore", 224.0, 178.0],
		[&"gather_berries", 170.0, 190.0], [&"fell_tree", 200.0, 205.0], [&"fish_by_hand", 160.0, 142.0]],
	&"southern_plains": [[&"fetch_water", 12.0, 139.0], [&"gather_berries", 44.0, 182.0], [&"gather_berries", -44.0, 190.0]],
	&"hill_quarry": [[&"quarry_stone", 236.0, -104.0], [&"quarry_stone", 248.0, -92.0], [&"quarry_stone", 226.0, -118.0], [&"knap_flint", 214.0, -78.0]],
}
## The camp each new region gets: a stockpile and a night shelter on the far side.
const CAMPS := {&"east_bank": Vector2(165.0, 153.0), &"southern_plains": Vector2(24.0, 150.0), &"hill_quarry": Vector2(203.0, -62.0)}
## The builders' yard on the near bank, pitched when the bridge plot is laid:
## a stockpile and a night shelter so the bridge crew is not walking home.
const BRIDGE_YARD := Vector2(144.0, 98.0)
## Where newcomers walk in from, per region.
const EDGES := {&"east_bank": Vector2(285.0, 225.0), &"southern_plains": Vector2(-100.0, 230.0), &"hill_quarry": Vector2(285.0, -140.0)}
## The raft is built on the north bank, south of the Clearing; once launched the
## people fish from it.
const RAFT := Vector2(60.0, 112.0)
const BOATS: Array[Vector2] = [Vector2(52.0, 113.0), Vector2(68.0, 113.0)]
## The rockfall that closes the Hill Quarry: boulders the hand lifts with Strength II.
const ROCKFALL := Vector2(181.0, -46.0)
const BOULDERS: Array[Vector2] = [Vector2(180.0, -52.0), Vector2(182.5, -45.5), Vector2(179.5, -39.0)]
const BOULDER_WEIGHT := 10.0
const ROCKFALL_CLEAR := 7.0
## The bear's den on the East Bank.
const BEAR_DEN := Vector2(236.0, 214.0)
## The harvest festival is held between the fields and the barn.
const FESTIVAL_SPOT := Vector2(-6.0, 70.0)

## Keep-out zones for the foliage (trees are not grown on these).
static func keep_out() -> Array:
	var z: Array = []
	for id in PLOT_SPOTS:
		var b: Vector2 = Vector2(8, 8)
		match id:
			&"field": b = Vector2(10, 8)
			&"barn": b = Vector2(10, 12)
			&"temple": b = Vector2(12, 16)
			&"bridge": b = Vector2(6, 22)
		for spot in PLOT_SPOTS[id]:
			z.append([spot, maxf(b.x, b.y) * 0.6])
	for spot in PLAINS_FIELDS:
		z.append([spot, 6.5])
	for r in REGION_JOBS:
		for row in REGION_JOBS[r]:
			z.append([Vector2(row[1], row[2]), 3.5])
	for r in CAMPS:
		z.append([CAMPS[r], 6.0])
	z.append([BRIDGE_YARD, 6.0])
	z.append([RAFT, 6.0])
	z.append([ROCKFALL, 10.0])
	z.append([FESTIVAL_SPOT, 5.0])
	return z

static func spots(id: StringName) -> Array:
	return PLOT_SPOTS.get(id, [])
