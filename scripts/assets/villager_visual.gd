class_name VillagerVisual
extends Node3D
## The look of one villager: a rigged Quaternius base body with hair, Era 1 hide clothing
## drawn by the villager shader, and the baked villager animation library.
## Scene: res://scenes/people/villager_visual.tscn  (or AssetCatalog.instance(&"villager")).
##
## API (keep it small; the Person scene drives it):
##   play(state: StringName, blend := 0.2)
##       idle, walk, run, carry, work, sit, wave, cheer, cower, held, fall, dead
##       (extras: flee, chop, pickup, talk, dance, and every task clip in
##       TaskAnims.TASK_CLIPS: pick, knap, tend, pray, hammer, ...). Unknown states fall
##       back to idle. dead and pickup play once and hold their last frame; the rest loop.
##       The hands take the clip's own props (TaskAnims.CLIP_PROPS: an axe for chop, ...).
##       sit and sit_talk put a seat under the villager (a log or rock in Era 1, a stool
##       later) unless set_seat_provided(true) says the world has one there.
##       Walking and running clips play at the speed the villager really moves (measured
##       from its own motion) so the feet do not slide.
##   play_task(clip: StringName, right := DEFAULT, left := DEFAULT, blend := 0.2)
##       play() with chosen props (PropKit ids, &"" = empty hand).
##   hold_cargo(kind: StringName)
##       an armful of a resource kind (PropKit.CARGO: berries, wood, stone, meat, ...),
##       shown between the hands while a carry clip plays; &"" clears it.
##   set_seat_provided(on: bool)
##   set_look(skin: Color, hair: Color, cloth: Color, outfit_variant: int)
##       outfit_variant picks body, hair style and clothing cut (wraps, see OUTFITS):
##       even = male body, odd = female body.
##   set_era(era: int)
##       picks the tailoring: 1 = hides (OUTFITS), 2 = woven clothes (OUTFITS_ERA2:
##       linen undershirt, hose or long skirt, trim bands, aprons, straw hats, coifs),
##       3 = town clothes (OUTFITS_ERA3: coats, waistcoats, breeches and stockings,
##       bodices and full skirts, tricorns, felt hats, bonnets, mob caps, flat caps),
##       4+ = the clothes of their trade (OUTFITS_ERA4: overalls, lab coats, suits and
##       dresses; hard hats, trilbies, pillbox hats, kerchiefs).
##       Until called, the villager follows ArtPalette.current_era() when it is built.
##   set_crew(on: bool)
##       the rocket's crew: a white flight suit with navy boots and gloves, orange bands,
##       the mission patch and an open-face helmet (CREW_SUITS, by body), whatever the era.
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
## Era 2: [body, hair pieces, cut, style (1, hose/long skirt, apron, undershirt sleeve
## reach), trim colour, hat]. Same body parity as OUTFITS so a save keeps its sex.
## The main garment keeps the job colour Person passes in; trim and hat add variety.
const OUTFITS_ERA2 := [
	[0, ["Hair_SimpleParted", "Eyebrows_Regular"], Vector4(0.34, 0.79, 0.36, 0.53), Vector4(1, 1, 0, 0.72), "#a8432e", &"straw_hat"],   # tunic, hose, straw hat
	[1, ["Hair_Buns", "Eyebrows_Female"], Vector4(0.06, 0.79, 0.34, 0.57), Vector4(1, 0, 1, 0.72), "#5c84a6", &"coif"],               # long dress, apron, coif
	[0, ["Hair_Buzzed", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.36, 0.78, 0.30, 0.53), Vector4(1, 1, 1, 0.6), "#7a4a2c", &""],   # short tunic, work apron
	[1, ["Hair_Long", "Eyebrows_Female"], Vector4(0.12, 0.79, 0.36, 0.57), Vector4(1, 0, 0, 0.72), "#d0a040", &""],                    # mid dress
	[0, ["Hair_Long", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.06, 0.80, 0.42, 0.55), Vector4(1, 0, 0, 0.72), "#d0a040", &""],     # long robe, gold trim
	[1, ["Hair_BuzzedFemale", "Eyebrows_Female"], Vector4(0.10, 0.79, 0.30, 0.57), Vector4(1, 0, 1, 0.72), "#6f8a3c", &"straw_hat"], # skirt, apron, straw hat
	[0, ["Hair_Beard", "Eyebrows_Regular"], Vector4(0.30, 0.79, 0.34, 0.53), Vector4(1, 1, 0, 0.72), "#5c84a6", &"cap"],              # long tunic, hose, felt cap
	[1, ["Hair_SimpleParted", "Eyebrows_Female"], Vector4(0.08, 0.79, 0.34, 0.57), Vector4(1, 0, 0, 0.72), "#a8432e", &"scarf"],     # dress, headscarf
]
## Era 3 (Town): same layout as OUTFITS_ERA2; style.x = 2 selects the shader's town
## tailoring (style.y = 1 men's coat and breeches, z = 1 waistcoat / stomacher, z = 2 apron,
## w = chemise sleeve reach). The main garment keeps the job colour; trim is the waistcoat,
## stomacher, cuffs and hem band.
const OUTFITS_ERA3 := [
	[0, ["Hair_SimpleParted", "Eyebrows_Regular"], Vector4(0.30, 0.79, 0.64, 0.53), Vector4(2, 1, 1, 0.72), "#d4a13a", &"tricorn"],      # knee coat, gold waistcoat, tricorn
	[1, ["Hair_Buns", "Eyebrows_Female"], Vector4(0.06, 0.78, 0.36, 0.56), Vector4(2, 0, 1, 0.52), "#e9e3d6", &"bonnet"],               # bodice, laced stomacher, bonnet
	[0, ["Hair_Buzzed", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.44, 0.78, 0.62, 0.53), Vector4(2, 1, 2, 0.72), "#6b4a32", &"flat_cap"], # work jacket, leather apron, flat cap
	[1, ["Hair_Long", "Eyebrows_Female"], Vector4(0.06, 0.79, 0.40, 0.56), Vector4(2, 0, 2, 0.6), "#2f8c88", &"mob_cap"],                # dress, white apron, mob cap
	[0, ["Hair_Long", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.08, 0.80, 0.68, 0.55), Vector4(2, 0, 0, 0.72), "#7d1f4a", &"felt_hat"], # scholar's gown, felt hat
	[1, ["Hair_BuzzedFemale", "Eyebrows_Female"], Vector4(0.06, 0.79, 0.62, 0.56), Vector4(2, 0, 1, 0.72), "#d4a13a", &"felt_hat"],      # riding jacket and skirt, felt hat
	[0, ["Hair_Beard", "Eyebrows_Regular"], Vector4(0.32, 0.79, 0.64, 0.53), Vector4(2, 1, 1, 0.72), "#3e4fa0", &""],                    # coat, blue waistcoat, bare head
	[1, ["Hair_SimpleParted", "Eyebrows_Female"], Vector4(0.06, 0.79, 0.34, 0.56), Vector4(2, 0, 0, 0.5), "#7d1f4a", &""],               # gown with a plum hem band
]
## Era 4 (Launch): same layout; style.x = 3 selects the shader's Era 4 tailoring:
## style.y = 0 overalls (w = shirt sleeve reach), 1 lab coat, 2 day clothes (z = 1 men's
## suit, z = 0 dress), 3 flight suit. The job colour is the overalls, the shirt under the
## lab coat, the suit or the dress; trim is the tie, pockets, belt and shoes.
const OUTFITS_ERA4 := [
	[0, ["Hair_SimpleParted", "Eyebrows_Regular"], Vector4(0.06, 0.79, 0.5, 0.53), Vector4(3, 0, 0, 0.5), "#c8442e", &"hard_hat"],      # overalls, hard hat
	[1, ["Hair_Buns", "Eyebrows_Female"], Vector4(0.3, 0.79, 0.64, 0.56), Vector4(3, 1, 0, 0.72), "#f26b1d", &""],                     # lab coat
	[0, ["Hair_Buzzed", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.3, 0.79, 0.64, 0.53), Vector4(3, 1, 0, 0.72), "#1c2a4a", &""],   # lab coat, navy tie
	[1, ["Hair_Long", "Eyebrows_Female"], Vector4(0.24, 0.79, 0.34, 0.56), Vector4(3, 2, 0, 0.72), "#c8442e", &"pillbox"],              # dress, red belt and shoes, pillbox
	[0, ["Hair_Long", "Hair_Beard", "Eyebrows_Regular"], Vector4(0.47, 0.79, 0.64, 0.53), Vector4(3, 2, 1, 0.72), "#c8442e", &"trilby"],  # suit and tie, trilby
	[1, ["Hair_BuzzedFemale", "Eyebrows_Female"], Vector4(0.06, 0.79, 0.5, 0.56), Vector4(3, 0, 0, 0.48), "#f2eee6", &"kerchief"],     # overalls, kerchief
	[0, ["Hair_Beard", "Eyebrows_Regular"], Vector4(0.06, 0.79, 0.5, 0.53), Vector4(3, 0, 0, 0.55), "#e0a526", &"flat_cap"],           # overalls, flat cap
	[1, ["Hair_SimpleParted", "Eyebrows_Female"], Vector4(0.24, 0.79, 0.3, 0.56), Vector4(3, 2, 0, 0.72), "#1c2a4a", &""],              # dress, navy belt
]
## The crew's flight suits, [male, female]: style.y = 3, trim = the orange bands.
const CREW_SUITS := [
	[0, ["Hair_Buzzed", "Eyebrows_Regular"], Vector4(0.06, 0.8, 0.62, 0.53), Vector4(3, 3, 0, 0.72), "#f26b1d", &"helmet"],
	[1, ["Hair_Buns", "Eyebrows_Female"], Vector4(0.06, 0.8, 0.62, 0.56), Vector4(3, 3, 0, 0.72), "#f26b1d", &"helmet"],
]
const UNDER_LINEN := Color("#e8dcc0")
const UNDER_TOWN := Color("#f3efe6")
const UNDER_SHIRT := Color("#e9eef2")
## hat colours (they use the hair material, so tint and era grading apply)
const HAT_COLOURS := {&"straw_hat": Color("#d2a75e"), &"coif": Color("#efe6d2"), &"cap": Color("#6a4a32"), &"scarf": Color("#c9b48a"),
	&"tricorn": Color("#2c2a33"), &"felt_hat": Color("#3d3440"), &"bonnet": Color("#e4d3a8"), &"mob_cap": Color("#f4efe4"),
	&"flat_cap": Color("#4a5f78"), &"hard_hat": Color("#f26b1d"), &"trilby": Color("#4a4440"), &"pillbox": Color("#2f8c88"),
	&"kerchief": Color("#c8442e"), &"helmet": Color("#f2f1ec")}
const ONE_SHOT := [&"dead", &"pickup"]
## play_task(): keep the clip's own prop for that hand
const DEFAULT := &"_"
## Clips the armful (hold_cargo) shows in.
const CARRY_CLIPS := [&"carry", &"carry_walk"]
## Clips that sit on a seat (baby_sit sits on the ground).
const SEAT_CLIPS := [&"sit", &"sit_talk"]
## Where the seat goes under a sitting adult, in the model's own units (1.81 m body).
const SEAT_AT := Vector3(0, 0, -0.27)
## Playback-rate limits when matching a walk to the ground speed.
const RATE_MIN := 0.45
const RATE_MAX := 3.4
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
var _era: int = -1   # -1 = follow ArtPalette.current_era() at build time
var _crew := false
var _props := [&"", &""]          # PropKit ids in the right and left hand
var _cargo_kind: StringName = &""
var _cargo: Node3D
var _seat: Node3D
var _seat_provided := false
var _last_pos := Vector3.INF
var _speed := 0.0               # smoothed ground speed (m/s), measured
var _grip_frames := {}          # "r"/"l" -> [grip Transform3D, palm Transform3D] in hand-bone space


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
	play_task(state, DEFAULT, DEFAULT, blend)


## Play a clip with these props in the hands (PropKit ids; DEFAULT = the clip's own,
## &"" = empty).
func play_task(clip: StringName, right: StringName = DEFAULT, left: StringName = DEFAULT, blend: float = 0.2) -> void:
	var defaults: Array = TaskAnims.CLIP_PROPS.get(clip, [&"", &""])
	var r: StringName = defaults[0] if right == DEFAULT else right
	var l: StringName = defaults[1] if left == DEFAULT else left
	if not is_node_ready():
		_state = clip
		_props = [r, l]
		return
	var s := clip if _anim.has_animation(clip) else &"idle"
	if s != _state or not _anim.is_playing() or _anim.current_animation != s:
		_state = s
		_anim.play(s, blend)
		if not _anim.get_animation(s).has_meta(&"ground_speed"):
			_anim.speed_scale = 1.0
		_apply_arms()
	_set_props(r, l)
	_update_seat()
	_update_cargo_visible()


## An armful of a resource kind, shown while a carry clip plays (&"" = nothing).
func hold_cargo(kind: StringName) -> void:
	if kind == _cargo_kind:
		return
	_cargo_kind = kind
	if _cargo:
		remove_child(_cargo)   # out now, so the new armful takes the name "Cargo"
		_cargo.queue_free()
		_cargo = null
	if kind != &"" and is_node_ready():
		_cargo = PropKit.make(PropKit.cargo_id(kind))
		_cargo.name = "Cargo"
		add_child(_cargo)
		_place_cargo()
	_update_cargo_visible()


func cargo_kind() -> StringName:
	return _cargo_kind


## The PropKit ids in the hands now: [right, left].
func held_props() -> Array:
	return _props.duplicate()


## True when the world already puts a seat (bench, log, stool) under this villager, so
## sitting adds none of its own.
func set_seat_provided(on: bool) -> void:
	_seat_provided = on
	if is_node_ready():
		_update_seat()


func has_seat() -> bool:
	return _seat != null and _seat.visible


## The top of a shoulder in world space (side &"r" or &"l"), where a carried log rests.
func shoulder_point(side: StringName = &"r") -> Vector3:
	if _skeleton == null:
		return global_position + Vector3(0, 1.45, 0)
	var bi := _skeleton.find_bone("upperarm_" + String(side))
	if bi < 0:
		return global_position + Vector3(0, 1.45, 0)
	var size := _model.global_basis.x.length()
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bi).origin + Vector3(0, 0.075 * size, 0)


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


## 1 = Era 1 hides, 2 = Era 2 woven clothes, 3 = Era 3 town clothes, 4 or later = Era 4.
func set_era(era: int) -> void:
	_era = era
	if is_node_ready():
		_build()


## Dress this villager as one of the rocket's crew (true) or back in their own clothes.
func set_crew(on: bool) -> void:
	_crew = on
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

func _tailoring() -> int:
	return clampi(_era if _era >= 0 else ArtPalette.current_era(), 1, 4)


func _build() -> void:
	var era := _tailoring()
	var woven := era >= 2 or _crew
	var o: Array = [OUTFITS, OUTFITS_ERA2, OUTFITS_ERA3, OUTFITS_ERA4][era - 1][_outfit]
	if _crew:
		o = CREW_SUITS[_outfit % 2]
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
			mi.set_instance_shader_parameter(&"outfit_style", o[3] if woven else Vector4(0, 0, 0, 0.72))
			if woven:
				mi.set_instance_shader_parameter(&"trim_color", Color(o[4]))
				mi.set_instance_shader_parameter(&"under_color", UNDER_SHIRT if era >= 4 or _crew else (UNDER_TOWN if era >= 3 else UNDER_LINEN))
	_build_hat(o[5] if woven else &"")
	_apply_colors()
	_apply_age()
	if _anim.has_animation(_state):
		_anim.play(_state, 0.0)
	_apply_arms()
	_grip_frames.clear()
	_rebuild_props()
	_update_seat(true)
	if not _skeleton.skeleton_updated.is_connected(_place_cargo):
		_skeleton.skeleton_updated.connect(_place_cargo)


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


## Hats ride a BoneAttachment3D on the head bone, so they follow the head through every
## animation and the PoseModifier's head scaling. Built from primitives; the hair
## material colours them (hair_color = hat colour) so tint and era grading apply.
func _build_hat(kind: StringName) -> void:
	var old := _skeleton.get_node_or_null("Hat")
	if old:
		old.free()
	if kind == &"":
		return
	var att := BoneAttachment3D.new()
	att.name = "Hat"
	att.bone_name = "Head"
	_skeleton.add_child(att)
	var top := 0.215   # crown of the head above the head bone (both bodies)
	var parts: Array = []   # [mesh, position, rotation_degrees, scale, colour factor]
	match kind:
		&"straw_hat":
			parts.append([_cyl_mesh(0.215, 0.205, 0.018, 20), Vector3(0, top - 0.055, 0.0), Vector3(-4, 0, 0), Vector3.ONE, 1.0])
			parts.append([_cyl_mesh(0.082, 0.112, 0.095, 16), Vector3(0, top - 0.005, -0.005), Vector3(-4, 0, 0), Vector3.ONE, 1.0])
			parts.append([_cyl_mesh(0.113, 0.114, 0.022, 16), Vector3(0, top - 0.04, -0.004), Vector3(-4, 0, 0), Vector3.ONE, 0.42])
		&"coif":
			parts.append([_dome_mesh(0.118), Vector3(0, top - 0.115, -0.022), Vector3(-14, 0, 0), Vector3(1.0, 1.12, 1.08), 1.0])
		&"cap":
			parts.append([_dome_mesh(0.112), Vector3(0, top - 0.085, -0.012), Vector3(-10, 0, 0), Vector3(1.0, 0.95, 1.05), 1.0])
			parts.append([_cyl_mesh(0.117, 0.117, 0.03, 18), Vector3(0, top - 0.08, -0.012), Vector3(-10, 0, 0), Vector3.ONE, 0.7])
		&"scarf":
			parts.append([_dome_mesh(0.12), Vector3(0, top - 0.11, -0.026), Vector3(-20, 0, 0), Vector3(1.02, 1.1, 1.08), 1.0])
			parts.append([_ball_mesh(0.045), Vector3(0, top - 0.17, -0.13), Vector3.ZERO, Vector3(1.2, 0.8, 0.9), 0.9])
		&"tricorn":
			# a low crown, the brim cocked up into three walls (front point over the face)
			parts.append([_cyl_mesh(0.098, 0.112, 0.07, 16), Vector3(0, top - 0.03, -0.01), Vector3(-6, 0, 0), Vector3.ONE, 1.0])
			for k in 3:
				var a := TAU * k / 3.0 + PI / 3.0
				var dir := Vector3(sin(a), 0, cos(a))
				parts.append([_box_mesh(Vector3(0.21, 0.085, 0.018)), Vector3(0, top - 0.035, -0.01) + dir * 0.12,
					Vector3(14, rad_to_deg(a), 0), Vector3.ONE, 1.0])
				parts.append([_box_mesh(Vector3(0.21, 0.012, 0.022)), Vector3(0, top + 0.008, -0.01) + dir * 0.137,
					Vector3(14, rad_to_deg(a), 0), Vector3.ONE, Color("#c9a043")])   # gilt edge
		&"felt_hat":
			parts.append([_cyl_mesh(0.225, 0.215, 0.016, 22), Vector3(0, top - 0.055, -0.005), Vector3(-6, 0, 0), Vector3.ONE, 1.0])
			parts.append([_cyl_mesh(0.085, 0.108, 0.16, 16), Vector3(0, top + 0.025, -0.012), Vector3(-6, 0, 0), Vector3.ONE, 1.0])
			parts.append([_cyl_mesh(0.105, 0.108, 0.028, 16), Vector3(0, top - 0.03, -0.01), Vector3(-6, 0, 0), Vector3.ONE, Color("#7d1f4a")])  # band
		&"bonnet":
			parts.append([_dome_mesh(0.122), Vector3(0, top - 0.11, -0.03), Vector3(-24, 0, 0), Vector3(1.03, 1.1, 1.1), 1.0])
			parts.append([_cyl_mesh(0.165, 0.15, 0.03, 20), Vector3(0, top - 0.06, 0.035), Vector3(-62, 0, 0), Vector3(1.0, 1.0, 1.15), 0.92])
		&"mob_cap":
			parts.append([_ball_mesh(0.12), Vector3(0, top - 0.06, -0.025), Vector3(-12, 0, 0), Vector3(1.05, 0.62, 1.1), 1.0])
			parts.append([_cyl_mesh(0.142, 0.15, 0.018, 20), Vector3(0, top - 0.09, -0.02), Vector3(-12, 0, 0), Vector3.ONE, 0.97])
			parts.append([_cyl_mesh(0.123, 0.124, 0.02, 18), Vector3(0, top - 0.075, -0.02), Vector3(-12, 0, 0), Vector3.ONE, Color("#2f8c88")])  # ribbon
		&"flat_cap":
			parts.append([_ball_mesh(0.13), Vector3(0.012, top - 0.035, 0.0), Vector3(-8, 0, -6), Vector3(1.08, 0.32, 1.12), 1.0])
			parts.append([_cyl_mesh(0.112, 0.114, 0.035, 18), Vector3(0, top - 0.06, -0.008), Vector3(-8, 0, 0), Vector3.ONE, 0.8])
			parts.append([_cyl_mesh(0.07, 0.075, 0.012, 12), Vector3(0, top - 0.06, 0.11), Vector3(-14, 0, 0), Vector3(1.0, 1.0, 0.7), 0.7])  # peak
		&"hard_hat":
			# a domed safety helmet with a ridge and a short peak
			parts.append([_dome_mesh(0.128), Vector3(0, top - 0.075, -0.008), Vector3(-6, 0, 0), Vector3(1.0, 1.02, 1.08), 1.0])
			parts.append([_cyl_mesh(0.146, 0.15, 0.014, 20), Vector3(0, top - 0.075, 0.004), Vector3(-6, 0, 0), Vector3(1.0, 1.0, 1.12), 0.9])
			parts.append([_box_mesh(Vector3(0.026, 0.02, 0.24)), Vector3(0, top + 0.05, -0.012), Vector3(-6, 0, 0), Vector3.ONE, 0.88])
		&"trilby":
			parts.append([_cyl_mesh(0.17, 0.165, 0.014, 22), Vector3(0, top - 0.05, -0.005), Vector3(-5, 0, 0), Vector3(1.0, 1.0, 1.06), 1.0])
			parts.append([_cyl_mesh(0.085, 0.105, 0.105, 16), Vector3(0, top + 0.005, -0.01), Vector3(-5, 0, 0), Vector3(1.0, 1.0, 1.1), 1.0])
			parts.append([_cyl_mesh(0.104, 0.106, 0.026, 16), Vector3(0, top - 0.03, -0.01), Vector3(-5, 0, 0), Vector3(1.0, 1.0, 1.1), Color("#1c2a4a")])  # band
		&"pillbox":
			parts.append([_cyl_mesh(0.07, 0.075, 0.05, 18), Vector3(0.0, top - 0.005, -0.03), Vector3(-18, 0, 8), Vector3.ONE, 1.0])
		&"kerchief":
			parts.append([_dome_mesh(0.122), Vector3(0, top - 0.1, -0.02), Vector3(-16, 0, 0), Vector3(1.03, 1.0, 1.08), 1.0])
			parts.append([_ball_mesh(0.035), Vector3(0, top - 0.01, 0.1), Vector3.ZERO, Vector3(1.6, 0.8, 0.9), 0.85])   # the knot on top
		&"helmet":
			# open-face flight helmet: a white shell round the back of the head, an orange
			# crest stripe, the gold visor raised over the brow, a chrome neck ring below
			parts.append([_dome_mesh(0.165), Vector3(0, top - 0.115, -0.03), Vector3(-28, 0, 0), Vector3(1.0, 1.25, 1.05), 1.0])
			parts.append([_box_mesh(Vector3(0.04, 0.012, 0.3)), Vector3(0, top + 0.02, -0.03), Vector3(-10, 0, 0), Vector3.ONE, Color("#f26b1d")])
			parts.append([_dome_mesh(0.16), Vector3(0, top - 0.06, 0.035), Vector3(-75, 0, 0), Vector3(1.02, 0.35, 1.0), Color("#d9a441")])
			parts.append([_cyl_mesh(0.14, 0.14, 0.035, 20), Vector3(0, -0.07, -0.01), Vector3.ZERO, Vector3.ONE, Color("#b8bec6")])
	var col: Color = HAT_COLOURS.get(kind, Color("#c9a582"))
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.position = p[1]
		mi.rotation_degrees = p[2]
		mi.scale = p[3]
		mi.material_override = MAT_HAIR
		# p[4]: a shade factor on the hat colour, or a Color of its own (gilt edges, bands)
		mi.set_meta("hat_shade", float(p[4]) if not p[4] is Color else 1.0)
		mi.set_meta("hat_colour", p[4] if p[4] is Color else col)
		att.add_child(mi)


func _cyl_mesh(top_r: float, bottom_r: float, h: float, seg: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _dome_mesh(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	m.radial_segments = 18
	m.rings = 6
	return m


func _ball_mesh(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


func _apply_colors() -> void:
	if _skeleton == null:
		return
	var hat := _skeleton.get_node_or_null("Hat")
	if hat:
		for c in hat.get_children():
			var g := c as GeometryInstance3D
			var hc: Color = g.get_meta("hat_colour", Color.WHITE)
			var f: float = g.get_meta("hat_shade", 1.0)
			g.set_instance_shader_parameter(&"hair_color", Color(hc.r * f, hc.g * f, hc.b * f))
			g.set_instance_shader_parameter(&"instance_tint", _tint)
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
	if _seat:
		_update_seat()


func _apply_arms() -> void:
	if _skeleton == null:
		return
	var mod := _skeleton.get_node_or_null("PoseModifier") as VillagerPoseModifier
	if mod == null:
		return
	match _state:
		&"wave": mod.arms = VillagerPoseModifier.Arms.WAVE
		&"cower": mod.arms = VillagerPoseModifier.Arms.COVER_HEAD
		_: mod.arms = VillagerPoseModifier.Arms.NONE   # cheer's arms are baked into the clip


func _on_finished(anim_name: StringName) -> void:
	if anim_name in ONE_SHOT:
		return   # hold the last frame


# ------------------------------------------------------------------ ground speed

## Walking and running clips play at the villager's real speed: each carries the ground
## speed it was authored for (meta "ground_speed", on the 1.81 m body) and the rate is
## the measured speed over that, scaled to this figure's size.
func _process(delta: float) -> void:
	if _model == null or delta <= 0.0:
		return
	var p := global_position
	var v := 0.0
	if _last_pos != Vector3.INF:
		var d := p - _last_pos
		d.y = 0.0
		v = d.length() / delta
	_last_pos = p
	if v > 25.0:
		v = _speed   # a teleport, not a step
	_speed = lerpf(_speed, v, minf(delta * 8.0, 1.0))
	var a := _anim.get_animation(_state) if _anim.has_animation(_state) else null
	if a == null or not a.has_meta(&"ground_speed"):
		return
	var size := _model.global_basis.x.length()
	if _speed < 0.08 or size <= 0.0:
		_anim.speed_scale = 1.0   # standing still in a walk (a portrait, a shot): natural pace
		return
	_anim.speed_scale = clampf(_speed / (float(a.get_meta(&"ground_speed")) * size), RATE_MIN, RATE_MAX)


## The current playback rate (1 = as authored); tests read it.
func play_rate() -> float:
	return _anim.speed_scale if _anim else 1.0


# ------------------------------------------------------------------ props in the hands

func _set_props(r: StringName, l: StringName) -> void:
	if _props[0] == r and _props[1] == l and _skeleton != null and _skeleton.get_node_or_null("HandR") != null:
		return
	_props = [r, l]
	_rebuild_props()


func _rebuild_props() -> void:
	if _skeleton == null:
		return
	for side in ["r", "l"]:
		var att_name := "HandR" if side == "r" else "HandL"
		var att := _skeleton.get_node_or_null(att_name) as BoneAttachment3D
		var id: StringName = _props[0 if side == "r" else 1]
		if att:
			for c in att.get_children():
				if c.get_meta(&"prop_id", &"") != id:
					c.free()
			if att.get_child_count() > 0:
				continue
		if id == &"" or not PropKit.has(id):
			continue
		if att == null:
			att = BoneAttachment3D.new()
			att.name = att_name
			att.bone_name = "hand_" + side
			_skeleton.add_child(att)
		var prop := PropKit.make(id)
		var fr: Array = _hand_frames(side)
		prop.transform = fr[0] if PropKit.mount(id) == &"grip" else fr[1]
		att.add_child(prop)


## [grip, palm] frames for a hand, in the hand bone's space, from the finger bones' rest:
## f along the fingers, t across the knuckles toward the index finger, and the palm
## normal. grip: +Y along t (a handle's working end comes out on the thumb side), +Z
## along f, origin inside the closed fist. palm: +Y out of the palm, +Z along f.
func _hand_frames(side: String) -> Array:
	if _grip_frames.has(side):
		return _grip_frames[side]
	var sk := _skeleton
	var f := Vector3.UP
	var t := Vector3.BACK
	var mi := sk.find_bone("middle_01_" + side)
	var ii := sk.find_bone("index_01_" + side)
	var pi := sk.find_bone("pinky_01_" + side)
	if mi >= 0 and ii >= 0 and pi >= 0:
		f = sk.get_bone_rest(mi).origin.normalized()
		t = sk.get_bone_rest(ii).origin - sk.get_bone_rest(pi).origin
		t = (t - f * t.dot(f)).normalized()
	var palm := t.cross(f) if side == "r" else f.cross(t)
	var grip := Transform3D(Basis(t.cross(f), t, f), f * 0.085 + palm * 0.035)
	var palm_xf := Transform3D(Basis(palm.cross(f), palm, f), f * 0.05 + palm * 0.03)
	_grip_frames[side] = [grip, palm_xf]
	return _grip_frames[side]


# ------------------------------------------------------------------ armful

func _update_cargo_visible() -> void:
	if _cargo:
		_cargo.visible = _state in CARRY_CLIPS


## Runs after the skeleton poses each frame: the armful sits between the hands, upright,
## facing the way the villager faces.
func _place_cargo() -> void:
	if _cargo == null or _skeleton == null or not _cargo.visible:
		return
	var hr := _skeleton.find_bone("hand_r")
	var hl := _skeleton.find_bone("hand_l")
	if hr < 0 or hl < 0:
		return
	var a := _skeleton.get_bone_global_pose(hr)
	var b := _skeleton.get_bone_global_pose(hl)
	# a little along the fingers from the wrists, so it rests in the hands
	var mid := (a.origin + a.basis.y.normalized() * 0.07 + b.origin + b.basis.y.normalized() * 0.07) * 0.5
	var world := _skeleton.global_transform * mid
	var s := _model.global_basis.x.length() / (ADULT_HEIGHT / 1.81)
	_cargo.global_transform = Transform3D(global_basis.orthonormalized().scaled_local(Vector3.ONE * s), world)


# ------------------------------------------------------------------ seats

func _update_seat(rebuild := false) -> void:
	var want := _state in SEAT_CLIPS and not _seat_provided and _model != null
	if rebuild and _seat:
		_seat.free()
		_seat = null
	if not want:
		if _seat:
			_seat.visible = false
		return
	if _seat == null:
		var era := _tailoring()
		var id := &"seat_stool" if era >= 2 else (&"seat_log" if posmod(_outfit, 3) != 1 else &"seat_rock")
		_seat = PropKit.make(id)
		_seat.name = "Seat"
		add_child(_seat)
	_seat.visible = true
	var k := _model.scale.x
	_seat.position = SEAT_AT * k
	_seat.scale = Vector3.ONE * k / (ADULT_HEIGHT / 1.81)
