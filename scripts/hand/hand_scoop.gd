class_name HandScoop
extends RefCounted
## The hand's scoop pose (HandVisual uses it while the hand sweeps people up).
## The scoop: the hand stands on its little-finger edge like a dustpan, the cupped palm
## facing the way it sweeps, fingers together and reaching away from the camera.
const CURL := [0.05, 0.12, 0.13, 0.15, 0.2]
const CUP := 0.75          # the palm hollowed
const SPREAD := -0.6
const DIP := 20.0          # degrees the fingers point down from level
const PALM_UP := 32.0      # degrees the palm tips up, to scoop rather than shove
const CLEAR := 0.04        # the lowest edge rides this far over the ground (hand lengths)
## points on the glove (hand units, palm down: fingers -Z, back +Y, thumb -X) used to
## find its lowest edge
const EDGE := [Vector3(0.24, -0.06, -0.25), Vector3(0.22, -0.06, -0.62), Vector3(0.1, -0.08, -0.95),
	Vector3(-0.26, -0.06, -0.3), Vector3(-0.1, -0.08, -0.98), Vector3(0.0, -0.12, -0.05)]


## The scoop's orientation: palm (-Y of the glove) toward `sweep`, fingers (-Z) away
## from the camera (`away`, flat) and dipping, the little-finger edge down when the sweep
## runs right to left as seen from the camera (the thumb edge, the other way).
static func basis(sweep: Vector3, away: Vector3) -> Basis:
	var n := Vector3(sweep.x, 0.0, sweep.z).normalized()
	var a := Vector3(away.x, 0.0, away.z)
	var f := (a - n * a.dot(n))
	f = f.normalized() if f.length() > 0.05 else n.cross(Vector3.UP).normalized()
	f = (f * cos(deg_to_rad(DIP)) - Vector3.UP * sin(deg_to_rad(DIP))).normalized()
	n = (n * cos(deg_to_rad(PALM_UP)) + Vector3.UP * sin(deg_to_rad(PALM_UP)))
	n = (n - f * n.dot(f)).normalized()
	var z := -f
	var y := -n
	return Basis(y.cross(z), y, z)


## How far to raise a hand placed at `origin` with basis `b` so its lowest edge
## (EDGE) is at height `floor_y`.
static func lift(b: Basis, origin: Vector3, floor_y: float) -> float:
	var low := INF
	for p in EDGE:
		low = minf(low, (origin + b * p).y)
	return floor_y - low
