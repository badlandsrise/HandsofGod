class_name AssetCatalog
extends RefCounted
## Logical art ids -> ready-to-place visuals (DESIGN 12.3 consistency rule).
##
## Data lives in res://assets/catalog/catalog.json. Usage:
##   var tree := AssetCatalog.instance(&"tree_pine", randi())     # any variant index wraps
##   var bush := AssetCatalog.instance(&"berry_bush", 0, &"winter") # season: autumn / winter
##   AssetCatalog.footprint(&"hut")  -> Vector2(4, 4)  metres, x by z
##   AssetCatalog.set_era(2)          # regrades every catalog material to the Era 2 palette
##
## instance() never returns null: a missing id or a scene that fails to load yields a
## coloured placeholder box of the entry's footprint (named "Placeholder_<id>"), so the
## game never breaks on art. Every visual is a wrapper Node3D (named after the id, meta
## "asset_id") whose origin sits on the ground at the footprint centre; the model is its
## child with the catalog scale/offset/rotation applied and its materials moved onto the
## shared palette shader (ArtPalette). No collision is added; gameplay owns its shapes.

const CATALOG_PATH := "res://assets/catalog/catalog.json"

static var _data: Dictionary = {}
static var _scenes: Dictionary = {}   # path -> PackedScene (or null if it failed)


static func _load() -> void:
	if not _data.is_empty():
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		push_error("AssetCatalog: cannot open %s" % CATALOG_PATH)
		_data = {"defaults": {}, "entries": {}}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AssetCatalog: bad JSON in %s" % CATALOG_PATH)
		_data = {"defaults": {}, "entries": {}}
		return
	_data = parsed


## All catalog ids, sorted.
static func ids() -> PackedStringArray:
	_load()
	var out := PackedStringArray(_data["entries"].keys())
	out.sort()
	return out


static func has(id: StringName) -> bool:
	_load()
	return _data["entries"].has(String(id))


## The raw entry merged over the defaults ({} if unknown).
static func entry(id: StringName) -> Dictionary:
	_load()
	var e: Dictionary = _data["entries"].get(String(id), {})
	if e.is_empty():
		return {}
	var out: Dictionary = (_data.get("defaults", {}) as Dictionary).duplicate(true)
	out.merge(e, true)
	return out


static func variant_count(id: StringName, season: StringName = &"") -> int:
	return _variants(entry(id), season).size()


## Footprint in metres (x by z) after scaling.
static func footprint(id: StringName) -> Vector2:
	var e := entry(id)
	var fp: Array = e.get("footprint", [1, 1])
	return Vector2(float(fp[0]), float(fp[1]))


## True when the art for this id is a stand-in (e.g. wolf, deer, bear until the animals pack).
static func is_placeholder(id: StringName) -> bool:
	return bool(entry(id).get("placeholder", false))


## Scene path for a variant (variant index wraps), or "" if unknown.
static func scene_path(id: StringName, variant: int = 0, season: StringName = &"") -> String:
	var v := _variants(entry(id), season)
	if v.is_empty():
		return ""
	return String(v[posmod(variant, v.size())])


## A ready visual for `id`. Never null; see the class doc.
static func instance(id: StringName, variant: int = 0, season: StringName = &"") -> Node3D:
	var e := entry(id)
	var root := Node3D.new()
	root.name = String(id)
	root.set_meta("asset_id", String(id))
	if e.is_empty():
		push_warning("AssetCatalog: unknown id '%s', using a placeholder" % id)
		root.add_child(_placeholder(id, Vector2.ONE))
		return root
	var path := scene_path(id, variant, season)
	var ps := _scene(path)
	if ps == null:
		push_warning("AssetCatalog: '%s' has no loadable scene (%s), using a placeholder" % [id, path])
		root.add_child(_placeholder(id, footprint(id)))
		return root
	var model := ps.instantiate() as Node3D
	if model == null:
		root.add_child(_placeholder(id, footprint(id)))
		return root
	model.name = "Model"
	var s := float(e.get("scale", 1.0))
	var off: Array = e.get("offset", [0, 0, 0])
	model.basis = Basis(Vector3.UP, deg_to_rad(float(e.get("rotation_y", 0.0)))).scaled(Vector3.ONE * s)
	model.position = Vector3(float(off[0]), float(off[1]), float(off[2]))
	ArtPalette.apply_to_tree(model, float(e.get("pull", 0.3)), Color(String(e.get("tint", "#ffffff"))),
		float(e.get("saturation", 1.0)))
	root.add_child(model)
	return root


## Regrade every catalog material to an era (1..4).
static func set_era(era: int) -> void:
	ArtPalette.apply_era(era)


static func _variants(e: Dictionary, season: StringName) -> Array:
	if e.is_empty():
		return []
	if season != &"":
		var seasons: Dictionary = e.get("seasons", {})
		if seasons.has(String(season)):
			return seasons[String(season)]
	return e.get("variants", [])


static func _scene(path: String) -> PackedScene:
	if path == "":
		return null
	if _scenes.has(path):
		return _scenes[path]
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_scenes[path] = ps
	return ps


static func _placeholder(id: StringName, fp: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Placeholder_%s" % id
	var box := BoxMesh.new()
	var h := clampf(maxf(fp.x, fp.y), 0.5, 3.0)
	box.size = Vector3(maxf(fp.x, 0.3), h, maxf(fp.y, 0.3))
	mi.mesh = box
	mi.position.y = h * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.from_hsv(float(hash(String(id)) % 360) / 360.0, 0.6, 0.9)
	mi.material_override = m
	return mi
