class_name ArtPalette
extends RefCounted
## The shared material library and era palettes (DESIGN 12.1, 12.2, 14.4).
##
## Palette approach: SHADER REMAP, not baked textures. Every imported model keeps its own
## source colours, but at instance time each source material is swapped for a
## ShaderMaterial on the shared hog_flat shader (one cached material per source material +
## pull + tint). The shader pulls each colour toward the nearest swatch of the current era
## palette, applies era saturation and a warm era tint, and lights everything with the same
## soft toon ramp and rim. apply_era() rewrites the era uniforms on every library material,
## so switching era regrades the whole world at once.
##
## Hand-made props (cairn, shrine, flame...) use the named library materials from
## material(), which are the same shader with a fixed albedo.

const SHADER := preload("res://assets/models/materials/hog_flat.gdshader")
const SHADER_2S := preload("res://assets/models/materials/hog_flat_2s.gdshader")
const VILLAGER_SHADER := preload("res://assets/models/materials/villager.gdshader")
const PALETTE_SIZE := 10

## Era palettes. The first four swatches of each era are the DESIGN 12.2 palette; the rest
## are supporting neutrals so greys, woods and greens do not all collapse onto the accents.
const ERAS := {
	1: {
		"name": "Tribe",
		"palette": ["#c8902e", "#6b7f3a", "#3a3633", "#e8803a",   # ochre, moss, charcoal, firelight
			"#8a5a3b", "#e6d5b0", "#8c8578", "#3f5230", "#9e3b26", "#a8b04a"],  # hide, bone, stone, deep moss, red ochre, lichen
		"tint": "#fff3e0", "saturation": 0.92,
	},
	2: {
		"name": "Village",
		"palette": ["#d9b256", "#b5573a", "#7fa9c9", "#ede6d6",   # wheat gold, terracotta, sky blue, white daub
			"#7a5236", "#6f8a3c", "#8f8a80", "#c9a46a", "#46603a", "#a8432e"],
		"tint": "#fff8ec", "saturation": 1.0,
	},
	3: {
		"name": "Town",
		"palette": ["#a0402f", "#5e6670", "#2f8c88", "#3e4fa0",   # brick red, slate grey, sea teal, jewel blue
			"#b8860b", "#7d1f4a", "#e9e3d6", "#6b4a32", "#5d7a3a", "#9a9a92"],
		"tint": "#fffaf3", "saturation": 1.0,
	},
	4: {
		"name": "Launch",
		"palette": ["#8d99a6", "#f2eee6", "#f26b1d", "#1c2a4a",   # steel, warm white, signal orange, night blue
			"#b5b1a8", "#5a6470", "#6a7d45", "#7a5a40", "#d9b256", "#3b4a5e"],
		"tint": "#f8fbff", "saturation": 0.98,
	},
}

## Named library materials for hand-built props: id -> [albedo hex, double sided].
const NAMED := {
	"stone": ["#8c8578", false],
	"stone_dark": ["#5d5852", false],
	"flint": ["#3d4048", false],
	"wood": ["#7a5236", false],
	"wood_dark": ["#4f3726", false],
	"hide": ["#9a6a43", true],
	"bone": ["#e6d5b0", false],
	"ochre": ["#c8902e", false],
	"red_ochre": ["#9e3b26", false],
	"moss": ["#6b7f3a", false],
	"charcoal": ["#2b2826", false],
	"cave_dark": ["#120e0c", false],
	"berry": ["#a3262e", false],
	"dirt": ["#7b6145", false],
	"deer": ["#9b6a3f", false],
	"deer_light": ["#d8c39e", false],
	"wolf": ["#6e6a66", false],
	"wolf_light": ["#b7b0a6", false],
	"antler": ["#d9c9a6", false],
}

static var _era: int = 1
static var _cache: Dictionary = {}       # key -> ShaderMaterial (converted imported materials)
static var _named: Dictionary = {}       # name -> ShaderMaterial
static var _all: Array[ShaderMaterial] = []
static var _registered: Dictionary = {}  # instance id -> true, for materials in _all
static var _flame: Material


static func current_era() -> int:
	return _era


## Regrades every library material to the given era (1..4).
static func apply_era(era: int) -> void:
	_era = clampi(era, 1, 4)
	for m in _all:
		_apply_era_to(m)


## A named library material (see NAMED). Unknown names return a magenta warning material.
static func material(mat_name: String) -> ShaderMaterial:
	if _named.has(mat_name):
		return _named[mat_name]
	var lib_path := "res://assets/models/materials/%s.tres" % mat_name
	if ResourceLoader.exists(lib_path):
		var loaded := load(lib_path) as ShaderMaterial
		if loaded != null:
			register(loaded)
			_named[mat_name] = loaded
			return loaded
	var spec: Array = NAMED.get(mat_name, ["#ff00ff", false])
	var m := _new_material(spec[1])
	m.set_shader_parameter("albedo_color", Color(spec[0]))
	m.set_shader_parameter("palette_pull", 0.0)
	m.resource_name = "hog_" + mat_name
	_named[mat_name] = m
	return m


## Glowing unshaded material for flames and embers.
static func flame_material() -> Material:
	if _flame == null and ResourceLoader.exists("res://assets/models/materials/flame.tres"):
		_flame = load("res://assets/models/materials/flame.tres")
	if _flame == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("#ffb347")
		m.emission_enabled = true
		m.emission = Color("#ff8a2a")
		m.emission_energy_multiplier = 2.0
		m.resource_name = "hog_flame"
		_flame = m
	return _flame


## Converts one source material into its cached palette material.
static func convert_material(src: Material, pull: float = 0.3, tint: Color = Color.WHITE, saturation: float = 1.0) -> Material:
	if src == null:
		return material("stone")
	if src is ShaderMaterial:
		register(src as ShaderMaterial)
		return src
	if (src is BaseMaterial3D and (src as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED):
		return src   # already a library or effect material
	var key := "%d|%.2f|%s|%.2f" % [src.get_instance_id(), pull, tint.to_html(), saturation]
	if _cache.has(key):
		return _cache[key]
	var albedo := Color.WHITE
	var tex: Texture2D = null
	var two_sided := false
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		albedo = b.albedo_color
		tex = b.albedo_texture
		two_sided = b.cull_mode == BaseMaterial3D.CULL_DISABLED
	var m := _new_material(two_sided)
	m.resource_name = "hog_" + src.resource_name
	m.set_shader_parameter("albedo_color", Color(albedo.r * tint.r, albedo.g * tint.g, albedo.b * tint.b, 1.0))
	if tex != null:
		m.set_shader_parameter("albedo_texture", tex)
		m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("palette_pull", pull)
	m.set_shader_parameter("source_saturation", saturation)
	_cache[key] = m
	return m


## Walks a node tree and puts every mesh surface on the shared palette shader.
## Nodes can carry meta "hog_pull" (float), "hog_sat" (float) and "hog_tint" (Color);
## children inherit them.
static func apply_to_tree(node: Node, pull: float = 0.3, tint: Color = Color.WHITE, saturation: float = 1.0) -> void:
	if node.has_meta("hog_sat"):
		saturation = float(node.get_meta("hog_sat"))
	if node.has_meta("hog_pull"):
		pull = float(node.get_meta("hog_pull"))
	if node.has_meta("hog_tint"):
		var t: Color = node.get_meta("hog_tint")
		tint = Color(tint.r * t.r, tint.g * t.g, tint.b * t.b)
	if node is MeshInstance3D and not node.has_meta("hog_keep_materials"):
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var src := mi.get_surface_override_material(i)
				if src == null:
					src = mi.mesh.surface_get_material(i)
				mi.set_surface_override_material(i, convert_material(src, pull, tint, saturation))
	for c in node.get_children():
		apply_to_tree(c, pull, tint, saturation)


static func _new_material(two_sided: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_2S if two_sided else SHADER
	register(m)
	return m


## Adds a hog_flat ShaderMaterial (e.g. a library .tres) to the era-regrade list.
static func register(m: ShaderMaterial) -> void:
	if _registered.has(m.get_instance_id()):
		return
	if m.shader != SHADER and m.shader != SHADER_2S and m.shader != VILLAGER_SHADER:
		return
	_registered[m.get_instance_id()] = true
	_apply_era_to(m)
	_all.append(m)


static func _apply_era_to(m: ShaderMaterial) -> void:
	var e: Dictionary = ERAS[_era]
	var pal := PackedColorArray()
	for hex in e["palette"]:
		pal.append(Color(hex))
	while pal.size() < PALETTE_SIZE:
		pal.append(Color(0, 0, 0, 0))
	if m.shader != VILLAGER_SHADER:
		m.set_shader_parameter("palette", pal)
	m.set_shader_parameter("era_tint", Color(e["tint"]))
	m.set_shader_parameter("era_saturation", e["saturation"])
