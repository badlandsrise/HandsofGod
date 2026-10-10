extends Person
## Test double for Person: records the hand's calls and draws a tiny villager.

var held_now: bool = false
var lifted_count: int = 0
var placed: Array = []          # [at, site] pairs
var colour: Color = Color(0.8, 0.5, 0.3)

func _ready() -> void:
	super()
	var vis := Node3D.new()
	vis.name = "Visual"
	add_child(vis)
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.22
	cm.height = 0.75
	body.mesh = cm
	body.material_override = m
	body.position.y = 0.42
	vis.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.21
	sm.height = 0.42
	head.mesh = sm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.96, 0.8, 0.65)
	head.material_override = hm
	head.position.y = 0.98
	vis.add_child(head)

func pickable() -> bool: return not held_now

func on_lifted() -> void:
	held_now = true
	lifted_count += 1

func on_placed(at: Vector3, site: Site) -> void:
	held_now = false
	placed.append([at, site])
	global_position = at
	if site != null and site.can_accept(1):
		site.claim(self)
		job_site = site

func status_text() -> String: return "Idle" if job_site == null else "Working"
