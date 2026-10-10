extends SceneTree
## Dev tool: prints AABB, node layout and materials of every imported model under a folder.
## godot --headless --path . -s res://scripts/assets/tools/inspect_models.gd -- res://assets/models/nature

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for dir in args:
		_inspect_dir(dir)
	quit()

func _inspect_dir(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import") or f.ends_with(".bin") or f.ends_with(".png"):
			continue
		var ps := load(dir.path_join(f)) as PackedScene
		if ps == null:
			print(f, ": not a scene")
			continue
		var n := ps.instantiate() as Node3D
		root.add_child(n)
		var box := _aabb(n, Transform3D.IDENTITY)
		var mats: Array[String] = []
		_mats(n, mats)
		print("%s size=%s pos=%s mats=%s" % [f, _v(box.size), _v(box.position), ", ".join(mats)])
		n.free()

func _v(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]

func _aabb(n: Node, xf: Transform3D) -> AABB:
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

func _mats(n: Node, out: Array[String]) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var s := "?"
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				s = "%s#%s%s" % [m.resource_name, bm.albedo_color.to_html(false), "+tex" if bm.albedo_texture else ""]
			out.append(s)
	for c in n.get_children():
		_mats(c, out)
