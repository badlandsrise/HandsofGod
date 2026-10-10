extends Site
## Test double for Site: a 3-slot group job ("Haul log 2/3").

var slots: int = 3
var needs: int = 3
var title: String = "Haul log"

func _ready() -> void:
	super()
	var vis := Node3D.new()
	vis.name = "Visual"
	add_child(vis)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.34
	cm.height = 3.2
	trunk.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.36, 0.2)
	trunk.material_override = m
	trunk.rotation = Vector3(0, 0, PI / 2)
	trunk.position.y = 0.34
	vis.add_child(trunk)

func can_accept(n: int = 1) -> bool: return n <= free_slots()
func free_slots() -> int: return maxi(slots - workers.size(), 0)
func group_needs() -> int: return needs
func slot_position(i: int) -> Vector3:
	var a := PI + PI * float(i) / float(maxi(slots - 1, 1))
	return global_position + Vector3(cos(a) * 1.4, 0, sin(a) * 1.0 + 0.9)
func hover_text() -> String: return "%s %d/%d" % [title, workers.size(), slots]
func pick_radius() -> float: return 2.0
func slots_filled() -> int: return workers.size()
func max_slots() -> int: return slots
func claim(p) -> void:
	if not workers.has(p):
		workers.append(p)
func release(p) -> void: workers.erase(p)
