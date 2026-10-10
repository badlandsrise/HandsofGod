class_name VillagerVisual
extends Node3D
## The look of one villager: a rigged Quaternius base body with hair, Era 1 hide clothing
## drawn by the villager shader, and the baked villager animation library.
## Scene: res://scenes/people/villager_visual.tscn  (or AssetCatalog.instance(&"villager")).
##
## API (keep it small; the Person scene drives it):
##   play(state: StringName, blend := 0.2)
##       idle, walk, run, carry, work, sit, wave, cheer, cower, held, fall, dead
##       (extras: flee, chop, pickup, talk, dance). Unknown states fall back to idle.
##       dead and pickup play once and hold their last frame; the rest loop.
##   set_look(skin: Color, hair: Color, cloth: Color, outfit_variant: int)
##       outfit_variant picks body, hair style and clothing cut (wraps, see OUTFITS):
##       even = male body, odd = female body.
##   set_age_scale(stage: int)
##       Person.Stage: 0 BABY, 1 CHILD, 2 ADULT, 3 ELDER. Smaller bodies get a bigger head.
##   set_tint(c: Color)   multiplies the whole figure (e.g. dim at night, red when hurt).
##   current_state() -> StringName
##
## An adult stands about 1.7 m, origin at the feet, facing +Z.

const BODIES := [
	"res://assets/models/characters/Superhero_Male_FullBody.gltf",
	"res://assets/models/characters/Superhero_Female_FullBody.gltf",
]
const HAIR_DIR := "res://assets/models/characters/"
const ANIMS := preload("res://assets/models/characters/anims/villager_anims.res")
const MAT_BODY := preload("res://assets/models/materials/villager_body.tres")
const MAT_HAIR := preload("res://assets/models/materials/villager_hair.tres")
const MAT_EYES := preload("res://assets/models/materials/villager_eyes.tres")

## [body, hair pieces, outfit cut (hem, neckline, sleeve reach, belt)]
## Cut heights are fractions of the body's height; sleeve reach 0.26 = sleeveless.
const OUTFITS := [
	[0, ["Hair_SimpleParted", "Eyebrows_Regular"], Vector4(0.36, 0.80, 0.34, 0.53)],            # tunic, short sleeves
	[1, ["Hair_Long", "Eyebrows_Female"], Vector4(0.10, 0.80, 0.30, 0.56)],                     # long dress
	[0, ["Hair_Buzzed", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.40, 0.66, 0.20, 0.53)],   # hide kilt and chest wrap
	[1, ["Hair_Buns", "Eyebrows_Female"], Vector4(0.35, 0.80, 0.26, 0.55)],                     # sleeveless tunic
	[0, ["Hair_Long", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.08, 0.81, 0.40, 0.55)],     # long robe
	[1, ["Hair_BuzzedFemale", "Eyebrows_Female"], Vector4(0.40, 0.80, 0.30, 0.56)],             # short tunic
	[0, ["Hair_Beard", "Eyebrows_Regular"], Vector4(0.30, 0.80, 0.26, 0.53)],                   # bald, long tunic
	[1, ["Hair_SimpleParted", "Eyebrows_Female"], Vector4(0.22, 0.79, 0.34, 0.56)],             # mid dress
]
const ONE_SHOT := [&"dead", &"pickup"]
const ADULT_HEIGHT := 1.7
## [overall scale, head scale] per Person.Stage
const AGE := [Vector2(0.36, 1.6), Vector2(0.62, 1.38), Vector2(1.0, 1.16), Vector2(0.97, 1.16)]

var _anim: AnimationPlayer
var _model: Node3D
var _skeleton: Skeleton3D
var _state: StringName = &"idle"
var _skin := Color("#c99a72")
var _hair := Color("#3b2a1e")
var _cloth := Color("#8a5a3b")
var _tint := Color.WHITE
var _outfit: int = 0
var _stage: int = 2
var _body_index: int = -1


func _ready() -> void:
	_anim = get_node_or_null("AnimationPlayer")
	if _anim == null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		add_child(_anim)
	if not _anim.has_animation_library(&""):
		_anim.add_animation_library(&"", ANIMS)
	_anim.animation_finished.connect(_on_finished)
	for m in [MAT_BODY, MAT_HAIR, MAT_EYES]:
		ArtPalette.register(m)   # era regrades reach villagers too
	_build()
	play(_state, 0.0)


## Play a state (see the API above). blend is the cross-fade time in seconds.
func play(state: StringName, blend: float = 0.2) -> void:
	if not is_node_ready():
		_state = state
		return
	var s := state if _anim.has_animation(state) else &"idle"
	if s == _state and _anim.is_playing() and _anim.current_animation == s:
		return
	_state = s
	_anim.play(s, blend)
	_apply_arms()


func current_state() -> StringName:
	return _state


## Colours are used as given (sRGB); cloth is the main garment colour.
func set_look(skin: Color, hair: Color, cloth: Color, outfit_variant: int) -> void:
	_skin = skin
	_hair = hair
	_cloth = cloth
	_outfit = posmod(outfit_variant, OUTFITS.size())
	if is_node_ready():
		_build()


func set_age_scale(stage: int) -> void:
	_stage = clampi(stage, 0, AGE.size() - 1)
	if is_node_ready():
		_apply_age()


func set_tint(c: Color) -> void:
	_tint = c
	if is_node_ready():
		_apply_colors()


# ------------------------------------------------------------------ internals

func _build() -> void:
	var o: Array = OUTFITS[_outfit]
	var body: int = o[0]
	if body != _body_index or _model == null:
		if _model:
			_model.free()
		_model = (load(BODIES[body]) as PackedScene).instantiate() as Node3D
		_model.name = "Model"
		add_child(_model)
		move_child(_model, 0)
		_skeleton = _model.get_node("Armature/Skeleton3D") as Skeleton3D
		var mod := VillagerPoseModifier.new()
		mod.name = "PoseModifier"
		_skeleton.add_child(mod)
		_body_index = body
		_anim.root_node = _anim.get_path_to(_model)
	# hair: remove old pieces, attach the outfit's pieces to our skeleton
	for c in _skeleton.get_children():
		if c.has_meta("hair_piece"):
			c.free()
	for piece in o[1]:
		_attach_hair(String(piece))
	for c in _skeleton.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if c.has_meta("hair_piece") or String(c.name) == "Eyebrows":
				mi.material_override = MAT_HAIR
			elif String(c.name) == "Eyes":
				mi.material_override = MAT_EYES
			else:
				mi.material_override = MAT_BODY
			mi.set_instance_shader_parameter(&"outfit_cut", o[2])
	_apply_colors()
	_apply_age()
	if _anim.has_animation(_state):
		_anim.play(_state, 0.0)
	_apply_arms()


func _attach_hair(piece: String) -> void:
	var ps := load(HAIR_DIR + piece + ".gltf") as PackedScene
	if ps == null:
		return
	var tmp := ps.instantiate()
	for mi in tmp.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.get_parent().remove_child(m)
		m.owner = null
		m.name = piece
		m.set_meta("hair_piece", true)
		_skeleton.add_child(m)
		m.skeleton = NodePath("..")
	tmp.free()


func _apply_colors() -> void:
	if _skeleton == null:
		return
	for c in _skeleton.get_children():
		if c is GeometryInstance3D:
			var g := c as GeometryInstance3D
			g.set_instance_shader_parameter(&"skin_color", _skin)
			g.set_instance_shader_parameter(&"hair_color", _hair)
			g.set_instance_shader_parameter(&"cloth_color", _cloth)
			g.set_instance_shader_parameter(&"instance_tint", _tint)


func _apply_age() -> void:
	if _model == null:
		return
	var a: Vector2 = AGE[_stage]
	var body_h := 1.81 if _body_index == 0 else 1.77
	_model.scale = Vector3.ONE * (ADULT_HEIGHT / body_h) * a.x / (1.0 + (a.y - 1.0) * 0.12)
	var mod := _skeleton.get_node_or_null("PoseModifier") as VillagerPoseModifier
	if mod:
		mod.head_scale = a.y
		mod.stoop = 0.22 if _stage == 3 else 0.0


func _apply_arms() -> void:
	if _skeleton == null:
		return
	var mod := _skeleton.get_node_or_null("PoseModifier") as VillagerPoseModifier
	if mod == null:
		return
	match _state:
		&"wave": mod.arms = VillagerPoseModifier.Arms.WAVE
		&"cheer": mod.arms = VillagerPoseModifier.Arms.CHEER
		&"cower": mod.arms = VillagerPoseModifier.Arms.COVER_HEAD
		_: mod.arms = VillagerPoseModifier.Arms.NONE


func _on_finished(anim_name: StringName) -> void:
	if anim_name in ONE_SHOT:
		return   # hold the last frame
