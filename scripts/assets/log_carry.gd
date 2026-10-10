class_name LogCarry
extends Node3D
## The two-person log carry: the log rests on the carriers' right shoulders while the
## group carries it (the "carry_log" clip puts a hand on top), and lies on the ground
## while they wait. SiteVisual builds one for the carry_log job; Site.slot_position()
## asks slot() where the carriers stand: one at each end, the log over their right
## shoulders, facing the way it is going.
## The log follows the carriers' shoulders each frame, so it stays on them however
## their steps fall.

const END := 0.95           # carriers stand this far from the log's middle (m)
const SHOULDER_IN := 0.21   # the log's axis is this far right of a carrier's centre (adult)
const LIFT_TIME := 0.45     # seconds to swing it up onto the shoulders or down again
const LENGTH := 2.6         # the log's length (m)

var site: Node3D            # the Site (duck-typed: workers, group_running, global_position)
var _log: Node3D            # the log model, centred, its length along local X
var _length := 2.0
var _up := 0.0              # 0 on the ground .. 1 on the shoulders


## `thickness`: the log's height in metres (a shoulder log is about a quarter metre through).
static func make(s: Node3D, seed_v: int, thickness: float = 0.26) -> LogCarry:
	var lc := LogCarry.new()
	lc.name = "LogCarry"
	lc.site = s
	var art := AssetCatalog.instance(&"log_fallen", seed_v)
	var inner := Node3D.new()
	inner.add_child(art)
	# centre the log, its long side along X and its underside at y = 0 ...
	var box := _aabb(inner, Transform3D.IDENTITY)
	if box.size.z > box.size.x:
		art.rotation.y += PI * 0.5
		art.position = art.position.rotated(Vector3.UP, PI * 0.5)
		box = _aabb(inner, Transform3D.IDENTITY)
	art.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	# ... as thick as a shoulder log, long enough to overhang both carriers a little
	inner.scale = Vector3(LENGTH / maxf(box.size.x, 0.01), thickness / maxf(box.size.y, 0.01), thickness / maxf(box.size.z, 0.01))
	var pivot := Node3D.new()
	pivot.add_child(inner)
	lc._length = LENGTH
	lc._log = pivot
	lc.add_child(pivot)
	return lc


## Where the i-th carrier of a log-carry site stands (world position).
static func slot(s: Node3D, i: int) -> Vector3:
	var f := heading(s)
	var right := f.cross(Vector3.UP)          # a carrier facing f has its right hand here
	var along := END * (1.0 if i % 2 == 0 else -1.0) * (1.0 + float(i / 2) * 0.6)
	var p: Vector3 = s.global_position + f * along - right * SHOULDER_IN
	p.y = _ground(s, p)
	return p


## The way the log will travel (flat unit vector), fixed once worked out.
static func heading(s: Node3D) -> Vector3:
	if s.has_meta(&"log_heading"):
		return s.get_meta(&"log_heading")
	var to: Vector3 = s.global_position + Vector3.FORWARD
	# the Site's own statics, looked up through its script (keeps this class free of the
	# game's autoloads, so the art tools and sheets can use it)
	var site_script: Script = s.get_script()
	var job = s.get(&"job")
	if job != null and site_script != null and job.carry_to == &"fire" and site_script.has_method(&"nearest"):
		var fire = site_script.call(&"nearest", s.global_position, 120.0, func(o): return o != s and o.is_fire())
		if fire != null:
			to = fire.global_position
	elif job != null and site_script != null and site_script.has_method(&"store_point"):
		to = site_script.call(&"store_point", s.global_position)
	var d := to - s.global_position
	d.y = 0.0
	var h := d.normalized() if d.length() > 0.1 else Vector3.BACK
	s.set_meta(&"log_heading", h)
	return h


func _process(delta: float) -> void:
	if site == null or not is_instance_valid(site) or _log == null:
		return
	var carriers := _carriers()
	var lifting: bool = site.get(&"group_running") and carriers.size() >= 2
	_up = move_toward(_up, 1.0 if lifting else 0.0, delta / LIFT_TIME)
	# on the ground: lying along the heading at the site
	var f := heading(site)
	var ground := Transform3D(_frame(f), site.global_position)
	if _up <= 0.0 or carriers.size() < 2:
		global_transform = global_transform.interpolate_with(ground, minf(delta * 8.0, 1.0)) if _up > 0.0 else ground
		return
	# on the shoulders: through the front and back carriers' right shoulders
	var a: Vector3 = carriers[0]
	var b: Vector3 = carriers[1]
	var axis := a - b
	if axis.length() < 0.2:
		axis = f
	var up_xf := Transform3D(_frame(axis), (a + b) * 0.5)   # the log's underside on the shoulders
	var e := _ease(_up)
	global_transform = Transform3D(ground.basis.slerp(up_xf.basis, e), ground.origin.lerp(up_xf.origin, e))


## Right-shoulder points of the two carriers furthest apart (world), front first.
func _carriers() -> Array:
	var pts: Array = []
	var ws = site.get(&"workers")
	if ws == null:
		return pts
	for w in ws:
		if w == null or not is_instance_valid(w) or w.get(&"visual") == null:
			continue
		var v = w.visual.get(&"villager")
		if v == null or not v.has_method(&"shoulder_point"):
			continue
		if (w.global_position - site.global_position).length() > _length * 0.5 + 1.6:
			continue
		pts.append(v.shoulder_point(&"r"))
	if pts.size() > 2:
		var f := heading(site)
		pts.sort_custom(func(p, q): return p.dot(f) > q.dot(f))
		pts = [pts[0], pts[pts.size() - 1]]
	elif pts.size() == 2 and (pts[1] - pts[0]).dot(heading(site)) > 0.0:
		pts.reverse()
	return pts


static func _ground(s: Node3D, p: Vector3) -> float:
	var site_script: Script = s.get_script()
	if site_script != null and site_script.has_method(&"ground"):
		return site_script.call(&"ground", p.x, p.z)
	return s.global_position.y


## A basis with X along `along` (its slope kept), Y as near up as it can be.
static func _frame(along: Vector3) -> Basis:
	var x := along.normalized()
	var z := x.cross(Vector3.UP).normalized()
	return Basis(x, z.cross(x), z)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is VisualInstance3D:
		out = t * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out
