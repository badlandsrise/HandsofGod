extends SceneTree
## Dev tool: prints the node tree of a scene (and the animations of any AnimationPlayer in it).
## godot --headless --path . -s res://scripts/assets/tools/print_tree.gd -- res://path/to/scene

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var n := (load(path) as PackedScene).instantiate()
		_print(n, 0)
		n.free()
	quit()

func _print(n: Node, depth: int) -> void:
	var extra := ""
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		extra = " bones=%d head_rest=%s" % [sk.get_bone_count(), str(sk.get_bone_global_rest(sk.find_bone("Head")).origin)]
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		var names := ap.get_animation_list()
		extra = " anims=%d" % names.size()
		if names.size() > 0:
			var a := ap.get_animation(names[0])
			extra += " first=%s len=%.2f tracks=%d sample=%s" % [names[0], a.length, a.get_track_count(), str(a.track_get_path(0))]
	if n is MeshInstance3D:
		extra = " skin=%s skel=%s" % [str((n as MeshInstance3D).skin != null), str((n as MeshInstance3D).skeleton)]
	if n is Node3D and (n as Node3D).transform != Transform3D.IDENTITY:
		extra += " xf=%s" % str((n as Node3D).transform)
	print("  ".repeat(depth), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_print(c, depth + 1)
