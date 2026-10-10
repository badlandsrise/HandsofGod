extends SceneTree
func _init():
	await process_frame
	for id in AssetCatalog.ids():
		var n := AssetCatalog.instance(StringName(id))
		root.add_child(n)
		var ab := AABB()
		var first := true
		for mi in n.find_children("*", "VisualInstance3D", true, false):
			var a: AABB = (mi as VisualInstance3D).global_transform * (mi as VisualInstance3D).get_aabb()
			if first: ab = a; first = false
			else: ab = ab.merge(a)
		print("%-16s size %s  fp %s  y0 %.2f" % [id, ab.size, AssetCatalog.footprint(StringName(id)), ab.position.y])
		n.free()
	quit()
