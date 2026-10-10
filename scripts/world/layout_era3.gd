class_name LayoutEra3 extends RefCounted
## Where Era 3 (Town) happens (doc 10.1): the town grows east along the
## Valley Floor from the old Clearing, the great hall goes up where the
## temple stood, the aqueduct walks in on stone legs from a spring in the
## east, the mills sit on the stream and the plains, the observatory crowns
## the hill quarry, and once the hand calms the sea the Coast opens: a
## harbour on the beach, a lighthouse on the point, and the islands beyond.
## Plots appear when the people want them (scripts/ai/village_era3.gd).

## BuildingDef id -> spots (x, z). The first free spot is used.
const PLOT_SPOTS := {
	&"mason": [Vector2(160.0, -20.0)],
	&"forge": [Vector2(146.0, -22.0)],
	&"school": [Vector2(80.0, 32.0)],
	&"fire_station": [Vector2(70.0, 18.0)],
	&"clinic": [Vector2(112.0, 36.0)],
	&"market_hall": [Vector2(98.0, -30.0)],
	&"clocktower": [Vector2(84.0, -26.0)],
	&"printing_house": [Vector2(116.0, -32.0)],
	&"laboratory": [Vector2(132.0, -36.0)],
	&"windmill": [Vector2(-42.0, 84.0)],
	&"watermill": [Vector2(13.5, 75.0)],
	&"great_hall": [Vector2(6.5, -21.0)],
	&"aqueduct": [Vector2(39.0, 2.0)],
	&"observatory": [Vector2(312.0, -118.0)],
	&"harbour": [Vector2(352.0, 441.6)],
	&"lighthouse": [Vector2(405.0, 365.0)],
	&"townhouse": [Vector2(86.0, -12.0), Vector2(96.0, -12.0), Vector2(106.0, -12.0), Vector2(116.0, -12.0),
		Vector2(126.0, -12.0), Vector2(86.0, 14.0), Vector2(96.0, 14.0), Vector2(106.0, 14.0), Vector2(116.0, 14.0),
		Vector2(126.0, 14.0), Vector2(136.0, -12.0), Vector2(136.0, 14.0), Vector2(146.0, 14.0), Vector2(146.0, -12.0)],
}
## Some buildings face a particular way (radians about Y); the rest use their BuildingDef yaw.
const YAW := {&"harbour": -2.4981, &"watermill": 0.0}

## The aqueduct: the castellum (BuildingDef aqueduct, the town end) stands at
## PLOT_SPOTS.aqueduct; arches run east from it to the spring head, every
## SEGMENT metres, all at the castellum's height (doc 10: kept level).
const AQUEDUCT_DIR := Vector2(1.0, 0.0)
const AQUEDUCT_FIRST := 8.0            # castellum centre to the first arch centre
const AQUEDUCT_SEGMENT := 12.0
const AQUEDUCT_SEGMENTS := 11
## The spring the aqueduct draws from (a water job once it runs).
const SPRING := Vector2(178.0, 2.0)
## The town square: the fountain appears here when the water arrives, and the
## town flag when the town loves the hand.
const FOUNTAIN := Vector2(-2.0, 16.0)
const FLAG := Vector2(8.0, 20.0)
## Street lamps along the town street (lit at dusk).
const LAMPS: Array[Vector2] = [Vector2(81.0, -5.0), Vector2(101.0, -5.0), Vector2(121.0, -5.0), Vector2(141.0, -5.0),
	Vector2(91.0, 8.0), Vector2(111.0, 8.0), Vector2(131.0, 8.0), Vector2(-6.0, 10.0), Vector2(6.0, 24.0), Vector2(22.0, 6.0)]

## [job id, x, z] spawned when Era 3 begins (iron on the hill quarry, more timber).
const START_JOBS := [[&"mine_iron", 262.0, -128.0], [&"mine_iron", 252.0, -140.0], [&"mine_iron", 270.0, -112.0],
	[&"fell_tree", 110.0, -52.0], [&"fell_tree", 150.0, 40.0], [&"fell_tree", -90.0, 40.0]]
## [job id, x, z] spawned when a region opens.
const REGION_JOBS := {
	&"coast": [[&"gather_berries", 318.0, 392.0], [&"fetch_water", 300.0, 380.0], [&"fell_tree", 290.0, 420.0]],
}
const CAMPS := {&"coast": Vector2(331.6, 414.4)}
const EDGES := {&"coast": Vector2(300.0, 470.0)}
## Where the ship waits on the beach for the hand to set it on the water, and
## where it rides at anchor once it floats.
const SHIP_BEACH := Vector2(372.0, 423.0)
const SHIP_ANCHOR := Vector2(368.0, 468.0)
const SHIP_WEIGHT := 10.0
## The far island the voyages sail to (tin), and the anchorage there.
const ISLAND := Vector2(505.0, 470.0)
const VOYAGE_SITE := Vector2(346.0, 432.0)
## The hand calms this stretch of sea (Calm Waters over any open water counts).
const ROUGH_SEA := Vector2(380.0, 470.0)

## Keep-out zones for the foliage (trees are not grown on these).
static func keep_out() -> Array:
	var z: Array = []
	for id in PLOT_SPOTS:
		var b: Vector2 = Vector2(9, 9)
		match id:
			&"great_hall": b = Vector2(14, 28)
			&"observatory": b = Vector2(16, 16)
			&"harbour": b = Vector2(18, 12)
			&"aqueduct": b = Vector2(8, 8)
		for spot in PLOT_SPOTS[id]:
			z.append([spot, maxf(b.x, b.y) * 0.6])
	for i in AQUEDUCT_SEGMENTS:
		z.append([aqueduct_segment(i), 7.0])
	for row in START_JOBS:
		z.append([Vector2(row[1], row[2]), 3.5])
	for r in REGION_JOBS:
		for row in REGION_JOBS[r]:
			z.append([Vector2(row[1], row[2]), 3.5])
	for r in CAMPS:
		z.append([CAMPS[r], 6.0])
	z.append([FOUNTAIN, 4.0])
	z.append([SHIP_BEACH, 8.0])
	z.append([SPRING, 4.0])
	for l in LAMPS:
		z.append([l, 1.5])
	return z

static func spots(id: StringName) -> Array:
	return PLOT_SPOTS.get(id, [])

## Centre (x, z) of the i-th aqueduct arch, counting from the castellum.
static func aqueduct_segment(i: int) -> Vector2:
	return PLOT_SPOTS[&"aqueduct"][0] + AQUEDUCT_DIR * (AQUEDUCT_FIRST + AQUEDUCT_SEGMENT * float(i))
