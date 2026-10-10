class_name GroundLook extends RefCounted
## Which ground look the terrain shader uses (scenes/world/shaders/terrain.gdshader):
##   procedural  painterly noise only (no textures)
##   stylised    CC0 hand-painted tiles (OpenGameArt), tinted toward the palette
##   photo       CC0 photo PBR (ambientCG, Poly Haven), posterised, softened and tinted
## Pick with the project setting "hands_of_god/ground_look", or "--ground=<look>" on the
## command line; DEFAULT otherwise.

const DEFAULT := &"procedural"
const LOOKS := [&"procedural", &"stylised", &"photo"]
const LAYERS := ["grass", "dirt", "rock", "mud", "forest"]
const DIR := "res://assets/textures/ground/%s/%s_%s.%s"

## look -> shader parameters on top of the texture slots
const PARAMS := {
	&"procedural": {},
	&"stylised": {"tex_tiling": Vector4(0.22, 0.3, 0.12, 0.3), "forest_tiling": 0.25, "posterize_steps": 0.0,
		"detail_softness": 0.5, "palette_tint": 0.7, "normal_strength": 0.5},
	&"photo": {"tex_tiling": Vector4(0.2, 0.25, 0.1, 0.25), "forest_tiling": 0.22, "posterize_steps": 10.0,
		"detail_softness": 1.6, "palette_tint": 0.8, "normal_strength": 0.45},
}

static func current() -> StringName:
	if Game.flags.has("ground"):
		var g := StringName(str(Game.flags["ground"]))
		if g in LOOKS:
			return g
	var s := StringName(str(ProjectSettings.get_setting("hands_of_god/ground_look", DEFAULT)))
	return s if s in LOOKS else DEFAULT

static func apply(mat: ShaderMaterial, look: StringName) -> void:
	for layer in LAYERS:
		mat.set_shader_parameter("use_%s_tex" % layer, false)
	if look == &"procedural":
		return
	var folder := "stylised" if look == &"stylised" else "photo"
	var ext := "png" if look == &"stylised" else "jpg"
	for layer in LAYERS:
		var alb := DIR % [folder, layer, "albedo", ext]
		if not ResourceLoader.exists(alb):
			continue
		mat.set_shader_parameter("%s_albedo" % layer, load(alb))
		var nrm := DIR % [folder, layer, "normal", ext]
		if ResourceLoader.exists(nrm):
			mat.set_shader_parameter("%s_normal" % layer, load(nrm))
		mat.set_shader_parameter("use_%s_tex" % layer, true)
	var p: Dictionary = PARAMS.get(look, {})
	for k in p:
		mat.set_shader_parameter(k, p[k])
