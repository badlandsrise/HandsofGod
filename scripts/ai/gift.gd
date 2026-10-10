class_name Gift extends Node3D
## A gift the people left at the shrine. The hand picks it up for faith
## (faith_value) or keeps it; picking up is the hand's job. If grants_power is
## set (the very first gift grants Grip II), the hand should Faith.grant() it.

const SCENE := "res://scenes/sites/gift.tscn"
const KINDS: Dictionary = {
	1: ["flowers", "carved hand", "handprint stone"],
	2: ["painted pot", "woven cloth"],
	3: ["illuminated book", "clockwork hand"],
	4: ["photograph of the village", "model rocket"],
}

var uid: int = 0
var faith_value: float = 3.0
var grants_power: StringName = &""
var kind: String = "flowers"
var from_uid: int = 0
var from_name: String = ""
var era: int = 1

func _ready() -> void:
	add_to_group("persist"); add_to_group("gift")
	if uid == 0:
		uid = Village.new_person_id()
	_build_visual()

func _build_visual() -> void:
	var old := get_node_or_null("Visual")
	if old:
		remove_child(old); old.queue_free()
	var v := Node3D.new()
	v.name = "Visual"
	add_child(v)
	var col := Color(0.95, 0.45, 0.6)
	var mesh: Mesh
	if kind.contains("hand") or kind.contains("stone"):
		var b := BoxMesh.new(); b.size = Vector3(0.4, 0.15, 0.3); mesh = b
		col = Color(0.75, 0.4, 0.2)
	elif kind == "flowers":
		var s := SphereMesh.new(); s.radius = 0.18; s.height = 0.3; s.radial_segments = 6; s.rings = 3; mesh = s
	else:
		var c := CylinderMesh.new(); c.top_radius = 0.15; c.bottom_radius = 0.2; c.height = 0.35; c.radial_segments = 6; mesh = c
		col = Color(0.7, 0.5, 0.3)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col * 0.4
	mi.material_override = m
	mi.position = Vector3(0, 0.18, 0)
	v.add_child(mi)

func title() -> String:
	return "%s from %s" % [kind, from_name] if from_name != "" else kind

func save_state() -> Dictionary:
	var p := global_position if is_inside_tree() else position
	return {"scene": SCENE, "uid": uid, "faith_value": faith_value, "grants_power": str(grants_power),
		"kind": kind, "from_uid": from_uid, "from_name": from_name, "era": era, "pos": [p.x, p.y, p.z]}

func load_state(d: Dictionary) -> void:
	uid = int(d.get("uid", 0)); faith_value = float(d.get("faith_value", 3.0))
	grants_power = StringName(str(d.get("grants_power", ""))); kind = str(d.get("kind", "flowers"))
	from_uid = int(d.get("from_uid", 0)); from_name = str(d.get("from_name", "")); era = int(d.get("era", 1))
	var pa: Array = d.get("pos", [0, 0, 0])
	var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	if is_inside_tree():
		global_position = pos
		_build_visual()
	else:
		position = pos
