extends "res://scripts/world/world.gd"
## Flat test world for the hand: ground at y = 0, a 60 m box.

func ground_y(_x: float, _z: float) -> float: return 0.0

func mouse_ground() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	var t := -o.y / d.y
	return o + d * t if t > 0.0 else Vector3.INF

func site_near(p: Vector3, r: float, filter: Callable = Callable()) -> Site:
	var best: Site = null
	var bd := r
	for s in Village.sites:
		if not is_instance_valid(s):
			continue
		if filter.is_valid() and not filter.call(s):
			continue
		var d := Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length()
		if d <= bd:
			bd = d
			best = s
	return best

func camera_bounds() -> AABB:
	return AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))
