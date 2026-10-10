class_name Valley extends RefCounted
## The hand-authored valley as data: a 2 m heightmap over 1.2 km, the region
## map, and the water (river, stream, sea). Pure data, no nodes, so tests and
## the navmesh baker can use it without the scene.
##
## Axes: +x east, -z north, +y up. The Clearing is at the origin, the cave in
## the cliff to its north. The river runs west to east south of the Clearing
## and bends south-east into the sea; mountains frame the north (section 10.3).

const HALF := 600.0
const CELL := 2.0
const N := 601                      # samples per side: 1200 m / 2 m + 1
const SEA_LEVEL := 0.0

## Region ids, in the order of design doc section 10.1. Index = region number.
const REGIONS: Array[StringName] = [&"clearing", &"valley_floor", &"western_meadow", &"east_bank",
	&"southern_plains", &"hill_quarry", &"coast", &"northern_pass", &"launch_plateau"]
## Ids other workers might use in data, mapped to ours.
const ALIASES := {&"valley": &"valley_floor", &"meadow": &"western_meadow", &"west_meadow": &"western_meadow",
	&"eastbank": &"east_bank", &"plains": &"southern_plains", &"quarry": &"hill_quarry",
	&"coast_islands": &"coast", &"pass": &"northern_pass", &"plateau": &"launch_plateau"}

## Rect per region (x, z, width, depth) for the camera bounds and the art.
const RECTS := {
	&"clearing": Rect2(-50, -42, 100, 88),
	&"valley_floor": Rect2(40, -75, 160, 190),
	&"western_meadow": Rect2(-205, -85, 165, 195),
	&"east_bank": Rect2(140, 100, 160, 140),
	&"southern_plains": Rect2(-120, 110, 270, 130),
	&"hill_quarry": Rect2(170, -160, 130, 200),
	&"coast": Rect2(300, 240, 300, 360),
	&"northern_pass": Rect2(-320, -600, 540, 420),
	&"launch_plateau": Rect2(-50, -95, 100, 60),
}

# Landmarks of the Clearing (y is filled from the heightmap at runtime).
const CAVE := Vector2(0.0, -30.5)          # inside the cave mouth
const CAVE_MOUTH := Vector2(0.0, -27.0)    # where the storm branch lies
const FIRE := Vector2(0.0, -13.0)
const STREAM_HEAD_Z := -29.0
const EAST_GAP := Vector2(47.0, 2.0)       # the fallen trunk lies here (to the Valley Floor)
const WEST_GAP := Vector2(-47.0, 2.0)      # the fallen logs lie here (to the Western Meadow)
const WOLF_DEN := Vector2(-150.0, -40.0)

var heights := PackedFloat32Array()
var region_ids := PackedByteArray()        # REGIONS index per sample
var noise := FastNoiseLite.new()
var ridge := FastNoiseLite.new()

func _init() -> void:
	noise.seed = 1717
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	ridge.seed = 4242
	ridge.frequency = 0.012
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3

## Fills the heightmap and region map. About half a second.
func generate() -> void:
	heights.resize(N * N)
	region_ids.resize(N * N)
	for j in N:
		var z := -HALF + j * CELL
		for i in N:
			var x := -HALF + i * CELL
			var k := j * N + i
			heights[k] = height_at(x, z)
			region_ids[k] = region_index_at(x, z, heights[k])

# ---------------------------------------------------------------- shape

static func ss(a: float, b: float, x: float) -> float:
	## smoothstep that also works with a > b (reversed edge).
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func river_z(x: float) -> float:
	if x < 230.0:
		return 118.0 + 14.0 * sin(x / 70.0)
	return 118.0 + 14.0 * sin(230.0 / 70.0) + (x - 230.0) * 0.75

static func river_level(x: float) -> float:
	return lerpf(2.4, 0.05, clampf((x + 600.0) / 1100.0, 0.0, 1.0))

static func stream_x(z: float) -> float:
	return 16.0 + 3.5 * sin(z / 11.0)

## > 0 on the sea side of the coast line (south-east).
static func coast_d(x: float, z: float) -> float:
	return x * 0.6 + z * 0.8 - 560.0

## Height before the stream is carved (also the stream's bank height).
func base_height(x: float, z: float) -> float:
	var n1 := noise.get_noise_2d(x, z)
	var h := 5.0 + n1 * 2.5
	# Mountains frame the north, with ridged peaks.
	var m := ss(-110.0, -340.0, z)
	h += m * (55.0 + 45.0 * ridge.get_noise_2d(x, z))
	# The western edge and the north-east edge rise into hills.
	h += ss(-430.0, -585.0, x) * (45.0 + 15.0 * n1)
	h += ss(450.0, 590.0, x) * ss(240.0, 80.0, z) * 40.0
	h += ss(470.0, 590.0, z) * ss(320.0, 120.0, x) * 25.0
	# Hill Quarry: a broad hill north-east with a cliff face to the south-west.
	var dq := Vector2(x - 315.0, z + 150.0).length()
	h += (1.0 - ss(30.0, 150.0, dq)) * 34.0
	# The Clearing: a basin ringed by low wooded ridges, with a gap east and west.
	var cz := z - 2.0
	var d := Vector2(x, cz * 1.08).length()
	var ring := exp(-pow((d - 55.0) / 11.0, 2.0)) * 12.0
	var gap := (1.0 - ss(4.0, 11.0, absf(cz))) * ss(25.0, 38.0, absf(x))
	ring *= 1.0 - gap * 0.93
	# The stream cuts a narrow gorge through the southern ridge.
	if z > 0.0:
		ring *= ss(2.5, 9.0, absf(x - stream_x(z)))
	h += ring
	h = lerpf(h, 4.0 + n1 * 0.5, 1.0 - ss(32.0, 46.0, d))
	# Rock shelf north of the Clearing (the future launch plateau), its cliff
	# facing south over the cave.
	var shelf := ss(-29.0, -35.0, z) * (1.0 - ss(55.0, 85.0, absf(x)))
	h = lerpf(h, maxf(h, 16.0 + n1 * 1.2), shelf)
	# The cave: a flat notch into the cliff.
	var notch := (1.0 - ss(2.6, 4.0, absf(x))) * ss(-26.0, -28.0, z) * (1.0 - ss(-35.0, -37.0, z))
	h = lerpf(h, 4.1, notch)
	# Valley Floor (east) and Western Meadow: broad flats.
	h = lerpf(h, 4.6 + n1 * 0.9, 1.0 - ss(45.0, 90.0, Vector2(x - 110.0, z - 15.0).length()))
	h = lerpf(h, 6.0 + n1 * 1.1, 1.0 - ss(45.0, 85.0, Vector2(x + 115.0, z - 5.0).length()))
	# Southern Plains: flat and dry.
	h = lerpf(h, 4.8 + n1 * 0.6, ss(170.0, 230.0, z) * (1.0 - ss(120.0, 260.0, x)) * (1.0 - ss(400.0, 480.0, z)))
	# The great river.
	var dr := absf(z - river_z(x))
	var rw := river_level(x)
	var prof := lerpf(rw - 1.7, rw + 1.4, ss(4.0, 11.0, dr))
	h = lerpf(h, prof, (1.0 - ss(11.0, 45.0, dr)) * (1.0 - m))
	# The sea to the south-east, with two islands.
	var c := coast_d(x, z)
	h = lerpf(h, -3.0 - c * 0.04, ss(-25.0, 35.0, c))
	for isl in [Vector3(505.0, 470.0, 9.0), Vector3(420.0, 560.0, 6.0), Vector3(560.0, 380.0, 5.0)]:
		var di := Vector2(x - isl.x, z - isl.y).length()
		h = maxf(h, lerpf(-4.0, isl.z + n1 * 1.5, 1.0 - ss(10.0, 45.0, di)))
	return h

func height_at(x: float, z: float) -> float:
	var h := base_height(x, z)
	var zr := river_z(stream_x(z))
	if z > STREAM_HEAD_Z - 1.0 and z < zr:
		var ds := absf(x - stream_x(z))
		h -= 1.2 * (1.0 - ss(1.0, 3.2, ds)) * ss(STREAM_HEAD_Z - 1.0, STREAM_HEAD_Z + 1.5, z)
	return h

## Water surface height of the stream at depth z.
func stream_level(z: float) -> float:
	return base_height(stream_x(z), z) - 0.45

# ---------------------------------------------------------------- regions

func region_index_at(x: float, z: float, h: float) -> int:
	if coast_d(x, z) > -15.0 or h < SEA_LEVEL - 0.5:
		return 6
	if z > river_z(x):
		return 3 if x > 140.0 else 4
	if z < -200.0:
		return 7
	if x > 175.0:
		return 5
	if absf(x) <= 46.0:
		if z < -38.0:
			return 8 if z > -110.0 else 7
		return 0 if z <= 44.0 else 1
	if z < -120.0:
		return 7
	return 1 if x > 0.0 else 2

func region_at(x: float, z: float) -> StringName:
	return REGIONS[region_index(x, z)]

func region_index(x: float, z: float) -> int:
	var i := clampi(roundi((x + HALF) / CELL), 0, N - 1)
	var j := clampi(roundi((z + HALF) / CELL), 0, N - 1)
	return region_ids[j * N + i] if region_ids.size() == N * N else region_index_at(x, z, height_at(x, z))

static func canon(id: StringName) -> StringName:
	return ALIASES.get(id, id)

# ---------------------------------------------------------------- queries

## Bilinear sample of the heightmap (matches the rendered mesh in detailed chunks).
func ground_y(x: float, z: float) -> float:
	if heights.size() != N * N:
		return height_at(x, z)
	var fx := clampf((x + HALF) / CELL, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / CELL, 0.0, N - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var k := j * N + i
	var a := lerpf(heights[k], heights[k + 1], tx)
	var b := lerpf(heights[k + N], heights[k + N + 1], tx)
	return lerpf(a, b, tz)

func sample(i: int, j: int) -> float:
	return heights[clampi(j, 0, N - 1) * N + clampi(i, 0, N - 1)]

func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	var hx := ground_y(x + e, z) - ground_y(x - e, z)
	var hz := ground_y(x, z + e) - ground_y(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()

## Water surface at x,z, or -INF where there is no water.
func water_level(x: float, z: float) -> float:
	var g := ground_y(x, z)
	if g < SEA_LEVEL:
		return SEA_LEVEL
	var zr := river_z(x)
	if absf(z - zr) < 9.0:
		var rw := river_level(x)
		if g < rw:
			return rw
	if z > STREAM_HEAD_Z and z < river_z(stream_x(z)) and absf(x - stream_x(z)) < 2.2:
		var sl := stream_level(z)
		if g < sl:
			return sl
	return -INF

func is_water(x: float, z: float) -> bool:
	return water_level(x, z) > ground_y(x, z) - 0.05
