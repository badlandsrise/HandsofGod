class_name Memorial extends Node3D
## A memorial stone with one carved name, set in a row near the shrine when
## someone dies. Persisted; the Village Book reads group "memorial".

const SCENE := "res://scenes/people/memorial.tscn"

var person_uid: int = 0
var carved_name: String = ""
var cause: String = ""
var died_day: int = 0
var uid: int = 0

static func add_name(p: Person, why: String) -> Memorial:
	if not p.is_inside_tree():
		return null
	var m: Memorial = (load(SCENE) as PackedScene).instantiate()
	m.person_uid = p.uid
	m.carved_name = p.given_name
	m.cause = why
	m.died_day = Clock.day
	var parent: Node = Game.world if Game.world != null and is_instance_valid(Game.world) else p.get_parent()
	parent.add_child(m)
	var count := p.get_tree().get_nodes_in_group("memorial").size() - 1
	var shrine := Site.nearest_shrine(p.global_position)
	var base := shrine.global_position + Vector3(-2.0, 0, shrine.pick_radius() + 2.5) if shrine else p.global_position
	var at := base + Vector3(float(count % 8) * 0.9, 0, float(count / 8) * 0.9)
	at.y = Site.ground(at.x, at.z)
	m.global_position = at
	return m

func _ready() -> void:
	add_to_group("persist"); add_to_group("memorial")
	if uid == 0:
		uid = Village.new_person_id()
	if get_node_or_null("Visual") == null:
		var v := Node3D.new()
		v.name = "Visual"
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.7, 0.18)
		mi.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.53)
		mi.material_override = mat
		mi.position = Vector3(0, 0.35, 0)
		v.add_child(mi)
		add_child(v)

func save_state() -> Dictionary:
	var p := global_position if is_inside_tree() else position
	return {"scene": SCENE, "uid": uid, "person_uid": person_uid, "name": carved_name, "cause": cause,
		"day": died_day, "pos": [p.x, p.y, p.z]}

func load_state(d: Dictionary) -> void:
	uid = int(d.get("uid", 0)); person_uid = int(d.get("person_uid", 0))
	carved_name = str(d.get("name", "")); cause = str(d.get("cause", "")); died_day = int(d.get("day", 0))
	var pa: Array = d.get("pos", [0, 0, 0])
	var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	if is_inside_tree(): global_position = pos
	else: position = pos
