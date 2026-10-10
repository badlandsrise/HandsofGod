class_name PropKit
extends RefCounted
## Small props modelled in code in the house style (flat palette shader, chunky low-poly
## shapes): the tools villagers work with, what they carry home (one prop per resource
## kind), the seats they sit on and the gifts they leave the hand.
##   PropKit.make(id) -> Node3D        a fresh copy (meshes and materials are shared)
##   PropKit.mount(id) -> StringName   how it is held: &"grip" (a fist round a handle),
##                                     &"palm" (resting on the open palm) or &"cargo"
##   PropKit.cargo_id(kind) -> StringName  the carried prop for a resource kind
##   PropKit.has(id)
##   PropKit.gift_visual(kind: String) -> Node3D  a gift as it lies at the shrine: the
##                                     object (by Gift kind, e.g. "carved hand") on a soft,
##                                     slowly breathing glow
## Frames (metres, adult villager scale):
##   grip:  origin in the fist, the handle along +Y, the working end up +Y
##   palm:  origin on the palm, +Y out of the palm, +Z along the fingers
##   cargo: origin between the two hands, +Y up, +Z away from the carrier's chest
##   seat, gift: origin on the ground

const GRIP := [&"axe", &"stone_axe", &"hammerstone", &"mallet", &"hammer", &"spear", &"pick", &"spade",
	&"sickle", &"firestick", &"knife", &"tongs", &"chisel", &"wrench", &"crook", &"peg"]
const PALM := [&"flint_core", &"basket", &"seed_bag", &"book", &"waterskin", &"bucket"]
## resource kind -> carried prop id
const CARGO := {
	&"berries": &"cargo_berries", &"wood": &"cargo_sticks", &"water": &"cargo_water",
	&"stone": &"cargo_stone", &"meat": &"cargo_meat", &"hide": &"cargo_hide", &"fish": &"cargo_fish",
	&"grain": &"cargo_grain", &"flour": &"cargo_flour", &"bread": &"cargo_bread", &"clay": &"cargo_clay",
	&"pots": &"cargo_pots", &"charcoal": &"cargo_charcoal", &"ore": &"cargo_ore", &"iron_ore": &"cargo_iron_ore",
	&"tin": &"cargo_tin", &"bronze": &"cargo_ingots", &"iron": &"cargo_iron", &"brass": &"cargo_brass",
	&"tools": &"cargo_tools", &"wool": &"cargo_wool", &"cloth": &"cargo_cloth", &"blocks": &"cargo_block",
	&"books": &"cargo_books", &"star_charts": &"cargo_scrolls", &"research": &"cargo_scrolls",
	&"planks": &"cargo_planks", &"coal": &"cargo_coal", &"fuel": &"cargo_crate", &"food": &"cargo_berries",
}
## Gift kind (Gift.KINDS) -> prop id
const GIFT_FOR_KIND := {
	"flowers": &"gift_wreath", "flower wreath": &"gift_wreath", "carved hand": &"gift_carved_hand",
	"handprint stone": &"gift_painted_stone", "painted stone": &"gift_painted_stone",
	"bead necklace": &"gift_necklace", "painted pot": &"gift_painted_pot", "woven cloth": &"gift_cloth",
	"illuminated book": &"gift_book", "clockwork hand": &"gift_clockwork_hand",
	"photograph of the village": &"gift_photo", "model rocket": &"gift_rocket",
}
const GIFT_SCALE := 1.5     # gifts are seen from the god's height: a little larger than life
const GLOW_COLOUR := Color(1.0, 0.82, 0.45)
const SEATS := [&"seat_log", &"seat_rock", &"seat_stool"]
const GIFTS := [&"gift_carved_hand", &"gift_wreath", &"gift_painted_stone", &"gift_necklace",
	&"gift_painted_pot", &"gift_cloth", &"gift_book", &"gift_clockwork_hand", &"gift_photo", &"gift_rocket"]

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}


static func has(id: StringName) -> bool:
	return id in GRIP or id in PALM or id in CARGO.values() or id in SEATS or id in GIFTS or id == &"cargo_crate"


static func mount(id: StringName) -> StringName:
	if id in GRIP:
		return &"grip"
	if id in PALM:
		return &"palm"
	return &"cargo"


static func gift_id(kind: String) -> StringName:
	if GIFT_FOR_KIND.has(kind):
		return GIFT_FOR_KIND[kind]
	for k in GIFT_FOR_KIND:   # loose match ("a carved hand", "stone with a handprint")
		if kind.contains(k) or k.contains(kind):
			return GIFT_FOR_KIND[k]
	return &"gift_carved_hand" if kind.contains("hand") else &"gift_wreath"


## A gift lying at the shrine: the object on a warm halo that breathes slowly, so it
## catches the eye among the grass. Origin on the ground.
static func gift_visual(kind: String) -> Node3D:
	var root := GiftGlow.new()
	var obj := make(gift_id(kind))
	obj.scale = Vector3.ONE * GIFT_SCALE
	root.add_child(obj)
	root.object = obj
	# the halo: a soft radial disc on the ground, added light so it glows in the dusk
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	q.orientation = PlaneMesh.FACE_Y
	halo.mesh = q
	halo.material_override = _glow_material()
	halo.position = Vector3(0, 0.03, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	root.halo = halo
	var light := OmniLight3D.new()
	light.light_color = GLOW_COLOUR
	light.omni_range = 1.6
	light.light_energy = 0.5
	light.shadow_enabled = false
	light.position = Vector3(0, 0.45, 0)
	root.add_child(light)
	root.light = light
	return root


static func _glow_material() -> Material:
	if _mats.has("_glow"):
		return _mats["_glow"]
	var g := Gradient.new()
	g.set_color(0, Color(GLOW_COLOUR, 0.55))
	g.set_color(1, Color(GLOW_COLOUR, 0.0))
	g.add_point(0.45, Color(GLOW_COLOUR, 0.22))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = t
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats["_glow"] = m
	return m


## The breathing glow under a gift (and a slow turn and bob of the object on it).
class GiftGlow extends Node3D:
	var object: Node3D
	var halo: MeshInstance3D
	var light: OmniLight3D
	var _t := randf() * TAU

	func _process(delta: float) -> void:
		_t += delta
		var b := 0.5 + 0.5 * sin(_t * 1.6)
		if halo:
			halo.scale = Vector3.ONE * (0.9 + 0.15 * b)
			halo.transparency = 0.35 - 0.3 * b
		if light:
			light.light_energy = 0.35 + 0.35 * b
		if object:
			object.position.y = 0.04 + 0.03 * b
			object.rotation.y += delta * 0.25


static func cargo_id(kind: StringName) -> StringName:
	return CARGO.get(kind, &"cargo_crate")


## Every prop id (tests and the contact sheet walk it).
static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for a in [GRIP, PALM, SEATS, GIFTS]:
		for id in a:
			out.append(id)
	for id in CARGO.values():
		if not id in out:
			out.append(id)
	if not &"cargo_crate" in out:
		out.append(&"cargo_crate")
	return out


static func make(id: StringName) -> Node3D:
	if not _cache.has(id):
		var root := Node3D.new()
		root.name = String(id)
		_build(id, root)
		_cache[id] = root
	var n := (_cache[id] as Node3D).duplicate() as Node3D
	n.set_meta(&"prop_id", id)
	return n


# ------------------------------------------------------------------ the models

static func _build(id: StringName, r: Node3D) -> void:
	match id:
		# ---- tools (grip frame: handle along +Y)
		&"stone_axe":
			_cyl(r, "wood", 0.022, 0.026, 0.62, Vector3(0, 0.2, 0))
			_rock(r, "flint", Vector3(0.05, 0.13, 0.11), Vector3(0, 0.44, 0.07), 3)
			_cyl(r, "rope", 0.032, 0.032, 0.07, Vector3(0, 0.44, 0))
		&"axe":
			_cyl(r, "wood", 0.021, 0.025, 0.66, Vector3(0, 0.2, 0))
			_box(r, "iron_light", Vector3(0.035, 0.09, 0.17), Vector3(0, 0.46, 0.07))
			_box(r, "iron", Vector3(0.04, 0.13, 0.03), Vector3(0, 0.46, 0.16))
		&"hammerstone":
			_rock(r, "stone_light", Vector3(0.07, 0.065, 0.07), Vector3(0, 0.02, 0), 7)
		&"mallet":
			_cyl(r, "wood", 0.018, 0.021, 0.42, Vector3(0, 0.12, 0))
			_cyl(r, "wood_dark", 0.06, 0.06, 0.17, Vector3(0, 0.34, 0), Vector3(90, 0, 0))
		&"hammer":
			_cyl(r, "wood", 0.016, 0.019, 0.4, Vector3(0, 0.12, 0))
			_box(r, "iron", Vector3(0.05, 0.05, 0.14), Vector3(0, 0.32, 0.02))
		&"spear":
			_cyl(r, "wood", 0.02, 0.022, 1.7, Vector3(0, 0.22, 0))
			_cone(r, "flint", 0.045, 0.2, Vector3(0, 1.16, 0))
			_cyl(r, "leather", 0.028, 0.028, 0.06, Vector3(0, 1.05, 0))
		&"pick":
			_cyl(r, "wood", 0.02, 0.024, 0.7, Vector3(0, 0.22, 0))
			var head := _cyl(r, "iron_light", 0.022, 0.03, 0.46, Vector3(0, 0.52, 0), Vector3(90, 0, 0))
			head.scale = Vector3(1, 1, 0.8)
		&"spade":
			_cyl(r, "wood", 0.02, 0.022, 0.8, Vector3(0, 0.25, 0))
			_box(r, "iron_light", Vector3(0.17, 0.24, 0.02), Vector3(0, 0.74, 0))
			_box(r, "wood", Vector3(0.14, 0.03, 0.03), Vector3(0, -0.14, 0))
		&"sickle":
			_cyl(r, "wood", 0.018, 0.02, 0.17, Vector3(0, 0.02, 0))
			# a crescent blade: short segments round an arc, thinning to the point
			for i in 7:
				var a := deg_to_rad(-80.0 + i * 30.0)
				var c := Vector3(0, 0.2 + sin(a) * 0.11, 0.1 - cos(a) * 0.11)
				_box(r, "iron_light", Vector3(0.012, 0.022 - i * 0.002, 0.06), c, Vector3(-rad_to_deg(a), 0, 0))
		&"firestick":
			_cyl(r, "wood_dark", 0.016, 0.022, 0.7, Vector3(0, 0.2, 0))
			var ember := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.028
			em.height = 0.05
			em.radial_segments = 6
			em.rings = 3
			ember.mesh = em
			ember.material_override = ArtPalette.flame_material()
			ember.position = Vector3(0, 0.56, 0)
			ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			r.add_child(ember)
		&"knife":
			_cyl(r, "wood", 0.016, 0.016, 0.1, Vector3(0, 0.0, 0))
			_box(r, "flint", Vector3(0.012, 0.13, 0.03), Vector3(0, 0.11, 0.005))
		&"tongs":
			_box(r, "iron", Vector3(0.016, 0.5, 0.016), Vector3(-0.012, 0.18, 0), Vector3(0, 0, 2))
			_box(r, "iron", Vector3(0.016, 0.5, 0.016), Vector3(0.012, 0.18, 0), Vector3(0, 0, -2))
		&"chisel":
			_cyl(r, "iron_light", 0.012, 0.014, 0.2, Vector3(0, 0.05, 0))
		&"wrench":
			_box(r, "steel", Vector3(0.025, 0.3, 0.012), Vector3(0, 0.08, 0))
			_torus(r, "steel", 0.025, 0.045, Vector3(0, 0.25, 0), Vector3(90, 0, 0))
		&"crook":
			_cyl(r, "wood", 0.018, 0.022, 1.55, Vector3(0, 0.25, 0))
			var hook := _torus(r, "wood", 0.07, 0.095, Vector3(0, 1.05, 0.08), Vector3(0, 90, 0))
			hook.scale = Vector3(1, 1, 1)
		&"peg":
			_cyl(r, "wood", 0.022, 0.016, 0.3, Vector3(0, -0.06, 0))
		# ---- palm items (palm frame: +Y out of the palm)
		&"flint_core":
			_rock(r, "flint", Vector3(0.08, 0.06, 0.09), Vector3(0, 0.05, 0.02), 11)
		&"basket":
			_basket(r, 0.12, 0.13, Vector3(0, 0.0, 0.03), false)
		&"seed_bag":
			_sack(r, "linen", 0.08, Vector3(0, 0.07, 0.03))
		&"book":
			_box(r, "leather", Vector3(0.2, 0.035, 0.26), Vector3(0, 0.02, 0.06))
			_box(r, "paper", Vector3(0.19, 0.03, 0.245), Vector3(0, 0.025, 0.064))
		&"waterskin":
			var sk := _ball(r, "leather", 0.09, Vector3(0, 0.08, 0.04))
			sk.scale = Vector3(0.8, 1.2, 0.7)
			_cyl(r, "leather", 0.02, 0.025, 0.06, Vector3(0, 0.2, 0.04))
		&"bucket":
			_cyl(r, "wood", 0.12, 0.1, 0.2, Vector3(0, -0.2, 0.02))
			_cyl(r, "iron", 0.123, 0.123, 0.02, Vector3(0, -0.13, 0.02))
			_cyl(r, "water", 0.11, 0.11, 0.01, Vector3(0, -0.11, 0.02))
		# ---- cargo (both hands, in front)
		&"cargo_berries":
			_basket(r, 0.2, 0.17, Vector3(0, -0.06, 0.02), true)
		&"cargo_sticks":
			_bundle(r, "wood", 9, 0.028, 0.8, 0.09, Vector3(0, 0.0, 0.02))
		&"cargo_water":
			var sk := _ball(r, "leather", 0.16, Vector3(0, 0.0, 0.03))
			sk.scale = Vector3(1.1, 0.85, 0.8)
			_cyl(r, "leather", 0.035, 0.04, 0.1, Vector3(0.15, 0.08, 0.03), Vector3(0, 0, -50))
			_cyl(r, "rope", 0.04, 0.04, 0.02, Vector3(0.19, 0.12, 0.03), Vector3(0, 0, -50))
		&"cargo_stone":
			_rock(r, "stone", Vector3(0.2, 0.16, 0.17), Vector3(0, 0.0, 0.04), 5)
		&"cargo_meat":
			var m := _ball(r, "meat", 0.14, Vector3(0, 0.0, 0.03))
			m.scale = Vector3(1.0, 0.8, 1.35)
			_ball(r, "fat", 0.06, Vector3(0.07, 0.06, 0.12))
			_cyl(r, "bone", 0.028, 0.035, 0.26, Vector3(0, 0.02, -0.2), Vector3(90, 0, 0))
			_ball(r, "bone", 0.045, Vector3(-0.015, 0.02, -0.33))
			_ball(r, "bone", 0.045, Vector3(0.025, 0.02, -0.33))
		&"cargo_hide":
			_cyl(r, "hide", 0.11, 0.11, 0.62, Vector3(0, 0.0, 0.02), Vector3(0, 0, 90))
			_cyl(r, "hide_light", 0.075, 0.075, 0.625, Vector3(0, 0.0, 0.02), Vector3(0, 0, 90))
			for x in [-0.18, 0.18]:
				_cyl(r, "rope", 0.116, 0.116, 0.035, Vector3(x, 0.0, 0.02), Vector3(0, 0, 90))
		&"cargo_fish":
			_cyl(r, "rope", 0.006, 0.006, 0.4, Vector3(0, 0.0, 0.02), Vector3(0, 0, 90))
			for i in 3:
				var f := _ball(r, "fish", 0.06, Vector3(-0.13 + i * 0.13, -0.12, 0.02))
				f.scale = Vector3(0.6, 2.2, 0.9)
				_cone(r, "fish_dark", 0.05, 0.08, Vector3(-0.13 + i * 0.13, -0.27, 0.02), Vector3(180, 0, 0))
		&"cargo_grain":
			_sack(r, "linen", 0.2, Vector3(0, -0.04, 0.03))
			for i in 4:
				_cyl(r, "crop_gold", 0.006, 0.006, 0.18, Vector3(-0.03 + i * 0.02, 0.2, 0.03), Vector3(0, 0, -20 + i * 13))
		&"cargo_flour":
			_sack(r, "wool", 0.19, Vector3(0, -0.04, 0.03))
		&"cargo_bread":
			_basket(r, 0.21, 0.08, Vector3(0, -0.04, 0.02), false)
			for i in 3:
				var b := _ball(r, "bread", 0.075, Vector3(-0.1 + i * 0.1, 0.04, 0.02 + (i % 2) * 0.03))
				b.scale = Vector3(1.0, 0.65, 1.4)
		&"cargo_clay":
			var c := _rock(r, "clay", Vector3(0.17, 0.12, 0.15), Vector3(0, 0.0, 0.04), 2)
			c.scale = Vector3(1, 1, 1)
		&"cargo_pots":
			_pot(r, "terracotta", Vector3(0, -0.08, 0.03), 1.0)
			_pot(r, "clay_light", Vector3(0, 0.1, 0.03), 0.8)
		&"cargo_charcoal":
			_basket(r, 0.19, 0.15, Vector3(0, -0.06, 0.02), false)
			_heap(r, "charcoal", 0.17, Vector3(0, 0.08, 0.02), 13)
		&"cargo_ore":
			_basket(r, 0.19, 0.15, Vector3(0, -0.06, 0.02), false)
			_heap(r, "copper", 0.17, Vector3(0, 0.08, 0.02), 17)
		&"cargo_iron_ore":
			_basket(r, 0.19, 0.15, Vector3(0, -0.06, 0.02), false)
			_heap(r, "rust", 0.17, Vector3(0, 0.08, 0.02), 19)
		&"cargo_tin":
			_basket(r, 0.19, 0.15, Vector3(0, -0.06, 0.02), false)
			_heap(r, "stone_light", 0.17, Vector3(0, 0.08, 0.02), 23)
		&"cargo_coal":
			_basket(r, 0.19, 0.15, Vector3(0, -0.06, 0.02), false)
			_heap(r, "coal", 0.17, Vector3(0, 0.08, 0.02), 29)
		&"cargo_ingots":
			_ingots(r, "bronze")
		&"cargo_iron":
			_ingots(r, "iron_light")
		&"cargo_brass":
			_ingots(r, "brass")
		&"cargo_tools":
			_box(r, "wood", Vector3(0.36, 0.12, 0.22), Vector3(0, -0.04, 0.03))
			for i in 3:
				_cyl(r, "wood", 0.014, 0.014, 0.34, Vector3(-0.1 + i * 0.1, 0.08, 0.03), Vector3(0, 0, 70 - i * 10))
				_box(r, "bronze", Vector3(0.07, 0.04, 0.03), Vector3(-0.1 + i * 0.1 + 0.12, 0.13 - i * 0.02, 0.03))
		&"cargo_wool":
			for i in 7:
				var a := TAU * i / 7.0
				_ball(r, "wool", 0.1, Vector3(cos(a) * 0.1, sin(a * 2.0) * 0.04 + 0.02, 0.03 + sin(a) * 0.07))
			_ball(r, "wool", 0.12, Vector3(0, 0.07, 0.03))
		&"cargo_cloth":
			_cyl(r, "cloth_blue", 0.085, 0.085, 0.5, Vector3(0, 0.05, 0.02), Vector3(0, 0, 90))
			_cyl(r, "cloth_red", 0.08, 0.08, 0.45, Vector3(0, -0.1, 0.04), Vector3(0, 0, 90))
		&"cargo_block":
			_box(r, "limestone", Vector3(0.4, 0.24, 0.26), Vector3(0, -0.02, 0.04))
			_box(r, "stone_light", Vector3(0.41, 0.02, 0.27), Vector3(0, 0.1, 0.04))
		&"cargo_books":
			var cols := ["leather", "cloth_red", "cloth_blue", "cloth_green"]
			for i in 4:
				_box(r, cols[i], Vector3(0.24 - i * 0.01, 0.05, 0.3 - i * 0.012), Vector3(0.01 * (i % 2), -0.06 + i * 0.05, 0.03), Vector3(0, i * 6 - 6, 0))
		&"cargo_scrolls":
			for i in 3:
				_cyl(r, "paper", 0.04, 0.04, 0.4, Vector3(0, -0.04 + i * 0.07, 0.03 + (i % 2) * 0.04), Vector3(0, 0, 90))
				_cyl(r, "cloth_red", 0.042, 0.042, 0.02, Vector3(0, -0.04 + i * 0.07, 0.03 + (i % 2) * 0.04), Vector3(0, 0, 90))
		&"cargo_planks":
			for i in 3:
				_box(r, "wood", Vector3(0.9, 0.035, 0.16), Vector3(0, -0.03 + i * 0.04, 0.03), Vector3(0, (i - 1) * 4, 0))
		&"cargo_crate":
			_box(r, "wood", Vector3(0.34, 0.26, 0.26), Vector3(0, -0.02, 0.03))
			_box(r, "wood_dark", Vector3(0.35, 0.03, 0.27), Vector3(0, 0.08, 0.03))
			_box(r, "wood_dark", Vector3(0.35, 0.03, 0.27), Vector3(0, -0.12, 0.03))
		# ---- seats (on the ground)
		&"seat_log":
			_cyl(r, "wood", 0.2, 0.2, 0.62, Vector3(0, 0.2, 0), Vector3(0, 0, 90))
			_cyl(r, "wood_light", 0.17, 0.17, 0.63, Vector3(0, 0.2, 0), Vector3(0, 0, 90))
			_ball(r, "moss", 0.06, Vector3(0.12, 0.38, -0.05))
		&"seat_rock":
			var rk := _rock(r, "stone", Vector3(0.3, 0.22, 0.26), Vector3(0, 0.2, 0), 31)
			rk.scale = Vector3(1, 1, 1)
			_ball(r, "moss", 0.07, Vector3(-0.15, 0.36, 0.05))
		&"seat_stool":
			_cyl(r, "wood", 0.19, 0.19, 0.05, Vector3(0, 0.43, 0))
			for i in 3:
				var a := TAU * i / 3.0
				_cyl(r, "wood_dark", 0.022, 0.026, 0.44, Vector3(cos(a) * 0.12, 0.2, sin(a) * 0.12), Vector3(sin(a) * 8.0, 0, -cos(a) * 8.0))
		# ---- gifts (on the ground)
		&"gift_carved_hand":
			_cyl(r, "wood_dark", 0.15, 0.17, 0.06, Vector3(0, 0.03, 0))
			var palm := _box(r, "wood", Vector3(0.13, 0.15, 0.06), Vector3(0, 0.15, 0))
			palm.rotation_degrees = Vector3(0, 0, 0)
			for i in 4:
				_cyl(r, "wood", 0.022, 0.02, 0.12 - absf(i - 1.5) * 0.02, Vector3(-0.045 + i * 0.03, 0.28 - absf(i - 1.5) * 0.01, 0))
			_cyl(r, "wood", 0.024, 0.022, 0.1, Vector3(0.09, 0.18, 0.0), Vector3(0, 0, -40))
			_ball(r, "red_ochre", 0.025, Vector3(0, 0.15, 0.03))
		&"gift_wreath":
			_torus(r, "leaf", 0.13, 0.2, Vector3(0, 0.03, 0))
			var cols := ["berry", "cloth_gold", "wool", "plaster_rose", "cloth_blue"]
			for i in 10:
				var a := TAU * i / 10.0
				var f := _ball(r, cols[i % cols.size()], 0.04, Vector3(cos(a) * 0.165, 0.07, sin(a) * 0.165))
				f.scale = Vector3(1, 0.6, 1)
				_ball(r, "cloth_gold", 0.015, Vector3(cos(a) * 0.165, 0.095, sin(a) * 0.165))
		&"gift_painted_stone":
			var st := _ball(r, "stone_light", 0.16, Vector3(0, 0.08, 0))
			st.scale = Vector3(1.2, 0.55, 1.0)
			# a red ochre handprint on top
			var p := _ball(r, "red_ochre", 0.05, Vector3(0, 0.155, 0.01))
			p.scale = Vector3(1.0, 0.18, 1.1)
			for i in 4:
				var fp := _ball(r, "red_ochre", 0.016, Vector3(-0.04 + i * 0.027, 0.155, -0.06 - absf(i - 1.5) * -0.008))
				fp.scale = Vector3(1, 0.3, 2.2)
			var th := _ball(r, "red_ochre", 0.016, Vector3(0.07, 0.15, 0.02))
			th.scale = Vector3(2.0, 0.3, 1)
		&"gift_necklace":
			var cols := ["bone", "red_ochre", "ochre", "bone", "cloth_blue", "bone", "berry"]
			for i in 18:
				var a := TAU * i / 18.0
				_ball(r, cols[i % cols.size()], 0.022, Vector3(cos(a) * 0.13, 0.025, sin(a) * 0.1))
			var tooth := _cone(r, "bone", 0.025, 0.08, Vector3(0, 0.025, 0.13), Vector3(-90, 0, 0))
			tooth.scale = Vector3(1, 1, 1)
		&"gift_painted_pot":
			_pot(r, "terracotta", Vector3(0, 0.12, 0), 1.0)
			_cyl(r, "charcoal", 0.122, 0.122, 0.03, Vector3(0, 0.12, 0))
			_cyl(r, "cloth_gold", 0.113, 0.113, 0.02, Vector3(0, 0.05, 0))
		&"gift_cloth":
			for i in 3:
				var cols := ["cloth_red", "cloth_gold", "cloth_blue"]
				_box(r, cols[i], Vector3(0.3, 0.04, 0.24), Vector3(0, 0.02 + i * 0.04, 0), Vector3(0, i * 9, 0))
		&"gift_book":
			_box(r, "cloth_plum", Vector3(0.24, 0.06, 0.3), Vector3(0, 0.03, 0))
			_box(r, "paper", Vector3(0.23, 0.05, 0.285), Vector3(0.006, 0.03, 0))
			_box(r, "brass", Vector3(0.1, 0.008, 0.12), Vector3(0, 0.062, 0))
		&"gift_clockwork_hand":
			_cyl(r, "wood_dark", 0.14, 0.15, 0.05, Vector3(0, 0.025, 0))
			_box(r, "brass", Vector3(0.12, 0.14, 0.05), Vector3(0, 0.14, 0))
			for i in 4:
				_cyl(r, "brass", 0.018, 0.016, 0.11, Vector3(-0.04 + i * 0.027, 0.26, 0))
			_torus(r, "copper", 0.03, 0.05, Vector3(0, 0.14, 0.03), Vector3(90, 0, 0))
		&"gift_photo":
			_box(r, "wood_dark", Vector3(0.24, 0.3, 0.03), Vector3(0, 0.15, 0), Vector3(-12, 0, 0))
			_box(r, "paper", Vector3(0.19, 0.24, 0.032), Vector3(0, 0.15, 0.002), Vector3(-12, 0, 0))
			_box(r, "stone_dark", Vector3(0.15, 0.08, 0.034), Vector3(0, 0.12, 0.004), Vector3(-12, 0, 0))
		&"gift_rocket":
			_cyl(r, "warm_white", 0.045, 0.05, 0.3, Vector3(0, 0.2, 0))
			_cone(r, "signal_orange", 0.045, 0.12, Vector3(0, 0.41, 0))
			for i in 3:
				var a := TAU * i / 3.0
				_box(r, "signal_orange", Vector3(0.012, 0.1, 0.07), Vector3(cos(a) * 0.05, 0.08, sin(a) * 0.05), Vector3(0, -rad_to_deg(a) + 90, 0))
			_cyl(r, "steel_dark", 0.08, 0.09, 0.03, Vector3(0, 0.015, 0))
		_:
			_box(r, "wood", Vector3(0.3, 0.25, 0.25), Vector3.ZERO)


# ------------------------------------------------------------------ composite shapes

## A woven basket: a tapered tub with a darker rim and weave bands; `full` heaps berries.
static func _basket(r: Node3D, rad: float, h: float, at: Vector3, full: bool) -> void:
	_cyl(r, "straw", rad, rad * 0.78, h, at)
	_cyl(r, "straw_dark", rad * 1.04, rad * 1.04, h * 0.14, at + Vector3(0, h * 0.5, 0))
	_cyl(r, "straw_dark", rad * 0.93, rad * 0.9, h * 0.1, at + Vector3(0, -h * 0.05, 0))
	if full:
		_heap(r, "berry", rad * 0.95, at + Vector3(0, h * 0.5, 0), 3)
		for i in 4:
			var a := TAU * i / 4.0 + 0.4
			var lf := _ball(r, "leaf", rad * 0.22, at + Vector3(cos(a) * rad * 0.7, h * 0.55, sin(a) * rad * 0.7))
			lf.scale = Vector3(1.4, 0.35, 0.8)


## A heap of little lumps (berries, charcoal, ore) on a basket's mouth.
static func _heap(r: Node3D, mat: String, rad: float, at: Vector3, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := 14
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * rad * 0.8
		var h := (1.0 - d / rad) * rad * 0.45
		var s := rad * rng.randf_range(0.17, 0.24)
		if mat == "berry":
			_ball(r, mat, s, at + Vector3(cos(a) * d, h, sin(a) * d))
		else:
			_rock(r, mat, Vector3(s, s * 0.8, s), at + Vector3(cos(a) * d, h, sin(a) * d), seed_v * 7 + i)


## A tied bundle of sticks or logs lying across the arms.
static func _bundle(r: Node3D, mat: String, n: int, rad: float, length: float, spread: float, at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var a := TAU * i / float(n) + rng.randf_range(-0.3, 0.3)
		var d := spread * sqrt(float(i % 3 + 1) / 3.0)
		var m := mat if i % 3 != 0 else "wood_dark"
		_cyl(r, m, rad * rng.randf_range(0.8, 1.2), rad * rng.randf_range(0.8, 1.2), length * rng.randf_range(0.85, 1.05),
			at + Vector3(rng.randf_range(-0.04, 0.04), sin(a) * d * 0.7, cos(a) * d * 0.7), Vector3(rng.randf_range(-6, 6), rng.randf_range(-8, 8), 90))
	for x in [-0.2, 0.2]:
		_cyl(r, "rope", spread * 1.05, spread * 1.05, 0.03, at + Vector3(x, 0, 0), Vector3(0, 0, 90))


## A tied sack (squashed ball with a gathered neck).
static func _sack(r: Node3D, mat: String, rad: float, at: Vector3) -> void:
	var b := _ball(r, mat, rad, at)
	b.scale = Vector3(1.0, 1.05, 0.8)
	_cyl(r, mat, rad * 0.35, rad * 0.55, rad * 0.5, at + Vector3(0, rad * 1.05, 0))
	_cyl(r, "rope", rad * 0.36, rad * 0.36, rad * 0.12, at + Vector3(0, rad * 1.0, 0))
	_cone(r, mat, rad * 0.4, rad * 0.3, at + Vector3(0, rad * 1.38, 0), Vector3(180, 0, 0))


## A round-bellied pot.
static func _pot(r: Node3D, mat: String, at: Vector3, s: float) -> void:
	var b := _ball(r, mat, 0.12 * s, at)
	b.scale = Vector3(1.0, 0.85, 1.0)
	_cyl(r, mat, 0.07 * s, 0.09 * s, 0.06 * s, at + Vector3(0, 0.1 * s, 0))
	_cyl(r, mat, 0.085 * s, 0.075 * s, 0.025 * s, at + Vector3(0, 0.135 * s, 0))


## Three cast bars, stacked crosswise.
static func _ingots(r: Node3D, mat: String) -> void:
	for i in 2:
		_box(r, mat, Vector3(0.3, 0.06, 0.09), Vector3(0, -0.04, -0.06 + i * 0.12))
	_box(r, mat, Vector3(0.09, 0.06, 0.3), Vector3(0, 0.025, 0.0))


# ------------------------------------------------------------------ primitives

static func _mat(mat_name: String) -> Material:
	if _mats.has(mat_name):
		return _mats[mat_name]
	var own := {"meat": "#a8463a", "fat": "#e9d7c2", "hide_light": "#c49a6c", "fish": "#9fb3bf", "fish_dark": "#5f7480",
		"wood_light": "#b8875a"}
	var m: Material
	if own.has(mat_name):
		var sm := ShaderMaterial.new()
		sm.shader = ArtPalette.SHADER
		sm.set_shader_parameter("albedo_color", Color(own[mat_name]))
		sm.set_shader_parameter("palette_pull", 0.0)
		ArtPalette.register(sm)
		m = sm
	else:
		m = ArtPalette.material(mat_name)
	_mats[mat_name] = m
	return m


static func _mi(r: Node3D, mesh: Mesh, mat: String, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	mi.position = at
	mi.rotation_degrees = rot
	r.add_child(mi)
	return mi


static func _cyl(r: Node3D, mat: String, top: float, bottom: float, h: float, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 8 if maxf(top, bottom) < 0.05 else 12
	m.rings = 1
	return _mi(r, m, mat, at, rot)


static func _cone(r: Node3D, mat: String, rad: float, h: float, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = rad
	m.height = h
	m.radial_segments = 7
	m.rings = 1
	return _mi(r, m, mat, at, rot)


static func _box(r: Node3D, mat: String, size: Vector3, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mi(r, m, mat, at, rot)


static func _ball(r: Node3D, mat: String, rad: float, at: Vector3) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = rad
	m.height = rad * 2.0
	m.radial_segments = 10
	m.rings = 6
	return _mi(r, m, mat, at)


static func _torus(r: Node3D, mat: String, inner: float, outer: float, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 14
	m.ring_segments = 6
	return _mi(r, m, mat, at, rot)


## A faceted rock: a low-poly sphere with its vertices pushed about (flat shaded).
static func _rock(r: Node3D, mat: String, size: Vector3, at: Vector3, seed_v: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 7
	sm.rings = 4
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	# jitter each distinct position the same way (seams stay closed)
	var jit := {}
	for i in verts.size():
		var key := Vector3i(roundi(verts[i].x * 1000), roundi(verts[i].y * 1000), roundi(verts[i].z * 1000))
		if not jit.has(key):
			jit[key] = rng.randf_range(0.78, 1.12)
		var v := verts[i] * float(jit[key])
		verts[i] = Vector3(v.x * size.x, maxf(v.y, -0.55) * size.y, v.z * size.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in idx.size():
		st.add_vertex(verts[idx[i]])
	st.generate_normals()
	return _mi(r, st.commit(), mat, at)
